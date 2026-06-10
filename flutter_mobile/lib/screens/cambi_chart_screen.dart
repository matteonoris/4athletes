import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';

class CambiChartScreen extends StatelessWidget {
  final String athleteName;
  final Map<String, Map<String, int>> cambiByMonthAndSpecialty;

  const CambiChartScreen({
    super.key,
    required this.athleteName,
    required this.cambiByMonthAndSpecialty,
  });

  // Colori per le diverse specialità
  Color _getColorForSpecialty(String specialty) {
    if (specialty == 'SL') return AppTheme.secondary;
    if (specialty == 'GS') return Colors.lightBlue;
    if (specialty == 'SG') return Colors.greenAccent;
    if (specialty == 'DH') return Colors.purpleAccent;
    if (specialty == 'SX') return Colors.redAccent;
    if (specialty == 'CL') return Colors.orangeAccent;
    if (specialty == 'ADD') return Colors.amberAccent;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    // Ordiniamo i mesi in ordine cronologico
    final sortedMonths = cambiByMonthAndSpecialty.keys.toList()..sort();

    // Trova tutte le specialità uniche
    final Set<String> allSpecialties = {};
    for (var m in cambiByMonthAndSpecialty.values) {
      allSpecialties.addAll(m.keys);
    }

    // Calcoliamo il massimo per asse Y
    double maxY = 0;
    for (var m in cambiByMonthAndSpecialty.values) {
      double sum = 0;
      for (var v in m.values) {
        sum += v;
      }
      if (sum > maxY) maxY = sum;
    }

    // Aggiungi un po' di margine al top
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY < 10) maxY = 10;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text('Cambi di Direzione - $athleteName',
            style: const TextStyle(fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Volume sci mensile',
              style: TextStyle(
                color: AppTheme.textHighEmphasis,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cambi totali divisi tra campo libero, pali e addestramento',
              style: TextStyle(
                color: AppTheme.textMediumEmphasis,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Grafico
            Expanded(
              child: sortedMonths.isEmpty
                  ? Center(
                      child: Text('Nessun dato disponibile',
                          style: TextStyle(color: AppTheme.textMediumEmphasis)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => AppTheme.card,
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final month = sortedMonths[groupIndex];
                              final data = cambiByMonthAndSpecialty[month]!;

                              // Create tooltip items per specialty
                              List<TextSpan> spans = [];
                              int i = 0;
                              final tooltipSpecs = data.keys.toList()
                                ..sort((a, b) =>
                                    _sortIndex(a).compareTo(_sortIndex(b)));
                              for (var spec in tooltipSpecs) {
                                if (data[spec]! > 0) {
                                  if (i > 0) {
                                    spans.add(const TextSpan(text: '\n'));
                                  }
                                  spans.add(
                                    TextSpan(
                                      text: '$spec: ${data[spec]}',
                                      style: TextStyle(
                                        color: _getColorForSpecialty(spec),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                  i++;
                                }
                              }
                              return BarTooltipItem(
                                '${_formatMonth(month)}\n',
                                TextStyle(
                                  color: AppTheme.textHighEmphasis,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                children: spans,
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < sortedMonths.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _formatMonthShort(sortedMonths[index]),
                                      style: TextStyle(
                                        color: AppTheme.textMediumEmphasis,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value == maxY) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: AppTheme.textMediumEmphasis,
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.white.withValues(alpha: 0.05),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(sortedMonths.length, (index) {
                          final month = sortedMonths[index];
                          final data = cambiByMonthAndSpecialty[month]!;

                          // Crea la lista di rod impilati (stacked)
                          List<BarChartRodStackItem> stackItems = [];
                          double currentY = 0;

                          // Ordiniamo le specialità per consistenza visiva (SL, GS, ecc.)
                          final sortedSpecs = data.keys.toList()
                            ..sort((a, b) =>
                                _sortIndex(a).compareTo(_sortIndex(b)));

                          for (var spec in sortedSpecs) {
                            final val = data[spec]!.toDouble();
                            if (val > 0) {
                              stackItems.add(BarChartRodStackItem(
                                currentY,
                                currentY + val,
                                _getColorForSpecialty(spec),
                              ));
                              currentY += val;
                            }
                          }

                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: currentY,
                                width: 24,
                                borderRadius: BorderRadius.circular(4),
                                rodStackItems: stackItems,
                                color: Colors
                                    .transparent, // Lo sfondo è trasparente, usiamo gli stack
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),

            const SizedBox(height: 32),

            // Legenda
            if (allSpecialties.isNotEmpty)
              Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: (allSpecialties.toList()
                      ..sort((a, b) => _sortIndex(a).compareTo(_sortIndex(b))))
                    .map((spec) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getColorForSpecialty(spec),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        spec,
                        style: TextStyle(
                          color: AppTheme.textMediumEmphasis,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatMonth(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM yyyy', 'it_IT').format(date);
    } catch (_) {
      return yyyyMM;
    }
  }

  String _formatMonthShort(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMM yyyy', 'it_IT').format(date);
    } catch (_) {
      return yyyyMM;
    }
  }

  int _sortIndex(String specialty) {
    const order = ['CL', 'SL', 'GS', 'SG', 'DH', 'SX', 'ADD'];
    final index = order.indexOf(specialty);
    return index == -1 ? order.length : index;
  }
}
