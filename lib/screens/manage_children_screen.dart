import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import 'notes_screen.dart';

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  static const _avatars = [
    '\u{1F466}', '\u{1F467}', '\u{1F476}', '\u{1F9D2}',
    '\u{1F471}', '\u{1F9D1}', '\u{1F478}', '\u{1F934}',
    '\u{1F9B8}', '\u{1F9B9}', '\u{1F9D9}', '\u{1F9DA}',
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 16)],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'add_child',
          onPressed: () => PinGuard.guardAction(context, () => _showAddDialog(context)),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GlowIcon(icon: Icons.people_alt_rounded, color: primary, size: 26),
                    const SizedBox(width: 10),
                    NeonText(text: 'Gerer les enfants', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, glowIntensity: 0.2),
                    const Spacer(),
                    Consumer<PinProvider>(
                      builder: (_, pin, __) {
                        if (pin.isPinSet) {
                          final color = pin.isParentMode ? const Color(0xFF00E676) : Colors.orange;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(pin.isParentMode ? Icons.lock_open : Icons.lock, size: 14, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  pin.isParentMode ? 'Parent' : 'Enfant',
                                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Consumer<FamilyProvider>(
                  builder: (context, provider, _) {
                    if (provider.children.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.child_care, size: 80, color: Colors.grey[700]),
                            const SizedBox(height: 16),
                            NeonText(text: 'Aucun enfant', fontSize: 18, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text('Ajoutez un enfant pour commencer', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: provider.children.length,
                      itemBuilder: (_, i) {
                        final child = provider.children[i];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + i * 100),
                          curve: Curves.easeOut,
                          builder: (_, v, w) => Opacity(
                            opacity: v.clamp(0.0, 1.0),
                            child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: w),
                          ),
                          child: GlassCard(
                            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                            padding: const EdgeInsets.all(14),
                            borderRadius: 16,
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.5)]),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 8)],
                                  ),
                                  child: Center(child: child.hasPhoto
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.memory(
                                        base64Decode(child.photoBase64),
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Text(
                                          child.avatar.isEmpty ? '\u{1F466}' : child.avatar,
                                          style: const TextStyle(fontSize: 26),
                                        ),
                                      ),
                                    )
                                  : Text(
                                    child.avatar.isEmpty ? '\u{1F466}' : child.avatar,
                                    style: const TextStyle(fontSize: 26),
                                  )),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                      Text(
                                        '${child.points} pts - ${child.levelTitle}',
                                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                                // Notes button
                                IconButton(
                                  icon: const Icon(Icons.sticky_note_2_rounded, color: Color(0xFFFFD740), size: 20),
                                  tooltip: 'Notes',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NotesScreen(childId: child.id, childName: child.name),
                                      ),
                                    );
                                  },
                                ),
                                PopupMenuButton(
                                  icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
                                  color: const Color(0xFF162033),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18, color: Colors.white70),
                                          SizedBox(width: 8),
                                          Text('Modifier', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'photo',
                                      child: Row(
                                        children: [
                                          Icon(Icons.camera_alt_rounded, size: 18, color: Color(0xFF00B0FF)),
                                          SizedBox(width: 8),
                                          Text('Photo', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: Color(0xFFFF1744)),
                                          SizedBox(width: 8),
                                          Text('Supprimer', style: TextStyle(color: Color(0xFFFF1744))),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      PinGuard.guardAction(context, () {
                                        _showEditDialog(context, child.id, child.name, child.avatar);
                                      });
                                    }
                                    if (v == 'photo') {
                                      PinGuard.guardAction(context, () {
                                        _pickPhoto(context, child.id);
                                      });
                                    }
                                    if (v == 'delete') {
                                      PinGuard.guardAction(context, () {
                                        _confirmDelete(context, provider, child.id, child.name);
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String selectedAvatar = '\u{1F466}';
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const NeonText(text: 'Ajouter un enfant', fontSize: 18, color: Colors.white),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Prenom',
                    prefixIcon: GlowIcon(icon: Icons.person, size: 20, color: primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Choisir un avatar', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _avatars.map((a) => GestureDetector(
                    onTap: () => setDialogState(() => selectedAvatar = a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selectedAvatar == a
                            ? primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: selectedAvatar == a
                            ? Border.all(color: primary, width: 2)
                            : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: selectedAvatar == a
                            ? [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 8)]
                            : null,
                      ),
                      child: Center(child: Text(a, style: const TextStyle(fontSize: 24))),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  context.read<FamilyProvider>().addChild(nameCtrl.text.trim(), selectedAvatar);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String id, String currentName, String currentAvatar) {
    final nameCtrl = TextEditingController(text: currentName);
    String selectedAvatar = currentAvatar.isEmpty ? '\u{1F466}' : currentAvatar;
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const NeonText(text: 'Modifier l\'enfant', fontSize: 18, color: Colors.white),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Prenom',
                    prefixIcon: GlowIcon(icon: Icons.person, size: 20, color: primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                const Text('Choisir un avatar', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _avatars.map((a) => GestureDetector(
                    onTap: () => setDialogState(() => selectedAvatar = a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selectedAvatar == a
                            ? primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: selectedAvatar == a
                            ? Border.all(color: primary, width: 2)
                            : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: selectedAvatar == a
                            ? [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 8)]
                            : null,
                      ),
                      child: Center(child: Text(a, style: const TextStyle(fontSize: 24))),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  context.read<FamilyProvider>().updateChild(id, nameCtrl.text.trim(), selectedAvatar);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FamilyProvider provider, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744)),
            const SizedBox(width: 8),
            Text('Supprimer $name ?', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text('Voulez-vous vraiment supprimer $name et toutes ses donnees ?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
            onPressed: () {
              provider.removeChild(id);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _pickPhoto(BuildContext context, String childId) {
    // Use file input for web/Android compatibility
    _showPhotoSourceDialog(context, childId);
  }

  void _showPhotoSourceDialog(BuildContext context, String childId) {
    final primary = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141833),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            NeonText(text: 'Choisir une photo', fontSize: 18, color: Colors.white),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOptionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galerie',
                  color: const Color(0xFF00B0FF),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFilePicker(childId);
                  },
                ),
                _photoOptionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Supprimer',
                  color: const Color(0xFFFF1744),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<FamilyProvider>().updateChildPhoto(childId, '');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Photo supprimee'),
                        backgroundColor: primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _photoOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8)],
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _openFilePicker(String childId) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        if (mounted) {
          context.read<FamilyProvider>().updateChildPhoto(childId, base64String);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Photo mise a jour !'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFFF1744),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }
}
