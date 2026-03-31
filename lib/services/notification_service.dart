import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification service for streak warnings, duel challenges,
/// and leaderboard rivalry alerts.
///
/// All notifications are local (device-only) and do not require a server.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Initialize the notification plugin. Call once in main().
  static Future<void> initialize() async {
    const android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
  }

  /// Request notification permissions on iOS and Android 13+.
  /// Call once during onboarding.
  static Future<void> requestPermission() async {
    // Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

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

  // ─── Leaderboard Rivalry ────────────────────────────────────────

  /// Notify when someone overtakes the user on the leaderboard.
  static Future<void> notifyOvertaken(String byUsername) async {
    try {
      await _plugin.show(
        1,
        '⚡ $byUsername just passed you!',
        'Open the game and reclaim your rank.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rivalry',
            'Rivalry Alerts',
            channelDescription: 'Leaderboard position change alerts',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Rivalry notification failed: $e');
    }
  }

  /// Cancel all pending notifications.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
