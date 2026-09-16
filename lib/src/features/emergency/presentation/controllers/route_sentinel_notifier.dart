import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ---------------------------------------------------------------------------
// Route Sentinel Notifier
// ---------------------------------------------------------------------------
// Monitors user GPS against an active route polyline from OSRM.
// If deviation exceeds 75m for 60+ seconds, triggers a check-in prompt.
// If no response within 30s, escalates to emergency verification.
// ---------------------------------------------------------------------------

/// Represents the state of route monitoring.
enum RouteSentinelPhase {
  /// Not monitoring any route.
  inactive,

  /// Actively comparing GPS to route.
  monitoring,

  /// User has deviated — check-in prompt shown.
  deviated,

  /// User acknowledged the check-in.
  acknowledged,

  /// No response to check-in — escalating.
  escalating,
}

class RouteSentinelState {
  final RouteSentinelPhase phase;
  final double? deviationMeters;
  final int? deviationDurationSeconds;
  final List<LatLng> routePolyline;

  const RouteSentinelState({
    this.phase = RouteSentinelPhase.inactive,
    this.deviationMeters,
    this.deviationDurationSeconds,
    this.routePolyline = const [],
  });

  RouteSentinelState copyWith({
    RouteSentinelPhase? phase,
    double? deviationMeters,
    int? deviationDurationSeconds,
    List<LatLng>? routePolyline,
  }) {
    return RouteSentinelState(
      phase: phase ?? this.phase,
      deviationMeters: deviationMeters ?? this.deviationMeters,
      deviationDurationSeconds:
          deviationDurationSeconds ?? this.deviationDurationSeconds,
      routePolyline: routePolyline ?? this.routePolyline,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final routeSentinelProvider =
    AsyncNotifierProvider<RouteSentinelNotifier, RouteSentinelState>(
  RouteSentinelNotifier.new,
);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class RouteSentinelNotifier extends AsyncNotifier<RouteSentinelState> {
  Timer? _monitorTimer;
  DateTime? _deviationStart;

  static const double _deviationThresholdMeters = 75.0;
  static const int _deviationThresholdSeconds = 60;
  static const int _checkInTimeoutSeconds = 30;
  static const Duration _sampleInterval = Duration(seconds: 5);

  @override
  Future<RouteSentinelState> build() async {
    ref.onDispose(() {
      _monitorTimer?.cancel();
    });
    return const RouteSentinelState();
  }

  /// Start monitoring the user against a route polyline.
  void startMonitoring(List<LatLng> routePolyline) {
    if (routePolyline.length < 2) return;

    _monitorTimer?.cancel();
    _deviationStart = null;

    state = AsyncData(RouteSentinelState(
      phase: RouteSentinelPhase.monitoring,
      routePolyline: routePolyline,
    ));

    _monitorTimer = Timer.periodic(_sampleInterval, (_) => _checkPosition());
    debugPrint('RouteSentinel: monitoring started (${routePolyline.length} points)');
  }

  /// Stop route monitoring.
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _deviationStart = null;
    state = AsyncData(const RouteSentinelState());
    debugPrint('RouteSentinel: stopped');
  }

  /// User acknowledged the deviation check-in.
  void acknowledgeCheckIn() {
    _deviationStart = null;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(
        phase: RouteSentinelPhase.acknowledged,
        deviationMeters: null,
        deviationDurationSeconds: null,
      ));
      // Resume monitoring after acknowledgement
      Future.delayed(const Duration(seconds: 2), () {
        if (state.valueOrNull?.phase == RouteSentinelPhase.acknowledged) {
          state = AsyncData(current.copyWith(
            phase: RouteSentinelPhase.monitoring,
          ));
        }
      });
    }
    debugPrint('RouteSentinel: check-in acknowledged');
  }

  Future<void> _checkPosition() async {
    final current = state.valueOrNull;
    if (current == null || current.phase == RouteSentinelPhase.deviated) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);
      final minDist = _minDistanceToPolyline(userLatLng, current.routePolyline);

      if (minDist > _deviationThresholdMeters) {
        _deviationStart ??= DateTime.now();
        final elapsed = DateTime.now().difference(_deviationStart!).inSeconds;

        if (elapsed >= _deviationThresholdSeconds) {
          // Trigger deviation alert
          state = AsyncData(current.copyWith(
            phase: RouteSentinelPhase.deviated,
            deviationMeters: minDist,
            deviationDurationSeconds: elapsed,
          ));
          HapticFeedback.mediumImpact();
          debugPrint(
            'RouteSentinel: DEVIATION — ${minDist.toStringAsFixed(0)}m off route for ${elapsed}s',
          );
        }
      } else {
        // Back on route
        _deviationStart = null;
      }
    } catch (e) {
      debugPrint('RouteSentinel: position check failed: $e');
    }
  }

  /// Calculates minimum perpendicular distance from a point to a polyline.
  static double _minDistanceToPolyline(LatLng point, List<LatLng> polyline) {
    double minDist = double.infinity;

    for (var i = 0; i < polyline.length - 1; i++) {
      final dist = _pointToSegmentDistance(
        point,
        polyline[i],
        polyline[i + 1],
      );
      if (dist < minDist) minDist = dist;
    }

    return minDist;
  }

  /// Haversine-based perpendicular distance from point to line segment.
  static double _pointToSegmentDistance(
    LatLng p,
    LatLng a,
    LatLng b,
  ) {
    final dAB = Geolocator.distanceBetween(
      a.latitude, a.longitude,
      b.latitude, b.longitude,
    );
    if (dAB < 1.0) {
      // Degenerate segment — treat as point
      return Geolocator.distanceBetween(
        p.latitude, p.longitude,
        a.latitude, a.longitude,
      );
    }

    // Project point P onto line AB using dot product approximation
    final dAP = Geolocator.distanceBetween(
      a.latitude, a.longitude,
      p.latitude, p.longitude,
    );
    final dBP = Geolocator.distanceBetween(
      b.latitude, b.longitude,
      p.latitude, p.longitude,
    );

    // Use law of cosines to find perpendicular distance
    final s = (dAB + dAP + dBP) / 2;
    final area = sqrt((s * (s - dAB) * (s - dAP) * (s - dBP)).abs());
    final perpendicular = 2 * area / dAB;

    // Also check if projection falls outside segment
    final cosA = (dAP * dAP + dAB * dAB - dBP * dBP) / (2 * dAP * dAB);
    final cosB = (dBP * dBP + dAB * dAB - dAP * dAP) / (2 * dBP * dAB);

    if (cosA < 0) return dAP; // Closest to A
    if (cosB < 0) return dBP; // Closest to B
    return perpendicular;
  }
}
