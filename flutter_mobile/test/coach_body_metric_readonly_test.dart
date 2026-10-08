import 'package:flutter/material.dart';
import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/screens/coach_body_metric_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('coach health detail has no editing controls in ${brightness.name}', (tester) async {
      AppTheme.setThemeMode(brightness == Brightness.dark ? 'dark' : 'light');
      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: CoachBodyMetricDetailScreen(title: 'Peso', type: 'weight', athleteName: 'Atleta di prova',
          logs: [BodyMetricLog(id:'log',date:DateTime.now().toIso8601String().substring(0,10),type:'weight',value:70)]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sola lettura'),findsOneWidget);
      expect(find.byIcon(Icons.add),findsNothing);
      expect(find.byIcon(Icons.delete),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }
}
