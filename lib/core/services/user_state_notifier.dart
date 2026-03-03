import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// FIX #19: ChangeNotifier that wraps [CurrentUserService] for Provider.
///
/// Screens that depend on user state listen to [UserStateNotifier] instead of
/// calling setState(). This replaces many loose setState() calls with a single
/// reactive source of truth.
///
/// Usage:
///   `context.watch<UserStateNotifier>()`   — rebuilds on change
///   `context.read<UserStateNotifier>()`    — one-shot reads
class UserStateNotifier extends ChangeNotifier {
  final CurrentUserService _svc = CurrentUserService.instance;

  // ── Forwarded getters ───────────────────────────────────────────────
  String get userId => _svc.userId;
  String get displayName => _svc.displayName;
  String get email => _svc.email;
  String get stateAbbr => _svc.stateAbbr;
  String get city => _svc.city;
  bool get isBmbPlus => _svc.isBmbPlus;
  bool get isBmbVip => _svc.isBmbVip;
  bool get isAdmin => _svc.isAdmin;
  bool get isBusiness => _svc.isBusiness;
  int get avatarIndex => _svc.avatarIndex;
  bool get isLoggedIn => _svc.isLoggedIn;
  bool isCurrentUser(String id) => _svc.isCurrentUser(id);

  // ── BMB Bucks balance (read from SharedPreferences) ─────────────────
  double _bmbBucks = 0;
  double get bmbBucks => _bmbBucks;

  // ── Lifecycle ───────────────────────────────────────────────────────

  /// Load user from SharedPreferences and notify listeners.
  Future<void> load() async {
    await _svc.load();
    final prefs = await SharedPreferences.getInstance();
    _bmbBucks = prefs.getDouble('bmb_bucks_balance') ?? 0;
    notifyListeners();
  }

  /// Update profile fields and notify listeners.
  Future<void> updateProfile({
    String? displayName,
    String? stateAbbr,
    String? city,
    String? street,
    String? zip,
    int? avatarIndex,
  }) async {
    await _svc.updateProfile(
      displayName: displayName,
      stateAbbr: stateAbbr,
      city: city,
      street: street,
      zip: zip,
      avatarIndex: avatarIndex,
    );
    notifyListeners();
  }

  /// Update BMB Bucks balance and notify listeners.
  Future<void> updateBmbBucks(double newBalance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bmb_bucks_balance', newBalance);
    _bmbBucks = newBalance;
    notifyListeners();
  }

  /// Refresh membership tier flags from SharedPreferences.
  Future<void> refreshTier() async {
    await _svc.load();
    final prefs = await SharedPreferences.getInstance();
    _bmbBucks = prefs.getDouble('bmb_bucks_balance') ?? 0;
    notifyListeners();
  }

  /// Clear user state (call on logout).
  void clear() {
    _svc.clear();
    _bmbBucks = 0;
    notifyListeners();
  }
}
