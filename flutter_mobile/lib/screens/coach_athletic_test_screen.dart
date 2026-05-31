import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

class CoachAthleticTestScreen extends StatefulWidget {
  final Team selectedTeam;
  final String testId;
  final String testTitle;
  final String testCategory; // 'jump' or 'pr'

  const CoachAthleticTestScreen({
    super.key,
    required this.selectedTeam,
    required this.testId,
    required this.testTitle,
    required this.testCategory,
  });

  @override
  State<CoachAthleticTestScreen> createState() => _CoachAthleticTestScreenState();
}

class _CoachAthleticTestScreenState extends State<CoachAthleticTestScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _athletes = [];
  bool _isSelectingPresent = true;

  @override
  void initState() {
    super.initState();
    _fetchAthletes();
  }

  Future<void> _fetchAthletes() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('profiles')
          .select('id, first_name, last_name, email')
          .eq('team_id', widget.selectedTeam.id)
          .eq('role', 'athlete');

      if (mounted) {
        setState(() {
          _athletes = (data as List).map((row) {
            final String firstName = row['first_name'] ?? '';
            final String lastName = row['last_name'] ?? '';
            final String fullName = '$firstName $lastName'.trim();
            final String nameToShow = fullName.isNotEmpty ? fullName : (row['email'] ?? 'Atleta');

            return {
              'id': row['id'],
              'name': nameToShow,
              'isPresent': false,
              'valueCtrl': TextEditingController(),
              'rsiCtrl': TextEditingController(),
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching athletes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    for (var a in _athletes) {
      (a['valueCtrl'] as TextEditingController).dispose();
      (a['rsiCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _saveTests() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final dateStr = DateTime.now().toIso8601String().split('T').first;

    int savedCount = 0;

    for (var a in _athletes) {
      if (a['isPresent']) {
        final valText = (a['valueCtrl'] as TextEditingController).text.trim().replaceAll(',', '.');
        final val = double.tryParse(valText);
        
        if (val != null && val > 0) {
          if (widget.testCategory == 'jump') {
            await appState.addJumpLogForAthlete(
              JumpLog(
                id: '',
                date: dateStr,
                type: widget.testId,
                value: val,
              ),
              a['id'],
            );
            if (widget.testId == 'drop_jump') {
              final rsiText = (a['rsiCtrl'] as TextEditingController).text.trim().replaceAll(',', '.');
              final rsiVal = double.tryParse(rsiText);
              if (rsiVal != null && rsiVal > 0) {
                await appState.addJumpLogForAthlete(
                  JumpLog(
                    id: '',
                    date: dateStr,
                    type: 'drop_jump_rsi',
                    value: rsiVal,
                  ),
                  a['id'],
                );
              }
            }
          } else if (widget.testCategory == 'pr') {
            await appState.addPRLogForAthlete(
              PRLog(
                id: '',
                exerciseId: widget.testId,
                date: dateStr,
                weight: val,
                note: 'Aggiunto dal coach',
              ),
              a['id'],
            );
          } else if (widget.testCategory == 'time' || widget.testCategory == 'score' || widget.testCategory == 'reps') {
            await appState.addBodyLogForAthlete(
              BodyMetricLog(
                id: '',
                date: dateStr,
                type: widget.testId,
                value: val,
              ),
              a['id'],
            );
          }
          savedCount++;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Salvati i risultati per $savedCount atleti'),
        backgroundColor: AppTheme.primary,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(widget.testTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    _isSelectingPresent
                        ? 'Seleziona gli atleti presenti al test'
                        : 'Inserisci i risultati per gli atleti presenti',
                    style: const TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: _isSelectingPresent ? _buildSelectionList() : _buildValueEntryList(),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_isSelectingPresent) {
                          final selectedCount = _athletes.where((a) => a['isPresent']).length;
                          if (selectedCount == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Seleziona almeno un atleta'),
                              backgroundColor: AppTheme.error,
                            ));
                            return;
                          }
                          setState(() {
                            _isSelectingPresent = false;
                          });
                        } else {
                          _saveTests();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: Text(
                        _isSelectingPresent ? 'Avanti' : 'Salva Risultati',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectionList() {
    if (_athletes.isEmpty) {
      return const Center(
        child: Text('Nessun atleta nel team.', style: TextStyle(color: AppTheme.textMediumEmphasis)),
      );
    }
    return ListView.builder(
      itemCount: _athletes.length,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemBuilder: (context, index) {
        final a = _athletes[index];
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              a['isPresent'] = !a['isPresent'];
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: a['isPresent'] ? AppTheme.primary : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  a['isPresent'] ? Icons.check_circle : Icons.circle_outlined,
                  color: a['isPresent'] ? AppTheme.primary : AppTheme.textMediumEmphasis,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    a['name'],
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildValueEntryList() {
    final presentAthletes = _athletes.where((a) => a['isPresent']).toList();

    return ListView.builder(
      itemCount: presentAthletes.length,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemBuilder: (context, index) {
        final a = presentAthletes[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  a['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: a['valueCtrl'],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: widget.testId == 'drop_jump' ? 'Alt.' : '0.0',
                    hintStyle: TextStyle(color: AppTheme.textMediumEmphasis.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppTheme.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (widget.testId == 'drop_jump') ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: a['rsiCtrl'],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'RSI',
                      hintStyle: TextStyle(color: AppTheme.textMediumEmphasis.withOpacity(0.5)),
                      filled: true,
                      fillColor: AppTheme.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
