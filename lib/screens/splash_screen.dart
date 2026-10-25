import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'customer_session_gate.dart';

class SplashScreen extends StatefulWidget {
  final Future<void> Function() initialize;
  final Widget destination;
  const SplashScreen(
      {super.key,
      required this.initialize,
      this.destination = const CustomerSessionGate()});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<void> _visualFinished;
  late final Animation<double> _fade;
  late final Animation<double> _zoom;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _visualFinished = _controller
        .forward()
        .orCancel
        .onError<TickerCanceled>((error, stack) {});
    _fade = _controller.drive(Tween<double>(begin: .01, end: 1).chain(
        CurveTween(curve: const Interval(0, .18, curve: Curves.easeOut))));
    _zoom = _controller.drive(Tween<double>(begin: 1, end: 1.008)
        .chain(CurveTween(curve: Curves.easeOutCubic)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    try {
      await widget.initialize();
      if (!mounted) return;
      // Initialization runs concurrently with the finite visual sequence.
      if (!MediaQuery.disableAnimationsOf(context) &&
          !_controller.isCompleted) {
        await _visualFinished;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => widget.destination,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFE3A921),
          systemNavigationBarIconBrightness: Brightness.dark),
      child: Scaffold(
          backgroundColor: const Color(0xFFEAB124),
          body: LayoutBuilder(builder: (context, constraints) {
            final size = constraints.biggest;
            // Cover removes only peripheral gold at the top on NUU M2.
            // Bottom alignment preserves the mark, tagline and Loumak.
            final fitted =
                applyBoxFit(BoxFit.cover, const Size(740, 1600), size);
            final source = Alignment.bottomCenter
                .inscribe(fitted.source, Offset.zero & const Size(740, 1600));
            final artRect = Rect.fromLTWH(
                0,
                -source.top * size.width / source.width,
                size.width,
                1600 * size.width / source.width);
            final reduced = MediaQuery.disableAnimationsOf(context);
            return ClipRect(
                child: Stack(fit: StackFit.expand, children: [
              Positioned.fill(
                  child: RepaintBoundary(
                      child: ScaleTransition(
                          alignment: Alignment.bottomCenter,
                          scale: reduced
                              ? const AlwaysStoppedAnimation(1.0)
                              : _zoom,
                          child: RepaintBoundary(
                              child: Image.asset(
                                  'assets/images/splash/chamae_official_gold_2026_10_21.jpeg',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.low,
                                  alignment: Alignment.bottomCenter,
                                  cacheWidth: (size.width *
                                          MediaQuery.devicePixelRatioOf(
                                              context))
                                      .ceil()
                                      .clamp(1, 740),
                                  opacity: _fade,
                                  gaplessPlayback: true,
                                  semanticLabel:
                                      'Chama\u00ea Delivery. Bebidas e conveni\u00eancia.'))))),
              if (!reduced)
                Positioned.fill(
                    child: IgnorePointer(
                        child: RepaintBoundary(
                            child: CustomPaint(
                                painter: _BrandLight(_controller, artRect))))),
              if (_failed)
                SafeArea(
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Material(
                                color: const Color(0xFFFFF8DD),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                              'Não foi possível conectar. Confira sua internet e tente novamente.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Color(0xFF191816))),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                              onPressed: _start,
                                              child: const Text(
                                                  'Tentar novamente')),
                                        ])))))),
              if (!_failed)
                Semantics(
                    liveRegion: true,
                    label: 'Iniciando aplicativo. Loumak Tecnologia.',
                    child: const SizedBox.shrink()),
            ]));
          })));
}

// Finite light pass and eight deterministic glints; no blur or repeating ticker.
class _BrandLight extends CustomPainter {
  final Animation<double> animation;
  final Rect art;
  _BrandLight(this.animation, this.art) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= .12 || t >= 1) return;
    final envelope = math.sin(math.pi * (t - .12) / .88);
    final progress = ((t - .18) / .65).clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final beam = Rect.fromCenter(
        center: Offset(
            art.width * (-.2 + 1.4 * progress), art.top + art.height * .44),
        width: art.width * .23,
        height: art.height * .32);
    canvas.drawOval(
        beam,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFF3BB).withValues(alpha: .32 * envelope),
            const Color(0xFFFFDE71).withValues(alpha: 0),
          ]).createShader(beam));
    for (var i = 0; i < 8; i++) {
      final x = size.width * (.10 + ((i * .137 + t * .025) % .8));
      final y = size.height * (.25 + (i % 4) * .14 - t * .035);
      final alpha = envelope * (.25 + .18 * math.sin(i + t * math.pi));
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.4 : .9,
          Paint()..color = const Color(0xFFFFF6C4).withValues(alpha: alpha));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandLight oldDelegate) =>
      oldDelegate.art != art || oldDelegate.animation != animation;
}
