import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/child_model.dart';
import '../services/point_action_submission_service.dart';
import '../utils/motif_helpers.dart';

class QuickPointActionPreset {
  final String label;
  final int points;

  const QuickPointActionPreset(this.label, this.points);
}

class QuickPointActionForm extends StatefulWidget {
  final bool isBonus;
  final List<ChildModel> children;
  final List<QuickPointActionPreset> presets;
  final Future<void> Function(PointActionDraft draft) onSubmit;

  const QuickPointActionForm({
    super.key,
    required this.isBonus,
    required this.children,
    required this.presets,
    required this.onSubmit,
  });

  @override
  State<QuickPointActionForm> createState() => _QuickPointActionFormState();
}

class _QuickPointActionFormState extends State<QuickPointActionForm> {
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController(text: '5');
  final _linesController = TextEditingController();
  final _instructionController = TextEditingController();
  QuickPointActionPreset? _preset;
  late String _childId;
  bool _isOther = false;
  bool? _hasLines;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _childId = widget.children.first.id;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    _linesController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  bool get _valid {
    final amount = int.tryParse(_amountController.text.trim());
    final reasonValid = isPointActionReasonValid(
      hasSelectedReason: _preset != null || _isOther,
      isOther: _isOther,
      customText: _reasonController.text,
    );
    final linesValid = widget.isBonus ||
        (_hasLines != null &&
            (_hasLines == false ||
                ((int.tryParse(_linesController.text.trim()) ?? 0) > 0)));
    return !_submitting &&
        amount != null &&
        amount > 0 &&
        amount <= 999 &&
        reasonValid &&
        linesValid;
  }

  void _selectPreset(QuickPointActionPreset preset) {
    if (_submitting) return;
    setState(() {
      _preset = preset;
      _isOther = false;
      _reasonController.clear();
      _amountController.text = '${preset.points}';
      _error = null;
    });
  }

  void _selectOther() {
    if (_submitting) return;
    setState(() {
      _preset = null;
      _isOther = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final reason = resolvePointActionReason(
      isOther: _isOther,
      selectedLabel: _preset?.label,
      customText: _reasonController.text,
    )!;
    final draft = PointActionDraft(
      actionId: 'quick-${DateTime.now().microsecondsSinceEpoch}',
      childId: _childId,
      amount: int.parse(_amountController.text.trim()),
      reason: reason,
      category: widget.isBonus ? 'bonus' : 'penalty',
      isBonus: widget.isBonus,
      hasPhoto: false,
      penaltyLinesCount:
          _hasLines == true ? int.parse(_linesController.text.trim()) : null,
      penaltyLinesInstruction:
          _hasLines == true ? _instructionController.text.trim() : null,
    );
    try {
      await widget.onSubmit(draft);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = widget.isBonus
            ? 'Impossible d’enregistrer le bonus. Réessayez.'
            : 'Impossible d’enregistrer la pénalité. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isBonus ? Colors.greenAccent : Colors.redAccent;
    return Material(
      color: const Color(0xFF0F2620),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('quick_point_action_scroll'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              children: [
                Text(
                  widget.isBonus ? 'Bonus rapide' : 'Pénalité rapide',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.children.length > 1) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _childId,
                    items: widget.children
                        .map((child) => DropdownMenuItem(
                              value: child.id,
                              child: Text(child.name),
                            ))
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _childId = value!),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...widget.presets.map((preset) => ChoiceChip(
                          label: Text(preset.label),
                          selected: identical(_preset, preset),
                          onSelected: (_) => _selectPreset(preset),
                        )),
                    ChoiceChip(
                      label: const Text('Autre'),
                      selected: _isOther,
                      onSelected: (_) => _selectOther(),
                    ),
                  ],
                ),
                if (_isOther) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('quick_custom_reason'),
                    controller: _reasonController,
                    enabled: !_submitting,
                    maxLength: maxCustomReasonLength,
                    decoration: const InputDecoration(
                      labelText: 'Motif personnalisé',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('quick_amount'),
                  controller: _amountController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Points'),
                  onChanged: (_) => setState(() {}),
                ),
                if (!widget.isBonus) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Cette pénalité comporte-t-elle des lignes à faire ?',
                    style: TextStyle(color: Colors.white),
                  ),
                  RadioGroup<bool>(
                    groupValue: _hasLines,
                    onChanged: _submitting
                        ? (_) {}
                        : (value) => setState(() => _hasLines = value),
                    child: const Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            value: false,
                            title: Text('Non'),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            value: true,
                            title: Text('Oui'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasLines == true) ...[
                    TextField(
                      key: const ValueKey('quick_lines_count'),
                      controller: _linesController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Nombre de lignes à faire',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      controller: _instructionController,
                      enabled: !_submitting,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Consigne facultative',
                      ),
                    ),
                  ],
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      key: const ValueKey('quick_submit_error'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('quick_apply_button'),
                onPressed: _valid ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  disabledBackgroundColor: const Color(0xFF45524E),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_submitting ? 'Enregistrement…' : 'Appliquer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
