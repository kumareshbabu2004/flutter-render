import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/squares/data/models/squares_game.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// ─── SQUARES SERVICE ────────────────────────────────────────────────────────
/// Manages the full lifecycle of Squares games:
///
///   UPCOMING     → Pick squares BLIND (no numbers, no credit deduction)
///   GO LIVE      → Credits DEDUCTED, numbers RANDOMLY assigned & revealed
///   IN_PROGRESS  → Board locked, live scores flow in
///   DONE         → Winners calculated, prizes distributed

class SquaresService {
  static final SquaresService _instance = SquaresService._internal();
  factory SquaresService() => _instance;
  SquaresService._internal();

  /// Key for persisting user credit balance
  static const _creditsKey = 'user_bmb_credits';

  // ─── CREDIT OPERATIONS ──────────────────────────────────────────────────

  /// Get user's current BMB Bucks balance
  Future<int> getUserCredits(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${_creditsKey}_$userId') ?? 350; // default 350
  }

  /// Set user's credit balance
  Future<void> setUserCredits(String userId, int credits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_creditsKey}_$userId', credits);
  }

  /// Deduct credits (at Go LIVE)
  Future<bool> deductCredits(String userId, int amount) async {
    final current = await getUserCredits(userId);
    if (current < amount) return false;
    await setUserCredits(userId, current - amount);
    return true;
  }

  /// Release credits (refund if user released at live, or prize payout)
  Future<void> releaseCredits(String userId, int amount) async {
    final current = await getUserCredits(userId);
    await setUserCredits(userId, current + amount);
  }

  // ─── PICK OPERATIONS ───────────────────────────────────────────────────

  /// Pick a square during UPCOMING status.
  /// NO credits are deducted — this is a blind reservation.
  /// Credits will be deducted when the host taps "Go LIVE".
  Future<(SquaresGame, bool, String)> pickSquare({
    required SquaresGame game,
    required int row,
    required int col,
    required String userId,
    required String userName,
  }) async {
    // Validation checks
    if (!game.isUpcoming) {
      return (game, false, 'Game is no longer accepting picks');
    }
    if (game.isSquarePicked(row, col)) {
      return (game, false, 'Square already taken');
    }
    if (!game.canUserPick(userId)) {
      return (game, false, 'Max ${game.maxSquaresPerPlayer} squares per player');
    }

    // NO credit deduction during upcoming — just reserve the square
    final newPicks = Map<String, SquarePick>.from(game.picks);
    newPicks['${row}_$col'] = SquarePick(
      userId: userId,
      userName: userName,
      pickedAt: DateTime.now(),
      creditDeducted: false,
    );

    final updated = game.copyWith(picks: newPicks);
    final totalCost = game.userPickCount(userId) * game.creditsPerSquare + game.creditsPerSquare;
    return (updated, true, 'Square claimed! ($totalCost credits will be charged at Go LIVE)');
  }

  /// Deselect a square during UPCOMING (free, no credit return needed)
  Future<(SquaresGame, bool, String)> deselectSquare({
    required SquaresGame game,
    required int row,
    required int col,
    required String userId,
  }) async {
    final key = '${row}_$col';
    final pick = game.picks[key];

    if (pick == null) return (game, false, 'Square is empty');
    if (pick.userId != userId) return (game, false, 'Not your square');
    if (!game.isUpcoming) return (game, false, 'Cannot deselect after Go LIVE');

    // No credit return needed — credits weren't deducted yet
    final newPicks = Map<String, SquarePick>.from(game.picks)..remove(key);
    final updated = game.copyWith(picks: newPicks);
    return (updated, true, 'Square released!');
  }

  // ─── STATUS TRANSITIONS ─────────────────────────────────────────────────

  /// Transition: UPCOMING → LIVE
  ///
  /// This is the BIG moment:
  /// 1. Deduct credits from ALL players (boxes * creditsPerSquare)
  /// 2. Players who can't afford get their squares RELEASED
  /// 3. Numbers are RANDOMLY assigned to rows and columns
  /// 4. numbersRevealed = true — users see their surprise numbers!
  Future<(SquaresGame, List<String>)> transitionToLive(SquaresGame game) async {
    if (!game.isUpcoming) return (game, <String>[]);

    final newPicks = Map<String, SquarePick>.from(game.picks);
    final releasedUsers = <String>{};
    final messages = <String>[];

    // Group picks by user to check total cost
    final userPicks = <String, List<String>>{};
    for (final entry in newPicks.entries) {
      final uid = entry.value.userId;
      userPicks.putIfAbsent(uid, () => []).add(entry.key);
    }

    // Process each user — deduct credits
    for (final entry in userPicks.entries) {
      final userId = entry.key;
      final pickKeys = entry.value;
      final totalCost = pickKeys.length * game.creditsPerSquare;

      // Try to deduct credits
      final success = await deductCredits(userId, totalCost);

      if (success) {
        // Mark all their picks as creditDeducted
        for (final key in pickKeys) {
          newPicks[key] = newPicks[key]!.copyWith(creditDeducted: true);
        }
        messages.add('${newPicks[pickKeys.first]!.userName}: $totalCost credits deducted');
      } else {
        // Can't afford — release ALL their squares
        for (final key in pickKeys) {
          newPicks.remove(key);
        }
        releasedUsers.add(userId);
        messages.add('${entry.key}: Released (insufficient credits)');
      }
    }

    // NOW randomly assign numbers!
    final random = Random();
    final cols = List.generate(10, (i) => i)..shuffle(random);
    final rows = List.generate(10, (i) => i)..shuffle(random);

    final updated = game.copyWith(
      picks: newPicks,
      status: SquaresStatus.live,
      releasedUserIds: releasedUsers,
      colNumbers: cols,
      rowNumbers: rows,
      numbersRevealed: true,
    );

    return (updated, messages);
  }

  /// Transition: LIVE → IN_PROGRESS (board locked)
  /// For Squares, "live" is skipped — this also accepts live state as input.
  SquaresGame transitionToInProgress(SquaresGame game) {
    if (!game.isLive && !game.isUpcoming) return game;
    return game.copyWith(status: SquaresStatus.inProgress);
  }

  /// Enter a quarter score and check if game is done
  SquaresGame enterQuarterScore({
    required SquaresGame game,
    required String quarter,
    required int team1Score,
    required int team2Score,
    bool isFinal = false,
    bool isFromEspn = false,
  }) {
    final newScores = List<QuarterScore>.from(game.scores);

    // Replace if this quarter already has a score
    newScores.removeWhere((s) => s.quarter == quarter);

    newScores.add(QuarterScore(
      quarter: quarter,
      team1Score: team1Score,
      team2Score: team2Score,
      isFinal: isFinal,
      isFromEspn: isFromEspn,
    ));

    // Sort scores by period label order
    final labels = game.periodLabels;
    newScores.sort((a, b) {
      final ai = labels.indexOf(a.quarter);
      final bi = labels.indexOf(b.quarter);
      return ai.compareTo(bi);
    });

    // If all 4 quarters are scored, mark as done
    final allScored = newScores.length >= 4;
    return game.copyWith(
      scores: newScores,
      status: allScored ? SquaresStatus.done : game.status,
    );
  }

  /// Distribute prizes to quarter winners
  Future<List<String>> distributePrizes(SquaresGame game) async {
    if (!game.isDone) return ['Game is not completed'];

    final messages = <String>[];
    final winners = game.getWinners();

    for (final w in winners) {
      if (w.hasWinner && w.prize > 0) {
        await releaseCredits(w.winner!.userId, w.prize);
        messages.add('${w.quarter}: ${w.winner!.userName} wins ${w.prize} credits!');
      } else if (!w.hasWinner) {
        messages.add('${w.quarter}: No winner (square unclaimed)');
      }
    }

    return messages;
  }

  // ─── SAMPLE GAMES ──────────────────────────────────────────────────────

  /// Generate demo squares games for testing all status flows
  List<SquaresGame> generateSampleGames() {
    final random = Random(42); // seeded for consistent demo data

    // ── Game 1: UPCOMING — Super Bowl Squares ─────────────────────────
    // Numbers are NOT assigned. Users pick blind.
    final g1 = SquaresGame.create(
      name: 'Super Bowl LIX Squares',
      team1: 'Kansas City Chiefs',
      team2: 'Philadelphia Eagles',
      sport: SquaresSport.football,
      hostId: 'host_nate',
      hostName: 'NateDoubleDown',
      creditsPerSquare: 5,
      maxSquaresPerPlayer: 10,
      scheduledLiveDate: DateTime.now().add(const Duration(days: 2)),
      gameStartTime: DateTime.now().add(const Duration(days: 3)),
      prizePerQuarter: 50,
      grandPrizeBonus: 100,
      autoHost: true,
      minPlayers: 4,
      goLiveDate: DateTime.now().add(const Duration(hours: 47, minutes: 30)),
    );
    // Add some bot picks (blind — no numbers yet)
    final g1Picks = <String, SquarePick>{};
    final botNames = ['SlickRick', 'MarchMax', 'ChalkMaster', 'HoopDreams', 'LuckyBreaks', 'SwishKing'];
    int botIdx = 0;
    for (int i = 0; i < 35; i++) {
      final r = (i * 7 + 3) % 10;
      final c = (i * 3 + 5) % 10;
      final key = '${r}_$c';
      if (!g1Picks.containsKey(key)) {
        final bot = botNames[botIdx % botNames.length];
        g1Picks[key] = SquarePick(
          userId: 'bot_${bot.toLowerCase()}',
          userName: bot,
          pickedAt: DateTime.now().subtract(Duration(hours: i)),
          creditDeducted: false, // NOT deducted yet — upcoming
        );
        botIdx++;
      }
    }
    // Upcoming game: no numbers, numbersRevealed = false (default from create)
    final game1 = g1.copyWith(picks: g1Picks);

    // ── Game 2: IN PROGRESS — NBA Finals Squares ──────────────────────
    // Squares skip "live" — goes straight from upcoming to inProgress.
    final g2cols = List.generate(10, (i) => i)..shuffle(random);
    final g2rows = List.generate(10, (i) => i)..shuffle(random);
    final g2 = SquaresGame(
      id: 'sq_inprog_nba',
      name: 'NBA Finals Squares',
      team1: 'Boston Celtics',
      team2: 'Denver Nuggets',
      sport: SquaresSport.basketball,
      colNumbers: g2cols,
      rowNumbers: g2rows,
      numbersRevealed: true,
      hostId: 'host_slick',
      hostName: 'SlickRick',
      creditsPerSquare: 3,
      maxSquaresPerPlayer: 8,
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      status: SquaresStatus.inProgress, // Squares skip "live" — goes straight to inProgress
      prizePerQuarter: 30,
      grandPrizeBonus: 75,
    );
    final g2Picks = <String, SquarePick>{};
    final bots2 = ['NateDoubleDown', 'CourtneyWins', 'StatGuru42', 'CinderellaFan', 'JamSession', 'SwishKing', 'ChalkMaster', 'HoopDreams'];
    int b2 = 0;
    for (int i = 0; i < 68; i++) {
      final r = (i * 11 + 2) % 10;
      final c = (i * 7 + 1) % 10;
      final key = '${r}_$c';
      if (!g2Picks.containsKey(key)) {
        final bot = bots2[b2 % bots2.length];
        g2Picks[key] = SquarePick(
          userId: 'bot_${bot.toLowerCase().replaceAll(' ', '')}',
          userName: bot,
          pickedAt: DateTime.now().subtract(Duration(hours: i)),
          creditDeducted: true, // credits deducted at Go LIVE
        );
        b2++;
      }
    }
    final game2 = g2.copyWith(picks: g2Picks);

    // ── Game 3: IN PROGRESS — NFL Playoff Squares ─────────────────────
    final g3cols = List.generate(10, (i) => i)..shuffle(random);
    final g3rows = List.generate(10, (i) => i)..shuffle(random);
    final g3 = SquaresGame(
      id: 'sq_inprog_nfl',
      name: 'NFL Playoff Squares',
      team1: 'Buffalo Bills',
      team2: 'Baltimore Ravens',
      sport: SquaresSport.football,
      colNumbers: g3cols,
      rowNumbers: g3rows,
      numbersRevealed: true,
      hostId: 'host_courtney',
      hostName: 'CourtneyWins',
      creditsPerSquare: 2,
      maxSquaresPerPlayer: 5,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: SquaresStatus.inProgress,
      gameEventName: 'AFC Championship',
      prizePerQuarter: 20,
      grandPrizeBonus: 50,
    );
    final g3Picks = <String, SquarePick>{};
    final bots3 = ['NateDoubleDown', 'SlickRick', 'StatGuru42', 'LuckyBreaks', 'SwishKing', 'MarchMax', 'ChalkMaster', 'HoopDreams', 'CinderellaFan', 'JamSession'];
    int b3 = 0;
    // Fill entire board
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 10; c++) {
        final bot = bots3[b3 % bots3.length];
        g3Picks['${r}_$c'] = SquarePick(
          userId: 'bot_${bot.toLowerCase().replaceAll(' ', '')}',
          userName: bot,
          pickedAt: DateTime.now().subtract(Duration(hours: r * 10 + c)),
          creditDeducted: true,
        );
        b3++;
      }
    }
    // Add current user picks
    final cuId = CurrentUserService.instance.userId;
    final cuName = CurrentUserService.instance.displayName.isNotEmpty ? CurrentUserService.instance.displayName : 'BracketKing';
    g3Picks['2_4'] = SquarePick(userId: cuId, userName: cuName, pickedAt: DateTime.now().subtract(const Duration(hours: 5)), creditDeducted: true);
    g3Picks['7_8'] = SquarePick(userId: cuId, userName: cuName, pickedAt: DateTime.now().subtract(const Duration(hours: 4)), creditDeducted: true);
    g3Picks['5_1'] = SquarePick(userId: cuId, userName: cuName, pickedAt: DateTime.now().subtract(const Duration(hours: 3)), creditDeducted: true);

    final game3 = g3.copyWith(
      picks: g3Picks,
      scores: [
        const QuarterScore(quarter: 'Q1', team1Score: 7, team2Score: 3),
        const QuarterScore(quarter: 'Q2', team1Score: 17, team2Score: 10),
      ],
    );

    // ── Game 4: DONE — March Madness Squares ──────────────────────────
    final g4cols = List.generate(10, (i) => i)..shuffle(random);
    final g4rows = List.generate(10, (i) => i)..shuffle(random);
    final g4 = SquaresGame(
      id: 'sq_done_mm',
      name: 'March Madness Final Squares',
      team1: 'Duke Blue Devils',
      team2: 'UConn Huskies',
      sport: SquaresSport.basketball,
      colNumbers: g4cols,
      rowNumbers: g4rows,
      numbersRevealed: true,
      hostId: 'host_nate',
      hostName: 'NateDoubleDown',
      creditsPerSquare: 2,
      maxSquaresPerPlayer: 5,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      status: SquaresStatus.done,
      gameEventName: 'NCAA Championship',
      prizePerQuarter: 25,
      grandPrizeBonus: 50,
    );
    final g4Picks = <String, SquarePick>{};
    final bots4 = ['SlickRick', 'CourtneyWins', 'StatGuru42', 'LuckyBreaks', 'SwishKing', 'MarchMax', 'ChalkMaster', 'HoopDreams', 'CinderellaFan', 'JamSession'];
    int b4 = 0;
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 10; c++) {
        final bot = bots4[b4 % bots4.length];
        g4Picks['${r}_$c'] = SquarePick(
          userId: 'bot_${bot.toLowerCase().replaceAll(' ', '')}',
          userName: bot,
          pickedAt: DateTime.now().subtract(Duration(days: 3, hours: r * 10 + c)),
          creditDeducted: true,
        );
        b4++;
      }
    }
    g4Picks['3_6'] = SquarePick(userId: cuId, userName: cuName, pickedAt: DateTime.now().subtract(const Duration(days: 3)), creditDeducted: true);
    g4Picks['8_2'] = SquarePick(userId: cuId, userName: cuName, pickedAt: DateTime.now().subtract(const Duration(days: 3)), creditDeducted: true);

    final game4 = g4.copyWith(
      picks: g4Picks,
      scores: [
        const QuarterScore(quarter: 'Q1', team1Score: 18, team2Score: 22),
        const QuarterScore(quarter: 'Q2', team1Score: 38, team2Score: 41),
        const QuarterScore(quarter: 'Q3', team1Score: 56, team2Score: 59),
        const QuarterScore(quarter: 'Q4', team1Score: 72, team2Score: 75, isFinal: true),
      ],
    );

    return [game1, game2, game3, game4];
  }
}
