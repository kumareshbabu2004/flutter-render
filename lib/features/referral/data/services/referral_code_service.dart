import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';
import 'package:flutter/foundation.dart';

/// Generates, persists, and manages unique referral codes.
///
/// Every user gets ONE permanent code. The code embeds a deep-link
/// to the in-app referral landing page which includes how-to videos,
/// BMB+ membership promos, and free-registration option — all viewable
/// without creating an account first.
class ReferralCodeService {
  ReferralCodeService._();
  static final ReferralCodeService instance = ReferralCodeService._();

  static const _prefsCodeKey = 'bmb_referral_code';
  static const _prefsHistoryKey = 'bmb_referral_history';
  static const _prefsStatsKey = 'bmb_referral_stats';

  /// The base URL for the BMB referral landing page.
  /// When the new user taps this link it opens the app (or web) to a
  /// public page with how-to videos, BMB+ promos, and signup — no auth
  /// required to view.
  static const String baseLandingUrl = 'https://backmybracket.com/invite';

  /// In-app route for the public referral landing page.
  static const String landingRoute = '/invite';

  String? _cachedCode;
  final _firestore = RestFirestoreService.instance;

  // ─── CODE GENERATION ────────────────────────────────────────────

  /// Get the user's unique referral code. Generates one if none exists.
  Future<String> getOrCreateCode() async {
    if (_cachedCode != null) return _cachedCode!;

    final prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString(_prefsCodeKey);

    if (code == null || code.isEmpty) {
      code = _generateUniqueCode();
      await prefs.setString(_prefsCodeKey, code);
    }

    _cachedCode = code;
    return code;
  }

  /// Build the full referral link that points to the landing page with
  /// the user's code embedded as a query parameter.
  ///
  /// Example: https://backmybracket.com/invite?ref=BMB-K7X9M2&section=videos
  ///
  /// The `section=videos` parameter deep-links the viewer directly to the
  /// how-to videos section so they immediately see what BMB is about.
  Future<String> getReferralLink({bool deepLinkToVideos = true}) async {
    final code = await getOrCreateCode();
    final buffer = StringBuffer('$baseLandingUrl?ref=$code');
    if (deepLinkToVideos) {
      buffer.write('&section=videos');
    }
    return buffer.toString();
  }

  /// Build the in-app route URL that the Flutter router can handle.
  /// Example: /invite?ref=BMB-K7X9M2&section=videos
  Future<String> getInAppRoute() async {
    final code = await getOrCreateCode();
    return '$landingRoute?ref=$code&section=videos';
  }

  /// Build a share message that includes the referral link.
  Future<String> buildShareMessage() async {
    final code = await getOrCreateCode();
    final link = await getReferralLink();
    final user = CurrentUserService.instance;
    final name = user.displayName.isNotEmpty ? user.displayName : 'A friend';

    return "$name invited you to Back My Bracket!\n\n"
        "Watch how it works, check out BMB+ perks, "
        "and sign up FREE — all from this link:\n\n"
        "$link\n\n"
        "Or enter code: $code when you sign up.\n\n"
        "Create brackets, compete with friends, and win. Let's go!";
  }

  /// Build a shorter social-optimized share message.
  Future<String> buildSocialMessage() async {
    final code = await getOrCreateCode();
    final link = await getReferralLink();

    return "I'm on Back My Bracket and it's fire! "
        "Watch how it works & sign up FREE: $link "
        "Use code $code for bonus credits. "
        "#BackMyBracket #BMB";
  }

  // ─── CODE FORMAT ─────────────────────────────────────────────────

  /// Generate a unique 6-char alphanumeric code with BMB- prefix.
  /// Format: BMB-XXXXXX (e.g., BMB-K7X9M2)
  String _generateUniqueCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 confusion
    final rng = Random.secure();
    final buffer = StringBuffer('BMB-');
    for (var i = 0; i < 6; i++) {
      buffer.write(chars[rng.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  // ─── REFERRAL TRACKING ──────────────────────────────────────────

  /// Record a new referral (when someone signs up with this user's code).
  Future<void> recordReferral({
    required String friendName,
    required String friendEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsHistoryKey);
    final List<Map<String, dynamic>> history = raw != null
        ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>()
        : [];

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final code = await getOrCreateCode();
    final userId = CurrentUserService.instance.userId;

    history.insert(0, {
      'name': friendName,
      'email': friendEmail,
      'status': 'pending',
      'earned': '--',
      'date': _formatDate(DateTime.now()),
      'timestamp': timestamp,
    });

    await prefs.setString(_prefsHistoryKey, jsonEncode(history));
    await _updateStats();

    // Persist to Firestore
    try {
      await _firestore.addDocument('referrals', {
        'referrerId': userId,
        'referralCode': code,
        'friendName': friendName,
        'friendEmail': friendEmail,
        'status': 'pending',
        'creditsEarned': 0,
        'timestamp': timestamp,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Referral: Firestore write error: $e');
    }
  }

  /// Mark a referral as active (friend completed onboarding).
  Future<void> activateReferral(String friendEmail) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsHistoryKey);
    if (raw == null) return;

    final List<Map<String, dynamic>> history =
        (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    for (final entry in history) {
      if (entry['email'] == friendEmail && entry['status'] == 'pending') {
        entry['status'] = 'active';
        entry['earned'] = '10 credits';
        break;
      }
    }

    await prefs.setString(_prefsHistoryKey, jsonEncode(history));
    await _updateStats();

    // Update in Firestore
    try {
      final docs = await _firestore.query(
        'referrals',
        whereField: 'friendEmail',
        whereValue: friendEmail,
      );
      for (final d in docs) {
        final docId = d['doc_id'] as String? ?? '';
        if (d['status'] == 'pending' && docId.isNotEmpty) {
          await _firestore.updateDocument('referrals', docId, {
            'status': 'active',
            'creditsEarned': 10,
            'activatedAt': DateTime.now().toUtc().toIso8601String(),
          });
          break;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Referral: Firestore activate error: $e');
    }
  }

  /// Get referral history list.
  Future<List<Map<String, dynamic>>> getReferralHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsHistoryKey);
    if (raw == null) return _demoHistory;

    final List<Map<String, dynamic>> history =
        (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return history.isEmpty ? _demoHistory : history;
  }

  /// Get referral stats (total earned, active count, pending count).
  Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsStatsKey);
    if (raw != null) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return {'totalCredits': 20, 'active': 2, 'pending': 1};
  }

  Future<void> _updateStats() async {
    final history = await getReferralHistory();
    int active = 0;
    int pending = 0;
    for (final entry in history) {
      if (entry['status'] == 'active') active++;
      if (entry['status'] == 'pending') pending++;
    }
    final stats = {
      'totalCredits': active * 10,
      'active': active,
      'pending': pending,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsStatsKey, jsonEncode(stats));
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  /// Demo history for first-time users.
  static const List<Map<String, dynamic>> _demoHistory = [
    {'name': 'Mike T.', 'status': 'active', 'earned': '10 credits', 'date': 'Jan 15'},
    {'name': 'Sarah L.', 'status': 'active', 'earned': '10 credits', 'date': 'Feb 3'},
    {'name': 'Jake P.', 'status': 'pending', 'earned': '--', 'date': 'Mar 8'},
  ];

  /// Extract a referral code from a URL (for when someone opens a referral link).
  static String? extractCodeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['ref'];
    } catch (_) {
      return null;
    }
  }

  /// Check if a URL has `section=videos` deep-link parameter.
  static bool hasVideoDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['section'] == 'videos';
    } catch (_) {
      return false;
    }
  }
}
