import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/widgets/order_confirmation.dart';

void main() {
  testWidgets(
      'customer confirmation uses official V8 and keeps technical identity separate',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OrderConfirmationView(
                orderId: 'technical-document-id',
                statusLabel: 'Em separação',
                data: const {'id': 'legacy-id', 'displayOrderId': 'V8-10000'},
                onTrack: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Agora é com a Pit Stop V8.\nPedido V8-10000'),
        findsOneWidget);
    expect(find.textContaining('technical-document-id'), findsNothing);
  });
}
