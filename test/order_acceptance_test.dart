// SDK doubles never initialize Firebase or make network calls.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/order_confirmation_policy.dart';
import 'package:chamae_delivery/data/customer_workspace.dart';
import 'package:chamae_delivery/data/customer_account.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/widgets/pix_payment_dialog.dart';

Map<String, dynamic> accepted({bool pix = false}) => {
      'customerUid': 'buyer',
      'status': 'Novo',
      'financialValidationStatus': 'validated',
      'paymentMethod': pix ? 'PIX' : 'Dinheiro',
      'pixRequested': pix,
      'paymentStatus': pix ? 'Pago' : 'Pendente na entrega',
      'stockReservationStatus': 'reserved',
      'itemsList': [
        {'id': 'p1', 'quantity': 2}
      ],
    };

class UserDouble extends Fake implements User {
  @override
  String get uid => 'buyer';
  @override
  bool get isAnonymous => false;
  @override
  String? get displayName => null;
  @override
  String? get email => null;
  @override
  List<UserInfo> get providerData => [];
}

class AuthDouble extends Fake implements FirebaseAuth {
  @override
  User? currentUser = UserDouble();
}

class MetadataDouble extends Fake implements SnapshotMetadata {
  final bool pending;
  MetadataDouble(this.pending);
  @override
  bool get hasPendingWrites => pending;
}

class DocDouble extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? value;
  final bool pending;
  DocDouble(this.value, [this.pending = false]);
  @override
  Map<String, dynamic>? data() => value;
  @override
  bool get exists => value != null;
  @override
  SnapshotMetadata get metadata => MetadataDouble(pending);
}

class RefDouble extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  @override
  final String path;
  RefDouble(this.path);
  @override
  String get id => path.split('/').last;
}

class CollectionDouble extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  @override
  final String path;
  CollectionDouble(this.path);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      RefDouble('$path/$id');
}

class StoreDouble extends Fake implements FirebaseFirestore {
  Map<String, dynamic> order = accepted();
  Map<String, dynamic> workspace = {
    'pending': {'documentId': 'order'},
    'cart': [
      {'id': 'p1', 'quantity': 5},
      {'id': 'new', 'quantity': 1}
    ]
  };
  int writes = 0;
  bool pending = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      CollectionDouble(path);
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
          {Duration timeout = const Duration(seconds: 30),
          int maxAttempts = 5}) =>
      handler(TxDouble(this));
}

class TxDouble extends Fake implements Transaction {
  final StoreDouble store;
  TxDouble(this.store);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
          DocumentReference<T> ref) async =>
      DocDouble(ref.path.startsWith('orders/') ? store.order : store.workspace,
          store.pending) as DocumentSnapshot<T>;
  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    store.writes++;
    store.workspace.addAll(data as Map<String, dynamic>);
    return this;
  }
}

void main() {
  test('account repository binds UID and refuses all actions after session change', () async {
    final auth = AuthDouble();
    final repo = FirebaseCustomerAccount(FirebaseCustomerAuth(auth: auth));
    expect(repo.requestId, matches(RegExp(r'^[a-f0-9]{24}$')));
    expect(repo.uid, 'buyer');
    auth.currentUser = null;
    await expectLater(repo.reauthenticate(), throwsA(isA<CustomerAuthFailure>()));
    await expectLater(repo.request(), throwsA(isA<CustomerAuthFailure>()));
  });
  test(
      'cash and PIX consume purchased quantities once, only after backend acceptance',
      () async {
    for (final pix in [false, true]) {
      final db = StoreDouble()..order = accepted(pix: pix);
      final auth = AuthDouble();
      final workspace = FirebaseCustomerWorkspace(auth: auth, firestore: db);
      for (final patch in [
        {'financialValidationStatus': 'pending'},
        {'financialValidationStatus': 'rejected'},
        {'status': 'Cancelado'},
        {'status': 'Revisão de estoque'},
        {'stockReservationStatus': 'requires_review'},
        {'stockProcessingStatus': 'error'},
        {'customerUid': 'other'},
        if (pix) {'paymentStatus': 'Pendente'},
      ]) {
        db.order = {...accepted(pix: pix), ...patch};
        expect(await workspace.completeOrder('order'), false, reason: '$patch');
        expect(db.writes, 0);
        expect(db.workspace['pending'], isNotNull);
      }
      db.order = accepted(pix: pix);
      db.pending = true;
      expect(await workspace.completeOrder('order'), false);
      db.pending = false;
      expect(await workspace.completeOrder('order'), true);
      expect(db.workspace['cart'], [
        {'id': 'p1', 'quantity': 3},
        {'id': 'new', 'quantity': 1}
      ]);
      expect(await workspace.completeOrder('order'), false);
      expect(db.writes, 1);
      auth.currentUser = null;
      await expectLater(workspace.completeOrder('order'), throwsStateError);
    }
  });

  test('local proposal, pending writes and unsettled PIX are never confirmed',
      () {
    for (final patch in [
      {'_hasPendingWrites': true},
      {'financialValidationStatus': 'pending'},
      {'status': 'Aguardando pagamento'},
      {'stockProcessingStatus': 'processing'},
      {'paymentMethod': 'PIX', 'paymentStatus': 'Pendente'}
    ]) {
      expect(orderIsConfirmed({...accepted(), ...patch}), false);
    }
    expect(orderIsConfirmed(accepted()), true);
    expect(orderIsConfirmed(accepted(pix: true)), true);
  });

  for (final interrupt in [false, true]) {
    testWidgets(
        'PIX callback requires official paid acceptance; session interruption $interrupt',
        (tester) async {
      final updates = StreamController<Map<String, dynamic>?>.broadcast();
      addTearDown(updates.close);
      var callbacks = 0;
      String? uid = 'buyer';
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => PixPaymentDialog(
                                orderReference: RefDouble('orders/order'),
                                orderId: '#TEST',
                                totalBRL: 12.34,
                                orderStream: updates.stream,
                                currentUid: () => uid,
                                onPaid: () async {
                                  callbacks++;
                                },
                              )),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (final patch in [
        {'financialValidationStatus': 'pending'},
        {'_hasPendingWrites': true},
        {'status': 'Cancelado'},
        {'stockProcessingStatus': 'error'},
        {'paymentStatus': 'Pendente'},
      ]) {
        updates.add({...accepted(pix: true), ...patch});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1300));
        expect(callbacks, 0);
      }
      updates.add(accepted(pix: true));
      await tester.pump();
      if (interrupt) {
        uid = null;
        updates.add(null);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 1300));
      if (!interrupt) await tester.pumpAndSettle();
      expect(callbacks, interrupt ? 0 : 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
