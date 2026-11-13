import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/widgets/delivery_quote_summary.dart';

const br = DeliveryAddress(
    latitude: -22.579796527952805,
    longitude: -55.68154530958363,
    countryCode: 'BR',
    confirmed: true);
const py = DeliveryAddress(
    latitude: -22.57000320142577,
    longitude: -55.76501750882302,
    countryCode: 'PY',
    confirmed: true);
DeliveryQuote quote({double fee = 21, double distance = 7964, int? expires}) =>
    DeliveryQuote(fee, 'a' * 64, 'routeBands',
        distanceMeters: distance,
        version: 'published-version',
        routingProvider: 'google-routes',
        quotedAtMs: DateTime.now().millisecondsSinceEpoch - 1000,
        expiresAtMs: expires ?? DateTime.now().millisecondsSinceEpoch + 60000);

class StubQuoter implements DeliveryQuoter {
  final DeliveryQuote response;
  int calls = 0;
  StubQuoter(this.response);
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) async {
    calls++;
    return response;
  }
}

void main() {
  test('quote reuse binds exact point, confirmed country and expiry', () {
    final cache = DeliveryQuoteCache();
    final value = quote();
    cache.remember(br, value);
    expect(identical(cache.forDestination(br), value), true);
    expect(
        cache.forDestination(br.copyWith(latitude: br.latitude + .001)), null);
    expect(cache.forDestination(br.copyWith(countryCode: 'PY')), null);
    expect(
        cache.forDestination(const DeliveryAddress(
            latitude: -22.579796527952805,
            longitude: -55.68154530958363,
            countryCode: 'BR')),
        null);
    expect(cache.forDestination(br, nowMs: value.expiresAtMs), null);
    cache.clear();
    expect(cache.forDestination(br), null);
  });
  test('incomplete quote cannot authorize checkout reuse', () {
    const incomplete = DeliveryQuote(21, null, 'routeBands');
    final cache = DeliveryQuoteCache()..remember(br, incomplete);
    expect(incomplete.isFresh(), false);
    expect(cache.forDestination(br), null);
  });
  test(
      'confirmation stages reuse one fresh quote instead of another paid request',
      () async {
    final cache = DeliveryQuoteCache(), quoter = StubQuoter(quote());
    final initial = await quoter.quote(br);
    cache.remember(br, initial);
    for (var stage = 0; stage < 2; stage++) {
      final reused = cache.forDestination(br) ?? await quoter.quote(br);
      expect(reused.id, initial.id);
    }
    expect(quoter.calls, 1);
  });
  testWidgets('cart quote expires locally without automatic recotation',
      (tester) async {
    final quoter = StubQuoter(
        quote(expires: DateTime.now().millisecondsSinceEpoch + 1000));
    final controller = DeliveryQuoteController(quoter);
    await controller.refresh(br);
    expect(controller.value, isNotNull);
    await tester.pump(const Duration(seconds: 2));
    expect(controller.value, null);
    expect(controller.error, contains('expirada'));
    expect(quoter.calls, 1);
    controller.dispose();
  });
  for (final country in ['BR', 'PY']) {
    testWidgets(
        'summary shows route, country and correct BRL total for $country',
        (tester) async {
      final isBr = country == 'BR';
      final controller = DeliveryQuoteController(
          StubQuoter(quote(fee: isBr ? 21 : 19, distance: isBr ? 7964 : 6549)));
      await controller.refresh(isBr ? br : py);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: DeliveryQuoteSummary(
                  controller: controller, subtotal: 100))));
      expect(
          find.text('Distância de rota: ${isBr ? '7,964' : '6,549'} km'),
          findsOneWidget);
      expect(find.text('Destino: ${isBr ? 'Brasil (BR)' : 'Paraguai (PY)'}'),
          findsOneWidget);
      expect(find.text(isBr ? r'R$ 121,00' : r'R$ 119,00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
