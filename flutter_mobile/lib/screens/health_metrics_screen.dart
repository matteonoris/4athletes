import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';

class HealthMetricsScreen extends StatefulWidget {
  final String initialMetric; // 'hrv' or 'resting_hr'

  const HealthMetricsScreen({super.key, required this.initialMetric});

  @override
  State<HealthMetricsScreen> createState() => _HealthMetricsScreenState();
}

class _HealthMetricsScreenState extends State<HealthMetricsScreen> {
  late String _selectedType;
  int _selectedDays = 30; // 7, 30, 180

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialMetric;
  }

  String _getMetricTitle(String type) {
    switch (type) {
      case 'hrv':
        return 'HRV';
      case 'resting_hr':
        return 'Battiti a Riposo';
      case 'spo2':
        return 'SpO2';
      case 'resp':
        return 'Freq. Respiratoria';
      case 'temp':
        return 'Temperatura';
      default:
        return type;
    }
  }

  String _getMetricUnit(String type) {
    switch (type) {
      case 'hrv':
        return 'ms';
      case 'resting_hr':
        return 'bpm';
      case 'spo2':
        return '%';
      case 'resp':
        return 'rpm';
      case 'temp':
        return '°C';
      default:
        return '';
    }
  }

  Color _getMetricColor(String type) {
    switch (type) {
      case 'hrv':
        return AppTheme.primary;
      case 'resting_hr':
        return AppTheme.error;
      case 'spo2':
        return Colors.blueAccent;
      case 'resp':
        return Colors.tealAccent;
      case 'temp':
        return Colors.orangeAccent;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final logs = appState.bodyLogs
        .where((l) => l.type == _selectedType)
        .toList()
      ..sort(
          (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _selectedDays));
    final filteredLogs =
        logs.where((l) => DateTime.parse(l.date).isAfter(cutoff)).toList();

    final Color mainColor = _getMetricColor(_selectedType);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getMetricTitle(_selectedType)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Metric Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeChip('hrv', 'HRV'),
                const SizedBox(width: 8),
                _buildTypeChip('resting_hr', 'RHR'),
                const SizedBox(width: 8),
                _buildTypeChip('spo2', 'SpO2'),
                const SizedBox(width: 8),
                _buildTypeChip('resp', 'Resp'),
                const SizedBox(width: 8),
                _buildTypeChip('temp', 'Temp'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Chart Section
          CustomCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Andamento ${_getMetricTitle(_selectedType)}',
                            style: TextStyle(
                                color: AppTheme.textMediumEmphasis,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            logs.isNotEmpty
                                ? '${logs.last.value.toStringAsFixed(1)} ${_getMetricUnit(_selectedType)}'
                                : '--',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildIntervalSelector(),
                  ],
                ),
                const SizedBox(height: 32),
                if (filteredLogs.isEmpty)
                  SizedBox(
                    height: 220,
                    child: Center(
                        child: Text('Nessun dato per questo intervallo',
                            style:
                                TextStyle(color: AppTheme.textMediumEmphasis))),
                  )
                else
                  Builder(
                    builder: (context) {
                      double minY = filteredLogs
                          .map((e) => e.value)
                          .reduce((a, b) => a < b ? a : b);
                      double maxY = filteredLogs
                          .map((e) => e.value)
                          .reduce((a, b) => a > b ? a : b);

                      // Add some padding to Y axis
                      if (minY == maxY) {
                        minY -= 10;
                        maxY += 10;
                      } else {
                        double padding = (maxY - minY) * 0.2;
                        minY -= padding;
                        maxY += padding;
                      }

                      return SizedBox(
                        height: 240,
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  strokeWidth: 1),
                              getDrawingVerticalLine: (value) => FlLine(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  strokeWidth: 1,
                                  dashArray: [5, 5]),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: (filteredLogs.length > 2)
                                      ? (filteredLogs.length - 1) / 2
                                      : 1.0,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.round();
                                    if (value != idx.toDouble() ||
                                        idx < 0 ||
                                        idx >= filteredLogs.length)
                                      return const SizedBox.shrink();

                                    final d =
                                        DateTime.parse(filteredLogs[idx].date);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        DateFormat('E d', 'it').format(d),
                                        style: TextStyle(
                                            color: AppTheme.textMediumEmphasis,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(0),
                                      style: TextStyle(
                                          color: mainColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    return LineTooltipItem(
                                      spot.y.toStringAsFixed(1),
                                      const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: filteredLogs
                                    .asMap()
                                    .entries
                                    .map((e) =>
                                        FlSpot(e.key.toDouble(), e.value.value))
                                    .toList(),
                                isCurved: true,
                                color: mainColor,
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter:
                                      (spot, percent, barData, index) =>
                                          FlDotCirclePainter(
                                              radius: 4,
                                              color: mainColor,
                                              strokeWidth: 2,
                                              strokeColor: AppTheme.card),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      mainColor.withValues(alpha: 0.3),
                                      Colors.transparent
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // History List
          Text('Cronologia', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            CustomCard(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('Nessuna misura registrata',
                        style: TextStyle(color: AppTheme.textMediumEmphasis))),
              ),
            )
          else
            ...logs.reversed.map((log) => _buildHistoryItem(log)).toList(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.textMediumEmphasis,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIntervalButton(7, '7D'),
          _buildIntervalButton(30, '30D'),
          _buildIntervalButton(180, '6M'),
          _buildIntervalButton(365, '1Y'),
          _buildIntervalButton(10000, 'All'),
        ],
      ),
    );
  }

  Widget _buildIntervalButton(int days, String label) {
    final isSelected = _selectedDays == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? AppTheme.textHighEmphasis
                : AppTheme.textMediumEmphasis,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BodyMetricLog log) {
    final date = DateTime.parse(log.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMMM yyyy').format(date),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHighEmphasis),
                ),
                const SizedBox(height: 4),
                Text(
                  _getMetricTitle(_selectedType),
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis, fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '${log.value.toStringAsFixed(1)} ${_getMetricUnit(_selectedType)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _getMetricColor(_selectedType)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
