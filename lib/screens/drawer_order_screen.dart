// lib/screens/drawer_order_screen.dart
//
// Écran de réorganisation du menu (drawer).
// Le parent peut glisser-déposer les items pour changer leur ordre.
// L'ordre est sauvegardé dans SharedPreferences.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/emerald_theme.dart';

class DrawerOrderScreen extends StatefulWidget {
  const DrawerOrderScreen({super.key});

  @override
  State<DrawerOrderScreen> createState() => _DrawerOrderScreenState();
}

class _DrawerOrderScreenState extends State<DrawerOrderScreen> {
  List<_DrawerItem> _items = [];

  // Items par défaut (dans l'ordre standard)
  static const _defaultItems = [
    _DrawerItem('notes', 'Notes Scolaires', Icons.school_rounded, Colors.orangeAccent),
    _DrawerItem('balance', 'Bonus et Penalites', Icons.monetization_on_rounded, Colors.greenAccent),
    _DrawerItem('balance2', 'Pénalité / Immunité', Icons.assignment_late_rounded, Colors.redAccent),
    _DrawerItem('tribunal', 'Tribunal', Icons.gavel_rounded, Colors.purpleAccent),
    _DrawerItem('penalty_immunity', 'Pénalité / Immunité', Icons.assignment_late_rounded, Colors.redAccent),
    _DrawerItem('checklist', 'Checklist du jour', Icons.checklist_rounded, Colors.purpleAccent),
    _DrawerItem('wheel', 'Roue des tâches', Icons.casino_rounded, Colors.deepPurpleAccent),
    _DrawerItem('gemini', 'Gemini AI', Icons.auto_awesome_rounded, Colors.cyanAccent),
    _DrawerItem('trades', 'Vente d\'immunites', Icons.sell_rounded, Colors.tealAccent),
    _DrawerItem('badges', 'Boutique', Icons.shopping_bag_rounded, Colors.yellowAccent),
    _DrawerItem('timeline', 'Timeline', Icons.timeline_rounded, Colors.cyanAccent),
    _DrawerItem('chores', 'Taches menageres', Icons.cleaning_services_rounded, Colors.purpleAccent),
    _DrawerItem('family', 'Famille', Icons.family_restroom_rounded, Colors.lightBlueAccent),
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('drawer_order');

    if (savedOrder != null && savedOrder.isNotEmpty) {
      // Reconstruire dans l'ordre sauvegardé
      final ordered = <_DrawerItem>[];
      for (final id in savedOrder) {
        final item = _defaultItems.where((i) => i.id == id).firstOrNull;
        if (item != null) ordered.add(item);
      }
      // Ajouter les items manquants (nouveaux)
      for (final item in _defaultItems) {
        if (!ordered.any((i) => i.id == item.id)) {
          ordered.add(item);
        }
      }
      setState(() => _items = ordered);
    } else {
      setState(() => _items = List.from(_defaultItems));
    }
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('drawer_order', _items.map((i) => i.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmeraldPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Réorganiser le menu', style: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: EmeraldPalette.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: EmeraldPalette.emerald, size: 28),
            onPressed: () {
              _saveOrder();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Ordre du menu enregistré'), backgroundColor: EmeraldPalette.emerald),
              );
            },
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: CircularProgressIndicator(color: EmeraldPalette.emerald))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  key: ValueKey(item.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: EmeraldPalette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: EmeraldPalette.glassBorder),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    title: Text(item.label, style: const TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#${index + 1}', style: TextStyle(color: EmeraldPalette.textMuted, fontSize: 12)),
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle_rounded, color: EmeraldPalette.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DrawerItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const _DrawerItem(this.id, this.label, this.icon, this.color);
}
