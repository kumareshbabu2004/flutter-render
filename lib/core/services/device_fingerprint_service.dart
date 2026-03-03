import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Generates and persists a device fingerprint that survives app reinstalls
/// where possible. Uses multiple signals to create a stable device identity.
///
/// Anti-abuse layers:
///   1. Persistent device ID stored in SharedPreferences
///   2. Installation timestamp (detects fresh installs / data clears)
///   3. Hardware signal hash (platform + locale + screen density)
///   4. Redemption-specific device lock keys stored separately
class DeviceFingerprintService {
  DeviceFingerprintService._();
  static final DeviceFingerprintService instance = DeviceFingerprintService._();

  static const _keyDeviceId = 'bmb_device_fingerprint_id';
  static const _keyInstallTimestamp = 'bmb_device_install_ts';
  static const _keyDeviceRedemptions = 'bmb_device_promo_redemptions';
  static const _keyRedemptionAttempts = 'bmb_promo_attempt_log';
  static const _keyHardwareHash = 'bmb_hardware_signal_hash';
  static const _keyLastSuccessfulRedeem = 'bmb_last_successful_redeem';
  static const _keyDailyRedeemCount = 'bmb_daily_redeem_count';
  static const _keyDailyRedeemDate = 'bmb_daily_redeem_date';

  String? _cachedDeviceId;
  DateTime? _installTimestamp;

  // ═══════════════════════════════════════════════════════════════════
  // DEVICE ID — persistent across sessions, regenerated on data clear
  // ═══════════════════════════════════════════════════════════════════

  /// Returns the stable device fingerprint ID.
  /// If none exists, generates one and persists it.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_keyDeviceId);

    if (deviceId == null || deviceId.isEmpty) {
      // Generate a new device fingerprint
      deviceId = _generateDeviceId();
      await prefs.setString(_keyDeviceId, deviceId);

      // Record the installation timestamp (first time this device ID was created)
      final now = DateTime.now().toIso8601String();
      await prefs.setString(_keyInstallTimestamp, now);
      _installTimestamp = DateTime.now();

      // Store a hardware signal hash for cross-reference
      final hwHash = _generateHardwareHash();
      await prefs.setString(_keyHardwareHash, hwHash);

      if (kDebugMode) {
        debugPrint('[DeviceFingerprint] New device ID generated: $deviceId');
      }
    } else {
      final tsStr = prefs.getString(_keyInstallTimestamp);
      if (tsStr != null) {
        _installTimestamp = DateTime.tryParse(tsStr);
      }
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Returns the installation timestamp (when this device ID was first created).
  /// Useful for detecting fresh installs that try to exploit welcome codes.
  Future<DateTime> getInstallTimestamp() async {
    if (_installTimestamp != null) return _installTimestamp!;
    await getDeviceId(); // Ensures _installTimestamp is loaded
    return _installTimestamp ?? DateTime.now();
  }

  /// Check if this appears to be a freshly wiped / reinstalled app
  /// by looking at whether the install timestamp is suspiciously recent
  /// while the device has a history of redemptions.
  Future<bool> isSuspiciousFreshInstall() async {
    final prefs = await SharedPreferences.getInstance();
    final installTs = await getInstallTimestamp();
    final age = DateTime.now().difference(installTs);

    // If the install is < 5 minutes old AND there are prior redemption
    // artifacts in secure storage, this is suspicious.
    // In production: cross-check with server-side device registry.
    if (age.inMinutes < 5) {
      // Check if hardware hash was seen before (stored server-side in prod)
      final hwHash = prefs.getString(_keyHardwareHash) ?? '';
      final knownHashes = prefs.getStringList('bmb_known_hw_hashes') ?? [];
      if (knownHashes.contains(hwHash)) {
        return true; // Same hardware, fresh install = suspicious
      }
      // Store this hash for future detection
      knownHashes.add(hwHash);
      await prefs.setStringList('bmb_known_hw_hashes', knownHashes);
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════
  // DEVICE-LEVEL REDEMPTION TRACKING
  // Separate from user-level tracking — prevents multi-account abuse
  // ═══════════════════════════════════════════════════════════════════

  /// Check if a promo code has been redeemed on THIS device (any account).
  Future<bool> isCodeRedeemedOnDevice(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceRedemptions =
        prefs.getStringList(_keyDeviceRedemptions) ?? [];
    return deviceRedemptions.contains(code.trim().toUpperCase());
  }

  /// Mark a promo code as redeemed on THIS device.
  Future<void> markCodeRedeemedOnDevice(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceRedemptions =
        prefs.getStringList(_keyDeviceRedemptions) ?? [];
    final normalized = code.trim().toUpperCase();
    if (!deviceRedemptions.contains(normalized)) {
      deviceRedemptions.add(normalized);
      await prefs.setStringList(_keyDeviceRedemptions, deviceRedemptions);
    }
  }

  /// Get all codes redeemed on this device (any account).
  Future<List<String>> getDeviceRedemptions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyDeviceRedemptions) ?? [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // RATE LIMITING — prevents brute-force code guessing
  // ═══════════════════════════════════════════════════════════════════

  /// Record a redemption attempt (success or failure).
  Future<void> recordAttempt({required bool success}) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getStringList(_keyRedemptionAttempts) ?? [];
    final entry =
        '${DateTime.now().toIso8601String()}|${success ? "ok" : "fail"}';
    attempts.insert(0, entry);
    // Keep last 50 attempts max
    if (attempts.length > 50) {
      attempts.removeRange(50, attempts.length);
    }
    await prefs.setStringList(_keyRedemptionAttempts, attempts);
  }

  /// Returns true if the user has exceeded the rate limit.
  /// Rules:
  ///   - Max 3 failed attempts per hour
  ///   - Max 5 total attempts (success + fail) per hour
  ///   - After 10 consecutive failures, 24-hour lockout
  Future<RateLimitResult> checkRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getStringList(_keyRedemptionAttempts) ?? [];
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final oneDayAgo = now.subtract(const Duration(hours: 24));

    // Parse recent attempts
    int failsLastHour = 0;
    int totalLastHour = 0;
    int consecutiveFails = 0;
    bool countingConsecutive = true;

    for (final entry in attempts) {
      final parts = entry.split('|');
      if (parts.length < 2) continue;
      final ts = DateTime.tryParse(parts[0]);
      final isSuccess = parts[1] == 'ok';

      if (ts == null) continue;

      // Count consecutive failures from most recent
      if (countingConsecutive) {
        if (!isSuccess) {
          consecutiveFails++;
        } else {
          countingConsecutive = false;
        }
      }

      // Count hourly stats
      if (ts.isAfter(oneHourAgo)) {
        totalLastHour++;
        if (!isSuccess) failsLastHour++;
      }
    }

    // 24-hour lockout after 10 consecutive failures
    if (consecutiveFails >= 10) {
      // Check if the most recent attempt was within 24 hours
      if (attempts.isNotEmpty) {
        final lastTs = DateTime.tryParse(attempts.first.split('|').first);
        if (lastTs != null && lastTs.isAfter(oneDayAgo)) {
          final unlockTime = lastTs.add(const Duration(hours: 24));
          final remaining = unlockTime.difference(now);
          return RateLimitResult(
            blocked: true,
            reason:
                'Too many failed attempts. Try again in ${remaining.inHours}h ${remaining.inMinutes % 60}m.',
          );
        }
      }
    }

    // Max 3 failed attempts per hour
    if (failsLastHour >= 3) {
      return const RateLimitResult(
        blocked: true,
        reason:
            'Too many invalid codes. Please wait an hour before trying again.',
      );
    }

    // Max 5 total attempts per hour
    if (totalLastHour >= 5) {
      return const RateLimitResult(
        blocked: true,
        reason: 'Redemption limit reached. Please try again later.',
      );
    }

    return const RateLimitResult(blocked: false);
  }

  /// Check cooldown between successful redemptions.
  /// Prevents rapid-fire code entry (e.g. from a shared list).
  /// Minimum 30 seconds between successful redemptions.
  Future<RateLimitResult> checkRedeemCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSuccessStr = prefs.getString(_keyLastSuccessfulRedeem);
    if (lastSuccessStr != null) {
      final lastSuccess = DateTime.tryParse(lastSuccessStr);
      if (lastSuccess != null) {
        final elapsed = DateTime.now().difference(lastSuccess);
        if (elapsed.inSeconds < 30) {
          final remaining = 30 - elapsed.inSeconds;
          return RateLimitResult(
            blocked: true,
            reason: 'Please wait $remaining seconds before redeeming another code.',
          );
        }
      }
    }
    return const RateLimitResult(blocked: false);
  }

  /// Record a successful redemption timestamp for cooldown tracking.
  Future<void> recordSuccessfulRedeem() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyLastSuccessfulRedeem,
      DateTime.now().toIso8601String(),
    );

    // Track daily redemption count (max 5 per day across all codes)
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(_keyDailyRedeemDate) ?? '';
    if (storedDate == today) {
      final count = prefs.getInt(_keyDailyRedeemCount) ?? 0;
      await prefs.setInt(_keyDailyRedeemCount, count + 1);
    } else {
      await prefs.setString(_keyDailyRedeemDate, today);
      await prefs.setInt(_keyDailyRedeemCount, 1);
    }
  }

  /// Check if the daily redemption limit has been reached.
  /// Max 5 successful redemptions per calendar day.
  Future<RateLimitResult> checkDailyRedeemLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(_keyDailyRedeemDate) ?? '';
    if (storedDate == today) {
      final count = prefs.getInt(_keyDailyRedeemCount) ?? 0;
      if (count >= 5) {
        return const RateLimitResult(
          blocked: true,
          reason: 'Daily redemption limit reached (5 per day). Try again tomorrow.',
        );
      }
    }
    return const RateLimitResult(blocked: false);
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Generates a unique device fingerprint using randomness + timestamp.
  /// Uses cryptographically secure random bytes for uniqueness.
  String _generateDeviceId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final b64 = base64Url.encode(randomBytes).replaceAll('=', '');
    return 'bmb_${timestamp.toRadixString(36)}_$b64';
  }

  /// Creates a hash of observable hardware signals.
  /// Combines multiple signals for better same-device detection.
  String _generateHardwareHash() {
    final signals = [
      defaultTargetPlatform.toString(),
      DateTime.now().timeZoneName,
      DateTime.now().timeZoneOffset.inHours.toString(),
      // In production, add: screen size, locale, device model, etc.
    ];
    // Use a more robust hash combining all signals
    int hash = 0;
    for (final s in signals) {
      for (int i = 0; i < s.length; i++) {
        hash = (hash * 31 + s.codeUnitAt(i)) & 0x7FFFFFFF;
      }
    }
    return hash.toRadixString(36);
  }

  // ═══════════════════════════════════════════════════════════════════
  // WELCOME CODE PER-DEVICE LIMIT — max 2 welcome-code redemptions
  // per device regardless of how many accounts are created.
  // ═══════════════════════════════════════════════════════════════════
  static const _keyWelcomeRedeemCount = 'bmb_device_welcome_redeem_count';

  /// How many welcome-type promo codes have been redeemed on this device.
  Future<int> getWelcomeCodeRedeemCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWelcomeRedeemCount) ?? 0;
  }

  /// Increment the per-device welcome code redemption counter.
  Future<void> incrementWelcomeCodeRedeemCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyWelcomeRedeemCount) ?? 0;
    await prefs.setInt(_keyWelcomeRedeemCount, current + 1);
    if (kDebugMode) {
      debugPrint(
          '[DeviceFingerprint] Welcome code redeemed on device. '
          'Total welcome redeems: ${current + 1}/2');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MULTI-ACCOUNT DETECTION — flags when same device creates many accounts
  // ═══════════════════════════════════════════════════════════════════
  static const _keyAccountsOnDevice = 'bmb_device_accounts';

  /// Record that an account logged in on this device.
  /// Returns the number of distinct accounts that have used this device.
  Future<int> recordAccountLogin(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList(_keyAccountsOnDevice) ?? [];
    if (!accounts.contains(userId)) {
      accounts.add(userId);
      await prefs.setStringList(_keyAccountsOnDevice, accounts);
    }
    return accounts.length;
  }

  /// Check if this device has an abnormal number of accounts.
  /// More than 3 accounts on one device is suspicious.
  Future<bool> hasExcessiveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList(_keyAccountsOnDevice) ?? [];
    return accounts.length > 3;
  }

  /// Get count of accounts that have used this device.
  Future<int> getAccountCount() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = prefs.getStringList(_keyAccountsOnDevice) ?? [];
    return accounts.length;
  }
}

/// Result of a rate limit check.
class RateLimitResult {
  final bool blocked;
  final String? reason;
  const RateLimitResult({required this.blocked, this.reason});
}
