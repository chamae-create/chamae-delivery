import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'customer_session_gate.dart';

class SplashScreen extends StatefulWidget {
  static const artwork = 'assets/Cartaz Chamaê Delivery em Degradê.png';
  static const artworkSize = Size(941, 1672);
  final Future<void> Function() initialize;
  final Widget destination;
  const SplashScreen({
    super.key,
    required this.initialize,
    this.destination = const CustomerSessionGate(),
  });
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _minimumVisible = Completer<void>();
  Timer? _minimumTimer;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _zoom;
  bool _failed = false, _initializing = false, _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = _controller.drive(CurveTween(curve: Curves.easeOut));
    _zoom = _controller.drive(
      Tween<double>(
        begin: .98,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    // Count from the first presented frame, in parallel with initialization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _minimumTimer = Timer(const Duration(seconds: 3), () {
        if (!_minimumVisible.isCompleted) _minimumVisible.complete();
      });
    });
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_animationStarted) {
      _controller.forward();
    }
    _animationStarted = true;
  }

  Future<void> _start() async {
    if (_initializing) return;
    _initializing = true;
    final recovering = _failed;
    if (_failed) setState(() => _failed = false);
    try {
      await widget.initialize();
      if (!mounted) return;
      // Errors/recovery are never held behind the presentation deadline.
      if (!recovering) await _minimumVisible.future;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          pageBuilder: (_, __, ___) => widget.destination,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _initializing = false;
    }
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    if (!_minimumVisible.isCompleted) _minimumVisible.complete();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final composition = LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final frame = SplashBackdrop.artworkRect(
          viewport,
          MediaQuery.paddingOf(context),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Container(
                key: const ValueKey('splash-responsive-background'),
                decoration: BoxDecoration(
                  gradient: SplashBackdrop.gradientFor(viewport, frame),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: frame,
              child: ScaleTransition(
                key: const ValueKey('splash-artwork-scale'),
                scale: reduced ? const AlwaysStoppedAnimation(1.0) : _zoom,
                child: ShaderMask(
                  key: const ValueKey('splash-peripheral-horizontal'),
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0, .035, .965, 1],
                  ).createShader(bounds),
                  child: ShaderMask(
                    key: const ValueKey('splash-peripheral-vertical'),
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: [0, .025, .975, 1],
                    ).createShader(bounds),
                    child: Image.asset(
                      SplashScreen.artwork,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      opacity: reduced
                          ? const AlwaysStoppedAnimation(1.0)
                          : _fade,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      semanticLabel: 'Chamaê Delivery. Bebidas e conveniência.',
                    ),
                  ),
                ),
              ),
            ),
            if (!_failed)
              Semantics(
                liveRegion: true,
                label: 'Iniciando aplicativo. Loumak Tecnologia.',
                child: const SizedBox.shrink(),
              ),
          ],
        );
      },
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: SplashBackdrop.edgeColors.first,
        body: !_failed
            ? composition
            : Column(
                children: [
                  Expanded(child: composition),
                  // Failure feedback gets its own layout space; it cannot hide Loumak.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .45,
                    ),
                    child: SafeArea(
                      top: false,
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
                                  style: TextStyle(color: Color(0xFF191816)),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _start,
                                  child: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Samples of the original outer left/right edges, averaged at each height.
/// The source PNG is unchanged. No brand lies in the narrow feathered margin.
abstract final class SplashBackdrop {
  static const edgePositions = [
    0.0,
    .05,
    .1,
    .2,
    .3,
    .4,
    .5,
    .6,
    .7,
    .8,
    .9,
    1.0,
  ];
  static const edgeColors = [
    Color(0xFFFDD707),
    Color(0xFFFED003),
    Color(0xFFFDBF02),
    Color(0xFFEDA202),
    Color(0xFFC37F01),
    Color(0xFF835401),
    Color(0xFF543501),
    Color(0xFF2F1C01),
    Color(0xFF140B01),
    Color(0xFF030100),
    Colors.black,
    Colors.black,
  ];

  static Rect artworkRect(Size viewport, EdgeInsets padding) {
    final available = Size(
      (viewport.width - padding.horizontal).clamp(0.0, viewport.width),
      (viewport.height - padding.vertical).clamp(0.0, viewport.height),
    );
    final fit = applyBoxFit(
      BoxFit.contain,
      SplashScreen.artworkSize,
      available,
    );
    return Alignment.center.inscribe(
      fit.destination,
      Rect.fromLTWH(
        padding.left,
        padding.top,
        available.width,
        available.height,
      ),
    );
  }

  static LinearGradient gradientFor(Size viewport, Rect artwork) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [edgeColors.first, ...edgeColors, edgeColors.last],
        stops: [
          0,
          for (final y in edgePositions)
            viewport.height == 0
                ? y
                : ((artwork.top + y * artwork.height) / viewport.height).clamp(
                    0.0,
                    1.0,
                  ),
          1,
        ],
      );
}
