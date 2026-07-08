import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'web_intro_stub.dart' if (dart.library.js_interop) 'web_intro_web.dart';

class VideoIntroScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const VideoIntroScreen({super.key, required this.onFinished});

  @override
  State<VideoIntroScreen> createState() => _VideoIntroScreenState();
}

class _VideoIntroScreenState extends State<VideoIntroScreen> {
  VideoPlayerController? _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = VideoPlayerController.asset('assets/videos/intro.mp4')
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _controller!.play();
          _controller!.setLooping(false);
        }).catchError((e) {
          _goNext();
        });

      _controller!.addListener(() {
        if (_controller != null &&
            _controller!.value.isInitialized &&
            _controller!.value.position >= _controller!.value.duration &&
            !_finished) {
          _goNext();
        }
      });
    }
  }

  void _goNext() {
    if (_finished) return;
    _finished = true;
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: kIsWeb
                ? WebIntroPlayer(
                    src: 'videos/intro.mp4',
                    onEnded: _goNext,
                  )
                : (_controller != null && _controller!.value.isInitialized)
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: SafeArea(
              child: TextButton(
                onPressed: _goNext,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black45,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Passer',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
