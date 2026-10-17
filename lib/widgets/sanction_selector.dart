import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

/// Catalogue local par famille. Les sanctions attribuées sont synchronisées
/// avec les pénalités ; les suggestions personnalisées restent sur cet appareil.
class SanctionSelector extends StatefulWidget {
  const SanctionSelector(
      {super.key, required this.enabled, required this.onChanged});
  final bool enabled;
  final void Function(String? type, String? label, String instruction)
      onChanged;

  @override
  State<SanctionSelector> createState() => _SanctionSelectorState();
}

class _SanctionSelectorState extends State<SanctionSelector> {
  String? _selection;
  final List<String> _custom = [];
  String? _detail;
  static const _chores = ['Ranger sa chambre', 'Ranger les jouets', 'Ranger son bureau', 'Mettre la table', 'Débarrasser la table', 'Sortir les poubelles', 'Essuyer la table', 'Passer le balai'];
  static const _repairs = ['Nettoyer ce qui a été sali', 'Remettre en état ce qui a été abîmé', 'Présenter des excuses', 'Proposer une action pour réparer son erreur'];
  static const _categories = {
    'lines': 'Lignes à copier',
    'chore': 'Corvée',
    'essay': 'Rédaction / réflexion',
    'repair': 'Réparation',
    'yellow_card': '🟨 Carton jaune',
    'red_card': '🟥 Carton rouge',
    'custom': 'Sanction personnalisée',
    'none': 'Retrait de points uniquement',
  };
  void _chooseCategory(String? value) {
    setState(() { _selection = value; _detail = null; });
    if (value == null || value == 'none') { widget.onChanged(null, null, ''); return; }
    final instruction = switch (value) {
      'essay' => 'Expliquer ce que j’ai fait, les conséquences et ce que je vais faire pour ne pas recommencer.',
      'yellow_card' || 'red_card' => 'Aller dans ma chambre pour un temps calme. Le parent décide sur place de la durée et valide la fin.',
      _ => '',
    };
    widget.onChanged(value, _categories[value], instruction);
  }
  String get _key =>
      'sanction_catalog_v1_${FirestoreService().familyId ?? 'local'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? [];
    if (mounted) setState(() => _custom.addAll(values));
  }

  Future<void> _add() async {
    String label = '';
    String instruction = '';
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, update) => AlertDialog(
                title: const Text('Ajouter une sanction'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      maxLength: 80,
                      decoration: const InputDecoration(
                          labelText: 'Nom (ex. Aider au jardin)'),
                      onChanged: (v) => update(() => label = v.trim())),
                  TextField(
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Consigne à effectuer'),
                      onChanged: (v) => update(() => instruction = v.trim())),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: label.isEmpty || instruction.isEmpty
                          ? null
                          : () => Navigator.pop(dialogContext, true),
                      child: const Text('Ajouter')),
                ],
              ),
            ));
    if (saved != true || !mounted) return;
    final encoded = jsonEncode({'label': label, 'instruction': instruction});
    if (!_custom.contains(encoded)) _custom.add(encoded);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _custom);
      if (!mounted) return;
      setState(() { _selection = 'custom'; _detail = encoded; });
      widget.onChanged('custom', label, instruction);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Impossible de conserver cette suggestion. Réessaie.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _selection == 'chore' ? _chores : _repairs;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(
        key: ValueKey(_selection), initialValue: _selection, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Catégorie de punition'),
        items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: widget.enabled ? _chooseCategory : null,
      ),
      if (_selection == 'chore' || _selection == 'repair') ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('detail_$_selection'), initialValue: _detail, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Action à effectuer'),
          items: choices.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: !widget.enabled ? null : (value) {
            setState(() => _detail = value);
            widget.onChanged(_selection, _categories[_selection], value ?? '');
          },
        ),
      ],
      if (_selection == 'custom') ...[
        if (_custom.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey(_detail), initialValue: _detail, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sanction enregistrée'),
            items: _custom.map((encoded) => DropdownMenuItem(value: encoded, child: Text((jsonDecode(encoded) as Map)['label'] as String))).toList(),
            onChanged: !widget.enabled ? null : (encoded) {
              if (encoded == null) return;
              setState(() => _detail = encoded);
              final value = jsonDecode(encoded) as Map;
              widget.onChanged('custom', value['label'] as String, value['instruction'] as String);
            },
          ),
        TextButton.icon(onPressed: widget.enabled ? _add : null, icon: const Icon(Icons.add), label: const Text('Ajouter une sanction personnalisée')),
        const Text('Les suggestions ajoutées sont conservées sur cet appareil.', style: TextStyle(fontSize: 12)),
      ],
      if (_selection == 'yellow_card' || _selection == 'red_card')
        const Padding(padding: EdgeInsets.only(top: 12), child: Text('Aucune durée imposée : le parent décide sur place et valide la fin du temps calme.')),
    ]);
  }
}
