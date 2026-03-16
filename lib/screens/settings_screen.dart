import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../widgets/neon_text.dart';
import 'family_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── App bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.settings, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Réglages',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ── Body ──
                Expanded(
                  child: Consumer3<ThemeProvider, PinProvider, FamilyProvider>(
                    builder: (context, themeProv, pinProv, familyProv, _) {
                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          // ═══════════ APPARENCE ═══════════
                          const _GlassSectionTitle(icon: Icons.palette, title: 'Apparence'),
                          const SizedBox(height: 8),

                          // Dark/Light toggle
                          _GlassSettingsTile(
                            icon: themeProv.isDark ? Icons.dark_mode : Icons.light_mode,
                            title: 'Mode sombre',
                            trailing: Switch(
                              value: themeProv.isDark,
                              onChanged: (_) => themeProv.toggle(),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Accent color picker
                          GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.color_lens, color: themeProv.primaryColor, size: 20),
                                      const SizedBox(width: 10),
                                      const Text('Couleur d\'accent', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: List.generate(ThemeProvider.accentColors.length, (i) {
                                      final color = ThemeProvider.accentColors[i];
                                      final selected = i == themeProv.colorIndex;
                                      return GestureDetector(
                                        onTap: () => themeProv.setColorIndex(i),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: selected
                                                ? Border.all(color: Colors.white, width: 3)
                                                : null,
                                            boxShadow: selected
                                                ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 12)]
                                                : [],
                                          ),
                                          child: selected
                                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                                              : null,
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Background color picker
                          GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.wallpaper, color: Colors.white70, size: 20),
                                      SizedBox(width: 10),
                                      Text('Fond d\'écran', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: List.generate(ThemeProvider.backgroundColors.length, (i) {
                                      final bg = ThemeProvider.backgroundColors[i];
                                      final selected = i == themeProv.bgIndex;
                                      return GestureDetector(
                                        onTap: () => themeProv.setBgIndex(i),
                                        child: Column(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: bg['color'] as Color,
                                                shape: BoxShape.circle,
                                                border: selected
                                                    ? Border.all(color: themeProv.primaryColor, width: 3)
                                                    : Border.all(color: Colors.white24, width: 1),
                                                boxShadow: selected
                                                    ? [BoxShadow(color: (bg['color'] as Color).withOpacity(0.5), blurRadius: 10)]
                                                    : [],
                                              ),
                                              child: selected
                                                  ? Icon(Icons.check, color: themeProv.primaryColor, size: 18)
                                                  : null,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              bg['label'] as String,
                                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ═══════════ FAMILLE ═══════════
                          const _GlassSectionTitle(icon: Icons.family_restroom, title: 'Famille'),
                          const SizedBox(height: 8),
                          _GlassSettingsTile(
                            icon: Icons.cloud_sync,
                            title: 'Synchronisation',
                            subtitle: familyProv.isSynced ? 'Connecté' : 'Hors ligne',
                            trailing: Icon(
                              familyProv.isSynced ? Icons.cloud_done : Icons.cloud_off,
                              color: familyProv.isSynced ? Colors.greenAccent : Colors.redAccent,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FamilyScreen()),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ═══════════ SÉCURITÉ ═══════════
                          const _GlassSectionTitle(icon: Icons.security, title: 'Sécurité'),
                          const SizedBox(height: 8),
                          _GlassSettingsTile(
                            icon: Icons.lock,
                            title: 'Code parental',
                            subtitle: pinProv.hasPin ? 'Activé' : 'Non défini',
                            trailing: Icon(
                              pinProv.hasPin ? Icons.lock : Icons.lock_open,
                              color: pinProv.hasPin ? Colors.greenAccent : Colors.orangeAccent,
                            ),
                            onTap: () => _showPinSetup(context, pinProv),
                          ),
                          const SizedBox(height: 8),
                          _GlassSettingsTile(
                            icon: pinProv.isParentMode ? Icons.admin_panel_settings : Icons.child_care,
                            title: 'Mode actuel',
                            subtitle: pinProv.isParentMode ? 'Mode parent' : 'Mode enfant',
                            trailing: Switch(
                              value: pinProv.isParentMode,
                              onChanged: (val) {
                                if (val) {
                                  PinGuard.check(context, () {});
                                } else {
                                  pinProv.setParentMode(false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ═══════════ DONNÉES ═══════════
                          const _GlassSectionTitle(icon: Icons.storage, title: 'Données'),
                          const SizedBox(height: 8),
                          _GlassSettingsTile(
                            icon: Icons.restart_alt,
                            title: 'Réinitialiser les scores',
                            subtitle: 'Remet tous les points à zéro',
                            onTap: () => PinGuard.check(context, () => _confirmResetScores(context, familyProv)),
                          ),
                          const SizedBox(height: 8),
                          _GlassSettingsTile(
                            icon: Icons.delete_sweep,
                            title: 'Effacer l\'historique',
                            subtitle: 'Supprime tout l\'historique',
                            onTap: () => PinGuard.check(context, () => _confirmClearHistory(context, familyProv)),
                          ),
                          const SizedBox(height: 16),

                          // ═══════════ À PROPOS ═══════════
                          const _GlassSectionTitle(icon: Icons.info_outline, title: 'À propos'),
                          const SizedBox(height: 8),
                          _GlassSettingsTile(
                            icon: Icons.phone_android,
                            title: 'SKS Family',
                            subtitle: 'Version 1.0.0',
                          ),
                          const SizedBox(height: 8),
                          _GlassSettingsTile(
                            icon: Icons.people,
                            title: 'Famille',
                            subtitle: '${familyProv.children.length} enfant(s)',
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPinSetup(BuildContext context, PinProvider pinProv) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Code parental', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pinProv.hasPin ? 'Modifier le code parental' : 'Créer un code parental',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 12),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          if (pinProv.hasPin)
            TextButton(
              onPressed: () {
                pinProv.removePin();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code supprimé')),
                );
              },
              child: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
            ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length == 4) {
                pinProv.setPin(controller.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code enregistré !')),
                );
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _confirmResetScores(BuildContext context, FamilyProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Réinitialiser ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tous les points seront remis à zéro. Cette action est irréversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              prov.resetAllScores();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scores réinitialisés')),
              );
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, FamilyProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Effacer l\'historique ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tout l\'historique sera supprimé. Cette action est irréversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              prov.clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historique effacé')),
              );
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ──
class _GlassSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _GlassSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ── Settings Tile ──
class _GlassSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _GlassSettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle!, style: const TextStyle(color: Colors.white60, fontSize: 12))
            : null,
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
