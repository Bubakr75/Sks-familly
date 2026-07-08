import 'dart:ui_web' as ui_web;
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

class WebIntroPlayer extends StatefulWidget {
  final String src;
  final VoidCallback onEnded;
  const WebIntroPlayer({super.key, required this.src, required this.onEnded});

  @override
  State<WebIntroPlayer> createState() => _WebIntroPlayerState();
}

class _WebIntroPlayerState extends State<WebIntroPlayer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'intro-video-${DateTime.now().microsecondsSinceEpoch}';

    final video = web.HTMLVideoElement()
      ..src = widget.src
      ..autoplay = true
      ..muted = true
      ..controls = false
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';

    video.addEventListener('ended', (web.Event e) {
      widget.onEnded();
    }.toJS);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => video,
    );

    video.play();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
