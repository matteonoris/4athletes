import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';
import 'health_import_normalizer.dart';
import 'native_health_service.dart';

enum HealthPermissionRequestStatus {
  granted,
  denied,
  healthConnectInstallRequired,
  healthConnectUnavailable,
  error,
}

class HealthPermissionRequestResult {
  const HealthPermissionRequestResult(this.status, {this.message});

  final HealthPermissionRequestStatus status;
  final String? message;

  bool get isGranted => status == HealthPermissionRequestStatus.granted;
}

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  static const int _healthImportVersion = 6;

  final List<HealthDataType> _dataTypes = Platform.isIOS
      ? [
          HealthDataType.WORKOUT,
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_AWAKE,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_IN_BED,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.RESTING_HEART_RATE,
          HealthDataType.HEART_RATE_VARIABILITY_SDNN,
          HealthDataType.WEIGHT,
          HealthDataType.HEIGHT,
          HealthDataType.DISTANCE_WALKING_RUNNING,
          HealthDataType.DISTANCE_CYCLING,
          HealthDataType.SPEED,
          HealthDataType.FLIGHTS_CLIMBED,
          HealthDataType.BLOOD_OXYGEN,
          HealthDataType.RESPIRATORY_RATE,
          HealthDataType.SLEEP_WRIST_TEMPERATURE,
          HealthDataType.MENSTRUATION_FLOW,
        ]
      : [
          HealthDataType.WORKOUT,
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.SLEEP_SESSION,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_AWAKE,
          HealthDataType.SLEEP_AWAKE_IN_BED,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_OUT_OF_BED,
          HealthDataType.SLEEP_UNKNOWN,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.DISTANCE_DELTA,
          HealthDataType.SPEED,
          HealthDataType.RESTING_HEART_RATE,
          HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
          HealthDataType.WEIGHT,
          HealthDataType.HEIGHT,
          HealthDataType.BLOOD_OXYGEN,
          HealthDataType.RESPIRATORY_RATE,
          HealthDataType.SKIN_TEMPERATURE,
          HealthDataType.MENSTRUATION_FLOW,
        ];

  Future<bool> requestPermissions() async {
    final result = await requestPermissionsDetailed();
    return result.isGranted;
  }

  Future<HealthPermissionRequestResult> requestPermissionsDetailed() async {
    try {
      // Configure health plugin before use
      await _health.configure();

      // On Android, check the status of Google Health Connect SDK
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status ==
            HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          debugPrint(
              "Health Connect is not installed or outdated. Directing user to Play Store...");
          await _health.installHealthConnect();
          return const HealthPermissionRequestResult(
            HealthPermissionRequestStatus.healthConnectInstallRequired,
            message:
                'Health Connect non e installato o va aggiornato. Scaricalo dal Play Store e poi torna in 4athletes.',
          );
        } else if (status == HealthConnectSdkStatus.sdkUnavailable) {
          debugPrint("Health Connect is unavailable on this device.");
          return const HealthPermissionRequestResult(
            HealthPermissionRequestStatus.healthConnectUnavailable,
            message:
                'Health Connect non e disponibile su questo dispositivo Android.',
          );
        }

        // Request Activity Recognition FIRST on Android
        final activityStatus = await Permission.activityRecognition.request();
        if (activityStatus.isDenied || activityStatus.isPermanentlyDenied) {
          debugPrint("Activity Recognition permission denied.");
          return const HealthPermissionRequestResult(
            HealthPermissionRequestStatus.denied,
            message:
                'Permesso rilevamento attivita negato. Puoi abilitarlo dalle impostazioni.',
          );
        }
      }

      // Request permissions from Health Connect / Apple Health. Skin
      // temperature is optional on Android and must be removed on devices
      // that do not expose the Health Connect feature.
      final requestTypes =
          _dataTypes.where(_health.isDataTypeAvailable).toList();
      if (Platform.isAndroid &&
          requestTypes.contains(HealthDataType.SKIN_TEMPERATURE)) {
        try {
          if (!await _health.isSkinTemperatureAvailable()) {
            requestTypes.remove(HealthDataType.SKIN_TEMPERATURE);
          }
        } catch (e) {
          requestTypes.remove(HealthDataType.SKIN_TEMPERATURE);
          debugPrint('Skin temperature availability check failed: $e');
        }
      }
      final requestPermissions =
          requestTypes.map((_) => HealthDataAccess.READ).toList();
      bool hasPermissions = await _health.hasPermissions(
            requestTypes,
            permissions: requestPermissions,
          ) ??
          false;

      if (!hasPermissions) {
        hasPermissions = await _health.requestAuthorization(
          requestTypes,
          permissions: requestPermissions,
        );
      }

      if (hasPermissions) {
        return const HealthPermissionRequestResult(
            HealthPermissionRequestStatus.granted);
      }

      return HealthPermissionRequestResult(
        HealthPermissionRequestStatus.denied,
        message: Platform.isIOS
            ? 'Permessi Apple Health non concessi completamente. Puoi abilitarli dall app Salute.'
            : 'Permessi Health Connect non concessi completamente. Puoi abilitarli dalle impostazioni.',
      );
    } catch (e) {
      debugPrint("Error requesting health permissions: $e");
      return HealthPermissionRequestResult(
        HealthPermissionRequestStatus.error,
        message: 'Errore durante la richiesta dei permessi salute: $e',
      );
    }
  }

  Future<List<TrainingSession>> fetchRecentWorkouts(UserProfile profile,
      {int days = 7}) async {
    final nativeSessions = await _fetchNativeWorkouts(profile, days: days);
    if (nativeSessions.isNotEmpty) return nativeSessions;

    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final healthData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      final sessions = <TrainingSession>[];
      for (final point in healthData) {
        if (point.value is! WorkoutHealthValue) continue;

        final workout = point.value as WorkoutHealthValue;
        final sportId =
            _mapHealthActivityToSportId(workout.workoutActivityType);

        // Exclude walking/camminate entirely as requested by the user.
        if (sportId == 'walking') continue;
        if (!_isTrustedWorkoutSource(point)) continue;

        final totalDurationSeconds =
            _durationSeconds(point.dateFrom, point.dateTo);
        final totalDurationMinutes =
            _secondsToRoundedMinutes(totalDurationSeconds);
        if (totalDurationMinutes < 5) continue;

        final distanceTypes = _distanceTypesForSport(sportId);
        final distancePoints = distanceTypes.isEmpty
            ? <HealthDataPoint>[]
            : await _fetchScopedPoints(
                workout: point,
                types: distanceTypes,
                debugLabel: 'distance',
              );

        double distanceMeters = (workout.totalDistance ?? 0).toDouble();
        if (distanceMeters <= 0) {
          distanceMeters =
              _sumNumericValues(distancePoints, point.dateFrom, point.dateTo);
        }
        if (!_isPlausibleDistance(
            distanceMeters, totalDurationSeconds, sportId)) {
          distanceMeters = 0;
        }

        double calories = (workout.totalEnergyBurned ?? 0).toDouble();
        if (calories <= 0) {
          final caloriePoints = await _fetchScopedPoints(
            workout: point,
            types: [HealthDataType.ACTIVE_ENERGY_BURNED],
            debugLabel: 'calories',
          );
          calories =
              _sumNumericValues(caloriePoints, point.dateFrom, point.dateTo);
        }

        final speedPoints = _isRunningSport(sportId)
            ? await _fetchScopedPoints(
                workout: point,
                types: [HealthDataType.SPEED],
                debugLabel: 'speed',
                preferDenseSamples: true,
              )
            : <HealthDataPoint>[];
        final averageSpeedKmh = _averageNumericValue(speedPoints) == null
            ? null
            : _averageNumericValue(speedPoints)! * 3.6;
        final stepPoints = _isRunningSport(sportId)
            ? await _fetchScopedPoints(
                workout: point,
                types: [HealthDataType.STEPS],
                debugLabel: 'steps',
              )
            : <HealthDataPoint>[];
        final importedSteps =
            _sumNumericValues(stepPoints, point.dateFrom, point.dateTo);

        final hrPoints = await _fetchScopedPoints(
          workout: point,
          types: [HealthDataType.HEART_RATE],
          debugLabel: 'heart rate',
          preferDenseSamples: true,
        );
        final hrMetrics = _calculateHrMetrics(
          hrPoints,
          profile,
          workoutStart: point.dateFrom,
          workoutEnd: point.dateTo,
        );

        final distanceCoverageSeconds = _durationCoveredByPositiveSamples(
            distancePoints, point.dateFrom, point.dateTo);
        final activeDurationSeconds = totalDurationSeconds;
        final movingDurationSeconds =
            HealthImportNormalizer.deriveMovingDurationSeconds(
          elapsedSeconds: totalDurationSeconds,
          distanceCoverageSeconds: distanceCoverageSeconds,
          heartRateCoverageSeconds: hrMetrics.coverageSeconds,
          hasDistance: distanceMeters > 0,
        );
        final activeDurationMinutes =
            _secondsToRoundedMinutes(activeDurationSeconds);
        final reliableHr =
            _isReliableHrMetrics(hrMetrics, activeDurationSeconds);

        final details = <String, dynamic>{
          'source': 'health_sync',
          'health_import_version': _healthImportVersion,
          'hr_zone_calculation_version':
              HealthImportNormalizer.heartRateZoneCalculationVersion,
          'source_name': point.sourceName,
          'source_id': point.sourceId,
          'external_id': _externalWorkoutId(point, sportId),
          'workout_start_ms': point.dateFrom.millisecondsSinceEpoch,
          'workout_end_ms': point.dateTo.millisecondsSinceEpoch,
          'total_duration_seconds': totalDurationSeconds,
          'active_duration_seconds': activeDurationSeconds,
          'moving_duration_seconds': movingDurationSeconds,
          'total_duration': totalDurationMinutes.toString(),
          'total_duration_minutes': totalDurationMinutes,
          'active_duration': activeDurationMinutes.toString(),
          'active_duration_minutes': activeDurationMinutes,
          'duration_source': 'source',
        };
        if (hrPoints.isNotEmpty) {
          details['hr_source_id'] = hrPoints.first.sourceId;
          details['hr_source_sample_count'] = hrPoints.length;
          details['hr_source_max_bpm'] = hrMetrics.maxHeartRate;
        }

        if (distanceMeters > 0) {
          final distanceKm = distanceMeters / 1000;
          details['distance'] = '${distanceKm.toStringAsFixed(2)} km';
          details['distance_meters'] = distanceMeters.round();

          if (_isRunningSport(sportId)) {
            final paceSecondsPerKm = activeDurationSeconds / distanceKm;
            details['pace'] = '${_formatPace(paceSecondsPerKm)} min/km';
            details['avg_pace_sec_per_km'] = paceSecondsPerKm.round();
            final derivedSpeed = distanceKm / (activeDurationSeconds / 3600);
            final speed = averageSpeedKmh != null && averageSpeedKmh > 0
                ? averageSpeedKmh
                : derivedSpeed;
            details['speed'] = '${speed.toStringAsFixed(2)} km/h';
            details['avg_speed_kmh'] = double.parse(speed.toStringAsFixed(2));
          } else if (_isCyclingSport(sportId)) {
            final speedKmh = distanceKm / (activeDurationSeconds / 3600);
            details['speed'] = '${speedKmh.toStringAsFixed(1)} km/h';
            details['avg_speed_kmh'] =
                double.parse(speedKmh.toStringAsFixed(1));
          }
        }
        if (_isRunningSport(sportId) &&
            distanceMeters <= 0 &&
            averageSpeedKmh != null &&
            averageSpeedKmh > 0) {
          details['speed'] = '${averageSpeedKmh.toStringAsFixed(2)} km/h';
          details['avg_speed_kmh'] =
              double.parse(averageSpeedKmh.toStringAsFixed(2));
        }
        if (_isRunningSport(sportId) &&
            importedSteps > 0 &&
            activeDurationSeconds > 0) {
          final cadence = importedSteps / (activeDurationSeconds / 60);
          details['cadence'] = cadence.round();
          details['avg_cadence_spm'] = double.parse(cadence.toStringAsFixed(1));
          details['cadence_source'] = 'steps_and_active_duration';
        }

        if (calories > 0) {
          details['calories'] = calories.round();
          details['energy_total_kcal'] = calories.round();
        }

        final estimatedElevationMeters =
            await _fetchEstimatedElevationMeters(point, sportId);
        if (estimatedElevationMeters != null) {
          details['elevation'] = '${estimatedElevationMeters.round()} m';
          details['elevation_meters'] = estimatedElevationMeters.round();
          details['elevation_source'] = 'flights_climbed_estimate';
        }

        details['hr_reliable'] = reliableHr;
        details['hr_sample_count'] = hrMetrics.sampleCount;
        if (reliableHr && hrMetrics.averageHeartRate != null) {
          details['avg_hr'] = hrMetrics.averageHeartRate;
        }
        if (reliableHr && hrMetrics.maxHeartRate != null) {
          details['max_hr'] = hrMetrics.maxHeartRate;
        }
        if (reliableHr) {
          details['hr_samples'] = _serializeHrSamples(hrMetrics.samples);
          details['hr_coverage_seconds'] = hrMetrics.coverageSeconds;
          details['hr_coverage_minutes'] =
              _secondsToRoundedMinutes(hrMetrics.coverageSeconds);
          if (hrMetrics.zoneSeconds.any((seconds) => seconds > 0)) {
            details['hr_zones_seconds'] =
                HealthImportNormalizer.roundedZoneSeconds(
              hrMetrics.zoneSeconds,
              targetSeconds: hrMetrics.coverageSeconds,
            );
            details['hr_zones'] = _zoneMinutesFromSeconds(
              zoneSeconds: hrMetrics.zoneSeconds,
              activeDurationSeconds: activeDurationSeconds,
              coveredSeconds: hrMetrics.coverageSeconds,
            );
            details['hr_zone_boundaries'] = _heartRateZones(profile);
            details['dominant_hr_zone'] =
                _dominantZoneIndex(hrMetrics.zoneSeconds);
          }
        }

        sessions.add(
          TrainingSession(
            id: 'new_session',
            date: point.dateFrom.toIso8601String().split('T')[0],
            sportId: sportId,
            duration: activeDurationMinutes.toString(),
            effort: 5,
            startTime: _formatClock(point.dateFrom),
            endTime: _formatClock(point.dateTo),
            details: details,
          ),
        );
      }

      return sessions;
    } catch (e) {
      debugPrint("Error fetching workouts: $e");
      return [];
    }
  }

  Future<List<TrainingSession>> _fetchNativeWorkouts(
    UserProfile profile, {
    required int days,
  }) async {
    try {
      final nativeWorkouts =
          await NativeHealthService.getNormalizedWorkouts(days: days);
      if (nativeWorkouts.isEmpty) return [];

      final sessions = <TrainingSession>[];
      for (final raw in _mergeAdjacentNativeWorkouts(nativeWorkouts)) {
        final session = _trainingSessionFromNativeWorkout(raw, profile);
        if (session != null) sessions.add(session);
      }
      return sessions;
    } catch (e) {
      debugPrint('Native workout import unavailable: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _mergeAdjacentNativeWorkouts(
    List<Map<String, dynamic>> workouts,
  ) {
    final sorted =
        workouts.map((workout) => Map<String, dynamic>.from(workout)).toList()
          ..sort((a, b) {
            final aStart = _asInt(a['startTime']) ?? 0;
            final bStart = _asInt(b['startTime']) ?? 0;
            return aStart.compareTo(bStart);
          });

    final merged = <Map<String, dynamic>>[];
    for (final workout in sorted) {
      if (merged.isEmpty ||
          !_shouldMergeNativeWorkoutParts(merged.last, workout)) {
        merged.add(workout);
        continue;
      }

      merged[merged.length - 1] = _mergeNativeWorkoutParts(
        merged.last,
        workout,
      );
    }

    return merged;
  }

  bool _shouldMergeNativeWorkoutParts(
    Map<String, dynamic> previous,
    Map<String, dynamic> current,
  ) {
    final previousEnd = _asInt(previous['endTime']);
    final currentStart = _asInt(current['startTime']);
    if (previousEnd == null || currentStart == null) return false;

    final gapSeconds = ((currentStart - previousEnd) / 1000).round();
    if (gapSeconds < 0 || gapSeconds > 30 * 60) return false;

    final sameSource =
        previous['sourceId']?.toString() == current['sourceId']?.toString();
    final sameActivity = previous['activityType']?.toString() ==
        current['activityType']?.toString();
    if (!sameSource || !sameActivity) return false;

    final previousDuration = _asInt(previous['activeDurationSeconds']) ?? 0;
    final currentDuration = _asInt(current['activeDurationSeconds']) ?? 0;
    return previousDuration >= 60 && currentDuration >= 60;
  }

  Map<String, dynamic> _mergeNativeWorkoutParts(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final start = math.min(
        _asInt(first['startTime']) ?? 0, _asInt(second['startTime']) ?? 0);
    final end = math.max(
      _asInt(first['endTime']) ?? start,
      _asInt(second['endTime']) ?? start,
    );
    final activeSeconds = (_asInt(first['activeDurationSeconds']) ?? 0) +
        (_asInt(second['activeDurationSeconds']) ?? 0);
    final movingSeconds = (_asInt(first['movingDurationSeconds']) ??
            _asInt(first['activeDurationSeconds']) ??
            0) +
        (_asInt(second['movingDurationSeconds']) ??
            _asInt(second['activeDurationSeconds']) ??
            0);
    final firstIds = _asStringList(first['mergedSourceWorkoutIds']);
    final secondIds = _asStringList(second['mergedSourceWorkoutIds']);
    final ids = <String>[
      if (firstIds.isNotEmpty)
        ...firstIds
      else if (first['id'] != null)
        first['id'].toString(),
      if (secondIds.isNotEmpty)
        ...secondIds
      else if (second['id'] != null)
        second['id'].toString(),
    ];
    final hrSamples = <dynamic>[
      if (first['hrSamples'] is List) ...(first['hrSamples'] as List),
      if (second['hrSamples'] is List) ...(second['hrSamples'] as List),
    ];

    return {
      ...first,
      'id': ids.isNotEmpty
          ? '${first['sourceId'] ?? first['sourceName']}-${ids.join('+')}'
          : '${first['sourceId'] ?? first['sourceName']}-$start-$end',
      'startTime': start,
      'endTime': end,
      'totalDurationSeconds': ((end - start) / 1000).round(),
      'activeDurationSeconds': activeSeconds,
      'movingDurationSeconds': movingSeconds,
      'distanceMeters': (_asDouble(first['distanceMeters']) ?? 0) +
          (_asDouble(second['distanceMeters']) ?? 0),
      'energyTotalKcal': (_asDouble(first['energyTotalKcal']) ?? 0) +
          (_asDouble(second['energyTotalKcal']) ?? 0),
      'hrSamples': hrSamples,
      'mergedSourceWorkoutIds': ids,
      'sourcePartCount': (_asInt(first['sourcePartCount']) ??
              firstIds.length.clamp(1, 999)) +
          (_asInt(second['sourcePartCount']) ?? secondIds.length.clamp(1, 999)),
    };
  }

  List<String> _asStringList(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => item.toString()).toList();
  }

  TrainingSession? _trainingSessionFromNativeWorkout(
    Map<String, dynamic> raw,
    UserProfile profile,
  ) {
    final startMs = _asInt(raw['startTime']);
    final endMs = _asInt(raw['endTime']);
    if (startMs == null || endMs == null || endMs <= startMs) return null;

    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    final totalDurationSeconds =
        _asInt(raw['totalDurationSeconds']) ?? _durationSeconds(start, end);
    final activeDurationSeconds =
        _asInt(raw['activeDurationSeconds']) ?? totalDurationSeconds;
    if (_secondsToRoundedMinutes(activeDurationSeconds) < 5) return null;

    final sportId =
        _mapNativeActivityToSportId(raw['activityType']?.toString());
    if (sportId == 'walking') return null;

    final distanceMeters = _asDouble(raw['distanceMeters']) ?? 0;
    final energyKcal = _asDouble(raw['energyTotalKcal']) ?? 0;
    final movingDurationSeconds =
        _asInt(raw['movingDurationSeconds']) ?? activeDurationSeconds;
    final hrSamples = _parseNativeHrSamples(raw['hrSamples']);
    final hrMetrics = _calculateHrMetricsFromSamples(
      hrSamples,
      profile,
      workoutStart: start,
      workoutEnd: end,
    );
    final reliableHr = _isReliableHrMetrics(hrMetrics, activeDurationSeconds);

    final distanceKm = distanceMeters / 1000;
    final details = <String, dynamic>{
      'source': 'health_sync',
      'health_import_version': _healthImportVersion,
      'hr_zone_calculation_version':
          HealthImportNormalizer.heartRateZoneCalculationVersion,
      'source_name': raw['sourceName'],
      'source_id': raw['sourceId'],
      'external_id': raw['id']?.toString() ??
          '${raw['sourceId'] ?? raw['sourceName'] ?? 'native'}-$startMs-$endMs',
      'workout_start_ms': startMs,
      'workout_end_ms': endMs,
      'total_duration_seconds': totalDurationSeconds,
      'active_duration_seconds': activeDurationSeconds,
      'moving_duration_seconds': movingDurationSeconds,
      'total_duration':
          _secondsToRoundedMinutes(totalDurationSeconds).toString(),
      'total_duration_minutes': _secondsToRoundedMinutes(totalDurationSeconds),
      'active_duration':
          _secondsToRoundedMinutes(activeDurationSeconds).toString(),
      'active_duration_minutes':
          _secondsToRoundedMinutes(activeDurationSeconds),
      'duration_source': 'source',
    };
    if (raw['hrSourceId'] != null) {
      details['hr_source_id'] = raw['hrSourceId'].toString();
    }
    final sourceSampleCount = _asInt(raw['hrSampleCount']);
    if (sourceSampleCount != null) {
      details['hr_source_sample_count'] = sourceSampleCount;
    }
    final sourceMaxBpm = _asDouble(raw['hrMaxBpm']);
    if (sourceMaxBpm != null) {
      details['hr_source_max_bpm'] = sourceMaxBpm;
    }
    if (raw['mergedSourceWorkoutIds'] is List) {
      details['merged_source_workout_ids'] = raw['mergedSourceWorkoutIds'];
      details['source_part_count'] = _asInt(raw['sourcePartCount']) ??
          (raw['mergedSourceWorkoutIds'] as List).length;
    }

    if (distanceMeters > 0 &&
        _isPlausibleDistance(distanceMeters, activeDurationSeconds, sportId)) {
      details['distance'] = '${distanceKm.toStringAsFixed(2)} km';
      details['distance_meters'] = distanceMeters.round();
      if (_isRunningSport(sportId)) {
        final paceSecondsPerKm = activeDurationSeconds / distanceKm;
        details['pace'] = '${_formatPace(paceSecondsPerKm)} min/km';
        details['avg_pace_sec_per_km'] = paceSecondsPerKm.round();
        final importedSpeed = _asDouble(raw['avgSpeedKmh']);
        final speedKmh = importedSpeed != null && importedSpeed > 0
            ? importedSpeed
            : distanceKm / (activeDurationSeconds / 3600);
        details['speed'] = '${speedKmh.toStringAsFixed(2)} km/h';
        details['avg_speed_kmh'] = double.parse(speedKmh.toStringAsFixed(2));
      } else if (_isCyclingSport(sportId)) {
        final speedKmh = distanceKm / (activeDurationSeconds / 3600);
        details['speed'] = '${speedKmh.toStringAsFixed(1)} km/h';
        details['avg_speed_kmh'] = double.parse(speedKmh.toStringAsFixed(1));
      }
    }

    final importedSpeedKmh = _asDouble(raw['avgSpeedKmh']);
    if (_isRunningSport(sportId) &&
        distanceMeters <= 0 &&
        importedSpeedKmh != null &&
        importedSpeedKmh > 0) {
      details['speed'] = '${importedSpeedKmh.toStringAsFixed(2)} km/h';
      details['avg_speed_kmh'] =
          double.parse(importedSpeedKmh.toStringAsFixed(2));
    }

    final cadenceSpm = _asDouble(raw['avgCadenceSpm']);
    if (_isRunningSport(sportId) && cadenceSpm != null && cadenceSpm > 0) {
      details['cadence'] = cadenceSpm.round();
      details['avg_cadence_spm'] = double.parse(cadenceSpm.toStringAsFixed(1));
      details['cadence_source'] = 'source';
    }

    final importedLaps = raw['importedLaps'];
    if (importedLaps is List && importedLaps.isNotEmpty) {
      details['imported_laps'] = importedLaps;
    }
    final importedSegments = raw['segments'];
    if (importedSegments is List && importedSegments.isNotEmpty) {
      details['imported_segments'] = importedSegments;
    }

    if (energyKcal > 0) {
      details['calories'] = energyKcal.round();
      details['energy_total_kcal'] = energyKcal.round();
    }

    final elevationMeters = _asDouble(raw['elevationMeters']);
    if (elevationMeters != null && elevationMeters > 0) {
      details['elevation'] = '${elevationMeters.round()} m';
      details['elevation_meters'] = elevationMeters.round();
    }

    details['hr_reliable'] = reliableHr;
    details['hr_sample_count'] = hrMetrics.sampleCount;
    if (reliableHr) {
      details['avg_hr'] = hrMetrics.averageHeartRate;
      details['max_hr'] = hrMetrics.maxHeartRate;
      details['hr_samples'] = _serializeHrSamples(hrMetrics.samples);
      details['hr_coverage_seconds'] = hrMetrics.coverageSeconds;
      details['hr_coverage_minutes'] =
          _secondsToRoundedMinutes(hrMetrics.coverageSeconds);
      details['hr_zones_seconds'] = HealthImportNormalizer.roundedZoneSeconds(
        hrMetrics.zoneSeconds,
        targetSeconds: hrMetrics.coverageSeconds,
      );
      details['hr_zones'] = _zoneMinutesFromSeconds(
        zoneSeconds: hrMetrics.zoneSeconds,
        activeDurationSeconds: activeDurationSeconds,
        coveredSeconds: hrMetrics.coverageSeconds,
      );
      details['hr_zone_boundaries'] = _heartRateZones(profile);
      details['dominant_hr_zone'] = _dominantZoneIndex(hrMetrics.zoneSeconds);
    }

    return TrainingSession(
      id: 'new_session',
      date: start.toIso8601String().split('T')[0],
      sportId: sportId,
      duration: _secondsToRoundedMinutes(activeDurationSeconds).toString(),
      effort: 5,
      startTime: _formatClock(start),
      endTime: _formatClock(end),
      details: details,
    );
  }

  bool _isTrustedWorkoutSource(HealthDataPoint point) {
    final source = '${point.sourceName} ${point.sourceId}'.toLowerCase();
    if (point.type == HealthDataType.WORKOUT &&
        point.recordingMethod != RecordingMethod.manual) {
      return true;
    }

    return source.contains('garmin') ||
        source.contains('strava') ||
        source.contains('polar') ||
        source.contains('suunto') ||
        source.contains('coros') ||
        source.contains('wahoo') ||
        source.contains('trainingpeaks') ||
        source.contains('apple watch') ||
        source.contains('apple') ||
        source.contains('health connect') ||
        source.contains('healthdata') ||
        source.contains('fitness') ||
        source.contains('google fit') ||
        source.contains('shealth') ||
        source.contains('samsung') ||
        source.contains('fitbit') ||
        source.contains('huawei') ||
        source.contains('amazfit') ||
        source.contains('zepp') ||
        source.contains('miband');
  }

  Future<List<HealthDataPoint>> _fetchScopedPoints({
    required HealthDataPoint workout,
    required List<HealthDataType> types,
    required String debugLabel,
    bool preferDenseSamples = false,
  }) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: workout.dateFrom,
        endTime: workout.dateTo,
        types: types,
      );
      return preferDenseSamples
          ? _preferDenseSampleSource(points, workout)
          : _preferWorkoutSource(points, workout);
    } catch (e) {
      debugPrint('Failed to fetch $debugLabel for workout: $e');
      return [];
    }
  }

  List<HealthDataPoint> _preferWorkoutSource(
    List<HealthDataPoint> points,
    HealthDataPoint workout,
  ) {
    if (points.isEmpty) return points;

    final workoutSourceId = workout.sourceId.trim().toLowerCase();
    final workoutSourceName = workout.sourceName.trim().toLowerCase();
    final exact = points.where((point) {
      final sourceId = point.sourceId.trim().toLowerCase();
      final sourceName = point.sourceName.trim().toLowerCase();
      return (workoutSourceId.isNotEmpty && sourceId == workoutSourceId) ||
          (workoutSourceName.isNotEmpty && sourceName == workoutSourceName);
    }).toList();
    if (exact.isNotEmpty) return exact;

    final trusted = points.where(_isTrustedWorkoutSource).toList();
    return trusted.isNotEmpty ? trusted : points;
  }

  List<HealthDataPoint> _preferDenseSampleSource(
    List<HealthDataPoint> points,
    HealthDataPoint workout,
  ) {
    if (points.isEmpty) return points;

    final exact = _exactWorkoutSourcePoints(points, workout);
    // The workout provider's own series is the only one that can match the
    // graph shown by that provider. Mirrored streams may be denser but can be
    // bucketed, averaged or delayed differently.
    if (exact.isNotEmpty) return exact;

    final trusted = points.where(_isTrustedWorkoutSource).toList();
    final pool = trusted.isNotEmpty ? trusted : points;
    return _densestHealthPointGroup(pool).points;
  }

  List<HealthDataPoint> _exactWorkoutSourcePoints(
    List<HealthDataPoint> points,
    HealthDataPoint workout,
  ) {
    final workoutSourceId = workout.sourceId.trim().toLowerCase();
    final workoutSourceName = workout.sourceName.trim().toLowerCase();
    return points.where((point) {
      final sourceId = point.sourceId.trim().toLowerCase();
      final sourceName = point.sourceName.trim().toLowerCase();
      return (workoutSourceId.isNotEmpty && sourceId == workoutSourceId) ||
          (workoutSourceName.isNotEmpty && sourceName == workoutSourceName);
    }).toList();
  }

  _SampleSourceStats _densestHealthPointGroup(List<HealthDataPoint> points) {
    final grouped = <String, List<HealthDataPoint>>{};
    for (final point in points) {
      final key = '${point.sourceId.trim()}|${point.sourceName.trim()}';
      grouped.putIfAbsent(key, () => <HealthDataPoint>[]).add(point);
    }

    return grouped.values.map(_sampleSourceStats).reduce((best, current) {
      if (current.coverageSeconds != best.coverageSeconds) {
        return current.coverageSeconds > best.coverageSeconds ? current : best;
      }
      return current.count > best.count ? current : best;
    });
  }

  _SampleSourceStats _sampleSourceStats(List<HealthDataPoint> points) {
    final sorted = [...points]
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    var coverageSeconds = 0;
    for (var i = 0; i < sorted.length - 1; i++) {
      final gap = _durationSeconds(sorted[i].dateFrom, sorted[i + 1].dateFrom);
      if (gap > 0 && gap <= HealthImportNormalizer.maxContinuousHrGapSeconds) {
        coverageSeconds += gap;
      }
    }

    return _SampleSourceStats(
      points: sorted,
      count: sorted.length,
      coverageSeconds: coverageSeconds,
    );
  }

  List<HealthDataType> _distanceTypesForSport(String sportId) {
    if (Platform.isAndroid) return [HealthDataType.DISTANCE_DELTA];
    if (_isCyclingSport(sportId)) return [HealthDataType.DISTANCE_CYCLING];
    if (_isRunningSport(sportId) || sportId == 'hiking') {
      return [HealthDataType.DISTANCE_WALKING_RUNNING];
    }
    return [];
  }

  bool _isRunningSport(String sportId) {
    return sportId == 'running' ||
        sportId == 'road_running' ||
        sportId == 'trail_running' ||
        sportId == 'track_and_field' ||
        sportId == 'track_field' ||
        sportId == 'running_treadmill';
  }

  bool _isCyclingSport(String sportId) {
    return sportId == 'cycling' ||
        sportId == 'road_cycling' ||
        sportId == 'biking_stationary';
  }

  bool _isPlausibleDistance(
    double distanceMeters,
    int durationSeconds,
    String sportId,
  ) {
    if (distanceMeters <= 0) return false;
    if (durationSeconds <= 0) return false;

    final speedKmh = (distanceMeters / 1000) / (durationSeconds / 3600);
    if (_isRunningSport(sportId)) return speedKmh <= 35;
    if (_isCyclingSport(sportId)) return speedKmh <= 120;
    return speedKmh <= 80;
  }

  int _durationSeconds(DateTime start, DateTime end) {
    return math.max(0, end.difference(start).inSeconds);
  }

  int _secondsToRoundedMinutes(int seconds) {
    if (seconds <= 0) return 0;
    return math.max(1, (seconds / 60).round());
  }

  String _formatClock(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  String _formatPace(double secondsPerKm) {
    final totalSeconds = secondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _externalWorkoutId(HealthDataPoint point, String sportId) {
    if (point.uuid.trim().isNotEmpty) return point.uuid;
    final source = point.sourceId.trim().isNotEmpty
        ? point.sourceId.trim()
        : point.sourceName.trim();
    return '$source-$sportId-${point.dateFrom.millisecondsSinceEpoch}-${point.dateTo.millisecondsSinceEpoch}';
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _mapNativeActivityToSportId(String? type) {
    final normalized =
        (type ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
    switch (normalized) {
      case 'RUNNING':
      case 'RUNNING_TREADMILL':
      case 'TRACK_AND_FIELD':
        return 'running';
      case 'BIKING':
      case 'BIKING_STATIONARY':
      case 'CYCLING':
        return 'cycling';
      case 'WALKING':
      case 'WALKING_TREADMILL':
        return 'walking';
      case 'HIKING':
        return 'hiking';
      case 'SWIMMING':
      case 'SWIMMING_OPEN_WATER':
      case 'SWIMMING_POOL':
        return 'swimming';
      case 'TRADITIONAL_STRENGTH_TRAINING':
      case 'FUNCTIONAL_STRENGTH_TRAINING':
      case 'STRENGTH_TRAINING':
      case 'WEIGHTLIFTING':
        return 'weightlifting';
      case 'HIGH_INTENSITY_INTERVAL_TRAINING':
      case 'CROSS_TRAINING':
      case 'MIXED_CARDIO':
        return 'crossfit';
      case 'YOGA':
      case 'FLEXIBILITY':
      case 'MIND_AND_BODY':
        return 'yoga';
      case 'CORE_TRAINING':
      case 'ELLIPTICAL':
      case 'STAIR_CLIMBING':
      case 'STAIRS':
      case 'STEP_TRAINING':
      case 'PREPARATION_AND_RECOVERY':
      case 'HKWORKOUT_3000':
      case 'OTHER':
        return 'athletic_prep';
      case 'PILATES':
        return 'pilates';
      case 'ROWING':
      case 'ROWING_MACHINE':
        return 'rowing';
      case 'MARTIAL_ARTS':
        return 'martial_arts';
      case 'KICKBOXING':
        return 'kickboxing';
      case 'DOWNHILL_SKIING':
      case 'DOWNHILL_SKI':
      case 'ALPINE_SKIING':
      case 'ALPINE_SKI':
      case 'SNOWBOARDING':
      case 'SKIING':
      case 'SKI':
      case 'SNOW_SPORTS':
      case 'SNOW_SPORT':
      case 'SNOWSPORTS':
        return 'alpine_skiing';
      case 'CROSS_COUNTRY_SKIING':
        return 'cross_country_skiing';
      default:
        return normalized.toLowerCase();
    }
  }

  double _sumNumericValues(
    List<HealthDataPoint> points,
    DateTime workoutStart,
    DateTime workoutEnd,
  ) {
    double total = 0;
    for (final point in points) {
      if (point.value is! NumericHealthValue) continue;

      final value = (point.value as NumericHealthValue).numericValue.toDouble();
      if (value <= 0) continue;

      final overlap = _overlapSeconds(
        point.dateFrom,
        point.dateTo,
        workoutStart,
        workoutEnd,
      );
      if (overlap <= 0) continue;

      final sampleSeconds = _durationSeconds(point.dateFrom, point.dateTo);
      if (sampleSeconds > 0 && overlap < sampleSeconds) {
        total += value * (overlap / sampleSeconds);
      } else {
        total += value;
      }
    }
    return total;
  }

  double? _averageNumericValue(List<HealthDataPoint> points) {
    final values = points
        .where((point) => point.value is NumericHealthValue)
        .map(
          (point) =>
              (point.value as NumericHealthValue).numericValue.toDouble(),
        )
        .where((value) => value > 0)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((left, right) => left + right) / values.length;
  }

  int _durationCoveredByPositiveSamples(
    List<HealthDataPoint> points,
    DateTime workoutStart,
    DateTime workoutEnd,
  ) {
    final intervals = <_TimeInterval>[];
    for (final point in points) {
      if (point.value is! NumericHealthValue) continue;
      final value = (point.value as NumericHealthValue).numericValue.toDouble();
      if (value <= 0) continue;

      final start =
          point.dateFrom.isBefore(workoutStart) ? workoutStart : point.dateFrom;
      final end = point.dateTo.isAfter(workoutEnd) ? workoutEnd : point.dateTo;
      if (end.isAfter(start)) intervals.add(_TimeInterval(start, end));
    }
    return _mergedIntervalSeconds(intervals);
  }

  int _mergedIntervalSeconds(List<_TimeInterval> intervals) {
    if (intervals.isEmpty) return 0;

    intervals.sort((a, b) => a.start.compareTo(b.start));
    var currentStart = intervals.first.start;
    var currentEnd = intervals.first.end;
    var totalSeconds = 0;

    for (final interval in intervals.skip(1)) {
      if (!interval.start.isAfter(currentEnd)) {
        if (interval.end.isAfter(currentEnd)) currentEnd = interval.end;
      } else {
        totalSeconds += _durationSeconds(currentStart, currentEnd);
        currentStart = interval.start;
        currentEnd = interval.end;
      }
    }

    totalSeconds += _durationSeconds(currentStart, currentEnd);
    return totalSeconds;
  }

  int _overlapSeconds(
    DateTime sampleStart,
    DateTime sampleEnd,
    DateTime workoutStart,
    DateTime workoutEnd,
  ) {
    final start =
        sampleStart.isAfter(workoutStart) ? sampleStart : workoutStart;
    final end = sampleEnd.isBefore(workoutEnd) ? sampleEnd : workoutEnd;
    return end.isAfter(start) ? end.difference(start).inSeconds : 0;
  }

  Future<double?> _fetchEstimatedElevationMeters(
    HealthDataPoint workout,
    String sportId,
  ) async {
    if (!Platform.isIOS) return null;
    if (!_isRunningSport(sportId) &&
        !_isCyclingSport(sportId) &&
        sportId != 'hiking') {
      return null;
    }

    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: workout.dateFrom,
        endTime: workout.dateTo,
        types: [HealthDataType.FLIGHTS_CLIMBED],
      );
      final scoped = _preferWorkoutSource(points, workout);
      final flights =
          _sumNumericValues(scoped, workout.dateFrom, workout.dateTo);
      if (flights <= 0) return null;

      // HealthKit exposes flights climbed through the package, not route ascent.
      return flights * 3.048;
    } catch (e) {
      debugPrint('Failed to fetch elevation estimate for workout: $e');
      return null;
    }
  }

  HeartRateMetrics _calculateHrMetrics(
    List<HealthDataPoint> points,
    UserProfile profile, {
    DateTime? workoutStart,
    DateTime? workoutEnd,
  }) {
    final samples = _cleanHeartRateSamples(points);
    return _calculateHrMetricsFromSamples(
      samples,
      profile,
      workoutStart: workoutStart,
      workoutEnd: workoutEnd,
    );
  }

  HeartRateMetrics _calculateHrMetricsFromSamples(
    List<HeartRateSample> samples,
    UserProfile profile, {
    DateTime? workoutStart,
    DateTime? workoutEnd,
  }) {
    return HealthImportNormalizer.calculateHeartRateMetrics(
      samples: samples,
      zones: _heartRateZones(profile),
      workoutStart: workoutStart,
      workoutEnd: workoutEnd,
    );
  }

  List<HeartRateSample> _cleanHeartRateSamples(List<HealthDataPoint> points) {
    final rawSamples = <HeartRateSample>[];
    for (final point in points) {
      if (point.value is! NumericHealthValue) continue;

      final bpm = (point.value as NumericHealthValue).numericValue.toDouble();
      rawSamples.add(HeartRateSample(point.dateFrom, bpm));
    }

    return HealthImportNormalizer.cleanHeartRateSamples(rawSamples);
  }

  List<HeartRateSample> _parseNativeHrSamples(dynamic value) {
    if (value is! List) return [];

    final samples = <HeartRateSample>[];
    for (final item in value) {
      if (item is! Map) continue;
      final timeMs = _asInt(item['time']);
      final bpm = _asDouble(item['bpm']);
      if (timeMs == null || bpm == null) continue;
      samples.add(HeartRateSample(
        DateTime.fromMillisecondsSinceEpoch(timeMs),
        bpm,
      ));
    }
    return HealthImportNormalizer.cleanHeartRateSamples(samples);
  }

  List<Map<String, dynamic>> _serializeHrSamples(
      List<HeartRateSample> samples) {
    return HealthImportNormalizer.serializeHeartRateSamples(samples);
  }

  bool _isReliableHrMetrics(
    HeartRateMetrics metrics,
    int activeDurationSeconds,
  ) {
    return HealthImportNormalizer.isReliableHeartRate(
      metrics,
      activeDurationSeconds,
    );
  }

  int _dominantZoneIndex(List<double> zoneSeconds) {
    return HealthImportNormalizer.dominantZoneIndex(zoneSeconds);
  }

  List<Map<String, int>> _heartRateZones(UserProfile profile) {
    return HealthImportNormalizer.resolveHeartRateZones(
      mode: profile.hrZoneMode,
      customZones: profile.customHrZones,
      maxHeartRate: profile.maxHr,
    );
  }

  List<int> _zoneMinutesFromSeconds({
    required List<double> zoneSeconds,
    required int activeDurationSeconds,
    required int coveredSeconds,
  }) {
    return HealthImportNormalizer.zoneMinutesFromSeconds(
      zoneSeconds: zoneSeconds,
      activeDurationSeconds: activeDurationSeconds,
      coveredSeconds: coveredSeconds,
    );
  }

  String _mapHealthActivityToSportId(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.RUNNING:
      case HealthWorkoutActivityType.RUNNING_TREADMILL:
      case HealthWorkoutActivityType.TRACK_AND_FIELD:
        return 'running';
      case HealthWorkoutActivityType.BIKING:
      case HealthWorkoutActivityType.BIKING_STATIONARY:
        return 'cycling';
      case HealthWorkoutActivityType.SWIMMING:
        return 'swimming';
      case HealthWorkoutActivityType.WALKING:
        return 'walking';
      case HealthWorkoutActivityType.HIKING:
        return 'hiking';
      case HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING:
      case HealthWorkoutActivityType.WEIGHTLIFTING:
        return 'weightlifting';
      case HealthWorkoutActivityType.CORE_TRAINING:
      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
      case HealthWorkoutActivityType.CROSS_TRAINING:
        return 'crossfit';
      case HealthWorkoutActivityType.FLEXIBILITY:
      case HealthWorkoutActivityType.YOGA:
        return 'yoga';
      case HealthWorkoutActivityType.SOCCER:
        return 'soccer';
      case HealthWorkoutActivityType.BASKETBALL:
        return 'basketball';
      case HealthWorkoutActivityType.TENNIS:
        return 'tennis';
      case HealthWorkoutActivityType.PILATES:
        return 'pilates';
      case HealthWorkoutActivityType.ROWING:
        return 'rowing';
      case HealthWorkoutActivityType.DOWNHILL_SKIING:
      case HealthWorkoutActivityType.SNOWBOARDING:
        return 'alpine_skiing';
      case HealthWorkoutActivityType.CROSS_COUNTRY_SKIING:
        return 'cross_country_skiing';
      default:
        // Use the exact enum name, lowercase, so if it's "BOXING" it becomes "boxing".
        // This will often match our activity_select.dart IDs, or gracefully fallback
        // to being displayed as a capitalized string in the UI.
        return type.name.toLowerCase();
    }
  }

  Future<Map<String, List<BodyMetricLog>>> syncDailyHealthMetrics(
      {int days = 7, bool requestPermissions = true}) async {
    Map<String, List<BodyMetricLog>> results = {
      'resting_hr': [],
      'hrv_sdnn': [],
      'hrv_rmssd': [],
      'weight': [],
      'spo2': [],
      'resp': [],
      'wrist_temp_c': [],
      'skin_temp_delta_c': [],
    };
    try {
      await _health.configure();
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      if (requestPermissions) {
        try {
          await _ensureDailyMetricPermissions();
        } catch (e) {
          // Reads below are isolated per stream; one optional permission must
          // not suppress RHR/HRV or the other recovery inputs.
          debugPrint('Daily metric permission check was partial: $e');
        }
      }

      // Fetch Resting Heart Rate
      List<HealthDataPoint> rhrData = [];
      try {
        rhrData = await _health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: now,
          types: [HealthDataType.RESTING_HEART_RATE],
        );
        debugPrint(
            'Health sync: RESTING_HEART_RATE returned ${rhrData.length} points');
      } catch (e) {
        debugPrint('Failed to fetch RHR: $e');
      }

      // Fetch HRV (SDNN for iOS, RMSSD for Android)
      List<HealthDataPoint> hrvData = [];
      try {
        hrvData = await _health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: now,
          types: [
            Platform.isIOS
                ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
                : HealthDataType.HEART_RATE_VARIABILITY_RMSSD
          ],
        );
        debugPrint('Health sync: HRV returned ${hrvData.length} points');
      } catch (e) {
        debugPrint('Failed to fetch HRV: $e');
      }

      // Fetch Weight
      List<HealthDataPoint> weightData = [];
      try {
        weightData = await _health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: now,
          types: [HealthDataType.WEIGHT],
        );
        debugPrint('Health sync: WEIGHT returned ${weightData.length} points');
      } catch (e) {
        debugPrint('Failed to fetch Weight: $e');
      }

      // Fetch optional recovery metrics independently. Health Connect
      // permissions are granular, so one denied metric must not hide the rest.
      final spo2Data = await _fetchDailyMetricPoints(
        startDate: startDate,
        endDate: now,
        type: HealthDataType.BLOOD_OXYGEN,
        label: 'SpO2',
      );
      final respData = await _fetchDailyMetricPoints(
        startDate: startDate,
        endDate: now,
        type: HealthDataType.RESPIRATORY_RATE,
        label: 'Respiratory Rate',
      );
      final skinTemperatureType = Platform.isIOS
          ? HealthDataType.SLEEP_WRIST_TEMPERATURE
          : HealthDataType.SKIN_TEMPERATURE;
      final tempData = await _fetchDailyMetricPoints(
        startDate: startDate,
        endDate: now,
        type: skinTemperatureType,
        label: 'Night skin/wrist temperature',
      );

      // Helper function to process daily averages
      void processAverages(List<HealthDataPoint> data,
          List<HealthDataType> types, String mapKey) {
        Map<String, List<double>> dailyMap = {};
        for (var point in data) {
          if (types.contains(point.type) && point.value is NumericHealthValue) {
            final val = (point.value as NumericHealthValue).numericValue;
            final dateStr = point.dateFrom.toIso8601String().split('T')[0];
            dailyMap.putIfAbsent(dateStr, () => []).add(val.toDouble());
          }
        }
        dailyMap.forEach((dateStr, values) {
          final avg = values.reduce((a, b) => a + b) / values.length;
          results[mapKey]!.add(BodyMetricLog(
            id: '${mapKey}_$dateStr', // Temp ID
            date: dateStr,
            type: mapKey,
            value: avg,
          ));
        });
      }

      processAverages(
          rhrData, [HealthDataType.RESTING_HEART_RATE], 'resting_hr');
      processAverages(weightData, [HealthDataType.WEIGHT], 'weight');
      processAverages(spo2Data, [HealthDataType.BLOOD_OXYGEN], 'spo2');
      processAverages(respData, [HealthDataType.RESPIRATORY_RATE], 'resp');
      if (Platform.isIOS) {
        processAverages(
          tempData,
          [HealthDataType.SLEEP_WRIST_TEMPERATURE],
          'wrist_temp_c',
        );
      } else {
        final dailySkinTemperature = <String, List<double>>{};
        for (final point in tempData) {
          final value = point.value;
          final delta = value is SkinTemperatureHealthValue
              ? value.temperatureDelta
              : value is NumericHealthValue
                  ? value.numericValue.toDouble()
                  : null;
          if (delta == null || !delta.isFinite) continue;
          final dateStr = point.dateFrom.toIso8601String().split('T')[0];
          dailySkinTemperature.putIfAbsent(dateStr, () => []).add(delta);
        }
        dailySkinTemperature.forEach((dateStr, values) {
          results['skin_temp_delta_c']!.add(BodyMetricLog(
            id: 'skin_temp_delta_c_$dateStr',
            date: dateStr,
            type: 'skin_temp_delta_c',
            value: values.reduce((a, b) => a + b) / values.length,
          ));
        });
      }

      // Process HRV (Only nighttime/morning: 00:00 to 08:00)
      Map<String, List<double>> dailyHrv = {};
      for (var point in hrvData) {
        if (point.value is NumericHealthValue) {
          final val = (point.value as NumericHealthValue).numericValue;
          final hour = point.dateFrom.hour;
          if (hour >= 0 && hour <= 8) {
            final dateStr = point.dateFrom.toIso8601String().split('T')[0];
            dailyHrv.putIfAbsent(dateStr, () => []).add(val.toDouble());
          }
        }
      }

      dailyHrv.forEach((dateStr, values) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        final metricKey = Platform.isIOS ? 'hrv_sdnn' : 'hrv_rmssd';
        results[metricKey]!.add(BodyMetricLog(
          id: '${metricKey}_$dateStr',
          date: dateStr,
          type: metricKey,
          value: avg,
        ));
      });

      return results;
    } catch (e) {
      debugPrint("Error syncing daily health metrics: $e");
      return results;
    }
  }

  Future<void> _ensureDailyMetricPermissions() async {
    final metricTypes = <HealthDataType>[
      HealthDataType.RESTING_HEART_RATE,
      Platform.isIOS
          ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
          : HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      HealthDataType.WEIGHT,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.RESPIRATORY_RATE,
      Platform.isIOS
          ? HealthDataType.SLEEP_WRIST_TEMPERATURE
          : HealthDataType.SKIN_TEMPERATURE,
    ].where(_health.isDataTypeAvailable).toList();
    if (Platform.isAndroid &&
        metricTypes.contains(HealthDataType.SKIN_TEMPERATURE)) {
      try {
        if (!await _health.isSkinTemperatureAvailable()) {
          metricTypes.remove(HealthDataType.SKIN_TEMPERATURE);
        }
      } catch (e) {
        metricTypes.remove(HealthDataType.SKIN_TEMPERATURE);
        debugPrint('Skin temperature availability check failed: $e');
      }
    }
    if (metricTypes.isEmpty) return;
    final permissions = metricTypes.map((_) => HealthDataAccess.READ).toList();

    final hasPermissions =
        await _health.hasPermissions(metricTypes, permissions: permissions) ??
            false;
    if (!hasPermissions) {
      await _health.requestAuthorization(metricTypes, permissions: permissions);
    }
  }

  Future<List<HealthDataPoint>> _fetchDailyMetricPoints({
    required DateTime startDate,
    required DateTime endDate,
    required HealthDataType type,
    required String label,
  }) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [type],
      );
      debugPrint('Health sync: $label returned ${points.length} points');
      return points;
    } catch (e) {
      debugPrint('Failed to fetch $label: $e');
      return [];
    }
  }
}

class _TimeInterval {
  final DateTime start;
  final DateTime end;

  const _TimeInterval(this.start, this.end);
}

class _SampleSourceStats {
  final List<HealthDataPoint> points;
  final int count;
  final int coverageSeconds;

  const _SampleSourceStats({
    required this.points,
    required this.count,
    required this.coverageSeconds,
  });
}
