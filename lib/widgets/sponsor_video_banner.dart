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
      await _controller.initialize();

      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();

      if (!mounted) return;

      setState(() {
        _videoReady = true;
      });
    } catch (e) {
      debugPrint('Erro ao carregar vídeo patrocinado: $e');
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
      height: 125,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
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
          : const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFCC00),
                strokeWidth: 2,
              ),
            ),
    );
  }
}