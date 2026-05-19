import 'package:flutter/material.dart';
import '../widgets/tv_focus_wrapper.dart';
import '../utils/tv_detector.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/note_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_widgets.dart';
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
  bool get isTV => TvDetector.isTV;

  @override
  void dispose() { _noteController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(isTV ? 28 : 20, isTV ? 20 : 16, isTV ? 28 : 20, 8),
              child: Row(children: [
                TvFocusWrapper(
                  autofocus: isTV,
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: isTV ? 48 : 40, height: isTV ? 48 : 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.06),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Icon(Icons.arrow_back_rounded, color: Colors.white70, size: isTV ? 24 : 20),
                  ),
                ),
                SizedBox(width: isTV ? 16 : 14),
                GlowIcon(icon: Icons.sticky_note_2_rounded, color: const Color(0xFFFFD740), size: isTV ? 30 : 26),
                SizedBox(width: isTV ? 12 : 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    NeonText(text: 'Notes', fontSize: isTV ? 26 : 20, fontWeight: FontWeight.w800, color: Colors.white),
                    Text(widget.childName, style: TextStyle(color: Colors.grey[500], fontSize: isTV ? 16 : 13)),
                  ]),
                ),
              ]),
            ),
            // Zone de saisie
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isTV ? 24 : 16, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: TvTextField(
                    controller: _noteController,
                    style: TextStyle(color: Colors.white, fontSize: isTV ? 18 : 14),
                    maxLines: 3, minLines: 1,
                    decoration: InputDecoration(
                      hintText: '\u00C9crire une note...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: isTV ? 16 : 14),
                      prefixIcon: GlowIcon(icon: Icons.edit_rounded, size: isTV ? 24 : 20, color: primary),
                      filled: true, fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: primary.withOpacity(0.5))),
                    ),
                  ),
                ),
                SizedBox(width: isTV ? 14 : 10),
                TvFocusWrapper(
                  onTap: _addNote,
                  child: Container(
                    width: isTV ? 56 : 48, height: isTV ? 56 : 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primary, primary.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 12)],
                    ),
                    child: Icon(Icons.send_rounded, color: Colors.white, size: isTV ? 26 : 22),
                  ),
                ),
              ]),
            ),
            // Liste des notes
            Expanded(
              child: Consumer<FamilyProvider>(
                builder: (context, provider, _) {
                  final notes = provider.getNotesForChild(widget.childId);
                  if (notes.isEmpty) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.note_alt_outlined, size: isTV ? 80 : 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      NeonText(text: 'Aucune note', fontSize: isTV ? 22 : 16, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('Ajoutez des notes pour ${widget.childName}',
                        style: TextStyle(color: Colors.grey[600], fontSize: isTV ? 16 : 13)),
                    ]));
                  }
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(isTV ? 24 : 16, 4, isTV ? 24 : 16, 100),
                    itemCount: notes.length,
                    itemBuilder: (_, i) => _buildNoteCard(notes[i], provider, primary),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _addNote() {
    if (_noteController.text.trim().isEmpty) return;
    context.read<FamilyProvider>().addNote(widget.childId, _noteController.text.trim());
    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  Widget _buildNoteCard(NoteModel note, FamilyProvider provider, Color primary) {
    final timeStr = '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} '
        '${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}';

    return TvFocusWrapper(
      onTap: () => _showNoteActions(note, provider),
      child: GlassCard(
        margin: EdgeInsets.symmetric(vertical: isTV ? 6 : 4),
        padding: EdgeInsets.all(isTV ? 18 : 14),
        borderRadius: 16,
        borderColor: note.isPinned ? const Color(0xFFFFD740).withOpacity(0.3) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (note.isPinned) ...[
              Icon(Icons.push_pin_rounded, size: isTV ? 18 : 14, color: const Color(0xFFFFD740)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(note.authorName, style: TextStyle(
                fontSize: isTV ? 16 : 12, fontWeight: FontWeight.w600, color: primary.withOpacity(0.8))),
            ),
            if (!isTV)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                color: const Color(0xFF162033),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: EdgeInsets.zero,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'pin', child: Row(children: [
                    Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                      size: 18, color: const Color(0xFFFFD740)),
                    const SizedBox(width: 8),
                    Text(note.isPinned ? 'D\u00E9s\u00E9pingler' : '\u00C9pingler',
                      style: const TextStyle(color: Colors.white)),
                  ])),
                  const PopupMenuItem(value: 'edit', child: Row(children: [
                    Icon(Icons.edit_rounded, size: 18, color: Colors.white70),
                    SizedBox(width: 8),
                    Text('Modifier', style: TextStyle(color: Colors.white)),
                  ])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [
                    Icon(Icons.delete_rounded, size: 18, color: Color(0xFFFF1744)),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: Color(0xFFFF1744))),
                  ])),
                ],
                onSelected: (v) {
                  if (v == 'pin') provider.toggleNotePin(note.id);
                  if (v == 'edit') _showEditDialog(note);
                  if (v == 'delete') provider.removeNote(note.id);
                },
              )
            else
              Icon(Icons.chevron_right, color: Colors.white24, size: isTV ? 24 : 18),
          ]),
          SizedBox(height: isTV ? 10 : 8),
          Text(note.text, style: TextStyle(color: Colors.white, fontSize: isTV ? 20 : 15, height: 1.4)),
          SizedBox(height: isTV ? 10 : 8),
          Text(timeStr, style: TextStyle(fontSize: isTV ? 14 : 11, color: Colors.grey[600])),
        ]),
      ),
    );
  }

  void _showNoteActions(NoteModel note, FamilyProvider provider) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: isTV ? 120 : 40, vertical: isTV ? 60 : 40),
      title: Text('Actions', style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TvFocusWrapper(
          autofocus: true,
          onTap: () { Navigator.pop(ctx); provider.toggleNotePin(note.id); },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 12),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: Colors.amber, size: isTV ? 22 : 18),
              const SizedBox(width: 8),
              Text(note.isPinned ? 'D\u00E9s\u00E9pingler' : '\u00C9pingler',
                style: TextStyle(color: Colors.amber, fontSize: isTV ? 18 : 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        SizedBox(height: isTV ? 12 : 8),
        TvFocusWrapper(
          onTap: () { Navigator.pop(ctx); _showEditDialog(note); },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.edit_rounded, color: Colors.blue, size: isTV ? 22 : 18),
              const SizedBox(width: 8),
              Text('Modifier', style: TextStyle(color: Colors.blue, fontSize: isTV ? 18 : 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        SizedBox(height: isTV ? 12 : 8),
        TvFocusWrapper(
          onTap: () { Navigator.pop(ctx); _confirmDelete(note, provider); },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: isTV ? 16 : 12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.delete_rounded, color: Colors.red, size: isTV ? 22 : 18),
              const SizedBox(width: 8),
              Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: isTV ? 18 : 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]),
      actions: [
        TvFocusWrapper(
          onTap: () => Navigator.pop(ctx),
          child: TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: TextStyle(color: Colors.white54, fontSize: isTV ? 18 : 14))),
        ),
      ],
    ));
  }

  void _confirmDelete(NoteModel note, FamilyProvider provider) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        Icon(Icons.warning_amber_rounded, color: const Color(0xFFFF1744), size: isTV ? 28 : 24),
        const SizedBox(width: 8),
        Text('Supprimer ?', style: TextStyle(color: Colors.white, fontSize: isTV ? 24 : 18)),
      ]),
      content: Text('Supprimer cette note ?', style: TextStyle(color: Colors.white70, fontSize: isTV ? 18 : 14)),
      actions: [
        TvFocusWrapper(
          onTap: () => Navigator.pop(ctx),
          child: TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(fontSize: isTV ? 18 : 14))),
        ),
        TvFocusWrapper(
          onTap: () { Navigator.pop(ctx); provider.removeNote(note.id); },
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF1744),
              padding: EdgeInsets.symmetric(horizontal: isTV ? 24 : 16, vertical: isTV ? 14 : 10)),
            onPressed: () { Navigator.pop(ctx); provider.removeNote(note.id); },
            child: Text('Supprimer', style: TextStyle(fontSize: isTV ? 18 : 14)),
          ),
        ),
      ],
    ));
  }

  void _showEditDialog(NoteModel note) {
    final editCtrl = TextEditingController(text: note.text);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(horizontal: isTV ? 100 : 24, vertical: isTV ? 40 : 24),
      title: NeonText(text: 'Modifier la note', fontSize: isTV ? 24 : 18, color: Colors.white),
      content: TvTextField(
        controller: editCtrl,
        style: TextStyle(color: Colors.white, fontSize: isTV ? 18 : 14),
        maxLines: 5,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
      ),
      actions: [
        TvFocusWrapper(
          onTap: () => Navigator.pop(ctx),
          child: TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(fontSize: isTV ? 18 : 14))),
        ),
        TvFocusWrapper(
          onTap: () {
            if (editCtrl.text.trim().isNotEmpty) {
              context.read<FamilyProvider>().updateNote(note.id, editCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
          child: FilledButton(
            onPressed: () {
              if (editCtrl.text.trim().isNotEmpty) {
                context.read<FamilyProvider>().updateNote(note.id, editCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: isTV ? 24 : 16, vertical: isTV ? 14 : 10)),
            child: Text('Enregistrer', style: TextStyle(fontSize: isTV ? 18 : 14)),
          ),
        ),
      ],
    ));
  }
}