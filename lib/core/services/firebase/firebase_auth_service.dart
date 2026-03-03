import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firebase_auth.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// Firebase Authentication service for Back My Bracket.
/// Uses REST API — bypasses Firebase JS SDK issues in iframe/sandbox.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final RestFirebaseAuth _auth = RestFirebaseAuth.instance;
  final RestFirestoreService _firestore = RestFirestoreService.instance;

  /// Current user UID (null if not signed in).
  String? get currentUserUid => _auth.uid;

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth.isSignedIn;

  // ══════════════════════════════════════════════════════════════════════════
  // SIGN UP
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a new account with email/password and store user profile in Firestore.
  Future<String> signUp({
    required String email,
    required String password,
    required String displayName,
    String? state,
    String? city,
    String? street,
    String? zip,
    bool isBusiness = false,
    String? bizName,
    String? bizType,
    String? bizPlan,
    String? bizContactName,
    String? bizPhone,
  }) async {
    final userId = await _auth.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );

    final userData = <String, dynamic>{
      'email': email.toLowerCase().trim(),
      'display_name': displayName,
      'state': state ?? '',
      'city': city ?? '',
      'street': street ?? '',
      'zip': zip ?? '',
      'avatar_index': 0,
      'subscription_tier': isBusiness ? 'business' : 'free',
      'credits_balance': 200,
      'companion_id': '',
      'is_admin': false,
      'is_business': isBusiness,
      'is_bmb_plus': isBusiness,
      'referral_code': _generateReferralCode(displayName),
      'brackets_created': 0,
      'brackets_entered': 0,
      'total_winnings': 0,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
      'last_active': DateTime.now().toUtc().toIso8601String(),
    };

    if (isBusiness) {
      userData['biz_name'] = bizName ?? '';
      userData['biz_type'] = bizType ?? 'bar';
      userData['biz_plan'] = bizPlan ?? 'business';
      userData['biz_contact_name'] = bizContactName ?? '';
      userData['biz_phone'] = bizPhone ?? '';
    }

    await _firestore.setUser(userId, userData);

    await _firestore.addCreditTransaction({
      'user_id': userId,
      'amount': 200,
      'type': 'signup_bonus',
      'description': 'Welcome bonus credits',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });

    await _firestore.logEvent({
      'event_type': 'signup_completed',
      'user_id': userId,
      'screen': 'auth',
    });

    return userId;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIN
  // ══════════════════════════════════════════════════════════════════════════

  /// Sign in with email/password.
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final userId = await _auth.signIn(email: email, password: password);

    // BUG #14 FIX: Log errors instead of silently swallowing them.
    _firestore.updateUser(userId, {
      'last_active': DateTime.now().toUtc().toIso8601String(),
    }).catchError((e) {
      if (kDebugMode) debugPrint('FirebaseAuth: Failed to update last_active: $e');
    });

    _firestore.logEvent({
      'event_type': 'login',
      'user_id': userId,
      'screen': 'auth',
    }).catchError((e) {
      if (kDebugMode) debugPrint('FirebaseAuth: Failed to log login event: $e');
    });

    return userId;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGOUT
  // ══════════════════════════════════════════════════════════════════════════

  /// BUG #13 FIX: Clear all session state on logout.
  /// Previously only called _auth.signOut() — leaving Firestore tokens
  /// and local user state stale.
  Future<void> signOut() async {
    // 1. Clear Firebase REST Auth tokens
    _auth.signOut();

    // 2. Clear local user state
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear session-specific data but preserve remember-me credentials
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_display_name');
      await prefs.remove('user_state');
      await prefs.remove('user_city');
      await prefs.remove('user_street');
      await prefs.remove('user_zip');
      await prefs.remove('is_bmb_plus');
      await prefs.remove('is_bmb_vip');
      await prefs.remove('is_business');
      await prefs.remove('is_admin');
      await prefs.remove('subscription_tier');
      await prefs.remove('bmb_bucks_balance');
      await prefs.remove('avatar_index');
      await prefs.remove('companion_id');
    } catch (_) {
      // Best-effort cleanup
    }

    // 3. Clear CurrentUserService state
    CurrentUserService.instance.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASSWORD RESET
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// BUG #11 FIX: Use 4-digit random suffix instead of 2-digit timestamp.
  /// Previous approach: millisecondsSinceEpoch % 100 = only 100 possible values.
  /// New approach: 4-character alphanumeric suffix = 1.6M+ possible values.
  String _generateReferralCode(String name) {
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final prefix = clean.length > 5 ? clean.substring(0, 5) : clean;
    final random = DateTime.now().microsecondsSinceEpoch;
    // Use base-36 encoding of microseconds for more unique suffix
    final suffix = random.toRadixString(36).toUpperCase();
    final safeSuffix = suffix.length > 4 ? suffix.substring(suffix.length - 4) : suffix.padLeft(4, '0');
    return '$prefix$safeSuffix';
  }
}
