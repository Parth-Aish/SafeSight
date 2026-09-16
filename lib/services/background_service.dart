import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart';

import '../firebase_options.dart';
import '../core/utils/reliable_location.dart';
import 'notification_service.dart';

Future<void> initializeBackgroundEngine() async {
  final service = FlutterBackgroundService();

  await NotificationService.initialize();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'safesight_foreground',
      initialNotificationTitle: 'SafeSight is Active',
      initialNotificationContent: 'Monitoring for threats every 30 seconds.',
      foregroundServiceTypes: [
        AndroidForegroundType.location,
        AndroidForegroundType.microphone
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  var firebaseReady = Firebase.apps.isNotEmpty;
  if (!firebaseReady) {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      firebaseReady = true;
    } catch (error, stackTrace) {
      debugPrint("Background Firebase initialization failed: $error");
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Set<String> alertedGuardianDocs = {};

  // ===========================================================================
  // 1. HARDWARE SOS TRIGGER LOGIC
  // ===========================================================================
  DateTime? lastSosTriggerTime;

  Future<void> triggerHardwareSOS(
      {String reason = "Hardware SOS Trigger"}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // FIX: Check if the user just manually stopped a broadcast
    final bool isOnCooldown = prefs.getBool('broadcast_cooldown') ?? false;
    if (isOnCooldown) {
      debugPrint("Skipping SOS trigger - User recently stopped broadcast.");
      return;
    }

    final now = DateTime.now();
    if (lastSosTriggerTime != null &&
        now.difference(lastSosTriggerTime!).inSeconds < 30) {
      return;
    }
    lastSosTriggerTime = now;

    debugPrint("🚨 EMERGENCY DETECTED: $reason 🚨");

    try {
      await NotificationService.showEmergencySOSAlert(reason);

      final pos = await getReliableLocation();
      if (pos == null) {
        throw StateError('Location unavailable for hardware SOS.');
      }
      final pin = (100000 + Random().nextInt(900000)).toString();

      if (!firebaseReady) {
        throw StateError('Firebase is unavailable for emergency dispatch.');
      }

      await prefs.setString('active_broadcast_pin', pin);

      await FirebaseFirestore.instance
          .collection('live_sessions')
          .doc(pin)
          .set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'ACTIVE',
        'destinationName': reason,
      });

      final guardians = prefs.getStringList('guardian_emails') ?? [];
      final user = FirebaseAuth.instance.currentUser;

      final String victimEmail =
          user?.email ?? prefs.getString('user_email') ?? "Unknown User";

      if (guardians.isNotEmpty && user != null) {
        await FirebaseFirestore.instance.collection('active_alerts').add({
          'victimUid': user.uid,
          'victimEmail': victimEmail,
          'guardianEmails': guardians,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'pin': pin,
          'type': 'SOS',
          'reason': reason,
        });
      }

      // Guardian dispatch is handled by the authenticated in-app alert path.
    } catch (e) {
      debugPrint("Hardware SOS Failed: $e");
    }
  }

  // ===========================================================================
  // 2. SHAKE DETECTOR (ACCELEROMETER)
  // ===========================================================================
  int shakeCount = 0;
  DateTime? lastShakeTime;

  try {
    userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      double acceleration =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      // Kept threshold high (30.0) to ignore running
      if (acceleration > 30.0) {
        final now = DateTime.now();
        if (lastShakeTime == null ||
            now.difference(lastShakeTime!).inSeconds > 2) {
          shakeCount = 1;
        } else {
          shakeCount++;
          // Triggering SOS exactly after 2 valid spikes!
          if (shakeCount >= 2) {
            triggerHardwareSOS(reason: "Violent Shake Detected");
            shakeCount = 0;
          }
        }
        lastShakeTime = now;
      }
    });
  } catch (e) {
    debugPrint("Shake engine failed: $e");
  }

  // ===========================================================================
  // 3. VOLUME BUTTON DETECTOR
  // ===========================================================================
  int volChangeCount = 0;
  DateTime? lastVolChangeTime;

  try {
    PerfectVolumeControl.stream.listen((volume) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final bool isAppChangingVolume =
          prefs.getBool('is_app_changing_volume') ?? false;

      if (isAppChangingVolume) {
        debugPrint("Ignoring volume change - caused by app Siren/Call");
        return;
      }

      final now = DateTime.now();
      if (lastVolChangeTime == null ||
          now.difference(lastVolChangeTime!).inSeconds > 4) {
        volChangeCount = 1;
      } else {
        volChangeCount++;
        if (volChangeCount >= 3) {
          triggerHardwareSOS(reason: "Volume Button SOS");
          volChangeCount = 0;
        }
      }
      lastVolChangeTime = now;
    });
  } catch (e) {
    debugPrint("Volume engine failed: $e");
  }

  // ===========================================================================
  // 4. VOICE & DISTRESS SOUND ENGINE
  // ===========================================================================
  try {
    final speech = stt.SpeechToText();
    final List<String> distressKeywords = [
      "safesight help",
      "help me",
      "call police",
      "stop it"
    ];

    void startContinuousListening() async {
      if (await speech.hasPermission) {
        speech.listen(
          onResult: (result) {
            String spoken = result.recognizedWords.toLowerCase();
            for (String word in distressKeywords) {
              if (spoken.contains(word)) {
                triggerHardwareSOS(reason: "Voice Command: '$word'");
                break;
              }
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            cancelOnError: true,
            partialResults: true,
          ),
        );
      }
    }

    bool sttAvailable = await speech.initialize(onStatus: (status) {
      if (status == 'done' || status == 'notListening') {
        Future.delayed(
            const Duration(milliseconds: 500), startContinuousListening);
      }
    }, onError: (err) {
      Future.delayed(
          const Duration(milliseconds: 500), startContinuousListening);
    });

    if (sttAvailable) {
      startContinuousListening();
    } else {
      final audioRecorder = AudioRecorder();
      if (await audioRecorder.hasPermission()) {
        await audioRecorder
            .startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));
        int loudCounter = 0;

        audioRecorder
            .onAmplitudeChanged(const Duration(milliseconds: 200))
            .listen((amp) {
          if (amp.current > -5.0) {
            loudCounter++;
            if (loudCounter >= 5) {
              triggerHardwareSOS(reason: "Distressed Sound / Scream Detected");
              loudCounter = 0;
            }
          } else {
            loudCounter = 0;
          }
        });
      }
    }
  } catch (e) {
    debugPrint("Voice Engine failed: $e");
  }

  // ===========================================================================
  // 5. RADAR & GUARDIAN RECEIVER
  // ===========================================================================
  int lastReportedThreatCount = 0;

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) return;
    }
    if (!firebaseReady) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();

      final String? myEmail = user?.email ?? prefs.getString('user_email');

      if (firebaseReady && user != null && myEmail != null) {
        final alertDocs = await FirebaseFirestore.instance
            .collection('active_alerts')
            .where('guardianEmails', arrayContains: myEmail)
            .where('timestamp',
                isGreaterThan:
                    DateTime.now().subtract(const Duration(minutes: 10)))
            .get();

        for (var doc in alertDocs.docs) {
          if (!alertedGuardianDocs.contains(doc.id)) {
            alertedGuardianDocs.add(doc.id);
            final data = doc.data();

            final String type = data['type'] ?? 'SOS';
            final String victim = data['victimEmail'] ?? 'A friend';

            if (type == 'DANGER_ZONE') {
              final int threats = data['threatCount'] ?? 1;
              await NotificationService.showGuardianDangerWarning(
                  id: doc.id.hashCode, victim: victim, threats: threats);
            } else {
              final String reason = data['reason'] ?? 'Manual SOS';
              final String pin = data['pin'] ?? 'N/A';
              await NotificationService.showGuardianSOSAlert(
                  id: doc.id.hashCode,
                  victim: victim,
                  reason: reason,
                  pin: pin);
            }
          }
        }
      }

      final pos = await getReliableLocation();
      if (pos == null) {
        throw StateError('Location unavailable for background scan.');
      }
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 2));
      final snapshot = await FirebaseFirestore.instance
          .collection('incidents')
          .where('timestamp', isGreaterThan: cutoffTime)
          .get();

      int nearbyThreats = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'] ?? 0.0;
        final lng = data['lng'] ?? 0.0;
        final distance =
            Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
        if (distance <= 1500) nearbyThreats++;
      }

      if (nearbyThreats > 0) {
        if (nearbyThreats > lastReportedThreatCount) {
          await NotificationService.showDangerNearbyAlert(nearbyThreats);

          final guardians = prefs.getStringList('guardian_emails') ?? [];
          final String victimEmail =
              user?.email ?? prefs.getString('user_email') ?? "Unknown User";

          if (guardians.isNotEmpty && user != null) {
            await FirebaseFirestore.instance.collection('active_alerts').add({
              'victimUid': user.uid,
              'victimEmail': victimEmail,
              'guardianEmails': guardians,
              'lat': pos.latitude,
              'lng': pos.longitude,
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'DANGER_ZONE',
              'threatCount': nearbyThreats,
            });
          }
        }
      }

      lastReportedThreatCount = nearbyThreats;

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "SafeSight Protection Active",
          content: nearbyThreats > 0
              ? "$nearbyThreats active threat(s) nearby."
              : "Area secure. Last checked: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
        );
      }
    } catch (e) {
      debugPrint("Background Engine Error: $e");
    }
  });
}
