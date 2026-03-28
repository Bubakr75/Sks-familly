import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';

class PunishmentLinesScreen extends StatefulWidget {
  const PunishmentLinesScreen({super.key});
  @override
  State<PunishmentLinesScreen> createState() => _PunishmentLinesScreenState();
}

class _PunishmentLinesScreenState extends State<PunishmentLinesScreen>
    with TickerProviderStateMixin {

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
                  colors: [Colors.red, Colors.orange],
                ).createShader(bounds),
                child: const Text(
                  '📕 Lignes de Punition',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              actions: [
                TvFocusWrapper(
                  onTap: () => _showAddPunishment(fp),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.red),
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
                          style:
                              TextStyle(color: Colors.white54, fontSize: 16)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final punishments =
                          fp.getPunishmentsForChild(child.id);

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration:
                            Duration(milliseconds: 500 + index * 200),
                        curve: Curves.easeOutBack,
                        builder: (context, value, w) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child: Opacity(opacity: value, child: w),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor:
                                          Colors.red.withOpacity(0.2),
                                      child: Text(
                                        child.name.isNotEmpty
                                            ? child.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(child.name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Text(
                                      '${punishments.length} punition${punishments.length > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                                if (punishments.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.white12),
                                  const SizedBox(height: 8),
                                  ...punishments
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final i = entry.key;
                                    final p = entry.value;
                                    final progress =
                                        (p['completed'] as int? ?? 0) /
                                            (p['lineCount'] as int? ?? 1);
                                    final isDone = progress >= 1.0;

                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(
                                          milliseconds: 300 + i * 100),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                              20 * (1 - value), 0),
                                          child: Opacity(
                                              opacity: value,
                                              child: child),
                                        );
                                      },
                                      child: TvFocusWrapper(
                                        onTap: () =>
                                            _showPunishmentDetail(
                                                p, child, fp),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                              bottom: 8),
                                          padding:
                                              const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isDone
                                                ? Colors.green
                                                    .withOpacity(0.08)
                                                : Colors.red
                                                    .withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDone
                                                  ? Colors.green
                                                      .withOpacity(0.2)
                                                  : Colors.red
                                                      .withOpacity(0.2),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    isDone
                                                        ? Icons.check_circle
                                                        : Icons.menu_book,
                                                    color: isDone
                                                        ? Colors.green
                                                        : Colors.red,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      p['reason'] ??
                                                          'Punition',
                                                      style:
                                                          const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${p['completed'] ?? 0}/${p['lineCount'] ?? 0}',
                                                    style: TextStyle(
                                                      color: isDone
                                                          ? Colors.green
                                                          : Colors.red[300],
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              // Animated progress bar
                                              TweenAnimationBuilder<double>(
                                                tween: Tween(
                                                    begin: 0.0,
                                                    end: progress
                                                        .clamp(0.0, 1.0)),
                                                duration: const Duration(
                                                    milliseconds: 800),
                                                curve: Curves.easeOutCubic,
                                                builder:
                                                    (context, val, _) {
                                                  return ClipRRect(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(4),
                                                    child: Stack(
                                                      children: [
                                                        Container(
                                                          height: 8,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .white
                                                                .withOpacity(
                                                                    0.08),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                        ),
                                                        FractionallySizedBox(
                                                          widthFactor: val,
                                                          child: Container(
                                                            height: 8,
                                                            decoration:
                                                                BoxDecoration(
                                                              gradient:
                                                                  LinearGradient(
                                                                colors: isDone
                                                                    ? [
                                                                        Colors.green,
                                                                        Colors.green.shade700
                                                                      ]
                                                                    : [
                                                                        Colors.red,
                                                                        Colors.red.shade700
                                                                      ],
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: (isDone
                                                                          ? Colors.green
                                                                          : Colors.red)
                                                                      .withOpacity(0.4),
                                                                  blurRadius:
                                                                      4,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
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

  void _showAddPunishment(FamilyProvider fp) {
    String? selectedChildId;
    final reasonController = TextEditingController();
    int lineCount = 10;

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

                    // Notebook animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: -0.5, end: 0.0),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform(
                          alignment: Alignment.centerLeft,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.002)
                            ..rotateY(value),
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.menu_book,
                            color: Colors.red, size: 40),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Nouvelle Punition',
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
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Colors.red
                                    : Colors.white12,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Text(child.name,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.red
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
                        hintText: 'Raison de la punition',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.edit,
                            color: Colors.red, size: 18),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.red.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.red),
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
                                    color: Colors.red,
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
                    const SizedBox(height: 20),

                    // Submit
                    TvFocusWrapper(
                      onTap: () {
                        if (selectedChildId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Sélectionne un enfant'),
                                backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        fp.addPunishment(
                          selectedChildId!,
                          reason: reasonController.text.isNotEmpty
                              ? reasonController.text
                              : 'Punition',
                          lineCount: lineCount,
                        );
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red, Colors.red.shade700],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('📕 Créer la punition',
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

  void _showPunishmentDetail(
      Map<String, dynamic> p, ChildModel child, FamilyProvider fp) {
    final completed = p['completed'] as int? ?? 0;
    final total = p['lineCount'] as int? ?? 1;
    final progress = (completed / total).clamp(0.0, 1.0);
    final isDone = progress >= 1.0;

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
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
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
                Text(p['reason'] ?? 'Punition',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _detailRow('Enfant', child.name),
                _detailRow('Progrès', '$completed / $total lignes'),
                _detailRow(
                    'Statut', isDone ? 'Terminé ✅' : 'En cours',
                    color: isDone ? Colors.green : Colors.orange),
                const SizedBox(height: 12),

                // Progress bar
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return Column(
                      children: [
                        Text(
                          '${(val * 100).round()}%',
                          style: TextStyle(
                            color: isDone ? Colors.green : Colors.red,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: val,
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(
                                isDone ? Colors.green : Colors.red),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: TvFocusWrapper(
                        onTap: () {
                          fp.deletePunishment(child.id, p['id']);
                          Navigator.pop(ctx);
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
                    if (!isDone) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: TvFocusWrapper(
                          onTap: () {
                            fp.completePunishment(child.id, p['id']);
                            Navigator.pop(ctx);
                            _showCompleteAnimation();
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
                              child: Text('✅ Terminé',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCompleteAnimation() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
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
                color: Colors.green.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 60),
            ),
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
