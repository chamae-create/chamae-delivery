import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/l10n/locale_controller.dart';
import 'package:chamae_delivery/screens/customer_onboarding_screen.dart';
import 'support/customer_flow_fakes.dart';

class RejectedAcceptance extends FlowOnboarding {
  final Object error;
  int calls = 0;
  RejectedAcceptance(this.error);
  @override
  Future<void> acceptForNavigation(
      CustomerPolicy policy, NavigationAgeDeclaration declaration) async {
    calls++;
    throw error;
  }
}

void main() {
  for (final language in ['pt', 'es']) {
    testWidgets('permission denied guides account switch in $language',
        (tester) async {
      final repository = RejectedAcceptance(FirebaseFunctionsException(
          code: 'permission-denied', message: 'synthetic backend denial'));
      var completed = false, signedOut = false;
      await showOnboarding(tester, repository, language, () => completed = true,
          () => signedOut = true);
      expect(
          tester
              .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
              .every((tile) => tile.value == false),
          isTrue);
      await confirmAndSubmit(tester);
      expect(
          find.textContaining(language == 'es'
              ? 'cuenta exclusiva de Cliente'
              : 'conta exclusiva de Cliente'),
          findsOneWidget);
      expect(find.textContaining('synthetic backend denial'), findsNothing);
      expect(repository.calls, 1);
      expect(completed, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.byKey(const Key('onboarding-continue')))
              .onPressed,
          isNotNull);
      final screen = tester.widget<CustomerOnboardingScreen>(
          find.byType(CustomerOnboardingScreen));
      final exit = find.byWidgetPredicate((widget) =>
          widget is TextButton && widget.onPressed == screen.onSignOut);
      expect(exit, findsOneWidget);
      await tapVisible(tester, exit);
      expect(signedOut, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unknown failures keep existing safe fallback and never complete',
      (tester) async {
    final repository =
        RejectedAcceptance(StateError('private synthetic marker'));
    var completed = false;
    await showOnboarding(
        tester, repository, 'pt', () => completed = true, () {});
    await confirmAndSubmit(tester);
    expect(find.textContaining('Não foi possível registrar o aceite'),
        findsOneWidget);
    expect(find.textContaining('conta exclusiva de Cliente'), findsNothing);
    expect(find.textContaining('private synthetic marker'), findsNothing);
    expect(completed, isFalse);
    expect(repository.calls, 1);
  });
}

Future<void> showOnboarding(WidgetTester tester, FlowOnboarding repository,
    String language, VoidCallback complete, VoidCallback signOut) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
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
          home: CustomerOnboardingScreen(
              state: CustomerOnboardingState(repository.policy, {}),
              repository: repository,
              onComplete: complete,
              onSignOut: signOut))));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180,
      scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> confirmAndSubmit(WidgetTester tester) async {
  final tiles = find.byType(CheckboxListTile);
  expect(tiles, findsNWidgets(4));
  for (var i = 0; i < 4; i++) {
    await tapVisible(tester,
        find.descendant(of: tiles.at(i), matching: find.byType(Checkbox)));
  }
  await tapVisible(tester, find.byKey(const Key('onboarding-continue')));
}
