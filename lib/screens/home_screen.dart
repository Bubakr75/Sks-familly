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
import '../screens/school_notes_screen.dart';
import '../screens/manage_children_screen.dart';
import '../screens/family_screen.dart';
import '../screens/notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;<span class="cursor">█</span>
