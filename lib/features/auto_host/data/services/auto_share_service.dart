import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';

/// Generates share messages and handles auto-share + share queue for brackets.
class AutoShareService {
  AutoShareService._();
  static final AutoShareService instance = AutoShareService._();

  static const String _baseLinkUrl = 'https://backmybracket.com/join';

  // ═══════════════════════════════════════════════════════════════════
  // SHARE MESSAGE GENERATION
  // ═══════════════════════════════════════════════════════════════════

  /// Generate a share message for a bracket.
  String generateShareMessage({
    required String bracketName,
    required String bracketId,
    required String bracketType,
    required String hostName,
    bool isFreeEntry = true,
    int entryFee = 0,
    String? prize,
    int? teamCount,
  }) {
    final link = '$_baseLinkUrl/$bracketId';
    final typeLabel = _typeLabel(bracketType);
    final entryLabel = isFreeEntry ? 'FREE to join' : '$entryFee credits to enter';
    final prizeLabel = prize != null && prize.isNotEmpty && prize != 'none'
        ? 'Prize: $prize'
        : 'Bragging rights on the line';

    return "$hostName just created a $typeLabel: \"$bracketName\"! "
        "${teamCount != null ? '$teamCount contestants. ' : ''}"
        "It's $entryLabel. $prizeLabel. "
        "Think you can win? Join now: $link "
        "#BackMyBracket #BMB";
  }

  /// Generate a shorter message for SMS.
  String generateSmsMessage({
    required String bracketName,
    required String bracketId,
    required String hostName,
  }) {
    final link = '$_baseLinkUrl/$bracketId';
    return "$hostName invited you to \"$bracketName\" on Back My Bracket! Join: $link";
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARE ACTIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Share to clipboard.
  Future<void> copyLink(String bracketId, BuildContext context) async {
    final link = '$_baseLinkUrl/$bracketId';
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Link copied to clipboard!'),
          backgroundColor: const Color(0xFF1a1f3d),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Share via SMS.
  Future<void> shareViaSms({
    required String bracketName,
    required String bracketId,
    required String hostName,
    required BuildContext context,
  }) async {
    final body = Uri.encodeComponent(
        generateSmsMessage(bracketName: bracketName, bracketId: bracketId, hostName: hostName));
    final uri = Uri.parse('sms:?body=$body');
    await _launch(uri, context);
  }

  /// Share via Twitter/X.
  Future<void> shareViaTwitter({
    required String message,
    required BuildContext context,
  }) async {
    final text = Uri.encodeComponent(message);
    final uri = Uri.parse('https://twitter.com/intent/tweet?text=$text');
    await _launch(uri, context);
  }

  /// Share via Facebook.
  Future<void> shareViaFacebook({
    required String bracketId,
    required BuildContext context,
  }) async {
    final link = Uri.encodeComponent('$_baseLinkUrl/$bracketId');
    final uri = Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$link');
    await _launch(uri, context);
  }

  /// Share via Instagram (open app — IG doesn't support prefilled text).
  Future<void> shareViaInstagram(BuildContext context) async {
    final uri = Uri.parse('https://www.instagram.com/');
    await _launch(uri, context);
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARE QUEUE (Firestore-backed)
  // ═══════════════════════════════════════════════════════════════════

  /// Queue a share for a bracket. If auto-share is on, the bracket
  /// will be auto-shared when it moves to "upcoming" status.
  Future<void> queueShare({
    required String bracketId,
    required String hostId,
    required String message,
    List<String> platforms = const ['in_app', 'sms'],
  }) async {
    try {
      await RestFirestoreService.instance.addDocument('share_queue', {
        'bracket_id': bracketId,
        'host_id': hostId,
        'message': message,
        'platforms': platforms,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('AutoShare: queueShare error: $e');
    }
  }

  /// Process pending shares for a bracket (called when status → upcoming).
  Future<void> processPendingShares(String bracketId) async {
    try {
      final results = await RestFirestoreService.instance.query(
          'share_queue', whereField: 'bracket_id', whereValue: bracketId);
      final pending = results.where((r) => r['status'] == 'pending').toList();

      for (final doc in pending) {
        final docId = doc['doc_id'] as String? ?? '';
        if (docId.isNotEmpty) {
          await RestFirestoreService.instance.updateDocument('share_queue', docId, {
            'status': 'sent',
            'sent_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }

      await FirestoreService.instance.logEvent({
        'event_type': 'auto_share_processed',
        'bracket_id': bracketId,
        'shares_sent': pending.length,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('AutoShare: processPendingShares error: $e');
    }
  }

  /// Get share queue for a host.
  Future<List<Map<String, dynamic>>> getHostShareQueue(String hostId) async {
    try {
      final results = await RestFirestoreService.instance.query(
          'share_queue', whereField: 'host_id', whereValue: hostId);
      results.sort((a, b) {
        final aTime = a['created_at']?.toString() ?? '';
        final bTime = b['created_at']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });
      return results;
    } catch (e) {
      if (kDebugMode) debugPrint('AutoShare: getHostShareQueue error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  String _typeLabel(String bracketType) {
    switch (bracketType) {
      case 'voting': return 'voting bracket';
      case 'pickem': return "pick'em bracket";
      case 'nopicks': return 'bracket (no picks)';
      default: return 'tournament bracket';
    }
  }

  Future<void> _launch(Uri uri, BuildContext context) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
