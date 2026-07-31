import 'package:flutter/material.dart';

void showPointActionSuccess({
  required ScaffoldMessengerState messenger,
  required String message,
  required Color color,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
  ));
}

void showPointActionFailure({
  required ScaffoldMessengerState messenger,
  required String message,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: Colors.redAccent,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 7),
  ));
}

Future<void> closePointActionPanelAfterSuccess(
  BuildContext context, {
  Duration delay = const Duration(milliseconds: 120),
}) async {
  await Future<void>.delayed(delay);
  if (!context.mounted) return;
  await Navigator.of(context).maybePop();
}
