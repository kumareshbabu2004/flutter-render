import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firebase_auth.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

/// Singleton service providing the current user's identity everywhere.
/// Uses REST API for Firebase operations — no JS SDK required.
class CurrentUserService {
  CurrentUserService._();
  static final CurrentUserService instance = CurrentUserService._();

  // ─── In-memory state ──────────────────────────────────────────────────

  String _userId = 'user_0';
  String _displayName = '';
  String _email = '';
  String _stateAbbr = '';
  String _city = '';
  String _street = '';
  String _zip = '';
  bool _isBmbPlus = false;
  bool _isBmbVip = false;
  bool _isAdmin = false;
  bool _isBusiness = false;
  int _avatarIndex = 0;
  bool _isLoggedIn = false;
  int _creditsBalance = 0;
  String _subscriptionTier = 'free';
  String _companionId = '';
  String _referralCode = '';

  // ─── Public getters ───────────────────────────────────────────────────

  String get userId => _userId;
  String get displayName => _displayName;
  String get email => _email;
  String get stateAbbr => _stateAbbr;
  String get city => _city;
  String get street => _street;
  String get zip => _zip;
  bool get isBmbPlus => _isBmbPlus;
  bool get isBmbVip => _isBmbVip;
  bool get isAdmin => _isAdmin;
  bool get isBusiness => _isBusiness;
  int get avatarIndex => _avatarIndex;
  bool get isLoggedIn => _isLoggedIn;
  int get creditsBalance => _creditsBalance;
  String get subscriptionTier => _subscriptionTier;
  String get companionId => _companionId;
  String get referralCode => _referralCode;

  bool isCurrentUser(String id) =>
      id == _userId || id == 'user_0' || id == 'u1';

  // ─── Lifecycle ────────────────────────────────────────────────────────

  /// Load user data — tries REST Firestore, falls back to SharedPreferences.
  Future<void> load() async {
    final auth = RestFirebaseAuth.instance;

    if (auth.isSignedIn && auth.uid != null) {
      _userId = auth.uid!;
      _email = auth.email ?? '';
      _isLoggedIn = true;

      try {
        final data = await RestFirestoreService.instance
            .getDocument('users', auth.uid!);

        if (data != null) {
          _displayName = data['display_name'] as String? ?? auth.displayName ?? '';
          _stateAbbr = data['state'] as String? ?? '';
          _city = data['city'] as String? ?? '';
          _street = data['street'] as String? ?? '';
          _zip = data['zip'] as String? ?? '';
          _isBmbPlus = data['is_bmb_plus'] as bool? ?? false;
          _isBmbVip = data['is_bmb_vip'] as bool? ?? false;
          _isAdmin = data['is_admin'] as bool? ?? false;
          _isBusiness = data['is_business'] as bool? ?? false;
          _avatarIndex = (data['avatar_index'] as num?)?.toInt() ?? 0;
          _creditsBalance = (data['credits_balance'] as num?)?.toInt() ?? 0;
          _subscriptionTier = data['subscription_tier'] as String? ?? 'free';
          _companionId = data['companion_id'] as String? ?? '';
          _referralCode = data['referral_code'] as String? ?? '';

          await _syncToPrefs();
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('CurrentUserService: REST Firestore load failed: $e');
      }
    }

    // Fallback to SharedPreferences
    await _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _email = prefs.getString('user_email') ?? '';
    _displayName = prefs.getString('user_display_name') ?? '';
    _stateAbbr = prefs.getString('user_state') ?? '';
    _city = prefs.getString('user_city') ?? '';
    _street = prefs.getString('user_street') ?? '';
    _zip = prefs.getString('user_zip') ?? '';
    _isBmbPlus = prefs.getBool('is_bmb_plus') ?? false;
    _isBmbVip = prefs.getBool('is_bmb_vip') ?? false;
    _isAdmin = prefs.getBool('is_admin') ?? false;
    _isBusiness = prefs.getBool('is_business') ?? false;
    _avatarIndex = prefs.getInt('avatar_index') ?? 0;
    _creditsBalance = prefs.getInt('credits_balance') ?? 0;
    _subscriptionTier = prefs.getString('subscription_tier') ?? 'free';
    _companionId = prefs.getString('companion_id') ?? '';
    _referralCode = prefs.getString('referral_code') ?? '';
    if (_userId == 'user_0' && _email.isNotEmpty) {
      _userId = 'user_${_email.hashCode.abs()}';
    }
  }

  Future<void> _syncToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', _isLoggedIn);
    await prefs.setString('user_email', _email);
    await prefs.setString('user_display_name', _displayName);
    await prefs.setString('user_state', _stateAbbr);
    await prefs.setString('user_city', _city);
    await prefs.setString('user_street', _street);
    await prefs.setString('user_zip', _zip);
    await prefs.setBool('is_bmb_plus', _isBmbPlus);
    await prefs.setBool('is_bmb_vip', _isBmbVip);
    await prefs.setBool('is_admin', _isAdmin);
    await prefs.setBool('is_business', _isBusiness);
    await prefs.setInt('avatar_index', _avatarIndex);
    await prefs.setInt('credits_balance', _creditsBalance);
    await prefs.setString('subscription_tier', _subscriptionTier);
    await prefs.setString('companion_id', _companionId);
    await prefs.setString('referral_code', _referralCode);
  }

  Future<void> save() async {
    await _syncToPrefs();

    // Also push updates to Firestore via REST if logged in
    final auth = RestFirebaseAuth.instance;
    if (auth.isSignedIn && auth.uid != null) {
      try {
        await RestFirestoreService.instance.updateDocument(
          'users',
          auth.uid!,
          {
            'display_name': _displayName,
            'state': _stateAbbr,
            'city': _city,
            'street': _street,
            'zip': _zip,
            'avatar_index': _avatarIndex,
            'last_active': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } catch (e) {
        if (kDebugMode) debugPrint('CurrentUserService.save: REST update failed: $e');
      }
    }
  }

  void clear() {
    _userId = 'user_0';
    _displayName = '';
    _email = '';
    _stateAbbr = '';
    _city = '';
    _street = '';
    _zip = '';
    _isBmbPlus = false;
    _isBmbVip = false;
    _isAdmin = false;
    _isBusiness = false;
    _avatarIndex = 0;
    _isLoggedIn = false;
    _creditsBalance = 0;
    _subscriptionTier = 'free';
    _companionId = '';
    _referralCode = '';
  }

  Future<void> updateProfile({
    String? displayName,
    String? stateAbbr,
    String? city,
    String? street,
    String? zip,
    int? avatarIndex,
  }) async {
    if (displayName != null) _displayName = displayName;
    if (stateAbbr != null) _stateAbbr = stateAbbr;
    if (city != null) _city = city;
    if (street != null) _street = street;
    if (zip != null) _zip = zip;
    if (avatarIndex != null) _avatarIndex = avatarIndex;
    await save();
  }

  Future<bool> isEmailRegistered(String email) async {
    try {
      final results = await RestFirestoreService.instance.query(
        'users',
        whereField: 'email',
        whereValue: email.toLowerCase().trim(),
        limit: 1,
      );
      if (results.isNotEmpty) return true;
    } catch (e) {
      if (kDebugMode) debugPrint('CurrentUserService.isEmailRegistered: REST check failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getStringList('registered_emails') ?? [];
    return registered.contains(email.toLowerCase().trim());
  }

  Future<void> registerEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getStringList('registered_emails') ?? [];
    final normalized = email.toLowerCase().trim();
    if (!registered.contains(normalized)) {
      registered.add(normalized);
      await prefs.setStringList('registered_emails', registered);
    }
  }

  void loadFromMap(String uid, Map<String, dynamic> data) {
    _userId = uid;
    _email = data['email'] as String? ?? '';
    _displayName = data['display_name'] as String? ?? '';
    _stateAbbr = data['state'] as String? ?? '';
    _city = data['city'] as String? ?? '';
    _street = data['street'] as String? ?? '';
    _zip = data['zip'] as String? ?? '';
    _isBmbPlus = data['is_bmb_plus'] as bool? ?? false;
    _isBmbVip = data['is_bmb_vip'] as bool? ?? false;
    _isAdmin = data['is_admin'] as bool? ?? false;
    _isBusiness = data['is_business'] as bool? ?? false;
    _avatarIndex = (data['avatar_index'] as num?)?.toInt() ?? 0;
    _creditsBalance = (data['credits_balance'] as num?)?.toInt() ?? 0;
    _subscriptionTier = data['subscription_tier'] as String? ?? 'free';
    _companionId = data['companion_id'] as String? ?? '';
    _referralCode = data['referral_code'] as String? ?? '';
    _isLoggedIn = true;
  }
}
