import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../config/emerald_theme.dart';
import '../models/parent_profile.dart';
import '../providers/family_provider.dart';

class ManageParentProfilesScreen extends StatefulWidget {
  const ManageParentProfilesScreen({super.key});

  @override
  State<ManageParentProfilesScreen> createState() =>
      _ManageParentProfilesScreenState();
}

class _ManageParentProfilesScreenState extends State<ManageParentProfilesScreen> {
  @override
  Widget build(BuildContext context) {
    return EmeraldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Profils Parents',
              style: EmeraldTypography.heading.copyWith(fontSize: 20)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Consumer<FamilyProvider>(
          builder: (context, fp, _) {
            final profiles = fp.parentProfiles;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: EmeraldPalette.emerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: EmeraldPalette.emerald.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: EmeraldPalette.emeraldLight, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Creez un profil pour chaque parent (papa, maman, tata...). Chaque profil a sa photo et son nom.',
                          style: EmeraldTypography.caption.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Profils
                if (profiles.isEmpty)
                  _buildEmptyState()
                else
                  ...profiles.map((p) => _buildProfileCard(fp, p)),

                const SizedBox(height: 16),

                // Bouton ajouter
                _buildAddButton(fp),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: EmeraldPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EmeraldPalette.glassBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: EmeraldPalette.emeraldGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_add_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Aucun profil',
              style: EmeraldTypography.heading.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text('Ajoutez votre premier profil ci-dessous',
              style: EmeraldTypography.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(FamilyProvider fp, ParentProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EmeraldPalette.surface,
            EmeraldPalette.surfaceLow,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: EmeraldPalette.emerald.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          _buildAvatar(profile, 28),
          const SizedBox(width: 14),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name,
                    style: EmeraldTypography.heading.copyWith(fontSize: 16)),
                if (profile.hasSecurityQuestion)
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 12, color: EmeraldPalette.textMuted),
                      const SizedBox(width: 4),
                      Text('Securise',
                          style: EmeraldTypography.caption.copyWith(
                              fontSize: 10,
                              color: EmeraldPalette.textMuted)),
                    ],
                  ),
              ],
            ),
          ),
          // Actions
          IconButton(
            icon: Icon(Icons.edit_rounded,
                color: EmeraldPalette.emeraldLight, size: 20),
            onPressed: () => _showEditDialog(fp, profile: profile),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: EmeraldPalette.error, size: 20),
            onPressed: () => _confirmDelete(fp, profile),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(FamilyProvider fp) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showEditDialog(fp),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un profil'),
        style: ElevatedButton.styleFrom(
          backgroundColor: EmeraldPalette.emerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  void _showEditDialog(FamilyProvider fp, {ParentProfile? profile}) {
    final isEdit = profile != null;
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final questionCtrl =
        TextEditingController(text: profile?.securityQuestion ?? '');
    final answerCtrl = TextEditingController();
    String? photoBase64 = profile?.photoBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          backgroundColor: EmeraldPalette.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                color: EmeraldPalette.emeraldLight,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(isEdit ? 'Modifier le profil' : 'Nouveau profil',
                  style: EmeraldTypography.heading.copyWith(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final xfile = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 200,
                      maxHeight: 200,
                      imageQuality: 50,
                    );
                    if (xfile != null) {
                      final bytes = await xfile.readAsBytes();
                      final b64 = Uri.dataFromBytes(bytes, mimeType: 'image/jpeg').toString();
                      setInnerState(() => photoBase64 = b64);
                    }
                  },
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: photoBase64 == null
                          ? LinearGradient(colors: [
                              EmeraldPalette.emerald.withValues(alpha: 0.15),
                              EmeraldPalette.emeraldDark.withValues(alpha: 0.1),
                            ])
                          : null,
                      border: Border.all(
                          color: EmeraldPalette.emerald.withValues(alpha: 0.4),
                          width: 2),
                    ),
                    child: photoBase64 != null
                        ? ClipOval(
                            child: Image.memory(
                              Uri.parse(photoBase64!).data!.contentAsBytes(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.person,
                                  color: EmeraldPalette.emeraldLight, size: 36),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_rounded,
                                  color: EmeraldPalette.emeraldLight, size: 28),
                              const SizedBox(height: 2),
                              Text('Photo',
                                  style: EmeraldTypography.caption
                                      .copyWith(fontSize: 9)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: EmeraldTypography.body,
                  decoration: InputDecoration(
                    labelText: 'Nom (Papa, Maman, Tata...)',
                    labelStyle: EmeraldTypography.caption,
                    prefixIcon: Icon(Icons.person_outline_rounded,
                        color: EmeraldPalette.emeraldLight, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: questionCtrl,
                  style: EmeraldTypography.body,
                  decoration: InputDecoration(
                    labelText: 'Question de securite (optionnel)',
                    labelStyle: EmeraldTypography.caption,
                    prefixIcon: Icon(Icons.help_outline_rounded,
                        color: EmeraldPalette.emeraldLight, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: answerCtrl,
                  style: EmeraldTypography.body,
                  decoration: InputDecoration(
                    labelText: 'Reponse (optionnel)',
                    labelStyle: EmeraldTypography.caption,
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: EmeraldPalette.emeraldLight, size: 20),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: EmeraldTypography.caption),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: const Text('Veuillez entrer un nom'),
                    backgroundColor: EmeraldPalette.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                  return;
                }

                String? answerHash;
                if (questionCtrl.text.trim().isNotEmpty &&
                    answerCtrl.text.trim().isNotEmpty) {
                  answerHash = answerCtrl.text.trim().hashCode.toString();
                }

                final newProfile = ParentProfile(
                  id: profile?.id ?? const Uuid().v4(),
                  name: name,
                  photoBase64: photoBase64,
                  securityQuestion: questionCtrl.text.trim().isEmpty
                      ? null
                      : questionCtrl.text.trim(),
                  securityAnswerHashed: answerHash,
                  createdAt: profile?.createdAt ?? DateTime.now(),
                );

                try {
                  await fp.saveParentProfile(newProfile);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Row(children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(isEdit ? 'Profil modifie !' : 'Profil cree !'),
                      ]),
                      backgroundColor: EmeraldPalette.emerald,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ));
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: EmeraldPalette.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: EmeraldPalette.emerald,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(FamilyProvider fp, ParentProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EmeraldPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Supprimer ?',
            style: EmeraldTypography.heading.copyWith(fontSize: 18)),
        content: Text('Supprimer le profil "${profile.name}" ?',
            style: EmeraldTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: EmeraldTypography.caption),
          ),
          ElevatedButton(
            onPressed: () async {
              await fp.deleteParentProfile(profile.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EmeraldPalette.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
