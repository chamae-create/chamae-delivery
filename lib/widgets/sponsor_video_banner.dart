import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SponsorVideoBanner extends StatefulWidget {
  const SponsorVideoBanner({super.key});

  @override
  State<SponsorVideoBanner> createState() => _SponsorVideoBannerState();
}

class _SponsorVideoBannerState extends State<SponsorVideoBanner> {
  late final VideoPlayerController _controller;
  bool _videoReady = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/images/pitstop_promo.mp4',
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 12));
      if (!mounted) return;

      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();

      if (!mounted) return;

      setState(() {
        _videoReady = true;
      });
    } catch (e) {
      debugPrint('Erro ao carregar vídeo patrocinado: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: CustomPaint(
            foregroundPainter: const _HomeHeroBorder(),
            child: ClipPath(
                clipper: const _HomeHeroClipper(),
                child: Container(
                  height: (MediaQuery.sizeOf(context).width * .56)
                      .clamp(190.0, 300.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFFCC00),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _videoReady
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final videoSize = _controller.value.size;

                            return FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: videoSize.width,
                                height: videoSize.height,
                                child: VideoPlayer(_controller),
                              ),
                            );
                          },
                        )
                      : Stack(fit: StackFit.expand, children: [
                          Image.asset('assets/images/splash_bg.png',
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -.65),
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Colors.black)),
                          const DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                Colors.transparent,
                                Color(0xCC141414)
                              ]))),
                          const Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Text(
                                  'Pit Stop V8 • Bebidas e conveniência',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800))),
                          if (!_failed)
                            const Positioned(
                                top: 16,
                                right: 16,
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFFCC00)))),
                        ]),
                ))));
  }
}

// Home-only silhouette; the video lifecycle above remains unchanged.
class _HomeHeroClipper extends CustomClipper<Path> {
  const _HomeHeroClipper();
  static Path outline(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(0, 24)
      ..quadraticBezierTo(0, 0, 24, 0)
      ..lineTo(w - 24, 0)
      ..quadraticBezierTo(w, 0, w, 24)
      ..lineTo(w, h - 24)
      ..quadraticBezierTo(w, h - 6, w - 24, h - 6)
      ..cubicTo(w * .68, h - 22, w * .32, h + 4, 24, h - 6)
      ..quadraticBezierTo(0, h - 8, 0, h - 24)
      ..close();
  }

  @override
  Path getClip(Size size) => outline(size);
  @override
  bool shouldReclip(_HomeHeroClipper oldClipper) => false;
}

class _HomeHeroBorder extends CustomPainter {
  const _HomeHeroBorder();
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
      _HomeHeroClipper.outline(size),
      Paint()
        ..color = const Color(0xFFFFCC00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
  @override
  bool shouldRepaint(_HomeHeroBorder oldDelegate) => false;
}
