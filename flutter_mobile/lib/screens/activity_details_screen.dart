import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../models/training_activity_models.dart';
import '../utils/time_utils.dart';
import '../utils/coach_training_utils.dart';
import '../utils/training_metrics_utils.dart';
import '../services/health_import_normalizer.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';
import 'add_training_screen.dart';
import 'athlete_event_screen.dart';
import 'dryland_activity_screen.dart';
import 'ski_activity_screen.dart';

class _HrChartPoint {
  final int time;
  final double bpm;

  const _HrChartPoint(this.time, this.bpm);
}

class ActivityDetailsScreen extends StatelessWidget {
  final TrainingSession session;

  /// Optional: display name for the sport (e.g. "POWERLIFTING").
  /// If not provided it is derived from sportId.
  final String? sportName;
  final List<PRLog>? prLogs;

  const ActivityDetailsScreen(
      {super.key, required this.session, this.sportName, this.prLogs});

  Widget _buildMetric(BuildContext context, IconData icon, Color color,
      String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(label,
              style:
                  TextStyle(fontSize: 10, color: AppTheme.textMediumEmphasis)),
        ],
      ),
    );
  }

  Widget _buildHrZonesChart(BuildContext context, List<int> zoneMins) {
    final colors = [
      Colors.grey,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red
    ];
    final labels = [
      'Z1 Recupero',
      'Z2 Fondo',
      'Z3 Tempo',
      'Z4 Soglia',
      'Z5 Max'
    ];

    int maxMins = zoneMins.fold(0, (max, v) => v > max ? v : max);
    if (maxMins == 0) maxMins = 1; // avoid division by zero

    return Column(
      children: List.generate(5, (index) {
        int mins = zoneMins[index];
        double fraction = mins / maxMins;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(labels[index],
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.subtleFill,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction > 0 ? fraction : 0.01,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[index],
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                                color: colors[index].withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${mins}m',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeartRatePanel(
      BuildContext context, Map<String, dynamic> details) {
    final samples = _parseHrSamples(details['hr_samples']);
    final activeSeconds = _asInt(details['active_duration_seconds']) ??
        TimeUtils.parseDurationToMinutes(session.duration) * 60;
    final coverageSeconds = _asInt(details['hr_coverage_seconds']) ?? 0;
    final reliable = details['hr_reliable'] == true &&
        samples.length >= 5 &&
        activeSeconds > 0 &&
        coverageSeconds / activeSeconds >= 0.50;

    if (!reliable) return const SizedBox();

    final zones = _parseZoneBoundaries(details['hr_zone_boundaries']);
    final zoneSeconds = _parseZoneSeconds(details['hr_zones_seconds']);
    final avgHr = _asInt(details['avg_hr']) ?? _averageHr(samples);
    final dominantZone =
        _asInt(details['dominant_hr_zone']) ?? _dominantZone(zoneSeconds);
    final colors = _hrZoneColors();
    final totalZoneSeconds =
        zoneSeconds.fold<int>(0, (sum, value) => sum + value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: CustomCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Frequenza cardiaca',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$avgHr bpm',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 34)),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('FC media',
                      style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text('Zona $dominantZone',
                    style: TextStyle(
                        color: colors[dominantZone.clamp(0, 5)],
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 190,
              child: LineChart(_buildHrChartData(samples, zones, colors)),
            ),
            const SizedBox(height: 18),
            _buildHrZoneLegend(zones, colors),
            const SizedBox(height: 22),
            _buildHrZoneTable(zoneSeconds, totalZoneSeconds, colors),
          ],
        ),
      ),
    );
  }

  LineChartData _buildHrChartData(
    List<_HrChartPoint> samples,
    List<Map<String, int>> zones,
    List<Color> colors,
  ) {
    final start = samples.first.time;
    final end = samples.last.time;
    final minHr = samples.map((s) => s.bpm).reduce((a, b) => a < b ? a : b);
    final maxHr = samples.map((s) => s.bpm).reduce((a, b) => a > b ? a : b);
    final chartMin = (minHr - 12).clamp(40, 220).toDouble();
    final chartMax = (maxHr + 12).clamp(chartMin + 20, 240).toDouble();

    final bars = <LineChartBarData>[];
    for (var i = 0; i < samples.length - 1; i++) {
      final current = samples[i];
      final next = samples[i + 1];
      final gapSeconds = (next.time - current.time) ~/ 1000;
      if (gapSeconds <= 0 ||
          gapSeconds > HealthImportNormalizer.maxContinuousHrGapSeconds) {
        continue;
      }

      final zone = _zoneIndexForHr(current.bpm, zones);
      bars.add(LineChartBarData(
        spots: [
          FlSpot((current.time - start) / 60000.0, current.bpm),
          FlSpot((next.time - start) / 60000.0, next.bpm),
        ],
        isCurved: false,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: colors[zone].withValues(alpha: 0.05),
        ),
        color: colors[zone],
      ));
    }

    return LineChartData(
      minX: 0,
      maxX: (end - start) / 60000.0,
      minY: chartMin,
      maxY: chartMax,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: ((chartMax - chartMin) / 2).clamp(10, 50),
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppTheme.chartGrid, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: chartMax - chartMin,
            getTitlesWidget: (value, meta) => Text(
              value.round().toString(),
              style:
                  TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 11),
            ),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: ((end - start) / 60000.0) / 2,
            getTitlesWidget: (value, meta) {
              final t = DateTime.fromMillisecondsSinceEpoch(
                  start + (value * 60000).round());
              return Text(_formatTimeLabel(t),
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis, fontSize: 11));
            },
          ),
        ),
      ),
      lineBarsData: bars,
      lineTouchData: const LineTouchData(enabled: false),
    );
  }

  Widget _buildHrZoneLegend(List<Map<String, int>> zones, List<Color> colors) {
    final labels = ['Z0', 'Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    final thresholds = [
      '0',
      zones[0]['min'].toString(),
      zones[1]['min'].toString(),
      zones[2]['min'].toString(),
      zones[3]['min'].toString(),
      '${zones[4]['min']}+',
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(labels.length, (i) {
            return Text(labels[i],
                style: TextStyle(
                    color: colors[i],
                    fontWeight: FontWeight.bold,
                    fontSize: 12));
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(labels.length, (i) {
            return Expanded(
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0 ? const Radius.circular(8) : Radius.zero,
                    right: i == labels.length - 1
                        ? const Radius.circular(8)
                        : Radius.zero,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: thresholds
              .map((value) => Text(value,
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis, fontSize: 12)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildHrZoneTable(
    List<int> zoneSeconds,
    int totalSeconds,
    List<Color> colors,
  ) {
    final maxSeconds =
        zoneSeconds.fold<int>(0, (max, value) => value > max ? value : max);

    return Column(
      children: List.generate(6, (index) {
        final seconds = index < zoneSeconds.length ? zoneSeconds[index] : 0;
        final percentage =
            totalSeconds > 0 ? ((seconds / totalSeconds) * 100).round() : 0;
        final widthFactor = maxSeconds > 0 ? seconds / maxSeconds : 0.0;
        final muted = seconds == 0;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.divider),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text('$index',
                    style: TextStyle(
                        color: muted
                            ? AppTheme.textMediumEmphasis.withValues(alpha: 0.6)
                            : AppTheme.textHighEmphasis,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 86,
                child: Text(_formatSeconds(seconds),
                    style: TextStyle(
                        color: muted
                            ? AppTheme.textMediumEmphasis.withValues(alpha: 0.6)
                            : AppTheme.textHighEmphasis,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: widthFactor.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors[index],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: Text('$percentage%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: muted
                            ? AppTheme.textMediumEmphasis.withValues(alpha: 0.6)
                            : AppTheme.textHighEmphasis,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<_HrChartPoint> _parseHrSamples(dynamic value) {
    if (value is! List) return [];
    final samples = <_HrChartPoint>[];
    for (final item in value) {
      if (item is! Map) continue;
      final time = _asInt(item['time']);
      final bpm = _asDouble(item['bpm']);
      if (time == null || bpm == null) continue;
      samples.add(_HrChartPoint(time, bpm));
    }
    samples.sort((a, b) => a.time.compareTo(b.time));
    return samples;
  }

  List<Map<String, int>> _parseZoneBoundaries(dynamic value) {
    if (value is List && value.length >= 5) {
      return value.take(5).map((item) {
        final map = item as Map;
        return {
          'min': _asInt(map['min']) ?? 0,
          'max': _asInt(map['max']) ?? 300,
        };
      }).toList();
    }
    return [
      {'min': 98, 'max': 116},
      {'min': 117, 'max': 136},
      {'min': 137, 'max': 155},
      {'min': 156, 'max': 175},
      {'min': 176, 'max': 300},
    ];
  }

  List<int> _parseZoneSeconds(dynamic value) {
    if (value is List) {
      final seconds = value.map((item) => _asInt(item) ?? 0).toList();
      if (seconds.length >= 6) return seconds.take(6).toList();
      if (seconds.length == 5) return [0, ...seconds];
    }
    final legacyMinutes = session.details?['hr_zones'];
    if (legacyMinutes is List) {
      final mins = legacyMinutes.map((item) => _asInt(item) ?? 0).toList();
      if (mins.length == 5) return [0, ...mins.map((m) => m * 60)];
      if (mins.length >= 6) return mins.take(6).map((m) => m * 60).toList();
    }
    return List<int>.filled(6, 0);
  }

  List<Color> _hrZoneColors() {
    return const [
      Color(0xFFA8C0FF),
      Color(0xFF2E86DE),
      Color(0xFFFFC300),
      Color(0xFFFF9F1C),
      Color(0xFFFF3B30),
      Color(0xFF8A3FFC),
    ];
  }

  int _zoneIndexForHr(double bpm, List<Map<String, int>> zones) {
    if (bpm < (zones.first['min'] ?? 0)) return 0;
    for (var i = zones.length - 1; i >= 0; i--) {
      final min = zones[i]['min'] ?? 0;
      final max = zones[i]['max'] ?? 300;
      final isLast = i == zones.length - 1;
      if (bpm >= min && (isLast || bpm < max)) return i + 1;
    }
    return 5;
  }

  int _averageHr(List<_HrChartPoint> samples) {
    if (samples.isEmpty) return 0;
    return (samples.fold<double>(0, (sum, sample) => sum + sample.bpm) /
            samples.length)
        .round();
  }

  int _dominantZone(List<int> zoneSeconds) {
    if (zoneSeconds.isEmpty) return 0;
    var bestIndex = 0;
    for (var i = 1; i < zoneSeconds.length; i++) {
      if (zoneSeconds[i] > zoneSeconds[bestIndex]) bestIndex = i;
    }
    return bestIndex;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTimeLabel(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String? _getMetricValue(Map<String, dynamic>? details, List<String> keys,
      {String? fallbackUnit}) {
    if (details == null) return null;
    for (var k in keys) {
      if (details.containsKey(k) && details[k] != null) {
        String val = details[k].toString().trim();
        if (val.isEmpty || val == 'null' || val == '--') return null;
        if (fallbackUnit != null && !val.contains(RegExp(r'[a-zA-Z]'))) {
          return '$val $fallbackUnit';
        }
        return val;
      }
    }
    return null;
  }

  String _formatKey(String key) {
    // Basic formatting for camelCase keys
    final formatted =
        key.replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}');
    if (formatted.isEmpty) return key;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textMediumEmphasis)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  List<PRLog> _effectivePrLogs(BuildContext context) {
    return prLogs ?? Provider.of<AppState>(context, listen: false).prLogs;
  }

  double _oneRepMaxForExercise(
    BuildContext context,
    String exerciseId,
    List<PRLog> logs,
  ) {
    var maxLoad = 0.0;
    for (final log in logs.where((l) => l.exerciseId == exerciseId)) {
      if (log.weight > maxLoad) maxLoad = log.weight;
    }
    var profileMax = 0.0;
    if (prLogs == null) {
      profileMax = Provider.of<AppState>(context, listen: false)
              .userProfile
              ?.oneRepMax?[exerciseId] ??
          0.0;
    }
    return profileMax > maxLoad ? profileMax : maxLoad;
  }

  String _formatLoad(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  String _strengthSetText(
    int setIndex, {
    double? kg,
    int? reps,
    int? durationSeconds,
    double? percent1RM,
    required double maxLoad,
  }) {
    final parts = <String>[];
    final load = kg ?? 0;
    if (load > 0) parts.add('${_formatLoad(load)} kg');
    if ((reps ?? 0) > 0) parts.add('$reps reps');
    if ((durationSeconds ?? 0) > 0) parts.add('${durationSeconds}s');
    if (parts.isEmpty) parts.add('dati non compilati');

    final pct = (percent1RM ?? 0) > 0
        ? percent1RM!
        : maxLoad > 0 && load > 0
            ? (load / maxLoad) * 100
            : null;
    final pctStr = pct == null ? '' : ' (${pct.toStringAsFixed(0)}% 1RM)';
    return 'Set ${setIndex + 1}: ${parts.join(' x ')}$pctStr';
  }

  Widget _buildDetailsMap(
      BuildContext context, Map<String, dynamic> data, List<PRLog> prLogs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) {
        if (e.key == 'painZones') return const SizedBox(); // Handled separately
        if (e.key == 'chronoLaps' && e.value is List) {
          final laps = e.value as List;
          if (laps.isEmpty) return const SizedBox();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text('CRONOMETRO & MATERIALI',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.secondary)),
              const SizedBox(height: 8),
              ...laps.asMap().entries.map((entry) {
                final idx = entry.key;
                final lap = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          left: BorderSide(color: AppTheme.primary, width: 2)),
                    ),
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GIRO ${idx + 1}',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        if ((lap['time']?.toString() ?? '').isNotEmpty)
                          Text('Tempo: ${lap['time']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        if ((lap['material']?.toString() ?? '').isNotEmpty)
                          Text('Materiale: ${lap['material']}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMediumEmphasis)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        }
        if (e.value is Map) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(_formatKey(e.key),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.secondary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(left: 12.0),
                decoration: const BoxDecoration(
                  border: Border(
                      left: BorderSide(color: AppTheme.secondary, width: 2)),
                ),
                child: _buildDetailsMap(
                    context, e.value as Map<String, dynamic>, prLogs),
              ),
            ],
          );
        } else if (e.value is List) {
          final list = e.value as List;
          if (list.isNotEmpty && list.first is Map) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(_formatKey(e.key),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary)),
                const SizedBox(height: 8),
                ...list.map((item) {
                  final mapItem = item as Map<String, dynamic>;
                  if (mapItem.containsKey('name') &&
                      mapItem.containsKey('sets')) {
                    final sets = mapItem['sets'] as List;
                    final exerciseId =
                        (mapItem['exerciseId'] ?? mapItem['id'] ?? '')
                            .toString();
                    final maxLoad =
                        _oneRepMaxForExercise(context, exerciseId, prLogs);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('- ${mapItem['name']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          ...sets.asMap().entries.map((setEntry) {
                            final setIdx = setEntry.key;
                            final setVal =
                                setEntry.value as Map<String, dynamic>;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(left: 16.0, top: 4.0),
                              child: Text(
                                  _strengthSetText(
                                    setIdx,
                                    kg: (setVal['kg'] as num?)?.toDouble(),
                                    reps: (setVal['reps'] as num?)?.toInt(),
                                    durationSeconds:
                                        (setVal['durationSeconds'] as num?)
                                            ?.toInt(),
                                    percent1RM: (setVal['percent1RM'] as num?)
                                            ?.toDouble() ??
                                        (setVal['percent1rm'] as num?)
                                            ?.toDouble(),
                                    maxLoad: maxLoad,
                                  ),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMediumEmphasis)),
                            );
                          }),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 16.0),
                    child: _buildDetailsMap(context, mapItem, prLogs),
                  );
                }),
              ],
            );
          } else {
            final listStr = list.join(', ');
            return _buildDetailRow(context, _formatKey(e.key),
                listStr.isEmpty ? 'Nessuno' : listStr);
          }
        }
        return _buildDetailRow(
            context, _formatKey(e.key), e.value?.toString() ?? 'Nessuno');
      }).toList(),
    );
  }

  bool get _isCoachSkiSession {
    final details = session.details;
    return session.sportId == 'alpine_skiing' &&
        details != null &&
        (details['from_calendar'] == true ||
            session.eventId != null ||
            details['skiSchemaVersion'] == 2);
  }

  bool get _isStructuredDrylandSession {
    final details = session.details;
    return details != null &&
        details['activityDomain'] == 'dryland' &&
        details['blocks'] is List;
  }

  CalendarEvent? _findSourceEvent(AppState appState) {
    if (session.eventId == null) return null;
    for (final event in appState.coachEvents) {
      if (event.id == session.eventId) return event;
    }
    return null;
  }

  Widget _buildCoachSkiSession(BuildContext context, String displayName) {
    final details = session.details ?? {};
    final summary = CoachTrainingUtils.volumeFromDetails(details);
    final appState = Provider.of<AppState>(context, listen: false);
    final sourceEvent = _findSourceEvent(appState);
    final specialty = CoachTrainingUtils.specialtyFromDetails(details);
    final athleteModified = details['athleteModified'] == true;
    final isCoachSession =
        details['from_calendar'] == true || session.eventId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio Attività'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.pencilSimple,
                color: AppTheme.primary),
            tooltip: isCoachSession
                ? 'Personalizza allenamento'
                : 'Modifica allenamento',
            onPressed: () {
              if (sourceEvent != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AthleteEventScreen(event: sourceEvent),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SkiActivityScreen(initialSession: session),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CustomCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.mountains,
                        color: AppTheme.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        displayName.toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _compactBadge('RPE ${session.effort}', AppTheme.primary),
                  ],
                ),
                const SizedBox(height: 12),
                _compactBadge(
                  isCoachSession ? 'Creato dal coach' : 'Creato da te',
                  isCoachSession ? AppTheme.secondary : AppTheme.primary,
                ),
                if (athleteModified) ...[
                  const SizedBox(height: 8),
                  _compactBadge('Modificato da te', AppTheme.success),
                ],
                const SizedBox(height: 18),
                _buildDetailRow(context, 'Specialità e data',
                    '$specialty · ${session.date}'),
                _buildDetailRow(context, 'Orario',
                    '${session.startTime} - ${session.endTime}'),
                _buildDetailRow(context, 'Durata',
                    TimeUtils.formatDuration(session.duration)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSkiSummaryCard(context, summary),
          const SizedBox(height: 24),
          _buildSkiTechnicalCard(context, details),
          const SizedBox(height: 24),
          _buildSkiConditionsCard(context, details),
          const SizedBox(height: 24),
          _buildSkiPersonalCard(context, details, athleteModified),
        ],
      ),
    );
  }

  Widget _compactBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSkiSummaryCard(
    BuildContext context,
    TrainingVolumeSummary summary,
  ) {
    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Riepilogo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _summaryLine(
            context,
            'Campo libero',
            '${summary.freeLaps} giri · ${summary.freeDirectionChanges} cambi',
          ),
          _summaryLine(
            context,
            'Pali',
            '${summary.poleLaps} giri · ${summary.polePasses} passaggi',
          ),
          _summaryLine(
            context,
            'Addestramento',
            '${summary.trainingLaps} giri · ${summary.trainingDirectionChanges} cambi',
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMediumEmphasis,
                    fontWeight: FontWeight.bold)),
          ),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSkiTechnicalCard(
    BuildContext context,
    Map<String, dynamic> details,
  ) {
    final free = CoachTrainingUtils.freeSkiingFromDetails(details);
    final tracks = CoachTrainingUtils.tracksFromDetails(details);
    final trainingBlocks =
        CoachTrainingUtils.trainingBlocksFromDetails(details);
    final chrono = CoachTrainingUtils.chronoFromDetails(details);

    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dettagli tecnici',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (free.isNotEmpty)
            _technicalBlock(
              context,
              'Campo libero',
              [
                '${CoachTrainingUtils.asNonNegativeInt(details['freeLaps'], fallback: CoachTrainingUtils.asNonNegativeInt(free['laps']))} giri',
                '${CoachTrainingUtils.asNonNegativeInt(free['changes'])} cambi/giro',
                '${CoachTrainingUtils.asNonNegativeInt(details['freeLaps'], fallback: CoachTrainingUtils.asNonNegativeInt(free['laps'])) * CoachTrainingUtils.asNonNegativeInt(free['changes'])} cambi totali',
              ],
            ),
          for (var i = 0; i < tracks.length; i++)
            _technicalBlock(
              context,
              'Pali / Tracciato ${i + 1}',
              [
                '${CoachTrainingUtils.asNonNegativeInt(tracks[i]['laps'])} giri',
                '${CoachTrainingUtils.asNonNegativeInt(tracks[i]['gates'], fallback: CoachTrainingUtils.asNonNegativeInt(tracks[i]['changes']))} porte/giro',
                '${CoachTrainingUtils.asNonNegativeInt(tracks[i]['laps']) * CoachTrainingUtils.asNonNegativeInt(tracks[i]['gates'], fallback: CoachTrainingUtils.asNonNegativeInt(tracks[i]['changes']))} passaggi',
              ],
            ),
          for (final block in trainingBlocks)
            _technicalBlock(
              context,
              'Addestramento',
              [
                '${CoachTrainingUtils.asNonNegativeInt(block['laps'])} giri',
                '${CoachTrainingUtils.asNonNegativeInt(block['references'], fallback: CoachTrainingUtils.asNonNegativeInt(block['changes']))} riferimenti/giro',
                '${CoachTrainingUtils.asNonNegativeInt(block['laps']) * CoachTrainingUtils.asNonNegativeInt(block['references'], fallback: CoachTrainingUtils.asNonNegativeInt(block['changes']))} cambi',
              ],
            ),
          if (chrono['enabled'] == true || details['chronoNotes'] != null)
            _technicalBlock(
              context,
              'Crono',
              [
                if ((details['chronoNotes'] ?? '').toString().trim().isNotEmpty)
                  details['chronoNotes'].toString()
                else
                  'Nessun crono inserito',
              ],
            ),
        ],
      ),
    );
  }

  Widget _technicalBlock(
    BuildContext context,
    String title,
    List<String> rows,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppTheme.textHighEmphasis,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(row,
                  style: TextStyle(
                      color: AppTheme.textMediumEmphasis, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkiConditionsCard(
    BuildContext context,
    Map<String, dynamic> details,
  ) {
    final tech = details['technicalDetails'] is Map
        ? Map<String, dynamic>.from(details['technicalDetails'])
        : <String, dynamic>{};
    final snow = details['snowCondition'] ?? tech['snowCondition'];
    final weather = details['weatherCondition'] ?? tech['weatherCondition'];
    final quality = tech['qualityRating'];
    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Condizioni',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildDetailRow(context, 'Neve', snow?.toString() ?? 'Non inserita'),
          _buildDetailRow(
              context, 'Meteo', weather?.toString() ?? 'Non inserito'),
          _buildDetailRow(
              context,
              'Qualità',
              quality == null
                  ? 'Non inserita'
                  : '${CoachTrainingUtils.asNonNegativeInt(quality)}/5'),
        ],
      ),
    );
  }

  Widget _buildSkiPersonalCard(
    BuildContext context,
    Map<String, dynamic> details,
    bool athleteModified,
  ) {
    final pain = (details['pain'] ?? '').toString().trim();
    final chrono = (details['chronoNotes'] ?? '').toString().trim();
    final notes = (details['athleteNotes'] ?? '').toString().trim();

    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Dati personali',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              if (athleteModified)
                _compactBadge('Modificato da te', AppTheme.success),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(context, 'RPE', '${session.effort}/10'),
          _buildDetailRow(context, 'Dolore', pain.isEmpty ? 'Nessuno' : pain),
          if (chrono.isNotEmpty) _buildDetailRow(context, 'Crono', chrono),
          if (notes.isNotEmpty) _buildDetailRow(context, 'Note', notes),
        ],
      ),
    );
  }

  Widget _buildStructuredDrylandSession(
    BuildContext context,
    String displayName,
  ) {
    final activity = TrainingActivity.fromTrainingSession(
      session,
      title: displayName,
    );
    final strength = TrainingMetricsUtils.strengthSummary([activity]);
    final plyo = TrainingMetricsUtils.plyometricSummary([activity]);
    final speed = TrainingMetricsUtils.speedAgilitySummary([activity]);
    final endurance = TrainingMetricsUtils.enduranceSummary([activity]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio Attivita'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.pencilSimple,
                color: AppTheme.primary),
            tooltip: 'Modifica allenamento',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DrylandActivityScreen(
                    category: activity.category,
                    title: activity.title,
                    initialSession: session,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            tooltip: 'Elimina allenamento',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    'Elimina Allenamento',
                    style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    'Sei sicuro di voler eliminare questo allenamento?',
                    style: TextStyle(color: AppTheme.textMediumEmphasis),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Annulla',
                        style: TextStyle(color: AppTheme.textMediumEmphasis),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Provider.of<AppState>(context, listen: false)
                            .deleteSession(session.id);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Elimina',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CustomCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.barbell,
                        color: AppTheme.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activity.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'RPE ${activity.rpe ?? session.effort}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppTheme.divider),
                const SizedBox(height: 16),
                _buildDetailRow(context, 'Categoria',
                    _drylandCategoryLabel(activity.category)),
                _buildDetailRow(context, 'Data', session.date),
                _buildDetailRow(context, 'Orario',
                    '${session.startTime} - ${session.endTime}'),
                _buildDetailRow(
                  context,
                  'Durata',
                  TimeUtils.formatDuration(session.duration),
                ),
                if ((activity.location ?? '').isNotEmpty)
                  _buildDetailRow(context, 'Luogo', activity.location!),
                _buildDetailRow(
                  context,
                  'Origine',
                  activity.createdByCoach ? 'Coach' : 'Atleta',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CustomCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riepilogo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (strength.totalSets > 0)
                      _drylandMetric(
                        context,
                        PhosphorIconsRegular.barbell,
                        Colors.orange,
                        strength.volumeKg.round().toString(),
                        'KG VOLUME',
                      ),
                    if (strength.totalReps > 0)
                      _drylandMetric(
                        context,
                        PhosphorIconsRegular.repeat,
                        Colors.amber,
                        strength.totalReps.toString(),
                        'RIPETIZIONI',
                      ),
                    if (plyo.totalContacts > 0)
                      _drylandMetric(
                        context,
                        PhosphorIconsRegular.lightning,
                        Colors.yellow,
                        plyo.totalContacts.toString(),
                        'CONTATTI',
                      ),
                    if (speed.drillCount > 0)
                      _drylandMetric(
                        context,
                        PhosphorIconsRegular.timer,
                        Colors.cyan,
                        speed.drillCount.toString(),
                        'DRILL',
                      ),
                    if (endurance.durationSeconds > 0)
                      _drylandMetric(
                        context,
                        PhosphorIconsRegular.heartbeat,
                        Colors.red,
                        '${(endurance.durationSeconds / 60).round()}m',
                        'RESISTENZA',
                      ),
                    if (endurance.zone23Seconds > 0)
                      _drylandMetric(
                        context,
                        Icons.monitor_heart_outlined,
                        Colors.green,
                        '${(endurance.zone23Seconds / 60).round()}m',
                        'Z2-Z3',
                      ),
                    if (endurance.zone45Seconds > 0)
                      _drylandMetric(
                        context,
                        PhosphorIconsRegular.fire,
                        Colors.deepOrange,
                        '${(endurance.zone45Seconds / 60).round()}m',
                        'Z4-Z5',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CustomCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blocchi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                for (final block in activity.blocks)
                  _drylandBlockSummary(context, block),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CustomCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dati personali',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                    context, 'RPE', '${activity.rpe ?? session.effort}/10'),
                _buildDetailRow(
                  context,
                  'Dolore',
                  (activity.pain ?? '').trim().isEmpty
                      ? 'Nessuno'
                      : activity.pain!,
                ),
                if ((activity.notes ?? '').trim().isNotEmpty)
                  _buildDetailRow(context, 'Note', activity.notes!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drylandMetric(
    BuildContext context,
    IconData icon,
    Color color,
    String value,
    String label,
  ) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 64) / 2,
      child: _buildMetric(context, icon, color, value, label),
    );
  }

  Widget _drylandBlockSummary(BuildContext context, TrainingBlock block) {
    final rows = <String>[];
    final logs = _effectivePrLogs(context);
    for (final exercise in block.exercises) {
      rows.add('${exercise.name} · ${exercise.sets.length} serie');
    }
    for (final exercise in block.exercises) {
      final maxLoad = _oneRepMaxForExercise(context, exercise.exerciseId, logs);
      for (final entry in exercise.sets.asMap().entries) {
        final set = entry.value;
        rows.add(
          '${exercise.name} · ${_strengthSetText(
            entry.key,
            kg: set.kg,
            reps: set.reps,
            durationSeconds: set.durationSeconds,
            percent1RM: set.percent1RM,
            maxLoad: maxLoad,
          )}',
        );
      }
    }
    for (final entry in block.plyometrics) {
      rows.add('${entry.exerciseName} · ${entry.totalContacts} contatti');
    }
    for (final drill in block.drills) {
      rows.add('${drill.name} · ${drill.sets ?? 0} serie');
    }
    final circuits = block.metrics['circuits'];
    if (circuits is List) {
      for (final item in circuits.whereType<Map>()) {
        final name = item['name']?.toString() ?? 'Circuito';
        final rounds = item['rounds']?.toString() ?? '-';
        final work = item['workSeconds']?.toString() ?? '-';
        final rest = item['restSeconds']?.toString() ?? '-';
        final intervalCount =
            item['intervals'] is List ? (item['intervals'] as List).length : 0;
        rows.add(intervalCount > 0
            ? '$name Â· ${rounds}x Â· $intervalCount intervalli'
            : '$name Â· ${rounds}x Â· ${work}s/${rest}s');
      }
    }
    if (block.endurance != null) {
      final endurance = block.endurance!;
      rows.add(
        '${(endurance.durationSeconds ?? 0) ~/ 60} min · ${(endurance.distanceKm ?? 0).toStringAsFixed(1)} km',
      );
    }
    if (rows.isEmpty && (block.notes ?? '').isNotEmpty) {
      rows.add(block.notes!);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _drylandBlockLabel(block.type),
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                row,
                style: TextStyle(
                  color: AppTheme.textMediumEmphasis,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _drylandBlockLabel(String type) {
    switch (type) {
      case TrainingBlockType.strength:
        return 'Forza';
      case TrainingBlockType.plyometrics:
        return 'Pliometria';
      case TrainingBlockType.speedAgility:
        return 'Velocita/agilita';
      case TrainingBlockType.endurance:
        return 'Resistenza';
      case TrainingBlockType.mobility:
        return 'Mobilita';
      case TrainingBlockType.core:
        return 'Core';
      default:
        return 'Blocco';
    }
  }

  String _drylandCategoryLabel(String category) {
    switch (category) {
      case ActivityCategory.strength:
        return 'Forza';
      case ActivityCategory.plyometrics:
        return 'Pliometria';
      case ActivityCategory.speedAgility:
        return 'Velocita/agilita';
      case ActivityCategory.endurance:
        return 'Resistenza';
      case ActivityCategory.mobility:
        return 'Mobilita';
      case ActivityCategory.core:
        return 'Core';
      case ActivityCategory.circuit:
        return 'Circuito';
      case ActivityCategory.sport:
        return 'Sport';
      case ActivityCategory.test:
        return 'Test';
      default:
        return 'Altro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPainZones = session.details != null &&
        session.details!['painZones'] != null &&
        (session.details!['painZones'] as List).isNotEmpty;

    final displayName = sportName ??
        (session.sportId[0].toUpperCase() +
            session.sportId.substring(1).replaceAll('_', ' '));

    if (_isCoachSkiSession) {
      return _buildCoachSkiSession(context, displayName);
    }
    if (_isStructuredDrylandSession) {
      return _buildStructuredDrylandSession(context, displayName);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio Attività'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.pencilSimple,
                color: AppTheme.primary),
            tooltip: 'Modifica allenamento',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTrainingScreen(
                    sportId: session.sportId,
                    sportName: displayName.toUpperCase(),
                    initialSession: session,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            tooltip: 'Elimina allenamento',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.card,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Text('Elimina Allenamento',
                      style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.bold)),
                  content: Text(
                      'Sei sicuro di voler eliminare questo allenamento?',
                      style: TextStyle(color: AppTheme.textMediumEmphasis)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Annulla',
                          style: TextStyle(color: AppTheme.textMediumEmphasis)),
                    ),
                    TextButton(
                      onPressed: () {
                        Provider.of<AppState>(context, listen: false)
                            .deleteSession(session.id);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Allenamento eliminato'),
                          backgroundColor: AppTheme.primary,
                        ));
                      },
                      child: const Text('Elimina',
                          style: TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header Card
          CustomCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                              session.sportId == 'alpine_skiing'
                                  ? PhosphorIconsRegular.mountains
                                  : PhosphorIconsRegular.barbell,
                              color: session.sportId == 'alpine_skiing'
                                  ? AppTheme.secondary
                                  : Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              session.sportId
                                  .toUpperCase()
                                  .replaceAll('_', ' '),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text('RPE ${session.effort}',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppTheme.divider),
                const SizedBox(height: 16),
                _buildDetailRow(context, 'Data', session.date),
                _buildDetailRow(context, 'Orario',
                    '${session.startTime} - ${session.endTime}'),
                if (session.details?['active_duration_minutes'] != null ||
                    session.details?['total_duration_minutes'] != null) ...[
                  _buildDetailRow(
                    context,
                    'Durata attiva',
                    TimeUtils.formatDuration(
                      session.details?['active_duration_minutes'] ??
                          session.duration,
                    ),
                  ),
                  _buildDetailRow(
                    context,
                    'Durata totale',
                    TimeUtils.formatDuration(
                      session.details?['total_duration_minutes'] ??
                          session.duration,
                    ),
                  ),
                ] else
                  _buildDetailRow(context, 'Durata',
                      TimeUtils.formatDuration(session.duration)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Import & Manual Metrics
          if (session.details != null) ...[
            Builder(builder: (context) {
              final details = session.details;
              final isRunning = session.sportId.contains('running') ||
                  session.sportId == 'track_field';

              // Extract values
              final distVal =
                  _getMetricValue(details, ['distance'], fallbackUnit: 'km');
              final speedVal = _getMetricValue(details, ['pace', 'speed']);
              final speedLabel =
                  details?.containsKey('pace') == true ? 'PASSO' : 'VELOCITÀ';
              final avgHrVal = _getMetricValue(
                  details, ['avg_hr', 'avgHeartRate'],
                  fallbackUnit: 'bpm');
              final kcalVal =
                  details != null && details.containsKey('calories') == true
                      ? '${(details['calories'] as num?)?.round() ?? "--"}'
                      : null;

              // Secondary metrics
              final maxHrVal = _getMetricValue(
                  details, ['max_hr', 'maxHeartRate'],
                  fallbackUnit: 'bpm');
              final elevationVal = _getMetricValue(
                  details, ['elevation', 'elevationGain'],
                  fallbackUnit: 'm');
              final cadenceVal = _getMetricValue(
                  details, ['cadence', 'avgCadence'],
                  fallbackUnit: isRunning ? 'spm' : 'rpm');
              final surfaceVal =
                  _getMetricValue(details, ['surface', 'terrain']);

              // Build list of widgets to display
              final List<Widget> primaryMetrics = [];
              if (distVal != null) {
                primaryMetrics.add(_buildMetric(
                    context,
                    PhosphorIconsRegular.mapPin,
                    Colors.blue,
                    distVal,
                    'DISTANZA'));
              }
              if (speedVal != null) {
                primaryMetrics.add(_buildMetric(
                    context,
                    PhosphorIconsRegular.timer,
                    Colors.green,
                    speedVal,
                    speedLabel));
              }
              if (avgHrVal != null) {
                primaryMetrics.add(_buildMetric(
                    context,
                    PhosphorIconsRegular.heart,
                    Colors.red,
                    avgHrVal,
                    'BPM MEDI'));
              }
              if (kcalVal != null) {
                primaryMetrics.add(_buildMetric(context,
                    PhosphorIconsRegular.fire, Colors.orange, kcalVal, 'KCAL'));
              }

              final List<Widget> secondaryMetrics = [];
              if (maxHrVal != null) {
                secondaryMetrics.add(_buildMetric(
                    context,
                    PhosphorIconsRegular.heartbeat,
                    Colors.pink,
                    maxHrVal,
                    'FC MAX'));
              }
              if (elevationVal != null) {
                secondaryMetrics.add(_buildMetric(
                    context,
                    PhosphorIconsRegular.mountains,
                    Colors.cyan,
                    elevationVal,
                    'DISLIVELLO'));
              }
              if (cadenceVal != null) {
                secondaryMetrics.add(_buildMetric(
                    context,
                    PhosphorIconsRegular.trendUp,
                    Colors.deepOrange,
                    cadenceVal,
                    isRunning ? 'CADENZA' : 'CADENZA MEDIA'));
              }
              if (surfaceVal != null) {
                secondaryMetrics.add(_buildMetric(
                    context,
                    PhosphorIconsRegular.compass,
                    Colors.teal,
                    surfaceVal,
                    'TERRENO'));
              }

              if (primaryMetrics.isEmpty && secondaryMetrics.isEmpty) {
                return const SizedBox();
              }

              Widget buildMetricsRow(List<Widget> items) {
                return Row(
                  children: List.generate(4, (index) {
                    if (index < items.length) {
                      return Expanded(
                        child: Padding(
                          padding:
                              EdgeInsets.only(right: index < 3 ? 8.0 : 0.0),
                          child: items[index],
                        ),
                      );
                    } else {
                      return const Expanded(child: SizedBox());
                    }
                  }),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    if (primaryMetrics.isNotEmpty) ...[
                      buildMetricsRow(primaryMetrics),
                      if (secondaryMetrics.isNotEmpty)
                        const SizedBox(height: 8),
                    ],
                    if (secondaryMetrics.isNotEmpty)
                      buildMetricsRow(secondaryMetrics),
                  ],
                ),
              );
            }),
            _buildHeartRatePanel(context, session.details!),
            if (session.details!['hr_reliable'] != true &&
                session.details!.containsKey('hr_zones'))
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: CustomCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(PhosphorIconsRegular.heartbeat,
                              color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Zone Cardiache',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildHrZonesChart(context,
                          List<int>.from(session.details!['hr_zones'])),
                    ],
                  ),
                ),
              ),
          ],

          // Sport Specific Details
          if (session.details != null) ...[
            Builder(builder: (ctx) {
              Map<String, dynamic> filteredDetails = Map.from(session.details!)
                ..removeWhere((k, v) => [
                      'painZones',
                      'source',
                      'external_id',
                      'hr_zones',
                      'avg_hr',
                      'avgHeartRate',
                      'speed',
                      'pace',
                      'distance',
                      'calories',
                      'max_hr',
                      'maxHeartRate',
                      'elevation',
                      'elevationGain',
                      'cadence',
                      'avgCadence',
                      'surface',
                      'terrain',
                      'technicalDetails',
                      'source_name',
                      'source_id',
                      'total_duration',
                      'total_duration_minutes',
                      'active_duration',
                      'active_duration_minutes',
                      'duration_source',
                      'distance_meters',
                      'energy_total_kcal',
                      'avg_pace_sec_per_km',
                      'avg_speed_kmh',
                      'hr_samples',
                      'hr_coverage_minutes',
                      'hr_zone_boundaries',
                      'elevation_source',
                      'health_import_version',
                      'total_duration_seconds',
                      'active_duration_seconds',
                      'moving_duration_seconds',
                      'elevation_meters',
                      'hr_reliable',
                      'hr_sample_count',
                      'hr_coverage_seconds',
                      'hr_zones_seconds',
                      'dominant_hr_zone',
                      'merged_source_workout_ids',
                      'source_part_count'
                    ].contains(k));

              if (filteredDetails.isEmpty) return const SizedBox();

              return Column(
                children: [
                  CustomCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dettagli Tecnici',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        _buildDetailsMap(
                            context,
                            filteredDetails,
                            prLogs ??
                                Provider.of<AppState>(context, listen: false)
                                    .prLogs),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }),
          ],

          // Pain Zones
          if (hasPainZones)
            CustomCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.healing, color: AppTheme.error, size: 20),
                      SizedBox(width: 8),
                      Text('Zone di Dolore',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.error)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        (session.details!['painZones'] as List).map((zone) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(zone.toString(),
                            style: const TextStyle(
                                color: AppTheme.error, fontSize: 12)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
