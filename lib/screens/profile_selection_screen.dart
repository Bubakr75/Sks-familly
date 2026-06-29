import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/emerald_theme.dart';
import '../models/parent_profile.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/tv_focus_wrapper.dart';
import 'pin_verification_screen.dart';
import 'home_screen.dart';
import 'manage_parent_profiles_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EmeraldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Consumer<FamilyProvider>(
            builder: (context, fp, _) {
              final profiles = fp.parentProfiles;
              return FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Logo + titre
                      _buildHeader(),
                      const SizedBox(height: 40),

                      // Titre "Qui es-tu ?"
                      Text(
                        'Qui es-tu ?',
                        style: EmeraldTypography.display.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choisis ton profil pour continuer',
                        style: EmeraldTypography.caption.copyWith(
                          fontSize: 13,
                          color: EmeraldPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Profils parents (cartes premium)
                      if (profiles.isNotEmpty) ...[
                        ...profiles.map((p) => _buildPremiumProfileCard(p)),
                        const SizedBox(height: 12),
                        // Bouton gerer les profils
                        _buildManageButton(fp),
                      ] else ...[
                        _buildWelcomeCard(fp),
                      ],

                      const SizedBox(height: 20),

                      // Separateur
                      _buildSeparator(),
                      const SizedBox(height: 20),

                      // Bouton Mode Parent (PIN direct)
                      _buildParentModeButton(),
                      const SizedBox(height: 12),

                      // Bouton Mode Enfant
                      _buildChildModeButton(fp),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // === HEADER ===
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: EmeraldPalette.emeraldGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: EmeraldPalette.emerald.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(Icons.family_restroom_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 14),
        ShaderMask(
          shaderCallback: (bounds) =>
              EmeraldPalette.emeraldGradient.createShader(bounds),
          child: const Text(
            'SKS Family',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  // === CARTE PROFIL PREMIUM ===
  Widget _buildPremiumProfileCard(ParentProfile profile) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: TvFocusWrapper(
          onTap: () => _selectProfile(profile),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  EmeraldPalette.surface,
                  EmeraldPalette.surfaceLow,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: EmeraldPalette.emerald.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: EmeraldPalette.emerald.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar premium avec halo
                _buildPremiumAvatar(profile, 32),
                const SizedBox(width: 16),
                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: EmeraldTypography.heading.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.shield_rounded,
                              size: 12,
                              color: EmeraldPalette.emeraldLight),
                          const SizedBox(width: 4),
                          Text(
                            'Profil Parent',
                            style: EmeraldTypography.caption.copyWith(
                              fontSize: 11,
                              color: EmeraldPalette.emeraldLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Fleche
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EmeraldPalette.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: EmeraldPalette.emeraldLight,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === AVATAR PREMIUM ===
  Widget _buildPremiumAvatar(ParentProfile profile, double radius) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo exterieur
        Container(
          width: radius * 2 + 12,
          height: radius * 2 + 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                EmeraldPalette.emerald.withValues(alpha: 0.3),
                EmeraldPalette.emerald.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        // Avatar
        if (profile.hasPhoto)
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: EmeraldPalette.emerald.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.memory(
                Uri.parse(profile.photoBase64!).data!.contentAsBytes(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildInitialAvatar(profile, radius),
              ),
            ),
          )
        else
          _buildInitialAvatar(profile, radius),
        // Bordure
        Container(
          width: radius * 2 + 2,
          height: radius * 2 + 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: EmeraldPalette.emerald.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialAvatar(ParentProfile profile, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            EmeraldPalette.emerald.withValues(alpha: 0.4),
            EmeraldPalette.emeraldDark.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Center(
        child: Text(
          profile.initial,
          style: TextStyle(
            color: EmeraldPalette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.7,
          ),
        ),
      ),
    );
  }

  // === BOUTON GERER LES PROFILS ===
  Widget _buildManageButton(FamilyProvider fp) {
    return TextButton.icon(
      onPressed: () => _openManageProfiles(fp),
      icon: Icon(Icons.settings_rounded,
          size: 16, color: EmeraldPalette.textMuted),
      label: Text(
        'Gerer les profils',
        style: EmeraldTypography.caption.copyWith(
          fontSize: 12,
          color: EmeraldPalette.textMuted,
        ),
      ),
    );
  }

  // === CARTE WELCOME (aucun profil) ===
  Widget _buildWelcomeCard(FamilyProvider fp) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EmeraldPalette.surface,
            EmeraldPalette.surfaceLow,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: EmeraldPalette.emerald.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: EmeraldPalette.emerald.withValues(alpha: 0.1),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: EmeraldPalette.emeraldGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: EmeraldPalette.emerald.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(Icons.person_add_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Bienvenue !',
            style: EmeraldTypography.display.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Creez votre premier profil parent pour commencer.\nVous pourrez en ajouter d\'autres plus tard (maman, tata...).',
            style: EmeraldTypography.caption.copyWith(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openManageProfiles(fp),
              icon: const Icon(Icons.person_add_rounded, size: 22),
              label: const Text('Creer mon profil parent',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: EmeraldPalette.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === SEPARATEUR ===
  Widget _buildSeparator() {
    return Row(
      children: [
        Expanded(
            child: Divider(
                color: EmeraldPalette.glassBorder, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OU',
              style:
                  EmeraldTypography.label.copyWith(fontSize: 10)),
        ),
        Expanded(
            child: Divider(
                color: EmeraldPalette.glassBorder, thickness: 1)),
      ],
    );
  }

  // === BOUTON MODE PARENT ===
  Widget _buildParentModeButton() {
    return SizedBox(
      width: double.infinity,
      child: TvFocusWrapper(
        onTap: () => _enterParentMode(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                EmeraldPalette.gold.withValues(alpha: 0.2),
                EmeraldPalette.goldLight.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: EmeraldPalette.gold.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: EmeraldPalette.gold.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded,
                  color: EmeraldPalette.goldLight, size: 24),
              const SizedBox(width: 10),
              Text(
                'Mode Parent',
                style: EmeraldTypography.heading.copyWith(
                  fontSize: 16,
                  color: EmeraldPalette.goldLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.lock_rounded,
                  color: EmeraldPalette.goldLight, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // === BOUTON MODE ENFANT ===
  Widget _buildChildModeButton(FamilyProvider fp) {
    return SizedBox(
      width: double.infinity,
      child: TvFocusWrapper(
        onTap: () => _enterChildMode(fp),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: EmeraldPalette.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: EmeraldPalette.emerald.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.child_care_rounded,
                  color: EmeraldPalette.emeraldLight, size: 24),
              const SizedBox(width: 10),
              Text(
                'Mode Enfant',
                style: EmeraldTypography.heading.copyWith(
                  fontSize: 16,
                  color: EmeraldPalette.emeraldLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== ACTIONS =====

  void _enterParentMode() {
    final pin = context.read<PinProvider>();
    if (!pin.isPinSet) {
      pin.unlockParentMode();
      _navigateToHome();
      return;
    }
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PinVerificationScreen()),
    ).then((ok) {
      if (ok == true) {
        context.read<PinProvider>().unlockParentMode();
        _navigateToHome();
      }
    });
  }

  void _selectProfile(ParentProfile profile) {
    final pin = context.read<PinProvider>();
    if (!pin.isPinSet) {
      pin.unlockParentModeWithProfile(profile);
      _navigateToHome();
      return;
    }
    Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PinVerificationScreen()),
    ).then((ok) {
      if (ok == true) {
        context.read<PinProvider>().unlockParentModeWithProfile(profile);
        _navigateToHome();
      }
    });
  }

  void _enterChildMode(FamilyProvider fp) {
    if (fp.children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Aucun enfant enregistre.'),
        backgroundColor: EmeraldPalette.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    context.read<PinProvider>().enterChildMode();
    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _openManageProfiles(FamilyProvider fp) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageParentProfilesScreen()),
    );
  }
}
