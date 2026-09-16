import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// Defensive Action Service
// ---------------------------------------------------------------------------
// Provides two tactical defense mechanisms:
//
// 1. Tactical Strobe: Toggles camera torch at 15 Hz to disorient/deter
// 2. Evidence Burst: Silently captures front/back camera frames as WebP
//
// Uses the `camera` package for both torch and image capture.
// ---------------------------------------------------------------------------

/// Controls defensive actions: tactical strobe and evidence capture.
class DefensiveActionService {
  CameraController? _rearController;
  CameraController? _frontController;
  Timer? _strobeTimer;
  bool _strobeActive = false;
  bool _isInitialized = false;

  /// Whether the strobe is currently active.
  bool get isStrobeActive => _strobeActive;

  /// Initialize camera controllers.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final cameras = await availableCameras();
      final rearCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _rearController = CameraController(
        rearCamera,
        ResolutionPreset.low, // low res for speed
        enableAudio: false,
      );
      await _rearController!.initialize();

      // Find front camera if available
      final frontCamera = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (frontCamera.isNotEmpty) {
        _frontController = CameraController(
          frontCamera.first,
          ResolutionPreset.low,
          enableAudio: false,
        );
        await _frontController!.initialize();
      }

      _isInitialized = true;
      debugPrint('DefensiveActionService: initialized');
    } catch (e) {
      debugPrint('DefensiveActionService: camera init failed: $e');
    }
  }

  // -------------------------------------------------------------------------
  // 1. Tactical Strobe (15 Hz torch toggle)
  // -------------------------------------------------------------------------

  /// Activates the camera torch in a 15 Hz strobe pattern.
  ///
  /// The torch toggles every ~33ms (half of 15 Hz period).
  /// Call [deactivateStrobe] to stop.
  Future<void> activateStrobe() async {
    if (_strobeActive) return;
    if (_rearController == null || !_rearController!.value.isInitialized) {
      await initialize();
    }
    if (_rearController == null) return;

    _strobeActive = true;
    bool torchOn = false;

    // 15 Hz = 66ms period, toggle every 33ms
    _strobeTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (timer) async {
        if (!_strobeActive) {
          timer.cancel();
          return;
        }
        try {
          torchOn = !torchOn;
          await _rearController!.setFlashMode(
            torchOn ? FlashMode.torch : FlashMode.off,
          );
        } catch (e) {
          // Torch control may fail on some devices
          debugPrint('DefensiveActionService: strobe error: $e');
        }
      },
    );

    debugPrint('DefensiveActionService: strobe ACTIVATED at 15 Hz');
  }

  /// Deactivates the strobe and ensures torch is off.
  Future<void> deactivateStrobe() async {
    _strobeActive = false;
    _strobeTimer?.cancel();
    _strobeTimer = null;

    try {
      await _rearController?.setFlashMode(FlashMode.off);
    } catch (_) {}

    debugPrint('DefensiveActionService: strobe DEACTIVATED');
  }

  // -------------------------------------------------------------------------
  // 2. Evidence Burst Capture
  // -------------------------------------------------------------------------

  /// Captures [frameCount] frames from both cameras silently.
  ///
  /// Returns a list of file paths to the captured images.
  /// Images are saved as JPG (converted to WebP by evidence vault).
  Future<List<String>> captureEvidenceBurst({int frameCount = 5}) async {
    final paths = <String>[];

    // Pause strobe during capture
    final wasStrobing = _strobeActive;
    if (wasStrobing) await deactivateStrobe();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Capture from rear camera
      if (_rearController != null && _rearController!.value.isInitialized) {
        for (var i = 0; i < frameCount; i++) {
          try {
            final file = await _rearController!.takePicture();
            final newPath = '${dir.path}/evidence_rear_${timestamp}_$i.jpg';
            await file.saveTo(newPath);
            paths.add(newPath);
            // Small delay between captures
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (e) {
            debugPrint('DefensiveActionService: rear capture $i failed: $e');
          }
        }
      }

      // Capture from front camera
      if (_frontController != null && _frontController!.value.isInitialized) {
        for (var i = 0; i < frameCount; i++) {
          try {
            final file = await _frontController!.takePicture();
            final newPath = '${dir.path}/evidence_front_${timestamp}_$i.jpg';
            await file.saveTo(newPath);
            paths.add(newPath);
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (e) {
            debugPrint('DefensiveActionService: front capture $i failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('DefensiveActionService: evidence burst failed: $e');
    }

    // Resume strobe if it was active
    if (wasStrobing) await activateStrobe();

    debugPrint('DefensiveActionService: captured ${paths.length} evidence frames');
    return paths;
  }

  /// Releases camera resources.
  Future<void> dispose() async {
    await deactivateStrobe();
    await _rearController?.dispose();
    await _frontController?.dispose();
    _rearController = null;
    _frontController = null;
    _isInitialized = false;
  }
}
