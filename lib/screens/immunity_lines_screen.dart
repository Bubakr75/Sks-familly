import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/immunity_lines.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import 'trade_screens.dart';

class ImmunityLinesScreen extends StatelessWidget {
  const ImmunityLinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const NeonText(text: 'Lignes d\'immunite', fontSize: 18, color: Colors.white),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.3), blurRadius: 16)],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'add_immunity',
          backgroundColor: const Color(0xFF00E676),
          foregroundColor: Colors.black,
          onPressed: () => PinGuard.guardAction(context, () => _showAddImmunity(context)),
          icon: const Icon(Icons.shield_rounded),
          label: const Text('Donner des immunites', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, provider, _) {
          if (provider.children.isEmpty) {
            return AnimatedBackground(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlowIcon(icon: Icons.people_outline, size: 64, color: Colors.grey[600]),
                    const SizedBox(height: 16),
                    Text('Ajoutez des enfants d\'abord', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                  ],
                ),
              ),
            );
          }

          return AnimatedBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                ...provider.children.map((child) {
                  final totalAvailable = provider.getTotalAvailableImmunity(child.id);
                  final allImmunities = provider.getImmunitiesForChild(child.id);
                  final usable = allImmunities.where((im) => im.isUsable).toList();
                  final used = allImmunities.where((im) => im.isFullyUsed).toList();
                  final expired = allImmunities.where((im) => im.isExpired && !im.isFullyUsed).toList();

                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 16),
                    glowColor: totalAvailable > 0 ? const Color(0xFF00E676) : Colors.grey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(colors: [
                                  const Color(0xFF00E676).withValues(alpha: totalAvailable > 0 ? 0.2 : 0.05),
                                  const Color(0xFF00E676).withValues(alpha: totalAvailable > 0 ? 0.1 : 0.02),
                                ]),
                                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: totalAvailable > 0 ? 0.3 : 0.1)),
                              ),
                              child: Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 24))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text('${child.points} pts', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(colors: [
                                  const Color(0xFF00E676).withValues(alpha: totalAvailable > 0 ? 0.15 : 0.05),
                                  const Color(0xFF00E676).withValues(alpha: totalAvailable > 0 ? 0.08 : 0.02),
                                ]),
                                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: totalAvailable > 0 ? 0.3 : 0.1)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 20),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$totalAvailable',
                                    style: TextStyle(
                                      color: totalAvailable > 0 ? const Color(0xFF00E676) : Colors.grey,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text('lignes', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (allImmunities.isEmpty) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Text('Aucune immunite pour le moment', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ),
                        ],

                        if (usable.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00E676))),
                            const SizedBox(width: 6),
                            Text('Disponibles', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 8),
                          ...usable.map((im) => _immunityTile(context, im, provider, isActive: true)),
                        ],

                        if (used.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[600])),
                            const SizedBox(width: 6),
                            Text('Utilisees', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 8),
                          ...used.map((im) => _immunityTile(context, im, provider, isActive: false)),
                        ],

                        if (expired.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange[600])),
                            const SizedBox(width: 6),
                            Text('Expirees', style: TextStyle(color: Colors.orange[600], fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 8),
                          ...expired.map((im) => _immunityTile(context, im, provider, isActive: false)),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 18),
                        const SizedBox(width: 8),
                        const NeonText(text: 'Comment ca marche ?', fontSize: 14, color: Colors.white),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        '\u{1F6E1} Les lignes d\'immunite sont un stock de lignes gratuites.\n\n'
                        '\u{2728} Quand un enfant a des lignes de punition a faire, il peut utiliser ses lignes d\'immunite pour en faire moins.\n\n'
                        '\u{1F4CB} Exemple : 100 lignes de punition - 20 lignes d\'immunite = 80 lignes a faire.\n\n'
                        '\u{1F381} Vous pouvez donner des lignes d\'immunite pour recompenser le bon comportement.',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _immunityTile(BuildContext context, ImmunityLines im, FamilyProvider provider, {required bool isActive}) {
    return TvFocusWrapper(
      onTap: () {
        HapticFeedback.lightImpact();
        _showImmunityDetail(context, im, provider, isActive: isActive);
      },
      focusBorderColor: isActive ? const Color(0xFF00E676) : Colors.grey,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02),
          border: Border.all(color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08)),
            child: Center(child: Text('\u{1F6E1}', style: TextStyle(fontSize: 18, color: isActive ? null : Colors.grey)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(im.reason, style: TextStyle(color: isActive ? Colors.white : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Text(im.statusLabel, style: TextStyle(color: isActive ? const Color(0xFF00E676) : Colors.grey[600], fontSize: 11)),
              if (im.expiresAt != null) ...[const SizedBox(width: 8), Text(im.expiresLabel, style: TextStyle(color: im.isExpired ? Colors.orange : Colors.grey[600], fontSize: 10))],
            ]),
            Text('Donne le ${im.createdAt.day}/${im.createdAt.month}/${im.createdAt.year}', style: TextStyle(color: Colors.grey[700], fontSize: 10)),
          ])),
          if (isActive) Text('${im.availableLines}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, fontSize: 20))
          else Text('${im.usedLines}/${im.lines}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3), size: 20),
        ]),
      ),
    );
  }


  void _showImmunityDetail(BuildContext context, ImmunityLines im, FamilyProvider provider, {required bool isActive}) {
    final child = provider.getChild(im.childId);
    final dateStr = '${im.createdAt.day.toString().padLeft(2, '0')}/${im.createdAt.month.toString().padLeft(2, '0')}/${im.createdAt.year}';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                border: Border.all(color: isActive ? const Color(0xFF00E676).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3), width: 2),
              ),
              child: const Center(child: Text('\u{1F6E1}', style: TextStyle(fontSize: 32))),
            ),
            const SizedBox(height: 12),
            Text(im.reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(child?.name ?? 'Inconnu', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _immunityDetailChip('\u{1F6E1}', 'Total', '${im.lines}', const Color(0xFF00E676))),
              const SizedBox(width: 10),
              Expanded(child: _immunityDetailChip('\u{2705}', 'Utilisees', '${im.usedLines}', Colors.amber)),
              const SizedBox(width: 10),
              Expanded(child: _immunityDetailChip('\u{2728}', 'Disponibles', '${im.availableLines}', isActive ? const Color(0xFF00E676) : Colors.grey)),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text('Donne le $dateStr', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ]),
                if (im.expiresAt != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.timer_rounded, size: 14, color: im.isExpired ? Colors.orange : Colors.grey[500]),
                    const SizedBox(width: 8),
                    Text(im.expiresLabel, style: TextStyle(color: im.isExpired ? Colors.orange : Colors.grey[400], fontSize: 13)),
                  ]),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? const Color(0xFF00E676) : im.isExpired ? Colors.orange : Colors.grey)),
                  const SizedBox(width: 8),
                  Text(im.statusLabel, style: TextStyle(color: isActive ? const Color(0xFF00E676) : Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            if (isActive) ...[
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, im.id, provider);
                    },
                    icon: const Icon(Icons.delete_rounded, size: 18),
                    label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1744),
                      side: BorderSide(color: const Color(0xFFFF1744).withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TradeScreen(childId: im.childId)));
                    },
                    icon: const Icon(Icons.sell_rounded, size: 18),
                    label: const Text('Vendre'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _immunityDetailChip(String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, String imId, FamilyProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162033),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer cette immunite ?', style: TextStyle(color: Colors.white)),
        content: const Text('Les lignes disponibles seront perdues.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
            onPressed: () {
              provider.removeImmunity(imId);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showAddImmunity(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final linesCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String? selectedChildId = provider.children.isNotEmpty ? provider.children.first.id : null;
    bool hasExpiry = false;
    int expiryDays = 7;

    final presetReasons = [
      {'reason': 'Bon comportement', 'lines': 10},
      {'reason': 'Bonne note a l\'ecole', 'lines': 20},
      {'reason': 'A aide a la maison', 'lines': 15},
      {'reason': 'Recompense speciale', 'lines': 30},
      {'reason': 'Sage toute la semaine', 'lines': 25},
      {'reason': 'A range sa chambre', 'lines': 10},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const NeonText(text: 'Donner des immunites', fontSize: 18, color: Colors.white),
                ]),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedChildId,
                  dropdownColor: const Color(0xFF162033),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enfant',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  items: provider.children.map((c) => DropdownMenuItem(value: c.id, child: Text('\u{1F466} ${c.name}'))).toList(),
                  onChanged: (v) => setState(() => selectedChildId = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Raison',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presetReasons.map((p) => GestureDetector(
                    onTap: () => setState(() {
                      reasonCtrl.text = p['reason'] as String;
                      linesCtrl.text = '${p['lines']}';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text('${p['reason']} (${p['lines']})', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: linesCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Nombre de lignes d\'immunite',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    suffixText: 'lignes',
                    suffixStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Switch(
                      value: hasExpiry,
                      activeColor: const Color(0xFF00E676),
                      onChanged: (v) => setState(() => hasExpiry = v),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasExpiry ? 'Expire dans $expiryDays jours' : 'Pas d\'expiration',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (hasExpiry)
                  Slider(
                    value: expiryDays.toDouble(),
                    min: 1,
                    max: 90,
                    divisions: 89,
                    activeColor: const Color(0xFF00E676),
                    label: '$expiryDays jours',
                    onChanged: (v) => setState(() => expiryDays = v.round()),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final lines = int.tryParse(linesCtrl.text) ?? 0;
                      if (selectedChildId != null && reasonCtrl.text.isNotEmpty && lines > 0) {
                        final expiry = hasExpiry ? DateTime.now().add(Duration(days: expiryDays)) : null;
                        provider.addImmunity(selectedChildId!, reasonCtrl.text, lines, expiresAt: expiry);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [
                              const Text('\u{1F6E1}', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(child: Text('$lines lignes d\'immunite donnees !')),
                            ]),
                            backgroundColor: const Color(0xFF00E676),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.shield_rounded),
                    label: const Text('Donner les immunites', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
