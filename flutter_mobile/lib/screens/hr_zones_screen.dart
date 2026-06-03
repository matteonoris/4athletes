import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';

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
    
    if (p.customHrZones != null && p.customHrZones!.length == 5) {
      _customZones = List.from(p.customHrZones!.map((e) => Map<String, int>.from(e)));
    } else {
      // Default custom zones based on typical values (just as placeholders)
      _customZones = [
        {'min': 100, 'max': 120},
        {'min': 120, 'max': 140},
        {'min': 140, 'max': 160},
        {'min': 160, 'max': 180},
        {'min': 180, 'max': 200},
      ];
    }
  }

  void _save() {
    final state = Provider.of<AppState>(context, listen: false);
    final p = state.userProfile!;
    
    // Ensure all values are valid
    for (int i = 0; i < _customZones.length; i++) {
      final zone = _customZones[i];
      if (i < 4) {
        if ((zone['min'] ?? 0) >= (zone['max'] ?? 0)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('I valori minimi devono essere minori dei massimi.'),
            backgroundColor: AppTheme.error,
          ));
          return;
        }
      } else {
        // Set max of Zone 5 to 300 (no upper boundary)
        zone['max'] = 300;
      }
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Min', style: TextStyle(fontSize: 10, color: AppTheme.textMediumEmphasis)),
                TextFormField(
                  initialValue: zone['min'].toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() {
                      zone['min'] = int.tryParse(val) ?? zone['min']!;
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
                const Text('Max', style: TextStyle(fontSize: 10, color: AppTheme.textMediumEmphasis)),
                if (index < 4)
                  TextFormField(
                    initialValue: zone['max'].toString(),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      setState(() {
                        zone['max'] = int.tryParse(val) ?? zone['max']!;
                      });
                    },
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('∞', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textMediumEmphasis)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('bpm', style: TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
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
            child: const Text('SALVA', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
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
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'standard',
                  groupValue: _mode,
                  onChanged: (val) => setState(() => _mode = val!),
                  activeColor: AppTheme.primary,
                  title: const Text('Zone Standard (Karvonen)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Calcolate in automatico in base alla tua Frequenza Cardiaca Massima e a Riposo.', style: TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                RadioListTile<String>(
                  value: 'custom',
                  groupValue: _mode,
                  onChanged: (val) => setState(() => _mode = val!),
                  activeColor: AppTheme.primary,
                  title: const Text('Zone Personalizzate', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Inserisci manualmente i valori per ogni zona, per allinearli ad altre app (es. Garmin).', style: TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
                ),
              ],
            ),
          ),

          if (_mode == 'custom') ...[
            const SizedBox(height: 32),
            const Text('CONFIGURA ZONE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMediumEmphasis, letterSpacing: 1.5)),
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
