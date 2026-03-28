import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'family_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _sectionController;
  late AnimationController _dangerShakeController;
  late Animation<double> _dangerShake;

  @override
  void initState() {
    super.initState();
    _sectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _dangerShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _dangerShake = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _dangerShakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _sectionController.dispose();
    _dangerShakeController.dispose();
    super.dispose();
  }

  Widget _animatedSection({required int index, required Widget child}) {
    final delay = index * 0.15;
    return AnimatedBuilder(
      animation: _sectionController,
      builder: (ctx, ch) {
        final t = Curves.easeOutCubic
            .transform(((_sectionController.value - delay) / (1 - delay)).clamp(0.0, 1.0));
        return Transform.translate(
          offset: Offset(0, 40 * (1 - t)),
          child: Opacity(opacity: t, child: ch),
        );
      },
      child: child,
    );
  }

  void _showPinDialog() {
    final pinProvider = context.read<PinProvider>();
    final ctrl = TextEditingController();
    final isSet = pinProvider.isPinSet;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isSet ? '🔒 Modifier le PIN' : '🔐 Créer un PIN',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (isSet)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () {
                    pinProvider.removePin();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: const Text('🔓 PIN supprimé'),
                          backgroundColor: Colors.orange.shade700),
                    );
                  },
                  child: const Text('Supprimer le PIN',
                      style: TextStyle(color: Colors.redAccent)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent.shade700),
            onPressed: () {
              final pin = ctrl.text.trim();
              if (pin.length >= 4) {
                pinProvider.setPin(pin);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: const Text('✅ PIN enregistré'),
                      backgroundColor: Colors.green.shade700),
                );
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    final themeProvider = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎨 Couleur d\'accent',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(themeProvider.accentColors.length, (i) {
                final color = themeProvider.accentColors[i];
                final selected = i == themeProvider.colorIndex;
                return TvFocusWrapper(
                  onSelect: () {
                    themeProvider.setColorIndex(i);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: selected
                          ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmResetScores() {
    _dangerShakeController.forward(from: 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ Remettre les scores à zéro ?',
            style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'Tous les points de tous les enfants seront remis à 0. Cette action est irréversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              context.read<FamilyProvider>().resetScores();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: const Text('🔄 Scores remis à zéro'),
                    backgroundColor: Colors.red.shade700),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory() {
    _dangerShakeController.forward(from: 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ Effacer tout l\'historique ?',
            style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'Tout l\'historique des activités sera supprimé. Cette action est irréversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              context.read<FamilyProvider>().clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: const Text('🗑️ Historique effacé'),
                    backgroundColor: Colors.red.shade700),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<FamilyProvider, PinProvider, ThemeProvider>(
      builder: (context, familyProvider, pinProvider, themeProvider, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Header ──
                  _animatedSection(
                    index: 0,
                    child: Row(
                      children: [
                        const Text('⚙️', style: TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Réglages',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('v4.9.0',
                              style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Apparence ──
                  _animatedSection(
                    index: 1,
                    child: _sectionTitle('🎨 Apparence'),
                  ),
                  _animatedSection(
                    index: 2,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _settingRow(
                            icon: themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
                            iconColor: Colors.amberAccent,
                            title: 'Thème sombre',
                            trailing: Switch(
                              value: themeProvider.isDark,
                              onChanged: (_) => themeProvider.toggle(),
                              activeColor: Colors.cyanAccent,
                            ),
                          ),
                          const Divider(color: Colors.white12),
                          TvFocusWrapper(
                            onSelect: _showColorPicker,
                            child: _settingRow(
                              icon: Icons.palette,
                              iconColor: themeProvider.primaryColor,
                              title: 'Couleur d\'accent',
                              trailing: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: themeProvider.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white38),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Sécurité ──
                  _animatedSection(
                    index: 3,
                    child: _sectionTitle('🔐 Sécurité'),
                  ),
                  _animatedSection(
                    index: 4,
                    child: GlassCard(
                      child: TvFocusWrapper(
                        onSelect: _showPinDialog,
                        child: _settingRow(
                          icon: Icons.lock,
                          iconColor: Colors.cyanAccent,
                          title: pinProvider.isPinSet ? 'Modifier le PIN' : 'Créer un PIN',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: pinProvider.isPinSet
                                  ? Colors.greenAccent.withValues(alpha: 0.2)
                                  : Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pinProvider.isPinSet ? 'Actif' : 'Inactif',
                              style: TextStyle(
                                color: pinProvider.isPinSet ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Famille ──
                  _animatedSection(
                    index: 5,
                    child: _sectionTitle('👨‍👩‍👧‍👦 Famille'),
                  ),
                  _animatedSection(
                    index: 6,
                    child: GlassCard(
                      child: Column(
                        children: [
                          TvFocusWrapper(
                            onSelect: () {
                              Navigator.push(
                                context,
                                SlidePageRoute(page: const FamilyScreen()),
                              );
                            },
                            child: _settingRow(
                              icon: Icons.sync,
                              iconColor: Colors.purpleAccent,
                              title: 'Synchronisation famille',
                              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                            ),
                          ),
                          const Divider(color: Colors.white12),
                          _settingRow(
                            icon: Icons.people,
                            iconColor: Colors.orangeAccent,
                            title: 'Enfants enregistrés',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${familyProvider.children.length}',
                                style: const TextStyle(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Zone dangereuse ──
                  _animatedSection(
                    index: 7,
                    child: _sectionTitle('⚠️ Zone dangereuse'),
                  ),
                  _animatedSection(
                    index: 8,
                    child: AnimatedBuilder(
                      animation: _dangerShake,
                      builder: (ctx, child) {
                        return Transform.translate(
                          offset: Offset(
                              _dangerShake.value *
                                  ((_dangerShakeController.value * 10).toInt() % 2 == 0
                                      ? 1
                                      : -1),
                              0),
                          child: child,
                        );
                      },
                      child: GlassCard(
                        child: Column(
                          children: [
                            TvFocusWrapper(
                              onSelect: _confirmResetScores,
                              child: _settingRow(
                                icon: Icons.refresh,
                                iconColor: Colors.orangeAccent,
                                title: 'Remettre les scores à zéro',
                                trailing: const Icon(Icons.warning_amber,
                                    color: Colors.orangeAccent, size: 20),
                              ),
                            ),
                            const Divider(color: Colors.white12),
                            TvFocusWrapper(
                              onSelect: _confirmClearHistory,
                              child: _settingRow(
                                icon: Icons.delete_forever,
                                iconColor: Colors.redAccent,
                                title: 'Effacer tout l\'historique',
                                trailing: const Icon(Icons.warning_amber,
                                    color: Colors.redAccent, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
          trailing,
        ],
      ),
    );
  }
}
