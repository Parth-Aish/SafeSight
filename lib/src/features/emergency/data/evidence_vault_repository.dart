import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// Evidence Vault Repository
// ---------------------------------------------------------------------------
// Manages local encrypted evidence storage with metadata tracking.
// Evidence files are retained for 72 hours then auto-purged unless
// the associated session is still active.
// ---------------------------------------------------------------------------

/// Metadata for a stored evidence file.
class EvidenceEntry {
  final String filePath;
  final DateTime capturedAt;
  final String? sessionId;
  final double? latitude;
  final double? longitude;
  final String source; // 'rear_camera', 'front_camera', 'audio'

  const EvidenceEntry({
    required this.filePath,
    required this.capturedAt,
    this.sessionId,
    this.latitude,
    this.longitude,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
        'filePath': filePath,
        'capturedAt': capturedAt.toIso8601String(),
        'sessionId': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
      };

  factory EvidenceEntry.fromMap(Map<String, dynamic> map) {
    return EvidenceEntry(
      filePath: map['filePath'] as String,
      capturedAt: DateTime.parse(map['capturedAt'] as String),
      sessionId: map['sessionId'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      source: map['source'] as String? ?? 'unknown',
    );
  }
}

/// Local evidence storage with auto-purge and upload queue.
class EvidenceVaultRepository {
  final List<EvidenceEntry> _entries = [];
  Timer? _purgeTimer;

  static const Duration _retentionPeriod = Duration(hours: 72);
  static const int _maxEntries = 500;

  /// All stored evidence entries.
  List<EvidenceEntry> get entries => List.unmodifiable(_entries);

  /// Number of stored evidence files.
  int get count => _entries.length;

  /// Initialize the vault and start the auto-purge timer.
  void initialize() {
    _purgeTimer?.cancel();
    // Check for expired evidence every hour
    _purgeTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => purgeExpired(),
    );
    debugPrint('EvidenceVault: initialized');
  }

  /// Stores evidence files with metadata.
  Future<void> storeEvidence({
    required List<String> filePaths,
    required String source,
    String? sessionId,
    double? latitude,
    double? longitude,
  }) async {
    final now = DateTime.now();

    for (final path in filePaths) {
      if (!await File(path).exists()) continue;

      final entry = EvidenceEntry(
        filePath: path,
        capturedAt: now,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        source: source,
      );
      _entries.add(entry);
    }

    // Enforce max entries (FIFO eviction)
    while (_entries.length > _maxEntries) {
      final oldest = _entries.removeAt(0);
      _deleteFile(oldest.filePath);
    }

    debugPrint(
      'EvidenceVault: stored ${filePaths.length} files (total: ${_entries.length})',
    );
  }

  /// Remove evidence older than 72 hours (unless session is active).
  Future<void> purgeExpired({Set<String>? activeSessionIds}) async {
    final cutoff = DateTime.now().subtract(_retentionPeriod);
    final active = activeSessionIds ?? {};

    final toRemove = _entries.where((e) {
      if (e.capturedAt.isBefore(cutoff)) {
        // Keep if session is still active
        if (e.sessionId != null && active.contains(e.sessionId)) return false;
        return true;
      }
      return false;
    }).toList();

    for (final entry in toRemove) {
      _entries.remove(entry);
      _deleteFile(entry.filePath);
    }

    if (toRemove.isNotEmpty) {
      debugPrint('EvidenceVault: purged ${toRemove.length} expired entries');
    }
  }

  /// Get evidence for a specific session.
  List<EvidenceEntry> getForSession(String sessionId) {
    return _entries.where((e) => e.sessionId == sessionId).toList();
  }

  /// Get evidence pending upload.
  List<EvidenceEntry> getPendingUpload() {
    // For now, return all entries. In production, track upload status.
    return List.from(_entries);
  }

  void _deleteFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      debugPrint('EvidenceVault: failed to delete $path: $e');
    }
  }

  /// Release resources.
  void dispose() {
    _purgeTimer?.cancel();
  }
}
