import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../utils/health_display_utils.dart';

class MetricTrendScreen extends StatelessWidget {
  final String metricLabel;
  final String metricKey;
  final List<double> history;
  final List<DateTime>? historyDates;
  final bool formatAsDuration;

  const MetricTrendScreen({
    super.key,
    required this.metricLabel,
    required this.metricKey,
    required this.history,
    this.historyDates,
    this.formatAsDuration = false,
  });

  String _formatValue(double value) {
    return formatAsDuration
        ? formatMinutesAsHours(value)
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(metricLabel)),
        body: const Center(child: Text('Dati storici non disponibili')),
      );
    }

    double avg = history.reduce((a, b) => a + b) / history.length;
    double maxVal = history.reduce((a, b) => a > b ? a : b);
    double minVal = history.reduce((a, b) => a < b ? a : b);
    final dates = _datesForHistory(history.length);
    final minY = _chartMinY(minVal, maxVal);
    final maxY = _chartMaxY(minVal, maxVal);

    // Crea i punti del grafico (X = indice del giorno, Y = valore)
    List<FlSpot> spots = [];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i]));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(metricLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Statistiche
          Card(
            color: AppTheme.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text('Media (30 giorni)',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppTheme.textMediumEmphasis)),
                  const SizedBox(height: 8),
                  Text(_formatValue(avg),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                  Divider(height: 32, color: AppTheme.surface),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Min',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis)),
                          Text(_formatValue(minVal),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Max',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis)),
                          Text(_formatValue(maxVal),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('Andamento Recente',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Grafico
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (value != index.toDouble() ||
                            index < 0 ||
                            index >= dates.length ||
                            !_shouldShowBottomTitle(index, dates.length)) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(
                            DateFormat('d/M', 'it').format(dates[index]),
                            style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: formatAsDuration ? 48 : 40,
                      getTitlesWidget: (value, meta) => Text(
                          formatAsDuration
                              ? formatMinutesAsHours(value)
                              : value.toInt().toString(),
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 10)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (history.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.round().clamp(0, dates.length - 1);
                        return LineTooltipItem(
                          '${DateFormat('d/M', 'it').format(dates[index])}\n${_formatValue(spot.y)}',
                          TextStyle(
                              color: AppTheme.textHighEmphasis,
                              fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true), // Mostra i puntini
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _datesForHistory(int count) {
    if (historyDates != null && historyDates!.length == count) {
      return historyDates!
          .map((date) => DateTime(date.year, date.month, date.day))
          .toList(growable: false);
    }

    final end = DateTime.now();
    final endDay = DateTime(end.year, end.month, end.day);
    return List<DateTime>.generate(
      count,
      (index) => endDay.subtract(Duration(days: count - index - 1)),
    );
  }

  bool _shouldShowBottomTitle(int index, int length) {
    if (length <= 0) return false;
    if (length <= 3) return true;
    final middle = ((length - 1) / 2).round();
    return index == 0 || index == middle || index == length - 1;
  }

  double _chartMinY(double minVal, double maxVal) {
    if (minVal == maxVal) return minVal - 1;
    final padding = (maxVal - minVal) * 0.12;
    return minVal - padding;
  }

  double _chartMaxY(double minVal, double maxVal) {
    if (minVal == maxVal) return maxVal + 1;
    final padding = (maxVal - minVal) * 0.12;
    return maxVal + padding;
  }
}
