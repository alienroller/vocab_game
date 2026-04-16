import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocab_game/services/key_constants.dart';
import 'package:vocab_game/services/storage_provider.dart';

class FirebaseService {
  static final _topic = 'Vocab Game News';
  static final _supabase = Supabase.instance.client;

  static void initFirebase() {
    if (Platform.isIOS) {
      FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,
        sound: true,
      );
    }

    FirebaseMessaging.instance.setAutoInitEnabled(true);

    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _registerMessageOpenedApp();

    _handleInitialNotificationIfAny();

    initMicroTasks();
  }

  static Future<void> _handleInitialNotificationIfAny() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();

    if (initial == null) return;

    // final data = RemoteMessageData.fromJson(initial.data);

    //onMessageOpenedApp(data.coreType);
  }

  static void _registerMessageOpenedApp() {
    // PerfectNotificationService.instance.onNotificationClick.listen((message) {
    //   if (message.data == null) return;
    //
    //   final msg = json.decode(message.data!);
    //
    //   if (msg["data"] == null) return;
    //
    //   final data = RemoteMessageData.fromJson(msg["data"]);
    //
    //   onMessageOpenedApp(data.coreType);
    // });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      //RemoteMessageData data = RemoteMessageData.fromJson(message.data);

      //onMessageOpenedApp(data.coreType);
    });
  }

  static void userLogin() => initMicroTasks();

  static Future<void> userLogout() async {
    await FirebaseMessaging.instance.deleteToken();

    await unsubscribeFCMTopics();
  }

  static void getAPNSToken() async {
    if (Platform.isIOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();

      if (apnsToken != null) {
        subscribeFCMTopics();
      } else {
        await Future<void>.delayed(const Duration(seconds: 3));

        apnsToken = await FirebaseMessaging.instance.getAPNSToken();

        if (apnsToken != null) subscribeFCMTopics();
      }
    } else {
      subscribeFCMTopics();
    }
  }

  static void initMicroTasks() {
    Future.microtask(() {
      _initializeFCMToken();

      getAPNSToken();
    });
  }

  static Future<void> _initializeFCMToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await LocalStorageProvider.cache.setString(KeyConstants.fcmToken, token);
        await _saveTokenToSupabase(token);
      } else {}

      FirebaseMessaging.instance.onTokenRefresh
          .listen((newToken) async {
            await LocalStorageProvider.cache.setString(KeyConstants.fcmToken, newToken);

            await _saveTokenToSupabase(newToken);
          })
          .onError((err) {
            debugPrint('FCM token refresh error: $err');
          });
    } catch (e, s) {
      debugPrint('FCM token refresh listener failed: $e\n$s');
    }
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    final profileId = Hive.box('userProfile').get('id') as String;

    await _supabase.from('profiles').update({'fcm_token': token}).eq('id', profileId);
  }

  //
  // static void onMessageOpenedApp(CoreType? coreType) {
  //   final action = NotificationActions.fromName(coreType?.action ?? '');
  //
  //   switch (action) {
  //     case NotificationActions.navigation:
  //       _handleNavigation(coreType);
  //
  //       break;
  //
  //     case NotificationActions.launch:
  //       _handleLaunch(coreType);
  //
  //       break;
  //
  //     case NotificationActions.launchUrl:
  //       _handleLaunchUrl(coreType);
  //
  //       break;
  //   }
  // }
  //
  // static void _handleNavigation(CoreType? coreType) {
  //   final context = navigatorKey.currentContext;
  //
  //   if (context == null) return;
  //
  //   try {
  //     final uri = Uri.parse(coreType?.data ?? '');
  //
  //     final query = uri.queryParameters['id'] ?? '';
  //
  //     final path = uri.path;
  //
  //     final argument = int.tryParse(query);
  //
  //     if (path.isEmpty) return;
  //
  //     final currentPath = platformNavigationObserver.lastRoute;
  //
  //     if (path == currentPath) {
  //       Navigator.of(context).pushReplacementNamed(path, arguments: argument);
  //
  //       return;
  //     }
  //
  //     if (!isLocalAuth && !isSplash) {
  //       Navigator.pushNamed(context, path, arguments: argument);
  //
  //       return;
  //     }
  //
  //     final canPop = Navigator.canPop(context);
  //
  //     if (!canPop) {
  //       Navigator.of(context)
  //         ..pushReplacementNamed(AppRoutes.tabsRoute)
  //         ..pushNamed(path, arguments: argument);
  //     } else {
  //       Navigator.of(context).pushReplacementNamed(path, arguments: argument);
  //     }
  //
  //     navigateToLocalAuth(context);
  //
  //     return;
  //   } catch (error, stack) {
  //     debugPrint('Error happened during opening Messaging: (Error: $error) | (StackTrace: $stack)');
  //   }
  // }
  //
  // static void _handleLaunch(CoreType? coreType) {}
  //
  // static void _handleLaunchUrl(CoreType? coreType) {}

  static Future<void> subscribeFCMTopics() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(_topic);
    } catch (e) {
      debugPrint('FCM subscribeToTopic($_topic) failed: $e');
    }
  }

  static Future<void> unsubscribeFCMTopics() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_topic);
    } catch (e) {
      debugPrint('FCM unsubscribeFromTopic($_topic) failed: $e');
    }
  }
}
