import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/tribunal_model.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class TribunalScreen extends StatefulWidget {
  const TribunalScreen({super.key});
  @override
  State<TribunalScreen> createState() => _TribunalScreenState();
}

class _TribunalScreenState extends State<TribunalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _courtBrown = Color(0xFF5D4037);
  static const _courtGold = Color(0xFFFFD740);
  static const _courtRed = Color(0xFFFF1744);
  static const _courtGreen = Color(0xFF00E676);
  static const _courtBlue = Color(0xFF448AFF);
  static const _courtPurple = Color(0xFF7C4DFF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u{2696}', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Tribunal Familial', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _courtRed.withValues(alpha: 0.3), blurRadius: 16)],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'file_complaint',
          backgroundColor: _courtRed,
          onPressed: () => PinGuard.guardAction(context, () => _showFileComplaint(context)),
          icon: const Icon(Icons.gavel_rounded),
          label: const Text('Deposer une plainte', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      body: Consumer<FamilyProvider>(
        builder: (context, provider, _) {
          return AnimatedBackground(
            child: Column(
              children: [
                _buildTribunalStats(provider),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: _courtBrown.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    dividerHeight: 0,
                    tabs: [
                      Tab(
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('\u{1F4CB}', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text('En cours (${provider.activeTribunalCases.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      Tab(
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('\u{1F4C1}', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text('Archives (${provider.closedTribunalCases.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveCases(provider),
                      _buildClosedCases(provider),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════
  //  STATS
  // ══════════════════════════════════════
  Widget _buildTribunalStats(FamilyProvider provider) {
    final total = provider.tribunalCases.length;
    final active = provider.activeTribunalCases.length;
    final verdicts = provider.closedTribunalCases.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _statCard('\u{2696}', '$total', 'Total', _courtGold),
          const SizedBox(width: 8),
          _statCard('\u{1F525}', '$active', 'En cours', _courtRed),
          const SizedBox(width: 8),
          _statCard('\u{1F528}', '$verdicts', 'Juges', _courtGreen),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        borderRadius: 14,
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  LISTES
  // ══════════════════════════════════════
  Widget _buildActiveCases(FamilyProvider provider) {
    final cases = provider.activeTribunalCases;
    if (cases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('\u{2696}', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Aucune affaire en cours', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            Text('La paix regne dans la famille !', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: cases.length,
      itemBuilder: (context, index) => _buildCaseCard(cases[index], provider),
    );
  }

  Widget _buildClosedCases(FamilyProvider provider) {
    final cases = provider.closedTribunalCases;
    if (cases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('\u{1F4C1}', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('Aucune archive', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: cases.length,
      itemBuilder: (context, index) => _buildCaseCard(cases[index], provider),
    );
  }

  // ══════════════════════════════════════
  //  CARTE AFFAIRE
  // ══════════════════════════════════════
  Widget _buildCaseCard(TribunalCase tc, FamilyProvider provider) {
    final plaintiff = provider.getChild(tc.plaintiffId);
    final accused = provider.getChild(tc.accusedId);

    return GestureDetector(
      onTap: () => _showCaseDetail(context, tc, provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _courtBrown.withValues(alpha: 0.15),
              tc.statusColor.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: tc.statusColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(tc.statusEmoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tc.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tc.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tc.statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(tc.statusLabel, style: TextStyle(color: tc.statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // VS
              Row(
                children: [
                  Expanded(child: _buildPartyChip(plaintiff, 'Plaignant', _courtBlue)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _courtRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _courtRed.withValues(alpha: 0.3)),
                      ),
                      child: const Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                  Expanded(child: _buildPartyChip(accused, 'Accuse', _courtRed)),
                ],
              ),
              const SizedBox(height: 10),
              Text(tc.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              // Votes mini-résumé
              if (tc.totalVotes > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _courtPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _courtPurple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('\u{1F5F3}', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('${tc.totalVotes} vote${tc.totalVotes > 1 ? 's' : ''}', style: TextStyle(color: _courtPurple, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Text('\u{274C} ${tc.guiltyVotes}', style: TextStyle(color: _courtRed, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text('\u{2705} ${tc.innocentVotes}', style: TextStyle(color: _courtGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Footer
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Text(_formatDate(tc.filedDate), style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                  if (tc.scheduledDate != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.access_time_rounded, size: 12, color: _courtGold.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text('Audience: ${_formatDateTime(tc.scheduledDate!)}', style: TextStyle(color: _courtGold.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                  const Spacer(),
                  if (tc.participants.length > 2)
                    Row(children: [
                      Icon(Icons.people_rounded, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text('${tc.participants.length}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                    ]),
                ],
              ),
              // Verdict
              if (tc.verdict != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tc.verdict == TribunalVerdict.guilty
                        ? _courtRed.withValues(alpha: 0.1)
                        : tc.verdict == TribunalVerdict.innocent
                            ? _courtGreen.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(tc.verdictEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Verdict: ${tc.verdictLabel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            if (tc.verdictReason != null)
                              Text(tc.verdictReason!, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartyChip(ChildModel? child, String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (child != null && child.hasPhoto)
            ClipOval(child: Image.memory(base64Decode(child.photoBase64), width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarText(child)))
          else
            _avatarText(child),
          const SizedBox(height: 4),
          Text(child?.name ?? 'Inconnu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(role, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _avatarText(ChildModel? child) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)),
      child: Center(child: Text(child?.avatar.isNotEmpty == true ? child!.avatar : '\u{1F464}', style: const TextStyle(fontSize: 18))),
    );
  }

  // ══════════════════════════════════════
  //  DETAIL AFFAIRE
  // ══════════════════════════════════════
  void _showCaseDetail(BuildContext context, TribunalCase tc, FamilyProvider provider) {
    final plaintiff = provider.getChild(tc.plaintiffId);
    final accused = provider.getChild(tc.accusedId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Center(child: Text('\u{2696}', style: const TextStyle(fontSize: 40))),
              const SizedBox(height: 8),
              Center(child: Text(tc.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: tc.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tc.statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text('${tc.statusEmoji} ${tc.statusLabel}', style: TextStyle(color: tc.statusColor, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
              // Parties
              Row(
                children: [
                  Expanded(child: _buildDetailParty(plaintiff, 'Plaignant', _courtBlue, tc.plaintiffPoints)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900, fontSize: 20))),
                  Expanded(child: _buildDetailParty(accused, 'Accuse', _courtRed, tc.accusedPoints)),
                ],
              ),
              const SizedBox(height: 16),
              // Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Motif de la plainte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(tc.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ═══ SECTION VOTES ═══
              _buildVoteSection(ctx, tc, provider, setModalState),

              // Avocats
              if (tc.prosecutionLawyer != null || tc.defenseLawyer != null) ...[
                const Text('\u{1F4BC} Avocats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (tc.prosecutionLawyer != null) _buildParticipantTile(tc.prosecutionLawyer!, provider, "Avocat de l'accusation", _courtBlue),
                if (tc.defenseLawyer != null) _buildParticipantTile(tc.defenseLawyer!, provider, 'Avocat de la defense', _courtPurple),
                const SizedBox(height: 16),
              ],
              // Temoins
              if (tc.witnesses.isNotEmpty) ...[
                const Text('\u{1F9D1}\u{200D}\u{2696} Temoins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ...tc.witnesses.map((w) => _buildParticipantTile(w, provider, 'Temoin', Colors.amber)),
                const SizedBox(height: 16),
              ],
              // Dates
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    _dateRow(Icons.description_rounded, 'Plainte deposee', _formatDateTime(tc.filedDate), Colors.white54),
                    if (tc.scheduledDate != null) _dateRow(Icons.event_rounded, 'Audience prevue', _formatDateTime(tc.scheduledDate!), _courtGold),
                    if (tc.verdictDate != null) _dateRow(Icons.gavel_rounded, 'Verdict rendu', _formatDateTime(tc.verdictDate!), _courtGreen),
                  ],
                ),
              ),
              // Verdict
              if (tc.verdict != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [
                      tc.verdict == TribunalVerdict.guilty ? _courtRed.withValues(alpha: 0.15) : tc.verdict == TribunalVerdict.innocent ? _courtGreen.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                      Colors.transparent,
                    ]),
                    border: Border.all(color: tc.verdict == TribunalVerdict.guilty ? _courtRed.withValues(alpha: 0.3) : tc.verdict == TribunalVerdict.innocent ? _courtGreen.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(tc.verdictEmoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text('VERDICT: ${tc.verdictLabel.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      if (tc.verdictReason != null) ...[
                        const SizedBox(height: 8),
                        Text(tc.verdictReason!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13), textAlign: TextAlign.center),
                      ],
                      // Résultat des votes après verdict
                      if (tc.votes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _courtPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Text('\u{1F5F3} Resultats des votes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 6),
                              ...tc.votes.map((v) {
                                final vChild = provider.getChild(v.childId);
                                final wasRight = v.vote == tc.verdict;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Text(vChild?.avatar ?? '\u{1F464}', style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(vChild?.name ?? '?', style: const TextStyle(color: Colors.white, fontSize: 12))),
                                      Text(v.vote == TribunalVerdict.guilty ? '\u{274C} Coupable' : '\u{2705} Innocent',
                                          style: TextStyle(color: v.vote == TribunalVerdict.guilty ? _courtRed : _courtGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (wasRight ? _courtGreen : _courtRed).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          wasRight ? '+1' : '-1',
                                          style: TextStyle(color: wasRight ? _courtGreen : _courtRed, fontWeight: FontWeight.w900, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // Actions
              if (!tc.isClosed) ...[
                const SizedBox(height: 20),
                _buildActionButtons(ctx, tc, provider),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  SECTION VOTES
  // ══════════════════════════════════════
  Widget _buildVoteSection(BuildContext ctx, TribunalCase tc, FamilyProvider provider, StateSetter setModalState) {
    final canVoteNow = tc.status == TribunalStatus.inProgress || tc.status == TribunalStatus.deliberation;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _courtPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _courtPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F5F3}', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text('Votes du jury', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _courtPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${tc.totalVotes} vote${tc.totalVotes > 1 ? 's' : ''}', style: TextStyle(color: _courtPurple, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barre de votes
          if (tc.totalVotes > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    if (tc.guiltyVotes > 0)
                      Expanded(
                        flex: tc.guiltyVotes,
                        child: Container(
                          color: _courtRed.withValues(alpha: 0.6),
                          child: Center(child: Text('\u{274C} ${tc.guiltyVotes}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    if (tc.innocentVotes > 0)
                      Expanded(
                        flex: tc.innocentVotes,
                        child: Container(
                          color: _courtGreen.withValues(alpha: 0.6),
                          child: Center(child: Text('\u{2705} ${tc.innocentVotes}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Liste des votants
            ...tc.votes.map((v) {
              final vChild = provider.getChild(v.childId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(vChild?.avatar ?? '\u{1F464}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(vChild?.name ?? '?', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (v.vote == TribunalVerdict.guilty ? _courtRed : _courtGreen).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: (v.vote == TribunalVerdict.guilty ? _courtRed : _courtGreen).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        v.vote == TribunalVerdict.guilty ? '\u{274C} Coupable' : '\u{2705} Innocent',
                        style: TextStyle(color: v.vote == TribunalVerdict.guilty ? _courtRed : _courtGreen, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(canVoteNow ? 'Aucun vote pour le moment' : 'Les votes sont ouverts pendant l\'audience', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
            ),
          // Boutons de vote
          if (canVoteNow) ...[
            const Divider(color: Colors.white12),
            const SizedBox(height: 6),
            Text('Choisir un enfant pour voter :', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...provider.children
                .where((c) => tc.canVote(c.id))
                .map((child) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Text(child.avatar.isNotEmpty ? child.avatar : '\u{1F466}', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(child.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                          _voteButton('\u{274C} Coupable', _courtRed, () async {
                            await provider.castTribunalVote(tc.id, child.id, TribunalVerdict.guilty);
                            setModalState(() {});
                            if (mounted) setState(() {});
                          }),
                          const SizedBox(width: 6),
                          _voteButton('\u{2705} Innocent', _courtGreen, () async {
                            await provider.castTribunalVote(tc.id, child.id, TribunalVerdict.innocent);
                            setModalState(() {});
                            if (mounted) setState(() {});
                          }),
                        ],
                      ),
                    )),
            if (provider.children.where((c) => tc.canVote(c.id)).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Tous les enfants eligibles ont vote \u{2705}', style: TextStyle(color: _courtGreen.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _voteButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ══════════════════════════════════════
  //  HELPERS DETAIL
  // ══════════════════════════════════════
  Widget _buildDetailParty(ChildModel? child, String role, Color color, int points) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (child != null && child.hasPhoto)
            ClipOval(child: Image.memory(base64Decode(child.photoBase64), width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _bigAvatar(child)))
          else
            _bigAvatar(child),
          const SizedBox(height: 8),
          Text(child?.name ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(role, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          if (points != 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: (points > 0 ? _courtGreen : _courtRed).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('${points > 0 ? '+' : ''}$points pts', style: TextStyle(color: points > 0 ? _courtGreen : _courtRed, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigAvatar(ChildModel? child) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)),
      child: Center(child: Text(child?.avatar.isNotEmpty == true ? child!.avatar : '\u{1F464}', style: const TextStyle(fontSize: 26))),
    );
  }

  Widget _buildParticipantTile(TribunalParticipant participant, FamilyProvider provider, String roleLabel, Color color) {
    final child = provider.getChild(participant.childId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
            child: Center(child: Text(child?.avatar ?? '\u{1F464}', style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child?.name ?? 'Inconnu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(roleLabel, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
                if (participant.testimony != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('"${participant.testimony}"', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
          if (participant.testimonyVerified != null)
            Icon(participant.testimonyVerified! ? Icons.check_circle : Icons.cancel, color: participant.testimonyVerified! ? _courtGreen : _courtRed, size: 20),
          if (participant.pointsAwarded != 0) ...[
            const SizedBox(width: 8),
            Text('${participant.pointsAwarded > 0 ? '+' : ''}${participant.pointsAwarded}', style: TextStyle(color: participant.pointsAwarded > 0 ? _courtGreen : _courtRed, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _dateRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════
  Widget _buildActionButtons(BuildContext ctx, TribunalCase tc, FamilyProvider provider) {
    return Column(
      children: [
        if (tc.status == TribunalStatus.filed)
          _actionButton('\u{1F4C5} Programmer l\'audience', _courtBlue, () {
            Navigator.pop(ctx);
            _showScheduleHearing(context, tc, provider);
          }),
        if (tc.status == TribunalStatus.scheduled)
          _actionButton('\u{2696} Ouvrir l\'audience', _courtPurple, () async {
            await provider.startTribunalHearing(tc.id);
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        if (tc.status == TribunalStatus.inProgress)
          _actionButton('\u{1F914} Passer en deliberation', _courtGold, () async {
            await provider.startTribunalDeliberation(tc.id);
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        if (tc.status == TribunalStatus.inProgress || tc.status == TribunalStatus.deliberation)
          _actionButton('\u{1F528} Rendre le verdict', _courtGreen, () {
            Navigator.pop(ctx);
            _showRenderVerdict(context, tc, provider);
          }),
        const SizedBox(height: 8),
        _actionButton('\u{1F5C4} Classer sans suite', Colors.grey, () async {
          await provider.dismissTribunalCase(tc.id);
          if (ctx.mounted) Navigator.pop(ctx);
        }),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withValues(alpha: 0.3))),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  DEPOSER PLAINTE
  // ══════════════════════════════════════
  void _showFileComplaint(BuildContext context) {
    final provider = context.read<FamilyProvider>();
    if (provider.children.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Il faut au moins 2 enfants pour deposer une plainte'), backgroundColor: _courtRed, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? plaintiffId;
    String? accusedId;
    String? prosecutionLawyerId;
    String? defenseLawyerId;
    List<String> witnessIds = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final availableForLawyers = provider.children.where((c) => c.id != plaintiffId && c.id != accusedId).toList();
          final availableForWitnesses = provider.children.where((c) => c.id != plaintiffId && c.id != accusedId && c.id != prosecutionLawyerId && c.id != defenseLawyerId).toList();

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Row(children: [Text('\u{2696}', style: TextStyle(fontSize: 24)), SizedBox(width: 10), Text('Deposer une plainte', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))]),
                  const SizedBox(height: 20),
                  TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Titre de la plainte', hintText: 'Ex: Vol de jouet, Bagarre...', hintStyle: TextStyle(color: Colors.grey[700]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 14),
                  TextField(controller: descCtrl, style: const TextStyle(color: Colors.white), maxLines: 3, decoration: InputDecoration(labelText: 'Description des faits', hintText: 'Racontez ce qui s\'est passe...', hintStyle: TextStyle(color: Colors.grey[700]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 14),
                  _childDropdown('Plaignant (qui porte plainte)', plaintiffId, provider.children, _courtBlue, (v) {
                    setState(() { plaintiffId = v; if (prosecutionLawyerId == v) prosecutionLawyerId = null; if (defenseLawyerId == v) defenseLawyerId = null; witnessIds.remove(v); });
                  }),
                  const SizedBox(height: 14),
                  _childDropdown('Accuse', accusedId, provider.children.where((c) => c.id != plaintiffId).toList(), _courtRed, (v) {
                    setState(() { accusedId = v; if (prosecutionLawyerId == v) prosecutionLawyerId = null; if (defenseLawyerId == v) defenseLawyerId = null; witnessIds.remove(v); });
                  }),
                  if (availableForLawyers.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _childDropdown("Avocat de l'accusation (optionnel)", prosecutionLawyerId, availableForLawyers, _courtBlue, (v) { setState(() { prosecutionLawyerId = v; witnessIds.remove(v); }); }, optional: true),
                    const SizedBox(height: 14),
                    _childDropdown('Avocat de la defense (optionnel)', defenseLawyerId, availableForLawyers.where((c) => c.id != prosecutionLawyerId).toList(), _courtPurple, (v) { setState(() { defenseLawyerId = v; witnessIds.remove(v); }); }, optional: true),
                  ],
                  if (availableForWitnesses.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Temoins (optionnel)', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: availableForWitnesses.map((c) {
                        final isSelected = witnessIds.contains(c.id);
                        return FilterChip(selected: isSelected, label: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}'), selectedColor: Colors.amber.withValues(alpha: 0.2), checkmarkColor: Colors.amber, onSelected: (v) { setState(() { if (v) { witnessIds.add(c.id); } else { witnessIds.remove(c.id); } }); });
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _courtRed),
                      onPressed: (titleCtrl.text.trim().isNotEmpty && descCtrl.text.trim().isNotEmpty && plaintiffId != null && accusedId != null)
                          ? () async {
                              await provider.fileTribunalCase(title: titleCtrl.text.trim(), description: descCtrl.text.trim(), plaintiffId: plaintiffId!, accusedId: accusedId!, prosecutionLawyerId: prosecutionLawyerId, defenseLawyerId: defenseLawyerId, witnessIds: witnessIds.isNotEmpty ? witnessIds : null);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Text('\u{2696}', style: TextStyle(fontSize: 18)), SizedBox(width: 8), Text('Plainte deposee !')]), backgroundColor: _courtRed, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                            }
                          : null,
                      icon: const Icon(Icons.gavel_rounded),
                      label: const Text('Deposer la plainte', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _childDropdown(String label, String? value, List<ChildModel> children, Color color, ValueChanged<String?> onChanged, {bool optional = false}) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF162033),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: color.withValues(alpha: 0.7)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withValues(alpha: 0.3)))),
      items: [
        if (optional) const DropdownMenuItem(value: null, child: Text('Aucun', style: TextStyle(color: Colors.grey))),
        ...children.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.avatar.isEmpty ? "\u{1F466}" : c.avatar} ${c.name}'))),
      ],
      onChanged: onChanged,
    );
  }

  // ══════════════════════════════════════
  //  PROGRAMMER AUDIENCE
  // ══════════════════════════════════════
  void _showScheduleHearing(BuildContext context, TribunalCase tc, FamilyProvider provider) async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (time == null || !mounted) return;
    final scheduledDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await provider.scheduleTribunalHearing(tc.id, scheduledDate);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Text('\u{1F4C5}', style: TextStyle(fontSize: 18)), const SizedBox(width: 8), Text('Audience prevue le ${_formatDateTime(scheduledDate)}')]), backgroundColor: _courtBlue, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  // ══════════════════════════════════════
  //  RENDRE VERDICT
  // ══════════════════════════════════════
  void _showRenderVerdict(BuildContext context, TribunalCase tc, FamilyProvider provider) {
    TribunalVerdict selectedVerdict = TribunalVerdict.guilty;
    final reasonCtrl = TextEditingController();
    int plaintiffPts = 0;
    int accusedPts = 0;
    Map<String, int> lawyerPts = {};
    Map<String, bool> witnessVerified = {};
    Map<String, int> witnessPts = {};

    for (final w in tc.witnesses) { witnessVerified[w.childId] = true; witnessPts[w.childId] = 2; }
    if (tc.prosecutionLawyer != null) lawyerPts[tc.prosecutionLawyer!.childId] = 0;
    if (tc.defenseLawyer != null) lawyerPts[tc.defenseLawyer!.childId] = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          if (selectedVerdict == TribunalVerdict.guilty) {
            plaintiffPts = 5; accusedPts = -5;
            if (tc.prosecutionLawyer != null) lawyerPts[tc.prosecutionLawyer!.childId] = 3;
            if (tc.defenseLawyer != null) lawyerPts[tc.defenseLawyer!.childId] = -2;
          } else if (selectedVerdict == TribunalVerdict.innocent) {
            plaintiffPts = -3; accusedPts = 5;
            if (tc.prosecutionLawyer != null) lawyerPts[tc.prosecutionLawyer!.childId] = -2;
            if (tc.defenseLawyer != null) lawyerPts[tc.defenseLawyer!.childId] = 3;
          } else {
            plaintiffPts = 0; accusedPts = 0;
            if (tc.prosecutionLawyer != null) lawyerPts[tc.prosecutionLawyer!.childId] = 0;
            if (tc.defenseLawyer != null) lawyerPts[tc.defenseLawyer!.childId] = 0;
          }
          for (final w in tc.witnesses) {
            final verified = witnessVerified[w.childId] ?? true;
            witnessPts[w.childId] = verified ? 2 : -3;
          }

          final plaintiff = provider.getChild(tc.plaintiffId);
          final accused = provider.getChild(tc.accusedId);

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Center(child: Text('\u{1F528}', style: TextStyle(fontSize: 36))),
                  const SizedBox(height: 8),
                  const Center(child: Text('Rendre le verdict', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 20),
                  const Text('Verdict', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _verdictChip('Coupable', '\u{274C}', TribunalVerdict.guilty, selectedVerdict, _courtRed, () => setState(() => selectedVerdict = TribunalVerdict.guilty)),
                    const SizedBox(width: 8),
                    _verdictChip('Innocent', '\u{2705}', TribunalVerdict.innocent, selectedVerdict, _courtGreen, () => setState(() => selectedVerdict = TribunalVerdict.innocent)),
                    const SizedBox(width: 8),
                    _verdictChip('Classe', '\u{1F5C4}', TribunalVerdict.dismissed, selectedVerdict, Colors.grey, () => setState(() => selectedVerdict = TribunalVerdict.dismissed)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(controller: reasonCtrl, style: const TextStyle(color: Colors.white), maxLines: 2, decoration: InputDecoration(labelText: 'Explication du verdict', hintText: 'Pourquoi cette decision...', hintStyle: TextStyle(color: Colors.grey[700]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  // Votes preview
                  if (tc.votes.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _courtPurple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: _courtPurple.withValues(alpha: 0.2))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('\u{1F5F3} ${tc.totalVotes} vote${tc.totalVotes > 1 ? 's' : ''} - Impact apres verdict :', style: TextStyle(color: _courtPurple, fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          ...tc.votes.map((v) {
                            final vChild = provider.getChild(v.childId);
                            final willWin = v.vote == selectedVerdict;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Text(vChild?.name ?? '?', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                const Spacer(),
                                Text(v.vote == TribunalVerdict.guilty ? '\u{274C}' : '\u{2705}', style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 6),
                                Text(willWin ? '+1 pt' : '-1 pt', style: TextStyle(color: willWin ? _courtGreen : _courtRed, fontWeight: FontWeight.w800, fontSize: 12)),
                              ]),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Points attribues', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _pointsPreview(plaintiff?.name ?? 'Plaignant', plaintiffPts),
                  _pointsPreview(accused?.name ?? 'Accuse', accusedPts),
                  if (tc.prosecutionLawyer != null)
                    _pointsPreview('Avocat accusation (${provider.getChild(tc.prosecutionLawyer!.childId)?.name ?? "?"})', lawyerPts[tc.prosecutionLawyer!.childId] ?? 0),
                  if (tc.defenseLawyer != null)
                    _pointsPreview('Avocat defense (${provider.getChild(tc.defenseLawyer!.childId)?.name ?? "?"})', lawyerPts[tc.defenseLawyer!.childId] ?? 0),
                  if (tc.witnesses.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Temoignages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...tc.witnesses.map((w) {
                      final wChild = provider.getChild(w.childId);
                      final verified = witnessVerified[w.childId] ?? true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: (verified ? _courtGreen : _courtRed).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: (verified ? _courtGreen : _courtRed).withValues(alpha: 0.2))),
                        child: Row(children: [
                          Text(wChild?.name ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          ChoiceChip(label: const Text('Veridique'), selected: verified, selectedColor: _courtGreen.withValues(alpha: 0.2), onSelected: (_) => setState(() => witnessVerified[w.childId] = true)),
                          const SizedBox(width: 6),
                          ChoiceChip(label: const Text('Faux'), selected: !verified, selectedColor: _courtRed.withValues(alpha: 0.2), onSelected: (_) => setState(() => witnessVerified[w.childId] = false)),
                        ]),
                      );
                    }),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _courtGold),
                      onPressed: () async {
                        await provider.renderVerdict(
                          caseId: tc.id,
                          verdict: selectedVerdict,
                          reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : selectedVerdict == TribunalVerdict.guilty ? 'Reconnu coupable' : selectedVerdict == TribunalVerdict.innocent ? 'Declare innocent' : 'Classe sans suite',
                          plaintiffPoints: plaintiffPts,
                          accusedPoints: accusedPts,
                          lawyerPoints: lawyerPts.isNotEmpty ? lawyerPts : null,
                          witnessVerified: witnessVerified.isNotEmpty ? witnessVerified : null,
                          witnessPoints: witnessPts.isNotEmpty ? witnessPts : null,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Row(children: [Text('\u{1F528}', style: TextStyle(fontSize: 18)), SizedBox(width: 8), Text('Verdict rendu !')]), backgroundColor: _courtGreen, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                      },
                      icon: const Icon(Icons.gavel_rounded),
                      label: const Text('Confirmer le verdict', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _verdictChip(String label, String emoji, TribunalVerdict verdict, TribunalVerdict selected, Color color, VoidCallback onTap) {
    final isSelected = verdict == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.white.withValues(alpha: 0.1), width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? color : Colors.white54, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pointsPreview(String name, int points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (points > 0 ? _courtGreen : points < 0 ? _courtRed : Colors.grey).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              points == 0 ? '0 pt' : '${points > 0 ? '+' : ''}$points pts',
              style: TextStyle(color: points > 0 ? _courtGreen : points < 0 ? _courtRed : Colors.grey, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  FORMAT HELPERS
  // ══════════════════════════════════════
  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _formatDateTime(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
