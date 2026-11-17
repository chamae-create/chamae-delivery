"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {createHash} = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const {Timestamp} = require("firebase-admin/firestore");

const {createRuntimeMapsAuth} = require("../maps-runtime-auth");
const {assertQuoteCaller} = require("../delivery-quote-limit");
const {parseEvent} = require("../courier-events");
const {submitDeliveryEvent} = require("../courier-delivery-events");
const {
  collectCourierTokens,
  registerCourierPushToken,
  createFcmCourierTransport,
  createCourierNotificationFunctions,
} = require("../courier-notifications");
const {notifyOrderStatusChange} = require("../customer-push-notifications");
const {ownProfile, reviewCourier} = require("../courier-approval");
const {useOpenClock} = require("./operational-fixture");
const {updateCourierLocation, createDeliveryJourneyFunctions} = require("../delivery-journey");
const {prepareOrderAcceptance} = require("../order-acceptance");
const {courierPolicyFixture, courierAcceptanceFixture} = require("./courier-policy-fixture");
const {deliveryFixture} = require("./delivery-fixture");

const hash = (v) => createHash("sha256").update(v).digest("hex");

test("[P0-01] runtime maps auth allows both staging and production, rejects unknown project", async () => {
  for (const project of ["chamae-delivery-staging", "chamae-delivery"]) {
    const authHeaders = createRuntimeMapsAuth({
      env: {K_SERVICE: "chamaeCotarEntrega", GCLOUD_PROJECT: project},
      clientFactory: () => ({getAccessToken: async () => "token-123"}),
    });
    const headers = await authHeaders();
    assert.equal(headers.Authorization, "Bearer token-123");
    assert.equal(headers["X-Goog-User-Project"], project);
  }
  const denied = createRuntimeMapsAuth({
    env: {K_SERVICE: "chamaeCotarEntrega", GCLOUD_PROJECT: "rogue-project"},
    clientFactory: () => ({getAccessToken: async () => "token-123"}),
  });
  await assert.rejects(denied(), /MAPS_RUNTIME_AUTH_UNAVAILABLE/);
});

test("[P0-01] quote caller allows non-anonymous customer in prod and rejects anonymous", () => {
  assert.doesNotThrow(() => assertQuoteCaller({
    auth: {uid: "cust-1", token: {firebase: {sign_in_provider: "google.com"}}},
  }, ""));
  assert.throws(() => assertQuoteCaller({
    auth: {uid: "anon-1", token: {firebase: {sign_in_provider: "anonymous"}}},
  }, ""), (e) => e.code === "permission-denied");
  assert.throws(() => assertQuoteCaller({
    auth: {uid: "cust-2", token: {firebase: {sign_in_provider: "google.com"}}},
  }, "cust-1"), (e) => e.code === "permission-denied");
});

test("[P0-02 & CNH Opcional] courier registers and gets approved without driverLicense", async () => {
  const docs = new Map();
  const policy = courierPolicyFixture();
  docs.set("courierPolicies/current", policy);
  docs.set("courierPolicyAcceptances/rider1", courierAcceptanceFixture(policy, Timestamp.now()));
  docs.set("courierProfilePhotos/rider1", {verified: true, reference: "photo-ref-1"});
  const refFor = (p) => ({
    path: p,
    get: async () => ({exists: docs.has(p), data: () => docs.get(p)}),
  });
  const db = {
    doc: refFor,
    collection: (c) => ({doc: (id) => refFor(`${c}/${id || `auto-${docs.size}`}`)}),
    runTransaction: async (fn) => {
      const ops = [];
      const res = await fn({
        get: async (r) => ({exists: docs.has(r.path), data: () => docs.get(r.path)}),
        create: (r, d) => ops.push([r.path, d]),
        update: (r, d) => ops.push([r.path, {...(docs.get(r.path) || {}), ...d}]),
      });
      for (const [p, d] of ops) docs.set(p, d);
      return res;
    },
  };
  const reg = await ownProfile(db, {
    auth: {uid: "rider1", token: {firebase: {sign_in_provider: "password"}, email_verified: true}},
    data: {name: "Moto Sem CNH", phone: "67999990000", profilePhoto: "photo-ref-1", vehicleType: "bicycle"},
  }, "register");
  assert.equal(reg.driverLicense, "");
  assert.equal(reg.approvalStatus, "pendingApproval");
  const reviewed = await reviewCourier(db, {
    auth: {uid: "admin1", token: {roles: ["superadmin"], firebase: {sign_in_provider: "password"}}},
    data: {courierUid: "rider1", action: "approve", expectedStatus: "pendingApproval"},
  });
  assert.equal(reviewed.approvalStatus, "approved");
});

test("[P0-02] courier confirmDelivery settles cash/card collection after PIN, never PIX", async () => {
  const mkFixture = (orderPatch = {}) => {
    const df = deliveryFixture();
    const docs = new Map(df.documents);
    const future = Timestamp.fromMillis(Date.now() + 3600 * 1000);
    const verificationId = "b".repeat(64);
    const policy = courierPolicyFixture();
    docs.set("courierPolicies/current", policy);
    docs.set("courierPolicyAcceptances/rider1", courierAcceptanceFixture(policy, Timestamp.now()));
    docs.set("couriers/rider1", {
      name: "Moto Rider",
      role: "courier", approvalStatus: "approved", administrativeState: "active",
      enabled: true, online: true,
    });
    docs.set("courierPickupAssignments/assign1", {
      courierUid: "rider1", orderId: "o1", status: "pickedUp",
    });
    docs.set("courierPickupGrants/o1", {
      courierUid: "rider1", assignmentId: "assign1", expiresAt: future,
      digest: "c".repeat(64), sessionId: "d".repeat(64), lastDeliverySequence: 1,
    });
    docs.set("courierDeliveries/o1", {orderId: "o1", courierUid: "rider1"});
    docs.set("customerDeliverySecrets/buyer", {revision: 1});
    docs.set("deliveryPinVerifiers/o1", {
      uid: "buyer", customerRevision: 1, verifiedCourierUid: "rider1",
      verifiedAssignmentId: "assign1", verificationId,
      verifiedAt: Timestamp.now(), record: {reconciled: true},
    });
    docs.set("products/p1", {category: "Gelo", priceBRL: 69});
    docs.set("orderFinancials/o1", {
      items: [{id: "p1", quantity: 1}], totalCentavos: 7000, totalBRL: 70,
    });
    docs.set("orders/o1", {
      id: "#CH-TEST1", customerUid: "buyer", customerName: "Cliente Teste",
      address: "Rua da Loja, 10",
      deliveryQuoteId: df.quoteId, deliveryAddress: {...df.destination, addressText: "Rua da Loja, 10"},
      status: "Saiu para Entrega", courierDeliveryPhase: "arrived",
      courierUid: "rider1", courierAssignmentId: "assign1",
      courierAssignmentExpiresAt: future, courierAssignedAt: Timestamp.now(),
      financialValidationStatus: "validated", stockReservationStatus: "reserved",
      stockProcessingStatus: "pending", stockReservationRequired: true,
      itemsList: [{id: "p1", quantity: 1}],
      paymentMethod: "Dinheiro", paymentStatus: "Pendente na entrega", pixRequested: false,
      deliveryFee: 1, totalBRL: 70, ...orderPatch,
    });
    const quote = docs.get(`deliveryQuotes/${df.quoteId}`);
    quote.orderId = "o1";
    const refFor = (p) => ({path: p, id: p.split("/").pop()});
    const db = {
      doc: refFor,
      collection: (c) => ({doc: (id) => refFor(`${c}/${id || `auto-${docs.size}`}`)}),
      runTransaction: async (fn) => {
        const ops = [];
        const tx = {
          get: async (r) => ({exists: docs.has(r.path), data: () => docs.get(r.path)}),
          create: (r, d) => ops.push(["set", r.path, d]),
          set: (r, d) => ops.push(["set", r.path, d]),
          update: (r, d) => ops.push(["update", r.path, d]),
        };
        const out = await fn(tx);
        for (const [op, p, d] of ops) {
          docs.set(p, op === "update" ? {...(docs.get(p) || {}), ...d} : d);
        }
        return out;
      },
    };
    const buildEvent = (collectionConfirmed) => {
      const payload = {
        proof: {method: "pin", verificationId},
        ...(collectionConfirmed !== undefined ? {collectionConfirmed} : {}),
      };
      const canonical = {
        assignmentId: "assign1", protocolVersion: 2, eventId: "event-confirm-123456",
        orderId: "o1", courierUid: "rider1", type: "confirmDelivery",
        localTimestampMs: 1700000000000, sequence: 2, payload,
      };
      return {...canonical, fingerprint: hash(JSON.stringify(canonical))};
    };
    const helpers = {
      checkFinancial: () => {},
      checkDeliveryPayment: () => {},
      resolveReservation: async (tx, ref) => {
        tx.update(ref, {stockReservationStatus: "finalized", stockProcessingStatus: "processed"});
      },
    };
    return {db, docs, buildEvent, helpers};
  };

  const req = {auth: {uid: "rider1", token: {firebase: {sign_in_provider: "password"}, email_verified: true}}};

  // Without collectionConfirmed on unpaid cash -> fails closed
  const f1 = mkFixture();
  await assert.rejects(
      submitDeliveryEvent(f1.db, req, parseEvent(f1.buildEvent(), "rider1"), f1.helpers),
      (e) => e.details?.reason === "COLLECTION_CONFIRMATION_REQUIRED",
  );

  // Unpaid PIX cannot dispatch nor confirm via courier collection
  const f2 = mkFixture({paymentMethod: "PIX", pixRequested: true});
  await assert.rejects(
      submitDeliveryEvent(f2.db, req, parseEvent(f2.buildEvent(true), "rider1"), f2.helpers),
      (e) => ["DELIVERY_NOT_READY", "COLLECTION_CONFIRMATION_REQUIRED"].includes(e.details?.reason),
  );

  // Unpaid Dinheiro WITH collectionConfirmed: true -> Pago + Concluído
  const f3 = mkFixture({paymentMethod: "Dinheiro"});
  const ack = await submitDeliveryEvent(f3.db, req, parseEvent(f3.buildEvent(true), "rider1"), f3.helpers);
  assert.equal(ack.deliveryAcknowledgement.phase, "delivered");
  assert.equal(f3.docs.get("orders/o1").status, "Concluído");
  assert.equal(f3.docs.get("orders/o1").paymentStatus, "Pago");
  assert.ok(f3.docs.get("orders/o1").deliveryCollectionConfirmedAt);
});

test("[P0-04 & P2-03] courier push registration, notification trigger & invalid token cleanup", async () => {
  const token = "f".repeat(48);
  const docs = new Map([
    ["couriers/rider1", {
      role: "courier", approvalStatus: "approved", administrativeState: "active",
      enabled: true, online: true,
    }],
    ["courierNotificationOutbox/assign1", {
      courierUid: "rider1", orderId: "o1", assignmentId: "assign1",
      kind: "courier_assignment", version: "2", title: "Nova", body: "Corpo",
    }],
    ["orders/o1", {
      courierUid: "rider1", courierAssignmentId: "assign1",
      courierAssignmentExpiresAt: Timestamp.fromMillis(Date.now() + 60000), status: "Em Separação",
    }],
    ["users/cust1", {fcmToken: token, fcmTokens: [token]}],
    ["customerProfiles/cust1", {fcmToken: token}],
  ]);
  const db = {
    doc: (p) => ({
      path: p,
      get: async () => ({exists: docs.has(p), data: () => docs.get(p)}),
      set: async (d) => {
        const cur = docs.get(p) || {};
        docs.set(p, {...cur, ...d});
      },
    }),
    collection: (c) => ({doc: (id) => db.doc(`${c}/${id}`)}),
  };
  await registerCourierPushToken(db, {
    auth: {uid: "rider1", token: {firebase: {sign_in_provider: "password"}, email_verified: true}},
    data: {token, platform: "android"},
  });
  assert.equal(docs.get("couriers/rider1").fcmToken, token);
  assert.deepEqual(collectCourierTokens({fcmToken: token, fcmTokens: [token]}), [token]);

  const sentPayloads = [];
  const transport = createFcmCourierTransport(db, {
    sendEachForMulticast: async (msg) => {
      sentPayloads.push(msg);
      return {successCount: 1, failureCount: 0, responses: [{success: true}]};
    },
  });
  await transport.send("rider1", {title: "Nova", body: "Corpo", orderId: "o1", assignmentId: "assign1"}, "assign1");
  assert.equal(sentPayloads[0].android.notification.channelId, "chamae_assignments_v2");

  const fnDefs = createCourierNotificationFunctions(db);
  assert.equal(fnDefs.chamaeEnviarNotificacaoMotoboy.__endpoint.eventTrigger.retry, true);

  // Customer push cleanup on invalid scalar fcmToken
  const custRes = await notifyOrderStatusChange(db, {
    params: {orderId: "o1"},
    data: {
      before: {exists: true, data: () => ({status: "Novo"})},
      after: {exists: true, data: () => ({id: "#CH-1", status: "Em Separação", customerUid: "cust1"})},
    },
  }, {
    sendEachForMulticast: async () => ({
      successCount: 0, failureCount: 1,
      responses: [{success: false, error: {code: "messaging/registration-token-not-registered"}}],
    }),
  });
  assert.equal(custRes.failed, 1);
  assert.notEqual(docs.get("users/cust1").fcmToken, token);
});

test("[P0-05 & P0-06 & P0-07] pickup defaults enabled and atomic active-order query blocks concurrent order", async () => {
  const pickupSrc = fs.readFileSync(path.join(__dirname, "../courier-pickup-runtime.js"), "utf8");
  assert.match(pickupSrc, /defineBoolean\("CHAMAE_PICKUP_ENABLED",\s*\{default:\s*true\}\)/);
  const storageRules = fs.readFileSync(path.join(__dirname, "../../storage.rules"), "utf8");
  assert.match(storageRules, /match \/courier-photos\/\{uid\}\/\{fileName\}/);

  const df = deliveryFixture();
  const docs = new Map(df.documents);
  const db = {
    collection: (c) => ({
      doc: (id) => ({path: `${c}/${id}`, id}),
      where: () => ({limit: () => ({queryForOrders: true})}),
    }),
  };
  const tx = {
    get: async (ref) => {
      if (ref.queryForOrders) {
        return {docs: [{id: "existing-order", data: () => ({status: "Novo"})}]};
      }
      return {exists: docs.has(ref.path), data: () => docs.get(ref.path)};
    },
  };
  await useOpenClock(async () => {
    await assert.rejects(
        prepareOrderAcceptance(tx, db, {id: "new-order"}, {
          customerUid: "buyer",
          deliveryQuoteId: df.quoteId,
          deliveryAddress: df.destination,
        }),
        (e) => e.details?.reason === "ACTIVE_ORDER_EXISTS",
    );
  });
});

test("[Wave 3] chamaeAtualizarLocalizacaoMotoboy validates courier assignment and persists throttled telemetry", async () => {
  const fns = createDeliveryJourneyFunctions({});
  assert.equal(typeof fns.chamaeAtualizarLocalizacaoMotoboy, "function");

  const policy = courierPolicyFixture();
  const docs = new Map([
    ["couriers/c1", {
      role: "courier",
      approvalStatus: "approved",
      administrativeState: "active",
      enabled: true,
      online: true,
    }],
    ["courierPolicies/current", policy],
    ["courierPolicyAcceptances/c1", {
      acceptedAt: new Date(),
      acceptTerms: true,
      acknowledgePrivacy: true,
      policyRevision: policy.revision,
      policyHash: policy.contentHash,
      termsVersion: policy.termsVersion,
      privacyVersion: policy.privacyVersion,
    }],
    ["orders/ord1", {
      status: "Saiu para Entrega",
      courierUid: "c1",
    }],
  ]);
  const db = {
    doc: (p) => ({path: p}),
    collection: (c) => ({doc: (id) => ({path: `${c}/${id}`, id})}),
    runTransaction: async (fn) => {
      const tx = {
        get: async (ref) => ({exists: docs.has(ref.path), data: () => docs.get(ref.path)}),
        set: (ref, val) => docs.set(ref.path, val),
        update: (ref, val) => docs.set(ref.path, {...(docs.get(ref.path) || {}), ...val}),
      };
      return fn(tx);
    },
  };
  const req = {
    auth: {
      uid: "c1",
      token: {roles: ["courier"], email_verified: true, firebase: {sign_in_provider: "password"}},
    },
    data: {
      orderId: "ord1",
      latitude: -22.5361,
      longitude: -55.7256,
      accuracyMeters: 12.5,
      atMs: Date.now(),
      headingDegrees: 90,
    },
  };
  const first = await updateCourierLocation(db, req);
  assert.equal(first.accepted, true);
  assert.equal(first.throttled, false);
  assert.equal(docs.get("orders/ord1").courierLocation.latitude, -22.5361);

  const second = await updateCourierLocation(db, req);
  assert.equal(second.accepted, true);
  assert.equal(second.throttled, true);

  await assert.rejects(
      updateCourierLocation(db, {
        ...req,
        data: {...req.data, latitude: 999},
      }),
      (e) => e.details?.reason === "TELEMETRY_REQUEST_INVALID",
  );
});
