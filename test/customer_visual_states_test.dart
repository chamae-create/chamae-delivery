import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/screens/splash_screen.dart';
import 'package:chamae_delivery/screens/customer_login_screen.dart';
import 'package:chamae_delivery/screens/customer_onboarding_screen.dart';
import 'package:chamae_delivery/screens/address_destination_screen.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'customer_visual_freeze_test.dart' as visuals;
import 'support/customer_flow_fakes.dart';

Future<void> open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(visuals.app(screen, 1));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    const path = String.fromEnvironment('VISUAL_FONT_PATH');
    if (path.isEmpty) return;
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)
            ..addFont(Future.value(
                ByteData.sublistView(File(path).readAsBytesSync()))))
          .load();
    }
    final icons = File('${File(path).parent.path}/materialicons-regular.otf');
    await (FontLoader('MaterialIcons')
          ..addFont(
              Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  });
  void compact(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  }

  testWidgets('compact entrance screens and failure feedback', (tester) async {
    compact(tester);
    final ready = Completer<void>();
    await tester.pumpWidget(
        visuals.app(SplashScreen(initialize: () => ready.future), 1));
    await tester.pump(const Duration(seconds: 1));
    await visuals.capture(tester, 'splash_loading_360');
    ready.completeError(StateError('fixture offline'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await visuals.capture(tester, 'splash_error_360');
    final auth = FlowAuth()..fail = true;
    addTearDown(auth.events.close);
    await open(tester, CustomerLoginScreen(auth: auth));
    await visuals.capture(tester, 'login_360');
    await tester.ensureVisible(find.text('Continuar com Google'));
    await tester.tap(find.text('Continuar com Google'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Não foi possível entrar agora'), findsOneWidget);
    await visuals.capture(tester, 'login_error_360');
    final onboarding = FlowOnboarding();
    await open(
        tester,
        CustomerOnboardingScreen(
            state: CustomerOnboardingState(onboarding.policy, {}),
            repository: onboarding,
            onComplete: () {}));
    await visuals.capture(tester, 'onboarding_360');
    await tester.scrollUntilVisible(find.text('Continuar'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await visuals.capture(tester, 'onboarding_footer_360');
    await open(
        tester,
        AddressDestinationScreen(
            onboarding: false,
            workspace: FlowWorkspace(),
            mapPicker: (_, __) async => null));
    await visuals.capture(tester, 'address_empty_360');
    await open(
        tester,
        CustomerProfileScreen(
            selectAddress: () async {},
            onboarding: FlowOnboarding(accepted: true)));
    await tester.ensureVisible(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    expect(find.text('Sair da conta').hitTestable(), findsOneWidget);
    await visuals.capture(tester, 'profile_footer_360');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('compact catalog empty, error and loading states',
      (tester) async {
    compact(tester);
    for (final (name, stream) in <(String, Stream<List<Product>>)>[
      ('empty', Stream.value([])),
      ('error', Stream.error(StateError('fixture offline'))),
    ]) {
      await open(tester, DeliveryHomeScreen(products: stream));
      final target = name == 'empty'
          ? find.text('Nenhum produto encontrado.')
          : find.text('Não foi possível carregar os produtos.');
      await tester.scrollUntilVisible(target, 200,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await visuals.capture(tester, 'home_${name}_360');
    }
    final pending = StreamController<List<Product>>();
    addTearDown(pending.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
        visuals.app(DeliveryHomeScreen(products: pending.stream), 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.byType(CircularProgressIndicator), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    await visuals.capture(tester, 'home_loading_360');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('compact cart empty and tracking unavailable states',
      (tester) async {
    compact(tester);
    await open(tester,
        CartScreen(items: () => [], change: (_, __) {}, checkout: () {}));
    expect(find.text('Seu carrinho está vazio.'), findsOneWidget);
    await visuals.capture(tester, 'cart_empty_360');
    for (final (name, stream) in <(String, Stream<Map<String, dynamic>?>)>[
      ('unavailable', Stream.value(null)),
      ('error', Stream.error(StateError('fixture offline'))),
    ]) {
      await open(
          tester,
          TrackingView(
              orderId: 'TEST',
              orderStream: stream,
              onBack: () {},
              onRetry: () {}));
      await visuals.capture(tester, 'tracking_${name}_360');
    }
    final pending = StreamController<Map<String, dynamic>?>();
    addTearDown(pending.close);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(visuals.app(
        TrackingView(
            orderId: 'TEST', orderStream: pending.stream, onBack: () {}),
        1));
    await tester.pump();
    await visuals.capture(tester, 'tracking_loading_360');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
