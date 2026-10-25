import 'package:cloud_functions/cloud_functions.dart';
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
  DeliveryAddress? lastDestination;
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) async {
    calls++;
    lastDestination = destination;
    // Same contract as chamaeCotarEntrega: an unconfirmed destination cannot
    // produce an official quote, regardless of the store's current opening time.
    if (!destination.confirmed) {
      throw FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'Confirme o destino da entrega.',
          details: const {'reason': 'DESTINATION_COUNTRY_UNVERIFIED'});
    }
    if (fail) {
      throw const DeliveryQuoteException(
          'Este endereço está fora da área de entrega.');
    }
    return const DeliveryQuote(7.25, 'test-quote', 'routeBands');
  }
}

Widget checkout(
        Verification verification, DeliveryQuoter? quoter, CartItem item,
        {bool confirmed = true, VoidCallback? onCartCleared}) =>
    MaterialApp(
        home: CheckoutScreen(
            cartItems: [item],
            onCartCleared: onCartCleared ?? () {},
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

  testWidgets(
      'default quoter failure hides numeric freight and blocks checkout',
      (tester) async {
    final cart = item();
    // Firebase is deliberately unavailable here. Omitting dependency injection
    // must not display the former R$10 tariff or enable an order.
    await tester.pumpWidget(checkout(Verification(false), null, cart));
    await tester.pumpAndSettle();
    expect(find.text('Aguardando cotação'), findsOneWidget);
    expect(find.text('Aguardando entrega'), findsOneWidget);
    expect(find.text('R\$ 10,00'), findsNothing);
    expect(find.text('R\$ 50,40'), findsNothing);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Finalizar pedido'))
            .onPressed,
        isNull);
    expect(cart.quantity, 2);
    expect(tester.takeException(), isNull);
  });

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
    final quoter = Quoter();
    final cartItem = item();
    var cartCleared = false;
    await tester.pumpWidget(checkout(Verification(true), quoter, cartItem,
        confirmed: false, onCartCleared: () => cartCleared = true));
    await tester.pumpAndSettle();
    expect(quoter.calls, 1);
    expect(quoter.lastDestination?.confirmed, isFalse);
    expect(
        find.text(
            'Não foi possível calcular a entrega agora. Tente novamente.'),
        findsOneWidget);
    expect(find.text('Aguardando cotação'), findsOneWidget);
    final finalize = find.widgetWithText(ElevatedButton, 'Finalizar pedido');
    await tester.scrollUntilVisible(finalize, 400,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<ElevatedButton>(finalize).onPressed, isNull);
    await tester.tap(finalize);
    await tester.pump();
    expect(cartCleared, isFalse);
    expect(cartItem.quantity, 2);
    expect(quoter.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
