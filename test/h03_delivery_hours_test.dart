import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/store_hours.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/screens/home_screen.dart';

void main() {
  test('daily MS boundaries keep the real next opening in the notice', () {
    expect(deliveryHoursTimeZone, 'America/Campo_Grande');
    for (var day = 10; day < 17; day++) {
      final midnight = DateTime.utc(2026, 11, day, 4);
      final beforeOpening = DateTime.utc(2026, 11, day, 11, 59, 59);
      final opening = DateTime.utc(2026, 11, day, 12);
      final lastSecond = DateTime.utc(2026, 11, day + 1, 3, 59, 59);
      for (final closed in [midnight, beforeOpening]) {
        expect(isStoreOpen(closed), isFalse);
        expect(storeHoursNotice(closed),
            'Delivery todos os dias • 08h às 00h\nLoja fechada • abre às 08:00 (MS)');
      }
      for (final open in [opening, lastSecond]) {
        expect(isStoreOpen(open), isTrue);
        expect(storeHoursNotice(open), 'Delivery todos os dias • 08h às 00h');
      }
    }
    expect(isStoreOpen(DateTime.parse('2026-11-10T08:00:00-04:00')), isTrue);
    expect(isStoreOpen(DateTime.parse('2026-11-10T08:00:00-03:00')), isFalse);
  });

  testWidgets('closed notice is localized without losing reopening information',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es', 'PY'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
          builder: (context) => Text(localizedLabel(
              context, storeHoursNotice(DateTime.utc(2026, 11, 10, 4))))),
    ));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Delivery todos los días • 08h a 00h\nTienda cerrada • abre a las 08:00 (MS)'),
        findsOneWidget);
  });

  testWidgets('home omits decorative hours and keeps the catalog visible',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: DeliveryHomeScreen(
          products: Stream.value([
        Product(
            id: 'h03-local-only',
            name: 'Água de teste local',
            category: 'Refrigerantes & Sucos',
            price: 20,
            stock: 10,
            isActive: true,
            imageUrl: '',
            description: '',
            isOffer: false,
            isCombo: false,
            salesCount: 0),
      ])),
    ));
    await tester.pump(const Duration(seconds: 1));
    final notice = find.textContaining('Delivery todos os dias • 08h às 00h');
    expect(notice, findsNothing);
    await tester.scrollUntilVisible(find.text('Água de teste local').first, 250,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Água de teste local'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
