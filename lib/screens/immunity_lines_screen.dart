import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class ImmunityLinesScreen extends StatefulWidget {
  const ImmunityLinesScreen({super.key});

  @override
  State<ImmunityLinesScreen> createState() => _ImmunityLinesScreenState();
}

class _ImmunityLinesScreenState extends State<ImmunityLinesScreen> {
  void _showAddImmunity() {
    final provider = context.read<FamilyProvider>();
    final children = provider.children;
    String? selectedChildId;
    String reason = '';
    int lines = 1;
    bool hasExpiry = false;
    int expiryDays = 7;
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900]?.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nouvelle immunité',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      const Text('Enfant',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: children.map((child) {
                          final isSelected = selectedChildId == child.id;
                          return TvFocusWrapper(
                            autofocus: children.first.id == child.id,
                            onTap: () {
                              setModalState(
                                  () => selectedChildId = child.id);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.cyanAccent.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.cyanAccent
                                      : Colors.white24,
                                ),
                              ),
                              child: Text(
                                child.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.cyanAccent
                                      : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('Raison',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ex: Excellent bulletin...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Colors.cyanAccent),
                          ),
                        ),
                        onChanged: (val) => reason = val,
                      ),
                      const SizedBox(height: 20),
                      const Text('Nombre de lignes d\'immunité',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TvFocusWrapper(
                            onTap: () {
                              if (lines > 1) setModalState(() => lines--);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(Icons.remove,
                                  color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Text(
                            '$lines',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 24),
                          TvFocusWrapper(
                            onTap: () {
                              if (lines < 20) setModalState(() => lines++);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [1, 3, 5, 10].map((val) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: OutlinedButton(
                              onPressed: () =>
                                  setModalState(() => lines = val),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: lines == val
                                    ? Colors.cyanAccent
                                    : Colors.white54,
                                side: BorderSide(
                                  color: lines == val
                                      ? Colors.cyanAccent
                                      : Colors.white24,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text('$val'),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      TvFocusWrapper(
                        onTap: () =>
                            setModalState(() => hasExpiry = !hasExpiry),
                        child: Row(
                          children: [
                            Switch(
                              value: hasExpiry,
                              activeColor: Colors.cyanAccent,
                              onChanged: (val) =>
                                  setModalState(() => hasExpiry = val),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Définir une expiration',
                              style: TextStyle(
                                color: hasExpiry
                                    ? Colors.cyanAccent
                                    : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasExpiry) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [7, 14, 30, 60].map((val) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: OutlinedButton(
                                onPressed: () =>
                                    setModalState(() => expiryDays = val),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: expiryDays == val
                                      ? Colors.orangeAccent
                                      : Colors.white54,
                                  side: BorderSide(
                                    color: expiryDays == val
                                        ? Colors.orangeAccent
                                        : Colors.white24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text('${val}j'),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: TvFocusWrapper(
                          onTap: () {
                            if (selectedChildId == null || reason.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Sélectionnez un enfant et une raison'),
                                  backgroundColor: Colors.orangeAccent,
                                ),
                              );
                              return;
                            }
                            provider.addImmunityLines(
                              childId: selectedChildId!,
                              reason: reason,
                              lines: lines,
                              expiryDate: hasExpiry
                                  ? DateTime.now()
                                      .add(Duration(days: expiryDays))
                                  : null,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '$lines ligne(s) d\'immunité ajoutée(s)'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (selectedChildId == null || reason.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Sélectionnez un enfant et une raison'),
                                    backgroundColor: Colors.orangeAccent,
                                  ),
                                );
                                return;
                              }
                              provider.addImmunityLines(
                                childId: selectedChildId!,
                                reason: reason,
                                lines: lines,
                                expiryDate: hasExpiry
                                    ? DateTime.now()
                                        .add(Duration(days: expiryDays))
                                    : null,
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '$lines ligne(s) d\'immunité ajoutée(s)'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: const Icon(Icons.shield),
                            label: const Text('Créer l\'immunité',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _getImmunityStatus(dynamic immunity) {
    if (immunity.isUsed == true) return 'used';
    if (immunity.expiryDate != null &&
        immunity.expiryDate.isBefore(DateTime.now())) return 'expired';
    return 'usable';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'usable':
        return Colors.greenAccent;
      case 'used':
        return Colors.white38;
      case 'expired':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'usable':
        return 'Disponible';
      case 'used':
        return 'Utilisée';
      case 'expired':
        return 'Expirée';
      default:
        return '';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'usable':
        return Icons.shield;
      case 'used':
        return Icons.check_circle_outline;
      case 'expired':
        return Icons.timer_off;
      default:
        return Icons.help_outline;
    }
  }

  void _showImmunityDetail(dynamic immunity, dynamic child) {
    final status = _getImmunityStatus(immunity);
    final statusColor = _getStatusColor(status);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(_getStatusIcon(status),
                          color: statusColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          immunity.reason ?? 'Sans raison',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _detailRow('Enfant', child.name),
                  _detailRow('Statut', _getStatusLabel(status),
                      valueColor: statusColor),
                  _detailRow('Lignes', '${immunity.lines ?? 1}'),
                  _detailRow(
                      'Créée le',
                      immunity.createdAt != null
                          ? _formatDate(immunity.createdAt)
                          : 'N/A'),
                  if (immunity.expiryDate != null)
                    _detailRow(
                        'Expire le', _formatDate(immunity.expiryDate),
                        valueColor: status == 'expired'
                            ? Colors.redAccent
                            : Colors.orangeAccent),
                  const SizedBox(height: 24),
                  if (status == 'usable') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TvFocusWrapper(
                            onTap: () {
                              Navigator.pop(ctx);
                              _confirmDelete(immunity);
                            },
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _confirmDelete(immunity);
                              },
                              icon: const Icon(Icons.delete_outline,
                                  size: 18),
                              label: const Text('Supprimer'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(
                                    color: Colors.redAccent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TvFocusWrapper(
                            onTap: () {
                              Navigator.pop(ctx);
                              _tradeImmunity(immunity, child);
                            },
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _tradeImmunity(immunity, child);
                              },
                              icon:
                                  const Icon(Icons.swap_horiz, size: 18),
                              label: const Text('Échanger'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.orangeAccent.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _confirmDelete(dynamic immunity) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Supprimer l\'immunité ?',
              style: TextStyle(color: Colors.white)),
          content: const Text('Cette action est irréversible.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white54)),
            ),
            TvFocusWrapper(
              onTap: () {
                context.read<FamilyProvider>().deleteImmunity(immunity.id);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: ElevatedButton(
                onPressed: () {
                  context
                      .read<FamilyProvider>()
                      .deleteImmunity(immunity.id);
                  Navigator.pop(ctx);
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Supprimer'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _tradeImmunity(dynamic immunity, dynamic child) {
    final provider = context.read<FamilyProvider>();
    provider.createTrade(
      fromChildId: child.id,
      immunityId: immunity.id,
      type: 'immunity',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Échange proposé !'),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Lignes d\'immunité'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: TvFocusWrapper(
          onTap: _showAddImmunity,
          child: FloatingActionButton.extended(
            onPressed: _showAddImmunity,
            backgroundColor: Colors.cyanAccent.shade700,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        ),
        body: Consumer<FamilyProvider>(
          builder: (context, provider, _) {
            final children = provider.children;

            if (children.isEmpty) {
              return const Center(
                child: Text(
                  'Aucun enfant enregistré',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                final immunities =
                    provider.getImmunitiesForChild(child.id);

                final usable = immunities
                    .where((i) => _getImmunityStatus(i) == 'usable')
                    .toList();
                final used = immunities
                    .where((i) => _getImmunityStatus(i) == 'used')
                    .toList();
                final expired = immunities
                    .where((i) => _getImmunityStatus(i) == 'expired')
                    .toList();

                final totalLines = usable.fold<int>(
                    0, (sum, i) => sum + ((i.lines as int?) ?? 1));

                return GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  Colors.cyanAccent.withOpacity(0.3),
                              child: Text(
                                child.name.isNotEmpty
                                    ? child.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    child.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${child.points} pts',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    Colors.greenAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.greenAccent
                                        .withOpacity(0.5)),
                              ),
                              child: Text(
                                '$totalLines lignes dispo',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (immunities.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'Aucune immunité',
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                        if (usable.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _sectionChip(
                              'Disponibles', Colors.greenAccent, usable.length),
                          ...usable.map((imm) =>
                              _buildImmunityTile(imm, child, 'usable')),
                        ],
                        if (used.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _sectionChip(
                              'Utilisées', Colors.white38, used.length),
                          ...used.map((imm) =>
                              _buildImmunityTile(imm, child, 'used')),
                        ],
                        if (expired.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _sectionChip(
                              'Expirées', Colors.redAccent, expired.length),
                          ...expired.map((imm) =>
                              _buildImmunityTile(imm, child, 'expired')),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _sectionChip(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($count)',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmunityTile(
      dynamic immunity, dynamic child, String status) {
    final statusColor = _getStatusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TvFocusWrapper(
        onTap: () => _showImmunityDetail(immunity, child),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(_getStatusIcon(status), color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      immunity.reason ?? 'Sans raison',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (immunity.expiryDate != null)
                      Text(
                        'Expire: ${_formatDate(immunity.expiryDate)}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${immunity.lines ?? 1}L',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
