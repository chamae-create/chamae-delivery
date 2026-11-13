@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/screens/splash_screen.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'support/customer_flow_fakes.dart';

void main() {
  testWidgets('compact startup-to-checkout remains usable with fallback font',
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
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: CheckoutScreen(cartItems: [
          CartItem(
              id: 'local',
              name: 'Nome longo de produto para validar quebra de linha',
              price: 20,
              imageUrl: '',
              quantity: 2)
        ], onCartCleared: () {}, deliveryAddress: testCustomerAddress)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('PIX'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(432, 960)
  ]) {
    testWidgets('premium splash intact at $size, DPR 2, safe areas',
        (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 48);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final ready = Completer<void>();
      await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('premium-splash-capture'),
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: SplashScreen(initialize: () => ready.future))));
      await tester.runAsync(() => precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(Image))));
      await tester.pump(const Duration(milliseconds: 520));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(
          tester
              .widget<ScaleTransition>(find.byType(ScaleTransition).first)
              .scale
              .value,
          1);
      final fitted = applyBoxFit(BoxFit.contain, SplashScreen.artworkSize,
          Size(size.width, size.height - 48));
      expect(fitted.source, SplashScreen.artworkSize);
      expect(fitted.destination.width, lessThanOrEqualTo(size.width));
      expect(fitted.destination.height, lessThanOrEqualTo(size.height - 48));
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('SPRINT100_CAPTURE')) {
        await tester.runAsync(() async {
          final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('premium-splash-capture')));
          final bitmap = await boundary.toImage(pixelRatio: 2);
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(const String.fromEnvironment(
              'SPRINT100_CAPTURE_DIR',
              defaultValue:
                  'C:/Users/DELL/chamae_admin/docs/sprint100_visual_2026-11-09/screenshots'))
            ..createSync(recursive: true);
          File('${dir.path}/SPLASH_${size.width.toInt()}x${size.height.toInt()}.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
