import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/family_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        final dayHistory = provider.getHistoryForDate(_selectedDay);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(children: [
                    GlowIcon(icon: Icons.calendar_month_rounded, color: primary, size: 26),
                    const SizedBox(width: 10),
                    NeonText(
                      text: 'Calendrier', fontSize: 22, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87, glowIntensity: 0.2,
                    ),
                  ]),
                ),

                // ─── Navigation mois manuelle pour TV ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: primary, size: 30),
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                          });
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'fr_FR').format(_focusedDay),
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: primary, size: 30),
                        onPressed: () {
                          setState(() {
                            _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                          });
                        },
                      ),
                    ],
                  ),
                ),

                GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 20,
                  child: TableCalendar(
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2030),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (f) => setState(() => _calendarFormat = f),
                    onDaySelected: (selected, focused) {
                      setState(() { _selectedDay = selected; _focusedDay = focused; });
                    },
                    locale: 'fr_FR',
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    // ─── CORRIGÉ : Cacher le header intégré (on a le nôtre) ───
                    headerVisible: false,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 8)],
                      ),
                      selectedDecoration: BoxDecoration(
                        gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.7)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12)],
                      ),
                      markerDecoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 4)],
                      ),
                      markersMaxCount: 3,
                      defaultTextStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                      weekendTextStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                      outsideTextStyle: TextStyle(color: isDark ? Colors.grey[700] : Colors.grey[400]),
                      todayTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                      selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      markerSize: 5,
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: primary.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
                      weekendStyle: TextStyle(color: primary.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    eventLoader: (day) => provider.getHistoryForDate(day),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(children: [
                    NeonText(
                      text: DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDay),
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87, glowIntensity: 0.15,
                    ),
                    const Spacer(),
                    if (dayHistory.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primary.withValues(alpha: 0.2)),
                        ),
                        child: Text('${dayHistory.length} activites', style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ),

                Expanded(
                  child: dayHistory.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[700]),
                          const SizedBox(height: 8),
                          Text('Aucune activite ce jour', style: TextStyle(color: Colors.grey[600])),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: dayHistory.length,
                          itemBuilder: (_, i) {
                            final h = dayHistory[i];
                            final child = provider.getChild(h.childId);
                            final color = h.isBonus ? const Color(0xFF00E676) : const Color(0xFFFF1744);
                            return GlassCard(
                              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              borderRadius: 14,
                              child: Row(children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
                                  child: Icon(h.isBonus ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(child?.name ?? 'Inconnu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                                  Text('${h.reason} \u2022 ${h.category}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: color.withValues(alpha: 0.12)),
                                  child: Text('${h.isBonus ? '+' : ''}${h.points}', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                                ),
                              ]),
                            );
                          },
                        ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
