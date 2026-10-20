import 'package:firebase_auth/firebase_auth.dart';

abstract class AccountVerification {
  Future<bool> isVerified();
  Future<void> startVerification();
}

/// Firebase-verified Google/Apple identity is distinct from age/identity proof.
/// Existing trusted customerVerified claims remain compatible.
class ConfiguredAccountVerification implements AccountVerification {
  @override
  Future<bool> isVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
    final token =
        await user.getIdTokenResult(true).timeout(const Duration(seconds: 15));
    final firebase = token.claims?['firebase'];
    final provider = firebase is Map ? firebase['sign_in_provider'] : null;
    return FirebaseAuth.instance.currentUser?.uid == user.uid &&
        (token.claims?['customerVerified'] == true ||
            ['google.com', 'apple.com'].contains(provider));
  }

  @override
  Future<void> startVerification() async {
    if (await isVerified()) return;
    throw StateError(
        'Entre com Google ou Apple pela tela inicial para continuar.');
  }
}
