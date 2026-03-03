import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Manages the Social Follow Promo feature.
///
/// Admin controls:
///   - Enable / disable the promo globally (manual toggle)
///   - Set a custom credit amount (any positive integer)
///   - Schedule an automated timeframe (start + end date/time)
///   - Admin override: force promo ON or OFF regardless of schedule
///
/// Scheduling logic:
///   1. If admin override is ON  → promo state = the manual toggle value.
///   2. If admin override is OFF → promo state is determined by schedule:
///      - No schedule set        → falls back to manual toggle.
///      - Schedule set, now < start → promo is OFF (hasn't started yet).
///      - Schedule set, start <= now <= end → promo is ON (in window).
///      - Schedule set, now > end → promo is OFF (expired).
///
/// User tracking:
///   - Which platforms the user has "visited" (opened the link)
///   - Whether the user has already claimed the promo reward
///
/// All state is persisted in SharedPreferences so it survives restarts.
class SocialFollowPromoService {
  SocialFollowPromoService._();
  static final SocialFollowPromoService instance =
      SocialFollowPromoService._();

  // ─── Keys ────────────────────────────────────────────────────────────
  static const _kEnabled = 'social_promo_enabled';
  static const _kCreditAmount = 'social_promo_credit_amount';
  static const _kVisitedPlatforms = 'social_promo_visited';
  static const _kPromoClaimed = 'social_promo_claimed';
  static const _kScheduleStart = 'social_promo_schedule_start';
  static const _kScheduleEnd = 'social_promo_schedule_end';
  static const _kScheduleEnabled = 'social_promo_schedule_enabled';
  static const _kAdminOverride = 'social_promo_admin_override';

  // ─── Default values ──────────────────────────────────────────────────
  /// Total max credits available (3 credits x 5 platforms = 15).
  static const int defaultCreditAmount = 15;

  /// Credits awarded per platform visited.
  static const int creditsPerPlatform = 3;

  /// Minimum platforms the user must visit before they can claim.
  static const int minPlatformsToClaim = 1;

  /// The 5 social platforms the promo requires.
  static const List<SocialPlatform> platforms = [
    SocialPlatform(
      id: 'instagram',
      name: 'Instagram',
      handle: '@backmybracket',
      url: 'https://instagram.com/backmybracket',
      deepLink: 'instagram://user?username=backmybracket',
      colorHex: 0xFFE4405F,
      iconName: 'instagram',
    ),
    SocialPlatform(
      id: 'tiktok',
      name: 'TikTok',
      handle: '@backmybracket',
      url: 'https://tiktok.com/@backmybracket',
      deepLink: 'https://tiktok.com/@backmybracket',
      colorHex: 0xFF000000,
      iconName: 'tiktok',
    ),
    SocialPlatform(
      id: 'twitter',
      name: 'X / Twitter',
      handle: '@BackMyBracket',
      url: 'https://twitter.com/BackMyBracket',
      deepLink: 'twitter://user?screen_name=BackMyBracket',
      colorHex: 0xFF1DA1F2,
      iconName: 'twitter',
    ),
    SocialPlatform(
      id: 'facebook',
      name: 'Facebook',
      handle: 'Back My Bracket',
      url: 'https://facebook.com/backmybracket',
      deepLink: 'fb://page/backmybracket',
      colorHex: 0xFF1877F2,
      iconName: 'facebook',
    ),
    SocialPlatform(
      id: 'youtube',
      name: 'YouTube',
      handle: 'Back My Bracket',
      url: 'https://youtube.com/@backmybracket',
      deepLink: 'https://youtube.com/@backmybracket',
      colorHex: 0xFFFF0000,
      iconName: 'youtube',
    ),
  ];

  // ─── Admin API — manual toggle ─────────────────────────────────────

  /// The raw manual toggle value (what the switch shows).
  Future<bool> isManualToggleOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? true;
  }

  /// Set the manual toggle. Also used by the admin override.
  Future<void> setManualToggle(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    if (kDebugMode) {
      debugPrint('SocialFollowPromo: manualToggle=$enabled');
    }
  }

  // ─── Admin API — schedule ──────────────────────────────────────────

  /// Whether a schedule has been configured.
  Future<bool> isScheduleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kScheduleEnabled) ?? false;
  }

  Future<void> setScheduleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kScheduleEnabled, enabled);
  }

  /// Persisted start time (ISO-8601).
  Future<DateTime?> getScheduleStart() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kScheduleStart);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> setScheduleStart(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kScheduleStart, dt.toIso8601String());
  }

  /// Persisted end time (ISO-8601).
  Future<DateTime?> getScheduleEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kScheduleEnd);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> setScheduleEnd(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kScheduleEnd, dt.toIso8601String());
  }

  /// Save both start and end together and enable the schedule.
  Future<void> setSchedule(DateTime start, DateTime end) async {
    await setScheduleStart(start);
    await setScheduleEnd(end);
    await setScheduleEnabled(true);
    if (kDebugMode) {
      debugPrint(
          'SocialFollowPromo: schedule set $start → $end');
    }
  }

  /// Remove the schedule entirely.
  Future<void> clearSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kScheduleStart);
    await prefs.remove(_kScheduleEnd);
    await prefs.setBool(_kScheduleEnabled, false);
  }

  // ─── Admin API — override ──────────────────────────────────────────

  /// When admin override is ON the manual toggle controls the promo
  /// directly, ignoring any schedule.
  Future<bool> isAdminOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAdminOverride) ?? false;
  }

  Future<void> setAdminOverride(bool override) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminOverride, override);
    if (kDebugMode) {
      debugPrint('SocialFollowPromo: adminOverride=$override');
    }
  }

  // ─── Effective promo state ─────────────────────────────────────────

  /// The computed active state that determines whether new users see the
  /// promo. This is the single source of truth.
  ///
  /// Priority:
  ///   1. Admin override ON → use manual toggle.
  ///   2. Schedule enabled  → use schedule window.
  ///   3. No schedule       → use manual toggle.
  Future<bool> isPromoEnabled() async {
    final override = await isAdminOverride();
    final manualOn = await isManualToggleOn();

    if (override) return manualOn;

    final schedEnabled = await isScheduleEnabled();
    if (!schedEnabled) return manualOn;

    final start = await getScheduleStart();
    final end = await getScheduleEnd();
    if (start == null || end == null) return manualOn;

    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Returns a human-readable status describing *why* the promo is
  /// currently active or inactive. Useful for the admin dashboard.
  Future<PromoStatus> getPromoStatus() async {
    final override = await isAdminOverride();
    final manualOn = await isManualToggleOn();
    final schedEnabled = await isScheduleEnabled();
    final start = await getScheduleStart();
    final end = await getScheduleEnd();
    final now = DateTime.now();

    if (override) {
      return PromoStatus(
        isActive: manualOn,
        reason: manualOn
            ? 'Admin override — promo forced ON'
            : 'Admin override — promo forced OFF',
        mode: PromoMode.override,
        scheduleStart: start,
        scheduleEnd: end,
      );
    }

    if (schedEnabled && start != null && end != null) {
      if (now.isBefore(start)) {
        return PromoStatus(
          isActive: false,
          reason: 'Scheduled — waiting to start',
          mode: PromoMode.scheduled,
          scheduleStart: start,
          scheduleEnd: end,
        );
      } else if (now.isAfter(end)) {
        return PromoStatus(
          isActive: false,
          reason: 'Scheduled — promo has ended',
          mode: PromoMode.expired,
          scheduleStart: start,
          scheduleEnd: end,
        );
      } else {
        return PromoStatus(
          isActive: true,
          reason: 'Scheduled — promo is live',
          mode: PromoMode.scheduledLive,
          scheduleStart: start,
          scheduleEnd: end,
        );
      }
    }

    return PromoStatus(
      isActive: manualOn,
      reason: manualOn ? 'Manual — promo is ON' : 'Manual — promo is OFF',
      mode: PromoMode.manual,
      scheduleStart: start,
      scheduleEnd: end,
    );
  }

  // ─── Admin API — credit amount ─────────────────────────────────────

  Future<int> getCreditAmount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kCreditAmount) ?? defaultCreditAmount;
  }

  Future<void> setCreditAmount(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCreditAmount, amount);
    if (kDebugMode) {
      debugPrint('SocialFollowPromo: creditAmount=$amount');
    }
  }

  // ─── User API ────────────────────────────────────────────────────────

  Future<Set<String>> getVisitedPlatforms() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kVisitedPlatforms) ?? [];
    return list.toSet();
  }

  Future<void> markPlatformVisited(String platformId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kVisitedPlatforms) ?? [];
    if (!list.contains(platformId)) {
      list.add(platformId);
      await prefs.setStringList(_kVisitedPlatforms, list);
    }
  }

  Future<bool> allPlatformsVisited() async {
    final visited = await getVisitedPlatforms();
    return visited.length >= platforms.length;
  }

  /// How many credits the user has earned so far based on platforms visited.
  Future<int> getEarnedCredits() async {
    final visited = await getVisitedPlatforms();
    return visited.length * creditsPerPlatform;
  }

  /// Whether the user has visited enough platforms to claim.
  Future<bool> canClaim() async {
    final visited = await getVisitedPlatforms();
    final claimed = await hasClaimedPromo();
    return !claimed && visited.isNotEmpty;
  }

  Future<bool> hasClaimedPromo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPromoClaimed) ?? false;
  }

  /// Claim tiered social-follow credits based on how many platforms
  /// the user actually visited (3 credits per platform, up to 15).
  Future<int> claimPromoCredits() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPromoClaimed) ?? false) return 0;

    final visited = await getVisitedPlatforms();
    if (visited.isEmpty) return 0;

    // Tiered: 3 credits per platform visited
    final amount = visited.length * creditsPerPlatform;

    final currentBalance = prefs.getDouble('bmb_bucks_balance') ?? 0;
    await prefs.setDouble('bmb_bucks_balance', currentBalance + amount);

    await prefs.setBool(_kPromoClaimed, true);

    // Store how many platforms were visited at claim time (for analytics)
    await prefs.setInt('social_promo_platforms_at_claim', visited.length);

    final transactions =
        prefs.getStringList('bmb_bucks_transactions') ?? [];
    transactions.insert(
      0,
      '${DateTime.now().toIso8601String()}|social_follow_bonus|+$amount|Social Follow Promo (${visited.length} platforms)',
    );
    await prefs.setStringList('bmb_bucks_transactions', transactions);

    if (kDebugMode) {
      debugPrint(
          'SocialFollowPromo: Awarded $amount credits '
          '(${visited.length} platforms x $creditsPerPlatform). '
          'New balance: ${currentBalance + amount}');
    }
    return amount;
  }

  /// Whether the promo popup should show for this user right now.
  Future<bool> shouldShowPromo() async {
    final enabled = await isPromoEnabled();
    if (!enabled) return false;
    final claimed = await hasClaimedPromo();
    return !claimed;
  }

  Future<void> resetUserPromoState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kVisitedPlatforms);
    await prefs.remove(_kPromoClaimed);
  }
}

// ─── Data models ─────────────────────────────────────────────────────────

class SocialPlatform {
  final String id;
  final String name;
  final String handle;
  final String url;
  final String deepLink;
  final int colorHex;
  final String iconName;

  const SocialPlatform({
    required this.id,
    required this.name,
    required this.handle,
    required this.url,
    required this.deepLink,
    required this.colorHex,
    required this.iconName,
  });
}

enum PromoMode { manual, scheduled, scheduledLive, expired, override }

class PromoStatus {
  final bool isActive;
  final String reason;
  final PromoMode mode;
  final DateTime? scheduleStart;
  final DateTime? scheduleEnd;

  const PromoStatus({
    required this.isActive,
    required this.reason,
    required this.mode,
    this.scheduleStart,
    this.scheduleEnd,
  });
}
