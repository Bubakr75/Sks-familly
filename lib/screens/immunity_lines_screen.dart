import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'trade_screen.dart';

class ImmunityLinesScreen extends StatefulWidget {
  const ImmunityLinesScreen({super.key});
  @override
  State<ImmunityLinesScreen> createState() => _ImmunityLinesScreenState();
}

class _ImmunityLinesScreenState extends State<ImmunityLinesScreen>
    with TickerProviderStateMixin {
  late AnimationController _shieldPulseController;
  late Animation<double> _shieldPulse;

  @override
  void initState() {
    super.initState();
    _shieldPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _shieldPulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _shieldPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shieldPulseController.dispose();
    super.dispose();
  }

  String _getStatusLabel(Map<String, dynamic> immunity) {
    if (immunity['used'] == true) return 'Utilisée';
    final expiry = immunity['expiry'] as DateTime?;
    if (expiry != null && expiry.isBefore(DateTime.now())) return 'Expirée';
    return 'Disponible';
  }

  Color _getStatusColor(Map<String, dynamic> immunity) {
    final label = _getStatusLabel(immunity);
    switch (label) {
      case 'Disponible':
        return Colors.green;
      case 'Utilisée':
        return Colors.grey;
      case 'Expirée':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(Map<String, dynamic> immunity) {
    final label = _getStatusLabel(immunity);
    switch (label) {
      case 'Disponible':
        return Icons.shield;
      case 'Utilisée':
        return Icons.shield_outlined;
      case 'Expirée':
        return Icons.timer_off;
      default:
        return Icons.shield_outlined;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: TvFocusWrapper(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                ).createShader(bounds),
                child: const Text(
                  '🛡️ Lignes d\'Immunité',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              actions: [
                TvFocusWrapper(
                  onTap: () => _showAddImmunity(fp),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.amber),
                  ),
                ),
              ],
            ),
            body: children.isEmpty
                ? Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(scale: value, child: child),
                        );
                      },
                      child: const Text('Aucun enfant enregistré',
                          style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final immunities = fp.getImmunitiesForChild(child.id);
                      final available = immunities
                          .where((i) =>
                              _getStatusLabel(i) == 'Disponible')
                          .length;

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 500 + index * 200),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Child header with animated shield
                                Row(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _shieldPulse,
                                      builder: (context, _) {
                                        return Transform.scale(
                                          scale: available > 0
                                              ? _shieldPulse.value
                                              : 0.8,
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: available > 0
                                                  ? Colors.amber
                                                      .withOpacity(0.2)
                                                  : Colors.grey
                                                      .withOpacity(0.1),
                                              boxShadow: available > 0
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.amber
                                                            .withOpacity(0.3 *
                                                                _shieldPulse
                                                                    .value),
                                                        blurRadius: 16,
                                                        spreadRadius: 2,
                                                      ),
                                                    ]
                                                  : [],
                                            ),
                                            child: Icon(
                                              Icons.shield,
                                              color: available > 0
                                                  ? Colors.amber
                                                  : Colors.grey,
                                              size: 24,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(child.name,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                          TweenAnimationBuilder<int>(
                                            tween: IntTween(
                                                begin: 0, end: available),
                                            duration: const Duration(
                                                milliseconds: 1000),
                                            builder: (context, val, _) {
                                              return Text(
                                                '$val immunité${val > 1 ? 's' : ''} disponible${val > 1 ? 's' : ''}',
                                                style: TextStyle(
                                                  color: available > 0
                                                      ? Colors.amber[300]
                                                      : Colors.white38,
                                                  fontSize: 12,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (immunities.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.white12),
                                  const SizedBox(height: 8),
                                  ...immunities.asMap().entries.map((entry) {
                                    final i = entry.key;
                                    final imm = entry.value;
                                    final status = _getStatusLabel(imm);
                                    final statusColor = _getStatusColor(imm);

                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(
                                          milliseconds: 300 + i * 100),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) {
                                        return Transform.translate(
                                          offset:
                                              Offset(20 * (1 - value), 0),
                                          child: Opacity(
                                              opacity: value, child: child),
                                        );
                                      },
                                      child: TvFocusWrapper(
                                        onTap: () => _showImmunityDetail(
                                            imm, child, fp),
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: statusColor
                                                .withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: statusColor
                                                  .withOpacity(0.2),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(_getStatusIcon(imm),
                                                  color: statusColor,
                                                  size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      imm['reason'] ??
                                                          'Immunité',
                                                      style:
                                                          const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${imm['lineCount'] ?? 1} ligne${(imm['lineCount'] ?? 1) > 1 ? 's' : ''}',
                                                      style:
                                                          const TextStyle(
                                                        color: Colors.white38,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  void _showAddImmunity(FamilyProvider fp) {
    String? selectedChildId;
    final reasonController = TextEditingController();
    int lineCount = 1;
    DateTime? expiry;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shield animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                            scale: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shield,
                            color: Colors.amber, size: 40),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Nouvelle Immunité',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Child picker
                    Wrap(
                      spacing: 8,
                      children: fp.children.map((child) {
                        final selected = selectedChildId == child.id;
                        return TvFocusWrapper(
                          onTap: () => setSheetState(
                              () => selectedChildId = child.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.amber.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Colors.amber
                                    : Colors.white12,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Text(child.name,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.amber
                                      : Colors.white54,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                )),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Reason
                    TextField(
                      controller: reasonController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Raison de l\'immunité',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.edit,
                            color: Colors.amber, size: 18),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.amber.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.amber),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Line count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Lignes: ',
                            style: TextStyle(color: Colors.white54)),
                        TvFocusWrapper(
                          onTap: () {
                            if (lineCount > 1) {
                              setSheetState(() => lineCount--);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: const Icon(Icons.remove,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: lineCount),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, val, _) {
                            return Text('$val',
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold));
                          },
                        ),
                        const SizedBox(width: 16),
                        TvFocusWrapper(
                          onTap: () => setSheetState(() => lineCount++),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Expiry date
                    TvFocusWrapper(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate:
                              DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setSheetState(() => expiry = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              expiry != null
                                  ? 'Expire le ${_formatDate(expiry!)}'
                                  : 'Date d\'expiration (optionnel)',
                              style: TextStyle(
                                color: expiry != null
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit
                    TvFocusWrapper(
                      onTap: () {
                        if (selectedChildId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Sélectionne un enfant'),
                                backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        fp.addImmunity(
                          selectedChildId!,
                          reason: reasonController.text.isNotEmpty
                              ? reasonController.text
                              : 'Immunité',
                          lineCount: lineCount,
                          expiry: expiry,
                        );
                        Navigator.pop(ctx);
                        _showCreateAnimation();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.amber, Colors.orange],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🛡️ Créer l\'immunité',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateAnimation() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.of(context).canPop()) Navigator.pop(context);
        });
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 60),
            ),
          ),
        );
      },
    );
  }

  void _showImmunityDetail(
      Map<String, dynamic> imm, ChildModel child, FamilyProvider fp) {
    final status = _getStatusLabel(imm);
    final statusColor = _getStatusColor(imm);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Shield icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.15),
                  ),
                  child: Icon(_getStatusIcon(imm),
                      color: statusColor, size: 36),
                ),
                const SizedBox(height: 12),

                Text(imm['reason'] ?? 'Immunité',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                _detailRow('Enfant', child.name),
                _detailRow('Lignes', '${imm['lineCount'] ?? 1}'),
                _detailRow('Statut', status, color: statusColor),
                if (imm['expiry'] != null)
                  _detailRow('Expire', _formatDate(imm['expiry'] as DateTime)),
                if (imm['createdAt'] != null)
                  _detailRow('Créée', _formatDate(imm['createdAt'] as DateTime)),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    // Delete
                    Expanded(
                      child: TvFocusWrapper(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showDeleteConfirm(imm, child, fp);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: Text('🗑️ Supprimer',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Trade
                    if (status == 'Disponible')
                      Expanded(
                        child: TvFocusWrapper(
                          onTap: () {
                            Navigator.pop(ctx);
                            // ★ TRANSITION PORTE vers TradeScreen
                            Navigator.push(context,
                                DoorPageRoute(page: const TradeScreen()));
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.green, Colors.teal],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text('🤝 Échanger',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(
      Map<String, dynamic> imm, ChildModel child, FamilyProvider fp) {
    showDialog(
      context: context,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Supprimer cette immunité ?',
                style: TextStyle(color: Colors.white)),
            content: Text(
              '${imm['reason'] ?? 'Immunité'} pour ${child.name}',
              style: const TextStyle(color: Colors.white54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  fp.deleteImmunity(child.id, imm['id']);
                  Navigator.pop(context);
                  _showBreakAnimation();
                },
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBreakAnimation() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (Navigator.of(context).canPop()) Navigator.pop(context);
        });
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 0.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.5 + value * 0.8,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: (1 - value) * 0.5,
                    child: child,
                  ),
                ),
              );
            },
            child: const Text('🛡️💥', style: TextStyle(fontSize: 60)),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value,
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
