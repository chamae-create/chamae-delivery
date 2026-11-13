import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'checkout_delivery_contract_test.dart' as fixture;

class LaunchQuoter implements DeliveryQuoter {
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DeliveryQuote(7.25, 'a' * 64, 'routeBands',
        distanceMeters: 1000,
        version: 'local-test-v1',
        routingProvider: 'local-test',
        quotedAtMs: now,
        expiresAtMs: now + 300000);
  }
}

void main() {
  testWidgets('launch V1.0 shows zero customer fee and unchanged freight',
      (tester) async {
    await tester.pumpWidget(fixture.checkout(
      fixture.Verification(true),
      LaunchQuoter(),
      CartItem(id: 'p1', name: 'Produto', price: 20, imageUrl: '', quantity: 2),
    ));
    await tester.pumpAndSettle();
    expect(find.text('+ R\$ 0,00'), findsOneWidget);
    expect(find.text('R\$ 7,25'), findsOneWidget);
    expect(find.text('R\$ 47,25'), findsOneWidget);
    expect(find.text('R\$ 47,65'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
