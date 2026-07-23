// lib/widgets/point_action_panel.dart
//
// Composant partagé pour les écrans Bonus et Pénalité.
// Gère : sélection enfant, cartes de motifs, montant, aperçu, validation,
// état de chargement, historique récent, animations.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import '../utils/checklist_helpers.dart';
import '../utils/motif_helpers.dart';
import '../services/motif_preferences_service.dart';

/// Configuration d'un motif de bonus ou pénalité.
class ActionMotif {
  final String id;
  final String emoji;
  final String label;
  final int defaultPoints;
  final bool isOther;

  const ActionMotif(
    this.id,
    this.emoji,
    this.label,
    this.defaultPoints, {
    this.isOther = false,
  });
}

/// Configuration visuelle et métier du panneau.
class PointActionConfig {
  final String title;
  final String subtitle;
  final String buttonText;
  final String category;
  final bool isBonus;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final List<ActionMotif> motifs;
  final IconData buttonIcon;
  final String successMessage;

  const PointActionConfig({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.category,
    required this.isBonus,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.motifs,
    required this.buttonIcon,
    required this.successMessage,
  });
}

/// Panneau d'action partagé pour Bonus et Pénalité.
/// Le montant se modifie par boutons et presets. Le motif "Autre" permet
/// un champ texte personnalisé pour décrire l'action précisément.
class PointActionPanel extends StatefulWidget {
  final PointActionConfig config;
  const PointActionPanel({super.key, required this.config});

  @override
  State<PointActionPanel> createState() => _PointActionPanelState();
}

class _PointActionPanelState extends State<PointActionPanel>
    with SingleTickerProviderStateMixin {
  String? _selectedChildId;
  ActionMotif? _selectedMotif;
  int _amount = 5;
  bool _processing = false;
  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnim;
  late TextEditingController _customTextCtrl;
  late FocusNode _customFocusNode;
  Set<String> _favorites = {};
  Map<String, int> _usage = {};
  List<ActionMotif> _sortedMotifs = [];

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _celebrationAnim = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeOut,
    );
    _customTextCtrl = TextEditingController();
    _customFocusNode = FocusNode();
    _sortedMotifs = widget.config.motifs;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final favs = await MotifPreferencesService.loadFavorites(
          widget.config.isBonus);
      final usage = await MotifPreferencesService.loadUsage(
          widget.config.isBonus);
      if (mounted) {
        setState(() {
          _favorites = favs;
          _usage = usage;
          _sortedMotifs = MotifPreferencesService.sortMotifs(
            motifs: widget.config.motifs,
            getId: (m) => m.id,
            isOther: (m) => m.isOther,
            favorites: favs,
            usage: usage,
          );
        });
      }
    } catch (_) {
      // Garder l'ordre par défaut silencieusement
    }
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _customTextCtrl.dispose();
    _customFocusNode.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _selectedChildId != null && _selectedMotif != null && !_processing && _isMotifValid;

  /// Un motif classique est toujours valide. "Autre" nécessite un texte non vide.
  bool get _isMotifValid {
    if (_selectedMotif == null) return false;
    if (_selectedMotif!.isOther) {
      return isValidCustomText(_customTextCtrl.text);
    }
    return true;
  }

  void _selectMotif(ActionMotif motif) {
    setState(() {
      _selectedMotif = motif;
      _amount = motif.defaultPoints;
      // Si on quitte "Autre", vider le texte et retirer le focus
      if (!motif.isOther) {
        _customTextCtrl.clear();
        _customFocusNode.unfocus();
      }
    });
    HapticFeedback.selectionClick();
    // Si on sélectionne "Autre", donner le focus après le build
    if (motif.isOther) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _customFocusNode.requestFocus();
      });
    }
  }

  void _adjustAmount(int delta) {
    setState(() {
      _amount = (_amount + delta).clamp(1, 999);
    });
    HapticFeedback.selectionClick();
  }

  void _setAmount(int value) {
    setState(() {
      _amount = value.clamp(1, 999);
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _apply() async {
    if (!_isValid) return;

    final fp = context.read<FamilyProvider>();
    final child = fp.getChild(_selectedChildId!);

    // 🔒 Pour une pénalité avec solde nul : aucune action
    if (!widget.config.isBonus && (child == null || child.points <= 0)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cet enfant n\'a aucun point à retirer'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    final messenger = ScaffoldMessenger.of(context);
    final childName = child?.name ?? '';
    final capturedMotif = _selectedMotif!;
    // 🔒 Calculer la raison via helper
    final reason = buildReason(
      isOther: capturedMotif.isOther,
      emoji: capturedMotif.emoji,
      label: capturedMotif.label,
      customText: _customTextCtrl.text,
    );

    // 🔒 Montant réel via helper testable
    final actualAmount = actualPenaltyAmount(
      requested: _amount,
      balance: child!.points,
      isBonus: widget.config.isBonus,
    );

    try {
      await fp.addPoints(
        _selectedChildId!,
        actualAmount,
        reason,
        category: widget.config.category,
        isBonus: widget.config.isBonus,
      );

      if (!mounted) return;

      // Animation de célébration
      if (!MediaQuery.of(context).disableAnimations) {
        _celebrationController.forward().then((_) {
          if (mounted) _celebrationController.reset();
        });
      }

      HapticFeedback.heavyImpact();
      messenger.showSnackBar(SnackBar(
        content: Text(widget.config.successMessage
            .replaceAll('{name}', childName)
            .replaceAll('{amount}', '$actualAmount')),
        backgroundColor: widget.config.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));

      // Reset partiel : garder l'enfant, effacer le motif et le texte
      setState(() {
        _selectedMotif = null;
        _customTextCtrl.clear();
        _customFocusNode.unfocus();
      });

      // 📊 Incrémenter le compteur d'utilisation après succès
      if (!capturedMotif.isOther) {
        await MotifPreferencesService.incrementUsage(
            widget.config.isBonus, capturedMotif.id);
        await _loadPreferences();
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Erreur lors de l\'application des points'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final children = fp.children;
    final config = widget.config;

    // Auto-sélection du premier enfant
    if (_selectedChildId == null && children.isNotEmpty) {
      _selectedChildId = children.first.id;
    }

    final selectedChild =
        _selectedChildId != null ? fp.getChild(_selectedChildId!) : null;

    return Stack(
      children: [
        // Contenu principal
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Titre ──
              Text(config.title,
                  style: TextStyle(
                      color: config.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(config.subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 20),

              // ── Sélection enfant ──
              if (children.length > 1)
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: children.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final c = children[i];
                      final isSel = c.id == _selectedChildId;
                      return GestureDetector(
                        onTap: _processing
                            ? null
                            : () => setState(() {
                                  _selectedChildId = c.id;
                                  _selectedMotif = null;
                                }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? config.primaryColor.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isSel
                                    ? config.primaryColor
                                    : Colors.white12,
                                width: isSel ? 2 : 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(c.avatar.isNotEmpty ? c.avatar : '👤',
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(c.name,
                                      style: TextStyle(
                                          color: isSel
                                              ? config.accentColor
                                              : Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  Text('${c.points} pts',
                                      style: TextStyle(
                                          color: config.primaryColor
                                              .withValues(alpha: 0.7),
                                          fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // ── Cartes de motifs ──
              Text('Choisis un motif',
                  style: TextStyle(
                      color: config.accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _sortedMotifs.map((motif) {
                  final isSel = _selectedMotif?.label == motif.label;
                  final isFav = _favorites.contains(motif.id);
                  return GestureDetector(
                    onTap: _processing ? null : () => _selectMotif(motif),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: motif.isOther ? double.infinity : 150,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSel
                            ? config.primaryColor.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isSel ? config.primaryColor : Colors.white12,
                            width: isSel ? 2 : 1),
                      ),
                      child: Column(
                        children: [
                          // Étoile favori (sauf pour "Autre")
                          if (!motif.isOther)
                            Align(
                              alignment: Alignment.topRight,
                              child: GestureDetector(
                                onTap: _processing
                                    ? null
                                    : () async {
                                        HapticFeedback.selectionClick();
                                        final newFavs = await MotifPreferencesService
                                            .toggleFavorite(
                                                widget.config.isBonus,
                                                motif.id);
                                        if (mounted) {
                                          setState(() {
                                            _favorites = newFavs;
                                            _sortedMotifs =
                                                MotifPreferencesService
                                                    .sortMotifs(
                                              motifs: widget.config.motifs,
                                              getId: (m) => m.id,
                                              isOther: (m) => m.isOther,
                                              favorites: _favorites,
                                              usage: _usage,
                                            );
                                          });
                                        }
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Icon(
                                    isFav
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: isFav
                                        ? const Color(0xFFFFD54F)
                                        : Colors.white24,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          Text(motif.emoji,
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 6),
                          Text(motif.label,
                              style: TextStyle(
                                  color: isSel
                                      ? config.accentColor
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 2),
                          Text(
                              '${widget.config.isBonus ? "+" : "-"}${motif.defaultPoints} pts',
                              style: TextStyle(
                                  color: config.primaryColor
                                      .withValues(alpha: 0.6),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // ── Champ texte pour motif "Autre" ──
              if (_selectedMotif?.isOther == true) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customTextCtrl,
                  focusNode: _customFocusNode,
                  enabled: !_processing,
                  maxLength: 100,
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: config.accentColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: widget.config.isBonus
                        ? 'Décris la bonne action…'
                        : 'Décris le comportement…',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: config.primaryColor.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: config.primaryColor.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: config.primaryColor, width: 2),
                    ),
                    counterStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
              ] else ...[
                const SizedBox(height: 24),
              ],

              // ── Montant ──
              if (_selectedMotif != null) ...[
                Text('Montant',
                    style: TextStyle(
                        color: config.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _processing ? null : () => _adjustAmount(-1),
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.white54, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: config.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: config.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                          '${widget.config.isBonus ? "+" : "-"}$_amount',
                          style: TextStyle(
                              color: config.primaryColor,
                              fontSize: 32,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: _processing ? null : () => _adjustAmount(1),
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.white54, size: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Presets rapides
                Wrap(
                  spacing: 8,
                  children: [1, 2, 3, 5, 10].map((v) {
                    return GestureDetector(
                      onTap: _processing ? null : () => _setAmount(v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _amount == v
                              ? config.primaryColor.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _amount == v
                                  ? config.primaryColor.withValues(alpha: 0.5)
                                  : Colors.white12),
                        ),
                        child: Text('$v',
                            style: TextStyle(
                                color: _amount == v
                                    ? config.accentColor
                                    : Colors.white54,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── Aperçu ──
                if (selectedChild != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: config.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            selectedChild.avatar.isNotEmpty
                                ? selectedChild.avatar
                                : '👤',
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Text('${selectedChild.name}:',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('${selectedChild.points}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 18)),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: config.primaryColor.withValues(alpha: 0.5),
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                            widget.config.isBonus
                                ? '${selectedChild.points + _amount}'
                                : '${(selectedChild.points - (selectedChild.points <= 0 ? 0 : _amount.clamp(1, selectedChild.points))).clamp(0, 999)}',
                            style: TextStyle(
                                color: config.primaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Historique récent (3 dernières) ──
                ..._buildRecentHistory(fp, selectedChild?.id ?? ''),

                const SizedBox(height: 20),
              ],
            ],
          ),
        ),

        // ── Bouton flottant de validation ──
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isValid ? config.primaryColor : Colors.white12,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: _isValid ? 6 : 0,
            ),
            onPressed: _isValid ? _apply : null,
            icon: _processing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(config.buttonIcon),
            label: Text(
              _processing ? 'Enregistrement...' : config.buttonText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // ── Animation de célébration ──
        if (_celebrationController.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _celebrationAnim,
                builder: (_, __) {
                  return Opacity(
                    opacity: (1 - _celebrationAnim.value) * 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            config.primaryColor.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  /// Affiche les 3 derniers bonus ou pénalités de l'enfant sélectionné.
  List<Widget> _buildRecentHistory(FamilyProvider fp, String childId) {
    if (childId.isEmpty) return [];
    final config = widget.config;
    final recent = fp.history
        .where((h) =>
            h.childId == childId &&
            h.isBonus == config.isBonus &&
            h.category == config.category &&
            !h.isPurchase &&
            !h.isPointsTransfer)
        .take(3)
        .toList();
    if (recent.isEmpty) return [];

    return [
      Text('Derniers ${config.isBonus ? "bonus" : "pénalités"}',
          style: TextStyle(
              color: config.accentColor.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      ...recent.map((h) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                    config.isBonus
                        ? Icons.add_circle_rounded
                        : Icons.remove_circle_rounded,
                    color: config.primaryColor.withValues(alpha: 0.7),
                    size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(h.reason,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${config.isBonus ? "+" : "-"}${h.points}',
                    style: TextStyle(
                        color: config.primaryColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          )),
    ];
  }
}
