import 'dart:typed_data';

import 'package:safesight/src/core/crypto/encrypted_payload.dart';
import 'package:safesight/features/emergency/domain/models/emergency_state.dart';

// ---------------------------------------------------------------------------
// Encrypted Live Session Model
// ---------------------------------------------------------------------------
// Represents a live tracking session where coordinates are E2E encrypted
// per-guardian using X25519 + XSalsa20-Poly1305. Firestore stores only
// opaque ciphertexts — the server cannot read location data.
// ---------------------------------------------------------------------------

class EncryptedLiveSession {
  /// Unique session identifier (UUID v4).
  final String sessionId;

  /// Firebase UID of the person in distress.
  final String victimUid;

  /// Per-guardian encrypted coordinate payloads.
  ///
  /// Keys are guardian IDs; values are encrypted (lat, lng, timestamp).
  /// Only the corresponding guardian can decrypt their own entry using
  /// the shared secret derived from X25519 key exchange.
  final Map<String, EncryptedPayload> encryptedLocations;

  /// Plaintext coordinates (only set when encryption is unavailable).
  /// This is the backwards-compatible fallback.
  final double? plaintextLat;
  final double? plaintextLng;

  /// Encryption algorithm version string.
  /// - "x25519-xsalsa20-poly1305-v1" for encrypted sessions
  /// - "none" for unencrypted fallback
  final String encryptionVersion;

  /// Current phase of this emergency session.
  final EmergencyPhase status;

  /// When the session was created.
  final DateTime createdAt;

  /// When the session was ended (null if still active).
  final DateTime? endedAt;

  /// Optional reason/trigger that started this session.
  final String? triggerReason;

  const EncryptedLiveSession({
    required this.sessionId,
    required this.victimUid,
    this.encryptedLocations = const {},
    this.plaintextLat,
    this.plaintextLng,
    this.encryptionVersion = 'x25519-xsalsa20-poly1305-v1',
    this.status = EmergencyPhase.broadcasting,
    required this.createdAt,
    this.endedAt,
    this.triggerReason,
  });

  /// Whether this session uses E2E encryption.
  bool get isEncrypted => encryptionVersion != 'none';

  /// Whether this session is still actively broadcasting.
  bool get isActive =>
      status == EmergencyPhase.broadcasting ||
      status == EmergencyPhase.coerced;

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toFirestoreMap() {
    final map = <String, dynamic>{
      'sessionId': sessionId,
      'victimUid': victimUid,
      'encryptionVersion': encryptionVersion,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
      if (triggerReason != null) 'triggerReason': triggerReason,
    };

    if (isEncrypted) {
      map['encryptedLocations'] = encryptedLocations.map(
        (guardianId, payload) => MapEntry(guardianId, payload.toBase64()),
      );
    } else {
      map['lat'] = plaintextLat;
      map['lng'] = plaintextLng;
    }

    return map;
  }

  /// Constructs from a Firestore document map.
  factory EncryptedLiveSession.fromFirestoreMap(
    String docId,
    Map<String, dynamic> map,
  ) {
    final encVersion = map['encryptionVersion'] as String? ?? 'none';
    final isEnc = encVersion != 'none';

    Map<String, EncryptedPayload> encLocs = {};
    if (isEnc && map['encryptedLocations'] is Map) {
      final raw = map['encryptedLocations'] as Map<String, dynamic>;
      encLocs = raw.map(
        (key, value) => MapEntry(key, EncryptedPayload.fromBase64(value as String)),
      );
    }

    return EncryptedLiveSession(
      sessionId: docId,
      victimUid: map['victimUid'] as String? ?? '',
      encryptedLocations: encLocs,
      plaintextLat: isEnc ? null : (map['lat'] as num?)?.toDouble(),
      plaintextLng: isEnc ? null : (map['lng'] as num?)?.toDouble(),
      encryptionVersion: encVersion,
      status: _parsePhase(map['status'] as String?),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      endedAt: map['endedAt'] != null
          ? DateTime.tryParse(map['endedAt'] as String)
          : null,
      triggerReason: map['triggerReason'] as String?,
    );
  }

  static EmergencyPhase _parsePhase(String? status) {
    switch (status) {
      case 'broadcasting':
      case 'ACTIVE':
        return EmergencyPhase.broadcasting;
      case 'coerced':
      case 'hostage_coerced':
        return EmergencyPhase.coerced;
      case 'resolved':
      case 'ARRIVED':
        return EmergencyPhase.resolved;
      case 'cancelled':
      case 'CANCELLED':
        return EmergencyPhase.cancelled;
      default:
        return EmergencyPhase.broadcasting;
    }
  }

  EncryptedLiveSession copyWith({
    Map<String, EncryptedPayload>? encryptedLocations,
    double? plaintextLat,
    double? plaintextLng,
    EmergencyPhase? status,
    DateTime? endedAt,
    String? triggerReason,
  }) {
    return EncryptedLiveSession(
      sessionId: sessionId,
      victimUid: victimUid,
      encryptedLocations: encryptedLocations ?? this.encryptedLocations,
      plaintextLat: plaintextLat ?? this.plaintextLat,
      plaintextLng: plaintextLng ?? this.plaintextLng,
      encryptionVersion: encryptionVersion,
      status: status ?? this.status,
      createdAt: createdAt,
      endedAt: endedAt ?? this.endedAt,
      triggerReason: triggerReason ?? this.triggerReason,
    );
  }
}
