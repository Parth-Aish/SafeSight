import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ---------------------------------------------------------------------------
// Connectivity Status
// ---------------------------------------------------------------------------

enum ConnectivityStatus {
  /// Device has a working internet connection (WiFi, mobile data, ethernet).
  online,

  /// Device has no internet connectivity at all.
  offline,

  /// Connectivity check is still in progress.
  checking,
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Streams the device's connectivity status.
///
/// On first listen, immediately checks current connectivity and emits.
/// Subsequent emissions are driven by platform connectivity change events.
final connectivityStatusProvider =
    StreamProvider<ConnectivityStatus>((ref) async* {
  final connectivity = Connectivity();

  // Initial check
  yield ConnectivityStatus.checking;
  final initial = await connectivity.checkConnectivity();
  yield _mapResult(initial);

  // Ongoing changes
  await for (final result in connectivity.onConnectivityChanged) {
    yield _mapResult(result);
  }
});

/// Convenience provider that returns `true` when the device is offline.
final isOfflineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.valueOrNull == ConnectivityStatus.offline;
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConnectivityStatus _mapResult(List<ConnectivityResult> results) {
  if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
    return ConnectivityStatus.offline;
  }
  return ConnectivityStatus.online;
}
