import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's favorite teams AND individual athletes.
///
/// Teams are sport-scoped: NFL, NBA, MLB, NHL, MLS, NCAA, NCAAF, etc.
/// Individual athletes are for sports like NASCAR, Tennis, Golf, UFC, Boxing.
///
/// The notification system uses these to deliver personalized score alerts:
/// "Your team just won!" / "Your driver finished P3!"
class FavoriteTeamsService {
  static const _teamsKey = 'bmb_favorite_teams';
  static const _athletesKey = 'bmb_favorite_athletes';
  static const _alertsEnabledKey = 'bmb_favorite_alerts_enabled';

  static final FavoriteTeamsService _instance = FavoriteTeamsService._internal();
  factory FavoriteTeamsService() => _instance;
  FavoriteTeamsService._internal();

  bool _initialized = false;

  // {sport: [team1, team2, ...]}
  Map<String, List<String>> _favorites = {};
  // {sport: [athlete1, athlete2, ...]}
  Map<String, List<String>> _athletes = {};
  bool _alertsEnabled = true;

  Map<String, List<String>> get favorites => Map.unmodifiable(_favorites);
  Map<String, List<String>> get athletes => Map.unmodifiable(_athletes);
  bool get alertsEnabled => _alertsEnabled;

  /// All followed team names (flat list for quick lookup).
  List<String> get allTeamNames =>
      _favorites.values.expand((t) => t).toList();

  /// All followed athlete names (flat list).
  List<String> get allAthleteNames =>
      _athletes.values.expand((a) => a).toList();

  /// True if user has at least one favorite team or athlete.
  bool get hasFavorites =>
      _favorites.values.any((l) => l.isNotEmpty) ||
      _athletes.values.any((l) => l.isNotEmpty);

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _alertsEnabled = prefs.getBool(_alertsEnabledKey) ?? true;

    final teamsRaw = prefs.getString(_teamsKey);
    if (teamsRaw != null) {
      try {
        final decoded = jsonDecode(teamsRaw) as Map<String, dynamic>;
        _favorites = decoded.map((k, v) =>
            MapEntry(k, (v as List).cast<String>()));
      } catch (_) {}
    }

    final athRaw = prefs.getString(_athletesKey);
    if (athRaw != null) {
      try {
        final decoded = jsonDecode(athRaw) as Map<String, dynamic>;
        _athletes = decoded.map((k, v) =>
            MapEntry(k, (v as List).cast<String>()));
      } catch (_) {}
    }

    _initialized = true;
  }

  // ─── TEAMS ─────────────────────────────────────────────────────────

  Future<void> addTeam(String sport, String team) async {
    _favorites.putIfAbsent(sport, () => []);
    if (!_favorites[sport]!.contains(team)) {
      _favorites[sport]!.add(team);
      await _persist();
    }
  }

  Future<void> removeTeam(String sport, String team) async {
    _favorites[sport]?.remove(team);
    await _persist();
  }

  bool isTeamFavorite(String sport, String team) =>
      _favorites[sport]?.contains(team) ?? false;

  List<String> teamsForSport(String sport) =>
      List.unmodifiable(_favorites[sport] ?? []);

  // ─── ATHLETES (individual sports) ──────────────────────────────────

  Future<void> addAthlete(String sport, String name) async {
    _athletes.putIfAbsent(sport, () => []);
    if (!_athletes[sport]!.contains(name)) {
      _athletes[sport]!.add(name);
      await _persist();
    }
  }

  Future<void> removeAthlete(String sport, String name) async {
    _athletes[sport]?.remove(name);
    await _persist();
  }

  bool isAthleteFavorite(String sport, String name) =>
      _athletes[sport]?.contains(name) ?? false;

  List<String> athletesForSport(String sport) =>
      List.unmodifiable(_athletes[sport] ?? []);

  // ─── ALERTS TOGGLE ─────────────────────────────────────────────────

  Future<void> setAlertsEnabled(bool value) async {
    _alertsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertsEnabledKey, value);
  }

  // ─── PERSISTENCE ───────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teamsKey,
        jsonEncode(_favorites.map((k, v) => MapEntry(k, v))));
    await prefs.setString(_athletesKey,
        jsonEncode(_athletes.map((k, v) => MapEntry(k, v))));
  }

  // ─── CATALOG — teams available per sport ───────────────────────────

  static const Map<String, List<String>> teamCatalog = {
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
    'MLS': [
      'Atlanta United', 'Austin FC', 'Charlotte FC', 'Chicago Fire',
      'Cincinnati FC', 'Colorado Rapids', 'Columbus Crew', 'Dallas FC',
      'Houston Dynamo', 'Inter Miami', 'LA Galaxy', 'LAFC',
      'Minnesota United', 'Nashville SC', 'New England Revolution', 'NYCFC',
      'NY Red Bulls', 'Orlando City', 'Philadelphia Union', 'Portland Timbers',
      'Real Salt Lake', 'San Jose Earthquakes', 'Seattle Sounders', 'Sporting KC',
      'St. Louis City', 'Toronto FC', 'Vancouver Whitecaps',
    ],
    'NCAA Basketball': [
      'Duke', 'North Carolina', 'Kansas', 'Kentucky', 'Gonzaga', 'Villanova',
      'UConn', 'Michigan State', 'UCLA', 'Arizona', 'Purdue', 'Houston',
      'Tennessee', 'Alabama', 'Baylor', 'Auburn', 'Creighton', 'Marquette',
      'Iowa State', 'Texas', 'Indiana', 'Ohio State', 'Michigan', 'Florida',
      'Wisconsin', 'Illinois', 'Oregon', 'Virginia', 'Memphis', 'Georgetown',
      'Syracuse', 'Louisville', 'Arkansas', 'LSU', 'St. Johns', 'Dayton',
    ],
    'NCAAF': [
      'Alabama', 'Ohio State', 'Georgia', 'Clemson', 'Michigan', 'Oklahoma',
      'LSU', 'Notre Dame', 'Texas', 'Penn State', 'Oregon', 'USC',
      'Florida', 'Auburn', 'Wisconsin', 'Tennessee', 'Miami (FL)', 'Oklahoma State',
      'Iowa', 'Washington', 'Utah', 'Baylor', 'Ole Miss', 'NC State',
      'Pittsburgh', 'Arkansas', 'Kentucky', 'Texas A&M', 'Colorado', 'Kansas State',
    ],
  };

  /// Individual sport athletes catalog
  static const Map<String, List<String>> athleteCatalog = {
    'NASCAR': [
      'Kyle Larson', 'Denny Hamlin', 'Martin Truex Jr.', 'Chase Elliott',
      'William Byron', 'Ross Chastain', 'Christopher Bell', 'Tyler Reddick',
      'Ryan Blaney', 'Bubba Wallace', 'Kyle Busch', 'Joey Logano',
      'Brad Keselowski', 'Alex Bowman', 'Daniel Suarez', 'Austin Cindric',
    ],
    'Tennis': [
      'Novak Djokovic', 'Carlos Alcaraz', 'Jannik Sinner', 'Daniil Medvedev',
      'Alexander Zverev', 'Andrey Rublev', 'Stefanos Tsitsipas', 'Holger Rune',
      'Iga Swiatek', 'Aryna Sabalenka', 'Coco Gauff', 'Jessica Pegula',
      'Elena Rybakina', 'Ons Jabeur', 'Zheng Qinwen', 'Mirra Andreeva',
    ],
    'Golf': [
      'Scottie Scheffler', 'Rory McIlroy', 'Jon Rahm', 'Xander Schauffele',
      'Collin Morikawa', 'Viktor Hovland', 'Patrick Cantlay', 'Wyndham Clark',
      'Ludvig Aberg', 'Max Homa', 'Sahith Theegala', 'Tommy Fleetwood',
      'Nelly Korda', 'Lydia Ko', 'Lilia Vu', 'Rose Zhang',
    ],
    'UFC / MMA': [
      'Jon Jones', 'Islam Makhachev', 'Alex Pereira', 'Leon Edwards',
      'Dricus Du Plessis', 'Sean O\'Malley', 'Ilia Topuria', 'Merab Dvalishvili',
      'Max Holloway', 'Dustin Poirier', 'Charles Oliveira', 'Belal Muhammad',
    ],
    'Boxing': [
      'Oleksandr Usyk', 'Terence Crawford', 'Canelo Alvarez', 'Naoya Inoue',
      'Tyson Fury', 'Gervonta Davis', 'Shakur Stevenson', 'Devin Haney',
      'Ryan Garcia', 'Jermell Charlo', 'Errol Spence Jr.', 'Dmitry Bivol',
    ],
  };

  /// All sport categories in order.
  static List<String> get allSports => [...teamCatalog.keys, ...athleteCatalog.keys];

  /// Whether a sport is individual (athlete-based) vs team-based.
  static bool isIndividualSport(String sport) => athleteCatalog.containsKey(sport);
}
