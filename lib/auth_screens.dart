import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'dart:async'; // Required for Timeout

// -----------------------------------------------------------------------------
// LOGIN SCREEN
// -----------------------------------------------------------------------------
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleEmailLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please enter both email and password.");
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      
      // 1. Attempt Login with 10-second Timeout
      await authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw "Connection timed out. Check your internet.";
      });
      
      // 2. Just go to home - let home screen handle verification check
      // This avoids the second network call that was causing the hang
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      // CRITICAL: Ensure loading stops even if app crashes
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      // 5-second watchdog for Google Sign In (Was 8s)
      await ref.read(authServiceProvider).signInWithGoogle()
          .timeout(const Duration(seconds: 5), onTimeout: () {
            throw "Google Sign-In unresponsive. Popup blocked?";
          });
          
      if (mounted) context.go('/home');
    } catch (e) {
      String message = e.toString();
      // Translate common errors
      if (message.contains("is disabled")) {
        message = "Enable 'Google' in Firebase Console > Authentication.";
      } else if (message.contains("10") || message.contains("12500")) {
        message = "SHA-1 missing in Firebase Console.";
      } else if (message.contains("popup_closed")) {
        message = "Sign-in cancelled.";
      }
      
      if (mounted) _showError("Login Failed: $message");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ANIMATED LOGO
                const _SafeSightLogo(), 
                const SizedBox(height: 24),
                Text(
                  "Welcome Back",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
                Text(
                  "Securely login to continue monitoring.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 48),

                _AuthTextField(controller: _emailController, label: "Email Address", icon: Icons.email_outlined),
                const SizedBox(height: 16),
                _AuthTextField(controller: _passwordController, label: "Password", icon: Icons.lock_outline, obscureText: true),
                
                const SizedBox(height: 24),
                
                // LOGIN BUTTON
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0F172A), strokeWidth: 2)),
                              const SizedBox(width: 12),
                              Text("CONNECTING...", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            ],
                          )
                        : Text("LOGIN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // GOOGLE BUTTON
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text("Sign in with Google", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                ),
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    GestureDetector(
                      onTap: () => context.push('/signup'),
                      child: Text("Sign Up", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SIGN UP SCREEN
// -----------------------------------------------------------------------------
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigits = false;
  bool _hasSpecialCharacters = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordStrength);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigits = password.contains(RegExp(r'[0-9]'));
      _hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordValid => _hasMinLength && _hasUppercase && _hasLowercase && _hasDigits && _hasSpecialCharacters;

  Future<void> _handleSignUp() async {
    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please meet all password requirements.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      
      // 10-second timeout for Signup
      await authService.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      ).timeout(const Duration(seconds: 10));
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text("Verification Sent", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_read, size: 50, color: Color(0xFF38BDF8)),
                const SizedBox(height: 16),
                Text("Verification link sent to ${_emailController.text}.", style: GoogleFonts.outfit(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text("Please check your email to activate.", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
                child: const Text("Go to Login", style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => context.pop())),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SafeSightLogo(),
                const SizedBox(height: 24),
                Text("Create Account", style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                Text("Join SafeSight network today.", style: GoogleFonts.outfit(fontSize: 16, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 32),
                
                _AuthTextField(controller: _emailController, label: "Email Address", icon: Icons.email_outlined),
                const SizedBox(height: 16),
                _AuthTextField(controller: _passwordController, label: "Password", icon: Icons.lock_outline, obscureText: true),
                
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Password Requirements:", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _PasswordRequirement(label: "8+ chars", isValid: _hasMinLength),
                    _PasswordRequirement(label: "Uppercase (A-Z)", isValid: _hasUppercase),
                    _PasswordRequirement(label: "Lowercase (a-z)", isValid: _hasLowercase),
                    _PasswordRequirement(label: "Number (0-9)", isValid: _hasDigits),
                    _PasswordRequirement(label: "Symbol (!@#)", isValid: _hasSpecialCharacters),
                  ],
                ),

                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPasswordValid ? colorScheme.primary : Colors.grey.withValues(alpha: 0.3),
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Color(0xFF0F172A))
                        : Text("SIGN UP & VERIFY", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI COMPONENTS
// -----------------------------------------------------------------------------

class _SafeSightLogo extends StatefulWidget {
  const _SafeSightLogo();

  @override
  State<_SafeSightLogo> createState() => _SafeSightLogoState();
}

class _SafeSightLogoState extends State<_SafeSightLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280, 
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -2.0,
                color: const Color(0xFFF8FAFC),
              ),
              children: const [
                TextSpan(text: 'Safe'),
                TextSpan(
                  text: 'Sight',
                  style: TextStyle(color: Color(0xFF38BDF8)),
                ),
              ],
            ),
          ),
          Positioned(
            top: 15,
            right: 95, // Set to 95 as requested
            child: _buildPulseDot(),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              width: 140,
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.0),
                    const Color(0xFF38BDF8),
                    const Color(0xFF38BDF8).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseDot() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double value = _controller.value;
        double scale = 1.0 + (value * 2.0);
        double opacity = (1.0 - value).clamp(0.0, 1.0);
        const color = Color(0xFF38BDF8);

        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: opacity * 0.5,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color, blurRadius: 10, spreadRadius: 2)
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  final String label;
  final bool isValid;

  const _PasswordRequirement({required this.label, required this.isValid});

  @override
  Widget build(BuildContext context) {
    final color = isValid ? Colors.greenAccent : Colors.white24;
    final icon = isValid ? Icons.check_circle : Icons.circle_outlined;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isValid ? Colors.white70 : Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;

  const _AuthTextField({required this.controller, required this.label, required this.icon, this.obscureText = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          border: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: colorScheme.primary.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}