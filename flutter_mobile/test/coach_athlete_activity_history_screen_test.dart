import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mobile/core/theme.dart';
import 'package:flutter_mobile/models/models.dart';
import 'package:flutter_mobile/screens/coach_athlete_activity_history_screen.dart';

void main() {
  TrainingSession session(int index) => TrainingSession(
        id: 'session-$index',
        sportId: index.isEven ? 'running' : 'alpine_skiing',
        date: '2026-07-${(15 - index).toString().padLeft(2, '0')}',
        startTime: '10:00',
        endTime: '11:00',
        duration: '60',
        effort: 6,
      );

  testWidgets('mostra e rende raggiungibili tutti gli allenamenti',
      (tester) async {
    AppTheme.setThemeMode(AppTheme.lightMode);
    final sessions = List.generate(8, session);

    await tester.pumpWidget(
      MaterialApp(
        home: CoachAthleteActivityHistoryScreen(
          athleteName: 'Mario Rossi',
          sessions: sessions,
        ),
      ),
    );

    expect(find.text('Storico attività'), findsOneWidget);
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('8 allenamenti svolti'), findsOneWidget);

    final lastSession = find.byKey(
      const ValueKey('coach-activity-session-7'),
    );
    await tester.scrollUntilVisible(
      lastSession,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(lastSession, findsOneWidget);
  });

  testWidgets('usa i colori del tema chiaro e scuro', (tester) async {
    AppTheme.setThemeMode(AppTheme.darkMode);
    await tester.pumpWidget(
      MaterialApp(
        home: CoachAthleteActivityHistoryScreen(
          athleteName: 'Mario Rossi',
          sessions: [session(0)],
        ),
      ),
    );

    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppTheme.background);

    AppTheme.setThemeMode(AppTheme.lightMode);
    await tester.pumpWidget(
      MaterialApp(
        home: CoachAthleteActivityHistoryScreen(
          athleteName: 'Mario Rossi',
          sessions: [session(0)],
        ),
      ),
    );

    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppTheme.background);
  });
}
