@TestOn('vm')
library;

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/restricted_catalog.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'package:chamae_delivery/data/customer_verification.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/l10n/locale_controller.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';
import 'package:chamae_delivery/screens/product_detail_screen.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'package:chamae_delivery/widgets/commerce_components.dart';
import 'package:chamae_delivery/widgets/age_verification_card.dart';
import 'support/customer_flow_fakes.dart';

Product sample(String id, String name, String category,
        {bool alcohol = false}) =>
    Product(
        id: id,
        name: name,
        category: category,
        price: 10,
        stock: 5,
        isActive: true,
        imageUrl: '',
        description: 'Item sintético para teste local.',
        isOffer: true,
        isCombo: false,
        salesCount: 1,
        isAlcoholic: alcohol);

class LocalQuote implements DeliveryQuoter {
  int calls = 0;
  @override
  Future<DeliveryQuote> quote(DeliveryAddress address) async {
    calls++;
    final now = DateTime.now().millisecondsSinceEpoch;
    return DeliveryQuote(5, 'a' * 64, 'routeBands',
        distanceMeters: 1200,
        version: 'synthetic-only',
        routingProvider: 'synthetic-only',
        quotedAtMs: now - 1000,
        expiresAtMs: now + 60000);
  }
}

class LocalVerifiedAccount implements AccountVerification {
  @override
  Future<bool> isVerified() async => true;
  @override
  Future<void> startVerification() async {}
}

Widget shell(Widget child, {String locale = 'pt-BR', double scale = 1}) {
  final controller = LocaleController(stored: locale, persist: (_) async {});
  return LocaleScope(
      controller: controller,
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          locale: controller.locale,
          supportedLocales: const [Locale('pt', 'BR'), Locale('es', 'PY')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: RepaintBoundary(
                  key: const ValueKey('sprint100-capture'), child: child!)),
          home: CommerceRouteNavigation(
              onSelected: (_) {},
              onSearch: () {},
              onCart: () {},
              child: child)));
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SPRINT100_CAPTURE')) return;
  await tester.runAsync(() async {
    for (final widget in tester.widgetList<Image>(find.byType(Image))) {
      final stream = widget.image.resolve(ImageConfiguration.empty);
      final ready = Completer<void>();
      final listener = ImageStreamListener((_, __) {
        if (!ready.isCompleted) ready.complete();
      }, onError: (Object _, StackTrace? __) {
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
        find.byKey(const ValueKey('sprint100-capture')));
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(const String.fromEnvironment('SPRINT100_CAPTURE_DIR',
        defaultValue: 'docs/sprint100_2026-11-09/screenshots'))
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    final geometry = <String, dynamic>{};
    for (final entry in [
      ('header', find.byType(CommerceHeader)),
      ('hero', find.byType(ConvenienceCampaign)),
      ('bottom_nav', find.byType(CommerceBottomBar)),
      ('heading', find.byType(CommercePageTitle)),
      ('primary_button', find.byType(GoldPrimaryButton)),
      ('stepper', find.byType(GoldStepper)),
      ('timeline', find.byType(CommerceOrderTimeline)),
      ('profile_hero', find.byType(CommerceProfileBanner)),
    ]) {
      final bounds = <Map<String, double>>[];
      for (final element in entry.$2.evaluate()) {
        final render = element.findRenderObject();
        if (render is RenderBox && render.hasSize) {
          final position = render.localToGlobal(Offset.zero);
          if (position.dx.isFinite && position.dy.isFinite) {
            bounds.add({
              'x': position.dx,
              'y': position.dy,
              'width': render.size.width,
              'height': render.size.height,
            });
          }
        }
      }
      geometry[entry.$1] = bounds;
    }
    File('${dir.path}/$name.geometry.json')
        .writeAsStringSync(jsonEncode(geometry));
    image.dispose();
  });
}

void main() {
  testWidgets('checkout failure remains readable at 320 dp and text 1.6',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(shell(
        CheckoutScreen(cartItems: [
          CartItem(
              id: 'local',
              name: 'Nome longo de produto para validar quebra de linha',
              price: 20,
              imageUrl: '',
              quantity: 2)
        ], onCartCleared: () {}, deliveryAddress: testCustomerAddress),
        scale: 1.6));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('PIX'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  setUpAll(() async {
    const directory = 'C:/flutter/bin/cache/artifacts/material_fonts';
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(
                File('$directory/roboto-regular.ttf').readAsBytesSync()))))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(
              File('$directory/materialicons-regular.otf').readAsBytesSync()))))
        .load();
  });

  test(
      'catalog uses authoritative flags and categories, not product names, for exposure',
      () {
    expect(
        restrictedCatalogProduct(sample('a', 'Água', 'Geral', alcohol: true)),
        true);
    expect(restrictedCatalogProduct(sample('b', 'Item', 'Cervejas')), true);
    expect(
        restrictedCatalogProduct(
            sample('c', 'Cerveja sem álcool', 'Refrigerantes & Sucos')),
        false);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'product and stepper stay usable at $width dp / text $scale / es-PY',
          (tester) async {
        tester.view.physicalSize = Size(width, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var received = 0;
        await tester.pumpWidget(shell(
            ProductDetailScreen(
                product: sample('water', 'Água mineral com nome longo',
                    'Gelo & Conveniência'),
                remaining: () => 2,
                add: (n) {
                  received = n;
                  return true;
                }),
            locale: 'es-PY',
            scale: scale));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(GoldStepper));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
            of: find.byType(GoldStepper), matching: find.byIcon(Icons.add)));
        await tester.pumpAndSettle();
        expect(tester.widget<GoldStepper>(find.byType(GoldStepper)).value, 2);
        expect(tester.takeException(), isNull);
        expect(received, 0);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
      'stable stepper golden preserves quantity and disabled boundaries',
      (tester) async {
    await tester.pumpWidget(shell(const Scaffold(
        body: Center(
            child: GoldStepper(value: 2, decrease: null, increase: null)))));
    await tester.pumpAndSettle();
    await expectLater(find.byType(GoldStepper),
        matchesGoldenFile('goldens/sprint100_visual_stepper.png'));
    final buttons = tester.widgetList<IconButton>(find.descendant(
        of: find.byType(GoldStepper), matching: find.byType(IconButton)));
    expect(buttons.every((button) => button.onPressed == null), true);
  });

  testWidgets(
      'seven actual Flutter screens at reference viewport; synthetic data and no Firebase initialization',
      (tester) async {
    const width = int.fromEnvironment('SPRINT100_WIDTH', defaultValue: 432);
    const height = int.fromEnvironment('SPRINT100_HEIGHT', defaultValue: 768);
    tester.view.physicalSize = const Size(width * 2.0, height * 2.0);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final products = [
      sample('water', 'Água mineral', 'Gelo & Conveniência'),
      sample('snack', 'Snack de teste', 'Snacks & Doces'),
      sample('juice', 'Suco de teste', 'Refrigerantes & Sucos'),
      sample('restricted', 'RESTRITO NÃO EXPOR', 'Geral', alcohol: true)
    ];
    expect(Firebase.apps, isEmpty);
    await tester.pumpWidget(
        shell(DeliveryHomeScreen(products: Stream.value(products))));
    await tester.pumpAndSettle();
    expect(find.text('RESTRITO NÃO EXPOR'), findsNothing);
    await capture(tester, '01_HOME');
    await tester.tap(find.text('Categorias').last);
    await tester.pumpAndSettle();
    await capture(tester, '02_CATEGORIAS');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(shell(ProductDetailScreen(
        product: products.first, remaining: () => 5, add: (_) => true)));
    await tester.pumpAndSettle();
    await capture(tester, '03_PRODUTO');
    final items = [
      CartItem(
          id: 'water',
          name: 'Água mineral',
          price: 10,
          imageUrl: '',
          quantity: 2),
      CartItem(id: 'snack', name: 'Snack de teste', price: 10, imageUrl: '')
    ];
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(shell(CartScreen(
        items: () => items,
        change: (_, __) {},
        checkout: () {},
        destination: testCustomerAddress,
        quoter: LocalQuote())));
    await tester.pumpAndSettle();
    await capture(tester, '04_CARRINHO');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(shell(CheckoutScreen(
        cartItems: items,
        onCartCleared: () {},
        deliveryAddress: testCustomerAddress,
        quoter: LocalQuote(),
        verification: LocalVerifiedAccount())));
    await tester.pumpAndSettle();
    expect(find.text('Dividir pagamento'), findsNothing);
    expect(find.byType(AgeVerificationCard), findsNothing);
    await capture(tester, '05_CHECKOUT');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(shell(TrackingView(
        orderId: 'SYNTHETIC-LOCAL',
        onBack: () {},
        orderStream: Stream.value({
          'id': 'SYNTHETIC-LOCAL',
          'status': 'Saiu para Entrega',
          'financialValidationStatus': 'validated',
          'paymentMethod': 'Dinheiro',
          'address': 'Rua de teste, 1',
          'itemsTotal': 30,
          'deliveryFee': 5,
          'customerFee': .3,
          'totalBRL': 35.3,
          'itemsList': [
            {'name': 'Água mineral', 'quantity': 2}
          ]
        }))));
    await tester.pumpAndSettle();
    await capture(tester, '06_PEDIDO');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(shell(CustomerProfileScreen(
        selectAddress: () async {},
        onboarding: FlowOnboarding(accepted: true))));
    await tester.pumpAndSettle();
    await capture(tester, '07_PERFIL');
    expect(Firebase.apps, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
