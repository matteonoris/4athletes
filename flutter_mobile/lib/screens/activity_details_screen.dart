import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';
import 'add_training_screen.dart';

class ActivityDetailsScreen extends StatelessWidget {
  final TrainingSession session;
  /// Optional: display name for the sport (e.g. "POWERLIFTING").
  /// If not provided it is derived from sportId.
  final String? sportName;
  final List<PRLog>? prLogs;

  const ActivityDetailsScreen({super.key, required this.session, this.sportName, this.prLogs});

  Widget _buildMetric(BuildContext context, IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMediumEmphasis)),
        ],
      ),
    );
  }

  Widget _buildHrZonesChart(BuildContext context, List<int> zoneMins) {
    final colors = [Colors.grey, Colors.blue, Colors.green, Colors.orange, Colors.red];
    final labels = ['Z1 Recupero', 'Z2 Fondo', 'Z3 Tempo', 'Z4 Soglia', 'Z5 Max'];
    
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
                child: Text(labels[index], style: const TextStyle(fontSize: 10, color: AppTheme.textMediumEmphasis, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
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
                            BoxShadow(color: colors[index].withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))
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
                child: Text('${mins}m', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
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

  Widget _buildDetailsMap(BuildContext context, Map<String, dynamic> data, List<PRLog> prLogs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) {
        if (e.key == 'painZones') return const SizedBox(); // Handled separately
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
                child:
                    _buildDetailsMap(context, e.value as Map<String, dynamic>, prLogs),
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
                Text(_formatKey(e.key), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                const SizedBox(height: 8),
                ...list.map((item) {
                  final mapItem = item as Map<String, dynamic>;
                  if (mapItem.containsKey('name') && mapItem.containsKey('sets')) {
                    final sets = mapItem['sets'] as List;
                    final exerciseId = mapItem['id'] ?? '';
                    final exercisePrLogs = prLogs
                        .where((l) => l.exerciseId == exerciseId)
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date));
                    final double maxLoad = exercisePrLogs.isNotEmpty
                        ? exercisePrLogs.first.weight
                        : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('- ${mapItem['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ...sets.asMap().entries.map((setEntry) {
                            final setIdx = setEntry.key;
                            final setVal = setEntry.value as Map<String, dynamic>;
                            final load = (setVal['kg'] as num?)?.toDouble() ?? 0.0;
                            String pctStr = '';
                            if (maxLoad > 0 && load > 0) {
                              pctStr = ' (${((load / maxLoad) * 100).toStringAsFixed(0)}% 1RM)';
                            }
                            return Padding(
                              padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                              child: Text('Set ${setIdx + 1}: ${setVal['kg']} kg x ${setVal['reps']} reps$pctStr', style: const TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
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
            return _buildDetailRow(context, _formatKey(e.key), listStr.isEmpty ? 'Nessuno' : listStr);
          }
        }
        return _buildDetailRow(context, _formatKey(e.key), e.value?.toString() ?? 'Nessuno');
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPainZones = session.details != null &&
        session.details!['painZones'] != null &&
        (session.details!['painZones'] as List).isNotEmpty;

    final displayName = sportName ??
        (session.sportId[0].toUpperCase() +
            session.sportId.substring(1).replaceAll('_', ' '));

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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Elimina Allenamento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: const Text('Sei sicuro di voler eliminare questo allenamento?', style: TextStyle(color: AppTheme.textMediumEmphasis)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annulla', style: TextStyle(color: AppTheme.textMediumEmphasis)),
                    ),
                    TextButton(
                      onPressed: () {
                        Provider.of<AppState>(context, listen: false).deleteSession(session.id);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Allenamento eliminato'),
                          backgroundColor: AppTheme.primary,
                        ));
                      },
                      child: const Text('Elimina', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
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
                              session.sportId.toUpperCase().replaceAll('_', ' '),
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
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                _buildDetailRow(context, 'Data', session.date),
                _buildDetailRow(context, 'Orario',
                    '${session.startTime} - ${session.endTime}'),
                _buildDetailRow(context, 'Durata', session.duration),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Import Metrics
          if (session.details != null) ...[
            if (session.details!.containsKey('distance') || session.details!.containsKey('calories') || session.details!.containsKey('speed') || session.details!.containsKey('pace') || session.details!.containsKey('avg_hr'))
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    if (session.details!.containsKey('distance'))
                      Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: _buildMetric(context, PhosphorIconsRegular.mapPin, Colors.blue, session.details!['distance']?.toString() ?? '--', 'DISTANZA'))),
                    if (session.details!.containsKey('pace') || session.details!.containsKey('speed'))
                      Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: _buildMetric(context, PhosphorIconsRegular.timer, Colors.green, (session.details!['pace'] ?? session.details!['speed'])?.toString() ?? '--', session.details!.containsKey('pace') ? 'PASSO' : 'VELOCITÀ'))),
                    if (session.details!.containsKey('avg_hr'))
                      Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: _buildMetric(context, PhosphorIconsRegular.heart, Colors.red, '${session.details!['avg_hr'] ?? '--'}', 'BPM MEDI'))),
                    if (session.details!.containsKey('calories'))
                      Expanded(child: _buildMetric(context, PhosphorIconsRegular.fire, Colors.orange, '${(session.details!['calories'] as num?)?.round() ?? '--'}', 'KCAL')),
                  ],
                ),
              ),

            // HR Zones Chart
            if (session.details!.containsKey('hr_zones'))
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: CustomCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(PhosphorIconsRegular.heartbeat, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Zone Cardiache', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildHrZonesChart(context, List<int>.from(session.details!['hr_zones'])),
                    ],
                  ),
                ),
              ),
          ],

          // Sport Specific Details
          if (session.details != null) ...[
            Builder(
              builder: (ctx) {
                Map<String, dynamic> filteredDetails = Map.from(session.details!)
                  ..removeWhere((k, v) => ['painZones', 'source', 'external_id', 'hr_zones', 'avg_hr', 'speed', 'pace', 'distance', 'calories'].contains(k));
                
                if (filteredDetails.isEmpty) return const SizedBox();
                
                return Column(
                  children: [
                    CustomCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dettagli Tecnici',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 16),
                          _buildDetailsMap(context, filteredDetails, prLogs ?? Provider.of<AppState>(context, listen: false).prLogs),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }
            ),
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
