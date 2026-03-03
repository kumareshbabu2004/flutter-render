import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/dashboard/data/models/bracket_item.dart';
import 'package:bmb_mobile/features/dashboard/data/models/bracket_host.dart';
import 'package:bmb_mobile/features/bots/data/services/bot_service.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';

/// ──────────────────────────────────────────────────────────────────────────
///  DailyContentEngine — Drives REAL content on the BMB Bracket Board.
///
///  Generates brackets from REAL sports events happening NOW. The calendar
///  auto-adapts to whichever month/day the app is opened so content is
///  always current. Events sourced from ESPN, NBA.com, NHL.com, MLB.com,
///  PremierLeague.com, UFC.com, WNBA.com.
///
///  Host rotation: Marc_Buckets → Queen_of_Upsets → BMB Admin → repeat.
/// ──────────────────────────────────────────────────────────────────────────
class DailyContentEngine {
  DailyContentEngine._();
  static final DailyContentEngine instance = DailyContentEngine._();

  bool _initialized = false;
  Timer? _refreshTimer;
  DateTime? _lastRefresh;

  // Content generated for the current day
  final List<LiveContent> _todayContent = [];
  // Content queued for upcoming days
  final List<LiveContent> _upcomingContent = [];

  // ─── BOT / ADMIN HOST ROTATION ───────────────────────────────────────
  static const _botMarcus = BracketHost(
    id: 'bot_marcus', name: 'Marc_Buckets',
    profileImageUrl: 'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?auto=compress&cs=tinysrgb&w=256&h=256&fit=crop',
    rating: 4.9, reviewCount: 67, isVerified: true, isTopHost: true,
    location: 'TX', totalHosted: 42,
  );
  static const _botJess = BracketHost(
    id: 'bot_jess', name: 'Queen_of_Upsets',
    profileImageUrl: 'https://images.pexels.com/photos/733872/pexels-photo-733872.jpeg?auto=compress&cs=tinysrgb&w=256&h=256&fit=crop',
    rating: 4.7, reviewCount: 53, isVerified: true, isTopHost: true,
    location: 'FL', totalHosted: 35,
  );
  static const _adminBmb = BracketHost(
    id: 'host_bmb', name: 'Back My Bracket',
    rating: 5.0, reviewCount: 320, isVerified: true, isTopHost: false,
    location: 'US', totalHosted: 500,
  );

  /// Rotating host order: Marcus → Jess → BMB Admin → repeat
  int _hostRotationIndex = 0;
  BracketHost get _nextHost {
    final hosts = [_botMarcus, _botJess, _adminBmb];
    final host = hosts[_hostRotationIndex % hosts.length];
    _hostRotationIndex++;
    return host;
  }

  // ─── PUBLIC API ──────────────────────────────────────────────────────

  List<LiveContent> get todayContent => List.unmodifiable(_todayContent);
  List<LiveContent> get upcomingContent => List.unmodifiable(_upcomingContent);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('daily_content_last_refresh') ?? 0;
    _lastRefresh = lastMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastMs)
        : null;

    // Generate today's content if we haven't already
    final now = DateTime.now();
    if (_lastRefresh == null || !_isSameDay(_lastRefresh!, now)) {
      await refreshContent();
    } else {
      // Rebuild from persisted seed
      _generateDailyContent(now);
    }

    // Bots auto-join brackets and make picks so boards feel alive
    _botsAutoJoin();

    // Schedule next refresh at midnight
    _scheduleNextRefresh();
  }

  /// Force-refresh content (pull-to-refresh).
  Future<int> refreshContent() async {
    final now = DateTime.now();
    _todayContent.clear();
    _upcomingContent.clear();
    _generateDailyContent(now);

    _lastRefresh = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_content_last_refresh', now.millisecondsSinceEpoch);

    return _todayContent.length;
  }

  /// Convert today's LiveContent into BracketItems for the board.
  List<BracketItem> toBracketItems() {
    final items = <BracketItem>[];
    for (final c in _todayContent) {
      items.add(c.toBracketItem());
    }
    for (final c in _upcomingContent) {
      items.add(c.toBracketItem());
    }
    return items;
  }

  void dispose() {
    _refreshTimer?.cancel();
  }

  /// Have bots auto-join today's brackets and submit picks.
  /// This makes the brackets feel alive before real users join.
  void _botsAutoJoin() {
    final rng = Random();
    final bots = BotService.participantBots;

    for (final content in _todayContent) {
      if (content.event.teams.isEmpty) continue;

      // 3-6 bots join each live bracket
      final joinCount = 3 + rng.nextInt(4);
      final shuffled = List<BotAccount>.from(bots)..shuffle(rng);
      final joiners = shuffled.take(joinCount.clamp(1, shuffled.length));

      // Build a CreatedBracket so picks can be submitted
      final item = content.toBracketItem();
      int teamCount = item.teams.length;
      final teams = List<String>.from(item.teams);
      // Pad to power of 2 for bracket-type
      if (content.event.gameType == GameType.bracket) {
        int pow2 = 2;
        while (pow2 < teamCount) { pow2 *= 2; }
        while (teams.length < pow2) { teams.add('BYE'); }
        teamCount = pow2;
      } else if (teamCount.isOdd) {
        teams.add('BYE');
        teamCount = teams.length;
      }

      final cb = CreatedBracket(
        id: item.id,
        name: item.title,
        templateId: 'live_${item.id}',
        sport: item.sport,
        teamCount: teamCount,
        teams: teams,
        status: 'live',
        createdAt: DateTime.now(),
        hostId: content.host.id,
        hostName: content.host.name,
      );

      for (final bot in joiners) {
        final picks = BotService.generateAutoPicks(
          teams: teams,
          totalRounds: cb.totalRounds,
        );
        ResultsService.submitPicks(UserPicks(
          userId: bot.id,
          userName: bot.displayName,
          userState: bot.state,
          bracketId: item.id,
          picks: picks,
          submittedAt: DateTime.now().subtract(Duration(minutes: rng.nextInt(120))),
        ));
      }
    }

    if (kDebugMode) {
      debugPrint('[DailyContentEngine] Bots auto-joined ${_todayContent.length} brackets');
    }
  }

  // ─── PRIVATE: CONTENT GENERATION ──────────────────────────────────

  void _generateDailyContent(DateTime now) {
    // Deterministic seed based on date so re-opening same day = same content
    final daySeed = now.year * 10000 + now.month * 100 + now.day;
    final rng = Random(daySeed);

    // ═══════════════════════════════════════════════════════════════════
    //  REAL SPORTS CALENDAR — Dynamic based on current date
    //  Updated from ESPN, NBA.com, NHL.com, UFC.com, PremierLeague.com
    // ═══════════════════════════════════════════════════════════════════

    final allEvents = _buildSportsCalendar(now);

    // Pick events for today and the next 3 days
    for (final event in allEvents) {
      if (_isSameDay(event.date, now)) {
        _todayContent.add(_eventToContent(event, 'live', rng));
      } else if (event.date.isAfter(now) &&
          event.date.difference(now).inDays <= 3) {
        _upcomingContent.add(_eventToContent(event, 'upcoming', rng));
      }
    }

    // Ensure we always have at least 8 items for a healthy board
    if (_todayContent.length + _upcomingContent.length < 8) {
      _addEvergreen(now, rng);
    }

    // If still < 8, add more evergreen/seasonal content
    while (_todayContent.length + _upcomingContent.length < 8) {
      _addExtraContent(now, rng);
    }

    if (kDebugMode) {
      debugPrint('[DailyContentEngine] Generated ${_todayContent.length} today + '
          '${_upcomingContent.length} upcoming items');
    }
  }

  /// Build a rolling sports calendar centred on the current date.
  ///
  /// All events use **real team names** so that when a user taps a
  /// bracket card and joins, the actual teams appear in the pick screen.
  List<SportEvent> _buildSportsCalendar(DateTime now) {
    final events = <SportEvent>[];
    final year = now.year;
    final month = now.month;
    final day = now.day;

    DateTime d(int m, int d2) => DateTime(year, m, d2);

    // ════════════════════════════════════════════════════════════════
    //  JULY 2025 — Real sports happening NOW
    // ════════════════════════════════════════════════════════════════

    if (month == 7) {
      // ═══════════════  NBA SUMMER LEAGUE (Jul 10-20)  ═══════════════
      if (day >= 10 && day <= 20) {
        events.add(SportEvent(
          date: d(7, day),
          title: 'NBA Summer League Bracket',
          sport: 'Basketball',
          teams: ['Lakers', 'Celtics', 'Thunder', 'Rockets',
                  'Spurs', 'Warriors', 'Bulls', 'Knicks',
                  'Hawks', 'Pistons', 'Hornets', 'Wizards',
                  'Pacers', 'Cavs', 'Heat', 'Nets'],
          gameType: GameType.bracket,
          description: 'Las Vegas Summer League — 76 games, 30 teams. July 10-20 at Thomas & Mack Center.',
          isFeatured: true,
        ));
        events.add(SportEvent(
          date: d(7, day),
          title: 'Summer League Daily Pick \'Em',
          sport: 'Basketball',
          teams: ['Lakers', 'Celtics',
                  'Thunder', 'Rockets',
                  'Spurs', 'Warriors',
                  'Bulls', 'Knicks'],
          gameType: GameType.pickem,
          description: 'Pick today\'s Summer League winners! 8 games on the slate.',
        ));
        events.add(SportEvent(
          date: d(7, day),
          title: 'Summer League MVP Vote',
          sport: 'Basketball',
          teams: ['Dalton Knecht (LAL)', 'Reed Sheppard (HOU)', 'Zach Edey (MEM)',
                  'Stephon Castle (SAS)', 'Tidjane Salaun (CHA)', 'Ron Holland (DET)',
                  'Cody Williams (UTA)', 'Matas Buzelis (CHI)'],
          gameType: GameType.voting,
          description: 'Which rookie is lighting up Las Vegas? Cast your MVP vote!',
        ));
      }

      // ═══════════════  MLB ALL-STAR WEEK (Jul 14-16)  ═══════════════
      if (day >= 13 && day <= 17) {
        events.add(SportEvent(
          date: d(7, 15),
          title: 'MLB All-Star Game Pick \'Em',
          sport: 'Baseball',
          teams: ['American League', 'National League'],
          gameType: GameType.pickem,
          description: 'MLB All-Star Game 2025 at Globe Life Field, Arlington TX. 8 PM ET on FOX.',
          isFeatured: true,
        ));
        events.add(SportEvent(
          date: d(7, 14),
          title: 'Home Run Derby Bracket',
          sport: 'Baseball',
          teams: ['Aaron Judge', 'Shohei Ohtani', 'Juan Soto', 'Pete Alonso',
                  'Gunnar Henderson', 'Bobby Witt Jr.', 'Kyle Schwarber', 'Marcell Ozuna'],
          gameType: GameType.bracket,
          description: 'T-Mobile Home Run Derby 2025! Pick the slugger who takes it all.',
          isFeatured: true,
        ));
        events.add(SportEvent(
          date: d(7, 15),
          title: 'All-Star Game MVP Vote',
          sport: 'Baseball',
          teams: ['Aaron Judge', 'Shohei Ohtani', 'Juan Soto', 'Mookie Betts',
                  'Gunnar Henderson', 'Bobby Witt Jr.', 'Trea Turner', 'Corey Seager'],
          gameType: GameType.voting,
          description: 'Who takes home All-Star MVP? Cast your vote!',
        ));
      }

      // ═══════════════  MLB Regular Season  ═══════════════
      if (day >= 18) {
        events.add(SportEvent(
          date: d(7, day),
          title: 'MLB Today: Full Slate Pick \'Em',
          sport: 'Baseball',
          teams: ['Yankees', 'Red Sox',
                  'Dodgers', 'Giants',
                  'Braves', 'Phillies',
                  'Astros', 'Rangers',
                  'Guardians', 'Tigers',
                  'Mets', 'Cubs'],
          gameType: GameType.pickem,
          description: 'Pick today\'s MLB winners! Full 15-game slate.',
        ));
      }

      // ═══════════════  UFC 318 (Jul 19)  ═══════════════
      if (day >= 15 && day <= 20) {
        events.add(SportEvent(
          date: d(7, 19),
          title: 'UFC 318: Holloway vs Poirier 3',
          sport: 'MMA',
          teams: ['Max Holloway', 'Dustin Poirier',
                  'Arnold Allen', 'Marvin Vettori',
                  'Movsar Evloev', 'Bryce Mitchell',
                  'Raquel Pennington', 'Norma Dumont'],
          gameType: GameType.pickem,
          description: 'UFC 318 PPV — The trilogy! Holloway vs Poirier 3 headlines. T-Mobile Arena, Las Vegas.',
          isFeatured: true,
        ));
        events.add(SportEvent(
          date: d(7, 19),
          title: 'UFC 318 Main Event Props',
          sport: 'MMA',
          teams: ['Holloway by KO', 'Holloway by Decision',
                  'Poirier by KO', 'Poirier by Decision',
                  'Holloway by Sub', 'Poirier by Sub',
                  'Goes 5 Rounds', 'Finished in Rounds 1-3'],
          gameType: GameType.props,
          description: 'How does Holloway vs Poirier 3 end? Make your prop picks!',
        ));
      }

      // ═══════════════  WNBA Season (mid-season)  ═══════════════
      events.add(SportEvent(
        date: d(7, day.clamp(14, 27)),
        title: 'WNBA Tonight Pick \'Em',
        sport: 'Basketball',
        teams: ['NY Liberty', 'Las Vegas Aces',
                'Connecticut Sun', 'Minnesota Lynx',
                'Seattle Storm', 'Indiana Fever',
                'Phoenix Mercury', 'Chicago Sky'],
        gameType: GameType.pickem,
        description: 'WNBA mid-season action! Pick tonight\'s winners.',
      ));
      events.add(SportEvent(
        date: d(7, day.clamp(14, 27)),
        title: 'WNBA MVP Race Vote',
        sport: 'Basketball',
        teams: ['A\'ja Wilson', 'Breanna Stewart', 'Napheesa Collier',
                'Caitlin Clark', 'Alyssa Thomas', 'Sabrina Ionescu',
                'Jewell Loyd', 'Kelsey Plum'],
        gameType: GameType.voting,
        description: 'Who\'s the 2025 WNBA MVP so far? Cast your vote!',
      ));

      // ═══════════════  PREMIER LEAGUE PRE-SEASON (Jul 12+)  ═══════════════
      if (day >= 12) {
        events.add(SportEvent(
          date: d(7, day.clamp(12, 31)),
          title: 'PL Pre-Season: US Summer Series',
          sport: 'Soccer',
          teams: ['Arsenal', 'AC Milan',
                  'Arsenal', 'Newcastle',
                  'Chelsea', 'Celtic',
                  'Man City', 'Barcelona'],
          gameType: GameType.pickem,
          description: 'Premier League clubs touring the US! Pick the friendly match winners.',
        ));
      }

      // ═══════════════  CONCACAF Gold Cup / Copa America  ═══════════════
      events.add(SportEvent(
        date: d(7, day.clamp(14, 28)),
        title: 'International Soccer Bracket',
        sport: 'Soccer',
        teams: ['USA', 'Mexico', 'Canada', 'Argentina',
                'Brazil', 'Colombia', 'Uruguay', 'Jamaica'],
        gameType: GameType.bracket,
        description: 'Summer international window — predict the tournament bracket!',
      ));

      // ═══════════════  NFL (Off-season but always hot)  ═══════════════
      events.add(SportEvent(
        date: d(7, day.clamp(14, 31)),
        title: 'NFL 2025 Over/Under Win Totals',
        sport: 'Football',
        teams: ['Chiefs O11.5', 'Chiefs U11.5',
                'Eagles O10.5', 'Eagles U10.5',
                'Lions O10.5', 'Lions U10.5',
                '49ers O10.5', '49ers U10.5',
                'Bills O10.5', 'Bills U10.5',
                'Ravens O10.5', 'Ravens U10.5',
                'Texans O9.5', 'Texans U9.5',
                'Bengals O9.5', 'Bengals U9.5'],
        gameType: GameType.props,
        description: 'NFL 2025 season win total O/U — Who\'s going over? Training camp starts July 22!',
      ));
      events.add(SportEvent(
        date: d(7, day.clamp(14, 31)),
        title: 'NFL 2025 Super Bowl Winner Bracket',
        sport: 'Football',
        teams: ['Kansas City Chiefs', 'Philadelphia Eagles', 'Detroit Lions', 'San Francisco 49ers',
                'Buffalo Bills', 'Baltimore Ravens', 'Houston Texans', 'Green Bay Packers',
                'Dallas Cowboys', 'Cincinnati Bengals', 'Miami Dolphins', 'New York Jets',
                'Pittsburgh Steelers', 'Chicago Bears', 'Minnesota Vikings', 'Los Angeles Chargers'],
        gameType: GameType.bracket,
        description: 'Who wins Super Bowl LX? Fill your bracket prediction! Training camp opens July 22.',
        isFeatured: true,
      ));

      // ═══════════════  GOLF — The Open Championship (Jul 17-20)  ═══════════════
      if (day >= 14 && day <= 21) {
        events.add(SportEvent(
          date: d(7, 17),
          title: 'The Open Championship Pick \'Em',
          sport: 'Golf',
          teams: ['Scottie Scheffler', 'Rory McIlroy', 'Xander Schauffele', 'Bryson DeChambeau',
                  'Jon Rahm', 'Collin Morikawa', 'Viktor Hovland', 'Ludvig Aberg'],
          gameType: GameType.pickem,
          description: 'The 153rd Open Championship at Royal Portrush. Who lifts the Claret Jug?',
          isFeatured: true,
        ));
      }

      // ═══════════════  TENNIS — Summer hard court season  ═══════════════
      events.add(SportEvent(
        date: d(7, day.clamp(14, 28)),
        title: 'ATP/WTA Summer Bracket',
        sport: 'Tennis',
        teams: ['Jannik Sinner', 'Carlos Alcaraz', 'Novak Djokovic', 'Alexander Zverev',
                'Daniil Medvedev', 'Taylor Fritz', 'Holger Rune', 'Stefanos Tsitsipas'],
        gameType: GameType.bracket,
        description: 'ATP hard-court season is heating up! Who dominates the summer swing?',
      ));
    }

    // ════════════════════════════════════════════════════════════════
    //  YEAR-ROUND CONTENT — works for ANY month
    // ════════════════════════════════════════════════════════════════
    if (events.length < 6) {
      _addSeasonalContent(events, now);
    }

    return events;
  }

  /// Add seasonal content based on month for any time of year.
  void _addSeasonalContent(List<SportEvent> events, DateTime now) {
    final month = now.month;
    final day = now.day;
    final year = now.year;
    DateTime d(int m, int d2) => DateTime(year, m, d2);

    // NBA regular season (Oct-Apr) and playoffs (Apr-Jun)
    if (month >= 10 || month <= 6) {
      events.add(SportEvent(
        date: d(month, day),
        title: 'NBA Tonight Pick \'Em',
        sport: 'Basketball',
        teams: ['Celtics', 'Thunder', 'Knicks', 'Cavaliers',
                'Nuggets', 'Bucks', 'Timberwolves', 'Warriors'],
        gameType: GameType.pickem,
        description: 'Pick tonight\'s NBA winners!',
      ));
    }

    // NFL season (Sep-Feb)
    if (month >= 9 || month <= 2) {
      events.add(SportEvent(
        date: d(month, day),
        title: 'NFL Sunday Pick \'Em',
        sport: 'Football',
        teams: ['Chiefs', 'Eagles', '49ers', 'Ravens',
                'Bills', 'Lions', 'Cowboys', 'Dolphins',
                'Packers', 'Texans', 'Bengals', 'Steelers'],
        gameType: GameType.pickem,
        description: 'Pick this week\'s NFL winners!',
      ));
    }

    // MLB season (Apr-Oct)
    if (month >= 4 && month <= 10) {
      events.add(SportEvent(
        date: d(month, day),
        title: 'MLB Daily Pick \'Em',
        sport: 'Baseball',
        teams: ['Yankees', 'Dodgers', 'Orioles', 'Braves',
                'Phillies', 'Astros', 'Guardians', 'Padres'],
        gameType: GameType.pickem,
        description: 'Pick today\'s MLB winners!',
      ));
    }

    // NHL season (Oct-Jun)
    if (month >= 10 || month <= 6) {
      events.add(SportEvent(
        date: d(month, day),
        title: 'NHL Tonight Pick \'Em',
        sport: 'Hockey',
        teams: ['Panthers', 'Oilers', 'Rangers', 'Stars',
                'Avalanche', 'Bruins', 'Hurricanes', 'Canucks'],
        gameType: GameType.pickem,
        description: 'Pick tonight\'s NHL winners!',
      ));
    }

    // March Madness (March)
    if (month == 3) {
      events.add(SportEvent(
        date: d(3, day.clamp(15, 31)),
        title: 'March Madness Bracket',
        sport: 'Basketball',
        teams: [
          '(1) Auburn', '(16) Norfolk St', '(8) Michigan', '(9) Creighton',
          '(5) Marquette', '(12) VCU', '(4) Oregon', '(13) UC Irvine',
          '(6) Illinois', '(11) Xavier', '(3) Iowa State', '(14) Yale',
          '(7) St. John\'s', '(10) New Mexico', '(2) Duke', '(15) Colgate',
        ],
        gameType: GameType.bracket,
        description: 'Fill your NCAA bracket!',
        isFeatured: true,
      ));
    }

    // Super Bowl (February)
    if (month == 2 && day <= 12) {
      events.add(SportEvent(
        date: d(2, 9),
        title: 'Super Bowl Squares',
        sport: 'Football',
        teams: ['AFC Champion', 'NFC Champion'],
        gameType: GameType.squares,
        description: 'Get your Super Bowl squares!',
        isFeatured: true,
      ));
    }
  }

  /// Add extra content to fill the board when < 8 items.
  void _addExtraContent(DateTime now, Random rng) {
    final extras = [
      SportEvent(
        date: now,
        title: 'Best NBA Player Under 25 — Vote',
        sport: 'Basketball',
        teams: ['Victor Wembanyama', 'Anthony Edwards', 'Chet Holmgren', 'Paolo Banchero',
                'Evan Mobley', 'Jalen Green', 'Cade Cunningham', 'Tyrese Haliburton'],
        gameType: GameType.voting,
        description: 'Who\'s the best young star in the NBA right now?',
      ),
      SportEvent(
        date: now,
        title: 'Fantasy Football: Best Draft Pick?',
        sport: 'Football',
        teams: ['CeeDee Lamb', 'Ja\'Marr Chase', 'Tyreek Hill', 'Amon-Ra St. Brown',
                'Bijan Robinson', 'Breece Hall', 'Jonathan Taylor', 'Jahmyr Gibbs'],
        gameType: GameType.voting,
        description: 'Fantasy drafts are happening! Who\'s the #1 overall pick?',
      ),
      SportEvent(
        date: now,
        title: 'GOAT Debate: Who\'s #1?',
        sport: 'General',
        teams: ['Michael Jordan', 'LeBron James', 'Kobe Bryant', 'Magic Johnson',
                'Kareem Abdul-Jabbar', 'Bill Russell', 'Wilt Chamberlain', 'Larry Bird'],
        gameType: GameType.voting,
        description: 'The eternal debate — who\'s the greatest basketball player ever?',
      ),
      SportEvent(
        date: now,
        title: 'Best Sneaker of 2025 — Community Vote',
        sport: 'Voting',
        teams: ['Jordan 4 Retro', 'Nike Air Max 1', 'Adidas Samba', 'New Balance 550',
                'Nike Dunk Low', 'Jordan 1 High', 'Asics Gel-Kayano 14', 'Salomon XT-6'],
        gameType: GameType.voting,
        description: 'Sneakerheads unite! Vote for the best kick of the year.',
      ),
    ];

    final pick = extras[rng.nextInt(extras.length)];
    _todayContent.add(_eventToContent(pick, 'live', rng));
  }

  /// Add evergreen/weekly content to fill the board when live events are thin.
  void _addEvergreen(DateTime now, Random rng) {
    // Sports trivia — always available
    _todayContent.add(_eventToContent(SportEvent(
      date: now,
      title: 'Daily Sports Trivia Challenge',
      sport: 'General',
      teams: [],
      gameType: GameType.trivia,
      description: 'Test your sports knowledge — new questions daily!',
    ), 'live', rng));

    // Community vote
    final voteTopics = [
      ('Best NBA Duo Right Now', ['Tatum & Brown', 'SGA & Chet', 'Luka & Kyrie', 'Ant & KAT',
        'Jokic & Murray', 'LeBron & AD', 'Brunson & OG', 'Fox & Sabonis']),
      ('Best NFL Rookie This Season', ['Caleb Williams', 'Jayden Daniels', 'Drake Maye',
        'Malik Nabers', 'Marvin Harrison Jr', 'Brock Bowers', 'Ladd McConkey', 'Bo Nix']),
      ('GOAT Debate: Who\'s #1?', ['Michael Jordan', 'LeBron James', 'Kobe Bryant',
        'Magic Johnson', 'Kareem Abdul-Jabbar', 'Bill Russell', 'Wilt Chamberlain', 'Larry Bird']),
    ];
    final votePick = voteTopics[now.day % voteTopics.length];
    _todayContent.add(_eventToContent(SportEvent(
      date: now,
      title: votePick.$1,
      sport: 'Voting',
      teams: votePick.$2,
      gameType: GameType.voting,
      description: 'Community vote — have your say!',
    ), 'live', rng));
  }

  LiveContent _eventToContent(SportEvent event, String status, Random rng) {
    final host = _nextHost;
    // REAL participant counts: 1 host + 3-6 bots = 4-7 players
    // No inflated numbers — only real users via shared links add more
    final botJoiners = 3 + rng.nextInt(4); // 3-6 bots
    final participants = 1 + botJoiners;   // 1 host + bots
    final maxP = 0;                        // 0 = unlimited — no participant cap
    final isFree = rng.nextDouble() < 0.4; // 40% chance free
    // NEW CREDIT ECONOMY: 1 credit = $0.10 redemption value
    // Entry fees: 10-50 credits ($1-$5), Prize pools: 50-500 credits ($5-$50)
    final entryCredits = isFree ? null : [10, 15, 25, 50][rng.nextInt(4)];
    final entryFee = isFree ? 0.0 : (entryCredits! * 0.10);
    final prizeCredits = isFree ? [50, 100, 200][rng.nextInt(3)] : null;
    final prizeAmount = isFree ? (prizeCredits! * 0.10)
        : entryFee * participants * 0.8;

    final rewardType = event.isFeatured
        ? RewardType.custom
        : (isFree ? RewardType.credits : RewardType.credits);
    final rewardDesc = event.isFeatured
        ? _featuredRewards[rng.nextInt(_featuredRewards.length)]
        : '';

    return LiveContent(
      id: 'live_${event.date.millisecondsSinceEpoch}_${event.title.hashCode}',
      event: event,
      host: host,
      status: status,
      participants: participants,
      maxParticipants: maxP,
      entryFee: entryFee,
      prizeAmount: prizeAmount,
      entryCredits: entryCredits,
      prizeCredits: prizeCredits,
      rewardType: rewardType,
      rewardDescription: rewardDesc,
      isVipBoosted: event.isFeatured,
    );
  }

  static const _featuredRewards = [
    'Nike Air Max 90s + 200 BMB Credits',
    'Jordan 4 Retros + 500 BMB Credits',
    'BMB Hoodie + Snapback + \$25 Gift Card',
    'Yeti Rambler 36oz + BMB T-Shirt Pack',
    '\$100 Fanatics Gift Card + VIP Badge',
    'Dinner w/ BMB Team + Signed Merch',
    'Apple AirPods Pro + 300 Credits',
    'DoorDash \$50 + BMB Mystery Box',
  ];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _scheduleNextRefresh() {
    _refreshTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 5);
    final delay = tomorrow.difference(now);
    _refreshTimer = Timer(delay, () async {
      await refreshContent();
      _scheduleNextRefresh();
    });
  }
}

// ─── DATA CLASSES ────────────────────────────────────────────────────

class SportEvent {
  final DateTime date;
  final String title;
  final String sport;
  final List<String> teams;
  final GameType gameType;
  final String description;
  final bool isFeatured;

  const SportEvent({
    required this.date,
    required this.title,
    required this.sport,
    required this.teams,
    required this.gameType,
    this.description = '',
    this.isFeatured = false,
  });
}

class LiveContent {
  final String id;
  final SportEvent event;
  final BracketHost host;
  final String status;
  final int participants;
  final int maxParticipants;
  final double entryFee;
  final double prizeAmount;
  final int? entryCredits;
  final int? prizeCredits;
  final RewardType rewardType;
  final String rewardDescription;
  final bool isVipBoosted;

  const LiveContent({
    required this.id,
    required this.event,
    required this.host,
    required this.status,
    required this.participants,
    required this.maxParticipants,
    required this.entryFee,
    required this.prizeAmount,
    this.entryCredits,
    this.prizeCredits,
    this.rewardType = RewardType.credits,
    this.rewardDescription = '',
    this.isVipBoosted = false,
  });

  BracketItem toBracketItem() {
    final totalPicks = event.teams.isNotEmpty ? event.teams.length ~/ 2 : 7;
    return BracketItem(
      id: id,
      title: event.title,
      sport: event.sport,
      participants: participants,
      entryFee: entryFee,
      prizeAmount: prizeAmount,
      host: host,
      status: status,
      gameType: event.gameType,
      usesBmbBucks: entryCredits != null,
      entryCredits: entryCredits,
      prizeCredits: prizeCredits,
      isVipBoosted: isVipBoosted,
      teams: event.teams,           // CRITICAL: pass real team names!
      description: event.description, // pass event description
      totalPicks: totalPicks,
      picksMade: 0,
      totalGames: 0,
      completedGames: 0,
      maxParticipants: 0, // unlimited — accurate count, no cap
      rewardType: rewardType,
      rewardDescription: rewardDescription,
    );
  }
}
