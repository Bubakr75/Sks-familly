import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/trade_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class TradeScreen extends StatefulWidget {
  final String childId;
  const TradeScreen({super.key, required this.childId});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          return const Scaffold(body: Center(child: Text('Enfant non trouve')));
        }

        final myTrades = provider.getTradesForChild(widget.childId);
        final pendingForMe = provider.getPendingTradesForChild(widget.childId);
        final activeTrades = myTrades.where((t) => t.isActive).toList();
        final completedTrades = myTrades.where((t) => t.isCompleted || t.isRejected || t.isCancelled).toList();
        final availableImmunity = provider.getTotalAvailableImmunity(widget.childId);

        return Scaffold(
          backgroundColor: const Color(0xFF0A0E21),
          appBar: AppBar(
            title: const Text('Echanges d\'immunite', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00E676),
              labelColor: const Color(0xFF00E676),
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: 'Recus (${pendingForMe.length})'),
                Tab(text: 'En cours (${activeTrades.length})'),
                const Tab(text: 'Historique'),
              ],
            ),
          ),
          floatingActionButton: availableImmunity > 0
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFF00E676).withOpacity(0.3), blurRadius: 16)],
                  ),
                  child: FloatingActionButton.extended(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    onPressed: () => _showCreateTradeDialog(context, provider),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Proposer un echange', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )
              : null,
          body: AnimatedBackground(
            child: Column(
              children: [
                // Résumé immunité
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildImmunitySummary(child.name, availableImmunity),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Onglet Reçus
                      pendingForMe.isEmpty
                          ? _buildEmptyState('\u{1F4ED}', 'Aucune proposition recue')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: pendingForMe.length,
                              itemBuilder: (_, i) => _buildPendingCard(pendingForMe[i], provider),
                            ),
                      // Onglet En cours
                      activeTrades.isEmpty
                          ? _buildEmptyState('\u{1F91D}', 'Aucun echange en cours')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: activeTrades.length,
                              itemBuilder: (_, i) => _buildActiveCard(activeTrades[i], provider),
                            ),
                      // Onglet Historique
                      completedTrades.isEmpty
                          ? _buildEmptyState('\u{1F4DC}', 'Aucun echange termine')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: completedTrades.length,
                              itemBuilder: (_, i) => _buildHistoryCard(completedTrades[i], provider),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════

  Widget _buildImmunitySummary(String name, int available) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF00E676).withOpacity(available > 0 ? 0.1 : 0.04),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(available > 0 ? 0.3 : 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF00E676).withOpacity(0.15),
            ),
            child: const Center(child: Text('\u{1F6E1}', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  available > 0 ? '$available lignes d\'immunite disponibles' : 'Aucune immunite a echanger',
                  style: TextStyle(color: available > 0 ? const Color(0xFF00E676) : Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$available',
            style: TextStyle(
              color: available > 0 ? const Color(0xFF00E676) : Colors.grey,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String emoji, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 15)),
        ],
      ),
    );
  }

  // ── Carte proposition reçue ──
  Widget _buildPendingCard(TradeModel trade, FamilyProvider provider) {
    final fromChild = provider.getChild(trade.fromChildId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.amber.withOpacity(0.2),
                child: Text(fromChild?.avatar ?? '\u{1F466}', style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${fromChild?.name ?? "?"} te propose', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${trade.immunityLines} lignes d\'immunite', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const Text('\u{23F3}', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Service demande :', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 4),
                Text(trade.serviceDescription, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => provider.rejectTrade(trade.id),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Refuser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF1744),
                    side: const BorderSide(color: Color(0xFFFF1744)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => provider.acceptTrade(trade.id),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Accepter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Carte échange en cours ──
  Widget _buildActiveCard(TradeModel trade, FamilyProvider provider) {
    final fromChild = provider.getChild(trade.fromChildId);
    final toChild = provider.getChild(trade.toChildId);
    final isFrom = trade.fromChildId == widget.childId;
    final otherChild = isFrom ? toChild : fromChild;

    Color statusColor;
    String statusText;
    switch (trade.status) {
      case 'pending':
        statusColor = Colors.amber;
        statusText = 'En attente de reponse';
        break;
      case 'accepted':
        statusColor = Colors.blue;
        statusText = isFrom ? '${otherChild?.name} doit rendre le service' : 'Tu dois rendre le service';
        break;
      case 'service_done':
        statusColor = Colors.purple;
        statusText = 'En attente de validation parent';
        break;
      default:
        statusColor = Colors.grey;
        statusText = trade.statusLabel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(trade.statusEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFrom ? 'Tu proposes a ${otherChild?.name}' : '${otherChild?.name} te propose',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text('${trade.immunityLines} lignes d\'immunite', style: TextStyle(color: statusColor, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: statusColor.withOpacity(0.1),
            ),
            child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Text('Service : ${trade.serviceDescription}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),

          // Actions selon le statut
          if (trade.isPending && isFrom)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => provider.cancelTrade(trade.id),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Annuler ma proposition'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF1744),
                  side: const BorderSide(color: Color(0xFFFF1744)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          if (trade.isAccepted && !isFrom)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => provider.markServiceDone(trade.id),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('J\'ai rendu le service'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          if (trade.isServiceDone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.purple.withOpacity(0.1),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.purple, size: 16),
                  SizedBox(width: 6),
                  Text('Un parent doit valider', style: TextStyle(color: Colors.purple, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Carte historique ──
  Widget _buildHistoryCard(TradeModel trade, FamilyProvider provider) {
    final fromChild = provider.getChild(trade.fromChildId);
    final toChild = provider.getChild(trade.toChildId);

    Color statusColor;
    switch (trade.status) {
      case 'completed':
        statusColor = const Color(0xFF00E676);
        break;
      case 'rejected':
        statusColor = const Color(0xFFFF1744);
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(trade.statusEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fromChild?.name ?? "?"} \u{2192} ${toChild?.name ?? "?"}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text('${trade.immunityLines} lignes - ${trade.serviceDescription}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(trade.statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  DIALOG CRÉER UN ÉCHANGE
  // ══════════════════════════════════════
  void _showCreateTradeDialog(BuildContext context, FamilyProvider provider) {
    final otherChildren = provider.children.where((c) => c.id != widget.childId).toList();
    if (otherChildren.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il faut au moins 2 enfants pour echanger')),
      );
      return;
    }

    String? selectedChildId = otherChildren.first.id;
    int linesToTrade = 5;
    final serviceCtrl = TextEditingController();
    final available = provider.getTotalAvailableImmunity(widget.childId);

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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00E676), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Proposer un echange', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),

                // Choisir l'enfant
                const Text('Proposer a :', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: otherChildren.length,
                    itemBuilder: (_, i) {
                      final c = otherChildren[i];
                      final isSelected = selectedChildId == c.id;
                      return GestureDetector(
                        onTap: () => setState(() => selectedChildId = c.id),
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isSelected ? const Color(0xFF00E676).withOpacity(0.15) : Colors.white.withOpacity(0.04),
                            border: Border.all(color: isSelected ? const Color(0xFF00E676) : Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(c.avatar.isEmpty ? '\u{1F466}' : c.avatar, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 2),
                              Text(c.name, style: TextStyle(fontSize: 10, color: isSelected ? const Color(0xFF00E676) : Colors.white54), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Nombre de lignes
                Text('Lignes d\'immunite a donner (max $available) :', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () { if (linesToTrade > 1) setState(() => linesToTrade--); },
                      icon: const Icon(Icons.remove_circle_rounded, color: Color(0xFFFF1744), size: 32),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF00E676).withOpacity(0.1),
                        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
                      ),
                      child: Text('$linesToTrade', style: const TextStyle(color: Color(0xFF00E676), fontSize: 28, fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      onPressed: () { if (linesToTrade < available) setState(() => linesToTrade++); },
                      icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF00E676), size: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [5, 10, 15, 20, 30].where((v) => v <= available).map((v) {
                    final isSelected = linesToTrade == v;
                    return GestureDetector(
                      onTap: () => setState(() => linesToTrade = v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected ? const Color(0xFF00E676).withOpacity(0.15) : Colors.white.withOpacity(0.04),
                          border: Border.all(color: isSelected ? const Color(0xFF00E676).withOpacity(0.5) : Colors.white.withOpacity(0.08)),
                        ),
                        child: Text('$v', style: TextStyle(color: isSelected ? const Color(0xFF00E676) : Colors.white54, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Service demandé
                const Text('Service demande en echange :', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: serviceCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ex: Ranger ma chambre pendant 2 jours',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Ranger ma chambre',
                    'Faire la vaisselle',
                    'Aider aux devoirs',
                    'Passer l\'aspirateur',
                    'Faire mon lit pendant 1 semaine',
                  ].map((s) => GestureDetector(
                        onTap: () => setState(() => serviceCtrl.text = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withOpacity(0.04),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Text(s, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                        ),
                      )).toList(),
                ),
                const SizedBox(height: 20),

                // Bouton valider
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: selectedChildId != null && serviceCtrl.text.isNotEmpty
                        ? () {
                            provider.createTrade(widget.childId, selectedChildId!, linesToTrade, serviceCtrl.text);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Text('\u{1F91D}', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Text('Proposition d\'echange envoyee !')),
                                ]),
                                backgroundColor: const Color(0xFF00E676),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: const Text('Envoyer la proposition', style: TextStyle(fontWeight: FontWeight.w700)),
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
