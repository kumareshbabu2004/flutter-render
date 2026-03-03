import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages branded deep-link generation, URL handling, and pending-join tracking.
///
/// Share URL format: https://backmybracket.com/join/{bracketId}
///
/// URL Strategy (Web):
///   The app uses Flutter's path URL strategy for clean URLs.
///   Routes are defined in MaterialApp.router and handled by GoRouter or
///   Navigator 2.0. When the user opens a deep link:
///
///   1. Web: URL is parsed from the browser address bar.
///   2. Android: Intent filter catches backmybracket.com/join/* URLs.
///   3. The route handler extracts bracketId and navigates accordingly.
///
/// Flow for existing users:
///   1. Tap link → app opens → /join/{bracketId} route
///   2. Fetch bracket from Firestore → show join screen
///   3. User joins → navigates to picks
///
/// Flow for NEW users:
///   1. Tap link → app opens → /join/{bracketId} route
///   2. Not logged in → redirect to auth with pendingBracketId
///   3. User signs up → auto-join bracket → navigate to picks
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const String baseLinkUrl = 'https://backmybracket.com/join';

  // ─── PENDING BRACKET (survives signup flow) ───────────────────────
  String? _pendingBracketId;
  String? get pendingBracketId => _pendingBracketId;

  /// Store a bracket ID that should be auto-joined after login/signup.
  Future<void> setPendingBracket(String bracketId) async {
    _pendingBracketId = bracketId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_bracket_id', bracketId);
    if (kDebugMode) debugPrint('DeepLink: Stored pending bracket $bracketId');
  }

  /// Retrieve and clear the pending bracket ID.
  Future<String?> consumePendingBracket() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _pendingBracketId ?? prefs.getString('pending_bracket_id');
    _pendingBracketId = null;
    await prefs.remove('pending_bracket_id');
    if (kDebugMode && id != null) {
      debugPrint('DeepLink: Consumed pending bracket $id');
    }
    return id;
  }

  /// Check if there's a pending bracket waiting.
  Future<bool> hasPendingBracket() async {
    if (_pendingBracketId != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('pending_bracket_id');
  }

  // ─── BRANDED SHARE LINK GENERATION ────────────────────────────────

  /// Generate a branded share link for a bracket.
  String generateShareLink(String bracketId) {
    return '$baseLinkUrl/$bracketId';
  }

  /// Generate the branded SMS share message.
  /// This text appears in iMessage / SMS alongside the rich link preview.
  String generateShareMessage({
    required String bracketName,
    required String bracketId,
    required String hostName,
    String? bracketType,
    bool isFreeEntry = true,
    int entryFee = 0,
    String? prize,
  }) {
    final link = generateShareLink(bracketId);
    final typeLabel = _typeLabel(bracketType ?? 'standard');
    final entryLabel = isFreeEntry ? 'FREE' : '$entryFee credits';

    return "🏆 $hostName invited you to join \"$bracketName\" "
        "— a $typeLabel on Back My Bracket! "
        "Entry: $entryLabel. "
        "${prize != null && prize.isNotEmpty && prize != 'none' ? 'Prize: $prize. ' : ''}"
        "Who you got? 👇\n$link";
  }

  /// Generate the share message from a CreatedBracket object.
  String generateShareMessageFromBracket(CreatedBracket bracket) {
    final cu = CurrentUserService.instance;
    return generateShareMessage(
      bracketName: bracket.name,
      bracketId: bracket.id,
      hostName: cu.displayName.isNotEmpty ? cu.displayName : 'A friend',
      bracketType: bracket.bracketType,
      isFreeEntry: bracket.isFreeEntry,
      entryFee: bracket.entryDonation,
      prize: bracket.prizeType == 'none' ? null : bracket.prizeLabel,
    );
  }

  // ─── SHARE METADATA (Firestore) ───────────────────────────────────

  /// Record a share event in Firestore for analytics.
  Future<void> recordShareEvent({
    required String bracketId,
    required String platform,
    String? recipientHint,
  }) async {
    try {
      final cu = CurrentUserService.instance;
      await RestFirestoreService.instance.addDocument('share_events', {
        'bracket_id': bracketId,
        'sharer_id': cu.userId,
        'sharer_name': cu.displayName,
        'platform': platform,
        'recipient_hint': recipientHint ?? '',
        'shared_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('DeepLink: recordShareEvent error: $e');
    }
  }

  /// Fetch bracket data for the join screen.
  Future<Map<String, dynamic>?> fetchBracketForJoin(String bracketId) async {
    try {
      // Try direct document fetch first
      var data = await RestFirestoreService.instance
          .getDocument('brackets', bracketId);
      if (data != null) return data;

      // If ID has fs_ prefix (board service injected), strip it
      if (bracketId.startsWith('fs_')) {
        data = await RestFirestoreService.instance
            .getDocument('brackets', bracketId.substring(3));
        if (data != null) return data;
      }

      // Try querying by bracket_id field
      final results = await RestFirestoreService.instance.query(
        'brackets',
        whereField: 'bracket_id',
        whereValue: bracketId,
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      if (kDebugMode) debugPrint('DeepLink: fetchBracketForJoin error: $e');
      return null;
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────

  String _typeLabel(String bracketType) {
    switch (bracketType) {
      case 'voting':
        return 'voting bracket';
      case 'pickem':
        return "pick'em";
      case 'nopicks':
        return 'bracket';
      default:
        return 'tournament bracket';
    }
  }

  /// Parse a bracket ID from a URL path like /join/abc123.
  static String? parseBracketIdFromPath(String path) {
    final joinPrefix = '/join/';
    if (path.startsWith(joinPrefix) && path.length > joinPrefix.length) {
      return path.substring(joinPrefix.length).split('?').first;
    }
    return null;
  }

  /// Handle an incoming URL (from web address bar or Android intent).
  /// Returns the extracted bracket ID if the URL is a join link.
  /// Sets pending bracket for post-login auto-join if user is not logged in.
  Future<String?> handleIncomingUrl(String url) async {
    try {
      final uri = Uri.parse(url);

      // Check for /join/{bracketId} pattern
      final bracketId = parseBracketIdFromPath(uri.path);
      if (bracketId != null && bracketId.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('DeepLink: Incoming join link for bracket $bracketId');
        }
        await setPendingBracket(bracketId);
        return bracketId;
      }

      // Check for /invite?ref=CODE pattern (referral link)
      if (uri.path.startsWith('/invite') && uri.queryParameters.containsKey('ref')) {
        final refCode = uri.queryParameters['ref'];
        if (refCode != null && refCode.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pending_referral_code', refCode);
          if (kDebugMode) {
            debugPrint('DeepLink: Incoming referral code $refCode');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DeepLink: handleIncomingUrl error: $e');
    }
    return null;
  }

  /// Initialize web URL listener.
  /// On web, reads the initial URL from the browser address bar.
  /// On mobile, would register an intent filter listener.
  Future<void> initUrlListener() async {
    if (kIsWeb) {
      // On web, the initial URL is handled by the Flutter router.
      // This method is called at app startup to process any pending deep link.
      // The actual URL is obtained via Uri.base in main.dart.
      if (kDebugMode) {
        debugPrint('DeepLink: Web URL listener initialized');
      }
    }
    // On Android: would use uni_links or app_links package
    // final initialLink = await getInitialLink();
    // if (initialLink != null) handleIncomingUrl(initialLink);
    // linkStream.listen(handleIncomingUrl);
  }
}
