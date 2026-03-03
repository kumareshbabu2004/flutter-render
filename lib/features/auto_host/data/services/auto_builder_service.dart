import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';
import 'package:bmb_mobile/features/auto_host/data/models/knowledge_pack.dart';
import 'package:bmb_mobile/features/auto_host/data/models/saved_template.dart';
import 'package:bmb_mobile/features/auto_host/data/services/knowledge_pack_service.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/bracket_template.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';

/// Result of the auto-builder interpreting a voice/text command.
class AutoBuildResult {
  final String bracketName;
  final String bracketType;      // 'standard', 'voting', 'pickem'
  final String sport;
  final int teamCount;
  final List<String> teams;
  final bool isFreeEntry;
  final int entryFee;
  final String prizeType;
  final String? prizeDescription;
  final DateTime? suggestedGoLiveDate;
  final int minPlayers;
  final String? knowledgePackId;
  final String? sourceTemplateId;
  final bool autoHost;
  final bool autoShare;
  final bool isPublic;
  final String? charityName;

  const AutoBuildResult({
    required this.bracketName,
    required this.bracketType,
    required this.sport,
    required this.teamCount,
    required this.teams,
    this.isFreeEntry = true,
    this.entryFee = 0,
    this.prizeType = 'none',
    this.prizeDescription,
    this.suggestedGoLiveDate,
    this.minPlayers = 4,
    this.knowledgePackId,
    this.sourceTemplateId,
    this.autoHost = true,
    this.autoShare = true,
    this.isPublic = true,
    this.charityName,
  });
}

/// User intent classification for voice commands.
enum _UserIntent { tournament, voting, ambiguous }

/// The Auto-Builder Service interprets voice commands / text queries and
/// produces a fully configured bracket ready for host approval.
///
/// INTENT-AWARE: Distinguishes between tournament brackets (real competitions)
/// and voting brackets (opinion polls) to prevent misinterpretation.
class AutoBuilderService {
  AutoBuilderService._();
  static final AutoBuilderService instance = AutoBuilderService._();

  final _kpService = KnowledgePackService.instance;
  final _rest = RestFirestoreService.instance;

  // ═══════════════════════════════════════════════════════════════════
  // VOICE COMMAND PARSING — INTENT-AWARE
  // ═══════════════════════════════════════════════════════════════════

  /// Parse a voice command or text request into an auto-build result.
  ///
  /// INTENT DETECTION (priority order):
  /// 1. **Tournament Intent** — user wants a real tournament bracket
  ///    Signals: "playoff", "playoffs", "tournament", "matchup", "bracket"
  ///    (combined with a sport name)
  ///    → Uses BracketTemplate (NFL Playoffs, March Madness, etc.)
  ///
  /// 2. **Opinion/Voting Intent** — user wants a debate/poll bracket
  ///    Signals: "best", "favorite", "greatest", "goat", "worst", "top",
  ///    "ranking", "vote", "who is"
  ///    → Uses KnowledgePack (Best QB, Best Rapper, etc.)
  ///
  /// 3. **Ambiguous** — could be either
  ///    "build me an NFL bracket" → Defaults to TOURNAMENT (template)
  ///    because users asking for a "bracket" most commonly mean the
  ///    actual competition, not a voting poll.
  AutoBuildResult? parseCommand(String command) {
    final q = command.toLowerCase().trim();
    if (q.isEmpty) return null;

    // ── Step 1: Determine user intent ──
    final intent = _detectIntent(q);

    if (intent == _UserIntent.tournament) {
      // TOURNAMENT FIRST: Try template match, then knowledge packs with standard type
      final template = _matchBracketTemplate(q);
      if (template != null) return _buildFromTemplate(template, q);

      // No exact template → try knowledge packs but force to 'standard' type
      final pack = _kpService.bestMatch(q);
      if (pack != null && pack.bracketType == 'standard') {
        return _buildFromPack(pack, q);
      }

      // Fall through to generic tournament builder
      return _buildGenericTournament(q);
    }

    if (intent == _UserIntent.voting) {
      // VOTING FIRST: Try knowledge pack match
      final pack = _kpService.bestMatch(q);
      if (pack != null) return _buildFromPack(pack, q);

      // No pack → build generic voting bracket
      return _buildGeneric(q);
    }

    // ── AMBIGUOUS intent — default priority: template > pack > generic ──
    // If the query mentions a sport and "bracket", assume tournament
    final template = _matchBracketTemplate(q);
    if (template != null) return _buildFromTemplate(template, q);

    final pack = _kpService.bestMatch(q);
    if (pack != null) return _buildFromPack(pack, q);

    return _buildGeneric(q);
  }

  /// Detect whether the user wants a real tournament or a voting/opinion bracket.
  _UserIntent _detectIntent(String query) {
    // ── TOURNAMENT SIGNALS ──
    // These words indicate the user wants a real sports competition bracket
    final tournamentSignals = [
      'playoff', 'playoffs', 'play-off', 'play off',
      'tournament', 'tourney',
      'matchup', 'match-up', 'match up', 'matchups',
      'championship', 'champion',
      'season', 'postseason', 'post-season',
      'super bowl', 'superbowl',
      'world series', 'world cup',
      'march madness', 'final four', 'sweet sixteen', 'sweet 16',
      'elite eight', 'elite 8',
      'wild card', 'wildcard', 'divisional',
      'conference championship',
      'stanley cup',
      'masters',
      'round of', 'round 1', 'round 2',
      'seeding', 'seed', 'seeds',
      'afc', 'nfc', 'east', 'west',
    ];

    // ── VOTING / OPINION SIGNALS ──
    // These words indicate the user wants a debate/poll bracket
    final votingSignals = [
      'best', 'favorite', 'favourite', 'greatest', 'goat',
      'worst', 'top', 'ranking', 'rank',
      'vote', 'poll', 'debate',
      'who is', 'who\'s', 'which is',
      'vs', 'versus',
      'most popular', 'popularity',
      'all time', 'all-time', 'of all time',
      'funniest', 'hottest', 'coolest',
    ];

    int tournamentScore = 0;
    int votingScore = 0;

    for (final signal in tournamentSignals) {
      if (query.contains(signal)) tournamentScore += 10;
    }

    for (final signal in votingSignals) {
      if (query.contains(signal)) votingScore += 10;
    }

    // ── CONTEXTUAL BOOSTERS ──
    // "Build me an NFL bracket" → tournament (the sport + bracket = competition)
    final hasSportContext = _hasSportKeyword(query);
    final hasBracketWord = query.contains('bracket') || query.contains('brackets');

    // If sport + "bracket" with no voting signals → tournament
    if (hasSportContext && hasBracketWord && votingScore == 0) {
      tournamentScore += 15;
    }

    // "Build me a bracket" with sport name → tournament
    if (hasSportContext && tournamentScore > 0 && votingScore == 0) {
      tournamentScore += 5;
    }

    // Explicit voting type keywords
    if (query.contains('voting bracket') || query.contains('vote bracket') ||
        query.contains('opinion') || query.contains('poll bracket')) {
      votingScore += 20;
    }

    if (tournamentScore > votingScore) return _UserIntent.tournament;
    if (votingScore > tournamentScore) return _UserIntent.voting;
    return _UserIntent.ambiguous;
  }

  /// Check if the query mentions a recognized sport.
  bool _hasSportKeyword(String query) {
    const sportKeywords = [
      'nfl', 'nba', 'mlb', 'nhl', 'ncaa', 'mls',
      'football', 'basketball', 'baseball', 'hockey', 'soccer',
      'tennis', 'golf', 'mma', 'ufc', 'boxing',
      'pga', 'atp', 'wta', 'wnba',
      'college football', 'college basketball',
      'premier league', 'la liga', 'champions league',
    ];
    return sportKeywords.any((kw) => query.contains(kw));
  }

  /// Build from a knowledge pack.
  AutoBuildResult _buildFromPack(KnowledgePack pack, String query) {
    final teams = pack.items.isNotEmpty
        ? pack.itemsForSize(pack.defaultSize)
        : <String>[];

    // Determine if this is a voting bracket (always free entry)
    final isVoting = pack.bracketType == 'voting';
    final fee = isVoting ? 0 : _calculateEntryFee(pack.category);

    return AutoBuildResult(
      bracketName: _generateBracketName(pack.name),
      bracketType: pack.bracketType,
      sport: pack.category == 'sports'
          ? _extractSport(pack.name)
          : pack.category.substring(0, 1).toUpperCase() + pack.category.substring(1),
      teamCount: pack.defaultSize,
      teams: teams,
      isFreeEntry: isVoting || fee == 0,
      entryFee: fee,
      prizeType: isVoting ? 'none' : 'none',
      prizeDescription: isVoting ? DefaultPrizes.defaultVotingPrize : null,
      suggestedGoLiveDate: _suggestGoLiveDate(pack),
      minPlayers: _suggestMinPlayers(pack.defaultSize),
      knowledgePackId: pack.id,
      autoHost: true,
      autoShare: true,
      isPublic: true,
    );
  }

  /// Build from a pre-built BracketTemplate (March Madness, NFL Playoffs, etc.).
  ///
  /// SMART DEFAULTS:
  /// - Uses template's default teams (which may be seeded placeholders like
  ///   "(1) AFC #1" for NFL Playoffs). These are correct — the host can update
  ///   team names later when matchups are announced.
  /// - Sets go-live date to the actual event start window (e.g., NFL playoffs
  ///   in January, March Madness in March).
  /// - Uses the most popular entry fee (10 credits) for paid brackets.
  AutoBuildResult _buildFromTemplate(BracketTemplate template, String query) {
    return AutoBuildResult(
      bracketName: _generateBracketName(template.name),
      bracketType: 'standard',
      sport: template.sport,
      teamCount: template.teamCount,
      teams: template.defaultTeams,
      isFreeEntry: false,
      entryFee: _mostCommonEntryFee,
      prizeType: 'none',
      suggestedGoLiveDate: _suggestGoLiveDateForTemplate(template),
      minPlayers: _suggestMinPlayers(template.teamCount),
      sourceTemplateId: template.id,
      autoHost: true,
      autoShare: true,
      isPublic: true,
    );
  }

  /// Build a generic bracket when no specific match is found.
  /// Defaults to voting for non-sport queries, standard for sport queries.
  AutoBuildResult? _buildGeneric(String query) {
    // Extract bracket type hints
    String bracketType = 'voting'; // default to voting for generic queries
    if (query.contains('pick') && query.contains('em') || query.contains("pick'em") || query.contains('pickem')) {
      bracketType = 'pickem';
    } else if (_hasSportKeyword(query) && (query.contains('bracket') || query.contains('tournament'))) {
      bracketType = 'standard'; // Sport + bracket = tournament, not voting
    }

    // Extract size hint
    int teamCount = 16; // default
    final sizeMatch = RegExp(r'(\d+)\s*(team|player|item|contestant)').firstMatch(query);
    if (sizeMatch != null) {
      teamCount = int.tryParse(sizeMatch.group(1)!) ?? 16;
      // Snap to nearest valid bracket size
      teamCount = _snapToValidSize(teamCount);
    }

    final isVoting = bracketType == 'voting';

    return AutoBuildResult(
      bracketName: _generateBracketName(_titleFromQuery(query)),
      bracketType: bracketType,
      sport: _extractSport(query),
      teamCount: teamCount,
      teams: List.generate(teamCount, (i) => 'TBD ${i + 1}'),
      isFreeEntry: isVoting,
      entryFee: isVoting ? 0 : _mostCommonEntryFee,
      prizeType: 'none',
      prizeDescription: isVoting ? DefaultPrizes.defaultVotingPrize : null,
      suggestedGoLiveDate: DateTime.now().add(const Duration(days: 1)),
      minPlayers: _suggestMinPlayers(teamCount),
      autoHost: true,
      autoShare: true,
      isPublic: true,
    );
  }

  /// Build a generic TOURNAMENT bracket when intent is clearly "tournament"
  /// but no template/pack matches.
  /// E.g. "build me a hockey tournament" → standard bracket, TBD teams
  AutoBuildResult _buildGenericTournament(String query) {
    int teamCount = 16;
    final sizeMatch = RegExp(r'(\d+)\s*(team|player|item|contestant)').firstMatch(query);
    if (sizeMatch != null) {
      teamCount = int.tryParse(sizeMatch.group(1)!) ?? 16;
      teamCount = _snapToValidSize(teamCount);
    }

    final sport = _extractSport(query);

    return AutoBuildResult(
      bracketName: _generateBracketName(_titleFromQuery(query)),
      bracketType: 'standard',
      sport: sport,
      teamCount: teamCount,
      teams: List.generate(teamCount, (i) => 'TBD ${i + 1}'),
      isFreeEntry: false,
      entryFee: _mostCommonEntryFee,
      prizeType: 'none',
      suggestedGoLiveDate: _suggestGoLiveDateForSport(sport),
      minPlayers: _suggestMinPlayers(teamCount),
      autoHost: true,
      autoShare: true,
      isPublic: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ENTRY FEE ALGORITHM
  // ═══════════════════════════════════════════════════════════════════

  /// Smart entry fee calculation based on recent similar brackets.
  /// Returns 0 for voting brackets.
  int _calculateEntryFee(String category) {
    // Default fees by category (will be replaced by Firestore lookups)
    const defaults = {
      'sports': 10,
      'music': 5,
      'food': 5,
      'entertainment': 5,
      'culture': 5,
      'custom': 10,
    };
    return defaults[category] ?? 10;
  }

  /// Calculate entry fee from recent bracket history (Firestore-backed).
  Future<int> calculateSmartEntryFee({
    required String sport,
    required String bracketType,
  }) async {
    try {
      // Query last 30 brackets for this sport
      final results = await _rest.query('brackets', whereField: 'sport', whereValue: sport);

      if (results.isEmpty) return 10; // default

      // Filter to paid brackets and get entry fees
      final fees = <int>[];
      for (final data in results) {
        final fee = (data['entry_fee'] as num?)?.toInt() ?? 0;
        final entrants = (data['entrants_count'] as num?)?.toInt() ?? 0;
        // Only include brackets with decent participation
        if (fee > 0 && entrants >= 3) fees.add(fee);
      }

      if (fees.isEmpty) return 10;

      // Average, round to nearest 5, clamp 5-100
      final avg = fees.reduce((a, b) => a + b) / fees.length;
      final rounded = ((avg / 5).round() * 5).clamp(5, 100);
      return rounded;
    } catch (e) {
      if (kDebugMode) debugPrint('AutoBuilder: fee calc error: $e');
      return 10;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // SAVED TEMPLATES (FIRESTORE)
  // ═══════════════════════════════════════════════════════════════════

  /// Save a template to Firestore.
  Future<String> saveTemplate(SavedTemplate template) async {
    try {
      final id = await _rest.addDocument('saved_templates', template.toFirestoreMap());
      return id ?? '';
    } catch (e) {
      if (kDebugMode) debugPrint('AutoBuilder: saveTemplate error: $e');
      rethrow;
    }
  }

  /// Update a saved template.
  Future<void> updateTemplate(String templateId, Map<String, dynamic> fields) async {
    try {
      await _rest.updateDocument('saved_templates', templateId, fields);
    } catch (e) {
      if (kDebugMode) debugPrint('AutoBuilder: updateTemplate error: $e');
      rethrow;
    }
  }

  /// Get all saved templates for a host.
  Future<List<SavedTemplate>> getHostTemplates(String hostId) async {
    try {
      final results = await _rest.query('saved_templates', whereField: 'host_id', whereValue: hostId);
      final templates = results
          .map((data) => SavedTemplate.fromFirestore(data, data['doc_id'] ?? ''))
          .toList();
      // Sort: favorites first, then by last used
      templates.sort((a, b) {
        if (a.isFavorite && !b.isFavorite) return -1;
        if (!a.isFavorite && b.isFavorite) return 1;
        final aTime = a.lastUsedAt ?? a.createdAt;
        final bTime = b.lastUsedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return templates;
    } catch (e) {
      if (kDebugMode) debugPrint('AutoBuilder: getHostTemplates error: $e');
      return [];
    }
  }

  /// Delete a saved template.
  Future<void> deleteTemplate(String templateId) async {
    try {
      // REST delete not yet implemented — mark as deleted
      await _rest.updateDocument('saved_templates', templateId, {'is_deleted': true});
    } catch (e) {
      if (kDebugMode) debugPrint('AutoBuilder: deleteTemplate error: $e');
      rethrow;
    }
  }

  /// "Use Again" — clone a template into a new bracket and save to Firestore.
  Future<String> useTemplate({
    required SavedTemplate template,
    required String hostId,
    required String hostName,
    DateTime? overrideGoLiveDate,
  }) async {
    try {
      // Build bracket data from template
      final bracketData = {
        'name': _generateBracketName(template.name),
        'sport': template.sport,
        'bracket_type': template.bracketType,
        'team_count': template.teamCount,
        'teams': template.defaultTeams.isNotEmpty
            ? template.defaultTeams
            : List.generate(template.teamCount, (i) => 'TBD ${i + 1}'),
        'entry_fee': template.isFreeEntry ? 0 : template.entryFee,
        'entry_type': template.isFreeEntry ? 'free' : 'paid',
        'prize_type': template.prizeType,
        'prize_description': template.prizeDescription ?? template.defaultPrize ?? '',
        'status': template.requiresApproval ? 'saved' : 'upcoming',
        'host_user_id': hostId,
        'host_display_name': hostName,
        'entrants_count': 0,
        'max_entrants': template.maxPlayers,
        'is_featured': false,
        'is_public': template.isPublic,
        'add_to_bracket_board': template.isPublic,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'auto_host': template.autoHost,
        'min_players': template.minPlayers,
        'auto_share': template.autoShare,
        'from_template_id': template.id,
        'requires_approval': template.requiresApproval,
        if (overrideGoLiveDate != null)
          'go_live_date': overrideGoLiveDate.toUtc().toIso8601String(),
        if (template.charityName != null) 'charity_name': template.charityName,
        if (template.charityGoal != null) 'charity_goal': template.charityGoal,
      };

      // Create bracket in Firestore
      final bracketId = await FirestoreService.instance.createBracket(bracketData);

      // Update template usage stats
      await updateTemplate(template.id, {
        'last_used_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Log analytics
      await FirestoreService.instance.logEvent({
        'event_type': 'auto_build_bracket',
        'host_id': hostId,
        'template_id': template.id,
        'bracket_id': bracketId,
        'bracket_type': template.bracketType,
      });

      return bracketId;
    } catch (e) {
      if (kDebugMode) debugPrint('AutoBuilder: useTemplate error: $e');
      rethrow;
    }
  }

  /// Create a bracket directly from an AutoBuildResult (after host approval).
  Future<String> createFromResult({
    required AutoBuildResult result,
    required String hostId,
    required String hostName,
  }) async {
    try {
      final bracketData = {
        'name': result.bracketName,
        'sport': result.sport,
        'bracket_type': result.bracketType,
        'team_count': result.teamCount,
        'teams': result.teams,
        'entry_fee': result.isFreeEntry ? 0 : result.entryFee,
        'entry_type': result.isFreeEntry ? 'free' : 'paid',
        'prize_type': result.prizeType,
        'prize_description': result.prizeDescription ?? '',
        'status': 'saved', // Always start as saved, host approves to move to upcoming
        'host_user_id': hostId,
        'host_display_name': hostName,
        'entrants_count': 0,
        'max_entrants': 0,
        'is_featured': false,
        'is_public': result.isPublic,
        'add_to_bracket_board': result.isPublic,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'auto_host': result.autoHost,
        'min_players': result.minPlayers,
        'auto_share': result.autoShare,
        if (result.suggestedGoLiveDate != null)
          'go_live_date': result.suggestedGoLiveDate!.toUtc().toIso8601String(),
        if (result.knowledgePackId != null)
          'knowledge_pack_id': result.knowledgePackId,
        if (result.sourceTemplateId != null)
          'source_template_id': result.sourceTemplateId,
      };

      final bracketId = await FirestoreService.instance.createBracket(bracketData);

      await FirestoreService.instance.logEvent({
        'event_type': 'auto_build_bracket',
        'host_id': hostId,
        'bracket_type': result.bracketType,
        'bracket_id': bracketId,
        'source': result.knowledgePackId ?? result.sourceTemplateId ?? 'generic',
      });

      return bracketId;
    } catch (e) {
      if (kDebugMode) debugPrint('AutoBuilder: createFromResult error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Match a query to a pre-built BracketTemplate.
  ///
  /// EXPANDED MATCHING: Handles many natural language variations:
  /// - "build me an NFL playoff bracket"
  /// - "nfl playoffs"
  /// - "NFL bracket" (sport + bracket → tournament)
  /// - "football playoff bracket"
  /// - "college football bracket"
  /// - "march madness"
  /// - "NBA playoff bracket"
  BracketTemplate? _matchBracketTemplate(String query) {
    // ── EXACT / SPECIFIC PHRASE MATCHES (highest priority) ──
    final exactMapping = <String, BracketTemplate>{
      'march madness': BracketTemplate.marchmadness,
      'big dance': BracketTemplate.marchmadness,
      'ncaa tournament': BracketTemplate.marchmadness,
      'ncaa bracket': BracketTemplate.marchmadness,
      'college basketball bracket': BracketTemplate.marchmadness,
      'college basketball tournament': BracketTemplate.marchmadness,
      'final four': BracketTemplate.marchmadness,
      'sweet sixteen': BracketTemplate.marchmadness,
      'sweet 16': BracketTemplate.marchmadness,
      'elite eight': BracketTemplate.marchmadness,
      'elite 8': BracketTemplate.marchmadness,
      'ncaa women': BracketTemplate.ncaaWomensBB,
      'women\'s basketball': BracketTemplate.ncaaWomensBB,
      'wnba bracket': BracketTemplate.ncaaWomensBB,
      'nit': BracketTemplate.nitTournament,
      'nit tournament': BracketTemplate.nitTournament,
      'nfl playoff': BracketTemplate.nflPlayoffs,
      'nfl playoffs': BracketTemplate.nflPlayoffs,
      'super bowl bracket': BracketTemplate.nflPlayoffs,
      'college football playoff': BracketTemplate.cfbPlayoff,
      'cfb playoff': BracketTemplate.cfbPlayoff,
      'cfp bracket': BracketTemplate.cfbPlayoff,
      'college football bracket': BracketTemplate.cfbPlayoff,
      'nba playoff': BracketTemplate.nbaPlayoffs,
      'nba playoffs': BracketTemplate.nbaPlayoffs,
      'nba bracket': BracketTemplate.nbaPlayoffs,
      'nba cup': BracketTemplate.nbaInSeason,
      'nba in-season': BracketTemplate.nbaInSeason,
      'in season tournament': BracketTemplate.nbaInSeason,
      'world cup': BracketTemplate.fifaWorldCup,
      'fifa': BracketTemplate.fifaWorldCup,
      'fifa bracket': BracketTemplate.fifaWorldCup,
      'wimbledon': BracketTemplate.wimbledon,
      'grand slam': BracketTemplate.wimbledon,
      'tennis bracket': BracketTemplate.wimbledon,
      'tennis tournament': BracketTemplate.wimbledon,
      'mlb playoff': BracketTemplate.mlbPlayoffs,
      'mlb playoffs': BracketTemplate.mlbPlayoffs,
      'mlb bracket': BracketTemplate.mlbPlayoffs,
      'baseball playoff': BracketTemplate.mlbPlayoffs,
      'baseball bracket': BracketTemplate.mlbPlayoffs,
      'world series bracket': BracketTemplate.mlbPlayoffs,
      'stanley cup': BracketTemplate.stanleyCup,
      'nhl playoff': BracketTemplate.stanleyCup,
      'nhl playoffs': BracketTemplate.stanleyCup,
      'nhl bracket': BracketTemplate.stanleyCup,
      'hockey playoff': BracketTemplate.stanleyCup,
      'hockey bracket': BracketTemplate.stanleyCup,
      'ufc bracket': BracketTemplate.mmaChampionship,
      'mma bracket': BracketTemplate.mmaChampionship,
      'ufc tournament': BracketTemplate.mmaChampionship,
      'golf bracket': BracketTemplate.mastersGolf,
      'pga bracket': BracketTemplate.mastersGolf,
      'pga tournament': BracketTemplate.mastersGolf,
      'masters bracket': BracketTemplate.mastersGolf,
      'masters tournament': BracketTemplate.mastersGolf,
    };

    // Check exact phrase matches
    for (final entry in exactMapping.entries) {
      if (query.contains(entry.key)) return entry.value;
    }

    // ── SPORT + GENERIC "bracket/tournament/playoff" ──
    // "football bracket" → NFL Playoffs (not a voting bracket about football)
    // "basketball bracket" → NBA Playoffs
    if (query.contains('bracket') || query.contains('tournament') || query.contains('playoff')) {
      if (query.contains('football') && !query.contains('college')) return BracketTemplate.nflPlayoffs;
      if (query.contains('basketball') && !query.contains('college') && !query.contains('women')) return BracketTemplate.nbaPlayoffs;
      if (query.contains('baseball')) return BracketTemplate.mlbPlayoffs;
      if (query.contains('hockey')) return BracketTemplate.stanleyCup;
      if (query.contains('soccer')) return BracketTemplate.fifaWorldCup;
      if (query.contains('tennis')) return BracketTemplate.wimbledon;
      if (query.contains('golf') || query.contains('pga')) return BracketTemplate.mastersGolf;
      if (query.contains('mma') || query.contains('ufc')) return BracketTemplate.mmaChampionship;
      if (query.contains('college football') || query.contains('cfb')) return BracketTemplate.cfbPlayoff;
      if (query.contains('college basketball') || query.contains('ncaa')) return BracketTemplate.marchmadness;
    }

    // ── LEAGUE NAME ALONE when intent is tournament ──
    // "build me an NFL bracket" → NFL Playoffs
    if (_hasSportKeyword(query) && (query.contains('bracket') || query.contains('tournament'))) {
      if (query.contains('nfl')) return BracketTemplate.nflPlayoffs;
      if (query.contains('nba')) return BracketTemplate.nbaPlayoffs;
      if (query.contains('mlb')) return BracketTemplate.mlbPlayoffs;
      if (query.contains('nhl')) return BracketTemplate.stanleyCup;
      if (query.contains('ncaa') || query.contains('march')) return BracketTemplate.marchmadness;
      if (query.contains('pga')) return BracketTemplate.mastersGolf;
    }

    return null;
  }

  /// Generate a bracket name with current year or context.
  String _generateBracketName(String baseName) {
    final year = DateTime.now().year;
    if (baseName.contains(year.toString())) return baseName;
    return '$baseName $year';
  }

  /// Suggest a go-live date based on the knowledge pack's event hints.
  DateTime? _suggestGoLiveDate(KnowledgePack pack) {
    if (pack.eventDateHint == null) {
      return DateTime.now().add(const Duration(days: 1));
    }
    // Default: tomorrow at 6 PM
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18, 0);
  }

  /// Suggest go-live for pre-built templates based on actual event timing.
  ///
  /// SMART SCHEDULING: Maps each template to its real-world event window.
  /// If the event hasn't started yet this year, schedule for this year.
  /// If it's already passed, schedule for next year.
  DateTime? _suggestGoLiveDateForTemplate(BracketTemplate template) {
    final now = DateTime.now();
    final year = now.year;
    final nextYear = year + 1;

    // Map template IDs to their typical event start dates
    // Format: (month, day) of when the event typically begins
    DateTime eventStart;
    switch (template.id) {
      case 'nfl_playoffs':
        // NFL Wild Card weekend is typically mid-January
        eventStart = DateTime(year, 1, 11, 13, 0);
        break;
      case 'cfb_playoff':
        // College Football Playoff first round is typically late December
        eventStart = DateTime(year, 12, 20, 16, 0);
        break;
      case 'march_madness':
      case 'march_madness_64':
        // First Four starts mid-March
        eventStart = DateTime(year, 3, 18, 18, 0);
        break;
      case 'ncaa_womens_bb':
        eventStart = DateTime(year, 3, 20, 18, 0);
        break;
      case 'nit':
        eventStart = DateTime(year, 3, 18, 18, 0);
        break;
      case 'nba_playoffs':
        // NBA Playoffs typically start late April
        eventStart = DateTime(year, 4, 19, 13, 0);
        break;
      case 'nba_in_season':
        // NBA Cup knockout stage is typically mid-December
        eventStart = DateTime(year, 12, 10, 19, 0);
        break;
      case 'mlb_playoffs':
        // MLB Playoffs start early October
        eventStart = DateTime(year, 10, 1, 16, 0);
        break;
      case 'stanley_cup':
        // NHL Playoffs start mid-April
        eventStart = DateTime(year, 4, 15, 19, 0);
        break;
      case 'fifa_world_cup':
        // World Cup timing varies; default to summer
        eventStart = DateTime(year, 6, 14, 12, 0);
        break;
      case 'wimbledon':
        // Wimbledon starts early July
        eventStart = DateTime(year, 7, 1, 11, 0);
        break;
      case 'masters_golf':
        // The Masters is always the second week of April
        eventStart = DateTime(year, 4, 10, 10, 0);
        break;
      default:
        // Default: 2 days from now at 6 PM
        final dt = now.add(const Duration(days: 2));
        return DateTime(dt.year, dt.month, dt.day, 18, 0);
    }

    // If event hasn't happened yet this year, use this year
    if (eventStart.isAfter(now)) {
      return eventStart;
    }

    // Event already passed this year → schedule for next year
    return DateTime(nextYear, eventStart.month, eventStart.day,
        eventStart.hour, eventStart.minute);
  }

  /// Suggest go-live date for a sport when no specific template matched.
  DateTime _suggestGoLiveDateForSport(String sport) {
    final now = DateTime.now();
    final dt = now.add(const Duration(days: 2));
    return DateTime(dt.year, dt.month, dt.day, 18, 0);
  }

  /// Most commonly used entry fee across the platform (10 credits).
  static const int _mostCommonEntryFee = 10;

  /// Suggest minimum players based on bracket size.
  int _suggestMinPlayers(int teamCount) {
    if (teamCount <= 2) return 2;
    if (teamCount <= 8) return 4;
    if (teamCount <= 16) return 6;
    if (teamCount <= 32) return 8;
    return 10;
  }

  /// Snap a number to the nearest valid bracket size.
  int _snapToValidSize(int n) {
    const sizes = [2, 4, 8, 16, 32, 64, 128];
    int closest = 16;
    int minDiff = 999;
    for (final s in sizes) {
      final diff = (s - n).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = s;
      }
    }
    return closest;
  }

  /// Extract a sport name from a pack/template name or query.
  String _extractSport(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('nfl') || lower.contains('quarterback') ||
        (lower.contains('football') && !lower.contains('college football'))) {
      return 'Football';
    }
    if (lower.contains('college football') || lower.contains('cfb') || lower.contains('cfp')) {
      return 'Football';
    }
    if (lower.contains('nba') || lower.contains('basketball') || lower.contains('wnba')) {
      return 'Basketball';
    }
    if (lower.contains('ncaa') || lower.contains('march madness') || lower.contains('college basketball')) {
      return 'Basketball';
    }
    if (lower.contains('mlb') || lower.contains('baseball') || lower.contains('world series')) {
      return 'Baseball';
    }
    if (lower.contains('nhl') || lower.contains('hockey') || lower.contains('stanley cup')) {
      return 'Hockey';
    }
    if (lower.contains('soccer') || lower.contains('fifa') || lower.contains('mls') ||
        lower.contains('premier league') || lower.contains('world cup')) {
      return 'Soccer';
    }
    if (lower.contains('tennis') || lower.contains('wimbledon') || lower.contains('atp') || lower.contains('wta')) {
      return 'Tennis';
    }
    if (lower.contains('golf') || lower.contains('pga') || lower.contains('masters')) {
      return 'Golf';
    }
    if (lower.contains('mma') || lower.contains('ufc') || lower.contains('boxing')) return 'MMA';
    return 'Sports';
  }

  /// Create a readable title from a generic query.
  String _titleFromQuery(String query) {
    // Remove common filler words
    var title = query
        .replaceAll(RegExp(r'\b(host|me|a|an|the|please|create|build|make|run|do|give|set|up|for)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) title = 'Custom Bracket';

    // Capitalize each word, with special handling for known acronyms
    const acronyms = {'nfl', 'nba', 'mlb', 'nhl', 'ncaa', 'ufc', 'mma', 'pga', 'mls', 'cfb', 'cfp', 'atp', 'wta', 'wnba'};
    return title.split(' ').map((w) {
      if (w.isEmpty) return '';
      if (acronyms.contains(w.toLowerCase())) return w.toUpperCase();
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).where((w) => w.isNotEmpty).join(' ');
  }
}
