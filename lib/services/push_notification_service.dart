import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firestore_service.dart';

/// Wires up FCM for the signed-in device: requests notification permission, captures the
/// device's push token into Firestore (so the notification Cloud Function in functions/ can
/// target it), and surfaces foreground pushes as a snackbar — Android doesn't show the system
/// tray banner for a "notification"-payload message while the app is in the foreground.
class PushNotificationService {
  final FirestoreService _firestore;
  final GlobalKey<ScaffoldMessengerState> _messengerKey;

  PushNotificationService(this._firestore, this._messengerKey);

  Future<void> initForUser(String userId) async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token != null) {
      await _firestore.savePushToken(userId, token);
    }
    messaging.onTokenRefresh.listen((refreshed) => _firestore.savePushToken(userId, refreshed));

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${notification.title}\n${notification.body}')),
      );
    });
  }
}
