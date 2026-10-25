import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_bootstrap.dart';
import '../core/order_confirmation_policy.dart';

abstract class CustomerWorkspace {
  Future<Map<String, dynamic>> read();
  Future<void> save(Map<String, dynamic> fields);
  Future<bool> completeOrder(String documentId);
}

/// Removes only purchased quantities; later additions remain in the cart.
List<Map<String, dynamic>> remainingCart(List cart, List purchased) {
  final consumed = <String, int>{};
  for (final raw in purchased.whereType<Map>()) {
    final id = raw['id'] as String;
    consumed[id] = (consumed[id] ?? 0) + (raw['quantity'] as num).toInt();
  }
  return cart
      .whereType<Map>()
      .map((raw) {
        final item = Map<String, dynamic>.from(raw);
        item['quantity'] =
            (item['quantity'] as num).toInt() - (consumed[item['id']] ?? 0);
        return item;
      })
      .where((item) => (item['quantity'] as int) > 0)
      .toList();
}

class FirebaseCustomerWorkspace implements CustomerWorkspace {
  final String uid;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  FirebaseCustomerWorkspace({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        uid = (auth ?? FirebaseAuth.instance).currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _ref =>
      firestore.collection('customerWorkspaces').doc(uid);
  void _check() {
    if (auth.currentUser?.uid != uid) {
      throw StateError('Sua sessão mudou. Abra o aplicativo novamente.');
    }
  }

  @override
  Future<Map<String, dynamic>> read() async {
    _check();
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      final data = await initializeCustomerDocument(
              _ref, uid, {'addresses': [], 'cart': []})
          .timeout(const Duration(seconds: 8));
      _check();
      return data;
    } on TimeoutException {
      doc = await _ref.get(const GetOptions(source: Source.cache));
    }
    _check();
    return doc.data() ?? {};
  }

  @override
  Future<void> save(Map<String, dynamic> fields) async {
    _check();
    await _ref
        .set(fields, SetOptions(merge: true))
        .timeout(const Duration(seconds: 8));
    _check();
  }

  @override
  Future<bool> completeOrder(String documentId) async {
    _check();
    return firestore.runTransaction((tx) async {
      _check();
      final workspace = await tx.get(_ref);
      final data = workspace.data() ?? {};
      final pending = data['pending'];
      if (pending is! Map || pending['documentId'] != documentId) return false;
      final order =
          await tx.get(firestore.collection('orders').doc(documentId));
      if (!order.exists || order.data()?['customerUid'] != uid) return false;
      final payload = order.data()!;
      if (!orderIsConfirmed(payload) || order.metadata.hasPendingWrites) {
        return false;
      }
      _check();
      tx.set(
          _ref,
          {
            'pending': null,
            'cart': remainingCart(data['cart'] as List? ?? [],
                payload['itemsList'] as List? ?? [])
          },
          SetOptions(merge: true));
      return true;
    }).timeout(const Duration(seconds: 15));
  }
}
