import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseDiagnosticScreen extends StatefulWidget {
  const FirebaseDiagnosticScreen({super.key});
  @override
  State<FirebaseDiagnosticScreen> createState() => _FirebaseDiagnosticScreenState();
}

class _FirebaseDiagnosticScreenState extends State<FirebaseDiagnosticScreen> {
  final List<_DiagStep> _steps = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _steps.clear();
      _running = true;
    });

    // Step 1: Check Firebase App
    _addStep('Verification Firebase App...');
    try {
      final app = Firebase.app();
      _updateStep(true, 'Firebase App OK: ${app.name}\nProject: ${app.options.projectId}');
    } catch (e) {
      _updateStep(false, 'Firebase App MANQUANT: $e');
      // Try to initialize
      _addStep('Tentative d\'initialisation...');
      try {
        await Firebase.initializeApp();
        _updateStep(true, 'Firebase initialise avec succes!');
      } catch (e2) {
        _updateStep(false, 'Initialisation echouee: $e2');
        setState(() => _running = false);
        return;
      }
    }

    // Step 2: Check Firestore instance
    _addStep('Verification Firestore...');
    try {
      final db = FirebaseFirestore.instance;
      _updateStep(true, 'Firestore instance OK\nApp: ${db.app.name}');
    } catch (e) {
      _updateStep(false, 'Firestore erreur: $e');
      setState(() => _running = false);
      return;
    }

    // Step 3: Read families collection
    _addStep('Lecture des familles Firestore...');
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('families')
          .get()
          .timeout(const Duration(seconds: 15));
      final codes = snapshot.docs.map((d) => d.data()['code'] ?? '?').toList();
      _updateStep(true, '${snapshot.docs.length} famille(s) trouvee(s)\nCodes: ${codes.join(", ")}');
    } catch (e) {
      _updateStep(false, 'Lecture echouee: $e');
    }

    // Step 4: Check SharedPreferences
    _addStep('Verification donnees locales...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final familyId = prefs.getString('family_id');
      final familyCode = prefs.getString('family_code');
      _updateStep(true, 'Family ID: ${familyId ?? "non defini"}\nFamily Code: ${familyCode ?? "non defini"}');
    } catch (e) {
      _updateStep(false, 'SharedPrefs erreur: $e');
    }

    // Step 5: Test write + read
    _addStep('Test ecriture/lecture Firestore...');
    try {
      final testRef = FirebaseFirestore.instance.collection('_diagnostic_test');
      final testDoc = testRef.doc('test_safari');
      await testDoc.set({
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'android',
        'test': true,
      }).timeout(const Duration(seconds: 10));
      
      final readBack = await testDoc.get().timeout(const Duration(seconds: 10));
      if (readBack.exists) {
        _updateStep(true, 'Ecriture + Lecture OK!\nPlateforme: ${readBack.data()?['platform']}');
        // Clean up
        await testDoc.delete();
      } else {
        _updateStep(false, 'Document ecrit mais pas lu');
      }
    } catch (e) {
      _updateStep(false, 'Test ecriture echoue: $e');
    }

    // Step 6: Test joining a family (read-only test)
    _addStep('Test recherche code famille...');
    try {
      // Search for any family code
      final query = await FirebaseFirestore.instance
          .collection('families')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (query.docs.isNotEmpty) {
        final code = query.docs.first.data()['code'];
        // Now test the exact query used in joinFamily
        final joinQuery = await FirebaseFirestore.instance
            .collection('families')
            .where('code', isEqualTo: code)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
        
        if (joinQuery.docs.isNotEmpty) {
          _updateStep(true, 'Recherche par code "$code" OK!\nFamily ID: ${joinQuery.docs.first.id}');
        } else {
          _updateStep(false, 'Code "$code" existe mais query where echoue!');
        }
      } else {
        _updateStep(false, 'Aucune famille dans Firestore');
      }
    } catch (e) {
      _updateStep(false, 'Recherche echouee: $e');
    }

    setState(() => _running = false);
  }

  void _addStep(String label) {
    setState(() {
      _steps.add(_DiagStep(label: label));
    });
  }

  void _updateStep(bool success, String detail) {
    setState(() {
      if (_steps.isNotEmpty) {
        _steps.last.success = success;
        _steps.last.detail = detail;
        _steps.last.done = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Firebase'),
        actions: [
          if (!_running)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _runDiagnostics,
              tooltip: 'Relancer',
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ce diagnostic teste la connexion Firebase etape par etape. Faites une capture d\'ecran du resultat.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._steps.map((step) => _buildStepCard(step)),
            if (_running)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_running && _steps.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(_DiagStep step) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!step.done)
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (step.success == true)
              const Icon(Icons.check_circle, color: Colors.green, size: 24)
            else
              const Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (step.detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.detail!,
                      style: TextStyle(
                        fontSize: 12,
                        color: step.success == true ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final failures = _steps.where((s) => s.done && s.success != true).length;
    final successes = _steps.where((s) => s.done && s.success == true).length;

    return Card(
      color: failures == 0 ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              failures == 0 ? Icons.celebration : Icons.warning_amber_rounded,
              size: 48,
              color: failures == 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              failures == 0
                  ? 'Tout fonctionne ! ($successes/$successes)'
                  : '$failures erreur(s) detectee(s)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: failures == 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            if (failures > 0) ...[
              const SizedBox(height: 8),
              const Text(
                'Faites une capture d\'ecran et envoyez-la pour le diagnostic.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
            if (failures == 0) ...[
              const SizedBox(height: 8),
              const Text(
                'Firebase fonctionne correctement. La synchronisation devrait marcher.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagStep {
  String label;
  bool? success;
  String? detail;
  bool done;

  _DiagStep({required this.label}) : done = false;
}
