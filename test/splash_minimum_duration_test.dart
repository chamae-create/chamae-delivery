import 'dart:async';
import 'package:chamae_delivery/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> show(WidgetTester t, Future<void> Function() initialize,
    {bool reduced = false, Widget? destination}) async {
  await t.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: SplashScreen(initialize: initialize,
      destination: destination ?? const Scaffold(body: Text('destination'))),
  ));
}

void main() {
  testWidgets('fast cold start waits exactly for first-frame minimum', (t) async {
    await show(t, () async {});
    await t.pump(const Duration(milliseconds: 2999));
    expect(find.text('destination'), findsNothing);
    await t.pump(const Duration(milliseconds: 1));
    await t.pump();
    expect(find.text('destination'), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('slow initialization has no additional three seconds', (t) async {
    final ready = Completer<void>();
    await show(t, () => ready.future);
    await t.pump(const Duration(seconds: 5));
    expect(find.text('destination'), findsNothing);
    ready.complete();
    await t.pump();
    await t.pump();
    await t.pump(const Duration(milliseconds: 1));
    expect(find.text('destination'), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('minimum begins at presentation not before first frame', (t) async {
    // The widget is first presented by pumpWidget; no init-dependent restart.
    final ready = Completer<void>();
    await show(t, () => ready.future);
    await t.pump(const Duration(seconds: 2));
    ready.complete();
    await t.pump();
    await t.pump(const Duration(milliseconds: 999));
    expect(find.text('destination'), findsNothing);
    await t.pump(const Duration(milliseconds: 1));
    await t.pump();
    expect(find.text('destination'), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('reduced motion preserves duration without animation', (t) async {
    await show(t, () async {}, reduced: true);
    await t.pump(const Duration(milliseconds: 2999));
    expect(find.text('destination'), findsNothing);
    await t.pump(const Duration(milliseconds: 1));
    await t.pump();
    expect(find.text('destination'), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('failure and immediate recovery never wait for deadline', (t) async {
    var calls = 0;
    await show(t, () async { if (++calls == 1) throw StateError('offline'); });
    await t.pump();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await t.tap(find.text('Tentar novamente'));
    await t.pump();
    await t.pump();
    expect(find.text('destination'), findsOneWidget);
    expect(calls, 2);
    await t.pumpAndSettle();
  });

  testWidgets('background resume does not restart elapsed minimum', (t) async {
    final ready = Completer<void>();
    await show(t, () => ready.future);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump(const Duration(seconds: 4));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    ready.complete();
    await t.pump();
    await t.pump();
    expect(find.text('destination'), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('login and subsequent navigation do not repeat splash', (t) async {
    var initialized = 0;
    await show(t, () async { initialized++; }, destination: Builder(
      builder: (context) => Scaffold(body: TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('session')))),
        child: const Text('login')))));
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    await t.tap(find.text('login'));
    await t.pumpAndSettle();
    expect(find.text('session'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(initialized, 1);
  });

  testWidgets('dispose cancels deadline and late initialization safely', (t) async {
    final ready = Completer<void>();
    await show(t, () => ready.future);
    await t.pumpWidget(const SizedBox());
    ready.complete();
    await t.pump(const Duration(seconds: 4));
    expect(t.takeException(), isNull);
  });
}
