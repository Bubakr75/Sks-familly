import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../services/family_backup_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

String _encryptFamilyBackup(Map<String, dynamic> arguments) {
  return FamilyBackupService.encryptPayload(
    Map<String, dynamic>.from(arguments['payload'] as Map),
    arguments['password'] as String,
  );
}

Map<String, dynamic> _inspectFamilyBackup(Map<String, dynamic> arguments) {
  final preview = FamilyBackupService.decryptAndInspect(
    arguments['archive'] as String,
    arguments['password'] as String,
  );
  return {
    'createdAt': preview.createdAt.toIso8601String(),
    'appVersion': preview.appVersion,
    'counts': preview.counts,
    'payload': preview.payload,
  };
}

class FamilyBackupScreen extends StatefulWidget {
  const FamilyBackupScreen({super.key});

  @override
  State<FamilyBackupScreen> createState() => _FamilyBackupScreenState();
}

class _FamilyBackupScreenState extends State<FamilyBackupScreen> {
  bool _busy = false;
  FamilyBackupPreview? _restorePreview;
  String? _restoreFileName;

  Future<String?> _askExportPassword() async {
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    var obscure = true;
    String? error;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Protéger la sauvegarde'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choisissez un mot de passe d’au moins 10 caractères. '
                  'Il sera impossible de restaurer le fichier sans lui.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe de sauvegarde',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmationController,
                  obscureText: obscure,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: Icon(Icons.verified_user_rounded),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Afficher le mot de passe'),
                  value: !obscure,
                  onChanged: (value) => setDialogState(() => obscure = !value),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text;
                if (password.length < FamilyBackupService.minPasswordLength) {
                  setDialogState(
                    () => error = 'Utilisez au moins 10 caractères.',
                  );
                  return;
                }
                if (password != confirmationController.text) {
                  setDialogState(
                    () => error = 'Les deux mots de passe sont différents.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, password);
              },
              child: const Text('Créer le fichier'),
            ),
          ],
        ),
      ),
    );

    passwordController
      ..clear()
      ..dispose();
    confirmationController
      ..clear()
      ..dispose();
    return result;
  }

  Future<String?> _askPassword({
    required String title,
    required String explanation,
    String label = 'Mot de passe de sauvegarde',
  }) async {
    final controller = TextEditingController();
    var obscure = true;
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(explanation),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: const Icon(Icons.password_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  setDialogState(() => error = 'Ce champ est obligatoire.');
                  return;
                }
                Navigator.pop(dialogContext, controller.text);
              },
              child: const Text('Continuer'),
            ),
          ],
        ),
      ),
    );
    controller
      ..clear()
      ..dispose();
    return result;
  }

  Future<void> _export() async {
    if (_busy) return;
    final password = await _askExportPassword();
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final appVersion = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
      final payload = context
          .read<FamilyProvider>()
          .createFamilyBackupPayload(appVersion: appVersion);
      final archive = await compute(
        _encryptFamilyBackup,
        {'payload': payload, 'password': password},
      );
      final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Enregistrer la sauvegarde chiffrée',
        fileName: 'sks-family-$date.${FamilyBackupService.extension}',
        type: FileType.custom,
        allowedExtensions: const [FamilyBackupService.extension],
        bytes: Uint8List.fromList(utf8.encode(archive)),
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sauvegarde chiffrée enregistrée.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FamilyBackupException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Impossible de créer la sauvegarde sur cet appareil.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectAndInspectRestore() async {
    if (_busy) return;
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choisir une sauvegarde SKS Family',
      type: FileType.custom,
      allowedExtensions: const [FamilyBackupService.extension],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.size > FamilyBackupService.maxArchiveBytes || file.bytes == null) {
      _showError('Ce fichier est trop volumineux ou inaccessible.');
      return;
    }
    final password = await _askPassword(
      title: 'Ouvrir la sauvegarde',
      explanation:
          'Entrez le mot de passe choisi lors de la création du fichier.',
    );
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final archive = utf8.decode(file.bytes!);
      final result = await compute(
        _inspectFamilyBackup,
        {'archive': archive, 'password': password},
      );
      if (!mounted) return;
      setState(() {
        _restorePreview = FamilyBackupPreview(
          createdAt: DateTime.parse(result['createdAt'] as String),
          appVersion: result['appVersion'] as String,
          counts: Map<String, int>.from(result['counts'] as Map),
          payload: Map<String, dynamic>.from(result['payload'] as Map),
        );
        _restoreFileName = file.name;
      });
    } on FamilyBackupException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('Le fichier sélectionné est invalide.');
    } catch (_) {
      _showError('Mot de passe incorrect ou sauvegarde endommagée.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _verifyParentPin() async {
    final pinProvider = context.read<PinProvider>();
    if (!pinProvider.isPinSet) {
      _showError(
        'Créez d’abord un PIN parent dans les réglages de sécurité.',
      );
      return false;
    }
    if (pinProvider.isLockedOut) {
      _showError(
        'PIN temporairement bloqué. Réessayez dans '
        '${pinProvider.lockoutRemainingSeconds} secondes.',
      );
      return false;
    }
    final pin = await _askPassword(
      title: 'Vérification parent',
      explanation:
          'Saisissez à nouveau le PIN parent avant toute modification.',
      label: 'PIN parent',
    );
    if (pin == null || !mounted) return false;
    final valid = pinProvider.verifyPin(pin);
    if (!valid) {
      _showError('PIN incorrect.');
    }
    return valid;
  }

  Future<bool> _confirmReplacement(FamilyBackupPreview preview) async {
    final controller = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Remplacer les données locales ?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cette opération remplace toutes les données familiales '
                    'locales. Une copie de retour arrière est créée '
                    'automatiquement pendant l’opération.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${preview.counts['children'] ?? 0} enfant(s), '
                    '${preview.counts['history'] ?? 0} historique(s), '
                    '${preview.counts['notes'] ?? 0} note(s).',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tapez RESTAURER pour confirmer.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Confirmation',
                    ),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () {
                    if (controller.text.trim() != 'RESTAURER') {
                      setDialogState(
                        () => error = 'Confirmation incorrecte.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Remplacer'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    controller
      ..clear()
      ..dispose();
    return confirmed;
  }

  Future<void> _restore() async {
    final preview = _restorePreview;
    if (preview == null || _busy) return;
    final provider = context.read<FamilyProvider>();
    if (provider.isSyncEnabled) {
      _showError(
        'Déconnectez d’abord la synchronisation familiale. '
        'Aucune restauration ne doit modifier Firebase.',
      );
      return;
    }
    if (!await _verifyParentPin() || !mounted) return;
    if (!await _confirmReplacement(preview) || !mounted) return;

    setState(() => _busy = true);
    try {
      await provider.restoreFamilyBackup(preview);
      if (!mounted) return;
      setState(() {
        _restorePreview = null;
        _restoreFileName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restauration locale terminée.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FamilyBackupException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(
        'La restauration a échoué. Les anciennes données ont été rétablies.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Sauvegarde familiale')),
      body: AnimatedBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded, color: Colors.greenAccent),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Export familial chiffré',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Le fichier contient les données familiales disponibles '
                      'sur cet appareil. Il est protégé par AES-256-GCM. Les '
                      'identifiants Firebase, le PIN, les jetons et les rôles '
                      'd’appareil ne sont jamais exportés.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Les photos déjà stockées uniquement dans le cloud ne '
                      'sont pas intégrées au fichier.',
                      style: TextStyle(color: Colors.amberAccent, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _export,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(
                          _busy
                              ? 'Chiffrement en cours…'
                              : 'Exporter la famille',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.restore_rounded, color: Colors.amberAccent),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Restauration contrôlée',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Le fichier est d’abord déchiffré et vérifié sans '
                      'modifier l’application. La restauration est bloquée '
                      'si la synchronisation familiale est active.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    if (_restorePreview == null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _selectAndInspectRestore,
                          icon: const Icon(Icons.file_open_rounded),
                          label: const Text('Analyser un fichier'),
                        ),
                      )
                    else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _restoreFileName ?? 'Sauvegarde',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Créée le '
                              '${_restorePreview!.createdAt.toLocal()}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'Version ${_restorePreview!.appVersion} • '
                              '${_restorePreview!.counts['children'] ?? 0} '
                              'enfant(s) • '
                              '${_restorePreview!.counts['history'] ?? 0} '
                              'entrée(s)',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _restorePreview = null;
                                        _restoreFileName = null;
                                      }),
                              child: const Text('Annuler'),
                            ),
                          ),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              onPressed: _busy ? null : _restore,
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Restaurer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
