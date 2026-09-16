import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

/// Repository for managing emergency live session documents in Firestore.
///
/// Supports encrypted and plaintext sessions, coerced (duress) status,
/// and multi-source trigger reasons for audit trail.
class SosRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid;

  SosRepository({FirebaseFirestore? firestore, FirebaseAuth? auth, Uuid? uuid})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _uuid = uuid ?? const Uuid();

  /// Creates a new live session and returns the session ID.
  ///
  /// [reason] is recorded for audit trail (e.g., "Manual SOS",
  /// "Snatch/Impact Detected", "Distress Sound Detected").
  Future<String> createSession(
    Position position, {
    String? reason,
  }) async {
    final sessionId = _uuid.v4();
    await _firestore.collection('live_sessions').doc(sessionId).set({
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'ACTIVE',
      'createdAt': FieldValue.serverTimestamp(),
      'victimUid': _auth.currentUser?.uid,
      'encryptionVersion': 'none', // plaintext fallback
      if (reason != null) 'triggerReason': reason,
    });
    return sessionId;
  }

  /// Updates the location of an active session.
  Future<void> updateLocation(String sessionId, Position position) {
    return _firestore.collection('live_sessions').doc(sessionId).set({
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'ACTIVE',
    }, SetOptions(merge: true));
  }

  /// Resolves a session with a terminal status.
  Future<void> resolveSession(
    String sessionId, {
    String status = 'CANCELLED',
  }) {
    return _firestore.collection('live_sessions').doc(sessionId).set({
      'status': status,
      'endedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Marks a session as coerced (duress PIN entered).
  ///
  /// The session remains active with silent location tracking.
  /// Status is set to 'hostage_coerced' which triggers special
  /// handling in guardian notification logic.
  Future<void> markCoerced(String sessionId) {
    return _firestore.collection('live_sessions').doc(sessionId).set({
      'status': 'hostage_coerced',
      'coercedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Creates an active alert for guardian notification.
  ///
  /// [type] values: 'SOS', 'DANGER_ZONE', 'DURESS_COERCION'
  Future<void> createGuardianAlert({
    required Position position,
    required String sessionId,
    required List<String> guardianEmails,
    required String type,
    String? reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null || guardianEmails.isEmpty) return;

    await _firestore.collection('active_alerts').add({
      'victimUid': user.uid,
      'victimEmail': user.email ?? 'Unknown',
      'guardianEmails': guardianEmails,
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'pin': sessionId.substring(0, 6).toUpperCase(),
      'type': type,
      'reason': reason ?? type,
      'sessionId': sessionId,
    });
  }

  /// Creates a silent duress alert for guardians.
  ///
  /// This is dispatched when the user enters a duress PIN, indicating
  /// they are being coerced. The alert contains a special type that
  /// guardian clients render as a critical silent notification.
  Future<void> createDuressAlert({
    required Position position,
    required String sessionId,
    required List<String> guardianEmails,
  }) async {
    await createGuardianAlert(
      position: position,
      sessionId: sessionId,
      guardianEmails: guardianEmails,
      type: 'DURESS_COERCION',
      reason: 'USER ENTERED DURESS PIN - DO NOT CALL, SEND ASSISTANCE',
    );
  }
}

