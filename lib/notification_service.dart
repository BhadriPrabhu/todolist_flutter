import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'task_model.dart';
import 'package:device_info_plus/device_info_plus.dart';

class NotificationService {
  Future<String> _getLogFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/task_logs.txt';
  }

  Future<void> _writeLog(String message) async {
    try {
      final file = File(await _getLogFilePath());
      await file.writeAsString('$message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('[2025-05-30 01:48 IST] Failed to write log: $e');
    }
  }

  Future<void> initialize() async {
    final logMessage = '[2025-05-30 01:48 IST] Initializing notification service with Awesome Notifications';
    debugPrint(logMessage);
    await _writeLog(logMessage);

    try {
      await AwesomeNotifications().initialize(
        null, // Default icon
        [
          NotificationChannel(
            channelKey: 'task_reminder_channel',
            channelName: 'Task Reminders',
            channelDescription: 'Notifications for task due dates',
            importance: NotificationImportance.High,
            playSound: true,
            enableVibration: true,
            channelShowBadge: true,
          ),
        ],
        debug: true,
      );

      final successMessage = '[2025-05-30 01:48 IST] Notification service initialized with Awesome Notifications';
      debugPrint(successMessage);
      await _writeLog(successMessage);

      bool permissionGranted = await requestPermissions();
      if (!permissionGranted) {
        final permissionMessage = '[2025-05-30 01:48 IST] Notification permission denied';
        debugPrint(permissionMessage);
        await _writeLog(permissionMessage);
      }
    } catch (e) {
      final errorMessage = '[2025-05-30 01:48 IST] Failed to initialize notifications with Awesome Notifications: $e';
      debugPrint(errorMessage);
      await _writeLog(errorMessage);
    }
  }

  Future<bool> requestPermissions() async {
    try {
      bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        isAllowed = await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      final message = '[2025-05-30 01:48 IST] Notification permission: ${isAllowed ? 'granted' : 'denied'}';
      debugPrint(message);
      await _writeLog(message);

      bool alarmGranted = true;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 31) {
          debugPrint('[2025-05-30 01:48 IST] Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt}) - exact alarm permission required');
          alarmGranted = true;
        }
      }

      return isAllowed && alarmGranted;
    } catch (e) {
      final errorMessage = '[2025-05-30 01:48 IST] Failed to request permissions with Awesome Notifications: $e';
      debugPrint(errorMessage);
      await _writeLog(errorMessage);
      return false;
    }
  }

  Future<void> scheduleNotification(Task task) async {
    if (task.dueDate == null) {
      final noDueMessage = '[2025-05-30 01:48 IST] Cannot schedule notification for task ${task.id}: No due date';
      debugPrint(noDueMessage);
      await _writeLog(noDueMessage);
      return;
    }

    try {
      final dueDateUtc = DateTime.parse(task.dueDate!);
      final dueDateIst = tz.TZDateTime.from(dueDateUtc, tz.getLocation('Asia/Kolkata'));
      final now = tz.TZDateTime.now(tz.getLocation('Asia/Kolkata'));

      final scheduleMessage = '[2025-05-30 01:48 IST] Scheduling task ${task.id}: dueDateUtc=$dueDateUtc, dueDateIst=$dueDateIst, now=$now, isAfter=${dueDateIst.isAfter(now)}';
      debugPrint(scheduleMessage);
      await _writeLog(scheduleMessage);

      if (!dueDateIst.isAfter(now)) {
        final pastDueMessage = '[2025-05-30 01:48 IST] Cannot schedule notification for task ${task.id}: Due date $dueDateIst is not in the future';
        debugPrint(pastDueMessage);
        await _writeLog(pastDueMessage);
        return;
      }

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt < 31) {
          debugPrint('[2025-05-30 01:48 IST] Warning: Exact alarms may not work on Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})');
        } else {
          debugPrint('[2025-05-30 01:48 IST] Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt}) supports exact alarms');
        }
      }

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: task.id.hashCode,
          channelKey: 'task_reminder_channel',
          title: task.title,
          body: task.description ?? 'No description',
          notificationLayout: NotificationLayout.Default,
          displayOnForeground: true,
          displayOnBackground: true,
        ),
        schedule: NotificationCalendar.fromDate(
          date: dueDateIst,
          preciseAlarm: true,
          allowWhileIdle: true,
        ),
      );

      final successMessage = '[2025-05-30 01:48 IST] Scheduled notification for task ${task.id}: ${task.title}, due: $dueDateIst';
      debugPrint(successMessage);
      await _writeLog(successMessage);
    } catch (e) {
      final errorMessage = '[2025-05-30 01:48 IST] Failed to schedule notification for task ${task.id}: $e';
      debugPrint(errorMessage);
      await _writeLog(errorMessage);
    }
  }

  Future<void> scheduleOverdueNotification(Task task) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: task.id.hashCode,
          channelKey: 'task_reminder_channel',
          title: 'Overdue: ${task.title}',
          body: task.description ?? 'This task is overdue!',
          notificationLayout: NotificationLayout.Default,
          displayOnForeground: true,
          displayOnBackground: true,
        ),
      );

      final successMessage = '[2025-05-30 01:48 IST] Sent overdue notification for task ${task.id}: ${task.title}';
      debugPrint(successMessage);
      await _writeLog(successMessage);
    } catch (e) {
      final errorMessage = '[2025-05-30 01:48 IST] Failed to send overdue notification for task ${task.id}: $e';
      debugPrint(errorMessage);
      await _writeLog(errorMessage);
    }
  }

  Future<void> cancelNotification(String taskId) async {
    try {
      await AwesomeNotifications().cancel(taskId.hashCode);
      final successMessage = '[2025-05-30 01:48 IST] Cancelled notification for task ID: $taskId';
      debugPrint(successMessage);
      await _writeLog(successMessage);
    } catch (e) {
      final errorMessage = '[2025-05-30 01:48 IST] Failed to cancel notification for task ID: $taskId: $e';
      debugPrint(errorMessage);
      await _writeLog(errorMessage);
    }
  }

  Future<void> showTestNotification() async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 0,
          channelKey: 'task_reminder_channel',
          title: 'Test Notification',
          body: 'This is a test',
          notificationLayout: NotificationLayout.Default,
          displayOnForeground: true,
          displayOnBackground: true,
        ),
      );

      final successMessage = '[2025-05-30 01:48 IST] Test notification triggered';
      debugPrint(successMessage);
      await _writeLog(successMessage);
    } catch (e) {
      final errorMessage = '[2025-05-30 01:48 IST] Failed to show test notification: $e';
      debugPrint(errorMessage);
      await _writeLog(errorMessage);
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await AwesomeNotifications().cancelAll();
      final successMessage = '[2025-05-30 01:48 IST] Cancelled all notifications';
      debugPrint(successMessage);
      await _writeLog(successMessage);
    } catch (e) {
      final errorMessage = '[2025-05-30 01:48 IST] Failed to cancel all notifications: $e';
      debugPrint(errorMessage);
      await _writeLog(errorMessage);
    }
  }
}