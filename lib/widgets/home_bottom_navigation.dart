import 'package:flutter/material.dart';
import '../config/emerald_theme.dart';

class HomeBottomNavigation extends StatelessWidget {
  const HomeBottomNavigation(
      {super.key, required this.selectedIndex, required this.onSelectTab});

  final int selectedIndex;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: EmeraldPalette.surface,
        indicatorColor: EmeraldPalette.emerald.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: onSelectTab,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle_rounded),
              label: 'Bonus'),
          NavigationDestination(
              icon: Icon(Icons.remove_circle_outline), label: 'Pénalité'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_rounded), label: 'Lignes'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Réglages'),
        ],
      );
}
