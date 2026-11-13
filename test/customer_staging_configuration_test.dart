import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/data/customer_staging_configuration.dart';
import 'package:chamae_delivery/data/customer_sign_in_configuration.dart';
import 'package:chamae_delivery/main_staging.dart';
import 'package:chamae_delivery/main.dart' show initializeCustomerSession;

CustomerStagingConfiguration config(
        {String project = 'isolated-test-project',
        String sender = '123456789',
        String? app,
        String? bucket,
        String? domain,
        String key = 'TEST-ONLY'}) =>
    CustomerStagingConfiguration(
        projectId: project,
        apiKey: key,
        appId: app ?? '1:$sender:web:abcdef123',
        senderId: sender,
        storageBucket: bucket ?? '$project.firebasestorage.app',
        authDomain: domain ?? '$project.firebaseapp.com');

class UntouchedAuth extends Fake implements FirebaseAuth {
  int reads = 0;
  @override
  User? get currentUser {
    reads++;
    throw StateError('SDK_MUST_NOT_BE_USED');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('disabled staging provider never reaches Firebase SDK', () async {
    final sdk = UntouchedAuth();
    final auth = FirebaseCustomerAuth(auth: sdk);
    for (final provider in CustomerProvider.values) {
      await expectLater(
          auth.signIn(provider), throwsA(isA<CustomerAuthFailure>()));
    }
    expect(sdk.reads, 0);
  }, skip: const String.fromEnvironment('CHAMAE_ENV') != 'STAGING');
  test('staging compilation disables draft passage and unconfigured providers',
      () {
    const legacy = String.fromEnvironment('CHAMAE_ENV') != 'STAGING';
    expect(
        developmentCustomerPolicy.allowsDevelopmentOnboarding(debugMode: true),
        legacy);
    expect(CustomerSignInConfiguration.enabled('google'), legacy);
    expect(CustomerSignInConfiguration.enabled('apple'), legacy);
  });
  test('missing staging defines stop before any Firebase initialization',
      () async {
    await expectLater(initializeCustomerStagingSession(), throwsStateError);
    if (const String.fromEnvironment('CHAMAE_ENV').isNotEmpty) {
      await expectLater(initializeCustomerSession(), throwsStateError);
    }
    expect(Firebase.apps, isEmpty);
  },
      skip: const String.fromEnvironment('CHAMAE_FIREBASE_PROJECT_ID')
          .isNotEmpty);
  test('production, demo, empty and malformed project IDs are rejected', () {
    for (final project in [
      'chamae-delivery',
      'demo-isolated',
      '',
      'INVALID.example',
      ' localhost '
    ]) {
      expect(() => config(project: project).validate(), throwsStateError);
    }
    expect(() => config(sender: '302882774102').validate(), throwsStateError);
  });
  test(
      'inconsistent or missing app, sender, bucket, domain or API key rejected',
      () {
    for (final candidate in [
      config(app: '1:999:web:abc'),
      config(app: 'invalid'),
      config(sender: 'not-numeric'),
      config(bucket: 'chamae-delivery.firebasestorage.app'),
      config(domain: 'chamae-delivery.firebaseapp.com'),
      config(key: '')
    ]) {
      expect(candidate.validate, throwsStateError);
    }
  });
  test('coherent isolated configuration accepted without connecting a service',
      () {
    config().validate();
    config().checkExistingProject('isolated-test-project');
    expect(() => config().checkExistingProject('chamae-delivery'),
        throwsStateError);
  });
  test(
      'staging providers fail closed unless explicitly enabled; legacy preserved',
      () {
    for (final provider in ['google', 'apple']) {
      expect(
          CustomerSignInConfiguration.enabled(provider,
              environment: 'STAGING', google: false, apple: false),
          isFalse);
      expect(
          CustomerSignInConfiguration.enabled(provider,
              environment: '', google: false, apple: false),
          isTrue);
    }
    expect(
        CustomerSignInConfiguration.enabled('google',
            environment: 'STAGING', google: true, apple: false),
        isTrue);
    expect(
        CustomerSignInConfiguration.enabled('apple',
            environment: 'STAGING', google: true, apple: false),
        isFalse);
  });
}
