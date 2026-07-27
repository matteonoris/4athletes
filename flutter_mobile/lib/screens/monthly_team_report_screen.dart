import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../models/monthly_team_report_models.dart';
import '../providers/app_state.dart';
import '../services/monthly_team_report_pdf_service.dart';
import '../services/monthly_team_report_service.dart';
import 'coach_athlete_detail_screen.dart';

class MonthlyTeamReportScreen extends StatefulWidget {
  final Team? initialTeam;

  const MonthlyTeamReportScreen({
    super.key,
    this.initialTeam,
  });

  @override
  State<MonthlyTeamReportScreen> createState() =>
      _MonthlyTeamReportScreenState();
}

class _MonthlyTeamReportScreenState extends State<MonthlyTeamReportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedTeamId;
  MonthlyTeamReport? _report;
  bool _didInit = false;
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  bool _includeIndividualSheets = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final teams = context.read<AppState>().teams;
    _selectedTeamId =
        widget.initialTeam?.id ?? (teams.isNotEmpty ? teams.first.id : null);
    if (_selectedTeamId != null) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    final teamId = _selectedTeamId;
    if (teamId == null || teamId.isEmpty) return;

    final appState = context.read<AppState>();
    final role = appState.userProfile?.role;
    if (role != 'coach' && role != 'admin') {
      setState(() {
        _error = 'Non hai i permessi per visualizzare il report team.';
        _isLoading = false;
      });
      return;
    }
    if (!appState.teams.any((team) => team.id == teamId)) {
      setState(() {
        _error = 'Team non disponibile o non autorizzato.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = MonthlyTeamReportService(Supabase.instance.client);
      final report = await service.getMonthlyTeamReport(
        teamId: teamId,
        month: _selectedMonth,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore nel caricamento del report mensile.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Seleziona mese',
    );
    if (picked == null) return;
    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });
    _loadReport();
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    _loadReport();
  }

  void _showPdfOptions() {
    if (_report == null || _isGeneratingPdf) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.modalHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.print, color: AppTheme.primary),
                title: Text(
                  'Stampa PDF',
                  style: TextStyle(color: AppTheme.textHighEmphasis),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _generatePdf(share: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share, color: AppTheme.primary),
                title: Text(
                  'Esporta report',
                  style: TextStyle(color: AppTheme.textHighEmphasis),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _generatePdf(share: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf({required bool share}) async {
    final report = _report;
    if (report == null) return;

    setState(() => _isGeneratingPdf = true);
    try {
      const service = MonthlyTeamReportPdfService();
      if (share) {
        await service.shareReport(
          report,
          includeIndividualSheets: _includeIndividualSheets,
        );
      } else {
        await service.printReport(
          report,
          includeIndividualSheets: _includeIndividualSheets,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore nella generazione del PDF.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final teams = appState.teams;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Report mensile team'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadReport,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: teams.isEmpty
          ? _buildStateMessage(
              icon: Icons.group_off,
              title: 'Nessun team selezionato',
              message:
                  'Crea o seleziona un team per generare il report mensile.',
            )
          : _buildBody(teams),
    );
  }

  Widget _buildBody(List<Team> teams) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildHeaderControls(teams),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 96),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (_error != null)
            _buildStateMessage(
              icon: Icons.error_outline,
              title: 'Report non disponibile',
              message: _error!,
              actionLabel: 'Riprova',
              onAction: _loadReport,
            )
          else if (_report == null)
            _buildStateMessage(
              icon: Icons.analytics_outlined,
              title: 'Nessun report caricato',
              message: 'Seleziona team e mese per caricare i dati.',
              actionLabel: 'Carica report',
              onAction: _loadReport,
            )
          else
            ..._buildReportContent(_report!),
        ],
      ),
    );
  }

  Widget _buildHeaderControls(List<Team> teams) {
    Team? selectedTeam;
    for (final team in teams) {
      if (team.id == _selectedTeamId) {
        selectedTeam = team;
        break;
      }
    }
    final monthLabel = DateFormat('MMMM yyyy', 'it').format(_selectedMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report mensile team',
                      style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedTeam?.name ?? 'Team',
                      style: TextStyle(
                        color: AppTheme.textMediumEmphasis,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _report == null || _isGeneratingPdf
                    ? null
                    : _showPdfOptions,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickMonth,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.subtleFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      monthLabel,
                      style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (teams.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.subtleFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTeamId,
                  isExpanded: true,
                  dropdownColor: AppTheme.card,
                  items: teams
                      .map(
                        (team) => DropdownMenuItem(
                          value: team.id,
                          child: Text(
                            team.name,
                            style: TextStyle(
                              color: AppTheme.textHighEmphasis,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedTeamId = value);
                    _loadReport();
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _includeIndividualSheets,
            activeThumbColor: AppTheme.primary,
            onChanged: (value) {
              setState(() => _includeIndividualSheets = value);
            },
            title: Text(
              'Includi schede individuali nel PDF',
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReportContent(MonthlyTeamReport report) {
    if (report.athletes.isEmpty) {
      return [
        _buildStateMessage(
          icon: Icons.person_off_outlined,
          title: 'Nessun atleta nel team',
          message: 'Il team selezionato non contiene atleti da monitorare.',
        ),
      ];
    }

    final hasMonthData = report.summary.athletesWithActivity > 0;
    return [
      if (!hasMonthData)
        _inlineNotice(
          'Nessun dato registrato per il mese selezionato. Le presenze possono risultare N/D o dati mancanti.',
        ),
      _buildKpiCards(report),
      const SizedBox(height: 20),
      _buildAutomaticSummary(report),
      const SizedBox(height: 20),
      _buildTeamSynthesis(report),
      const SizedBox(height: 20),
      _buildAthleteComparison(report),
      const SizedBox(height: 20),
      _buildCharts(report),
    ];
  }

  Widget _buildKpiCards(MonthlyTeamReport report) {
    final cards = [
      _KpiData('Atleti monitorati', '${report.summary.totalAthletes}',
          Icons.groups_outlined),
      _KpiData('Presenza media sci',
          _formatPresence(report.summary.averageSkiPresence), Icons.ac_unit),
      _KpiData(
        'Presenza media preparazione',
        _formatPresence(report.summary.averageAthleticPresence),
        Icons.fitness_center,
      ),
      _KpiData(
        'Sedute coach completate',
        '${report.coachWorkload.completedSessionCount}',
        Icons.event_available_outlined,
      ),
      _KpiData(
        'Ore sci coach',
        _formatHours(report.coachWorkload.completedSkiHours),
        Icons.timer_outlined,
      ),
      _KpiData(
        'Ore preparazione coach',
        _formatHours(report.coachWorkload.completedPreparationHours),
        Icons.timer,
      ),
      _KpiData(
        'Volume sci medio atleta',
        report.ski.validAthleteCount == 0
            ? 'N/D'
            : '${_formatNumber(report.ski.averageDirectionChanges)} · '
                '${report.ski.validAthleteCount}/'
                '${report.ski.skiActiveAthleteCount}',
        Icons.swap_calls,
      ),
      _KpiData('Dati incompleti', '${report.summary.incompleteDataCount}',
          Icons.info_outline),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map((card) => SizedBox(width: width, child: _buildKpiCard(card)))
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    return MonthlyTeamReportKpiCard(
      label: data.label,
      value: data.value,
      icon: data.icon,
    );
  }

  Widget _buildAutomaticSummary(MonthlyTeamReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.notes_outlined, 'Sintesi automatica'),
          const SizedBox(height: 10),
          Text(
            report.automaticSummary,
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSynthesis(MonthlyTeamReport report) {
    final mostPresent = List<MonthlyTeamAthleteReport>.from(report.athletes)
      ..sort((a, b) => _averagePresence(b).compareTo(_averagePresence(a)));
    final outOfProgram = List<MonthlyTeamAthleteReport>.from(report.athletes)
      ..sort((a, b) => b.outOfProgramHours.compareTo(a.outOfProgramHours));
    final attention = List<MonthlyTeamAthleteReport>.from(report.athletes)
      ..sort((a, b) => b.alerts.length.compareTo(a.alerts.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.insights_outlined, 'Sintesi team'),
        const SizedBox(height: 12),
        _synthesisBlock(
          'Atleti più presenti',
          mostPresent
              .where((athlete) => _averagePresence(athlete) > 0)
              .take(3)
              .map((athlete) =>
                  '${athlete.athleteName} ${(_averagePresence(athlete) * 100).round()}%')
              .toList(),
        ),
        const SizedBox(height: 10),
        _synthesisBlock(
          'Più volume fuori programma',
          outOfProgram
              .where((athlete) => athlete.outOfProgramHours > 0)
              .take(3)
              .map((athlete) =>
                  '${athlete.athleteName} ${_formatHours(athlete.outOfProgramHours)}')
              .toList(),
        ),
        const SizedBox(height: 10),
        _synthesisBlock(
          'Atleti da attenzionare',
          attention
              .where((athlete) => athlete.alerts.isNotEmpty)
              .take(3)
              .map((athlete) =>
                  '${athlete.athleteName} ${athlete.alerts.first.label}')
              .toList(),
        ),
      ],
    );
  }

  Widget _synthesisBlock(String title, List<String> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              'N/D',
              style: TextStyle(color: AppTheme.textMediumEmphasis),
            )
          else
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  row,
                  style: TextStyle(
                    color: AppTheme.textMediumEmphasis,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAthleteComparison(MonthlyTeamReport report) {
    final athletes = List<MonthlyTeamAthleteReport>.from(report.athletes)
      ..sort((a, b) => a.athleteName.compareTo(b.athleteName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.table_rows_outlined, 'Tabella comparativa atleti'),
        const SizedBox(height: 12),
        ...athletes.map(_athleteRow),
      ],
    );
  }

  Widget _athleteRow(MonthlyTeamAthleteReport athlete) {
    final mainAlert = athlete.alerts.isEmpty ? null : athlete.alerts.first;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CoachAthleteDetailScreen(
              athleteName: athlete.athleteName,
              initial: athlete.initial,
              athleteId: athlete.athleteId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.subtleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.subtleFill,
                  child: Text(
                    athlete.initial,
                    style: TextStyle(
                      color: AppTheme.textHighEmphasis,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        athlete.athleteName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textHighEmphasis,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        athlete.skiPresence != null ||
                                athlete.athleticPresence != null
                            ? '${_formatPresence(athlete.skiPresence)} sci | ${_formatPresence(athlete.athleticPresence)} atletica'
                            : 'Dati mancanti',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textMediumEmphasis),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniMetric('Sci', _formatHours(athlete.totalSkiHours)),
                _miniMetric(
                    'Atletica', _formatHours(athlete.totalAthleticHours)),
                _miniMetric('Volume sci', '${athlete.totalDirectionChanges}'),
                if (athlete.slDirectionChanges > 0)
                  _miniMetric('SL', '${athlete.slDirectionChanges}'),
                if (athlete.gsDirectionChanges > 0)
                  _miniMetric('GS', '${athlete.gsDirectionChanges}'),
                if (athlete.sgDirectionChanges > 0)
                  _miniMetric('SG', '${athlete.sgDirectionChanges}'),
                if (athlete.dhDirectionChanges > 0)
                  _miniMetric('DH', '${athlete.dhDirectionChanges}'),
                if (athlete.sxDirectionChanges > 0)
                  _miniMetric('SX', '${athlete.sxDirectionChanges}'),
                _miniMetric('Kg', _formatNumber(athlete.strengthVolumeKg)),
              ],
            ),
            if (mainAlert != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  mainAlert.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: AppTheme.textMediumEmphasis,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCharts(MonthlyTeamReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.bar_chart, 'Grafici'),
        const SizedBox(height: 12),
        _barChartCard(
          title: 'Ore coach per tipologia',
          values: [
            _ChartValue('Sci', report.coachWorkload.completedSkiHours),
            _ChartValue(
              'Prep',
              report.coachWorkload.completedPreparationHours,
            ),
            _ChartValue(
              'Sport',
              report.coachWorkload.completedOtherSportHours,
            ),
          ],
          color: Colors.tealAccent,
        ),
        const SizedBox(height: 12),
        _barChartCard(
          title: 'Volume sci per atleta',
          values: report.athletes
              .map((athlete) => _ChartValue(
                    athlete.initial,
                    athlete.totalDirectionChanges.toDouble(),
                  ))
              .toList(),
          color: AppTheme.primary,
        ),
        const SizedBox(height: 12),
        _barChartCard(
          title: 'Volume tecnico medio per specialità',
          values: report.ski.averageDirectionChangesByDiscipline.entries
              .map((entry) => _ChartValue(entry.key, entry.value.toDouble()))
              .toList(),
          color: AppTheme.secondary,
        ),
        const SizedBox(height: 12),
        _barChartCard(
          title: 'Presenza sci per atleta',
          values: report.athletes
              .map((athlete) => _ChartValue(
                    athlete.initial,
                    (athlete.skiPresence ?? 0) * 100,
                  ))
              .toList(),
          color: Colors.lightBlueAccent,
        ),
        const SizedBox(height: 12),
        _barChartCard(
          title: 'Presenza preparazione per atleta',
          values: report.athletes
              .map((athlete) => _ChartValue(
                    athlete.initial,
                    (athlete.athleticPresence ?? 0) * 100,
                  ))
              .toList(),
          color: Colors.orangeAccent,
        ),
        const SizedBox(height: 12),
        _barChartCard(
          title: 'Volume kg per atleta',
          values: report.athletes
              .map((athlete) =>
                  _ChartValue(athlete.initial, athlete.strengthVolumeKg))
              .toList(),
          color: Colors.greenAccent,
        ),
      ],
    );
  }

  Widget _barChartCard({
    required String title,
    required List<_ChartValue> values,
    required Color color,
  }) {
    final nonZero = values.where((value) => value.value > 0).toList();
    final chartValues = values.take(12).toList();
    final maxValue = chartValues.fold<double>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );

    return Container(
      height: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: nonZero.isEmpty
                ? Center(
                    child: Text(
                      'Nessun dato per il mese selezionato',
                      style: TextStyle(color: AppTheme.textMediumEmphasis),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: AppTheme.chartGrid, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: AppTheme.textLowEmphasis,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= chartValues.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  chartValues[index].label,
                                  style: TextStyle(
                                    color: AppTheme.textMediumEmphasis,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: chartValues.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.value,
                              color: color,
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _inlineNotice(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: AppTheme.textMediumEmphasis,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textMediumEmphasis, size: 44),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  double _averagePresence(MonthlyTeamAthleteReport athlete) {
    final values = [athlete.skiPresence, athlete.athleticPresence]
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _formatPresence(double? value) {
    if (value == null) return 'N/D';
    return '${(value * 100).round()}%';
  }

  String _formatHours(double value) {
    if (value == 0) return '0h';
    return '${_formatNumber(value)}h';
  }

  String _formatNumber(double value) {
    if (value.abs() >= 100) return value.toStringAsFixed(0);
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;

  const _KpiData(this.label, this.value, this.icon);
}

class _ChartValue {
  final String label;
  final double value;

  const _ChartValue(this.label, this.value);
}

class MonthlyTeamReportKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const MonthlyTeamReportKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
