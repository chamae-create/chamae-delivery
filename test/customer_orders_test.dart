// Doubles isolam o SDK sem inicializar Firebase ou acessar produção.
// O SDK não fornece construtores públicos para snapshots e queries.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/customer_orders.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'package:chamae_delivery/screens/motoboy_screen.dart';

class TestUser extends Fake implements User {
  @override
  final String uid;
  TestUser(this.uid);
}

class TestAuth extends Fake implements FirebaseAuth {
  @override
  User? currentUser;
  final changes = StreamController<User?>.broadcast(sync: true);

  void change(String? uid) {
    currentUser = uid == null ? null : TestUser(uid);
    changes.add(currentUser);
  }

  @override
  Stream<User?> idTokenChanges() => Stream.multi((controller) {
        controller.add(currentUser);
        final sub = changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
        controller.onCancel = sub.cancel;
      });
}

class TestDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> value;
  TestDoc(this.id, this.value);
  @override
  Map<String, dynamic> data() => value;
}

class TestSnapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  TestSnapshot(this.docs);
  @override
  SnapshotMetadata get metadata => TestMetadata();
}

class TestMetadata extends Fake implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
}

class TestStore extends Fake implements FirebaseFirestore {
  final documents = <TestDoc>[];
  final queries = <Map<Object, dynamic>>[];
  final updates = StreamController<void>.broadcast(sync: true);
  bool ignoreFilters = false;
  Object? failure;
  int active = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'orders');
    return TestQuery(this, {});
  }
}

class TestQuery extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final TestStore store;
  final Map<Object, dynamic> filters;
  TestQuery(this.store, this.filters);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      return TestQuery(store, {
        ...filters,
        invocation.positionalArguments.first:
            invocation.namedArguments[#isEqualTo],
      });
    }
    if (invocation.memberName == #limit) {
      expect(invocation.positionalArguments.single, 1);
      return this;
    }
    if (invocation.memberName == #snapshots) {
      store.queries.add(filters);
      return Stream<QuerySnapshot<Map<String, dynamic>>>.multi((controller) {
        store.active++;
        void emit() {
          if (store.failure != null) {
            controller.addError(store.failure!);
            return;
          }
          controller.add(
            TestSnapshot(
              store.documents
                  .where(
                    (doc) =>
                        store.ignoreFilters ||
                        filters.entries.every(
                          (entry) =>
                              (entry.key == FieldPath.documentId
                                  ? doc.id
                                  : doc.value[entry.key]) ==
                              entry.value,
                        ),
                  )
                  .take(1)
                  .toList(),
            ),
          );
        }

        emit();
        final sub = store.updates.stream.listen((_) => emit());
        controller.onCancel = () async {
          store.active--;
          await sub.cancel();
        };
      });
    }
    return super.noSuchMethod(invocation);
  }
}

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late TestAuth auth;
  late TestStore store;
  late CustomerOrders orders;
  late List<Map<String, dynamic>?> events;
  late List<Object> errors;
  StreamSubscription<Map<String, dynamic>?>? sub;

  setUp(() {
    auth = TestAuth()..change('alice');
    store = TestStore();
    store.documents.addAll([
      TestDoc('alice-doc', {
        'id': '#CH-1',
        'customerUid': 'alice',
        'status': 'Em Separação',
        'totalBRL': 20.0,
        'address': 'Rua própria',
        'courierName': 'Entregador',
        'paymentStatus': 'Pago',
        'mercadoPagoQrCode': 'pix-do-proprio-pedido',
      }),
      TestDoc('bob-doc', {
        'id': '#CH-2',
        'customerUid': 'bob',
        'address': 'Endereço privado',
      }),
    ]);
    orders = CustomerOrders(auth: auth, firestore: store);
    events = [];
    errors = [];
  });

  tearDown(() async {
    await sub?.cancel();
    sub = null;
    await auth.changes.close();
    await store.updates.close();
  });

  void watch(Stream<Map<String, dynamic>?> stream) {
    sub = stream.listen(events.add, onError: errors.add);
  }

  test('sem sessão não consulta pedidos', () async {
    auth.change(null);
    watch(orders.watchFriendlyId('#CH-1'));
    await settle();
    expect(store.queries, isEmpty);
    expect(events.last, isNull);
  });

  test('pedido próprio combina ID amigável com UID autenticado', () async {
    watch(orders.watchFriendlyId('#CH-1'));
    await settle();
    expect(store.queries.single, {'customerUid': 'alice', 'id': '#CH-1'});
    expect(events.last?['address'], 'Rua própria');
  });

  test('alterar ID não inicia consulta com UID de outro cliente', () async {
    watch(orders.watchFriendlyId('#CH-2'));
    await settle();
    expect(store.queries.single, {'customerUid': 'alice', 'id': '#CH-2'});
    expect(events.whereType<Map<String, dynamic>>(), isEmpty);
  });

  test(
    'resposta com proprietário inesperado nunca chega à interface',
    () async {
      store.documents.removeAt(0);
      store.ignoreFilters = true;
      watch(orders.watchFriendlyId('#CH-2'));
      await settle();
      expect(events.last, isNull);
    },
  );

  test(
    'leitura por documentId do checkout mantém payload do pedido próprio',
    () async {
      watch(orders.watchDocumentId('alice-doc'));
      await settle();
      expect(store.queries.single['customerUid'], 'alice');
      expect(store.queries.single[FieldPath.documentId], 'alice-doc');
      expect(events.last?['_documentId'], 'alice-doc');
      expect(events.last?['paymentStatus'], 'Pago');
      expect(events.last?['mercadoPagoQrCode'], 'pix-do-proprio-pedido');
    },
  );

  test(
    'documentId de outro cliente também fica limitado ao UID da sessão',
    () async {
      watch(orders.watchDocumentId('bob-doc'));
      await settle();
      expect(store.queries.single['customerUid'], 'alice');
      expect(events.whereType<Map<String, dynamic>>(), isEmpty);
    },
  );

  test('logout cancela pedidos e limpa dados já recebidos', () async {
    watch(orders.watchFriendlyId('#CH-1'));
    await settle();
    auth.change(null);
    await settle();
    expect(store.active, 0);
    expect(events.last, isNull);
    store.updates.add(null);
    await settle();
    expect(events.last, isNull);
    expect(store.queries, hasLength(1));
  });

  test(
    'trocar conta cancela assinatura anterior e consulta somente novo UID',
    () async {
      watch(orders.watchFriendlyId('#CH-1'));
      await settle();
      auth.change('bob');
      await settle();
      expect(store.active, 1);
      expect(store.queries.last['customerUid'], 'bob');
      expect(events.last, isNull);
    },
  );

  test('erro de sessão cancela acesso aos dados', () async {
    watch(orders.watchFriendlyId('#CH-1'));
    await settle();
    auth.changes.addError(StateError('token inválido'));
    await settle();
    expect(store.active, 0);
    expect(events.last, isNull);
    expect(errors, hasLength(1));
  });

  test('erro do Firestore não fornece dados', () async {
    store.failure = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    watch(orders.watchFriendlyId('#CH-1'));
    await settle();
    expect(events.last, isNull);
    expect(errors, hasLength(1));
  });

  test('ID vazio não inicia consulta', () async {
    watch(orders.watchFriendlyId(''));
    await settle();
    expect(store.queries, isEmpty);
  });

  testWidgets('tracking exibe pedido próprio e limpa a tela no logout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingView(
          orderId: '#CH-1',
          orderStream: orders.watchFriendlyId('#CH-1'),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('STATUS DO PEDIDO'), findsOneWidget);
    expect(find.text('Destino: Rua própria'), findsOneWidget);
    expect(find.text('Total: R\$ 20,00'), findsOneWidget);
    auth.change(null);
    await tester.pumpAndSettle();
    expect(find.text('STATUS DO PEDIDO'), findsNothing);
    expect(find.text('Pedido indisponível para esta sessão.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tracking de outro cliente não mostra dados privados', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingView(
          orderId: '#CH-2',
          orderStream: orders.watchFriendlyId('#CH-2'),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Endereço privado'), findsNothing);
    expect(find.text('Pedido indisponível para esta sessão.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'motoboy desativado abre sem Firebase, consultas ou ações de entrega',
    (tester) async {
      // Sem Firebase.initializeApp: uma consulta real faria este teste falhar.
      await tester.pumpWidget(const MaterialApp(home: MotoboyAppScreen()));
      await tester.pumpAndSettle();
      expect(
        find.text('Acesso de entregadores indisponível neste aplicativo.'),
        findsOneWidget,
      );
      expect(find.text('Retirar'), findsNothing);
      expect(find.text('Concluir'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
