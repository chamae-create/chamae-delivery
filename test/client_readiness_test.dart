import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/core/catalog.dart';
import 'package:chamae_delivery/core/cart_validation.dart';
import 'package:chamae_delivery/core/store_hours.dart';
import 'package:chamae_delivery/screens/splash_screen.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';

Product product({int stock = 5}) => Product(
    id: 'beer',
    name: 'Bebida 350 ml',
    category: 'Cervejas',
    price: 20,
    stock: stock,
    isActive: true,
    imageUrl: '',
    description: 'Lata 350 ml',
    isOffer: true,
    isCombo: false,
    salesCount: 1);
CartItem item() => CartItem(
    id: 'beer', name: 'Bebida 350 ml', price: 20, imageUrl: '', quantity: 2);

Widget checkout(String? country) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: CheckoutScreen(
        cartItems: [item()],
        onCartCleared: () {},
        deliveryAddress: DeliveryAddress(
            latitude: -22.53,
            longitude: -55.72,
            addressText: 'Rua de teste',
            countryCode: country)));

void main() {
  testWidgets('home respeita texto ampliado e área segura inferior',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 34)),
            child: child!),
        home: DeliveryHomeScreen(products: Stream.value([product()]))));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('horário MS: meia-noite fechado, 08h aberto, 23h59 aberto', () {
    expect(isStoreOpen(DateTime.utc(2026, 10, 18, 3, 59)), isTrue);
    expect(isStoreOpen(DateTime.utc(2026, 10, 18, 4)), isFalse);
    expect(isStoreOpen(DateTime.utc(2026, 10, 18, 11, 59)), isFalse);
    expect(isStoreOpen(DateTime.utc(2026, 10, 18, 12)), isTrue);
    expect(
        storeHoursLabel(DateTime.utc(2026, 10, 18, 12)), 'Delivery até 00:00');
    expect(storeHoursLabel(DateTime.utc(2026, 10, 18, 4)),
        'Loja fechada • abre às 08:00 (MS)');
  });
  test(
      'preflight detecta preço, reserva, estoque e bloqueio sem alterar carrinho',
      () {
    final cart = item();
    final data = <String, dynamic>{
      'name': cart.name,
      'stock': 5,
      'reservedStock': 2,
      'priceBRL': 20
    };
    expect(cartItemIssue(cart, data), isNull);
    expect(cartItemIssue(cart, {...data, 'priceBRL': 21}), contains('preço'));
    expect(cartItemIssue(cart, {...data, 'reservedStock': 4}),
        contains('estoque'));
    expect(cartItemIssue(cart, {...data, 'isActive': false}),
        contains('disponível'));
    expect(
        cartItemIssue(cart, {...data, 'name': 'POD'}), contains('disponível'));
    expect(cartItemIssue(cart, null), contains('disponível'));
    expect(cart.price, 20);
    expect(cart.quantity, 2);
  });
  test('catálogo mantém indisponível visível e bloqueia compra', () {
    final unavailable = product(stock: 0);
    expect(visibleCatalogProducts([unavailable]), [unavailable]);
    expect(commerciallyAvailable(unavailable), isFalse);
  });
  test('endereço preserva país estruturado e compatibilidade legada', () {
    final address = DeliveryAddress.fromMap({
      'latitude': -22.5,
      'longitude': -55.7,
      'addressText': 'Rua sem nome de país',
      'countryCode': 'PY'
    });
    expect(address.copyWith(complement: 'Casa').toMap()['countryCode'], 'PY');
    expect(DeliveryAddress.fromMap({}).countryCode, isNull);
  });
  testWidgets('splash avança assim que sessão pronta, sem espera estética',
      (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: SplashScreen(
            initialize: () => ready.future,
            destination: const Scaffold(body: Text('Home pronta')))));
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel,
        'Chamaê Delivery. Bebidas e conveniência.');
    ready.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Home pronta'), findsOneWidget);
    await tester.pumpAndSettle();
  });
  testWidgets('splash mostra erro e permite nova tentativa', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
        home: SplashScreen(
            initialize: () async {
              if (++attempts == 1) throw Exception('offline');
            },
            destination: const Scaffold(body: Text('Conectado')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Conectado'), findsOneWidget);
    expect(attempts, 2);
  });
  for (final country in ['BR', 'PY']) {
    testWidgets('checkout $country automático e cartão somente BR',
        (tester) async {
      await tester.pumpWidget(checkout(country));
      await tester.pumpAndSettle();
      expect(find.text('Destino: ${country == 'BR' ? 'Brasil' : 'Paraguai'}'),
          findsOneWidget);
      expect(find.text('Confirmar país da entrega'), findsNothing);
      await tester.ensureVisible(find.text('PIX'));
      expect(find.text('Cartão na entrega'),
          country == 'BR' ? findsOneWidget : findsNothing);
      expect(find.text('Débito'), findsNothing);
      expect(find.text('Crédito à vista'), findsNothing);
      expect(find.text('Crédito'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('país desconhecido usa confirmação excepcional', (tester) async {
    await tester.pumpWidget(checkout(null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar país da entrega'));
    await tester.pumpAndSettle();
    expect(find.text('Esta entrega é no Brasil ou Paraguai?'), findsOneWidget);
    await tester.tap(find.text('Paraguai'));
    await tester.pumpAndSettle();
    expect(find.text('Destino: Paraguai'), findsOneWidget);
  });
  testWidgets('dinheiro: moedas e troco em BRL', (tester) async {
    await tester.pumpWidget(checkout('BR'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dinheiro'));
    await tester.tap(find.text('Dinheiro'));
    await tester.pumpAndSettle();
    for (final currency in ['BRL', 'PYG', 'USD']) {
      await tester.ensureVisible(find.text(currency));
      await tester.tap(find.text(currency));
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextField, 'Valor que será entregue');
      await tester.ensureVisible(input);
      await tester.enterText(input, currency == 'PYG' ? '100000' : '100');
      await tester.pumpAndSettle();
      expect(find.textContaining('Troco em Real'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('pagamento dividido começa recolhido e aceita dinheiro',
      (tester) async {
    await tester.pumpWidget(checkout('BR'));
    await tester.pumpAndSettle();
    final toggle = find.byType(Switch);
    await tester.ensureVisible(toggle);
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.textContaining('Somente dinheiro'), findsWidgets);
    expect(find.text('Cartão na entrega'), findsNothing);
  });
  testWidgets('carrinho altera quantidade, total e remove item',
      (tester) async {
    final cart = [item()];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: CartScreen(
            items: () => cart,
            checkout: () {},
            change: (id, delta) {
              cart.single.quantity += delta;
              if (cart.single.quantity <= 0) cart.clear();
            })));
    expect(find.text('R\$ 40,40'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar quantidade'));
    await tester.pump();
    expect(find.text('R\$ 60,60'), findsOneWidget);
    await tester.tap(find.byTooltip('Remover Bebida 350 ml'));
    await tester.pump();
    expect(find.text('Seu carrinho está vazio.'), findsOneWidget);
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('home, produto, busca e carrinho em largura $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: DeliveryHomeScreen(products: Stream.value([product()]))));
      await tester.pump(const Duration(seconds: 1));
      await tester.scrollUntilVisible(find.text('BEBIDA 350 ML'), 300,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first);
      await Scrollable.ensureVisible(tester.element(find.text('BEBIDA 350 ML')),
          alignment: .3);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BEBIDA 350 ML'));
      await tester.pumpAndSettle();
      expect(find.text('Lata 350 ml'), findsOneWidget);
      await tester.tap(find.text('Adicionar ao carrinho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carrinho'));
      await tester.pumpAndSettle();
      expect(find.text('Seu carrinho'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
