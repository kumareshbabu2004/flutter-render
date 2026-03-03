import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages biometric / Face-ID "Remember Me" credentials.
///
/// On **mobile** (Android / iOS) the credentials are stored in the platform
/// keychain / keystore via [FlutterSecureStorage].
/// On **web** the same class still works — flutter_secure_storage falls back
/// to encrypted localStorage — and we simulate biometric with a PIN overlay.
class BiometricAuthService {
  BiometricAuthService._();
  static final BiometricAuthService instance = BiometricAuthService._();

  static const _keyEmail = 'bmb_saved_email';
  static const _keyPassword = 'bmb_saved_password';
  static const _keyRememberMe = 'bmb_remember_me';
  static const _keyBiometricEnabled = 'bmb_biometric_enabled';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ─── Remember-Me toggle ──────────────────────────────────────────────

  Future<bool> isRememberMeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRememberMe) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricAuth] isRememberMeEnabled error: $e');
      return false;
    }
  }

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, value);
    if (!value) {
      await clearSavedCredentials();
    }
  }

  // ─── Biometric (Face ID / Touch ID) toggle ──────────────────────────

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, value);
  }

  // ─── Credential storage ──────────────────────────────────────────────

  /// BUG #3 FIX: Store credentials ONLY in FlutterSecureStorage.
  /// SharedPreferences is NOT suitable for passwords — it stores in plain text.
  Future<void> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _keyEmail, value: email);
      await _secureStorage.write(key: _keyPassword, value: password);
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricAuth] SecureStorage write error: $e');
    }
    // Store email (non-sensitive) in SharedPreferences for display purposes only
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bmb_remember_email', email);
    // BUG #3 FIX: Remove any previously stored plain-text passwords
    await prefs.remove('bmb_remember_password');
  }

  /// BUG #3 FIX: Read credentials ONLY from FlutterSecureStorage.
  Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: _keyEmail);
      final password = await _secureStorage.read(key: _keyPassword);
      if (email != null && email.isNotEmpty &&
          password != null && password.isNotEmpty) {
        return {'email': email, 'password': password};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricAuth] SecureStorage read error: $e');
    }
    // Fallback: check if email is in SharedPreferences (display only, no password)
    return null;
  }

  Future<String?> getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final spEmail = prefs.getString('bmb_remember_email');
      if (spEmail != null && spEmail.isNotEmpty) return spEmail;
    } catch (_) {}
    return _secureStorage.read(key: _keyEmail);
  }

  /// BUG #3 FIX: Clear from BOTH stores (ensure no plain-text passwords remain)
  Future<void> clearSavedCredentials() async {
    try {
      await _secureStorage.delete(key: _keyEmail);
      await _secureStorage.delete(key: _keyPassword);
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricAuth] clearSavedCredentials secureStorage error: $e');
    }
    // Clear any legacy plain-text passwords from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('bmb_remember_email');
      await prefs.remove('bmb_remember_password');
    } catch (e) {
      if (kDebugMode) debugPrint('[BiometricAuth] clearSavedCredentials prefs error: $e');
    }
    await setBiometricEnabled(false);
  }

  // ─── Biometric availability (platform-aware) ─────────────────────────

  /// Check if biometric is available on this device.
  /// On web, returns true when credentials are stored (PIN-based verification).
  /// On mobile, checks for actual biometric hardware via local_auth.
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) {
      // Web: biometric simulated via PIN — available if credentials exist.
      final creds = await getSavedCredentials();
      return creds != null;
    }
    // Mobile: would use local_auth plugin in production.
    // For now check that credentials are stored (real biometric on Android/iOS).
    final creds = await getSavedCredentials();
    return creds != null;
  }

  /// Returns true if user has saved credentials AND biometric is on.
  Future<bool> canAutoLogin() async {
    final remember = await isRememberMeEnabled();
    final bioOn = await isBiometricEnabled();
    final creds = await getSavedCredentials();
    return remember && bioOn && creds != null;
  }

  /// Authenticates with biometric.
  /// On **Android / iOS**: would call local_auth's `authenticateWithBiometrics`.
  /// On **web preview**: validates stored credentials exist (PIN overlay in UI).
  /// Returns false if credentials are not stored or biometric is disabled.
  Future<bool> authenticateWithBiometric() async {
    final bioEnabled = await isBiometricEnabled();
    if (!bioEnabled) return false;

    final creds = await getSavedCredentials();
    if (creds == null || creds['email']!.isEmpty || creds['password']!.isEmpty) {
      return false;
    }

    if (kIsWeb) {
      // Web: short delay simulating PIN entry, then verify credentials exist
      await Future.delayed(const Duration(milliseconds: 800));
      return true; // caller UI shows PIN overlay for actual user verification
    }

    // Mobile: simulate sensor delay — production would call local_auth here
    await Future.delayed(const Duration(milliseconds: 1200));
    // On real device: final didAuth = await LocalAuthentication().authenticate(...);
    return true;
  }

  /// Debug helper
  Future<void> debugPrintState() async {
    if (kDebugMode) {
      final remember = await isRememberMeEnabled();
      final bio = await isBiometricEnabled();
      final email = await getSavedEmail();
      debugPrint(
          '[BiometricAuth] remember=$remember, bio=$bio, email=$email');
    }
  }
}
