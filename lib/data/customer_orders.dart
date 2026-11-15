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

  static const Set<String> _terminalStatuses = {
    'concluído',
    'concluido',
    'entregue',
    'cancelado',
    'cancelada',
  };

  /// Watches active (non-terminal) orders owned by the signed-in customer.
  Stream<List<Map<String, dynamic>>> watchActiveOrders() {
    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription<User?>? session;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? orders;
    var generation = 0;

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        session = auth.idTokenChanges().listen(
          (user) {
            final version = ++generation;
            orders?.cancel();
            orders = null;
            if (user == null ||
                user.uid.isEmpty ||
                user.isAnonymous ||
                auth.currentUser?.uid != user.uid) {
              controller.add(const []);
              return;
            }
            final uid = user.uid;
            orders = firestore
                .collection('orders')
                .where('customerUid', isEqualTo: uid)
                .snapshots()
                .listen(
              (snapshot) {
                if (controller.isClosed ||
                    version != generation ||
                    auth.currentUser?.uid != uid) {
                  return;
                }
                final active = <Map<String, dynamic>>[];
                for (final doc in snapshot.docs) {
                  final data = doc.data();
                  if (data['customerUid'] != uid) continue;
                  final status =
                      (data['status'] ?? 'Novo').toString().trim().toLowerCase();
                  if (_terminalStatuses.contains(status)) continue;
                  active.add({...data, '_documentId': doc.id});
                }
                active.sort((a, b) {
                  final ta = a['createdAt'];
                  final tb = b['createdAt'];
                  final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
                  final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
                  return mb.compareTo(ma);
                });
                controller.add(active);
              },
              onError: (Object error, StackTrace stack) {
                if (!controller.isClosed && version == generation) {
                  controller.add(const []);
                }
              },
            );
          },
          onError: (_, __) {
            if (!controller.isClosed) controller.add(const []);
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
                  .snapshots(includeMetadataChanges: true)
                  .listen(
                (snapshot) {
                  if (!isCurrent(version, uid)) return;
                  final data = snapshot.docs.isEmpty
                      ? null
                      : {
                          ...snapshot.docs.first.data(),
                          '_documentId': snapshot.docs.first.id,
                          '_hasPendingWrites':
                              snapshot.metadata.hasPendingWrites
                        };
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
