import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/emerald_theme.dart';
import '../models/child_model.dart';
import '../providers/family_provider.dart';

class ScreenTimeStore extends StatefulWidget {
  const ScreenTimeStore({super.key, required this.child});
  final ChildModel child;
  @override
  State<ScreenTimeStore> createState() => _ScreenTimeStoreState();
}

class _ScreenTimeStoreState extends State<ScreenTimeStore> {
  bool _buying = false;
  Future<void> _buy(int minutes) async {
    if (_buying) return;
    setState(() => _buying = true);
    try {
      await context
          .read<FamilyProvider>()
          .purchaseScreenTime(widget.child.id, minutes);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$minutes minutes ajoutées à ton temps d’écran.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Achat non confirmé. Vérifie ton solde et ta connexion, puis réessaie.')));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.watch<FamilyProvider>();
    final balance = widget.child.points;
    final blocked = fp.isScreenAccessBlocked(widget.child.id);
    return EmeraldCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mes points, mon temps d’écran',
          style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: EmeraldPalette.textPrimary)),
      const SizedBox(height: 8),
      Text(
          '$balance point${balance == 1 ? '' : 's'} disponible${balance == 1 ? '' : 's'}',
          style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: EmeraldPalette.gold)),
      const Text(
          'Une bonne action = 1 point. Choisis du temps et utilise-le avec le chrono.'),
      const SizedBox(height: 16),
      for (final offer in const [(30, 3), (60, 5)])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey('screen_buy_${offer.$1}'),
                onPressed: _buying || blocked || balance < offer.$2
                    ? null
                    : () => _buy(offer.$1),
                icon: const Icon(Icons.sports_esports_rounded),
                label: Text(
                    '${offer.$1 == 60 ? '1 heure' : '30 minutes'} · ${offer.$2} points'),
              )),
        ),
      Text(blocked
          ? 'Écrans bloqués : ${fp.pendingPenaltyLinesForChild(widget.child.id).map((s) => s.isWriting ? '${s.sanctionTitle} (${s.totalLines} lignes)' : '${s.sanctionTitle} : ${s.text}').join(', ')}. Fais valider par un parent.'
          : _buying
              ? 'Vérification de l’achat…'
              : balance < 3
                  ? 'Encore ${3 - balance} point(s) pour 30 minutes.'
                  : 'Les points sont retirés de ton solde à l’achat.'),
    ]));
  }
}
