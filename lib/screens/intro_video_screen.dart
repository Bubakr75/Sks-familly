import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class IntroVideoScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final Future<void> Function()? initializeForTest;
  final Future<void> Function()? activateSoundForTest;

  const IntroVideoScreen({
    super.key,
    required this.onFinished,
    this.initializeForTest,
    this.activateSoundForTest,
  });

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Timer? _safetyTimer;
  bool _initialized = false;
  bool _finished = false;
  bool _soundPending = false;
  bool _soundEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _safetyTimer = Timer(const Duration(seconds: 20), _goNext);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final testInitializer = widget.initializeForTest;
      if (testInitializer != null) {
        await testInitializer().timeout(const Duration(seconds: 10));
        if (mounted && !_finished) setState(() => _initialized = true);
        return;
      }

      final controller = VideoPlayerController.asset('assets/videos/intro.mp4');
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 10));
      if (!mounted || _finished) return;

      await controller.setLooping(false);
      await controller.setVolume(kIsWeb ? 0 : 1);
      controller.addListener(_onVideoChanged);
      setState(() => _initialized = true);

      // La lecture muette est autorisée par Safari sans geste utilisateur.
      unawaited(controller.play().catchError((Object error) {
        if (mounted && !_finished) {
          setState(() => _errorMessage =
              'La vidéo est en pause. Tu peux la passer ou activer le son.');
        }
      }));
    } catch (_) {
      _goNext();
    }
  }

  void _onVideoChanged() {
    final value = _controller?.value;
    if (value == null || _finished) return;
    if (value.hasError) {
      _goNext();
      return;
    }
    if (value.duration > Duration.zero && value.position >= value.duration) {
      _goNext();
    }
  }

  void _enableSound() {
    if (_finished || _soundPending || _soundEnabled) return;

    // Ces appels doivent rester synchrones avec le geste utilisateur Safari.
    final Future<void> request;
    try {
      final testRequest = widget.activateSoundForTest;
      if (testRequest != null) {
        request = testRequest();
      } else {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          throw StateError('Vidéo indisponible');
        }
        final playFuture = controller.play();
        final volumeFuture = controller.setVolume(1);
        request = Future.wait([playFuture, volumeFuture]);
      }
    } catch (_) {
      _showSoundError();
      return;
    }

    setState(() {
      _soundPending = true;
      _errorMessage = null;
    });
    request.then((_) {
      if (!mounted || _finished) return;
      setState(() {
        _soundPending = false;
        _soundEnabled = true;
      });
    }).catchError((Object error) {
      if (mounted && !_finished) _showSoundError();
    });
  }

  void _showSoundError() {
    if (!mounted || _finished) return;
    setState(() {
      _soundPending = false;
      _errorMessage =
          'Safari a refusé le son. La vidéo continue sans bloquer l’application.';
    });
  }

  void _goNext() {
    if (_finished) return;
    _finished = true;
    _safetyTimer?.cancel();
    final controller = _controller;
    if (controller != null) unawaited(controller.pause());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) widget.onFinished();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _finished) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(controller.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(controller.play().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _safetyTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = _initialized &&
        (widget.initializeForTest != null ||
            (controller != null && controller.value.isInitialized));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _goNext(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (isReady && controller != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            if (!isReady)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              top: 24,
              right: 16,
              child: SafeArea(
                child: Semantics(
                  button: true,
                  label: 'Passer l’introduction',
                  child: TextButton(
                    key: const ValueKey('intro_skip_button'),
                    onPressed: _goNext,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black87,
                      minimumSize: const Size(96, 48),
                    ),
                    child: const Text('Passer'),
                  ),
                ),
              ),
            ),
            if (isReady && !_soundEnabled)
              Positioned(
                bottom: 32,
                right: 16,
                child: SafeArea(
                  child: Semantics(
                    button: true,
                    label: 'Activer le son de l’introduction',
                    child: FilledButton.icon(
                      key: const ValueKey('intro_sound_button'),
                      onPressed: _soundPending ? null : _enableSound,
                      icon: _soundPending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.volume_up_rounded),
                      label: const Text('Activer le son'),
                    ),
                  ),
                ),
              ),
            if (_errorMessage != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 96,
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
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
