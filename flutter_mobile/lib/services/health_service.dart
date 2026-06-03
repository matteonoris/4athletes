import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();

  final List<HealthDataType> _dataTypes = Platform.isIOS ? [
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.WEIGHT,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.DISTANCE_CYCLING,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BODY_TEMPERATURE,
  ] : [
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.WEIGHT,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BODY_TEMPERATURE,
  ];

  late final List<HealthDataAccess> _permissions = _dataTypes.map((e) => HealthDataAccess.READ).toList();

  Future<bool> requestPermissions() async {
    try {
      // Configure health plugin before use
      await _health.configure();

      // On Android, check the status of Google Health Connect SDK
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          debugPrint("Health Connect is not installed or outdated. Directing user to Play Store...");
          await _health.installHealthConnect();
          return false;
        } else if (status == HealthConnectSdkStatus.sdkUnavailable) {
          debugPrint("Health Connect is unavailable on this device.");
          return false;
        }

        // Request Activity Recognition FIRST on Android
        final activityStatus = await Permission.activityRecognition.request();
        if (activityStatus.isDenied || activityStatus.isPermanentlyDenied) {
          debugPrint("Activity Recognition permission denied.");
          return false;
        }
      }

      // Request permissions from Health Connect / Apple Health
      bool hasPermissions = await _health.hasPermissions(_dataTypes, permissions: _permissions) ?? false;
      
      if (!hasPermissions) {
        hasPermissions = await _health.requestAuthorization(_dataTypes, permissions: _permissions);
      }
      
      return hasPermissions;
    } catch (e) {
      debugPrint("Error requesting health permissions: $e");
      return false;
    }
  }

  Future<List<TrainingSession>> fetchRecentWorkouts(UserProfile profile, {int days = 7}) async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(Duration(days: days));

      // Fetch workouts
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      // Convert HealthDataPoint to TrainingSession
      List<TrainingSession> sessions = [];
      for (var point in healthData) {
        if (point.value is WorkoutHealthValue) {
          final workout = point.value as WorkoutHealthValue;
          
          // Map HealthWorkoutActivityType to our SportId
          String sportId = _mapHealthActivityToSportId(workout.workoutActivityType);
          
          // Exclude walking/camminate entirely as requested by the user
          if (sportId == 'walking') {
            continue;
          }
          
          // Calculate duration in minutes - must be at least 15 minutes
          int durationMinutes = point.dateTo.difference(point.dateFrom).inMinutes;
          if (durationMinutes < 15) continue;

          // Filter out passive activities by whitelisting trusted active sources and platforms
          String sourceName = point.sourceName.toLowerCase();
          bool isManual = sourceName.contains('garmin') ||
                          sourceName.contains('strava') ||
                          sourceName.contains('polar') ||
                          sourceName.contains('suunto') ||
                          sourceName.contains('coros') ||
                          sourceName.contains('wahoo') ||
                          sourceName.contains('trainingpeaks') ||
                          sourceName.contains('apple watch') ||
                          sourceName.contains('apple') || // Native iOS Health app
                          sourceName.contains('health connect') ||
                          sourceName.contains('healthdata') || // Google Health Connect package name
                          sourceName.contains('fitness') || // Google Fit package name
                          sourceName.contains('google fit') ||
                          sourceName.contains('shealth') || // Samsung Health package name
                          sourceName.contains('samsung') ||
                          sourceName.contains('fitbit') ||
                          sourceName.contains('huawei') ||
                          sourceName.contains('amazfit') ||
                          sourceName.contains('zepp') ||
                          sourceName.contains('miband');

          if (!isManual) {
            continue;
          }

          // Format start and end time
          String startTime = '${point.dateFrom.hour.toString().padLeft(2, '0')}:${point.dateFrom.minute.toString().padLeft(2, '0')}';
          String endTime = '${point.dateTo.hour.toString().padLeft(2, '0')}:${point.dateTo.minute.toString().padLeft(2, '0')}';

          // Extract metrics if available
          Map<String, dynamic> details = {
            'source': 'health_sync',
            'external_id': point.uuid,
          };

          // Filter fallbacks by exact workout source name to prevent combining daily activity
          final workoutSource = point.sourceName;
          
          if (workout.totalEnergyBurned != null) {
            details['calories'] = workout.totalEnergyBurned;
          } else {
             try {
                List<HealthDataPoint> calData = await _health.getHealthDataFromTypes(
                  startTime: point.dateFrom,
                  endTime: point.dateTo,
                  types: [HealthDataType.ACTIVE_ENERGY_BURNED],
                );
                
                // Filter by exact sourceName of the workout session to prevent phone sensor inflation
                final filteredCal = calData.where((c) => c.sourceName == workoutSource).toList();
                final calToProcess = filteredCal.isNotEmpty ? filteredCal : calData;

                double totalCals = 0;
                for (var c in calToProcess) {
                   if (c.value is NumericHealthValue) totalCals += (c.value as NumericHealthValue).numericValue;
                }
                if (totalCals > 0) details['calories'] = totalCals.round();
             } catch (e) {
                debugPrint('Failed to fetch Cals for workout: $e');
             }
          }
          
          double distanceKm = 0.0;
          if (workout.totalDistance != null && workout.totalDistance! > 0) {
            distanceKm = workout.totalDistance! / 1000;
            details['distance'] = '${distanceKm.toStringAsFixed(2)} km';
          } else {
             try {
                List<HealthDataPoint> distData = await _health.getHealthDataFromTypes(
                  startTime: point.dateFrom,
                  endTime: point.dateTo,
                  types: Platform.isIOS
                    ? [HealthDataType.DISTANCE_WALKING_RUNNING, HealthDataType.DISTANCE_CYCLING]
                    : [HealthDataType.DISTANCE_DELTA],
                );

                // Filter by exact sourceName of the workout session to prevent phone step inflation
                final filteredDist = distData.where((d) => d.sourceName == workoutSource).toList();
                final distToProcess = filteredDist.isNotEmpty ? filteredDist : distData;

                double totalDist = 0;
                for (var d in distToProcess) {
                   if (d.value is NumericHealthValue) totalDist += (d.value as NumericHealthValue).numericValue;
                }
                if (totalDist > 0) {
                   distanceKm = totalDist / 1000;
                   details['distance'] = '${distanceKm.toStringAsFixed(2)} km';
                }
             } catch (e) {
                debugPrint('Failed to fetch Dist for workout: $e');
             }
          }

          // Fetch explicit HR for this workout (exact time window, no buffer)
          List<HealthDataPoint> workoutHr = [];
          try {
            workoutHr = await _health.getHealthDataFromTypes(
              startTime: point.dateFrom,
              endTime: point.dateTo,
              types: [HealthDataType.HEART_RATE],
            );
          } catch (e) {
            debugPrint('Failed to fetch HR for workout: $e');
          }

          // Filter by exact sourceName of the workout session (with fallback if empty)
          // Fallback ensures workouts synced via Strava/Garmin preserve their heart rate points
          List<HealthDataPoint> filteredHr = workoutHr.where((hr) => hr.sourceName == workoutSource).toList();
          if (filteredHr.isEmpty) {
            filteredHr = workoutHr;
          }

          // Use exact duration from device, without manual gap recalculation
          int activeDurationMinutes = durationMinutes;
          
          // Calculate Pace / Speed based on activeDurationMinutes
          if (distanceKm > 0) {
            if (sportId == 'running' || sportId == 'walking' || sportId == 'trail_running') {
               double paceDecimal = activeDurationMinutes / distanceKm;
               int paceMins = paceDecimal.floor();
               int paceSecs = ((paceDecimal - paceMins) * 60).round();
               details['pace'] = '$paceMins:${paceSecs.toString().padLeft(2, '0')} min/km';
            } else {
               double speed = distanceKm / (activeDurationMinutes / 60);
               details['speed'] = '${speed.toStringAsFixed(1)} km/h';
            }
          }

          if (filteredHr.isNotEmpty) {
            final sortedHr = List<HealthDataPoint>.from(filteredHr)
              ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

            double totalWeightedHr = 0;
            double totalWeightSeconds = 0;
            
            for (int i = 0; i < sortedHr.length - 1; i++) {
              final gap = sortedHr[i + 1].dateFrom.difference(sortedHr[i].dateFrom).inSeconds;
              // A threshold of 60 seconds handles reasonable gaps while weighting time properly
              if (gap <= 60 && gap > 0) {
                 double v1 = (sortedHr[i].value as NumericHealthValue).numericValue.toDouble();
                 double v2 = (sortedHr[i+1].value as NumericHealthValue).numericValue.toDouble();
                 double avgGapHr = (v1 + v2) / 2;
                 totalWeightedHr += avgGapHr * gap;
                 totalWeightSeconds += gap;
              }
            }
            
            int avgHr;
            if (totalWeightSeconds > 0) {
               avgHr = (totalWeightedHr / totalWeightSeconds).round();
            } else {
               // Fallback to simple mean if only 1 point or gaps are all > 60s
               double totalHr = 0;
               for (var hr in filteredHr) {
                  if (hr.value is NumericHealthValue) {
                     totalHr += (hr.value as NumericHealthValue).numericValue;
                  }
               }
               avgHr = (totalHr / filteredHr.length).round();
            }
            details['avg_hr'] = avgHr;

            // Define zone boundaries
            List<Map<String, int>> zones = [];
            if (profile.hrZoneMode == 'custom' && profile.customHrZones != null && profile.customHrZones!.length == 5) {
               zones = profile.customHrZones!;
            } else {
               // Karvonen Formula
               int restingHr = 50; 
               int reserve = profile.maxHr - restingHr;
               zones = [
                 {'min': (reserve * 0.50 + restingHr).round(), 'max': (reserve * 0.60 + restingHr).round()},
                 {'min': (reserve * 0.60 + restingHr).round(), 'max': (reserve * 0.70 + restingHr).round()},
                 {'min': (reserve * 0.70 + restingHr).round(), 'max': (reserve * 0.80 + restingHr).round()},
                 {'min': (reserve * 0.80 + restingHr).round(), 'max': (reserve * 0.90 + restingHr).round()},
                 {'min': (reserve * 0.90 + restingHr).round(), 'max': profile.maxHr},
               ];
            }

            // Calculate time in zones
            List<int> zoneCounts = [0, 0, 0, 0, 0];
            for (var hr in filteredHr) {
               if (hr.value is NumericHealthValue) {
                  int val = (hr.value as NumericHealthValue).numericValue.round();
                  // Z5 has only a minimum limit: all heartbeats >= min go to Z5
                  if (val >= zones[4]['min']!) {
                     zoneCounts[4]++;
                  } else {
                     // For zones 1 to 4: check if it falls within the min-max boundaries
                     for (int i = 3; i >= 0; i--) {
                        if (val >= zones[i]['min']! && val <= zones[i]['max']!) {
                           zoneCounts[i]++;
                           break;
                        }
                     }
                  }
               }
            }

            // Scale zone minutes so they sum up to exactly activeDurationMinutes.
            // Using the sum of counted points in Z1-Z5 as the divisor ensures 
            // the heart rate zone chart perfectly accounts for the entire active workout duration.
            int totalPoints = zoneCounts.reduce((a, b) => a + b);
            if (totalPoints == 0) totalPoints = filteredHr.length; // fallback
            
            List<int> zoneMins = zoneCounts.map((count) => ((count / totalPoints) * activeDurationMinutes).round()).toList();
            details['hr_zones'] = zoneMins;
          }

          sessions.add(
            TrainingSession(
              id: 'new_session', // Will be replaced by UUID on insert
              date: point.dateFrom.toIso8601String().split('T')[0],
              sportId: sportId,
              duration: activeDurationMinutes.toString(),
              effort: 5, // Default effort
              startTime: startTime,
              endTime: endTime,
              details: details,
            )
          );
        }
      }

      return sessions;
    } catch (e) {
      debugPrint("Error fetching workouts: $e");
      return [];
    }
  }

  String _mapHealthActivityToSportId(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.RUNNING:
        return 'running';
      case HealthWorkoutActivityType.BIKING:
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

  Future<Map<String, List<BodyMetricLog>>> syncDailyHealthMetrics({int days = 7}) async {
    Map<String, List<BodyMetricLog>> results = {
      'resting_hr': [], 
      'hrv': [], 
      'weight': [],
      'spo2': [],
      'resp': [],
      'temp': []
    };
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Fetch Resting Heart Rate
      List<HealthDataPoint> rhrData = [];
      try {
        rhrData = await _health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: now,
          types: [HealthDataType.RESTING_HEART_RATE],
        );
      } catch (e) {
        debugPrint('Failed to fetch RHR: $e');
      }

      // Fetch HRV (SDNN for iOS, RMSSD for Android)
      List<HealthDataPoint> hrvData = [];
      try {
        hrvData = await _health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: now,
          types: [Platform.isIOS ? HealthDataType.HEART_RATE_VARIABILITY_SDNN : HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
        );
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
      } catch (e) {
        debugPrint('Failed to fetch Weight: $e');
      }

      // Fetch SpO2, Resp, Temp
      List<HealthDataPoint> extraData = [];
      try {
        extraData = await _health.getHealthDataFromTypes(
          startTime: startDate,
          endTime: now,
          types: [HealthDataType.BLOOD_OXYGEN, HealthDataType.RESPIRATORY_RATE, HealthDataType.BODY_TEMPERATURE],
        );
      } catch (e) {
        debugPrint('Failed to fetch Extra Metrics: $e');
      }

      // Helper function to process daily averages
      void _processAverages(List<HealthDataPoint> data, List<HealthDataType> types, String mapKey) {
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
          results[mapKey]!.add(
            BodyMetricLog(
              id: '${mapKey}_$dateStr', // Temp ID
              date: dateStr,
              type: mapKey,
              value: avg,
            )
          );
        });
      }

      _processAverages(rhrData, [HealthDataType.RESTING_HEART_RATE], 'resting_hr');
      _processAverages(weightData, [HealthDataType.WEIGHT], 'weight');
      _processAverages(extraData, [HealthDataType.BLOOD_OXYGEN], 'spo2');
      _processAverages(extraData, [HealthDataType.RESPIRATORY_RATE], 'resp');
      _processAverages(extraData, [HealthDataType.BODY_TEMPERATURE], 'temp');

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
        results['hrv']!.add(
          BodyMetricLog(
            id: 'hrv_$dateStr', // Temp ID
            date: dateStr,
            type: 'hrv',
            value: avg,
          )
        );
      });

      return results;
    } catch (e) {
      debugPrint("Error syncing daily health metrics: $e");
      return results;
    }
  }
}
