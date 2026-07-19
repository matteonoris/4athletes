import '../models/models.dart';
import '../models/monthly_team_report_models.dart';
import '../models/training_activity_models.dart';
import '../utils/coach_training_utils.dart';
import '../utils/time_utils.dart';
import '../utils/training_metrics_utils.dart';
import 'training_activity_service.dart';
import 'monthly_training_classifier.dart';

class MonthlyTeamReportAlertThresholds {
  final double lowPresenceRatio;
  final double lowVolumeAverageRatio;
  final double highVolumeAverageRatio;
  final double disciplineDominanceRatio;
  final double jumpAsymmetryPercent;

  const MonthlyTeamReportAlertThresholds({
    this.lowPresenceRatio = 0.50,
    this.lowVolumeAverageRatio = 0.50,
    this.highVolumeAverageRatio = 1.50,
    this.disciplineDominanceRatio = 0.80,
    this.jumpAsymmetryPercent = 10,
  });
}

class MonthlyTeamReportCalculator {
  static const partialAttendanceStatus = 'partial';

  final MonthlyTeamReportAlertThresholds thresholds;

  const MonthlyTeamReportCalculator({
    this.thresholds = const MonthlyTeamReportAlertThresholds(),
  });

  MonthlyTeamReport build({
    required Team team,
    required DateTime month,
    required List<TeamReportAthleteProfile> athletes,
    required List<TeamReportSession> sessions,
    required List<CalendarEvent> events,
    List<TeamReportMetricLog> jumpLogs = const [],
    List<TeamReportMetricLog> bodyMetricLogs = const [],
    List<TeamReportPrLog> prLogs = const [],
    DateTime? generatedAt,
  }) {
    final currentMonth = DateTime(month.year, month.month);
    final reportNow = generatedAt ?? DateTime.now();
    final isCurrentMonth = currentMonth.year == reportNow.year &&
        currentMonth.month == reportNow.month;
    final throughDay = isCurrentMonth ? reportNow.day : null;
    final historyMonths = List<DateTime>.generate(
      7,
      (index) => DateTime(
        currentMonth.year,
        currentMonth.month - (6 - index),
      ),
    );
    final eventsByMonth = <String, List<CalendarEvent>>{
      for (final historyMonth in historyMonths)
        _monthKey(historyMonth): _eventsForMonth(
          events,
          team.id,
          historyMonth,
          throughDay: throughDay,
        ),
    };
    final currentEvents = eventsByMonth[_monthKey(currentMonth)] ?? const [];

    final athleteReports = <MonthlyTeamAthleteReport>[];

    for (final athlete in athletes) {
      final monthlyMetrics = historyMonths.map((historyMonth) {
        final monthEvents =
            eventsByMonth[_monthKey(historyMonth)] ?? const <CalendarEvent>[];
        return _metricsForAthleteMonth(
          athlete: athlete,
          month: historyMonth,
          throughDay: throughDay,
          sessions: sessions,
          eventIds: monthEvents.map((event) => event.id).toSet(),
          events: monthEvents,
          jumpLogs: jumpLogs,
          bodyMetricLogs: bodyMetricLogs,
          prLogs: prLogs,
        );
      }).toList();
      final currentMetrics = monthlyMetrics.last;
      final previousMetrics = monthlyMetrics[monthlyMetrics.length - 2];
      final trend = <MonthlyAthleteTrendPoint>[
        for (var index = 0; index < historyMonths.length; index++)
          _trendPoint(
            historyMonths[index],
            throughDay,
            monthlyMetrics[index],
          ),
      ];

      athleteReports.add(
        MonthlyTeamAthleteReport(
          athleteId: athlete.id,
          athleteName: athlete.name,
          initial: athlete.initial,
          avatarUrl: athlete.avatarUrl,
          skillLevel: athlete.skillLevel,
          hasAnyData: currentMetrics.hasAnyData,
          skiPresence: currentMetrics.skiPresence,
          athleticPresence: currentMetrics.athleticPresence,
          scheduledSkiHours: currentMetrics.scheduledSkiMinutes / 60,
          outOfProgramSkiHours: currentMetrics.outOfProgramSkiMinutes / 60,
          scheduledAthleticHours: currentMetrics.scheduledAthleticMinutes / 60,
          outOfProgramAthleticHours:
              currentMetrics.outOfProgramAthleticMinutes / 60,
          externalCoachHours: currentMetrics.externalCoachMinutes / 60,
          individualHours: currentMetrics.individualMinutes / 60,
          unclassifiedHours: currentMetrics.unclassifiedMinutes / 60,
          totalDirectionChanges: currentMetrics.totalDirectionChanges,
          clDirectionChanges: currentMetrics.clDirectionChanges,
          slDirectionChanges: currentMetrics.slDirectionChanges,
          gsDirectionChanges: currentMetrics.gsDirectionChanges,
          sgDirectionChanges: currentMetrics.sgDirectionChanges,
          dhDirectionChanges: currentMetrics.dhDirectionChanges,
          sxDirectionChanges: currentMetrics.sxDirectionChanges,
          addestramentoDirectionChanges:
              currentMetrics.addestramentoDirectionChanges,
          strengthVolumeKg: currentMetrics.strengthVolumeKg,
          strengthSets: currentMetrics.strengthSets,
          drillCount: currentMetrics.drillCount,
          enduranceMeters: currentMetrics.enduranceMeters,
          squatJumpCm: currentMetrics.squatJumpCm,
          cmjCm: currentMetrics.cmjCm,
          dropJumpCm: currentMetrics.dropJumpCm,
          rsi: currentMetrics.rsi,
          singleLegLeftCm: currentMetrics.singleLegLeftCm,
          singleLegRightCm: currentMetrics.singleLegRightCm,
          asymmetryPercent: currentMetrics.asymmetryPercent,
          testSessionCount: currentMetrics.testSessionCount,
          incompleteDataCount: currentMetrics.incompleteDataCount,
          alerts: const [],
          deltas: _buildDeltas(currentMetrics, previousMetrics),
          sessionCount: currentMetrics.sessionCount,
          hoursByMacro: currentMetrics.hoursByMacroHours,
          preparationHoursByType: currentMetrics.preparationHoursByTypeHours,
          trend: trend,
          trendSummary: _athleteTrendSummary(trend),
        ),
      );
    }

    final reportsWithAlerts = _withAlerts(athleteReports);
    final alerts =
        reportsWithAlerts.expand((athlete) => athlete.alerts).toList();
    final summary = _buildSummary(reportsWithAlerts);
    final ski = _buildSkiReport(reportsWithAlerts);
    final athletic = _buildAthleticReport(reportsWithAlerts);
    final tests = _buildTestsReport(reportsWithAlerts);
    final coachWorkload = _buildCoachWorkload(currentEvents);

    return MonthlyTeamReport(
      team: team,
      month: _monthKey(currentMonth),
      generatedAt: reportNow,
      summary: summary,
      coachWorkload: coachWorkload,
      athletes: reportsWithAlerts,
      ski: ski,
      athletic: athletic,
      tests: tests,
      alerts: alerts,
      automaticSummary: _automaticSummary(
        summary,
        coachWorkload,
        ski,
        reportsWithAlerts,
      ),
    );
  }

  List<CalendarEvent> _eventsForMonth(
    List<CalendarEvent> events,
    String teamId,
    DateTime month, {
    int? throughDay,
  }) {
    return events.where((event) {
      if (event.status != CoachTrainingUtils.statusCompleted) return false;
      final date = DateTime.tryParse(event.date);
      if (date == null || !_isInMonth(date, month)) return false;
      if (throughDay != null && date.day > throughDay) return false;
      return CoachTrainingUtils.teamIdsForEvent(event).contains(teamId);
    }).toList();
  }

  _AthleteMonthMetrics _metricsForAthleteMonth({
    required TeamReportAthleteProfile athlete,
    required DateTime month,
    required int? throughDay,
    required List<TeamReportSession> sessions,
    required Set<String> eventIds,
    required List<CalendarEvent> events,
    required List<TeamReportMetricLog> jumpLogs,
    required List<TeamReportMetricLog> bodyMetricLogs,
    required List<TeamReportPrLog> prLogs,
  }) {
    final metrics = _AthleteMonthMetrics();
    final athleteSessions = _canonicalSessions(
      sessions.where((item) {
        if (item.athleteId != athlete.id ||
            !_isCompletedSession(item.session)) {
          return false;
        }
        final date = DateTime.tryParse(item.session.date);
        return date != null &&
            _isInMonth(date, month) &&
            (throughDay == null || date.day <= throughDay);
      }),
    );

    final sessionEventIds = athleteSessions
        .map((item) => item.session.eventId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final skiEvents = events
        .where((event) => event.sportCategory == 'ski')
        .toList(growable: false);
    final athleticEvents = events
        .where(
          (event) => _macroForEvent(event) == MonthlyTrainingMacro.preparation,
        )
        .toList(growable: false);

    metrics.skiPresence = _presenceRatio(
      athlete: athlete,
      events: skiEvents,
      linkedSessionEventIds: sessionEventIds,
    );
    metrics.athleticPresence = _presenceRatio(
      athlete: athlete,
      events: athleticEvents,
      linkedSessionEventIds: sessionEventIds,
    );
    if ((metrics.skiPresence ?? 0) > 0 || (metrics.athleticPresence ?? 0) > 0) {
      metrics.hasAnyData = true;
    }

    for (final item in athleteSessions) {
      metrics.hasAnyData = true;
      metrics.sessionCount++;
      final session = item.session;
      final classification =
          const MonthlyTrainingClassifier().classify(session);
      final isSki = classification.macroId == MonthlyTrainingMacro.ski;
      final durationMinutes =
          TimeUtils.parseDurationToMinutes(session.duration);
      final isProgrammed =
          session.eventId != null && eventIds.contains(session.eventId);

      if (durationMinutes <= 0) {
        metrics.incompleteDataCount++;
      }
      metrics.addMacroMinutes(classification.macroId, durationMinutes);

      if (isSki) {
        if (isProgrammed) {
          metrics.scheduledSkiMinutes += durationMinutes;
        } else {
          metrics.outOfProgramSkiMinutes += durationMinutes;
        }
        _addSkiVolume(metrics, session);
      } else if (classification.macroId == MonthlyTrainingMacro.preparation) {
        metrics.hasPreparationData = true;
        if (isProgrammed) {
          metrics.scheduledAthleticMinutes += durationMinutes;
        } else {
          metrics.outOfProgramAthleticMinutes += durationMinutes;
        }
        _addAthleticVolume(metrics, session);
        metrics.addPreparationMinutes(
          classification.detailId,
          durationMinutes,
        );
      }

      if (!isProgrammed) {
        switch (_activityClassification(session)) {
          case _ActivityClassification.externalCoach:
            metrics.externalCoachMinutes += durationMinutes;
          case _ActivityClassification.individual:
            metrics.individualMinutes += durationMinutes;
          case _ActivityClassification.unclassified:
            metrics.unclassifiedMinutes += durationMinutes;
          case _ActivityClassification.programmed:
            break;
        }
      }
    }

    _addCompletedEventFallbacks(
      metrics: metrics,
      athlete: athlete,
      events: events,
      linkedSessionEventIds: sessionEventIds,
    );

    _addLatestJumpMetrics(metrics, athlete.id, month, jumpLogs);
    metrics.testSessionCount += _testMeasurementCount(
      athlete.id,
      month,
      jumpLogs,
      bodyMetricLogs,
      prLogs,
    );

    if (metrics.testSessionCount > 0) {
      metrics.hasAnyData = true;
    }

    return metrics;
  }

  double? _presenceRatio({
    required TeamReportAthleteProfile athlete,
    required List<CalendarEvent> events,
    required Set<String> linkedSessionEventIds,
  }) {
    if (events.isEmpty) return null;

    var score = 0.0;
    var invitedEventCount = 0;
    for (final event in events) {
      final attendee = _attendeeForAthlete(event, athlete);
      if (attendee == null) {
        if (linkedSessionEventIds.contains(event.id)) {
          invitedEventCount++;
          score += 1;
        }
        continue;
      }
      invitedEventCount++;
      score += _attendanceScore(attendee);
    }
    return invitedEventCount == 0 ? null : score / invitedEventCount;
  }

  List<TeamReportSession> _canonicalSessions(
    Iterable<TeamReportSession> candidates,
  ) {
    final source = candidates.toList(growable: false);
    final mergedExternalIds = <String>{};
    final mergedSessionIds = <String>{};

    for (final item in source) {
      final session = item.session;
      final details = session.details ?? const <String, dynamic>{};
      if (details['workoutSource']?.toString() != 'merged') continue;
      final sourceIds = details['merged_source_workout_ids'];
      if (sourceIds is List) {
        mergedExternalIds.addAll(sourceIds.map((id) => id.toString()));
      }
      final externalLink = details['externalLink'];
      if (externalLink is Map) {
        final sourceSessionId = externalLink['sourceSessionId']?.toString();
        if (sourceSessionId != null && sourceSessionId != session.id) {
          mergedSessionIds.add(sourceSessionId);
        }
      }
    }

    final byId = <String, TeamReportSession>{};
    for (var index = 0; index < source.length; index++) {
      final item = source[index];
      final session = item.session;
      final details = session.details ?? const <String, dynamic>{};
      final isMerged = details['workoutSource']?.toString() == 'merged';
      final externalId = details['external_id']?.toString();
      if (!isMerged &&
          (mergedSessionIds.contains(session.id) ||
              (externalId != null && mergedExternalIds.contains(externalId)))) {
        continue;
      }
      final key = session.id.trim().isEmpty ? 'row_$index' : session.id;
      final existing = byId[key];
      if (existing == null || _preferSession(session, existing.session)) {
        byId[key] = item;
      }
    }

    final byEvent = <String, TeamReportSession>{};
    final withoutEvent = <TeamReportSession>[];
    for (final item in byId.values) {
      final eventId = item.session.eventId?.trim();
      if (eventId == null || eventId.isEmpty) {
        withoutEvent.add(item);
        continue;
      }
      final existing = byEvent[eventId];
      if (existing == null || _preferSession(item.session, existing.session)) {
        byEvent[eventId] = item;
      }
    }
    return [...withoutEvent, ...byEvent.values];
  }

  bool _isCompletedSession(TrainingSession session) {
    final status = TrainingActivity.fromTrainingSession(session).status;
    return status != ActivityStatus.planned &&
        status != ActivityStatus.cancelled;
  }

  bool _preferSession(TrainingSession candidate, TrainingSession existing) {
    final candidateMerged =
        candidate.details?['workoutSource']?.toString() == 'merged';
    final existingMerged =
        existing.details?['workoutSource']?.toString() == 'merged';
    if (candidateMerged != existingMerged) return candidateMerged;
    return TimeUtils.parseDurationToMinutes(candidate.duration) >
        TimeUtils.parseDurationToMinutes(existing.duration);
  }

  Map<String, MonthlyMetricDelta> _buildDeltas(
    _AthleteMonthMetrics current,
    _AthleteMonthMetrics previous,
  ) {
    double? previousOrNull(double value) => value == 0 ? null : value;

    return {
      'total_hours': MonthlyMetricDelta(
        current: current.totalHours,
        previous: previousOrNull(previous.totalHours),
      ),
      'session_count': MonthlyMetricDelta(
        current: current.sessionCount.toDouble(),
        previous: previousOrNull(previous.sessionCount.toDouble()),
      ),
      'ski_hours': MonthlyMetricDelta(
        current:
            (current.scheduledSkiMinutes + current.outOfProgramSkiMinutes) / 60,
        previous: previousOrNull(
          (previous.scheduledSkiMinutes + previous.outOfProgramSkiMinutes) / 60,
        ),
      ),
      'direction_changes': MonthlyMetricDelta(
        current: current.totalDirectionChanges.toDouble(),
        previous: previousOrNull(previous.totalDirectionChanges.toDouble()),
      ),
      'athletic_hours': MonthlyMetricDelta(
        current: (current.scheduledAthleticMinutes +
                current.outOfProgramAthleticMinutes) /
            60,
        previous: previousOrNull(
          (previous.scheduledAthleticMinutes +
                  previous.outOfProgramAthleticMinutes) /
              60,
        ),
      ),
      'volume_kg': MonthlyMetricDelta(
        current: current.strengthVolumeKg,
        previous: previousOrNull(previous.strengthVolumeKg),
      ),
      'cmj': MonthlyMetricDelta(
        current: current.cmjCm ?? 0,
        previous: previous.cmjCm,
      ),
      'rsi': MonthlyMetricDelta(
        current: current.rsi ?? 0,
        previous: previous.rsi,
      ),
    };
  }

  List<MonthlyTeamAthleteReport> _withAlerts(
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    return athletes.map((athlete) {
      final alerts = <MonthlyTeamAlert>[];
      final directionBaseline = _trendAverage(
        athlete.trend,
        (point) => point.skiDirectionChanges.toDouble(),
      );
      final preparationBaseline = _trendAverage(
        athlete.trend,
        (point) => point.hoursFor(MonthlyTrainingMacro.preparation),
      );
      final totalHoursBaseline = _trendAverage(
        athlete.trend,
        (point) => point.totalHours,
      );

      void add(String type, String label, {String severity = 'warning'}) {
        alerts.add(MonthlyTeamAlert(
          athleteId: athlete.athleteId,
          athleteName: athlete.athleteName,
          type: type,
          label: label,
          severity: severity,
        ));
      }

      if (athlete.skiPresence != null &&
          athlete.skiPresence! < thresholds.lowPresenceRatio) {
        add('low_ski_presence', 'Bassa presenza sci');
      }
      if (athlete.athleticPresence != null &&
          athlete.athleticPresence! < thresholds.lowPresenceRatio) {
        add('low_athletic_presence', 'Bassa presenza atletica');
      }
      if (athlete.outOfProgramHours > athlete.scheduledHours &&
          athlete.outOfProgramHours > 0) {
        add('high_out_of_program', 'Alto volume fuori programma');
      }
      if (directionBaseline != null &&
          athlete.totalDirectionChanges > 0 &&
          athlete.totalDirectionChanges <
              directionBaseline * thresholds.lowVolumeAverageRatio) {
        add('low_ski_volume', 'Volume sci basso');
      }
      if (preparationBaseline != null &&
          athlete.totalAthleticHours > 0 &&
          athlete.totalAthleticHours <
              preparationBaseline * thresholds.lowVolumeAverageRatio) {
        add('low_athletic_volume', 'Volume atletico basso');
      }
      if (_hasDominantSkiDiscipline(athlete)) {
        add('ski_imbalance', 'Squilibrio volume tecnico sci');
      }
      if ((athlete.asymmetryPercent ?? 0) > thresholds.jumpAsymmetryPercent) {
        add('jump_asymmetry', 'Asimmetria salto');
      }
      if (athlete.incompleteDataCount > 0 || !athlete.hasAnyData) {
        add('incomplete_data', 'Dati incompleti', severity: 'info');
      }
      if (totalHoursBaseline != null &&
          athlete.totalHours >
              totalHoursBaseline * thresholds.highVolumeAverageRatio) {
        add('high_volume_recovery', 'Volume alto, controllare recupero');
      }

      return MonthlyTeamAthleteReport(
        athleteId: athlete.athleteId,
        athleteName: athlete.athleteName,
        initial: athlete.initial,
        avatarUrl: athlete.avatarUrl,
        skillLevel: athlete.skillLevel,
        hasAnyData: athlete.hasAnyData,
        skiPresence: athlete.skiPresence,
        athleticPresence: athlete.athleticPresence,
        scheduledSkiHours: athlete.scheduledSkiHours,
        outOfProgramSkiHours: athlete.outOfProgramSkiHours,
        scheduledAthleticHours: athlete.scheduledAthleticHours,
        outOfProgramAthleticHours: athlete.outOfProgramAthleticHours,
        externalCoachHours: athlete.externalCoachHours,
        individualHours: athlete.individualHours,
        unclassifiedHours: athlete.unclassifiedHours,
        totalDirectionChanges: athlete.totalDirectionChanges,
        clDirectionChanges: athlete.clDirectionChanges,
        slDirectionChanges: athlete.slDirectionChanges,
        gsDirectionChanges: athlete.gsDirectionChanges,
        sgDirectionChanges: athlete.sgDirectionChanges,
        dhDirectionChanges: athlete.dhDirectionChanges,
        sxDirectionChanges: athlete.sxDirectionChanges,
        addestramentoDirectionChanges: athlete.addestramentoDirectionChanges,
        strengthVolumeKg: athlete.strengthVolumeKg,
        strengthSets: athlete.strengthSets,
        drillCount: athlete.drillCount,
        enduranceMeters: athlete.enduranceMeters,
        squatJumpCm: athlete.squatJumpCm,
        cmjCm: athlete.cmjCm,
        dropJumpCm: athlete.dropJumpCm,
        rsi: athlete.rsi,
        singleLegLeftCm: athlete.singleLegLeftCm,
        singleLegRightCm: athlete.singleLegRightCm,
        asymmetryPercent: athlete.asymmetryPercent,
        testSessionCount: athlete.testSessionCount,
        incompleteDataCount: athlete.incompleteDataCount,
        alerts: alerts,
        deltas: athlete.deltas,
        sessionCount: athlete.sessionCount,
        hoursByMacro: athlete.hoursByMacro,
        preparationHoursByType: athlete.preparationHoursByType,
        trend: athlete.trend,
        trendSummary: athlete.trendSummary,
      );
    }).toList();
  }

  MonthlyTeamReportSummary _buildSummary(
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    final activeAthletes =
        athletes.where((athlete) => athlete.hasAnyData).toList();
    final active = activeAthletes.length;
    return MonthlyTeamReportSummary(
      totalAthletes: athletes.length,
      athletesWithActivity: active,
      athletesWithoutData: athletes.length - active,
      averageSkiPresence: _averageNullable(
        athletes.map((athlete) => athlete.skiPresence),
      ),
      averageAthleticPresence: _averageNullable(
        athletes.map((athlete) => athlete.athleticPresence),
      ),
      averageAthleteHours: active == 0
          ? 0
          : activeAthletes.fold<double>(
                0,
                (sum, item) => sum + item.totalHours,
              ) /
              active,
      athleteHoursCoverage: active,
      testSessionCount:
          athletes.fold(0, (sum, item) => sum + item.testSessionCount),
      incompleteDataCount: athletes.fold(
        0,
        (sum, item) =>
            sum + item.incompleteDataCount + (item.hasAnyData ? 0 : 1),
      ),
    );
  }

  MonthlyTeamSkiReport _buildSkiReport(
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    final skiActive =
        athletes.where((athlete) => athlete.totalSkiHours > 0).toList();
    final valid = skiActive
        .where((athlete) => athlete.totalDirectionChanges > 0)
        .toList();

    double average(int Function(MonthlyTeamAthleteReport athlete) value) =>
        valid.isEmpty
            ? 0
            : valid.fold<double>(0, (sum, athlete) => sum + value(athlete)) /
                valid.length;

    return MonthlyTeamSkiReport(
      averageDirectionChanges: average(
        (athlete) => athlete.totalDirectionChanges,
      ),
      validAthleteCount: valid.length,
      skiActiveAthleteCount: skiActive.length,
      averageDirectionChangesByDiscipline: {
        'CL': average((athlete) => athlete.clDirectionChanges),
        'SL': average((athlete) => athlete.slDirectionChanges),
        'GS': average((athlete) => athlete.gsDirectionChanges),
        'SG': average((athlete) => athlete.sgDirectionChanges),
        'DH': average((athlete) => athlete.dhDirectionChanges),
        'SX': average((athlete) => athlete.sxDirectionChanges),
        'ADD': average(
          (athlete) => athlete.addestramentoDirectionChanges,
        ),
      },
    );
  }

  MonthlyTeamAthleticReport _buildAthleticReport(
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    final preparationActive =
        athletes.where((athlete) => athlete.totalAthleticHours > 0).toList();
    final strengthVolumeValid = preparationActive
        .where((athlete) => athlete.strengthVolumeKg > 0)
        .toList();
    final strengthSetsValid =
        preparationActive.where((athlete) => athlete.strengthSets > 0).toList();
    final drillsValid =
        preparationActive.where((athlete) => athlete.drillCount > 0).toList();
    final enduranceValid = preparationActive
        .where((athlete) => athlete.enduranceMeters > 0)
        .toList();

    double average(
      List<MonthlyTeamAthleteReport> valid,
      double Function(MonthlyTeamAthleteReport athlete) value,
    ) =>
        valid.isEmpty
            ? 0
            : valid.fold<double>(0, (sum, athlete) => sum + value(athlete)) /
                valid.length;
    final categories = preparationActive
        .expand((athlete) => athlete.preparationHoursByType.keys)
        .toSet();

    return MonthlyTeamAthleticReport(
      averageAthleteHours: average(
        preparationActive,
        (athlete) => athlete.totalAthleticHours,
      ),
      averageStrengthVolumeKg: average(
        strengthVolumeValid,
        (athlete) => athlete.strengthVolumeKg,
      ),
      averageStrengthSets: average(
        strengthSetsValid,
        (athlete) => athlete.strengthSets.toDouble(),
      ),
      averageDrills: average(
        drillsValid,
        (athlete) => athlete.drillCount.toDouble(),
      ),
      averageEnduranceMeters: average(
        enduranceValid,
        (athlete) => athlete.enduranceMeters,
      ),
      validAthleteCount: preparationActive.length,
      strengthVolumeCoverage: strengthVolumeValid.length,
      strengthSetsCoverage: strengthSetsValid.length,
      drillCoverage: drillsValid.length,
      enduranceCoverage: enduranceValid.length,
      averageHoursByCategory: {
        for (final category in categories)
          category: average(
            preparationActive,
            (athlete) => athlete.preparationHoursByType[category] ?? 0,
          ),
      },
    );
  }

  MonthlyTeamTestsReport _buildTestsReport(
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    return MonthlyTeamTestsReport(
      averageSquatJumpCm:
          _averageNullable(athletes.map((athlete) => athlete.squatJumpCm)),
      averageCmjCm: _averageNullable(athletes.map((athlete) => athlete.cmjCm)),
      averageDropJumpCm:
          _averageNullable(athletes.map((athlete) => athlete.dropJumpCm)),
      averageRsi: _averageNullable(athletes.map((athlete) => athlete.rsi)),
      averageSingleLegLeftCm:
          _averageNullable(athletes.map((athlete) => athlete.singleLegLeftCm)),
      averageSingleLegRightCm:
          _averageNullable(athletes.map((athlete) => athlete.singleLegRightCm)),
      averageAsymmetryPercent:
          _averageNullable(athletes.map((athlete) => athlete.asymmetryPercent)),
    );
  }

  String _automaticSummary(
    MonthlyTeamReportSummary summary,
    MonthlyTeamCoachWorkload workload,
    MonthlyTeamSkiReport skiReport,
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    if (summary.totalAthletes == 0 || summary.athletesWithActivity == 0) {
      return 'Dati insufficienti per generare una sintesi affidabile.';
    }

    final ski = summary.averageSkiPresence;
    final athletic = summary.averageAthleticPresence;
    if (ski == null &&
        athletic == null &&
        workload.completedSessionCount == 0) {
      return 'Dati insufficienti per generare una sintesi affidabile.';
    }

    final parts = <String>[];
    if (ski != null) {
      parts.add(
        'presenza media sci del ${(ski * 100).round()}%',
      );
    }
    if (athletic != null) {
      parts.add(
        'presenza preparazione del ${(athletic * 100).round()}%',
      );
    }

    final highOutOfProgram = athletes
        .where((athlete) =>
            athlete.outOfProgramHours > athlete.scheduledHours &&
            athlete.outOfProgramHours > 0)
        .length;
    final attention =
        athletes.where((athlete) => athlete.alerts.isNotEmpty).length;

    var text = 'Nel mese selezionato il team ha registrato ';
    text += parts.isEmpty
        ? 'dati parziali sulle attivita registrate'
        : parts.join(' e ');
    text += '.';

    if (workload.completedSessionCount > 0) {
      text +=
          ' Gli allenatori hanno completato ${workload.completedSessionCount} sedute per ${workload.completedHours.toStringAsFixed(1)} ore complessive.';
    }
    if (skiReport.validAthleteCount > 0) {
      text +=
          ' Il volume sci medio è ${skiReport.averageDirectionChanges.round()} passaggi/cambi per atleta con dati validi.';
    }

    if (highOutOfProgram > 0) {
      text +=
          ' Alcuni atleti mostrano un volume fuori programma superiore alle sedute supervisionate.';
    }
    if (attention > 0) {
      text += ' Da monitorare gli atleti con alert automatici.';
    }
    return text;
  }

  MonthlyTeamCoachWorkload _buildCoachWorkload(
    List<CalendarEvent> events,
  ) {
    final uniqueEvents = <String, CalendarEvent>{
      for (final event in events) event.id: event,
    }.values;
    var skiSessions = 0;
    var skiMinutes = 0;
    var preparationSessions = 0;
    var preparationMinutes = 0;
    var otherSportSessions = 0;
    var otherSportMinutes = 0;
    final preparationMinutesByType = <String, int>{};

    for (final event in uniqueEvents) {
      final minutes = _eventDurationMinutes(event);
      switch (_macroForEvent(event)) {
        case MonthlyTrainingMacro.ski:
          skiSessions++;
          skiMinutes += minutes;
          break;
        case MonthlyTrainingMacro.preparation:
          preparationSessions++;
          preparationMinutes += minutes;
          final type = _preparationTypeForEvent(event);
          preparationMinutesByType[type] =
              (preparationMinutesByType[type] ?? 0) + minutes;
          break;
        case MonthlyTrainingMacro.otherSports:
        case MonthlyTrainingMacro.recoveryOther:
          otherSportSessions++;
          otherSportMinutes += minutes;
          break;
      }
    }

    return MonthlyTeamCoachWorkload(
      completedSkiSessions: skiSessions,
      completedSkiHours: skiMinutes / 60,
      completedPreparationSessions: preparationSessions,
      completedPreparationHours: preparationMinutes / 60,
      completedOtherSportSessions: otherSportSessions,
      completedOtherSportHours: otherSportMinutes / 60,
      preparationHoursByType: {
        for (final entry in preparationMinutesByType.entries)
          entry.key: entry.value / 60,
      },
    );
  }

  MonthlyAthleteTrendPoint _trendPoint(
    DateTime month,
    int? throughDay,
    _AthleteMonthMetrics metrics,
  ) {
    return MonthlyAthleteTrendPoint(
      month: _monthKey(month),
      throughDay: throughDay,
      sessionCount: metrics.sessionCount,
      totalHours: metrics.totalHours,
      hoursByMacro: metrics.hoursByMacroHours,
      preparationHoursByType: metrics.preparationHoursByTypeHours,
      skiDirectionChanges: metrics.totalDirectionChanges,
      skiPresence: metrics.skiPresence,
      athleticPresence: metrics.athleticPresence,
      incompleteDataCount: metrics.incompleteDataCount,
    );
  }

  String _athleteTrendSummary(List<MonthlyAthleteTrendPoint> trend) {
    if (trend.isEmpty || !trend.last.hasActivity) {
      return 'Nessuna attività completata nel mese selezionato.';
    }
    final previous = trend
        .take(trend.length - 1)
        .where((point) => point.hasActivity)
        .toList();
    final dominant = MonthlyTrainingMacro.ordered.reduce(
      (current, candidate) =>
          trend.last.hoursFor(candidate) > trend.last.hoursFor(current)
              ? candidate
              : current,
    );
    if (previous.length < 2) {
      return 'Tipologia prevalente: ${MonthlyTrainingMacro.label(dominant)}. Storico ancora insufficiente per un confronto stabile.';
    }
    final average = previous.fold<double>(
          0,
          (sum, point) => sum + point.totalHours,
        ) /
        previous.length;
    if (average <= 0) {
      return 'Tipologia prevalente: ${MonthlyTrainingMacro.label(dominant)}. Storico ancora insufficiente per un confronto stabile.';
    }
    final delta = ((trend.last.totalHours - average) / average) * 100;
    final direction = delta.abs() < 10
        ? 'in linea'
        : delta > 0
            ? 'in aumento del ${delta.round()}%'
            : 'in calo del ${delta.abs().round()}%';
    return 'Carico $direction rispetto alla media dei ${previous.length} mesi validi. Tipologia prevalente: ${MonthlyTrainingMacro.label(dominant)}.';
  }

  double? _trendAverage(
    List<MonthlyAthleteTrendPoint> trend,
    double Function(MonthlyAthleteTrendPoint point) value,
  ) {
    if (trend.length < 3) return null;
    final valid = trend
        .take(trend.length - 1)
        .map(value)
        .where((item) => item > 0)
        .toList();
    if (valid.length < 2) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  String _macroForEvent(CalendarEvent event) {
    return _classificationForEvent(event).macroId;
  }

  String _preparationTypeForEvent(CalendarEvent event) {
    return _classificationForEvent(event).detailId;
  }

  MonthlyTrainingClassification _classificationForEvent(
    CalendarEvent event,
  ) {
    if (event.sportCategory == 'ski') {
      return const MonthlyTrainingClassification(
        macroId: MonthlyTrainingMacro.ski,
        detailId: 'alpine_skiing',
        detailLabel: 'Sci alpino',
      );
    }

    final planned = event.technicalDetails?['plannedDrylandSession'];
    TrainingActivity? activity;
    Map<String, dynamic> details = const {};
    if (planned is Map) {
      activity = TrainingActivity.fromJson(
        Map<String, dynamic>.from(planned),
      );
      details = activity.toSessionDetails();
    } else if (event.drylandSpecialty?.trim().isNotEmpty == true) {
      details = {
        'activityDomain': 'dryland',
        'activityCategory': event.drylandSpecialty,
      };
    }

    final activitySportType = activity?.sportType?.trim();
    final drylandSpecialty = event.drylandSpecialty?.trim();
    final String sportId;
    if (activitySportType != null && activitySportType.isNotEmpty) {
      sportId = activitySportType;
    } else if (drylandSpecialty != null && drylandSpecialty.isNotEmpty) {
      sportId = drylandSpecialty;
    } else {
      sportId = event.sportCategory?.trim().isNotEmpty == true
          ? event.sportCategory!
          : 'athletic_prep';
    }
    return const MonthlyTrainingClassifier().classify(
      TrainingSession(
        id: 'event_${event.id}',
        sportId: sportId,
        date: event.date,
        startTime: event.startTime,
        endTime: event.endTime,
        duration: _durationStringFromMinutes(_eventDurationMinutes(event)),
        effort: 0,
        eventId: event.id,
        details: details,
      ),
    );
  }

  void _addSkiVolume(_AthleteMonthMetrics metrics, TrainingSession session) {
    final summary = CoachTrainingUtils.volumeFromDetails(session.details);
    final hasDetails = session.details != null && session.details!.isNotEmpty;

    _addSkiSummary(metrics, summary, hasDetails: hasDetails);
  }

  void _addSkiSummary(
    _AthleteMonthMetrics metrics,
    TrainingVolumeSummary summary, {
    required bool hasDetails,
  }) {
    metrics.totalDirectionChanges += summary.totalSkiDirectionChanges;
    metrics.clDirectionChanges += summary.freeDirectionChanges;
    metrics.slDirectionChanges += summary.polePassesBySpecialty['SL'] ?? 0;
    metrics.gsDirectionChanges += summary.polePassesBySpecialty['GS'] ?? 0;
    metrics.sgDirectionChanges += summary.polePassesBySpecialty['SG'] ?? 0;
    metrics.dhDirectionChanges += summary.polePassesBySpecialty['DH'] ?? 0;
    metrics.sxDirectionChanges += summary.polePassesBySpecialty['SX'] ?? 0;
    metrics.addestramentoDirectionChanges += summary.trainingDirectionChanges;

    if (!hasDetails || summary.totalSkiDirectionChanges == 0) {
      metrics.incompleteDataCount++;
    }
  }

  void _addCompletedEventFallbacks({
    required _AthleteMonthMetrics metrics,
    required TeamReportAthleteProfile athlete,
    required List<CalendarEvent> events,
    required Set<String> linkedSessionEventIds,
  }) {
    const activityService = TrainingActivityService();

    for (final event in events) {
      if (linkedSessionEventIds.contains(event.id)) continue;
      if (event.status != CoachTrainingUtils.statusCompleted) continue;

      final attendee = _attendeeForAthlete(event, athlete);
      if (attendee == null || _attendanceScore(attendee) <= 0) continue;

      final durationMinutes = _eventDurationMinutes(event);
      metrics.hasAnyData = true;
      metrics.sessionCount++;
      if (durationMinutes <= 0) metrics.incompleteDataCount++;

      if (event.sportCategory == 'ski') {
        metrics.addMacroMinutes(MonthlyTrainingMacro.ski, durationMinutes);
        metrics.scheduledSkiMinutes += durationMinutes;
        _addSkiSummary(
          metrics,
          CoachTrainingUtils.volumeFromEventAttendee(event, attendee),
          hasDetails: event.technicalDetails?.isNotEmpty == true,
        );
      } else {
        final details = activityService.buildCoachDrylandSessionDetails(
          event,
          attendee,
        );
        final session = TrainingSession(
          id: 'event_${event.id}',
          sportId: details['sportType']?.toString() ?? 'athletic_prep',
          date: event.date,
          startTime: event.startTime,
          endTime: event.endTime,
          duration: _durationStringFromMinutes(durationMinutes),
          effort: CoachTrainingUtils.asInt(attendee['rpe'], fallback: 0),
          eventId: event.id,
          details: details,
        );
        final classification =
            const MonthlyTrainingClassifier().classify(session);
        metrics.addMacroMinutes(classification.macroId, durationMinutes);
        if (classification.macroId == MonthlyTrainingMacro.preparation) {
          metrics.hasPreparationData = true;
          metrics.scheduledAthleticMinutes += durationMinutes;
          metrics.addPreparationMinutes(
            classification.detailId,
            durationMinutes,
          );
          _addAthleticVolume(metrics, session);
        }
      }
    }
  }

  void _addAthleticVolume(
      _AthleteMonthMetrics metrics, TrainingSession session) {
    final activity = TrainingActivity.fromTrainingSession(session);
    if (activity.status == ActivityStatus.cancelled) return;

    final strength = TrainingMetricsUtils.strengthSummary([activity]);
    final drills = TrainingMetricsUtils.speedAgilitySummary([activity]);
    final endurance = TrainingMetricsUtils.enduranceSummary([activity]);

    metrics.strengthVolumeKg += strength.volumeKg;
    metrics.strengthSets += strength.totalSets;
    metrics.drillCount += drills.drillCount;
    metrics.enduranceMeters += endurance.distanceKm * 1000;

    if (activity.category == ActivityCategory.test ||
        activity.blocks.any((block) => block.type == TrainingBlockType.test)) {
      metrics.testSessionCount++;
    }
  }

  void _addLatestJumpMetrics(
    _AthleteMonthMetrics metrics,
    String athleteId,
    DateTime month,
    List<TeamReportMetricLog> jumpLogs,
  ) {
    double? latest(String type) {
      final logs = jumpLogs
          .where((log) =>
              log.athleteId == athleteId &&
              log.type == type &&
              _isInMonth(DateTime.tryParse(log.date), month))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return logs.isEmpty ? null : logs.last.value;
    }

    metrics.squatJumpCm = latest('squat_jump');
    metrics.cmjCm = latest('cm_jump');
    metrics.dropJumpCm = latest('drop_jump');
    metrics.rsi = latest('drop_jump_rsi');
    metrics.singleLegLeftCm = latest('single_leg_left');
    metrics.singleLegRightCm = latest('single_leg_right');

    final left = metrics.singleLegLeftCm;
    final right = metrics.singleLegRightCm;
    if (left != null && right != null && left > 0 && right > 0) {
      final maxValue = left > right ? left : right;
      metrics.asymmetryPercent = ((left - right).abs() / maxValue) * 100;
    }
  }

  int _testMeasurementCount(
    String athleteId,
    DateTime month,
    List<TeamReportMetricLog> jumpLogs,
    List<TeamReportMetricLog> bodyMetricLogs,
    List<TeamReportPrLog> prLogs,
  ) {
    final jumpCount = jumpLogs
        .where((log) =>
            log.athleteId == athleteId &&
            _isInMonth(DateTime.tryParse(log.date), month))
        .length;
    final bodyCount = bodyMetricLogs
        .where((log) =>
            log.athleteId == athleteId &&
            _isInMonth(DateTime.tryParse(log.date), month))
        .length;
    final prCount = prLogs
        .where((log) =>
            log.athleteId == athleteId &&
            _isInMonth(DateTime.tryParse(log.date), month))
        .length;
    return jumpCount + bodyCount + prCount;
  }

  _ActivityClassification _activityClassification(TrainingSession session) {
    final details = session.details ?? const {};
    final supervision = (details['supervision'] ??
            details['supervision_type'] ??
            details['coachType'] ??
            details['coach_type'])
        ?.toString()
        .toLowerCase();
    if (supervision == 'external_coach' ||
        supervision == 'coach_esterno' ||
        supervision == 'external') {
      return _ActivityClassification.externalCoach;
    }

    final source = details['source']?.toString().toLowerCase();
    if (source == ActivitySource.athlete ||
        source == 'health_sync' ||
        source == ActivitySource.imported ||
        details['athleteModified'] == true) {
      return _ActivityClassification.individual;
    }

    return _ActivityClassification.unclassified;
  }

  bool _hasDominantSkiDiscipline(MonthlyTeamAthleteReport athlete) {
    if (athlete.totalDirectionChanges <= 0) return false;
    final buckets = [
      athlete.clDirectionChanges,
      athlete.slDirectionChanges,
      athlete.gsDirectionChanges,
      athlete.sgDirectionChanges,
      athlete.dhDirectionChanges,
      athlete.sxDirectionChanges,
      athlete.addestramentoDirectionChanges,
    ];
    final maxBucket = buckets.reduce((a, b) => a > b ? a : b);
    return maxBucket / athlete.totalDirectionChanges >
        thresholds.disciplineDominanceRatio;
  }

  Map<String, dynamic>? _attendeeForAthlete(
    CalendarEvent event,
    TeamReportAthleteProfile athlete,
  ) {
    final attendees = event.attendees ?? const [];
    for (final attendee in attendees) {
      final id = attendee['id']?.toString();
      final name = attendee['name']?.toString().trim();
      if (id == athlete.id || (name != null && name == athlete.name)) {
        return attendee;
      }
    }
    return null;
  }

  double _attendanceScore(Map<String, dynamic> attendee) {
    final status = attendee['attendanceStatus']?.toString().toLowerCase();
    if (status == partialAttendanceStatus) return 0.5;
    if (status == CoachTrainingUtils.attendancePresent) return 1;
    if (status == CoachTrainingUtils.attendanceAbsent ||
        status == CoachTrainingUtils.attendancePending) {
      return 0;
    }
    if (attendee['isPresent'] == true) return 1;
    return 0;
  }

  int _eventDurationMinutes(CalendarEvent event) {
    final start = _timeToMinutes(event.startTime);
    final end = _timeToMinutes(event.endTime);
    if (start == null || end == null) return 0;
    var diff = end - start;
    if (diff < 0) diff += 24 * 60;
    return diff;
  }

  int? _timeToMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    return (int.tryParse(match.group(1)!) ?? 0) * 60 +
        (int.tryParse(match.group(2)!) ?? 0);
  }

  String _durationStringFromMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
  }

  static bool _isInMonth(DateTime? date, DateTime month) {
    if (date == null) return false;
    return date.year == month.year && date.month == month.month;
  }

  static String _monthKey(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  double? _averageNullable(Iterable<double?> values) {
    final valid = values.whereType<double>().toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }
}

class _AthleteMonthMetrics {
  bool hasAnyData = false;
  bool hasPreparationData = false;
  double? skiPresence;
  double? athleticPresence;
  int sessionCount = 0;
  int scheduledSkiMinutes = 0;
  int outOfProgramSkiMinutes = 0;
  int scheduledAthleticMinutes = 0;
  int outOfProgramAthleticMinutes = 0;
  int externalCoachMinutes = 0;
  int individualMinutes = 0;
  int unclassifiedMinutes = 0;
  int totalDirectionChanges = 0;
  int clDirectionChanges = 0;
  int slDirectionChanges = 0;
  int gsDirectionChanges = 0;
  int sgDirectionChanges = 0;
  int dhDirectionChanges = 0;
  int sxDirectionChanges = 0;
  int addestramentoDirectionChanges = 0;
  double strengthVolumeKg = 0;
  int strengthSets = 0;
  int drillCount = 0;
  double enduranceMeters = 0;
  int testSessionCount = 0;
  double? squatJumpCm;
  double? cmjCm;
  double? dropJumpCm;
  double? rsi;
  double? singleLegLeftCm;
  double? singleLegRightCm;
  double? asymmetryPercent;
  int incompleteDataCount = 0;
  final Map<String, int> hoursByMacroMinutes = {
    for (final macro in MonthlyTrainingMacro.ordered) macro: 0,
  };
  final Map<String, int> preparationHoursByTypeMinutes = {};

  void addMacroMinutes(String macro, int minutes) {
    if (minutes <= 0) return;
    hoursByMacroMinutes[macro] = (hoursByMacroMinutes[macro] ?? 0) + minutes;
  }

  void addPreparationMinutes(String type, int minutes) {
    if (minutes <= 0) return;
    preparationHoursByTypeMinutes[type] =
        (preparationHoursByTypeMinutes[type] ?? 0) + minutes;
  }

  Map<String, double> get hoursByMacroHours => {
        for (final entry in hoursByMacroMinutes.entries)
          entry.key: entry.value / 60,
      };

  Map<String, double> get preparationHoursByTypeHours => {
        for (final entry in preparationHoursByTypeMinutes.entries)
          entry.key: entry.value / 60,
      };

  double get totalHours =>
      hoursByMacroMinutes.values.fold<int>(0, (sum, value) => sum + value) / 60;
}

enum _ActivityClassification {
  programmed,
  externalCoach,
  individual,
  unclassified,
}
