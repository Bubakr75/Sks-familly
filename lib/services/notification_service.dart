import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      'sks_family_channel',
      'SKS Family',
      description: 'Notifications SKS Family',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const reminderChannel = AndroidNotificationChannel(
      'sks_reminder_channel',
      'Rappels SKS Family',
      description: 'Rappels quotidiens et hebdomadaires',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(androidChannel);
    await android?.createNotificationChannel(reminderChannel);

    _initialized = true;
  }

  // ===== SCHEDULED NOTIFICATIONS =====

  static Future<void> scheduleDailyReminder({int hour = 19, int minute = 0}) async {
    await _localNotifications.cancel(1001);

    await _localNotifications.zonedSchedule(
      1001,
      '\u{1F4CB} Rappel du soir',
      'N\'oubliez pas de noter la journee de vos enfants !',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sks_reminder_channel',
          'Rappels SKS Family',
          channelDescription: 'Rappels quotidiens et hebdomadaires',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

  static Future<void> scheduleFridayScreenTime({
    required Map<String, String> childrenScreenTime,
  }) async {
    await _localNotifications.cancel(1002);

    if (childrenScreenTime.isEmpty) return;

    final buffer = StringBuffer();
    childrenScreenTime.forEach((name, time) {
      buffer.writeln('$name : $time');
    });

    await _localNotifications.zonedSchedule(
      1002,
      '\u{1F3AE} Temps d\'ecran du week-end',
      buffer.toString().trim(),
      _nextInstanceOfDayAndTime(DateTime.friday, 18, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sks_reminder_channel',
          'Rappels SKS Family',
          channelDescription: 'Rappels quotidiens et hebdomadaires',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

  static Future<void> cancelDailyReminder() async {
    await _localNotifications.cancel(1001);
  }

  static Future<void> cancelFridayScreenTime() async {
    await _localNotifications.cancel(1002);
  }

  static Future<void> cancelAllScheduled() async {
    await _localNotifications.cancelAll();
  }

  // ===== TIME HELPERS =====

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != dayOfWeek) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ===== INSTANT NOTIFICATIONS =====

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sks_family_channel',
      'SKS Family',
      channelDescription: 'Notifications SKS Family',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(id, title, body, details);
  }

  static void show({
    required String title,
    required String message,
    required NotificationType type,
  }) {
    _showLocalNotification(
      title: title,
      body: message,
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
    );
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

  // ===== CONVENIENCE METHODS =====

  static void notifyBonus(String childName, int points, String reason) {
    show(title: 'Bonus pour $childName', message: '+$points pts - $reason', type: NotificationType.bonus);
  }

  static void notifyPenalty(String childName, int points, String reason) {
    show(title: 'Penalite pour $childName', message: '$points pts - $reason', type: NotificationType.penalty);
  }

  static void notifyPunishment(String childName, String text, int lines) {
    show(title: 'Punition pour $childName', message: '$lines lignes - "$text"', type: NotificationType.punishment);
  }

  static void notifyPunishmentProgress(String childName, int completed, int total) {
    show(title: 'Progres de $childName', message: '$completed/$total lignes completees', type: NotificationType.progress);
  }

  static void notifyBadge(String childName, String badgeName) {
    show(title: '\u{1F3C6} Nouveau badge !', message: '$childName a obtenu "$badgeName"', type: NotificationType.badge);
  }

  static void notifyGoalCompleted(String childName, String goalTitle) {
    show(title: '\u{1F3AF} Objectif atteint !', message: '$childName a complete "$goalTitle"', type: NotificationType.goal);
  }

  static void notifyScreenTime(String childName, String time) {
    show(title: '\u{1F4FA} Temps d\'ecran', message: '$childName a $time ce week-end', type: NotificationType.screenTime);
  }

  static void notifySyncUpdate(String detail) {
    show(title: '\u{1F504} Mise a jour', message: detail, type: NotificationType.sync);
  }
}

enum NotificationType {
  bonus,
  penalty,
  punishment,
  progress,
  badge,
  goal,
  screenTime,
  sync,
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _controller.reverse().then((_) { if (mounted) widget.onDismiss(); });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.type) {
      case NotificationType.bonus: return Icons.add_circle_rounded;
      case NotificationType.penalty: return Icons.remove_circle_rounded;
      case NotificationType.punishment: return Icons.assignment_rounded;
      case NotificationType.progress: return Icons.trending_up_rounded;
      case NotificationType.badge: return Icons.emoji_events_rounded;
      case NotificationType.goal: return Icons.flag_rounded;
      case NotificationType.screenTime: return Icons.tv_rounded;
      case NotificationType.sync: return Icons.sync_rounded;
    }
  }

  Color get _color {
    switch (widget.type) {
      case NotificationType.bonus: return const Color(0xFF2E7D32);
      case NotificationType.penalty: return const Color(0xFFC62828);
      case NotificationType.punishment: return const Color(0xFFE65100);
      case NotificationType.progress: return const Color(0xFF1565C0);
      case NotificationType.badge: return const Color(0xFFF9A825);
      case NotificationType.goal: return const Color(0xFF6A1B9A);
      case NotificationType.screenTime: return const Color(0xFF7C4DFF);
      case NotificationType.sync: return const Color(0xFF00897B);
    }
  }

  String get _emoji {
    switch (widget.type) {
      case NotificationType.bonus: return '\u{2B50}';
      case NotificationType.penalty: return '\u{26A0}';
      case NotificationType.punishment: return '\u{1F4DD}';
      case NotificationType.progress: return '\u{1F4C8}';
      case NotificationType.badge: return '\u{1F3C6}';
      case NotificationType.goal: return '\u{1F3AF}';
      case NotificationType.screenTime: return '\u{1F4FA}';
      case NotificationType.sync: return '\u{1F504}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12, right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onDismiss,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                _controller.reverse().then((_) { if (mounted) widget.onDismiss(); });
              }
            },
            child: Material(
              elevation: 8, borderRadius: BorderRadius.circular(16),
              shadowColor: _color.withValues(alpha: 0.3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_color, _color.withValues(alpha: 0.85)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Text(_emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(widget.message, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  Icon(_icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
