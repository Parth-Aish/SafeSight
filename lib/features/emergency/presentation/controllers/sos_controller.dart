import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/sos_repository.dart';
import '../../domain/models/emergency_state.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final sosRepositoryProvider = Provider<SosRepository>((ref) => SosRepository());
final sosControllerProvider =
    NotifierProvider<SosController, EmergencyState>(SosController.new);

// ---------------------------------------------------------------------------
// SOS Controller
// ---------------------------------------------------------------------------
// Manages the full emergency lifecycle including:
//   - Manual SOS (hold-to-trigger)
//   - Snatch/impact auto-trigger with verification countdown
//   - Audio distress auto-trigger
//   - Walk With Me dead-man's switch
//   - Duress PIN covert escalation
//   - Normal safety PIN cancellation
// ---------------------------------------------------------------------------

class SosController extends Notifier<EmergencyState> {
  @override
  EmergencyState build() => const EmergencyState();

  // ---- Manual SOS Flow ----

  void beginPress() {
    if (state.phase == EmergencyPhase.idle) {
      state = state.copyWith(
        phase: EmergencyPhase.pressing,
        changedAt: DateTime.now(),
        triggerSource: 'manual',
      );
    }
  }

  void cancelPress() {
    if (state.phase == EmergencyPhase.pressing) {
      state = state.copyWith(
        phase: EmergencyPhase.idle,
        changedAt: DateTime.now(),
      );
    }
  }

  /// Triggers emergency from manual SOS hold.
  Future<void> trigger(Position position) async {
    state = state.copyWith(
      phase: EmergencyPhase.triggered,
      changedAt: DateTime.now(),
      triggerSource: 'manual',
    );
    await _createSession(position, reason: 'Manual SOS');
  }

  // ---- Snatch / Impact Auto-Trigger ----

  /// Called by MotionSensorService when a snatch/impact is detected.
  /// Starts a 15-second verification countdown.
  void onSnatchDetected() {
    if (state.phase != EmergencyPhase.idle) return;

    state = state.copyWith(
      phase: EmergencyPhase.snatchDetected,
      changedAt: DateTime.now(),
      countdownSeconds: 15,
      triggerSource: 'snatch',
    );
    HapticFeedback.heavyImpact();
  }

  /// User confirms they are OK during snatch verification.
  void cancelSnatchVerification() {
    if (state.phase == EmergencyPhase.snatchDetected) {
      state = state.copyWith(
        phase: EmergencyPhase.idle,
        changedAt: DateTime.now(),
        countdownSeconds: null,
        triggerSource: null,
      );
    }
  }

  /// Snatch countdown expired — escalate to full SOS.
  Future<void> escalateSnatch(Position position) async {
    if (state.phase != EmergencyPhase.snatchDetected) return;

    state = state.copyWith(
      phase: EmergencyPhase.triggered,
      changedAt: DateTime.now(),
      countdownSeconds: null,
      triggerSource: 'snatch',
    );
    await _createSession(position, reason: 'Snatch/Impact Detected');
  }

  // ---- Audio Distress Trigger ----

  /// Called by AudioClassifierService when distress sounds are detected.
  Future<void> onAudioDistressDetected(Position position) async {
    if (state.phase != EmergencyPhase.idle) return;

    state = state.copyWith(
      phase: EmergencyPhase.triggered,
      changedAt: DateTime.now(),
      triggerSource: 'audio',
    );
    await _createSession(position, reason: 'Distress Sound Detected');
  }

  // ---- Duress / Coercion PIN Cancellation ----

  /// Cancels (or covertly escalates) the emergency based on PIN type.
  ///
  /// - [PinType.safety]: Genuine cancellation, session resolved.
  /// - [PinType.duress]: Fake cancellation shown, but session continues
  ///   with status 'hostage_coerced' and silent guardian notification.
  /// - [PinType.invalid]: No action, returns false.
  Future<bool> cancelWithPin(String pin, PinType pinType) async {
    if (!state.isActive &&
        state.phase != EmergencyPhase.walkWithMePinChallenge) {
      return false;
    }

    switch (pinType) {
      case PinType.safety:
        // Genuine cancellation
        final sessionId = state.sessionId;
        if (sessionId != null) {
          await ref
              .read(sosRepositoryProvider)
              .resolveSession(sessionId, status: 'CANCELLED');
        }
        state = state.copyWith(
          phase: EmergencyPhase.cancelled,
          changedAt: DateTime.now(),
        );
        return true;

      case PinType.duress:
        // COVERT: Show fake cancellation but maintain tracking
        final sessionId = state.sessionId;
        if (sessionId != null) {
          await ref
              .read(sosRepositoryProvider)
              .markCoerced(sessionId);
        }
        state = state.copyWith(
          phase: EmergencyPhase.coerced,
          changedAt: DateTime.now(),
        );
        debugPrint('🚨 DURESS PIN ENTERED — covert tracking maintained');
        return true;

      case PinType.invalid:
        return false;
    }
  }

  // ---- Standard Cancel / Reset ----

  Future<void> cancel() async {
    final sessionId = state.sessionId;
    if (sessionId != null) {
      await ref.read(sosRepositoryProvider).resolveSession(sessionId);
    }
    state = state.copyWith(
      phase: EmergencyPhase.cancelled,
      changedAt: DateTime.now(),
    );
  }

  void reset() => state = const EmergencyState();

  /// Update countdown display (called by timer in UI).
  void updateCountdown(int seconds) {
    state = state.copyWith(countdownSeconds: seconds);
  }

  // ---- Internal ----

  Future<void> _createSession(Position position, {String? reason}) async {
    try {
      final sessionId = await ref
          .read(sosRepositoryProvider)
          .createSession(position, reason: reason);
      state = state.copyWith(
        phase: EmergencyPhase.broadcasting,
        sessionId: sessionId,
        changedAt: DateTime.now(),
      );
    } catch (error) {
      state = state.copyWith(
        phase: EmergencyPhase.failed,
        failureMessage:
            'Emergency session could not start. Check your connection.',
        changedAt: DateTime.now(),
      );
    }
  }
}

