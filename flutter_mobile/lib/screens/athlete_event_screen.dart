import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/custom_card.dart';

class AthleteEventScreen extends StatefulWidget {
  final CalendarEvent event;

  const AthleteEventScreen({super.key, required this.event});

  @override
  State<AthleteEventScreen> createState() => _AthleteEventScreenState();
}

class _AthleteEventScreenState extends State<AthleteEventScreen> {
  bool _isLoading = false;
  String _laps = '6';
  String _freeLaps = '4';
  bool? _currentAttendance;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    final userId = appState.userId;
    
    // Find current laps if already present
    if (widget.event.attendees != null && userId != null) {
      final name = '${appState.userProfile?.firstName ?? ''} ${appState.userProfile?.lastName ?? ''}'.trim();
      final attendee = widget.event.attendees!.cast<Map<String,dynamic>?>().firstWhere(
        (a) => a != null && (a['id'] == userId || a['name'] == name), 
        orElse: () => null
      );
      if (attendee != null) {
        if (attendee['laps'] != null) {
          _laps = attendee['laps'].toString();
        }
        if (attendee['freeLaps'] != null) {
          _freeLaps = attendee['freeLaps'].toString();
        }
        if (attendee['isPresent'] != null) {
          _currentAttendance = attendee['isPresent'] as bool?;
        }
      }
    }
  }

  bool get _isPast {
    final eventDate = DateTime.tryParse(widget.event.date) ?? DateTime.now();
    final today = DateTime.now();
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return eventDay.isBefore(todayDay);
  }

  Future<void> _handleRSVP(bool isPresent) async {
    setState(() {
      _isLoading = true;
      _currentAttendance = isPresent;
    });
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.updateAthleteAttendance(widget.event, isPresent);
    
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isPresent ? 'Presenza confermata!' : 'Assenza registrata.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _handleSaveLaps() async {
    final laps = int.tryParse(_laps) ?? 0;
    final freeLaps = int.tryParse(_freeLaps) ?? 0;
    setState(() => _isLoading = true);
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.updateAthleteLaps(widget.event, laps, freeLaps);
    
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dati aggiornati con successo!')),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildField(String label, String value, Function(String) onChanged, {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMediumEmphasis)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: TextFormField(
            initialValue: value,
            keyboardType: type,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Dettaglio Evento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
            children: [
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.event.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
                      title: const Text('Data', style: TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
                      subtitle: Text(widget.event.date, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            leading: const Icon(Icons.access_time, color: AppTheme.primary),
                            title: const Text('Inizio', style: TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
                            subtitle: Text(widget.event.startTime, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            leading: const Icon(Icons.access_time_filled, color: AppTheme.primary),
                            title: const Text('Fine', style: TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
                            subtitle: Text(widget.event.endTime, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on, color: AppTheme.primary),
                      title: const Text('Luogo', style: TextStyle(fontSize: 12, color: AppTheme.textMediumEmphasis)),
                      subtitle: Text(widget.event.location ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              if (_isPast && widget.event.sportCategory == 'ski') ...[
                const Text('Dettagli Allenamento (Modifica)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.event.technicalDetails?['specialties']?[0] != 'CL') ...[
                      Expanded(child: _buildField('GIRI PALI', _laps, (v) => setState(() => _laps = v), type: TextInputType.number)),
                      const SizedBox(width: 16),
                    ],
                    Expanded(child: _buildField('GIRI CL', _freeLaps, (v) => setState(() => _freeLaps = v), type: TextInputType.number)),
                  ],
                ),
              ] else if (!_isPast) ...[
                const Text('Conferma Presenza', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleRSVP(true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: _currentAttendance == true ? Colors.green : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green, width: _currentAttendance == true ? 2 : 1),
                          ),
                          child: Center(
                            child: Text('SÌ, CI SARÒ', style: TextStyle(color: _currentAttendance == true ? Colors.white : Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleRSVP(false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: _currentAttendance == false ? AppTheme.error : AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.error, width: _currentAttendance == false ? 2 : 1),
                          ),
                          child: Center(
                            child: Text('NO, ASSENTE', style: TextStyle(color: _currentAttendance == false ? Colors.white : AppTheme.error, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          
          if (_isPast && widget.event.sportCategory == 'ski')
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppTheme.background, AppTheme.background.withValues(alpha: 0.0)],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSaveLaps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('SALVA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
