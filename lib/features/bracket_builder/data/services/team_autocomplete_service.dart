/// Auto-populate team names for common sports leagues.
/// Supports NFL, NBA, NCAA Basketball, NCAA Football, MLB, NHL, MLS.
class TeamAutocompleteService {
  static final TeamAutocompleteService _instance = TeamAutocompleteService._internal();
  factory TeamAutocompleteService() => _instance;
  TeamAutocompleteService._internal();

  /// Search teams by query across all leagues
  static List<TeamSuggestion> search(String query, {String? sport}) {
    if (query.length < 2) return [];
    final q = query.toLowerCase();
    final results = <TeamSuggestion>[];

    for (final entry in _allTeams.entries) {
      if (sport != null && entry.key.toLowerCase() != sport.toLowerCase()) continue;
      for (final team in entry.value) {
        if (team.toLowerCase().contains(q)) {
          results.add(TeamSuggestion(name: team, league: entry.key));
        }
      }
    }
    return results..sort((a, b) {
      // Prioritize starts-with matches
      final aStarts = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      return aStarts.compareTo(bStarts);
    });
  }

  /// Get all teams for a specific league
  static List<String> getTeamsForLeague(String league) {
    return _allTeams[league] ?? [];
  }

  /// Get available league names
  static List<String> get leagues => _allTeams.keys.toList();

  // ─── PICK-EM SPORT TYPES ───
  /// The types of Pick 'Em available for creation
  static const List<String> pickEmSportTypes = [
    'NFL',
    'NBA',
    'NCAA Basketball',
    'NCAA Football',
    'NCAA Women\'s Basketball',
    'MLB',
    'NHL',
    'BMB Weekly Mix',
    'Custom',
  ];

  /// All schedule maps follow the **[Away, Home]** convention:
  ///   pair[0] = AWAY team  (displayed before "@")
  ///   pair[1] = HOME team  (displayed after  "@")

  // ─── NFL WEEKLY SCHEDULES (2026 Mock) ───
  /// NFL regular season has 18 weeks; each week has ~16-17 games (some bye weeks).
  /// Key: week number -> list of matchups as [away, home]
  /// NFL weekly schedules: each matchup is **[Away, Home]**.
  /// pair[0] = AWAY team (displayed before "@")
  /// pair[1] = HOME team (displayed after "@")
  static const Map<int, List<List<String>>> nflWeeklySchedules = {
    // ── REAL 2025 NFL Week 12 (Nov 20-24, 2025) ──
    12: [
      // Thursday Night Football
      ['Buffalo Bills', 'Houston Texans'],                // BUF @ HOU
      // Sunday 1:00 PM ET
      ['Pittsburgh Steelers', 'Chicago Bears'],            // PIT @ CHI
      ['New England Patriots', 'Cincinnati Bengals'],      // NE @ CIN
      ['New York Giants', 'Detroit Lions'],                // NYG @ DET
      ['Minnesota Vikings', 'Green Bay Packers'],          // MIN @ GB
      ['Seattle Seahawks', 'Tennessee Titans'],            // SEA @ TEN
      ['Indianapolis Colts', 'Kansas City Chiefs'],        // IND @ KC
      ['New York Jets', 'Baltimore Ravens'],               // NYJ @ BAL
      // Sunday 4:05 PM ET
      ['Cleveland Browns', 'Las Vegas Raiders'],           // CLE @ LV
      ['Jacksonville Jaguars', 'Arizona Cardinals'],       // JAX @ ARI
      // Sunday 4:25 PM ET
      ['Philadelphia Eagles', 'Dallas Cowboys'],           // PHI @ DAL
      ['Atlanta Falcons', 'New Orleans Saints'],           // ATL @ NO
      // Sunday Night Football
      ['Tampa Bay Buccaneers', 'Los Angeles Rams'],        // TB @ LAR
      // Monday Night Football
      ['Carolina Panthers', 'San Francisco 49ers'],        // CAR @ SF
    ],
    // ── Mock Week 15 of the 2026 NFL Season ──
    15: [
      ['Kansas City Chiefs', 'Houston Texans'],
      ['Buffalo Bills', 'Detroit Lions'],
      ['Philadelphia Eagles', 'Pittsburgh Steelers'],
      ['Baltimore Ravens', 'New York Giants'],
      ['Cincinnati Bengals', 'Cleveland Browns'],
      ['Green Bay Packers', 'Minnesota Vikings'],
      ['Miami Dolphins', 'New York Jets'],
      ['Chicago Bears', 'Indianapolis Colts'],
      ['Denver Broncos', 'Las Vegas Raiders'],
      ['Seattle Seahawks', 'Arizona Cardinals'],
      ['Tampa Bay Buccaneers', 'Carolina Panthers'],
      ['New England Patriots', 'Jacksonville Jaguars'],
      ['Los Angeles Chargers', 'Dallas Cowboys'],
      ['San Francisco 49ers', 'Los Angeles Rams'],
      ['Atlanta Falcons', 'New Orleans Saints'],
      ['Tennessee Titans', 'Washington Commanders'],
    ],
  };

  // ─── NBA SCHEDULE (Feb 23-25, 2026 — real games) ───
  static const Map<String, List<List<String>>> nbaSchedules = {
    'sample': [
      // Real NBA games Feb 23-25, 2026  [Away, Home]
      ['San Antonio Spurs', 'Detroit Pistons'],            // SAS @ DET
      ['Sacramento Kings', 'Memphis Grizzlies'],           // SAC @ MEM
      ['Utah Jazz', 'Houston Rockets'],                    // UTA @ HOU
      ['Cleveland Cavaliers', 'Oklahoma City Thunder'],    // CLE @ OKC
      ['Brooklyn Nets', 'Boston Celtics'],                 // BKN @ BOS
      ['New York Knicks', 'Milwaukee Bucks'],              // NYK @ MIL
      ['Philadelphia 76ers', 'Indiana Pacers'],            // PHI @ IND
      ['Denver Nuggets', 'Los Angeles Lakers'],            // DEN @ LAL
      ['Golden State Warriors', 'Phoenix Suns'],           // GSW @ PHX
      ['Miami Heat', 'Atlanta Hawks'],                     // MIA @ ATL
      ['Minnesota Timberwolves', 'Dallas Mavericks'],      // MIN @ DAL
      ['Portland Trail Blazers', 'Chicago Bulls'],         // POR @ CHI
      ['Toronto Raptors', 'Charlotte Hornets'],            // TOR @ CHA
      ['Orlando Magic', 'Washington Wizards'],             // ORL @ WAS
      ['Los Angeles Clippers', 'New Orleans Pelicans'],    // LAC @ NOP
    ],
  };

  // ─── NHL SCHEDULE (Feb 25-26, 2026 — real games, post-Olympic return) ───
  static const Map<String, List<List<String>>> nhlSchedules = {
    'sample': [
      // Real NHL games Feb 25-26, 2026  [Away, Home]
      ['Buffalo Sabres', 'New Jersey Devils'],             // BUF @ NJD
      ['Philadelphia Flyers', 'Washington Capitals'],      // PHI @ WSH
      ['Toronto Maple Leafs', 'Tampa Bay Lightning'],      // TOR @ TBL
      ['Seattle Kraken', 'Dallas Stars'],                  // SEA @ DAL
      ['Colorado Avalanche', 'St. Louis Blues'],           // COL @ STL
      ['Chicago Blackhawks', 'Nashville Predators'],       // CHI @ NSH
      ['Minnesota Wild', 'Colorado Avalanche'],            // MIN @ COL
      ['Calgary Flames', 'San Jose Sharks'],               // CGY @ SJS
      ['Edmonton Oilers', 'Los Angeles Kings'],            // EDM @ LAK
      ['Columbus Blue Jackets', 'Ottawa Senators'],        // CBJ @ OTT
      ['Detroit Red Wings', 'Ottawa Senators'],            // DET @ OTT
      ['Boston Bruins', 'Montreal Canadiens'],             // BOS @ MTL
      ['Pittsburgh Penguins', 'Carolina Hurricanes'],      // PIT @ CAR
      ['New York Rangers', 'Florida Panthers'],            // NYR @ FLA
      ['Vegas Golden Knights', 'Vancouver Canucks'],       // VGK @ VAN
    ],
  };

  // ─── MLB SAMPLE SCHEDULE ───
  static const Map<String, List<List<String>>> mlbSchedules = {
    'sample': [
      // Format: [Away, Home]
      ['New York Yankees', 'Boston Red Sox'],
      ['Los Angeles Dodgers', 'San Francisco Giants'],
      ['Houston Astros', 'Texas Rangers'],
      ['Atlanta Braves', 'Philadelphia Phillies'],
      ['Chicago Cubs', 'St. Louis Cardinals'],
      ['San Diego Padres', 'Arizona Diamondbacks'],
      ['Tampa Bay Rays', 'Baltimore Orioles'],
      ['Cleveland Guardians', 'Detroit Tigers'],
      ['Seattle Mariners', 'Oakland Athletics'],
      ['Minnesota Twins', 'Kansas City Royals'],
      ['Toronto Blue Jays', 'New York Mets'],
      ['Miami Marlins', 'Washington Nationals'],
      ['Milwaukee Brewers', 'Cincinnati Reds'],
      ['Pittsburgh Pirates', 'Chicago White Sox'],
      ['Colorado Rockies', 'Los Angeles Angels'],
    ],
  };

  // ─── BMB WEEKLY MIX (Feb 23-26, 2026 — real cross-sport slate) ───
  /// A curated mix of the hottest games across multiple sports this week.
  /// Updated weekly by BMB to create a fun, diverse pick 'em experience.
  static const List<List<String>> bmbWeeklyMixSchedule = [
    // NBA (2 games)
    ['San Antonio Spurs', 'Detroit Pistons'],              // NBA: SAS @ DET
    ['Cleveland Cavaliers', 'Oklahoma City Thunder'],      // NBA: CLE @ OKC
    // NCAA Men's Basketball (2 games)
    ['#21 St. John\'s', '#5 UConn'],                       // NCAAM: SJU @ UCONN
    ['#2 Houston', 'Kansas'],                              // NCAAM: HOU @ KU
    // NCAA Women's Basketball (2 games)
    ['USC', 'Ohio State'],                                 // NCAAW: USC @ OSU
    ['Alabama', 'Florida'],                                // NCAAW: BAMA @ UF
    // NHL (2 games)
    ['Buffalo Sabres', 'New Jersey Devils'],                // NHL: BUF @ NJD
    ['Toronto Maple Leafs', 'Tampa Bay Lightning'],         // NHL: TOR @ TBL
  ];

  // ─── NCAA SAMPLE SCHEDULES ───
  static const Map<String, List<List<String>>> ncaaSchedules = {
    'NCAA Basketball': [
      // Men's college basketball – real games this week [Away, Home]
      ['#21 St. John\'s', '#5 UConn'],
      ['#2 Houston', 'Kansas'],
      ['Mississippi State', '#12 Alabama'],
      ['USC', 'UCLA'],
      ['LSU', 'Ole Miss'],
      ['Texas A&M', 'Arkansas'],
      ['Kentucky', 'South Carolina'],
      ['Portland', '#7 Gonzaga'],
      ['Creighton', '#5 UConn'],
      ['#4 Arizona', '#23 BYU'],
    ],
    'NCAA Football': [
      // College football (post-season / bowl season placeholder)
      ['Ohio State', 'Michigan'],
      ['Alabama', 'Auburn'],
      ['Texas', 'Oklahoma'],
      ['USC', 'UCLA'],
      ['Georgia', 'Florida'],
      ['Oregon', 'Washington'],
      ['Clemson', 'South Carolina'],
      ['Penn State', 'Michigan State'],
    ],
    'NCAA Women\'s Basketball': [
      // Women's college basketball – real games this week [Away, Home]
      ['USC', 'Ohio State'],
      ['Alabama', 'Florida'],
      ['Pittsburgh', 'North Carolina'],
      ['Tennessee', 'South Carolina'],
      ['Stanford', 'Oregon'],
      ['Iowa', 'Indiana'],
      ['LSU', 'Texas'],
      ['#2 UCLA', 'Oregon State'],
    ],
  };

  /// Get available NFL weeks
  static List<int> get availableNflWeeks => nflWeeklySchedules.keys.toList()..sort();

  /// Get matchups for a specific NFL week
  static List<List<String>> getNflWeekMatchups(int week) {
    return nflWeeklySchedules[week] ?? [];
  }

  /// Get sample matchups for NBA (Away @ Home).
  static List<List<String>> getNbaMatchups() => nbaSchedules['sample'] ?? [];

  /// Get sample matchups for NHL (Away @ Home).
  static List<List<String>> getNhlMatchups() => nhlSchedules['sample'] ?? [];

  /// Get sample matchups for MLB (Away @ Home).
  static List<List<String>> getMlbMatchups() => mlbSchedules['sample'] ?? [];

  /// Get the default home/away matchups for a given sport.
  /// Returns null if the sport doesn't have pre-built schedules.
  static List<List<String>>? getScheduleMatchups(String sport) {
    switch (sport) {
      case 'NBA': return getNbaMatchups();
      case 'NHL': return getNhlMatchups();
      case 'MLB': return getMlbMatchups();
      case 'BMB Weekly Mix': return bmbWeeklyMixSchedule;
      case 'NCAA Basketball':
      case 'NCAA Football':
      case "NCAA Women's Basketball":
        return ncaaSchedules[sport];
      default: return null;
    }
  }

  // ─── TEAM DATABASE ───
  static const Map<String, List<String>> _allTeams = {
    'NFL': [
      'Arizona Cardinals', 'Atlanta Falcons', 'Baltimore Ravens', 'Buffalo Bills',
      'Carolina Panthers', 'Chicago Bears', 'Cincinnati Bengals', 'Cleveland Browns',
      'Dallas Cowboys', 'Denver Broncos', 'Detroit Lions', 'Green Bay Packers',
      'Houston Texans', 'Indianapolis Colts', 'Jacksonville Jaguars', 'Kansas City Chiefs',
      'Las Vegas Raiders', 'Los Angeles Chargers', 'Los Angeles Rams', 'Miami Dolphins',
      'Minnesota Vikings', 'New England Patriots', 'New Orleans Saints', 'New York Giants',
      'New York Jets', 'Philadelphia Eagles', 'Pittsburgh Steelers', 'San Francisco 49ers',
      'Seattle Seahawks', 'Tampa Bay Buccaneers', 'Tennessee Titans', 'Washington Commanders',
    ],
    'NBA': [
      'Atlanta Hawks', 'Boston Celtics', 'Brooklyn Nets', 'Charlotte Hornets',
      'Chicago Bulls', 'Cleveland Cavaliers', 'Dallas Mavericks', 'Denver Nuggets',
      'Detroit Pistons', 'Golden State Warriors', 'Houston Rockets', 'Indiana Pacers',
      'Los Angeles Clippers', 'Los Angeles Lakers', 'Memphis Grizzlies', 'Miami Heat',
      'Milwaukee Bucks', 'Minnesota Timberwolves', 'New Orleans Pelicans', 'New York Knicks',
      'Oklahoma City Thunder', 'Orlando Magic', 'Philadelphia 76ers', 'Phoenix Suns',
      'Portland Trail Blazers', 'Sacramento Kings', 'San Antonio Spurs', 'Toronto Raptors',
      'Utah Jazz', 'Washington Wizards',
    ],
    'NCAA Basketball': [
      'Alabama Crimson Tide', 'Arizona Wildcats', 'Arkansas Razorbacks', 'Auburn Tigers',
      'Baylor Bears', 'BYU Cougars', 'Cincinnati Bearcats', 'Colorado Buffaloes',
      'Connecticut Huskies', 'Creighton Bluejays', 'Duke Blue Devils', 'Florida Gators',
      'Georgetown Hoyas', 'Gonzaga Bulldogs', 'Houston Cougars', 'Illinois Fighting Illini',
      'Indiana Hoosiers', 'Iowa Hawkeyes', 'Iowa State Cyclones', 'Kansas Jayhawks',
      'Kentucky Wildcats', 'Louisville Cardinals', 'Marquette Golden Eagles', 'Maryland Terrapins',
      'Memphis Tigers', 'Miami Hurricanes', 'Michigan Wolverines', 'Michigan State Spartans',
      'Mississippi State Bulldogs', 'Missouri Tigers', 'North Carolina Tar Heels', 'NC State Wolfpack',
      'Ohio State Buckeyes', 'Oklahoma Sooners', 'Oregon Ducks', 'Purdue Boilermakers',
      'Saint Mary\'s Gaels', 'San Diego State Aztecs', 'St. John\'s Red Storm', 'Syracuse Orange',
      'TCU Horned Frogs', 'Tennessee Volunteers', 'Texas Longhorns', 'Texas A&M Aggies',
      'Texas Tech Red Raiders', 'UCLA Bruins', 'USC Trojans', 'Villanova Wildcats',
      'Virginia Cavaliers', 'Virginia Tech Hokies', 'Wake Forest Demon Deacons', 'West Virginia Mountaineers',
      'Wisconsin Badgers', 'Xavier Musketeers',
    ],
    'MLB': [
      'Arizona Diamondbacks', 'Atlanta Braves', 'Baltimore Orioles', 'Boston Red Sox',
      'Chicago Cubs', 'Chicago White Sox', 'Cincinnati Reds', 'Cleveland Guardians',
      'Colorado Rockies', 'Detroit Tigers', 'Houston Astros', 'Kansas City Royals',
      'Los Angeles Angels', 'Los Angeles Dodgers', 'Miami Marlins', 'Milwaukee Brewers',
      'Minnesota Twins', 'New York Mets', 'New York Yankees', 'Oakland Athletics',
      'Philadelphia Phillies', 'Pittsburgh Pirates', 'San Diego Padres', 'San Francisco Giants',
      'Seattle Mariners', 'St. Louis Cardinals', 'Tampa Bay Rays', 'Texas Rangers',
      'Toronto Blue Jays', 'Washington Nationals',
    ],
    'NHL': [
      'Anaheim Ducks', 'Arizona Coyotes', 'Boston Bruins', 'Buffalo Sabres',
      'Calgary Flames', 'Carolina Hurricanes', 'Chicago Blackhawks', 'Colorado Avalanche',
      'Columbus Blue Jackets', 'Dallas Stars', 'Detroit Red Wings', 'Edmonton Oilers',
      'Florida Panthers', 'Los Angeles Kings', 'Minnesota Wild', 'Montreal Canadiens',
      'Nashville Predators', 'New Jersey Devils', 'New York Islanders', 'New York Rangers',
      'Ottawa Senators', 'Philadelphia Flyers', 'Pittsburgh Penguins', 'San Jose Sharks',
      'Seattle Kraken', 'St. Louis Blues', 'Tampa Bay Lightning', 'Toronto Maple Leafs',
      'Vancouver Canucks', 'Vegas Golden Knights', 'Washington Capitals', 'Winnipeg Jets',
    ],
  };
}

class TeamSuggestion {
  final String name;
  final String league;

  const TeamSuggestion({required this.name, required this.league});
}
