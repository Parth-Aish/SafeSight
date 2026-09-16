import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _appearController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  String _statusText = "INITIALIZING SYSTEMS...";

  @override
  void initState() {
    super.initState();

    _appearController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation =
        CurvedAnimation(parent: _appearController, curve: Curves.easeOut);
    _slideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutQuart),
    );
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: false);

    _appearController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // FIX: Firebase is already initialized securely in main.dart
    // We just wait for the animation to finish and then check auth state!
    try {
      await Future.delayed(const Duration(seconds: 3));
      final user = FirebaseAuth.instance.currentUser;

      if (mounted) {
        if (user != null) {
          context.go('/home');
        } else {
          context.go('/login');
        }
      }
    } catch (e) {
      debugPrint("Startup Error: $e");
      if (mounted)
        setState(() => _statusText = "CONNECTION ISSUE. STARTING ANYWAY...");
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.slate900,
      body: Center(
        child: AnimatedBuilder(
          animation: _appearController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 340,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.outfit(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: -2.0,
                                color: AppTheme.textWhite,
                              ),
                              children: const [
                                TextSpan(text: 'Safe'),
                                TextSpan(
                                  text: 'Sight',
                                  style: TextStyle(color: AppTheme.sky400),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 20,
                            right: 0,
                            child: _buildPulseDot(),
                          ),
                          Positioned(
                            bottom: 10,
                            child: Container(
                              width: 180,
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.sky400.withValues(alpha: 0.0),
                                    AppTheme.sky400,
                                    AppTheme.sky400.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _statusText,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        letterSpacing: 3.0,
                        color: AppTheme.sky400.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPulseDot() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        double value = _pulseController.value;
        double scale = 1.0 + (value * 2.0);
        double opacity = (1.0 - value).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: opacity * 0.5,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.sky400, width: 2),
                  ),
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.sky400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.sky400, blurRadius: 10, spreadRadius: 2)
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
