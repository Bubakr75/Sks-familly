import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/history_entry.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class TimelineScreen extends StatefulWidget {
  final String? initialChildId;
  const TimelineScreen({super.key, this.initialChildId});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String? _selectedChildId;
  final Set<String> _activeCategories = {};
  DateTimeRange? _dateRange;

  final List<String> _allCategories = [
    'punition', 'immunité', 'note', 'objectif',
    'échange', 'tribunal', 'bonus', 'pénalité',
  ];

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.initialChildId;
    _activeCategories.addAll(_allCategories);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, fp, _) {
        final children = fp.children;

        List<HistoryEntry> entries = _selectedChildId == null
            ? List.from(fp.allHistory)
            : fp.getHistoryForChild(_selectedChildId!);

        entries = entries
            .where((e) => _activeCategories.contains(e.category))
            .toList();

        if (_dateRange != null) {
          entries = entries.where((e) {
            return e.date.isAfter(
                    _dateRange!.start.subtract(const Duration(days: 1))) &&
                e.date.isBefore(
                    _dateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('📅 Timeline',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.date_range,
                    color: _dateRange != null
                        ? Colors.cyanAccent
                        : Colors.white54,
                  ),
                  tooltip: 'Filtrer par date',
                  onPressed: () => _pickDateRange(context),
                ),
                if (_dateRange != null ||
                    _activeCategories.length != _allCategories.length)
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.orangeAccent),
                    tooltip: 'Réinitialiser les filtres',
                    onPressed: () => setState(() {
                      _dateRange = null;
                      _activeCategories
                        ..clear()
                        ..addAll(_allCategories);
                    }),
                  ),
              ],
            ),
            body: Column(
              children: [
                _buildChildSelector(children),
                _buildCategoryFilter(),
                if (_dateRange != null) _buildDateRangeBadge(),
                Expanded(
                  child: entries.isEmpty
                      ? _buildEmpty()
                      : _buildTimeline(entries, fp),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChildSelector(List<ChildModel> children) {
    return Container(
      height: 76,
      color: Colors.black12,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        children: [
          _childChip(null, '👨‍👩‍👧‍👦', 'Tous'),
          ...children.map((c) => _childChip(
              c.id,
              c.avatar.isNotEmpty ? c.avatar : '🧒',
              c.name)),
        ],
      ),
    );
  }

  Widget _childChip(String? childId, String avatar, String name) {
    final isSelected = _selectedChildId == childId;
    return GestureDetector(
      onTap: () => setState(() => _selectedChildId = childId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF00BCD4)])
              : null,
          color: isSelected ? null : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  isSelected ? Colors.transparent : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(avatar, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(name,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 52,
      color: Colors.black.withOpacity(0.15),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _allCategories.map((cat) {
          final isOn = _activeCategories.contains(cat);
          final entry = HistoryEntry(
            id: '',
            childId: '',
            description: '',
            points: 0,
            isBonus: cat == 'bonus' ||
                cat == 'objectif' ||
                cat == 'immunité',
            category: cat,
            date: DateTime.now(),
          );
          return GestureDetector(
            onTap: () => setState(() {
              if (isOn) {
                _activeCategories.remove(cat);
              } else {
                _activeCategories.add(cat);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOn
                    ? entry.color.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isOn
                        ? entry.color.withOpacity(0.6)
                        : Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(entry.icon,
                      size: 14,
                      color: isOn ? entry.color : Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    cat[0].toUpperCase() + cat.substring(1),
                    style: TextStyle(
                        color: isOn ? entry.color : Colors.white38,
                        fontSize: 12,
                        fontWeight: isOn
                            ? FontWeight.w600
                            : FontWeight.normal),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateRangeBadge() {
    final fmt = (DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.cyanAccent.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.date_range,
              color: Colors.cyanAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            '${fmt(_dateRange!.start)} → ${fmt(_dateRange!.end)}',
            style: const TextStyle(
                color: Colors.cyanAccent, fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _dateRange = null),
            child: const Icon(Icons.close,
                color: Colors.cyanAccent, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<HistoryEntry> entries, FamilyProvider fp) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        final isLast = i == entries.length - 1;

        String? childName;
        if (_selectedChildId == null) {
          try {
            childName =
                fp.children.firstWhere((c) => c.id == e.childId).name;
          } catch (_) {}
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: e.color.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: e.color.withOpacity(0.6),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: e.color.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1),
                        ],
                      ),
                      child: Icon(e.icon, color: e.color, size: 18),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.white12,
                          margin: const EdgeInsets.symmetric(
                              vertical: 4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: e.color.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(8),
                              border: Border.all(
                                  color: e.color.withOpacity(0.4)),
                            ),
                            child: Text(
                              e.category[0].toUpperCase() +
                                  e.category.substring(1),
                              style: TextStyle(
                                  color: e.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDateTime(e.date),
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(e.description,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      if (e.points != 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              e.isBonus
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: e.color,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatPoints(e),
                              style: TextStyle(
                                  color: e.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            if (childName != null) ...[
                              const Spacer(),
                              Text('👤 $childName',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11)),
                            ],
                          ],
                        ),
                      ] else if (childName != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('👤 $childName',
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🕐', style: TextStyle(fontSize: 60)),
          SizedBox(height: 12),
          Text('Aucun événement trouvé',
              style:
                  TextStyle(color: Colors.white54, fontSize: 16)),
          SizedBox(height: 4),
          Text('Modifie les filtres pour voir plus d\'événements',
              style:
                  TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF7C4DFF),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  String _formatPoints(HistoryEntry e) {
    final sign = e.isBonus ? '+' : '-';
    if (e.category == 'punition') {
      return '$sign${(e.points / 100).toStringAsFixed(2)} pt';
    }
    return '$sign${e.points} pt';
  }

  String _formatDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} $h:$m';
  }
}
