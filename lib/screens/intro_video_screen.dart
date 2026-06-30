// lib/screens/intro_video_screen.dart
//
// Écran d'intro : joue la vidéo assets/videos/intro.mp4 AVEC LE SON,
// puis bascule vers l'app principale à la fin (ou bouton "Passer").
//
// Affiché au tout 1er démarrage (une fois par version, pour ne pas lasser).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntroVideoScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const IntroVideoScreen({super.key, required this.onFinished});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Mode immersif plein écran pendant l'intro
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.asset('assets/videos/intro.mp4');

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      // 🔊 Son actif + volume max
      _controller.setVolume(1.0);
      _controller.setLooping(false);
      // Démarrage IMMÉDIAT dès que prêt
      _controller.play();

      // À la fin de la vidéo → bascule vers l'app
      _controller.addListener(() {
        if (_controller.value.position >= _controller.value.duration &&
            !_finished &&
            _controller.value.duration > Duration.zero) {
          _goNext();
        }
      });
    }).catchError((e) {
      // Si la vidéo ne charge pas (rare), on passe directement
      _goNext();
    });
  }

  void _goNext() {
    if (_finished) return;
    _finished = true;
    // Restaurer l'UI système normale
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Marquer l'intro comme vue (pour ne pas la rejouer à chaque fois)
    _markIntroSeen();
    if (mounted) widget.onFinished();
  }

  Future<void> _markIntroSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('intro_seen_version', '1');
    } catch (_) {}
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Vidéo plein écran (seulement si initialisée, sinon fond noir pur)
          if (_initialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          // Fond NOIR PUR pendant le court instant de chargement de la vidéo
          // (pas de spinner, pas de logo, pas de gris)
          else
            const SizedBox.shrink(),

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
