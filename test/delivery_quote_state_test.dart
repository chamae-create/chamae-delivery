import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'package:chamae_delivery/widgets/delivery_quote_summary.dart';

class PendingQuoter implements DeliveryQuoter {
  final requests = <Completer<DeliveryQuote>>[];
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) {
    final c = Completer<DeliveryQuote>();
    requests.add(c);
    return c.future;
  }
}

const br = DeliveryAddress(
    latitude: -20, longitude: -50, countryCode: 'BR', confirmed: true);
const py = DeliveryAddress(
    latitude: -20.01, longitude: -50.01, countryCode: 'PY', confirmed: true);
void main() {
  testWidgets('outside area removes freight and blocks cart continuation',
      (tester) async {
    final q = PendingQuoter();
    var continued = false;
    await tester.pumpWidget(MaterialApp(
        home: CartScreen(
      items: () => [
        CartItem(id: 'test', name: 'Produto teste', price: 20, imageUrl: '')
      ],
      change: (_, delta) {},
      checkout: () => continued = true,
      destination: br,
      quoter: q,
    )));
    q.requests.single.completeError(const DeliveryQuoteException(
        'Este endereço está fora da área de entrega disponível no momento.'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar para entrega'));
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Continuar para entrega'))
            .onPressed,
        isNull);
    expect(
        find.text(
            'Este endereço está fora da área de entrega disponível no momento.'),
        findsOneWidget);
    expect(find.textContaining('Entrega R\$'), findsNothing);
    expect(continued, isFalse);
  });
  test(
      'changing address immediately invalidates quote; stale responses cannot overwrite current destination',
      () async {
    final q = PendingQuoter();
    final state = DeliveryQuoteController(q);
    addTearDown(state.dispose);
    final first = state.refresh(br);
    final second = state.refresh(py);
    expect(state.value, isNull);
    expect(state.loading, isTrue);
    q.requests[1].complete(const DeliveryQuote(21, 'py', 'routeBands'));
    await second;
    q.requests[0].complete(const DeliveryQuote(6, 'br', 'routeBands'));
    await first;
    expect(state.value!.id, 'py');
    expect(state.value!.fee, 21);
  });
  testWidgets(
      'pre-checkout summary shows loading, official separate totals, range failure and safe retry',
      (tester) async {
    final q = PendingQuoter();
    final state = DeliveryQuoteController(q);
    addTearDown(state.dispose);
    final initial = state.refresh(br);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DeliveryQuoteSummary(controller: state, subtotal: 100))));
    await tester.pump();
    expect(find.text('Calculando entrega...'), findsOneWidget);
    q.requests.last.complete(const DeliveryQuote(6, 'first', 'routeBands'));
    await initial;
    await tester.pump();
    expect(find.text('Entrega R\$ 6,00'), findsOneWidget);
    expect(find.text('Produtos'), findsOneWidget);
    expect(find.text('Taxa de serviço'), findsOneWidget);
    expect(find.text('R\$ 107,00'), findsOneWidget);
    final outside = state.refresh(py);
    q.requests.last.completeError(const DeliveryQuoteException(
        'Este endereço está fora da área de entrega disponível no momento.'));
    await outside;
    await tester.pump();
    expect(state.value, isNull);
    expect(
        find.text(
            'Este endereço está fora da área de entrega disponível no momento.'),
        findsOneWidget);
    expect(find.text('Entrega R\$ 6,00'), findsNothing);
    expect(find.text('A calcular'), findsOneWidget);
    await tester.tap(find.text('Tentar calcular entrega novamente'));
    await tester.pump();
    q.requests.last.complete(const DeliveryQuote(21, 'retry', 'routeBands'));
    await tester.pumpAndSettle();
    expect(find.text('Entrega R\$ 21,00'), findsOneWidget);
  });
  test('network failure never keeps stale or zero quote', () async {
    final q = PendingQuoter();
    final state = DeliveryQuoteController(q);
    addTearDown(state.dispose);
    final call = state.refresh(br);
    q.requests.last.completeError(StateError('offline'));
    await call;
    expect(state.value, isNull);
    expect(state.error,
        'Não foi possível calcular a entrega agora. Tente novamente.');
  });
}
