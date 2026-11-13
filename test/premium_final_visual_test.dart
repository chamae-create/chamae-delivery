@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/widgets/commerce_components.dart';
import 'package:chamae_delivery/widgets/product_image.dart';
import 'package:chamae_delivery/core/theme.dart';

void main() {
  testWidgets('neutral carousel pages and indicators follow actual swipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: ConvenienceCampaign()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SEU DIA PEDE'), findsOneWidget);
    final pager = find.byKey(const ValueKey('premium-campaign-carousel'));
    await tester.drag(pager, const Offset(-420, 0));
    await tester.pumpAndSettle();
    expect(find.text('ESCOLHA DO SEU JEITO'), findsOneWidget);
    expect(find.textContaining('cerveja'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'category count and action remain real with unavailable photography',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 195,
                height: 126,
                child: CategoryBannerTile(
                  title: 'Snacks & Doces',
                  count: 7,
                  imageUrl: '',
                  onTap: () => opened++,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('7 produtos'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.text('Snacks & Doces'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog photograph uses contain and eight percent inset', (
    tester,
  ) async {
    // Transparent one-pixel image tests layout only; it is never a product asset.
    final bytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: ProductImage(
                url: 'data:image/png;base64,${base64Encode(bytes)}',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(tester.getSize(find.byType(Image)), const Size(168, 168));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
