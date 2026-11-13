import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/screens/splash_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Isolated evidence harness: no Firebase, authentication or production data.
// The 1100ms local initializer is a fixture, never a production splash delay.
final navigator = GlobalKey<NavigatorState>();
final frames = <ui.FrameTiming>[];
final metrics = ValueNotifier<String>('Medição pendente');
final keys = {
  LogicalKeyboardKey.f1: '/',
  LogicalKeyboardKey.f2: '/hold',
  LogicalKeyboardKey.f3: '/error',
  LogicalKeyboardKey.f4: '/fast',
  LogicalKeyboardKey.f5: '/reduced',
};

void reportFrames() {
  if (frames.isEmpty) return;
  final build =
      frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList();
  final raster =
      frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList();
  final hz = ui.PlatformDispatcher.instance.views.first.display.refreshRate;
  final budget = 1000 / hz;
  final result = jsonEncode({
    'refreshHz': hz,
    'budgetMs': budget,
    'buildOverBudget': build.where((v) => v > budget).length,
    'rasterOverBudget': raster.where((v) => v > budget).length,
    'firstRasterMs': raster.first,
    'frames': frames.length,
    'buildOver16_67ms': build.where((v) => v > 16.67).length,
    'rasterOver16_67ms': raster.where((v) => v > 16.67).length,
    'maxBuildMs': build.reduce((a, b) => a > b ? a : b),
    'maxRasterMs': raster.reduce((a, b) => a > b ? a : b),
  });
  metrics.value =
      const JsonEncoder.withIndent('  ').convert(jsonDecode(result));
  debugPrint('SPLASH_FRAME_TIMINGS $result');
}

void main() {
  if (kReleaseMode) {
    throw UnsupportedError('Visual evidence harness cannot run in release.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addTimingsCallback(frames.addAll);
  HardwareKeyboard.instance.addHandler((event) {
    final route = keys[event.logicalKey];
    if (event is! KeyDownEvent || route == null) return false;
    frames.clear();
    navigator.currentState?.pushReplacementNamed(route);
    return true;
  });
  runApp(MaterialApp(
    navigatorKey: navigator,
    initialRoute: '/',
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    onGenerateRoute: (settings) {
      final route = settings.name ?? '/';
      final hold = Completer<void>();
      Future<void> initialize() async {
        final watch = Stopwatch()..start();
        debugPrint('SPLASH_INITIALIZE_BEGIN route=$route');
        if (route == '/hold' || route == '/reduced') {
          unawaited(
              Future<void>.delayed(const Duration(seconds: 3), reportFrames));
          return hold.future;
        }
        if (route == '/error') throw StateError('Local offline fixture');
        if (route != '/fast') {
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }
        debugPrint(
            'SPLASH_INITIALIZE_READY localMs=${watch.elapsedMilliseconds}');
        unawaited(
            Future<void>.delayed(const Duration(seconds: 3), reportFrames));
      }

      return PageRouteBuilder<void>(
        settings: settings,
        transitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: route == '/reduced'),
          child: SplashScreen(
            initialize: initialize,
            destination: Scaffold(
              body: Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: ValueListenableBuilder<String>(
                  valueListenable: metrics,
                  builder: (context, value, child) => Text(
                    'Fim da abertura — evidência local\n\n$value',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )),
            ),
          ),
        ),
      );
    },
  ));
}
