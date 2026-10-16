import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/emerald_theme.dart';

class PunishmentFormSheet extends StatefulWidget {
  const PunishmentFormSheet(
      {super.key, required this.childName, required this.onSubmit});
  final String childName;
  final Future<void> Function(String description, int lines) onSubmit;

  @override
  State<PunishmentFormSheet> createState() => _PunishmentFormSheetState();
}

class _PunishmentFormSheetState extends State<PunishmentFormSheet> {
  final _description = TextEditingController();
  final _lines = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _lines.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final description = _description.text.trim();
    final lines = int.tryParse(_lines.text.trim());
    if (description.isEmpty || lines == null || lines <= 0) {
      setState(() => _error =
          'Indique une consigne et un nombre de lignes supérieur à zéro.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(description, lines);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Enregistrement non confirmé. Vérifie les lignes avant de réessayer. Ta saisie est conservée.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nouvelle punition pour ${widget.childName}',
                      style: const TextStyle(
                          color: EmeraldPalette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                      key: const ValueKey('punishment_description'),
                      controller: _description,
                      enabled: !_saving,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Consigne des lignes')),
                  const SizedBox(height: 12),
                  TextField(
                      key: const ValueKey('punishment_lines'),
                      controller: _lines,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration:
                          const InputDecoration(labelText: 'Nombre de lignes')),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: EmeraldPalette.warning))),
                  const SizedBox(height: 16),
                  Row(children: [
                    TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        child: const Text('Annuler')),
                    const Spacer(),
                    FilledButton(
                        key: const ValueKey('punishment_save'),
                        onPressed: _saving ? null : _save,
                        child:
                            Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
                  ]),
                ],
              )),
            )),
      );
}
