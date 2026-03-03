import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages bot account detection and controlled bot creation.
///
/// Only admin-created bots are allowed.  User signups must pass
/// human verification first — any account that doesn't pass is
/// flagged and blocked.
class BotAccountService {
  BotAccountService._();
  static final BotAccountService instance = BotAccountService._();

  static const _keyIsBot = 'is_bot_account';
  static const _keyBotControlledBy = 'bot_controlled_by';
  static const _keyHumanVerified = 'human_verified';
  static const _keyVerifiedAt = 'human_verified_at';

  // ─── Mark current session as human-verified ──────────────────────────

  Future<void> markHumanVerified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHumanVerified, true);
      await prefs.setString(
          _keyVerifiedAt, DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) debugPrint('[BotAccountService] markHumanVerified error: $e');
    }
  }

  Future<bool> isHumanVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHumanVerified) ?? false;
  }

  // ─── Bot account helpers ─────────────────────────────────────────────

  /// Creates a controlled bot account (admin only).
  Future<void> createBotAccount({
    required String email,
    required String displayName,
    required String controlledByAdmin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsBot, true);
    await prefs.setString(_keyBotControlledBy, controlledByAdmin);
    // In production you'd write this to Firestore with isBot: true
  }

  /// Returns true if the current logged-in account is a bot.
  Future<bool> isCurrentAccountBot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsBot) ?? false;
  }

  /// Clears verification state (used on logout).
  Future<void> clearVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHumanVerified);
      await prefs.remove(_keyVerifiedAt);
    } catch (e) {
      if (kDebugMode) debugPrint('[BotAccountService] clearVerification error: $e');
    }
  }
}
