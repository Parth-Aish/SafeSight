import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Sets up the notification channels required by Android 14+
  static Future<void> initialize() async {
    // Basic initialization for Android and iOS
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // 1. Silent Foreground Channel (Keeps the background engine alive)
    const AndroidNotificationChannel foregroundChannel =
        AndroidNotificationChannel(
      'safesight_foreground',
      'SafeSight Active Protection',
      description: 'Runs constantly to monitor your surroundings.',
      importance: Importance.low,
    );

    // 2. Max Priority Alert Channel (For SOS & Danger)
    const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
      'safesight_alerts',
      'Emergency Alerts',
      description: 'Critical notifications about nearby danger.',
      importance: Importance.max,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(foregroundChannel);
      await androidPlugin.createNotificationChannel(alertChannel);
    }
  }

  // ---------------------------------------------------------------------------
  // ALERT TEMPLATES
  // ---------------------------------------------------------------------------

  /// Fired when the USER triggers an SOS locally
  static Future<void> showEmergencySOSAlert(String reason) async {
    await _plugin.show(
      999,
      '🚨 EMERGENCY SOS ACTIVATED 🚨',
      'Distress signal ($reason) detected. Broadcasting to Guardians...',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safesight_alerts',
          'Emergency Alerts',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFFF43F5E),
          enableVibration: true,
          playSound: true,
        ),
      ),
    );
  }

  /// Fired when a FRIEND triggers an SOS and sends it to the user
  static Future<void> showGuardianSOSAlert(
      {required int id,
      required String victim,
      required String reason,
      required String pin}) async {
    await _plugin.show(
      id,
      '🚨 GUARDIAN ALERT: Friend in Danger!',
      '$victim triggered SOS ($reason). Track PIN: $pin',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safesight_alerts',
          'Emergency Alerts',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFFF43F5E),
          enableVibration: true,
          playSound: true,
        ),
      ),
    );
  }

  /// Fired when a FRIEND walks into a high-risk neighborhood
  static Future<void> showGuardianDangerWarning(
      {required int id, required String victim, required int threats}) async {
    await _plugin.show(
      id,
      '⚠️ GUARDIAN WARNING',
      '$victim has entered a high-risk area with $threats active threat(s)!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safesight_alerts',
          'Emergency Alerts',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFFEAB308),
          enableVibration: true,
          playSound: true,
        ),
      ),
    );
  }

  /// Fired when the USER walks into a high-risk neighborhood
  static Future<void> showDangerNearbyAlert(int nearbyThreats) async {
    await _plugin.show(
      888,
      '⚠️ DANGER NEARBY',
      '$nearbyThreats incident(s) reported within 1.5km of your location!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safesight_alerts',
          'Emergency Alerts',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFFF43F5E),
          enableVibration: true,
        ),
      ),
    );
  }
}
