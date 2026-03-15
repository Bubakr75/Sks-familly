import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../providers/pin_provider.dart';
import '../utils/pin_guard.dart';
import '../widgets/glass_card.dart';
import '../screens/dashboard_screen.dart';
import '../screens/add_points_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/pin_verification_screen.dart';
import '../screens/badges_screen.dart';
import '../screens/punishment_lines_screen.dart';
import '../screens/immunity_lines_screen.dart';
import '../screens/manage_children_screen.dart';
import '../screens/family_screen.dart';
import '../screens/notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navAnimController;
  late Animation<double> _navSlideAnim;

  static const _protectedTabs = {1, 4};

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _navSlideAnim = CurvedAnimation(
      parent: _navAnimController,
      curve: Curves.easeOutCubic,
    );
    _navAnimController.forward();
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    final pin = context.read<PinProvider>();
    if (_protectedTabs.contains(index) && pin.isPinSet && !pin.isParentMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinVerificationScreen(
            onVerified: () {
              Navigator.pop(context);
              setState(() => _currentIndex = index);
            },
          ),
        ),
      );
      return;
    }
    if (pin.isParentMode) pin.refreshActivity();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pin = context.watch<PinProvider>();
    final provider = context.watch<FamilyProvider>();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      drawer: _buildDrawer(context, provider, pin, primary),
      body: Stack(
        children: [
          _buildBody(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_navSlideAnim),
              child: _buildGlassNavBar(pin, primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _build<span class="cursor">█</span>
