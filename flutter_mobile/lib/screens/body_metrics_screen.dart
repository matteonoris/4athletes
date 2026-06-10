import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';

class BodyMetricsScreen extends StatefulWidget {
  final String initialMetric; // 'weight' or 'height'

  const BodyMetricsScreen({super.key, required this.initialMetric});

  @override
  State<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends State<BodyMetricsScreen> {
  late String _selectedType;
  int _selectedDays = 30; // 7, 30, 180, 365

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialMetric;
  }

  void _showAddMetricDialog() {
    String valStr = '';
    String fatStr = '';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                _selectedType == 'weight'
                    ? 'Aggiungi Peso'
                    : 'Aggiungi Altezza',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: _selectedType == 'weight'
                          ? 'Peso (kg)'
                          : 'Altezza (cm)',
                    ),
                    onChanged: (v) => valStr = v,
                    style: TextStyle(color: AppTheme.textHighEmphasis),
                  ),
                  if (_selectedType == 'weight') ...[
                    const SizedBox(height: 16),
                    TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          hintText: 'Massa grassa % (opzionale)'),
                      onChanged: (v) => fatStr = v,
                      style: TextStyle(color: AppTheme.textHighEmphasis),
                    ),
                  ],
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppTheme.primary,
                              onPrimary: Colors.white,
                              surface: AppTheme.card,
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (d != null) {
                        setDialogState(() => selectedDate = d);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Data',
                              style: TextStyle(
                                  color: AppTheme.textMediumEmphasis)),
                          Text(
                            DateFormat('dd/MM/yyyy').format(selectedDate),
                            style: TextStyle(
                                color: AppTheme.textHighEmphasis,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annulla',
                      style: TextStyle(color: AppTheme.textMediumEmphasis)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final v = double.tryParse(valStr.replaceAll(',', '.'));
                    if (v != null) {
                      final appState =
                          Provider.of<AppState>(context, listen: false);
                      final dateStr =
                          selectedDate.toIso8601String().split('T')[0];
                      appState.addBodyLog(BodyMetricLog(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        date: dateStr,
                        type: _selectedType,
                        value: v,
                      ));
                      if (_selectedType == 'weight' && fatStr.isNotEmpty) {
                        final f = double.tryParse(fatStr.replaceAll(',', '.'));
                        if (f != null) {
                          appState.addBodyLog(BodyMetricLog(
                            id: (DateTime.now().millisecondsSinceEpoch + 1)
                                .toString(),
                            date: dateStr,
                            type: 'fat',
                            value: f,
                          ));
                        }
                      }
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.userProfile;
    final showHeightChip = user == null || user.age < 18;

    final logs = appState.bodyLogs
        .where((l) => l.type == _selectedType)
        .toList()
      ..sort(
          (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _selectedDays));
    final filteredLogs =
        logs.where((l) => DateTime.parse(l.date).isAfter(cutoff)).toList();

    // For weight, we also show fat trends if available
    final filteredFat = _selectedType == 'weight'
        ? (appState.bodyLogs
            .where((l) =>
                l.type == 'fat' && DateTime.parse(l.date).isAfter(cutoff))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date)))
        : <BodyMetricLog>[];

    final Color mainColor =
        _selectedType == 'weight' ? AppTheme.primary : const Color(0xFF9462E5);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedType == 'weight'
            ? 'Peso e Composizione'
            : 'Andamento Altezza'),
        actions: [
          IconButton(
            onPressed: _showAddMetricDialog,
            icon: const Icon(Icons.add_circle_outline,
                size: 28, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Metric Selector
          Row(
            children: [
              _buildTypeChip('weight', 'Peso'),
              if (showHeightChip) ...[
                const SizedBox(width: 12),
                _buildTypeChip('height', 'Altezza'),
              ],
            ],
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
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedType == 'weight'
                              ? 'Andamento Peso'
                              : 'Andamento Altezza',
                          style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          logs.isNotEmpty
                              ? '${logs.last.value.toStringAsFixed(1)} ${_selectedType == 'weight' ? 'kg' : 'cm'}'
                              : '--',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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
                      // Calculate ranges for dual axis scaling
                      double minW = filteredLogs
                          .map((e) => e.value)
                          .reduce((a, b) => a < b ? a : b);
                      double maxW = filteredLogs
                          .map((e) => e.value)
                          .reduce((a, b) => a > b ? a : b);
                      double minF = filteredFat.isNotEmpty
                          ? filteredFat
                              .map((e) => e.value)
                              .reduce((a, b) => a < b ? a : b)
                          : 10;
                      double maxF = filteredFat.isNotEmpty
                          ? filteredFat
                              .map((e) => e.value)
                              .reduce((a, b) => a > b ? a : b)
                          : 25;

                      minW -= 2;
                      maxW += 2;
                      minF -= 2;
                      maxF += 2;
                      final chartStart =
                          DateTime(cutoff.year, cutoff.month, cutoff.day);
                      final chartEnd = DateTime.now();
                      final chartDays = math.max(
                        1,
                        DateTime(chartEnd.year, chartEnd.month, chartEnd.day)
                            .difference(chartStart)
                            .inDays,
                      );
                      double xForDate(String date) {
                        final parsed = DateTime.tryParse(date);
                        if (parsed == null) return 0;
                        return DateTime(parsed.year, parsed.month, parsed.day)
                            .difference(chartStart)
                            .inDays
                            .clamp(0, chartDays)
                            .toDouble();
                      }

                      double scaleFat(double fat) {
                        if (maxF == minF) return (maxW + minW) / 2;
                        return ((fat - minF) / (maxF - minF)) * (maxW - minW) +
                            minW;
                      }

                      return SizedBox(
                        height: 240,
                        child: LineChart(
                          LineChartData(
                            minX: 0,
                            maxX: chartDays.toDouble(),
                            minY: minW,
                            maxY: maxW,
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
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: chartDays / 2,
                                  getTitlesWidget: (value, meta) {
                                    final isEdgeOrMiddle = (value - 0).abs() <
                                            0.01 ||
                                        (value - chartDays / 2).abs() < 0.01 ||
                                        (value - chartDays).abs() < 0.01;
                                    if (!isEdgeOrMiddle) {
                                      return const SizedBox.shrink();
                                    }

                                    final d = chartStart
                                        .add(Duration(days: value.round()));
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
                                  showTitles: _selectedType == 'weight',
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    double fatVal =
                                        ((value - minW) / (maxW - minW)) *
                                                (maxF - minF) +
                                            minF;
                                    return Text(
                                      fatVal.toStringAsFixed(0),
                                      style: const TextStyle(
                                          color: AppTheme.secondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(
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
                            lineBarsData: [
                              LineChartBarData(
                                spots: filteredLogs
                                    .map((log) =>
                                        FlSpot(xForDate(log.date), log.value))
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
                              if (_selectedType == 'weight' &&
                                  filteredFat.isNotEmpty)
                                LineChartBarData(
                                  spots: filteredFat
                                      .map((log) => FlSpot(xForDate(log.date),
                                          scaleFat(log.value)))
                                      .toList(),
                                  isCurved: true,
                                  color: AppTheme.secondary,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, barData, index) =>
                                            FlDotCirclePainter(
                                                radius: 4,
                                                color: AppTheme.secondary,
                                                strokeWidth: 2,
                                                strokeColor: AppTheme.card),
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
            ...logs.reversed.map((log) => _buildHistoryItem(log)),

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
          _buildIntervalButton(365, '1A'),
        ],
      ),
    );
  }

  Widget _buildIntervalButton(int days, String label) {
    final isSelected = _selectedDays == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  _selectedType == 'weight' ? 'Peso Corporeo' : 'Altezza',
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis, fontSize: 12),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '${log.value.toStringAsFixed(1)} ${_selectedType == 'weight' ? 'kg' : 'cm'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.error, size: 20),
                  onPressed: () {
                    Provider.of<AppState>(context, listen: false)
                        .deleteBodyLog(log.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
