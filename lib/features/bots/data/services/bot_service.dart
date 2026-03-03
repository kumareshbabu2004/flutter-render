import 'dart:math';

/// Bot account strategy for BMB:
/// 1. Hosting Bots: Create and host brackets regularly (BMB Official account)
/// 2. Participant Bots: Join FREE brackets as "people", auto-pick, engage in chat
/// 3. Community Bots: Post in community chat for engagement

class BotService {
  static final BotService _instance = BotService._internal();
  factory BotService() => _instance;
  BotService._internal();

  static final _random = Random();

  /// All bot accounts with personas
  static const List<BotAccount> allBots = [
    // ─── HOSTING BOTS (BMB Official) ───
    BotAccount(
      id: 'bot_bmb_official',
      username: 'BackMyBracket',
      displayName: 'Back My Bracket',
      state: 'US',
      role: BotRole.host,
      bio: 'Official BMB brackets. Join the action!',
      isVerified: true,
    ),
    BotAccount(
      id: 'bot_bmb_sports',
      username: 'BMBSports',
      displayName: 'BMB Sports Desk',
      state: 'US',
      role: BotRole.host,
      bio: 'Your source for BMB tournament brackets.',
      isVerified: true,
    ),

    // ─── REALISTIC "HUMAN" BOT ACCOUNTS (host + join) ───
    BotAccount(
      id: 'bot_marcus',
      username: 'MarcBuckets',
      displayName: 'Marc_Buckets',
      state: 'TX',
      role: BotRole.hostAndParticipant,
      bio: 'Houston hooper. Stats nerd. Your bracket ain\'t safe.',
      isVerified: true,
      profileImageUrl: 'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?auto=compress&cs=tinysrgb&w=256&h=256&fit=crop',
    ),
    BotAccount(
      id: 'bot_jess',
      username: 'QueenOfUpsets',
      displayName: 'Queen_of_Upsets',
      state: 'FL',
      role: BotRole.hostAndParticipant,
      bio: 'Upset whisperer. Cinderella believer. Your chalk is boring.',
      isVerified: true,
      profileImageUrl: 'https://images.pexels.com/photos/733872/pexels-photo-733872.jpeg?auto=compress&cs=tinysrgb&w=256&h=256&fit=crop',
    ),

    // ─── PARTICIPANT BOTS (join free brackets) ───
    BotAccount(
      id: 'bot_jam81',
      username: 'JamSession81',
      displayName: 'JamSession81',
      state: 'IL',
      role: BotRole.participant,
      bio: 'Love brackets. Love competition.',
    ),
    BotAccount(
      id: 'bot_swish',
      username: 'SwishKing',
      displayName: 'SwishKing',
      state: 'CA',
      role: BotRole.participant,
      bio: 'Nothing but net. Nothing but Ws.',
    ),
    BotAccount(
      id: 'bot_madness',
      username: 'MarchMadnessMax',
      displayName: 'MarchMadnessMax',
      state: 'NC',
      role: BotRole.participant,
      bio: 'March is MY month.',
    ),
    BotAccount(
      id: 'bot_chalky',
      username: 'ChalkMaster',
      displayName: 'ChalkMaster',
      state: 'TX',
      role: BotRole.participant,
      bio: 'I trust the seeds. Chalk picks forever.',
    ),
    BotAccount(
      id: 'bot_cindy',
      username: 'CinderellaFan',
      displayName: 'CinderellaFan',
      state: 'FL',
      role: BotRole.participant,
      bio: 'Upset city. Always picking the underdog.',
    ),
    BotAccount(
      id: 'bot_stats',
      username: 'StatGuru42',
      displayName: 'StatGuru42',
      state: 'NY',
      role: BotRole.participant,
      bio: 'Analytics-driven picks. Data never lies.',
    ),
    BotAccount(
      id: 'bot_lucky',
      username: 'LuckyBreaks',
      displayName: 'LuckyBreaks',
      state: 'NV',
      role: BotRole.participant,
      bio: 'Feeling lucky! Random picks, real wins.',
    ),
    BotAccount(
      id: 'bot_hoop',
      username: 'HoopDreams99',
      displayName: 'HoopDreams99',
      state: 'OH',
      role: BotRole.participant,
      bio: 'Ball is life. Brackets are love.',
    ),

    // ─── COMMUNITY / CHAT BOTS ───
    BotAccount(
      id: 'bot_hype',
      username: 'BMBHypeMan',
      displayName: 'BMB Hype Man',
      state: 'US',
      role: BotRole.community,
      bio: 'LET\'S GOOO! Keeping the energy high.',
      isVerified: true,
    ),
    BotAccount(
      id: 'bot_trivia',
      username: 'SportsTrivia',
      displayName: 'Sports Trivia Bot',
      state: 'US',
      role: BotRole.community,
      bio: 'Daily sports trivia. Can you beat me?',
      isVerified: true,
    ),
  ];

  /// Get only hosting bots (including dual-role bots)
  static List<BotAccount> get hostingBots =>
      allBots.where((b) => b.role == BotRole.host || b.role == BotRole.hostAndParticipant).toList();

  /// Get only participant bots (including dual-role bots)
  static List<BotAccount> get participantBots =>
      allBots.where((b) => b.role == BotRole.participant || b.role == BotRole.hostAndParticipant).toList();

  /// Get the two realistic "human" bot accounts
  static List<BotAccount> get realisticBots =>
      allBots.where((b) => b.role == BotRole.hostAndParticipant).toList();

  /// Get only community bots
  static List<BotAccount> get communityBots =>
      allBots.where((b) => b.role == BotRole.community).toList();

  /// Select random bots to join a free bracket
  static List<BotAccount> selectBotsForBracket({int count = 5}) {
    final available = List<BotAccount>.from(participantBots)..shuffle(_random);
    return available.take(count.clamp(1, available.length)).toList();
  }

  /// Generate auto-picks for a bot (random picks from available teams)
  static Map<String, String> generateAutoPicks({
    required List<String> teams,
    required int totalRounds,
  }) {
    final picks = <String, String>{};
    var currentTeams = List<String>.from(teams);

    for (int round = 0; round < totalRounds; round++) {
      final nextTeams = <String>[];
      for (int i = 0; i < currentTeams.length; i += 2) {
        if (i + 1 < currentTeams.length) {
          final winner = _random.nextBool() ? currentTeams[i] : currentTeams[i + 1];
          picks['r${round}_g${i ~/ 2}'] = winner;
          nextTeams.add(winner);
        } else {
          nextTeams.add(currentTeams[i]);
        }
      }
      currentTeams = nextTeams;
    }
    return picks;
  }

  /// Generate a random tie-breaker prediction
  static int generateTieBreakerPrediction() {
    return 120 + _random.nextInt(80); // 120-199 total points
  }

  // ─── BOT CREDIT MANAGEMENT ──────────────────────────────────────────
  /// Minimum credit balance bots should always have to join paid tournaments.
  static const int _minBotCredits = 500;
  static const int _botCreditTopUp = 1000;

  /// Map of bot credit balances (simulated — seeded high, auto-topped-up).
  static final Map<String, int> _botCredits = {
    'bot_marcus': 1250,
    'bot_jess': 1100,
  };

  /// Get a bot's current credit balance, auto-topping up if low.
  static int getBotCredits(String botId) {
    final balance = _botCredits[botId] ?? _minBotCredits;
    if (balance < _minBotCredits) {
      _botCredits[botId] = _botCreditTopUp;
      return _botCreditTopUp;
    }
    return balance;
  }

  /// Deduct contribution from a bot's balance. Auto-tops up if needed.
  static bool deductBotCredits(String botId, int amount) {
    var balance = _botCredits[botId] ?? _botCreditTopUp;
    if (balance < amount) {
      // Auto top-up — bots always have enough to play
      balance = _botCreditTopUp;
    }
    _botCredits[botId] = balance - amount;
    return true; // Always succeeds — bots never run out
  }

  /// Award credits to a bot (winnings, trivia rewards, etc.)
  static void awardBotCredits(String botId, int amount) {
    final balance = _botCredits[botId] ?? _botCreditTopUp;
    _botCredits[botId] = balance + amount;
  }

  /// Check if a bot can afford a contribution (always true — auto-tops up).
  static bool canBotAfford(String botId, int entryFee) {
    if (entryFee <= 0) return true;
    final balance = getBotCredits(botId);
    if (balance < entryFee) {
      _botCredits[botId] = _botCreditTopUp;
    }
    return true; // Always returns true — bots auto-fund
  }

  // ─── BOT BRACKET POST GENERATION ─────────────────────────────────
  /// Generate a fake bracket post for Marc_Buckets or Queen_of_Upsets.
  /// These look exactly like real user bracket posts in the community.
  static Map<String, dynamic> generateBotBracketPost(String botId) {
    final bot = allBots.firstWhere((b) => b.id == botId);
    final rng = Random();

    // Pick a realistic bracket and champion
    final brackets = [
      ('NCAA March Madness 2025', 'Basketball', 'Single Elimination'),
      ('NFL Playoff Bracket', 'Football', 'Single Elimination'),
      ('NBA Playoff Predictions', 'Basketball', 'Best of 7'),
      ('College Football Playoff', 'Football', 'Single Elimination'),
      ('March Madness Sweet 16', 'Basketball', 'Single Elimination'),
      ('NIT Tournament 2025', 'Basketball', 'Single Elimination'),
    ];
    final bracket = brackets[rng.nextInt(brackets.length)];

    // Champion picks based on personality
    final marcChampions = ['Houston', 'Duke', 'Kansas', 'UConn', 'Auburn', 'Tennessee', 'Gonzaga', 'Purdue'];
    final jessChampions = ['Vermont', 'Drake', 'Yale', 'New Mexico', 'San Diego St', 'UAB', 'Furman', 'Princeton'];

    final champ = botId == 'bot_marcus'
        ? marcChampions[rng.nextInt(marcChampions.length)]
        : jessChampions[rng.nextInt(jessChampions.length)];

    final totalPicks = 15 + rng.nextInt(48);
    final correct = rng.nextInt((totalPicks * 0.7).round());
    final wrong = rng.nextInt(totalPicks - correct);
    final pending = totalPicks - correct - wrong;

    // Natural-sounding post messages
    final marcMessages = [
      'locked in my picks. not gonna lie, I feel really good about this one',
      'just submitted. ran the numbers all morning and I like where I landed',
      'alright my bracket is in. somebody tell me if I\'m crazy or if this actually makes sense',
      'picks are locked. went back and forth on my Final Four for an hour but I\'m committed now',
      'just turned in my picks. studied the matchups all weekend for this',
    ];
    final jessMessages = [
      'ok my picks are IN and yes there are upsets everywhere. don\'t come for me',
      'just submitted the most chaotic bracket of all time and I regret nothing',
      'locked in! I\'ve got three double-digit seeds in my Sweet 16 and I\'m not sorry',
      'my bracket is done. is it chalk? absolutely not. am I confident? absolutely yes',
      'just posted my picks. if you don\'t have at least two upsets you\'re doing it wrong',
    ];

    final message = botId == 'bot_marcus'
        ? marcMessages[rng.nextInt(marcMessages.length)]
        : jessMessages[rng.nextInt(jessMessages.length)];

    // Generate realistic teams for the bracket tree visual
    final teamSets = <String, List<String>>{
      'Basketball': [
        '(1) Houston', '(16) SIU-E', '(8) Wisconsin', '(9) Drake',
        '(5) Michigan St', '(12) UC Irvine', '(4) Arizona', '(13) Vermont',
      ],
      'Football': [
        '(1) Chiefs', '(8) Texans', '(4) Bills', '(5) Chargers',
        '(3) Lions', '(6) Packers', '(2) Eagles', '(7) Commanders',
      ],
    };
    final teams = List<String>.from(
      teamSets[bracket.$2] ?? teamSets['Basketball']!,
    );
    // Calculate rounds for 8 teams
    final botTotalRounds = 3;
    final botPicks = generateAutoPicks(teams: teams, totalRounds: botTotalRounds);
    final botChampGameId = 'r${botTotalRounds - 1}_g0';
    final botChamp = botPicks[botChampGameId] ?? champ;

    return {
      'botId': botId,
      'userName': bot.displayName,
      'bracketName': bracket.$1,
      'sport': bracket.$2,
      'bracketType': bracket.$3,
      'totalPicks': botPicks.length,
      'correct': correct,
      'wrong': wrong,
      'pending': pending,
      'championPick': botChamp,
      'tieBreakerPrediction': 120 + rng.nextInt(60),
      'message': message,
      'state': bot.state,
      'teams': teams,
      'picksMap': botPicks,
      'totalRounds': botTotalRounds,
    };
  }

  // ─── BOT BRACKET HOSTING ────────────────────────────────────────────
  /// Generate a complete hosted bracket for a bot, including teams,
  /// picks map (keyed for BracketPrintCanvas), and champion.
  /// Returns data ready to be added to BracketBoardService.
  static Map<String, dynamic> generateHostedBracket(String botId) {
    final bot = allBots.firstWhere((b) => b.id == botId);
    final rng = Random();

    final templates = [
      ('March Madness Sweet 16', 'Basketball', 16),
      ('NBA Playoff Bracket', 'Basketball', 8),
      ('NFL Playoff Challenge', 'Football', 8),
      ('College Football Playoff', 'Football', 8),
      ('Best Wings in Town', 'Voting', 8),
      ('Best Burger Showdown', 'Voting', 8),
      ('Premier League Top 8', 'Soccer', 8),
      ('Stanley Cup Playoff Picks', 'Hockey', 8),
    ];
    final template = templates[rng.nextInt(templates.length)];

    // Get realistic teams for the bracket
    final teams = _getTeamsForSport(template.$2, template.$3);

    // Generate full picks through the bracket
    final totalRounds = _log2Ceil(template.$3);
    final picks = generateAutoPicks(teams: teams, totalRounds: totalRounds);

    // Determine champion from the final round pick
    final champKey = 'r${totalRounds - 1}_g0';
    final champion = picks[champKey] ?? teams.first;

    // Convert picks to the slot_left/right keyed format for the print canvas
    final keyedPicks = <String, String>{};
    keyedPicks.addAll(picks);

    // Also create slot-keyed entries for later rounds
    int matchesInRound = template.$3 ~/ 2;
    for (int r = 0; r < totalRounds; r++) {
      final halfMatches = matchesInRound ~/ 2;
      for (int g = 0; g < matchesInRound; g++) {
        final pickKey = 'r${r}_g$g';
        if (picks.containsKey(pickKey)) {
          if (g < halfMatches) {
            keyedPicks['slot_left_r${r + 1}_m${g}_team1'] = picks[pickKey]!;
          } else {
            keyedPicks['slot_right_r${r + 1}_m${g - halfMatches}_team1'] = picks[pickKey]!;
          }
        }
      }
      matchesInRound = (matchesInRound / 2).ceil();
    }

    return {
      'botId': botId,
      'hostName': bot.displayName,
      'hostState': bot.state,
      'bracketTitle': template.$1,
      'sport': template.$2,
      'teamCount': template.$3,
      'teams': teams,
      'picks': keyedPicks,
      'champion': champion,
      'totalRounds': totalRounds,
      'isFree': rng.nextBool(),
      'entryCredits': rng.nextBool() ? 0 : (5 + rng.nextInt(20)),
      'prizeCredits': 50 + rng.nextInt(450),
    };
  }

  /// Get realistic teams for a sport
  static List<String> _getTeamsForSport(String sport, int count) {
    final teamPools = {
      'Basketball': [
        'Duke', 'UConn', 'Houston', 'Kansas', 'Auburn', 'Tennessee',
        'Alabama', 'Gonzaga', 'Purdue', 'Michigan St', 'Kentucky',
        'Arizona', 'Baylor', 'Marquette', 'Creighton', 'Iowa St',
      ],
      'Football': [
        'Chiefs', 'Bills', 'Eagles', 'Lions', 'Packers', 'Cowboys',
        'Texans', 'Ravens', '49ers', 'Bengals', 'Commanders', 'Steelers',
        'Chargers', 'Dolphins', 'Vikings', 'Rams',
      ],
      'Soccer': [
        'Arsenal', 'Man City', 'Liverpool', 'Chelsea', 'Tottenham',
        'Newcastle', 'Aston Villa', 'Man Utd', 'Brighton', 'West Ham',
        'Wolves', 'Crystal Palace', 'Everton', 'Brentford', 'Fulham', 'Bournemouth',
      ],
      'Hockey': [
        'Panthers', 'Oilers', 'Rangers', 'Stars', 'Avalanche', 'Hurricanes',
        'Bruins', 'Canucks', 'Jets', 'Predators', 'Kings', 'Lightning',
        'Capitals', 'Maple Leafs', 'Devils', 'Islanders',
      ],
      'Voting': [
        'Classic Buffalo', 'Korean BBQ', 'Honey Garlic', 'Lemon Pepper',
        'Mango Habanero', 'Cajun Dry Rub', 'Nashville Hot', 'Teriyaki',
        'Ranch Dusted', 'Sweet Chili', 'Jamaican Jerk', 'Garlic Parmesan',
        'Carolina Reaper', 'Thai Peanut', 'Old Bay', 'Maple Bourbon',
      ],
    };

    final pool = List<String>.from(
      teamPools[sport] ?? teamPools['Basketball']!,
    )..shuffle(Random());
    return pool.take(count).toList();
  }

  static int _log2Ceil(int n) {
    int r = 0;
    while ((1 << r) < n) {
      r++;
    }
    return r;
  }

  /// Generate chat messages for community engagement
  static List<BotChatMessage> generateChatMessages() {
    return const [
      BotChatMessage(botId: 'bot_hype', message: 'Who\'s ready for some bracket action?! LET\'S GO!', type: BotMessageType.hype),
      BotChatMessage(botId: 'bot_trivia', message: 'TRIVIA: Which team has the most NCAA tournament wins? Reply in chat!', type: BotMessageType.trivia),
      BotChatMessage(botId: 'bot_jam81', message: 'Just submitted my picks. Feeling confident this time!', type: BotMessageType.engagement),
      BotChatMessage(botId: 'bot_swish', message: 'Anyone else going chalk in the first round? Or am I crazy?', type: BotMessageType.engagement),
      BotChatMessage(botId: 'bot_cindy', message: 'I\'ve got a 12-seed winning it all. Don\'t @ me.', type: BotMessageType.engagement),
      BotChatMessage(botId: 'bot_stats', message: 'Fun stat: 1-seeds have only lost to 16-seeds once in history.', type: BotMessageType.trivia),
      BotChatMessage(botId: 'bot_hype', message: 'UPSET ALERT! Did anyone call that?!', type: BotMessageType.hype),
      BotChatMessage(botId: 'bot_madness', message: 'My bracket is already busted and I love it. That\'s March baby!', type: BotMessageType.engagement),
      BotChatMessage(botId: 'bot_chalky', message: 'Chalk never fails... except when it does.', type: BotMessageType.engagement),
      BotChatMessage(botId: 'bot_lucky', message: 'I picked with my eyes closed and I\'m somehow in first place!', type: BotMessageType.engagement),
      BotChatMessage(botId: 'bot_hoop', message: 'Great game! That buzzer beater was insane!', type: BotMessageType.hype),
      BotChatMessage(botId: 'bot_trivia', message: 'DAILY CHALLENGE: Name the last team to go undefeated in March Madness. Winner gets bragging rights!', type: BotMessageType.trivia),
      BotChatMessage(botId: 'bot_hype', message: 'Shoutout to everyone in the community! BMB fam is the best!', type: BotMessageType.hype),
      BotChatMessage(botId: 'bot_jam81', message: 'Who\'s watching the games tonight? Post your scores!', type: BotMessageType.engagement),
      BotChatMessage(botId: 'bot_stats', message: 'Pro tip: Teams ranked 4-5 have the closest matchups historically.', type: BotMessageType.trivia),
    ];
  }
}

enum BotRole { host, participant, community, hostAndParticipant }

enum BotMessageType { hype, trivia, engagement }

class BotAccount {
  final String id;
  final String username;
  final String displayName;
  final String state;
  final BotRole role;
  final String bio;
  final bool isVerified;
  final String? profileImageUrl;

  const BotAccount({
    required this.id,
    required this.username,
    required this.displayName,
    required this.state,
    required this.role,
    required this.bio,
    this.isVerified = false,
    this.profileImageUrl,
  });

  String get roleLabel {
    switch (role) {
      case BotRole.host: return 'Official Host';
      case BotRole.participant: return 'Player';
      case BotRole.community: return 'Community';
      case BotRole.hostAndParticipant: return 'Host & Player';
    }
  }
}

class BotChatMessage {
  final String botId;
  final String message;
  final BotMessageType type;

  const BotChatMessage({
    required this.botId,
    required this.message,
    required this.type,
  });
}
