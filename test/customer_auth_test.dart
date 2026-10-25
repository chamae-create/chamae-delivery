// ignore_for_file: subtype_of_sealed_class
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:chamae_delivery/data/customer_auth.dart';

class ProviderInfo extends Fake implements UserInfo {
  @override
  final String providerId;
  ProviderInfo(this.providerId);
}

class CredentialResult extends Fake implements UserCredential {
  @override
  final User? user;
  CredentialResult(this.user);
}

class SdkUser extends Fake implements User {
  @override
  final String uid;
  @override
  bool isAnonymous;
  String provider;
  int links = 0, tokenRefreshes = 0;
  bool conflict = false, revoked = false;
  SdkUser(this.uid, {this.isAnonymous = false, this.provider = 'google.com'});
  @override
  String get displayName => 'Cliente';
  @override
  String get email => 'buyer@example.test';
  @override
  List<UserInfo> get providerData =>
      isAnonymous ? [] : [ProviderInfo(provider)];
  Future<UserCredential> _link(String name) async {
    if (conflict) {
      throw FirebaseAuthException(code: 'credential-already-in-use');
    }
    links++;
    provider = name;
    isAnonymous = false;
    return CredentialResult(this);
  }

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) =>
      _link(credential.providerId);
  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) =>
      _link(provider.providerId);
  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) =>
      _link(provider.providerId);
  @override
  Future<void> reload() async {
    if (revoked) throw FirebaseAuthException(code: 'user-disabled');
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) tokenRefreshes++;
    return 'TEST-TOKEN';
  }
}

class SdkAuth extends Fake implements FirebaseAuth {
  @override
  User? currentUser;
  int signIns = 0, signOuts = 0;
  String? failureCode;
  Future<UserCredential> _sign(String provider) async {
    if (failureCode != null) {
      throw FirebaseAuthException(code: failureCode!, message: 'SDK INTERNAL');
    }
    signIns++;
    currentUser = SdkUser('new-customer', provider: provider);
    return CredentialResult(currentUser);
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) =>
      _sign(credential.providerId);
  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) =>
      _sign(provider.providerId);
  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) =>
      _sign(provider.providerId);
  @override
  Future<void> signOut() async {
    signOuts++;
    currentUser = null;
  }

  @override
  Stream<User?> idTokenChanges() => Stream.value(currentUser);
}

void main() {
  late SdkAuth sdk;
  late FirebaseCustomerAuth adapter;
  setUp(() {
    sdk = SdkAuth();
    adapter = FirebaseCustomerAuth(
        auth: sdk,
        googleCredential: () async =>
            GoogleAuthProvider.credential(idToken: 'TEST-NO-REAL-TOKEN'));
  });
  for (final provider in CustomerProvider.values) {
    test('Firebase ${provider.name}: sign-in and refresh verified session',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await adapter.signIn(provider);
        expect(sdk.signIns, 1);
        expect(adapter.current?.anonymous, false);
        expect(adapter.current?.providers,
            [provider == CustomerProvider.google ? 'google.com' : 'apple.com']);
        expect((sdk.currentUser as SdkUser).tokenRefreshes, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
    test(
        'Firebase ${provider.name}: links existing anonymous UID instead of duplicating',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        sdk.currentUser = SdkUser('existing-customer', isAnonymous: true);
        await adapter.signIn(provider);
        expect(adapter.current?.uid, 'existing-customer');
        expect((sdk.currentUser as SdkUser).links, 1);
        expect(sdk.signIns, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
  test(
      'credential conflict preserves current UID and requires explicit account choice',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      sdk.currentUser = SdkUser('old-uid', isAnonymous: true)..conflict = true;
      await expectLater(
          adapter.signIn(CustomerProvider.google),
          throwsA(isA<CustomerAuthFailure>().having(
              (e) => e.existingAccount, 'existing account choice', true)));
      expect(sdk.currentUser?.uid, 'old-uid');
      expect(sdk.signIns, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  test('revoked session signs out and returns a friendly error', () async {
    sdk.currentUser = SdkUser('old-uid')..revoked = true;
    await expectLater(adapter.refresh(), throwsA(isA<CustomerAuthFailure>()));
    expect(sdk.currentUser, isNull);
    expect(sdk.signOuts, 1);
  });

  for (final code in [
    'popup-closed-by-user',
    'network-request-failed',
    'operation-not-allowed'
  ]) {
    test('Google $code returns friendly feedback without a new session',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        sdk.failureCode = code;
        await expectLater(
            adapter.signIn(CustomerProvider.google),
            throwsA(isA<CustomerAuthFailure>()
                .having((e) => e.message.contains('SDK INTERNAL'),
                    'no SDK message', false)
                .having((e) => e.existingAccount, 'no account switch offered',
                    false)));
        expect(sdk.currentUser, isNull);
        expect(sdk.signOuts, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  test('restored Firebase session is exposed without signing in again',
      () async {
    sdk.currentUser = SdkUser('restored-uid');
    expect((await adapter.changes.first)?.uid, 'restored-uid');
    await adapter.refresh();
    expect(sdk.signIns, 0);
    expect(adapter.current?.uid, 'restored-uid');
    expect((sdk.currentUser as SdkUser).tokenRefreshes, 1);
  });

  test('native Google cancellation retains the anonymous UID', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      sdk.currentUser = SdkUser('anonymous-uid', isAnonymous: true);
      final canceled = FirebaseCustomerAuth(
          auth: sdk,
          googleCredential: () async {
            throw const GoogleSignInException(
                code: GoogleSignInExceptionCode.canceled);
          });
      await expectLater(
          canceled.signIn(CustomerProvider.google),
          throwsA(isA<CustomerAuthFailure>().having(
              (e) => e.message, 'cancellation', contains('cancelada'))));
      expect(sdk.currentUser?.uid, 'anonymous-uid');
      expect(sdk.signIns, 0);
      expect((sdk.currentUser as SdkUser).links, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: kIsWeb);

  test('explicit account switch signs in only after conflict was presented',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final anonymous = SdkUser('anonymous-uid', isAnonymous: true)
        ..conflict = true;
      sdk.currentUser = anonymous;
      await expectLater(adapter.signIn(CustomerProvider.google),
          throwsA(isA<CustomerAuthFailure>()));
      expect(sdk.signIns, 0);
      await adapter.signIn(CustomerProvider.google, useExistingAccount: true);
      expect(sdk.signIns, 1);
      expect(anonymous.links, 0);
      expect(anonymous.uid, 'anonymous-uid');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
