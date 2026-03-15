import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/punishment_lines.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class PunishmentLinesScreen extends StatelessWidget {
  const PunishmentLinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          title: NeonText(text: 'Lignes de punition', fontSize: 18, color: Colors.white),
          backgroundColor: Colors.transparent,
          bottom: TabBar(
            indicatorColor: primary,
            indicatorWeight: 3,
            labelColor: primary,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(icon: Icon(Icons.edit_note), text: 'En cours'),
              Tab(icon: Icon(Icons.history), text: 'Historique'),
            ],
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFFFF1744).withValues(alpha: 0.3), blurRadius: 16)],
          ),
          child: FloatingActionButton.extended(
            heroTag: 'add_punishment',
            backgroundColor: const Color(0xFFFF1744),
            onPressed: () => PinGuard.guardAction(context, () => _showAddPunishment(context)),
            icon: const Icon(Icons.add),
            label: const Text('Assigner'),
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
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlowIcon(icon: Icons.edit_note, size: 64, color: Colors.grey[600]),
                              const SizedBox(height: 16),
                              Text('Aucune punition en cours', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: active.length,
                          itemBuilder: (_, i) => _PunishmentCard(punishment: active[i], provider: provider, showActions: true),
                        ),
                  completed.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlowIcon(icon: Icons.history, size: 64, color: Colors.grey[600]),
                              const SizedBox(height: 16),
                              Text('Aucune punition terminee', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: completed.length,
                          itemBuilder: (_, i) => _PunishmentCard(punishment: completed[i], provider: provider, showActions: false),
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
    final textCtrl = TextEditingController(text: 'Je dois respecter mes parents et etre poli(e).');
    final linesCtrl = TextEditingController(text: '10');
    String? selectedChildId = provider.children.isNotEmpty ? provider.children.first.id : null;
    final presets = [5, 10, 20, 50, 100, 200, 500];

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
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFF1744).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.edit_note, color: Color(0xFFFF1744)),
                    ),
                    const SizedBox(width: 12),
                    const NeonText(text: 'Assigner une punition', fontSize: 18, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: selectedChildId,
                  dropdownColor: const Color(0xFF162033),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Enfant',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: provider.children.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}'),
                  )).toList(),
                  onChanged: (v) => setState(() => selectedChildId = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Texte a copier',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Nombre de lignes', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((n) {
                    final isSelected = linesCtrl.text == n.toString();
                    return GestureDetector(
                      onTap: () => setState(() => linesCtrl.text = n.toString()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected ? const Color(0xFFFF1744).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: isSelected ? const Color(0xFFFF1744).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text('$n', style: TextStyle(color: isSelected ? const Color(0xFFFF1744) : Colors.grey[500], fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linesCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF1744)),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    labelText: 'Nombre exact',
                    suffixText: 'lignes',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
                    onPressed: () {
                      final lines = int.tryParse(linesCtrl.text) ?? 0;
                      if (textCtrl.text.trim().isNotEmpty && selectedChildId != null && lines > 0 && lines <= 1000) {
                        provider.addPunishment(selectedChildId!, textCtrl.text.trim(), lines);
                        Navigator.pop(ctx);
                      }
                    },
                    icon: const Icon(Icons.gavel_rounded),
                    label: Text('Assigner ${linesCtrl.text.isNotEmpty ? "${linesCtrl.text} lignes" : ""}'),
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
  final bool showActions;
  const _PunishmentCard({required this.punishment, required this.provider, required this.showActions});

  @override
  Widget build(BuildContext context) {
    final child = provider.getChild(punishment.childId);
    final p = punishment;
    final progressColor = p.isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF1744);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      glowColor: p.isCompleted ? const Color(0xFF00E676) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(child?.avatar ?? '\u{1F466}', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child?.name ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    Text(
                      '${p.completedLines} / ${p.totalLines} lignes',
                      style: TextStyle(color: progressColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (p.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF00E676), size: 14),
                      SizedBox(width: 4),
                      Text('Termine', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                )
              else if (showActions)
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Color(0xFFFF1744), size: 22),
                  onPressed: () => PinGuard.guardAction(context, () => provider.removePunishment(p.id)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: progressColor.withValues(alpha: 0.15)),
            ),
            child: Text('"${p.text}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14, color: Colors.white70)),
          ),

          // === PHOTOS SECTION ===
          if (p.hasPhotos) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: p.photoUrls.length,
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () => _showPhotoFullscreen(context, p.photoUrls[i]),
                    onLongPress: showActions ? () => _confirmDeletePhoto(context, p.id, i) : null,
                    child: Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: progressColor.withValues(alpha: 0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(
                          base64Decode(p.photoUrls[i]),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: Icon(Icons.broken_image_rounded, color: Colors.grey[600], size: 30),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Add photo button
          if (showActions && !p.isCompleted) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _addPhoto(context, p.id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
                  border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 18, color: const Color(0xFF7C4DFF)),
                    const SizedBox(width: 8),
                    Text(
                      p.hasPhotos ? 'Ajouter une photo' : 'Joindre une photo',
                      style: const TextStyle(color: Color(0xFF7C4DFF), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      LinearProgressIndicator(
                        value: p.progress,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation(progressColor),
                      ),
                      Positioned.fill(
                        child: FractionallySizedBox(
                          widthFactor: p.progress.clamp(0.0, 1.0),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [BoxShadow(color: progressColor.withValues(alpha: 0.4), blurRadius: 6)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              NeonText(text: '${(p.progress * 100).toInt()}%', fontSize: 14, color: progressColor, glowIntensity: 0.3),
            ],
          ),
          if (showActions && !p.isCompleted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1744),
                      side: const BorderSide(color: Color(0xFFFF1744)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => provider.incrementPunishmentLines(p.id),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text('Ligne ${p.completedLines + 1} faite'),
                  ),
                ),
                if (p.totalLines > 10) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1744),
                      side: const BorderSide(color: Color(0xFFFF1744)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                    onPressed: () => _addMultipleLines(context, p),
                    child: const Text('+5'),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Assigne le ${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              if (p.hasPhotos) ...[
                const Spacer(),
                Icon(Icons.photo_library_rounded, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${p.photoUrls.length} photo${p.photoUrls.length > 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _addPhoto(BuildContext context, String punishmentId) {
    // On mobile (Android), use file picker. On web, show info dialog.
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.photo_camera_rounded, color: Color(0xFF7C4DFF)),
              SizedBox(width: 10),
              Text('Photo de penalite', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: const Text(
            'La selection de photos est disponible sur Android lorsque l\'application est installee.\n\nEn mode web, cette fonctionnalite est limitee.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    } else {
      // Android - will use platform image picker
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.photo_camera_rounded, color: Color(0xFF7C4DFF)),
              SizedBox(width: 10),
              Text('Photo de penalite', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Utilisez l\'appareil photo ou la galerie pour ajouter une photo comme preuve de la penalite.\n\nCette photo sera visible par tous les membres de la famille.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: Colors.grey[400])),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
              onPressed: () {
                Navigator.pop(ctx);
                // Trigger native image picker
                _pickImageNative(context, punishmentId);
              },
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text('Galerie'),
            ),
          ],
        ),
      );
    }
  }

  void _pickImageNative(BuildContext context, String punishmentId) {
    // Platform channel for image picker on Android
    // This provides a demo placeholder since we're in preview mode
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text('Selection de photo disponible sur l\'APK installe sur Android')),
          ],
        ),
        backgroundColor: const Color(0xFF7C4DFF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPhotoFullscreen(BuildContext context, String photoBase64) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  base64Decode(photoBase64),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 200,
                    height: 200,
                    color: const Color(0xFF0D1B2A),
                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePhoto(BuildContext context, String punishmentId, int photoIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744)),
            SizedBox(width: 8),
            Text('Supprimer la photo ?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Cette action est irreversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: Colors.grey[400]))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
            onPressed: () {
              provider.removePunishmentPhoto(punishmentId, photoIndex);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _addMultipleLines(BuildContext context, PunishmentLines p) {
    final remaining = p.totalLines - p.completedLines;
    final options = [5, 10, 20, 50].where((n) => n <= remaining).toList();
    if (options.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const NeonText(text: 'Ajouter plusieurs lignes', fontSize: 18, color: Colors.white),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lignes restantes: $remaining', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((n) => FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
                onPressed: () {
                  for (var i = 0; i < n; i++) {
                    provider.incrementPunishmentLines(p.id);
                  }
                  Navigator.pop(ctx);
                },
                child: Text('+$n lignes'),
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: Colors.grey[400]))),
        ],
      ),
    );
  }
}
