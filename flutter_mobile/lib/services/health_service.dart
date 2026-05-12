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
  ];

  final List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Request specific activity recognition permission for Android
        final status = await Permission.activityRecognition.request();
        if (status.isDenied) return false;
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
      default:
        return 'other'; // Fallback
    }
  }
}
