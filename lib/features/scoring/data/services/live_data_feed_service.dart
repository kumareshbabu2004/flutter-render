import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';

/// Service that pulls live game data from ESPN and NCAA.com hidden APIs
/// to auto-update bracket results in real time.
///
/// Supported data sources:
/// 1. ESPN Hidden API — scoreboard, game details, bracket info
/// 2. NCAA.com Casablanca API — official NCAA tournament data
/// 3. henrygd/ncaa-api — free proxy wrapper for NCAA data
///
/// NOTE: These are *unofficial/hidden* APIs that ESPN & NCAA use internally.
/// They could change at any time. The service is built with fallback logic:
/// if one source fails, it tries the next.
class LiveDataFeedService {
  // ─── ESPN HIDDEN API ENDPOINTS ──────────────────────────────────
  // Documented at: https://gist.github.com/akeaswaran/b48b02f1c94f873c6655e7129910fc3b

  /// ESPN Scoreboard — returns today's games with live scores
  static const _espnScoreboardMen =
      'https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard';
  static const _espnScoreboardWomen =
      'https://site.api.espn.com/apis/site/v2/sports/basketball/womens-college-basketball/scoreboard';


  // ─── NCAA.COM CASABLANCA API ────────────────────────────────────
  // Returns official NCAA tournament bracket data

  /// NCAA Scoreboard by date
  static String _ncaaScoreboard(DateTime date, {String division = 'd1', String sport = 'basketball-men'}) =>
      'https://data.ncaa.com/casablanca/scoreboard/$sport/$division/'
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/scoreboard.json';

  // ─── HENRYGD NCAA API (FREE PROXY) ─────────────────────────────
  // GitHub: https://github.com/henrygd/ncaa-api
  static const _ncaaApiBase = 'https://ncaa-api.henrygd.me';

  static String _ncaaApiScoreboard(DateTime date, {String sport = 'basketball-men', String division = 'd1'}) =>
      '$_ncaaApiBase/scoreboard/$sport/$division/${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';


  // ─── FEED CONFIGURATION PER TEMPLATE ────────────────────────────

  /// Maps template dataFeedId to the appropriate API configuration
  static final Map<String, _FeedConfig> _feedConfigs = {
    'espn_ncaam': _FeedConfig(
      scoreboardUrl: _espnScoreboardMen,
      sport: 'basketball-men',
      division: 'd1',
      isWomens: false,
      leagueName: "NCAA Men's Basketball",
    ),
    'espn_ncaaw': _FeedConfig(
      scoreboardUrl: _espnScoreboardWomen,
      sport: 'basketball-women',
      division: 'd1',
      isWomens: true,
      leagueName: "NCAA Women's Basketball",
    ),
    'espn_nit': _FeedConfig(
      scoreboardUrl: _espnScoreboardMen,
      sport: 'basketball-men',
      division: 'd1',
      isWomens: false,
      leagueName: 'NIT',
      filterGroup: 'nit', // Filter NIT games from scoreboard
    ),
  };

  // ─── PUBLIC API ─────────────────────────────────────────────────

  /// Check if live data is available for a template
  static bool isLiveDataAvailable(String? dataFeedId) {
    return dataFeedId != null && _feedConfigs.containsKey(dataFeedId);
  }

  /// Get the data source display name
  static String getDataSourceName(String? dataFeedId) {
    if (dataFeedId == null) return 'Manual';
    final config = _feedConfigs[dataFeedId];
    return config?.leagueName ?? 'Manual';
  }

  /// Fetch live scores from ESPN/NCAA APIs.
  /// Returns a list of [LiveGameResult] objects.
  ///
  /// Falls back through multiple data sources:
  /// 1. ESPN Hidden API (primary)
  /// 2. NCAA.com Casablanca API (fallback)
  /// 3. henrygd NCAA proxy API (second fallback)
  static Future<LiveDataFeedResult> fetchLiveScores({
    required String dataFeedId,
    DateTime? date,
  }) async {
    final config = _feedConfigs[dataFeedId];
    if (config == null) {
      return LiveDataFeedResult(
        success: false,
        games: [],
        source: 'none',
        errorMessage: 'No feed config for "$dataFeedId"',
      );
    }

    final targetDate = date ?? DateTime.now();

    // Try ESPN first
    try {
      final espnGames = await _fetchFromEspn(config, targetDate);
      if (espnGames.isNotEmpty) {
        return LiveDataFeedResult(
          success: true,
          games: espnGames,
          source: 'ESPN',
          lastFetched: DateTime.now(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LiveFeed] ESPN failed: $e');
      }
    }

    // Fallback to NCAA.com
    try {
      final ncaaGames = await _fetchFromNcaaDotCom(config, targetDate);
      if (ncaaGames.isNotEmpty) {
        return LiveDataFeedResult(
          success: true,
          games: ncaaGames,
          source: 'NCAA.com',
          lastFetched: DateTime.now(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LiveFeed] NCAA.com failed: $e');
      }
    }

    // Second fallback: henrygd proxy
    try {
      final proxyGames = await _fetchFromNcaaProxy(config, targetDate);
      if (proxyGames.isNotEmpty) {
        return LiveDataFeedResult(
          success: true,
          games: proxyGames,
          source: 'NCAA API Proxy',
          lastFetched: DateTime.now(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LiveFeed] NCAA proxy failed: $e');
      }
    }

    return LiveDataFeedResult(
      success: false,
      games: [],
      source: 'none',
      errorMessage: 'All data sources failed for $dataFeedId',
    );
  }

  /// Fetch and parse the full NCAA tournament bracket structure from ESPN
  static Future<List<LiveGameResult>> fetchTournamentBracket({
    required String dataFeedId,
    int? year,
  }) async {
    final config = _feedConfigs[dataFeedId];
    if (config == null) return [];

    final seasonYear = year ?? DateTime.now().year;
    final bracketUrl =
        'https://site.api.espn.com/apis/site/v2/sports/basketball/'
        '${config.isWomens ? "womens" : "mens"}-college-basketball/scoreboard'
        '?groups=100&dates=$seasonYear';

    try {
      final response = await http.get(
        Uri.parse(bracketUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return _parseEspnScoreboard(json.decode(response.body), config);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LiveFeed] Bracket fetch failed: $e');
      }
    }
    return [];
  }

  // ─── ESPN PARSER ────────────────────────────────────────────────

  static Future<List<LiveGameResult>> _fetchFromEspn(
    _FeedConfig config,
    DateTime date,
  ) async {
    final dateStr = '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';

    final url = '${config.scoreboardUrl}?dates=$dateStr&limit=200';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) return [];
    final data = json.decode(response.body);
    return _parseEspnScoreboard(data, config);
  }

  static List<LiveGameResult> _parseEspnScoreboard(
    Map<String, dynamic> data,
    _FeedConfig config,
  ) {
    final events = data['events'] as List<dynamic>? ?? [];
    final games = <LiveGameResult>[];

    for (final event in events) {
      try {
        // Filter for NIT if needed
        if (config.filterGroup == 'nit') {
          final season = event['season'] as Map<String, dynamic>?;
          final slug = season?['slug']?.toString() ?? '';
          if (!slug.contains('nit') && !slug.contains('national-invitation')) {
            continue;
          }
        }

        final competitions = event['competitions'] as List<dynamic>? ?? [];
        if (competitions.isEmpty) continue;

        final comp = competitions[0] as Map<String, dynamic>;
        final competitors = comp['competitors'] as List<dynamic>? ?? [];
        if (competitors.length < 2) continue;

        // ESPN lists home first, away second in competitors
        final home = competitors[0] as Map<String, dynamic>;
        final away = competitors[1] as Map<String, dynamic>;

        final homeTeam = home['team'] as Map<String, dynamic>?;
        final awayTeam = away['team'] as Map<String, dynamic>?;

        final homeName = homeTeam?['displayName']?.toString() ?? homeTeam?['shortDisplayName']?.toString() ?? 'TBD';
        final awayName = awayTeam?['displayName']?.toString() ?? awayTeam?['shortDisplayName']?.toString() ?? 'TBD';

        final homeSeed = int.tryParse(home['curatedRank']?['current']?.toString() ?? '');
        final awaySeed = int.tryParse(away['curatedRank']?['current']?.toString() ?? '');

        final homeScore = int.tryParse(home['score']?.toString() ?? '');
        final awayScore = int.tryParse(away['score']?.toString() ?? '');

        final status = comp['status'] as Map<String, dynamic>?;
        final statusType = status?['type'] as Map<String, dynamic>?;
        final state = statusType?['state']?.toString() ?? 'pre';
        final completed = statusType?['completed'] == true || state == 'post';

        String? winner;
        if (completed && homeScore != null && awayScore != null) {
          if (homeScore > awayScore) {
            winner = homeSeed != null ? '($homeSeed) $homeName' : homeName;
          } else {
            winner = awaySeed != null ? '($awaySeed) $awayName' : awayName;
          }
        }

        games.add(LiveGameResult(
          eventId: event['id']?.toString() ?? '',
          team1: awaySeed != null ? '($awaySeed) $awayName' : awayName,
          team2: homeSeed != null ? '($homeSeed) $homeName' : homeName,
          team1Score: awayScore,
          team2Score: homeScore,
          team1Seed: awaySeed,
          team2Seed: homeSeed,
          winner: winner,
          isCompleted: completed,
          isInProgress: state == 'in',
          score: (homeScore != null && awayScore != null)
              ? '$awayScore-$homeScore'
              : null,
          statusText: statusType?['shortDetail']?.toString(),
          startTime: DateTime.tryParse(comp['date']?.toString() ?? ''),
          round: _extractRound(event),
        ));
      } catch (e) {
        // Skip malformed events
        continue;
      }
    }
    return games;
  }

  static String? _extractRound(Map<String, dynamic> event) {
    final season = event['season'] as Map<String, dynamic>?;
    final type = season?['type'] as Map<String, dynamic>?;
    return type?['name']?.toString();
  }

  // ─── NCAA.COM PARSER ────────────────────────────────────────────

  static Future<List<LiveGameResult>> _fetchFromNcaaDotCom(
    _FeedConfig config,
    DateTime date,
  ) async {
    final url = _ncaaScoreboard(date, sport: config.sport, division: config.division);

    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) return [];
    final data = json.decode(response.body);
    return _parseNcaaScoreboard(data);
  }

  static List<LiveGameResult> _parseNcaaScoreboard(Map<String, dynamic> data) {
    final games = <LiveGameResult>[];
    final gamesData = data['games'] as List<dynamic>? ?? [];

    for (final gameWrapper in gamesData) {
      try {
        final game = gameWrapper['game'] as Map<String, dynamic>? ?? gameWrapper;
        final home = game['home'] as Map<String, dynamic>?;
        final away = game['away'] as Map<String, dynamic>?;

        if (home == null || away == null) continue;

        final homeName = home['names']?['short']?.toString() ??
            home['names']?['full']?.toString() ?? 'TBD';
        final awayName = away['names']?['short']?.toString() ??
            away['names']?['full']?.toString() ?? 'TBD';

        final homeSeed = int.tryParse(home['seed']?.toString() ?? '');
        final awaySeed = int.tryParse(away['seed']?.toString() ?? '');

        final homeScore = int.tryParse(home['score']?.toString() ?? '');
        final awayScore = int.tryParse(away['score']?.toString() ?? '');

        final state = game['gameState']?.toString() ?? 'pre';
        final completed = state == 'final' || state == 'F';

        String? winner;
        if (completed && homeScore != null && awayScore != null) {
          if (homeScore > awayScore) {
            winner = homeSeed != null ? '($homeSeed) $homeName' : homeName;
          } else {
            winner = awaySeed != null ? '($awaySeed) $awayName' : awayName;
          }
        }

        games.add(LiveGameResult(
          eventId: game['gameID']?.toString() ?? '',
          team1: awaySeed != null ? '($awaySeed) $awayName' : awayName,
          team2: homeSeed != null ? '($homeSeed) $homeName' : homeName,
          team1Score: awayScore,
          team2Score: homeScore,
          team1Seed: awaySeed,
          team2Seed: homeSeed,
          winner: winner,
          isCompleted: completed,
          isInProgress: state == 'live' || state == 'I',
          score: (homeScore != null && awayScore != null) ? '$awayScore-$homeScore' : null,
          statusText: game['currentPeriod']?.toString(),
          startTime: DateTime.tryParse(game['startDate']?.toString() ?? ''),
        ));
      } catch (e) {
        continue;
      }
    }
    return games;
  }

  // ─── NCAA PROXY PARSER ──────────────────────────────────────────

  static Future<List<LiveGameResult>> _fetchFromNcaaProxy(
    _FeedConfig config,
    DateTime date,
  ) async {
    final url = _ncaaApiScoreboard(date, sport: config.sport, division: config.division);

    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) return [];
    final data = json.decode(response.body);
    return _parseNcaaScoreboard(data);
  }

  // ─── MATCH LIVE DATA TO BRACKET TEAMS ───────────────────────────

  /// Given live game results and bracket team names, match games to
  /// bracket positions using team name fuzzy matching and seed numbers.
  static Map<String, LiveGameResult> matchGamesToBracket({
    required List<LiveGameResult> liveGames,
    required List<String> bracketTeams,
    required Map<String, GameResult> existingGames,
  }) {
    final matched = <String, LiveGameResult>{};

    for (final entry in existingGames.entries) {
      final game = entry.value;
      if (game.isCompleted) continue; // Already have result

      // Try to find a live game matching team1 and team2
      for (final live in liveGames) {
        if (_teamsMatch(game.team1, live.team1, live.team2) &&
            _teamsMatch(game.team2, live.team1, live.team2) &&
            game.team1 != game.team2) {
          matched[entry.key] = live;
          break;
        }
      }
    }

    return matched;
  }

  /// Fuzzy match: check if a bracket team name matches either live team
  static bool _teamsMatch(String bracketTeam, String liveTeam1, String liveTeam2) {
    final normalized = _normalizeTeamName(bracketTeam);
    final norm1 = _normalizeTeamName(liveTeam1);
    final norm2 = _normalizeTeamName(liveTeam2);

    return normalized == norm1 || normalized == norm2 ||
           norm1.contains(normalized) || norm2.contains(normalized) ||
           normalized.contains(norm1) || normalized.contains(norm2);
  }

  /// Strip seed prefix and normalize for comparison
  static String _normalizeTeamName(String name) {
    return name
        .replaceFirst(RegExp(r'^\(\d+\)\s*'), '') // Remove "(N) " prefix
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); // Remove non-alphanumeric
  }

  // ─── POLLING / AUTO-REFRESH SUPPORT ─────────────────────────────

  /// Recommended poll interval based on game state
  static Duration getRecommendedPollInterval(LiveDataFeedResult result) {
    if (!result.success || result.games.isEmpty) {
      return const Duration(minutes: 30); // No games - check infrequently
    }

    final hasLiveGames = result.games.any((g) => g.isInProgress);
    final hasUpcomingGames = result.games.any((g) => !g.isCompleted && !g.isInProgress);

    if (hasLiveGames) {
      return const Duration(seconds: 30); // Live action - refresh often
    } else if (hasUpcomingGames) {
      return const Duration(minutes: 5); // Games coming up
    } else {
      return const Duration(minutes: 30); // All done for today
    }
  }
}

// ─── INTERNAL MODELS ──────────────────────────────────────────────

class _FeedConfig {
  final String scoreboardUrl;
  final String sport;
  final String division;
  final bool isWomens;
  final String leagueName;
  final String? filterGroup;

  const _FeedConfig({
    required this.scoreboardUrl,
    required this.sport,
    required this.division,
    required this.isWomens,
    required this.leagueName,
    this.filterGroup,
  });
}

// ─── PUBLIC MODELS ────────────────────────────────────────────────

/// Result of a live data feed fetch operation
class LiveDataFeedResult {
  final bool success;
  final List<LiveGameResult> games;
  final String source; // 'ESPN', 'NCAA.com', 'NCAA API Proxy', 'none'
  final String? errorMessage;
  final DateTime? lastFetched;

  const LiveDataFeedResult({
    required this.success,
    required this.games,
    required this.source,
    this.errorMessage,
    this.lastFetched,
  });

  int get completedGames => games.where((g) => g.isCompleted).length;
  int get liveGames => games.where((g) => g.isInProgress).length;
  int get upcomingGames => games.where((g) => !g.isCompleted && !g.isInProgress).length;
}

/// A single game result from a live data source
class LiveGameResult {
  final String eventId;
  final String team1;
  final String team2;
  final int? team1Score;
  final int? team2Score;
  final int? team1Seed;
  final int? team2Seed;
  final String? winner;
  final bool isCompleted;
  final bool isInProgress;
  final String? score;
  final String? statusText;
  final DateTime? startTime;
  final String? round;

  const LiveGameResult({
    required this.eventId,
    required this.team1,
    required this.team2,
    this.team1Score,
    this.team2Score,
    this.team1Seed,
    this.team2Seed,
    this.winner,
    this.isCompleted = false,
    this.isInProgress = false,
    this.score,
    this.statusText,
    this.startTime,
    this.round,
  });

  /// Total combined points (for tie-breaker calculation)
  int get totalPoints => (team1Score ?? 0) + (team2Score ?? 0);
}
