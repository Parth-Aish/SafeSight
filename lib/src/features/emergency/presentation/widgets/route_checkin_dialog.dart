import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:safesight/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Route Check-In Dialog
// ---------------------------------------------------------------------------
// Gentle notification shown when route deviation is detected.
// "Are you still on your route?" with haptic pulse.
// Two buttons: "Yes, I'm fine" / "I need help"
// ---------------------------------------------------------------------------

class RouteCheckInDialog extends StatelessWidget {
  final double deviationMeters;
  final VoidCallback onConfirmFine;
  final VoidCallback onNeedHelp;

  const RouteCheckInDialog({
    super.key,
    required this.deviationMeters,
    required this.onConfirmFine,
    required this.onNeedHelp,
  });

  @override
  Widget build(BuildContext context) {
    // Trigger haptic on display
    HapticFeedback.mediumImpact();

    return Dialog(
      backgroundColor: AppTheme.slate800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.sky400.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.navigation_outlined,
                color: AppTheme.sky400,
                size: 36,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Are you still on\nyour route?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppTheme.textWhite,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'You appear to be ${deviationMeters.toStringAsFixed(0)}m '
              'away from your planned route.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppTheme.textGrey,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 28),

            // "Yes, I'm fine" button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConfirmFine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.safeGreen.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.safeGreen),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Yes, I'm fine",
                  style: GoogleFonts.outfit(
                    color: AppTheme.safeGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // "I need help" button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNeedHelp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.alertRed),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'I need help',
                  style: GoogleFonts.outfit(
                    color: AppTheme.alertRed,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
