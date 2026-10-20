import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/customer_verification.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';

class Verification implements AccountVerification {
  bool verified;
  int starts = 0;
  Verification(this.verified);
  @override
  Future<bool> isVerified() async => verified;
  @override
  Future<void> startVerification() async {
    starts++;
    verified = true;
  }
}

class Quoter implements DeliveryQuoter {
  int calls = 0;
  bool fail = false;
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) async {
    calls++;
    if (fail) {
      throw const DeliveryQuoteException(
          'Este endereço está fora da área de entrega.');
    }
    return const DeliveryQuote(7.25, 'test-quote', 'routeBands');
  }
}

Widget checkout(Verification verification, Quoter quoter, CartItem item,
        {bool confirmed = true}) =>
    MaterialApp(
        home: CheckoutScreen(
            cartItems: [item],
            onCartCleared: () {},
            quoter: quoter,
            verification: verification,
            deliveryAddress: DeliveryAddress(
                latitude: -20,
                longitude: -50,
                street: 'Rua',
                number: '1',
                city: 'Cidade',
                countryCode: 'BR',
                confirmed: confirmed)));

void main() {
  CartItem item() =>
      CartItem(id: 'p1', name: 'Produto', price: 20, imageUrl: '', quantity: 2);

  testWidgets('verified returning account does not repeat verification',
      (tester) async {
    final verification = Verification(true);
    await tester.pumpWidget(checkout(verification, Quoter(), item()));
    await tester.pumpAndSettle();
    expect(find.text('Atualizar sessão'), findsNothing);
    expect(verification.starts, 0);
  });

  testWidgets('checkout refreshes existing session without beginning login',
      (tester) async {
    final verification = Verification(false);
    await tester.pumpWidget(checkout(verification, Quoter(), item()));
    await tester.pumpAndSettle();
    expect(verification.starts, 0);
    verification.verified = true;
    await tester.tap(find.text('Atualizar sessão'));
    await tester.pumpAndSettle();
    expect(verification.starts, 0);
    expect(find.text('Atualizar sessão'), findsNothing);
  });

  testWidgets('out of range quote blocks delivery with retry and retains cart',
      (tester) async {
    final quoter = Quoter()..fail = true;
    final cartItem = item();
    await tester.pumpWidget(checkout(Verification(false), quoter, cartItem));
    await tester.pumpAndSettle();
    expect(find.text('Este endereço está fora da área de entrega.'),
        findsOneWidget);
    expect(cartItem.quantity, 2);
    quoter.fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(quoter.calls, 2);
    expect(
        find.text('Este endereço está fora da área de entrega.'), findsNothing);
    expect(cartItem.quantity, 2);
  });

  testWidgets(
      'checkout refuses an unconfirmed destination before any order write',
      (tester) async {
    await tester.pumpWidget(
        checkout(Verification(false), Quoter(), item(), confirmed: false));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Finalizar pedido'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Finalizar pedido'));
    await tester.pump();
    expect(find.text('Confirme o destino da entrega antes de continuar.'),
        findsOneWidget);
  });
}
