import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';
import 'package:bmb_mobile/features/scoring/data/services/official_results_registry.dart';

/// Service that manages the 5-status tournament lifecycle:
///   saved -> upcoming -> live -> in_progress -> done
///
/// Credit deduction happens ONLY at the saved->live transition (or upcoming->live).
/// This is the fail-safe: deleting a "saved" bracket charges no one.
///
/// For TEMPLATE brackets, status transitions are driven by the
/// [OfficialResultsRegistry] — when the registry detects game completions
/// from the live feed, the bracket automatically advances through statuses.
class TournamentStatusService {
  /// Check and update the tournament status based on current conditions.
  /// Returns the updated bracket if status changed, null otherwise.
  static Future<CreatedBracket?> checkAndUpdateStatus(
      CreatedBracket bracket) async {
    switch (bracket.tournamentStatus) {
      case TournamentStatus.saved:
        // saved -> upcoming: host explicitly shares or publishes
        // (manual action -- not auto-triggered)
        return null;

      case TournamentStatus.upcoming:
        // upcoming -> live: auto-host conditions met
        return _checkUpcomingToLive(bracket);

      case TournamentStatus.live:
        // live -> in_progress: first game has started
        return _checkLiveToInProgress(bracket);

      case TournamentStatus.inProgress:
        // in_progress -> done: all games completed
        return _checkInProgressToDone(bracket);

      case TournamentStatus.done:
        return null; // terminal state
    }
  }

  /// Full lifecycle check — runs through ALL possible transitions in one call.
  /// Useful when a live feed sync just finished and multiple transitions
  /// may be needed (e.g. upcoming -> live -> in_progress).
  static Future<CreatedBracket?> checkFullLifecycle(
      CreatedBracket bracket) async {
    CreatedBracket current = bracket;
    CreatedBracket? updated;

    // Keep checking transitions until no more changes happen
    for (int i = 0; i < 4; i++) {
      // max 4 transitions (saved->upcoming->live->in_progress->done)
      updated = await checkAndUpdateStatus(current);
      if (updated == null) break;
      current = updated;
      if (kDebugMode) {
        debugPrint(
            '[TournamentStatus] Auto-transition: ${bracket.status} -> ${current.status}');
      }
    }

    return current.status != bracket.status ? current : null;
  }

  /// Manually advance a bracket from saved -> upcoming (host shares it).
  static CreatedBracket advanceToUpcoming(CreatedBracket bracket) {
    if (bracket.status != 'saved') return bracket;
    return bracket.copyWith(status: 'upcoming');
  }

  /// Manually advance a bracket to live (host chooses "Go Live Now").
  static Future<CreatedBracket> advanceToLive(CreatedBracket bracket) async {
    if (bracket.status != 'upcoming' && bracket.status != 'saved') {
      return bracket;
    }

    // Deduct credits from host and all joined players
    final updated = await _deductCreditsOnLive(bracket);

    // If this is a template bracket, start live polling in the registry
    if (ResultsService.isAutoSynced(bracket)) {
      ResultsService.startLivePolling(bracket);
      if (kDebugMode) {
        debugPrint(
            '[TournamentStatus] Started live polling for template: ${bracket.templateId}');
      }
    }

    return updated.copyWith(status: 'live', creditsDeducted: true);
  }

  /// Called when a live feed sync reports completed games.
  /// Checks whether the bracket should auto-advance through statuses.
  static Future<CreatedBracket?> onLiveFeedUpdate(
      CreatedBracket bracket) async {
    if (!ResultsService.isAutoSynced(bracket)) return null;

    final results = ResultsService.getResults(bracket);

    switch (bracket.tournamentStatus) {
      case TournamentStatus.live:
        // Auto-advance to in_progress when first game completes
        if (results.completedGames > 0) {
          if (kDebugMode) {
            debugPrint(
                '[TournamentStatus] Live feed: ${results.completedGames} games done -> in_progress');
          }
          return bracket.copyWith(status: 'in_progress');
        }
        return null;

      case TournamentStatus.inProgress:
        // Auto-advance to done when tournament is complete
        if (results.isTournamentComplete) {
          if (kDebugMode) {
            debugPrint(
                '[TournamentStatus] Live feed: Tournament complete -> done');
          }
          // Stop polling — no more data needed
          ResultsService.stopLivePolling(bracket);
          return bracket.copyWith(status: 'done', completedAt: DateTime.now());
        }
        return null;

      default:
        return null;
    }
  }

  // ─── PRIVATE TRANSITION CHECKS ──────────────────────────────────

  static Future<CreatedBracket?> _checkUpcomingToLive(
      CreatedBracket bracket) async {
    if (!bracket.autoHost) return null;
    if (bracket.scheduledLiveDate == null) return null;

    final now = DateTime.now();
    final goLiveDate = bracket.scheduledLiveDate!;

    // Check: min players met AND go-live date reached
    if (bracket.participantCount >= bracket.minPlayers &&
        !goLiveDate.isAfter(now)) {
      // Auto-advance to live
      final updated = await _deductCreditsOnLive(bracket);

      // Start live polling for template brackets
      if (ResultsService.isAutoSynced(bracket)) {
        ResultsService.startLivePolling(bracket);
      }

      return updated.copyWith(status: 'live', creditsDeducted: true);
    }

    return null;
  }

  static CreatedBracket? _checkLiveToInProgress(CreatedBracket bracket) {
    final results = ResultsService.getResults(bracket);
    final hasStartedGame = results.games.values.any((g) => g.isCompleted);

    if (hasStartedGame) {
      return bracket.copyWith(status: 'in_progress');
    }
    return null;
  }

  static CreatedBracket? _checkInProgressToDone(CreatedBracket bracket) {
    final results = ResultsService.getResults(bracket);
    if (results.isTournamentComplete) {
      // Stop polling when done
      if (ResultsService.isAutoSynced(bracket)) {
        ResultsService.stopLivePolling(bracket);
      }
      return bracket.copyWith(status: 'done', completedAt: DateTime.now());
    }
    return null;
  }

  // ─── CREDIT DEDUCTION ──────────────────────────────────────────

  /// Deduct contribution credits from host and all joined players when going LIVE.
  /// This is the ONLY point where credits are deducted.
  static Future<CreatedBracket> _deductCreditsOnLive(
      CreatedBracket bracket) async {
    if (bracket.isFreeEntry ||
        bracket.entryDonation <= 0 ||
        bracket.creditsDeducted) {
      return bracket;
    }

    final prefs = await SharedPreferences.getInstance();
    final cost = bracket.entryDonation.toDouble();

    // 1. Deduct from host
    final hostBalance = prefs.getDouble('bmb_bucks_balance') ?? 0;
    double newHostBalance = hostBalance;

    if (hostBalance < cost) {
      final autoReplenish = prefs.getBool('auto_replenish') ?? false;
      if (autoReplenish) {
        final needed = cost - hostBalance;
        final autoAmount = ((needed / 10).ceil() * 10).toDouble();
        newHostBalance = hostBalance + autoAmount;
      }
    }

    newHostBalance = newHostBalance - cost;
    if (newHostBalance < 0) newHostBalance = 0;
    await prefs.setDouble('bmb_bucks_balance', newHostBalance);

    // Check if auto-replenish needed after deduction
    final autoReplenish = prefs.getBool('auto_replenish') ?? false;
    if (autoReplenish && newHostBalance <= 10) {
      newHostBalance += 10;
      await prefs.setDouble('bmb_bucks_balance', newHostBalance);
    }

    // 2. Deduct from each joined player (simulated — server-side in production)
    return bracket.copyWith(creditsDeducted: true);
  }

  // ─── TIE-BREAKER RESOLUTION ──────────────────────────────────

  /// Resolve tie-breaker when tournament is done.
  /// Rule: Players predict total combined points for the championship game.
  /// Closest to actual WITHOUT going over wins.
  static TieBreakerResult resolveTieBreaker({
    required List<JoinedPlayer> players,
    required int actualTotal,
  }) {
    final eligible =
        players.where((p) => p.tieBreakerPrediction != null).toList();
    if (eligible.isEmpty) {
      return TieBreakerResult(
        actualTotal: actualTotal,
        rankings: [],
        hasWinner: false,
      );
    }

    final underOrEqual =
        eligible.where((p) => p.tieBreakerPrediction! <= actualTotal).toList();
    final over =
        eligible.where((p) => p.tieBreakerPrediction! > actualTotal).toList();

    underOrEqual.sort(
        (a, b) => b.tieBreakerPrediction!.compareTo(a.tieBreakerPrediction!));
    over.sort(
        (a, b) => a.tieBreakerPrediction!.compareTo(b.tieBreakerPrediction!));

    final ranked = [...underOrEqual, ...over];
    final rankings = <TieBreakerRanking>[];

    for (int i = 0; i < ranked.length; i++) {
      final player = ranked[i];
      final diff = (player.tieBreakerPrediction! - actualTotal).abs();
      final wentOver = player.tieBreakerPrediction! > actualTotal;

      rankings.add(TieBreakerRanking(
        player: player,
        rank: i + 1,
        prediction: player.tieBreakerPrediction!,
        difference: diff,
        wentOver: wentOver,
      ));
    }

    return TieBreakerResult(
      actualTotal: actualTotal,
      rankings: rankings,
      hasWinner: rankings.isNotEmpty,
    );
  }
}

/// Result of tie-breaker resolution.
class TieBreakerResult {
  final int actualTotal;
  final List<TieBreakerRanking> rankings;
  final bool hasWinner;

  const TieBreakerResult({
    required this.actualTotal,
    required this.rankings,
    required this.hasWinner,
  });

  TieBreakerRanking? get winner =>
      rankings.isNotEmpty ? rankings.first : null;
}

/// Individual tie-breaker ranking entry.
class TieBreakerRanking {
  final JoinedPlayer player;
  final int rank;
  final int prediction;
  final int difference;
  final bool wentOver;

  const TieBreakerRanking({
    required this.player,
    required this.rank,
    required this.prediction,
    required this.difference,
    required this.wentOver,
  });
}
