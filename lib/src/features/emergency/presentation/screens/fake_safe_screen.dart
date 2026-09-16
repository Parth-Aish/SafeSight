import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:safesight/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Fake Safe Screen
// ---------------------------------------------------------------------------
// Displayed when the user enters a DURESS PIN. This screen is designed to
// be visually indistinguishable from a genuine "SOS Cancelled" confirmation.
//
// Behind this screen, the session continues silently with coerced tracking.
// ---------------------------------------------------------------------------

class FakeSafeScreen extends StatelessWidget {
  const FakeSafeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.slate900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated check icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.safeGreen.withValues(alpha: 0.15),
                      border: Border.all(
                        color: AppTheme.safeGreen,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.safeGreen,
                      size: 64,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            Text(
              'SOS Cancelled',
              style: GoogleFonts.outfit(
                color: AppTheme.textWhite,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'You Are Safe',
              style: GoogleFonts.outfit(
                color: AppTheme.safeGreen,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Emergency session has been ended.',
              style: GoogleFonts.outfit(
                color: AppTheme.textGrey,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 48),

            // "Return Home" button — acts as if everything is normal
            ElevatedButton(
              onPressed: () {
                Navigator.of(context)
                    .popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.safeGreen.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                side: const BorderSide(color: AppTheme.safeGreen),
              ),
              child: Text(
                'Return Home',
                style: GoogleFonts.outfit(
                  color: AppTheme.safeGreen,
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
}
