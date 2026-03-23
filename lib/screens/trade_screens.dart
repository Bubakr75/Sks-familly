import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/trade_model.dart';

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
          return Scaffold(
            backgroundColor: const Color(0xFF0a0a2a),
            body: const Center(child: Text('Enfant non trouvé', style: TextStyle(color: Colors.white))),
          );
        }

        final availableImmunity = provider.getTotalAvailableImmunity(widget.childId);
        final allTrades = provider.getTradesForChild(widget.childId);
        final activeTrades = allTrades.where((t) => t.isActive).toList();
        final pendingForMe = provider.getPendingTradesForChild(widget.childId);
        final completedTrades = allTrades.where((t) => t.isCompleted || t.isRejected || t.isCancelled).toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0a0a2a),
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_rounded, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                const Text('Vente d\'immunités'),
              ],
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Marché'),
                      if (pendingForMe.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildBadgeCount(pendingForMe.length),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('En cours'),
                      if (activeTrades.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _buildBadgeCount(activeTrades.length),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Historique'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Bandeau stock d'immunités
              _buildImmunityBanner(child, availableImmunity),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMarketTab(provider, child, availableImmunity, pendingForMe),
                    _buildActiveTab(provider, child, activeTrades),
                    _buildHistoryTab(provider, child, completedTrades),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: availableImmunity > 0
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateSaleDialog(context, provider, child, availableImmunity),
                  backgroundColor: const Color(0xFF00E676),
                  icon: const Icon(Icons.sell_rounded, color: Colors.black),
                  label: const Text('Vendre', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              : null,
        );
      },
    );
  }

  // ══════════════════════════════════════
  //  BANDEAU IMMUNITÉS
  // ══════════════════════════════════════
  Widget _buildImmunityBanner(ChildModel child, int available) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00E676).withOpacity(0.12),
            const Color(0xFF00E676).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                Text(
                  available > 0
                      ? '$available ligne${available > 1 ? 's' : ''} d\'immunité disponible${available > 1 ? 's' : ''}'
                      : 'Aucune immunité à vendre',
                  style: TextStyle(
                    color: available > 0 ? const Color(0xFF00E676) : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: available > 0
                  ? const Color(0xFF00E676).withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: available > 0
                    ? const Color(0xFF00E676).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Text(
              '$available',
              style: TextStyle(
                color: available > 0 ? const Color(0xFF00E676) : Colors.white38,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  TAB MARCHÉ
  // ══════════════════════════════════════
  Widget _buildMarketTab(FamilyProvider provider, ChildModel child, int available, List<TradeModel> pendingForMe) {
    // Offres en attente POUR cet enfant (quelqu'un lui vend)
    // + offres créées PAR cet enfant en attente
    final myPendingSales = provider.trades
        .where((t) => t.isPending && t.fromChildId == widget.childId)
        .toList();

    if (pendingForMe.isEmpty && myPendingSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: 70, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('Aucune offre en cours', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
            const SizedBox(height: 8),
            if (available > 0)
              Text('Appuyez sur "Vendre" pour proposer une vente', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendingForMe.isNotEmpty) ...[
          _buildSectionTitle('📩 Offres reçues', Colors.amber),
          const SizedBox(height: 8),
          ...pendingForMe.map((trade) => _buildPendingOfferCard(provider, trade, isReceived: true)),
          const SizedBox(height: 20),
        ],
        if (myPendingSales.isNotEmpty) ...[
          _buildSectionTitle('📤 Mes ventes en attente', const Color(0xFF00E676)),
          const SizedBox(height: 8),
          ...myPendingSales.map((trade) => _buildPendingOfferCard(provider, trade, isReceived: false)),
        ],
      ],
    );
  }

  Widget _buildPendingOfferCard(FamilyProvider provider, TradeModel trade, {required bool isReceived}) {
    final seller = provider.getChild(trade.fromChildId);
    final buyer = provider.getChild(trade.toChildId);
    final otherChild = isReceived ? seller : buyer;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReceived
              ? Colors.amber.withOpacity(0.3)
              : const Color(0xFF00E676).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    otherChild?.avatar.isNotEmpty == true ? otherChild!.avatar : '👤',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReceived
                          ? '${seller?.name ?? "?"} te vend'
                          : 'Vente à ${buyer?.name ?? "?"}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} d\'immunité',
                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('${trade.immunityLines}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💼 Service demandé :', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                const SizedBox(height: 4),
                Text(trade.serviceDescription, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isReceived)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => provider.rejectTrade(trade.id),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Refuser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => provider.acceptTrade(trade.id),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accepter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
                      foregroundColor: const Color(0xFF00E676),
                      side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => provider.cancelTrade(trade.id),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Annuler la vente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.15),
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  TAB EN COURS
  // ══════════════════════════════════════
  Widget _buildActiveTab(FamilyProvider provider, ChildModel child, List<TradeModel> activeTrades) {
    // On ne montre ici que les trades "accepted" ou "service_done"
    final inProgress = activeTrades.where((t) => t.isAccepted || t.isServiceDone).toList();

    if (inProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 70, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('Aucune vente en cours', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: inProgress.map((trade) => _buildActiveTradeCard(provider, trade)).toList(),
    );
  }

  Widget _buildActiveTradeCard(FamilyProvider provider, TradeModel trade) {
    final seller = provider.getChild(trade.fromChildId);
    final buyer = provider.getChild(trade.toChildId);
    final isSeller = trade.fromChildId == widget.childId;

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (trade.isAccepted) {
      statusColor = Colors.orange;
      statusText = 'En attente du service';
      statusIcon = Icons.pending_actions_rounded;
    } else {
      statusColor = const Color(0xFF7C4DFF);
      statusText = 'Service rendu — validation parent';
      statusIcon = Icons.verified_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${seller?.name ?? "?"} → ${buyer?.name ?? "?"}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} d\'immunité',
                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 16),
                    const SizedBox(width: 4),
                    Text('${trade.immunityLines}', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('💼 ${trade.serviceDescription}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          const SizedBox(height: 12),

          // Actions selon le statut
          if (trade.isAccepted && !isSeller)
            // L'acheteur peut marquer le service comme fait
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => provider.markServiceDone(trade.id),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('J\'ai rendu le service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
                  foregroundColor: const Color(0xFF00E676),
                  side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          if (trade.isServiceDone)
            // Le parent doit valider
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showParentValidationDialog(context, provider, trade),
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: const Text('Validation parent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF).withOpacity(0.2),
                  foregroundColor: const Color(0xFF7C4DFF),
                  side: BorderSide(color: const Color(0xFF7C4DFF).withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          // Bouton annuler toujours dispo
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () => provider.cancelTrade(trade.id),
              child: const Text('Annuler', style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  TAB HISTORIQUE
  // ══════════════════════════════════════
  Widget _buildHistoryTab(FamilyProvider provider, ChildModel child, List<TradeModel> trades) {
    if (trades.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 70, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('Aucune vente terminée', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: trades.map((trade) {
        final seller = provider.getChild(trade.fromChildId);
        final buyer = provider.getChild(trade.toChildId);
        final dateStr = DateFormat('dd/MM/yy à HH:mm', 'fr_FR').format(trade.createdAt);

        Color statusColor;
        if (trade.isCompleted) {
          statusColor = const Color(0xFF00E676);
        } else if (trade.isRejected) {
          statusColor = Colors.red;
        } else {
          statusColor = Colors.grey;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(trade.statusEmoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${seller?.name ?? "?"} → ${buyer?.name ?? "?"}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} • ${trade.serviceDescription}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trade.statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════
  //  DIALOG: CRÉER UNE VENTE
  // ══════════════════════════════════════
  void _showCreateSaleDialog(BuildContext context, FamilyProvider provider, ChildModel seller, int maxLines) {
    final otherChildren = provider.children.where((c) => c.id != widget.childId).toList();

    if (otherChildren.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Il faut au moins 2 enfants pour une vente'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    String? selectedBuyerId;
    int lines = 1;
    String service = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a4a),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.sell_rounded, color: Color(0xFF00E676), size: 22),
                  SizedBox(width: 8),
                  Text('Nouvelle vente', style: TextStyle(color: Color(0xFF00E676), fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélection de l'acheteur
                    const Text('Vendre à :', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: otherChildren.map((c) {
                        final isSelected = selectedBuyerId == c.id;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedBuyerId = c.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF00E676).withOpacity(0.2) : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF00E676) : Colors.white24,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.avatar.isNotEmpty ? c.avatar : '👤',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  c.name,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF00E676) : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Nombre de lignes
                    const Text('Nombre de lignes :', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: lines > 1 ? () => setDialogState(() => lines--) : null,
                          icon: Icon(Icons.remove_circle_rounded, color: lines > 1 ? Colors.red : Colors.grey, size: 32),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$lines',
                            style: const TextStyle(color: Color(0xFF00E676), fontSize: 28, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: lines < maxLines ? () => setDialogState(() => lines++) : null,
                          icon: Icon(Icons.add_circle_rounded, color: lines < maxLines ? const Color(0xFF00E676) : Colors.grey, size: 32),
                        ),
                      ],
                    ),
                    Center(
                      child: Text('max: $maxLines', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                    ),
                    const SizedBox(height: 20),

                    // Service demandé
                    const Text('Service demandé en échange :', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (val) => service = val,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Ex: Ranger ma chambre, faire la vaisselle...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: selectedBuyerId != null && service.trim().isNotEmpty
                      ? () async {
                          await provider.createTrade(widget.childId, selectedBuyerId!, lines, service.trim());
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Vente proposée !'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF00E676),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.sell_rounded, size: 18),
                  label: const Text('Proposer la vente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════
  //  DIALOG: VALIDATION PARENT
  // ══════════════════════════════════════
  void _showParentValidationDialog(BuildContext context, FamilyProvider provider, TradeModel trade) {
    String note = '';
    final seller = provider.getChild(trade.fromChildId);
    final buyer = provider.getChild(trade.toChildId);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a4a),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFF7C4DFF), size: 22),
              SizedBox(width: 8),
              Text('Validation parent', style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${seller?.name ?? "?"} vend ${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} à ${buyer?.name ?? "?"}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text('Service : ${trade.serviceDescription}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Note (optionnel) :', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (val) => note = val,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Commentaire...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await provider.completeTrade(trade.id, parentNote: note.isNotEmpty ? note : null);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Vente validée ! Immunités transférées.'),
                        ],
                      ),
                      backgroundColor: const Color(0xFF7C4DFF),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Valider la vente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════
  Widget _buildBadgeCount(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
