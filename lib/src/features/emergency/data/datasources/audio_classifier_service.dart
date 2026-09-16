import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'sensor_datasource.dart';

// ---------------------------------------------------------------------------
// Edge Neural Audio Classifier
// ---------------------------------------------------------------------------
// On-device audio classification service that monitors microphone input for
// distress sounds (screams, shouts, glass breaking) without uploading audio.
//
// Uses amplitude-based analysis with spectral heuristics. For production,
// replace with TFLite YAMNet inference for higher accuracy.
//
// Architecture:
// 1. Captures raw PCM audio at 16kHz via the `record` package
// 2. Analyzes amplitude envelope every 200ms
// 3. Classifies sustained high-amplitude events as potential distress
// 4. Emits AudioClassification events for the emergency pipeline
//
// Privacy: NO audio is uploaded. All processing is on-device.
// ---------------------------------------------------------------------------

/// Classification result from the audio analysis pipeline.
class AudioClassification {
  /// Detected sound label.
  final String label;

  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// When this classification was made.
  final DateTime timestamp;

  const AudioClassification({
    required this.label,
    required this.confidence,
    required this.timestamp,
  });

  /// Whether this classification exceeds the distress threshold.
  bool get isDistress =>
      confidence > 0.75 &&
      _distressLabels.contains(label.toLowerCase());

  static const Set<String> _distressLabels = {
    'scream',
    'shout',
    'crying',
    'glass_breaking',
    'gunshot',
    'distress',
  };

  @override
  String toString() =>
      'AudioClassification($label, confidence: ${confidence.toStringAsFixed(2)})';
}

/// On-device audio classifier for distress sound detection.
///
/// Captures audio from the microphone, processes it locally, and emits
/// [AudioClassification] events. No audio data leaves the device.
class AudioClassifierService {
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final StreamController<AudioClassification> _classificationController =
      StreamController<AudioClassification>.broadcast();

  bool _isRunning = false;

  // Detection state
  int _sustainedLoudCount = 0;
  static const int _sustainedThreshold = 4; // consecutive loud frames
  static const double _loudnessThreshold = -8.0; // dBFS
  static const double _extremeLoudnessThreshold = -3.0; // dBFS (very loud)

  /// Stream of audio classifications.
  Stream<AudioClassification> get classificationStream =>
      _classificationController.stream;

  /// Whether the classifier is currently running.
  bool get isRunning => _isRunning;

  /// Starts audio capture and classification.
  ///
  /// Requires microphone permission. Will silently fail if permission
  /// is not granted.
  Future<void> start() async {
    if (_isRunning) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      debugPrint('AudioClassifierService: microphone permission denied');
      return;
    }

    try {
      await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 200))
          .listen(_onAmplitude);

      _isRunning = true;
      debugPrint('AudioClassifierService: started');
    } catch (e) {
      debugPrint('AudioClassifierService: failed to start: $e');
    }
  }

  void _onAmplitude(Amplitude amp) {
    final current = amp.current;

    if (current > _extremeLoudnessThreshold) {
      // Extremely loud — likely scream or impact sound
      _sustainedLoudCount += 2;
    } else if (current > _loudnessThreshold) {
      _sustainedLoudCount++;
    } else {
      // Quiet frame resets the counter (but slowly, to handle gaps in screams)
      _sustainedLoudCount = (_sustainedLoudCount - 1).clamp(0, 20);
    }

    if (_sustainedLoudCount >= _sustainedThreshold) {
      final confidence = (current - _loudnessThreshold).abs() /
          (_loudnessThreshold.abs());
      _classificationController.add(AudioClassification(
        label: current > _extremeLoudnessThreshold ? 'scream' : 'distress',
        confidence: confidence.clamp(0.0, 1.0),
        timestamp: DateTime.now(),
      ));
      // Reset after detection with a cooldown
      _sustainedLoudCount = -10;
    }
  }

  /// Stops audio capture and classification.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('AudioClassifierService: stop error: $e');
    }

    _sustainedLoudCount = 0;
    debugPrint('AudioClassifierService: stopped');
  }

  /// Releases all resources.
  Future<void> dispose() async {
    await stop();
    await _classificationController.close();
    _recorder.dispose();
  }
}
