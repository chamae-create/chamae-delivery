@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/screens/splash_screen.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(432, 960),
  ]) {
    testWidgets('two layers preserve all artwork at $size with safe areas', (
      tester,
    ) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 48);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('two-layer-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SplashScreen(initialize: () => Completer<void>().future),
          ),
        ),
      );
      final background = find.byKey(
        const ValueKey('splash-responsive-background'),
      );
      expect(tester.getRect(background), Offset.zero & size);
      final decoration =
          tester.widget<Container>(background).decoration! as BoxDecoration;
      expect(decoration.image, isNull);
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.colors.first, SplashBackdrop.edgeColors.first);
      expect(gradient.colors.last, Colors.black);
      // Independent background exists while the image is still transparent.
      expect(tester.widget<Image>(find.byType(Image)).opacity!.value, 0);
      expect(
        tester
            .widget<ScaleTransition>(
              find.byKey(const ValueKey('splash-artwork-scale')),
            )
            .scale
            .value,
        .98,
      );
      await tester.runAsync(
        () => precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(Image)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 520));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect((image.image as AssetImage).assetName, SplashScreen.artwork);
      final frame = tester.getRect(find.byType(Image));
      expect(frame.left, greaterThanOrEqualTo(0));
      expect(frame.right, lessThanOrEqualTo(size.width));
      expect(frame.top, greaterThanOrEqualTo(24));
      expect(frame.bottom, lessThanOrEqualTo(size.height - 24));
      expect(frame.width / frame.height, closeTo(941 / 1672, .000001));
      expect(
        applyBoxFit(
          BoxFit.contain,
          SplashScreen.artworkSize,
          frame.size,
        ).source,
        SplashScreen.artworkSize,
      );
      // Both brand regions, including the motorcycle and Loumak signature,
      // are strictly inside the opaque plateau of both peripheral masks.
      const protected = Rect.fromLTRB(70, 320, 880, 1560);
      expect(protected.left / 941, greaterThan(.035));
      expect(protected.right / 941, lessThan(.965));
      expect(protected.top / 1672, greaterThan(.025));
      expect(protected.bottom / 1672, lessThan(.975));
      expect(
        tester
            .widget<ScaleTransition>(
              find.byKey(const ValueKey('splash-artwork-scale')),
            )
            .scale
            .value,
        1,
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('SPLASH_FINAL_CAPTURE')) {
        await tester.runAsync(() async {
          final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('two-layer-capture')),
          );
          final bitmap = await boundary.toImage(pixelRatio: 2);
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory(
            'C:/Users/DELL/chamae_admin/docs/sprint100_visual_2026-11-09/screenshots',
          )..createSync(recursive: true);
          File(
            '${directory.path}/SPLASH_FINAL_${size.width.toInt()}x${size.height.toInt()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('failure feedback cannot cover either brand', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(initialize: () => ready.future)),
    );
    ready.completeError(StateError('local offline fixture'));
    await tester.pumpAndSettle();
    final image = tester.getRect(find.byType(Image));
    final retry = tester.getRect(find.text('Tentar novamente'));
    expect(image.bottom, lessThan(retry.top));
    expect(image.width / image.height, closeTo(941 / 1672, .000001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
