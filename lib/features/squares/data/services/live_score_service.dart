import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ─── LIVE SCORE SERVICE ─────────────────────────────────────────────────────
/// Pulls real-time scores from ESPN's public API endpoints.
/// Falls back to simulated scores for demo purposes.
///
/// ESPN endpoints used (public, no API key required):
///   Football (NFL): https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard
///   Basketball (NBA): https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard
///   Basketball (NCAAM): https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard
///   Hockey (NHL): https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard

class LiveScoreService {
  static final LiveScoreService _instance = LiveScoreService._internal();
  factory LiveScoreService() => _instance;
  LiveScoreService._internal();

  Timer? _pollTimer;
  final _scoreController = StreamController<LiveScoreUpdate>.broadcast();

  Stream<LiveScoreUpdate> get scoreStream => _scoreController.stream;

  /// ESPN API base URLs by sport
  static const Map<String, String> _espnEndpoints = {
    'football': 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard',
    'basketball': 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard',
    'basketball_ncaa': 'https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard',
    'hockey': 'https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard',
  };

  /// Fetch live scores from ESPN
  Future<List<EspnGame>> fetchLiveScores(String sport) async {
    final endpoint = _espnEndpoints[sport] ?? _espnEndpoints['football']!;

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseEspnResponse(data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ESPN fetch failed: $e — using simulated scores');
      }
    }

    return [];
  }

  /// Parse ESPN API response into EspnGame objects
  List<EspnGame> _parseEspnResponse(Map<String, dynamic> data) {
    final games = <EspnGame>[];

    try {
      final events = data['events'] as List<dynamic>? ?? [];

      for (final event in events) {
        final competitions = event['competitions'] as List<dynamic>? ?? [];
        if (competitions.isEmpty) continue;

        final comp = competitions[0];
        final competitors = comp['competitors'] as List<dynamic>? ?? [];
        if (competitors.length < 2) continue;

        // ESPN lists home first, away second — or vice versa
        final home = competitors.firstWhere(
          (c) => c['homeAway'] == 'home',
          orElse: () => competitors[0],
        );
        final away = competitors.firstWhere(
          (c) => c['homeAway'] == 'away',
          orElse: () => competitors[1],
        );

        final status = comp['status'] as Map<String, dynamic>?;
        final period = status?['period'] as int? ?? 0;
        final statusType = status?['type'] as Map<String, dynamic>?;
        final statusName = statusType?['name'] as String? ?? '';

        // Extract line scores (per-period scores)
        final homeLineScores = _extractLineScores(home);
        final awayLineScores = _extractLineScores(away);

        games.add(EspnGame(
          eventId: event['id']?.toString() ?? '',
          name: event['name']?.toString() ?? '',
          shortName: event['shortName']?.toString() ?? '',
          homeTeam: home['team']?['displayName']?.toString() ?? 'Home',
          awayTeam: away['team']?['displayName']?.toString() ?? 'Away',
          homeScore: int.tryParse(home['score']?.toString() ?? '0') ?? 0,
          awayScore: int.tryParse(away['score']?.toString() ?? '0') ?? 0,
          period: period,
          statusName: statusName,
          isLive: statusName == 'STATUS_IN_PROGRESS',
          isFinal: statusName == 'STATUS_FINAL',
          homeLineScores: homeLineScores,
          awayLineScores: awayLineScores,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ESPN parse error: $e');
      }
    }

    return games;
  }

  List<int> _extractLineScores(Map<String, dynamic> competitor) {
    try {
      final lineScores = competitor['linescores'] as List<dynamic>? ?? [];
      return lineScores.map((ls) => int.tryParse(ls['value']?.toString() ?? '0') ?? 0).toList();
    } catch (_) {
      return [];
    }
  }

  /// Convert ESPN game data to QuarterScore entries (cumulative)
  List<QuarterScoreData> getQuarterScores(EspnGame game, List<String> periodLabels) {
    final scores = <QuarterScoreData>[];
    int homeCum = 0;
    int awayCum = 0;

    final maxPeriods = game.homeLineScores.length.clamp(0, periodLabels.length);

    for (int i = 0; i < maxPeriods; i++) {
      homeCum += i < game.awayLineScores.length ? game.awayLineScores[i] : 0; // team1 = away (columns)
      awayCum += i < game.homeLineScores.length ? game.homeLineScores[i] : 0; // team2 = home (rows)

      scores.add(QuarterScoreData(
        quarter: periodLabels[i],
        team1Score: homeCum,
        team2Score: awayCum,
        isFinal: i == maxPeriods - 1 && game.isFinal,
      ));
    }

    return scores;
  }

  // ─── POLLING ────────────────────────────────────────────────────────────

  /// Start polling ESPN for score updates every [intervalSeconds]
  void startPolling(String sport, {int intervalSeconds = 30, required void Function(List<EspnGame>) onUpdate}) {
    stopPolling();
    _pollTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      final games = await fetchLiveScores(sport);
      if (games.isNotEmpty) {
        onUpdate(games);
      }
    });
    // Also fetch immediately
    fetchLiveScores(sport).then((games) {
      if (games.isNotEmpty) onUpdate(games);
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ─── SIMULATED SCORES (for demo when ESPN unavailable) ─────────────────

  /// Simulate quarter-by-quarter scores for a football game
  static List<QuarterScoreData> simulateFootballScores(String team1, String team2) {
    final rand = Random();
    int t1 = 0, t2 = 0;
    final labels = ['Q1', 'Q2', 'Q3', 'Q4'];
    final scores = <QuarterScoreData>[];

    for (int i = 0; i < 4; i++) {
      // Football scoring: 0, 3, 7, 10, 14 point increments
      final t1Add = [0, 0, 3, 3, 7, 7, 10, 14][rand.nextInt(8)];
      final t2Add = [0, 0, 3, 3, 7, 7, 10, 14][rand.nextInt(8)];
      t1 += t1Add;
      t2 += t2Add;
      scores.add(QuarterScoreData(
        quarter: labels[i],
        team1Score: t1,
        team2Score: t2,
        isFinal: i == 3,
      ));
    }
    return scores;
  }

  /// Simulate quarter-by-quarter scores for a basketball game
  static List<QuarterScoreData> simulateBasketballScores(String team1, String team2) {
    final rand = Random();
    int t1 = 0, t2 = 0;
    final labels = ['Q1', 'Q2', 'Q3', 'Q4'];
    final scores = <QuarterScoreData>[];

    for (int i = 0; i < 4; i++) {
      t1 += 18 + rand.nextInt(14); // 18-31 points per quarter
      t2 += 18 + rand.nextInt(14);
      scores.add(QuarterScoreData(
        quarter: labels[i],
        team1Score: t1,
        team2Score: t2,
        isFinal: i == 3,
      ));
    }
    return scores;
  }

  /// Simulate scores based on sport type
  static List<QuarterScoreData> simulateScores(String sportKey, String team1, String team2) {
    switch (sportKey) {
      case 'basketball':
        return simulateBasketballScores(team1, team2);
      case 'hockey':
        final rand = Random();
        int t1 = 0, t2 = 0;
        final scores = <QuarterScoreData>[];
        for (int i = 0; i < 3; i++) {
          t1 += rand.nextInt(3);
          t2 += rand.nextInt(3);
          scores.add(QuarterScoreData(quarter: 'P${i + 1}', team1Score: t1, team2Score: t2, isFinal: i == 2));
        }
        return scores;
      default:
        return simulateFootballScores(team1, team2);
    }
  }

  void dispose() {
    stopPolling();
    _scoreController.close();
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────────────

class EspnGame {
  final String eventId;
  final String name;
  final String shortName;
  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final int period;
  final String statusName;
  final bool isLive;
  final bool isFinal;
  final List<int> homeLineScores;
  final List<int> awayLineScores;

  const EspnGame({
    required this.eventId,
    required this.name,
    required this.shortName,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.period,
    required this.statusName,
    required this.isLive,
    required this.isFinal,
    required this.homeLineScores,
    required this.awayLineScores,
  });
}

class QuarterScoreData {
  final String quarter;
  final int team1Score;
  final int team2Score;
  final bool isFinal;

  const QuarterScoreData({
    required this.quarter,
    required this.team1Score,
    required this.team2Score,
    this.isFinal = false,
  });
}

class LiveScoreUpdate {
  final String eventId;
  final List<QuarterScoreData> scores;
  final DateTime timestamp;

  const LiveScoreUpdate({
    required this.eventId,
    required this.scores,
    required this.timestamp,
  });
}
