import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/emerald_theme.dart';
import '../models/parent_profile.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';
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
    with SingleTickerProviderStateMixin {
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
    return AnimatedBackground(
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
                      const SizedBox(height: 30),
                      // Logo + titre
                      _buildHeader(),
                      const SizedBox(height: 40),

                      // Titre "Qui est-ce ?"
                      Text(
                        'Qui est-ce ?',
                        style: EmeraldTypography.display.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choisissez votre profil pour continuer',
                        style: EmeraldTypography.caption.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 30),

                      // Grille des profils parents
                      if (profiles.isEmpty)
                        _buildEmptyProfiles(fp)
                      else
                        _buildProfilesGrid(fp, profiles),

                      const SizedBox(height: 24),

                      // Séparateur
                      Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color: EmeraldPalette.glassBorder,
                                  thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OU',
                                style: EmeraldTypography.label
                                    .copyWith(fontSize: 10)),
                          ),
                          Expanded(
                              child: Divider(
                                  color: EmeraldPalette.glassBorder,
                                  thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 24),

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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: EmeraldPalette.emeraldGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: EmeraldPalette.emerald.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.family_restroom_rounded,
              color: Colors.white, size: 32),
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) => EmeraldPalette.emeraldGradient
              .createShader(bounds),
          child: const Text(
            'SKS Family',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProfiles(FamilyProvider fp) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EmeraldPalette.glassBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.person_add_rounded,
              size: 40, color: EmeraldPalette.emeraldLight),
          const SizedBox(height: 12),
          Text('Aucun profil parent',
              style: EmeraldTypography.heading.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('Créez des profils pour les parents',
              style: EmeraldTypography.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _openManageProfiles(fp),
            icon: Icon(Icons.add_rounded, color: EmeraldPalette.emeraldLight),
            label: Text('Créer un profil',
                style: TextStyle(color: EmeraldPalette.emeraldLight)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesGrid(FamilyProvider fp, List<ParentProfile> profiles) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.85,
      children: [
        ...profiles.map((p) => _buildProfileCard(p)),
        // Carte "Ajouter"
        _buildAddCard(fp),
      ],
    );
  }

  Widget _buildProfileCard(ParentProfile profile) {
    return TvFocusWrapper(
      onTap: () => _selectProfile(profile),
      child: Container(
        decoration: BoxDecoration(
          color: EmeraldPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: EmeraldPalette.emerald.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatar(profile, 36),
            const SizedBox(height: 12),
            Text(
              profile.name,
              style: EmeraldTypography.heading.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Parent',
              style: EmeraldTypography.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCard(FamilyProvider fp) {
    return TvFocusWrapper(
      onTap: () => _openManageProfiles(fp),
      child: Container(
        decoration: BoxDecoration(
          color: EmeraldPalette.surfaceLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: EmeraldPalette.glassBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded,
                size: 32, color: EmeraldPalette.emeraldLight),
            const SizedBox(height: 8),
            Text(
              'Gérer les\nprofils',
              style: EmeraldTypography.caption.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildAvatar(ParentProfile profile, double radius) {
    if (profile.hasPhoto) {
      try {
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: EmeraldPalette.emerald.withValues(alpha: 0.5),
                width: 2),
          ),
          child: ClipOval(
            child: Image.memory(
              Uri.parse(profile.photoBase64!).data!.contentAsBytes(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _buildInitialAvatar(profile, radius),
            ),
          ),
        );
      } catch (_) {}
    }
    return _buildInitialAvatar(profile, radius);
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
        border: Border.all(
            color: EmeraldPalette.emerald.withValues(alpha: 0.4), width: 1.5),
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

  // ─── Actions ──────────────────────────────────────────────────────────

  void _selectProfile(ParentProfile profile) {
    final pin = context.read<PinProvider>();
    if (!pin.isPinSet) {
      // Pas de PIN défini → on entre directement
      pin.unlockParentModeWithProfile(profile);
      _navigateToHome();
      return;
    }

    // PIN défini → on affiche l'écran PIN
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
        content: const Text('Aucun enfant enregistré.'),
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
      MaterialPageRoute(
          builder: (_) => const ManageParentProfilesScreen()),
    );
  }
}
