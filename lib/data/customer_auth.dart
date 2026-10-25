import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/models.dart';

enum CustomerProvider { google, apple }

class CustomerIdentity {
  final String uid, name, email;
  final List<String> providers;
  final bool anonymous;
  const CustomerIdentity(
      {required this.uid,
      this.name = '',
      this.email = '',
      this.providers = const [],
      this.anonymous = false});
}

class CustomerAuthFailure implements Exception {
  final String message;
  final bool existingAccount;
  const CustomerAuthFailure(this.message, {this.existingAccount = false});
}

abstract class CustomerAuth {
  Stream<CustomerIdentity?> get changes;
  CustomerIdentity? get current;
  Future<void> signIn(CustomerProvider provider,
      {bool useExistingAccount = false});
  Future<void> signOut();
  Future<void> refresh();
}

class FirebaseCustomerAuth implements CustomerAuth {
  final FirebaseAuth auth;
  final Future<AuthCredential> Function()? googleCredential;
  FirebaseCustomerAuth({FirebaseAuth? auth, this.googleCredential})
      : auth = auth ?? FirebaseAuth.instance;
  static Future<void>? _googleInitialization;
  CustomerIdentity? _identity(User? user) => user == null
      ? null
      : CustomerIdentity(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          anonymous: user.isAnonymous,
          providers: user.providerData.map((p) => p.providerId).toList());
  @override
  CustomerIdentity? get current => _identity(auth.currentUser);
  @override
  Stream<CustomerIdentity?> get changes => auth.idTokenChanges().map(_identity);

  @override
  Future<void> signIn(CustomerProvider kind,
      {bool useExistingAccount = false}) async {
    final old = auth.currentUser;
    try {
      final link = old != null && !useExistingAccount;
      if (kDebugMode) {
        debugPrint('[customer-auth] provider=${kind.name} link=$link');
      }
      final AuthProvider provider;
      if (kind == CustomerProvider.google) {
        provider = GoogleAuthProvider()..addScope('email');
      } else {
        provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
      }
      final UserCredential result;
      if (kIsWeb) {
        if (link) {
          result = await old.linkWithPopup(provider);
        } else {
          result = await auth.signInWithPopup(provider);
        }
      } else if (kind == CustomerProvider.apple) {
        if (link) {
          result = await old.linkWithProvider(provider);
        } else {
          result = await auth.signInWithProvider(provider);
        }
      } else {
        if (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) {
          throw const CustomerAuthFailure(
              'Use o app para Android, iPhone ou a versão Web para entrar.');
        }
        final credential = await _nativeGoogleCredential();
        if (link) {
          result = await old.linkWithCredential(credential);
        } else {
          result = await auth.signInWithCredential(credential);
        }
      }
      final expectedUid = link ? old.uid : result.user?.uid;
      if (expectedUid == null || result.user?.uid != expectedUid) {
        await signOut();
        throw const CustomerAuthFailure('Sua sessão mudou. Entre novamente.');
      }
      await _checkUid(expectedUid);
      await auth.currentUser!.reload();
      await _checkUid(expectedUid);
      await auth.currentUser!.getIdToken(true);
      await _checkUid(expectedUid);
    } on FirebaseAuthException catch (e) {
      if ([
        'credential-already-in-use',
        'account-exists-with-different-credential',
        'email-already-in-use'
      ].contains(e.code)) {
        throw const CustomerAuthFailure(
            'Esta identidade já está vinculada a uma conta. Você pode entrar nela para recuperar os dados dessa conta. Os dados da sessão atual não serão mesclados automaticamente.',
            existingAccount: true);
      }
      if (e.code == 'provider-already-linked' && old != null) {
        await _checkUid(old.uid);
        await refresh();
        await _checkUid(old.uid);
        return;
      }
      if ([
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-cancelled',
        'web-context-canceled',
        'user-cancelled'
      ].contains(e.code)) {
        throw const CustomerAuthFailure(
            'Entrada cancelada. Você pode tentar novamente quando quiser.');
      }
      if ([
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token'
      ].contains(e.code)) {
        await signOut();
        throw const CustomerAuthFailure(
            'Sua sessão não está disponível. Entre novamente.');
      }
      if (e.code == 'operation-not-allowed' ||
          e.code == 'unauthorized-domain') {
        throw const CustomerAuthFailure(
            'Esta forma de entrada ainda não está disponível. Tente novamente mais tarde.');
      }
      throw const CustomerAuthFailure(
          'Não foi possível entrar agora. Confira sua conexão e tente novamente.');
    } on GoogleSignInException catch (e) {
      throw CustomerAuthFailure(e.code == GoogleSignInExceptionCode.canceled
          ? 'Entrada cancelada. Você pode tentar novamente.'
          : 'Não foi possível entrar com Google agora. Tente novamente mais tarde.');
    }
  }

  Future<void> _checkUid(String expected) async {
    if (auth.currentUser?.uid == expected) return;
    await signOut();
    throw const CustomerAuthFailure('Sua sessão mudou. Entre novamente.');
  }

  Future<AuthCredential> _nativeGoogleCredential() async {
    if (googleCredential != null) return googleCredential!();
    _googleInitialization ??= GoogleSignIn.instance.initialize(
        clientId: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID').isEmpty
            ? null
            : const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
        serverClientId:
            const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID').isEmpty
                ? null
                : const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'));
    await _googleInitialization;
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null) {
      throw const CustomerAuthFailure(
          'Não foi possível confirmar sua conta Google. Tente novamente.');
    }
    return GoogleAuthProvider.credential(idToken: token);
  }

  Future<void> confirmIdentity() async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const CustomerAuthFailure(
          'Entre novamente para confirmar sua identidade.');
    }
    final token = await user.getIdTokenResult();
    await _checkUid(user.uid);
    final firebase = token.claims?['firebase'];
    final apple =
        firebase is Map && firebase['sign_in_provider'] == 'apple.com';
    final AuthProvider provider =
        apple ? AppleAuthProvider() : GoogleAuthProvider();
    if (kIsWeb) {
      await user.reauthenticateWithPopup(provider);
    } else if (apple) {
      await user.reauthenticateWithProvider(provider);
    } else {
      await user.reauthenticateWithCredential(await _nativeGoogleCredential());
    }
    await _checkUid(user.uid);
    await user.getIdToken(true);
    await _checkUid(user.uid);
  }

  @override
  Future<void> refresh() async {
    final user = auth.currentUser;
    try {
      if (user == null) return;
      await user.reload().timeout(const Duration(seconds: 12));
      await _checkUid(user.uid);
      await user.getIdToken(true).timeout(const Duration(seconds: 12));
      await _checkUid(user.uid);
    } on FirebaseAuthException catch (e) {
      if ([
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token'
      ].contains(e.code)) {
        await signOut();
        throw const CustomerAuthFailure(
            'Sua sessão expirou. Entre novamente para continuar.');
      }
      throw const CustomerAuthFailure(
          'Não foi possível conferir sua sessão. Verifique a conexão e tente novamente.');
    }
  }

  @override
  Future<void> signOut() async {
    await auth.signOut();
    UserSession.clearPersonalData();
    if (!kIsWeb && _googleInitialization != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {/* Firebase session already closed. */}
    }
  }
}
