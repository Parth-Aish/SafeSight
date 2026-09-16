import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'sensor_datasource.dart';

// ---------------------------------------------------------------------------
// Snatch / Impact Vector Sentry
// ---------------------------------------------------------------------------
// Monitors accelerometer for sudden high-g events indicating phone snatching
// or violent impacts. Uses a two-phase detection algorithm:
//
// Phase 1 (Spike): magnitude > 35 m/s² (sudden snatch or blow)
// Phase 2 (Aftermath): Within 5 seconds of the spike, detect either:
//   (a) Sustained rapid movement: avg magnitude > 15 m/s² for 3 seconds
//   (b) Complete stillness: avg magnitude < 1.0 m/s² for 3 seconds
//
// If both phases match, emits a SnatchEvent for the emergency pipeline.
// ---------------------------------------------------------------------------

/// Represents a detected snatch or violent impact event.
class SnatchEvent {
  /// The peak acceleration magnitude that triggered detection.
  final double peakMagnitude;

  /// What happened after the spike.
  final SnatchAftermath aftermath;

  /// When the initial spike was detected.
  final DateTime detectedAt;

  const SnatchEvent({
    required this.peakMagnitude,
    required this.aftermath,
    required this.detectedAt,
  });

  @override
  String toString() =>
      'SnatchEvent(peak: ${peakMagnitude.toStringAsFixed(1)} m/s², '
      'aftermath: ${aftermath.name}, at: $detectedAt)';
}

enum SnatchAftermath {
  /// Phone was snatched and is being carried away at speed.
  rapidMovement,

  /// Phone hit the ground or user was knocked out — zero motion.
  impactStillness,
}

/// Service that analyzes accelerometer data for snatch/impact patterns.
///
/// Subscribes to [SensorDatasource.accelerometerStream] and emits
/// [SnatchEvent]s when the two-phase detection algorithm triggers.
class MotionSensorService {
  final SensorDatasource _sensorDatasource;

  StreamSubscription<AccelerometerReading>? _subscription;
  final StreamController<SnatchEvent> _eventController =
      StreamController<SnatchEvent>.broadcast();

  // Detection parameters
  static const double _spikeThreshold = 35.0; // m/s²
  static const double _rapidMovementThreshold = 15.0; // m/s²
  static const double _stillnessThreshold = 1.0; // m/s²
  static const Duration _aftermathWindow = Duration(seconds: 5);
  static const Duration _aftermathConfirmDuration = Duration(seconds: 3);
  static const Duration _cooldownDuration = Duration(seconds: 30);

  // State
  bool _isMonitoring = false;
  DateTime? _lastSpikeTime;
  DateTime? _lastEventTime;
  double _spikePeakMagnitude = 0;
  final Queue<AccelerometerReading> _recentReadings =
      Queue<AccelerometerReading>();

  /// Stream of detected snatch/impact events.
  Stream<SnatchEvent> get snatchEvents => _eventController.stream;

  /// Whether the service is actively monitoring.
  bool get isMonitoring => _isMonitoring;

  MotionSensorService(this._sensorDatasource);

  /// Start monitoring accelerometer for snatch patterns.
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    _subscription =
        _sensorDatasource.accelerometerStream.listen(_onAccelerometerReading);
    debugPrint('MotionSensorService: monitoring started');
  }

  /// Stop monitoring.
  void stopMonitoring() {
    _isMonitoring = false;
    _subscription?.cancel();
    _subscription = null;
    _recentReadings.clear();
    _lastSpikeTime = null;
    debugPrint('MotionSensorService: monitoring stopped');
  }

  void _onAccelerometerReading(AccelerometerReading reading) {
    // Maintain a sliding window of recent readings (last 5 seconds)
    _recentReadings.add(reading);
    while (_recentReadings.isNotEmpty &&
        reading.timestamp
                .difference(_recentReadings.first.timestamp)
                .inMilliseconds >
            _aftermathWindow.inMilliseconds) {
      _recentReadings.removeFirst();
    }

    // Phase 1: Detect initial spike
    if (_lastSpikeTime == null && reading.magnitude > _spikeThreshold) {
      // Check cooldown
      if (_lastEventTime != null &&
          reading.timestamp.difference(_lastEventTime!).inSeconds <
              _cooldownDuration.inSeconds) {
        return;
      }

      _lastSpikeTime = reading.timestamp;
      _spikePeakMagnitude = reading.magnitude;
      debugPrint(
        'MotionSensorService: spike detected at ${reading.magnitude.toStringAsFixed(1)} m/s²',
      );
      return;
    }

    // Phase 2: Analyze aftermath within the window
    if (_lastSpikeTime != null) {
      final elapsed = reading.timestamp.difference(_lastSpikeTime!);

      // Wait for enough data (at least 3 seconds after spike)
      if (elapsed < _aftermathConfirmDuration) return;

      // If we've exceeded the aftermath window without triggering, reset
      if (elapsed > _aftermathWindow) {
        _lastSpikeTime = null;
        _spikePeakMagnitude = 0;
        return;
      }

      // Analyze the readings after the spike
      final postSpikeReadings = _recentReadings
          .where((r) => r.timestamp.isAfter(_lastSpikeTime!))
          .toList();

      if (postSpikeReadings.length < 10) return; // Need sufficient data

      final avgMagnitude = postSpikeReadings
              .map((r) => r.magnitude)
              .reduce((a, b) => a + b) /
          postSpikeReadings.length;

      SnatchAftermath? aftermath;

      if (avgMagnitude > _rapidMovementThreshold) {
        aftermath = SnatchAftermath.rapidMovement;
      } else if (avgMagnitude < _stillnessThreshold) {
        aftermath = SnatchAftermath.impactStillness;
      }

      if (aftermath != null) {
        final event = SnatchEvent(
          peakMagnitude: _spikePeakMagnitude,
          aftermath: aftermath,
          detectedAt: _lastSpikeTime!,
        );
        _eventController.add(event);
        _lastEventTime = reading.timestamp;
        _lastSpikeTime = null;
        _spikePeakMagnitude = 0;
        debugPrint('MotionSensorService: SNATCH EVENT: $event');
      }
    }
  }

  /// Releases all resources.
  void dispose() {
    stopMonitoring();
    _eventController.close();
  }
}
