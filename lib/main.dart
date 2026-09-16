import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/auth_screens.dart';
import 'home_screen.dart';
import 'services/background_service.dart';
import 'src/core/crypto/crypto_service.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
  ],
);

/// Global crypto service instance, initialized on app boot.
final cryptoService = CryptoService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // Initialize E2E encryption keypair
  try {
    await cryptoService.initialize();
  } catch (e) {
    debugPrint("CryptoService init error: $e");
  }

  // Boot up the background notification engine
  await initializeBackgroundEngine();

  runApp(const ProviderScope(child: SafeSightApp()));
}

class SafeSightApp extends ConsumerWidget {
  const SafeSightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SafeSight',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
