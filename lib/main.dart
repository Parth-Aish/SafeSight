import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for User Persistence check
import 'auth_screens.dart';
import 'home_screen.dart';
import 'firebase_options.dart'; 

void main() {
  // 1. Instant Startup (Don't wait for Firebase here)
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SafeSightApp()));
}

// -----------------------------------------------------------------------------
// 2. ROOT WIDGET & ROUTING
// -----------------------------------------------------------------------------
class SafeSightApp extends ConsumerWidget {
  const SafeSightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'SafeSight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

// -----------------------------------------------------------------------------
// 3. DESIGN SYSTEM (THEME)
// -----------------------------------------------------------------------------
class AppTheme {
  static const Color slate900 = Color(0xFF020617);
  static const Color slate800 = Color(0xFF0F172A);
  static const Color sky400 = Color(0xFF38BDF8);
  static const Color sky500 = Color(0xFF0EA5E9);
  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textGrey = Color(0xFF94A3B8);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color rose500 = Color(0xFFF43F5E);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: slate900,
      colorScheme: const ColorScheme.dark(
        primary: sky400,
        secondary: sky500,
        surface: slate800,
        onSurface: textWhite,
        error: rose500,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textWhite,
        displayColor: textWhite,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. SPLASH SCREEN (HANDLES INIT & AUTH CHECK)
// -----------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _appearController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  String _statusText = "INITIALIZING SYSTEMS...";

  @override
  void initState() {
    super.initState();
    
    // Animation Setup
    _appearController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = CurvedAnimation(parent: _appearController, curve: Curves.easeOut);
    _slideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutQuart),
    );
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: false);

    _appearController.forward();
    
    // START INITIALIZATION
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Wait for minimum animation time (so it doesn't flash too fast)
    // Reduced to 3 seconds for a snappier feel while still allowing the animation to play
    final minWait = Future.delayed(const Duration(seconds: 3));

    // 2. Initialize Firebase safely
    final firebaseInit = _initFirebase();

    try {
      // Wait for both animation and Firebase
      await Future.wait([minWait, firebaseInit]);
      
      // 3. CHECK AUTH STATE (The Fix)
      // Once Firebase is ready, we check if a user is already logged in.
      final user = FirebaseAuth.instance.currentUser;

      if (mounted) {
        if (user != null) {
          // User exists -> Go straight to Dashboard
          context.go('/home');
        } else {
          // No user -> Go to Login
          context.go('/login');
        }
      }
    } catch (e) {
      // Even if Firebase fails, we let them into the app (offline mode or retry)
      // so the app doesn't stay stuck on the splash screen.
      debugPrint("Startup Error: $e");
      if (mounted) setState(() => _statusText = "CONNECTION ISSUE. STARTING ANYWAY...");
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/login');
    }
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("✅ Firebase Ready");
    } catch (e) {
      debugPrint("⚠️ Firebase Init Error (Ignored for UI launch): $e");
      // If it's already initialized, that's fine.
      if (e.toString().contains('duplicate-app')) return;
      rethrow;
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
                    // LOGO
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
                      _statusText, // Dynamic Status Text
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
                  BoxShadow(color: AppTheme.sky400, blurRadius: 10, spreadRadius: 2)
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}