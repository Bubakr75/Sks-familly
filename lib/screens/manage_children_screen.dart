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
                    Gest<span class="cursor">█</span>
