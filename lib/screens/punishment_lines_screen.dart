import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/family_provider.dart';
import '../models/punishment_lines.dart';
import '../models/immunity_lines.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class PunishmentLinesScreen extends StatelessWidget {
  const PunishmentLinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          title: const NeonText(text: 'Lignes de punition', fontSize: 18, color: Colors.white),
          backgroundColor: Colors.transparent,
          bottom: TabBar(
            indicatorColor: const Color(0xFFFF6E40),
            labelColor: const Color(0xFFFF6E40),
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(icon: Icon(Icons.pending_actions_rounded), text: 'En cours'),
              Tab(icon: Icon(Icons.check_circle_outline_rounded), text: 'Terminees'),
            ],
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFFFF6E40).withValues(alpha: 0.3), blurRadius: 16)],
          ),
          child: FloatingActionButton.extended(
            heroTag: 'add_punishment',
            backgroundColor: const Color(0xFFFF6E40),
            onPressed: () => PinGuard.guardAction(context, () => _showAddPunishment(context)),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Donner des lignes', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        body: Consumer<FamilyProvider>(
          builder: (context, provider, _) {
            final active = provider.punishments.where((p) => !p.isCompleted).toList();
            final completed = provider.punishments.where((p) => p.isCompleted).toList();
            return AnimatedBackground(
              child: TabBarView(
                children: [
                  active.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          GlowIcon(icon: Icons.sentiment_satisfied_alt_rounded, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text('Aucune punition en cours', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Text('Bonne conduite !', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: active.length,
                          itemBuilder: (_, i) => _PunishmentCard(punishment: active[i], provider: provider),
                        ),
                  completed.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          GlowIcon(icon: Icons.history_rounded, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text('Aucune punition terminee', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: completed.length,
                          itemBuilder: (_, i) => _PunishmentCard(punishment: completed[i], provider: provider),
                        ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddPunishment(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    final textCtrl = TextEditingController();
    final linesCtrl = TextEditingController();
    String? selectedChildId = provider.children.isNotEmpty ? provider.children.first.id : null;

    final presets = [
      {'text': 'Je ne dois pas me battre', 'lines': 50},
      {'text': 'Je dois etre poli', 'lines': 30},
      {'text': 'Je dois ecouter en classe', 'lines': 40},
      {'text': 'Je ne dois pas mentir', 'lines': 50},
      {'text': 'Je dois faire mes devoirs', 'lines': 30},
      {'text': 'Je dois respecter les autres', 'lines': 40},
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
                    decoration: BoxDecoration(color: const Color(0xFFFF6E40).withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.3))),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFFFF6E40), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const NeonText(text: 'Nouvelle punition', fontSize: 18, color: Colors.white),
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
                  controller: textCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Texte a copier',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: presets.map((p) => GestureDetector(
                    onTap: () => setState(() {
                      textCtrl.text = p['text'] as String;
                      linesCtrl.text = '${p['lines']}';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(p['text'] as String, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: linesCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre de lignes',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6E40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () {
                      final lines = int.tryParse(linesCtrl.text) ?? 0;
                      if (selectedChildId != null && textCtrl.text.isNotEmpty && lines > 0) {
                        provider.addPunishment(selectedChildId!, textCtrl.text, lines);
                        Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Donner les lignes', style: TextStyle(fontWeight: FontWeight.w700)),
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

class _PunishmentCard extends StatelessWidget {
  final PunishmentLines punishment;
  final FamilyProvider provider;
  const _PunishmentCard({required this.punishment, required this.provider});

  @override
  Widget build(BuildContext context) {
    final child = provider.getChild(punishment.childId);
    final remaining = punishment.totalLines - punishment.completedLines;
    final usableImmunities = provider.getUsableImmunitiesForChild(punishment.childId);
    final hasUsableImmunity = usableImmunities.isNotEmpty && !punishment.isCompleted;
    final totalImmunityLines = provider.getTotalAvailableImmunity(punishment.childId);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      glowColor: punishment.isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF6E40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: punishment.isCompleted ? const Color(0xFF00E676).withValues(alpha: 0.12) : const Color(0xFFFF6E40).withValues(alpha: 0.12),
                  border: Border.all(color: punishment.isCompleted ? const Color(0xFF00E676).withValues(alpha: 0.3) : const Color(0xFFFF6E40).withValues(alpha: 0.3)),
                ),
                child: Center(child: Text(child?.avatar ?? '\u{1F466}', style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child?.name ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('"${punishment.text}"', style: TextStyle(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (punishment.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF00E676).withValues(alpha: 0.12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, color: Color(0xFF00E676), size: 14), SizedBox(width: 4), Text('Termine', style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w600))]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${punishment.completedLines}', style: TextStyle(color: punishment.isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF6E40), fontWeight: FontWeight.w800, fontSize: 18)),
              Text(' / ${punishment.totalLines} lignes', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const Spacer(),
              if (!punishment.isCompleted)
                Text('Reste $remaining', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          // Indicateur immunité disponible
          if (hasUsableImmunity && !punishment.isCompleted) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 14),
              const SizedBox(width: 4),
              Text('$totalImmunityLines lignes d\'immunite disponibles', style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: punishment.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(punishment.isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF6E40)),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(punishment.progress * 100).toInt()}%', style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
          if (!punishment.isCompleted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _lineButton(context, '+1', 1),
                const SizedBox(width: 8),
                _lineButton(context, '+5', 5),
                const SizedBox(width: 8),
                _lineButton(context, '+10', 10),
                const SizedBox(width: 8),
                _lineButton(context, '+20', 20),
                const Spacer(),
                if (punishment.hasPhotos)
                  GestureDetector(
                    onTap: () => _showPhotos(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.blue.withValues(alpha: 0.12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.photo_library_rounded, color: Colors.blue, size: 14),
                        const SizedBox(width: 4),
                        Text('${punishment.photoUrls.length}', style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _addPhoto(context),
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text('Preuve photo', style: TextStyle(fontSize: 12)),
                  ),
                ),
                if (hasUsableImmunity) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00E676),
                        side: BorderSide(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _showUseImmunityDialog(context, usableImmunities),
                      icon: const Icon(Icons.shield_rounded, size: 16),
                      label: const Text('Utiliser immunite', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (punishment.hasPhotos && punishment.isCompleted) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showPhotos(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.blue.withValues(alpha: 0.08)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_library_rounded, color: Colors.blue, size: 16),
                  const SizedBox(width: 6),
                  Text('Voir les ${punishment.photoUrls.length} preuves', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text('Cree le ${punishment.createdAt.day}/${punishment.createdAt.month}/${punishment.createdAt.year}', style: TextStyle(fontSize: 10, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _lineButton(BuildContext context, String label, int count) {
    return GestureDetector(
      onTap: () {
        final newCompleted = (punishment.completedLines + count).clamp(0, punishment.totalLines);
        final toAdd = newCompleted - punishment.completedLines;
        if (toAdd > 0) provider.updatePunishmentProgress(punishment.id, toAdd);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFFF6E40).withValues(alpha: 0.1),
          border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.25)),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFFFF6E40), fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _addPhoto(BuildContext context) {
    if (kIsWeb) {
      _pickImage(context, ImageSource.gallery);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF162033),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ajouter une preuve', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.camera_alt_rounded, color: Colors.blue)),
                title: const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); _pickImage(context, ImageSource.camera); },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.photo_library_rounded, color: Colors.purple)),
                title: const Text('Galerie', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(ctx); _pickImage(context, ImageSource.gallery); },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 70);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final b64 = base64Encode(bytes);
        provider.addPhotoToPunishment(punishment.id, b64);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8), Text('Preuve photo ajoutee')]),
            backgroundColor: const Color(0xFF00E676), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _showPhotos(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.photo_library_rounded, color: Colors.blue, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Text('Preuves photos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: punishment.photoUrls.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () => _showFullPhoto(context, punishment.photoUrls[i]),
                          child: Image.memory(base64Decode(punishment.photoUrls[i]), width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(height: 100, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[900]), child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)))),
                        ),
                      ),
                      Positioned(top: 4, right: 4, child: GestureDetector(
                        onTap: () { Navigator.pop(ctx); _confirmDeletePhoto(context, i); },
                        child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle), child: const Icon(Icons.delete_rounded, color: Color(0xFFFF1744), size: 18)),
                      )),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullPhoto(BuildContext context, String photoB64) {
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.black, insetPadding: const EdgeInsets.all(8),
      child: Stack(children: [
        InteractiveViewer(child: Image.memory(base64Decode(photoB64), fit: BoxFit.contain)),
        Positioned(top: 8, right: 8, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(ctx))),
      ]),
    ));
  }

  void _confirmDeletePhoto(BuildContext context, int index) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF162033), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Supprimer la photo ?', style: TextStyle(color: Colors.white)),
      content: const Text('Cette action est irreversible.', style: TextStyle(color: Colors.grey)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)), onPressed: () { provider.removePhotoFromPunishment(punishment.id, index); Navigator.pop(ctx); }, child: const Text('Supprimer')),
      ],
    ));
  }

  void _showUseImmunityDialog(BuildContext context, List<ImmunityLines> immunities) {
    final remaining = punishment.totalLines - punishment.completedLines;
    ImmunityLines? selectedImmunity = immunities.first;
    int linesToUse = 0;
    final linesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final maxUsable = selectedImmunity != null
              ? selectedImmunity!.availableLines.clamp(0, remaining)
              : 0;

          return AlertDialog(
            backgroundColor: const Color(0xFF0D1B2A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF00E676).withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3))),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Utiliser immunite', style: TextStyle(color: Colors.white, fontSize: 16))),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFFFF6E40).withValues(alpha: 0.08), border: Border.all(color: const Color(0xFFFF6E40).withValues(alpha: 0.2))),
                    child: Row(children: [
                      const Icon(Icons.edit_note_rounded, color: Color(0xFFFF6E40), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Punition: $remaining lignes restantes', style: const TextStyle(color: Color(0xFFFF6E40), fontSize: 13, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Choisir une immunite :', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...immunities.map((im) {
                    final isSelected = selectedImmunity?.id == im.id;
                    return GestureDetector(
                      onTap: () => setState(() { selectedImmunity = im; linesCtrl.clear(); linesToUse = 0; }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? const Color(0xFF00E676).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
                          border: Border.all(color: isSelected ? const Color(0xFF00E676).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Row(children: [
                          Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? const Color(0xFF00E676) : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          const Text('\u{1F6E1}', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(im.reason, style: TextStyle(color: isSelected ? const Color(0xFF00E676) : Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${im.availableLines} lignes disponibles', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                            if (im.expiresAt != null)
                              Text(im.expiresLabel, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                          ])),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text('Combien de lignes utiliser ?', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: linesCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Ex: 20', hintStyle: TextStyle(color: Colors.grey[700]),
                      helperText: 'Max: $maxUsable lignes', helperStyle: TextStyle(color: Colors.grey[600], fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00E676))),
                    ),
                    onChanged: (val) => setState(() { linesToUse = (int.tryParse(val) ?? 0).clamp(0, maxUsable); }),
                  ),
                  const SizedBox(height: 12),
                  if (linesToUse > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [const Color(0xFF00E676).withValues(alpha: 0.1), const Color(0xFF00E676).withValues(alpha: 0.03)]), border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.2))),
                      child: Column(children: [
                        Row(children: [const Icon(Icons.info_outline_rounded, color: Color(0xFF00E676), size: 16), const SizedBox(width: 8), const Expanded(child: Text('Resume :', style: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w600)))]),
                        const SizedBox(height: 8),
                        Text('$linesToUse lignes deduites de la punition', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Restera ${remaining - linesToUse} lignes a faire', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ]),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: Colors.grey[500]))),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: linesToUse > 0 ? const Color(0xFF00E676) : Colors.grey[800], foregroundColor: Colors.black),
                onPressed: linesToUse > 0 && selectedImmunity != null ? () {
                  provider.useImmunityOnPunishment(selectedImmunity!.id, punishment.id, linesToUse);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [const Text('\u{1F6E1}', style: TextStyle(fontSize: 20)), const SizedBox(width: 8), Expanded(child: Text('$linesToUse lignes deduites !'))]),
                    backgroundColor: const Color(0xFF00E676), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                } : null,
                icon: const Icon(Icons.shield_rounded, size: 16),
                label: Text(linesToUse > 0 ? 'Utiliser $linesToUse lignes' : 'Choisir un nombre'),
              ),
            ],
          );
        },
      ),
    );
  }
}
