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
  static const int _weightReminderBaseId = 2200;
  static const int _weightReminderScheduleDays = 30;
  static const String _channelId = 'daily_training_reminders';
  static const String _channelName = 'Promemoria allenamenti';
  static const String _channelDescription =
      'Reminder serali per registrare gli allenamenti svolti nella giornata.';
  static const String _weightChannelId = 'weight_measurement_reminders';
  static const String _weightChannelName = 'Promemoria peso';
  static const String _weightChannelDescription =
      'Reminder mattutini per aggiornare la misurazione del peso.';

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

  Future<void> syncForProfile(
    UserProfile? profile, {
    List<BodyMetricLog> bodyLogs = const [],
  }) async {
    if (profile?.role == 'athlete' && profile?.notificationsEnabled == true) {
      await scheduleDailyTrainingReminder();
      await syncWeightMeasurementReminder(profile, bodyLogs);
      return;
    }

    await cancelAllReminders();
  }

  Future<bool> requestPermissionAndSchedule({
    UserProfile? profile,
    List<BodyMetricLog> bodyLogs = const [],
  }) async {
    await initialize();
    final granted = await requestPermission();
    if (!granted) {
      await cancelAllReminders();
      return false;
    }

    await scheduleDailyTrainingReminder();
    await syncWeightMeasurementReminder(profile, bodyLogs);
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

  Future<void> syncWeightMeasurementReminder(
    UserProfile? profile,
    List<BodyMetricLog> bodyLogs,
  ) async {
    if (kIsWeb) return;
    await initialize();

    if (profile?.role != 'athlete' || profile?.notificationsEnabled != true) {
      await cancelWeightMeasurementReminder();
      return;
    }

    final lastWeightDate = _latestWeightDate(bodyLogs);
    if (lastWeightDate == null) {
      await cancelWeightMeasurementReminder();
      return;
    }

    await scheduleWeightMeasurementReminderFrom(lastWeightDate);
  }

  Future<void> scheduleWeightMeasurementReminderFrom(
    DateTime lastWeightDate,
  ) async {
    if (kIsWeb) return;
    await initialize();

    await cancelWeightMeasurementReminder();

    final firstReminder = _nextWeightReminderDate(lastWeightDate);
    for (var day = 0; day < _weightReminderScheduleDays; day++) {
      await _plugin.zonedSchedule(
        _weightReminderBaseId + day,
        'Aggiorna il tuo peso',
        'Sono passati alcuni giorni dall\'ultima misurazione: aggiungi il peso di oggi per tenere aggiornati i progressi.',
        firstReminder.add(Duration(days: day)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _weightChannelId,
            _weightChannelName,
            channelDescription: _weightChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'weight_measurement_reminder',
      );
    }
  }

  Future<void> cancelWeightMeasurementReminder() async {
    if (kIsWeb) return;
    await initialize();
    for (var day = 0; day < _weightReminderScheduleDays; day++) {
      await _plugin.cancel(_weightReminderBaseId + day);
    }
  }

  Future<void> cancelAllReminders() async {
    await cancelDailyTrainingReminder();
    await cancelWeightMeasurementReminder();
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

  DateTime? _latestWeightDate(List<BodyMetricLog> bodyLogs) {
    DateTime? latest;
    for (final log in bodyLogs) {
      if (log.type != 'weight') continue;
      final parsed = DateTime.tryParse(log.date);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }
    return latest;
  }

  tz.TZDateTime _firstWeightReminderDate(DateTime lastWeightDate) {
    final dueDate = lastWeightDate.add(const Duration(days: 7));
    return tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      7,
      30,
    );
  }

  tz.TZDateTime _nextWeightReminderDate(DateTime lastWeightDate) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = _firstWeightReminderDate(lastWeightDate);
    if (!scheduledDate.isAfter(now)) {
      scheduledDate =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 7, 30);
      if (!scheduledDate.isAfter(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    }
    return scheduledDate;
  }
}
