import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/l10n/locale_controller.dart';
import 'package:chamae_delivery/screens/customer_onboarding_screen.dart';
import 'package:chamae_delivery/screens/legal_document_screen.dart';
import 'support/customer_flow_fakes.dart';

class PendingOnboarding extends FlowOnboarding {
  final result = Completer<void>();
  @override
  Future<void> acceptForNavigation(
      CustomerPolicy policy, NavigationAgeDeclaration declaration) async {
    await result.future;
    await super.acceptForNavigation(policy, declaration);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Roboto', 'CHAMAE_ROBOTO_FONT'),
      ('MaterialIcons', 'CHAMAE_ICONS_FONT')
    ]) {
      final file = Platform.environment[font.$2];
      if (file != null) {
        final loader = FontLoader(font.$1);
        loader.addFont(File(file).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
  });
  Future<void> show(
      WidgetTester tester, FlowOnboarding repository, GlobalKey boundary,
      {double width = 390,
      double height = 844,
      double scale = 1,
      String language = 'pt'}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = LocaleController(
        stored: language == 'es' ? 'es-PY' : 'pt-BR', persist: (_) async {});
    addTearDown(controller.dispose);
    await tester.pumpWidget(LocaleScope(
        controller: controller,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 47, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
                  textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: boundary,
              child: CustomerOnboardingScreen(
                  state: CustomerOnboardingState(repository.policy, {}),
                  repository: repository,
                  onComplete: () {})),
        )));
    await tester.pumpAndSettle();
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/onboarding/official_app_icon.png'),
        boundary.currentContext!));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 180,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    final tiles = find.byType(CheckboxListTile);
    expect(tiles, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      await tapVisible(tester,
          find.descendant(of: tiles.at(i), matching: find.byType(Checkbox)));
    }
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final dir = Platform.environment['CHAMAE_CAPTURE_DIR'];
    if (dir == null) return;
    final oldShadows = debugDisableShadows;
    try {
      // Test bindings disable blur by default. Capture the same shadows as the app.
      debugDisableShadows = false;
      for (final view in tester.binding.renderViews) {
        view.reassemble();
      }
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    } finally {
      debugDisableShadows = oldShadows;
      for (final view in tester.binding.renderViews) {
        view.reassemble();
      }
      await tester.pumpAndSettle();
    }
  }

  for (final size in [
    (390.0, 844.0, 1.0, 'pt'),
    (320.0, 640.0, 2.0, 'es'),
    (430.0, 932.0, 1.0, 'pt'),
    (900.0, 900.0, 1.0, 'pt'),
    (390.0, 844.0, 2.0, 'pt'),
    (390.0, 844.0, 1.0, 'es'),
    (430.0, 932.0, 2.0, 'es'),
    (320.0, 640.0, 1.0, 'pt')
  ]) {
    testWidgets('premium native ${size.$1} ${size.$4} scale ${size.$3}',
        (tester) async {
      final repo = FlowOnboarding(identified: false), key = GlobalKey();
      await show(tester, repo, key,
          width: size.$1, height: size.$2, scale: size.$3, language: size.$4);
      expect(find.byType(TextField), findsNothing);
      final tiles = find.byType(CheckboxListTile);
      expect(tiles, findsNWidgets(4));
      for (final tile in tester.widgetList<CheckboxListTile>(tiles)) {
        expect(tile.value, isFalse,
            reason:
                'New users never start with a declaration or consent selected');
      }

      expect(find.text('Etapa 1 de 2'), findsNothing);
      final button = find.byKey(const Key('onboarding-continue'));
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await capture(tester, key,
          'premium-${size.$1.toInt()}-${size.$4}-s${size.$3.toInt()}-top');
      for (var i = 1; i < 4; i++) {
        final documentLink = find
            .descendant(of: tiles.at(i), matching: find.byType(TextButton))
            .first;
        await tapVisible(tester, documentLink);
        expect(find.byType(LegalDocumentScreen), findsOneWidget);
        final backLabel = MaterialLocalizations.of(
                tester.element(find.byType(LegalDocumentScreen)))
            .backButtonTooltip;
        final back = find.byTooltip(backLabel);
        expect(back.hitTestable(), findsOneWidget);
        await tester.tap(back);
        await tester.pumpAndSettle();
      }
      for (final tile in tester.widgetList<CheckboxListTile>(tiles)) {
        expect(tile.value, isFalse,
            reason: 'Opening a document never records agreement');
      }
      await confirm(tester);
      await tester.scrollUntilVisible(button, 180,
          scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(button), alignment: .5);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
      expect(button.hitTestable(), findsOneWidget);
      await capture(tester, key,
          'premium-${size.$1.toInt()}-${size.$4}-s${size.$3.toInt()}-selected');
      expect(repo.acceptCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'PY changes threshold, clears declaration and keeps official button blocked',
      (tester) async {
    final repo = FlowOnboarding(identified: false);
    await show(tester, repo, GlobalKey());
    await tapVisible(
        tester, find.byKey(const Key('navigation-age-declaration')));
    final country = find.byKey(const Key('navigation-jurisdiction'));
    await tapVisible(tester, country);
    await tester.tap(find.text('Paraguay').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const Key('navigation-age-declaration')))
            .value,
        isFalse);
    expect(find.text('Declaro ter pelo menos 20 anos.'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.byKey(const Key('onboarding-continue')))
            .onPressed,
        isNull);
    expect(repo.acceptCalls, 0);
  });
  testWidgets(
      'pending acceptance locks controls, exposes progress and recovers from an error',
      (tester) async {
    final repo = PendingOnboarding();
    await show(tester, repo, GlobalKey());
    await confirm(tester);
    final next = find.byKey(const Key('onboarding-continue'));
    await tester.scrollUntilVisible(next, 200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(next), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
    for (final tile
        in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) {
      expect(tile.onChanged, isNull);
    }
    repo.result.completeError(StateError('synthetic connectivity failure'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Não foi possível registrar o aceite'),
        findsOneWidget);
    expect(tester.widget<ElevatedButton>(next).onPressed, isNotNull);
    expect(repo.acceptCalls, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'premium iOS visible targets have labels and accessible touch areas',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await show(tester, FlowOnboarding(identified: false), GlobalKey());
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      final next = find.byKey(const Key('onboarding-continue'));
      await tester.scrollUntilVisible(next, 220,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
}
