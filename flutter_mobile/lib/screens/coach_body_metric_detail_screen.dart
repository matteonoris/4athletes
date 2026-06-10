import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/custom_card.dart';

/// Read-only body metric detail screen for coaches.
/// Shows a full-screen chart of an athlete's weight or height over time.
/// Coaches cannot add or edit data — view only.
class CoachBodyMetricDetailScreen extends StatefulWidget {
  final String title;
  final String type; // 'weight' | 'height' | 'fat'
  final List<BodyMetricLog> logs;
  final String athleteName;

  const CoachBodyMetricDetailScreen({
    super.key,
    required this.title,
    required this.type,
    required this.logs,
    required this.athleteName,
  });

  @override
  State<CoachBodyMetricDetailScreen> createState() =>
      _CoachBodyMetricDetailScreenState();
}

class _CoachBodyMetricDetailScreenState
    extends State<CoachBodyMetricDetailScreen> {
  String _selectedTimeframe = '30D';

  List<BodyMetricLog> _filterByTimeframe(List<BodyMetricLog> allLogs) {
    if (_selectedTimeframe == 'ALL') return allLogs;
    final now = DateTime.now();
    DateTime cutoff;
    switch (_selectedTimeframe) {
      case '7D':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case '30D':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case '6M':
        cutoff = now.subtract(const Duration(days: 180));
        break;
      case '1A':
        cutoff = now.subtract(const Duration(days: 365));
        break;
      default:
        cutoff = DateTime(2000);
    }
    return allLogs
        .where((l) => DateTime.parse(l.date).isAfter(cutoff))
        .toList();
  }

  String _unit() {
    if (widget.type == 'weight') return 'kg';
    if (widget.type == 'height') return 'cm';
    return '%';
  }

  Color _lineColor() {
    if (widget.type == 'weight') return AppTheme.secondary;
    if (widget.type == 'height') return Colors.purpleAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<BodyMetricLog>.from(widget.logs)
      ..sort(
          (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
    final logs = _filterByTimeframe(sorted);

    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(widget.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(widget.athleteName,
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis, fontSize: 12)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildTimeframeSelector(),
          const SizedBox(height: 16),
          _buildMaxCard(logs),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Andamento',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('Sola lettura',
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildChartSection(logs),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Storico (${logs.length})',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nessun dato registrato nel periodo selezionato.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMediumEmphasis),
                    ),
                    if (_selectedTimeframe != 'ALL') ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            setState(() => _selectedTimeframe = 'ALL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Mostra tutti i dati'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...logs.reversed.map((l) => _buildHistoryRow(l)),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final options = ['7D', '30D', '6M', '1A', 'ALL'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: options.map((opt) {
            bool isSelected = _selectedTimeframe == opt;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTimeframe = opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(opt,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textMediumEmphasis)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMaxCard(List<BodyMetricLog> logs) {
    if (logs.isEmpty) return const SizedBox();
    final latest = logs.last;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomCard(
        color: const Color(0xFF22282D),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VALORE ATTUALE',
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(latest.value.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1)),
                const SizedBox(width: 8),
                Text(_unit(),
                    style: TextStyle(
                        fontSize: 20,
                        color: AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Ultima misurazione: ${latest.date}',
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(List<BodyMetricLog> logs) {
    if (logs.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: CustomCard(
          color: Color(0xFF22282D),
          height: 250,
          child: Center(
            child: Text('Nessun dato per il grafico',
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis, fontSize: 13)),
          ),
        ),
      );
    }

    List<FlSpot> spots = [];
    double minY = 9999, maxY = 0;
    for (int i = 0; i < logs.length; i++) {
      final val = logs[i].value;
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }
    final padding = (maxY - minY) * 0.15 + 1;
    minY = (minY - padding).clamp(0, 9999);
    maxY = maxY + padding;

    final lineColor = _lineColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomCard(
        color: const Color(0xFF22282D),
        height: 260,
        padding:
            const EdgeInsets.only(top: 32, bottom: 16, left: 16, right: 32),
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 4,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0x1AFFFFFF), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1.0,
                  getTitlesWidget: (val, meta) {
                    final idx = val.round();
                    if (val != idx.toDouble()) return const SizedBox.shrink();
                    if (idx >= 0 &&
                        idx < logs.length &&
                        (idx == 0 ||
                            idx == logs.length - 1 ||
                            (logs.length > 3 &&
                                idx == (logs.length / 2).floor()))) {
                      final date = DateTime.parse(logs[idx].date);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${date.day}/${date.month}',
                            style: TextStyle(
                                color: AppTheme.textMediumEmphasis,
                                fontSize: 9)),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (val, meta) => Text(val.toStringAsFixed(1),
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis, fontSize: 9)),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: lineColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 3.5,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF22282D),
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: lineColor.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryRow(BodyMetricLog log) {
    final date = DateTime.parse(log.date);
    const giorni = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
    const mesi = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre'
    ];
    final giornoStr = giorni[date.weekday - 1];
    final meseStr = mesi[date.month - 1];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
      child: CustomCard(
        color: const Color(0xFF22282D),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text('$giornoStr ${date.day} $meseStr',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white)),
            ),
            Text(log.value.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary)),
            const SizedBox(width: 4),
            Text(_unit(),
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
