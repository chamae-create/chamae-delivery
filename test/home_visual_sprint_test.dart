import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product sample(String id,
        {bool offer = false,
        int sales = 1,
        int stock = 2,
        String category = 'Cervejas',
        String? name,
        double price = 20}) =>
    Product(
        id: id,
        name: name ?? 'Produto $id',
        category: category,
        price: price,
        stock: stock,
        isActive: true,
        imageUrl: '',
        description: 'Descrição real da fixture',
        isOffer: offer,
        isCombo: false,
        salesCount: sales);

Future<void> openHome(WidgetTester tester, List<Product> products,
    {double width = 360, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: DeliveryHomeScreen(products: Stream.value(products))));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180,
      maxScrolls: 60,
      scrollable: find
          .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable))
          .first);
  await tester.pump();
}

void main() {
  testWidgets('Ver todos reveals the lazy catalog without layout errors',
      (tester) async {
    await openHome(
        tester, List.generate(12, (i) => sample('item$i', sales: 20 - i)));
    await reveal(tester, find.text('Mais pedidos'));
    await tester.tap(find.widgetWithText(TextButton, 'Ver todos').first);
    await tester.pumpAndSettle();
    expect(find.text('Todos os produtos').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home sections use real offers, sales and permitted categories',
      (tester) async {
    await openHome(tester, [
      sample('A', offer: true, sales: 4),
      sample('B', sales: 12, category: 'Snacks & Doces'),
      sample('blocked', name: 'POD bloqueado', category: 'Tabacaria')
    ]);
    expect(find.byTooltip('Buscar produtos'), findsOneWidget);
    expect(find.text('Carrinho'), findsNothing);
    await reveal(tester, find.text('Promoções do dia'));
    await reveal(tester, find.text('Mais pedidos'));
    await reveal(tester, find.text('Compre por categoria'));
    await reveal(tester, find.text('Todos os produtos'));
    expect(find.text('POD bloqueado'), findsNothing);
    expect(find.text('Tabacaria'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home preserves stock limit, decrement and cart entry',
      (tester) async {
    await openHome(tester, [sample('A')]);
    await reveal(tester, find.text('Todos os produtos'));
    await reveal(tester, find.byTooltip('Adicionar Produto A').last);
    await tester.tap(find.byTooltip('Adicionar Produto A').last);
    await tester.pump();
    await tester.tap(find.byTooltip('Adicionar Produto A').last);
    await tester.pump();
    await tester.tap(find.byTooltip('Adicionar Produto A').last);
    await tester.pump();
    expect(find.text('2 • R\$ 40,00'), findsOneWidget);
    expect(find.text('Você já adicionou a quantidade disponível.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Diminuir quantidade de Produto A').last);
    await tester.pump();
    expect(find.text('1 • R\$ 20,00'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Carrinho').last);
    await tester.pumpAndSettle();
    expect(find.text('Seu carrinho'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Search remains available from header and filters real products',
      (tester) async {
    await openHome(tester, [sample('A'), sample('B')]);
    await tester.tap(find.byTooltip('Buscar produtos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Produto B');
    await tester.pump();
    await reveal(tester, find.text('Resultados da busca'));
    await reveal(tester, find.text('Produto B').last);
    expect(find.text('Produto A'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('No promotion or ranking is fabricated when data is absent',
      (tester) async {
    await openHome(tester, [sample('A', sales: 0)]);
    await reveal(tester, find.text('Todos os produtos'));
    expect(find.text('Promoções do dia'), findsNothing);
    expect(find.text('Mais pedidos'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 360.0, 440.0, 768.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('Home safe layout $width text $scale', (tester) async {
        await openHome(
            tester,
            [
              sample('long',
                  offer: true,
                  name:
                      'Bebida com nome muito extenso e embalagem retornável de um litro',
                  price: 1234.56)
            ],
            width: width,
            scale: scale);
        await reveal(tester, find.text('Promoções do dia'));
        await reveal(tester, find.text('Mais pedidos'));
        await reveal(tester, find.text('Todos os produtos'));
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
