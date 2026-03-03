// Data models for the BMB scoring and leaderboard system.

/// Represents the result of a single game/matchup in a bracket.
class GameResult {
  final String gameId; // format: "r{round}_g{matchIndex}"
  final int round;
  final int matchIndex;
  final String team1;
  final String team2;
  final String? winner;
  final bool isCompleted;
  final String? score; // e.g. "75-68"
  final DateTime? completedAt;

  const GameResult({
    required this.gameId,
    required this.round,
    required this.matchIndex,
    required this.team1,
    required this.team2,
    this.winner,
    this.isCompleted = false,
    this.score,
    this.completedAt,
  });

  GameResult copyWith({
    String? winner,
    bool? isCompleted,
    String? score,
    DateTime? completedAt,
  }) {
    return GameResult(
      gameId: gameId,
      round: round,
      matchIndex: matchIndex,
      team1: team1,
      team2: team2,
      winner: winner ?? this.winner,
      isCompleted: isCompleted ?? this.isCompleted,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// All official results for a bracket tournament.
class BracketResults {
  final String bracketId;
  final Map<String, GameResult> games; // gameId -> result
  final bool isAutoSynced; // true = template (auto), false = custom (manual)
  final DateTime lastUpdated;
  final String? source; // 'official_api', 'host_manual', 'mock'

  const BracketResults({
    required this.bracketId,
    required this.games,
    this.isAutoSynced = false,
    required this.lastUpdated,
    this.source,
  });

  /// How many games are completed
  int get completedGames => games.values.where((g) => g.isCompleted).length;

  /// Total games in the bracket
  int get totalGames => games.length;

  /// Tournament completion percentage
  double get completionPercent =>
      totalGames > 0 ? completedGames / totalGames : 0;

  /// Whether the entire tournament is finished
  bool get isTournamentComplete => completedGames == totalGames && totalGames > 0;

  /// Get all winners that have advanced
  List<String> get confirmedWinners =>
      games.values.where((g) => g.isCompleted && g.winner != null).map((g) => g.winner!).toList();

  BracketResults copyWith({
    Map<String, GameResult>? games,
    DateTime? lastUpdated,
    String? source,
  }) {
    return BracketResults(
      bracketId: bracketId,
      games: games ?? this.games,
      isAutoSynced: isAutoSynced,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      source: source ?? this.source,
    );
  }
}

/// A single user's submitted picks for a bracket.
class UserPicks {
  final String userId;
  final String userName;
  final String? userState; // state abbreviation for leaderboard
  final String bracketId;
  final Map<String, String> picks; // gameId -> picked team name
  final DateTime submittedAt;
  final bool addedToApparel;

  const UserPicks({
    required this.userId,
    required this.userName,
    this.userState,
    required this.bracketId,
    required this.picks,
    required this.submittedAt,
    this.addedToApparel = false,
  });

  /// Get the user's champion pick (last-round pick)
  String? getChampionPick(int totalRounds) {
    final lastRoundKeys =
        picks.keys.where((k) => k.startsWith('r${totalRounds - 1}_')).toList();
    if (lastRoundKeys.isNotEmpty) {
      return picks[lastRoundKeys.first];
    }
    return null;
  }
}

/// Scored entry on the leaderboard.
class ScoredEntry {
  final String userId;
  final String userName;
  final String? userState;
  final int correctPicks;
  final int incorrectPicks;
  final int pendingPicks;
  final int totalPicks;
  final int score;
  final int rank;
  final int maxPossibleScore;
  final String? championPick;
  final bool isCurrentUser;
  final int? tieBreakerPrediction; // user's predicted total points
  final int? tieBreakerDiff; // abs diff from actual (null if not resolved yet)
  final bool? tieBreakerWentOver; // whether prediction exceeded actual

  const ScoredEntry({
    required this.userId,
    required this.userName,
    this.userState,
    required this.correctPicks,
    required this.incorrectPicks,
    required this.pendingPicks,
    required this.totalPicks,
    required this.score,
    required this.rank,
    required this.maxPossibleScore,
    this.championPick,
    this.isCurrentUser = false,
    this.tieBreakerPrediction,
    this.tieBreakerDiff,
    this.tieBreakerWentOver,
  });

  /// Accuracy percentage (of completed picks)
  double get accuracy {
    final decided = correctPicks + incorrectPicks;
    return decided > 0 ? (correctPicks / decided) * 100 : 0;
  }

  /// Whether champion pick is still alive
  bool isChampionAlive(BracketResults results) {
    if (championPick == null) return false;
    // Check if champion pick hasn't been eliminated
    for (final game in results.games.values) {
      if (game.isCompleted && game.winner != null) {
        if ((game.team1 == championPick || game.team2 == championPick) &&
            game.winner != championPick) {
          return false;
        }
      }
    }
    return true;
  }

  ScoredEntry copyWith({int? rank, bool? isCurrentUser, int? tieBreakerPrediction, int? tieBreakerDiff, bool? tieBreakerWentOver}) {
    return ScoredEntry(
      userId: userId,
      userName: userName,
      userState: userState,
      correctPicks: correctPicks,
      incorrectPicks: incorrectPicks,
      pendingPicks: pendingPicks,
      totalPicks: totalPicks,
      score: score,
      rank: rank ?? this.rank,
      maxPossibleScore: maxPossibleScore,
      championPick: championPick,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      tieBreakerPrediction: tieBreakerPrediction ?? this.tieBreakerPrediction,
      tieBreakerDiff: tieBreakerDiff ?? this.tieBreakerDiff,
      tieBreakerWentOver: tieBreakerWentOver ?? this.tieBreakerWentOver,
    );
  }
}

/// Pick status for visual display
enum PickStatus { correct, incorrect, pending, notPicked }
