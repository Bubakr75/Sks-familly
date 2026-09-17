import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/child_model.dart';

typedef SubmitTribunalCase = Future<void> Function(String caseId, String title,
    String description, String plaintiffId, String accusedId);

class TribunalCaseDialog extends StatefulWidget {
  const TribunalCaseDialog(
      {super.key,
      required this.children,
      required this.onSubmit,
      this.childId,
      this.childAccount = false});
  final List<ChildModel> children;
  final SubmitTribunalCase onSubmit;
  final String? childId;
  final bool childAccount;
  @override
  State<TribunalCaseDialog> createState() => _TribunalCaseDialogState();
}

class _TribunalCaseDialogState extends State<TribunalCaseDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  // Conservé lors d'une nouvelle tentative après une réponse réseau perdue.
  final _caseId = const Uuid().v4();
  String? _plaintiff;
  String? _accused;
  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.childAccount) _plaintiff = widget.childId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pending) return;
    if (_title.text.trim().isEmpty ||
        _plaintiff == null ||
        _accused == null ||
        _plaintiff == _accused) {
      setState(() => _error =
          'Renseignez le titre, le plaignant et un autre enfant accusé.');
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_caseId, _title.text.trim(),
          _description.text.trim(), _plaintiff!, _accused!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = switch (error) {
          FirebaseFunctionsException(code: 'permission-denied') =>
            'Ce compte ne peut pas déposer cette affaire. Vérifiez le profil enfant.',
          FirebaseFunctionsException(code: 'already-exists') =>
            'Cette tentative existe déjà. Vérifiez la liste des affaires avant de recommencer.',
          _ =>
            'Envoi non confirmé. Vérifiez la connexion puis réessayez. Votre texte est conservé.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_pending,
        child: AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Nouvelle affaire',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                TextField(
                    key: const ValueKey('tribunal_title'),
                    controller: _title,
                    enabled: !_pending,
                    maxLength: 200,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        const InputDecoration(labelText: 'Titre de l’affaire')),
                TextField(
                    key: const ValueKey('tribunal_description'),
                    controller: _description,
                    enabled: !_pending,
                    maxLines: 3,
                    maxLength: 4000,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Description des faits')),
                const Text('Plaignant',
                    style: TextStyle(color: Colors.white70)),
                Wrap(
                    spacing: 8,
                    children: widget.children
                        .where((c) =>
                            !widget.childAccount || c.id == widget.childId)
                        .map((c) => ChoiceChip(
                            label: Text(c.name),
                            selected: _plaintiff == c.id,
                            onSelected: _pending || widget.childAccount
                                ? null
                                : (_) => setState(() {
                                      _plaintiff = c.id;
                                      if (_accused == c.id) _accused = null;
                                    })))
                        .toList()),
                const Text('Accusé', style: TextStyle(color: Colors.white70)),
                Wrap(
                    spacing: 8,
                    children: widget.children
                        .where((c) => c.id != _plaintiff)
                        .map((c) => ChoiceChip(
                            key: ValueKey('tribunal_accused_${c.id}'),
                            label: Text(c.name),
                            selected: _accused == c.id,
                            onSelected: _pending
                                ? null
                                : (_) => setState(() => _accused = c.id)))
                        .toList()),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          key: const ValueKey('tribunal_error'),
                          style: const TextStyle(color: Colors.orangeAccent))),
              ])),
          actions: [
            TextButton(
                onPressed:
                    _pending ? null : () => Navigator.of(context).pop(false),
                child: const Text('Annuler')),
            ElevatedButton(
                key: const ValueKey('tribunal_submit'),
                onPressed: _pending ? null : _submit,
                child:
                    Text(_pending ? 'Envoi en cours…' : 'Déposer l’affaire')),
          ],
        ),
      );
}
