import 'sanction_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

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
  final Future<bool> Function({bool force})? checkServiceAvailability;

  const QuickPointActionForm({
    super.key,
    required this.isBonus,
    required this.children,
    required this.presets,
    required this.onSubmit,
    this.checkServiceAvailability,
  });

  @override
  State<QuickPointActionForm> createState() => _QuickPointActionFormState();
}

class _QuickPointActionFormState extends State<QuickPointActionForm> {
  static const _uuid = Uuid();
  final _reasonController = TextEditingController();
  bool _deductPoints = false;
  final _amountController = TextEditingController(text: '1');
  final _linesController = TextEditingController();
  final _instructionController = TextEditingController();
  QuickPointActionPreset? _preset;
  late String _childId;
  bool _isOther = false;
  bool? _hasLines;
  String? _sanctionType;
  String? _sanctionLabel;
  bool _submitting = false;
  bool _verifying = false;
  String? _operationId;
  String? _error;
  late bool _serviceAvailable;
  bool _checkingService = false;
  bool _serviceCheckFailed = false;

  @override
  void initState() {
    super.initState();
    _childId = widget.children.isEmpty ? '' : widget.children.first.id;
    _serviceAvailable = widget.checkServiceAvailability == null;
    if (widget.checkServiceAvailability != null) {
      _checkService();
    }
  }

  Future<void> _checkService({bool force = false}) async {
    if (_checkingService || widget.checkServiceAvailability == null) return;
    setState(() => _checkingService = true);
    bool available;
    bool failed = false;
    try {
      available = await widget.checkServiceAvailability!(force: force);
    } catch (_) {
      available = false;
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _serviceAvailable = available;
      _checkingService = false;
      _serviceCheckFailed = failed;
    });
  }

  @override
  void didUpdateWidget(covariant QuickPointActionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.children.any((child) => child.id == _childId)) {
      _childId = widget.children.isEmpty ? '' : widget.children.first.id;
      _operationId = null;
    }
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
                ((int.tryParse(_linesController.text.trim()) ?? 0) > 0 &&
                    (int.tryParse(_linesController.text.trim()) ?? 0) <= 10000 &&
                    (_sanctionType == 'lines' ||
                        _instructionController.text.trim().isNotEmpty))));
    return !_submitting &&
        widget.children.any((child) => child.id == _childId) &&
        _serviceAvailable &&
        amount != null &&
        (widget.isBonus || _deductPoints ? amount > 0 : _hasLines == true) &&
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
      _operationId = null;
    });
  }

  void _selectOther() {
    if (_submitting) return;
    setState(() {
      _preset = null;
      _isOther = true;
      _error = null;
      _operationId = null;
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
      actionId: _operationId ??= _uuid.v4(),
      childId: _childId,
      amount: widget.isBonus || _deductPoints ? int.parse(_amountController.text.trim()) : 0,
      reason: reason,
      category: widget.isBonus ? 'bonus' : 'penalty',
      isBonus: widget.isBonus,
      hasPhoto: false,
      penaltyLinesCount:
          _hasLines == true ? int.parse(_linesController.text.trim()) : null,
      penaltyLinesInstruction:
          _hasLines == true ? _instructionController.text.trim() : null,
      sanctionType: _hasLines == true ? _sanctionType : null,
      sanctionLabel: _hasLines == true ? _sanctionLabel : null,
      onVerifying: () {
        if (mounted) setState(() => _verifying = true);
      },
    );
    try {
      await widget.onSubmit(draft);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _verifying = false;
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
                if (widget.children.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                        'Aucun profil enfant disponible. Ajoute un enfant avant d’enregistrer une action.'),
                  ),
                if (widget.children.length > 1) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_childId),
                    initialValue: _childId,
                    items: widget.children
                        .map((child) => DropdownMenuItem(
                              value: child.id,
                              child: Text(child.name),
                            ))
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() {
                              _childId = value!;
                              _operationId = null;
                            }),
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
                    onChanged: (_) => setState(() => _operationId = null),
                  ),
                ],
                const SizedBox(height: 12),
                if (!widget.isBonus)
                  SwitchListTile(
                    title: const Text('Retirer aussi des points'),
                    subtitle: const Text('Aucun retrait par défaut'),
                    value: _deductPoints,
                    onChanged: _submitting ? null : (value) => setState(() { _deductPoints = value; _operationId = null; }),
                  ),
                TextField(
                  key: const ValueKey('quick_amount'),
                  controller: _amountController,
                  enabled: !_submitting && (widget.isBonus || _deductPoints),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Points'),
                  onChanged: (_) => setState(() => _operationId = null),
                ),
                if (!widget.isBonus) ...[
                  const SizedBox(height: 16),
                  SanctionSelector(
                    enabled: !_submitting,
                    onChanged: (type, label, instruction) => setState(() {
                      _sanctionType = type;
                            if (type == null) _deductPoints = true;
                      _sanctionLabel = label;
                      _hasLines = type != null;
                      _linesController.text = (type == 'lines' || type == 'essay') ? '' : '1';
                      _instructionController.text = instruction;
                      _operationId = null;
                    }),
                  ),
                  if (_hasLines == true) ...[
                    if ((_sanctionType == 'lines' || _sanctionType == 'essay'))
                      TextField(
                        key: const ValueKey('quick_lines_count'),
                        controller: _linesController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: _sanctionType == 'essay' ? 'Nombre de lignes de rédaction' : 'Nombre de lignes à copier',
                        ),
                        onChanged: (_) => setState(() => _operationId = null),
                      ),
                    TextField(
                      controller: _instructionController,
                      enabled: !_submitting,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Consigne (quantité ou durée à préciser)',
                      ),
                      onChanged: (_) => setState(() => _operationId = null),
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
                if (!_serviceAvailable) ...[
                  const SizedBox(height: 12),
                  Text(
                    _serviceCheckFailed
                        ? 'Connexion au service impossible. Vérifie le réseau puis réessaie.'
                        : PointActionMaintenanceException.message,
                    key: const ValueKey('quick_maintenance_message'),
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  TextButton.icon(
                    onPressed: _checkingService
                        ? null
                        : () => _checkService(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Vérifier à nouveau'),
                  ),
                ],
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
                label: Text(_submitting
                    ? (_verifying
                        ? 'Vérification de l’enregistrement…'
                        : 'Enregistrement…')
                    : 'Appliquer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
