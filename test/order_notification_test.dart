import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/order_notifications.dart';
import 'package:chamae_delivery/widgets/order_notification_card.dart';

class FakeNotifications implements OrderNotifications {
  int calls = 0;
  String? order;
  @override
  Future<OrderNotificationPermission> requestForOrder(String orderId) async {
    calls++;
    order = orderId;
    return OrderNotificationPermission.denied;
  }
}

void main() {
  testWidgets('permission is contextual and denial preserves tracking',
      (tester) async {
    final adapter = FakeNotifications();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderNotificationCard(
                orderId: 'order1', notifications: adapter))));
    expect(adapter.calls, 0);
    await tester.tap(find.text('Receber atualizações'));
    await tester.pumpAndSettle();
    expect(adapter.calls, 1);
    expect(adapter.order, 'order1');
    expect(find.textContaining('continuar acompanhando'), findsOneWidget);
  });
  testWidgets('unconfigured integration never pretends to grant permission',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: OrderNotificationCard(orderId: 'o1'))));
    await tester.tap(find.text('Receber atualizações'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ainda não estão disponíveis'), findsOneWidget);
  });
}
