import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../models/child_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import 'manage_children_screen.dart';
import 'punishment_lines_screen.dart';
import 'immunity_lines_screen.dart';
import 'screen_time_screen.dart';
import 'school_notes_screen.dart';
import 'child_dashboard_screen.dart';
import 'tribunal_screen.dart';
import 'badges_screen.dart';
import 'trade_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final children = provider.childrenSorted;
        final allTrades = provider.trades;
        final activeTrades = allTrades.where((t) => t.isActive).toList();

        return FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ══════════════════════════════
                //  HEADER SKS FAMILY (interactif)
                // ══════════════════════════════
                _buildHeader(provider),
                const SizedBox(height: 20),

                // ══════════════════════════════
                //  CLASSEMENT PODIUM
                // ══════════════════════════════
                if (children.isNotEmpty) ...[
                  const Text(
                    'CLASSEMENT 👑',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPodium(children, provider),
                  const SizedBox(height: 20),
                ],

                // ══════════════════════════════
                //  QUICK ACTIONS GRILLE
                // ══════════════════════════════
                _buildQuickActionsGrid(context, provider),
                const SizedBox(height: 20),

                // ══════════════════════════════
                //  VENTES EN COURS
                // ══════════════════════════════
                if (activeTrades.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text(
                        '🏷 Ventes en cours',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${activeTrades.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...activeTrades.map(
                      (trade) => _buildTradeCard(trade, provider)),
                  const SizedBox(height: 12),
                ],

                // ══════════════════════════════
                //  BOUTON HISTORIQUE
                // ══════════════════════════════
                TvFocusWrapper(
                  onTap: () => _showFullHistory(provider),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyanAccent.withOpacity(0.08),
                          Colors.purpleAccent.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Text(
                        'Voir l\'historique complet',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //  HEADER — bouton interactif pour le drawer
  // ══════════════════════════════════════════
  Widget _buildHeader(FamilyProvider provider) {
    return Row(
      children: [
        // Bouton SKS interactif pour ouvrir le drawer
        TvFocusWrapper(
          onTap: () => Scaffold.of(context).openDrawer(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C4DFF),
                  const Color(0xFF536DFE),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'SKS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                // Petit indicateur "menu" en bas
                Positioned(
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 4, height: 2, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(1))),
                      const SizedBox(width: 2),
                      Container(width: 8, height: 2, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(1))),
                      const SizedBox(width: 2),
                      Container(width: 4, height: 2, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(1))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SKS Family',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Tableau de bord',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Bouton sync interactif
        TvFocusWrapper(
          onTap: () => provider.reconnectFirestore(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Icon(
                  provider.isSyncEnabled
                      ? Icons.sync
                      : Icons.sync_disabled,
                  color: provider.isSyncEnabled
                      ? Colors.cyanAccent
                      : Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  CLASSEMENT PODIUM — avec photo de profil
  // ══════════════════════════════════════════
  Widget _buildPodium(List<ChildModel> children, FamilyProvider provider) {
    if (children.isEmpty) return const SizedBox.shrink();

    final first = children[0];
    final second = children.length > 1 ? children[1] : null;
    final third = children.length > 2 ? children[2] : null;
    final rest = children.length > 3 ? children.sublist(3) : <ChildModel>[];

    return Column(
      children: [
        // 1er place
        TvFocusWrapper(
          autofocus: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChildDashboardScreen(childId: first.id)),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD740).withOpacity(0.12),
                  const Color(0xFFFFAB00).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFFFFD740).withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD740).withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              children: [
                _buildRankAvatar(first, 1, 44),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        first.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Niveau ${first.currentLevelNumber}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      // Samedi + Dimanche
                      Row(
                        children: [
                          Icon(Icons.tv, color: Colors.purpleAccent.withOpacity(0.7), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Sam ${_formatMinutes(provider.getSaturdayMinutes(first.id))}',
                            style: TextStyle(color: Colors.purpleAccent.withOpacity(0.8), fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dim ${_formatMinutes(provider.getSundayMinutes(first.id))}',
                            style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${first.points} pts',
                      style: const TextStyle(
                        color: Color(0xFFFFD740),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text('🥇',
                        style: TextStyle(fontSize: 20)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 2ème et 3ème
        if (second != null)
          Row(
            children: [
              Expanded(
                child: _buildPodiumCard(second, 2, provider),
              ),
              if (third != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPodiumCard(third, 3, provider),
                ),
              ],
            ],
          ),
        if (second != null) const SizedBox(height: 10),

        // 4ème+
        ...rest.asMap().entries.map((entry) {
          final rank = entry.key + 4;
          final child = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildListRankCard(child, rank, provider),
          );
        }),
      ],
    );
  }

  Widget _buildPodiumCard(
      ChildModel child, int rank, FamilyProvider provider) {
    final Color rankColor =
        rank == 2 ? const Color(0xFFB0BEC5) : const Color(0xFFFF8A65);
    final String medal = rank == 2 ? '🥈' : '🥉';

    return TvFocusWrapper(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChildDashboardScreen(childId: child.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: rankColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: rankColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            _buildRankAvatar(child, rank, 36),
            const SizedBox(height: 10),
            Text(
              child.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              'Niveau ${child.currentLevelNumber}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
            const SizedBox(height: 4),
            // Samedi + Dimanche
            Text(
              'Sam ${_formatMinutes(provider.getSaturdayMinutes(child.id))}',
              style: TextStyle(color: Colors.purpleAccent.withOpacity(0.7), fontSize: 10),
            ),
            Text(
              'Dim ${_formatMinutes(provider.getSundayMinutes(child.id))}',
              style: TextStyle(color: Colors.blueAccent.withOpacity(0.7), fontSize: 10),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${child.points} pts',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Text(medal, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListRankCard(
      ChildModel child, int rank, FamilyProvider provider) {
    return TvFocusWrapper(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChildDashboardScreen(childId: child.id)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildChildAvatar(child, 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text('Niveau ${child.currentLevelNumber}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${child.points} pts',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Sam ${_formatMinutes(provider.getSaturdayMinutes(child.id))} • Dim ${_formatMinutes(provider.getSundayMinutes(child.id))}',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankAvatar(ChildModel child, int rank, double radius) {
    final Color rankColor;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD740);
        break;
      case 2:
        rankColor = const Color(0xFFB0BEC5);
        break;
      case 3:
        rankColor = const Color(0xFFFF8A65);
        break;
      default:
        rankColor = Colors.white38;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: rankColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: _buildChildAvatar(child, radius),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [rankColor, rankColor.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF0A0E21), width: 2),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildAvatar(ChildModel child, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.cyanAccent.withOpacity(0.2),
      backgroundImage: child.hasPhoto
          ? MemoryImage(base64Decode(child.photoBase64))
          : null,
      child: !child.hasPhoto
          ? Text(
              child.avatar.isNotEmpty
                  ? child.avatar
                  : (child.name.isNotEmpty
                      ? child.name[0].toUpperCase()
                      : '?'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }

  // ══════════════════════════════════════════
  //  QUICK ACTIONS GRID 3x2
  // ══════════════════════════════════════════
  Widget _buildQuickActionsGrid(
      BuildContext context, FamilyProvider provider) {
    final actions = [
      _QuickAction('Punition', 'Gérer les sanctions', Icons.edit_note_rounded,
          Colors.redAccent, const Color(0xFFFF1744),
          () => PinGuard.guardNavigation(context, const PunishmentLinesScreen())),
      _QuickAction('Immunité', 'Protégez-vous', Icons.shield_rounded,
          const Color(0xFF00E676), const Color(0xFF00E676),
          () => PinGuard.guardNavigation(context, const ImmunityLinesScreen())),
      _QuickAction('Écran', 'Temps de session', Icons.tv_rounded,
          Colors.purpleAccent, Colors.purpleAccent,
          () => PinGuard.guardNavigation(context, const ScreenTimeScreen())),
      _QuickAction('Notes', 'Suivi académique', Icons.school_rounded,
          Colors.orangeAccent, Colors.orangeAccent,
          () => _showSchoolNotesChildPicker(provider)),
      _QuickAction('Enfant', 'Vigilance active', Icons.child_care_rounded,
          Colors.amber, Colors.amber,
          () => PinGuard.guardNavigation(context, const ManageChildrenScreen())),
      _QuickAction('Badges', 'Collectionnez', Icons.emoji_events_rounded,
          const Color(0xFFFFD740), const Color(0xFFFFAB00),
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const BadgesScreen()))),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionTile(actions[0])),
            const SizedBox(width: 10),
            Expanded(child: _buildActionTile(actions[1])),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildActionTile(actions[2])),
            const SizedBox(width: 10),
            Expanded(child: _buildActionTile(actions[3])),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildActionTile(actions[4])),
            const SizedBox(width: 10),
            Expanded(child: _buildActionTile(actions[5])),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile(_QuickAction action) {
    return TvFocusWrapper(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              action.color.withOpacity(0.12),
              action.color.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: action.borderColor.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(action.icon, color: action.color, size: 30),
            const SizedBox(height: 10),
            Text(
              action.label,
              style: TextStyle(
                color: action.color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              action.subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  TRADE CARD
  // ══════════════════════════════════════════
  Widget _buildTradeCard(dynamic trade, FamilyProvider provider) {
    final fromChild = provider.getChild(trade.fromChildId);
    final toChild = provider.getChild(trade.toChildId);
    final fromName = fromChild?.name ?? '?';
    final toName = toChild?.name ?? '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TvFocusWrapper(
        onTap: () => _showTradeDetail(trade, provider),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.orangeAccent.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (fromChild != null)
                    _buildChildAvatar(fromChild, 18)
                  else
                    const Icon(Icons.person, color: Colors.white38, size: 20),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${fromName.toUpperCase()} → ${toName.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFF00E676).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded,
                            color: Color(0xFF00E676), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TvFocusWrapper(
                      onTap: () => provider.cancelTrade(trade.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.3)),
                        ),
                        child: const Center(
                          child: Text(
                            '✕ Annuler',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TvFocusWrapper(
                      onTap: () {
                        if (trade.isPending) {
                          provider.acceptTrade(trade.id);
                        } else if (trade.isAccepted) {
                          provider.markServiceDone(trade.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white12),
                        ),
                        child: Center(
                          child: Text(
                            trade.isPending
                                ? '⏳ En attente'
                                : trade.isAccepted
                                    ? '✓ Service rendu'
                                    : trade.statusLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  DIALOGS
  // ══════════════════════════════════════════
  void _showTradeDetail(dynamic trade, FamilyProvider provider) {
    final fromChild = provider.getChild(trade.fromChildId);
    final toChild = provider.getChild(trade.toChildId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(
              '${trade.statusEmoji} ${trade.serviceDescription}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _infoRow('De', fromChild?.name ?? '?'),
            _infoRow('Pour', toChild?.name ?? '?'),
            _infoRow('Lignes', '${trade.immunityLines}'),
            _infoRow('Statut', trade.statusLabel),
            const SizedBox(height: 20),
            TvFocusWrapper(
              onTap: () => Navigator.pop(ctx),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Fermer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showSchoolNotesChildPicker(FamilyProvider provider) {
    final children = provider.children;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucun enfant enregistré'),
          backgroundColor: Colors.orangeAccent));
      return;
    }
    if (children.length == 1) {
      PinGuard.guardNavigation(
          context, SchoolNotesScreen(childId: children.first.id));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900]?.withOpacity(0.95),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Notes scolaires',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: children.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final child = children[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TvFocusWrapper(
                        autofocus: index == 0,
                        onTap: () {
                          Navigator.pop(context);
                          PinGuard.guardNavigation(this.context,
                              SchoolNotesScreen(childId: child.id));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              _buildChildAvatar(child, 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(child.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white38),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullHistory(FamilyProvider provider) {
    final allHistory = provider.history;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[900]?.withOpacity(0.95),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Historique complet',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: allHistory.isEmpty
                    ? const Center(
                        child: Text('Aucune activité',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: allHistory.length,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final h = allHistory[index];
                          final child = provider.getChild(h.childId);
                          final childName = child?.name ?? 'Inconnu';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  h.isBonus
                                      ? Icons.add_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: h.isBonus
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(h.reason,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis),
                                      Text(
                                        '$childName • ${h.date.day.toString().padLeft(2, '0')}/${h.date.month.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${h.isBonus ? '+' : '-'}${h.points}',
                                  style: TextStyle(
                                    color: h.isBonus
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color borderColor;
  final VoidCallback onTap;
  _QuickAction(this.label, this.subtitle, this.icon, this.color,
      this.borderColor, this.onTap);
}
