import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pin_provider.dart';
import '../screens/pin_verification_screen.dart';

/// Utility class for PIN protection throughout the app.
/// Every parent-only action MUST go through this.
class PinGuard {
  /// Execute an action that requires parent authentication.
  /// If PIN is set and not in parent mode, shows the PIN verification screen.
  /// If PIN is not set or already in parent mode, executes immediately.
  static void guardAction(BuildContext context, VoidCallback onAuthorized) {
    final pin = context.read<PinProvider>();
    if (pin.canPerformParentAction()) {
      pin.refreshActivity();
      onAuthorized();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinVerificationScreen(
            onVerified: () {
              Navigator.pop(context);
              onAuthorized();
            },
          ),
        ),
      );
    }
  }

  /// Navigate to a screen that requires parent mode.
  static void guardNavigation(BuildContext context, Widget screen) {
    final pin = context.read<PinProvider>();
    if (pin.canPerformParentAction()) {
      pin.refreshActivity();
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinVerificationScreen(
            onVerified: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
            },
          ),
        ),
      );
    }
  }

  /// Show a "locked" snackbar when trying to do a protected action
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
