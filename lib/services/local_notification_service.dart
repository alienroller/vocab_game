import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/standalone.dart';
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final _localNotification = FlutterLocalNotificationsPlugin();

  final _defaultId = 404;
  bool _isInitialized = false;
  final _channelId = 'app_notifications';
  final _channelName = 'Vocab Game Notifications';

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;

    tz.initializeTimeZones();

    tz.setLocalLocation(tz.getLocation('Asia/Tashkent'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotification.initialize(
      settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveNotificationResponse,
    );

    if (!Platform.isAndroid) return;

    final androidPlugin =
        _localNotification
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.max,
    );
    await androidPlugin?.createNotificationChannel(channel);
  }

  void _onDidReceiveNotificationResponse(NotificationResponse details) {
    // Currently no-op. Payload could be used to route the user
    // to a specific screen when they tap a notification.
  }

  Future<void> show({int id = 404, String? title, String? body, String? payload}) async {
    try {
      if (id == _defaultId) id = DateTime.now().millisecondsSinceEpoch;

      final details = NotificationDetails(android: _androidDetails, iOS: _iosDetails);

      await _localNotification.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('notification failed: $e');
    }
  }

  Future<void> schedule({
    int id = 404,
    required String title,
    required String body,
    TZDateTime? date,
    Duration delay = const Duration(days: 1),
    DateTimeComponents? repeat,
    String? payload,
  }) async {
    if (id == _defaultId) id = DateTime.now().millisecondsSinceEpoch;

    final scheduledDate = date ?? tz.TZDateTime.now(tz.local).add(delay);

    final details = NotificationDetails(android: _androidDetails, iOS: _iosDetails);

    await _localNotification.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: repeat,
      payload: payload,
    );
  }

  AndroidNotificationDetails get _androidDetails => AndroidNotificationDetails(
    _channelId,
    _channelName,
    importance: Importance.max,
    priority: Priority.high,
  );

  DarwinNotificationDetails get _iosDetails => const DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    presentBanner: true,
  );
}
