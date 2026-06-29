import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../widgets/animated_page_transition.dart';
import 'family_screen.dart';
import 'manage_children_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key}); // ✅ super.key
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _sectionController;
  late AnimationController _dangerShakeController;
  late Animation<double>   _dangerShake;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _sectionController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _dangerShakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _dangerShake = Tween<double>(begin: 0, end: 12).animate(
        CurvedAnimation(
            parent: _dangerShakeController, curve: Curves.elasticIn));

    // ✅ Version récupérée dynamiquement
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _appVersion = 'v${info.version}');
      }
    });
  }

  @override
  void dispose() {
    _sectionController.dispose();
    _dangerShakeController.dispose();
    super.dispose();
  }

  // ─── Animation d'entrée des sections ───────────────────────
  Widget _animatedSection({required int index, required Widget child}) {
    final delay = (index * 0.12).clamp(0.0, 0.85);
    return AnimatedBuilder(
      animation: _sectionController,
      builder: (ctx, ch) {
        final progress = ((_sectionController.value - delay) /
                (1.0 - delay))
            .clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(progress);
        return Transform.translate(
          offset: Offset(0, 30 * (1 - t)),
          child: Opacity(opacity: t, child: ch),
        );
      },
      child: child,
    );
  }

  // ─── Dialog PIN ────────────────────────────────────────────
  void _showPinDialog() {
    final pinProvider = context.read<PinProvider>();
    final ctrl        = TextEditingController();
    final isSet       = pinProvider.isPinSet;
    bool  _obscure    = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Icon(isSet ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: Colors.amber),
              const SizedBox(width: 8),
              Text(isSet ? 'Modifier le PIN' : 'Créer un PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSet
                    ? 'Entrez un nouveau code PIN (4 à 6 chiffres).'
                    : 'Créez un code PIN pour protéger le mode parent.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller:  ctrl,
                keyboardType: TextInputType.number,
                obscureText:  _obscure,
                maxLength:    6,
                autofocus:    true,
                textAlign:    TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText:     '• • • •',
                  counterText:  '',
                  suffixIcon:   IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () =>
                        setStateDialog(() => _obscure = !_obscure),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onSubmitted: (_) {
                  final pin = ctrl.text.trim();
                  if (pin.length >= 4) {
                    pinProvider.setPin(pin);
                    Navigator.pop(ctx);
                    _showSnack('✅ PIN enregistré avec succès.');
                  }
                },
              ),
              if (isSet) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    pinProvider.removePin();
                    Navigator.pop(ctx);
                    _showSnack('🔓 PIN supprimé.', isWarning: true);
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                  label: const Text('Supprimer le PIN',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final pin = ctrl.text.trim();
                if (pin.length >= 4) {
                  pinProvider.setPin(pin);
                  Navigator.pop(ctx);
                  _showSnack('✅ PIN enregistré avec succès.');
                } else {
                  HapticFeedback.heavyImpact();
                  _showSnack('⚠️ Le PIN doit avoir au moins 4 chiffres.',
                      isWarning: true);
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    ).then((_) => ctrl.dispose());
  }

  // ─── Sélecteur de couleur ───────────────────────────────────
  void _showColorPicker() {
    final themeProvider = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text(
              '🎨 Couleur d\'accent',
              style: TextStyle(
                  color:      Colors.white,
                  fontSize:   20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                ThemeProvider.accentColors.length,
                (i) {
                  final color    = ThemeProvider.accentColors[i];
                  final selected = i == themeProvider.colorIndex;
                  return TvFocusWrapper(
                    onTap: () {
                      themeProvider.setColorIndex(i);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width:  52,
                      height: 52,
                      decoration: BoxDecoration(
                        color:  color,
                        shape:  BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [BoxShadow(
                                color:      color.withValues(alpha: 0.6),
                                blurRadius: 12)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 24)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Sélecteur fond
            const Text(
              '🌃 Couleur de fond',
              style: TextStyle(
                  color:      Colors.white,
                  fontSize:   16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(
                ThemeProvider.backgroundColors.length,
                (i) {
                  final bg = ThemeProvider.backgroundColors[i];
                  final selected = i == themeProvider.bgIndex;
                  return TvFocusWrapper(
                    onTap: () {
                      themeProvider.setBgIndex(i);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width:  52,
                      height: 52,
                      decoration: BoxDecoration(
                        color:  bg['color'] as Color,
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? Border.all(color: Colors.white, width: 2)
                            : Border.all(
                                color: Colors.white24, width: 1),
                        boxShadow: selected
                            ? [BoxShadow(
                                color:      Colors.white.withValues(alpha: 0.2),
                                blurRadius: 8)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : Center(
                              child: Text(
                                (bg['label'] as String).substring(0, 2),
                                style: const TextStyle(
                                    color:    Colors.white54,
                                    fontSize: 10),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Confirmations danger ───────────────────────────────────
  void _confirmResetScores() {
    _dangerShakeController.forward(from: 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Remettre les scores à zéro ?'),
          ],
        ),
        content: const Text(
          'Tous les points de tous les enfants seront remis à 0.\nCette action est irréversible !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            onPressed: () {
              context.read<FamilyProvider>().resetAllScores();
              Navigator.pop(ctx);
              _showSnack('🔄 Scores remis à zéro.', isWarning: true);
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
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Effacer tout l\'historique ?'),
          ],
        ),
        content: const Text(
          'Tout l\'historique des activités sera supprimé définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            onPressed: () {
              context.read<FamilyProvider>().clearHistory();
              Navigator.pop(ctx);
              _showSnack('🗑️ Historique effacé.', isWarning: true);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  // ─── Snackbar helper ────────────────────────────────────────
  void _showSnack(String msg, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isWarning ? Colors.orange.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer3<FamilyProvider, PinProvider, ThemeProvider>(
      builder: (context, fp, pin, theme, _) {
        final primary = Theme.of(context).colorScheme.primary;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [

                  // ─── Header ──────────────────────────────
                  _animatedSection(
                    index: 0,
                    child: Row(
                      children: [
                        const Text('⚙️', style: TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Réglages',
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _appVersion.isEmpty ? '...' : _appVersion,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Apparence ───────────────────────────
                  _animatedSection(
                      index: 1,
                      child: _sectionTitle('🎨 Apparence')),
                  _animatedSection(
                    index: 2,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _settingRow(
                            icon: theme.isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            iconColor: Colors.amberAccent,
                            title: 'Thème sombre',
                            trailing: Switch(
                              value:    theme.isDark,
                              onChanged: (_) => theme.toggle(),
                            ),
                          ),
                          const Divider(color: Colors.white12),
                          TvFocusWrapper(
                            onTap: _showColorPicker,
                            child: _settingRow(
                              icon:      Icons.palette_rounded,
                              iconColor: primary,
                              title:     'Couleur & fond',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width:  24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color:  primary,
                                      shape:  BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white38),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.white38),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Sécurité ────────────────────────────
                  _animatedSection(
                      index: 3,
                      child: _sectionTitle('🔐 Sécurité')),
                  _animatedSection(
                    index: 4,
                    child: GlassCard(
                      child: TvFocusWrapper(
                        onTap: _showPinDialog,
                        child: _settingRow(
                          icon:      Icons.lock_rounded,
                          iconColor: Colors.cyanAccent,
                          title: pin.isPinSet
                              ? 'Modifier le PIN'
                              : 'Créer un PIN',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (pin.isPinSet
                                      ? Colors.greenAccent
                                      : Colors.redAccent)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pin.isPinSet ? '🔒 Actif' : '🔓 Inactif',
                              style: TextStyle(
                                color: pin.isPinSet
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize:   12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Famille ─────────────────────────────
                  _animatedSection(
                      index: 5,
                      child: _sectionTitle('👨‍👩‍👧‍👦 Famille')),
                  _animatedSection(
                    index: 6,
                    child: GlassCard(
                      child: Column(
                        children: [
                          TvFocusWrapper(
                            onTap: () => Navigator.push(context,
                                SlidePageRoute(
                                    page: const FamilyScreen())),
                            child: _settingRow(
                              icon:      Icons.sync_rounded,
                              iconColor: Colors.purpleAccent,
                              title:     'Synchronisation famille',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    fp.isSyncEnabled
                                        ? Icons.cloud_done_rounded
                                        : Icons.cloud_off_rounded,
                                    color: fp.isSyncEnabled
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.white38),
                                ],
                              ),
                            ),
                          ),
                          const Divider(color: Colors.white12),
                          TvFocusWrapper(
                            onTap: () => Navigator.push(context,
                                SlidePageRoute(
                                    page:
                                        const ManageChildrenScreen())),
                            child: _settingRow(
                              icon:      Icons.people_rounded,
                              iconColor: Colors.orangeAccent,
                              title:     'Gérer les enfants',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orangeAccent
                                          .withValues(alpha: 0.2),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${fp.children.length}',
                                      style: const TextStyle(
                                        color:      Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.white38),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Zone dangereuse ─────────────────────
                  _animatedSection(
                      index: 7,
                      child: _sectionTitle('⚠️ Zone dangereuse')),
                  _animatedSection(
                    index: 8,
                    child: AnimatedBuilder(
                      animation: _dangerShake,
                      builder: (ctx, child) => Transform.translate(
                        offset: Offset(
                          _dangerShake.value *
                              ((_dangerShakeController.value * 10)
                                          .toInt() %
                                      2 ==
                                  0
                                  ? 1
                                  : -1),
                          0,
                        ),
                        child: child,
                      ),
                      child: GlassCard(
                        child: Column(
                          children: [
                            TvFocusWrapper(
                              onTap: _confirmResetScores,
                              child: _settingRow(
                                icon:      Icons.refresh_rounded,
                                iconColor: Colors.orangeAccent,
                                title: 'Remettre les scores à zéro',
                                trailing: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orangeAccent,
                                    size: 20),
                              ),
                            ),
                            const Divider(color: Colors.white12),
                            TvFocusWrapper(
                              onTap: _confirmClearHistory,
                              child: _settingRow(
                                icon:      Icons.delete_forever_rounded,
                                iconColor: Colors.redAccent,
                                title: 'Effacer tout l\'historique',
                                trailing: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.redAccent,
                                    size: 20),
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

  // ─── Helpers UI ────────────────────────────────────────────
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
              color:      Colors.white70,
              fontSize:   15,
              fontWeight: FontWeight.w600),
        ),
      );

  Widget _settingRow({
    required IconData icon,
    required Color    iconColor,
    required String   title,
    required Widget   trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Container(
            width:  42,
            height: 42,
            decoration: BoxDecoration(
              color:         iconColor.withValues(alpha: 0.15),
              borderRadius:  BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
