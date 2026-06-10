import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'metric_trend_screen.dart';

class DailyReadinessDetailsScreen extends StatelessWidget {
  final String title;
  final double? score;
  final Map<String, double> dailyMetrics;
  final Map<String, List<double>> historicalMetrics;

  const DailyReadinessDetailsScreen({
    Key? key,
    required this.title,
    this.score,
    required this.dailyMetrics,
    required this.historicalMetrics,
  }) : super(key: key);

  Color _getScoreColor(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.yellow[700]!;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    bool isSleep = title.toLowerCase().contains('sleep');

    // Lista di metriche da visualizzare in base al tipo
    List<Map<String, dynamic>> metricsToShow = isSleep
        ? [
            {
              'key': 'sleepRegularity',
              'label': 'Regolarità Sonno (/100)',
              'icon': Icons.schedule
            },
            {
              'key': 'totalSleep',
              'label': 'Tempo Totale (min)',
              'icon': Icons.bedtime
            },
            {
              'key': 'deepSleep',
              'label': 'Sonno Profondo (min)',
              'icon': Icons.nights_stay
            },
            {
              'key': 'remSleep',
              'label': 'Sonno REM (min)',
              'icon': Icons.remove_red_eye
            },
          ]
        : [
            {
              'key': 'rhr',
              'label': 'Battiti a Riposo (bpm)',
              'icon': Icons.favorite
            },
            {'key': 'hrv', 'label': 'HRV (ms)', 'icon': Icons.monitor_heart},
            {
              'key': 'temp',
              'label': 'Temperatura (°C)',
              'icon': Icons.thermostat
            },
            {
              'key': 'resp',
              'label': 'Frequenza Respiratoria (rpm)',
              'icon': Icons.air
            },
            {
              'key': 'spo2',
              'label': 'Ossigenazione (%)',
              'icon': Icons.bloodtype
            },
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Dettagli $title',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header Score
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _getScoreColor(score), width: 8),
              ),
              child: Text(
                score != null ? score!.toStringAsFixed(0) : '--',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(score),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('Metriche di oggi',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          ...metricsToShow.map((metric) {
            String mKey = metric['key'];
            double? mVal = dailyMetrics[mKey];
            if (mVal == null) return const SizedBox();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppTheme.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Icon(metric['icon'], color: AppTheme.primary),
                title: Text(metric['label'],
                    style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mVal.toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Icon(Icons.chevron_right,
                        color: AppTheme.textMediumEmphasis),
                  ],
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MetricTrendScreen(
                        metricLabel: metric['label'],
                        metricKey: mKey,
                        history: historicalMetrics[mKey] ?? [],
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
