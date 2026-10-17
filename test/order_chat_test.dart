import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/order_chat.dart';

class ChatFake extends OrderChatGateway {
  final sent = <String>[];
  @override
  Stream<List<Map<String, dynamic>>> watch(String id) => Stream.value([]);
  @override
  Future<void> read(String id) async {}
  @override
  Future<void> send(String id, String text, String requestId) async { sent.add('$id:$text'); }
}
void main() {
  test('session change clears history and never reopens old chat for another UID', () async {
    var uid = 'first';
    final sessions = StreamController<String?>();
    final first = StreamController<String>(sync: true), second = StreamController<String>.broadcast();
    final values = <String>[];
    final subscription = chatSessionStream(sessions.stream, () => uid, '',
      () => uid == 'first' ? first.stream : second.stream).listen(values.add);
    sessions.add('first'); await Future<void>.delayed(Duration.zero);
    first.add('private-first'); await Future<void>.delayed(Duration.zero);
    first.add('queued-private-first');
    uid = 'second'; sessions.add('second');
    await Future<void>.delayed(Duration.zero);
    first.add('stale-private'); second.add('private-second');
    await Future<void>.delayed(Duration.zero);
    sessions.add(null); await Future<void>.delayed(Duration.zero);
    expect(values, ['', 'private-first', '', '']);
    await subscription.cancel(); await sessions.close(); await first.close(); await second.close();
  });
  test('restricted administrative roles cannot replay cached chat history', () {
    for (final role in ['finance', 'catalog_admin']) {
      expect(chatRolesPermitRead([role], anonymous: false), false);
      expect(chatRolesPermitRead([role, 'operations_admin'], anonymous: false), true);
      expect(chatRolesPermitRead([role, 'superadmin'], anonymous: false), true);
      expect(chatRolesPermitRead([role, 'operations_admin'], anonymous: true), false);
    }
    expect(chatRolesPermitRead([], anonymous: true), true);
  });
  test('24 hour closure boundary and cancellation', () {
    final now = DateTime(2026, 10, 16, 12);
    expect(chatIsClosed({'status': 'Novo'}, now), false);
    expect(chatIsClosed({'status': 'Cancelado'}, now), true);
    expect(chatIsClosed({'status': 'Concluído', 'completedAt': now.subtract(const Duration(hours: 24))}, now), true);
    expect(chatIsClosed({'status': 'Concluído', 'completedAt': now.subtract(const Duration(hours: 23))}, now), false);
  });
  testWidgets('customer sends only text for the specified order', (tester) async {
    final gateway = ChatFake();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OrderChat(orderId: 'real-order', order: const {'status': 'Novo'}, gateway: gateway))));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Pode confirmar?');
    await tester.tap(find.text('Enviar')); await tester.pump();
    expect(gateway.sent, ['real-order:Pode confirmar?']);
    expect(find.text('Resposta rápida'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('closed chat preserves history and has no composer', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OrderChat(orderId: 'closed', order: const {'status': 'Concluído'}, gateway: ChatFake()))));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Conversa encerrada. Histórico preservado.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
