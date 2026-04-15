  Future<void> _startQuiz(PunishmentLines p, ChildModel child,
      FamilyProvider fp, String theme) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.purpleAccent),
            SizedBox(height: 16),
            Text('🧠 Gemini prépare le quiz...',
                style: TextStyle(color: Colors.white)),
            SizedBox(height: 4),
            Text('Adapté à l\'âge de l\'enfant',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );

    try {
      final questions = await GeminiService.generateQuizQuestions(
        theme: theme,
        age: _estimateAge(child),
      );
      if (mounted) Navigator.pop(context);

      if (questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('❌ Aucune question reçue de Gemini'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 10),
          ));
        }
        return;
      }

      if (mounted) {
        _showQuizDialog(p, child, fp, questions, theme);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur exacte : $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 15),
        ));
      }
    }
  }
