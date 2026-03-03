import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Real-time sports data from ESPN's free public API.
///
/// Endpoints (no auth required):
///   Scoreboard: site.api.espn.com/apis/site/v2/sports/{sport}/{league}/scoreboard
///   News:       site.api.espn.com/apis/site/v2/sports/{sport}/{league}/news
///
/// Covers: NBA, NFL, MLB, NHL, MLS, NCAA Basketball, NCAA Football,
///         PGA (golf), UFC (MMA), EPL (soccer), La Liga, Serie A, Bundesliga.
class EspnSportsService {
  EspnSportsService._();
  static final EspnSportsService instance = EspnSportsService._();

  static const _base = 'https://site.api.espn.com/apis/site/v2/sports';

  // ─── LEAGUE REGISTRY ────────────────────────────────────────────────
  /// Each entry: sport path / league path, display abbreviation, icon hint.
  static const List<_LeagueConfig> _leagues = [
    _LeagueConfig('basketball', 'nba', 'NBA'),
    _LeagueConfig('football', 'nfl', 'NFL'),
    _LeagueConfig('baseball', 'mlb', 'MLB'),
    _LeagueConfig('hockey', 'nhl', 'NHL'),
    _LeagueConfig('soccer', 'usa.1', 'MLS'),
    _LeagueConfig('basketball', 'mens-college-basketball', 'NCAAM'),
    _LeagueConfig('football', 'college-football', 'NCAAF'),
    _LeagueConfig('soccer', 'eng.1', 'EPL'),
    _LeagueConfig('golf', 'pga', 'PGA'),
    _LeagueConfig('mma', 'ufc', 'UFC'),
  ];

  // ─── CACHED DATA ────────────────────────────────────────────────────
  List<LiveScore> _scores = [];
  List<HeadlineItem> _headlines = [];
  DateTime? _lastScoreFetch;
  DateTime? _lastNewsFetch;
  bool _fetching = false;

  List<LiveScore> get scores => List.unmodifiable(_scores);
  List<HeadlineItem> get headlines => List.unmodifiable(_headlines);

  /// Whether we have at least one game that is currently in progress.
  bool get hasLiveGames => _scores.any((s) => s.isLive);

  // ─── PUBLIC FETCH METHODS ───────────────────────────────────────────

  /// Fetch live scores across all leagues.
  /// Caches for [minInterval] seconds (default 30) to avoid hammering ESPN.
  Future<List<LiveScore>> fetchScores({int minInterval = 30}) async {
    if (_fetching) return _scores;
    final now = DateTime.now();
    if (_lastScoreFetch != null &&
        now.difference(_lastScoreFetch!).inSeconds < minInterval) {
      return _scores;
    }
    _fetching = true;
    try {
      final results = <LiveScore>[];
      // Fetch all leagues in parallel
      final futures = _leagues.map((cfg) => _fetchLeagueScores(cfg));
      final batches = await Future.wait(futures);
      for (final batch in batches) {
        results.addAll(batch);
      }
      // Sort: live games first, then upcoming, then final
      results.sort((a, b) {
        if (a.isLive && !b.isLive) return -1;
        if (!a.isLive && b.isLive) return 1;
        if (a.isUpcoming && !b.isUpcoming) return -1;
        if (!a.isUpcoming && b.isUpcoming) return 1;
        return 0;
      });
      _scores = results;
      _lastScoreFetch = now;
    } catch (e) {
      if (kDebugMode) debugPrint('[ESPN] Score fetch error: $e');
    }
    _fetching = false;
    return _scores;
  }

  /// Fetch top headlines across major leagues.
  Future<List<HeadlineItem>> fetchHeadlines({int minInterval = 120}) async {
    final now = DateTime.now();
    if (_lastNewsFetch != null &&
        now.difference(_lastNewsFetch!).inSeconds < minInterval) {
      return _headlines;
    }
    try {
      final results = <HeadlineItem>[];
      // Only fetch news for the 4 majors + NCAA to keep it fast
      final newsLeagues = _leagues.where(
          (c) => ['NBA', 'NFL', 'MLB', 'NHL', 'NCAAM'].contains(c.label));
      final futures = newsLeagues.map((cfg) => _fetchLeagueNews(cfg));
      final batches = await Future.wait(futures);
      for (final batch in batches) {
        results.addAll(batch);
      }
      _headlines = results;
      _lastNewsFetch = now;
    } catch (e) {
      if (kDebugMode) debugPrint('[ESPN] News fetch error: $e');
    }
    return _headlines;
  }

  /// Force-refresh everything (ignores cache).
  Future<void> forceRefresh() async {
    _lastScoreFetch = null;
    _lastNewsFetch = null;
    await Future.wait([fetchScores(), fetchHeadlines()]);
  }

  // ─── PRIVATE: Per-league fetchers ──────────────────────────────────

  Future<List<LiveScore>> _fetchLeagueScores(_LeagueConfig cfg) async {
    try {
      final url = Uri.parse('$_base/${cfg.sport}/${cfg.league}/scoreboard');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final events = json['events'] as List<dynamic>? ?? [];
      return events.map((e) => _parseEvent(e, cfg.label)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[ESPN] ${cfg.label} score error: $e');
      return [];
    }
  }

  Future<List<HeadlineItem>> _fetchLeagueNews(_LeagueConfig cfg) async {
    try {
      final url =
          Uri.parse('$_base/${cfg.sport}/${cfg.league}/news?limit=3');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final articles = json['articles'] as List<dynamic>? ?? [];
      return articles.map((a) {
        return HeadlineItem(
          league: cfg.label,
          headline: a['headline'] as String? ?? '',
          description: a['description'] as String? ?? '',
          type: _categorizeHeadline(a['headline'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[ESPN] ${cfg.label} news error: $e');
      return [];
    }
  }

  // ─── PARSERS ────────────────────────────────────────────────────────

  LiveScore _parseEvent(dynamic event, String leagueLabel) {
    final comp = (event['competitions'] as List<dynamic>).first;
    final competitors = comp['competitors'] as List<dynamic>;
    final statusMap = comp['status'] as Map<String, dynamic>;
    final statusType = statusMap['type'] as Map<String, dynamic>;

    // Away / Home
    final awayData = competitors.firstWhere(
        (c) => c['homeAway'] == 'away',
        orElse: () => competitors.last);
    final homeData = competitors.firstWhere(
        (c) => c['homeAway'] == 'home',
        orElse: () => competitors.first);

    final awayTeam = awayData['team'] as Map<String, dynamic>;
    final homeTeam = homeData['team'] as Map<String, dynamic>;

    return LiveScore(
      league: leagueLabel,
      awayAbbr: awayTeam['abbreviation'] as String? ?? '?',
      homeAbbr: homeTeam['abbreviation'] as String? ?? '?',
      awayName: awayTeam['shortDisplayName'] as String? ??
          awayTeam['displayName'] as String? ??
          '?',
      homeName: homeTeam['shortDisplayName'] as String? ??
          homeTeam['displayName'] as String? ??
          '?',
      awayScore: awayData['score'] as String? ?? '0',
      homeScore: homeData['score'] as String? ?? '0',
      statusShort: statusType['shortDetail'] as String? ?? '',
      statusState: statusType['state'] as String? ?? 'pre',
      // state: "pre" | "in" | "post"
      awayLogo: awayTeam['logo'] as String?,
      homeLogo: homeTeam['logo'] as String?,
      gameId: event['id'] as String? ?? '',
    );
  }

  HeadlineType _categorizeHeadline(String headline) {
    final h = headline.toLowerCase();
    if (h.contains('injur') ||
        h.contains('out for') ||
        h.contains('day-to-day') ||
        h.contains('questionable') ||
        h.contains('ruled out') ||
        h.contains('torn') ||
        h.contains('sprain') ||
        h.contains('concussion')) {
      return HeadlineType.injury;
    }
    if (h.contains('trade') ||
        h.contains('sign') ||
        h.contains('waive') ||
        h.contains('release') ||
        h.contains('free agent') ||
        h.contains('contract')) {
      return HeadlineType.trade;
    }
    if (h.contains('suspend') || h.contains('fine') || h.contains('eject')) {
      return HeadlineType.suspension;
    }
    if (h.contains('upset') || h.contains('stunner') || h.contains('shock')) {
      return HeadlineType.upset;
    }
    return HeadlineType.general;
  }
}

// ═══════════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════════

class LiveScore {
  final String league; // "NBA", "NFL", etc.
  final String awayAbbr;
  final String homeAbbr;
  final String awayName;
  final String homeName;
  final String awayScore;
  final String homeScore;
  final String statusShort; // "Q4 2:30", "FINAL", "7:00 PM EST"
  final String statusState; // "pre", "in", "post"
  final String? awayLogo;
  final String? homeLogo;
  final String gameId;

  const LiveScore({
    required this.league,
    required this.awayAbbr,
    required this.homeAbbr,
    required this.awayName,
    required this.homeName,
    required this.awayScore,
    required this.homeScore,
    required this.statusShort,
    required this.statusState,
    this.awayLogo,
    this.homeLogo,
    this.gameId = '',
  });

  /// Game is currently being played.
  bool get isLive => statusState == 'in';

  /// Game hasn't started yet.
  bool get isUpcoming => statusState == 'pre';

  /// Game is finished.
  bool get isFinal => statusState == 'post';

  /// Compact ticker string: "LAL 112 - BOS 108"
  String get scoreLine => '$awayAbbr $awayScore - $homeAbbr $homeScore';

  /// Status label for ticker badge
  String get tickerStatus {
    if (isLive) return statusShort; // "Q4 2:30", "3RD PER", "7TH INN"
    if (isFinal) return 'FINAL';
    // Upcoming — show just the time portion
    return statusShort;
  }
}

enum HeadlineType { general, injury, trade, suspension, upset }

class HeadlineItem {
  final String league;
  final String headline;
  final String description;
  final HeadlineType type;

  const HeadlineItem({
    required this.league,
    required this.headline,
    this.description = '',
    this.type = HeadlineType.general,
  });

  bool get isBreaking =>
      type == HeadlineType.injury ||
      type == HeadlineType.trade ||
      type == HeadlineType.suspension;
}

// ─── Internal league config ──────────────────────────────────────────

class _LeagueConfig {
  final String sport;
  final String league;
  final String label;
  const _LeagueConfig(this.sport, this.league, this.label);
}
