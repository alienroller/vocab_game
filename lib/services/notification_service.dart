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

  // ─── Teacher → Student notifications ────────────────────────────
  //
  // Triggered from home_screen poll diffs / realtime subscriptions when
  // a teacher action becomes visible to the student. Shown via the
  // existing local-notification plugin so they appear in the system
  // tray + as in-app banners. Channel ids are stable so users can
  // disable them granularly in OS settings.

  /// New exam invitation arrived for the student's class.
  static Future<void> notifyNewExam({
    required String examTitle,
    required int sessionHashId,
  }) async {
    try {
      await _plugin.show(
        // Stable id so a re-poll doesn't re-notify the same exam twice
        // — flutter_local_notifications dedupes by id.
        sessionHashId,
        '📝 New exam: $examTitle',
        'Your teacher started an exam. Tap to join.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'exams',
            'Exam Invitations',
            channelDescription: 'New exams from your teacher',
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('New exam notification failed: $e');
    }
  }

  /// New assignment posted by the teacher.
  static Future<void> notifyNewAssignment({
    required String unitTitle,
    required String bookTitle,
    required int assignmentHashId,
  }) async {
    try {
      await _plugin.show(
        assignmentHashId,
        '📚 New assignment: $unitTitle',
        bookTitle.isEmpty
            ? 'Your teacher assigned a unit. Open VocabGame to start.'
            : 'From $bookTitle. Open VocabGame to start.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'assignments',
            'Class Assignments',
            channelDescription: 'New homework / unit assignments',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('New assignment notification failed: $e');
    }
  }

  /// Teacher pinned (or updated) the class message.
  static Future<void> notifyTeacherMessage(String preview) async {
    try {
      // Single-slot channel id — overwriting an older message is the
      // intended behavior since teachers only have one pinned message
      // per class at a time.
      await _plugin.show(
        3,
        '📌 Class announcement',
        preview.length > 80 ? '${preview.substring(0, 77)}…' : preview,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'messages',
            'Class Messages',
            channelDescription: 'Pinned messages from your teacher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Teacher message notification failed: $e');
    }
  }

  /// Hash a string id into the int range flutter_local_notifications expects.
  /// 32-bit positive — Android caps notification ids at int32.
  static int idFromString(String s) {
    var hash = 0;
    for (final code in s.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse details) {
    // Currently no-op. Payload could be used to route the user
    // to a specific screen when they tap a notification.
  }
}
