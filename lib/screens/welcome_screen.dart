import 'package:flutter/foundation.dart';
void _showPinDialog(VoidCallback onSuccess) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) {
      final pinProvider = Provider.of<PinProvider>(dialogContext, listen: false);
      
      return AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🔒 PIN Parental', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 10),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.cyan),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinProvider.verifyPin(controller.text)) {
                Navigator.pop(dialogContext);
                onSuccess();
                debugPrint("✅ PIN accepté - Ouverture du sélecteur parent");
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ PIN incorrect'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            child: const Text('Valider'),
          ),
        ],
      );
    },
  );
}
