// lib/screens/trade_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../models/trade_model.dart';
import '../widgets/tv_focus_wrapper.dart';

// ═══════════════════════════════════════════════════════════
//  POIGNÉE DE MAIN ANIMÉE
// ═══════════════════════════════════════════════════════════
class _HandshakeAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final String message;
  const _HandshakeAnimation({required this.onComplete, required this.message});
  @override
  State<_HandshakeAnimation> createState() => _HandshakeAnimationState();
}

class _HandshakeAnimationState extends State<_HandshakeAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late Animation<double> _leftHand;
  late Animation<double> _shake;
  late Animation<double> _textFade;
  late AnimationController _sparkCtrl;
  final _rng = Random();
  late List<_SparkDot> _sparks;

  @override
  void initState() {
    super.initState();
    _mainCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward().then((_) {
        if (mounted) widget.onComplete();
      });
    _leftHand = Tween<double>(begin: -120.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _mainCtrl,
            curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic)));
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 8.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 8.0, end: -6.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: -6.0, end: 5.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 5.0, end: -3.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: -3.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.35, 0.7, curve: Curves.easeInOut)));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _mainCtrl,
            curve: const Interval(0.5, 0.75, curve: Curves.easeIn)));
    _sparkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _sparks = List.generate(
        16,
        (i) => _SparkDot(
              angle: (i / 16) * 2 * pi + _rng.nextDouble() * 0.4,
              speed: 40 + _rng.nextDouble() * 80,
              size: 2 + _rng.nextDouble() * 3,
              color: [
                Colors.amber,
                Colors.greenAccent,
                Colors.cyanAccent,
                Colors.white
              ][_rng.nextInt(4)],
            ));
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _sparkCtrl.forward();
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainCtrl, _sparkCtrl]),
      builder: (context, _) {
        return Stack(alignment: Alignment.center, children: [
          Container(color: Colors.amber.withOpacity(0.04 * (1 - _mainCtrl.value))),
          if (_sparkCtrl.isAnimating || _sparkCtrl.isCompleted)
            CustomPaint(
                size: Size.infinite,
                painter: _SparkDotPainter(_sparks, _sparkCtrl.value)),
          Transform.translate(
            offset: Offset(0, _shake.value),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Transform.translate(
                offset: Offset(_leftHand.value, 0),
                child: const Text('🤝', style: TextStyle(fontSize: 72)),
              ),
            ]),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.3,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.message,
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [Shadow(color: Colors.orangeAccent, blurRadius: 15)])),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _SparkDot {
  final double angle, speed, size;
  final Color color;
  const _SparkDot({required this.angle, required this.speed, required this.size, required this.color});
}

class _SparkDotPainter extends CustomPainter {
  final List<_SparkDot> sparks;
  final double t;
  _SparkDotPainter(this.sparks, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (final s in sparks) {
      final dist = s.speed * t;
      final dx = cx + cos(s.angle) * dist;
      final dy = cy + sin(s.angle) * dist;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(dx, dy), s.size,
          Paint()
            ..color = s.color.withOpacity(opacity * 0.8)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.size));
    }
  }
  @override
  bool shouldRepaint(covariant _SparkDotPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  CONFETTIS CÉLÉBRATION
// ═══════════════════════════════════════════════════════════
class _TradeCelebration extends StatefulWidget {
  final VoidCallback onComplete;
  const _TradeCelebration({required this.onComplete});
  @override
  State<_TradeCelebration> createState() => _TradeCelebrationState();
}

class _TradeCelebrationState extends State<_TradeCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = Random();
  late List<_ConfettiRect> _confetti;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..forward().then((_) {
        if (mounted) widget.onComplete();
      });
    _confetti = List.generate(
        40,
        (i) => _ConfettiRect(
              x: _rng.nextDouble(),
              speed: 120 + _rng.nextDouble() * 250,
              size: 4 + _rng.nextDouble() * 7,
              color: [
                Colors.amber, Colors.greenAccent, Colors.cyanAccent,
                Colors.pinkAccent, Colors.purpleAccent, Colors.white
              ][_rng.nextInt(6)],
              rotSpeed: (_rng.nextDouble() - 0.5) * 10,
              wobble: _rng.nextDouble() * 2 * pi,
            ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size.infinite, painter: _ConfettiRectPainter(_confetti, t)),
          if (t > 0.15 && t < 0.85)
            ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                      parent: _ctrl,
                      curve: const Interval(0.15, 0.45, curve: Curves.elasticOut))),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🎉', style: TextStyle(fontSize: 52)),
                SizedBox(height: 8),
                Text('VENTE VALIDÉE !',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3)),
                SizedBox(height: 4),
                Text('Immunités transférées',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
            ),
        ]);
      },
    );
  }
}

class _ConfettiRect {
  final double x, speed, size, rotSpeed, wobble;
  final Color color;
  const _ConfettiRect({required this.x, required this.speed, required this.size,
      required this.color, required this.rotSpeed, required this.wobble});
}

class _ConfettiRectPainter extends CustomPainter {
  final List<_ConfettiRect> confetti;
  final double t;
  _ConfettiRectPainter(this.confetti, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final c in confetti) {
      final dx = c.x * size.width + sin(c.wobble + t * 6) * 25;
      final dy = -20 + c.speed * t;
      if (dy > size.height + 20) continue;
      final opacity = (1.0 - t * 0.5).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(c.rotSpeed * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: c.size, height: c.size * 0.5),
            const Radius.circular(1)),
        Paint()..color = c.color.withOpacity(opacity),
      );
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant _ConfettiRectPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
//  DIALOGUES D'ANIMATION
// ═══════════════════════════════════════════════════════════
Future<void> showHandshakeAnimation(BuildContext context, String message) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _HandshakeAnimation(
          message: message, onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

Future<void> showTradeCelebration(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (ctx, _, __) => Material(
      color: Colors.transparent,
      child: _TradeCelebration(onComplete: () => Navigator.of(ctx).pop()),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
//  TRADE SCREEN
// ═══════════════════════════════════════════════════════════
class TradeScreen extends StatefulWidget {
  final String childId;
  const TradeScreen({super.key, required this.childId});
  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;

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

  Future<void> _run(Future<void> Function() action) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final child = provider.getChild(widget.childId);
        if (child == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0a0a2a),
            body: const Center(
                child: Text('Enfant non trouvé',
                    style: TextStyle(color: Colors.white))),
          );
        }
        final availableImmunity = provider.getTotalAvailableImmunity(widget.childId);
        final allTrades = provider.getTradesForChild(widget.childId);
        final activeTrades = allTrades.where((t) => t.isActive).toList();
        final pendingForMe = provider.getPendingTradesForChild(widget.childId);
        final completedTrades = allTrades
            .where((t) => t.isCompleted || t.isRejected || t.isCancelled)
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0a0a2a),
          appBar: AppBar(
            title: Row(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, val, child) =>
                    Transform.scale(scale: val, child: child),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 8),
              const Text('Vente d\'immunités'),
            ]),
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Marché'),
                  if (pendingForMe.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildBadgeCount(pendingForMe.length)
                  ],
                ])),
                Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('En cours'),
                  if (activeTrades.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildBadgeCount(activeTrades.length)
                  ],
                ])),
                const Tab(text: 'Historique'),
              ],
            ),
          ),
          body: Column(children: [
            _buildImmunityBanner(child, availableImmunity),
            Expanded(
                child: TabBarView(controller: _tabController, children: [
              _buildMarketTab(provider, child, availableImmunity, pendingForMe),
              _buildActiveTab(provider, child, activeTrades),
              _buildHistoryTab(provider, child, completedTrades),
            ])),
          ]),
          floatingActionButton: availableImmunity > 0
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateSaleDialog(
                      context, provider, child, availableImmunity),
                  backgroundColor: const Color(0xFF00E676),
                  icon: const Icon(Icons.sell_rounded, color: Colors.black),
                  label: const Text('Vendre',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                )
              : null,
        );
      },
    );
  }

  Widget _buildImmunityBanner(ChildModel child, int available) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF00E676).withOpacity(0.12),
          const Color(0xFF00E676).withOpacity(0.04)
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(child.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          Text(
            available > 0
                ? '$available ligne${available > 1 ? 's' : ''} d\'immunité disponible${available > 1 ? 's' : ''}'
                : 'Aucune immunité à vendre',
            style: TextStyle(
                color: available > 0 ? const Color(0xFF00E676) : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ])),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: available.toDouble()),
          duration: const Duration(milliseconds: 800),
          builder: (context, val, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: available > 0
                    ? const Color(0xFF00E676).withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: available > 0
                        ? const Color(0xFF00E676).withOpacity(0.5)
                        : Colors.white.withOpacity(0.1))),
            child: Text('${val.round()}',
                style: TextStyle(
                    color: available > 0 ? const Color(0xFF00E676) : Colors.white38,
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
          ),
        ),
      ]),
    );
  }

  Widget _buildMarketTab(FamilyProvider provider, ChildModel child,
      int available, List<TradeModel> pendingForMe) {
    final myPendingSales = provider.trades
        .where((t) => t.isPending && t.fromChildId == widget.childId)
        .toList();
    if (pendingForMe.isEmpty && myPendingSales.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.storefront_rounded, size: 70, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 16),
        Text('Aucune offre en cours',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
        const SizedBox(height: 8),
        if (available > 0)
          Text('Appuyez sur "Vendre" pour proposer une vente',
              style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13)),
      ]));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (pendingForMe.isNotEmpty) ...[
        _buildSectionTitle('📩 Offres reçues', Colors.amber),
        const SizedBox(height: 8),
        ...pendingForMe.map((trade) =>
            _buildPendingOfferCard(provider, trade, isReceived: true)),
        const SizedBox(height: 20),
      ],
      if (myPendingSales.isNotEmpty) ...[
        _buildSectionTitle('📤 Mes ventes en attente', const Color(0xFF00E676)),
        const SizedBox(height: 8),
        ...myPendingSales.map((trade) =>
            _buildPendingOfferCard(provider, trade, isReceived: false)),
      ],
    ]);
  }

  Widget _buildPendingOfferCard(FamilyProvider provider, TradeModel trade,
      {required bool isReceived}) {
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
                : const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text(
                    otherChild?.avatar.isNotEmpty == true ? otherChild!.avatar : '👤',
                    style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                isReceived
                    ? '${seller?.name ?? "?"} te vend'
                    : 'Vente à ${buyer?.name ?? "?"}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(
                '${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} d\'immunité',
                style: const TextStyle(
                    color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shield_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text('${trade.immunityLines}',
                  style: const TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('💼 Service demandé :',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            const SizedBox(height: 4),
            Text(trade.serviceDescription,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 12),
        if (isReceived)
          Row(children: [
            Expanded(
                child: TvFocusWrapper(
              onTap: () => _run(() async => provider.rejectTrade(trade.id)),
              child: ElevatedButton.icon(
                  onPressed: () => _run(() async => provider.rejectTrade(trade.id)),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Refuser'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)))),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: TvFocusWrapper(
              onTap: () => _run(() async {
                await showHandshakeAnimation(context, 'OFFRE ACCEPTÉE !');
                if (mounted) provider.acceptTrade(trade.id);
              }),
              child: ElevatedButton.icon(
                onPressed: () => _run(() async {
                  await showHandshakeAnimation(context, 'OFFRE ACCEPTÉE !');
                  if (mounted) provider.acceptTrade(trade.id);
                }),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Accepter'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
                    foregroundColor: const Color(0xFF00E676),
                    side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            )),
          ])
        else
          SizedBox(
              width: double.infinity,
              child: TvFocusWrapper(
                onTap: () => _run(() async => provider.cancelTrade(trade.id)),
                child: ElevatedButton.icon(
                    onPressed: () =>
                        _run(() async => provider.cancelTrade(trade.id)),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Annuler la vente'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.15),
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)))),
              )),
      ]),
    );
  }

  Widget _buildActiveTab(FamilyProvider provider, ChildModel child,
      List<TradeModel> activeTrades) {
    final inProgress =
        activeTrades.where((t) => t.isAccepted || t.isServiceDone).toList();
    if (inProgress.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.hourglass_empty_rounded,
            size: 70, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 16),
        Text('Aucune vente en cours',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
      ]));
    }
    return ListView(
        padding: const EdgeInsets.all(16),
        children:
            inProgress.map((trade) => _buildActiveTradeCard(provider, trade)).toList());
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
      statusText = 'Service rendu – validation parent';
      statusIcon = Icons.verified_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(statusIcon, color: statusColor, size: 14),
            const SizedBox(width: 6),
            Text(statusText,
                style: TextStyle(
                    color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${seller?.name ?? "?"} → ${buyer?.name ?? "?"}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
                '${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} d\'immunité',
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 13)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF00E676).withOpacity(0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 16),
              const SizedBox(width: 4),
              Text('${trade.immunityLines}',
                  style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10)),
          child: Text('💼 ${trade.serviceDescription}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        const SizedBox(height: 12),
        if (trade.isAccepted && !isSeller)
          SizedBox(
              width: double.infinity,
              child: TvFocusWrapper(
                onTap: () => _run(() async {
                  await showHandshakeAnimation(context, 'SERVICE RENDU !');
                  if (mounted) provider.markServiceDone(trade.id);
                }),
                child: ElevatedButton.icon(
                  onPressed: () => _run(() async {
                    await showHandshakeAnimation(context, 'SERVICE RENDU !');
                    if (mounted) provider.markServiceDone(trade.id);
                  }),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('J\'ai rendu le service'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
                      foregroundColor: const Color(0xFF00E676),
                      side: BorderSide(
                          color: const Color(0xFF00E676).withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              )),
        if (trade.isServiceDone)
          SizedBox(
              width: double.infinity,
              child: TvFocusWrapper(
                onTap: () =>
                    _showParentValidationDialog(context, provider, trade),
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showParentValidationDialog(context, provider, trade),
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: const Text('Validation parent'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF).withOpacity(0.2),
                      foregroundColor: const Color(0xFF7C4DFF),
                      side: BorderSide(
                          color: const Color(0xFF7C4DFF).withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              )),
        const SizedBox(height: 6),
        Center(
            child: TextButton(
                onPressed: () =>
                    _run(() async => provider.cancelTrade(trade.id)),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.red, fontSize: 12)))),
      ]),
    );
  }

  Widget _buildHistoryTab(FamilyProvider provider, ChildModel child,
      List<TradeModel> trades) {
    if (trades.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history_rounded, size: 70, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 16),
        Text('Aucune vente terminée',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
      ]));
    }
    return ListView(
        padding: const EdgeInsets.all(16),
        children: trades.map((trade) {
          final seller = provider.getChild(trade.fromChildId);
          final buyer = provider.getChild(trade.toChildId);
          final dateStr =
              DateFormat('dd/MM/yy à HH:mm', 'fr_FR').format(trade.createdAt);
          final Color statusColor;
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
                border: Border.all(color: statusColor.withOpacity(0.2))),
            child: Row(children: [
              Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(trade.statusEmoji,
                          style: const TextStyle(fontSize: 18)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text('${seller?.name ?? "?"} → ${buyer?.name ?? "?"}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(
                    '${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} • ${trade.serviceDescription}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(dateStr,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ])),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(trade.statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }).toList());
  }

  void _showCreateSaleDialog(BuildContext context, FamilyProvider provider,
      ChildModel seller, int maxLines) {
    final otherChildren =
        provider.children.where((c) => c.id != widget.childId).toList();
    if (otherChildren.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Il faut au moins 2 enfants pour une vente'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }

    showDialog(
        context: context,
        builder: (ctx) {
          String? selectedBuyerId;
          final linesCtrl = TextEditingController(text: '1');
          final serviceCtrl = TextEditingController();

          return StatefulBuilder(builder: (ctx, setDialogState) {
            final parsedLines = int.tryParse(linesCtrl.text) ?? 0;
            final bool canSubmit = selectedBuyerId != null &&
                serviceCtrl.text.trim().isNotEmpty &&
                parsedLines > 0 &&
                parsedLines <= maxLines;

            return AlertDialog(
              backgroundColor: const Color(0xFF1a1a4a),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, val, child) =>
                      Transform.scale(scale: val, child: child),
                  child: const Icon(Icons.sell_rounded,
                      color: Color(0xFF00E676), size: 22),
                ),
                const SizedBox(width: 8),
                const Text('Nouvelle vente',
                    style: TextStyle(color: Color(0xFF00E676), fontSize: 18)),
              ]),
              content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Vendre à :',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: otherChildren.map((c) {
                          final isSelected = selectedBuyerId == c.id;
                          return TvFocusWrapper(
                            onTap: () => setDialogState(() => selectedBuyerId = c.id),
                            child: GestureDetector(
                              onTap: () =>
                                  setDialogState(() => selectedBuyerId = c.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF00E676).withOpacity(0.2)
                                        : Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF00E676)
                                            : Colors.white24,
                                        width: isSelected ? 2 : 1)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(c.avatar.isNotEmpty ? c.avatar : '👤',
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(c.name,
                                      style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFF00E676)
                                              : Colors.white70,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal)),
                                ]),
                              ),
                            ),
                          );
                        }).toList()),
                    const SizedBox(height: 20),
                    const Text('Nombre de lignes :',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Center(
                      child: SizedBox(
                        width: 120,
                        child: TextField(
                          controller: linesCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 28,
                              fontWeight: FontWeight.w900),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                    Center(
                        child: Text('max: $maxLines',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 11))),
                    const SizedBox(height: 8),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        children: [1, 3, 5, 10, 20]
                            .where((n) => n <= maxLines)
                            .map((n) => GestureDetector(
                                  onTap: () => setDialogState(
                                      () => linesCtrl.text = '$n'),
                                  child: Chip(
                                    label: Text('$n',
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.1),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Service demandé en échange :',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: serviceCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: InputDecoration(
                          hintText: 'Ex: Ranger ma chambre, faire la vaisselle...',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none)),
                    ),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annuler',
                        style: TextStyle(color: Colors.white54))),
                TvFocusWrapper(
                  onTap: canSubmit
                      ? () => _run(() async {
                            final finalLines =
                                (int.tryParse(linesCtrl.text) ?? 1)
                                    .clamp(1, maxLines);
                            await provider.createTrade(
                                widget.childId,
                                selectedBuyerId!,
                                finalLines,
                                serviceCtrl.text.trim());
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              await showHandshakeAnimation(
                                  context, 'VENTE PROPOSÉE !');
                            }
                          })
                      : null,
                  child: ElevatedButton.icon(
                    onPressed: canSubmit
                        ? () => _run(() async {
                              final finalLines =
                                  (int.tryParse(linesCtrl.text) ?? 1)
                                      .clamp(1, maxLines);
                              await provider.createTrade(
                                  widget.childId,
                                  selectedBuyerId!,
                                  finalLines,
                                  serviceCtrl.text.trim());
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                await showHandshakeAnimation(
                                    context, 'VENTE PROPOSÉE !');
                              }
                            })
                        : null,
                    icon: const Icon(Icons.sell_rounded, size: 18),
                    label: const Text('Proposer la vente'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            );
          });
        });
  }

  // ✅ CORRIGÉ : suppression du paramètre parentNote inexistant
  void _showParentValidationDialog(
      BuildContext context, FamilyProvider provider, TradeModel trade) {
    final noteCtrl = TextEditingController();
    final seller = provider.getChild(trade.fromChildId);
    final buyer = provider.getChild(trade.toChildId);

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1a4a),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.gavel_rounded, color: Color(0xFF7C4DFF), size: 22),
              SizedBox(width: 8),
              Text('Validation parent',
                  style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 18)),
            ]),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          '${seller?.name ?? "?"} vend '
                          '${trade.immunityLines} ligne${trade.immunityLines > 1 ? 's' : ''} '
                          'à ${buyer?.name ?? "?"}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('💼 ${trade.serviceDescription}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Note optionnelle :',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                        hintText: 'Ex: Service bien rendu !',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none)),
                  ),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler',
                      style: TextStyle(color: Colors.white54))),
              ElevatedButton.icon(
                // ✅ CORRIGÉ : pas de paramètre parentNote
                onPressed: () => _run(() async {
                  await provider.completeTrade(trade.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) await showTradeCelebration(context);
                }),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Valider la vente'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ],
          );
        });
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(title,
        style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5));
  }

  Widget _buildBadgeCount(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.amber, borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}
