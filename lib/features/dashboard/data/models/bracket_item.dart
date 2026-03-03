import 'bracket_host.dart';

/// What kind of reward the bracket champion receives.
enum RewardType {
  credits,   // BMB credits from the bucket
  custom,    // Host-written custom reward (dinner, sneakers, etc.)
  charity,   // Proceeds go to a named charity
  none,      // No reward / just bragging rights
}

/// The type of game/competition shown on the Bracket Board.
/// Each type has its own icon, badge color, and gameplay flow.
enum GameType {
  bracket,     // Traditional bracket tournament
  pickem,      // Pick 'em — pick winners for each game in a slate
  squares,     // Squares — 10x10 grid, score-based quarter prizes
  trivia,      // Trivia / quiz night
  props,       // Prop bets — over/under style picks
  survivor,    // Survivor pool — pick one team per week, lose on a loss
  voting,      // Community vote — best pizza, best burger, etc.
}

class BracketItem {
  final String id;
  final String title;
  final String sport;
  final int participants;
  final double entryFee;
  final double prizeAmount;
  final String? imageUrl;
  final BracketHost? host;
  final String? authorName;
  final String status;
  final GameType gameType; // bracket, pickem, squares, trivia, etc.
  final bool usesBmbBucks;
  final int? entryCredits;
  final int? prizeCredits;
  final bool isVipBoosted; // host paid 2 credits/mo for VIP front placement
  final bool isPublic; // true = visible on bracket board; false = private (host + joined only)

  // ─── CHAMPION ──────────────────────────────────────────────────
  /// The display name of the tournament champion (null until bracket is done).
  final String? championName;

  /// Whether the charity donation has already been processed by the winner.
  final bool charityDonationCompleted;

  // ─── REAL CONTENT DATA ──────────────────────────────────────────
  /// Actual team/option names for this bracket. These flow from the
  /// DailyContentEngine (real sports) or template pool and are used
  /// to build the playable bracket/pick-em/voting experience.
  final List<String> teams;

  /// Short description shown on the detail screen (venue, time, etc.)
  final String description;

  // ─── REWARD ────────────────────────────────────────────────────
  final RewardType rewardType;
  final String rewardDescription; // custom text or charity name

  // ─── PROGRESS TRACKING ─────────────────────────────────────────
  final int totalGames;       // total matchups in the bracket
  final int completedGames;   // how many games resolved
  final int totalPicks;       // total picks user can make
  final int picksMade;        // how many the user has filled in
  final int maxParticipants;  // max capacity (for fill bar)

  const BracketItem({
    required this.id,
    required this.title,
    required this.sport,
    required this.participants,
    this.entryFee = 0.0,
    this.prizeAmount = 0.0,
    this.imageUrl,
    this.host,
    this.authorName,
    this.status = 'live',
    this.gameType = GameType.bracket,
    this.usesBmbBucks = false,
    this.entryCredits,
    this.prizeCredits,
    this.isVipBoosted = false,
    this.isPublic = true,
    this.championName,
    this.charityDonationCompleted = false,
    this.teams = const [],
    this.description = '',
    this.rewardType = RewardType.credits,
    this.rewardDescription = '',
    this.totalGames = 0,
    this.completedGames = 0,
    this.totalPicks = 0,
    this.picksMade = 0,
    this.maxParticipants = 0,
  });

  bool get isFree => entryFee == 0.0 && (entryCredits == null || entryCredits == 0);
  double get bmbBucksCost => (entryCredits ?? 0).toDouble();

  /// Progress fraction for the bracket tournament (games completed)
  double get tournamentProgress => totalGames > 0 ? completedGames / totalGames : 0.0;

  /// Progress fraction for the user's picks
  double get picksProgress => totalPicks > 0 ? picksMade / totalPicks : 0.0;

  /// How full is the bracket (participants / max)
  double get fillProgress => maxParticipants > 0 ? participants / maxParticipants : 0.0;

  /// Human-readable status label for display
  String get statusLabel {
    switch (status) {
      case 'saved': return 'SAVED';
      case 'upcoming': return 'UPCOMING';
      case 'live': return 'LIVE';
      case 'in_progress': return 'IN PROGRESS';
      case 'done': return 'COMPLETED';
      default: return status.toUpperCase();
    }
  }

  /// Human-readable game type label
  String get gameTypeLabel {
    switch (gameType) {
      case GameType.bracket: return 'Bracket';
      case GameType.pickem: return "Pick 'Em";
      case GameType.squares: return 'Squares';
      case GameType.trivia: return 'Trivia';
      case GameType.props: return 'Props';
      case GameType.survivor: return 'Survivor';
      case GameType.voting: return 'Vote';
    }
  }

  /// Whether this bracket can be played (picks made)
  bool get isPlayable => status == 'live' || status == 'in_progress';

  /// Whether the bracket is finished
  bool get isDone => status == 'done';
}
