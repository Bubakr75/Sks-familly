import 'package:flutter/material.dart';

class WebIntroPlayer extends StatelessWidget {
  final String src;
  final VoidCallback onEnded;
  const WebIntroPlayer({super.key, required this.src, required this.onEnded});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
