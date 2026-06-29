import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/family_provider.dart';
import '../models/history_entry.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  late AnimationController _calendarController;
  late AnimationController _eventsController;
  late AnimationController _selectPulseController;
  late Animation<double> _selectPulseAnim;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();

    _calendarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _eventsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _selectPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _selectPulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
          parent: _selectPulseController, curve: Curves.elasticOut),
    );

    _calendarController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _eventsController.forward();
    });
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _eventsController.dispose();
    _selectPulseController.dispose();
    super.dispose();
  }

  /// Returns a list of maps with event data for a given day.
  /// HistoryEntry is a class, so we convert to map for display.
  List<Map<String, dynamic>> _getEventsForDay(
      DateTime day, FamilyProvider fp) {
    final events = <Map<String, dynamic>>[];
    for (final child in fp.children) {
      for (final h in fp.getHistoryForChild(child.id)) {
        if (isSameDay(h.date, day)) {
          events.add({
            'points': h.points * (h.isBonus ? 1 : -1),
            'reason': h.reason,
            'category': h.category,
            'timestamp': h.date,
            'childName': child.name,
          });
        }
      }
    }
    return events;
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    _selectPulseController.forward(from: 0.0);
    _eventsController.reset();
    _eventsController.forward();
  }

  void _navigateDay(int delta) {
    setState(() {
      _focusedDay = _focusedDay.add(Duration(days: delta));
      _selectedDay = _focusedDay;
    });
    _selectPulseController.forward(from: 0.0);
    _eventsController.reset();
    _eventsController.forward();
  }

  void _navigateWeek(int delta) {
    setState(() {
      _focusedDay = _focusedDay.add(Duration(days: 7 * delta));
      _selectedDay = _focusedDay;
    });
    _eventsController.reset();
    _eventsController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final selectedEvents =
            _selectedDay != null ? _getEventsForDay(_selectedDay!, fp) : <Map<String, dynamic>>[];

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.cyan, Colors.blue],
                ).createShader(bounds),
                child: const Text(
                  '📅 Calendrier',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            body: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _navigateDay(-1);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    _navigateDay(1);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _navigateWeek(-1);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _navigateWeek(1);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Column(
                children: [
                  // Calendar with fade-in
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _calendarController,
                      curve: Curves.easeIn,
                    ),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _calendarController,
                        curve: Curves.easeOutCubic,
                      )),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TableCalendar(
                          locale: 'fr_FR',
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2030),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          calendarFormat: _calendarFormat,
                          onFormatChanged: (format) {
                            setState(() => _calendarFormat = format);
                          },
                          onDaySelected: _onDaySelected,
                          onPageChanged: (focused) {
                            _focusedDay = focused;
                          },
                          eventLoader: (day) =>
                              _getEventsForDay(day, fp),
                          calendarStyle: CalendarStyle(
                            defaultTextStyle:
                                const TextStyle(color: Colors.white70),
                            weekendTextStyle:
                                TextStyle(color: Colors.cyan[200]),
                            outsideTextStyle:
                                const TextStyle(color: Colors.white24),
                            todayDecoration: BoxDecoration(
                              color: Colors.cyan.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.cyan, width: 1.5),
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: Colors.cyan,
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            markerSize: 6,
                            markersMaxCount: 3,
                          ),
                          headerStyle: HeaderStyle(
                            titleCentered: true,
                            formatButtonVisible: true,
                            titleTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            leftChevronIcon: const Icon(
                                Icons.chevron_left,
                                color: Colors.cyan),
                            rightChevronIcon: const Icon(
                                Icons.chevron_right,
                                color: Colors.cyan),
                            formatButtonTextStyle: const TextStyle(
                                color: Colors.cyan, fontSize: 12),
                            formatButtonDecoration: BoxDecoration(
                              border: Border.all(color: Colors.cyan),
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(8)),
                            ),
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                                color: Colors.white54, fontSize: 12),
                            weekendStyle: TextStyle(
                                color: Colors.cyan, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Selected date header with pulse
                  if (_selectedDay != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: AnimatedBuilder(
                        animation: _selectPulseAnim,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _selectPulseAnim.value,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.cyan.withOpacity(0.2),
                                Colors.blue.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.cyan.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${_selectedDay!.day.toString().padLeft(2, '0')}/${_selectedDay!.month.toString().padLeft(2, '0')}/${_selectedDay!.year} — ${selectedEvents.length} activité${selectedEvents.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Events list
                  Expanded(
                    child: selectedEvents.isEmpty
                        ? FadeTransition(
                            opacity: _eventsController,
                            child: const Center(
                              child: Text(
                                'Aucune activité ce jour',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 14),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            itemCount: selectedEvents.length,
                            itemBuilder: (context, index) {
                              final event = selectedEvents[index];
                              final pts = event['points'] as int? ?? 0;
                              final isPositive = pts >= 0;

                              final delay = index * 0.1;
                              return AnimatedBuilder(
                                animation: _eventsController,
                                builder: (context, child) {
                                  final progress =
                                      ((_eventsController.value - delay) /
                                              (1.0 - delay))
                                          .clamp(0.0, 1.0);
                                  return Transform.translate(
                                    offset:
                                        Offset(50 * (1 - progress), 0),
                                    child: Opacity(
                                      opacity: progress,
                                      child: child,
                                    ),
                                  );
                                },
                                child: TvFocusWrapper(
                                  onTap: () => _showEventDetail(event),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: GlassCard(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: isPositive
                                                    ? [Colors.green, Colors.green.shade700]
                                                    : [Colors.red, Colors.red.shade700],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isPositive ? Colors.green : Colors.red).withOpacity(0.3),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                isPositive ? '+$pts' : '$pts',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  event['reason'] as String? ?? 'Activité',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Text(
                                                      event['childName'] as String? ?? '',
                                                      style: TextStyle(color: Colors.cyan[300], fontSize: 11),
                                                    ),
                                                    if (event['category'] != null) ...[
                                                      const Text(' • ', style: TextStyle(color: Colors.white24)),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.cyan.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          event['category'] as String,
                                                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (event['timestamp'] != null)
                                            Text(
                                              _formatTime(event['timestamp'] as DateTime),
                                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _showEventDetail(Map<String, dynamic> event) {
    final pts = event['points'] as int? ?? 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(color: Colors.cyan.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text(event['reason'] as String? ?? 'Activité', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _detailRow('Enfant', event['childName'] as String? ?? ''),
                _detailRow('Points', '${pts >= 0 ? '+' : ''}$pts', color: pts >= 0 ? Colors.green : Colors.red),
                if (event['category'] != null)
                  _detailRow('Catégorie', event['category'] as String),
                if (event['timestamp'] != null)
                  _detailRow('Date & Heure', _formatDateTime(event['timestamp'] as DateTime)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
