// lib/screens/intro_video_screen.dart
//
// Écran d'intro : joue la vidéo assets/videos/intro.mp4 AVEC LE SON,
// puis bascule vers l'app principale à la fin (ou bouton "Passer").
//
// Affiché au tout 1er démarrage (une fois par version, pour ne pas lasser).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class IntroVideoScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const IntroVideoScreen({super.key, required this.onFinished});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Mode immersif plein écran pendant l'intro
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset('assets/videos/intro.mp4');
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      controller.setVolume(1.0);
      controller.setLooping(false);
      setState(() => _initialized = true);
      // Petit délai pour laisser l'UI peindre la 1ère frame
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await controller.play();
      controller.setVolume(1.0);

      // À la fin de la vidéo → bascule vers l'app
      controller.addListener(() {
        final value = controller.value;
        if (value.position >= value.duration &&
            !_finished &&
            value.duration > Duration.zero) {
          _goNext();
        }
      });
    } catch (e) {
      // Si la vidéo ne charge pas, on passe directement à l'app
      _goNext();
    }
  }

  void _goNext() {
    if (_finished) return;
    _finished = true;
    // Restaurer l'UI système normale
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = _initialized && controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Vidéo plein écran via FittedBox + Center (compatible Android + Web)
          if (isReady)
            Center(
              child: AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else
            const SizedBox.shrink(), // fond noir pur pendant chargement

          // Bouton "Passer" (en bas à droite)
          Positioned(
            bottom: 40,
            right: 24,
            child: SafeArea(
              child: TextButton(
                onPressed: _goNext,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text(
                  'Passer ⏭',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
