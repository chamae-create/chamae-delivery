import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/widgets/customer_visual.dart';
import 'package:chamae_delivery/widgets/order_confirmation.dart';
import 'package:chamae_delivery/widgets/product_image.dart';
import 'package:chamae_delivery/widgets/store_hours_builder.dart';
import 'support/customer_flow_fakes.dart';

Map<String, dynamic> confirmedOrder({bool pix = false}) => {
      'id': '#TEST-24',
      'status': 'Novo',
      'financialValidationStatus': 'validated',
      'paymentMethod': pix ? 'PIX' : 'Maquininha',
      'pixRequested': pix,
      'paymentStatus': pix ? 'Pago' : 'Pendente na entrega',
      'address': 'Rua de teste, 1',
      'itemsList': [
        {'name': 'Produto de teste', 'quantity': 2}
      ],
      'itemsTotal': 40,
      'deliveryFee': 7.25,
      'customerFee': .4,
      'totalBRL': 47.65,
    }; // Only synthetic, already frozen server values; no production settings.

Widget app(Widget child, {double scale = 1, bool reducedMotion = false}) =>
    MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reducedMotion),
            child: child!),
        home: child);

class PendingProfile implements CustomerOnboardingRepository {
  Completer<CustomerOnboardingState> result = Completer();
  @override
  Future<CustomerOnboardingState> load() => result.future;
  @override
  Future<void> accept(CustomerPolicy policy, String birthDate) async {}
}

void main() {
  test(
      'confirmation requires official finance and paid PIX, including older PIX records',
      () {
    expect(canPresentOrderConfirmation(confirmedOrder()), isTrue);
    expect(canPresentOrderConfirmation(confirmedOrder(pix: true)), isTrue);
    for (final change in [
      {'financialValidationStatus': 'pending'},
      {'financialValidationStatus': 'rejected'},
      {'status': 'Cancelado'},
      {'status': 'Revisão financeira'},
      {'status': 'Revisão de estoque'},
      {'status': 'unknown'},
      {'paymentMethod': 'PIX', 'paymentStatus': 'Pendente'},
      {'pixRequested': true, 'paymentStatus': 'Pendente'},
    ]) {
      expect(canPresentOrderConfirmation({...confirmedOrder(), ...change}),
          isFalse,
          reason: change.toString());
    }
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets(
        'confirmed order is scrollable at 320px, text $scale and reduced motion',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(
          TrackingView(
              orderId: '#TEST-24',
              showConfirmation: true,
              onBack: () {},
              orderStream: Stream.value(confirmedOrder(pix: true))),
          scale: scale,
          reducedMotion: true));
      await tester.pumpAndSettle();
      expect(find.text('Pedido confirmado!'), findsOneWidget);
      expect(find.textContaining('#TEST-24'), findsWidgets);
      expect(find.text('Pagamento confirmado'), findsOneWidget);
      expect(find.text('R\$ 47,65'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Acompanhar pedido'), 180,
          scrollable: find.byType(Scrollable).first);
      expect(
          tester
              .getSize(find.widgetWithText(ElevatedButton, 'Acompanhar pedido'))
              .height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.text('Acompanhar pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Pedido confirmado!'), findsNothing);
      await tester.scrollUntilVisible(find.text('STATUS DO PEDIDO'), 180,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('STATUS DO PEDIDO'), findsOneWidget);
      expect(find.textContaining('15 a 25'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'unconfirmed write cannot celebrate; stream confirmation appears once',
      (tester) async {
    final orders = StreamController<Map<String, dynamic>?>();
    addTearDown(orders.close);
    await tester.pumpWidget(app(TrackingView(
        orderId: '#TEST-24',
        orderStream: orders.stream,
        onBack: () {},
        showConfirmation: true)));
    orders.add({
      ...confirmedOrder(pix: true),
      'paymentStatus': 'Pendente',
      'financialValidationStatus': 'pending'
    });
    await tester.pumpAndSettle();
    expect(find.text('Pedido confirmado!'), findsNothing);
    orders.add(confirmedOrder(pix: true));
    await tester.pumpAndSettle();
    expect(find.text('Pedido confirmado!'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Acompanhar pedido'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Acompanhar pedido'));
    await tester.pumpAndSettle();
    orders.add({...confirmedOrder(pix: true), 'status': 'Em Separação'});
    await tester.pumpAndSettle();
    expect(find.text('Pedido confirmado!'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'tracking never invents address, courier, total or progress for unknown status',
      (tester) async {
    await tester.pumpWidget(app(TrackingView(
        orderId: '#TEST',
        onBack: () {},
        orderStream: Stream.value({'status': 'unknown'}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Destino: Endereço não informado'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Total em confirmação'), findsOneWidget);
    expect(find.textContaining('Centro - Ponta Porã'), findsNothing);
    expect(find.text('Entregador não informado'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracking error has human recovery and retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(app(TrackingView(
        orderId: '#TEST',
        onBack: () {},
        onRetry: () => retries++,
        orderStream: Stream.error(StateError('SDK_DETAIL')))));
    await tester.pumpAndSettle();
    expect(find.textContaining('SDK_DETAIL'), findsNothing);
    expect(find.textContaining('não confirma o cancelamento'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });

  testWidgets(
      'store presentation refreshes on close and resume without rebuilding every tick',
      (tester) async {
    var now = DateTime.utc(2026, 10, 25, 3, 59); // 23:59 MS.
    var builds = 0;
    await tester.pumpWidget(app(StoreHoursBuilder(
        clock: () => now,
        builder: (context, open, label) {
          builds++;
          return Text('$open: $label');
        })));
    expect(find.textContaining('true: Delivery'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(builds, 1);
    now = DateTime.utc(2026, 10, 25, 4); // 00:00 MS.
    await tester.pump(const Duration(seconds: 30));
    expect(find.textContaining('false: Loja fechada'), findsOneWidget);
    now = DateTime.utc(2026, 10, 25, 12); // 08:00 MS.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.textContaining('true: Delivery'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'long cart builds lazily and last item remains removable at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = List.generate(
        35,
        (i) => CartItem(
            id: 'test$i',
            name: 'Item $i',
            price: 1,
            imageUrl: '',
            quantity: 1));
    await tester.pumpWidget(app(
        CartScreen(
            items: () => items,
            change: (id, delta) => items.removeWhere((item) => item.id == id),
            checkout: () {}),
        scale: 1.6));
    await tester.pumpAndSettle();
    expect(find.text('Item 34'), findsNothing);
    await tester.scrollUntilVisible(find.byTooltip('Remover Item 34'), 450,
        maxScrolls: 70, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Remover Item 34')),
        alignment: .5);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remover Item 34').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Remover Item 34'));
    await tester.pumpAndSettle();
    expect(items.length, 34);
    expect(items.any((item) => item.id == 'test34'), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'profile loading and failure preserve account navigation and offer retry',
      (tester) async {
    final repository = PendingProfile();
    await tester.pumpWidget(app(CustomerProfileScreen(
        onboarding: repository, selectAddress: () async {})));
    await tester.pump();
    expect(find.text('Buscando os dados da sua conta'), findsOneWidget);
    repository.result.completeError(StateError('SDK_DETAIL'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tentar novamente'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente').hitTestable(), findsOneWidget);
    expect(find.textContaining('SDK_DETAIL'), findsNothing);
    repository.result = Completer();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    repository.result
        .complete(const CustomerOnboardingState(testCustomerPolicy, {}));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível atualizar seu perfil.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('invalid product image uses neutral accessible placeholder',
      (tester) async {
    await tester.pumpWidget(app(const SizedBox(
        width: 80,
        height: 80,
        child: ProductImage(url: 'data:image/png;base64,invalid!'))));
    expect(find.byIcon(Icons.local_drink_outlined), findsNothing);
    expect(find.bySemanticsLabel('Imagem do produto indisponível'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('convenience offers and cards have no ice backdrop',
      (tester) async {
    final product = Product(
        id: 'test',
        name: 'Snack teste',
        category: 'Snacks & Doces',
        price: 1,
        stock: 3,
        isActive: true,
        imageUrl: '',
        description: 'Snack',
        isOffer: true,
        isCombo: false,
        salesCount: 1);
    await tester
        .pumpWidget(app(DeliveryHomeScreen(products: Stream.value([product]))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Promoções do dia'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    final offers = find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        widget.properties.label == 'Ver oferta de Snack teste');
    await tester.scrollUntilVisible(offers, 160,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(offers, findsOneWidget);
    final ink = tester.widget<Ink>(
        find.descendant(of: offers, matching: find.byType(Ink)).first);
    expect((ink.decoration as BoxDecoration).image, isNull);
    expect((ink.decoration as BoxDecoration).gradient, CustomerVisual.charcoal);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
