import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/note_model.dart';

class EvaluationHistoryCard extends StatefulWidget {
  final List<NoteModel> evaluations;

  const EvaluationHistoryCard({
    super.key,
    required this.evaluations,
  });

  @override
  State<EvaluationHistoryCard> createState() => _EvaluationHistoryCardState();
}

class _EvaluationHistoryCardState extends State<EvaluationHistoryCard> {
  static const _globalMetric = 'Global';

  String _selectedMetric = _globalMetric;

  List<NoteModel> get _records {
    final records = List<NoteModel>.from(widget.evaluations)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (records.length <= 12) return records;
    return records.sublist(records.length - 12);
  }

  List<String> get _availableMetrics {
    final metrics = <String>[_globalMetric];

    for (final category in const [
      'Respect',
      'Coopération',
      'Autonomie',
      'Gestion des émotions',
    ]) {
      if (_records
          .any((record) => record.categoryScores.containsKey(category))) {
        metrics.add(category);
      }
    }

    return metrics;
  }

  int? _scoreFor(NoteModel note, String metric) {
    if (metric == _globalMetric) return note.overallScore;
    return note.categoryScores[metric];
  }

  Color _metricColor(String metric) {
    switch (metric) {
      case 'Respect':
        return const Color(0xFF00D2FF);
      case 'Coopération':
        return const Color(0xFF43E97B);
      case 'Autonomie':
        return const Color(0xFFFFD740);
      case 'Gestion des émotions':
        return const Color(0xFFFF6B9D);
      default:
        return const Color(0xFF9D97FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _availableMetrics;

    if (!metrics.contains(_selectedMetric)) {
      _selectedMetric = _globalMetric;
    }

    final records = _records
        .where((record) => _scoreFor(record, _selectedMetric) != null)
        .toList();

    if (records.isEmpty) return const SizedBox.shrink();

    final latestScore = _scoreFor(records.last, _selectedMetric)!.clamp(0, 20);
    final previousScore = records.length > 1
        ? _scoreFor(records[records.length - 2], _selectedMetric)
        : null;
    final difference =
        previousScore == null ? null : latestScore - previousScore;
    final color = _metricColor(_selectedMetric);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: color),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Évolution des évaluations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$latestScore/20',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (difference != null) ...[
            const SizedBox(height: 4),
            Text(
              difference == 0
                  ? 'Stable depuis la dernière évaluation'
                  : difference > 0
                      ? '+$difference point${difference > 1 ? 's' : ''} depuis la dernière évaluation'
                      : '$difference point${difference < -1 ? 's' : ''} depuis la dernière évaluation',
              style: TextStyle(
                color: difference >= 0
                    ? const Color(0xFF43E97B)
                    : const Color(0xFFFFB74D),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: metrics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final metric = metrics[index];
                final selected = metric == _selectedMetric;
                final metricColor = _metricColor(metric);

                return ChoiceChip(
                  label: Text(metric),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedMetric = metric);
                  },
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  selectedColor: metricColor.withValues(alpha: 0.35),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  side: BorderSide(
                    color: selected
                        ? metricColor
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          if (records.length == 1)
            _singleEvaluation(records.single, latestScore, color)
          else
            SizedBox(
              height: 190,
              child: LineChart(
                _chartData(records, color),
                duration: const Duration(milliseconds: 350),
              ),
            ),
        ],
      ),
    );
  }

  Widget _singleEvaluation(
    NoteModel record,
    int score,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            'Première évaluation enregistrée',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${record.createdAt.day}/${record.createdAt.month}/${record.createdAt.year} • $score/20',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(
    List<NoteModel> records,
    Color color,
  ) {
    final spots = <FlSpot>[];

    for (var index = 0; index < records.length; index++) {
      final score = _scoreFor(records[index], _selectedMetric);
      if (score != null) {
        spots.add(
          FlSpot(
            index.toDouble(),
            score.clamp(0, 20).toDouble(),
          ),
        );
      }
    }

    return LineChartData(
      minX: 0,
      maxX: (records.length - 1).toDouble(),
      minY: 0,
      maxY: 20,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 5,
        getDrawingHorizontalLine: (_) => FlLine(
          color: Colors.white.withValues(alpha: 0.06),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 5,
            reservedSize: 28,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.round();

              if (index < 0 || index >= records.length) {
                return const SizedBox.shrink();
              }

              final date = records[index].createdAt;

              return Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  '${date.day}/${date.month}',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF17233A),
          getTooltipItems: (spots) => spots
              .map(
                (spot) => LineTooltipItem(
                  '${spot.y.round()}/20',
                  TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 3.5,
              color: color,
              strokeWidth: 2,
              strokeColor: const Color(0xFF0A0E21),
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.01),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
