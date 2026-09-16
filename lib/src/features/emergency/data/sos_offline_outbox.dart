import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// SOS Offline Outbox
// ---------------------------------------------------------------------------
// Persists pending SOS payloads locally when the device is offline.
// Automatically replays them to Firestore when connectivity is restored.
// Maximum queue depth: 100 entries with FIFO eviction.
// ---------------------------------------------------------------------------

/// A pending SOS payload waiting to be sent to the server.
class PendingSosPayload {
  final String sessionId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String triggerReason;
  final String? victimUid;
  final List<String> guardianEmails;
  final int retryCount;

  const PendingSosPayload({
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.triggerReason,
    this.victimUid,
    this.guardianEmails = const [],
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'triggerReason': triggerReason,
        'victimUid': victimUid,
        'guardianEmails': guardianEmails,
        'retryCount': retryCount,
      };

  factory PendingSosPayload.fromJson(Map<String, dynamic> json) {
    return PendingSosPayload(
      sessionId: json['sessionId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      triggerReason: json['triggerReason'] as String? ?? 'Unknown',
      victimUid: json['victimUid'] as String?,
      guardianEmails: (json['guardianEmails'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  PendingSosPayload copyWith({int? retryCount}) {
    return PendingSosPayload(
      sessionId: sessionId,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      triggerReason: triggerReason,
      victimUid: victimUid,
      guardianEmails: guardianEmails,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Offline outbox for SOS payloads with automatic replay.
class SosOfflineOutbox {
  static const String _storageKey = 'sos_offline_outbox';
  static const int _maxQueueDepth = 100;
  static const int _maxRetries = 5;

  final List<PendingSosPayload> _queue = [];

  /// All pending payloads.
  List<PendingSosPayload> get pending => List.unmodifiable(_queue);

  /// Number of pending payloads.
  int get count => _queue.length;

  /// Enqueue a payload for later delivery.
  Future<void> enqueue(PendingSosPayload payload) async {
    _queue.add(payload);

    // FIFO eviction if over limit
    while (_queue.length > _maxQueueDepth) {
      _queue.removeAt(0);
    }

    await _persist();
    debugPrint('SosOutbox: enqueued (total: ${_queue.length})');
  }

  /// Replay all pending payloads using the provided callback.
  ///
  /// [sender] should attempt to write the payload to Firestore and
  /// return true on success, false on failure.
  Future<int> replay(
    Future<bool> Function(PendingSosPayload payload) sender,
  ) async {
    if (_queue.isEmpty) return 0;

    final toSend = List<PendingSosPayload>.from(_queue);
    var sentCount = 0;

    for (final payload in toSend) {
      if (payload.retryCount >= _maxRetries) {
        _queue.remove(payload);
        debugPrint('SosOutbox: dropped payload ${payload.sessionId} '
            '(max retries exceeded)');
        continue;
      }

      try {
        final success = await sender(payload);
        if (success) {
          _queue.remove(payload);
          sentCount++;
          debugPrint('SosOutbox: sent ${payload.sessionId}');
        } else {
          final idx = _queue.indexOf(payload);
          if (idx >= 0) {
            _queue[idx] = payload.copyWith(retryCount: payload.retryCount + 1);
          }
        }
      } catch (e) {
        debugPrint('SosOutbox: send failed for ${payload.sessionId}: $e');
        final idx = _queue.indexOf(payload);
        if (idx >= 0) {
          _queue[idx] = payload.copyWith(retryCount: payload.retryCount + 1);
        }
      }
    }

    await _persist();
    debugPrint('SosOutbox: replay complete ($sentCount sent, '
        '${_queue.length} remaining)');
    return sentCount;
  }

  /// Load persisted queue from SharedPreferences.
  Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _queue.clear();
        _queue.addAll(
          list.map((e) =>
              PendingSosPayload.fromJson(e as Map<String, dynamic>)),
        );
        debugPrint('SosOutbox: loaded ${_queue.length} pending from disk');
      }
    } catch (e) {
      debugPrint('SosOutbox: load failed: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('SosOutbox: persist failed: $e');
    }
  }

  /// Clear all pending payloads.
  Future<void> clear() async {
    _queue.clear();
    await _persist();
    debugPrint('SosOutbox: cleared');
  }
}
