// ─── SQUARES GAME MODEL ─────────────────────────────────────────────────────
// A 10x10 grid (100 squares) where players pay BMB Bucks to pick squares.
// Row/column headers are randomly assigned digits 0-9 for each team.
// The LAST DIGIT of each team's score at the end of each quarter determines
// which square wins that quarter's prize.
//
// ══════════════════════════════════════════════════════════════════════════════
// STATUS FLOW (CORRECT RULES):
//
//   UPCOMING  → Players pick squares BLIND (no numbers visible).
//               Credits are NOT deducted yet. Users can freely pick/deselect.
//
//   (LIVE)    → SKIPPED for Squares. Retained in enum for Brackets.
//               Squares go directly from UPCOMING → IN_PROGRESS.
//
//   IN_PROGRESS -> Board LOCKED. Credits deducted, numbers revealed.
//                 Live scoring flows in per quarter.
//
//   DONE      -> Final scores entered. Quarter winners auto-calculated.
// ══════════════════════════════════════════════════════════════════════════════
//
// SPORTS SUPPORTED: Any sport with quarters --
//   Football (NFL), Basketball (NBA/NCAA), Hockey (NHL periods), Lacrosse, etc.

enum SquaresStatus { upcoming, live, inProgress, done }

enum SquaresSport {
  football,
  basketball,
  hockey,
  lacrosse,
  soccer, // halves treated as Q1/Q2
  other,
}

class SquaresGame {
  final String id;
  final String name;
  final String team1; // columns
  final String team2; // rows
  final SquaresSport sport;
  final List<int> colNumbers; // 0-9 shuffled for team1 (empty until live)
  final List<int> rowNumbers; // 0-9 shuffled for team2 (empty until live)
  final bool numbersRevealed; // true once Go LIVE assigns numbers
  final Map<String, SquarePick> picks; // "row_col" -> pick
  final List<QuarterScore> scores; // Q1-Q4
  final String hostId;
  final String hostName;
  final int creditsPerSquare; // BMB Bucks cost per square
  final int maxSquaresPerPlayer;
  final DateTime createdAt;
  final DateTime? scheduledLiveDate; // when to transition upcoming->live
  final DateTime? gameStartTime; // actual sporting event start
  final SquaresStatus status;
  final String? gameEventId; // ESPN event ID for auto-score pulling
  final String? gameEventName; // e.g. "Super Bowl LVIII"
  final int prizePerQuarter; // credits awarded per quarter winner
  final int grandPrizeBonus; // bonus credits for final score winner
  final Set<String> releasedUserIds; // users whose squares were released at live
  final bool autoHost; // auto-host: auto-transition at goLiveDate
  final int minPlayers; // minimum unique players required to go live
  final DateTime? goLiveDate; // scheduled date to auto-transition to in_progress
  final bool isPublic; // true = visible on bracket board; false = host + joined only
  final bool addToBracketBoard; // true = show on public bracket board feed

  SquaresGame({
    required this.id,
    required this.name,
    required this.team1,
    required this.team2,
    this.sport = SquaresSport.football,
    required this.colNumbers,
    required this.rowNumbers,
    this.numbersRevealed = false,
    this.picks = const {},
    this.scores = const [],
    required this.hostId,
    required this.hostName,
    this.creditsPerSquare = 1,
    this.maxSquaresPerPlayer = 10,
    required this.createdAt,
    this.scheduledLiveDate,
    this.gameStartTime,
    this.status = SquaresStatus.upcoming,
    this.gameEventId,
    this.gameEventName,
    this.prizePerQuarter = 0,
    this.grandPrizeBonus = 0,
    this.releasedUserIds = const {},
    this.autoHost = false,
    this.minPlayers = 2,
    this.goLiveDate,
    this.isPublic = true,
    this.addToBracketBoard = true,
  });

  /// Create a new game — numbers are NOT assigned yet (empty lists).
  /// Numbers get randomly assigned when host taps "Go LIVE".
  factory SquaresGame.create({
    required String name,
    required String team1,
    required String team2,
    SquaresSport sport = SquaresSport.football,
    required String hostId,
    required String hostName,
    int creditsPerSquare = 1,
    int maxSquaresPerPlayer = 10,
    DateTime? scheduledLiveDate,
    DateTime? gameStartTime,
    String? gameEventId,
    String? gameEventName,
    int prizePerQuarter = 0,
    int grandPrizeBonus = 0,
    bool autoHost = false,
    int minPlayers = 2,
    DateTime? goLiveDate,
    bool isPublic = true,
    bool addToBracketBoard = true,
  }) {
    return SquaresGame(
      id: 'sq_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      team1: team1,
      team2: team2,
      sport: sport,
      colNumbers: const [],  // empty — assigned at Go LIVE
      rowNumbers: const [],  // empty — assigned at Go LIVE
      numbersRevealed: false,
      hostId: hostId,
      hostName: hostName,
      creditsPerSquare: creditsPerSquare,
      maxSquaresPerPlayer: maxSquaresPerPlayer,
      createdAt: DateTime.now(),
      scheduledLiveDate: scheduledLiveDate,
      gameStartTime: gameStartTime,
      gameEventId: gameEventId,
      gameEventName: gameEventName,
      prizePerQuarter: prizePerQuarter,
      grandPrizeBonus: grandPrizeBonus,
      autoHost: autoHost,
      minPlayers: minPlayers,
      goLiveDate: goLiveDate,
      isPublic: isPublic,
      addToBracketBoard: addToBracketBoard,
    );
  }

  // ─── COMPUTED GETTERS ───────────────────────────────────────────────────

  int get totalSquares => 100;
  int get pickedCount => picks.length;
  int get availableCount => totalSquares - pickedCount;
  bool get isFull => pickedCount >= totalSquares;

  bool get isUpcoming => status == SquaresStatus.upcoming;
  bool get isLive => status == SquaresStatus.live;
  bool get isInProgress => status == SquaresStatus.inProgress;
  bool get isDone => status == SquaresStatus.done;

  /// Users can pick squares during UPCOMING only (blind picks, no numbers visible)
  bool get isSelectable => isUpcoming;
  bool get isLocked => isInProgress || isDone;

  /// Whether numbers have been assigned and should be visible
  bool get areNumbersVisible => numbersRevealed && colNumbers.isNotEmpty && rowNumbers.isNotEmpty;

  String get statusLabel {
    switch (status) {
      case SquaresStatus.upcoming:
        return 'UPCOMING';
      case SquaresStatus.live:
        return 'LIVE';
      case SquaresStatus.inProgress:
        return 'IN PROGRESS';
      case SquaresStatus.done:
        return 'COMPLETED';
    }
  }

  String get sportLabel {
    switch (sport) {
      case SquaresSport.football:
        return 'Football';
      case SquaresSport.basketball:
        return 'Basketball';
      case SquaresSport.hockey:
        return 'Hockey';
      case SquaresSport.lacrosse:
        return 'Lacrosse';
      case SquaresSport.soccer:
        return 'Soccer';
      case SquaresSport.other:
        return 'Other';
    }
  }

  /// Label for each period (quarter/period/half)
  List<String> get periodLabels {
    switch (sport) {
      case SquaresSport.hockey:
        return ['P1', 'P2', 'P3', 'OT'];
      case SquaresSport.soccer:
        return ['1H', '2H', 'ET1', 'ET2'];
      default:
        return ['Q1', 'Q2', 'Q3', 'Q4'];
    }
  }

  /// Full period names
  List<String> get periodFullNames {
    switch (sport) {
      case SquaresSport.hockey:
        return ['1st Period', '2nd Period', '3rd Period', 'Overtime'];
      case SquaresSport.soccer:
        return ['1st Half', '2nd Half', 'Extra Time 1', 'Extra Time 2'];
      default:
        return ['1st Quarter', '2nd Quarter', '3rd Quarter', '4th Quarter'];
    }
  }

  /// Unique player count
  int get uniquePlayerCount {
    final playerIds = picks.values.map((p) => p.userId).toSet();
    return playerIds.length;
  }

  /// Whether the go-live date has been reached
  bool get isGoLiveDateReached =>
      goLiveDate != null && DateTime.now().isAfter(goLiveDate!);

  /// Whether the game is ready for auto-transition
  bool get canAutoTransition =>
      autoHost && isUpcoming && isGoLiveDateReached && uniquePlayerCount >= minPlayers;

  /// Time remaining until go-live date (null if no date or already passed)
  Duration? get timeUntilGoLive {
    if (goLiveDate == null) return null;
    final remaining = goLiveDate!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Total prize pool in credits
  int get totalPrizePool => (prizePerQuarter * 4) + grandPrizeBonus;

  /// Total credits collected from all picks
  int get totalCreditsCollected => pickedCount * creditsPerSquare;

  /// Check if current user has reached max squares
  int userPickCount(String userId) =>
      picks.values.where((p) => p.userId == userId).length;

  bool canUserPick(String userId) =>
      userPickCount(userId) < maxSquaresPerPlayer;

  /// Total credits a user has committed
  int userTotalCredits(String userId) =>
      userPickCount(userId) * creditsPerSquare;

  // ─── SQUARE OPERATIONS ──────────────────────────────────────────────────

  bool isSquarePicked(int row, int col) => picks.containsKey('${row}_$col');
  SquarePick? getSquarePick(int row, int col) => picks['${row}_$col'];

  /// Get winner for a given quarter score (only works if numbers are revealed)
  SquarePick? getQuarterWinner(QuarterScore score) {
    if (!areNumbersVisible) return null;
    final t1Digit = score.team1Score % 10;
    final t2Digit = score.team2Score % 10;
    final col = colNumbers.indexOf(t1Digit);
    final row = rowNumbers.indexOf(t2Digit);
    if (col >= 0 && row >= 0) return picks['${row}_$col'];
    return null;
  }

  /// Get winning square coordinates for a score
  (int row, int col)? getWinningCoords(QuarterScore score) {
    if (!areNumbersVisible) return null;
    final t1Digit = score.team1Score % 10;
    final t2Digit = score.team2Score % 10;
    final col = colNumbers.indexOf(t1Digit);
    final row = rowNumbers.indexOf(t2Digit);
    if (col >= 0 && row >= 0) return (row, col);
    return null;
  }

  /// Get all quarter winners with their info
  List<QuarterWinner> getWinners() {
    return scores.map((score) {
      final winner = getQuarterWinner(score);
      final coords = getWinningCoords(score);
      return QuarterWinner(
        quarter: score.quarter,
        score: score,
        winner: winner,
        winningRow: coords?.$1,
        winningCol: coords?.$2,
        prize: score.isFinal ? prizePerQuarter + grandPrizeBonus : prizePerQuarter,
      );
    }).toList();
  }

  /// Get unique player leaderboard (total winnings)
  List<PlayerWinnings> getLeaderboard() {
    final winnings = <String, PlayerWinnings>{};
    for (final w in getWinners()) {
      if (w.hasWinner) {
        final uid = w.winner!.userId;
        final existing = winnings[uid];
        if (existing != null) {
          winnings[uid] = existing.copyWith(
            quartersWon: existing.quartersWon + 1,
            totalCredits: existing.totalCredits + w.prize,
          );
        } else {
          winnings[uid] = PlayerWinnings(
            userId: uid,
            userName: w.winner!.userName,
            quartersWon: 1,
            totalCredits: w.prize,
          );
        }
      }
    }
    final list = winnings.values.toList()
      ..sort((a, b) => b.totalCredits.compareTo(a.totalCredits));
    return list;
  }

  // ─── COPY WITH ──────────────────────────────────────────────────────────

  SquaresGame copyWith({
    List<int>? colNumbers,
    List<int>? rowNumbers,
    bool? numbersRevealed,
    Map<String, SquarePick>? picks,
    List<QuarterScore>? scores,
    SquaresStatus? status,
    Set<String>? releasedUserIds,
    DateTime? gameStartTime,
    String? gameEventId,
    bool? autoHost,
    int? minPlayers,
    DateTime? goLiveDate,
    bool? isPublic,
    bool? addToBracketBoard,
  }) {
    return SquaresGame(
      id: id,
      name: name,
      team1: team1,
      team2: team2,
      sport: sport,
      colNumbers: colNumbers ?? this.colNumbers,
      rowNumbers: rowNumbers ?? this.rowNumbers,
      numbersRevealed: numbersRevealed ?? this.numbersRevealed,
      picks: picks ?? this.picks,
      scores: scores ?? this.scores,
      hostId: hostId,
      hostName: hostName,
      creditsPerSquare: creditsPerSquare,
      maxSquaresPerPlayer: maxSquaresPerPlayer,
      createdAt: createdAt,
      scheduledLiveDate: scheduledLiveDate,
      gameStartTime: gameStartTime ?? this.gameStartTime,
      status: status ?? this.status,
      gameEventId: gameEventId ?? this.gameEventId,
      gameEventName: gameEventName,
      prizePerQuarter: prizePerQuarter,
      grandPrizeBonus: grandPrizeBonus,
      releasedUserIds: releasedUserIds ?? this.releasedUserIds,
      autoHost: autoHost ?? this.autoHost,
      minPlayers: minPlayers ?? this.minPlayers,
      goLiveDate: goLiveDate ?? this.goLiveDate,
      isPublic: isPublic ?? this.isPublic,
      addToBracketBoard: addToBracketBoard ?? this.addToBracketBoard,
    );
  }
}

// ─── SUPPORTING MODELS ────────────────────────────────────────────────────

class SquarePick {
  final String userId;
  final String userName;
  final DateTime pickedAt;
  final bool creditDeducted; // true = credits taken (at Go LIVE)

  const SquarePick({
    required this.userId,
    required this.userName,
    required this.pickedAt,
    this.creditDeducted = false,
  });

  SquarePick copyWith({bool? creditDeducted}) {
    return SquarePick(
      userId: userId,
      userName: userName,
      pickedAt: pickedAt,
      creditDeducted: creditDeducted ?? this.creditDeducted,
    );
  }
}

class QuarterScore {
  final String quarter; // 'Q1','Q2','Q3','Q4' or 'P1','P2','P3','OT' etc.
  final int team1Score; // cumulative score at end of this period
  final int team2Score;
  final bool isFinal; // true for the last quarter (grand prize bonus)
  final bool isFromEspn; // true if auto-pulled from ESPN

  const QuarterScore({
    required this.quarter,
    required this.team1Score,
    required this.team2Score,
    this.isFinal = false,
    this.isFromEspn = false,
  });
}

class QuarterWinner {
  final String quarter;
  final QuarterScore score;
  final SquarePick? winner;
  final int? winningRow;
  final int? winningCol;
  final int prize; // credits awarded

  const QuarterWinner({
    required this.quarter,
    required this.score,
    this.winner,
    this.winningRow,
    this.winningCol,
    this.prize = 0,
  });

  bool get hasWinner => winner != null;
}

class PlayerWinnings {
  final String userId;
  final String userName;
  final int quartersWon;
  final int totalCredits;

  const PlayerWinnings({
    required this.userId,
    required this.userName,
    required this.quartersWon,
    required this.totalCredits,
  });

  PlayerWinnings copyWith({int? quartersWon, int? totalCredits}) {
    return PlayerWinnings(
      userId: userId,
      userName: userName,
      quartersWon: quartersWon ?? this.quartersWon,
      totalCredits: totalCredits ?? this.totalCredits,
    );
  }
}
