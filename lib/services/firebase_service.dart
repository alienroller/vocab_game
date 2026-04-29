import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocab_game/firebase_options.dart';
import 'package:vocab_game/models/notification.dart';
import 'package:vocab_game/services/key_constants.dart';
import 'package:vocab_game/services/notification_service.dart';
import 'package:vocab_game/services/storage_provider.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // kerak bo‘lsa Firebase.initializeApp()
}

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _isInitialized = false;
  final _topic = 'vocab_game_news';
  final _supabase = Supabase.instance.client;

  StreamSubscription? _tokenSubscription;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (!kIsWeb) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }

      await FirebaseMessaging.instance.setAutoInitEnabled(true);

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _onBackgroundMessage();

      await _onMessageReceived();

      await _onMessageOpened();

      await _getInitialMessage();

      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  Future<void> _onBackgroundMessage() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> _onMessageReceived() async {
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = Notification.fromRemoteMessage(message);

      await NotificationService.instance.show(
        id: 404,
        title: notification.title,
        body: notification.body,
        // payload: notification.data TODO(Do it later like this : payload = jsonEncode(data);)
      );
    });
  }

  Future<void> _onMessageOpened() async {
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final notification = Notification.fromRemoteMessage(message);

      await NotificationService.instance.onNotificationOpened(notification);
    });
  }

  Future<void> _getInitialMessage() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();

    if (initial == null) return;

    final notification = Notification.fromRemoteMessage(initial);

    await NotificationService.instance.onNotificationOpened(notification);
  }

  void userLogin() => _initializeFCMToken();

  Future<void> userLogout() async {
    await FirebaseMessaging.instance.deleteToken();

    await _unsubscribeFCMTopics();
  }

  Future<void> _initializeFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await LocalStorageProvider.cache.setString(KeyConstants.fcmToken, token);

        await _saveTokenToSupabase(token);

        await _subscribeFCMTopics();
      }

      await _tokenSubscription?.cancel();

      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await LocalStorageProvider.cache.setString(KeyConstants.fcmToken, newToken);

        await _saveTokenToSupabase(newToken);

        await _subscribeFCMTopics();
      });
    } catch (e, s) {
      debugPrint('FCM token refresh listener failed: $e\n$s');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final profileId = Hive.box('userProfile').get('id');

    if (profileId == null) return;

    try {
      await _supabase.from('profiles').update({'fcm_token': token}).eq('id', profileId);
    } catch (e) {
      debugPrint('Supabase error: $e');
    }
  }

  Future<void> _subscribeFCMTopics() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_topic);
    } catch (e) {
      debugPrint('FCM subscribeToTopic($_topic) failed: $e');
    }
  }

  Future<void> _unsubscribeFCMTopics() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_topic);
    } catch (e) {
      debugPrint('FCM unsubscribeFromTopic($_topic) failed: $e');
    }
  }
}
