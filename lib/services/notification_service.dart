import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'task_reminders';
  static const _channelName = 'Task Reminders';

  Future<void> init() async {
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.max,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();

    final exactGranted = await androidPlugin?.requestExactAlarmsPermission();
    debugPrint(
      '[NotificationService] requestExactAlarmsPermission → '
      '${exactGranted == true ? 'granted' : 'denied'}',
    );
  }

  Future<void> scheduleNotification(
    String taskId,
    String title,
    DateTime deadline,
  ) async {
    final scheduledDate = tz.TZDateTime.from(deadline, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final canScheduleExact =
        await androidPlugin?.canScheduleExactNotifications() ?? false;

    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexact;

    try {
      await _plugin.zonedSchedule(
        taskId.hashCode,
        'Task Due',
        title,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint(
        '[NotificationService] zonedSchedule called — '
        'taskId: $taskId, mode: $scheduleMode, at: $scheduledDate',
      );
    } catch (e) {
      debugPrint('[NotificationService] scheduleNotification failed: $e');
    }
  }

  Future<void> cancelNotification(String taskId) async {
    await _plugin.cancel(taskId.hashCode);
  }
}
