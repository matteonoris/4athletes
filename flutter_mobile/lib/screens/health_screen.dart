import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../utils/health_display_utils.dart';
import '../widgets/custom_card.dart';
import 'analytics_details_screen.dart';
import 'body_metrics_screen.dart';

const _sleepDeepColor = Color(0xFF123B7A);
const _sleepRemColor = Color(0xFFB48CFF);
const _sleepLightColor = Color(0xFF7DDCFF);
Color get _sleepAwakeColor => AppTheme.textMediumEmphasis;
const _sleepBedtimeColor = AppTheme.primary;
const _sleepWakeColor = Color(0xFFB48CFF);
const _sleepDebtColor = AppTheme.error;
const _sleepSurplusColor = AppTheme.secondary;

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final Map<String, int> _ranges = {
    'sleep_need': 14,
    'sleep_debt': 14,
    'sleep_architecture': 14,
    'sleep_regularity': 14,
    'sleep_efficiency': 14,
    'hrv': 30,
    'resting_hr': 30,
    'temp': 30,
    'resp': 30,
    'spo2': 30,
    'weight': 30,
    'height': 30,
    'sleep_score': 30,
    'recovery_score': 30,
  };

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final profile = appState.userProfile;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Salute', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: () => appState.refreshAllHealthData(DateTime.now()),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _sectionTitle('Composizione corporea'),
            _buildBodyCompositionSection(appState, profile),
            const SizedBox(height: 28),
            _sectionTitle('Sleep & recovery score'),
            _buildScoreTrendSection(appState),
            const SizedBox(height: 28),
            _sectionTitle('Sonno'),
            _buildSleepSection(appState),
            const SizedBox(height: 28),
            _sectionTitle('Parametri vitali'),
            _buildVitalsSection(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreTrendSection(AppState appState) {
    final now = DateTime.now();
    final sleepSeries = buildDailySeries(
      logs: appState.bodyLogs,
      type: 'sleep_score',
      endDate: now,
      days: _ranges['sleep_score']!,
    );
    final recoverySeries = buildDailySeries(
      logs: appState.bodyLogs,
      type: 'recovery_score',
      endDate: now,
      days: _ranges['recovery_score']!,
    );

    final sleepValue = appState.currentSleepScore ??
        _latestLogValue(appState.bodyLogs, 'sleep_score');
    final recoveryValue = appState.currentRecoveryScore ??
        _latestLogValue(appState.bodyLogs, 'recovery_score');

    return Column(
      children: [
        _ScoreTrendCard(
          title: 'Sleep Score',
          value: sleepValue,
          series: sleepSeries,
          color: const Color(0xFF5C6CFF),
          days: _ranges['sleep_score']!,
          onDaysChanged: (days) => _setRange('sleep_score', days),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AnalyticsDetailsScreen(
                title: 'Sleep Score',
                type: 'body',
                exerciseId: 'sleep_score',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ScoreTrendCard(
          title: 'Recovery Score',
          value: recoveryValue,
          series: recoverySeries,
          color: AppTheme.secondary,
          days: _ranges['recovery_score']!,
          onDaysChanged: (days) => _setRange('recovery_score', days),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AnalyticsDetailsScreen(
                title: 'Recovery Score',
                type: 'body',
                exerciseId: 'recovery_score',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSleepSection(AppState appState) {
    final metrics = appState.currentDailyMetrics ?? const <String, double>{};
    final todaySleep = _todaySleepEntry(appState.currentLocalSleepHistory);
    final totalSleep =
        metrics['totalSleep'] ?? _numFromMap(todaySleep, 'totalSleepMinutes');
    final need = metrics['dailySleepNeed'];
    final timeInBed =
        metrics['timeInBed'] ?? _numFromMap(todaySleep, 'timeInBedMinutes');
    final deep =
        metrics['deepSleep'] ?? _numFromMap(todaySleep, 'deepSleepMinutes');
    final rem =
        metrics['remSleep'] ?? _numFromMap(todaySleep, 'remSleepMinutes');
    final light =
        metrics['lightSleep'] ?? _numFromMap(todaySleep, 'lightSleepMinutes');
    final awake = metrics['awake'] ?? _numFromMap(todaySleep, 'awakeMinutes');
    final efficiency = totalSleep != null && timeInBed != null && timeInBed > 0
        ? (totalSleep / timeInBed) * 100
        : null;
    final diff = totalSleep != null && need != null ? totalSleep - need : null;

    final bedTime = _timeFromMap(todaySleep, 'bedTime');
    final wakeTime = _timeFromMap(todaySleep, 'wakeTime');
    final regularity = metrics['sleepRegularity'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricGrid([
          _MetricData('Daily Sleep Need', formatMinutesAsHours(need)),
          _MetricData('Sonno effettivo', formatMinutesAsHours(totalSleep)),
          _MetricData('Differenza dal fabbisogno', formatMinutesAsHours(diff)),
          _MetricData('Tempo a letto', formatMinutesAsHours(timeInBed)),
          _MetricData('Efficienza', formatPercent(efficiency)),
          _MetricData('Sonno profondo', formatMinutesAsHours(deep)),
          _MetricData('Sonno REM', formatMinutesAsHours(rem)),
          _MetricData('Sonno leggero', formatMinutesAsHours(light)),
          _MetricData('Tempo sveglio', formatMinutesAsHours(awake)),
          _MetricData('Pisolini', formatMinutesAsHours(metrics['naps'])),
          _MetricData(
            'Debito di sonno',
            formatMinutesAsHours(metrics['sleepDebt']),
            accentColor: _sleepDebtStatusColor(metrics['sleepDebt']),
          ),
          _MetricData('Addormentamento', _formatTime(bedTime)),
          _MetricData('Risveglio', _formatTime(wakeTime)),
          _MetricData('Regolarità del sonno', formatPercent(regularity)),
        ]),
        const SizedBox(height: 16),
        _SleepNeedChartCard(
          title: 'Sonno vs fabbisogno',
          days: _ranges['sleep_need']!,
          onDaysChanged: (days) => _setRange('sleep_need', days),
          history: appState.currentLocalSleepHistory ?? const [],
          dailyNeedMinutes: need,
        ),
        const SizedBox(height: 12),
        _SleepDebtChartCard(
          title: 'Debito di sonno',
          days: _ranges['sleep_debt']!,
          onDaysChanged: (days) => _setRange('sleep_debt', days),
          history: appState.currentLocalSleepHistory ?? const [],
          dailyNeedMinutes: need,
          todaySleepMinutes: totalSleep,
        ),
        const SizedBox(height: 12),
        _SleepArchitectureChartCard(
          title: 'Architettura del sonno',
          days: _ranges['sleep_architecture']!,
          onDaysChanged: (days) => _setRange('sleep_architecture', days),
          history: appState.currentLocalSleepHistory ?? const [],
        ),
        const SizedBox(height: 12),
        _SleepRegularityChartCard(
          title: 'Regolarità del sonno',
          days: _ranges['sleep_regularity']!,
          onDaysChanged: (days) => _setRange('sleep_regularity', days),
          history: appState.currentLocalSleepHistory ?? const [],
        ),
        const SizedBox(height: 12),
        _SleepEfficiencyChartCard(
          title: 'Efficienza del sonno',
          days: _ranges['sleep_efficiency']!,
          onDaysChanged: (days) => _setRange('sleep_efficiency', days),
          history: appState.currentLocalSleepHistory ?? const [],
        ),
      ],
    );
  }

  Widget _buildVitalsSection(AppState appState) {
    final metrics = appState.currentDailyMetrics ?? const <String, double>{};
    return Column(
      children: [
        _VitalMetricCard(
          chartKeyName: 'hrv',
          title: 'HRV',
          todayValue: metrics['hrv'],
          logs: appState.bodyLogs,
          type: 'hrv',
          unit: 'ms',
          decimals: 0,
          days: _ranges['hrv']!,
          onDaysChanged: (days) => _setRange('hrv', days),
        ),
        const SizedBox(height: 12),
        _VitalMetricCard(
          chartKeyName: 'resting_hr',
          title: 'RHR',
          todayValue: metrics['rhr'],
          logs: appState.bodyLogs,
          type: 'resting_hr',
          unit: 'bpm',
          decimals: 0,
          days: _ranges['resting_hr']!,
          onDaysChanged: (days) => _setRange('resting_hr', days),
        ),
        const SizedBox(height: 12),
        _VitalMetricCard(
          chartKeyName: 'temp',
          title: 'Temperatura cutanea',
          todayValue: metrics['temp'],
          logs: appState.bodyLogs,
          type: 'temp',
          unit: '\u00B0C',
          decimals: 1,
          days: _ranges['temp']!,
          onDaysChanged: (days) => _setRange('temp', days),
          emphasizeDifference: true,
        ),
        const SizedBox(height: 12),
        _VitalMetricCard(
          chartKeyName: 'resp',
          title: 'Frequenza respiratoria',
          todayValue: metrics['resp'],
          logs: appState.bodyLogs,
          type: 'resp',
          unit: 'atti/min',
          decimals: 1,
          days: _ranges['resp']!,
          onDaysChanged: (days) => _setRange('resp', days),
        ),
        const SizedBox(height: 12),
        _VitalMetricCard(
          chartKeyName: 'spo2',
          title: 'SpO2',
          todayValue: metrics['spo2'],
          logs: appState.bodyLogs,
          type: 'spo2',
          unit: '%',
          decimals: 0,
          days: _ranges['spo2']!,
          onDaysChanged: (days) => _setRange('spo2', days),
        ),
      ],
    );
  }

  Widget _buildBodyCompositionSection(
    AppState appState,
    UserProfile? profile,
  ) {
    final latestWeight =
        _latestLogValue(appState.bodyLogs, 'weight') ?? profile?.weight;
    final latestHeight =
        _latestLogValue(appState.bodyLogs, 'height') ?? profile?.height;
    final showHeight = shouldShowHeightChart(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricGrid([
          _MetricData(
              'Altezza attuale',
              latestHeight == null
                  ? missingValue
                  : '${latestHeight.toStringAsFixed(0)} cm'),
          _MetricData(
              'Peso attuale',
              latestWeight == null
                  ? missingValue
                  : '${latestWeight.toStringAsFixed(1)} kg'),
        ]),
        const SizedBox(height: 16),
        _BodyMetricChartCard(
          title: 'Peso',
          logs: appState.bodyLogs,
          type: 'weight',
          unit: 'kg',
          decimals: 1,
          days: _ranges['weight']!,
          onDaysChanged: (days) => _setRange('weight', days),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BodyMetricsScreen(initialMetric: 'weight'),
            ),
          ),
        ),
        if (showHeight) ...[
          const SizedBox(height: 12),
          _BodyMetricChartCard(
            title: 'Altezza',
            logs: appState.bodyLogs,
            type: 'height',
            unit: 'cm',
            decimals: 0,
            days: _ranges['height']!,
            onDaysChanged: (days) => _setRange('height', days),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const BodyMetricsScreen(initialMetric: 'height'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textHighEmphasis,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid(List<_MetricData> metrics) {
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return CustomCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                metric.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: metric.accentColor ?? AppTheme.textMediumEmphasis,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: metric.accentColor ?? AppTheme.textHighEmphasis,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setRange(String key, int days) {
    setState(() => _ranges[key] = days);
  }
}

class _ScoreTrendCard extends StatelessWidget {
  final String title;
  final double? value;
  final List<DailyChartPoint> series;
  final Color color;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onTap;

  const _ScoreTrendCard({
    required this.title,
    required this.value,
    required this.series,
    required this.color,
    required this.days,
    required this.onDaysChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _ScoreTrendStats.fromSeries(series, currentValue: value);

    return CustomCard(
      padding: const EdgeInsets.all(18),
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
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value == null ? missingValue : value!.toStringAsFixed(0),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                    ),
                  ],
                ),
              ),
              _RangeSelector(days: days, onChanged: onDaysChanged),
            ],
          ),
          const SizedBox(height: 14),
          _ScoreStatsRow(stats: stats, color: color),
          const SizedBox(height: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              height: 240,
              child: _ScoreTrendChart(
                series: series,
                stats: stats,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStatsRow extends StatelessWidget {
  final _ScoreTrendStats stats;
  final Color color;

  const _ScoreStatsRow({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScoreMiniStat(
            label: 'Media',
            value: _formatScoreStat(stats.average),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ScoreTrendChip(stats: stats, color: color),
        ),
      ],
    );
  }
}

class _ScoreMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreMiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreTrendChip extends StatelessWidget {
  final _ScoreTrendStats stats;
  final Color color;

  const _ScoreTrendChip({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    final delta = stats.deltaFromAverage;
    final hasTrend = delta != null;
    final icon = !hasTrend
        ? Icons.trending_flat
        : delta > 0
            ? Icons.trending_up
            : delta < 0
                ? Icons.trending_down
                : Icons.trending_flat;
    final trendColor = !hasTrend
        ? AppTheme.textMediumEmphasis
        : delta >= 0
            ? color
            : AppTheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: AppTheme.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: trendColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: trendColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              hasTrend ? '${_formatSignedScore(delta)} vs media' : 'Trend n/d',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: trendColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreTrendChart extends StatelessWidget {
  final List<DailyChartPoint> series;
  final _ScoreTrendStats stats;
  final Color color;

  const _ScoreTrendChart({
    required this.series,
    required this.stats,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final values = series.map((point) => point.value).whereType<double>();
    if (values.isEmpty) return const _NoDataChart();

    final lineBars = <LineChartBarData>[];
    final rollingBand = _rollingScoreBandSpots(series);
    final hasBand = rollingBand != null;
    final average = stats.average?.clamp(0.0, 100.0).toDouble();
    final lastValueIndex = _lastValueIndex(series);

    if (rollingBand != null) {
      lineBars.add(_scoreBandLine(rollingBand.lower));
      lineBars.add(_scoreBandLine(rollingBand.upper));
    }

    if (average != null && series.length > 1) {
      lineBars.add(
        LineChartBarData(
          spots: _constantScoreSpots(series.length, average),
          isCurved: false,
          color: AppTheme.textMediumEmphasis.withValues(alpha: 0.62),
          barWidth: 1.5,
          dashArray: [7, 5],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    lineBars.addAll(
      _scoreValueBars(
        series.map((point) => point.value).toList(),
        color,
        lastValueIndex: lastValueIndex,
      ),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(0, series.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.chartGrid,
            strokeWidth: 1,
          ),
        ),
        titlesData: _chartTitles(
          series,
          leftFormatter: (value) => value.toStringAsFixed(0),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        betweenBarsData: hasBand
            ? [
                BetweenBarsData(
                  fromIndex: 0,
                  toIndex: 1,
                  color: color.withValues(
                    alpha: AppTheme.isDark ? 0.12 : 0.09,
                  ),
                ),
              ]
            : const [],
        lineBarsData: lineBars,
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final Color? accentColor;

  const _MetricData(this.label, this.value, {this.accentColor});
}

class _VitalMetricCard extends StatelessWidget {
  final String chartKeyName;
  final String title;
  final double? todayValue;
  final List<BodyMetricLog> logs;
  final String type;
  final String unit;
  final int decimals;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final bool emphasizeDifference;

  const _VitalMetricCard({
    required this.chartKeyName,
    required this.title,
    required this.todayValue,
    required this.logs,
    required this.type,
    required this.unit,
    required this.decimals,
    required this.days,
    required this.onDaysChanged,
    this.emphasizeDifference = false,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOrLatest = todayValue ?? _latestLogValue(logs, type);
    final baseline = rollingBaseline(logs, type, today);
    final diff = todayOrLatest != null && baseline != null
        ? todayOrLatest - baseline
        : null;
    final series = buildDailySeries(
      logs: logs,
      type: type,
      endDate: today,
      days: days,
      includeRollingBaseline: true,
    );

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InlineMetric(
                  label: emphasizeDifference ? 'Differenza' : 'Oggi',
                  value: emphasizeDifference
                      ? formatSigned(diff, unit, decimals: decimals)
                      : _formatNumber(todayOrLatest, unit, decimals),
                  large: true,
                ),
              ),
              Expanded(
                child: _InlineMetric(
                  label: 'Baseline 30 giorni',
                  value: _formatNumber(baseline, unit, decimals),
                ),
              ),
              Expanded(
                child: _InlineMetric(
                  label: emphasizeDifference ? 'Oggi' : 'Diff.',
                  value: emphasizeDifference
                      ? _formatNumber(todayOrLatest, unit, decimals)
                      : formatSigned(diff, unit, decimals: decimals),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: _LineSeriesChart(
              series: series,
              valueColor: AppTheme.primary,
              baselineColor: AppTheme.textMediumEmphasis,
              unit: unit,
              decimals: decimals,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _vitalDescription(title, todayOrLatest, baseline),
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyMetricChartCard extends StatelessWidget {
  final String title;
  final List<BodyMetricLog> logs;
  final String type;
  final String unit;
  final int decimals;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback? onTap;

  const _BodyMetricChartCard({
    required this.title,
    required this.logs,
    required this.type,
    required this.unit,
    required this.decimals,
    required this.days,
    required this.onDaysChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final metricLogs = logs.where((log) {
      if (log.type != type) return false;
      final date = DateTime.tryParse(log.date);
      return date != null && date.isAfter(cutoff);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final fatLogs = type == 'weight'
        ? (logs.where((log) {
            if (log.type != 'fat') return false;
            final date = DateTime.tryParse(log.date);
            return date != null && date.isAfter(cutoff);
          }).toList()
          ..sort((a, b) => a.date.compareTo(b.date)))
        : <BodyMetricLog>[];

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              _RangeSelector(days: days, onChanged: onDaysChanged),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              height: 210,
              child: type == 'weight'
                  ? _BodyCompositionLineChart(
                      weightLogs: metricLogs,
                      fatLogs: fatLogs,
                      days: days,
                    )
                  : _LineSeriesChart(
                      series: metricLogs
                          .map((log) => DailyChartPoint(
                                date: DateTime.parse(log.date),
                                value: log.value,
                              ))
                          .toList(),
                      valueColor: AppTheme.primary,
                      unit: unit,
                      decimals: decimals,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyCompositionLineChart extends StatelessWidget {
  final List<BodyMetricLog> weightLogs;
  final List<BodyMetricLog> fatLogs;
  final int days;

  const _BodyCompositionLineChart({
    required this.weightLogs,
    required this.fatLogs,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    if (weightLogs.isEmpty) return const _NoDataChart();

    var minW = weightLogs.map((log) => log.value).reduce(math.min) - 2;
    var maxW = weightLogs.map((log) => log.value).reduce(math.max) + 2;
    var minF = fatLogs.isNotEmpty
        ? fatLogs.map((log) => log.value).reduce(math.min) - 2
        : 10.0;
    var maxF = fatLogs.isNotEmpty
        ? fatLogs.map((log) => log.value).reduce(math.max) + 2
        : 25.0;
    if (minW == maxW) {
      minW -= 1;
      maxW += 1;
    }
    if (minF == maxF) {
      minF -= 1;
      maxF += 1;
    }

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final chartStart = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final chartEnd = DateTime(now.year, now.month, now.day);
    final chartDays = math.max(1, chartEnd.difference(chartStart).inDays);

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
      return ((fat - minF) / (maxF - minF)) * (maxW - minW) + minW;
    }

    double unscaleFat(double value) {
      return ((value - minW) / (maxW - minW)) * (maxF - minF) + minF;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: chartDays.toDouble(),
        minY: minW,
        maxY: maxW,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.chartGrid,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: chartDays / 2,
              getTitlesWidget: (value, meta) {
                final isEdgeOrMiddle = (value - 0).abs() < 0.01 ||
                    (value - chartDays / 2).abs() < 0.01 ||
                    (value - chartDays).abs() < 0.01;
                if (!isEdgeOrMiddle) return const SizedBox.shrink();
                final date = chartStart.add(Duration(days: value.round()));
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('d/M', 'it').format(date),
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
            axisNameWidget: const Text(
              'Massa grassa %',
              style: TextStyle(
                color: AppTheme.secondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            sideTitles: SideTitles(
              showTitles: fatLogs.isNotEmpty,
              reservedSize: fatLogs.isNotEmpty ? 42 : 0,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: Text(
                  unscaleFat(value).toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          rightTitles: AxisTitles(
            axisNameWidget: const Text(
              'Peso kg',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                space: 6,
                child: Text(
                  value.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final isFat = spot.bar.color == AppTheme.secondary;
              return LineTooltipItem(
                isFat
                    ? '${unscaleFat(spot.y).toStringAsFixed(1)} %'
                    : '${spot.y.toStringAsFixed(1)} kg',
                TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          _lineBar(
            weightLogs
                .map((log) => FlSpot(xForDate(log.date), log.value))
                .toList(),
            AppTheme.primary,
            3,
            null,
          ),
          if (fatLogs.isNotEmpty)
            _lineBar(
              fatLogs
                  .map((log) => FlSpot(xForDate(log.date), scaleFat(log.value)))
                  .toList(),
              AppTheme.secondary,
              3,
              null,
            ),
        ],
      ),
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
      footer: _sleepNeedDescription(points, dailyNeedMinutes, days),
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
      footer:
          'Sopra 0 indica sonno sotto il fabbisogno; sotto 0 indica surplus.',
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
      footer: 'Le fasi del sonno sono stime del dispositivo.',
      child: _SleepArchitectureChart(
          points: _sleepArchitecturePoints(history, days)),
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
      footer: 'Le linee tratteggiate indicano gli orari medi del periodo.',
      child:
          _SleepRegularityChart(points: _sleepRegularityPoints(history, days)),
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
  final String? footer;
  final List<_LegendItem> legend;

  const _ChartCardShell({
    required this.title,
    required this.days,
    required this.onDaysChanged,
    required this.child,
    this.footer,
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
          if (footer != null) ...[
            const SizedBox(height: 10),
            Text(
              footer!,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 12,
              ),
            ),
          ],
        ],
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

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool large;

  const _InlineMetric({
    required this.label,
    required this.value,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontSize: large ? 22 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _LineSeriesChart extends StatelessWidget {
  final List<DailyChartPoint> series;
  final Color valueColor;
  final Color? baselineColor;
  final String unit;
  final int decimals;
  final double? minYOverride;
  final double? maxYOverride;

  const _LineSeriesChart({
    required this.series,
    required this.valueColor,
    required this.unit,
    required this.decimals,
    this.baselineColor,
    this.minYOverride,
    this.maxYOverride,
  });

  @override
  Widget build(BuildContext context) {
    final values = <double>[
      ...series.map((p) => p.value).whereType<double>(),
      ...series.map((p) => p.baseline).whereType<double>(),
    ];
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
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(decimals)} $unit',
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
            series.map((p) => p.value).toList(),
            valueColor,
            width: 3,
          ),
          if (baselineColor != null)
            ..._lineBars(
              series.map((p) => p.baseline).toList(),
              baselineColor!,
              width: 2,
              dashArray: [6, 4],
            ),
        ],
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
                    'Sonno\n${formatMinutesAsHours(value)}',
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
                '$label\n${formatMinutesAsHours(value.abs())}',
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
                'Totale ${formatMinutesAsHours(point.total)}'
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
    var minY = values.reduce(math.min) - 45;
    var maxY = values.reduce(math.max) + 45;
    final avgBedMinutes = _averageNullable(
      points.map((point) => point.bedMinutes),
    );
    final avgWakeMinutes = _averageNullable(
      points.map((point) => point.wakeMinutes),
    );

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
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (avgBedMinutes != null)
              HorizontalLine(
                y: avgBedMinutes,
                color: _sleepBedtimeColor.withValues(alpha: 0.48),
                strokeWidth: 1.6,
                dashArray: [6, 4],
              ),
            if (avgWakeMinutes != null)
              HorizontalLine(
                y: avgWakeMinutes,
                color: _sleepWakeColor.withValues(alpha: 0.48),
                strokeWidth: 1.6,
                dashArray: [6, 4],
              ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final label = spot.bar.color == _sleepBedtimeColor
                  ? 'Addormentamento'
                  : 'Risveglio';
              return LineTooltipItem(
                '$label\n${_formatClockAxis(spot.y)}',
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
  List<int>? dashArray,
  bool showDots = true,
}) {
  final bars = <LineChartBarData>[];
  var current = <FlSpot>[];
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value == null || !value.isFinite) {
      if (current.isNotEmpty) {
        bars.add(_lineBar(current, color, width, dashArray, showDots));
        current = <FlSpot>[];
      }
    } else {
      current.add(FlSpot(index.toDouble(), value));
    }
  }
  if (current.isNotEmpty) {
    bars.add(_lineBar(current, color, width, dashArray, showDots));
  }
  return bars;
}

LineChartBarData _lineBar(
  List<FlSpot> spots,
  Color color,
  double width,
  List<int>? dashArray, [
  bool showDots = true,
]) {
  return LineChartBarData(
    spots: spots,
    isCurved: spots.length > 2,
    color: color,
    barWidth: width,
    isStrokeCapRound: true,
    dashArray: dashArray,
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

double? _averageNullable(Iterable<double?> values) {
  var total = 0.0;
  var count = 0;
  for (final value in values) {
    if (value == null || !value.isFinite) continue;
    total += value;
    count += 1;
  }
  return count == 0 ? null : total / count;
}

class _ScoreTrendStats {
  final double? average;
  final double? currentValue;

  const _ScoreTrendStats({
    required this.average,
    required this.currentValue,
  });

  factory _ScoreTrendStats.fromSeries(
    List<DailyChartPoint> series, {
    double? currentValue,
  }) {
    final values = series.map((point) => point.value).whereType<double>().where(
          (value) => value.isFinite,
        );
    final list = values.toList(growable: false);
    if (list.isEmpty) {
      return _ScoreTrendStats(
        average: null,
        currentValue: currentValue,
      );
    }

    final average = list.reduce((a, b) => a + b) / list.length;
    final latestValue = currentValue ??
        series.reversed.map((point) => point.value).firstWhere(
            (value) => value != null && value.isFinite,
            orElse: () => null);

    return _ScoreTrendStats(
      average: average,
      currentValue: latestValue,
    );
  }

  double? get deltaFromAverage =>
      average != null && currentValue != null ? currentValue! - average! : null;
}

String _formatScoreStat(double? value) {
  if (value == null || !value.isFinite) return missingValue;
  return value.toStringAsFixed(0);
}

String _formatSignedScore(double value) {
  if (!value.isFinite) return missingValue;
  final rounded = value.round();
  if (rounded == 0) return '0';
  return '${rounded > 0 ? '+' : ''}$rounded';
}

int? _lastValueIndex(List<DailyChartPoint> series) {
  for (var index = series.length - 1; index >= 0; index--) {
    final value = series[index].value;
    if (value != null && value.isFinite) return index;
  }
  return null;
}

List<FlSpot> _constantScoreSpots(int count, double value) {
  return List<FlSpot>.generate(
    count,
    (index) => FlSpot(index.toDouble(), value),
  );
}

class _ScoreBandSpots {
  final List<FlSpot> lower;
  final List<FlSpot> upper;

  const _ScoreBandSpots({required this.lower, required this.upper});
}

_ScoreBandSpots? _rollingScoreBandSpots(
  List<DailyChartPoint> series, {
  int windowDays = 7,
  int minimumValues = 3,
}) {
  final lower = <FlSpot>[];
  final upper = <FlSpot>[];
  var validBandPoints = 0;

  for (var index = 0; index < series.length; index++) {
    final windowStart = math.max(0, index - windowDays + 1);
    final windowValues = series
        .sublist(windowStart, index + 1)
        .map((point) => point.value)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);

    if (windowValues.length < minimumValues) {
      lower.add(FlSpot.nullSpot);
      upper.add(FlSpot.nullSpot);
      continue;
    }

    final average = windowValues.reduce((a, b) => a + b) / windowValues.length;
    final variance = windowValues
            .map((value) => math.pow(value - average, 2).toDouble())
            .reduce((a, b) => a + b) /
        windowValues.length;
    final deviation = math.sqrt(variance);

    lower.add(FlSpot(index.toDouble(), (average - deviation).clamp(0, 100)));
    upper.add(FlSpot(index.toDouble(), (average + deviation).clamp(0, 100)));
    validBandPoints += 1;
  }

  if (validBandPoints < 2) return null;
  return _ScoreBandSpots(lower: lower, upper: upper);
}

LineChartBarData _scoreBandLine(List<FlSpot> spots) {
  return LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.2,
    preventCurveOverShooting: true,
    color: Colors.transparent,
    barWidth: 0,
    dotData: const FlDotData(show: false),
  );
}

List<LineChartBarData> _scoreValueBars(
  List<double?> values,
  Color color, {
  required int? lastValueIndex,
}) {
  final bars = <LineChartBarData>[];
  var current = <FlSpot>[];
  for (var index = 0; index < values.length; index++) {
    final value = values[index];
    if (value == null || !value.isFinite) {
      if (current.isNotEmpty) {
        bars.add(_scoreValueBar(current, color, lastValueIndex));
        current = <FlSpot>[];
      }
    } else {
      current.add(FlSpot(index.toDouble(), value));
    }
  }
  if (current.isNotEmpty) {
    bars.add(_scoreValueBar(current, color, lastValueIndex));
  }
  return bars;
}

LineChartBarData _scoreValueBar(
  List<FlSpot> spots,
  Color color,
  int? lastValueIndex,
) {
  return LineChartBarData(
    spots: spots,
    isCurved: spots.length > 2,
    curveSmoothness: 0.24,
    preventCurveOverShooting: true,
    color: color,
    barWidth: 3.4,
    isStrokeCapRound: true,
    isStrokeJoinRound: true,
    belowBarData: BarAreaData(
      show: true,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: AppTheme.isDark ? 0.14 : 0.12),
          color.withValues(alpha: 0.015),
        ],
      ),
    ),
    dotData: FlDotData(
      show: true,
      checkToShowDot: (spot, barData) {
        if (lastValueIndex == null) return spots.length <= 14;
        return spot.x.round() == lastValueIndex || spots.length <= 14;
      },
      getDotPainter: (spot, percent, barData, index) {
        final isLatest =
            lastValueIndex != null && spot.x.round() == lastValueIndex;
        return FlDotCirclePainter(
          radius: isLatest ? 5 : 2.7,
          color: color,
          strokeWidth: isLatest ? 2.5 : 1.5,
          strokeColor: AppTheme.card,
        );
      },
    ),
  );
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

Map<String, dynamic>? _todaySleepEntry(List<Map<String, dynamic>>? history) {
  if (history == null) return null;
  final today = _dateKey(DateTime.now());
  for (final item in history) {
    if (item['date'] == today) return item;
  }
  return history.isNotEmpty ? history.first : null;
}

double? _numFromMap(Map<String, dynamic>? map, String key) {
  final value = map?[key];
  return value is num && value.isFinite ? value.toDouble() : null;
}

DateTime? _timeFromMap(Map<String, dynamic>? map, String key) {
  final value = map?[key];
  return value is String ? DateTime.tryParse(value) : null;
}

String _formatTime(DateTime? value) {
  if (value == null) return missingValue;
  return DateFormat.Hm('it').format(value.toLocal());
}

String _formatNumber(double? value, String unit, int decimals) {
  if (value == null || !value.isFinite) return missingValue;
  return '${value.toStringAsFixed(decimals)} $unit';
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

double? _latestLogValue(List<BodyMetricLog> logs, String type) {
  final filtered = logs.where((log) => log.type == type).toList()
    ..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
  return filtered.isEmpty ? null : filtered.last.value;
}

String _vitalDescription(String title, double? today, double? baseline) {
  if (today == null || baseline == null) return 'Dato non disponibile.';
  if (today > baseline) {
    return '$title oggi è superiore rispetto alla baseline a 30 giorni.';
  }
  if (today < baseline) {
    return '$title oggi è inferiore rispetto alla baseline a 30 giorni.';
  }
  return '$title oggi è in linea con la baseline a 30 giorni.';
}

String? _sleepNeedDescription(
  List<DailyChartPoint> points,
  double? dailyNeed,
  int days,
) {
  if (dailyNeed == null) return null;
  final available = points.map((p) => p.value).whereType<double>().toList();
  if (available.isEmpty) return null;
  final below = available.where((value) => value < dailyNeed).length;
  if (below > available.length / 2) {
    return 'Il sonno effettivo degli ultimi $days giorni è spesso inferiore al fabbisogno stimato.';
  }
  return 'Il sonno effettivo degli ultimi $days giorni è spesso in linea con il fabbisogno stimato.';
}
