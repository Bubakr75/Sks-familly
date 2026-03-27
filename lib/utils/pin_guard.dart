import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pin_provider.dart';
import '../screens/pin_verification_screen.dart';

class PinGuard {
  static void guardAction(BuildContext context, VoidCallback onAuthorized) {
    final pin = context.read<PinProvider>();
    if (pin.canPerformParentAction()) {
      pin.refreshActivity();
      onAuthorized();
    } else {
      Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinVerificationScreen()),
      ).then((result) {
        if (result == true) {
          onAuthorized();
        }
      });
    }
  }

  static void guardNavigation(BuildContext context, Widget screen) {
    final pin = context.read<PinProvider>();
    if (pin.canPerformParentAction()) {
      pin.refreshActivity();
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } else {
      Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinVerificationScreen()),
      ).then((result) {
        if (result == true) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        }
      });
    }
  }

  static void showLockedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Action protegee - Entrez le code parental'),
          ],
        ),
        backgroundColor: Colors.orange[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
