import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:safesight/core/theme/app_theme.dart';
import 'package:safesight/services/auth_service.dart';
import '../controllers/walk_with_me_controller.dart';
import 'package:safesight/features/emergency/domain/models/emergency_state.dart';

// ---------------------------------------------------------------------------
// Walk With Me Screen
// ---------------------------------------------------------------------------
// Full-screen dark tactical UI with a large central pulsing touch zone.
// - Animated ring fills while touched, drains when released
// - Countdown overlay with haptic feedback
// - PIN entry bottom sheet
// ---------------------------------------------------------------------------

class WalkWithMeScreen extends ConsumerStatefulWidget {
  const WalkWithMeScreen({super.key});

  @override
  ConsumerState<WalkWithMeScreen> createState() => _WalkWithMeScreenState();
}

class _WalkWithMeScreenState extends ConsumerState<WalkWithMeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(walkWithMeControllerProvider);
    final wmState = asyncState.valueOrNull ?? const WalkWithMeState();

    return Scaffold(
      backgroundColor: AppTheme.slate900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textWhite),
          onPressed: () {
            ref.read(walkWithMeControllerProvider.notifier).deactivate();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Walk With Me',
          style: GoogleFonts.outfit(
            color: AppTheme.textWhite,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(wmState),
    );
  }

  Widget _buildBody(WalkWithMeState wmState) {
    switch (wmState.phase) {
      case WalkWithMePhase.inactive:
        return _buildInactiveView();
      case WalkWithMePhase.active:
        return _buildActiveView();
      case WalkWithMePhase.countdown:
        return _buildCountdownView(wmState.countdownSeconds);
      case WalkWithMePhase.pinChallenge:
        return _buildPinChallengeView();
      case WalkWithMePhase.cancelled:
        return _buildCancelledView();
      case WalkWithMePhase.escalated:
        return _buildEscalatedView();
    }
  }

  // ---- Inactive: Instructions ----
  Widget _buildInactiveView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 80,
            color: AppTheme.sky400.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 24),
          Text(
            'Hold the screen to activate',
            style: GoogleFonts.outfit(
              color: AppTheme.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Keep your finger on the screen while walking. '
              'If you lift your finger, a countdown will begin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppTheme.textGrey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 48),
          GestureDetector(
            onTapDown: (_) => ref
                .read(walkWithMeControllerProvider.notifier)
                .onTouchDown(),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.sky400.withValues(alpha: 0.3),
                  width: 3,
                ),
                color: AppTheme.slate800,
              ),
              child: Center(
                child: Text(
                  'HOLD',
                  style: GoogleFonts.outfit(
                    color: AppTheme.sky400,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Active: Touch held ----
  Widget _buildActiveView() {
    return GestureDetector(
      onTapUp: (_) =>
          ref.read(walkWithMeControllerProvider.notifier).onTouchUp(),
      onPanEnd: (_) =>
          ref.read(walkWithMeControllerProvider.notifier).onTouchUp(),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.08);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.safeGreen.withValues(alpha: 0.4),
                        AppTheme.safeGreen.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.safeGreen,
                      width: 4,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shield,
                        color: AppTheme.safeGreen,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'PROTECTED',
                        style: GoogleFonts.outfit(
                          color: AppTheme.safeGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep holding',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---- Countdown ----
  Widget _buildCountdownView(int seconds) {
    final progress = seconds / 10.0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor:
                      AppTheme.alertRed.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.alertRed),
                ),
              ),
              Text(
                '$seconds',
                style: GoogleFonts.outfit(
                  color: AppTheme.alertRed,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Are you okay?',
            style: GoogleFonts.outfit(
              color: AppTheme.textWhite,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Touch the screen to reset',
            style: GoogleFonts.outfit(
              color: AppTheme.textGrey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTapDown: (_) => ref
                .read(walkWithMeControllerProvider.notifier)
                .onTouchDown(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 48, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: AppTheme.safeGreen.withValues(alpha: 0.2),
                border: Border.all(color: AppTheme.safeGreen),
              ),
              child: Text(
                "I'M OKAY",
                style: GoogleFonts.outfit(
                  color: AppTheme.safeGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- PIN Challenge ----
  Widget _buildPinChallengeView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: AppTheme.alertRed, size: 56),
            const SizedBox(height: 24),
            Text(
              'Enter your PIN',
              style: GoogleFonts.outfit(
                color: AppTheme.textWhite,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Emergency alert will trigger in 30 seconds',
              style: GoogleFonts.outfit(
                color: AppTheme.alertRed,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppTheme.textWhite,
                fontSize: 32,
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: GoogleFonts.outfit(
                  color: AppTheme.textGrey.withValues(alpha: 0.5),
                  fontSize: 32,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: AppTheme.textGrey.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.sky400, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.slate800,
              ),
              onSubmitted: _onPinSubmitted,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _onPinSubmitted(_pinController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sky400,
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: Text(
                'VERIFY',
                style: GoogleFonts.outfit(
                  color: AppTheme.slate900,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPinSubmitted(String pin) async {
    final authService = ref.read(authServiceProvider);
    final pinType = await authService.validatePin(pin);
    await ref
        .read(walkWithMeControllerProvider.notifier)
        .onPinValidated(pinType);
    _pinController.clear();
  }

  // ---- Cancelled ----
  Widget _buildCancelledView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppTheme.safeGreen, size: 80),
          const SizedBox(height: 24),
          Text(
            'You\'re Safe',
            style: GoogleFonts.outfit(
              color: AppTheme.safeGreen,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Escalated ----
  Widget _buildEscalatedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emergency, color: AppTheme.alertRed, size: 80),
          const SizedBox(height: 24),
          Text(
            'SOS ACTIVATED',
            style: GoogleFonts.outfit(
              color: AppTheme.alertRed,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Broadcasting to your guardians...',
            style: GoogleFonts.outfit(
              color: AppTheme.textGrey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
