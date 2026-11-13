import 'dart:async';
import 'package:chamae_delivery/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> showSplash(WidgetTester tester, Completer<void> ready,
    {double width = 360,
    double height = 640,
    bool reduced = false,
    double fontScale = 1}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              disableAnimations: reduced,
              textScaler: TextScaler.linear(fontScale)),
          child: child!),
      home: SplashScreen(
          initialize: () => ready.future,
          destination: const Scaffold(body: Text('Destino real pronto')))));
  // Decode the exact provider used on screen, then establish its first frame.
  await tester.runAsync(() => precacheImage(
      tester.widget<Image>(find.byType(Image)).image,
      tester.element(find.byType(Image))));
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(320, 640),
    const Size(440, 850),
    const Size(640, 360)
  ]) {
    testWidgets('premium artwork fits whole viewport proportionally at $size',
        (tester) async {
      final ready = Completer<void>();
      await showSplash(tester, ready, width: size.width, height: size.height);
      await tester.pump(const Duration(milliseconds: 2600));
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, SplashScreen.artwork);
      expect(image.fit, BoxFit.contain);
      expect(image.alignment, Alignment.center);
      final fitted =
          applyBoxFit(BoxFit.contain, SplashScreen.artworkSize, size);
      expect(fitted.source, SplashScreen.artworkSize);
      final destination =
          Alignment.center.inscribe(fitted.destination, Offset.zero & size);
      expect(destination.left, greaterThanOrEqualTo(0));
      expect(destination.top, greaterThanOrEqualTo(0));
      expect(destination.right, lessThanOrEqualTo(size.width));
      expect(destination.bottom, lessThanOrEqualTo(size.height));
      expect(find.text('Loumak'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('reduced motion presents intact art immediately', (tester) async {
    await showSplash(tester, Completer<void>(), reduced: true);
    expect(
        tester
            .widget<ScaleTransition>(find
                .ancestor(
                    of: find.byType(Image),
                    matching: find.byType(ScaleTransition))
                .first)
            .scale
            .value,
        1);
    expect(tester.widget<Image>(find.byType(Image)).opacity!.value, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'animation ends without repeating while initialization is pending',
      (tester) async {
    await showSplash(tester, Completer<void>());
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('Destino real pronto'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'ready initialization respects three seconds total',
      (tester) async {
    final ready = Completer<void>();
    await showSplash(tester, ready);
    ready.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('Destino real pronto'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Destino real pronto'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pumpAndSettle();
    expect(find.text('Destino real pronto'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('reduced motion preserves three second minimum',
      (tester) async {
    final ready = Completer<void>();
    await showSplash(tester, ready, reduced: true);
    ready.complete();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Destino real pronto'), findsOneWidget);
  });

  testWidgets('animation never bypasses pending initialization',
      (tester) async {
    final ready = Completer<void>();
    await showSplash(tester, ready);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Destino real pronto'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destino real pronto'), findsOneWidget);
  });

  testWidgets('completing after disposal does not navigate', (tester) async {
    final ready = Completer<void>();
    await showSplash(tester, ready);
    await tester.pumpWidget(const SizedBox());
    ready.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry remains accessible with large text and narrow viewport',
      (tester) async {
    final ready = Completer<void>();
    await showSplash(tester, ready, width: 320, fontScale: 2);
    ready.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.ensureVisible(find.text('Tentar novamente'));
    expect(find.text('Tentar novamente').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
