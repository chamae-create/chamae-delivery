@TestOn('browser')
library;

// Browser tests explicitly register the production SDK plugins.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/data/customer_workspace.dart';

void main() {
  const enabled = bool.fromEnvironment('CHAMAE_CONTROLLED_EMULATORS');
  TestWidgetsFlutterBinding.ensureInitialized();
  const options = FirebaseOptions(
      apiKey: 'fake-client-sdk-emulator-only',
      appId: '1:1:web:client-sdk-emulator-only',
      messagingSenderId: '1',
      projectId: 'demo-chamae-rules');
  setUpAll(() async {
    if (!enabled) return;
    FirebaseCoreWeb.registerWith(webPluginRegistrar);
    FirebaseAuthWeb.registerWith(webPluginRegistrar);
    FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
    await Firebase.initializeApp(options: options);
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 18187);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 19099);
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  });

  test(
      'SDK preserves anonymous UID, cart/address after Google link and relogin; Rules deny another user',
      () async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    await auth.signOut();
    final anonymous = (await auth.signInAnonymously()).user!;
    final uid = anonymous.uid;
    final before = FirebaseCustomerWorkspace();
    await before.read();
    const address = DeliveryAddress(
        latitude: -22.53,
        longitude: -55.72,
        street: 'Rua de teste SDK',
        number: '1',
        district: 'Teste',
        city: 'Ponta Porã',
        countryCode: 'BR',
        addressText: 'Rua de teste SDK, 1',
        confirmed: true);
    await before.save({
      'cart': [
        {'id': 'cliente-sdk-test-only', 'quantity': 2}
      ],
      'addresses': [address.toMap()],
      'lastAddress': address.toMap(),
      'contact': {'name': 'Cliente SDK de teste', 'phone': '+5500000000000'}
    });
    // Deliberately fake provider identity is supported ONLY by the Auth Emulator.
    // It is confined to this opt-in test and never shipped in an app entrypoint.
    final subject = 'cliente-sdk-${DateTime.now().microsecondsSinceEpoch}';
    final credential = GoogleAuthProvider.credential(
        idToken: jsonEncode({
      'sub': subject,
      'email': '$subject@sdk-emulator.test',
      'email_verified': true,
      'name': 'Cliente SDK de teste'
    }));
    final linked = await anonymous.linkWithCredential(credential);
    expect(linked.user!.uid, uid);
    expect(linked.user!.isAnonymous, isFalse);
    expect(linked.user!.providerData.map((p) => p.providerId),
        contains('google.com'));
    final adapter = FirebaseCustomerAuth();
    await adapter.refresh();
    expect(adapter.current!.uid, uid);
    final token = await auth.currentUser!.getIdTokenResult(true);
    expect(
        (token.claims!['firebase'] as Map)['sign_in_provider'], 'google.com');
    final onboarding = await FirebaseCustomerOnboarding().load();
    expect(onboarding.profile['birthDate'], isNull);
    expect(onboarding.profile['acceptedAt'], isNull);
    final profile = await db
        .collection('customerProfiles')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    expect(profile.metadata.isFromCache, isFalse);
    expect(profile.data()!['createdAt'], isA<Timestamp>());
    expect(profile.data()!.keys, ['createdAt']);
    final persistedBeforeLogout = await db
        .collection('customerWorkspaces')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    expect(persistedBeforeLogout.metadata.isFromCache, isFalse);
    expect(persistedBeforeLogout.data()!['cart'], [
      {'id': 'cliente-sdk-test-only', 'quantity': 2}
    ]);
    UserSession.fullName = 'TEMPORARY PERSONAL DATA';
    await adapter.signOut();
    expect(auth.currentUser, isNull);
    expect(UserSession.fullName, isEmpty);
    await expectLater(before.read(), throwsStateError);
    final restored = await auth.signInWithCredential(credential);
    expect(restored.user!.uid, uid);
    final restoredProfile = await FirebaseCustomerOnboarding().load();
    expect(restoredProfile.profile['createdAt'], profile.data()!['createdAt']);
    expect(restoredProfile.profile['acceptedAt'], isNull);
    final after = FirebaseCustomerWorkspace();
    final saved = await after.read();
    expect(saved['cart'], [
      {'id': 'cliente-sdk-test-only', 'quantity': 2}
    ]);
    expect((saved['lastAddress'] as Map)['countryCode'], 'BR');
    expect((saved['contact'] as Map)['name'], 'Cliente SDK de teste');
    await adapter.signOut();
    final other = (await auth.signInAnonymously()).user!;
    expect(other.uid, isNot(uid));
    await expectLater(
        db
            .collection('customerWorkspaces')
            .doc(uid)
            .get(const GetOptions(source: Source.server)),
        throwsA(isA<FirebaseException>()
            .having((e) => e.code, 'authorization', 'permission-denied')));
    await auth.signOut();
    // Counts and flags only: no token, email, UID or contact information in logs.
    // ignore: avoid_print
    print(
        'CLIENT_SDK_EMULATOR_EVIDENCE uidPreserved=true serverPersistence=true profilePersistence=true noFabricatedConsent=true logout=true sameUidRelogin=true crossUidDenied=true');
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 2)));
}
