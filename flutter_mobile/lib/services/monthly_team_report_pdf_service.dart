import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/monthly_team_report_models.dart';

class MonthlyTeamReportPdfService {
  const MonthlyTeamReportPdfService();

  Future<Uint8List> buildPdf(
    MonthlyTeamReport report, {
    bool includeIndividualSheets = false,
  }) async {
    final doc = pw.Document();
    final monthLabel = _monthLabel(report.month);
    final generatedLabel =
        DateFormat('dd/MM/yyyy HH:mm', 'it').format(report.generatedAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _title('Report mensile team'),
          pw.SizedBox(height: 4),
          _muted('${report.team.name} - $monthLabel'),
          pw.SizedBox(height: 18),
          _sectionTitle('Executive summary'),
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
              'Presenza atletica',
              _formatPercent(report.summary.averageAthleticPresence),
            ),
            _PdfKpi('Ore sci', _formatNumber(report.summary.totalSkiHours)),
            _PdfKpi(
              'Ore atletica',
              _formatNumber(report.summary.totalAthleticHours),
            ),
            _PdfKpi(
              'Cambi direzione',
              '${report.summary.totalDirectionChanges}',
            ),
            _PdfKpi(
              'Volume kg',
              _formatNumber(report.summary.totalStrengthVolumeKg),
            ),
          ]),
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
        margin: const pw.EdgeInsets.all(22),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _sectionHeader('Tabella comparativa atleti', report, monthLabel),
          _table(
            headers: const [
              'Atleta',
              'Pres. sci',
              'Pres. atl.',
              'Sci prog.',
              'Sci fuori',
              'Atl. prog.',
              'Atl. fuori',
              'Cambi',
              'Vol. kg',
              'Alert',
            ],
            rows: report.athletes.map((athlete) {
              return [
                athlete.athleteName,
                _formatPercent(athlete.skiPresence),
                _formatPercent(athlete.athleticPresence),
                _formatNumber(athlete.scheduledSkiHours),
                _formatNumber(athlete.outOfProgramSkiHours),
                _formatNumber(athlete.scheduledAthleticHours),
                _formatNumber(athlete.outOfProgramAthleticHours),
                '${athlete.totalDirectionChanges}',
                _formatNumber(athlete.strengthVolumeKg),
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
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _sectionHeader('Sci alpino', report, monthLabel),
          _kpiGrid([
            _PdfKpi('Cambi CL', '${report.ski.clDirectionChanges}'),
            _PdfKpi('Cambi SL', '${report.ski.slDirectionChanges}'),
            _PdfKpi('Cambi GS', '${report.ski.gsDirectionChanges}'),
            _PdfKpi(
                'Addestramento', '${report.ski.addestramentoDirectionChanges}'),
          ]),
          pw.SizedBox(height: 14),
          _table(
            headers: const ['Atleta', 'CL', 'SL', 'GS', 'ADD', 'Totale'],
            rows: report.athletes
                .map((athlete) => [
                      athlete.athleteName,
                      '${athlete.clDirectionChanges}',
                      '${athlete.slDirectionChanges}',
                      '${athlete.gsDirectionChanges}',
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
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => _footer(context, generatedLabel),
        build: (context) => [
          _sectionHeader('Preparazione atletica', report, monthLabel),
          _table(
            headers: const [
              'Atleta',
              'Ore atletica',
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
          _sectionTitle('Alert atletica'),
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
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(28),
            footer: (context) => _footer(context, generatedLabel),
            build: (context) => [
              _sectionHeader('Scheda atleta', report, monthLabel),
              _title(athlete.athleteName, fontSize: 18),
              pw.SizedBox(height: 12),
              _kpiGrid([
                _PdfKpi('Presenza sci', _formatPercent(athlete.skiPresence)),
                _PdfKpi('Presenza atletica',
                    _formatPercent(athlete.athleticPresence)),
                _PdfKpi('Ore sci', _formatNumber(athlete.totalSkiHours)),
                _PdfKpi(
                  'Cambi direzione',
                  '${athlete.totalDirectionChanges}',
                ),
                _PdfKpi(
                  'Ore atletica',
                  _formatNumber(athlete.totalAthleticHours),
                ),
                _PdfKpi('Volume kg', _formatNumber(athlete.strengthVolumeKg)),
              ]),
              pw.SizedBox(height: 16),
              _sectionTitle('Profilo salto'),
              pw.Text(
                'SJ ${_formatNullable(athlete.squatJumpCm)} | CMJ ${_formatNullable(athlete.cmjCm)} | DJ ${_formatNullable(athlete.dropJumpCm)} | RSI ${_formatNullable(athlete.rsi)} | SL sx ${_formatNullable(athlete.singleLegLeftCm)} | SL dx ${_formatNullable(athlete.singleLegRightCm)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 14),
              _sectionTitle('Alert'),
              if (athlete.alerts.isEmpty)
                pw.Text('Nessun alert automatico.',
                    style: const pw.TextStyle(fontSize: 10))
              else
                ...athlete.alerts.map((alert) => _bullet(alert.label)),
              pw.SizedBox(height: 14),
              _sectionTitle('Nota automatica'),
              pw.Text(
                athlete.hasAnyData
                    ? 'Scheda generata dai dati registrati nel mese selezionato.'
                    : 'Dati mancanti per il mese selezionato.',
                style: const pw.TextStyle(fontSize: 10),
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
    bool includeIndividualSheets = false,
  }) async {
    final bytes = await buildPdf(
      report,
      includeIndividualSheets: includeIndividualSheets,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareReport(
    MonthlyTeamReport report, {
    bool includeIndividualSheets = false,
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
