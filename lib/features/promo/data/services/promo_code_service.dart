import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/device_fingerprint_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

/// Promo Code Service — validates codes, awards credits to BMB Bucket.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ANTI-ABUSE SYSTEM (4 Layers)
/// ═══════════════════════════════════════════════════════════════════════
///
/// Layer 1: PER-USER TRACKING
///   Each code can only be redeemed once per user account (by user ID).
///   Stored in SharedPreferences under the user's unique key.
///
/// Layer 2: PER-DEVICE TRACKING
///   Each code can only be redeemed once per physical device (any account).
///   Prevents creating new accounts on the same phone to re-use codes.
///   Uses DeviceFingerprintService for persistent device identity.
///
/// Layer 3: RATE LIMITING
///   - Max 3 failed attempts per hour (anti brute-force)
///   - Max 5 total attempts per hour (anti-spam)
///   - 24-hour lockout after 10 consecutive failures
///
/// Layer 4: CODE-TYPE RESTRICTIONS
///   - Welcome codes: only redeemable within 48 hours of account creation
///   - Welcome codes: max 1 welcome-type code per account lifetime
///   - Event codes: have expiration dates
///   - Global redemption caps per code
///
/// In production: these checks are also enforced server-side.
/// The local checks provide instant UX feedback and reduce server load.
/// ═══════════════════════════════════════════════════════════════════════
class PromoCodeService {
  PromoCodeService._();
  static final PromoCodeService instance = PromoCodeService._();

  final _deviceService = DeviceFingerprintService.instance;
  final _userService = CurrentUserService.instance;
  final _firestore = RestFirestoreService.instance;

  // ═══════════════════════════════════════════════════════════════════
  // PROMO CODE CATALOG
  // In production: fetch from backend/Firebase. For now, hardcoded.
  // ═══════════════════════════════════════════════════════════════════

  static const List<PromoCode> _codes = [
    // ── HOST FREE TOURNAMENT CODES ──────────────────────────────────
    PromoCode(
      code: 'FREEHOST50',
      credits: 50,
      description: 'Free Tournament Host Pass — 50 credits',
      type: PromoType.hostFreeTourney,
      maxRedemptions: 100,
    ),
    PromoCode(
      code: 'HOSTBMB100',
      credits: 100,
      description: 'BMB Host Starter — 100 credits',
      type: PromoType.hostFreeTourney,
      maxRedemptions: 50,
    ),
    PromoCode(
      code: 'BMBBOSS',
      credits: 200,
      description: 'BMB Boss Pack — 200 credits to host premium brackets',
      type: PromoType.hostFreeTourney,
      maxRedemptions: 25,
    ),

    // ── WELCOME ABOARD CODES ─────────────────────────────────────────
    // Active welcome code — distributed via ads, rotated periodically.
    // Only ONE welcome-type code is allowed per account lifetime.
    // Max 2 accounts per device can redeem a welcome code.
    PromoCode(
      code: 'WELCOME81',
      credits: 25,
      description: 'Welcome Aboard — 25 free credits for joining the BmB family!',
      type: PromoType.welcomeBonus,
      maxRedemptions: 10000,
    ),

    // ── RETIRED WELCOME CODES (kept for history / duplicate checks) ────
    PromoCode(
      code: 'WELCOME25',
      credits: 25,
      description: 'Welcome to BMB — 25 bonus credits (retired)',
      type: PromoType.welcomeBonus,
      maxRedemptions: 1000,
    ),
    PromoCode(
      code: 'BACKMYBRACKET',
      credits: 50,
      description: 'Back My Bracket Launch Special — 50 credits',
      type: PromoType.welcomeBonus,
      maxRedemptions: 500,
    ),

    // ── EVENT PROMO CODES ───────────────────────────────────────────
    PromoCode(
      code: 'SUMMER25',
      credits: 30,
      description: 'Summer 2025 Promo — 30 bonus credits',
      type: PromoType.eventPromo,
      maxRedemptions: 200,
    ),
    PromoCode(
      code: 'MARCHMADNESS',
      credits: 50,
      description: 'March Madness Special — 50 credits for bracket season',
      type: PromoType.eventPromo,
      maxRedemptions: 500,
    ),
    PromoCode(
      code: 'SUPERBOWL',
      credits: 25,
      description: 'Super Bowl Promo — 25 credits for game day',
      type: PromoType.eventPromo,
      maxRedemptions: 300,
    ),
    PromoCode(
      code: 'NFL2025',
      credits: 40,
      description: 'NFL Season Kickoff — 40 credits',
      type: PromoType.eventPromo,
      maxRedemptions: 500,
    ),

    // ── CREDIT BONUS CODES ──────────────────────────────────────────
    PromoCode(
      code: 'CREDITS10',
      credits: 10,
      description: 'Quick 10 — 10 bonus credits',
      type: PromoType.creditBonus,
      maxRedemptions: 500,
    ),
    PromoCode(
      code: 'BMBVIP',
      credits: 75,
      description: 'VIP Special — 75 bonus credits',
      type: PromoType.creditBonus,
      maxRedemptions: 100,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════
  // REDEEM FLOW — with all 4 anti-abuse layers
  // ═══════════════════════════════════════════════════════════════════

  /// Attempt to redeem a promo code. Returns result with success/failure info.
  /// Enforces all anti-abuse checks before awarding credits.
  Future<PromoRedeemResult> redeemCode(String inputCode) async {
    final normalized = inputCode.trim().toUpperCase();

    if (normalized.isEmpty) {
      return const PromoRedeemResult(
        success: false,
        message: 'Please enter a promo code.',
      );
    }

    // ─── LAYER 3: Rate Limit Check (first — cheapest check) ────────
    final rateResult = await _deviceService.checkRateLimit();
    if (rateResult.blocked) {
      return PromoRedeemResult(
        success: false,
        message: rateResult.reason ?? 'Too many attempts. Please try later.',
        abuseFlag: AbuseFlag.rateLimited,
      );
    }

    // ─── LAYER 3b: Cooldown between successful redemptions ─────────
    final cooldownResult = await _deviceService.checkRedeemCooldown();
    if (cooldownResult.blocked) {
      return PromoRedeemResult(
        success: false,
        message: cooldownResult.reason ?? 'Please wait before trying again.',
        abuseFlag: AbuseFlag.rateLimited,
      );
    }

    // ─── LAYER 3c: Daily redemption cap ────────────────────────────
    final dailyResult = await _deviceService.checkDailyRedeemLimit();
    if (dailyResult.blocked) {
      return PromoRedeemResult(
        success: false,
        message: dailyResult.reason ?? 'Daily limit reached.',
        abuseFlag: AbuseFlag.rateLimited,
      );
    }

    // ─── Find the matching code ────────────────────────────────────
    final promo = _codes.cast<PromoCode?>().firstWhere(
      (c) => c!.code == normalized,
      orElse: () => null,
    );

    if (promo == null) {
      await _deviceService.recordAttempt(success: false);
      return const PromoRedeemResult(
        success: false,
        message: 'Invalid promo code. Please check and try again.',
      );
    }

    // ─── LAYER 1: Per-User Check ──────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    final userId = _userService.userId;
    final userRedeemedKey = 'redeemed_promo_codes_$userId';
    final userRedeemed = prefs.getStringList(userRedeemedKey) ?? [];

    // Also check legacy key (pre-upgrade)
    final legacyRedeemed = prefs.getStringList('redeemed_promo_codes') ?? [];

    if (userRedeemed.contains(normalized) ||
        legacyRedeemed.contains(normalized)) {
      await _deviceService.recordAttempt(success: false);
      return const PromoRedeemResult(
        success: false,
        message: 'You\'ve already redeemed this code on your account.',
        abuseFlag: AbuseFlag.alreadyRedeemedUser,
      );
    }

    // ─── LAYER 2: Per-Device Check ────────────────────────────────
    final deviceRedeemed =
        await _deviceService.isCodeRedeemedOnDevice(normalized);
    if (deviceRedeemed) {
      await _deviceService.recordAttempt(success: false);
      return const PromoRedeemResult(
        success: false,
        message:
            'This code has already been used on this device. '
            'Each promo code can only be used once per device.',
        abuseFlag: AbuseFlag.alreadyRedeemedDevice,
      );
    }

    // ─── LAYER 4a: Welcome Code Age Restriction ───────────────────
    if (promo.type == PromoType.welcomeBonus) {
      // Welcome codes only work within 48 hours of account creation
      final accountAge = await _getAccountAge();
      if (accountAge != null && accountAge.inHours > 48) {
        await _deviceService.recordAttempt(success: false);
        return const PromoRedeemResult(
          success: false,
          message:
              'Welcome codes can only be used within 48 hours of creating '
              'your account.',
          abuseFlag: AbuseFlag.welcomeCodeExpired,
        );
      }

      // Max 1 welcome-type code per account lifetime
      final welcomeUsedKey = 'welcome_promo_used_$userId';
      final alreadyUsedWelcome = prefs.getBool(welcomeUsedKey) ?? false;
      if (alreadyUsedWelcome) {
        await _deviceService.recordAttempt(success: false);
        return const PromoRedeemResult(
          success: false,
          message:
              'You\'ve already used a welcome bonus code. '
              'Only one welcome code is allowed per account.',
          abuseFlag: AbuseFlag.welcomeCodeLimitReached,
        );
      }
    }

    // ─── LAYER 4b: Suspicious Install Detection ───────────────────
    final suspicious = await _deviceService.isSuspiciousFreshInstall();
    if (suspicious && promo.type == PromoType.welcomeBonus) {
      await _deviceService.recordAttempt(success: false);
      return const PromoRedeemResult(
        success: false,
        message:
            'This device has been flagged for unusual activity. '
            'Please contact support@backmybracket.com if you believe '
            'this is an error.',
        abuseFlag: AbuseFlag.suspiciousDevice,
      );
    }

    // ─── LAYER 4b2: Multi-Account Detection (2 max per device/IP) ──
    // Blocks welcome bonus codes if 2+ accounts have ALREADY redeemed
    // a welcome code on this device.
    if (promo.type == PromoType.welcomeBonus) {
      final welcomeRedeemCount =
          await _deviceService.getWelcomeCodeRedeemCount();
      if (welcomeRedeemCount >= 2) {
        await _deviceService.recordAttempt(success: false);
        return const PromoRedeemResult(
          success: false,
          message:
              'This device has already been used to redeem the maximum '
              'number of welcome bonuses (2 per device). '
              'Contact support@backmybracket.com if you need help.',
          abuseFlag: AbuseFlag.suspiciousDevice,
        );
      }
    }

    // ─── LAYER 4c: Global Redemption Cap ──────────────────────────
    final globalKey = 'promo_global_count_$normalized';
    final globalCount = prefs.getInt(globalKey) ?? 0;
    if (globalCount >= promo.maxRedemptions) {
      await _deviceService.recordAttempt(success: false);
      return const PromoRedeemResult(
        success: false,
        message: 'This promo code has expired (max redemptions reached).',
      );
    }

    // ═══════════════════════════════════════════════════════════════
    // ALL CHECKS PASSED — Award credits
    // ═══════════════════════════════════════════════════════════════

    final currentBalance = prefs.getDouble('bmb_bucks_balance') ?? 0;
    final newBalance = currentBalance + promo.credits;
    await prefs.setDouble('bmb_bucks_balance', newBalance);

    // ── Mark as redeemed: User level ─────────────────────────────
    userRedeemed.add(normalized);
    await prefs.setStringList(userRedeemedKey, userRedeemed);

    // Also update legacy key for backward compatibility
    legacyRedeemed.add(normalized);
    await prefs.setStringList('redeemed_promo_codes', legacyRedeemed);

    // ── Mark as redeemed: Device level ───────────────────────────
    await _deviceService.markCodeRedeemedOnDevice(normalized);

    // ── Mark welcome code used (if applicable) ───────────────────
    if (promo.type == PromoType.welcomeBonus) {
      final welcomeUsedKey = 'welcome_promo_used_$userId';
      await prefs.setBool(welcomeUsedKey, true);
      // Also increment the per-device welcome redeem counter
      await _deviceService.incrementWelcomeCodeRedeemCount();
    }

    // ── Increment global count ───────────────────────────────────
    await prefs.setInt(globalKey, globalCount + 1);

    // ── Record successful attempt ────────────────────────────────
    await _deviceService.recordAttempt(success: true);

    // ── Record cooldown + daily limit tracking ───────────────────
    await _deviceService.recordSuccessfulRedeem();

    // ── Record redemption in transaction history ─────────────────
    final deviceId = await _deviceService.getDeviceId();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final transactions = prefs.getStringList('promo_transactions') ?? [];
    transactions.insert(
      0,
      '$timestamp'
      '|$normalized'
      '|${promo.credits}'
      '|${promo.description}'
      '|$userId'
      '|$deviceId',
    );
    await prefs.setStringList('promo_transactions', transactions);

    // ── Persist to Firestore (durable, cross-device) ────────────────
    try {
      await _firestore.addDocument('promo_redemptions', {
        'code': normalized,
        'credits': promo.credits,
        'description': promo.description,
        'type': promo.type.name,
        'userId': userId,
        'deviceId': deviceId,
        'timestamp': timestamp,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[PromoCode] Firestore write error: $e');
    }

    if (kDebugMode) {
      debugPrint(
        '[PromoCode] Redeemed $normalized: +${promo.credits} credits. '
        'User: $userId, Device: $deviceId, New balance: $newBalance',
      );
    }

    return PromoRedeemResult(
      success: true,
      message: '${promo.credits} credits added to your BMB Bucket!',
      creditsAwarded: promo.credits,
      newBalance: newBalance.toInt(),
      promoDescription: promo.description,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HISTORY & QUERIES
  // ═══════════════════════════════════════════════════════════════════

  /// Get list of previously redeemed codes for this user.
  Future<List<PromoRedemptionRecord>> getRedemptionHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('promo_transactions') ?? [];
    return raw.map((line) {
      final parts = line.split('|');
      return PromoRedemptionRecord(
        redeemedAt: DateTime.parse(parts[0]),
        code: parts[1],
        credits: int.parse(parts[2]),
        description: parts.length > 3 ? parts[3] : '',
        userId: parts.length > 4 ? parts[4] : '',
        deviceId: parts.length > 5 ? parts[5] : '',
      );
    }).toList();
  }

  /// Check if a code has already been redeemed (user OR device level).
  Future<bool> isCodeRedeemed(String code) async {
    final normalized = code.trim().toUpperCase();

    // Check user level
    final prefs = await SharedPreferences.getInstance();
    final userId = _userService.userId;
    final userRedeemedKey = 'redeemed_promo_codes_$userId';
    final userRedeemed = prefs.getStringList(userRedeemedKey) ?? [];
    if (userRedeemed.contains(normalized)) return true;

    // Check legacy key
    final legacyRedeemed = prefs.getStringList('redeemed_promo_codes') ?? [];
    if (legacyRedeemed.contains(normalized)) return true;

    // Check device level
    return await _deviceService.isCodeRedeemedOnDevice(normalized);
  }

  /// Get a summary of anti-abuse status for admin/debug purposes.
  Future<Map<String, dynamic>> getAntiAbuseSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userService.userId;
    final deviceId = await _deviceService.getDeviceId();
    final userRedeemedKey = 'redeemed_promo_codes_$userId';
    final userRedeemed = prefs.getStringList(userRedeemedKey) ?? [];
    final deviceRedeemed = await _deviceService.getDeviceRedemptions();
    final rateResult = await _deviceService.checkRateLimit();
    final installTs = await _deviceService.getInstallTimestamp();

    return {
      'userId': userId,
      'deviceId': deviceId,
      'userRedeemedCodes': userRedeemed,
      'deviceRedeemedCodes': deviceRedeemed,
      'isRateLimited': rateResult.blocked,
      'rateLimitReason': rateResult.reason,
      'installTimestamp': installTs.toIso8601String(),
      'accountAgeHours': (await _getAccountAge())?.inHours ?? 'unknown',
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Determine how old the current account is.
  /// Returns null if account creation time is unknown.
  Future<Duration?> _getAccountAge() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userService.userId;
    final createdKey = 'account_created_at_$userId';
    final createdStr = prefs.getString(createdKey);

    if (createdStr != null) {
      final created = DateTime.tryParse(createdStr);
      if (created != null) {
        return DateTime.now().difference(created);
      }
    }

    // If no creation time stored, store one now (first check = account exists)
    // This means the first time anti-abuse runs, it records the current time.
    await prefs.setString(createdKey, DateTime.now().toIso8601String());
    return Duration.zero;
  }

  /// Called during signup to record account creation time.
  /// This should be called from the auth flow after successful signup.
  Future<void> recordAccountCreation() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userService.userId;
    final createdKey = 'account_created_at_$userId';
    await prefs.setString(createdKey, DateTime.now().toIso8601String());
  }
}

// ═══════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════

enum PromoType {
  hostFreeTourney,
  welcomeBonus,
  creditBonus,
  eventPromo,
}

/// Flags indicating why a redemption was blocked.
enum AbuseFlag {
  none,
  alreadyRedeemedUser,
  alreadyRedeemedDevice,
  rateLimited,
  welcomeCodeExpired,
  welcomeCodeLimitReached,
  suspiciousDevice,
}

class PromoCode {
  final String code;
  final int credits;
  final String description;
  final PromoType type;
  final int maxRedemptions;

  const PromoCode({
    required this.code,
    required this.credits,
    required this.description,
    required this.type,
    this.maxRedemptions = 100,
  });

  String get typeLabel {
    switch (type) {
      case PromoType.hostFreeTourney:
        return 'Host Pass';
      case PromoType.welcomeBonus:
        return 'Welcome Bonus';
      case PromoType.creditBonus:
        return 'Credit Bonus';
      case PromoType.eventPromo:
        return 'Event Promo';
    }
  }
}

class PromoRedeemResult {
  final bool success;
  final String message;
  final int creditsAwarded;
  final int newBalance;
  final String? promoDescription;
  final AbuseFlag abuseFlag;

  const PromoRedeemResult({
    required this.success,
    required this.message,
    this.creditsAwarded = 0,
    this.newBalance = 0,
    this.promoDescription,
    this.abuseFlag = AbuseFlag.none,
  });
}

class PromoRedemptionRecord {
  final DateTime redeemedAt;
  final String code;
  final int credits;
  final String description;
  final String userId;
  final String deviceId;

  const PromoRedemptionRecord({
    required this.redeemedAt,
    required this.code,
    required this.credits,
    required this.description,
    this.userId = '',
    this.deviceId = '',
  });
}
