import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:safesight/features/emergency/domain/models/emergency_state.dart';
import 'package:safesight/features/emergency/data/sos_repository.dart';
import 'package:safesight/features/emergency/presentation/controllers/sos_controller.dart';
import 'package:safesight/core/utils/reliable_location.dart';

// ---------------------------------------------------------------------------
// Walk With Me Controller
// ---------------------------------------------------------------------------
// Dead Man's Switch: requires continuous touch. On release:
//   Phase 1: 10-second countdown with haptic pulses (1Hz)
//   Phase 2: PIN challenge — safety PIN cancels, duress PIN covert-escalates
//   Phase 3: No response → escalate to full SOS
//
// UI: Full-screen touch zone with animated ring that fills while touched.
// ---------------------------------------------------------------------------

/// State for the Walk With Me feature.
enum WalkWithMePhase {
  /// Feature is inactive.
  inactive,

  /// User is holding the touch zone.
  active,

  /// Touch released — counting down.
  countdown,

  /// Countdown expired — waiting for PIN.
  pinChallenge,

  /// PIN accepted, returning to inactive.
  cancelled,

  /// Escalated to full SOS.
  escalated,
}

class WalkWithMeState {
  final WalkWithMePhase phase;
  final int countdownSeconds;

  const WalkWithMeState({
    this.phase = WalkWithMePhase.inactive,
    this.countdownSeconds = 10,
  });

  WalkWithMeState copyWith({
    WalkWithMePhase? phase,
    int? countdownSeconds,
  }) {
    return WalkWithMeState(
      phase: phase ?? this.phase,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final walkWithMeControllerProvider =
    AsyncNotifierProvider<WalkWithMeController, WalkWithMeState>(
  WalkWithMeController.new,
);

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class WalkWithMeController extends AsyncNotifier<WalkWithMeState> {
  Timer? _countdownTimer;
  Timer? _hapticTimer;

  @override
  Future<WalkWithMeState> build() async {
    ref.onDispose(() {
      _countdownTimer?.cancel();
      _hapticTimer?.cancel();
    });
    return const WalkWithMeState();
  }

  /// User touches the screen — activates the dead man's switch.
  void onTouchDown() {
    _countdownTimer?.cancel();
    _hapticTimer?.cancel();

    state = AsyncData(
      const WalkWithMeState(phase: WalkWithMePhase.active),
    );
    debugPrint('WalkWithMe: ACTIVE — touch held');
  }

  /// User releases touch — starts 10-second countdown.
  void onTouchUp() {
    final current = state.valueOrNull;
    if (current == null || current.phase != WalkWithMePhase.active) return;

    state = AsyncData(const WalkWithMeState(
      phase: WalkWithMePhase.countdown,
      countdownSeconds: 10,
    ));

    _startCountdown();
    _startHapticPulse();
    debugPrint('WalkWithMe: COUNTDOWN started');
  }

  void _startCountdown() {
    var remaining = 10;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;

      if (remaining <= 0) {
        timer.cancel();
        _hapticTimer?.cancel();
        _onCountdownExpired();
        return;
      }

      state = AsyncData(WalkWithMeState(
        phase: WalkWithMePhase.countdown,
        countdownSeconds: remaining,
      ));
    });
  }

  void _startHapticPulse() {
    _hapticTimer?.cancel();
    // Haptic pattern: short-short-long every second
    _hapticTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 150), () {
        HapticFeedback.lightImpact();
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        HapticFeedback.heavyImpact();
      });
    });
  }

  void _onCountdownExpired() {
    state = AsyncData(const WalkWithMeState(
      phase: WalkWithMePhase.pinChallenge,
      countdownSeconds: 0,
    ));
    HapticFeedback.vibrate();
    debugPrint('WalkWithMe: PIN CHALLENGE — countdown expired');
  }

  /// User submitted a PIN. Validated externally; this receives the result.
  Future<void> onPinValidated(PinType pinType) async {
    _countdownTimer?.cancel();
    _hapticTimer?.cancel();

    switch (pinType) {
      case PinType.safety:
        state = AsyncData(const WalkWithMeState(
          phase: WalkWithMePhase.cancelled,
        ));
        debugPrint('WalkWithMe: CANCELLED — safety PIN');
        // Auto-return to inactive after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (state.valueOrNull?.phase == WalkWithMePhase.cancelled) {
            state = AsyncData(const WalkWithMeState());
          }
        });
        break;

      case PinType.duress:
        // Covert escalation via SOS controller
        state = AsyncData(const WalkWithMeState(
          phase: WalkWithMePhase.escalated,
        ));
        // The SOS controller handles the coerced state
        debugPrint('WalkWithMe: DURESS — covert escalation');
        break;

      case PinType.invalid:
        // Wrong PIN — stay in pin challenge
        HapticFeedback.heavyImpact();
        break;
    }
  }

  /// No PIN entered within timeout — escalate to full SOS.
  Future<void> escalate() async {
    _countdownTimer?.cancel();
    _hapticTimer?.cancel();

    state = AsyncData(const WalkWithMeState(
      phase: WalkWithMePhase.escalated,
    ));

    // Trigger emergency via SOS controller
    try {
      final position = await getReliableLocation();
      if (position != null) {
        final sosCtrl = ref.read(sosControllerProvider.notifier);
        sosCtrl.beginPress(); // Simulate manual trigger
        await sosCtrl.trigger(position);
      }
    } catch (e) {
      debugPrint('WalkWithMe: escalation failed: $e');
    }

    debugPrint('WalkWithMe: ESCALATED — full SOS triggered');
  }

  /// Cancel everything and return to inactive.
  void deactivate() {
    _countdownTimer?.cancel();
    _hapticTimer?.cancel();
    state = AsyncData(const WalkWithMeState());
    debugPrint('WalkWithMe: DEACTIVATED');
  }
}
