import 'package:shared_preferences/shared_preferences.dart';

/// Manages chat room access control for BMB tournaments.
///
/// Rules:
/// 1. Each tournament has its own private chat room (bracketId = room key).
/// 2. Only users who have successfully JOINED the tournament may view or
///    participate in that chat room.
/// 3. Users who have NOT joined are shown a prompt to join first.
/// 4. Users must have accepted the Terms of Service to use chat.
/// 5. Suspended / banned users are blocked from all chat rooms.
class ChatAccessService {
  ChatAccessService._();

  // ─── SharedPreferences Keys ──────────────────────────────────────────
  static const String _joinedBracketsKey = 'joined_bracket_ids';
  static const String _tosAcceptedKey = 'tos_accepted';
  static const String _tosAcceptedDateKey = 'tos_accepted_date';
  static const String _chatSuspendedKey = 'chat_suspended';
  static const String _chatSuspendedUntilKey = 'chat_suspended_until';
  static const String _chatBannedKey = 'chat_banned';
  static const String _violationCountKey = 'chat_violation_count';

  // ─── JOIN STATUS ─────────────────────────────────────────────────────

  /// Check if the current user has joined the given tournament.
  static Future<bool> hasJoinedTournament(String bracketId) async {
    final prefs = await SharedPreferences.getInstance();
    final joined = prefs.getStringList(_joinedBracketsKey) ?? [];
    return joined.contains(bracketId);
  }

  /// Record that the current user has joined a tournament.
  static Future<void> recordJoin(String bracketId) async {
    final prefs = await SharedPreferences.getInstance();
    final joined = prefs.getStringList(_joinedBracketsKey) ?? [];
    if (!joined.contains(bracketId)) {
      joined.add(bracketId);
      await prefs.setStringList(_joinedBracketsKey, joined);
    }
  }

  /// Remove a join record (e.g., if user leaves a tournament).
  static Future<void> removeJoin(String bracketId) async {
    final prefs = await SharedPreferences.getInstance();
    final joined = prefs.getStringList(_joinedBracketsKey) ?? [];
    joined.remove(bracketId);
    await prefs.setStringList(_joinedBracketsKey, joined);
  }

  /// Get all bracket IDs the current user has joined.
  static Future<List<String>> getJoinedBrackets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_joinedBracketsKey) ?? [];
  }

  // ─── TERMS OF SERVICE ────────────────────────────────────────────────

  /// Check if the user has accepted the Terms of Service.
  static Future<bool> hasAcceptedTos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tosAcceptedKey) ?? false;
  }

  /// Record TOS acceptance with timestamp.
  static Future<void> acceptTos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tosAcceptedKey, true);
    await prefs.setString(_tosAcceptedDateKey, DateTime.now().toIso8601String());
  }

  /// Get the date when TOS was accepted.
  static Future<DateTime?> getTosAcceptedDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_tosAcceptedDateKey);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  // ─── MODERATION / SUSPENSION / BAN ───────────────────────────────────

  /// Check if the user is currently suspended from chat.
  static Future<bool> isChatSuspended() async {
    final prefs = await SharedPreferences.getInstance();
    final suspended = prefs.getBool(_chatSuspendedKey) ?? false;
    if (!suspended) return false;

    // Check if suspension has expired
    final untilStr = prefs.getString(_chatSuspendedUntilKey);
    if (untilStr != null) {
      final until = DateTime.tryParse(untilStr);
      if (until != null && DateTime.now().isAfter(until)) {
        // Suspension expired, clear it
        await prefs.setBool(_chatSuspendedKey, false);
        await prefs.remove(_chatSuspendedUntilKey);
        return false;
      }
    }
    return true;
  }

  /// Check if the user is permanently banned from chat.
  static Future<bool> isChatBanned() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chatBannedKey) ?? false;
  }

  /// Record a violation and potentially suspend/ban the user.
  /// Returns the enforcement action taken.
  static Future<String> recordViolation() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_violationCountKey) ?? 0) + 1;
    await prefs.setInt(_violationCountKey, count);

    if (count >= 5) {
      // Permanent ban
      await prefs.setBool(_chatBannedKey, true);
      return 'BANNED';
    } else if (count >= 4) {
      // 30-day suspension
      await prefs.setBool(_chatSuspendedKey, true);
      await prefs.setString(_chatSuspendedUntilKey,
          DateTime.now().add(const Duration(days: 30)).toIso8601String());
      return 'SUSPENDED_30_DAYS';
    } else if (count >= 3) {
      // 7-day suspension
      await prefs.setBool(_chatSuspendedKey, true);
      await prefs.setString(_chatSuspendedUntilKey,
          DateTime.now().add(const Duration(days: 7)).toIso8601String());
      return 'SUSPENDED_7_DAYS';
    } else if (count >= 2) {
      // 24-hour suspension
      await prefs.setBool(_chatSuspendedKey, true);
      await prefs.setString(_chatSuspendedUntilKey,
          DateTime.now().add(const Duration(hours: 24)).toIso8601String());
      return 'SUSPENDED_24_HOURS';
    } else {
      // First violation = warning
      return 'WARNING';
    }
  }

  /// Get current violation count.
  static Future<int> getViolationCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_violationCountKey) ?? 0;
  }

  // ─── COMPREHENSIVE ACCESS CHECK ──────────────────────────────────────

  /// Performs all access checks and returns a [ChatAccessResult].
  static Future<ChatAccessResult> checkAccess(String bracketId) async {
    // 1. Check if banned
    if (await isChatBanned()) {
      return ChatAccessResult(
        allowed: false,
        reason: ChatDenialReason.banned,
        message: 'Your account has been permanently banned from BMB chat rooms due to repeated violations.',
      );
    }

    // 2. Check if suspended
    if (await isChatSuspended()) {
      final prefs = await SharedPreferences.getInstance();
      final untilStr = prefs.getString(_chatSuspendedUntilKey) ?? '';
      return ChatAccessResult(
        allowed: false,
        reason: ChatDenialReason.suspended,
        message: 'Your chat access is suspended until $untilStr. Please respect our community guidelines.',
      );
    }

    // 3. Check TOS acceptance
    if (!await hasAcceptedTos()) {
      return ChatAccessResult(
        allowed: false,
        reason: ChatDenialReason.tosNotAccepted,
        message: 'You must accept the Terms of Service and Community Chat Agreement before using chat rooms.',
      );
    }

    // 4. Check if user has joined this tournament
    if (!await hasJoinedTournament(bracketId)) {
      return ChatAccessResult(
        allowed: false,
        reason: ChatDenialReason.notJoined,
        message: 'You must join this tournament to access its chat room.',
      );
    }

    return ChatAccessResult(
      allowed: true,
      reason: null,
      message: null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ACCESS RESULT
// ═══════════════════════════════════════════════════════════════════════════
enum ChatDenialReason {
  banned,
  suspended,
  tosNotAccepted,
  notJoined,
}

class ChatAccessResult {
  final bool allowed;
  final ChatDenialReason? reason;
  final String? message;

  const ChatAccessResult({
    required this.allowed,
    this.reason,
    this.message,
  });
}
