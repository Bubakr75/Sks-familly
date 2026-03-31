import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';

import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/badge_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_background.dart';
import '../widgets/page_transitions.dart';
import '../screens/school_notes_screen.dart';
import '../screens/punishment_lines_screen.dart';
import '../screens/immunity_lines_screen.dart';
import '../screens/badges_screen.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;
  const ChildDashboardScreen({super.key, required this.childId});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _profileController;
  late AnimationController _contentController;
  late AnimationController _glowController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileController.dispose();
    _contentController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color _getLevelColor(int points) {
    if (points >= 300) return Colors.amber;
    if (points >= 220) return Colors.purpleAccent;
    if (points >= 150) return Colors.cyanAccent;
    if (points >= 90) return Colors.greenAccent;
    if (points >= 40) return Colors.orangeAccent;
    return Colors.blueAccent;
  }

  void _showPhotoOptions(BuildContext context) {
    final familyProvider = context.read<FamilyProvider>();
    final child = familyProvider.getChild(widget.childId);
    final hasPhoto = child != null && child.hasPhoto;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('📸 Photo de profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TvFocusWrapper(
                      onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.camera); },
                      child: GlassCard(
                        onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.camera); },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(children: [
                            Text('📷', style: TextStyle(fontSize: 36)),
                            SizedBox(height: 8),
                            Text('Appareil photo', style: TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TvFocusWrapper(
                      onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.gallery); },
                      child: GlassCard(
                        onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.gallery); },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(children: [
                            Text('🖼️', style: TextStyle(fontSize: 36)),
                            SizedBox(height: 8),
                            Text('Galerie', style: TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasPhoto) ...[
                const SizedBox(height: 12),
                TvFocusWrapper(
                  onTap: () { Navigator.pop(ctx); _removePhoto(); },
                  child: TextButton.icon(
                    onPressed: () { Navigator.pop(ctx); _removePhoto(); },
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    label: const Text('Supprimer la photo', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source, maxWidth: 800, maxHeight: 800, imageQuality: 75,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('⚠️ Photo trop lourde (max 2 Mo)'),
          backgroundColor: Colors.orange.withOpacity(0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      return;
    }
    final base64Photo = base64Encode(bytes);
    if (mounted) {
      final familyProvider = context.read<FamilyProvider>();
      familyProvider.updateChildPhoto(widget.childId, base64Photo);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('📸 Photo mise à jour !'),
        backgroundColor: Colors.green.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  void _removePhoto() {
    final familyProvider = context.read<FamilyProvider>();
    familyProvider.updateChildPhoto(widget.childId, '');
    setState(() {});
  }

  void _showFullPhoto(BuildContext context, String base64Photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: InteractiveViewer(child: Image.memory(base64Decode(base64Photo), fit: BoxFit.contain)),
          ),
          Positioned(top: 8, right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildLargeAvatar(dynamic child, {double size = 120}) {
    final levelColor = _getLevelColor(child.points);
    return GestureDetector(
      onTap: () {
        if (child.hasPhoto) { _showFullPhoto(context, child.photoBase64); }
        else { _showPhotoOptions(context); }
      },
      onLongPress: () => _showPhotoOptions(context),
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (_, __) {
          final glowValue = _glowController.value;
          return Container(
            width: size + 12, height: size + 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: levelColor.withOpacity(0.3 + glowValue * 0.3), blurRadius: 15 + glowValue * 10, spreadRadius: 2 + glowValue * 3)],
            ),
            child: Container(
              width: size + 8, height: size + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [levelColor, levelColor.withOpacity(0.3), levelColor], transform: GradientRotation(glowValue * math.pi * 2)),
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).scaffoldBackgroundColor),
                padding: const EdgeInsets.all(3),
                child: child.hasPhoto
                    ? ClipOval(child: Image.memory(base64Decode(child.photoBase64), width: size, height: size, fit: BoxFit.cover))
                    : Container(
                        width: size, height: size,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [levelColor.withOpacity(0.3), levelColor.withOpacity(0.1)])),
                        child: Center(child: Text(child.name.isNotEmpty ? child.name[0].toUpperCase() : '?', style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.bold, color: levelColor))),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileTab(dynamic child, FamilyProvider provider) {
    final history = provider.getHistory(widget.childId);
    final totalBonus = history.where((e) => e.isBonus).fold<int>(0, (s, e) => s + e.points);
    final totalPenalty = history.where((e) => !e.isBonus).fold<int>(0, (s, e) => s + e.points);
    final activePunishments = provider.punishments.where((p) => p['childId'] == widget.childId && p['isCompleted'] != true).length;
    final activeImmunities = provider.immunities.where((i) => i.childId == widget.childId && i.isUsable).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 8),
        ScaleTransition(
          scale: CurvedAnimation(parent: _profileController, curve: Curves.elasticOut),
          child: _buildLargeAvatar(child, size: 120),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: CurvedAnimation(parent: _profileController, curve: const Interval(0.3, 0.7)),
          child: Text(child.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        FadeTransition(
          opacity: CurvedAnimation(parent: _profileController, curve: const Interval(0.4, 0.8)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_getLevelColor(child.points).withOpacity(0.3), _getLevelColor(child.points).withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getLevelColor(child.points).withOpacity(0.5)),
            ),
            child: Text(child.levelTitle, style: TextStyle(color: _getLevelColor(child.points), fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
        FadeTransition(
          opacity: CurvedAnimation(parent: _profileController, curve: const Interval(0.5, 0.9)),
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('${child.points}', style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: _getLevelColor(child.points))),
                const Text('points', style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 16),
                if (!child.isMaxLevel) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: child.levelProgress, minHeight: 8, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(_getLevelColor(child.points))),
                  ),
                  const SizedBox(height: 6),
                  Text('${child.points} / ${child.nextLevelPoints} pts pour le prochain niveau', style: const TextStyle(fontSize: 12, color: Colors.white38)),
                ] else
                  const Text('⭐ Niveau maximum atteint !', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: CurvedAnimation(parent: _contentController, curve: const Interval(0.2, 0.8)),
          child: Row(children: [
            Expanded(child: _statCard(emoji: '⭐', label: 'Bonus', value: '+$totalBonus', color: Colors.greenAccent)),
            const SizedBox(width: 8),
            Expanded(child: _statCard(emoji: '💔', label: 'Pénalités', value: '$totalPenalty', color: Colors.redAccent)),
          ]),
        ),
        const SizedBox(height: 8),
        FadeTransition(
          opacity: CurvedAnimation(parent: _contentController, curve: const Interval(0.4, 1.0)),
          child: Row(children: [
            Expanded(child: _statCard(emoji: '✍️', label: 'Punitions actives', value: '$activePunishments', color: Colors.orangeAccent)),
            const SizedBox(width: 8),
            Expanded(child: _statCard(emoji: '🛡️', label: 'Immunités', value: '$activeImmunities', color: Colors.cyanAccent)),
          ]),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Actions rapides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _quickAction(emoji: '📚', label: 'Notes', onTap: () => Navigator.push(context, SlidePageRoute(page: SchoolNotesScreen(childId: widget.childId)))),
                _quickAction(emoji: '✍️', label: 'Punitions', onTap: () => Navigator.push(context, SlidePageRoute(page: PunishmentLinesScreen(initialChildId: widget.childId)))),
                _quickAction(emoji: '🛡️', label: 'Immunités', onTap: () => Navigator.push(context, SlidePageRoute(page: ImmunityLinesScreen(initialChildId: widget.childId)))),
                _quickAction(emoji: '🏆', label: 'Badges', onTap: () => Navigator.push(context, SlidePageRoute(page: const BadgesScreen()))),
                _quickAction(emoji: '📸', label: 'Photo', onTap: () => _showPhotoOptions(context)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Text(child.hasPhoto ? 'Tape sur la photo pour agrandir • Appui long pour changer' : 'Tape sur l\'avatar pour ajouter une photo',
            style: const TextStyle(color: Colors.white24, fontSize: 11)),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _statCard({required String emoji, required String label, required String value, required Color color}) {
    return GlassCard(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
    ])));
  }

  Widget _quickAction({required String emoji, required String label, required VoidCallback onTap}) {
    return TvFocusWrapper(onTap: onTap, child: GlassCard(onTap: onTap, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ));
  }

  Widget _buildScreenTimeTab(dynamic child, FamilyProvider provider) {
    final satMinutes = provider.getSaturdayMinutes(widget.childId);
    final sunMinutes = provider.getSundayMinutes(widget.childId);
    final bonusMinutes = provider.getParentBonusMinutes(widget.childId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 8),
        Row(children: [
          child.hasPhoto
              ? ClipOval(child: Image.memory(base64Decode(child.photoBase64), width: 48, height: 48, fit: BoxFit.cover))
              : CircleAvatar(radius: 24, backgroundColor: _getLevelColor(child.points).withOpacity(0.2),
                  child: Text(child.name.isNotEmpty ? child.name[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold, color: _getLevelColor(child.points)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Temps d\'écran du week-end', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _screenTimeCard('Samedi', satMinutes, Colors.cyan)),
          const SizedBox(width: 12),
          Expanded(child: _screenTimeCard('Dimanche', sunMinutes, Colors.purple)),
        ]),
        const SizedBox(height: 16),
        GlassCard(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('📺', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Column(children: [
            const Text('Total week-end', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_formatMinutes(satMinutes + sunMinutes), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70)),
          ]),
        ]))),
        if (bonusMinutes > 0) ...[
          const SizedBox(height: 8),
          GlassCard(child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🎁', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('Bonus parent : +${_formatMinutes(bonusMinutes)}', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ]))),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _screenTimeCard(String day, int minutes, Color color) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return GlassCard(
      glowColor: color,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Text(day, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 12),
        SizedBox(width: 80, height: 80, child: Stack(children: [
          CircularProgressIndicator(value: (minutes / 180).clamp(0.0, 1.0), strokeWidth: 8, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(color)),
          Center(child: Text(hours > 0 ? '${hours}h${mins > 0 ? mins.toString().padLeft(2, '0') : ''}' : '${mins}m', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ])),
        const SizedBox(height: 8),
        Text(_formatMinutes(minutes), style: const TextStyle(fontSize: 11, color: Colors.white38)),
      ])),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${h}h';
  }

  Widget _buildHistoryTab(FamilyProvider provider) {
    final history = provider.getHistory(widget.childId);
    if (history.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('📜', style: TextStyle(fontSize: 64)),
        SizedBox(height: 16),
        Text('Aucun historique', style: TextStyle(fontSize: 18, color: Colors.white54)),
        Text('Les activités apparaîtront ici', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (_, index) {
        final entry = history[index];
        final isBonus = entry.isBonus;
        // ✅ CORRIGÉ : description au lieu de reason
        final displayReason = entry.description.contains('|') ? entry.description.split('|').first : entry.description;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(CurvedAnimation(
              parent: _contentController,
              curve: Interval((index * 0.05).clamp(0.0, 1.0), ((index * 0.05) + 0.3).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
            )),
            child: GlassCard(child: ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: isBonus ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                child: Center(child: Text('${isBonus ? '+' : ''}${entry.points}', style: TextStyle(fontWeight: FontWeight.bold, color: isBonus ? Colors.greenAccent : Colors.redAccent, fontSize: 13)))),
              title: Text(displayReason, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Row(children: [
                Text(_formatDate(entry.date), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                if (entry.category != 'Bonus') ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                    child: Text(entry.category, style: const TextStyle(fontSize: 9, color: Colors.white38))),
                ],
                if (entry.hasProofPhoto) ...[const SizedBox(width: 4), const Icon(Icons.photo, size: 12, color: Colors.white38)],
              ]),
              trailing: entry.hasProofPhoto
                  ? GestureDetector(onTap: () => _showFullPhoto(context, entry.proofPhotoBase64!),
                      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(base64Decode(entry.proofPhotoBase64!), width: 36, height: 36, fit: BoxFit.cover)))
                  : null,
            )),
          ),
        );
      },
    );
  }

  Widget _buildBadgesTab(dynamic child, FamilyProvider provider) {
    final allBadges = [...BadgeModel.defaultBadges, ...provider.customBadges];
    final unlockedIds = child.badgeIds as List<String>;

    if (allBadges.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🏆', style: TextStyle(fontSize: 64)),
        SizedBox(height: 16),
        Text('Aucun badge disponible', style: TextStyle(fontSize: 18, color: Colors.white54)),
      ]));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
      itemCount: allBadges.length,
      itemBuilder: (_, index) {
        final badge = allBadges[index];
        final isUnlocked = unlockedIds.contains(badge.id);
        final progress = badge.requiredPoints > 0 ? (child.points / badge.requiredPoints).clamp(0.0, 1.0) : 0.0;

        return TvFocusWrapper(
          onTap: () => _showBadgeDetail(context, badge, isUnlocked, child),
          child: GlassCard(
            glowColor: isUnlocked ? Colors.amber : null,
            onTap: () => _showBadgeDetail(context, badge, isUnlocked, child),
            child: Padding(padding: const EdgeInsets.all(8), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Opacity(opacity: isUnlocked ? 1.0 : 0.4, child: Text(badge.powerEmoji, style: const TextStyle(fontSize: 32))),
              const SizedBox(height: 6),
              Text(badge.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.white : Colors.white38), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              if (isUnlocked)
                const Text('✅ Débloqué', style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold))
              else ...[
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Colors.amber))),
                const SizedBox(height: 2),
                Text('${child.points}/${badge.requiredPoints} pts', style: const TextStyle(fontSize: 9, color: Colors.white38)),
              ],
            ])),
          ),
        );
      },
    );
  }

  void _showBadgeDetail(BuildContext context, BadgeModel badge, bool isUnlocked, dynamic child) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(badge.powerEmoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(badge.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(badge.description, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (isUnlocked)
            Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.5))),
              child: const Text('✅ Débloqué !', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)))
          else ...[
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: badge.requiredPoints > 0 ? (child.points / badge.requiredPoints).clamp(0.0, 1.0) : 0.0, minHeight: 10, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Colors.amber))),
            const SizedBox(height: 8),
            Text('${child.points} / ${badge.requiredPoints} points', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Encore ${(badge.requiredPoints - child.points).clamp(0, 999999)} points nécessaires', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Aujourd\'hui $time';
    if (diff == 1) return 'Hier $time';
    if (diff < 7) return 'Il y a $diff jours';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.getChild(widget.childId);
        if (child == null) {
          return AnimatedBackground(child: Scaffold(backgroundColor: Colors.transparent, body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('😢', style: TextStyle(fontSize: 64)), const SizedBox(height: 16),
            const Text('Enfant introuvable', style: TextStyle(fontSize: 18)), const SizedBox(height: 24),
            TvFocusWrapper(onTap: () => Navigator.pop(context), child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Retour'))),
          ]))));
        }
        final levelColor = _getLevelColor(child.points);
        return AnimatedBackground(child: Scaffold(backgroundColor: Colors.transparent, body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                backgroundColor: Colors.transparent, expandedHeight: 0, floating: true, pinned: false,
                leading: TvFocusWrapper(onTap: () => Navigator.pop(context), child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back))),
                title: Row(children: [
                  if (child.hasPhoto) ...[ClipOval(child: Image.memory(base64Decode(child.photoBase64), width: 32, height: 32, fit: BoxFit.cover)), const SizedBox(width: 8)],
                  Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                actions: [Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: levelColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: levelColor.withOpacity(0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${child.points}', style: TextStyle(fontWeight: FontWeight.bold, color: levelColor, fontSize: 16)),
                    const SizedBox(width: 4),
                    Text('pts', style: TextStyle(color: levelColor.withOpacity(0.7), fontSize: 11)),
                  ]),
                )],
                bottom: TabBar(
                  controller: _tabController, isScrollable: true, indicatorColor: levelColor, indicatorWeight: 3,
                  labelColor: Colors.white, unselectedLabelColor: Colors.white38, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [Tab(text: '👤 Profil'), Tab(text: '📺 Écran'), Tab(text: '📜 Historique'), Tab(text: '🏆 Badges')],
                ),
              ),
            ],
            body: TabBarView(controller: _tabController, children: [
              _buildProfileTab(child, provider),
              _buildScreenTimeTab(child, provider),
              _buildHistoryTab(provider),
              _buildBadgesTab(child, provider),
            ]),
          ),
        )));
      },
    );
  }
}
