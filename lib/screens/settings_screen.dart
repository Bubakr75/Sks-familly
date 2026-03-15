import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import 'pin_verification_screen.dart';
import 'setup_pin_screen.dart';
import 'family_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GlowIcon(icon: Icons.settings_rounded, color: primary, size: 26),
                    const SizedBox(width: 10),
                    NeonText(text: 'Reglages', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, glowIntensity: 0.2),
                  ],
                ),
                const SizedBox(height: 24),

                // Appearance
                _GlassSectionTitle(title: 'Apparence', color: primary),
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Consumer<ThemeProvider>(
                    builder: (_, themeProvider, __) => Column(
                      children: [
                        _GlassSettingsTile(
                          icon: themeProvider.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          iconColor: themeProvider.isDark ? const Color(0xFFFFD740) : Colors.orange,
                          title: 'Theme sombre',
                          subtitle: themeProvider.isDark ? 'Active' : 'Desactive',
                          trailing: Switch(
                            value: themeProvider.isDark,
                            onChanged: (_) => themeProvider.toggle(),
                          ),
                        ),
                        Divider(color: Colors.white.withValues(alpha: 0.06), height: 1, indent: 56),
                        _GlassSettingsTile(
                          icon: Icons.palette_rounded,
                          iconColor: themeProvider.primaryColor,
                          title: 'Couleur d\'accent',
                          subtitle: 'Personnalisez le theme',
                          trailing: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: themeProvider.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                              boxShadow: [BoxShadow(color: themeProvider.primaryColor.withValues(alpha: 0.4), blurRadius: 8)],
                            ),
                          ),
                          onTap: () => _showColorPicker(context, themeProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Family
                _GlassSectionTitle(title: 'Famille', color: primary),
                Consumer<FamilyProvider>(
                  builder: (_, provider, __) => GlassCard(
                    margin: const EdgeInsets.only(bottom: 6),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen())),
                    child: _GlassSettingsTile(
                      icon: provider.isSyncEnabled ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      iconColor: provider.isSyncEnabled ? const Color(0xFF00E676) : Colors.grey,
                      title: provider.isSyncEnabled ? 'Synchronisation active' : 'Mode local',
                      subtitle: provider.isSyncEnabled
                          ? 'Les donnees sont partagees en temps reel'
                          : 'Activez pour partager avec votre conjoint(e)',
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Security
                _GlassSectionTitle(title: 'Securite', color: primary),
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Consumer<PinProvider>(
                    builder: (_, pinProvider, __) => Column(
                      children: [
                        _GlassSettingsTile(
                          icon: pinProvider.isPinSet ? Icons.lock_rounded : Icons.lock_open_rounded,
                          iconColor: pinProvider.isPinSet ? const Color(0xFF00E676) : Colors.orange,
                          title: 'Code parental',
                          subtitle: pinProvider.isPinSet
                              ? (pinProvider.isParentMode ? 'Active - Mode parent' : 'Active - Mode enfant')
                              : 'Desactive - Pas de protection',
                          trailing: Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
                          onTap: () {
                            if (pinProvider.isPinSet) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PinVerificationScreen(
                                    onVerified: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SetupPinScreen()),
                                      );
                                    },
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupPinScreen()));
                            }
                          },
                        ),
                        if (pinProvider.isPinSet) ...[
                          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1, indent: 56),
                          _GlassSettingsTile(
                            icon: pinProvider.isParentMode ? Icons.shield_rounded : Icons.shield_outlined,
                            iconColor: pinProvider.isParentMode ? const Color(0xFF00E676) : Colors.grey,
                            title: pinProvider.isParentMode ? 'Mode parent actif' : 'Mode enfant actif',
                            subtitle: pinProvider.isParentMode ? 'Touchez pour verrouiller' : 'Touchez pour deverrouiller',
                            trailing: Switch(
                              value: pinProvider.isParentMode,
                              onChanged: (v) {
                                if (v) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PinVerificationScreen(onVerified: () => Navigator.pop(context)),
                                    ),
                                  );
                                } else {
                                  pinProvider.lockParentMode();
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Data
                _GlassSectionTitle(title: 'Donnees', color: primary),
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Consumer<FamilyProvider>(
                    builder: (_, provider, __) => Column(
                      children: [
                        _GlassSettingsTile(
                          icon: Icons.restart_alt_rounded,
                          iconColor: Colors.orange,
                          title: 'Reinitialiser les scores',
                          subtitle: 'Remettre tous les scores a zero',
                          onTap: () => PinGuard.guardAction(context, () => _confirmResetScores(context, provider)),
                        ),
                        Divider(color: Colors.white.withValues(alpha: 0.06), height: 1, indent: 56),
                        _GlassSettingsTile(
                          icon: Icons.delete_sweep_rounded,
                          iconColor: const Color(0xFFFF1744),
                          title: 'Effacer l\'historique',
                          subtitle: 'Supprimer tout l\'historique d\'activites',
                          onTap: () => PinGuard.guardAction(context, () => _confirmClearHistory(context, provider)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // About
                _GlassSectionTitle(title: 'A propos', color: primary),
                GlassCard(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    children: [
                      _GlassSettingsTile(
                        icon: Icons.info_rounded,
                        iconColor: const Color(0xFF00E5FF),
                        title: 'SKS Family',
                        subtitle: 'Version 3.5.0 - Dark Premium',
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.06), height: 1, indent: 56),
                      Consumer<FamilyProvider>(
                        builder: (_, p, __) => _GlassSettingsTile(
                          icon: Icons.family_restroom_rounded,
                          iconColor: const Color(0xFF7C4DFF),
                          title: 'Ma famille',
                          subtitle: '${p.children.length} enfants - ${p.history.length} activites',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const NeonText(text: 'Choisir une couleur', fontSize: 18, color: Colors.white),
        content: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: ThemeProvider.accentColors.asMap().entries.map((entry) {
            final isSelected = themeProvider.colorIndex == entry.key;
            return GestureDetector(
              onTap: () {
                themeProvider.setColorIndex(entry.key);
                Navigator.pop(ctx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: entry.value,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(color: entry.value.withValues(alpha: isSelected ? 0.6 : 0.2), blurRadius: isSelected ? 16 : 6),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmResetScores(BuildContext context, FamilyProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reinitialiser', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text('Voulez-vous vraiment remettre tous les scores a zero ? Les badges seront aussi reinitialises.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              provider.resetAllScores();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scores reinitialises'), backgroundColor: Colors.orange),
              );
            },
            child: const Text('Reinitialiser'),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, FamilyProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744)),
            const SizedBox(width: 8),
            const Text('Effacer', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text('Voulez-vous vraiment supprimer tout l\'historique ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historique efface'), backgroundColor: Color(0xFFFF1744)),
              );
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}

class _GlassSectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _GlassSectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: NeonText(text: title, fontSize: 13, fontWeight: FontWeight.w700, color: color, glowIntensity: 0.3),
    );
  }
}

class _GlassSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _GlassSettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(color: iconColor.withValues(alpha: 0.12), blurRadius: 6)],
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
