import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class TrainingReminderNotificationService {
  TrainingReminderNotificationService._();

  static final TrainingReminderNotificationService instance =
      TrainingReminderNotificationService._();

  static const int _dailyTrainingReminderId = 2100;
  static const String _channelId = 'daily_training_reminders';
  static const String _channelName = 'Promemoria allenamenti';
  static const String _channelDescription =
      'Reminder serali per registrare gli allenamenti svolti nella giornata.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('ic_stat_4athletes');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> syncForProfile(UserProfile? profile) async {
    if (profile?.role == 'athlete' && profile?.notificationsEnabled == true) {
      await scheduleDailyTrainingReminder();
      return;
    }

    await cancelDailyTrainingReminder();
  }

  Future<bool> requestPermissionAndSchedule() async {
    await initialize();
    final granted = await requestPermission();
    if (!granted) {
      await cancelDailyTrainingReminder();
      return false;
    }

    await scheduleDailyTrainingReminder();
    return true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? true;
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (Platform.isMacOS) {
      final macOSPlugin = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      return await macOSPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  Future<bool> areNotificationsAllowed() async {
    if (kIsWeb) return false;
    await initialize();

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? true;
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return (await iosPlugin?.checkPermissions())?.isEnabled ?? false;
    }

    if (Platform.isMacOS) {
      final macOSPlugin = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      return (await macOSPlugin?.checkPermissions())?.isEnabled ?? false;
    }

    return false;
  }

  Future<void> scheduleDailyTrainingReminder() async {
    if (kIsWeb) return;
    await initialize();

    await _plugin.cancel(_dailyTrainingReminderId);
    await _plugin.zonedSchedule(
      _dailyTrainingReminderId,
      'Allenamento di oggi?',
      'Registralo ora: ci vogliono solo 30 secondi.',
      _nextInstanceOfNinePM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_training_reminder',
    );
  }

  Future<void> cancelDailyTrainingReminder() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(_dailyTrainingReminderId);
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb || Platform.isLinux) return;

    tz.initializeTimeZones();
    if (Platform.isWindows) return;

    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  tz.TZDateTime _nextInstanceOfNinePM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
