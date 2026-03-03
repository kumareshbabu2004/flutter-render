import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

/// Central scoring engine that computes leaderboard rankings.
/// Now wired to Firestore for auto-scoring: fetches official results and
/// all participant picks, computes leaderboard, and persists results.
class ScoringEngine {
  /// Point values per round (later rounds worth more).
  /// Round 0 = first round, Round 1 = second round, etc.
  static const List<int> roundPoints = [1, 2, 4, 8, 16, 32, 64];

  /// Get points for a correct pick in a given round.
  static int pointsForRound(int round) {
    if (round < roundPoints.length) return roundPoints[round];
    return roundPoints.last * 2;
  }

  /// Score a single user's picks against official results.
  static ScoredEntry scoreUser({
    required UserPicks userPicks,
    required BracketResults results,
    required int totalRounds,
    required int rank,
    bool isCurrentUser = false,
  }) {
    int correct = 0;
    int incorrect = 0;
    int pending = 0;
    int score = 0;
    int maxPossible = 0;

    for (final entry in userPicks.picks.entries) {
      final gameId = entry.key;
      final userPick = entry.value;
      final result = results.games[gameId];

      if (result == null || !result.isCompleted) {
        // Game not played yet — still possible
        pending++;
        final round = _roundFromGameId(gameId);
        maxPossible += pointsForRound(round);
      } else if (result.winner == userPick) {
        correct++;
        final round = _roundFromGameId(gameId);
        final pts = pointsForRound(round);
        score += pts;
        maxPossible += pts;
      } else {
        incorrect++;
      }
    }

    // Find champion pick (last round pick)
    String? championPick;
    final lastRoundKey = userPicks.picks.keys
        .where((k) => k.startsWith('r${totalRounds - 1}_'))
        .toList();
    if (lastRoundKey.isNotEmpty) {
      championPick = userPicks.picks[lastRoundKey.first];
    }

    return ScoredEntry(
      userId: userPicks.userId,
      userName: userPicks.userName,
      userState: userPicks.userState,
      correctPicks: correct,
      incorrectPicks: incorrect,
      pendingPicks: pending,
      totalPicks: userPicks.picks.length,
      score: score,
      rank: rank,
      maxPossibleScore: score + maxPossible,
      championPick: championPick,
      isCurrentUser: isCurrentUser,
    );
  }

  /// Score all participants and return a sorted leaderboard.
  static List<ScoredEntry> buildLeaderboard({
    required List<UserPicks> allPicks,
    required BracketResults results,
    required int totalRounds,
    String? currentUserId,
  }) {
    // Score everyone
    final scored = allPicks
        .map((up) => scoreUser(
              userPicks: up,
              results: results,
              totalRounds: totalRounds,
              rank: 0,
              isCurrentUser: up.userId == currentUserId,
            ))
        .toList();

    // Sort by score descending, then by correct picks, then by name
    scored.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      final correctCmp = b.correctPicks.compareTo(a.correctPicks);
      if (correctCmp != 0) return correctCmp;
      return a.userName.compareTo(b.userName);
    });

    // Assign ranks (handle ties)
    final ranked = <ScoredEntry>[];
    for (int i = 0; i < scored.length; i++) {
      int rank = i + 1;
      if (i > 0 && scored[i].score == scored[i - 1].score) {
        rank = ranked[i - 1].rank;
      }
      ranked.add(scored[i].copyWith(rank: rank));
    }
    return ranked;
  }

  /// Determine a user's pick status for a specific game.
  static PickStatus getPickStatus(
      String gameId, UserPicks userPicks, BracketResults results) {
    final userPick = userPicks.picks[gameId];
    if (userPick == null) return PickStatus.notPicked;

    final result = results.games[gameId];
    if (result == null || !result.isCompleted) return PickStatus.pending;

    return result.winner == userPick
        ? PickStatus.correct
        : PickStatus.incorrect;
  }

  static int _roundFromGameId(String gameId) {
    // gameId format: "r{round}_g{matchIndex}"
    final parts = gameId.split('_');
    if (parts.isNotEmpty && parts[0].startsWith('r')) {
      return int.tryParse(parts[0].substring(1)) ?? 0;
    }
    return 0;
  }

  static int _matchFromGameId(String gameId) {
    final parts = gameId.split('_');
    if (parts.length > 1 && parts[1].startsWith('g')) {
      return int.tryParse(parts[1].substring(1)) ?? 0;
    }
    return 0;
  }

  // ─── PICK 'EM SCORING ──────────────────────────────────────

  /// Score a Pick 'Em bracket (single round, percentage correct, tie-breaker).
  static PickEmScoredEntry scorePickEm({
    required PickEmUserEntry entry,
    required Map<String, String> officialResults, // gameId -> winner
    required int? actualTieBreakerTotal,
    required int rank,
    bool isCurrentUser = false,
  }) {
    int correct = 0;
    int total = 0;

    for (final pick in entry.picks.entries) {
      final gameId = pick.key;
      final pickedTeam = pick.value;
      final officialWinner = officialResults[gameId];
      if (officialWinner != null) {
        total++;
        if (officialWinner == pickedTeam) correct++;
      }
    }

    final pct = total > 0 ? (correct / total) * 100 : 0.0;
    int? tieDiff;
    if (actualTieBreakerTotal != null && entry.tieBreakerPrediction != null) {
      tieDiff = (entry.tieBreakerPrediction! - actualTieBreakerTotal).abs();
    }

    return PickEmScoredEntry(
      userId: entry.userId,
      userName: entry.userName,
      correctPicks: correct,
      totalPicks: total,
      percentCorrect: pct,
      tieBreakerPrediction: entry.tieBreakerPrediction,
      tieBreakerDiff: tieDiff,
      rank: rank,
      isCurrentUser: isCurrentUser,
    );
  }

  /// Build a Pick 'Em leaderboard ranked by % correct, then tie-break closeness.
  static List<PickEmScoredEntry> buildPickEmLeaderboard({
    required List<PickEmUserEntry> allEntries,
    required Map<String, String> officialResults,
    required int? actualTieBreakerTotal,
    String? currentUserId,
  }) {
    final scored = allEntries.map((e) => scorePickEm(
      entry: e,
      officialResults: officialResults,
      actualTieBreakerTotal: actualTieBreakerTotal,
      rank: 0,
      isCurrentUser: e.userId == currentUserId,
    )).toList();

    scored.sort((a, b) {
      final pctCmp = b.percentCorrect.compareTo(a.percentCorrect);
      if (pctCmp != 0) return pctCmp;
      // Tie-break: closer to actual total wins
      if (a.tieBreakerDiff != null && b.tieBreakerDiff != null) {
        return a.tieBreakerDiff!.compareTo(b.tieBreakerDiff!);
      }
      return a.userName.compareTo(b.userName);
    });

    final ranked = <PickEmScoredEntry>[];
    for (int i = 0; i < scored.length; i++) {
      int rank = i + 1;
      if (i > 0 &&
          scored[i].percentCorrect == scored[i - 1].percentCorrect &&
          scored[i].tieBreakerDiff == scored[i - 1].tieBreakerDiff) {
        rank = ranked[i - 1].rank;
      }
      ranked.add(scored[i].copyWith(rank: rank));
    }
    return ranked;
  }

  // ═══════════════════════════════════════════════════════════════════
  // AUTO-SCORING PIPELINE — Firestore integration
  // ═══════════════════════════════════════════════════════════════════

  static final _firestore = RestFirestoreService.instance;

  /// Run auto-scoring for a bracket: fetches results + picks from Firestore,
  /// computes leaderboard, and persists scored entries.
  static Future<List<ScoredEntry>> autoScoreBracket({
    required String bracketId,
    required int totalRounds,
    String? currentUserId,
  }) async {
    try {
      // 1. Fetch official results from Firestore
      final resultsDoc = await _firestore.getDocument('bracket_results', bracketId);
      if (resultsDoc == null) {
        if (kDebugMode) debugPrint('AutoScore: No results found for $bracketId');
        return [];
      }

      final gamesData = resultsDoc['games'] as Map<String, dynamic>? ?? {};
      final games = <String, GameResult>{};
      for (final entry in gamesData.entries) {
        final g = entry.value as Map<String, dynamic>? ?? {};
        final gameId = entry.key;
        final round = _roundFromGameId(gameId);
        final matchIdx = _matchFromGameId(gameId);
        games[gameId] = GameResult(
          gameId: gameId,
          round: round,
          matchIndex: matchIdx,
          team1: g['team1'] as String? ?? '',
          team2: g['team2'] as String? ?? '',
          winner: g['winner'] as String?,
          isCompleted: g['isCompleted'] == true,
          score: g['score'] as String?,
        );
      }
      final results = BracketResults(
        bracketId: bracketId,
        games: games,
        lastUpdated: DateTime.now(),
      );

      // 2. Fetch all participant picks from Firestore
      final picksDocs = await _firestore.query(
        'bracket_picks',
        whereField: 'bracketId',
        whereValue: bracketId,
      );

      final allPicks = picksDocs.map((d) {
        final picksMap = d['picks'] as Map<String, dynamic>? ?? {};
        return UserPicks(
          userId: d['userId'] as String? ?? '',
          userName: d['userName'] as String? ?? 'Player',
          userState: d['userState'] as String? ?? '',
          bracketId: bracketId,
          picks: picksMap.map((k, v) => MapEntry(k, v.toString())),
          submittedAt: DateTime.tryParse(d['submittedAt'] as String? ?? '') ?? DateTime.now(),
        );
      }).toList();

      if (allPicks.isEmpty) {
        if (kDebugMode) debugPrint('AutoScore: No picks found for $bracketId');
        return [];
      }

      // 3. Build leaderboard
      final leaderboard = buildLeaderboard(
        allPicks: allPicks,
        results: results,
        totalRounds: totalRounds,
        currentUserId: currentUserId,
      );

      // 4. Persist scored leaderboard to Firestore
      try {
        final leaderboardData = leaderboard.map((e) => {
          'userId': e.userId,
          'userName': e.userName,
          'score': e.score,
          'rank': e.rank,
          'correctPicks': e.correctPicks,
          'incorrectPicks': e.incorrectPicks,
          'pendingPicks': e.pendingPicks,
          'maxPossibleScore': e.maxPossibleScore,
          'championPick': e.championPick ?? '',
        }).toList();

        await _firestore.setDocument('bracket_leaderboards', bracketId, {
          'bracketId': bracketId,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'totalParticipants': leaderboard.length,
          'entries': leaderboardData,
        });
      } catch (e) {
        if (kDebugMode) debugPrint('AutoScore: Firestore persist error: $e');
      }

      if (kDebugMode) {
        debugPrint('AutoScore: Scored ${leaderboard.length} entries for $bracketId');
      }
      return leaderboard;
    } catch (e) {
      if (kDebugMode) debugPrint('AutoScore: Pipeline error: $e');
      return [];
    }
  }

  /// Fetch cached leaderboard from Firestore (pre-computed).
  static Future<List<ScoredEntry>> getCachedLeaderboard(String bracketId) async {
    try {
      final doc = await _firestore.getDocument('bracket_leaderboards', bracketId);
      if (doc == null) return [];

      final entries = doc['entries'] as List<dynamic>? ?? [];
      return entries.map((e) {
        final m = e as Map<String, dynamic>;
        return ScoredEntry(
          userId: m['userId'] as String? ?? '',
          userName: m['userName'] as String? ?? '',
          userState: '',
          correctPicks: (m['correctPicks'] as int?) ?? 0,
          incorrectPicks: (m['incorrectPicks'] as int?) ?? 0,
          pendingPicks: (m['pendingPicks'] as int?) ?? 0,
          totalPicks: ((m['correctPicks'] as int?) ?? 0) +
              ((m['incorrectPicks'] as int?) ?? 0) +
              ((m['pendingPicks'] as int?) ?? 0),
          score: (m['score'] as int?) ?? 0,
          rank: (m['rank'] as int?) ?? 0,
          maxPossibleScore: (m['maxPossibleScore'] as int?) ?? 0,
          championPick: (m['championPick'] as String?)?.isEmpty == true
              ? null
              : m['championPick'] as String?,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('AutoScore: getCachedLeaderboard error: $e');
      return [];
    }
  }
}

/// A user's Pick 'Em entry (single-round picks + tie-breaker prediction).
class PickEmUserEntry {
  final String userId;
  final String userName;
  final Map<String, String> picks; // gameId -> picked team
  final int? tieBreakerPrediction; // predicted total points for tie-break game

  const PickEmUserEntry({
    required this.userId,
    required this.userName,
    required this.picks,
    this.tieBreakerPrediction,
  });
}

/// Scored Pick 'Em entry for leaderboard display.
class PickEmScoredEntry {
  final String userId;
  final String userName;
  final int correctPicks;
  final int totalPicks;
  final double percentCorrect;
  final int? tieBreakerPrediction;
  final int? tieBreakerDiff; // abs difference from actual total
  final int rank;
  final bool isCurrentUser;

  const PickEmScoredEntry({
    required this.userId,
    required this.userName,
    required this.correctPicks,
    required this.totalPicks,
    required this.percentCorrect,
    this.tieBreakerPrediction,
    this.tieBreakerDiff,
    required this.rank,
    this.isCurrentUser = false,
  });

  PickEmScoredEntry copyWith({int? rank, bool? isCurrentUser}) {
    return PickEmScoredEntry(
      userId: userId,
      userName: userName,
      correctPicks: correctPicks,
      totalPicks: totalPicks,
      percentCorrect: percentCorrect,
      tieBreakerPrediction: tieBreakerPrediction,
      tieBreakerDiff: tieBreakerDiff,
      rank: rank ?? this.rank,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
