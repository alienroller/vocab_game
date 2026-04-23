import 'package:firebase_messaging/firebase_messaging.dart';

class Notification {
  factory Notification.fromRemoteMessage(RemoteMessage message) => Notification(
    title: message.notification?.title ?? '',
    body: message.notification?.body ?? '',
    data: message.data,
  );

  factory Notification.fromRemoteNotification(RemoteNotification notification) =>
      Notification(title: notification.title ?? '', body: notification.body ?? '', data: null);

  const Notification({required this.title, required this.body, this.data});

  final String title;
  final String body;
  final Map<String, dynamic>? data;

  @override
  String toString() => '{Notification title: $title, body: $body, data: $data,}';
}
