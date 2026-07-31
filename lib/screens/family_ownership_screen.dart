import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/family_manager_service.dart';
import '../services/family_ownership_service.dart';

class FamilyOwnershipScreen extends StatefulWidget {
  const FamilyOwnershipScreen({
    required this.familyId,
    super.key,
  });

  final String familyId;

  @override
  State<FamilyOwnershipScreen> createState() => _FamilyOwnershipScreenState();
}

class _FamilyOwnershipScreenState extends State<FamilyOwnershipScreen> {
  final _auth = AuthService();
  final _managerService = FamilyManagerService();
  final _ownershipService = FamilyOwnershipService();
  List<FamilyManagerMember> _members = const [];
  bool _busy = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await _managerService.listMembers(widget.familyId);
      if (!mounted) return;
      setState(() {
        _members = members.where((member) => member.durable).toList();
        _busy = false;
      });
    } catch (error) {
      _showMessage(error.toString(), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _requestPassword(String title) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
            labelText: 'Mot de passe du compte',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.clear();
    controller.dispose();
    return password;
  }

  Future<void> _reauthenticate(String title) async {
    final password = await _requestPassword(title);
    if (password == null) throw const _Cancelled();
    await _auth.reauthenticateWithPassword(password: password);
  }

  Future<void> _transfer() async {
    final target = await showDialog<FamilyManagerMember>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Nouveau propriétaire'),
        children: _members
            .map(
              (member) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, member),
                child: ListTile(
                  title: Text(member.displayName),
                  subtitle: const Text('Compte durable vérifié'),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (target == null) return;
    if (!mounted) return;
    final oldRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Votre futur rôle'),
        content: const Text(
          'Après le transfert, vous ne serez plus propriétaire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'parent'),
            child: const Text('Devenir parent'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'manager'),
            child: const Text('Devenir gestionnaire'),
          ),
        ],
      ),
    );
    if (oldRole == null) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmation définitive'),
        content: Text(
          'Transférer la propriété à ${target.displayName} ? '
          'Cette opération modifie le propriétaire unique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Transférer définitivement'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _reauthenticate('Authentification récente requise');
      await _ownershipService.transfer(
        familyId: widget.familyId,
        targetMemberId: target.memberId,
        previousOwnerRole: oldRole,
      );
      _showMessage('La propriété a été transférée.', error: false);
    });
  }

  Future<void> _generateRecoveryCode() async {
    await _run(() async {
      await _reauthenticate('Créer un code de récupération');
      final receipt =
          await _ownershipService.generateRecoveryCode(widget.familyId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Code affiché une seule fois'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Notez ce code hors de l’appareil. Il ne sera pas conservé '
                'en clair et expire automatiquement.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                receipt.code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Validité : ${receipt.expiresInDays} jours'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Je l’ai noté'),
            ),
          ],
        ),
      );
      _showMessage(
        'Le code précédent a été remplacé et le nouveau code n’est plus '
        'affichable.',
        error: false,
      );
    });
  }

  Future<void> _revokeRecoveryCode() async {
    await _run(() async {
      await _reauthenticate('Révoquer le code de récupération');
      await _ownershipService.revokeRecoveryCode(widget.familyId);
      _showMessage('Le code de récupération est révoqué.', error: false);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on _Cancelled {
      // L'annulation volontaire ne produit aucun message d'erreur.
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String value, {required bool error}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageIsError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Propriété et récupération')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Le transfert exige un compte durable vérifié, une '
                  'authentification récente et un parent destinataire '
                  'également vérifié. Le PIN local ne donne aucun droit.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || _members.isEmpty ? null : _transfer,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Transférer la propriété'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _generateRecoveryCode,
              icon: const Icon(Icons.key_rounded),
              label: const Text('Créer ou renouveler le code de récupération'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _revokeRecoveryCode,
              icon: const Icon(Icons.key_off_rounded),
              label: const Text('Révoquer le code de récupération'),
            ),
            if (_members.isEmpty && !_busy) ...[
              const SizedBox(height: 12),
              const Text(
                'Aucun autre parent avec compte durable vérifié ne peut '
                'encore recevoir la propriété.',
                textAlign: TextAlign.center,
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _messageIsError ? Colors.redAccent : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
