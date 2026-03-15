import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/note_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class NotesScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const NotesScreen({super.key, required this.childId, required this.childName});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
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
                    GlowIcon(icon: Icons.sticky_note_2_rounded, color: const Color(0xFFFFD740), size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NeonText(
                            text: 'Notes',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            glowIntensity: 0.2,
                          ),
                          Text(
                            widget.childName,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Input area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Ecrire une note...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: GlowIcon(icon: Icons.edit_rounded, size: 20, color: primary),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primary.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _addNote,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.7)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12)],
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),

              // Notes list
              Expanded(
                child: Consumer<FamilyProvider>(
                  builder: (context, provider, _) {
                    final notes = provider.getNotesForChild(widget.childId);
                    if (notes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey[700]),
                            const SizedBox(height: 16),
                            NeonText(text: 'Aucune note', fontSize: 16, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Ajoutez des notes pour ${widget.childName}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: notes.length,
                      itemBuilder: (_, i) {
                        final note = notes[i];
                        return _buildNoteCard(note, provider, primary);
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

  void _addNote() {
    if (_noteController.text.trim().isEmpty) return;
    context.read<FamilyProvider>().addNote(
          widget.childId,
          _noteController.text.trim(),
        );
    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  Widget _buildNoteCard(NoteModel note, FamilyProvider provider, Color primary) {
    final timeStr =
        '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} ${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFF1744).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFFF1744)),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0D1B2A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1744)),
                SizedBox(width: 8),
                Text('Supprimer ?', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text('Supprimer cette note ?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => provider.removeNote(note.id),
      child: GlassCard(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        borderRadius: 16,
        borderColor: note.isPinned ? const Color(0xFFFFD740).withValues(alpha: 0.3) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (note.isPinned) ...[
                  Icon(Icons.push_pin_rounded, size: 14, color: const Color(0xFFFFD740)),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    note.authorName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                  color: const Color(0xFF162033),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.zero,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                              size: 18, color: const Color(0xFFFFD740)),
                          const SizedBox(width: 8),
                          Text(note.isPinned ? 'Desepingler' : 'Epingler',
                              style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Modifier', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, size: 18, color: Color(0xFFFF1744)),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: Color(0xFFFF1744))),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'pin') provider.toggleNotePin(note.id);
                    if (v == 'edit') _showEditDialog(note);
                    if (v == 'delete') provider.removeNote(note.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(note.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
            const SizedBox(height: 8),
            Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(NoteModel note) {
    final editCtrl = TextEditingController(text: note.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const NeonText(text: 'Modifier la note', fontSize: 18, color: Colors.white),
        content: TextField(
          controller: editCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (editCtrl.text.trim().isNotEmpty) {
                context.read<FamilyProvider>().updateNote(note.id, editCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
