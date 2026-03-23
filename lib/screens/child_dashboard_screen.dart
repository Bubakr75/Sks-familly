import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/history_entry.dart';
import 'school_notes_screen.dart';
import 'trade_screens.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childId;
  const ChildDashboardScreen({super.key, required this.childId});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.getChild(widget.childId);
        if (child == null) {
          return Scaffold(
            body: Center(child: Text('Enfant non trouvé')),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0a0a2a),
          appBar: AppBar(
            title: Text(child.name),
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'Profil'),
                Tab(text: 'Temps d\'écran'),
                Tab(text: 'Historique'),
                Tab(text: 'Badges'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildProfileTab(child, provider),
              _buildScreenTimeTab(child, provider),
              _buildHistoryTab(child, provider),
              _buildBadgesTab(child, provider),
            ],
          ),
        );
      },
    );
  }

  // ===== TAB PROFIL =====
  Widget _buildProfileTab(ChildModel child, FamilyProvider provider) {
    final availableImmunity = provider.getTotalAvailableImmunity(widget.childId);
    final pendingTrades = provider.getPendingTradesForChild(widget.childId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar et infos
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.amber.withOpacity(0.3),
            child: child.hasPhoto
                ? ClipOval(child: Image.memory(
                    Uri.parse('data:image/png;base64,${child.photoBase64}').data!.contentAsBytes(),
                    width: 100, height: 100, fit: BoxFit.cover))
                : Text(child.name[0], style: const TextStyle(fontSize: 40, color: Colors.amber)),
          ),
          const SizedBox(height: 12),
          Text(child.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(child.levelTitle, style: const TextStyle(color: Colors.amber, fontSize: 16)),
          const SizedBox(height: 8),
          Text('${child.points} points', style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 8),

          // Barre de progression
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Niveau ${child.currentLevelNumber}', style: const TextStyle(color: Colors.white70)),
                    Text('${child.points}/${child.nextLevelPoints} pts', style: const TextStyle(color: Colors.amber)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: child.levelProgress,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bouton Notes scolaires
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SchoolNotesScreen(childId: widget.childId),
                ));
              },
              icon: const Icon(Icons.school, color: Colors.black),
              label: const Text('\u{1F4DD} Notes & Temps d\'ecran', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bouton Échanges d'immunité
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TradeScreen(childId: widget.childId),
                ));
              },
              icon: const Icon(Icons.swap_horiz_rounded, color: Colors.black),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰 Vente d\'immunités', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  if (pendingTrades.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${pendingTrades.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (availableImmunity > 0) ...[
            const SizedBox(height: 4),
            Text('$availableImmunity lignes d\'immunite disponibles', style: const TextStyle(color: Color(0xFF00E676), fontSize: 12)),
          ],
          const SizedBox(height: 12),

          // Stats rapides
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u{1F4CA} Stats de la semaine', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildStatRow('Points cette semaine', '${provider.getWeeklyPoints(widget.childId).length}'),
                _buildStatRow('Note globale', '${provider.getWeeklyGlobalScore(widget.childId).toStringAsFixed(1)}/20'),
                _buildStatRow('Samedi', _formatMinutes(provider.getSaturdayMinutes(widget.childId))),
                _buildStatRow('Dimanche', _formatMinutes(provider.getSundayMinutes(widget.childId))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== TAB TEMPS D'ÉCRAN =====
  Widget _buildScreenTimeTab(ChildModel child, FamilyProvider provider) {
    final globalScore = provider.getWeeklyGlobalScore(widget.childId);
    final schoolAvg = provider.getWeeklySchoolAverage(widget.childId);
    final behaviorScore = provider.getWeeklyBehaviorScore(widget.childId);
    final satMinutes = provider.getSaturdayMinutes(widget.childId);
    final sunMinutes = provider.getSundayMinutes(widget.childId);
    final bonus = provider.getParentBonusMinutes(widget.childId);
    final satRating = provider.getSaturdayBehaviorRating(widget.childId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGlassCard(
            child: Column(
              children: [
                const Text('\u{1F4FA} Temps d\'ecran', style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBigTimeChip('Samedi', satMinutes),
                    _buildBigTimeChip('Dimanche', sunMinutes),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total week-end : ${_formatMinutes(satMinutes + sunMinutes)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u{1F4CA} Details du calcul', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildStatRow('Note globale semaine', '${globalScore.toStringAsFixed(1)}/20'),
                _buildStatRow('Moy. scolaire', schoolAvg >= 0 ? '${schoolAvg.toStringAsFixed(1)}/20' : 'Aucune note'),
                _buildStatRow('Score comportement', '${behaviorScore.toStringAsFixed(1)}/20'),
                _buildStatRow('Bonus parent', bonus != 0 ? '${bonus > 0 ? "+" : ""}${bonus}min' : 'Aucun'),
                if (satRating >= 0)
                  _buildStatRow('Note samedi (\u{2192}dim)', '${satRating.toStringAsFixed(0)}/20'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u{1F381} Bonus / Ajustement', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBonusButton(provider, '-30', -30),
                    _buildBonusButton(provider, '-15', -15),
                    _buildBonusButton(provider, '+15', 15),
                    _buildBonusButton(provider, '+30', 30),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCustomBonusDialog(context, provider),
                    icon: const Icon(Icons.star, color: Colors.black, size: 18),
                    label: const Text('Bonne note / Bonus personnalise',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await provider.resetScreenTimeBonus(widget.childId);
                    },
                    child: const Text('Reinitialiser les bonus', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSaturdayRatingDialog(context, provider),
              icon: const Icon(Icons.edit_note, color: Colors.black),
              label: const Text('Noter le comportement du samedi (\u{2192} dimanche)',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== TAB HISTORIQUE =====
  Widget _buildHistoryTab(ChildModel child, FamilyProvider provider) {
    final recentHistory = provider.getRecentHistory(widget.childId, limit: 50);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (recentHistory.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucun historique', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          ...recentHistory.map((entry) => _buildHistoryTile(entry)),
      ],
    );
  }

  Widget _buildHistoryTile(HistoryEntry entry) {
    final dateStr = DateFormat('dd/MM à HH:mm', 'fr_FR').format(entry.date);
    final isPositive = entry.isBonus && entry.points > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPositive ? Colors.greenAccent.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            color: isPositive ? Colors.greenAccent : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.reason, style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${entry.points > 0 ? "+" : ""}${entry.points}',
            style: TextStyle(
              color: isPositive ? Colors.greenAccent : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ===== TAB BADGES =====
  Widget _buildBadgesTab(ChildModel child, FamilyProvider provider) {
    final badges = child.badgeIds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (badges.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucun badge debloque', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          ...badges.map((badgeId) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('\u{1F3C6} ', style: TextStyle(fontSize: 24)),
                    Text(badgeId, style: const TextStyle(color: Colors.amber, fontSize: 15)),
                  ],
                ),
              )),
      ],
    );
  }

  // ===== DIALOGS =====
  void _showCustomBonusDialog(BuildContext context, FamilyProvider provider) {
    int bonusMinutes = 15;
    String reason = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a4a),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('\u{1F381} Bonus personnalise', style: TextStyle(color: Colors.amber, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Minutes a ajouter :', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 30, 45, 60, 90, 120].map((min) {
                      final isSelected = bonusMinutes == min;
                      return GestureDetector(
                        onTap: () => setDialogState(() => bonusMinutes = min),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.amber.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? Colors.amber : Colors.white24),
                          ),
                          child: Text(
                            _formatMinutes(min),
                            style: TextStyle(
                              color: isSelected ? Colors.amber : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => reason = val,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Raison (ex: Bonne note en maths)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final r = reason.isNotEmpty ? reason : 'Bonus';
                    await provider.addScreenTimeBonus(widget.childId, bonusMinutes, r);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: const Text('Ajouter', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSaturdayRatingDialog(BuildContext context, FamilyProvider provider) {
    int rating = 10;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a4a),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('\u{1F4CB} Note du samedi', style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Comment s\'est comporte l\'enfant aujourd\'hui ?',
                      style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (rating > 0) setDialogState(() => rating--);
                        },
                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 32),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$rating/20',
                          style: TextStyle(
                            color: rating >= 16
                                ? Colors.greenAccent
                                : rating >= 12
                                    ? Colors.yellow
                                    : rating >= 8
                                        ? Colors.orange
                                        : Colors.red,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (rating < 20) setDialogState(() => rating++);
                        },
                        icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 32),
                      ),
                    ],
                  ),
                  Slider(
                    value: rating.toDouble(),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    activeColor: Colors.deepPurpleAccent,
                    inactiveColor: Colors.white24,
                    onChanged: (val) => setDialogState(() => rating = val.round()),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Temps d\'ecran dimanche : ${_formatMinutes(_previewMinutesFromRating(rating))}',
                    style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await provider.rateSaturdayBehavior(widget.childId, rating);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
                  child: const Text('Valider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===== HELPERS =====
  Widget _buildBonusButton(FamilyProvider provider, String label, int minutes) {
    final isPositive = minutes > 0;
    return ElevatedButton(
      onPressed: () async {
        await provider.addScreenTimeBonus(widget.childId, minutes, 'Ajustement rapide');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isPositive ? Colors.greenAccent.withOpacity(0.2) : Colors.red.withOpacity(0.2),
        side: BorderSide(color: isPositive ? Colors.greenAccent : Colors.red),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.red, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBigTimeChip(String label, int minutes) {
    Color color;
    if (minutes >= 150) {
      color = Colors.greenAccent;
    } else if (minutes >= 90) {
      color = Colors.yellow;
    } else if (minutes >= 30) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            _formatMinutes(minutes),
            style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: child,
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h${mins.toString().padLeft(2, '0')}';
    if (hours > 0) return '${hours}h';
    return '${mins}min';
  }

  int _previewMinutesFromRating(int rating) {
    if (rating >= 18) return 180;
    if (rating >= 16) return 150;
    if (rating >= 14) return 120;
    if (rating >= 12) return 90;
    if (rating >= 10) return 60;
    if (rating >= 8) return 30;
    return 0;
  }
}
