import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:safesight/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Snatch Verification Dialog
// ---------------------------------------------------------------------------
// 15-second cancellable emergency verification dialog triggered when the
// motion sensor detects a potential snatch or violent impact.
//
// Shows: "We detected a sudden impact. Are you okay?"
// Countdown ring animation. "I'm Fine" cancels; timeout escalates.
// ---------------------------------------------------------------------------

class SnatchVerificationDialog extends StatefulWidget {
  /// Called when the user taps "I'm Fine".
  final VoidCallback onConfirmSafe;

  /// Called when the countdown expires without interaction.
  final VoidCallback onTimeout;

  const SnatchVerificationDialog({
    super.key,
    required this.onConfirmSafe,
    required this.onTimeout,
  });

  @override
  State<SnatchVerificationDialog> createState() =>
      _SnatchVerificationDialogState();
}

class _SnatchVerificationDialogState extends State<SnatchVerificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringController;
  int _secondsRemaining = 15;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          timer.cancel();
          widget.onTimeout();
        }
      });
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.slate900.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Warning icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.warningYellow.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningYellow,
                size: 64,
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Impact Detected',
              style: GoogleFonts.outfit(
                color: AppTheme.textWhite,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'We detected a sudden impact or rapid movement. '
                'Are you okay?',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: AppTheme.textGrey,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Countdown ring
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, child) {
                      return CircularProgressIndicator(
                        value: 1.0 - _ringController.value,
                        strokeWidth: 6,
                        backgroundColor:
                            AppTheme.alertRed.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(
                          _secondsRemaining <= 5
                              ? AppTheme.alertRed
                              : AppTheme.warningYellow,
                        ),
                      );
                    },
                  ),
                ),
                Text(
                  '$_secondsRemaining',
                  style: GoogleFonts.outfit(
                    color: _secondsRemaining <= 5
                        ? AppTheme.alertRed
                        : AppTheme.textWhite,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // "I'm Fine" button
            GestureDetector(
              onTap: widget.onConfirmSafe,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: AppTheme.safeGreen,
                ),
                child: Text(
                  "I'M FINE",
                  style: GoogleFonts.outfit(
                    color: AppTheme.slate900,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Emergency SOS will trigger automatically',
              style: GoogleFonts.outfit(
                color: AppTheme.alertRed.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
