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
        return _buildDetailRow(context, _formatKey(e.key), e.value.toString());
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
                    Row(
                      children: [
                        Icon(
                            session.sportId == 'alpine_skiing'
                                ? PhosphorIconsRegular.mountains
                                : PhosphorIconsRegular.barbell,
                            color: session.sportId == 'alpine_skiing'
                                ? AppTheme.secondary
                                : Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          session.sportId.toUpperCase().replaceAll('_', ' '),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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

          // Sport Specific Details
          if (session.details != null &&
              session.details!.keys.any((k) => k != 'painZones'))
            CustomCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dettagli Tecnici',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _buildDetailsMap(context, session.details!, prLogs ?? Provider.of<AppState>(context, listen: false).prLogs),
                ],
              ),
            ),

          if (session.details != null &&
              session.details!.keys.any((k) => k != 'painZones'))
            const SizedBox(height: 24),

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
