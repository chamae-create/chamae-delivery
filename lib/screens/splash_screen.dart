import 'package:flutter/material.dart';
import '../core/theme.dart';
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
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
    _start();
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    try {
      await widget.initialize();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: Center(
                  child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = MediaQuery.disableAnimationsOf(context)
                  ? 1.0
                  : Curves.easeOut.transform(_controller.value);
              return Opacity(
                  opacity: t,
                  child: Transform.scale(scale: .985 + .015 * t, child: child));
            },
            child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: DecoratedBox(
                    decoration: BoxDecoration(boxShadow: [
                      BoxShadow(
                          color: AppTheme.primaryYellow.withValues(alpha: .07),
                          blurRadius: 40),
                    ]),
                    child: Image.asset('assets/images/logo.png',
                        semanticLabel:
                            'Chamaê Delivery. Bebidas e conveniência.',
                        fit: BoxFit.contain))),
          ))),
          if (_failed) ...[
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                    'Não foi possível conectar. Confira sua internet e tente novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white))),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _start, child: const Text('Tentar novamente')),
          ] else
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryYellow)),
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Loumak',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12, letterSpacing: 2))),
        ])),
      );
}
