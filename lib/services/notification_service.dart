import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/standalone.dart';
import 'package:vocab_game/models/notification.dart';
import 'package:vocab_game/services/firebase_service.dart';
import 'package:vocab_game/services/local_notification_service.dart';
import 'package:vocab_game/util/app_permission_manager.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  Future<void> initialize() async {
    await LocalNotificationService.instance.initialize();

    await FirebaseService.instance.initialize();
  }

  Future<void> requestPermission({
    required PermissionCallback onGranted,
    required PermissionCallback onDenied,
    PermissionCallback? onPermanentlyDenied,
  }) async {
    await AppPermissionManager.requestPermission(
      permission: Permission.notification,
      onGranted: onGranted,
      onDenied: onDenied,
      onPermanentlyDenied: onPermanentlyDenied,
    );
  }

  Future<void> onNotificationOpened(Notification notification) async {
    if (notification.data == null) return;

    if (notification.data!['path'] == null) return;
  }

  Future<void> show({int id = 404, String? title, String? body, String? payload}) async {
    await LocalNotificationService.instance.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> schedule({
    int id = 404,
    required String title,
    required String body,
    TZDateTime? date,
    Duration delay = const Duration(days: 1),
    DateTimeComponents? repeat,
  }) async {
    await LocalNotificationService.instance.schedule(
      id: id,
      title: title,
      body: body,
      date: date,
      delay: delay,
      repeat: repeat,
      // payload: TODO(Do it later like this : payload = jsonEncode(data);)
    );
  }

  static final _plugin = FlutterLocalNotificationsPlugin();

  // ─── Streak Warning ─────────────────────────────────────────────

  /// Show an immediate streak warning notification.
  /// Call this when the user opens the app and hasn't played today
  /// but has a streak worth protecting.
  static Future<void> showStreakWarning(int streakDays) async {
    if (streakDays < 2) return;

    try {
      await _plugin.show(
        0,
        '🔥 Your $streakDays-day streak is in danger!',
        'Open the app and play to keep your streak alive.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak',
            'Streak Alerts',
            channelDescription: 'Reminders to protect your streak',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Streak notification failed: $e');
    }
  }

  /// Cancel the streak warning (call after the user plays today).
  static Future<void> cancelStreakWarning() async {
    await _plugin.cancel(0);
  }

  // ─── Duel Challenge ─────────────────────────────────────────────

  /// Notify when a duel challenge arrives.
  static Future<void> notifyDuelChallenge(String challengerUsername) async {
    try {
      await _plugin.show(
        2,
        '⚔️ $challengerUsername challenged you!',
        'Accept the duel before it expires.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'duels',
            'Duel Challenges',
            channelDescription: 'Incoming duel challenge alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Duel notification failed: $e');
    }
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse details) {
    // Currently no-op. Payload could be used to route the user
    // to a specific screen when they tap a notification.
  }
}
