import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../screens/family_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _sectionController;
  late AnimationController _dangerShakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _sectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _dangerShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(_dangerShakeController);

    _sectionController.forward();
  }

  @override
  void dispose() {
    _sectionController.dispose();
    _dangerShakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, PinProvider, FamilyProvider>(
      builder: (context, theme, pin, fp, _) {
        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Animated header
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, -20 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          TvFocusWrapper(
                            onTap: () => Navigator.pop(context),
                            child:
                                const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.cyan, Colors.purple],
                            ).createShader(bounds),
                            child: const Text(
                              '⚙️ Paramètres',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Settings list
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Section 0: Appearance
                        _buildAnimatedSection(
                          index: 0,
                          title: '🎨 Apparence',
                          children: [
                            _GlassSettingsTile(
                              icon: Icons.dark_mode,
                              iconColor: Colors.indigo,
                              title: 'Mode sombre',
                              trailing: Switch(
                                value: theme.isDarkMode,
                                activeColor: Colors.cyan,
                                onChanged: (_) => theme.toggleDarkMode(),
                              ),
                            ),
                            TvFocusWrapper(
                              onTap: () => _showAccentColorPicker(theme),
                              child: _GlassSettingsTile(
                                icon: Icons.color_lens,
                                iconColor: Colors.pink,
                                title: 'Couleur d\'accent',
                                trailing: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: theme.accentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white38, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.accentColor
                                            .withOpacity(0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Section 1: Family
                        _buildAnimatedSection(
                          index: 1,
                          title: '👨‍👩‍👧‍👦 Famille',
                          children: [
                            TvFocusWrapper(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const FamilyScreen()),
                                );
                              },
                              child: const _GlassSettingsTile(
                                icon: Icons.sync,
                                iconColor: Colors.cyan,
                                title: 'Synchronisation famille',
                                trailing: Icon(Icons.chevron_right,
                                    color: Colors.white38),
                              ),
                            ),
                            TvFocusWrapper(
                              onTap: () => _showEditParentDialog(fp),
                              child: _GlassSettingsTile(
                                icon: Icons.person,
                                iconColor: Colors.green,
                                title: 'Profil parent',
                                subtitle: fp.activeParent ?? 'Non défini',
                                trailing: const Icon(Icons.edit,
                                    color: Colors.white38, size: 18),
                              ),
                            ),
                          ],
                        ),

                        // Section 2: Security
                        _buildAnimatedSection(
                          index: 2,
                          title: '🔒 Sécurité',
                          children: [
                            TvFocusWrapper(
                              onTap: () => _showPinDialog(pin),
                              child: _GlassSettingsTile(
                                icon: Icons.lock,
                                iconColor: Colors.amber,
                                title: 'PIN parental',
                                subtitle: pin.hasPin
                                    ? 'Activé'
                                    : 'Non configuré',
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: pin.hasPin
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pin.hasPin ? 'ON' : 'OFF',
                                    style: TextStyle(
                                      color: pin.hasPin
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Section 3: Danger zone
                        _buildAnimatedSection(
                          index: 3,
                          title: '⚠️ Zone Danger',
                          isDanger: true,
                          children: [
                            AnimatedBuilder(
                              animation: _shakeAnim,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset:
                                      Offset(_shakeAnim.value, 0),
                                  child: child,
                                );
                              },
                              child: TvFocusWrapper(
                                onTap: () {
                                  _dangerShakeController.forward(
                                      from: 0.0);
                                  _showResetConfirm(fp, 'scores');
                                },
                                child: const _GlassSettingsTile(
                                  icon: Icons.refresh,
                                  iconColor: Colors.orange,
                                  title: 'Réinitialiser les scores',
                                  subtitle:
                                      'Remet tous les scores à zéro',
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _shakeAnim,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset:
                                      Offset(_shakeAnim.value, 0),
                                  child: child,
                                );
                              },
                              child: TvFocusWrapper(
                                onTap: () {
                                  _dangerShakeController.forward(
                                      from: 0.0);
                                  _showResetConfirm(fp, 'history');
                                },
                                child: const _GlassSettingsTile(
                                  icon: Icons.delete_forever,
                                  iconColor: Colors.red,
                                  title: 'Effacer l\'historique',
                                  subtitle:
                                      'Supprime toutes les activités',
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Section 4: About
                        _buildAnimatedSection(
                          index: 4,
                          title: 'ℹ️ À propos',
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Spinning logo
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 6.2832),
                                    duration:
                                        const Duration(milliseconds: 2000),
                                    builder: (context, value, child) {
                                      return Transform.rotate(
                                        angle: value,
                                        child: child,
                                      );
                                    },
                                    child: const Text('👨‍👩‍👧‍👦',
                                        style: TextStyle(fontSize: 40)),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Family Points TV',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Text('v4.9.0',
                                      style: TextStyle(
                                          color: Colors.white38)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${fp.children.length} enfant${fp.children.length > 1 ? 's' : ''} enregistré${fp.children.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSection({
    required int index,
    required String title,
    required List<Widget> children,
    bool isDanger = false,
  }) {
    final delay = index * 0.15;

    return AnimatedBuilder(
      animation: _sectionController,
      builder: (context, child) {
        final progress =
            ((_sectionController.value - delay) / (1.0 - delay))
                .clamp(0.0, 1.0);
        final curved = Curves.easeOutCubic.transform(progress);

        return Transform.translate(
          offset: Offset(0, 30 * (1 - curved)),
          child: Opacity(opacity: curved, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlassSectionTitle(title: title, isDanger: isDanger),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showAccentColorPicker(ThemeProvider theme) {
    final colors = [
      Colors.cyan,
      Colors.blue,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.teal,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Couleur d\'accent',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 300 + i * 80),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                          scale: value, child: child);
                    },
                    child: TvFocusWrapper(
                      onTap: () {
                        theme.setAccentColor(c);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.accentColor == c
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: c.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditParentDialog(FamilyProvider fp) {
    final controller = TextEditingController(text: fp.activeParent ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Profil parent',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Nom du parent',
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.cyan),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  fp.setActiveParent(controller.text.trim());
                }
                Navigator.pop(context);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _showPinDialog(PinProvider pin) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            pin.hasPin ? 'Modifier le PIN' : 'Créer un PIN',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '• • • •',
                  hintStyle: const TextStyle(color: Colors.white24),
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.cyan.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.cyan),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (pin.hasPin) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    pin.removePin();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  label: const Text('Supprimer le PIN',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.length == 4) {
                  pin.setPin(controller.text);
                  Navigator.pop(context);
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirm(FamilyProvider fp, String type) {
    final isScore = type == 'scores';
    showDialog(
      context: context,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber,
                    color: Colors.red[400], size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isScore
                        ? 'Réinitialiser les scores ?'
                        : 'Effacer l\'historique ?',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Text(
              isScore
                  ? 'Tous les scores seront remis à zéro. Cette action est irréversible.'
                  : 'Tout l\'historique sera supprimé. Cette action est irréversible.',
              style: const TextStyle(color: Colors.white54),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (isScore) {
                    fp.resetAllScores();
                  } else {
                    fp.clearAllHistory();
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isScore
                          ? '✅ Scores réinitialisés'
                          : '✅ Historique effacé'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Helper widgets ───

class _GlassSectionTitle extends StatelessWidget {
  final String title;
  final bool isDanger;
  const _GlassSectionTitle(
      {required this.title, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          color: isDanger ? Colors.red[300] : Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _GlassSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _GlassSettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.15),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
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
