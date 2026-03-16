import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/immunity_lines.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class ImmunityLinesScreen extends StatelessWidget {
  const ImmunityLinesScreen({super.key});

  static const _shieldColor = Color(0xFF00E676);
  static const _goldColor = Color(0xFFFFD740);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          title: NeonText(text: 'Lignes d\'immunite', fontSize: 18, color: Colors.white),
          backgroundColor: Colors.transparent,
          bottom: TabBar(
            indicatorColor: _shieldColor,
            indicatorWeight: 3,
            labelColor: _shieldColor,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(icon: Icon(Icons.shield_outlined), text: 'En cours'),
              Tab(icon: Icon(Icons.verified_rounded), text: 'Terminees'),
            ],
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _shieldColor.withValues(alpha: 0.3), blurRadius: 16)],
          ),
          child: FloatingActionButton.extended(
            heroTag: 'add_immunity',
            backgroundColor: _shieldColor,
            foregroundColor: Colors.black,
            onPressed: () => PinGuard.guardAction(context, () => _showAddImmunity(context)),
            icon: const Icon(Icons.shield_rounded),
            label: const Text('Attribuer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        body: Consumer<FamilyProvider>(
          builder: (context, provider, _) {
            final active = provider.immunities.where((im) => !im.isCompleted).toList();
            final completed = provider.immunities.where((im) => im.isCompleted).toList();

            return AnimatedBackground(
              child: TabBarView(
                children: [
                  active.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlowIcon(icon: Icons.shield_outlined, size: 64, color: Colors.grey[600]),
                              const SizedBox(height: 16),
                              Text('Aucune immunite en cours', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                              const SizedBox(height: 8),
                              Text('Attribuez une immunite a un enfant', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: active.length,
                          itemBuilder: (_, i) => _ImmunityCard(immunity: active[i], provider: provider, showActions: true),
                        ),
                  completed.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlowIcon(icon: Icons.verified_rounded, size: 64, color: Colors.grey[600]),
                              const SizedBox(height: 16),
                              Text('Aucune immunite terminee', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: completed.length,
                          itemBuilder: (_, i) => _ImmunityCard(immunity: completed[i], provider: provider, showActions: false),
                        ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddImmunity(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final textCtrl = TextEditingController(text: 'Je suis dispense(e) de cette tache grace a mon immunite.');
    final linesCtrl = TextEditingController(text: '10');
    String? selectedChildId = provider.children.isNotEmpty ? provider.children.first.id : null;
    String selectedType = 'custom';
    int expirationDays = 0;
    final presets = [5, 10, 20, 50, 100];

    final immunityTypes = [
      {'value': 'corvee', 'label': 'Corvee', 'emoji': '\u{1F9F9}'},
      {'value': 'punition', 'label': 'Punition', 'emoji': '\u{1F6E1}'},
      {'value': 'devoir', 'label': 'Devoir', 'emoji': '\u{1F4DA}'},
      {'value': 'custom', 'label': 'Speciale', 'emoji': '\u{2B50}'},
    ];

    final expirationOptions = [
      {'days': 0, 'label': 'Pas de limite'},
      {'days': 1, 'label': '1 jour'},
      {'days': 3, 'label': '3 jours'},
      {'days': 7, 'label': '1 semaine'},
      {'days': 14, 'label': '2 semaines'},
      {'days': 30, 'label': '1 mois'},
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
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: _shieldColor.withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: _shieldColor.withValues(alpha: 0.3))),
                    child: const Icon(Icons.shield_rounded, color: _shieldColor),
                  ),
                  const SizedBox(width: 12),
                  const NeonText(text: 'Attribuer une immunite', fontSize: 18, color: Colors.white),
                ]),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: selectedChildId,
                  dropdownColor: const Color(0xFF162033),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Enfant', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: provider.children.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}'))).toList(),
                  onChanged: (v) => setState(() => selectedChildId = v),
                ),
                const SizedBox(height: 16),

                const Text('Type d\'immunite', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: immunityTypes.map((type) {
                    final isSelected = selectedType == type['value'];
                    return GestureDetector(
                      onTap: () => setState(() => selectedType = type['value'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? _shieldColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: isSelected ? _shieldColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(type['emoji'] as String, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(type['label'] as String, style: TextStyle(color: isSelected ? _shieldColor : Colors.grey[500], fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Texte a copier', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),

                const Text('Nombre de lignes', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: presets.map((n) {
                    final isSelected = linesCtrl.text == n.toString();
                    return GestureDetector(
                      onTap: () => setState(() => linesCtrl.text = n.toString()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected ? _shieldColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: isSelected ? _shieldColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text('$n', style: TextStyle(color: isSelected ? _shieldColor : Colors.grey[500], fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linesCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _shieldColor),
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), labelText: 'Nombre exact', suffixText: 'lignes'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                const Text('Date d\'expiration', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: expirationOptions.map((opt) {
                    final isSelected = expirationDays == opt['days'];
                    return GestureDetector(
                      onTap: () => setState(() => expirationDays = opt['days'] as int),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected ? _goldColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: isSelected ? _goldColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.timer_outlined, size: 14, color: isSelected ? _goldColor : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(opt['label'] as String, style: TextStyle(color: isSelected ? _goldColor : Colors.grey[500], fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontSize: 12)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _shieldColor, foregroundColor: Colors.black),
                    onPressed: () {
                      final lines = int.tryParse(linesCtrl.text) ?? 0;
                      if (textCtrl.text.trim().isNotEmpty && selectedChildId != null && lines > 0 && lines <= 1000) {
                        final expires = expirationDays > 0 ? DateTime.now().add(Duration(days: expirationDays)) : null;
                        provider.addImmunity(selectedChildId!, textCtrl.text.trim(), lines, selectedType, expiresAt: expires);
                        Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.shield_rounded),
                    label: Text('Attribuer ${linesCtrl.text.isNotEmpty ? "${linesCtrl.text} lignes" : ""}'),
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

class _ImmunityCard extends StatelessWidget {
  final ImmunityLines immunity;
  final FamilyProvider provider;
  final bool showActions;
  const _ImmunityCard({required this.immunity, required this.provider, required this.showActions});

  static const _shieldColor = Color(0xFF00E676);

  @override
  Widget build(BuildContext context) {
    final child = provider.getChild(immunity.childId);
    final im = immunity;
    final progressColor = im.isCompleted ? const Color(0xFFFFD740) : _shieldColor;
    final isExpired = im.isExpired;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      glowColor: isExpired ? Colors.grey : (im.isCompleted ? const Color(0xFFFFD740) : _shieldColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(child?.avatar ?? '\u{1F466}', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(child?.name ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text('${im.completedLines} / ${im.totalLines} lignes', style: TextStyle(color: progressColor, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.grey.withValues(alpha: 0.12) : (im.isCompleted ? const Color(0xFFFFD740).withValues(alpha: 0.12) : _shieldColor.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isExpired ? Colors.grey.withValues(alpha: 0.3) : (im.isCompleted ? const Color(0xFFFFD740).withValues(alpha: 0.3) : _shieldColor.withValues(alpha: 0.3))),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(im.immunityEmoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    isExpired ? 'Expiree' : (im.isCompleted ? 'Active (${im.availableLines} dispo)' : im.immunityLabel),
                    style: TextStyle(color: isExpired ? Colors.grey : (im.isCompleted ? const Color(0xFFFFD740) : _shieldColor), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ]),
              ),
              if (im.expiresAt != null) ...[
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, size: 12, color: isExpired ? Colors.red : Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(im.expiresLabel, style: TextStyle(fontSize: 10, color: isExpired ? Colors.red : Colors.grey[500])),
                ]),
              ],
            ]),
            if (showActions && !im.isCompleted)
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Color(0xFFFF1744), size: 22),
                onPressed: () => PinGuard.guardAction(context, () => provider.removeImmunity(im.id)),
              ),
          ]),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: progressColor.withValues(alpha: 0.15)),
            ),
            child: Text('"${im.text}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14, color: Colors.white70)),
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(children: [
                  LinearProgressIndicator(value: im.progress, minHeight: 10, backgroundColor: Colors.white.withValues(alpha: 0.06), valueColor: AlwaysStoppedAnimation(progressColor)),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      widthFactor: im.progress.clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: progressColor.withValues(alpha: 0.4), blurRadius: 6)])),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            NeonText(text: '${(im.progress * 100).toInt()}%', fontSize: 14, color: progressColor, glowIntensity: 0.3),
          ]),

          if (showActions && !im.isCompleted) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: _shieldColor, side: const BorderSide(color: _shieldColor), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => provider.incrementImmunityLines(im.id),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('Ligne ${im.completedLines + 1} faite'),
                ),
              ),
              if (im.totalLines > 10) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: _shieldColor, side: const BorderSide(color: _shieldColor), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
                  onPressed: () => _addMultipleLines(context, im),
                  child: const Text('+5'),
                ),
              ],
            ]),
          ],

          if (im.isCompleted && !isExpired) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [const Color(0xFFFFD740).withValues(alpha: 0.08), _shieldColor.withValues(alpha: 0.08)]),
                border: Border.all(color: const Color(0xFFFFD740).withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.verified_rounded, color: Color(0xFFFFD740), size: 20),
                const SizedBox(width: 8),
                Text('Immunite active ! ${im.availableLines} lignes disponibles', style: const TextStyle(color: Color(0xFFFFD740), fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ],

          if (isExpired && im.isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.red.withValues(alpha: 0.08),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.timer_off_rounded, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('Immunite expiree', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ],

          const SizedBox(height: 8),
          Text('Attribue le ${im.createdAt.day}/${im.createdAt.month}/${im.createdAt.year}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _addMultipleLines(BuildContext context, ImmunityLines im) {
    final remaining = im.totalLines - im.completedLines;
    final options = [5, 10, 20, 50].where((n) => n <= remaining).toList();
    if (options.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const NeonText(text: 'Ajouter plusieurs lignes', fontSize: 18, color: Colors.white),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Lignes restantes: $remaining', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: options.map((n) => FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _shieldColor, foregroundColor: Colors.black),
              onPressed: () { for (var i = 0; i < n; i++) provider.incrementImmunityLines(im.id); Navigator.pop(ctx); },
              child: Text('+$n lignes'),
            )).toList(),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: Colors.grey[400])))],
      ),
    );
  }
}
