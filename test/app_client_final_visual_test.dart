@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'app_client_final_test.dart' as fixtures;
import 'customer_visual_freeze_test.dart' as visuals;

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

  testWidgets(
      'final confirmation and tracking expose real state in compact layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(visuals.app(
        TrackingView(
            orderId: '#TEST-24',
            onBack: () {},
            showConfirmation: true,
            orderStream: Stream.value(fixtures.confirmedOrder(pix: true))),
        1));
    await tester.pumpAndSettle();
    await visuals.capture(tester, 'confirmation_390');
    await tester.scrollUntilVisible(find.text('Acompanhar pedido'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await visuals.capture(tester, 'confirmation_cta_390');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(visuals.app(
        TrackingView(
            orderId: '#TEST-24',
            onBack: () {},
            orderStream: Stream.value(
                {...fixtures.confirmedOrder(), 'status': 'Saiu para Entrega'})),
        1));
    await tester.pumpAndSettle();
    await visuals.capture(tester, 'tracking_390_final');
    await tester.scrollUntilVisible(find.text('STATUS DO PEDIDO'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await visuals.capture(tester, 'tracking_progress_390');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
