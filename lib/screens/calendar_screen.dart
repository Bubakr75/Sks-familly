import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<dynamic> _getEventsForDay(DateTime day, FamilyProvider provider) {
    return provider.getActivitiesForDate(day);
  }

  void _navigateDay(int delta) {
    setState(() {
      final newDay =
          (_selectedDay ?? _focusedDay).add(Duration(days: delta));
      _selectedDay = newDay;
      _focusedDay = newDay;
    });
  }

  void _navigateWeek(int delta) {
    setState(() {
      final newDay =
          (_selectedDay ?? _focusedDay).add(Duration(days: delta * 7));
      _selectedDay = newDay;
      _focusedDay = newDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Colors.cyanAccent;

    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final events = _selectedDay != null
            ? _getEventsForDay(_selectedDay!, provider)
            : <dynamic>[];

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Calendrier'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Column(
              children: [
                // Navigation TV pour le calendrier
                Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      final key = event.logicalKey;
                      if (key == LogicalKeyboardKey.arrowLeft) {
                        _navigateDay(-1);
                        return KeyEventResult.handled;
                      } else if (key == LogicalKeyboardKey.arrowRight) {
                        _navigateDay(1);
                        return KeyEventResult.handled;
                      } else if (key == LogicalKeyboardKey.arrowUp) {
                        _navigateWeek(-1);
                        return KeyEventResult.handled;
                      } else if (key == LogicalKeyboardKey.arrowDown) {
                        _navigateWeek(1);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TableCalendar(
                        locale: 'fr_FR',
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onFormatChanged: (format) {
                          setState(() => _calendarFormat = format);
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        eventLoader: (day) =>
                            _getEventsForDay(day, provider),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: primary.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, primary.withOpacity(0.6)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle:
                              const TextStyle(color: Colors.white),
                          selectedTextStyle:
                              const TextStyle(color: Colors.black),
                          defaultTextStyle:
                              const TextStyle(color: Colors.white70),
                          weekendTextStyle:
                              const TextStyle(color: Colors.white54),
                          outsideTextStyle:
                              const TextStyle(color: Colors.white24),
                          markerDecoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                          markerSize: 6,
                          markersMaxCount: 3,
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: true,
                          titleCentered: true,
                          titleTextStyle:
                              const TextStyle(color: Colors.white, fontSize: 16),
                          leftChevronIcon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white70),
                          rightChevronIcon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white70),
                          formatButtonTextStyle:
                              TextStyle(color: primary, fontSize: 13),
                          formatButtonDecoration: BoxDecoration(
                            border: Border.all(color: primary.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle:
                              TextStyle(color: Colors.white54, fontSize: 12),
                          weekendStyle:
                              TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),

                // Date sélectionnée + compteur
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDay != null
                            ? DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                                .format(_selectedDay!)
                            : 'Aucune date',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${events.length} activité(s)',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste activités
                Expanded(
                  child: events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy,
                                  size: 48, color: Colors.white24),
                              const SizedBox(height: 8),
                              const Text(
                                'Aucune activité ce jour',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final activity = events[index];
                            final isPositive =
                                (activity.points as int?) != null &&
                                    activity.points > 0;
                            final childName = provider
                                .getChildName(activity.childId);

                            return TvFocusWrapper(
                              onSelect: () {},
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: (isPositive
                                                ? Colors.greenAccent
                                                : Colors.redAccent)
                                            .withOpacity(0.15),
                                      ),
                                      child: Icon(
                                        isPositive
                                            ? Icons.add_circle_outline
                                            : Icons.remove_circle_outline,
                                        color: isPositive
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activity.reason ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                childName,
                                                style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 12),
                                              ),
                                              if (activity.category !=
                                                  null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.06),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    activity.category,
                                                    style: const TextStyle(
                                                        color: Colors.white30,
                                                        fontSize: 10),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${isPositive ? '+' : ''}${activity.points}',
                                      style: TextStyle(
                                        color: isPositive
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
