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
    return Container(
      height: (MediaQuery.sizeOf(context).width * .48).clamp(190.0, 360.0),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
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
                          colors: [Colors.transparent, Color(0xCC141414)]))),
              const Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text('Pit Stop V8 • Bebidas e conveniência',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800))),
              if (!_failed)
                const Positioned(
                    top: 16,
                    right: 16,
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFFFCC00)))),
            ]),
    );
  }
}
