import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../services/health_import_normalizer.dart';

class HrZonesScreen extends StatefulWidget {
  const HrZonesScreen({super.key});

  @override
  State<HrZonesScreen> createState() => _HrZonesScreenState();
}

class _HrZonesScreenState extends State<HrZonesScreen> {
  late String _mode;
  late List<Map<String, int>> _customZones;

  @override
  void initState() {
    super.initState();
    final p = Provider.of<AppState>(context, listen: false).userProfile!;
    _mode = p.hrZoneMode;

    _customZones = HealthImportNormalizer.resolveHeartRateZones(
      mode: 'custom',
      customZones: p.customHrZones,
      maxHeartRate: p.maxHr,
    );
    _syncZoneMaximums();
  }

  void _syncZoneMaximums() {
    for (var i = 0; i < _customZones.length; i++) {
      _customZones[i]['max'] =
          i < _customZones.length - 1 ? _customZones[i + 1]['min']! - 1 : 300;
    }
  }

  void _save() {
    final state = Provider.of<AppState>(context, listen: false);
    final p = state.userProfile!;

    if (_mode == 'custom') {
      for (int i = 0; i < _customZones.length; i++) {
        final min = _customZones[i]['min'];
        if (min == null || min < 35 || min > 250) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Inserisci soglie comprese tra 35 e 250 bpm.'),
            backgroundColor: AppTheme.error,
          ));
          return;
        }
        if (i > 0 && min <= _customZones[i - 1]['min']!) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Le soglie delle zone devono essere crescenti.'),
            backgroundColor: AppTheme.error,
          ));
          return;
        }
      }
      _syncZoneMaximums();
    }

    final updated = p.copyWith(
      hrZoneMode: _mode,
      customHrZones: _customZones,
    );
    state.updateProfile(updated);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Zone cardiache salvate con successo!'),
      backgroundColor: AppTheme.success,
    ));
    Navigator.pop(context);
  }

  Widget _buildZoneInput(int index, String title, Color color) {
    final zone = _customZones[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Min',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textMediumEmphasis)),
                TextFormField(
                  initialValue: zone['min'].toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed == null) return;
                    setState(() {
                      zone['min'] = parsed;
                      _syncZoneMaximums();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Max',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textMediumEmphasis)),
                if (index < 4)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(zone['max'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('∞',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.textMediumEmphasis)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('bpm',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone Cardiache'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('SALVA',
                style: TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Scegli come calcolare le tue zone cardiache. Queste zone verranno utilizzate per i grafici degli allenamenti.',
            style: TextStyle(color: AppTheme.textMediumEmphasis, height: 1.5),
          ),
          const SizedBox(height: 32),

          // Radio Options
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: RadioGroup<String>(
              groupValue: _mode,
              onChanged: (value) {
                if (value != null) setState(() => _mode = value);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'standard',
                    activeColor: AppTheme.primary,
                    title: const Text('Zone Standard (Karvonen)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Calcolate in automatico in base alla tua Frequenza Cardiaca Massima e a Riposo.',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMediumEmphasis)),
                  ),
                  Divider(color: AppTheme.divider, height: 1),
                  RadioListTile<String>(
                    value: 'custom',
                    activeColor: AppTheme.primary,
                    title: const Text('Zone Personalizzate',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Inserisci manualmente i valori per ogni zona, per allinearli ad altre app (es. Garmin).',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMediumEmphasis)),
                  ),
                ],
              ),
            ),
          ),

          if (_mode == 'custom') ...[
            const SizedBox(height: 32),
            Text('CONFIGURA ZONE',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMediumEmphasis,
                    letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Text(
              'Imposta il valore iniziale di ogni zona. Il limite finale viene allineato automaticamente alla zona successiva, senza buchi o sovrapposizioni.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMediumEmphasis,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _buildZoneInput(0, 'Zona 1 (Recupero)', Colors.grey),
            _buildZoneInput(1, 'Zona 2 (Fondo)', Colors.blue),
            _buildZoneInput(2, 'Zona 3 (Tempo)', Colors.green),
            _buildZoneInput(3, 'Zona 4 (Soglia)', Colors.orange),
            _buildZoneInput(4, 'Zona 5 (VO2 Max)', Colors.red),
          ],
        ],
      ),
    );
  }
}
