import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/app_state.dart';
import '../services/athlete_monthly_recap_calculator.dart';

class AthleteMonthlyRecapCard extends StatelessWidget {
  final AthleteMonthlyRecap recap;
  final VoidCallback onTap;

  const AthleteMonthlyRecapCard({
    super.key,
    required this.recap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final period = recap.selected;
    return Container(
      key: const ValueKey('athlete_monthly_recap_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
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
                      'IL TUO MESE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textMediumEmphasis,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _periodLabel(period),
                      style: TextStyle(
                        color: AppTheme.textHighEmphasis,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.calendar_month_outlined,
                color: AppTheme.primary,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            formatRecapDuration(period.totalMinutes),
            key: const ValueKey('monthly_recap_total_duration'),
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.w800,
              fontSize: 34,
              height: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _comparisonText(recap),
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Sedute',
                  value: period.sessionCount.round().toString(),
                ),
              ),
              Container(width: 1, height: 34, color: AppTheme.divider),
              Expanded(
                child: _Metric(
                  label: 'Durata media',
                  value: period.validDurationSessionCount <= 0
                      ? '—'
                      : formatRecapDuration(period.averageSessionMinutes),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RecapCompositionBar(period: period),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: AthleteRecapMacro.ordered
                .where((id) => period.bucket(id).minutes > 0)
                .map(
                  (id) => _LegendItem(
                    color: recapMacroColor(id),
                    label: AthleteRecapMacro.label(id),
                  ),
                )
                .toList(),
          ),
          if (period.incompleteDurationCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${period.incompleteDurationCount.round()} sedut${period.incompleteDurationCount.round() == 1 ? 'a' : 'e'} senza durata completa',
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('open_monthly_recap_details'),
              onPressed: onTap,
              label: const Text(
                'VEDI DETTAGLIO',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.chevron_right, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class RecapCompositionBar extends StatelessWidget {
  final AthleteMonthlyRecapPeriod period;
  final double height;

  const RecapCompositionBar({
    super.key,
    required this.period,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (period.totalMinutes <= 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.subtleFill,
          borderRadius: BorderRadius.circular(height),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: AthleteRecapMacro.ordered
              .where((id) => period.bucket(id).minutes > 0)
              .map(
                (id) => Expanded(
                  flex:
                      (period.bucket(id).minutes * 10).round().clamp(1, 100000),
                  child: ColoredBox(color: recapMacroColor(id)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class AthleteMonthlyRecapScreen extends StatefulWidget {
  final DateTime initialMonth;

  const AthleteMonthlyRecapScreen({
    super.key,
    required this.initialMonth,
  });

  @override
  State<AthleteMonthlyRecapScreen> createState() =>
      _AthleteMonthlyRecapScreenState();
}

class _AthleteMonthlyRecapScreenState extends State<AthleteMonthlyRecapScreen> {
  static const _calculator = AthleteMonthlyRecapCalculator();
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.profile;
    final now = DateTime.now();
    final recap = _calculator.build(
      sessions: appState.sessions,
      coachEvents: appState.coachEvents,
      athleteId: profile?.id,
      athleteEmail: profile?.email,
      athleteName: profile == null
          ? null
          : '${profile.firstName} ${profile.lastName}'.trim(),
      selectedMonth: _selectedMonth,
      now: now,
    );
    final currentMonth = DateTime(now.year, now.month);

    return Scaffold(
      appBar: AppBar(title: const Text('Recap allenamenti')),
      body: ListView(
        key: const ValueKey('athlete_monthly_recap_details'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _MonthSelector(
            selectedMonth: _selectedMonth,
            earliestMonth: recap.earliestMonth,
            currentMonth: currentMonth,
            onPrevious: _isAfter(_selectedMonth, recap.earliestMonth)
                ? () => _selectMonth(
                      DateTime(_selectedMonth.year, _selectedMonth.month - 1),
                    )
                : null,
            onNext: _isBefore(_selectedMonth, currentMonth)
                ? () => _selectMonth(
                      DateTime(_selectedMonth.year, _selectedMonth.month + 1),
                    )
                : null,
            onOpenPicker: () => _openMonthPicker(
              recap.earliestMonth,
              currentMonth,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryCard(recap: recap),
          if (recap.selected.incompleteDurationCount > 0) ...[
            const SizedBox(height: 12),
            _DataNotice(count: recap.selected.incompleteDurationCount.round()),
          ],
          const SizedBox(height: 20),
          _ComparisonChart(recap: recap),
          const SizedBox(height: 24),
          Text(
            'Composizione del mese',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (recap.selected.sessionCount <= 0)
            _EmptyMonth(period: recap.selected)
          else
            ...AthleteRecapMacro.ordered
                .map(recap.selected.bucket)
                .where((bucket) => bucket.sessionCount > 0)
                .map(
                  (bucket) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BreakdownTile(
                      bucket: bucket,
                      period: recap.selected,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _selectMonth(DateTime month) {
    setState(() => _selectedMonth = DateTime(month.year, month.month));
  }

  Future<void> _openMonthPicker(
    DateTime earliestMonth,
    DateTime currentMonth,
  ) async {
    final months = <DateTime>[];
    var cursor = currentMonth;
    while (!_isBefore(cursor, earliestMonth)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Scegli il mese',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: months.length,
                  itemBuilder: (_, index) {
                    final month = months[index];
                    final selected = _sameMonth(month, _selectedMonth);
                    return ListTile(
                      key: ValueKey(
                        'recap_month_${month.year}_${month.month}',
                      ),
                      title: Text(_monthLabel(month)),
                      trailing: selected
                          ? const Icon(Icons.check, color: AppTheme.primary)
                          : null,
                      onTap: () => Navigator.pop(context, month),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) _selectMonth(selected);
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final DateTime earliestMonth;
  final DateTime currentMonth;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOpenPicker;

  const _MonthSelector({
    required this.selectedMonth,
    required this.earliestMonth,
    required this.currentMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('monthly_recap_previous_month'),
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('monthly_recap_month_picker'),
            onPressed: onOpenPicker,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(
              _monthLabel(selectedMonth),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('monthly_recap_next_month'),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AthleteMonthlyRecap recap;

  const _SummaryCard({required this.recap});

  @override
  Widget build(BuildContext context) {
    final period = recap.selected;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _periodLabel(period),
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatRecapDuration(period.totalMinutes),
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _comparisonText(recap),
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Sedute',
                  value: period.sessionCount.round().toString(),
                ),
              ),
              Container(width: 1, height: 34, color: AppTheme.divider),
              Expanded(
                child: _Metric(
                  label: 'Durata media',
                  value: period.validDurationSessionCount <= 0
                      ? '—'
                      : formatRecapDuration(period.averageSessionMinutes),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RecapCompositionBar(period: period, height: 12),
        ],
      ),
    );
  }
}

class _ComparisonChart extends StatelessWidget {
  final AthleteMonthlyRecap recap;

  const _ComparisonChart({required this.recap});

  @override
  Widget build(BuildContext context) {
    final values = <_ChartValue>[
      if (recap.average != null)
        _ChartValue(
          'Media\n${recap.averageMonthCount}M',
          recap.average!,
        ),
      if (recap.previous != null)
        _ChartValue(_shortMonth(recap.previous!.month), recap.previous!),
      _ChartValue(_shortMonth(recap.selected.month), recap.selected),
    ];
    final maxMinutes = values.fold<double>(
      0,
      (max, value) =>
          value.period.totalMinutes > max ? value.period.totalMinutes : max,
    );

    return Container(
      height: 310,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confronto del volume',
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recap.isCurrentMonth
                ? 'Periodi confrontati fino allo stesso giorno'
                : 'Mesi di calendario completi',
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxMinutes <= 0 ? 1 : (maxMinutes / 60) * 1.22,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppTheme.chartGrid, strokeWidth: 1),
                ),
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
                      getTitlesWidget: (value, _) => Text(
                        '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}h',
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
                      reservedSize: 34,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= values.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            values[index].label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textMediumEmphasis,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: values.asMap().entries.map((entry) {
                  final stacks = <BarChartRodStackItem>[];
                  var start = 0.0;
                  for (final macroId in AthleteRecapMacro.ordered) {
                    final value =
                        entry.value.period.bucket(macroId).minutes / 60;
                    if (value <= 0) continue;
                    stacks.add(
                      BarChartRodStackItem(
                        start,
                        start + value,
                        recapMacroColor(macroId),
                      ),
                    );
                    start += value;
                  }
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.period.totalMinutes / 60,
                        width: 30,
                        color: entry.value.period.totalMinutes <= 0
                            ? AppTheme.subtleFill
                            : null,
                        rodStackItems: stacks,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: AthleteRecapMacro.ordered
                .map(
                  (id) => _LegendItem(
                    color: recapMacroColor(id),
                    label: AthleteRecapMacro.label(id),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  final AthleteMonthlyRecapBucket bucket;
  final AthleteMonthlyRecapPeriod period;

  const _BreakdownTile({required this.bucket, required this.period});

  @override
  Widget build(BuildContext context) {
    final details = bucket.details.values.toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    final hasSkiDetails =
        bucket.id == AthleteRecapMacro.ski && period.skiSpecialties.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: ExpansionTile(
        key: ValueKey('monthly_recap_bucket_${bucket.id}'),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 10,
          height: 38,
          decoration: BoxDecoration(
            color: recapMacroColor(bucket.id),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Text(
          bucket.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${formatRecapDuration(bucket.minutes)} · ${_sessionsLabel(bucket.sessionCount)} · ${bucket.percentageOf(period.totalMinutes).round()}%',
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 12,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (hasSkiDetails) ...[
            ...period.skiSpecialties.values.map(
              (specialty) => _DetailRow(
                label: specialty.label,
                value:
                    '${specialty.sessionCount} sedut${specialty.sessionCount == 1 ? 'a' : 'e'} · ${specialty.technicalVolume} cambi/passaggi',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Una seduta con due specialità compare in entrambe. Le ore restano attribuite al totale Sci alpino.',
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ] else if (details.isNotEmpty)
            ...details.map(
              (detail) => _DetailRow(
                label: detail.label,
                value:
                    '${formatRecapDuration(detail.minutes)} · ${_sessionsLabel(detail.sessionCount)}',
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Nessun dettaglio aggiuntivo registrato.',
                style: TextStyle(color: AppTheme.textMediumEmphasis),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textHighEmphasis),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  final AthleteMonthlyRecapPeriod period;

  const _EmptyMonth({required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('monthly_recap_empty_state'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: AppTheme.textMediumEmphasis,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            'Nessuna seduta registrata',
            style: TextStyle(
              color: AppTheme.textHighEmphasis,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Il confronto resta visibile quando sono disponibili mesi precedenti.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMediumEmphasis,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataNotice extends StatelessWidget {
  final int count;

  const _DataNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            AppTheme.primary.withValues(alpha: AppTheme.isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$count sedut${count == 1 ? 'a è conteggiata' : 'e sono conteggiate'} nel totale delle attività, ma non nelle ore perché la durata non è disponibile.',
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textHighEmphasis,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMediumEmphasis,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(color: AppTheme.textMediumEmphasis, fontSize: 10),
        ),
      ],
    );
  }
}

class _ChartValue {
  final String label;
  final AthleteMonthlyRecapPeriod period;

  const _ChartValue(this.label, this.period);
}

Color recapMacroColor(String id) {
  switch (id) {
    case AthleteRecapMacro.ski:
      return AppTheme.primary;
    case AthleteRecapMacro.preparation:
      return AppTheme.secondary;
    case AthleteRecapMacro.otherSports:
      return const Color(0xFFFFA726);
    case AthleteRecapMacro.recoveryOther:
    default:
      return const Color(0xFFAB7DF6);
  }
}

String formatRecapDuration(double minutes) {
  final rounded = minutes.round().clamp(0, 10000000);
  final hours = rounded ~/ 60;
  final remaining = rounded % 60;
  if (hours <= 0) return '${remaining}m';
  if (remaining == 0) return '${hours}h';
  return '${hours}h ${remaining}m';
}

String _comparisonText(AthleteMonthlyRecap recap) {
  final parts = <String>[];
  final previous = recap.previous;
  if (previous != null) {
    parts.add(
      _deltaText(
        recap.selected.totalMinutes,
        previous.totalMinutes,
        recap.isCurrentMonth
            ? 'rispetto allo stesso periodo di ${_shortMonth(previous.month).toLowerCase()}'
            : 'rispetto a ${_shortMonth(previous.month).toLowerCase()}',
      ),
    );
  }
  final average = recap.average;
  if (average != null) {
    parts.add(
      _deltaText(
        recap.selected.totalMinutes,
        average.totalMinutes,
        'rispetto alla media ${recap.averageMonthCount}M',
      ),
    );
  }
  return parts.isEmpty
      ? 'Lo storico non è ancora sufficiente per un confronto.'
      : parts.join(' · ');
}

String _deltaText(double current, double reference, String suffix) {
  final difference = current - reference;
  if (reference > 0) {
    final percentage = (difference / reference) * 100;
    final sign = percentage > 0 ? '+' : '';
    return '$sign${percentage.round()}% $suffix';
  }
  if (current <= 0) return '0h $suffix';
  return '+${formatRecapDuration(difference)} $suffix';
}

String _periodLabel(AthleteMonthlyRecapPeriod period) {
  final month = _monthLabel(period.month);
  if (period.throughDay == null) return month;
  return '1–${period.throughDay} ${_shortMonth(period.month).toLowerCase()} ${period.month.year}';
}

String _monthLabel(DateTime month) {
  final value = DateFormat('MMMM yyyy', 'it').format(month);
  return value[0].toUpperCase() + value.substring(1);
}

String _shortMonth(DateTime month) {
  final value = DateFormat('MMM', 'it').format(month).replaceAll('.', '');
  return value[0].toUpperCase() + value.substring(1);
}

String _sessionsLabel(double count) {
  final rounded = count.round();
  return '$rounded sedut${rounded == 1 ? 'a' : 'e'}';
}

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

bool _isBefore(DateTime a, DateTime b) =>
    a.year < b.year || (a.year == b.year && a.month < b.month);

bool _isAfter(DateTime a, DateTime b) => _isBefore(b, a);
