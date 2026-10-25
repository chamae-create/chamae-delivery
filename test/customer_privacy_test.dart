// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/customer_account.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/data/customer_local_privacy.dart';
import 'package:chamae_delivery/screens/customer_account_closure_screen.dart';
import 'package:chamae_delivery/screens/customer_session_gate.dart';
import 'customer_auth_test.dart' show SdkAuth, SdkUser, CredentialResult;
import 'support/customer_flow_fakes.dart';

class TokenResult extends Fake implements IdTokenResult {
  final String provider;
  TokenResult(this.provider);
  @override
  Map<String, dynamic> get claims => {
        'firebase': {'sign_in_provider': provider}
      };
}

class FailingLinkUser extends SdkUser {
  final String code;
  FailingLinkUser(this.code) : super('anonymous', isAnonymous: true);
  Future<UserCredential> _fail() async =>
      throw FirebaseAuthException(code: code, message: 'SDK INTERNAL');
  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) => _fail();
  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) => _fail();
  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) =>
      _fail();
}

class ReauthUser extends SdkUser {
  ReauthUser(super.uid, {super.provider, super.isAnonymous});
  String? reauthError, reloadError;
  int confirmations = 0;
  Future<void> Function()? afterReload, afterToken;
  Future<UserCredential> _confirm() async {
    confirmations++;
    if (reauthError != null) {
      throw FirebaseAuthException(
          code: reauthError!, message: 'SDK_SECRET_DETAIL');
    }
    return CredentialResult(this);
  }

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      TokenResult(provider);
  @override
  Future<UserCredential> reauthenticateWithProvider(AuthProvider provider) =>
      _confirm();
  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) =>
      _confirm();
  @override
  Future<UserCredential> reauthenticateWithCredential(
          AuthCredential credential) =>
      _confirm();
  @override
  Future<void> reload() async {
    if (reloadError != null) throw FirebaseAuthException(code: reloadError!);
    await super.reload();
    await afterReload?.call();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    final result = await super.getIdToken(forceRefresh);
    await afterToken?.call();
    return result;
  }
}

class CacheDouble extends Fake implements FirebaseFirestore {
  final calls = <String>[];
  bool fail = false;
  @override
  Future<void> terminate() async {
    calls.add('terminate');
  }

  @override
  Future<void> clearPersistence() async {
    calls.add('clear');
    if (fail) throw StateError('CACHE_CLEAR_FAILED');
  }
}

class PendingAppleAccount implements CustomerAccountRepository {
  int requests = 0;
  @override
  Future<void> reauthenticate() async {}
  @override
  Future<AccountClosureStatus> request() async {
    requests++;
    return AccountClosureStatus.providerPending;
  }

  @override
  Stream<AccountClosureStatus> watch() =>
      Stream.value(AccountClosureStatus.providerPending);
  @override
  Future<void> finishSession() async =>
      throw StateError('must not finish blocked Apple');
}

void main() {
  late SdkAuth sdk;
  late FirebaseCustomerAuth adapter;
  setUp(() {
    CustomerLocalPrivacy.state.value = LocalClosureCleanup.idle;
    UserSession.clearPersonalData();
    sdk = SdkAuth();
    adapter = FirebaseCustomerAuth(
        auth: sdk,
        googleCredential: () async =>
            GoogleAuthProvider.credential(idToken: 'TEST_ONLY_TOKEN'));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  void populate() {
    UserSession.fullName = 'OLD_NAME';
    UserSession.socialName = 'OLD_SOCIAL';
    UserSession.whatsapp = 'OLD_PHONE';
    UserSession.document = 'OLD_DOCUMENT';
    UserSession.isRegistered = true;
  }

  void cleared() {
    expect([
      UserSession.fullName,
      UserSession.socialName,
      UserSession.whatsapp,
      UserSession.document
    ], everyElement(''));
    expect(UserSession.isRegistered, false);
  }

  for (final provider in CustomerProvider.values) {
    final id = provider == CustomerProvider.apple ? 'apple.com' : 'google.com';
    test(
        '$id reauthentication preserves UID and does not delete/revoke or switch provider account',
        () async {
      final user = ReauthUser('buyer', provider: id);
      sdk.currentUser = user;
      await adapter.confirmIdentity();
      expect(adapter.current?.uid, 'buyer');
      expect(user.confirmations, 1);
      expect(user.tokenRefreshes, 1);
      expect(sdk.signIns, 0);
      expect(sdk.signOuts, 0);
    });
    test(
        '$id credential conflict preserves identity; only explicit choice signs into existing account',
        () async {
      final user = SdkUser('anonymous', isAnonymous: true)..conflict = true;
      sdk.currentUser = user;
      await expectLater(
          adapter.signIn(provider),
          throwsA(isA<CustomerAuthFailure>().having(
              (error) => error.existingAccount, 'explicit choice', true)));
      expect(sdk.currentUser?.uid, 'anonymous');
      expect(sdk.signIns, 0);
      await adapter.signIn(provider, useExistingAccount: true);
      expect(sdk.signIns, 1);
      expect(sdk.currentUser?.uid, 'new-customer');
    });
    test(
        '$id account link preserves existing verified UID without duplicate sign-in',
        () async {
      sdk.currentUser = SdkUser('verified-existing',
          provider: id == 'apple.com' ? 'google.com' : 'apple.com');
      await adapter.signIn(provider);
      expect(adapter.current?.uid, 'verified-existing');
      expect(sdk.signIns, 0);
      expect((sdk.currentUser as SdkUser).links, 1);
    });
    for (final code in [
      'web-context-cancelled',
      'invalid-credential',
      'user-mismatch'
    ]) {
      test(
          '$id reauthentication $code never switches identity or exposes provider detail',
          () async {
        final user = ReauthUser('buyer', provider: id)..reauthError = code;
        sdk.currentUser = user;
        Object? failure;
        try {
          await adapter.confirmIdentity();
        } catch (error) {
          failure = error;
        }
        expect(failure, isNotNull);
        expect(accountClosureError(failure!),
            isNot(contains('SDK_SECRET_DETAIL')));
        expect(sdk.currentUser?.uid, 'buyer');
        expect(sdk.signIns, 0);
      });
    }
  }
  for (final code in [
    'web-context-cancelled',
    'web-context-canceled',
    'user-cancelled',
    'invalid-credential',
    'missing-or-invalid-nonce',
    'network-request-failed'
  ]) {
    test(
        'Apple $code keeps current anonymous identity and exposes no SDK detail',
        () async {
      sdk.currentUser = FailingLinkUser(code);
      await expectLater(
          adapter.signIn(CustomerProvider.apple),
          throwsA(isA<CustomerAuthFailure>().having(
              (error) => error.message.contains('SDK INTERNAL'),
              'sanitized error',
              false)));
      expect(sdk.currentUser?.uid, 'anonymous');
      expect(sdk.currentUser?.isAnonymous, true);
      expect(sdk.signIns, 0);
    });
  }
  for (final code in [
    'user-disabled',
    'user-not-found',
    'user-token-expired',
    'invalid-user-token'
  ]) {
    test(
        '$code refresh clears full local identity and ends the unavailable session',
        () async {
      populate();
      sdk.currentUser = ReauthUser('buyer')..reloadError = code;
      await expectLater(adapter.refresh(), throwsA(isA<CustomerAuthFailure>()));
      expect(sdk.currentUser, isNull);
      cleared();
      expect(sdk.signOuts, 1);
    });
  }
  for (final stage in ['reload', 'token']) {
    test(
        'UID changed during $stage fails closed instead of accepting a silent identity swap',
        () async {
      final user = ReauthUser('old');
      sdk.currentUser = user;
      populate();
      Future<void> swap() async {
        sdk.currentUser = SdkUser('unexpected');
      }

      if (stage == 'reload') {
        user.afterReload = swap;
      } else {
        user.afterToken = swap;
      }
      await expectLater(adapter.refresh(), throwsA(isA<CustomerAuthFailure>()));
      expect(sdk.currentUser, isNull);
      cleared();
    });
  }
  test('logout clears all local personal fields without account deletion',
      () async {
    populate();
    sdk.currentUser = SdkUser('buyer');
    await adapter.signOut();
    cleared();
    expect(sdk.signOuts, 1);
    expect(sdk.currentUser, isNull);
    expect(CustomerLocalPrivacy.state.value, LocalClosureCleanup.idle);
  });
  test('auth debug logs omit UID, email and credential values', () async {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    try {
      sdk.currentUser = SdkUser('PRIVATE_UID', isAnonymous: true);
      await adapter.signIn(CustomerProvider.google);
    } finally {
      debugPrint = original;
    }
    expect(messages.join(), isNot(contains('PRIVATE_UID')));
    expect(messages.join(), isNot(contains('buyer@example.test')));
    expect(messages.join(), isNot(contains('TEST_ONLY_TOKEN')));
  });
  test('anonymous cannot confirm identity for customer deletion', () async {
    final user = ReauthUser('anonymous', isAnonymous: true);
    sdk.currentUser = user;
    await expectLater(
        adapter.confirmIdentity(), throwsA(isA<CustomerAuthFailure>()));
    expect(user.confirmations, 0);
    expect(sdk.currentUser?.uid, 'anonymous');
  });
  for (final provider in ['google.com', 'apple.com']) {
    test(
        '$provider completed deletion closes Firebase, purges cache in order and requires restart once',
        () async {
      sdk.currentUser = SdkUser('buyer', provider: provider);
      populate();
      final cache = CacheDouble();
      final account = FirebaseCustomerAccount(adapter, firestore: cache);
      await account.finishSession();
      await account.finishSession();
      expect(sdk.currentUser, isNull);
      expect(sdk.signOuts, 1);
      cleared();
      expect(cache.calls, ['terminate', 'clear']);
      expect(CustomerLocalPrivacy.state.value,
          LocalClosureCleanup.restartRequired);
    });
  }
  test(
      'cache failure never reports complete local cleanup; explicit retry finishes without restoring identity',
      () async {
    sdk.currentUser = SdkUser('buyer');
    final cache = CacheDouble()..fail = true;
    final account = FirebaseCustomerAccount(adapter, firestore: cache);
    await expectLater(account.finishSession(), throwsStateError);
    expect(CustomerLocalPrivacy.state.value, LocalClosureCleanup.failed);
    expect(sdk.currentUser, isNull);
    cache.fail = false;
    await CustomerLocalPrivacy.retry();
    expect(
        CustomerLocalPrivacy.state.value, LocalClosureCleanup.restartRequired);
    expect(cache.calls, ['terminate', 'clear', 'terminate', 'clear']);
  });
  test(
      'account changed before cleanup cannot sign out or clear another identity',
      () async {
    sdk.currentUser = SdkUser('first');
    final cache = CacheDouble();
    final account = FirebaseCustomerAccount(adapter, firestore: cache);
    sdk.currentUser = SdkUser('second');
    await expectLater(
        account.finishSession(), throwsA(isA<CustomerAuthFailure>()));
    expect(sdk.signOuts, 0);
    expect(cache.calls, isEmpty);
    expect(sdk.currentUser?.uid, 'second');
  });
  test(
      'closure parser distinguishes Apple dependency from active order without leaking provider errors',
      () {
    expect(
        accountClosureStatus(
            {'status': 'blocked', 'reason': 'APPLE_REVOCATION_NOT_CONFIGURED'}),
        AccountClosureStatus.providerPending);
    expect(
        accountClosureStatus({'status': 'blocked', 'reason': 'ACTIVE_ORDER'}),
        AccountClosureStatus.blocked);
    expect(
        accountClosureError(FirebaseAuthException(
            code: 'invalid-credential', message: 'SECRET_TOKEN')),
        isNot(contains('SECRET_TOKEN')));
  });
  testWidgets(
      'blocked Apple deletion is visibly pending, never completed or submitted again automatically',
      (tester) async {
    debugDefaultTargetPlatformOverride = null;
    final account = PendingAppleAccount();
    await tester.pumpWidget(
        MaterialApp(home: CustomerAccountClosureScreen(repository: account)));
    await tester.pumpAndSettle();
    expect(find.text('Revogação Apple pendente'), findsOneWidget);
    expect(find.text('Conta excluída'), findsNothing);
    expect(account.requests, 0);
    final button =
        find.widgetWithText(ElevatedButton, 'Confirmar identidade e excluir');
    await tester.scrollUntilVisible(button, 180);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), -160);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.scrollUntilVisible(button, 160);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(account.requests, 1);
    expect(find.text('Conta excluída'), findsNothing);
  });
  testWidgets(
      'account switch and logout discard every global personal field and private route',
      (tester) async {
    debugDefaultTargetPlatformOverride = null;
    final auth = FlowAuth(const CustomerIdentity(uid: 'first', name: 'First'));
    addTearDown(auth.events.close);
    await tester.pumpWidget(MaterialApp(
        home: CustomerSessionGate(
            auth: auth,
            onboarding: (_) => FlowOnboarding(accepted: true),
            workspace: (_) => FlowWorkspace(),
            destination: (_) => const Text('PRIVATE_DESTINATION'))));
    await tester.pumpAndSettle();
    populate();
    auth.change(const CustomerIdentity(uid: 'second', name: 'Second'));
    await tester.pumpAndSettle();
    expect(UserSession.fullName, 'Second');
    expect(UserSession.socialName, '');
    expect(UserSession.whatsapp, '');
    expect(UserSession.document, '');
    expect(UserSession.isRegistered, false);
    auth.change(null);
    await tester.pumpAndSettle();
    cleared();
    expect(find.text('PRIVATE_DESTINATION'), findsNothing);
    expect(find.text('Continuar com Google'), findsOneWidget);
  });
  testWidgets(
      'terminated cache keeps all login/private screens closed until app restart',
      (tester) async {
    debugDefaultTargetPlatformOverride = null;
    final auth = FlowAuth();
    addTearDown(auth.events.close);
    CustomerLocalPrivacy.state.value = LocalClosureCleanup.restartRequired;
    await tester.pumpWidget(MaterialApp(home: CustomerSessionGate(auth: auth)));
    await tester.pumpAndSettle();
    expect(find.text('Conta excluída'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsNothing);
    expect(find.textContaining('recarregue a página'), findsOneWidget);
  });
}
