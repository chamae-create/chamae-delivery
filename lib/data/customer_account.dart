import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'customer_auth.dart';
import 'customer_local_privacy.dart';

enum AccountClosureStatus {
  ready,
  requested,
  processing,
  blocked,
  providerPending,
  completed
}

abstract class CustomerAccountRepository {
  Future<void> reauthenticate();
  Future<AccountClosureStatus> request();
  Stream<AccountClosureStatus> watch();
  Future<void> finishSession();
}

class FirebaseCustomerAccount implements CustomerAccountRepository {
  final FirebaseCustomerAuth auth;
  final String uid;
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  final String requestId =
      List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16))
          .join();
  FirebaseCustomerAccount(this.auth, {FirebaseFirestore? firestore})
      : uid = auth.current!.uid,
        _firestore = firestore;

  void _check() {
    if (auth.current?.uid != uid) {
      throw const CustomerAuthFailure(
          'Sua sessão mudou. Entre novamente para continuar.');
    }
  }

  @override
  Future<void> reauthenticate() async {
    _check();
    await auth.confirmIdentity().timeout(const Duration(seconds: 90));
    _check();
  }

  @override
  Future<AccountClosureStatus> request() async {
    _check();
    final result =
        await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
            .httpsCallable('chamaeSolicitarExclusaoConta')
            .call({
      'confirmation': 'EXCLUIR MINHA CONTA',
      'expectedUid': uid,
      'requestId': requestId,
    }).timeout(const Duration(seconds: 25));
    _check();
    return accountClosureStatus(result.data);
  }

  @override
  Stream<AccountClosureStatus> watch() => firestore
          .collection('customerAccountClosures')
          .doc(uid)
          .snapshots()
          .map((doc) {
        _check();
        return doc.exists
            ? accountClosureStatus(doc.data())
            : AccountClosureStatus.ready;
      });

  @override
  Future<void> finishSession() async {
    if (auth.current != null) _check();
    await CustomerLocalPrivacy.afterClosure(closeSession: () async {
      if (auth.current != null) _check();
      await auth.signOut();
      if (auth.current != null) throw StateError('SESSION_NOT_CLOSED');
    }, clearStore: () async {
      await firestore.terminate().timeout(const Duration(seconds: 15));
      await firestore.clearPersistence().timeout(const Duration(seconds: 15));
    });
  }
}

AccountClosureStatus accountClosureStatus(dynamic data) {
  final status = data is Map ? data['status'] : null;
  if (status == 'blocked' &&
      data['reason'] is String &&
      (data['reason'] as String).startsWith('APPLE_REVOCATION_')) {
    return AccountClosureStatus.providerPending;
  }
  return switch (status) {
    'requested' => AccountClosureStatus.requested,
    'processing' => AccountClosureStatus.processing,
    'blocked' => AccountClosureStatus.blocked,
    'completed' => AccountClosureStatus.completed,
    _ => throw StateError('Não foi possível conferir a exclusão agora.'),
  };
}

String accountClosureError(Object error) {
  if (error is CustomerAuthFailure) return error.message;
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    if (details is Map && details['reason'] == 'ACTIVE_ORDER') {
      return 'Há um pedido ou pagamento em andamento. Aguarde a conclusão ou fale com a loja antes de excluir a conta.';
    }
    if (error.code == 'unauthenticated') {
      return 'Confirme sua identidade novamente para continuar.';
    }
  }
  return 'Não foi possível concluir agora. Confira a conexão e verifique o status antes de tentar novamente.';
}
