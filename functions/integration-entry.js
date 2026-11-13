"use strict";
// Reject an implicit/production project before any Admin SDK initialization.
const {integrationProject, selectCommercialExports} = require("./commercial-selection");
const projectId = integrationProject(process.env);
const {getApps, initializeApp} = require("firebase-admin/app");
if (getApps().some((app) => app.options.projectId !== projectId)) throw Error("EXISTING_APP_PROJECT_MISMATCH");
if (!getApps().length) initializeApp({projectId, storageBucket: `${projectId}.firebasestorage.app`});
const {getFirestore} = require("firebase-admin/firestore");
const available = {...require("./index"),
  ...require("./customer-identification").createCustomerIdentification(getFirestore()),
  ...require("./age-verification-service").createAgeVerificationFunctions(getFirestore()),
  ...require("./recipient-age-check").createRecipientAgeCheck(getFirestore()),
  ...require("./delivery-journey").createDeliveryJourneyFunctions(getFirestore()),
  ...require("./delivery-pin-verification").createDeliveryPinVerification(getFirestore())};
// The unchanged index composes the existing financial, stock and PIX helpers.
// Unconfigured signer/map providers keep pickup closed until separately wired.
module.exports = selectCommercialExports(available);
