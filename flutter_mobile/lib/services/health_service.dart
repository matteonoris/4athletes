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

  // Define the types we want to access
  final List<HealthDataType> _dataTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.WEIGHT,
  ];

  final List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

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

  Future<List<TrainingSession>> fetchRecentWorkouts({int days = 7}) async {
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
          
          // Calculate duration in minutes
          int durationMinutes = point.dateTo.difference(point.dateFrom).inMinutes;
          if (durationMinutes <= 0) continue;

          // Format start and end time
          String startTime = '${point.dateFrom.hour.toString().padLeft(2, '0')}:${point.dateFrom.minute.toString().padLeft(2, '0')}';
          String endTime = '${point.dateTo.hour.toString().padLeft(2, '0')}:${point.dateTo.minute.toString().padLeft(2, '0')}';

          // Extract metrics if available
          Map<String, dynamic> details = {
            'source': 'health_sync',
            'external_id': point.uuid,
          };
          
          if (workout.totalEnergyBurned != null) {
            details['calories'] = workout.totalEnergyBurned;
          }
          if (workout.totalDistance != null) {
            details['distance'] = '${(workout.totalDistance! / 1000).toStringAsFixed(2)} km';
          }

          sessions.add(
            TrainingSession(
              id: 'new_session', // Will be replaced by UUID on insert
              date: point.dateFrom.toIso8601String().split('T')[0],
              sportId: sportId,
              duration: durationMinutes.toString(),
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
      case HealthWorkoutActivityType.SOCCER:
        return 'soccer';
      case HealthWorkoutActivityType.BASKETBALL:
        return 'basketball';
      case HealthWorkoutActivityType.TENNIS:
        return 'tennis';
      case HealthWorkoutActivityType.YOGA:
        return 'yoga';
      case HealthWorkoutActivityType.PILATES:
        return 'pilates';
      case HealthWorkoutActivityType.CROSS_TRAINING:
        return 'crossfit';
      case HealthWorkoutActivityType.ROWING:
        return 'rowing';
      case HealthWorkoutActivityType.DOWNHILL_SKIING:
      case HealthWorkoutActivityType.SNOWBOARDING:
        return 'alpine_skiing';
      case HealthWorkoutActivityType.CROSS_COUNTRY_SKIING:
        return 'cross_country_skiing';
      default:
        return 'other'; // Fallback
    }
  }

  Future<Map<String, List<BodyMetricLog>>> syncDailyHealthMetrics({int days = 7}) async {
    Map<String, List<BodyMetricLog>> results = {'resting_hr': [], 'hrv': [], 'weight': []};
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      // Fetch Resting Heart Rate
      List<HealthDataPoint> rhrData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: now,
        types: [HealthDataType.RESTING_HEART_RATE],
      );

      // Fetch HRV (SDNN)
      List<HealthDataPoint> hrvData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: now,
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
      );

      // Fetch Weight
      List<HealthDataPoint> weightData = await _health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: now,
        types: [HealthDataType.WEIGHT],
      );

      // Process RHR (Apple Health gives one per day usually, but we group by day)
      Map<String, List<double>> dailyRhr = {};
      for (var point in rhrData) {
        if (point.value is NumericHealthValue) {
          final val = (point.value as NumericHealthValue).numericValue;
          final dateStr = point.dateFrom.toIso8601String().split('T')[0];
          dailyRhr.putIfAbsent(dateStr, () => []).add(val.toDouble());
        }
      }

      dailyRhr.forEach((dateStr, values) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        results['resting_hr']!.add(
          BodyMetricLog(
            id: 'rhr_$dateStr', // Temp ID
            date: dateStr,
            type: 'resting_hr',
            value: avg,
          )
        );
      });

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

      // Process Weight
      Map<String, List<double>> dailyWeight = {};
      for (var point in weightData) {
        if (point.value is NumericHealthValue) {
          final val = (point.value as NumericHealthValue).numericValue;
          final dateStr = point.dateFrom.toIso8601String().split('T')[0];
          dailyWeight.putIfAbsent(dateStr, () => []).add(val.toDouble());
        }
      }

      dailyWeight.forEach((dateStr, values) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        results['weight']!.add(
          BodyMetricLog(
            id: 'weight_$dateStr', // Temp ID
            date: dateStr,
            type: 'weight',
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
