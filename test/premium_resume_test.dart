import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/launch_financial_policy.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'package:chamae_delivery/data/binational_identity.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/screens/customer_identification_screen.dart';
import 'package:chamae_delivery/widgets/delivery_quote_summary.dart';
import 'package:chamae_delivery/widgets/commerce_components.dart';
import 'package:chamae_delivery/widgets/product_image.dart';
import 'customer_visual_freeze_test.dart' as visuals;
import 'support/customer_flow_fakes.dart';

class _Pending implements DeliveryQuoter {
  final response = Completer<DeliveryQuote>();
  @override
  Future<DeliveryQuote> quote(DeliveryAddress address) => response.future;
}

class _Identification implements IdentificationRepository {
  @override
  Future<void> save(BinationalIdentity identity) async {}
}

void main() {
  test('freight error categories do not leak provider details', () {
    final denied = deliveryQuoteErrorMessage(FirebaseFunctionsException(
        code: 'permission-denied', message: 'PRIVATE_PROVIDER_DETAIL'));
    expect(denied.contains('autorizada'), true);
    expect(denied.contains('PRIVATE_PROVIDER_DETAIL'), false);
    expect(
        deliveryQuoteErrorMessage(
                FirebaseFunctionsException(code: 'resource-exhausted', message: 'synthetic'))
            .contains('Limite'),
        true);
    expect(
        deliveryQuoteErrorMessage(
                FirebaseFunctionsException(code: 'unauthenticated', message: 'synthetic'))
            .contains('Entre'),
        true);
  });

  test(
      'new-order fee policy never charges customer or current merchant commission',
      () {
    for (final subtotal in [0.0, .01, 19.99, 200.0, 99999.99]) {
      expect(LaunchFinancialPolicy.customerFee(subtotal), 0);
      expect(LaunchFinancialPolicy.merchantFee(subtotal), 0);
    }
    expect(LaunchFinancialPolicy.futureMerchantCommissionBps, 300);
    expect(() => LaunchFinancialPolicy.customerFee(double.nan),
        throwsArgumentError);
  });
  test('removing destination invalidates in-flight quote and late response',
      () async {
    final quoter = _Pending(), controller = DeliveryQuoteController(_Pending());
    controller.dispose();
    final active = DeliveryQuoteController(quoter);
    final request = active.refresh(testCustomerAddress);
    active.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    quoter.response.complete(DeliveryQuote(10, 'a' * 64, 'routeBands',
        distanceMeters: 1000,
        version: 'synthetic',
        routingProvider: 'synthetic',
        quotedAtMs: now,
        expiresAtMs: now + 60000));
    await request;
    expect(active.value, isNull);
    expect(active.destination, isNull);
    expect(active.loading, false);
    active.dispose();
  });
  testWidgets('cart without address shows 200 not 202 and no invented freight',
      (tester) async {
    await tester.pumpWidget(visuals.app(
        CartScreen(
            items: () => [
                  CartItem(
                      id: 'synthetic',
                      name: 'ÁGUA TESTE HML NÃO COMERCIALIZAR',
                      price: 20,
                      imageUrl: '',
                      quantity: 10)
                ],
            change: (_, __) {},
            checkout: () {}),
        1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Taxa de serviço'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('R\$ 0,00'), findsOneWidget);
    expect(find.text('R\$ 2,00'), findsNothing);
    expect(find.text('R\$ 202,00'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('quote summary does not add 1% with a valid freight quote',
      (tester) async {
    final controller = DeliveryQuoteController(_Pending());
    final now = DateTime.now().millisecondsSinceEpoch;
    controller.value = DeliveryQuote(10, 'a' * 64, 'routeBands',
        distanceMeters: 1000,
        version: 'synthetic',
        routingProvider: 'synthetic',
        quotedAtMs: now,
        expiresAtMs: now + 60000);
    await tester.pumpWidget(visuals.app(
        Scaffold(
            body: DeliveryQuoteSummary(controller: controller, subtotal: 200)),
        1));
    expect(find.textContaining('210,00'), findsOneWidget);
    expect(find.textContaining('212,00'), findsNothing);
    controller.dispose();
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('header and identification accessible $width/$scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(visuals.app(
            Scaffold(
                body: CommerceHeader(
                    address: 'Avenida de teste, 100, Centro',
                    onCart: () {},
                    onSearch: () {},
                    onAddress: () {},
                    cartCount: 10)),
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Pit Stop V8'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(visuals.app(
            CustomerIdentificationScreen(
                profile: const {},
                repository: _Identification(),
                onComplete: () {}),
            scale));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Salvar identificação'), 180,
            scrollable: find.byType(Scrollable).first);
        await Scrollable.ensureVisible(
            tester.element(find.text('Salvar identificação')),
            alignment: .5);
        await tester.pumpAndSettle();
        expect(find.text('Salvar identificação').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets(
      'image URL normalization accepts valid data and malformed data stays safe',
      (tester) async {
    const png =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jr1EAAAAASUVORK5CYII=';
    await tester.pumpWidget(visuals.app(
        const SizedBox(
            width: 50, height: 50, child: ProductImage(url: ' $png ')),
        1));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpWidget(visuals.app(
        const ProductImage(url: 'data:image/png;base64,invalid'), 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
