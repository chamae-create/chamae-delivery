import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/screens/customer_onboarding_screen.dart';
import 'support/customer_flow_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = Platform.environment['FLUTTER_TEST_FONTS'];
    if (fonts != null) {
      for (final entry in [('Roboto', 'roboto-regular.ttf'), ('MaterialIcons', 'materialicons-regular.otf')]) {
        final loader = FontLoader(entry.$1);
        loader.addFont(File('$fonts/${entry.$2}').readAsBytes().then((b) => ByteData.sublistView(b)));
        await loader.load();
      }
    }
  });
  for (final scenario in [(390.0, 844.0, 1.0, 'pt'), (320.0, 640.0, 2.0, 'es'), (900.0, 900.0, 1.0, 'pt')]) {
    testWidgets('approved onboarding ${scenario.$1} text ${scenario.$3} ${scenario.$4}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(scenario.$1, scenario.$2);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repository = FlowOnboarding();
      var completed = false;
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        locale: Locale(scenario.$4),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scenario.$3)), child: child!),
        home: RepaintBoundary(key: key, child: CustomerOnboardingScreen(
          state: const CustomerOnboardingState(testCustomerPolicy, {}), repository: repository,
          onComplete: () => completed = true)),
      ));
      await tester.pumpAndSettle();
      for (final label in ['Li e aceito os Termos de Uso', 'Li e estou ciente da Política de Privacidade', 'Estou ciente das regras para bebidas alcoólicas']) {
        final finder = find.text(localizedLabel(key.currentContext!, label));
        await tester.scrollUntilVisible(finder, 180, scrollable: find.byType(Scrollable).first);
        final tile = tester.widget<CheckboxListTile>(find.ancestor(of: finder, matching: find.byType(CheckboxListTile)));
        expect(tile.value, isFalse);
        expect(tester.takeException(), isNull);
      }
      expect(repository.acceptCalls, 0);
      final heading = find.text(localizedLabel(key.currentContext!, 'Vamos começar'));
      await tester.scrollUntilVisible(heading, -250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      Scrollable.of(tester.element(heading)).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await precacheImage(const AssetImage('assets/images/onboarding/approved_onboarding_reference.png'), key.currentContext!);
      });
      await tester.pumpAndSettle();
      final directory = Platform.environment['CHAMAE_CAPTURE_DIR'];
      if (directory != null) {
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$directory/onboarding-${scenario.$1.toInt()}-${scenario.$4}.png').writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      final button = find.byType(ElevatedButton);
      await tester.scrollUntilVisible(button, 250, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.acceptCalls, 0);
      expect(completed, isFalse);
      expect(developmentCustomerPolicy.canContinueOnboarding(debugMode: false), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
