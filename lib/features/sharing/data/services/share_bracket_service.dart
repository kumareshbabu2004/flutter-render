import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/sharing/data/services/deep_link_service.dart';

/// Handles sharing brackets to SMS, Twitter/X, Instagram, TikTok.
/// Uses url_launcher to open native share intents.
class ShareBracketService {
  ShareBracketService._();

  /// The deep-link base — resolves to the app / web join page.
  static const String _baseLinkUrl = 'https://backmybracket.com/join';

  /// Build a shareable bracket link (branded).
  static String bracketLink(CreatedBracket bracket) {
    return '$_baseLinkUrl/${bracket.id}';
  }

  /// Build the pre-written share text (branded, with emoji CTA).
  static String shareText({
    required CreatedBracket bracket,
    required String userName,
  }) {
    final link = bracketLink(bracket);
    final prize = bracket.prizeType == 'none'
        ? 'bragging rights'
        : bracket.prizeLabel;
    final entry = bracket.isFreeEntry ? 'FREE to join' : '${bracket.entryDonation} credits';
    final type = bracket.bracketTypeLabel;

    return "\u{1F3C6} $userName invited you to \"${bracket.name}\" "
        "\u2014 a $type on Back My Bracket! "
        "Entry: $entry. Prize: $prize. "
        "Who you got? \u{1F447}\n$link";
  }

  // ─── SMS ─────────────────────────────────────────────────────────────

  static Future<void> shareViaSms({
    required CreatedBracket bracket,
    required String userName,
    required BuildContext context,
  }) async {
    final body = Uri.encodeComponent(shareText(userName: userName, bracket: bracket));
    final uri = Uri.parse('sms:?body=$body');
    await _launch(uri, context);
    // Record the share event
    DeepLinkService.instance.recordShareEvent(
      bracketId: bracket.id,
      platform: 'sms',
    );
  }

  // ─── TWITTER / X ─────────────────────────────────────────────────────

  static Future<void> shareViaTwitter({
    required CreatedBracket bracket,
    required String userName,
    required BuildContext context,
  }) async {
    final text = Uri.encodeComponent(shareText(userName: userName, bracket: bracket));
    final uri = Uri.parse('https://twitter.com/intent/tweet?text=$text');
    await _launch(uri, context);
    DeepLinkService.instance.recordShareEvent(
      bracketId: bracket.id,
      platform: 'twitter',
    );
  }

  // ─── INSTAGRAM ───────────────────────────────────────────────────────
  // Instagram doesn't support prefilled text via URL scheme, so we copy text
  // to clipboard and open the Instagram app.

  static Future<void> shareViaInstagram({
    required CreatedBracket bracket,
    required String userName,
    required BuildContext context,
  }) async {
    // Try to open Instagram app; user can paste from clipboard
    final uri = Uri.parse('https://www.instagram.com/');
    await _launch(uri, context);
  }

  // ─── TIKTOK ──────────────────────────────────────────────────────────

  static Future<void> shareViaTikTok({
    required CreatedBracket bracket,
    required String userName,
    required BuildContext context,
  }) async {
    final uri = Uri.parse('https://www.tiktok.com/');
    await _launch(uri, context);
  }

  // ─── COPY LINK ───────────────────────────────────────────────────────

  static String copyLink(CreatedBracket bracket) {
    return bracketLink(bracket);
  }

  // ─── HELPER ──────────────────────────────────────────────────────────

  static Future<void> _launch(Uri uri, BuildContext context) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Could not open app. Link copied to clipboard.'),
            backgroundColor: const Color(0xFF1a1f3d),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open app.'),
          backgroundColor: const Color(0xFF1a1f3d),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
