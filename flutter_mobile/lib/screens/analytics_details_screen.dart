import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/custom_card.dart';

class AnalyticsDetailsScreen extends StatefulWidget {
  final String title;
  final String type; // 'pr' | 'jump'
  final String exerciseId;
  final List<dynamic>? preloadedLogs;
  final bool isReadOnly;
  final String? athleteId;

  const AnalyticsDetailsScreen({
    super.key,
    required this.title,
    required this.type,
    required this.exerciseId,
    this.preloadedLogs,
    this.isReadOnly = false,
    this.athleteId,
  });

  @override
  State<AnalyticsDetailsScreen> createState() => _AnalyticsDetailsScreenState();
}

class _AnalyticsDetailsScreenState extends State<AnalyticsDetailsScreen> {
  String _selectedTimeframe = '1M'; // '1M' | '3M' | '6M' | '1Y' | 'ALL'

  int _getDecimalPlaces() {
    final twoDecimals = [
      'sprint_20m',
      'sprint_60m',
      'balance_bipedal',
      'balance_single_l',
      'balance_single_r',
      'single_leg',
      'leger_vam',
      'leger_vo2max'
    ];
    if (twoDecimals.contains(widget.exerciseId)) return 2;
    return 0;
  }

  List<dynamic> _filterLogsByTimeframe(List<dynamic> allLogs) {
    if (_selectedTimeframe == 'ALL') return allLogs;
    final now = DateTime.now();
    DateTime cutoff;
    switch (_selectedTimeframe) {
      case '1M':
        cutoff = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3M':
        cutoff = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6M':
        cutoff = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1Y':
        cutoff = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        cutoff = DateTime(2000);
    }
    return allLogs
        .where((l) => DateTime.parse((l as dynamic).date).isAfter(cutoff))
        .toList();
  }

  void _showAddOrEditLogDialog({dynamic existingLog}) {
    final isEditing = existingLog != null;
    final int dec = _getDecimalPlaces() > 0 ? _getDecimalPlaces() : 1;
    final TextEditingController valCtrl = TextEditingController(
        text: isEditing
            ? (widget.type == 'pr'
                ? (existingLog as PRLog).weight.toStringAsFixed(dec)
                : widget.type == 'body'
                    ? (existingLog as BodyMetricLog).value.toStringAsFixed(dec)
                    : (existingLog as JumpLog).value.toStringAsFixed(dec))
            : '');
    DateTime selectedDate = isEditing
        ? DateTime.parse((existingLog as dynamic).date)
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
              isEditing ? 'Modifica Record' : 'Nuovo Record: ${widget.title}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0.0',
                  suffixText: ' ${_getUnit()}',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppTheme.primary,
                          onPrimary: Colors.white,
                          surface: AppTheme.card,
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (d != null) setDialogState(() => selectedDate = d);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(PhosphorIconsRegular.calendar,
                          size: 20, color: AppTheme.textMediumEmphasis),
                      Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(valCtrl.text.replaceAll(',', '.'));
                if (val != null) {
                  final appState =
                      Provider.of<AppState>(context, listen: false);

                  if (isEditing) {
                    if (widget.athleteId != null) {
                      if (widget.type == 'pr') {
                        await appState.deletePRLogForAthlete(existingLog.id, widget.exerciseId, widget.athleteId!);
                      } else if (widget.type == 'body') {
                        await appState.deleteBodyLogForAthlete(existingLog.id);
                      } else {
                        await appState.deleteJumpLogForAthlete(existingLog.id);
                      }
                      widget.preloadedLogs?.removeWhere((l) => l.id == existingLog.id);
                    } else {
                      if (widget.type == 'pr') {
                        appState.deletePRLog(existingLog.id);
                      } else if (widget.type == 'body') {
                        appState.deleteBodyLog(existingLog.id);
                      } else {
                        appState.deleteJumpLog(existingLog.id);
                      }
                    }
                  }

                  if (widget.athleteId != null) {
                    if (widget.type == 'pr') {
                      final log = PRLog(
                        id: isEditing ? existingLog.id : '',
                        exerciseId: widget.exerciseId,
                        date: selectedDate.toIso8601String().split('T')[0],
                        weight: val,
                      );
                      await appState.addPRLogForAthlete(log, widget.athleteId!);
                      widget.preloadedLogs?.add(log);
                    } else if (widget.type == 'body') {
                      final log = BodyMetricLog(
                        id: isEditing ? existingLog.id : '',
                        type: widget.exerciseId,
                        date: selectedDate.toIso8601String().split('T')[0],
                        value: val,
                      );
                      await appState.addBodyLogForAthlete(log, widget.athleteId!);
                      widget.preloadedLogs?.add(log);
                    } else {
                      final log = JumpLog(
                        id: isEditing ? existingLog.id : '',
                        type: widget.exerciseId,
                        date: selectedDate.toIso8601String().split('T')[0],
                        value: val,
                      );
                      await appState.addJumpLogForAthlete(log, widget.athleteId!);
                      widget.preloadedLogs?.add(log);
                    }
                    if (mounted) setState(() {});
                  } else {
                    if (widget.type == 'pr') {
                      appState.addPRLog(PRLog(
                        id: isEditing
                            ? existingLog.id
                            : DateTime.now().millisecondsSinceEpoch.toString(),
                        exerciseId: widget.exerciseId,
                        date: selectedDate.toIso8601String().split('T')[0],
                        weight: val,
                      ));
                    } else if (widget.type == 'body') {
                      appState.addBodyLog(BodyMetricLog(
                        id: isEditing
                            ? existingLog.id
                            : DateTime.now().millisecondsSinceEpoch.toString(),
                        type: widget.exerciseId,
                        date: selectedDate.toIso8601String().split('T')[0],
                        value: val,
                      ));
                    } else {
                      appState.addJumpLog(JumpLog(
                        id: isEditing
                            ? existingLog.id
                            : DateTime.now().millisecondsSinceEpoch.toString(),
                        type: widget.exerciseId,
                        date: selectedDate.toIso8601String().split('T')[0],
                        value: val,
                      ));
                    }
                  }
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Filter and sort logs
    List<dynamic> allLogs = [];
    if (widget.preloadedLogs != null) {
      if (widget.type == 'pr') {
        allLogs = widget.preloadedLogs!
            .where((l) => (l as PRLog).exerciseId == widget.exerciseId)
            .toList();
      } else if (widget.type == 'body') {
        allLogs = widget.preloadedLogs!
            .where((l) => (l as BodyMetricLog).type == widget.exerciseId)
            .toList();
      } else {
        allLogs = widget.preloadedLogs!
            .where((l) => (l as JumpLog).type == widget.exerciseId)
            .toList();
      }
    } else {
      if (widget.type == 'pr') {
        allLogs = appState.prLogs
            .where((l) => l.exerciseId == widget.exerciseId)
            .toList();
      } else if (widget.type == 'body') {
        allLogs = appState.bodyLogs
            .where((l) => l.type == widget.exerciseId)
            .toList();
      } else {
        allLogs =
            appState.jumpLogs.where((l) => l.type == widget.exerciseId).toList();
      }
    }

    allLogs.sort(
        (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
    List<dynamic> logs = _filterLogsByTimeframe(allLogs);

    return Scaffold(
      backgroundColor:
          const Color(0xFF111418), // very dark background resembling image
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          if (!widget.isReadOnly)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () => _showAddOrEditLogDialog(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B232A), // circle bg
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(PhosphorIconsRegular.plus,
                      color: AppTheme.primary, size: 20),
                ),
              ),
            )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildTimeframeSelector(),
          const SizedBox(height: 16),
          _buildPeriodMaxCard(logs),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Performance Trend',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          _buildChartSection(logs),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('History (${logs.length})',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Nessun dato registrato nel periodo.',
                        style: TextStyle(color: AppTheme.textMediumEmphasis))))
          else
            ...logs.reversed.map((l) => _buildHistoryRow(l)),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final options = ['1M', '3M', '6M', '1Y', 'ALL'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: options.map((opt) {
            bool isSelected = _selectedTimeframe == opt;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTimeframe = opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textMediumEmphasis,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getUnit() {
    if (widget.type == 'pr') return 'kg';
    if (widget.type == 'jump') return 'cm'; 
    if (widget.type == 'body') {
       if (widget.exerciseId == 'sleep_score' || widget.exerciseId == 'recovery_score' || widget.exerciseId.startsWith('balance_')) return '';
       if (widget.exerciseId == 'sprint_20m' || widget.exerciseId == 'sprint_60m' || widget.exerciseId.startsWith('plank_')) return 's';
       if (widget.exerciseId == 'pullups_max') return 'reps';
       if (widget.exerciseId == 'leger_vam') return 'km/h';
       if (widget.exerciseId == 'leger_vo2max') return 'ml/kg/min';
       if (widget.exerciseId == 'leger_distance') return 'm';
       return '';
    }
    return '';
  }

  Widget _buildPeriodMaxCard(List<dynamic> logs) {
    if (logs.isEmpty) return const SizedBox();
    dynamic targetLog;
    double targetVal = -1.0;

    bool showLatest = widget.exerciseId == 'sleep_score' || widget.exerciseId == 'recovery_score';
    bool wantMin = widget.exerciseId == 'sprint_20m' || widget.exerciseId == 'sprint_60m';

    if (showLatest) {
      targetLog = logs.last;
      targetVal = widget.type == 'pr'
          ? (targetLog as PRLog).weight
          : widget.type == 'body'
              ? (targetLog as BodyMetricLog).value
              : (targetLog as JumpLog).value;
    } else {
      if (wantMin) targetVal = double.infinity;
      for (var l in logs) {
        double val = widget.type == 'pr'
            ? (l as PRLog).weight
            : widget.type == 'body'
                ? (l as BodyMetricLog).value
                : (l as JumpLog).value;
        if (wantMin) {
          if (val < targetVal) {
            targetVal = val;
            targetLog = l;
          }
        } else {
          if (val > targetVal) {
            targetVal = val;
            targetLog = l;
          }
        }
      }
    }

    if (targetLog == null) return const SizedBox();
    String dateStr = (targetLog as dynamic).date;
    String unit = _getUnit();
    String prefixTitle = showLatest ? 'LATEST' : (wantMin ? 'PERIOD MIN' : 'PERIOD MAX');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomCard(
        color: const Color(0xFF22282D),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prefixTitle,
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(targetVal.toStringAsFixed(_getDecimalPlaces()),
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1)),
                if (unit.isNotEmpty) const SizedBox(width: 8),
                if (unit.isNotEmpty) Text(unit,
                    style: const TextStyle(
                        fontSize: 20,
                        color: AppTheme.textMediumEmphasis,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(PhosphorIconsRegular.calendarBlank,
                    size: 14, color: AppTheme.textMediumEmphasis),
                const SizedBox(width: 6),
                Text('Data: $dateStr',
                    style: const TextStyle(
                        color: AppTheme.textMediumEmphasis, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(List<dynamic> logs) {
    if (widget.exerciseId == 'leger_vo2max' || widget.exerciseId == 'leger_distance') {
      return const SizedBox.shrink();
    }
    
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: CustomCard(
          color: Color(0xFF22282D),
          height: 250,
          child: Center(
            child: Text('Nessun dato per il grafico',
                style: TextStyle(
                    color: AppTheme.textMediumEmphasis, fontSize: 13)),
          ),
        ),
      );
    }

    List<FlSpot> spots = [];
    double minY = 1000, maxY = 0;

    for (int i = 0; i < logs.length; i++) {
      double val = widget.type == 'pr'
          ? (logs[i] as PRLog).weight
          : widget.type == 'body'
              ? (logs[i] as BodyMetricLog).value
              : (logs[i] as JumpLog).value;
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    minY = (minY - 10).clamp(0, 500);
    maxY = maxY + 10;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomCard(
        color: const Color(0xFF22282D),
        height: 250,
        padding:
            const EdgeInsets.only(top: 32, bottom: 16, left: 16, right: 32),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              show: true,
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1.0,
                  getTitlesWidget: (val, meta) {
                    final idx = val.round();
                    if (val != idx.toDouble()) return const SizedBox.shrink();
                    if (idx >= 0 &&
                        idx < logs.length &&
                        (idx == 0 ||
                            idx == logs.length - 1 ||
                            (logs.length > 3 &&
                                idx == (logs.length / 2).floor()))) {
                      final date = DateTime.parse((logs[idx] as dynamic).date);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            '${date.day} ${_getMon(date.month).toLowerCase()}',
                            style: const TextStyle(
                                color: AppTheme.textMediumEmphasis,
                                fontSize: 10)),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  getTitlesWidget: (val, meta) {
                    final dec = _getDecimalPlaces();
                    return Text(dec == 0 ? val.toInt().toString() : val.toStringAsFixed(dec),
                        style: const TextStyle(
                            color: AppTheme.textMediumEmphasis, fontSize: 10));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: AppTheme.secondary, // Greenish line as requested
                barWidth: 2, // Width to see trend line
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: AppTheme.secondary,
                      strokeWidth: 2,
                      strokeColor: const Color(0xFF22282D),
                    );
                  },
                ),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryRow(dynamic log) {
    final date = DateTime.parse(log.date);
    double val = widget.type == 'pr'
        ? (log as PRLog).weight
        : widget.type == 'body'
            ? (log as BodyMetricLog).value
            : (log as JumpLog).value;
    String unit = _getUnit();
    String id = widget.type == 'pr'
        ? (log as PRLog).id
        : widget.type == 'body'
            ? (log as BodyMetricLog).id
            : (log as JumpLog).id;

    // In Italian: mer 22 aprile
    List<String> giorni = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
    String giornoStr = giorni[date.weekday - 1];
    String meseStr = _getMonStrFull(date.month);
    
    String desc = widget.type == 'pr' ? '1 Rep Max' : (widget.type == 'jump' ? 'Max Height' : 'Registrazione');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
      child: GestureDetector(
        onTap: widget.isReadOnly ? null : () => _showAddOrEditLogDialog(existingLog: log),
        child: CustomCard(
          color: const Color(0xFF22282D),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$giornoStr ${date.day} $meseStr',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(desc,
                        style: const TextStyle(
                            color: AppTheme.textMediumEmphasis, fontSize: 12)),
                  ],
                ),
              ),
              Text(val.toStringAsFixed(_getDecimalPlaces()),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary)),
              const SizedBox(width: 4),
              Text(unit,
                  style: const TextStyle(
                      color: AppTheme.textMediumEmphasis,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              if (!widget.isReadOnly) ...[
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () async {
                    final appState =
                        Provider.of<AppState>(context, listen: false);
                    if (widget.athleteId != null) {
                      if (widget.type == 'pr') {
                        await appState.deletePRLogForAthlete(id, widget.exerciseId, widget.athleteId!);
                      } else if (widget.type == 'body') {
                        await appState.deleteBodyLogForAthlete(id);
                      } else {
                        await appState.deleteJumpLogForAthlete(id);
                      }
                      widget.preloadedLogs?.removeWhere((l) => l.id == id);
                      if (mounted) setState(() {});
                    } else {
                      if (widget.type == 'pr') {
                        appState.deletePRLog(id);
                      } else if (widget.type == 'body') {
                        appState.deleteBodyLog(id);
                      } else {
                        appState.deleteJumpLog(id);
                      }
                    }
                  },
                  child: const Icon(PhosphorIconsRegular.trash,
                      color: AppTheme.textMediumEmphasis, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getMon(int m) {
    const months = [
      'GEN',
      'FEB',
      'MAR',
      'APR',
      'MAG',
      'GIU',
      'LUG',
      'AGO',
      'SET',
      'OTT',
      'NOV',
      'DIC'
    ];
    return months[m - 1];
  }

  String _getMonStrFull(int m) {
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre'
    ];
    return months[m - 1];
  }
}
