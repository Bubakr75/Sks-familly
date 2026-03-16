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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.people_alt_rounded, color: Color(0xFF00E5FF), size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: NeonText(text: 'Gerer les enfants', fontSize: 20, color: Colors.white),
                    ),
                    Consumer<PinProvider>(
                      builder: (_, pin, __) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pin.isParentMode
                              ? const Color(0xFF00E676).withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: pin.isParentMode
                                ? const Color(0xFF00E676).withValues(alpha: 0.3)
                                : Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              pin.isParentMode ? Icons.lock_open : Icons.lock,
                              size: 12,
                              color: pin.isParentMode ? const Color(0xFF00E676) : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pin.isParentMode ? 'Parent' : 'Enfant',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: pin.isParentMode ? const Color(0xFF00E676) : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<FamilyProvider>(
                  builder: (context, provider, _) {
                    if (provider.children.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GlowIcon(icon: Icons.people_outline, size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text('Aucun enfant', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                            const SizedBox(height: 8),
                            Text('Appuyez sur + pour ajouter', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: provider.children.length,
                      itemBuilder: (_, i) {
                        final child = provider.children[i];
                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              // Avatar or photo
                              Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: primary.withValues(alpha: 0.12),
                                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                                ),
                                child: child.photoBase64 != null && child.photoBase64!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(13),
                                        child: Image.memory(base64Decode(child.photoBase64!), fit: BoxFit.cover, width: 50, height: 50,
                                          errorBuilder: (_, __, ___) => Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 26))),
                                        ),
                                      )
                                    : Center(child: Text(child.avatar.isEmpty ? '\u{1F466}' : child.avatar, style: const TextStyle(fontSize: 26))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(child.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text('${child.points} pts', style: TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('Nv.${child.level}', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Notes button
                              IconButton(
                                icon: Icon(Icons.sticky_note_2_rounded, color: Colors.grey[500], size: 22),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => NotesScreen(childId: child.id, childName: child.name),
                                )),
                              ),
                              // Menu
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: Colors.grey[500]),
                                color: const Color(0xFF162033),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    PinGuard.guardAction(context, () => _showEditDialog(context, child));
                                  } else if (val == 'photo') {
                                    PinGuard.guardAction(context, () => _showPhotoOptions(context, child.id, provider));
                                  } else if (val == 'delete') {
                                    PinGuard.guardAction(context, () => _confirmDelete(context, child.id, child.name, provider));
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.white70), SizedBox(width: 8), Text('Modifier', style: TextStyle(color: Colors.white))])),
                                  const PopupMenuItem(value: 'photo', child: Row(children: [Icon(Icons.camera_alt, size: 18, color: Colors.white70), SizedBox(width: 8), Text('Photo', style: TextStyle(color: Colors.white))])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Color(0xFFFF1744)), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Color(0xFFFF1744)))])),
                                ],
                              ),
                            ],
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
    String selectedAvatar = _avatars[0];
    String? photoBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF00E5FF)),
              SizedBox(width: 10),
              Text('Ajouter un enfant', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Photo button
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, imageQuality: 70);
                    if (img != null) {
                      final bytes = await img.readAsBytes();
                      setState(() => photoBase64 = base64Encode(bytes));
                    }
                  },
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                    ),
                    child: photoBase64 != null
                        ? ClipOval(child: Image.memory(base64Decode(photoBase64!), fit: BoxFit.cover, width: 80, height: 80))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_rounded, color: Color(0xFF00E5FF), size: 28),
                              const SizedBox(height: 4),
                              Text('Photo', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Prenom',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerLeft, child: Text('Avatar', style: TextStyle(color: Colors.white70, fontSize: 13))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _avatars.map((a) {
                    final isSelected = selectedAvatar == a;
                    return GestureDetector(
                      onTap: () => setState(() => selectedAvatar = a),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Center(child: Text(a, style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: Colors.grey[400]))),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final provider = context.read<FamilyProvider>();
                  provider.addChild(nameCtrl.text.trim(), selectedAvatar);
                  if (photoBase64 != null) {
                    final children = provider.children;
                    final newChild = children.last;
                    provider.updateChildPhoto(newChild.id, photoBase64!);
                  }
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

  void _showEditDialog(BuildContext context, dynamic child) {
    final nameCtrl = TextEditingController(text: child.name);
    String selectedAvatar = child.avatar;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: Color(0xFF00E5FF)),
              SizedBox(width: 10),
              Text('Modifier', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Prenom',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _avatars.map((a) {
                    final isSelected = selectedAvatar == a;
                    return GestureDetector(
                      onTap: () => setState(() => selectedAvatar = a),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Center(child: Text(a, style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: Colors.grey[400]))),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  context.read<FamilyProvider>().updateChild(child.id, nameCtrl.text.trim(), selectedAvatar);
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

  void _showPhotoOptions(BuildContext context, String childId, FamilyProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Photo de profil', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOptionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galerie',
                  color: const Color(0xFF7C4DFF),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, imageQuality: 70);
                    if (img != null) {
                      final bytes = await img.readAsBytes();
                      final b64 = base64Encode(bytes);
                      provider.updateChildPhoto(childId, b64);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Photo mise a jour'),
                            backgroundColor: const Color(0xFF00E676),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    }
                  },
                ),
                _photoOptionButton(
                  icon: Icons.delete_rounded,
                  label: 'Supprimer',
                  color: const Color(0xFFFF1744),
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.updateChildPhoto(childId, '');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _photoOptionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String childId, String childName, FamilyProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744)),
            SizedBox(width: 8),
            Text('Supprimer ?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text('Supprimer $childName et toutes ses donnees ?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: Colors.grey[400]))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
            onPressed: () {
              provider.removeChild(childId);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
