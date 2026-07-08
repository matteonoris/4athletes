import '../models/models.dart';
import '../models/monthly_team_report_models.dart';
import '../models/training_activity_models.dart';
import '../utils/coach_training_utils.dart';
import '../utils/time_utils.dart';
import '../utils/training_metrics_utils.dart';
import 'training_activity_service.dart';

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
    final previousMonth = DateTime(month.year, month.month - 1);

    final currentEvents = _eventsForMonth(events, team.id, currentMonth);
    final previousEvents = _eventsForMonth(events, team.id, previousMonth);
    final currentEventIds = currentEvents.map((event) => event.id).toSet();
    final previousEventIds = previousEvents.map((event) => event.id).toSet();

    final athleteReports = <MonthlyTeamAthleteReport>[];
    final previousByAthlete = <String, _AthleteMonthMetrics>{};

    for (final athlete in athletes) {
      final currentMetrics = _metricsForAthleteMonth(
        athlete: athlete,
        month: currentMonth,
        sessions: sessions,
        eventIds: currentEventIds,
        events: currentEvents,
        jumpLogs: jumpLogs,
        bodyMetricLogs: bodyMetricLogs,
        prLogs: prLogs,
      );
      final previousMetrics = _metricsForAthleteMonth(
        athlete: athlete,
        month: previousMonth,
        sessions: sessions,
        eventIds: previousEventIds,
        events: previousEvents,
        jumpLogs: jumpLogs,
        bodyMetricLogs: bodyMetricLogs,
        prLogs: prLogs,
      );
      previousByAthlete[athlete.id] = previousMetrics;

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

    return MonthlyTeamReport(
      team: team,
      month: _monthKey(currentMonth),
      generatedAt: generatedAt ?? DateTime.now(),
      summary: summary,
      athletes: reportsWithAlerts,
      ski: ski,
      athletic: athletic,
      tests: tests,
      alerts: alerts,
      automaticSummary: _automaticSummary(summary, reportsWithAlerts),
    );
  }

  List<CalendarEvent> _eventsForMonth(
    List<CalendarEvent> events,
    String teamId,
    DateTime month,
  ) {
    return events.where((event) {
      if (event.status == CoachTrainingUtils.statusCancelled) return false;
      final date = DateTime.tryParse(event.date);
      if (date == null || !_isInMonth(date, month)) return false;
      return CoachTrainingUtils.teamIdsForEvent(event).contains(teamId);
    }).toList();
  }

  _AthleteMonthMetrics _metricsForAthleteMonth({
    required TeamReportAthleteProfile athlete,
    required DateTime month,
    required List<TeamReportSession> sessions,
    required Set<String> eventIds,
    required List<CalendarEvent> events,
    required List<TeamReportMetricLog> jumpLogs,
    required List<TeamReportMetricLog> bodyMetricLogs,
    required List<TeamReportPrLog> prLogs,
  }) {
    final metrics = _AthleteMonthMetrics();
    final athleteSessions = sessions.where((item) {
      if (item.athleteId != athlete.id) return false;
      final date = DateTime.tryParse(item.session.date);
      return date != null && _isInMonth(date, month);
    }).toList();

    final sessionEventIds = athleteSessions
        .map((item) => item.session.eventId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final skiEvents = events
        .where((event) => event.sportCategory == 'ski')
        .toList(growable: false);
    final athleticEvents = events
        .where((event) => event.sportCategory != 'ski')
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
      final session = item.session;
      final isSki = _isSkiSport(session.sportId);
      final durationMinutes =
          TimeUtils.parseDurationToMinutes(session.duration);
      final isProgrammed =
          session.eventId != null && eventIds.contains(session.eventId);

      if (durationMinutes <= 0) {
        metrics.incompleteDataCount++;
      }

      if (isSki) {
        if (isProgrammed) {
          metrics.scheduledSkiMinutes += durationMinutes;
        } else {
          metrics.outOfProgramSkiMinutes += durationMinutes;
        }
        _addSkiVolume(metrics, session);
      } else {
        if (isProgrammed) {
          metrics.scheduledAthleticMinutes += durationMinutes;
        } else {
          metrics.outOfProgramAthleticMinutes += durationMinutes;
        }
        _addAthleticVolume(metrics, session);
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
    for (final event in events) {
      final attendee = _attendeeForAthlete(event, athlete);
      if (attendee == null) {
        if (linkedSessionEventIds.contains(event.id)) score += 1;
        continue;
      }
      score += _attendanceScore(attendee);
    }
    return score / events.length;
  }

  Map<String, MonthlyMetricDelta> _buildDeltas(
    _AthleteMonthMetrics current,
    _AthleteMonthMetrics previous,
  ) {
    double? previousOrNull(double value) => value == 0 ? null : value;

    return {
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
    final activeDirectionAverage = _activeAverage(
      athletes.map((athlete) => athlete.totalDirectionChanges.toDouble()),
    );
    final activeKgAverage =
        _activeAverage(athletes.map((athlete) => athlete.strengthVolumeKg));
    final activeAthleticHoursAverage =
        _activeAverage(athletes.map((athlete) => athlete.totalAthleticHours));
    final activeTotalHoursAverage =
        _activeAverage(athletes.map((athlete) => athlete.totalHours));

    return athletes.map((athlete) {
      final alerts = <MonthlyTeamAlert>[];

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
      if (activeDirectionAverage != null &&
          athlete.totalDirectionChanges > 0 &&
          athlete.totalDirectionChanges <
              activeDirectionAverage * thresholds.lowVolumeAverageRatio) {
        add('low_ski_volume', 'Volume sci basso');
      }
      if (activeKgAverage != null &&
          athlete.strengthVolumeKg > 0 &&
          athlete.strengthVolumeKg <
              activeKgAverage * thresholds.lowVolumeAverageRatio) {
        add('low_athletic_volume', 'Volume atletico basso');
      } else if (activeAthleticHoursAverage != null &&
          athlete.totalAthleticHours > 0 &&
          athlete.totalAthleticHours <
              activeAthleticHoursAverage * thresholds.lowVolumeAverageRatio) {
        add('low_athletic_volume', 'Volume atletico basso');
      }
      if (_hasDominantSkiDiscipline(athlete)) {
        add('ski_imbalance', 'Squilibrio SL/GS/CL');
      }
      if ((athlete.asymmetryPercent ?? 0) > thresholds.jumpAsymmetryPercent) {
        add('jump_asymmetry', 'Asimmetria salto');
      }
      if (athlete.incompleteDataCount > 0 || !athlete.hasAnyData) {
        add('incomplete_data', 'Dati incompleti', severity: 'info');
      }
      if (activeTotalHoursAverage != null &&
          athlete.totalHours >
              activeTotalHoursAverage * thresholds.highVolumeAverageRatio) {
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
      );
    }).toList();
  }

  MonthlyTeamReportSummary _buildSummary(
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    final active = athletes.where((athlete) => athlete.hasAnyData).length;
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
      totalSkiHours: athletes.fold(0, (sum, item) => sum + item.totalSkiHours),
      totalAthleticHours:
          athletes.fold(0, (sum, item) => sum + item.totalAthleticHours),
      totalOutOfProgramHours:
          athletes.fold(0, (sum, item) => sum + item.outOfProgramHours),
      totalDirectionChanges: athletes.fold(
        0,
        (sum, item) => sum + item.totalDirectionChanges,
      ),
      totalStrengthVolumeKg:
          athletes.fold(0, (sum, item) => sum + item.strengthVolumeKg),
      totalStrengthSets:
          athletes.fold(0, (sum, item) => sum + item.strengthSets),
      totalEnduranceMeters:
          athletes.fold(0, (sum, item) => sum + item.enduranceMeters),
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
    final cl = athletes.fold(0, (sum, item) => sum + item.clDirectionChanges);
    final sl = athletes.fold(0, (sum, item) => sum + item.slDirectionChanges);
    final gs = athletes.fold(0, (sum, item) => sum + item.gsDirectionChanges);
    final add = athletes.fold(
      0,
      (sum, item) => sum + item.addestramentoDirectionChanges,
    );
    return MonthlyTeamSkiReport(
      totalDirectionChanges:
          athletes.fold(0, (sum, item) => sum + item.totalDirectionChanges),
      clDirectionChanges: cl,
      slDirectionChanges: sl,
      gsDirectionChanges: gs,
      addestramentoDirectionChanges: add,
      directionChangesByDiscipline: {
        'CL': cl,
        'SL': sl,
        'GS': gs,
        'ADD': add,
      },
    );
  }

  MonthlyTeamAthleticReport _buildAthleticReport(
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    return MonthlyTeamAthleticReport(
      totalHours:
          athletes.fold(0, (sum, item) => sum + item.totalAthleticHours),
      totalStrengthVolumeKg:
          athletes.fold(0, (sum, item) => sum + item.strengthVolumeKg),
      totalStrengthSets:
          athletes.fold(0, (sum, item) => sum + item.strengthSets),
      totalDrills: athletes.fold(0, (sum, item) => sum + item.drillCount),
      totalEnduranceMeters:
          athletes.fold(0, (sum, item) => sum + item.enduranceMeters),
      hoursByCategory: const {},
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
    List<MonthlyTeamAthleteReport> athletes,
  ) {
    if (summary.totalAthletes == 0 || summary.athletesWithActivity == 0) {
      return 'Dati insufficienti per generare una sintesi affidabile.';
    }

    final ski = summary.averageSkiPresence;
    final athletic = summary.averageAthleticPresence;
    if (ski == null && athletic == null && summary.totalDirectionChanges == 0) {
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
        'presenza atletica del ${(athletic * 100).round()}%',
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

    if (highOutOfProgram > 0) {
      text +=
          ' Alcuni atleti mostrano un volume fuori programma superiore alle sedute supervisionate.';
    }
    if (attention > 0) {
      text += ' Da monitorare gli atleti con alert automatici.';
    }
    return text;
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

      if (event.sportCategory == 'ski') {
        metrics.scheduledSkiMinutes += durationMinutes;
        _addSkiSummary(
          metrics,
          CoachTrainingUtils.volumeFromEventAttendee(event, attendee),
          hasDetails: event.technicalDetails?.isNotEmpty == true,
        );
      } else {
        metrics.scheduledAthleticMinutes += durationMinutes;
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
        _addAthleticVolume(metrics, session);
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

  bool _isSkiSport(String sportId) {
    return sportId == 'alpine_skiing' ||
        sportId == 'ski' ||
        sportId == 'skiing' ||
        sportId == 'snowboarding';
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

  double? _activeAverage(Iterable<double> values) {
    final valid = values.where((value) => value > 0).toList();
    if (valid.length < 2) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }
}

class _AthleteMonthMetrics {
  bool hasAnyData = false;
  double? skiPresence;
  double? athleticPresence;
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
}

enum _ActivityClassification {
  programmed,
  externalCoach,
  individual,
  unclassified,
}
