import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ---------------------------------------------------------------------------
// Sensor Datasource
// ---------------------------------------------------------------------------
// Central hub for all device sensor streams. Manages lifecycle (pause/resume)
// to preserve battery when features are disabled. All emergency feature
// services subscribe to streams from this hub rather than directly accessing
// hardware sensors.
// ---------------------------------------------------------------------------

/// Raw accelerometer reading with computed magnitude.
class AccelerometerReading {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  AccelerometerReading({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  }) : magnitude = sqrt(x * x + y * y + z * z);

  @override
  String toString() =>
      'AccelerometerReading(mag: ${magnitude.toStringAsFixed(1)} m/s², '
      'x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, z: ${z.toStringAsFixed(1)})';
}

/// Manages raw sensor subscriptions and exposes filtered streams.
///
/// Call [initialize] to start, [pauseAll] to suspend sensors for battery
/// savings, and [resumeAll] to reactivate. Call [dispose] when no longer
/// needed.
class SensorDatasource {
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  final StreamController<AccelerometerReading> _accelController =
      StreamController<AccelerometerReading>.broadcast();

  bool _isPaused = false;
  bool _isInitialized = false;

  /// Whether sensor streams are currently paused.
  bool get isPaused => _isPaused;

  /// Whether the datasource has been initialized.
  bool get isInitialized => _isInitialized;

  /// Filtered accelerometer readings at ~50 Hz.
  ///
  /// Uses `UserAccelerometerEvent` which excludes gravity, making it
  /// appropriate for detecting sudden jerks, impacts, and snatches.
  Stream<AccelerometerReading> get accelerometerStream =>
      _accelController.stream;

  /// Initializes hardware sensor subscriptions.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    _startAccelerometer();
    debugPrint('SensorDatasource: initialized');
  }

  void _startAccelerometer() {
    _accelSubscription?.cancel();
    try {
      _accelSubscription =
          userAccelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 20), // ~50 Hz
          ).listen(
        (event) {
          if (!_isPaused) {
            _accelController.add(AccelerometerReading(
              x: event.x,
              y: event.y,
              z: event.z,
              timestamp: DateTime.now(),
            ));
          }
        },
        onError: (error) {
          debugPrint('SensorDatasource: accelerometer error: $error');
        },
      );
    } catch (e) {
      debugPrint('SensorDatasource: failed to start accelerometer: $e');
    }
  }

  /// Pauses all sensor streams to conserve battery.
  ///
  /// Call this when the user disables background protection or
  /// when the app enters a state where sensors aren't needed.
  void pauseAll() {
    if (_isPaused) return;
    _isPaused = true;
    debugPrint('SensorDatasource: paused');
  }

  /// Resumes all sensor streams.
  void resumeAll() {
    if (!_isPaused) return;
    _isPaused = false;
    debugPrint('SensorDatasource: resumed');
  }

  /// Permanently shuts down all sensor subscriptions.
  void dispose() {
    _accelSubscription?.cancel();
    _accelController.close();
    _isInitialized = false;
    debugPrint('SensorDatasource: disposed');
  }
}
