import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Leituras de pedidos do cliente sempre limitadas à sessão Firebase atual.
/// O customerUid nunca é recebido de uma rota ou parâmetro externo.
class CustomerOrders {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  CustomerOrders({required this.auth, required this.firestore});

  Stream<Map<String, dynamic>?> watchFriendlyId(String id) => _watch('id', id);

  Stream<Map<String, dynamic>?> watchDocumentId(String id) =>
      _watch(FieldPath.documentId, id);

  Stream<Map<String, dynamic>?> _watch(Object field, String id) {
    late StreamController<Map<String, dynamic>?> controller;
    StreamSubscription<User?>? session;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? orders;
    var generation = 0;

    bool isCurrent(int version, String uid) =>
        !controller.isClosed &&
        version == generation &&
        auth.currentUser?.uid == uid;

    controller = StreamController<Map<String, dynamic>?>(
      onListen: () {
        session = auth.idTokenChanges().listen(
          (user) {
            final version = ++generation;
            orders?.cancel();
            orders = null;
            // Descarta dados da sessão anterior antes de consultar outra conta.
            controller.add(null);
            if (user == null ||
                user.uid.isEmpty ||
                id.isEmpty ||
                auth.currentUser?.uid != user.uid) {
              return;
            }
            final uid = user.uid;
            try {
              orders = firestore
                  .collection('orders')
                  .where('customerUid', isEqualTo: uid)
                  .where(field, isEqualTo: id)
                  .limit(1)
                  .snapshots()
                  .listen(
                    (snapshot) {
                      if (!isCurrent(version, uid)) return;
                      final data = snapshot.docs.isEmpty
                          ? null
                          : {...snapshot.docs.first.data(), '_documentId': snapshot.docs.first.id};
                      // Defesa adicional: não entregar dados de outro proprietário à UI.
                      controller.add(data?['customerUid'] == uid ? data : null);
                    },
                    onError: (Object error, StackTrace stack) {
                      if (!isCurrent(version, uid)) return;
                      controller.add(null);
                      controller.addError(error, stack);
                    },
                  );
            } catch (error, stack) {
              if (isCurrent(version, uid)) controller.addError(error, stack);
            }
          },
          onError: (Object error, StackTrace stack) {
            generation++;
            orders?.cancel();
            controller.add(null);
            controller.addError(error, stack);
          },
        );
      },
      onCancel: () async {
        generation++;
        await session?.cancel();
        await orders?.cancel();
      },
    );
    return controller.stream;
  }
}
