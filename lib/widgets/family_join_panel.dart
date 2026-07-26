import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_join_request.dart';
import '../services/family_join_coordinator.dart';
import '../services/family_join_service.dart';
import 'glass_card.dart';

class FamilyJoinPanel extends StatefulWidget {
  const FamilyJoinPanel({
    required this.onActivated,
    super.key,
  });

  final ValueChanged<String> onActivated;

  @override
  State<FamilyJoinPanel> createState() => _FamilyJoinPanelState();
}

class _FamilyJoinPanelState extends State<FamilyJoinPanel> {
  final FamilyJoinService _joinService = FamilyJoinService();
  final FamilyJoinCoordinator _coordinator = FamilyJoinCoordinator();

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _childNameController = TextEditingController();

  FamilyJoinRole _requestedRole = FamilyJoinRole.parent;
  PendingFamilyJoin? _pending;
  FamilyJoinStatus? _lastStatus;

  bool _isBusy = false;
  bool _isLoadingPending = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingRequest();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _childNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingRequest() async {
    try {
      final pending = await _joinService.loadPendingRequest();

      if (!mounted) return;

      setState(() {
        _pending = pending;
        _lastStatus = pending == null ? null : FamilyJoinStatus.pending;
        _isLoadingPending = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _messageForError(error);
        _isLoadingPending = false;
      });
    }
  }

  Future<void> _requestJoin() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.length < 4 || code.length > 10) {
      setState(() {
        _errorMessage =
            'Le code famille doit contenir entre 4 et 10 caractères.';
      });
      return;
    }

    if (_requestedRole == FamilyJoinRole.child &&
        _childNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Indique le prénom de l’enfant.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      final deviceId = preferences.getString('device_id');

      if (deviceId == null || deviceId.trim().isEmpty) {
        throw const FamilyJoinException(
          code: 'device-not-ready',
          message: 'L’identifiant de cet appareil est indisponible. '
              'Redémarre l’application puis réessaie.',
        );
      }

      await _joinService.requestFamilyJoin(
        code: code,
        requestedRole: _requestedRole,
        requestedChildName: _requestedRole == FamilyJoinRole.child
            ? _childNameController.text.trim()
            : null,
        deviceId: deviceId,
        deviceName: _deviceName,
      );

      final pending = await _joinService.loadPendingRequest();

      if (!mounted) return;

      setState(() {
        _pending = pending;
        _lastStatus = FamilyJoinStatus.pending;
        _isBusy = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _messageForError(error);
        _isBusy = false;
      });
    }
  }

  Future<void> _checkAuthorization() async {
    final pending = _pending;

    if (pending == null) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final result = await _coordinator.checkAndActivatePendingRequest();

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _pending = null;
          _lastStatus = null;
          _isBusy = false;
        });
        return;
      }

      if (result.isApproved) {
        final familyCode = pending.familyCode;

        setState(() {
          _pending = null;
          _lastStatus = FamilyJoinStatus.approved;
          _isBusy = false;
        });

        widget.onActivated(familyCode);
        return;
      }

      setState(() {
        _lastStatus = result.status;
        _isBusy = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _messageForError(error);
        _isBusy = false;
      });
    }
  }

  Future<void> _cancelPendingRequest() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      await _joinService.clearPendingRequest();

      if (!mounted) return;

      setState(() {
        _pending = null;
        _lastStatus = null;
        _isBusy = false;
        _codeController.clear();
        _childNameController.clear();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _messageForError(error);
        _isBusy = false;
      });
    }
  }

  String get _deviceName {
    if (kIsWeb) return 'Navigateur Web';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Appareil Android',
      TargetPlatform.iOS => 'iPhone ou iPad',
      TargetPlatform.macOS => 'Mac',
      TargetPlatform.windows => 'PC Windows',
      TargetPlatform.linux => 'Appareil Linux',
      TargetPlatform.fuchsia => 'Appareil mobile',
    };
  }

  String _messageForError(Object error) {
    if (error is FamilyJoinException) {
      return error.message;
    }

    return 'Une erreur est survenue. Vérifie la connexion puis réessaie.';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPending) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_pending != null) {
      return _buildPendingView();
    }

    return _buildRequestView();
  }

  Widget _buildRequestView() {
    const accent = Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Rejoindre une famille', accent),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          glowColor: accent,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: accent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Envoie une demande au parent de la famille. '
                'Les données resteront bloquées jusqu’à son autorisation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 18),
              SegmentedButton<FamilyJoinRole>(
                segments: const [
                  ButtonSegment(
                    value: FamilyJoinRole.parent,
                    icon: Icon(Icons.admin_panel_settings_rounded),
                    label: Text('Parent'),
                  ),
                  ButtonSegment(
                    value: FamilyJoinRole.child,
                    icon: Icon(Icons.child_care_rounded),
                    label: Text('Enfant'),
                  ),
                ],
                selected: {_requestedRole},
                onSelectionChanged: _isBusy
                    ? null
                    : (selection) {
                        setState(() {
                          _requestedRole = selection.first;
                          _errorMessage = null;

                          if (_requestedRole == FamilyJoinRole.parent) {
                            _childNameController.clear();
                          }
                        });
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                enabled: !_isBusy,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 10,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                decoration: const InputDecoration(
                  hintText: 'CODE FAMILLE',
                  counterText: '',
                  helperText: '4 à 10 lettres ou chiffres',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[A-Za-z0-9]'),
                  ),
                ],
                onSubmitted: (_) {
                  if (!_isBusy) _requestJoin();
                },
              ),
              if (_requestedRole == FamilyJoinRole.child) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _childNameController,
                  enabled: !_isBusy,
                  textCapitalization: TextCapitalization.words,
                  textAlign: TextAlign.center,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    hintText: 'Prénom de l’enfant',
                    counterText: '',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                  onSubmitted: (_) {
                    if (!_isBusy) _requestJoin();
                  },
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : _requestJoin,
                  icon: _isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isBusy ? 'Envoi en cours...' : 'Envoyer la demande',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingView() {
    final pending = _pending!;
    final rejected = _lastStatus == FamilyJoinStatus.rejected;
    final color = rejected ? const Color(0xFFFF5252) : Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(
          rejected ? 'Demande refusée' : 'Autorisation en attente',
          color,
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          glowColor: color,
          child: Column(
            children: [
              Icon(
                rejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded,
                color: color,
                size: 52,
              ),
              const SizedBox(height: 14),
              Text(
                rejected
                    ? 'Le parent a refusé cette demande.'
                    : 'La demande a été envoyée au parent de la famille.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Code : ${pending.familyCode}\n'
                'Profil demandé : '
                '${pending.requestedRole == FamilyJoinRole.parent ? 'Parent' : 'Enfant'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF5252),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (!rejected)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isBusy ? null : _checkAuthorization,
                    icon: _isBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _isBusy ? 'Vérification...' : 'Vérifier l’autorisation',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (!rejected) const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _cancelPendingRequest,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(
                    rejected
                        ? 'Effacer et recommencer'
                        : 'Annuler sur cet appareil',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        rejected ? const Color(0xFFFF5252) : Colors.white70,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
        shadows: [
          Shadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}
