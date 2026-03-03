import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/bracket_template.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/features/scoring/data/services/live_data_feed_service.dart';

/// The OFFICIAL source of truth for template tournament results.
///
/// Architecture:
/// ┌─────────────────────────────────────────────────────────────┐
/// │  Live Data Feeds (ESPN / NCAA / SportsDataIO / Sportradar)  │
/// └──────────────────────┬──────────────────────────────────────┘
///                        ▼
/// ┌──────────────────────────────────────────────────┐
/// │         OfficialResultsRegistry (singleton)       │
/// │  One BracketResults per templateId (e.g.         │
/// │  "march_madness", "ncaa_womens_bb", "nit")       │
/// │                                                   │
/// │  Polls live data → updates official results       │
/// │  Notifies all subscribers when results change     │
/// └──────┬──────────┬──────────┬─────────────────────┘
///        ▼          ▼          ▼
///   HostBracket  HostBracket  HostBracket
///   (id: b_001)  (id: b_002)  (id: b_003)
///   template:    template:    template:
///   march_madness march_madness ncaa_womens_bb
///
/// Each host bracket reads from the official registry.
/// When the registry updates, ALL host brackets using that template
/// automatically get the updated results.
class OfficialResultsRegistry {
  OfficialResultsRegistry._();
  static final OfficialResultsRegistry instance = OfficialResultsRegistry._();

  // ─── STATE ──────────────────────────────────────────────────────

  /// Official results keyed by templateId (e.g. "march_madness")
  final Map<String, BracketResults> _officialResults = {};

  /// Last live feed result per templateId (for UI display)
  final Map<String, LiveDataFeedResult> _lastFeedResults = {};

  /// Last successful sync time per templateId
  final Map<String, DateTime> _lastSyncTimes = {};

  /// Active poll timers per templateId
  final Map<String, Timer> _pollTimers = {};

  /// Change listeners — notified when official results update
  final List<VoidCallback> _listeners = [];

  /// Data provider configuration
  DataProviderConfig _providerConfig = DataProviderConfig.free();

  // ─── PUBLIC API ─────────────────────────────────────────────────

  /// Get the current data provider config
  DataProviderConfig get providerConfig => _providerConfig;

  /// Set the data provider (free, SportsDataIO, or Sportradar)
  void setProviderConfig(DataProviderConfig config) {
    _providerConfig = config;
    if (kDebugMode) {
      debugPrint('[OfficialRegistry] Provider changed to: ${config.displayName}');
    }
  }

  /// Register a change listener
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Remove a change listener
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Get official results for a templateId.
  /// If no official results exist yet, initializes them from a reference bracket.
  BracketResults? getOfficialResults(String templateId) {
    return _officialResults[templateId];
  }

  /// Get the last live feed result for a template (for UI status display)
  LiveDataFeedResult? getLastFeedResult(String templateId) {
    return _lastFeedResults[templateId];
  }

  /// Get last sync time for a template
  DateTime? getLastSyncTime(String templateId) {
    return _lastSyncTimes[templateId];
  }

  /// Whether a templateId has official results available
  bool hasOfficialResults(String templateId) {
    return _officialResults.containsKey(templateId);
  }

  /// Check if a bracket should use the official registry (= it uses a known template)
  static bool shouldUseOfficialResults(CreatedBracket bracket) {
    if (bracket.templateId.startsWith('custom')) return false;
    return BracketTemplate.allTemplates.any((t) => t.id == bracket.templateId);
  }

  /// Initialize official results for a template from a reference bracket's team list.
  /// Called once when the first host bracket using this template is created.
  void initializeTemplate(String templateId, CreatedBracket referenceBracket) {
    if (_officialResults.containsKey(templateId)) return; // already init'd

    final template = BracketTemplate.allTemplates
        .firstWhere((t) => t.id == templateId, orElse: () => BracketTemplate.allTemplates.first);

    // Build empty game scaffold (no results yet — all TBD)
    final games = <String, GameResult>{};
    var currentTeams = List<String>.from(referenceBracket.teams);
    final totalRounds = referenceBracket.totalRounds;

    for (int round = 0; round < totalRounds; round++) {
      final nextTeams = <String>[];
      for (int m = 0; m < currentTeams.length; m += 2) {
        if (m + 1 < currentTeams.length) {
          final matchIdx = m ~/ 2;
          final gameId = 'r${round}_g$matchIdx';
          games[gameId] = GameResult(
            gameId: gameId,
            round: round,
            matchIndex: matchIdx,
            team1: currentTeams[m],
            team2: currentTeams[m + 1],
          );
          nextTeams.add('TBD');
        }
      }
      currentTeams = nextTeams;
    }

    _officialResults[templateId] = BracketResults(
      bracketId: 'official_$templateId',
      games: games,
      isAutoSynced: true,
      lastUpdated: DateTime.now(),
      source: 'initialized',
    );

    if (kDebugMode) {
      debugPrint('[OfficialRegistry] Initialized template: $templateId '
          '(${games.length} games, ${template.teamCount} teams)');
    }
  }

  /// Sync official results from live data feed for a templateId.
  /// This is the core method — it pulls data and updates the single
  /// source of truth that ALL host brackets inherit from.
  Future<SyncResult> syncTemplate(String templateId) async {
    final template = BracketTemplate.allTemplates
        .firstWhere((t) => t.id == templateId,
            orElse: () => BracketTemplate.allTemplates.first);

    final dataFeedId = template.dataFeedId;
    if (dataFeedId == null) {
      return SyncResult(success: false, message: 'No data feed for $templateId');
    }

    final current = _officialResults[templateId];
    if (current == null) {
      return SyncResult(success: false, message: 'Template not initialized');
    }
    if (current.isTournamentComplete) {
      return SyncResult(success: true, message: 'Tournament already complete', gamesUpdated: 0);
    }

    // Fetch from the configured provider
    LiveDataFeedResult feedResult;

    if (_providerConfig.tier == DataProviderTier.free) {
      // Free tier: ESPN → NCAA.com → henrygd proxy
      feedResult = await LiveDataFeedService.fetchLiveScores(
        dataFeedId: dataFeedId,
      );
    } else {
      // Paid tier: SportsDataIO or Sportradar
      // For now, falls back to the same free endpoints.
      // In production, these would hit authenticated paid API endpoints.
      feedResult = await _fetchFromPaidProvider(dataFeedId);
    }

    _lastFeedResults[templateId] = feedResult;

    if (!feedResult.success || feedResult.games.isEmpty) {
      return SyncResult(
        success: false,
        message: 'Feed returned no data (source: ${feedResult.source})',
        source: feedResult.source,
      );
    }

    // Match live games to official bracket games
    final matched = LiveDataFeedService.matchGamesToBracket(
      liveGames: feedResult.games,
      bracketTeams: current.games.values.expand((g) => [g.team1, g.team2]).toList(),
      existingGames: current.games,
    );

    if (matched.isEmpty) {
      _lastSyncTimes[templateId] = DateTime.now();
      return SyncResult(
        success: true,
        message: 'No new game results to apply',
        source: feedResult.source,
        gamesUpdated: 0,
      );
    }

    // Apply matched results to official games
    final updatedGames = Map<String, GameResult>.from(current.games);
    int gamesUpdated = 0;

    for (final entry in matched.entries) {
      final live = entry.value;
      if (live.isCompleted && live.winner != null) {
        final game = updatedGames[entry.key];
        if (game != null && !game.isCompleted) {
          updatedGames[entry.key] = game.copyWith(
            winner: live.winner,
            isCompleted: true,
            score: live.score,
            completedAt: DateTime.now(),
          );
          _advanceWinner(updatedGames, game.round, game.matchIndex,
              live.winner!, _totalRounds(current.games));
          gamesUpdated++;
        }
      }
    }

    if (gamesUpdated > 0) {
      _officialResults[templateId] = current.copyWith(
        games: updatedGames,
        lastUpdated: DateTime.now(),
        source: 'live_${feedResult.source}',
      );
      _lastSyncTimes[templateId] = DateTime.now();
      _notifyListeners();

      if (kDebugMode) {
        debugPrint('[OfficialRegistry] Updated $templateId: '
            '$gamesUpdated games from ${feedResult.source}');
      }
    }

    return SyncResult(
      success: true,
      message: '$gamesUpdated game(s) updated from ${feedResult.source}',
      source: feedResult.source,
      gamesUpdated: gamesUpdated,
      liveGamesInProgress: feedResult.liveGames,
    );
  }

  /// Start auto-polling for a templateId.
  /// Intelligently adjusts poll frequency based on game state.
  void startPolling(String templateId) {
    stopPolling(templateId); // Clear any existing timer

    // Initial sync
    syncTemplate(templateId).then((result) {
      if (kDebugMode) {
        debugPrint('[OfficialRegistry] Initial sync for $templateId: ${result.message}');
      }
      // Schedule next poll based on result
      _scheduleNextPoll(templateId);
    });
  }

  /// Stop auto-polling for a templateId
  void stopPolling(String templateId) {
    _pollTimers[templateId]?.cancel();
    _pollTimers.remove(templateId);
  }

  /// Stop all polling
  void stopAllPolling() {
    for (final timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
  }

  void _scheduleNextPoll(String templateId) {
    final feedResult = _lastFeedResults[templateId];
    Duration interval;

    if (feedResult != null) {
      interval = LiveDataFeedService.getRecommendedPollInterval(feedResult);
    } else {
      interval = const Duration(minutes: 5);
    }

    _pollTimers[templateId] = Timer(interval, () {
      syncTemplate(templateId).then((_) => _scheduleNextPoll(templateId));
    });

    if (kDebugMode) {
      debugPrint('[OfficialRegistry] Next poll for $templateId in ${interval.inSeconds}s');
    }
  }

  // ─── APPLY OFFICIAL RESULTS TO A HOST BRACKET ───────────────────

  /// Get the official results mapped to a specific host bracket.
  /// The official results use the same game IDs (r0_g0, r0_g1, etc.)
  /// so they directly overlay onto any host bracket using the same template.
  BracketResults getResultsForBracket(CreatedBracket bracket) {
    final official = _officialResults[bracket.templateId];
    if (official == null) {
      // Initialize if needed
      initializeTemplate(bracket.templateId, bracket);
      return _officialResults[bracket.templateId]!;
    }

    // Return a copy with the host bracket's ID (so scoring works per-bracket)
    return BracketResults(
      bracketId: bracket.id,
      games: official.games,
      isAutoSynced: true,
      lastUpdated: official.lastUpdated,
      source: official.source,
    );
  }

  // ─── PAID PROVIDER FETCH ────────────────────────────────────────

  Future<LiveDataFeedResult> _fetchFromPaidProvider(String dataFeedId) async {
    switch (_providerConfig.tier) {
      case DataProviderTier.sportsDataIO:
        // In production: hit SportsDataIO authenticated endpoint
        // For now, fall back to free ESPN/NCAA feeds
        if (kDebugMode) {
          debugPrint('[OfficialRegistry] SportsDataIO provider — '
              'falling back to free feeds (API key: ${_providerConfig.apiKey != null ? "set" : "not set"})');
        }
        return LiveDataFeedService.fetchLiveScores(dataFeedId: dataFeedId);

      case DataProviderTier.sportradar:
        // In production: hit Sportradar authenticated endpoint
        if (kDebugMode) {
          debugPrint('[OfficialRegistry] Sportradar provider — '
              'falling back to free feeds (API key: ${_providerConfig.apiKey != null ? "set" : "not set"})');
        }
        return LiveDataFeedService.fetchLiveScores(dataFeedId: dataFeedId);

      case DataProviderTier.free:
        return LiveDataFeedService.fetchLiveScores(dataFeedId: dataFeedId);
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────

  int _totalRounds(Map<String, GameResult> games) {
    int maxRound = 0;
    for (final game in games.values) {
      if (game.round > maxRound) maxRound = game.round;
    }
    return maxRound + 1;
  }

  static void _advanceWinner(Map<String, GameResult> games, int round,
      int matchIndex, String winner, int totalRounds) {
    final nextRound = round + 1;
    if (nextRound >= totalRounds) return;

    final nextMatchIndex = matchIndex ~/ 2;
    final nextGameId = 'r${nextRound}_g$nextMatchIndex';
    final nextGame = games[nextGameId];

    if (nextGame != null) {
      final isTeam1Slot = matchIndex % 2 == 0;
      games[nextGameId] = GameResult(
        gameId: nextGameId,
        round: nextRound,
        matchIndex: nextMatchIndex,
        team1: isTeam1Slot ? winner : nextGame.team1,
        team2: isTeam1Slot ? nextGame.team2 : winner,
        winner: nextGame.winner,
        isCompleted: nextGame.isCompleted,
        score: nextGame.score,
        completedAt: nextGame.completedAt,
      );
    }
  }

  /// Directly update official results for a template (used by simulation).
  void updateOfficialResults(String templateId, BracketResults results) {
    _officialResults[templateId] = results;
    _notifyListeners();
  }

  /// Reset everything (for testing)
  void reset() {
    stopAllPolling();
    _officialResults.clear();
    _lastFeedResults.clear();
    _lastSyncTimes.clear();
    _listeners.clear();
  }
}

// ═══════════════════════════════════════════════════════════════════
// ─── DATA PROVIDER CONFIGURATION ─────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

enum DataProviderTier { free, sportsDataIO, sportradar }

/// Configuration for which live data provider to use.
/// Supports free (ESPN/NCAA hidden APIs) and paid (SportsDataIO, Sportradar).
class DataProviderConfig {
  final DataProviderTier tier;
  final String displayName;
  final String? apiKey;
  final String? apiSecret;
  final String? baseUrl;
  final String description;
  final String pricing;
  final List<String> features;

  const DataProviderConfig({
    required this.tier,
    required this.displayName,
    this.apiKey,
    this.apiSecret,
    this.baseUrl,
    required this.description,
    required this.pricing,
    required this.features,
  });

  /// Free tier: ESPN + NCAA.com hidden APIs (no key required)
  factory DataProviderConfig.free() => const DataProviderConfig(
    tier: DataProviderTier.free,
    displayName: 'ESPN / NCAA.com (Free)',
    description:
        'Uses ESPN and NCAA.com hidden/unofficial APIs. '
        'Free, no API key required. Data is pulled from the same endpoints '
        'that power ESPN.com and NCAA.com websites. '
        'May be rate-limited or change without notice.',
    pricing: 'Free',
    features: [
      'Live scores from ESPN scoreboard API',
      'NCAA.com Casablanca bracket data',
      'henrygd/ncaa-api proxy fallback',
      'Auto-failover between 3 sources',
      'No API key required',
      '30-second refresh during live games',
    ],
  );

  /// Paid tier: SportsDataIO
  factory DataProviderConfig.sportsDataIO({String? apiKey}) => DataProviderConfig(
    tier: DataProviderTier.sportsDataIO,
    displayName: 'SportsDataIO',
    apiKey: apiKey,
    baseUrl: 'https://api.sportsdata.io/v3/cbb',
    description:
        'Professional-grade college basketball data API. '
        'Provides guaranteed uptime, official data, and comprehensive coverage '
        'including play-by-play, player stats, and betting odds.',
    pricing: 'Starting at \$50/month',
    features: [
      'Official licensed data',
      'Guaranteed 99.9% uptime SLA',
      'Real-time play-by-play',
      'Player-level statistics',
      'Historical data access',
      'Betting odds integration',
      'Dedicated API support',
      '10-second refresh during live games',
    ],
  );

  /// Paid tier: Sportradar
  factory DataProviderConfig.sportradar({String? apiKey}) => DataProviderConfig(
    tier: DataProviderTier.sportradar,
    displayName: 'Sportradar',
    apiKey: apiKey,
    baseUrl: 'https://api.sportradar.us/ncaamb/production',
    description:
        'Enterprise-level sports data from the official NCAA data partner. '
        'Powers major sportsbooks and media companies. '
        'Most comprehensive and reliable NCAA basketball data available.',
    pricing: 'Custom pricing (contact sales)',
    features: [
      'Official NCAA data partner',
      'Enterprise-grade reliability',
      'Real-time push notifications',
      'Full play-by-play coverage',
      'Advanced analytics and projections',
      'Team and player imagery',
      'Dedicated account manager',
      '5-second refresh during live games',
      'Webhook support for instant updates',
    ],
  );

  bool get isPaid => tier != DataProviderTier.free;
  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;
}

// ═══════════════════════════════════════════════════════════════════
// ─── SYNC RESULT ──────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;
  final String? source;
  final int gamesUpdated;
  final int liveGamesInProgress;

  const SyncResult({
    required this.success,
    required this.message,
    this.source,
    this.gamesUpdated = 0,
    this.liveGamesInProgress = 0,
  });
}
