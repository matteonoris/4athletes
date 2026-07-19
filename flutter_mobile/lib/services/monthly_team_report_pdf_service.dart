import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/monthly_team_report_models.dart';

class MonthlyTeamReportPdfService {
  const MonthlyTeamReportPdfService();

  Future<Uint8List> buildPdf(
    MonthlyTeamReport report, {
    bool includeIndividualSheets = true,
  }) async {
    final doc = pw.Document();
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );
    final monthLabel = _monthLabel(report.month);
    final generatedLabel =
        DateFormat('dd/MM/yyyy HH:mm', 'it').format(report.generatedAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _title('Report mensile team'),
          pw.SizedBox(height: 4),
          _muted('${report.team.name} - $monthLabel'),
          pw.SizedBox(height: 18),
          _sectionTitle('Sintesi del mese'),
          pw.SizedBox(height: 8),
          pw.Text(
            report.automaticSummary,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
          pw.SizedBox(height: 16),
          _kpiGrid([
            _PdfKpi('Atleti', '${report.summary.totalAthletes}'),
            _PdfKpi('Atleti attivi', '${report.summary.athletesWithActivity}'),
            _PdfKpi(
              'Presenza sci',
              _formatPercent(report.summary.averageSkiPresence),
            ),
            _PdfKpi(
              'Presenza preparazione',
              _formatPercent(report.summary.averageAthleticPresence),
            ),
            _PdfKpi(
              'Sedute coach',
              '${report.coachWorkload.completedSessionCount}',
            ),
            _PdfKpi(
              'Ore sci coach',
              _formatNumber(report.coachWorkload.completedSkiHours),
            ),
            _PdfKpi(
              'Ore preparazione coach',
              _formatNumber(report.coachWorkload.completedPreparationHours),
            ),
            _PdfKpi(
              'Volume sci medio',
              report.ski.validAthleteCount == 0
                  ? 'N/D'
                  : _formatNumber(report.ski.averageDirectionChanges),
            ),
          ]),
          pw.SizedBox(height: 16),
          _horizontalBarChart(
            title: 'Ore coach per tipologia',
            values: {
              'Sci': report.coachWorkload.completedSkiHours,
              'Preparazione': report.coachWorkload.completedPreparationHours,
              'Altri sport': report.coachWorkload.completedOtherSportHours,
            },
            color: PdfColors.teal600,
          ),
          pw.SizedBox(height: 8),
          _muted(
            'Le ore coach conteggiano ogni seduta completata una sola volta, indipendentemente dal numero di presenti.',
          ),
          pw.SizedBox(height: 16),
          _sectionTitle('Dati incompleti'),
          pw.SizedBox(height: 6),
          pw.Text(
            report.summary.incompleteDataCount == 0
                ? 'Non sono stati rilevati dati incompleti nel report.'
                : 'Rilevati ${report.summary.incompleteDataCount} elementi incompleti o non classificati.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        margin: const pw.EdgeInsets.all(22),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _sectionHeader('Tabella comparativa atleti', report, monthLabel),
          _table(
            headers: const [
              'Atleta',
              'Pres. sci',
              'Pres. prep.',
              'Ore tot.',
              'Ore sci',
              'Ore prep.',
              'Altri/rec.',
              'Vol. sci',
              'vs media 6m',
              'Alert',
            ],
            rows: report.athletes.map((athlete) {
              return [
                athlete.athleteName,
                _formatPercent(athlete.skiPresence),
                _formatPercent(athlete.athleticPresence),
                _formatNumber(athlete.totalHours),
                _formatNumber(athlete.totalSkiHours),
                _formatNumber(athlete.totalAthleticHours),
                _formatNumber(
                  athlete.otherSportHours + athlete.recoveryOtherHours,
                ),
                '${athlete.totalDirectionChanges}',
                _formatVsAverage(athlete),
                athlete.alerts.take(3).map((alert) => alert.label).join(', '),
              ];
            }).toList(),
            headerFontSize: 7,
            cellFontSize: 7,
          ),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _sectionHeader('Sci alpino', report, monthLabel),
          _kpiGrid([
            _PdfKpi(
              'Media atleta',
              _formatNumber(report.ski.averageDirectionChanges),
            ),
            _PdfKpi(
              'Copertura dati',
              '${report.ski.validAthleteCount}/${report.ski.skiActiveAthleteCount}',
            ),
            _PdfKpi(
              'Sedute sci coach',
              '${report.coachWorkload.completedSkiSessions}',
            ),
            _PdfKpi(
              'Ore sci coach',
              _formatNumber(report.coachWorkload.completedSkiHours),
            ),
          ]),
          pw.SizedBox(height: 14),
          _horizontalBarChart(
            title: 'Volume tecnico medio per atleta e specialità',
            values: report.ski.averageDirectionChangesByDiscipline,
            color: PdfColors.blue600,
          ),
          pw.SizedBox(height: 14),
          _table(
            headers: const [
              'Atleta',
              'CL',
              'SL',
              'GS',
              'SG',
              'DH',
              'SX',
              'ADD',
              'Tot.'
            ],
            rows: report.athletes
                .map((athlete) => [
                      athlete.athleteName,
                      '${athlete.clDirectionChanges}',
                      '${athlete.slDirectionChanges}',
                      '${athlete.gsDirectionChanges}',
                      '${athlete.sgDirectionChanges}',
                      '${athlete.dhDirectionChanges}',
                      '${athlete.sxDirectionChanges}',
                      '${athlete.addestramentoDirectionChanges}',
                      '${athlete.totalDirectionChanges}',
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 14),
          _sectionTitle('Alert sci'),
          ..._alertTexts(report, const {
            'low_ski_presence',
            'low_ski_volume',
            'ski_imbalance',
          }),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _sectionHeader('Preparazione atletica', report, monthLabel),
          _kpiGrid([
            _PdfKpi(
              'Sedute coach',
              '${report.coachWorkload.completedPreparationSessions}',
            ),
            _PdfKpi(
              'Ore coach',
              _formatNumber(report.coachWorkload.completedPreparationHours),
            ),
            _PdfKpi(
              'Ore medie atleta',
              _formatNumber(report.athletic.averageAthleteHours),
            ),
            _PdfKpi(
              'Volume kg medio',
              _formatNumber(report.athletic.averageStrengthVolumeKg),
            ),
            _PdfKpi(
              'Atleti con ore prep.',
              '${report.athletic.validAthleteCount}/${report.summary.totalAthletes}',
            ),
          ]),
          pw.SizedBox(height: 6),
          pw.Text(
            'Medie tecniche su dati validi: '
            'volume ${_formatNumber(report.athletic.averageStrengthVolumeKg)} kg '
            '(${report.athletic.strengthVolumeCoverage}/${report.summary.totalAthletes}), '
            'serie ${_formatNumber(report.athletic.averageStrengthSets)} '
            '(${report.athletic.strengthSetsCoverage}/${report.summary.totalAthletes}), '
            'drill ${_formatNumber(report.athletic.averageDrills)} '
            '(${report.athletic.drillCoverage}/${report.summary.totalAthletes}), '
            'resistenza ${_formatNumber(report.athletic.averageEnduranceMeters)} m '
            '(${report.athletic.enduranceCoverage}/${report.summary.totalAthletes}).',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 14),
          if (report.coachWorkload.preparationHoursByType.isNotEmpty) ...[
            _horizontalBarChart(
              title: 'Ore coach per tipo di preparazione',
              values: _labeledPreparationValues(
                report.coachWorkload.preparationHoursByType,
              ),
              color: PdfColors.orange600,
            ),
            pw.SizedBox(height: 14),
          ],
          _table(
            headers: const [
              'Atleta',
              'Ore prep.',
              'Volume kg',
              'Serie forza',
              'Drill',
              'Resistenza m',
            ],
            rows: report.athletes
                .map((athlete) => [
                      athlete.athleteName,
                      _formatNumber(athlete.totalAthleticHours),
                      _formatNumber(athlete.strengthVolumeKg),
                      '${athlete.strengthSets}',
                      '${athlete.drillCount}',
                      _formatNumber(athlete.enduranceMeters),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 14),
          _sectionTitle('Alert preparazione'),
          ..._alertTexts(report, const {
            'low_athletic_presence',
            'low_athletic_volume',
            'high_out_of_program',
            'high_volume_recovery',
          }),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        margin: const pw.EdgeInsets.all(22),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _sectionHeader('Test fisici', report, monthLabel),
          _table(
            headers: const [
              'Atleta',
              'SJ',
              'CMJ',
              'DJ',
              'RSI',
              'SL sx',
              'SL dx',
              'Asim.',
              'Delta CMJ',
              'Delta RSI',
            ],
            rows: report.athletes
                .map((athlete) => [
                      athlete.athleteName,
                      _formatNullable(athlete.squatJumpCm),
                      _formatNullable(athlete.cmjCm),
                      _formatNullable(athlete.dropJumpCm),
                      _formatNullable(athlete.rsi),
                      _formatNullable(athlete.singleLegLeftCm),
                      _formatNullable(athlete.singleLegRightCm),
                      _formatNullablePercentValue(athlete.asymmetryPercent),
                      _formatDelta(athlete.deltas['cmj']),
                      _formatDelta(athlete.deltas['rsi']),
                    ])
                .toList(),
            headerFontSize: 7,
            cellFontSize: 7,
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('Alert test'),
          ..._alertTexts(report, const {'jump_asymmetry'}),
        ],
      ),
    );

    if (includeIndividualSheets) {
      for (final athlete in report.athletes) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            theme: theme,
            margin: const pw.EdgeInsets.all(28),
            footer: (context) => _footer(context, generatedLabel),
            build: (context) => [
              _sectionHeader('Scheda atleta', report, monthLabel),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(child: _title(athlete.athleteName, fontSize: 18)),
                  _muted(_formatVsAverage(athlete)),
                ],
              ),
              pw.SizedBox(height: 10),
              _compactKpiRow([
                _PdfKpi('Ore totali', _formatNumber(athlete.totalHours)),
                _PdfKpi('Sedute', '${athlete.sessionCount}'),
                _PdfKpi('Presenza sci', _formatPercent(athlete.skiPresence)),
                _PdfKpi(
                  'Presenza prep.',
                  _formatPercent(athlete.athleticPresence),
                ),
                _PdfKpi('Volume sci', '${athlete.totalDirectionChanges}'),
                _PdfKpi(
                  'Ore prep.',
                  _formatNumber(athlete.totalAthleticHours),
                ),
              ]),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: _stackedTrendChart(athlete.trend),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    flex: 2,
                    child: _athleteComparisonTable(athlete),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _horizontalBarChart(
                      title: 'Dettaglio sci del mese',
                      values: _athleteSkiValues(athlete),
                      color: PdfColors.blue600,
                      height: 108,
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: _horizontalBarChart(
                      title: 'Tipi di preparazione del mese',
                      values: _labeledPreparationValues(
                        athlete.preparationHoursByType,
                      ),
                      color: PdfColors.orange600,
                      height: 108,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  '${athlete.trendSummary}${athlete.alerts.isEmpty ? '' : ' Da monitorare: ${athlete.alerts.map((alert) => alert.label).join(', ')}.'}',
                  style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
                ),
              ),
            ],
          ),
        );
      }
    }

    return doc.save();
  }

  Future<void> printReport(
    MonthlyTeamReport report, {
    bool includeIndividualSheets = true,
  }) async {
    final bytes = await buildPdf(
      report,
      includeIndividualSheets: includeIndividualSheets,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareReport(
    MonthlyTeamReport report, {
    bool includeIndividualSheets = true,
  }) async {
    final bytes = await buildPdf(
      report,
      includeIndividualSheets: includeIndividualSheets,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'report_mensile_team_${report.month}.pdf',
    );
  }

  pw.Widget _sectionHeader(
    String title,
    MonthlyTeamReport report,
    String monthLabel,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _title(title, fontSize: 18),
        pw.SizedBox(height: 2),
        _muted('${report.team.name} - $monthLabel'),
        pw.SizedBox(height: 14),
      ],
    );
  }

  pw.Widget _title(String text, {double fontSize = 22}) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey900,
      ),
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey900,
      ),
    );
  }

  pw.Widget _muted(String text) {
    return pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
    );
  }

  pw.Widget _footer(pw.Context context, String generatedLabel) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generato il $generatedLabel',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          'Pagina ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _kpiGrid(List<_PdfKpi> items) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => pw.Container(
              width: 120,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.label,
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    item.value,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _compactKpiRow(List<_PdfKpi> items) {
    return pw.Row(
      children: items
          .map(
            (item) => pw.Expanded(
              child: pw.Container(
                margin: const pw.EdgeInsets.only(right: 6),
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.label,
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      item.value,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _horizontalBarChart({
    required String title,
    required Map<String, double> values,
    required PdfColor color,
    double height = 150,
  }) {
    final entries = values.entries.where((entry) => entry.value > 0).toList();
    final maxValue = entries.isEmpty
        ? 0.0
        : entries.map((entry) => entry.value).reduce((a, b) => a > b ? a : b);
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (entries.isEmpty)
            pw.Expanded(
              child: pw.Center(
                child: pw.Text(
                  'Nessun dato disponibile',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            )
          else
            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: entries.map((entry) {
                  final filled = maxValue <= 0
                      ? 0
                      : ((entry.value / maxValue) * 100)
                          .round()
                          .clamp(1, 100)
                          .toInt();
                  return pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 72,
                        child: pw.Text(
                          entry.key,
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Container(
                          height: 7,
                          color: PdfColors.grey200,
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: filled,
                                child: pw.Container(color: color),
                              ),
                              if (filled < 100)
                                pw.Expanded(
                                  flex: 100 - filled,
                                  child: pw.SizedBox(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.SizedBox(
                        width: 30,
                        child: pw.Text(
                          _formatNumber(entry.value),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _stackedTrendChart(List<MonthlyAthleteTrendPoint> trend) {
    const chartHeight = 112.0;
    final maxValue = trend.isEmpty
        ? 0.0
        : trend.map((point) => point.totalHours).fold<double>(
              0,
              (max, value) => value > max ? value : max,
            );
    const colors = {
      MonthlyTrainingMacro.ski: PdfColors.blue600,
      MonthlyTrainingMacro.preparation: PdfColors.orange600,
      MonthlyTrainingMacro.otherSports: PdfColors.green600,
      MonthlyTrainingMacro.recoveryOther: PdfColors.grey500,
    };
    return pw.Container(
      height: 180,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Andamento e composizione - 7 mesi',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              ...MonthlyTrainingMacro.ordered.map(
                (macro) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 7),
                  child: pw.Row(
                    children: [
                      pw.Container(width: 6, height: 6, color: colors[macro]),
                      pw.SizedBox(width: 2),
                      pw.Text(
                        _shortMacroLabel(macro),
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Expanded(
            child: maxValue <= 0
                ? pw.Center(
                    child: pw.Text(
                      'Nessuna attività nello storico',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  )
                : pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: trend.map((point) {
                      final totalHeight =
                          chartHeight * (point.totalHours / maxValue);
                      return pw.Expanded(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            pw.Text(
                              _formatNumber(point.totalHours),
                              style: const pw.TextStyle(fontSize: 6),
                            ),
                            pw.SizedBox(height: 2),
                            pw.SizedBox(
                              height: chartHeight,
                              width: 24,
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.end,
                                children:
                                    MonthlyTrainingMacro.ordered.map((macro) {
                                  final hours = point.hoursFor(macro);
                                  final segmentHeight = point.totalHours <= 0
                                      ? 0.0
                                      : totalHeight *
                                          (hours / point.totalHours);
                                  return segmentHeight <= 0
                                      ? pw.SizedBox()
                                      : pw.Container(
                                          height: segmentHeight,
                                          color: colors[macro],
                                        );
                                }).toList(),
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              _shortMonth(point.month),
                              style: pw.TextStyle(
                                fontSize: 6,
                                fontWeight: point == trend.last
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  pw.Widget _athleteComparisonTable(MonthlyTeamAthleteReport athlete) {
    final current = athlete.trend.isEmpty ? null : athlete.trend.last;
    final previous = athlete.previousTrend;
    final history =
        athlete.previousSixTrend.where((point) => point.hasActivity).toList();
    double? average(double Function(MonthlyAthleteTrendPoint point) value) {
      if (history.isEmpty) return null;
      return history.fold<double>(0, (sum, point) => sum + value(point)) /
          history.length;
    }

    String value(double? item) => item == null ? 'N/D' : _formatNumber(item);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Confronto'),
        pw.SizedBox(height: 5),
        _table(
          headers: const ['Metrica', 'Mese', 'Prec.', 'Media 6m'],
          rows: [
            [
              'Ore totali',
              value(current?.totalHours),
              value(previous?.totalHours),
              value(average((point) => point.totalHours)),
            ],
            [
              'Sedute',
              value(current?.sessionCount.toDouble()),
              value(previous?.sessionCount.toDouble()),
              value(average((point) => point.sessionCount.toDouble())),
            ],
            [
              'Ore sci',
              value(current?.hoursFor(MonthlyTrainingMacro.ski)),
              value(previous?.hoursFor(MonthlyTrainingMacro.ski)),
              value(average(
                (point) => point.hoursFor(MonthlyTrainingMacro.ski),
              )),
            ],
            [
              'Ore prep.',
              value(current?.hoursFor(MonthlyTrainingMacro.preparation)),
              value(previous?.hoursFor(MonthlyTrainingMacro.preparation)),
              value(average(
                (point) => point.hoursFor(MonthlyTrainingMacro.preparation),
              )),
            ],
            [
              'Altri/rec.',
              value(current == null
                  ? null
                  : current.hoursFor(MonthlyTrainingMacro.otherSports) +
                      current.hoursFor(MonthlyTrainingMacro.recoveryOther)),
              value(previous == null
                  ? null
                  : previous.hoursFor(MonthlyTrainingMacro.otherSports) +
                      previous.hoursFor(MonthlyTrainingMacro.recoveryOther)),
              value(average(
                (point) =>
                    point.hoursFor(MonthlyTrainingMacro.otherSports) +
                    point.hoursFor(MonthlyTrainingMacro.recoveryOther),
              )),
            ],
            [
              'Volume sci',
              value(current?.skiDirectionChanges.toDouble()),
              value(previous?.skiDirectionChanges.toDouble()),
              value(average(
                (point) => point.skiDirectionChanges.toDouble(),
              )),
            ],
          ],
          headerFontSize: 7,
          cellFontSize: 7,
        ),
      ],
    );
  }

  Map<String, double> _athleteSkiValues(
    MonthlyTeamAthleteReport athlete,
  ) =>
      {
        'CL': athlete.clDirectionChanges.toDouble(),
        'SL': athlete.slDirectionChanges.toDouble(),
        'GS': athlete.gsDirectionChanges.toDouble(),
        'SG': athlete.sgDirectionChanges.toDouble(),
        'DH': athlete.dhDirectionChanges.toDouble(),
        'SX': athlete.sxDirectionChanges.toDouble(),
        'ADD': athlete.addestramentoDirectionChanges.toDouble(),
      };

  Map<String, double> _labeledPreparationValues(Map<String, double> values) {
    final result = <String, double>{};
    for (final entry in values.entries) {
      final label = _preparationLabel(entry.key);
      result[label] = (result[label] ?? 0) + entry.value;
    }
    return result;
  }

  String _preparationLabel(String id) {
    switch (id) {
      case 'strength':
        return 'Forza';
      case 'plyometrics':
        return 'Pliometria';
      case 'speed_agility':
        return 'Velocità/agilità';
      case 'endurance':
        return 'Resistenza';
      case 'mobility':
      case 'mobility_core':
      case 'core':
        return 'Mobilità/core';
      case 'circuit':
      case 'mixed_circuit':
        return 'Circuito/HIIT';
      case 'test':
        return 'Test';
      default:
        return 'Preparazione mista';
    }
  }

  String _shortMacroLabel(String macro) {
    switch (macro) {
      case MonthlyTrainingMacro.ski:
        return 'Sci';
      case MonthlyTrainingMacro.preparation:
        return 'Prep.';
      case MonthlyTrainingMacro.otherSports:
        return 'Sport';
      default:
        return 'Rec.';
    }
  }

  String _shortMonth(String month) {
    final value = DateTime.tryParse('$month-01');
    return value == null ? month : DateFormat('MMM', 'it').format(value);
  }

  String _formatVsAverage(MonthlyTeamAthleteReport athlete) {
    final average = athlete.previousSixAverageHours;
    if (average == null || average <= 0) return 'Media 6m N/D';
    final delta = ((athlete.totalHours - average) / average) * 100;
    final prefix = delta > 0 ? '+' : '';
    return '$prefix${delta.round()}% vs media 6m';
  }

  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    double headerFontSize = 8,
    double cellFontSize = 8,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map(
                (header) => _cell(
                  header,
                  fontSize: headerFontSize,
                  isHeader: true,
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: row
                .map((value) => _cell(value, fontSize: cellFontSize))
                .toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _cell(
    String value, {
    required double fontSize,
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        value.isEmpty ? '-' : value,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.grey900,
        ),
      ),
    );
  }

  List<pw.Widget> _alertTexts(
    MonthlyTeamReport report,
    Set<String> types,
  ) {
    final alerts = report.alerts.where((alert) => types.contains(alert.type));
    if (alerts.isEmpty) {
      return [
        pw.Text('Nessun alert in questa sezione.',
            style: const pw.TextStyle(fontSize: 10)),
      ];
    }
    return alerts
        .map((alert) => _bullet('${alert.athleteName}: ${alert.label}'))
        .toList();
  }

  pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('- ', style: const pw.TextStyle(fontSize: 10)),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  String _monthLabel(String monthKey) {
    final parts = monthKey.split('-');
    final date = DateTime(
      int.tryParse(parts.first) ?? 2000,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1,
    );
    return DateFormat('MMMM yyyy', 'it').format(date);
  }

  String _formatPercent(double? value) {
    if (value == null) return 'N/D';
    return '${(value * 100).round()}%';
  }

  String _formatNullable(double? value) {
    if (value == null || value == 0) return 'N/D';
    return _formatNumber(value);
  }

  String _formatNullablePercentValue(double? value) {
    if (value == null || value == 0) return 'N/D';
    return '${_formatNumber(value)}%';
  }

  String _formatDelta(MonthlyMetricDelta? delta) {
    if (delta == null || !delta.hasPrevious) return 'N/D';
    final value = delta.absoluteDelta ?? 0;
    final sign = value > 0 ? '+' : '';
    return '$sign${_formatNumber(value)}';
  }

  String _formatNumber(double value) {
    if (value.abs() >= 100) return value.toStringAsFixed(0);
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

class _PdfKpi {
  final String label;
  final String value;

  const _PdfKpi(this.label, this.value);
}
