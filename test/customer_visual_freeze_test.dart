import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'support/customer_flow_fakes.dart';

Product product(String id, String name, String category) => Product(
    id: id,
    name: name,
    category: category,
    price: 20,
    stock: 5,
    isActive: true,
    imageUrl: '',
    description: 'Descrição do catálogo de teste.',
    isOffer: false,
    isCombo: false,
    salesCount: 1);

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_VISUAL')) return;
  await tester.runAsync(() async {
    for (final widget in tester.widgetList<Image>(find.byType(Image))) {
      final stream = widget.image.resolve(ImageConfiguration.empty);
      final ready = Completer<void>();
      final listener = ImageStreamListener((_, __) {
        if (!ready.isCompleted) ready.complete();
      }, onError: (Object error, StackTrace? stack) {
        if (!ready.isCompleted) ready.complete();
      });
      stream.addListener(listener);
      try {
        await ready.future.timeout(const Duration(seconds: 5));
      } finally {
        stream.removeListener(listener);
      }
    }
  });
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(() async {
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')));
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory(const String.fromEnvironment(
        'VISUAL_CAPTURE_DIR',
        defaultValue: 'tool/visual_freeze/screenshots'))
      ..createSync(recursive: true);
    File('${directory.path}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget app(Widget home, double scale) => MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: const ValueKey('capture'), child: child!)),
    home: home);

void main() {
  setUpAll(() async {
    const path = String.fromEnvironment('VISUAL_FONT_PATH');
    if (path.isEmpty) return;
    final loader = FontLoader('Roboto')
      ..addFont(
          Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    await loader.load();
    await (FontLoader('Ahem')
          ..addFont(
              Future.value(ByteData.sublistView(File(path).readAsBytesSync()))))
        .load();
    final icons = File('${File(path).parent.path}/materialicons-regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')
            ..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
          .load();
    }
  });
  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('visual flows at width $width, text $scale', (tester) async {
        tester.view.physicalSize = Size(width, width == 360 ? 640 : 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (width == 360) {
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
        }
        final products = [
          product('a', 'Bebida de teste', 'Cervejas'),
          product('b', 'Snack de teste', 'Snacks & Doces'),
          product('blocked', 'POD', 'Tabacaria')
        ];
        await tester.pumpWidget(
            app(DeliveryHomeScreen(products: Stream.value(products)), scale));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, 'home_$width');
        await tester.tap(find.text('Categorias').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('category-Cervejas')), 250,
            scrollable: find
                .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable))
                .first);
        expect(find.text('Tabacaria'), findsNothing);
        expect(find.text('POD'), findsNothing);
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, 'categories_$width');
        await Scrollable.ensureVisible(
            tester.element(find.byKey(const ValueKey('category-Cervejas'))),
            alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('category-Cervejas')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Bebida de teste'), 250,
            scrollable: find
                .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable))
                .first);
        await Scrollable.ensureVisible(
            tester.element(find.text('Bebida de teste')),
            alignment: .3);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bebida de teste'));
        await tester.pumpAndSettle();
        expect(find.text('Descrição do catálogo de teste.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, 'product_$width');
        if (width == 360) {
          await tester.ensureVisible(find.text('Adicionar ao carrinho'));
          await tester.pumpAndSettle();
          expect(
              find.text('Adicionar ao carrinho').hitTestable(), findsOneWidget);
          expect(tester.getRect(find.text('Adicionar ao carrinho')).bottom,
              lessThanOrEqualTo(616));
          if (scale == 1) await capture(tester, 'product_footer_360');
        }
        await tester.pumpWidget(const SizedBox());

        final items = [
          CartItem(
              id: 'a',
              name: 'Nome longo de produto para validar quebra de linha',
              price: 20,
              imageUrl: '',
              quantity: 2)
        ];
        await tester.pumpWidget(app(
            CartScreen(items: () => items, change: (_, __) {}, checkout: () {}),
            scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, 'cart_$width');
        await tester.pumpWidget(app(
            CheckoutScreen(
                cartItems: items,
                onCartCleared: () {},
                deliveryAddress: testCustomerAddress),
            scale));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('PIX'), 250,
            scrollable: find.byType(Scrollable).first);
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, 'checkout_$width');
        await tester.pumpWidget(app(
            CustomerProfileScreen(
                onboarding: FlowOnboarding(accepted: true),
                selectAddress: () async {}),
            scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, 'profile_$width');
        await tester.pumpWidget(app(
            TrackingView(
                orderId: 'TEST-1',
                onBack: () {},
                orderStream: Stream.value({
                  'status': 'Concluído',
                  'address': 'Endereço confirmado no teste',
                  'totalBRL': 40,
                  'itemsList': [
                    {'name': 'Produto de teste', 'quantity': 2}
                  ],
                })),
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Entregue'), findsWidgets);
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, 'tracking_$width');
        if (width == 360) {
          await tester.ensureVisible(find.text('Entregador não informado'));
          await tester.pumpAndSettle();
          expect(find.text('Entregador não informado').hitTestable(),
              findsOneWidget);
          if (scale == 1) await capture(tester, 'tracking_footer_360');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
