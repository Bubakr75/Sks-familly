import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_background.dart';
import '../utils/pin_guard.dart';

class ParentAdminScreen extends StatefulWidget {
  const ParentAdminScreen({super.key});

  @override
  State<ParentAdminScreen> createState() => _ParentAdminScreenState();
}

class _ParentAdminScreenState extends State<ParentAdminScreen>
    with TickerProviderStateMixin {
  late AnimationController _listController;
  late AnimationController _shakeController;
  String? _selectedChildId;
  String _currentTab = 'history'; // history, bonuses, penalties, punishments, immunities, notes

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  // ──────────────────────────────────────────────
  //  CONFIRMATION GÉNÉRIQUE
  // ──────────────────────────────────────────────
  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Supprimer',
    Color confirmColor = Colors.redAccent,
    String? extraInfo,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (extraInfo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(extraInfo,
                          style: const TextStyle(fontSize: 12, color: Colors.orangeAccent)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor.withOpacity(0.3),
            ),
            child: Text(confirmText, style: TextStyle(color: confirmColor)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ──────────────────────────────────────────────
  //  CONFIRMATION DOUBLE (actions dangereuses)
  // ──────────────────────────────────────────────
  Future<bool> _confirmDangerousAction(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final firstConfirm = await _confirmAction(
      context,
      title: title,
      message: message,
      extraInfo: 'Cette action est irréversible !',
    );
    if (!firstConfirm) return false;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ Dernière confirmation'),
        content: const Text(
          'Es-tu vraiment sûr(e) ? Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non, annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.5),
            ),
            child: const Text('Oui, confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return secondConfirm ?? false;
  }

  void _showSnack(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.green.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  SUPPRIMER UN HISTORIQUE
  // ──────────────────────────────────────────────
  void _deleteHistoryEntry(BuildContext context, dynamic entry) async {
    final confirmed = await _confirmAction(
      context,
      title: '🗑️ Supprimer cette entrée ?',
      message: 'Raison : "${entry.reason}"\n'
          'Points : ${entry.isBonus ? '+' : ''}${entry.points}\n'
          'Date : ${_formatDate(entry.date)}',
      extraInfo: entry.points != 0
          ? 'Les points ${entry.isBonus ? "bonus" : "de pénalité"} (${entry.points}) seront annulés.'
          : null,
    );
    if (!confirmed || !mounted) return;

    final familyProvider = context.read<FamilyProvider>();
    familyProvider.deleteHistoryEntry(
      childId: entry.childId,
      entryId: entry.id,
      reversePoints: true,
    );
    _triggerShake();
    setState(() {});
    _showSnack('🗑️ Entrée supprimée et points ajustés');
  }

  // ──────────────────────────────────────────────
  //  MODIFIER DES POINTS
  // ──────────────────────────────────────────────
  void _editHistoryEntry(BuildContext context, dynamic entry) {
    int newPoints = entry.points;
    final reasonController = TextEditingController(text: entry.reason);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    const Text('✏️ Modifier l\'entrée',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Points
                    const Text('Points :',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TvFocusWrapper(
                          onTap: () => setModalState(() => newPoints--),
                          child: IconButton(
                            onPressed: () => setModalState(() => newPoints--),
                            icon: const Icon(Icons.remove_circle_outline),
                            iconSize: 32,
                          ),
                        ),
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: Text(
                            '${newPoints > 0 ? '+' : ''}$newPoints',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: newPoints > 0
                                  ? Colors.greenAccent
                                  : newPoints < 0
                                      ? Colors.redAccent
                                      : Colors.white,
                            ),
                          ),
                        ),
                        TvFocusWrapper(
                          onTap: () => setModalState(() => newPoints++),
                          child: IconButton(
                            onPressed: () => setModalState(() => newPoints++),
                            icon: const Icon(Icons.add_circle_outline),
                            iconSize: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Raison
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: 'Raison',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ancien : ${entry.points > 0 ? '+' : ''}${entry.points} pts — "${entry.reason}"',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: TvFocusWrapper(
                            onTap: () => Navigator.pop(ctx),
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Annuler'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TvFocusWrapper(
                            onTap: () {
                              final provider = context.read<FamilyProvider>();
                              provider.editHistoryEntry(
                                childId: entry.childId,
                                entryId: entry.id,
                                newPoints: newPoints,
                                newReason: reasonController.text.trim(),
                              );
                              Navigator.pop(ctx);
                              setState(() {});
                              _showSnack(
                                  '✏️ Entrée modifiée : ${newPoints > 0 ? '+' : ''}$newPoints pts');
                            },
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final provider = context.read<FamilyProvider>();
                                provider.editHistoryEntry(
                                  childId: entry.childId,
                                  entryId: entry.id,
                                  newPoints: newPoints,
                                  newReason: reasonController.text.trim(),
                                );
                                Navigator.pop(ctx);
                                setState(() {});
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Enregistrer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.green.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  //  SUPPRESSION EN MASSE
  // ──────────────────────────────────────────────
  void _showBulkDeleteOptions(BuildContext context) {
    final familyProvider = context.read<FamilyProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('🗑️ Suppression en masse',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Actions irréversibles — double confirmation requise',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              const SizedBox(height: 20),

              if (_selectedChildId != null) ...[
                // Supprimer tout l'historique d'un enfant
                _bulkActionTile(
                  emoji: '📜',
                  title: 'Effacer tout l\'historique',
                  subtitle: 'Supprime toutes les entrées d\'historique de cet enfant',
                  color: Colors.orange,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await _confirmDangerousAction(
                      context,
                      title: '📜 Effacer tout l\'historique ?',
                      message: 'Toutes les entrées d\'historique seront supprimées pour cet enfant.',
                    );
                    if (confirmed && mounted) {
                      familyProvider.clearChildHistory(
                          childId: _selectedChildId!);
                      _triggerShake();
                      setState(() {});
                      _showSnack('📜 Historique effacé', color: Colors.orange.withOpacity(0.8));
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Supprimer toutes les punitions
                _bulkActionTile(
                  emoji: '✍️',
                  title: 'Supprimer toutes les punitions',
                  subtitle: 'Active et terminées',
                  color: Colors.orange,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await _confirmDangerousAction(
                      context,
                      title: '✍️ Supprimer toutes les punitions ?',
                      message: 'Toutes les punitions seront définitivement supprimées.',
                    );
                    if (confirmed && mounted) {
                      familyProvider.clearAllPunishments(
                          childId: _selectedChildId!);
                      _triggerShake();
                      setState(() {});
                      _showSnack('✍️ Punitions supprimées', color: Colors.orange.withOpacity(0.8));
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Supprimer toutes les immunités
                _bulkActionTile(
                  emoji: '🛡️',
                  title: 'Supprimer toutes les immunités',
                  subtitle: 'Actives et utilisées',
                  color: Colors.cyan,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await _confirmDangerousAction(
                      context,
                      title: '🛡️ Supprimer toutes les immunités ?',
                      message: 'Toutes les immunités seront définitivement supprimées.',
                    );
                    if (confirmed && mounted) {
                      familyProvider.clearAllImmunities(
                          childId: _selectedChildId!);
                      _triggerShake();
                      setState(() {});
                      _showSnack('🛡️ Immunités supprimées', color: Colors.cyan.withOpacity(0.8));
                    }
                  },
                ),
                const SizedBox(height: 8),

                // Remettre les points à zéro
                _bulkActionTile(
                  emoji: '🔄',
                  title: 'Remettre les points à zéro',
                  subtitle: 'Remet le score de cet enfant à 0',
                  color: Colors.red,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await _confirmDangerousAction(
                      context,
                      title: '🔄 Remettre à zéro ?',
                      message: 'Le score sera remis à 0 points. L\'historique sera conservé.',
                    );
                    if (confirmed && mounted) {
                      familyProvider.resetChildPoints(
                          childId: _selectedChildId!);
                      _triggerShake();
                      setState(() {});
                      _showSnack('🔄 Points remis à zéro', color: Colors.red.withOpacity(0.8));
                    }
                  },
                ),
              ],

              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),

              // Reset total
              _bulkActionTile(
                emoji: '💣',
                title: 'RESET TOTAL — Tous les enfants',
                subtitle: 'Efface TOUT : historique, punitions, immunités, notes, points',
                color: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await _confirmDangerousAction(
                    context,
                    title: '💣 RESET TOTAL ?',
                    message:
                        'TOUTES les données de TOUS les enfants seront supprimées :\n'
                        '• Historique\n• Punitions\n• Immunités\n• Notes scolaires\n• Points\n\n'
                        'Les profils des enfants seront conservés.',
                  );
                  if (confirmed && mounted) {
                    familyProvider.resetEverything();
                    _triggerShake();
                    setState(() {});
                    _showSnack('💣 Reset total effectué', color: Colors.red.withOpacity(0.8));
                  }
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _bulkActionTile({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TvFocusWrapper(
      onTap: onTap,
      child: GlassCard(
        glowColor: color,
        onTap: onTap,
        child: ListTile(
          leading: Text(emoji, style: const TextStyle(fontSize: 28)),
          title: Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: color),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  VUE HISTORIQUE AVEC ACTIONS
  // ──────────────────────────────────────────────
  Widget _buildHistoryTab(FamilyProvider provider) {
    if (_selectedChildId == null) {
      return const Center(
          child: Text('Sélectionne un enfant',
              style: TextStyle(color: Colors.white54)));
    }

    final history = provider.getHistory(_selectedChildId!);
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📜', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Aucun historique',
                style: TextStyle(fontSize: 18, color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (_, index) {
        final entry = history[index];
        final isBonus = entry.isBonus;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Dismissible(
            key: Key(entry.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.redAccent, size: 28),
            ),
            confirmDismiss: (_) async {
              return await _confirmAction(
                context,
                title: '🗑️ Supprimer ?',
                message: '"${entry.reason}" — ${entry.points} pts',
                extraInfo: 'Les points seront ajustés automatiquement.',
              );
            },
            onDismissed: (_) {
              provider.deleteHistoryEntry(
                childId: entry.childId,
                entryId: entry.id,
                reversePoints: true,
              );
              setState(() {});
              _showSnack('🗑️ Supprimé : "${entry.reason}"');
            },
            child: GlassCard(
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBonus
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                  ),
                  child: Center(
                    child: Text(
                      '${isBonus ? '+' : ''}${entry.points}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isBonus ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  entry.reason.contains('|')
                      ? entry.reason.split('|').first
                      : entry.reason,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    Text(_formatDate(entry.date),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white38)),
                    if (entry.category != 'Bonus') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(entry.category,
                            style: const TextStyle(
                                fontSize: 9, color: Colors.white54)),
                      ),
                    ],
                    if (entry.hasProofPhoto) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.photo, size: 12, color: Colors.white38),
                    ],
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.white38),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.orangeAccent),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                    if (entry.hasProofPhoto)
                      const PopupMenuItem(
                        value: 'photo',
                        child: Row(
                          children: [
                            Icon(Icons.photo, size: 18, color: Colors.lightBlueAccent),
                            SizedBox(width: 8),
                            Text('Voir la photo'),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        _editHistoryEntry(context, entry);
                        break;
                      case 'delete':
                        _deleteHistoryEntry(context, entry);
                        break;
                      case 'photo':
                        if (entry.proofPhotoBase64 != null) {
                          _showFullPhoto(context, entry.proofPhotoBase64!);
                        }
                        break;
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  //  VUE PUNITIONS AVEC ACTIONS
  // ──────────────────────────────────────────────
  Widget _buildPunishmentsTab(FamilyProvider provider) {
    if (_selectedChildId == null) {
      return const Center(
          child: Text('Sélectionne un enfant',
              style: TextStyle(color: Colors.white54)));
    }

    final punishments = provider.getPunishments(_selectedChildId!);
    if (punishments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✍️', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Aucune punition',
                style: TextStyle(fontSize: 18, color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: punishments.length,
      itemBuilder: (_, index) {
        final p = punishments[index];
        final total = p['totalLines'] ?? 0;
        final completed = p['completedLines'] ?? 0;
        final progress = total > 0 ? completed / total : 0.0;
        final isComplete = completed >= total;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: Key(p['id'] ?? '$index'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete,
                  color: Colors.redAccent, size: 28),
            ),
            confirmDismiss: (_) => _confirmAction(
              context,
              title: '🗑️ Supprimer cette punition ?',
              message: '"${p['text']}"\n$completed/$total lignes',
            ),
            onDismissed: (_) {
              provider.deletePunishment(
                childId: _selectedChildId!,
                punishmentId: p['id'] as String,
              );
              setState(() {});
              _showSnack('🗑️ Punition supprimée');
            },
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(isComplete ? '✅' : '✍️',
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(p['text'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 18, color: Colors.white38),
                          color: Theme.of(context).scaffoldBackgroundColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'reset',
                                child: Text('🔄 Remettre à zéro')),
                            const PopupMenuItem(
                                value: 'complete',
                                child: Text('✅ Marquer terminée')),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('🗑️ Supprimer',
                                  style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                          onSelected: (action) async {
                            switch (action) {
                              case 'reset':
                                provider.resetPunishmentProgress(
                                  childId: _selectedChildId!,
                                  punishmentId: p['id'] as String,
                                );
                                setState(() {});
                                _showSnack('🔄 Progression remise à zéro');
                                break;
                              case 'complete':
                                provider.completePunishment(
                                  childId: _selectedChildId!,
                                  punishmentId: p['id'] as String,
                                );
                                setState(() {});
                                _showSnack('✅ Punition marquée terminée');
                                break;
                              case 'delete':
                                final confirmed = await _confirmAction(
                                    context,
                                    title: '🗑️ Supprimer ?',
                                    message: '"${p['text']}"');
                                if (confirmed && mounted) {
                                  provider.deletePunishment(
                                    childId: _selectedChildId!,
                                    punishmentId: p['id'] as String,
                                  );
                                  setState(() {});
                                  _showSnack('🗑️ Supprimée');
                                }
                                break;
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                            isComplete
                                ? Colors.greenAccent
                                : Colors.orangeAccent),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$completed / $total lignes',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  //  VUE IMMUNITÉS
  // ──────────────────────────────────────────────
  Widget _buildImmunitiesTab(FamilyProvider provider) {
    if (_selectedChildId == null) {
      return const Center(
          child: Text('Sélectionne un enfant',
              style: TextStyle(color: Colors.white54)));
    }

    final immunities = provider.getImmunities(_selectedChildId!);
    if (immunities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🛡️', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Aucune immunité',
                style: TextStyle(fontSize: 18, color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: immunities.length,
      itemBuilder: (_, index) {
        final imm = immunities[index];
        final status = imm['status'] ?? 'active';
        final isActive = status == 'active';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: Key(imm['id'] ?? '$index'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete,
                  color: Colors.redAccent, size: 28),
            ),
            confirmDismiss: (_) => _confirmAction(
              context,
              title: '🗑️ Supprimer cette immunité ?',
              message: '"${imm['reason']}"\n${imm['lines']} lignes — $status',
            ),
            onDismissed: (_) {
              provider.deleteImmunity(
                childId: _selectedChildId!,
                immunityId: imm['id'] as String,
              );
              setState(() {});
              _showSnack('🗑️ Immunité supprimée');
            },
            child: GlassCard(
              glowColor: isActive ? Colors.cyan : null,
              child: ListTile(
                leading: Text(isActive ? '🛡️' : '🛡️',
                    style: TextStyle(
                        fontSize: 24,
                        color: isActive ? null : Colors.white38)),
                title: Text(imm['reason'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration:
                          !isActive ? TextDecoration.lineThrough : null,
                    )),
                subtitle: Text(
                    '${imm['lines']} lignes — ${isActive ? 'Active' : status}',
                    style: TextStyle(
                        color: isActive
                            ? Colors.cyanAccent
                            : Colors.white38,
                        fontSize: 12)),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Colors.white38),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    if (!isActive)
                      const PopupMenuItem(
                          value: 'reactivate',
                          child: Text('🔄 Réactiver')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('🗑️ Supprimer',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                  onSelected: (action) async {
                    switch (action) {
                      case 'reactivate':
                        provider.reactivateImmunity(
                          childId: _selectedChildId!,
                          immunityId: imm['id'] as String,
                        );
                        setState(() {});
                        _showSnack('🔄 Immunité réactivée');
                        break;
                      case 'delete':
                        final confirmed = await _confirmAction(
                          context,
                          title: '🗑️ Supprimer ?',
                          message: '"${imm['reason']}"',
                        );
                        if (confirmed && mounted) {
                          provider.deleteImmunity(
                            childId: _selectedChildId!,
                            immunityId: imm['id'] as String,
                          );
                          setState(() {});
                          _showSnack('🗑️ Supprimée');
                        }
                        break;
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullPhoto(BuildContext context, String base64Photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(children: [
          InteractiveViewer(
              child: Image.memory(base64Decode(base64Photo),
                  fit: BoxFit.contain)),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon:
                    const Icon(Icons.close, color: Colors.white, size: 32)),
          ),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pinProvider = context.watch<PinProvider>();

    // Sécurité : si pas en mode parent, bloquer
    if (!pinProvider.canPerformParentAction()) {
      return AnimatedBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text('Accès réservé aux parents',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                TvFocusWrapper(
                  onTap: () => Navigator.pop(context),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retour'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.children;

        if (_selectedChildId == null && children.isNotEmpty) {
          _selectedChildId = children.first.id;
        }

        // Stats rapides
        int totalHistory = 0;
        int totalPunishments = 0;
        int totalImmunities = 0;
        if (_selectedChildId != null) {
          totalHistory = provider.getHistory(_selectedChildId!).length;
          totalPunishments =
              provider.getPunishments(_selectedChildId!).length;
          totalImmunities =
              provider.getImmunities(_selectedChildId!).length;
        }

        final tabs = [
          {'key': 'history', 'label': 'Historique', 'emoji': '📜', 'count': totalHistory},
          {'key': 'punishments', 'label': 'Punitions', 'emoji': '✍️', 'count': totalPunishments},
          {'key': 'immunities', 'label': 'Immunités', 'emoji': '🛡️', 'count': totalImmunities},
        ];

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TvFocusWrapper(
                          onTap: () => Navigator.pop(context),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                        const Expanded(
                          child: Text('👑 Administration',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ),
                        TvFocusWrapper(
                          onTap: () => _showBulkDeleteOptions(context),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            glowColor: Colors.red,
                            onTap: () => _showBulkDeleteOptions(context),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_sweep,
                                    color: Colors.redAccent, size: 20),
                                SizedBox(width: 4),
                                Text('Masse',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sélecteur enfant
                  if (children.length > 1)
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: children.length,
                        itemBuilder: (_, index) {
                          final child = children[index];
                          final isSelected =
                              child.id == _selectedChildId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TvFocusWrapper(
                              onTap: () => setState(
                                  () => _selectedChildId = child.id),
                              child: ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(child.name),
                                    const SizedBox(width: 4),
                                    Text('(${child.points} pts)',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white54)),
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor:
                                    Colors.purple.withOpacity(0.3),
                                onSelected: (_) => setState(
                                    () => _selectedChildId = child.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Tabs
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: tabs.map((tab) {
                        final isSelected =
                            _currentTab == tab['key'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TvFocusWrapper(
                            onTap: () => setState(
                                () => _currentTab = tab['key'] as String),
                            child: GlassCard(
                              glowColor: isSelected
                                  ? Colors.purpleAccent
                                  : null,
                              onTap: () => setState(
                                  () => _currentTab = tab['key'] as String),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(tab['emoji'] as String,
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(tab['label'] as String,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white54,
                                        fontSize: 13,
                                      )),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text('${tab['count']}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white54)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Astuce swipe
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '← Glisse vers la gauche sur un élément pour le supprimer rapidement',
                      style: TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                          fontStyle: FontStyle.italic),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Contenu
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentTab == 'history'
                          ? _buildHistoryTab(provider)
                          : _currentTab == 'punishments'
                              ? _buildPunishmentsTab(provider)
                              : _buildImmunitiesTab(provider),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
