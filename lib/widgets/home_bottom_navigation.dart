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
        height: 76,
        elevation: 0,
        indicatorColor: (selectedIndex == 2
                ? EmeraldPalette.penalty
                : EmeraldPalette.emerald)
            .withValues(alpha: 0.12),
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
              icon: Icon(Icons.remove_circle_outline,
                  color: EmeraldPalette.penalty),
              selectedIcon: Icon(Icons.remove_circle_rounded,
                  color: EmeraldPalette.penalty),
              label: 'Pénalité'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_rounded), label: 'Lignes'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Réglages'),
        ],
      );
}
