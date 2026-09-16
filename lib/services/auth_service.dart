import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/emergency/domain/models/emergency_state.dart';

// -----------------------------------------------------------------------------
// PROVIDER
// -----------------------------------------------------------------------------
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// -----------------------------------------------------------------------------
// SERVICE CLASS
// -----------------------------------------------------------------------------
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Using the standard constructor.
  // NOTE: If you see "doesn't have an unnamed constructor" error here,
  // it implies you still have a file named 'google_sign_in.dart' inside 'lib/'.
  // Please delete it and run 'flutter clean'.
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // Get current user (if any)
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // 1. PASSWORD STRENGTH VALIDATOR (Google Standard)
  // ---------------------------------------------------------------------------
  String? validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!password.contains(RegExp(r'[A-Z]')))
      return 'Must contain at least one uppercase letter';
    if (!password.contains(RegExp(r'[a-z]')))
      return 'Must contain at least one lowercase letter';
    if (!password.contains(RegExp(r'[0-9]')))
      return 'Must contain at least one number';
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')))
      return 'Must contain at least one special character';
    return null; // Valid
  }

  // ---------------------------------------------------------------------------
  // 2. EMAIL SIGN UP & VERIFICATION
  // ---------------------------------------------------------------------------
  Future<void> signUpWithEmail(
      {required String email, required String password}) async {
    // 1. Validate Password Strength first
    final passwordError = validatePassword(password);
    if (passwordError != null) throw passwordError;

    try {
      // 2. Create the user
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 3. Send Verification Email immediately
      await cred.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'An unknown error occurred.';
    }
  }

  // ---------------------------------------------------------------------------
  // 3. EMAIL LOGIN (Checks Verification)
  // ---------------------------------------------------------------------------
  Future<void> signInWithEmail(
      {required String email, required String password}) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (cred.user != null && !cred.user!.emailVerified) {
        // Option: You can choose to block login until verified,
        // or let them in and show a banner.
        // For strict security, we can throw an error:
        // await _auth.signOut();
        // throw 'Please verify your email before logging in.';
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'An unknown error occurred.';
    }
  }

  // ---------------------------------------------------------------------------
  // 4. GOOGLE SIGN IN
  // ---------------------------------------------------------------------------
  Future<void> signInWithGoogle() async {
    try {
      // Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google Credential
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw 'Google Sign-In failed: $e';
    }
  }

  // ---------------------------------------------------------------------------
  // UTILS
  // ---------------------------------------------------------------------------
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload(); // Force refresh from server
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ---------------------------------------------------------------------------
  // DURESS / SAFETY PIN MANAGEMENT
  // ---------------------------------------------------------------------------
  static const _secureStorage = FlutterSecureStorage();
  static const _safetyPinKey = 'safesight_safety_pin';
  static const _duressPinKey = 'safesight_duress_pin';

  /// Sets the safety PIN (used to genuinely cancel emergencies).
  Future<void> setSafetyPin(String pin) async {
    if (pin.length < 4) throw 'PIN must be at least 4 digits';
    await _secureStorage.write(key: _safetyPinKey, value: pin);
  }

  /// Sets the duress PIN (covert hostage signal).
  ///
  /// Must differ from the safety PIN.
  Future<void> setDuressPin(String pin) async {
    if (pin.length < 4) throw 'PIN must be at least 4 digits';
    final safetyPin = await _secureStorage.read(key: _safetyPinKey);
    if (pin == safetyPin) {
      throw 'Duress PIN must be different from your Safety PIN';
    }
    await _secureStorage.write(key: _duressPinKey, value: pin);
  }

  /// Validates a PIN against stored safety and duress PINs.
  ///
  /// Returns [PinType.safety] for genuine cancellation,
  /// [PinType.duress] for covert escalation, or
  /// [PinType.invalid] if the PIN doesn't match.
  Future<PinType> validatePin(String pin) async {
    final safetyPin = await _secureStorage.read(key: _safetyPinKey);
    final duressPin = await _secureStorage.read(key: _duressPinKey);

    if (safetyPin != null && pin == safetyPin) return PinType.safety;
    if (duressPin != null && pin == duressPin) return PinType.duress;
    return PinType.invalid;
  }

  /// Whether the user has configured both PINs.
  Future<bool> hasPinsConfigured() async {
    final safety = await _secureStorage.read(key: _safetyPinKey);
    return safety != null;
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
