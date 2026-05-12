import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _morningHourKey = 'notification_morning_hour';
  static const String _morningMinuteKey = 'notification_morning_minute';
  static const String _eveningHourKey = 'notification_evening_hour';
  static const String _eveningMinuteKey = 'notification_evening_minute';
  static const String _enabledKey = 'notification_enabled';

  static const int _morningNotificationId = 1001;
  static const int _eveningNotificationId = 1002;
  static const int _reviewDueNotificationId = 1003;

  Future<void> init() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    _isInitialized = true;

    // Schedule saved reminders
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? true;
    if (enabled) {
      await _rescheduleReminders();
    }
  }

  /// Đặt lịch nhắc nhở ôn tập hàng ngày
  Future<void> scheduleDailyReminders({
    TimeOfDay morningTime = const TimeOfDay(hour: 8, minute: 0),
    TimeOfDay eveningTime = const TimeOfDay(hour: 20, minute: 0),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_morningHourKey, morningTime.hour);
    await prefs.setInt(_morningMinuteKey, morningTime.minute);
    await prefs.setInt(_eveningHourKey, eveningTime.hour);
    await prefs.setInt(_eveningMinuteKey, eveningTime.minute);
    await prefs.setBool(_enabledKey, true);

    await _scheduleNotification(
      id: _morningNotificationId,
      hour: morningTime.hour,
      minute: morningTime.minute,
      title: '🌅 Good morning! Time to review',
      body: 'You have words due for review. Keep your streak going!',
    );

    await _scheduleNotification(
      id: _eveningNotificationId,
      hour: eveningTime.hour,
      minute: eveningTime.minute,
      title: '🌙 Evening review reminder',
      body: 'Don\'t forget to review your vocabulary before bed!',
    );
  }

  Future<void> _rescheduleReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final morningHour = prefs.getInt(_morningHourKey) ?? 8;
    final morningMinute = prefs.getInt(_morningMinuteKey) ?? 0;
    final eveningHour = prefs.getInt(_eveningHourKey) ?? 20;
    final eveningMinute = prefs.getInt(_eveningMinuteKey) ?? 0;

    await scheduleDailyReminders(
      morningTime: TimeOfDay(hour: morningHour, minute: morningMinute),
      eveningTime: TimeOfDay(hour: eveningHour, minute: eveningMinute),
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'vocab_review_channel',
      'Vocabulary Review',
      channelDescription: 'Daily vocabulary review reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  /// Hiện notification ngay lập tức khi có từ cần ôn
  Future<void> showReviewDueNotification(int wordCount) async {
    if (wordCount <= 0) return;

    const androidDetails = AndroidNotificationDetails(
      'vocab_review_channel',
      'Vocabulary Review',
      channelDescription: 'Vocabulary review notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _reviewDueNotificationId,
      '📚 $wordCount words ready for review!',
      'Review now to strengthen your memory.',
      details,
      payload: 'review',
    );
  }

  /// Bật/tắt notifications
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      await _rescheduleReminders();
    } else {
      await cancelAll();
    }
  }

  /// Kiểm tra notification có được bật không
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// Lấy thời gian nhắc nhở đã lưu
  Future<Map<String, TimeOfDay>> getSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'morning': TimeOfDay(
        hour: prefs.getInt(_morningHourKey) ?? 8,
        minute: prefs.getInt(_morningMinuteKey) ?? 0,
      ),
      'evening': TimeOfDay(
        hour: prefs.getInt(_eveningHourKey) ?? 20,
        minute: prefs.getInt(_eveningMinuteKey) ?? 0,
      ),
    };
  }

  /// Hủy tất cả notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
