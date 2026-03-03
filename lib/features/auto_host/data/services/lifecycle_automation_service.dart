import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';
import 'package:bmb_mobile/features/auto_host/data/services/auto_share_service.dart';

/// Handles bracket lifecycle automation:
///   - Early join reservations (upcoming phase)
///   - Go-live credit checks & auto-replenish
///   - Status transitions (saved -> upcoming -> live -> done)
///   - Winner payout
class LifecycleAutomationService {
  LifecycleAutomationService._();
  static final LifecycleAutomationService instance = LifecycleAutomationService._();

  final _rest = RestFirestoreService.instance;
  final _fs = FirestoreService.instance;
  final _share = AutoShareService.instance;

  // ═══════════════════════════════════════════════════════════════════
  // EARLY JOIN (UPCOMING PHASE)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> reserveSpot({
    required String bracketId,
    required String userId,
    required String userName,
  }) async {
    try {
      final existing = await _rest.query(
          'bracket_reservations', whereField: 'bracket_id', whereValue: bracketId);
      if (existing.any((r) => r['user_id'] == userId)) return;

      await _rest.addDocument('bracket_reservations', {
        'bracket_id': bracketId,
        'user_id': userId,
        'user_name': userName,
        'reserved_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'reserved',
        'credits_deducted': false,
      });

      // Increment entrants_count
      final bracket = await _rest.getDocument('brackets', bracketId);
      if (bracket != null) {
        final count = (bracket['entrants_count'] as num?)?.toInt() ?? 0;
        await _rest.updateDocument('brackets', bracketId, {'entrants_count': count + 1});
      }

      await _fs.logEvent({
        'event_type': 'early_join_reservation',
        'bracket_id': bracketId,
        'user_id': userId,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Lifecycle: reserveSpot error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getReservations(String bracketId) async {
    try {
      return await _rest.query(
          'bracket_reservations', whereField: 'bracket_id', whereValue: bracketId);
    } catch (e) {
      if (kDebugMode) debugPrint('Lifecycle: getReservations error: $e');
      return [];
    }
  }

  Future<void> cancelReservation({
    required String bracketId,
    required String userId,
  }) async {
    try {
      final results = await _rest.query(
          'bracket_reservations', whereField: 'bracket_id', whereValue: bracketId);
      final match = results.where((r) => r['user_id'] == userId);
      for (final doc in match) {
        final docId = doc['doc_id'] as String? ?? '';
        if (docId.isNotEmpty) {
          await _rest.updateDocument('bracket_reservations', docId, {'status': 'removed'});
        }
      }

      final bracket = await _rest.getDocument('brackets', bracketId);
      if (bracket != null) {
        final count = (bracket['entrants_count'] as num?)?.toInt() ?? 0;
        await _rest.updateDocument('brackets', bracketId, {'entrants_count': (count - 1).clamp(0, 999999)});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Lifecycle: cancelReservation error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HOST APPROVAL (saved -> upcoming)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> approveBracket(String bracketId) async {
    try {
      await _rest.updateDocument('brackets', bracketId, {
        'status': 'upcoming',
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      });

      final data = await _rest.getDocument('brackets', bracketId);
      if (data != null && (data['auto_share'] as bool? ?? false)) {
        final hostName = data['host_display_name'] as String? ?? 'A host';
        final message = _share.generateShareMessage(
          bracketName: data['name'] as String? ?? '',
          bracketId: bracketId,
          bracketType: data['bracket_type'] as String? ?? 'standard',
          hostName: hostName,
          isFreeEntry: (data['entry_fee'] as num?)?.toInt() == 0,
          entryFee: (data['entry_fee'] as num?)?.toInt() ?? 0,
          prize: data['prize_description'] as String?,
          teamCount: (data['team_count'] as num?)?.toInt(),
        );
        await _share.queueShare(
          bracketId: bracketId,
          hostId: data['host_user_id'] as String? ?? '',
          message: message,
        );
      }

      await _fs.logEvent({
        'event_type': 'bracket_approved',
        'bracket_id': bracketId,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Lifecycle: approveBracket error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // GO-LIVE TRANSITION (upcoming -> live)
  // ═══════════════════════════════════════════════════════════════════

  Future<GoLiveResult> goLive(String bracketId) async {
    try {
      final bracket = await _rest.getDocument('brackets', bracketId);
      if (bracket == null) return GoLiveResult(success: false, message: 'Bracket not found');

      final entryFee = (bracket['entry_fee'] as num?)?.toInt() ?? 0;
      final isFreeBracket = entryFee == 0;

      final reservations = await getReservations(bracketId);
      final activeReservations = reservations.where((r) => r['status'] == 'reserved').toList();

      int confirmed = 0;
      int graceGiven = 0;
      int removed = 0;

      if (!isFreeBracket) {
        for (final reservation in activeReservations) {
          final userId = reservation['user_id'] as String;
          final docId = reservation['doc_id'] as String? ?? '';

          final userData = await _fs.getUser(userId);
          final balance = (userData?['credits_balance'] as num?)?.toInt() ?? 0;

          if (balance >= entryFee) {
            await _fs.incrementUserCredits(userId, -entryFee);
            await _fs.addCreditTransaction({
              'user_id': userId,
              'amount': -entryFee,
              'type': 'entry_fee',
              'bracket_id': bracketId,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            });
            if (docId.isNotEmpty) {
              await _rest.updateDocument('bracket_reservations', docId, {
                'status': 'confirmed', 'credits_deducted': true,
              });
            }
            confirmed++;
          } else {
            if (docId.isNotEmpty) {
              await _rest.updateDocument('bracket_reservations', docId, {
                'status': 'grace_period',
                'grace_deadline': DateTime.now().add(const Duration(minutes: 30)).toUtc().toIso8601String(),
              });
            }
            graceGiven++;
          }
        }
      } else {
        for (final reservation in activeReservations) {
          final docId = reservation['doc_id'] as String? ?? '';
          if (docId.isNotEmpty) {
            await _rest.updateDocument('bracket_reservations', docId, {'status': 'confirmed'});
          }
          confirmed++;
        }
      }

      await _rest.updateDocument('brackets', bracketId, {
        'status': 'live',
        'went_live_at': DateTime.now().toUtc().toIso8601String(),
        'confirmed_players': confirmed,
        'grace_players': graceGiven,
      });

      await _fs.logEvent({
        'event_type': 'bracket_went_live',
        'bracket_id': bracketId,
        'confirmed': confirmed,
        'grace_period': graceGiven,
        'removed': removed,
      });

      return GoLiveResult(
        success: true,
        message: 'Bracket is now LIVE!',
        confirmedPlayers: confirmed,
        gracePlayers: graceGiven,
        removedPlayers: removed,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Lifecycle: goLive error: $e');
      return GoLiveResult(success: false, message: 'Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // WINNER & PAYOUT
  // ═══════════════════════════════════════════════════════════════════

  Future<void> crownWinner({
    required String bracketId,
    required String winnerUserId,
    required String winnerName,
  }) async {
    try {
      final bracket = await _rest.getDocument('brackets', bracketId);
      if (bracket == null) return;

      final entryFee = (bracket['entry_fee'] as num?)?.toInt() ?? 0;
      final entrants = (bracket['entrants_count'] as num?)?.toInt() ?? 0;

      final totalPool = entryFee * entrants;
      final platformFee = (totalPool * 0.10).round();
      final winnerPrize = totalPool - platformFee;

      if (winnerPrize > 0) {
        await _fs.incrementUserCredits(winnerUserId, winnerPrize);
        await _fs.addCreditTransaction({
          'user_id': winnerUserId,
          'amount': winnerPrize,
          'type': 'bracket_winnings',
          'bracket_id': bracketId,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });

        if (platformFee > 0) {
          await _fs.addCreditTransaction({
            'user_id': 'bmb_platform',
            'amount': platformFee,
            'type': 'platform_fee',
            'bracket_id': bracketId,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }

      await _rest.updateDocument('brackets', bracketId, {
        'status': 'done',
        'winner_user_id': winnerUserId,
        'winner_display_name': winnerName,
        'winner_prize_credits': winnerPrize,
        'platform_fee': platformFee,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _fs.logEvent({
        'event_type': 'bracket_completed',
        'bracket_id': bracketId,
        'winner_user_id': winnerUserId,
        'winner_prize': winnerPrize,
        'platform_fee': platformFee,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Lifecycle: crownWinner error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // AUTO-PILOT CHECK
  // ═══════════════════════════════════════════════════════════════════

  Future<void> checkAutoGoLive() async {
    try {
      final results = await _rest.query(
          'brackets', whereField: 'status', whereValue: 'upcoming');

      final now = DateTime.now();
      for (final data in results) {
        if (data['auto_host'] != true) continue;
        final docId = data['doc_id'] as String? ?? '';
        final goLiveDateStr = data['go_live_date']?.toString();
        final minPlayers = (data['min_players'] as num?)?.toInt() ?? 2;
        final entrants = (data['entrants_count'] as num?)?.toInt() ?? 0;

        DateTime? goLiveDate;
        if (goLiveDateStr != null) {
          goLiveDate = DateTime.tryParse(goLiveDateStr);
        }

        if (goLiveDate != null &&
            !goLiveDate.isAfter(now) &&
            entrants >= minPlayers &&
            docId.isNotEmpty) {
          await goLive(docId);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Lifecycle: checkAutoGoLive error: $e');
    }
  }
}

/// Result of a go-live transition.
class GoLiveResult {
  final bool success;
  final String message;
  final int confirmedPlayers;
  final int gracePlayers;
  final int removedPlayers;

  const GoLiveResult({
    required this.success,
    required this.message,
    this.confirmedPlayers = 0,
    this.gracePlayers = 0,
    this.removedPlayers = 0,
  });
}
