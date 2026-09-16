/// Phases of the emergency state machine.
///
/// Lifecycle:
///   idle → pressing → triggered → broadcasting → resolved/cancelled/failed
///   idle → walkWithMe_active → walkWithMe_countdown → walkWithMe_pinChallenge
///        → broadcasting (no PIN) or cancelled (safety PIN) or coerced (duress PIN)
///   idle → snatchDetected → broadcasting (timeout) or cancelled (user OK)
enum EmergencyPhase {
  /// No emergency active.
  idle,

  /// SOS button is being held down.
  pressing,

  /// SOS has been triggered, creating session.
  triggered,

  /// Emergency session is active, broadcasting to guardians.
  broadcasting,

  /// Emergency was resolved normally.
  resolved,

  /// Emergency was cancelled by the user with a safety PIN.
  cancelled,

  /// Emergency session creation failed.
  failed,

  // ---- Walk With Me phases ----

  /// Walk With Me mode is active (user is holding the touch zone).
  walkWithMeActive,

  /// Touch released — 10-second countdown with haptic pulses.
  walkWithMeCountdown,

  /// Countdown expired — PIN entry required to cancel.
  walkWithMePinChallenge,

  // ---- Snatch / Impact phases ----

  /// Snatch or impact detected — 15-second verification window.
  snatchDetected,

  // ---- Coercion / Duress ----

  /// Duress PIN entered. A fake "cancelled" screen is shown to the user,
  /// but the session continues silently in the background with status
  /// 'hostage_coerced'. Guardians receive a silent critical alert.
  coerced,
}

/// The type of PIN entered during emergency cancellation.
enum PinType {
  /// The normal safety PIN — genuinely cancels the emergency.
  safety,

  /// The duress/coercion PIN — shows fake cancellation, maintains tracking.
  duress,

  /// PIN did not match either configured value.
  invalid,
}

class EmergencyState {
  final EmergencyPhase phase;
  final String? sessionId;
  final String? failureMessage;
  final DateTime? changedAt;

  /// Seconds remaining in an active countdown (Walk With Me or snatch).
  final int? countdownSeconds;

  /// Source that triggered this emergency (manual, snatch, audio, walkWithMe).
  final String? triggerSource;

  const EmergencyState({
    this.phase = EmergencyPhase.idle,
    this.sessionId,
    this.failureMessage,
    this.changedAt,
    this.countdownSeconds,
    this.triggerSource,
  });

  /// Whether the emergency is in any active broadcasting or coerced state.
  bool get isActive =>
      phase == EmergencyPhase.broadcasting ||
      phase == EmergencyPhase.coerced;

  /// Whether a countdown is in progress.
  bool get hasCountdown =>
      phase == EmergencyPhase.walkWithMeCountdown ||
      phase == EmergencyPhase.snatchDetected;

  EmergencyState copyWith({
    EmergencyPhase? phase,
    String? sessionId,
    String? failureMessage,
    DateTime? changedAt,
    int? countdownSeconds,
    String? triggerSource,
  }) {
    return EmergencyState(
      phase: phase ?? this.phase,
      sessionId: sessionId ?? this.sessionId,
      failureMessage: failureMessage ?? this.failureMessage,
      changedAt: changedAt ?? this.changedAt,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      triggerSource: triggerSource ?? this.triggerSource,
    );
  }
}

