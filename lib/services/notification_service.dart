import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize local notifications (call once at app start)
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'sks_family_channel',
      'SKS Family',
      description: 'Notifications de synchronisation familiale',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  /// Show a real Android notification in the status bar
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sks_family_channel',
      'SKS Family',
      channelDescription: 'Notifications de synchronisation familiale',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(id, title, body, details);
  }

  /// Show both in-app overlay AND Android notification
  static void show({
    required String title,
    required String message,
    required NotificationType type,
  }) {
    // Show Android notification in status bar
    _showLocalNotification(
      title: title,
      body: message,
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
    );

    // Also show in-app overlay if context is available
    _showOverlay(title: title, message: message, type: type);
  }

  static void _showOverlay({
    required String title,
    required String message,
    required NotificationType type,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _NotificationOverlay(
        title: title,
        message: message,
        type: type,
        onDismiss: () {
          try { entry.remove(); } catch (_) {}
        },
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      try { entry.remove(); } catch (_) {}
    });
  }

  static void notifyBonus(String childName, int points, String reason) {
    show(
      title: 'Bonus pour $childName',
      message: '+$points pts - $reason',
      type: NotificationType.bonus,
    );
  }

  static void notifyPenalty(String childName, int points, String reason) {
    show(
      title: 'Penalite pour $childName',
      message: '$points pts - $reason',
      type: NotificationType.penalty,
    );
  }

  static void notifyPunishment(String childName, String text, int lines) {
    show(
      title: 'Punition pour $childName',
      message: '$lines lignes - "$text"',
      type: NotificationType.punishment,
    );
  }

  static void notifyPunishmentProgress(String childName, int completed, int total) {
    show(
      title: 'Progres de $childName',
      message: '$completed/$total lignes completees',
      type: NotificationType.progress,
    );
  }

  static void notifyBadge(String childName, String badgeName) {
    show(
      title: 'Nouveau badge !',
      message: '$childName a obtenu "$badgeName"',
      type: NotificationType.badge,
    );
  }

  static void notifyGoalCompleted(String childName, String goalTitle) {
    show(
      title: 'Objectif atteint !',
      message: '$childName a complete "$goalTitle"',
      type: NotificationType.goal,
    );
  }
}

enum NotificationType {
  bonus,
  penalty,
  punishment,
  progress,
  badge,
  goal,
}

class _NotificationOverlay extends StatefulWidget {
  final String title;
  final String message;
  final NotificationType type;
  final VoidCallback onDismiss;

  const _NotificationOverlay({
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<_NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.type) {
      case NotificationType.bonus:
        return Icons.add_circle_rounded;
      case NotificationType.penalty:
        return Icons.remove_circle_rounded;
      case NotificationType.punishment:
        return Icons.assignment_rounded;
      case NotificationType.progress:
        return Icons.trending_up_rounded;
      case NotificationType.badge:
        return Icons.emoji_events_rounded;
      case NotificationType.goal:
        return Icons.flag_rounded;
    }
  }

  Color get _color {
    switch (widget.type) {
      case NotificationType.bonus:
        return const Color(0xFF2E7D32);
      case NotificationType.penalty:
        return const Color(0xFFC62828);
      case NotificationType.punishment:
        return const Color(0xFFE65100);
      case NotificationType.progress:
        return const Color(0xFF1565C0);
      case NotificationType.badge:
        return const Color(0xFFF9A825);
      case NotificationType.goal:
        return const Color(0xFF6A1B9A);
    }
  }

  String get _emoji {
    switch (widget.type) {
      case NotificationType.bonus:
        return '\u{2B50}';
      case NotificationType.penalty:
        return '\u{26A0}';
      case NotificationType.punishment:
        return '\u{1F4DD}';
      case NotificationType.progress:
        return '\u{1F4C8}';
      case NotificationType.badge:
        return '\u{1F3C6}';
      case NotificationType.goal:
        return '\u{1F3AF}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onDismiss,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                _controller.reverse().then((_) {
                  if (mounted) widget.onDismiss();
                });
              }
            },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              shadowColor: _color.withValues(alpha: 0.3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _color,
                      _color.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(_emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(_icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
