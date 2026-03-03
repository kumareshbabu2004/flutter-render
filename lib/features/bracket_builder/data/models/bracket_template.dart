/// All pre-built tournament templates available in BMB.
class BracketTemplate {
  final String id;
  final String name;
  final String sport;
  final String icon; // Material icon name hint
  final int teamCount;
  final bool hasPlayInGames;
  final int playInCount;
  final List<String> defaultTeams;
  final String description;
  final String category; // 'popular', 'football', 'basketball', 'soccer', 'tennis', 'baseball', 'golf', 'custom'

  // Play-in game definitions: each entry maps [teamA, teamB] -> slotIndex in main bracket
  final List<PlayInGame> playInGames;

  // Data feed source for live auto-sync
  final String? dataFeedId; // e.g. 'espn_ncaam', 'espn_ncaaw', 'ncaa_nit'

  /// If true, the bracket reseeds between rounds (e.g. NFL Divisional round).
  /// The highest remaining seed always faces the lowest remaining seed,
  /// rather than following a fixed bracket path.
  final bool reseeds;

  /// The round name after which reseeding occurs (e.g. 'Wild Card').
  /// Only meaningful when [reseeds] is true.
  final String? reseedAfterRound;

  const BracketTemplate({
    required this.id,
    required this.name,
    required this.sport,
    required this.icon,
    required this.teamCount,
    this.hasPlayInGames = false,
    this.playInCount = 0,
    this.defaultTeams = const [],
    this.playInGames = const [],
    this.dataFeedId,
    required this.description,
    required this.category,
    this.reseeds = false,
    this.reseedAfterRound,
  });

  /// Total slots including play-in teams
  int get totalSlots => teamCount + playInCount;

  // ─── Helper: parse seed number from a team name like "(1) Duke" ──
  static int? parseSeed(String teamName) {
    final match = RegExp(r'^\((\d+)\)').firstMatch(teamName);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  /// Format a team name with seed: returns "(seed) name" or just "name"
  static String formatWithSeed(int seed, String name) => '($seed) $name';

  // ═══════════════════════════════════════════════════════════════════
  // ─── NCAA MEN'S MARCH MADNESS (68 teams, First Four play-in) ─────
  // ═══════════════════════════════════════════════════════════════════

  static const marchmadness = BracketTemplate(
    id: 'march_madness',
    name: 'March Madness NCAA',
    sport: 'Basketball',
    icon: 'sports_basketball',
    teamCount: 64,
    hasPlayInGames: true,
    playInCount: 4, // 8 teams play 4 games -> 4 winners fill spots in 64
    dataFeedId: 'espn_ncaam',
    description:
        '68-team NCAA Men\'s Tournament with First Four play-in games. '
        'The ultimate bracket challenge. 8 teams compete in 4 play-in games, '
        'and the 4 winners are placed into the Round of 64.',
    category: 'basketball',
    // 64 main-bracket teams listed by region and seeding.
    // Play-in slots are marked "Play-In Winner" and get filled once the
    // First Four games are decided.
    defaultTeams: [
      // ─── EAST REGION ───
      '(1) East Seed 1',   '(16) Play-In Winner E',  // game 0
      '(8) East Seed 8',   '(9) East Seed 9',        // game 1
      '(5) East Seed 5',   '(12) East Seed 12',      // game 2
      '(4) East Seed 4',   '(13) East Seed 13',      // game 3
      '(6) East Seed 6',   '(11) Play-In Winner F',  // game 4
      '(3) East Seed 3',   '(14) East Seed 14',      // game 5
      '(7) East Seed 7',   '(10) East Seed 10',      // game 6
      '(2) East Seed 2',   '(15) East Seed 15',      // game 7

      // ─── WEST REGION ───
      '(1) West Seed 1',   '(16) Play-In Winner G',  // game 8
      '(8) West Seed 8',   '(9) West Seed 9',        // game 9
      '(5) West Seed 5',   '(12) West Seed 12',      // game 10
      '(4) West Seed 4',   '(13) West Seed 13',      // game 11
      '(6) West Seed 6',   '(11) West Seed 11',      // game 12
      '(3) West Seed 3',   '(14) West Seed 14',      // game 13
      '(7) West Seed 7',   '(10) West Seed 10',      // game 14
      '(2) West Seed 2',   '(15) West Seed 15',      // game 15

      // ─── SOUTH REGION ───
      '(1) South Seed 1',  '(16) South Seed 16',     // game 16
      '(8) South Seed 8',  '(9) South Seed 9',       // game 17
      '(5) South Seed 5',  '(12) South Seed 12',     // game 18
      '(4) South Seed 4',  '(13) South Seed 13',     // game 19
      '(6) South Seed 6',  '(11) Play-In Winner H',  // game 20
      '(3) South Seed 3',  '(14) South Seed 14',     // game 21
      '(7) South Seed 7',  '(10) South Seed 10',     // game 22
      '(2) South Seed 2',  '(15) South Seed 15',     // game 23

      // ─── MIDWEST REGION ───
      '(1) Midwest Seed 1','(16) Midwest Seed 16',   // game 24
      '(8) Midwest Seed 8','(9) Midwest Seed 9',     // game 25
      '(5) Midwest Seed 5','(12) Midwest Seed 12',   // game 26
      '(4) Midwest Seed 4','(13) Midwest Seed 13',   // game 27
      '(6) Midwest Seed 6','(11) Midwest Seed 11',   // game 28
      '(3) Midwest Seed 3','(14) Midwest Seed 14',   // game 29
      '(7) Midwest Seed 7','(10) Midwest Seed 10',   // game 30
      '(2) Midwest Seed 2','(15) Midwest Seed 15',   // game 31
    ],
    playInGames: [
      // First Four: 8 teams -> 4 play-in games
      // Game E: Two 16-seeds play -> winner goes to East slot 1 (index 1)
      PlayInGame(id: 'playin_E', team1: '(16) East Play-In A', team2: '(16) East Play-In B', mainBracketSlot: 1, region: 'East', seedSlot: 16),
      // Game F: Two 11-seeds play -> winner goes to East slot 9 (index 9)
      PlayInGame(id: 'playin_F', team1: '(11) East Play-In C', team2: '(11) East Play-In D', mainBracketSlot: 9, region: 'East', seedSlot: 11),
      // Game G: Two 16-seeds play -> winner goes to West slot 17 (index 17)
      PlayInGame(id: 'playin_G', team1: '(16) West Play-In E', team2: '(16) West Play-In F', mainBracketSlot: 17, region: 'West', seedSlot: 16),
      // Game H: Two 11-seeds play -> winner goes to South slot 41 (index 41)
      PlayInGame(id: 'playin_H', team1: '(11) South Play-In G', team2: '(11) South Play-In H', mainBracketSlot: 41, region: 'South', seedSlot: 11),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // ─── NCAA WOMEN'S MARCH MADNESS (68 teams, First Four) ───────────
  // ═══════════════════════════════════════════════════════════════════

  static const ncaaWomensBB = BracketTemplate(
    id: 'ncaa_womens_bb',
    name: "NCAA Women's March Madness",
    sport: 'Basketball',
    icon: 'sports_basketball',
    teamCount: 64,
    hasPlayInGames: true,
    playInCount: 4,
    dataFeedId: 'espn_ncaaw',
    description:
        "68-team NCAA Women's Tournament with First Four play-in games. "
        "Same format as men's — 8 teams compete in 4 play-in games, winners "
        "advance to the Round of 64.",
    category: 'basketball',
    defaultTeams: [
      // ─── ALBANY REGION ───
      '(1) Albany Seed 1',   '(16) Play-In Winner W1',
      '(8) Albany Seed 8',   '(9) Albany Seed 9',
      '(5) Albany Seed 5',   '(12) Albany Seed 12',
      '(4) Albany Seed 4',   '(13) Albany Seed 13',
      '(6) Albany Seed 6',   '(11) Play-In Winner W2',
      '(3) Albany Seed 3',   '(14) Albany Seed 14',
      '(7) Albany Seed 7',   '(10) Albany Seed 10',
      '(2) Albany Seed 2',   '(15) Albany Seed 15',

      // ─── PORTLAND REGION ───
      '(1) Portland Seed 1',   '(16) Play-In Winner W3',
      '(8) Portland Seed 8',   '(9) Portland Seed 9',
      '(5) Portland Seed 5',   '(12) Portland Seed 12',
      '(4) Portland Seed 4',   '(13) Portland Seed 13',
      '(6) Portland Seed 6',   '(11) Portland Seed 11',
      '(3) Portland Seed 3',   '(14) Portland Seed 14',
      '(7) Portland Seed 7',   '(10) Portland Seed 10',
      '(2) Portland Seed 2',   '(15) Portland Seed 15',

      // ─── BIRMINGHAM REGION ───
      '(1) Birmingham Seed 1', '(16) Birmingham Seed 16',
      '(8) Birmingham Seed 8', '(9) Birmingham Seed 9',
      '(5) Birmingham Seed 5', '(12) Birmingham Seed 12',
      '(4) Birmingham Seed 4', '(13) Birmingham Seed 13',
      '(6) Birmingham Seed 6', '(11) Play-In Winner W4',
      '(3) Birmingham Seed 3', '(14) Birmingham Seed 14',
      '(7) Birmingham Seed 7', '(10) Birmingham Seed 10',
      '(2) Birmingham Seed 2', '(15) Birmingham Seed 15',

      // ─── TAMPA REGION ───
      '(1) Tampa Seed 1',     '(16) Tampa Seed 16',
      '(8) Tampa Seed 8',     '(9) Tampa Seed 9',
      '(5) Tampa Seed 5',     '(12) Tampa Seed 12',
      '(4) Tampa Seed 4',     '(13) Tampa Seed 13',
      '(6) Tampa Seed 6',     '(11) Tampa Seed 11',
      '(3) Tampa Seed 3',     '(14) Tampa Seed 14',
      '(7) Tampa Seed 7',     '(10) Tampa Seed 10',
      '(2) Tampa Seed 2',     '(15) Tampa Seed 15',
    ],
    playInGames: [
      PlayInGame(id: 'playin_W1', team1: '(16) Albany Play-In A', team2: '(16) Albany Play-In B', mainBracketSlot: 1, region: 'Albany', seedSlot: 16),
      PlayInGame(id: 'playin_W2', team1: '(11) Albany Play-In C', team2: '(11) Albany Play-In D', mainBracketSlot: 9, region: 'Albany', seedSlot: 11),
      PlayInGame(id: 'playin_W3', team1: '(16) Portland Play-In E', team2: '(16) Portland Play-In F', mainBracketSlot: 17, region: 'Portland', seedSlot: 16),
      PlayInGame(id: 'playin_W4', team1: '(11) Birmingham Play-In G', team2: '(11) Birmingham Play-In H', mainBracketSlot: 41, region: 'Birmingham', seedSlot: 11),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // ─── NIT (NATIONAL INVITATION TOURNAMENT) ─────────────────────────
  // ═══════════════════════════════════════════════════════════════════

  static const nitTournament = BracketTemplate(
    id: 'nit',
    name: 'NIT Tournament',
    sport: 'Basketball',
    icon: 'sports_basketball',
    teamCount: 32,
    hasPlayInGames: false,
    playInCount: 0,
    dataFeedId: 'espn_nit',
    description:
        '32-team National Invitation Tournament (NIT). '
        'The second-most prestigious post-season tournament in college basketball. '
        '4 regions, single-elimination bracket.',
    category: 'basketball',
    defaultTeams: [
      // ─── UPPER LEFT REGION ───
      '(1) NIT Seed 1',   '(8) NIT Seed 8',
      '(4) NIT Seed 4',   '(5) NIT Seed 5',
      '(3) NIT Seed 3',   '(6) NIT Seed 6',
      '(2) NIT Seed 2',   '(7) NIT Seed 7',

      // ─── UPPER RIGHT REGION ───
      '(1) NIT Seed 9',   '(8) NIT Seed 16',
      '(4) NIT Seed 12',  '(5) NIT Seed 13',
      '(3) NIT Seed 11',  '(6) NIT Seed 14',
      '(2) NIT Seed 10',  '(7) NIT Seed 15',

      // ─── LOWER LEFT REGION ───
      '(1) NIT Seed 17',  '(8) NIT Seed 24',
      '(4) NIT Seed 20',  '(5) NIT Seed 21',
      '(3) NIT Seed 19',  '(6) NIT Seed 22',
      '(2) NIT Seed 18',  '(7) NIT Seed 23',

      // ─── LOWER RIGHT REGION ───
      '(1) NIT Seed 25',  '(8) NIT Seed 32',
      '(4) NIT Seed 28',  '(5) NIT Seed 29',
      '(3) NIT Seed 27',  '(6) NIT Seed 30',
      '(2) NIT Seed 26',  '(7) NIT Seed 31',
    ],
  );

  // ─── OTHER TEMPLATES (UNCHANGED) ─────────────────────────────────

  /// NFL Playoffs — 14-team field (7 AFC + 7 NFC).
  ///
  /// **Round Structure:**
  ///   1. Wild Card Round — 6 games (3 per conference)
  ///      AFC: #2 vs #7, #3 vs #6, #4 vs #5
  ///      NFC: #2 vs #7, #3 vs #6, #4 vs #5
  ///      (#1 seeds receive a first-round bye)
  ///
  ///   2. Divisional Round — 4 games (2 per conference)
  ///      ⚠️ RESEEDED: #1 plays the lowest remaining seed; the other
  ///      two surviving wild-card winners play each other (higher seed hosts).
  ///
  ///   3. Conference Championship — 2 games (AFC + NFC)
  ///      Higher remaining seed hosts.
  ///
  ///   4. Super Bowl — 1 game (AFC champion vs NFC champion, neutral site)
  ///
  /// **Key: The NFL does NOT use a fixed bracket.**  After the Wild Card round
  /// the bracket resets/reseeds so that the #1 seed always plays the weakest
  /// survivor.  This means the Divisional matchups cannot be known before
  /// Wild Card results are in.  Our bracket flow should surface this to users.
  ///
  /// `defaultTeams` is laid out as Wild Card matchups within each conference
  /// (#1 Bye → separate, then #2 vs #7, #3 vs #6, #4 vs #5).
  static const nflPlayoffs = BracketTemplate(
    id: 'nfl_playoffs',
    name: 'NFL Playoffs',
    sport: 'Football',
    icon: 'sports_football',
    teamCount: 14,
    reseeds: true,
    reseedAfterRound: 'Wild Card',
    description:
        '14-team NFL Playoff bracket. Wild Card, Divisional, Conference '
        'Championship, and Super Bowl. #1 seeds in each conference receive a '
        'first-round bye. The bracket reseeds after the Wild Card round so the '
        '#1 seed faces the lowest remaining seed in the Divisional round.',
    category: 'football',
    defaultTeams: [
      // ─── AFC ─── (ordered by Wild Card matchups)
      '(1) AFC #1 (Bye)',  // Bye — enters at Divisional
      '(2) AFC #2',  '(7) AFC #7',   // WC game 1
      '(3) AFC #3',  '(6) AFC #6',   // WC game 2
      '(4) AFC #4',  '(5) AFC #5',   // WC game 3

      // ─── NFC ─── (ordered by Wild Card matchups)
      '(1) NFC #1 (Bye)',  // Bye — enters at Divisional
      '(2) NFC #2',  '(7) NFC #7',   // WC game 4
      '(3) NFC #3',  '(6) NFC #6',   // WC game 5
      '(4) NFC #4',  '(5) NFC #5',   // WC game 6
    ],
  );

  static const cfbPlayoff = BracketTemplate(
    id: 'cfb_playoff',
    name: 'College Football Playoff',
    sport: 'Football',
    icon: 'sports_football',
    teamCount: 12,
    description: '12-team College Football Playoff bracket with first-round byes for top 4 seeds.',
    category: 'football',
    defaultTeams: [
      '(1) #1 Seed (Bye)', '(2) #2 Seed (Bye)', '(3) #3 Seed (Bye)', '(4) #4 Seed (Bye)',
      '(5) #5 Seed', '(12) #12 Seed', '(6) #6 Seed', '(11) #11 Seed',
      '(7) #7 Seed', '(10) #10 Seed', '(8) #8 Seed', '(9) #9 Seed',
    ],
  );

  static const nbaPlayoffs = BracketTemplate(
    id: 'nba_playoffs',
    name: 'NBA Playoffs',
    sport: 'Basketball',
    icon: 'sports_basketball',
    teamCount: 16,
    description: '16-team NBA Playoff bracket. First round through the NBA Finals.',
    category: 'basketball',
    defaultTeams: [
      '(1) East #1', '(8) East #8', '(4) East #4', '(5) East #5',
      '(3) East #3', '(6) East #6', '(2) East #2', '(7) East #7',
      '(1) West #1', '(8) West #8', '(4) West #4', '(5) West #5',
      '(3) West #3', '(6) West #6', '(2) West #2', '(7) West #7',
    ],
  );

  static const nbaInSeason = BracketTemplate(
    id: 'nba_in_season',
    name: 'NBA In-Season Tournament',
    sport: 'Basketball',
    icon: 'sports_basketball',
    teamCount: 8,
    description: '8-team NBA Cup knockout stage bracket.',
    category: 'basketball',
    defaultTeams: [
      'East Group A', 'East Group B', 'East Wild Card', 'West Wild Card',
      'West Group A', 'West Group B', 'East Group C', 'West Group C',
    ],
  );

  static const fifaWorldCup = BracketTemplate(
    id: 'fifa_world_cup',
    name: 'FIFA World Cup',
    sport: 'Soccer',
    icon: 'sports_soccer',
    teamCount: 32,
    description: '32-team FIFA World Cup knockout stage bracket. Round of 32 through the Final.',
    category: 'soccer',
    defaultTeams: [
      'Group A 1st', 'Group B 2nd', 'Group C 1st', 'Group D 2nd',
      'Group E 1st', 'Group F 2nd', 'Group G 1st', 'Group H 2nd',
      'Group B 1st', 'Group A 2nd', 'Group D 1st', 'Group C 2nd',
      'Group F 1st', 'Group E 2nd', 'Group H 1st', 'Group G 2nd',
      'Group I 1st', 'Group J 2nd', 'Group K 1st', 'Group L 2nd',
      'Group M 1st', 'Group N 2nd', 'Group O 1st', 'Group P 2nd',
      'Group J 1st', 'Group I 2nd', 'Group L 1st', 'Group K 2nd',
      'Group N 1st', 'Group M 2nd', 'Group P 1st', 'Group O 2nd',
    ],
  );

  static const wimbledon = BracketTemplate(
    id: 'wimbledon',
    name: 'Grand Slam Tennis',
    sport: 'Tennis',
    icon: 'sports_tennis',
    teamCount: 128,
    description: '128-player Grand Slam draw (Wimbledon, US Open, French Open, Australian Open).',
    category: 'tennis',
  );

  static const mlbPlayoffs = BracketTemplate(
    id: 'mlb_playoffs',
    name: 'MLB Playoffs',
    sport: 'Baseball',
    icon: 'sports_baseball',
    teamCount: 12,
    description: '12-team MLB Playoff bracket. Wild Card through World Series.',
    category: 'baseball',
    defaultTeams: [
      '(1) AL #1 (Bye)', '(2) AL #2 (Bye)', '(3) AL #3', '(6) AL #6',
      '(4) AL #4', '(5) AL #5',
      '(1) NL #1 (Bye)', '(2) NL #2 (Bye)', '(3) NL #3', '(6) NL #6',
      '(4) NL #4', '(5) NL #5',
    ],
  );

  static const mastersGolf = BracketTemplate(
    id: 'masters_golf',
    name: 'Golf Match Play',
    sport: 'Golf',
    icon: 'sports_golf',
    teamCount: 64,
    description: '64-player match play bracket for golf tournaments.',
    category: 'golf',
  );

  static const mmaChampionship = BracketTemplate(
    id: 'mma_championship',
    name: 'MMA / UFC Tournament',
    sport: 'MMA',
    icon: 'sports_mma',
    teamCount: 16,
    description: '16-fighter MMA bracket tournament.',
    category: 'other',
  );

  // ═══════════════════════════════════════════════════════════════════
  // ─── 1v1 FIGHT / HEAD-TO-HEAD TEMPLATES ────────────────────────────
  // ═══════════════════════════════════════════════════════════════════

  /// Boxing match — single 1v1 fight bracket.
  static const boxingMatch = BracketTemplate(
    id: 'boxing_1v1',
    name: 'Boxing Match (1v1)',
    sport: 'Boxing',
    icon: 'sports_mma',
    teamCount: 2,
    description: '1v1 boxing match bracket. Pick the winner of a single head-to-head fight.',
    category: 'other',
    defaultTeams: ['Fighter A', 'Fighter B'],
  );

  /// UFC / MMA fight — single 1v1 bout.
  static const ufcFight = BracketTemplate(
    id: 'ufc_1v1',
    name: 'UFC / MMA Fight (1v1)',
    sport: 'MMA',
    icon: 'sports_mma',
    teamCount: 2,
    description: '1v1 UFC or MMA bout. Pick the winner of a single fight.',
    category: 'other',
    defaultTeams: ['Fighter A', 'Fighter B'],
  );

  /// Generic 1v1 head-to-head bracket for any sport or matchup.
  static const headToHead = BracketTemplate(
    id: 'head_to_head_1v1',
    name: 'Head-to-Head (1v1)',
    sport: 'General',
    icon: 'people',
    teamCount: 2,
    description: '1v1 head-to-head matchup. Perfect for any single-game showdown.',
    category: 'other',
    defaultTeams: ['Team A', 'Team B'],
  );

  static const stanleyCup = BracketTemplate(
    id: 'stanley_cup',
    name: 'NHL Stanley Cup Playoffs',
    sport: 'Hockey',
    icon: 'sports_hockey',
    teamCount: 16,
    description: '16-team NHL Stanley Cup Playoff bracket.',
    category: 'other',
    defaultTeams: [
      '(1) East #1', '(8) East WC2', '(2) East #2', '(3) East #3',
      '(4) East WC1', '(5) East #4', '(6) East Div 1', '(7) East Div 2',
      '(1) West #1', '(8) West WC2', '(2) West #2', '(3) West #3',
      '(4) West WC1', '(5) West #4', '(6) West Div 1', '(7) West Div 2',
    ],
  );

  /// All available templates
  static const List<BracketTemplate> allTemplates = [
    marchmadness,
    ncaaWomensBB,
    nitTournament,
    nflPlayoffs,
    cfbPlayoff,
    nbaPlayoffs,
    nbaInSeason,
    fifaWorldCup,
    wimbledon,
    mlbPlayoffs,
    mastersGolf,
    stanleyCup,
    mmaChampionship,
    // 1v1 Fight / Head-to-Head
    boxingMatch,
    ufcFight,
    headToHead,
  ];

  /// Common custom bracket sizes for "Build Your Own"
  /// 2 = 1v1 (boxing, UFC, head-to-head matchups)
  static const List<int> customSizes = [2, 4, 8, 16, 32, 64, 128, 256];
}

// ═══════════════════════════════════════════════════════════════════════
// ─── VOTING BRACKET TEMPLATES ─────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Pre-built voting bracket templates that businesses & individuals can
/// use to quickly launch a community-voted bracket.
///
/// Categories:
///   'business_food'       – Restaurant / bar / café menu brackets
///   'business_products'   – Retail & product brackets
///   'business_services'   – Service-based business brackets
///   'entertainment'       – Movies, TV shows, streaming
///   'music'               – Songs, albums, artists
///   'sports'              – Athlete/team popularity votes
///   'holidays'            – Holiday-themed brackets
///   'lifestyle'           – Travel, fashion, pop culture
///   'fun'                 – Icebreakers, debates, hypotheticals
class VotingTemplate {
  final String id;
  final String name;
  final String description;
  final String icon;        // Material icon name hint
  final String category;    // category key from above
  final String audience;    // 'business' | 'individual' | 'both'
  final int itemCount;
  final List<String> defaultItems;

  const VotingTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.audience,
    required this.itemCount,
    required this.defaultItems,
  });

  // ─── CATEGORY METADATA ──────────────────────────────────────────
  static const List<VotingCategory> categories = [
    VotingCategory(id: 'business_food', label: 'Food & Drink', icon: 'restaurant', audience: 'business'),
    VotingCategory(id: 'business_products', label: 'Products', icon: 'storefront', audience: 'business'),
    VotingCategory(id: 'business_services', label: 'Services', icon: 'business_center', audience: 'business'),
    VotingCategory(id: 'entertainment', label: 'Movies & TV', icon: 'movie', audience: 'individual'),
    VotingCategory(id: 'music', label: 'Music', icon: 'music_note', audience: 'individual'),
    VotingCategory(id: 'sports', label: 'Sports', icon: 'sports', audience: 'individual'),
    VotingCategory(id: 'holidays', label: 'Holidays', icon: 'celebration', audience: 'both'),
    VotingCategory(id: 'lifestyle', label: 'Lifestyle', icon: 'favorite', audience: 'individual'),
    VotingCategory(id: 'fun', label: 'Fun & Debates', icon: 'emoji_emotions', audience: 'both'),
  ];

  // ═══════════════════════════════════════════════════════════════════
  // BUSINESS — FOOD & DRINK
  // ═══════════════════════════════════════════════════════════════════

  static const bestMenuItem = VotingTemplate(
    id: 'vote_best_menu_item',
    name: 'Best Menu Item',
    description: 'Let your customers vote on the #1 dish on your menu. Perfect for restaurants, cafes, and food trucks.',
    icon: 'restaurant_menu',
    category: 'business_food',
    audience: 'business',
    itemCount: 16,
    defaultItems: [
      'Signature Burger', 'Grilled Salmon', 'Chicken Alfredo', 'Fish Tacos',
      'BBQ Ribs', 'Caesar Salad', 'Margherita Pizza', 'Steak & Fries',
      'Shrimp Scampi', 'Chicken Wings', 'Mac & Cheese', 'Lobster Roll',
      'Pulled Pork Sandwich', 'Loaded Nachos', 'Truffle Fries', 'Cobb Salad',
    ],
  );

  static const bestCocktail = VotingTemplate(
    id: 'vote_best_cocktail',
    name: 'Best Cocktail / Drink',
    description: 'Find out which drink your patrons love most. Great for bars, breweries, and juice bars.',
    icon: 'local_bar',
    category: 'business_food',
    audience: 'business',
    itemCount: 16,
    defaultItems: [
      'Margarita', 'Old Fashioned', 'Mojito', 'Espresso Martini',
      'Piña Colada', 'Manhattan', 'Moscow Mule', 'Whiskey Sour',
      'Negroni', 'Cosmopolitan', 'Daiquiri', 'Mai Tai',
      'Paloma', 'Aperol Spritz', 'Tom Collins', 'French 75',
    ],
  );

  static const bestDessert = VotingTemplate(
    id: 'vote_best_dessert',
    name: 'Best Dessert',
    description: 'Which sweet treat reigns supreme? Let customers vote for the ultimate dessert.',
    icon: 'cake',
    category: 'business_food',
    audience: 'business',
    itemCount: 16,
    defaultItems: [
      'Chocolate Lava Cake', 'Tiramisu', 'Cheesecake', 'Crème Brûlée',
      'Brownie Sundae', 'Key Lime Pie', 'Apple Pie', 'Ice Cream Sampler',
      'Churros', 'Panna Cotta', 'Red Velvet Cake', 'Banana Pudding',
      'Cannoli', 'Gelato Flight', 'Bread Pudding', 'Carrot Cake',
    ],
  );

  static const bestCoffee = VotingTemplate(
    id: 'vote_best_coffee',
    name: 'Best Coffee Drink',
    description: 'Which coffee drink do your customers crave? Ideal for coffee shops and cafes.',
    icon: 'coffee',
    category: 'business_food',
    audience: 'business',
    itemCount: 16,
    defaultItems: [
      'Iced Latte', 'Cappuccino', 'Cold Brew', 'Caramel Macchiato',
      'Flat White', 'Americano', 'Mocha', 'Espresso',
      'Matcha Latte', 'Pumpkin Spice Latte', 'Vanilla Latte', 'Chai Latte',
      'Nitro Cold Brew', 'Affogato', 'Irish Coffee', 'Cortado',
    ],
  );

  static const bestBeer = VotingTemplate(
    id: 'vote_best_beer',
    name: 'Best Beer on Tap',
    description: 'Which brew is king? Let your customers pick the best beer on tap.',
    icon: 'sports_bar',
    category: 'business_food',
    audience: 'business',
    itemCount: 16,
    defaultItems: [
      'House IPA', 'Pilsner', 'Stout', 'Wheat Beer',
      'Pale Ale', 'Amber Ale', 'Porter', 'Lager',
      'Sour Ale', 'Belgian Tripel', 'Hazy IPA', 'Brown Ale',
      'Hefeweizen', 'Blonde Ale', 'Red Ale', 'Double IPA',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // BUSINESS — PRODUCTS
  // ═══════════════════════════════════════════════════════════════════

  static const bestProduct = VotingTemplate(
    id: 'vote_best_product',
    name: 'Best Product',
    description: 'Discover which product your audience loves. Use for any retail, e-commerce, or subscription business.',
    icon: 'storefront',
    category: 'business_products',
    audience: 'business',
    itemCount: 16,
    defaultItems: [
      'Product A', 'Product B', 'Product C', 'Product D',
      'Product E', 'Product F', 'Product G', 'Product H',
      'Product I', 'Product J', 'Product K', 'Product L',
      'Product M', 'Product N', 'Product O', 'Product P',
    ],
  );

  static const bestNewFeature = VotingTemplate(
    id: 'vote_best_feature',
    name: 'Best New Feature',
    description: 'Let your users vote on which feature to build next. Great for SaaS, apps, and tech products.',
    icon: 'build_circle',
    category: 'business_products',
    audience: 'business',
    itemCount: 8,
    defaultItems: [
      'Dark Mode', 'Offline Access', 'Custom Themes', 'Social Sharing',
      'Push Notifications', 'Analytics Dashboard', 'Team Collaboration', 'AI Suggestions',
    ],
  );

  static const bestBrandDesign = VotingTemplate(
    id: 'vote_best_brand',
    name: 'Best Brand / Logo',
    description: 'Crowdsource opinions on brand designs, logos, or packaging options.',
    icon: 'palette',
    category: 'business_products',
    audience: 'business',
    itemCount: 8,
    defaultItems: [
      'Design A', 'Design B', 'Design C', 'Design D',
      'Design E', 'Design F', 'Design G', 'Design H',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // BUSINESS — SERVICES
  // ═══════════════════════════════════════════════════════════════════

  static const bestClassWorkout = VotingTemplate(
    id: 'vote_best_class',
    name: 'Best Class / Workout',
    description: 'Gyms, studios, and schools: let members vote on their favorite class.',
    icon: 'fitness_center',
    category: 'business_services',
    audience: 'business',
    itemCount: 8,
    defaultItems: [
      'HIIT', 'Yoga Flow', 'Spin Class', 'Pilates',
      'CrossFit', 'Zumba', 'Boxing', 'Barre',
    ],
  );

  static const bestEvent = VotingTemplate(
    id: 'vote_best_event',
    name: 'Best Event Idea',
    description: 'Let your community vote on the next event, theme night, or fundraiser idea.',
    icon: 'event',
    category: 'business_services',
    audience: 'business',
    itemCount: 8,
    defaultItems: [
      'Trivia Night', 'Live Music', 'Karaoke Night', 'Wine Tasting',
      'Open Mic', 'Game Night', 'Comedy Show', 'Dance Party',
    ],
  );

  static const bestLocalBusiness = VotingTemplate(
    id: 'vote_best_local',
    name: 'Best Local Spot',
    description: 'Neighborhood showdown: let the community vote on the best local businesses.',
    icon: 'place',
    category: 'business_services',
    audience: 'both',
    itemCount: 16,
    defaultItems: [
      'Best Pizza Place', 'Best Burger Joint', 'Best Coffee Shop', 'Best Taco Spot',
      'Best Bakery', 'Best BBQ', 'Best Sushi', 'Best Italian',
      'Best Brunch', 'Best Bar', 'Best Food Truck', 'Best Ice Cream',
      'Best Deli', 'Best Thai', 'Best Mexican', 'Best Seafood',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // ENTERTAINMENT — MOVIES & TV
  // ═══════════════════════════════════════════════════════════════════

  static const favoriteMovie = VotingTemplate(
    id: 'vote_fav_movie',
    name: 'Favorite Movie',
    description: 'The ultimate movie showdown. Which film deserves the crown?',
    icon: 'movie',
    category: 'entertainment',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'The Shawshank Redemption', 'The Dark Knight', 'Inception', 'Pulp Fiction',
      'Forrest Gump', 'The Godfather', 'Titanic', 'Jurassic Park',
      'The Lion King', 'Avengers: Endgame', 'Gladiator', 'The Matrix',
      'Interstellar', 'Goodfellas', 'Back to the Future', 'Fight Club',
    ],
  );

  static const bestActionMovie = VotingTemplate(
    id: 'vote_best_action',
    name: 'Best Action Movie',
    description: 'Explosions, car chases, and epic battles. Which action film is the GOAT?',
    icon: 'local_fire_department',
    category: 'entertainment',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Die Hard', 'Mad Max: Fury Road', 'John Wick', 'Top Gun: Maverick',
      'The Dark Knight', 'Terminator 2', 'Mission: Impossible - Fallout', 'Gladiator',
      'The Matrix', 'Aliens', 'Kill Bill Vol. 1', 'Inception',
      'Raiders of the Lost Ark', 'Lethal Weapon', 'Speed', 'The Bourne Identity',
    ],
  );

  static const bestComedyMovie = VotingTemplate(
    id: 'vote_best_comedy',
    name: 'Best Comedy Movie',
    description: 'Which comedy had you laughing the hardest? Settle the debate.',
    icon: 'sentiment_very_satisfied',
    category: 'entertainment',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Superbad', 'The Hangover', 'Step Brothers', 'Bridesmaids',
      'Anchorman', 'Mean Girls', 'Dumb and Dumber', 'Coming to America',
      'Friday', 'Happy Gilmore', 'Airplane!', 'Borat',
      'Ghostbusters', 'Caddyshack', '21 Jump Street', 'Wedding Crashers',
    ],
  );

  static const bestTvShow = VotingTemplate(
    id: 'vote_best_tv',
    name: 'Best TV Show',
    description: 'From dramas to sitcoms, which show is the greatest of all time?',
    icon: 'tv',
    category: 'entertainment',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Breaking Bad', 'Game of Thrones', 'The Office', 'Friends',
      'Stranger Things', 'The Sopranos', 'Seinfeld', 'The Wire',
      'Yellowstone', 'Ted Lasso', 'Succession', 'The Last of Us',
      'Squid Game', 'Wednesday', 'Cobra Kai', 'Ozark',
    ],
  );

  static const bestAnimatedMovie = VotingTemplate(
    id: 'vote_best_animated',
    name: 'Best Animated Movie',
    description: 'Pixar vs Disney vs DreamWorks vs anime. Which animated film wins?',
    icon: 'animation',
    category: 'entertainment',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'The Lion King', 'Toy Story', 'Shrek', 'Finding Nemo',
      'Spirited Away', 'Up', 'Frozen', 'Inside Out',
      'Coco', 'How to Train Your Dragon', 'Spider-Verse', 'Ratatouille',
      'Moana', 'Monsters, Inc.', 'The Incredibles', 'WALL-E',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // MUSIC
  // ═══════════════════════════════════════════════════════════════════

  static const favoriteSong = VotingTemplate(
    id: 'vote_fav_song',
    name: 'Favorite Song',
    description: 'Which song is the ultimate banger? Let the people decide.',
    icon: 'music_note',
    category: 'music',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Bohemian Rhapsody', 'Billie Jean', 'Hotel California', 'Smells Like Teen Spirit',
      'Imagine', 'Hey Jude', 'Superstition', 'Purple Rain',
      'Lose Yourself', 'Sweet Child O\' Mine', 'Rolling in the Deep', 'Shape of You',
      'Blinding Lights', 'Uptown Funk', 'Mr. Brightside', 'Stairway to Heaven',
    ],
  );

  static const best80sSong = VotingTemplate(
    id: 'vote_best_80s_song',
    name: 'Best 80s Song',
    description: 'Synths, big hair, and unforgettable hooks. Vote for the best 80s anthem.',
    icon: 'queue_music',
    category: 'music',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Take On Me', 'Don\'t Stop Believin\'', 'Livin\' on a Prayer', 'Sweet Child O\' Mine',
      'Every Breath You Take', 'Billie Jean', 'Jump', 'Girls Just Want to Have Fun',
      'Come On Eileen', 'Eye of the Tiger', 'Walk Like an Egyptian', 'Total Eclipse of the Heart',
      'I Love Rock \'n\' Roll', 'Africa', 'Under Pressure', 'Purple Rain',
    ],
  );

  static const best90sSong = VotingTemplate(
    id: 'vote_best_90s_song',
    name: 'Best 90s Song',
    description: 'Grunge, hip-hop, pop, and R&B. Which 90s track is the GOAT?',
    icon: 'queue_music',
    category: 'music',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Smells Like Teen Spirit', 'Wonderwall', 'No Diggity', 'Waterfalls',
      'Baby One More Time', 'Creep', 'Jump Around', 'Gangsta\'s Paradise',
      'Livin\' La Vida Loca', 'Semi-Charmed Life', 'Iris', 'Mo Money Mo Problems',
      'I Want It That Way', 'Killing Me Softly', 'Bittersweet Symphony', 'Lose Yourself',
    ],
  );

  static const bestRapAlbum = VotingTemplate(
    id: 'vote_best_rap_album',
    name: 'Best Rap / Hip-Hop Album',
    description: 'Classic vs modern. Which hip-hop album is the greatest?',
    icon: 'album',
    category: 'music',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Illmatic', 'The Blueprint', 'good kid, m.A.A.d city', 'The Marshall Mathers LP',
      'Ready to Die', 'All Eyez on Me', 'My Beautiful Dark Twisted Fantasy', 'Reasonable Doubt',
      'Aquemini', 'The Chronic', 'To Pimp a Butterfly', 'Get Rich or Die Tryin\'',
      'The College Dropout', 'Doggystyle', 'Enter the Wu-Tang', 'Astroworld',
    ],
  );

  static const bestArtist = VotingTemplate(
    id: 'vote_best_artist',
    name: 'Best Music Artist',
    description: 'Who is the greatest musical artist of all time? Settle it with a vote.',
    icon: 'mic',
    category: 'music',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Michael Jackson', 'Beyoncé', 'Drake', 'Taylor Swift',
      'The Beatles', 'Eminem', 'Rihanna', 'Jay-Z',
      'Prince', 'Kendrick Lamar', 'Whitney Houston', 'Kanye West',
      'Stevie Wonder', 'Adele', 'Bob Marley', 'Freddie Mercury',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // SPORTS
  // ═══════════════════════════════════════════════════════════════════

  static const favoriteAthlete = VotingTemplate(
    id: 'vote_fav_athlete',
    name: 'Favorite Athlete',
    description: 'Who is the greatest athlete? Cross-sport showdown decided by popular vote.',
    icon: 'sports',
    category: 'sports',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'LeBron James', 'Michael Jordan', 'Tom Brady', 'Serena Williams',
      'Lionel Messi', 'Cristiano Ronaldo', 'Muhammad Ali', 'Kobe Bryant',
      'Wayne Gretzky', 'Mike Tyson', 'Usain Bolt', 'Tiger Woods',
      'Patrick Mahomes', 'Steph Curry', 'Shaquille O\'Neal', 'Derek Jeter',
    ],
  );

  static const goatNba = VotingTemplate(
    id: 'vote_goat_nba',
    name: 'NBA GOAT',
    description: 'Jordan? LeBron? Kobe? Settle the NBA GOAT debate once and for all.',
    icon: 'sports_basketball',
    category: 'sports',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Michael Jordan', 'LeBron James', 'Kobe Bryant', 'Kareem Abdul-Jabbar',
      'Magic Johnson', 'Larry Bird', 'Tim Duncan', 'Shaquille O\'Neal',
      'Steph Curry', 'Wilt Chamberlain', 'Bill Russell', 'Kevin Durant',
      'Hakeem Olajuwon', 'Allen Iverson', 'Giannis Antetokounmpo', 'Nikola Jokic',
    ],
  );

  static const goatNfl = VotingTemplate(
    id: 'vote_goat_nfl',
    name: 'NFL GOAT',
    description: 'Who is the greatest football player ever? Let the fans decide.',
    icon: 'sports_football',
    category: 'sports',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Tom Brady', 'Jerry Rice', 'Jim Brown', 'Joe Montana',
      'Patrick Mahomes', 'Walter Payton', 'Peyton Manning', 'Lawrence Taylor',
      'Barry Sanders', 'Johnny Unitas', 'Deion Sanders', 'Aaron Donald',
      'Emmitt Smith', 'Dick Butkus', 'Randy Moss', 'Ray Lewis',
    ],
  );

  static const bestNbaTeam = VotingTemplate(
    id: 'vote_best_nba_team',
    name: 'Best NBA Team (All-Time)',
    description: 'Which NBA franchise is the most loved? Vote for your favorite.',
    icon: 'sports_basketball',
    category: 'sports',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Los Angeles Lakers', 'Boston Celtics', 'Chicago Bulls', 'Golden State Warriors',
      'Miami Heat', 'San Antonio Spurs', 'Philadelphia 76ers', 'New York Knicks',
      'Dallas Mavericks', 'Brooklyn Nets', 'Denver Nuggets', 'Milwaukee Bucks',
      'Houston Rockets', 'Phoenix Suns', 'Toronto Raptors', 'Cleveland Cavaliers',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // HOLIDAYS
  // ═══════════════════════════════════════════════════════════════════

  static const bestChristmasMovie = VotingTemplate(
    id: 'vote_best_xmas_movie',
    name: 'Best Christmas Movie',
    description: 'Home Alone vs Elf vs Die Hard. Settle the holiday movie debate.',
    icon: 'ac_unit',
    category: 'holidays',
    audience: 'both',
    itemCount: 16,
    defaultItems: [
      'Home Alone', 'Elf', 'A Christmas Story', 'It\'s a Wonderful Life',
      'Die Hard', 'The Polar Express', 'How the Grinch Stole Christmas', 'Miracle on 34th Street',
      'National Lampoon\'s Christmas Vacation', 'The Santa Clause', 'Rudolph the Red-Nosed Reindeer', 'A Charlie Brown Christmas',
      'Love Actually', 'Scrooged', 'The Nightmare Before Christmas', 'White Christmas',
    ],
  );

  static const bestChristmasSong = VotingTemplate(
    id: 'vote_best_xmas_song',
    name: 'Best Christmas Song',
    description: 'Jingle Bells to All I Want for Christmas. Which holiday tune is #1?',
    icon: 'audiotrack',
    category: 'holidays',
    audience: 'both',
    itemCount: 16,
    defaultItems: [
      'All I Want for Christmas Is You', 'Jingle Bell Rock', 'Rockin\' Around the Christmas Tree', 'Last Christmas',
      'White Christmas', 'Santa Baby', 'Let It Snow!', 'Rudolph the Red-Nosed Reindeer',
      'Feliz Navidad', 'Silent Night', 'Have Yourself a Merry Little Christmas', 'The Christmas Song',
      'Winter Wonderland', 'Frosty the Snowman', 'Jingle Bells', 'O Holy Night',
    ],
  );

  static const bestHalloweenCostume = VotingTemplate(
    id: 'vote_best_costume',
    name: 'Best Halloween Costume',
    description: 'Spooky season: vote for the best costume idea or theme.',
    icon: 'face_retouching_natural',
    category: 'holidays',
    audience: 'both',
    itemCount: 16,
    defaultItems: [
      'Zombie', 'Vampire', 'Witch', 'Superhero',
      'Ghost', 'Pirate', 'Skeleton', 'Werewolf',
      'Clown', 'Alien', 'Mummy', 'Princess',
      'Ninja', 'Cowboy', 'Robot', 'Dinosaur',
    ],
  );

  static const bestThanksgivingDish = VotingTemplate(
    id: 'vote_best_thanksgiving',
    name: 'Best Thanksgiving Dish',
    description: 'Turkey vs mac & cheese vs sweet potato pie. The ultimate Thanksgiving showdown.',
    icon: 'dinner_dining',
    category: 'holidays',
    audience: 'both',
    itemCount: 16,
    defaultItems: [
      'Turkey', 'Mac & Cheese', 'Mashed Potatoes', 'Stuffing / Dressing',
      'Sweet Potato Pie', 'Pumpkin Pie', 'Cranberry Sauce', 'Green Bean Casserole',
      'Cornbread', 'Gravy', 'Deviled Eggs', 'Dinner Rolls',
      'Candied Yams', 'Pecan Pie', 'Ham', 'Collard Greens',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // LIFESTYLE
  // ═══════════════════════════════════════════════════════════════════

  static const bestVacationSpot = VotingTemplate(
    id: 'vote_best_vacation',
    name: 'Best Vacation Destination',
    description: 'Beach vs city vs mountains. Where would your audience rather go?',
    icon: 'flight',
    category: 'lifestyle',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Hawaii', 'Cancun', 'Paris', 'Tokyo',
      'Bahamas', 'London', 'Bali', 'Maldives',
      'New York City', 'Dubai', 'Rome', 'Barcelona',
      'Miami', 'Santorini', 'Bora Bora', 'Iceland',
    ],
  );

  static const bestFastFood = VotingTemplate(
    id: 'vote_best_fast_food',
    name: 'Best Fast Food Chain',
    description: 'Chick-fil-A vs McDonald\'s vs In-N-Out. Crown the fast food king.',
    icon: 'fastfood',
    category: 'lifestyle',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Chick-fil-A', 'McDonald\'s', 'In-N-Out', 'Wendy\'s',
      'Five Guys', 'Taco Bell', 'Popeyes', 'Chipotle',
      'Raising Cane\'s', 'Whataburger', 'Shake Shack', 'Panda Express',
      'Subway', 'Wingstop', 'Sonic', 'Culver\'s',
    ],
  );

  static const bestSneaker = VotingTemplate(
    id: 'vote_best_sneaker',
    name: 'Best Sneaker',
    description: 'Jordans, Yeezys, Dunks, or New Balance? Sneakerheads unite and vote.',
    icon: 'directions_run',
    category: 'lifestyle',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'Air Jordan 1', 'Yeezy 350', 'Nike Dunk Low', 'Air Force 1',
      'New Balance 550', 'Nike Air Max 90', 'Converse Chuck Taylor', 'Adidas Superstar',
      'Jordan 4', 'Nike Cortez', 'Vans Old Skool', 'Adidas Samba',
      'Air Jordan 11', 'Nike SB Dunk', 'Reebok Classic', 'Puma Suede',
    ],
  );

  static const bestVideoGame = VotingTemplate(
    id: 'vote_best_game',
    name: 'Best Video Game',
    description: 'GTA vs Zelda vs Minecraft. Which game is the GOAT?',
    icon: 'sports_esports',
    category: 'lifestyle',
    audience: 'individual',
    itemCount: 16,
    defaultItems: [
      'GTA V', 'Minecraft', 'The Legend of Zelda: BOTW', 'Red Dead Redemption 2',
      'God of War Ragnarök', 'Elden Ring', 'The Witcher 3', 'Fortnite',
      'Super Mario Odyssey', 'The Last of Us', 'Halo 3', 'Skyrim',
      'Call of Duty: Modern Warfare', 'Spider-Man 2', 'Cyberpunk 2077', 'Pokémon Gold/Silver',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // FUN & DEBATES
  // ═══════════════════════════════════════════════════════════════════

  static const bestSuperhero = VotingTemplate(
    id: 'vote_best_superhero',
    name: 'Best Superhero',
    description: 'Marvel vs DC. Who is the ultimate superhero? Vote now.',
    icon: 'shield',
    category: 'fun',
    audience: 'both',
    itemCount: 16,
    defaultItems: [
      'Spider-Man', 'Batman', 'Superman', 'Iron Man',
      'Wolverine', 'Captain America', 'Thor', 'Wonder Woman',
      'Black Panther', 'The Flash', 'Deadpool', 'Hulk',
      'Aquaman', 'Doctor Strange', 'Green Lantern', 'Ant-Man',
    ],
  );

  static const bestIcebreaker = VotingTemplate(
    id: 'vote_best_icebreaker',
    name: 'Would You Rather',
    description: 'Fun "would you rather" matchups. Great for team-building, parties, and engagement.',
    icon: 'help_outline',
    category: 'fun',
    audience: 'both',
    itemCount: 8,
    defaultItems: [
      'Fly', 'Be Invisible',
      'Time Travel', 'Read Minds',
      'Live at the Beach', 'Live in the Mountains',
      'Be Famous', 'Be Wealthy',
    ],
  );

  static const bestSuperpower = VotingTemplate(
    id: 'vote_best_superpower',
    name: 'Best Superpower',
    description: 'If you could have any superpower, which would you choose?',
    icon: 'flash_on',
    category: 'fun',
    audience: 'both',
    itemCount: 16,
    defaultItems: [
      'Flying', 'Invisibility', 'Super Speed', 'Time Travel',
      'Teleportation', 'Mind Reading', 'Super Strength', 'Shapeshifting',
      'Healing Factor', 'Telekinesis', 'Fire Control', 'Ice Control',
      'X-Ray Vision', 'Elasticity', 'Cloning', 'Immortality',
    ],
  );

  static const bestDecade = VotingTemplate(
    id: 'vote_best_decade',
    name: 'Best Decade',
    description: 'Which decade had the best music, fashion, culture, and vibes?',
    icon: 'access_time',
    category: 'fun',
    audience: 'both',
    itemCount: 8,
    defaultItems: [
      '1960s', '1970s', '1980s', '1990s',
      '2000s', '2010s', '2020s', '1950s',
    ],
  );

  static const bestCereal = VotingTemplate(
    id: 'vote_best_cereal',
    name: 'Best Cereal',
    description: 'Childhood nostalgia meets taste buds. Which cereal takes the crown?',
    icon: 'breakfast_dining',
    category: 'fun',
    audience: 'both',
    itemCount: 16,
    defaultItems: [
      'Cinnamon Toast Crunch', 'Frosted Flakes', 'Lucky Charms', 'Fruity Pebbles',
      'Honey Nut Cheerios', 'Froot Loops', 'Cocoa Puffs', 'Cap\'n Crunch',
      'Reese\'s Puffs', 'Apple Jacks', 'Rice Krispies', 'Frosted Mini-Wheats',
      'Corn Flakes', 'Raisin Bran', 'Cookie Crisp', 'Cheerios',
    ],
  );

  // ═══════════════════════════════════════════════════════════════════
  // BLANK / CUSTOM
  // ═══════════════════════════════════════════════════════════════════

  static const blankVoting = VotingTemplate(
    id: 'vote_blank',
    name: 'Blank Voting Bracket',
    description: 'Start from scratch. Add your own items and let the community vote.',
    icon: 'add_circle_outline',
    category: 'custom',
    audience: 'both',
    itemCount: 16,
    defaultItems: [],
  );

  // ─── MASTER LIST (ordered by category for display) ──────────────

  static const List<VotingTemplate> allTemplates = [
    // Business — Food & Drink
    bestMenuItem,
    bestCocktail,
    bestDessert,
    bestCoffee,
    bestBeer,
    // Business — Products
    bestProduct,
    bestNewFeature,
    bestBrandDesign,
    // Business — Services
    bestClassWorkout,
    bestEvent,
    bestLocalBusiness,
    // Entertainment
    favoriteMovie,
    bestActionMovie,
    bestComedyMovie,
    bestTvShow,
    bestAnimatedMovie,
    // Music
    favoriteSong,
    best80sSong,
    best90sSong,
    bestRapAlbum,
    bestArtist,
    // Sports
    favoriteAthlete,
    goatNba,
    goatNfl,
    bestNbaTeam,
    // Holidays
    bestChristmasMovie,
    bestChristmasSong,
    bestHalloweenCostume,
    bestThanksgivingDish,
    // Lifestyle
    bestVacationSpot,
    bestFastFood,
    bestSneaker,
    bestVideoGame,
    // Fun & Debates
    bestSuperhero,
    bestIcebreaker,
    bestSuperpower,
    bestDecade,
    bestCereal,
    // Custom
    blankVoting,
  ];

  /// Convenience: templates filtered by audience
  static List<VotingTemplate> get businessTemplates =>
      allTemplates.where((t) => t.audience == 'business' || t.audience == 'both').toList();
  static List<VotingTemplate> get individualTemplates =>
      allTemplates.where((t) => t.audience == 'individual' || t.audience == 'both').toList();

  /// Templates for a specific category
  static List<VotingTemplate> forCategory(String categoryId) =>
      allTemplates.where((t) => t.category == categoryId).toList();
}

/// Category metadata for display
class VotingCategory {
  final String id;
  final String label;
  final String icon;
  final String audience; // 'business', 'individual', 'both'
  const VotingCategory({required this.id, required this.label, required this.icon, required this.audience});
}

/// Represents a play-in game that feeds into the main bracket.
class PlayInGame {
  final String id;
  final String team1;
  final String team2;
  final int mainBracketSlot; // index in the defaultTeams list where the winner goes
  final String region;
  final int seedSlot; // seed number the winner will carry (e.g. 16 or 11)

  const PlayInGame({
    required this.id,
    required this.team1,
    required this.team2,
    required this.mainBracketSlot,
    required this.region,
    required this.seedSlot,
  });
}
