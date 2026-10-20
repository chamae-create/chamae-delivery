@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';

void main() {
  testWidgets('checkout preserva carrinho, total e entrada no pagamento PIX',
      (tester) async {
    // Smoke funcional com a largura padrão de testes (Ahem é monoespaçada).
    // O layout real do app não é alterado por esta configuração de teste.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var cartCleared = false;
    final cart = [
      CartItem(
          id: 'produto',
          name: 'Produto de teste',
          price: 20,
          quantity: 2,
          imageUrl: '')
    ];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: CheckoutScreen(
          cartItems: cart,
          onCartCleared: () => cartCleared = true,
          deliveryAddress: const DeliveryAddress(
              latitude: -22.53,
              longitude: -55.72,
              addressText: 'Endereço de teste'),
        )));
    await tester.pumpAndSettle();
    expect(find.text('Finalizar Pedido'), findsOneWidget);
    final button = find.text('Finalizar pedido');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);
    // 2 x R$20 + entrega R$10 + taxa de cliente de 1% = R$50,40.
    expect(find.textContaining('50,40'), findsWidgets);
    expect(cart.single.quantity, 2);
    expect(cartCleared, isFalse);
    expect(tester.takeException(), isNull);
  });
}
