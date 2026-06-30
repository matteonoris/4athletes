import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../utils/health_display_utils.dart';
import 'custom_card.dart';

const _sleepDeepColor = Color(0xFF123B7A);
const _sleepRemColor = Color(0xFFB48CFF);
const _sleepLightColor = Color(0xFF7DDCFF);
const _sleepBedtimeColor = AppTheme.primary;
const _sleepWakeColor = Color(0xFFB48CFF);
const _sleepDebtColor = AppTheme.error;
const _sleepSurplusColor = AppTheme.secondary;

Color get _sleepAwakeColor => AppTheme.textMediumEmphasis;

class SleepDetailChartsSection extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final Map<String, double> dailyMetrics;

  const SleepDetailChartsSection({
    super.key,
    required this.history,
    required this.dailyMetrics,
  });

  @override
  State<SleepDetailChartsSection> createState() =>
      _SleepDetailChartsSectionState();
}

class _SleepDetailChartsSectionState extends State<SleepDetailChartsSection> {
  final Map<String, int> _ranges = {
    'need': 14,
    'debt': 14,
    'architecture': 14,
    'regularity': 14,
    'efficiency': 14,
  };

  void _setRange(String key, int days) {
    setState(() => _ranges[key] = days);
  }

  @override
  Widget build(BuildContext context) {
    final history = _historyWithToday(widget.history, widget.dailyMetrics);
    final dailyNeed = widget.dailyMetrics['dailySleepNeed'];
    final todaySleep = widget.dailyMetrics['totalSleep'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grafici sonno',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _SleepNeedChartCard(
          title: 'Sonno vs fabbisogno',
          days: _ranges['need']!,
          onDaysChanged: (days) => _setRange('need', days),
          history: history,
          dailyNeedMinutes: dailyNeed,
        ),
        const SizedBox(height: 12),
        _SleepDebtChartCard(
          title: 'Debito di sonno',
          days: _ranges['debt']!,
          onDaysChanged: (days) => _setRange('debt', days),
          history: history,
          dailyNeedMinutes: dailyNeed,
          todaySleepMinutes: todaySleep,
        ),
        const SizedBox(height: 12),
        _SleepArchitectureChartCard(
          title: 'Architettura del sonno',
          days: _ranges['architecture']!,
          onDaysChanged: (days) => _setRange('architecture', days),
          history: history,
        ),
        const SizedBox(height: 12),
        _SleepRegularityChartCard(
          title: 'Regolarita del sonno',
          days: _ranges['regularity']!,
          onDaysChanged: (days) => _setRange('regularity', days),
          history: history,
        ),
        const SizedBox(height: 12),
        _SleepEfficiencyChartCard(
          title: 'Efficienza del sonno',
          days: _ranges['efficiency']!,
          onDaysChanged: (days) => _setRange('efficiency', days),
          history: history,
        ),
      ],
    );
  }
}

class _SleepNeedChartCard extends StatelessWidget {
  final String title;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final List<Map<String, dynamic>> history;
  final double? dailyNeedMinutes;

  const _SleepNeedChartCard({
    required this.title,
    required this.days,
    required this.onDaysChanged,
    required this.history,
    required this.dailyNeedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final points = _sleepPoints(history, days);
    return _ChartCardShell(
      title: title,
      days: days,
      onDaysChanged: onDaysChanged,
      legend: [
        const _LegendItem('Sonno', AppTheme.primary),
        _LegendItem('Fabbisogno', AppTheme.textMediumEmphasis),
      ],
      child:
          _SleepNeedChart(points: points, dailyNeedMinutes: dailyNeedMinutes),
    );
  }
}

class _SleepDebtChartCard extends StatelessWidget {
  final String title;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final List<Map<String, dynamic>> history;
  final double? dailyNeedMinutes;
  final double? todaySleepMinutes;

  const _SleepDebtChartCard({
    required this.title,
    required this.days,
    required this.onDaysChanged,
    required this.history,
    required this.dailyNeedMinutes,
    required this.todaySleepMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final sleep = _sleepPoints(history, days);
    final series = sleep.map((point) {
      final value = point.value == null || dailyNeedMinutes == null
          ? null
          : dailyNeedMinutes! - point.value!;
      return DailyChartPoint(date: point.date, value: value);
    }).toList();

    if (series.isNotEmpty &&
        todaySleepMinutes != null &&
        dailyNeedMinutes != null) {
      series[series.length - 1] = DailyChartPoint(
        date: series.last.date,
        value: dailyNeedMinutes! - todaySleepMinutes!,
      );
    }

    return _ChartCardShell(
      title: title,
      days: days,
      onDaysChanged: onDaysChanged,
      legend: const [
        _LegendItem('Debito', _sleepDebtColor),
        _LegendItem('Surplus', _sleepSurplusColor),
      ],
      child: _SleepDebtChart(series: series),
    );
  }
}

class _SleepArchitectureChartCard extends StatelessWidget {
  final String title;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final List<Map<String, dynamic>> history;

  const _SleepArchitectureChartCard({
    required this.title,
    required this.days,
    required this.onDaysChanged,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return _ChartCardShell(
      title: title,
      days: days,
      onDaysChanged: onDaysChanged,
      legend: [
        const _LegendItem('Profondo', _sleepDeepColor),
        const _LegendItem('REM', _sleepRemColor),
        const _LegendItem('Leggero', _sleepLightColor),
        _LegendItem('Sveglio', _sleepAwakeColor),
      ],
      child: _SleepArchitectureChart(
        points: _sleepArchitecturePoints(history, days),
      ),
    );
  }
}

class _SleepRegularityChartCard extends StatelessWidget {
  final String title;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final List<Map<String, dynamic>> history;

  const _SleepRegularityChartCard({
    required this.title,
    required this.days,
    required this.onDaysChanged,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return _ChartCardShell(
      title: title,
      days: days,
      onDaysChanged: onDaysChanged,
      legend: const [
        _LegendItem('Addormentamento', _sleepBedtimeColor),
        _LegendItem('Risveglio', _sleepWakeColor),
      ],
      child: _SleepRegularityChart(
        points: _sleepRegularityPoints(history, days),
      ),
    );
  }
}

class _SleepEfficiencyChartCard extends StatelessWidget {
  final String title;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final List<Map<String, dynamic>> history;

  const _SleepEfficiencyChartCard({
    required this.title,
    required this.days,
    required this.onDaysChanged,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final points = _sleepArchitecturePoints(history, days)
        .map((point) => DailyChartPoint(
              date: point.date,
              value: point.totalSleep != null &&
                      point.timeInBed != null &&
                      point.timeInBed! > 0
                  ? (point.totalSleep! / point.timeInBed!) * 100
                  : null,
            ))
        .toList();

    return _ChartCardShell(
      title: title,
      days: days,
      onDaysChanged: onDaysChanged,
      child: _LineSeriesChart(
        series: points,
        valueColor: AppTheme.primary,
        unit: '%',
        decimals: 0,
        minYOverride: 0,
        maxYOverride: 100,
      ),
    );
  }
}

class _ChartCardShell extends StatelessWidget {
  final String title;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final Widget child;
  final List<_LegendItem> legend;

  const _ChartCardShell({
    required this.title,
    required this.days,
    required this.onDaysChanged,
    required this.child,
    this.legend = const [],
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              _RangeSelector(days: days, onChanged: onDaysChanged),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(height: 220, child: child),
          if (legend.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChartLegend(items: legend),
          ],
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;

  const _RangeSelector({required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [7, 14, 30, 90].map((value) {
          final selected = value == days;
          return GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.card : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${value}g',
                style: TextStyle(
                  color: selected
                      ? AppTheme.textHighEmphasis
                      : AppTheme.textMediumEmphasis,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);
}

class _ChartLegend extends StatelessWidget {
  final List<_LegendItem> items;

  const _ChartLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _LineSeriesChart extends StatelessWidget {
  final List<DailyChartPoint> series;
  final Color valueColor;
  final String unit;
  final int decimals;
  final double? minYOverride;
  final double? maxYOverride;

  const _LineSeriesChart({
    required this.series,
    required this.valueColor,
    required this.unit,
    required this.decimals,
    this.minYOverride,
    this.maxYOverride,
  });

  @override
  Widget build(BuildContext context) {
    final values = series.map((p) => p.value).whereType<double>().toList();
    if (values.isEmpty) return const _NoDataChart();

    var minY = minYOverride ?? values.reduce(math.min);
    var maxY = maxYOverride ?? values.reduce(math.max);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    } else {
      final padding = (maxY - minY) * 0.16;
      minY = minYOverride ?? (minY - padding);
      maxY = maxYOverride ?? (maxY + padding);
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(0, series.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.chartGrid,
            strokeWidth: 1,
          ),
        ),
        titlesData: _chartTitles(
          series,
          leftFormatter: (value) => value.toStringAsFixed(decimals),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final index = spot.x.round().clamp(0, series.length - 1);
              final date = DateFormat('d/M', 'it').format(series[index].date);
              return LineTooltipItem(
                '$date\n${spot.y.toStringAsFixed(decimals)} $unit',
                TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: _lineBars(
          series.map((p) => p.value).toList(),
          valueColor,
          width: 3,
        ),
      ),
    );
  }
}

class _SleepNeedChart extends StatelessWidget {
  final List<DailyChartPoint> points;
  final double? dailyNeedMinutes;

  const _SleepNeedChart({
    required this.points,
    required this.dailyNeedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.value).whereType<double>().toList();
    if (dailyNeedMinutes != null) values.add(dailyNeedMinutes!);
    if (values.isEmpty) return const _NoDataChart();

    final maxY = values.reduce(math.max) * 1.18;
    return Stack(
      children: [
        BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppTheme.chartGrid,
                strokeWidth: 1,
              ),
            ),
            titlesData: _chartTitles(
              points,
              leftFormatter: (value) => formatMinutesAsHours(value),
              leftReservedSize: 62,
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final value = points[group.x].value;
                  if (value == null) return null;
                  return BarTooltipItem(
                    '${DateFormat('d/M', 'it').format(points[group.x].date)}'
                    '\nSonno ${formatMinutesAsHours(value)}',
                    TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            barGroups: points.asMap().entries.map((entry) {
              final value = entry.value.value;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: value ?? 0,
                    width: _barWidthForPointCount(points.length),
                    color: value == null
                        ? Colors.transparent
                        : AppTheme.primary.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        if (dailyNeedMinutes != null)
          LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(0, points.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: points
                      .asMap()
                      .entries
                      .where((entry) => entry.value.value != null)
                      .map((entry) =>
                          FlSpot(entry.key.toDouble(), dailyNeedMinutes!))
                      .toList(),
                  isCurved: false,
                  color: AppTheme.textMediumEmphasis,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  dashArray: [6, 4],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SleepDebtChart extends StatelessWidget {
  final List<DailyChartPoint> series;

  const _SleepDebtChart({required this.series});

  @override
  Widget build(BuildContext context) {
    final values = series.map((p) => p.value).whereType<double>().toList();
    if (values.isEmpty) return const _NoDataChart();

    var minY = math.min(0.0, values.reduce(math.min));
    var maxY = math.max(0.0, values.reduce(math.max));
    if (minY == maxY) {
      minY -= 30;
      maxY += 30;
    } else {
      final padding = math.max(20.0, (maxY - minY) * 0.16);
      minY -= padding;
      maxY += padding;
    }

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: value == 0
                ? AppTheme.textMediumEmphasis.withValues(alpha: 0.32)
                : AppTheme.chartGrid,
            strokeWidth: value == 0 ? 1.4 : 1,
          ),
        ),
        titlesData: _chartTitles(
          series,
          leftFormatter: (value) => formatMinutesAsHours(value),
          leftReservedSize: 62,
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY;
              final label = value > 0 ? 'Debito' : 'Surplus';
              return BarTooltipItem(
                '${DateFormat('d/M', 'it').format(series[group.x].date)}'
                '\n$label ${formatMinutesAsHours(value.abs())}',
                TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        barGroups: series.asMap().entries.map((entry) {
          final value = entry.value.value;
          final color = _sleepDebtStatusColor(value);
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                fromY: 0,
                toY: value ?? 0,
                width: _barWidthForPointCount(series.length),
                color: value == null ? Colors.transparent : color,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SleepArchitectureChart extends StatelessWidget {
  final List<_SleepArchitecturePoint> points;

  const _SleepArchitectureChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final totals =
        points.map((point) => point.total).whereType<double>().toList();
    if (totals.isEmpty) return const _NoDataChart();
    final maxY = totals.reduce(math.max) * 1.18;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.chartGrid,
            strokeWidth: 1,
          ),
        ),
        titlesData: _chartTitles(
          points
              .map((point) =>
                  DailyChartPoint(date: point.date, value: point.total))
              .toList(),
          leftFormatter: (value) => formatMinutesAsHours(value),
          leftReservedSize: 62,
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = points[group.x];
              if (point.total == null) return null;
              return BarTooltipItem(
                '${DateFormat('d/M', 'it').format(point.date)}'
                '\nTotale ${formatMinutesAsHours(point.total)}'
                '\nProfondo ${formatMinutesAsHours(point.deep)}'
                '\nREM ${formatMinutesAsHours(point.rem)}'
                '\nLeggero ${formatMinutesAsHours(point.light)}'
                '\nSveglio ${formatMinutesAsHours(point.awake)}',
                TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        barGroups: points.asMap().entries.map((entry) {
          final point = entry.value;
          final total = point.total;
          if (total == null) {
            return BarChartGroupData(x: entry.key, barRods: [
              BarChartRodData(
                toY: 0,
                width: _barWidthForPointCount(points.length),
                color: Colors.transparent,
              ),
            ]);
          }

          final hasStages = [point.deep, point.rem, point.light, point.awake]
              .whereType<double>()
              .any((value) => value > 0);
          if (!hasStages) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: total,
                  width: _barWidthForPointCount(points.length),
                  color: AppTheme.primary.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }

          var from = 0.0;
          BarChartRodStackItem stack(double value, Color color) {
            final item = BarChartRodStackItem(from, from + value, color);
            from += value;
            return item;
          }

          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: total,
                width: _barWidthForPointCount(points.length),
                borderRadius: BorderRadius.circular(4),
                rodStackItems: [
                  stack(point.deep ?? 0, _sleepDeepColor),
                  stack(point.rem ?? 0, _sleepRemColor),
                  stack(point.light ?? 0, _sleepLightColor),
                  stack(point.awake ?? 0, _sleepAwakeColor),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SleepRegularityChart extends StatelessWidget {
  final List<_SleepRegularityPoint> points;

  const _SleepRegularityChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final values = <double>[
      ...points.map((p) => p.bedMinutes).whereType<double>(),
      ...points.map((p) => p.wakeMinutes).whereType<double>(),
    ];
    if (values.isEmpty) return const _NoDataChart();
    final minY = values.reduce(math.min) - 45;
    final maxY = values.reduce(math.max) + 45;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(0, points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.chartGrid,
            strokeWidth: 1,
          ),
        ),
        titlesData: _chartTitles(
          points
              .map((p) => DailyChartPoint(date: p.date, value: p.bedMinutes))
              .toList(),
          leftFormatter: _formatClockAxis,
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final index = spot.x.round().clamp(0, points.length - 1);
              final label = spot.bar.color == _sleepBedtimeColor
                  ? 'Addormentamento'
                  : 'Risveglio';
              return LineTooltipItem(
                '${DateFormat('d/M', 'it').format(points[index].date)}'
                '\n$label ${_formatClockAxis(spot.y)}',
                TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          ..._lineBars(
            points.map((p) => p.bedMinutes).toList(),
            _sleepBedtimeColor,
            width: 3,
            showDots: points.length <= 30,
          ),
          ..._lineBars(
            points.map((p) => p.wakeMinutes).toList(),
            _sleepWakeColor,
            width: 3,
            showDots: points.length <= 30,
          ),
        ],
      ),
    );
  }
}

class _NoDataChart extends StatelessWidget {
  const _NoDataChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Dato non disponibile',
        style: TextStyle(color: AppTheme.textMediumEmphasis),
      ),
    );
  }
}

FlTitlesData _chartTitles(
  List<DailyChartPoint> points, {
  required String Function(double value) leftFormatter,
  double leftReservedSize = 56,
}) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: leftReservedSize,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          axisSide: meta.axisSide,
          space: 8,
          child: Text(
            leftFormatter(value),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (value != index.toDouble() ||
              index < 0 ||
              index >= points.length ||
              !_shouldShowBottomTitle(index, points.length)) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 8,
            child: Text(
              DateFormat('d/M', 'it').format(points[index].date),
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
  );
}

bool _shouldShowBottomTitle(int index, int length) {
  if (length <= 0) return false;
  if (length <= 3) return true;
  final middle = ((length - 1) / 2).round();
  return index == 0 || index == middle || index == length - 1;
}

List<LineChartBarData> _lineBars(
  List<double?> values,
  Color color, {
  required double width,
  bool showDots = true,
}) {
  final bars = <LineChartBarData>[];
  var current = <FlSpot>[];
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value == null || !value.isFinite) {
      if (current.isNotEmpty) {
        bars.add(_lineBar(current, color, width, showDots));
        current = <FlSpot>[];
      }
    } else {
      current.add(FlSpot(index.toDouble(), value));
    }
  }
  if (current.isNotEmpty) {
    bars.add(_lineBar(current, color, width, showDots));
  }
  return bars;
}

LineChartBarData _lineBar(
  List<FlSpot> spots,
  Color color,
  double width,
  bool showDots,
) {
  return LineChartBarData(
    spots: spots,
    isCurved: spots.length > 2,
    color: color,
    barWidth: width,
    isStrokeCapRound: true,
    dotData: FlDotData(
      show: showDots,
      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
        radius: 3,
        color: color,
        strokeWidth: 1.5,
        strokeColor: AppTheme.card,
      ),
    ),
  );
}

double _barWidthForPointCount(int count) {
  if (count >= 90) return 3;
  if (count >= 30) return 5;
  return 9;
}

class _SleepArchitecturePoint {
  final DateTime date;
  final double? totalSleep;
  final double? timeInBed;
  final double? deep;
  final double? rem;
  final double? light;
  final double? awake;

  const _SleepArchitecturePoint({
    required this.date,
    this.totalSleep,
    this.timeInBed,
    this.deep,
    this.rem,
    this.light,
    this.awake,
  });

  double? get total {
    final values = [deep, rem, light, awake].whereType<double>().toList();
    if (values.isEmpty) return totalSleep;
    return values.reduce((a, b) => a + b);
  }
}

class _SleepRegularityPoint {
  final DateTime date;
  final double? bedMinutes;
  final double? wakeMinutes;

  const _SleepRegularityPoint({
    required this.date,
    this.bedMinutes,
    this.wakeMinutes,
  });
}

List<Map<String, dynamic>> _historyWithToday(
  List<Map<String, dynamic>> history,
  Map<String, double> dailyMetrics,
) {
  final todayKey = _dateKey(DateTime.now());
  final hasToday = history.any((item) => item['date'] == todayKey);
  if (hasToday || dailyMetrics['totalSleep'] == null) return history;

  return [
    ...history,
    {
      'date': todayKey,
      'totalSleepMinutes': dailyMetrics['totalSleep'],
      if (dailyMetrics['deepSleep'] != null)
        'deepSleepMinutes': dailyMetrics['deepSleep'],
      if (dailyMetrics['remSleep'] != null)
        'remSleepMinutes': dailyMetrics['remSleep'],
      if (dailyMetrics['lightSleep'] != null)
        'lightSleepMinutes': dailyMetrics['lightSleep'],
      if (dailyMetrics['awake'] != null) 'awakeMinutes': dailyMetrics['awake'],
      if (dailyMetrics['timeInBed'] != null)
        'timeInBedMinutes': dailyMetrics['timeInBed'],
    },
  ];
}

List<DailyChartPoint> _sleepPoints(
  List<Map<String, dynamic>> history,
  int days,
) {
  final byDate = _sleepHistoryByDate(history);
  final end = DateTime.now();
  return List.generate(days, (index) {
    final date = DateTime(end.year, end.month, end.day)
        .subtract(Duration(days: days - index - 1));
    final item = byDate[_dateKey(date)];
    return DailyChartPoint(
      date: date,
      value: _numFromMap(item, 'totalSleepMinutes'),
    );
  });
}

List<_SleepArchitecturePoint> _sleepArchitecturePoints(
  List<Map<String, dynamic>> history,
  int days,
) {
  final byDate = _sleepHistoryByDate(history);
  final end = DateTime.now();
  return List.generate(days, (index) {
    final date = DateTime(end.year, end.month, end.day)
        .subtract(Duration(days: days - index - 1));
    final item = byDate[_dateKey(date)];
    return _SleepArchitecturePoint(
      date: date,
      totalSleep: _numFromMap(item, 'totalSleepMinutes'),
      timeInBed: _numFromMap(item, 'timeInBedMinutes'),
      deep: _numFromMap(item, 'deepSleepMinutes'),
      rem: _numFromMap(item, 'remSleepMinutes'),
      light: _numFromMap(item, 'lightSleepMinutes'),
      awake: _numFromMap(item, 'awakeMinutes'),
    );
  });
}

List<_SleepRegularityPoint> _sleepRegularityPoints(
  List<Map<String, dynamic>> history,
  int days,
) {
  final byDate = _sleepHistoryByDate(history);
  final end = DateTime.now();
  return List.generate(days, (index) {
    final date = DateTime(end.year, end.month, end.day)
        .subtract(Duration(days: days - index - 1));
    final item = byDate[_dateKey(date)];
    return _SleepRegularityPoint(
      date: date,
      bedMinutes:
          _sleepClockMinutes(_timeFromMap(item, 'bedTime'), isWake: false),
      wakeMinutes:
          _sleepClockMinutes(_timeFromMap(item, 'wakeTime'), isWake: true),
    );
  });
}

Map<String, Map<String, dynamic>> _sleepHistoryByDate(
  List<Map<String, dynamic>> history,
) {
  return {
    for (final item in history)
      if (item['date'] is String) item['date'] as String: item,
  };
}

double? _numFromMap(Map<String, dynamic>? map, String key) {
  final value = map?[key];
  return value is num && value.isFinite ? value.toDouble() : null;
}

DateTime? _timeFromMap(Map<String, dynamic>? map, String key) {
  final value = map?[key];
  return value is String ? DateTime.tryParse(value) : null;
}

String _formatClockAxis(double value) {
  final minutes = value.round() % 1440;
  final positive = minutes < 0 ? minutes + 1440 : minutes;
  final hour = (positive ~/ 60).toString().padLeft(2, '0');
  final minute = (positive % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

double? _sleepClockMinutes(DateTime? value, {required bool isWake}) {
  if (value == null) return null;
  final local = value.toLocal();
  var minutes = local.hour * 60 + local.minute;
  if (!isWake && minutes < 12 * 60) minutes += 1440;
  if (isWake && minutes < 18 * 60) minutes += 1440;
  return minutes.toDouble();
}

Color _sleepDebtStatusColor(double? value) {
  if (value == null) return AppTheme.textMediumEmphasis;
  return value > 0 ? _sleepDebtColor : _sleepSurplusColor;
}

String _dateKey(DateTime date) => date.toIso8601String().split('T').first;
