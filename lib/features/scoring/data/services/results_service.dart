import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/features/scoring/data/services/live_data_feed_service.dart';
import 'package:bmb_mobile/features/scoring/data/services/official_results_registry.dart';

/// Manages bracket results for the entire app.
///
/// Architecture (template brackets):
///   Live Feed  ->  OfficialResultsRegistry (one per templateId)
///                      |
///                      +---> HostBracket A (reads from registry)
///                      +---> HostBracket B (reads from registry)
///                      +---> HostBracket C (reads from registry)
///
/// Custom brackets still use their own per-bracket results cache.
class ResultsService {
  // ─── PER-BRACKET CACHE (custom / non-template only) ──────────
  static final Map<String, BracketResults> _customResultsCache = {};

  // ─── USER PICKS ──────────────────────────────────────────────
  static final Map<String, List<UserPicks>> _picksCache = {};

  // ═══════════════════════════════════════════════════════════════
  //  CORE: GET RESULTS
  // ═══════════════════════════════════════════════════════════════

  /// Get official results for a bracket.
  ///
  /// - **Template brackets**: reads from [OfficialResultsRegistry].
  ///   Every host who chose the same template sees the SAME results.
  /// - **Custom brackets**: per-bracket cache with host-driven updates.
  static BracketResults getResults(CreatedBracket bracket) {
    if (_isTemplateBracket(bracket)) {
      return _getTemplateResults(bracket);
    }
    // Custom bracket — use local cache
    if (_customResultsCache.containsKey(bracket.id)) {
      return _customResultsCache[bracket.id]!;
    }
    final results = _generateCustomResults(bracket);
    _customResultsCache[bracket.id] = results;
    return results;
  }

  /// Whether this bracket auto-syncs via the official registry.
  static bool isAutoSynced(CreatedBracket bracket) {
    return _isTemplateBracket(bracket);
  }

  /// Whether this bracket uses a known BMB template.
  static bool _isTemplateBracket(CreatedBracket bracket) {
    return OfficialResultsRegistry.shouldUseOfficialResults(bracket);
  }

  // ═══════════════════════════════════════════════════════════════
  //  TEMPLATE BRACKET FLOW
  // ═══════════════════════════════════════════════════════════════

  /// Get results from the official registry, mapped to the host bracket's ID.
  static BracketResults _getTemplateResults(CreatedBracket bracket) {
    final registry = OfficialResultsRegistry.instance;

    // Ensure template is initialized (first host to use it seeds the scaffold)
    if (!registry.hasOfficialResults(bracket.templateId)) {
      registry.initializeTemplate(bracket.templateId, bracket);
    }

    // Return official results stamped with this host's bracket ID
    return registry.getResultsForBracket(bracket);
  }

  /// Trigger a live data sync for a template bracket.
  /// This updates the OfficialResultsRegistry which ALL host brackets
  /// using the same template will immediately inherit.
  static Future<SyncResult> syncTemplateLive(CreatedBracket bracket) async {
    if (!_isTemplateBracket(bracket)) {
      return const SyncResult(
        success: false,
        message: 'Not a template bracket',
      );
    }

    final registry = OfficialResultsRegistry.instance;

    // Ensure initialized
    if (!registry.hasOfficialResults(bracket.templateId)) {
      registry.initializeTemplate(bracket.templateId, bracket);
    }

    return registry.syncTemplate(bracket.templateId);
  }

  /// Start auto-polling for a template bracket.
  /// The registry handles the polling — when it updates, all host brackets
  /// using the same template will see the new results immediately.
  static void startLivePolling(CreatedBracket bracket) {
    if (!_isTemplateBracket(bracket)) return;
    final registry = OfficialResultsRegistry.instance;
    if (!registry.hasOfficialResults(bracket.templateId)) {
      registry.initializeTemplate(bracket.templateId, bracket);
    }
    registry.startPolling(bracket.templateId);
  }

  /// Stop live polling for a template bracket.
  static void stopLivePolling(CreatedBracket bracket) {
    if (!_isTemplateBracket(bracket)) return;
    OfficialResultsRegistry.instance.stopPolling(bracket.templateId);
  }

  /// Legacy entry point — maintained for backward-compat.
  /// Delegates to the registry for templates, simulation for custom.
  static Future<BracketResults> autoSyncUpdateLive(CreatedBracket bracket) async {
    if (_isTemplateBracket(bracket)) {
      final result = await syncTemplateLive(bracket);
      if (kDebugMode) {
        debugPrint('[ResultsService] Live sync: ${result.message}');
      }
      return getResults(bracket);
    }
    // Custom brackets don't auto-sync
    return getResults(bracket);
  }

  /// Simulate one game advance (demo/test mode only).
  /// For template brackets this updates the official registry so ALL
  /// host brackets using the same template will see the update.
  static BracketResults autoSyncUpdate(CreatedBracket bracket) {
    if (_isTemplateBracket(bracket)) {
      return _simulateTemplateAdvance(bracket);
    }
    // Custom brackets don't auto-advance
    return getResults(bracket);
  }

  /// Simulate advancing one game in the official registry.
  static BracketResults _simulateTemplateAdvance(CreatedBracket bracket) {
    final registry = OfficialResultsRegistry.instance;
    if (!registry.hasOfficialResults(bracket.templateId)) {
      registry.initializeTemplate(bracket.templateId, bracket);
    }

    final official = registry.getOfficialResults(bracket.templateId);
    if (official == null || official.isTournamentComplete) {
      return getResults(bracket);
    }

    final updatedGames = Map<String, GameResult>.from(official.games);
    final totalRounds = _totalRoundsFromGames(updatedGames);

    // Find first incomplete game whose both teams are determined
    for (final entry in updatedGames.entries) {
      final game = entry.value;
      if (!game.isCompleted && game.team1 != 'TBD' && game.team2 != 'TBD') {
        final rng = Random();
        final winner = rng.nextBool() ? game.team1 : game.team2;
        final s1 = 60 + rng.nextInt(40);
        final s2 = 55 + rng.nextInt(35);
        updatedGames[entry.key] = game.copyWith(
          winner: winner,
          isCompleted: true,
          score: '$s1-$s2',
          completedAt: DateTime.now(),
        );
        _advanceWinner(updatedGames, game.round, game.matchIndex, winner, totalRounds);
        break;
      }
    }

    // Write back to the registry — every host bracket inherits immediately
    registry.updateOfficialResults(
      bracket.templateId,
      official.copyWith(
        games: updatedGames,
        lastUpdated: DateTime.now(),
        source: 'simulated',
      ),
    );

    return getResults(bracket);
  }

  // ═══════════════════════════════════════════════════════════════
  //  LIVE FEED STATUS (for UI badges)
  // ═══════════════════════════════════════════════════════════════

  /// Get the last live feed result for a bracket (template or custom).
  static LiveDataFeedResult? getLastLiveFeedResult(CreatedBracket bracket) {
    if (_isTemplateBracket(bracket)) {
      return OfficialResultsRegistry.instance
          .getLastFeedResult(bracket.templateId);
    }
    return null;
  }

  /// Get last sync time for a template bracket
  static DateTime? getLastSyncTime(CreatedBracket bracket) {
    if (_isTemplateBracket(bracket)) {
      return OfficialResultsRegistry.instance
          .getLastSyncTime(bracket.templateId);
    }
    return null;
  }

  /// Get the data provider config currently in use
  static DataProviderConfig get currentProvider =>
      OfficialResultsRegistry.instance.providerConfig;

  /// Set the data provider (ESPN free, SportsDataIO, Sportradar)
  static void setDataProvider(DataProviderConfig config) {
    OfficialResultsRegistry.instance.setProviderConfig(config);
  }

  // ═══════════════════════════════════════════════════════════════
  //  CUSTOM BRACKET: HOST-DRIVEN UPDATES
  // ═══════════════════════════════════════════════════════════════

  /// For custom brackets — host manually sets a game winner.
  static BracketResults setGameResult({
    required CreatedBracket bracket,
    required String gameId,
    required String winner,
    String? score,
  }) {
    if (_isTemplateBracket(bracket)) {
      // Template brackets don't allow manual updates
      if (kDebugMode) {
        debugPrint('[ResultsService] Cannot manually update a template bracket');
      }
      return getResults(bracket);
    }

    final current = getResults(bracket);
    final updatedGames = Map<String, GameResult>.from(current.games);

    final game = updatedGames[gameId];
    if (game == null) return current;

    updatedGames[gameId] = game.copyWith(
      winner: winner,
      isCompleted: true,
      score: score,
      completedAt: DateTime.now(),
    );

    _advanceWinner(updatedGames, game.round, game.matchIndex, winner,
        bracket.totalRounds);

    final updated = current.copyWith(
      games: updatedGames,
      lastUpdated: DateTime.now(),
      source: 'host_manual',
    );
    _customResultsCache[bracket.id] = updated;
    return updated;
  }

  /// For custom brackets — host renames TBD teams and sets the winner in one step.
  /// This updates the game's team1/team2 names AND records the winner.
  static BracketResults renameTeamsAndSetResult({
    required CreatedBracket bracket,
    required String gameId,
    required String newTeam1,
    required String newTeam2,
    required String winner,
    String? score,
  }) {
    if (_isTemplateBracket(bracket)) return getResults(bracket);

    final current = getResults(bracket);
    final updatedGames = Map<String, GameResult>.from(current.games);

    final game = updatedGames[gameId];
    if (game == null) return current;

    // Update team names and set the winner
    updatedGames[gameId] = GameResult(
      gameId: game.gameId,
      round: game.round,
      matchIndex: game.matchIndex,
      team1: newTeam1,
      team2: newTeam2,
      winner: winner,
      isCompleted: true,
      score: score,
      completedAt: DateTime.now(),
    );

    _advanceWinner(updatedGames, game.round, game.matchIndex, winner,
        bracket.totalRounds);

    final updated = current.copyWith(
      games: updatedGames,
      lastUpdated: DateTime.now(),
      source: 'host_manual',
    );
    _customResultsCache[bracket.id] = updated;
    return updated;
  }

  /// Undo a game result (host correction — custom brackets only).
  static BracketResults undoGameResult({
    required CreatedBracket bracket,
    required String gameId,
  }) {
    if (_isTemplateBracket(bracket)) return getResults(bracket);

    final current = getResults(bracket);
    final updatedGames = Map<String, GameResult>.from(current.games);
    final game = updatedGames[gameId];
    if (game == null) return current;

    updatedGames[gameId] = game.copyWith(
      winner: null,
      isCompleted: false,
      score: null,
    );

    _clearDownstream(
        updatedGames, game.round, game.matchIndex, bracket.totalRounds);

    final updated = current.copyWith(
      games: updatedGames,
      lastUpdated: DateTime.now(),
    );
    _customResultsCache[bracket.id] = updated;
    return updated;
  }

  // ═══════════════════════════════════════════════════════════════
  //  USER PICKS
  // ═══════════════════════════════════════════════════════════════

  /// Submit user picks for a bracket.
  static void submitPicks(UserPicks picks) {
    if (!_picksCache.containsKey(picks.bracketId)) {
      _picksCache[picks.bracketId] = [];
    }
    final list = _picksCache[picks.bracketId]!;
    final idx = list.indexWhere((p) => p.userId == picks.userId);
    if (idx >= 0) {
      list[idx] = picks;
    } else {
      list.add(picks);
    }
  }

  /// Get all picks for a bracket.
  ///
  /// CRITICAL FIX: No longer auto-generates mock picks for brackets.
  /// Mock picks were causing the bug where a new joiner would see
  /// pre-filled picks (from the first mock user) instead of a blank slate.
  ///
  /// Bot picks submitted by DailyContentEngine._botsAutoJoin() are still
  /// present — those are real bot participants, not mock data.
  /// Only returns picks that were explicitly submitted via [submitPicks].
  static List<UserPicks> getAllPicks(CreatedBracket bracket) {
    if (_picksCache.containsKey(bracket.id) &&
        _picksCache[bracket.id]!.isNotEmpty) {
      return _picksCache[bracket.id]!;
    }
    // Return empty list — no mock data.
    // Bot picks will be injected by DailyContentEngine._botsAutoJoin()
    // and BracketBoardService bot join logic.
    return [];
  }

  /// Clear all caches (for testing)
  static void clearCache() {
    _customResultsCache.clear();
    _picksCache.clear();
    OfficialResultsRegistry.instance.reset();
  }

  // ═══════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════

  static int _totalRoundsFromGames(Map<String, GameResult> games) {
    int maxRound = 0;
    for (final game in games.values) {
      if (game.round > maxRound) maxRound = game.round;
    }
    return maxRound + 1;
  }

  /// Generate initial results for a custom bracket (no auto-completion).
  static BracketResults _generateCustomResults(CreatedBracket bracket) {
    final isDone = bracket.status == 'done';
    final games = <String, GameResult>{};
    var currentTeams = List<String>.from(bracket.teams);
    final totalRounds = bracket.totalRounds;

    for (int round = 0; round < totalRounds; round++) {
      final nextTeams = <String>[];
      for (int m = 0; m < currentTeams.length; m += 2) {
        if (m + 1 < currentTeams.length) {
          final matchIdx = m ~/ 2;
          final gameId = 'r${round}_g$matchIdx';
          // For done brackets, pre-complete every game with a mock winner
          final String? winner;
          if (isDone && currentTeams[m] != 'TBD' && currentTeams[m + 1] != 'TBD') {
            // Deterministic pick: top seed (even-index) wins
            winner = currentTeams[m];
          } else {
            winner = null;
          }
          games[gameId] = GameResult(
            gameId: gameId,
            round: round,
            matchIndex: matchIdx,
            team1: currentTeams[m],
            team2: currentTeams[m + 1],
            winner: winner,
            isCompleted: winner != null,
            completedAt: winner != null
                ? bracket.createdAt.add(Duration(hours: round * 6 + matchIdx))
                : null,
          );
          nextTeams.add(winner ?? 'TBD');
        }
      }
      currentTeams = nextTeams;
    }

    return BracketResults(
      bracketId: bracket.id,
      games: games,
      isAutoSynced: false,
      lastUpdated: DateTime.now(),
      source: isDone ? 'mock' : 'host_manual',
    );
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

  static void _clearDownstream(Map<String, GameResult> games, int round,
      int matchIndex, int totalRounds) {
    final nextRound = round + 1;
    if (nextRound >= totalRounds) return;

    final nextMatchIndex = matchIndex ~/ 2;
    final nextGameId = 'r${nextRound}_g$nextMatchIndex';
    final nextGame = games[nextGameId];

    if (nextGame != null) {
      games[nextGameId] = GameResult(
        gameId: nextGameId,
        round: nextRound,
        matchIndex: nextMatchIndex,
        team1: matchIndex % 2 == 0 ? 'TBD' : nextGame.team1,
        team2: matchIndex % 2 == 0 ? nextGame.team2 : 'TBD',
        winner: null,
        isCompleted: false,
      );
      _clearDownstream(games, nextRound, nextMatchIndex, totalRounds);
    }
  }
}

/// Generates mock participants for demo.
class MockDataGenerator {
  static final _participants = [
    ('BracketKing', 'TX'),
    ('SlickRick', 'CA'),
    ('CourtneyWins', 'NY'),
    ('NateDoubleDown', 'IL'),
    ('HoopsDreamer', 'OH'),
    ('MadnessQueen', 'FL'),
    ('PickMaster99', 'PA'),
    ('ChalkBuster', 'GA'),
    ('UnderdogLuv', 'MI'),
    ('FinalFourFan', 'NC'),
    ('BracketNerd', 'WA'),
    ('CinderellaMan', 'AZ'),
    ('ChampPicker', 'NV'),
    ('SwishKing', 'IN'),
    ('EliteEight88', 'OR'),
  ];

  static List<UserPicks> generateMockPicks({
    required String bracketId,
    required List<String> teams,
    required int totalRounds,
  }) {
    final allPicks = <UserPicks>[];
    for (int u = 0; u < _participants.length; u++) {
      final picks = <String, String>{};
      var currentTeams = List<String>.from(teams);

      for (int round = 0; round < totalRounds; round++) {
        final nextTeams = <String>[];
        for (int m = 0; m < currentTeams.length; m += 2) {
          if (m + 1 < currentTeams.length) {
            final pick = ((m + u + round) % 3 == 0)
                ? currentTeams[m + 1]
                : currentTeams[m];
            picks['r${round}_g${m ~/ 2}'] = pick;
            nextTeams.add(pick);
          }
        }
        currentTeams = nextTeams;
      }

      allPicks.add(UserPicks(
        userId: 'user_$u',
        userName: _participants[u].$1,
        userState: _participants[u].$2,
        bracketId: bracketId,
        picks: picks,
        submittedAt: DateTime.now().subtract(Duration(hours: u)),
      ));
    }
    return allPicks;
  }
}
