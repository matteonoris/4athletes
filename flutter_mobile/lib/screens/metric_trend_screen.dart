import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';

class MetricTrendScreen extends StatelessWidget {
  final String metricLabel;
  final String metricKey;
  final List<double> history;

  const MetricTrendScreen({
    Key? key,
    required this.metricLabel,
    required this.metricKey,
    required this.history,
  }) : super(key: key);

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
                  Text(avg.toStringAsFixed(1),
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
                          Text(minVal.toStringAsFixed(1),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Max',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis)),
                          Text(maxVal.toStringAsFixed(1),
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
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: false)), // Nascondi indici giorni
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontSize: 10)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (history.length - 1).toDouble(),
                minY: minVal * 0.9, // Lascia un po' di margine in basso
                maxY: maxVal * 1.1, // Margine in alto
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          spot.y.toStringAsFixed(1),
                          const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
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
                    dotData: FlDotData(show: true), // Mostra i puntini
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withOpacity(0.15),
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
}
