// ignore_for_file: unused_field
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/dashboard/data/models/bracket_item.dart';
import 'package:bmb_mobile/features/dashboard/data/models/bracket_host.dart';
import 'package:bmb_mobile/core/services/daily_content_engine.dart';
import 'package:bmb_mobile/features/bots/data/services/bot_service.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';

/// BracketBoardService manages the Bracket Board lifecycle:
///
///  1. **Visibility Duration**: Configurable TTL per status — brackets auto-
///     archive when they've been on the board longer than their allowed time.
///  2. **Auto-Lifecycle**: Brackets progress through statuses automatically:
///     upcoming → live → in_progress → done (archived).
///  3. **Continuous Rotation**: New brackets are generated periodically (every
///     few minutes on a background timer) so the board always feels fresh.
///  4. **Reset Support**: `resetBoard()` clears everything and generates a fresh
///     batch of brackets from the template pool.
///
/// Persistence: last_board_refresh timestamp via SharedPreferences.
class BracketBoardService {
  BracketBoardService._();
  static final BracketBoardService instance = BracketBoardService._();

  // ─── CONFIGURATION ──────────────────────────────────────────────────
  /// How long each bracket status stays visible on the board before it either
  /// progresses to the next status or gets archived.
  ///
  /// These are *board-visible* durations — real tournaments would be longer,
  /// but for the demo board we cycle faster so users always see movement.
  static const Map<String, Duration> visibilityDurations = {
    'upcoming':    Duration(hours: 12),   // upcoming visible up to 12 h
    'live':        Duration(hours: 24),   // live visible up to 24 h
    'in_progress': Duration(hours: 48),   // in-progress up to 48 h
    'done':        Duration(hours: 6),    // done shown briefly then archived
  };

  /// How often the background timer checks for lifecycle updates (minutes).
  static const int _lifecycleCheckMinutes = 3;

  /// How many brackets to keep on the board at any given time (target range).
  static const int _minBoardSize = 12;
  static const int _maxBoardSize = 20;

  /// How many new brackets to add per refresh cycle.
  static const int _newPerCycle = 2;

  // ─── IN-MEMORY STATE ──────────────────────────────────────────────────
  final List<_BoardBracket> _boardItems = [];
  final Map<String, List<BracketItem>> _archivedByHost = {};

  bool _initialized = false;
  Timer? _lifecycleTimer;
  int _nextId = 1000;
  int _lastBatchSize = 0;
  DateTime? _lastRefresh;

  // ─── HOSTS POOL ──────────────────────────────────────────────────────
  static const _hostPool = [
    BracketHost(id: 'host_nate', name: 'NateDoubleDown', rating: 4.8,
        reviewCount: 151, isVerified: true, isTopHost: true, location: 'IL', totalHosted: 201),
    BracketHost(id: 'host_slick', name: 'SlickRick', rating: 4.6,
        reviewCount: 42, isVerified: true, isTopHost: true, location: 'CA', totalHosted: 78),
    BracketHost(id: 'host_courtney', name: 'CourtneyWins', rating: 4.7,
        reviewCount: 39, isVerified: true, isTopHost: true, location: 'NY', totalHosted: 51),
    BracketHost(id: 'host_bmb', name: 'Back My Bracket', rating: 5.0,
        reviewCount: 320, isVerified: true, isTopHost: false, location: 'US', totalHosted: 500),
    BracketHost(id: 'bot_marcus', name: 'Marc_Buckets',
        profileImageUrl: 'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?auto=compress&cs=tinysrgb&w=256&h=256&fit=crop',
        rating: 4.9, reviewCount: 67, isVerified: true, isTopHost: true, location: 'TX', totalHosted: 42),
    BracketHost(id: 'bot_jess', name: 'Queen_of_Upsets',
        profileImageUrl: 'https://images.pexels.com/photos/733872/pexels-photo-733872.jpeg?auto=compress&cs=tinysrgb&w=256&h=256&fit=crop',
        rating: 4.7, reviewCount: 53, isVerified: true, isTopHost: true, location: 'FL', totalHosted: 35),
    BracketHost(id: 'host_king', name: 'BracketKingBK', rating: 4.5,
        reviewCount: 88, isVerified: true, isTopHost: true, location: 'GA', totalHosted: 64),
    BracketHost(id: 'host_ace', name: 'AcePicks', rating: 4.4,
        reviewCount: 31, isVerified: true, isTopHost: false, location: 'OH', totalHosted: 22),
  ];

  // ─── BRACKET TEMPLATE POOL ──────────────────────────────────────────
  static const List<_BracketTemplate> _templatePool = [
    // ═══════════════════════  BRACKETS  ═══════════════════════════════
    _BracketTemplate('College Football Playoff Bracket', 'Football', RewardType.custom, 'Signed Mini Helmet + 200 BMB Credits', true, 0, 200, null, null, true, GameType.bracket),
    _BracketTemplate('Women\'s March Madness 64', 'Basketball', RewardType.credits, '', false, 5, 500, 25, 500, false, GameType.bracket),
    _BracketTemplate('Premier League Top 16 Bracket', 'Soccer', RewardType.credits, '', true, 0, 250, 50, 250, false, GameType.bracket),
    _BracketTemplate('Stanley Cup Playoff Bracket', 'Hockey', RewardType.charity, 'Hockey Fights Cancer Foundation', false, 5, 150, null, null, false, GameType.bracket),
    _BracketTemplate('NBA Summer League Bracket', 'Basketball', RewardType.credits, '', true, 0, 100, 10, 100, false, GameType.bracket),
    _BracketTemplate('World Series Bracket Challenge', 'Baseball', RewardType.custom, 'Rawlings Official Ball + BMB Snapback', false, 5, 200, null, null, false, GameType.bracket),
    _BracketTemplate('March Madness First Four', 'Basketball', RewardType.credits, '', false, 10, 750, 100, 750, true, GameType.bracket),
    _BracketTemplate('Copa America Bracket', 'Soccer', RewardType.charity, 'Soccer Without Borders', true, 0, 100, null, null, false, GameType.bracket),
    _BracketTemplate('ATP Tennis Grand Slam Bracket', 'Tennis', RewardType.custom, 'Wilson Pro Staff Racket + 150 Credits', false, 5, 300, null, null, false, GameType.bracket),
    _BracketTemplate('MLS Cup Bracket Challenge', 'Soccer', RewardType.credits, '', true, 0, 200, 25, 200, false, GameType.bracket),
    _BracketTemplate('College Basketball Conference Tourney', 'Basketball', RewardType.custom, 'Yeti Rambler 36oz + BMB Hoodie', false, 5, 200, null, null, true, GameType.bracket),
    _BracketTemplate('NBA Dunk Contest Bracket', 'Basketball', RewardType.credits, '', true, 0, 150, 10, 150, false, GameType.bracket),
    _BracketTemplate('UFC Fight Night Bracket', 'MMA', RewardType.custom, 'UFC Venum Gloves + \$25 Fanatics Card', false, 10, 300, null, null, true, GameType.bracket),
    _BracketTemplate('PGA Championship Bracket', 'Golf', RewardType.custom, 'Callaway Rogue ST Driver + 100 Credits', false, 10, 400, null, null, true, GameType.bracket),
    _BracketTemplate('NBA Playoff Showdown', 'Basketball', RewardType.custom, 'Free dinner w/ Chicago Bear Ahmad Merritt + Rare Air Jordan 4 Retros', true, 0, 500, null, null, true, GameType.bracket),
    _BracketTemplate('NFL Playoff Prediction Challenge', 'Football', RewardType.custom, 'Patagonia Black Hole Backpack 32L', false, 10, 250, null, null, true, GameType.bracket),
    _BracketTemplate('NHL Stanley Cup Playoff Picks', 'Hockey', RewardType.charity, 'St. Jude Children\u2019s Research Hospital', false, 5, 200, null, null, false, GameType.bracket),
    _BracketTemplate('NBA Finals Championship Bracket', 'Basketball', RewardType.credits, '', false, 0, 300, 25, 250, false, GameType.bracket),

    // ═══════════════════════  PICK 'EMS  ═══════════════════════════════
    _BracketTemplate('NBA Weekly Pick \u2019Em', 'Basketball', RewardType.credits, '', true, 0, 300, 15, 300, true, GameType.pickem),
    _BracketTemplate('NFL Sunday Pick \u2019Em', 'Football', RewardType.credits, '', false, 5, 500, 25, 500, true, GameType.pickem),
    _BracketTemplate('NBA Playoff Pick \u2019Em', 'Basketball', RewardType.custom, 'Nike Air Max 90s + 200 Credits', false, 10, 400, 50, 400, true, GameType.pickem),
    _BracketTemplate('College Football Saturday Pick \u2019Em', 'Football', RewardType.credits, '', true, 0, 200, 10, 200, false, GameType.pickem),
    _BracketTemplate('MLB Midweek Pick \u2019Em', 'Baseball', RewardType.credits, '', true, 0, 150, 10, 150, false, GameType.pickem),
    _BracketTemplate('NHL Nightly Pick \u2019Em', 'Hockey', RewardType.credits, '', true, 0, 100, 5, 100, false, GameType.pickem),
    _BracketTemplate('Premier League Matchday Pick \u2019Em', 'Soccer', RewardType.credits, '', false, 5, 250, 25, 250, false, GameType.pickem),
    _BracketTemplate('UFC Fight Card Pick \u2019Em', 'MMA', RewardType.custom, 'UFC Fight Kit + 150 Credits', false, 10, 350, null, null, true, GameType.pickem),
    _BracketTemplate('PGA Tour Weekend Pick \u2019Em', 'Golf', RewardType.credits, '', true, 0, 200, 15, 200, false, GameType.pickem),
    _BracketTemplate('NFL Draft Pick \u2019Em', 'Football', RewardType.custom, 'Nike Dunk Lows + DoorDash \$50 Card', true, 0, 500, 50, 500, true, GameType.pickem),
    _BracketTemplate('NBA Finals Pick \u2019Em', 'Basketball', RewardType.custom, 'Jordan 4 Retros + 500 BMB Credits', false, 15, 750, 75, 750, true, GameType.pickem),
    _BracketTemplate('March Madness Daily Pick \u2019Em', 'Basketball', RewardType.credits, '', false, 5, 400, 25, 400, true, GameType.pickem),

    // ═══════════════════════  SQUARES  ════════════════════════════════
    _BracketTemplate('NBA Squares \u2014 Tonight\u2019s Game', 'Basketball', RewardType.credits, '', false, 3, 200, 15, 200, false, GameType.squares),
    _BracketTemplate('Super Bowl Squares', 'Football', RewardType.custom, 'VIP Sports Bar Tab + BMB Hoodie', false, 5, 500, 25, 500, true, GameType.squares),
    _BracketTemplate('NFL Sunday Night Squares', 'Football', RewardType.credits, '', false, 3, 250, 15, 250, false, GameType.squares),
    _BracketTemplate('NBA Finals Squares', 'Basketball', RewardType.custom, 'Signed Jersey + 300 Credits', false, 10, 600, 50, 600, true, GameType.squares),
    _BracketTemplate('NHL Stanley Cup Squares', 'Hockey', RewardType.credits, '', false, 3, 200, 15, 200, false, GameType.squares),
    _BracketTemplate('Monday Night Football Squares', 'Football', RewardType.credits, '', false, 2, 150, 10, 150, false, GameType.squares),
    _BracketTemplate('NBA Rivalry Night Squares', 'Basketball', RewardType.credits, '', true, 0, 100, 5, 100, false, GameType.squares),
    _BracketTemplate('March Madness Squares', 'Basketball', RewardType.custom, 'Fanatics \$100 Gift Card', false, 5, 300, 25, 300, true, GameType.squares),
    _BracketTemplate('World Series Squares', 'Baseball', RewardType.credits, '', false, 3, 200, 15, 200, false, GameType.squares),
    _BracketTemplate('MLS Cup Final Squares', 'Soccer', RewardType.credits, '', false, 2, 150, 10, 150, false, GameType.squares),

    // ═══════════════════════  TRIVIA  ═════════════════════════════════
    _BracketTemplate('NBA Trivia Night', 'Basketball', RewardType.credits, '', true, 0, 100, 5, 100, false, GameType.trivia),
    _BracketTemplate('NFL History Trivia', 'Football', RewardType.credits, '', true, 0, 100, 5, 100, false, GameType.trivia),
    _BracketTemplate('March Madness Trivia Blitz', 'Basketball', RewardType.credits, '', true, 0, 75, 5, 75, false, GameType.trivia),
    _BracketTemplate('Sports Bar Trivia Challenge', 'General', RewardType.custom, 'BMB Snapback + 50 Credits', true, 0, 50, null, null, false, GameType.trivia),
    _BracketTemplate('World Cup Trivia', 'Soccer', RewardType.credits, '', true, 0, 75, 5, 75, false, GameType.trivia),
    _BracketTemplate('Baseball Legends Trivia', 'Baseball', RewardType.credits, '', true, 0, 50, 5, 50, false, GameType.trivia),

    // ═══════════════════════  PROPS  ══════════════════════════════════
    _BracketTemplate('NBA Player Props Tonight', 'Basketball', RewardType.credits, '', false, 3, 200, 15, 200, false, GameType.props),
    _BracketTemplate('NFL Gameday Props', 'Football', RewardType.credits, '', false, 5, 300, 25, 300, true, GameType.props),
    _BracketTemplate('MLB Home Run Props', 'Baseball', RewardType.credits, '', true, 0, 100, 5, 100, false, GameType.props),
    _BracketTemplate('NBA MVP Race Props', 'Basketball', RewardType.custom, 'NBA League Pass + 100 Credits', false, 10, 400, null, null, true, GameType.props),
    _BracketTemplate('Super Bowl Prop Bets', 'Football', RewardType.custom, 'Pizza Party for 10 + 200 Credits', false, 5, 500, 25, 500, true, GameType.props),

    // ═══════════════════════  SURVIVOR  ═══════════════════════════════
    _BracketTemplate('NFL Survivor Pool', 'Football', RewardType.credits, '', false, 10, 1000, 50, 1000, true, GameType.survivor),
    _BracketTemplate('NBA Survivor Challenge', 'Basketball', RewardType.credits, '', false, 5, 500, 25, 500, false, GameType.survivor),
    _BracketTemplate('Premier League Survivor', 'Soccer', RewardType.credits, '', false, 5, 400, 25, 400, false, GameType.survivor),
    _BracketTemplate('College Football Survivor', 'Football', RewardType.credits, '', true, 0, 300, 15, 300, false, GameType.survivor),

    // ═══════════════════════  COMMUNITY VOTES  ════════════════════════
    _BracketTemplate('Best Taco in LA - Community Vote', 'Voting', RewardType.none, 'Bragging rights only!', true, 0, 0, null, null, false, GameType.voting),
    _BracketTemplate('Best Burger in Chicago - Vote', 'Voting', RewardType.none, 'Bragging rights only!', true, 0, 0, null, null, false, GameType.voting),
    _BracketTemplate('Best Wings in NYC - Community Vote', 'Voting', RewardType.none, 'Bragging rights only!', true, 0, 0, null, null, false, GameType.voting),
    _BracketTemplate('Best BBQ Sauce Showdown', 'Voting', RewardType.custom, 'Full BBQ Sauce Gift Set (12 bottles)', true, 0, 0, null, null, false, GameType.voting),
    _BracketTemplate('Best Coffee Shop - Community Vote', 'Voting', RewardType.none, 'Bragging rights only!', true, 0, 0, null, null, false, GameType.voting),
    _BracketTemplate('Best Sports Bar in America', 'Voting', RewardType.custom, 'Bar Tab \$200 + BMB Gear', true, 0, 0, null, null, true, GameType.voting),
    _BracketTemplate('Best Pizza in NYC - Community Vote', 'Voting', RewardType.none, 'Bragging rights only!', true, 0, 0, null, null, false, GameType.voting),
    _BracketTemplate('Best Brunch in Miami - Community Vote', 'Voting', RewardType.none, 'Bragging rights only!', true, 0, 0, null, null, false, GameType.voting),
  ];

  // ─── PUBLIC API ───────────────────────────────────────────────────────

  /// Initialise the service. Call once at app startup.
  /// Now uses DailyContentEngine for REAL sports content instead of fake templates.
  Future<void> init([List<BracketItem>? seedBrackets]) async {
    if (_initialized) return;
    _initialized = true;

    // ═══ REAL CONTENT: Initialize DailyContentEngine first ═══
    await DailyContentEngine.instance.init();

    // Generate a fresh board using real content + some templates for variety
    _generateFreshBoard();

    // Start the background lifecycle timer
    _startLifecycleTimer();

    // Check if we should add daily new brackets
    await _checkDailyRefresh();

    if (kDebugMode) {
      debugPrint('[BracketBoardService] Board initialized with '
          '${boardBrackets.length} items (real content engine active)');
    }
  }

  /// Active board brackets — excludes archived items.
  List<BracketItem> get boardBrackets =>
      _boardItems
          .where((b) => !b.archived)
          .map((b) => b.item)
          .toList();

  /// Archived (completed) brackets for a given host.
  List<BracketItem> archivedForHost(String hostId) =>
      List.unmodifiable(_archivedByHost[hostId] ?? []);

  /// All archived brackets across all hosts.
  List<BracketItem> get allArchived {
    final all = <BracketItem>[];
    for (final list in _archivedByHost.values) {
      all.addAll(list);
    }
    return all;
  }

  /// Archived brackets for the current user (brackets they hosted that are done).
  List<BracketItem> archivedForCurrentUser(String userId) {
    return allArchived.where((b) => b.host?.id == userId).toList();
  }

  /// Number of new brackets added in the last 24 hours.
  int get newTodayCount {
    if (_lastRefresh == null) return 0;
    final now = DateTime.now();
    final diff = now.difference(_lastRefresh!);
    return diff.inHours < 24 ? _lastBatchSize : 0;
  }

  /// Inject Firestore brackets into the board.
  /// Converts raw Firestore bracket maps into BracketItem objects and inserts
  /// them at the top of the board. Skips duplicates by bracket ID.
  void injectFirestoreBrackets(List<Map<String, dynamic>> firestoreBrackets) {
    final existingIds = _boardItems.map((b) => b.item.id).toSet();
    int injected = 0;

    for (final fb in firestoreBrackets) {
      final docId = fb['doc_id'] as String? ?? fb['bracket_id'] as String? ?? '';
      final fsId = 'fs_$docId'; // prefix to avoid collision with template IDs
      if (docId.isEmpty || existingIds.contains(fsId)) continue;

      final status = fb['status'] as String? ?? 'draft';
      // Only inject active brackets
      if (status != 'live' && status != 'upcoming' && status != 'in_progress') continue;

      final teams = List<String>.from(fb['teams'] ?? []);
      final entryFee = (fb['entry_fee'] as num?)?.toDouble() ?? 0;
      final prizeValue = (fb['prize_value'] as num?)?.toDouble() ?? 0;
      final entrants = (fb['entrants_count'] as num?)?.toInt() ?? 0;
      final maxEntrants = (fb['max_entrants'] as num?)?.toInt() ?? 0;
      final isFeatured = fb['is_featured'] as bool? ?? false;
      final hostName = fb['host_display_name'] as String? ?? 'Unknown Host';
      final hostId = fb['host_user_id'] as String? ?? '';
      final sport = fb['sport'] as String? ?? 'General';
      final name = fb['name'] as String? ?? 'Untitled Bracket';
      final prizeDesc = fb['prize_description'] as String? ?? '';

      // Build a host
      final host = BracketHost(
        id: hostId,
        name: hostName,
        rating: 4.5,
        reviewCount: 0,
        isVerified: true,
        isTopHost: isFeatured,
        location: '',
        totalHosted: 0,
      );

      final item = BracketItem(
        id: fsId,
        title: name,
        sport: sport,
        participants: entrants,
        entryFee: entryFee,
        prizeAmount: prizeValue.toDouble(),
        host: host,
        status: status == 'upcoming' ? 'upcoming' : 'live',
        gameType: _mapBracketType(fb['bracket_type'] as String? ?? 'elimination'),
        usesBmbBucks: entryFee == 0 && prizeValue > 0,
        entryCredits: entryFee > 0 ? entryFee.toInt() : null,
        prizeCredits: prizeValue > 0 ? prizeValue.toInt() : null,
        isVipBoosted: isFeatured,
        teams: teams,
        description: prizeDesc,
        totalPicks: teams.isNotEmpty ? (teams.length / 2).floor() : 0,
        picksMade: 0,
        maxParticipants: maxEntrants,
        rewardType: _mapRewardType(fb['prize_type'] as String? ?? 'custom'),
        rewardDescription: prizeDesc,
      );

      _boardItems.insert(0, _BoardBracket(item, DateTime.now()));
      existingIds.add(fsId);
      injected++;
    }

    if (kDebugMode && injected > 0) {
      debugPrint('[BracketBoardService] Injected $injected Firestore brackets into board');
    }
  }

  /// Map Firestore bracket_type to GameType enum.
  static GameType _mapBracketType(String type) {
    switch (type.toLowerCase()) {
      case 'pickem':
      case 'pick_em':
        return GameType.pickem;
      case 'squares':
        return GameType.squares;
      case 'trivia':
        return GameType.trivia;
      case 'props':
        return GameType.props;
      case 'survivor':
        return GameType.survivor;
      case 'voting':
        return GameType.voting;
      default:
        return GameType.bracket;
    }
  }

  /// Map Firestore prize_type to RewardType enum.
  static RewardType _mapRewardType(String type) {
    switch (type.toLowerCase()) {
      case 'credits':
        return RewardType.credits;
      case 'charity':
        return RewardType.charity;
      case 'bragging':
      case 'none':
        return RewardType.none;
      default:
        return RewardType.custom;
    }
  }

  /// Force-add a bracket to the board (e.g. from bracket builder).
  void addBracket(BracketItem bracket) {
    _boardItems.insert(0, _BoardBracket(bracket, DateTime.now()));
    if (bracket.status == 'done') {
      _archiveSingle(bracket);
      _boardItems.first.archived = true;
    }
  }

  /// Mark a bracket as completed → move to archive.
  void completeBracket(String bracketId) {
    final idx = _boardItems.indexWhere((b) => b.item.id == bracketId);
    if (idx < 0) return;
    final old = _boardItems[idx].item;
    final done = BracketItem(
      id: old.id,
      title: old.title,
      sport: old.sport,
      participants: old.participants,
      entryFee: old.entryFee,
      prizeAmount: old.prizeAmount,
      imageUrl: old.imageUrl,
      host: old.host,
      authorName: old.authorName,
      status: 'done',
      usesBmbBucks: old.usesBmbBucks,
      entryCredits: old.entryCredits,
      prizeCredits: old.prizeCredits,
      isVipBoosted: old.isVipBoosted,
      teams: old.teams,
      description: old.description,
      totalGames: old.totalGames,
      completedGames: old.totalGames,
      totalPicks: old.totalPicks,
      picksMade: old.totalPicks,
      maxParticipants: old.maxParticipants,
      rewardType: old.rewardType,
      rewardDescription: old.rewardDescription,
    );
    _boardItems[idx] = _BoardBracket(done, _boardItems[idx].addedAt);
    _archiveSingle(done);
    // Keep it on board briefly so users see "COMPLETED" badge
  }

  /// **Reset the entire board**: clear all items and regenerate a fresh set.
  void resetBoard() {
    _boardItems.clear();
    _generateFreshBoard();
    _lastRefresh = DateTime.now();
    _lastBatchSize = _boardItems.length;
  }

  /// Manually trigger a daily refresh (useful for pull-to-refresh).
  Future<int> triggerDailyRefresh({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!force) {
      final lastMs = prefs.getInt('last_board_refresh') ?? 0;
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      final diff = now.difference(last);
      if (diff.inHours < 24) return 0;
    }

    // Run lifecycle to archive expired items
    _runLifecycleCheck();

    // Add new brackets to fill the board
    final rng = Random();
    final deficit = _minBoardSize - boardBrackets.length;
    final count = max(_newPerCycle, deficit);
    _lastBatchSize = count;
    for (var i = 0; i < count; i++) {
      _boardItems.insert(0, _generateNewBoardBracket(rng));
    }

    _lastRefresh = now;
    await prefs.setInt('last_board_refresh', now.millisecondsSinceEpoch);
    return count;
  }

  // ─── SORT HELPERS ────────────────────────────────────────────────────
  void sortBoard(String sortBy) {
    final active = _boardItems.where((b) => !b.archived).toList();
    final archived = _boardItems.where((b) => b.archived).toList();

    switch (sortBy) {
      case 'VIP First':
        active.sort((a, b) {
          if (a.item.isVipBoosted && !b.item.isVipBoosted) return -1;
          if (!a.item.isVipBoosted && b.item.isVipBoosted) return 1;
          final aTop = a.item.host?.isTopHost ?? false;
          final bTop = b.item.host?.isTopHost ?? false;
          if (aTop && !bTop) return -1;
          if (!aTop && bTop) return 1;
          return 0;
        });
      case 'Top Rated':
        active.sort((a, b) {
          final aR = a.item.host?.rating ?? 0;
          final bR = b.item.host?.rating ?? 0;
          return bR.compareTo(aR);
        });
      case 'Most Players':
        active.sort((a, b) => b.item.participants.compareTo(a.item.participants));
      case 'Free Entry':
        active.sort((a, b) {
          if (a.item.isFree && !b.item.isFree) return -1;
          if (!a.item.isFree && b.item.isFree) return 1;
          return 0;
        });
      case 'Newest':
        active.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }

    _boardItems
      ..clear()
      ..addAll(active)
      ..addAll(archived);
  }

  /// Get visibility duration config (exposed for settings UI).
  static Duration getVisibilityDuration(String status) {
    return visibilityDurations[status] ?? const Duration(hours: 24);
  }

  /// Human-readable TTL label for the board info section.
  static String visibilityLabel(String status) {
    final dur = visibilityDurations[status]!;
    if (dur.inHours >= 24) return '${dur.inDays}d';
    return '${dur.inHours}h';
  }

  /// Dispose the timer (call when service is no longer needed).
  void dispose() {
    _lifecycleTimer?.cancel();
    _lifecycleTimer = null;
  }

  // ─── PRIVATE: FRESH BOARD GENERATION ────────────────────────────────

  /// Generate a fresh board prioritizing REAL sports content from the
  /// DailyContentEngine, then filling remaining slots with templates.
  void _generateFreshBoard() {
    final rng = Random();

    // ═══ STEP 1: Add REAL content from DailyContentEngine ═══
    final realItems = DailyContentEngine.instance.toBracketItems();
    for (final item in realItems) {
      final addedAt = DateTime.now().subtract(
        Duration(minutes: rng.nextInt(120)), // stagger slightly
      );
      _boardItems.add(_BoardBracket(item, addedAt));
    }

    if (kDebugMode) {
      debugPrint('[BracketBoardService] Added ${realItems.length} REAL content items');
    }

    // ═══ STEP 2: Fill remaining with template variety if needed ═══
    final target = _minBoardSize + rng.nextInt(4);
    if (_boardItems.length < target) {
      final statusWeights = ['upcoming', 'live', 'live', 'in_progress'];
      final shuffled = List<int>.generate(_templatePool.length, (i) => i)..shuffle(rng);
      var templateIdx = 0;
      final toAdd = target - _boardItems.length;

      for (var i = 0; i < toAdd; i++) {
        final tIdx = shuffled[templateIdx % shuffled.length];
        templateIdx++;
        final template = _templatePool[tIdx];
        final host = _hostPool[rng.nextInt(_hostPool.length)];
        final status = statusWeights[rng.nextInt(statusWeights.length)];
        final id = 'board_${_nextId++}';
        final hoursAgo = rng.nextDouble() * 36;
        final addedAt = DateTime.now().subtract(Duration(minutes: (hoursAgo * 60).round()));
        // REAL participant counts: 1 host + 3-6 bots
        final botJoiners = 3 + rng.nextInt(4);
        final participants = 1 + botJoiners;
        final maxP = 0; // unlimited — no participant cap
        final teams = _getTeamsForTemplate(template);
        // Pick 'Em totalPicks = number of matchups (teams/2).
        // Standard brackets use generic random picks count.
        final totalPicks = template.gameType == GameType.pickem
            ? (teams.length / 2).floor()
            : 7 + rng.nextInt(57);
        // CRITICAL FIX: picksMade=0 for joinable brackets (upcoming + live)
        // so users joining see a blank slate, not fake progress.
        final picksMade = (status == 'upcoming' || status == 'live') ? 0 : rng.nextInt(totalPicks + 1);
        final totalGames = (status == 'in_progress' || status == 'done') ? 15 + rng.nextInt(48) : 0;
        final completedGames = status == 'done' ? totalGames : status == 'in_progress' ? rng.nextInt(totalGames + 1) : 0;

        final item = BracketItem(
          id: id, title: template.title, sport: template.sport,
          participants: participants,
          // NEW ECONOMY: entryFee in $ = entryCredits * $0.10
          entryFee: template.isFree ? 0 : (template.entryCredits != null ? template.entryCredits! * 0.10 : template.entryFee),
          prizeAmount: template.prizeCredits != null ? template.prizeCredits! * 0.10 : template.prizeAmount,
          host: host, status: status,
          gameType: template.gameType, usesBmbBucks: template.entryCredits != null,
          entryCredits: template.entryCredits, prizeCredits: template.prizeCredits,
          isVipBoosted: template.isVipBoosted,
          teams: teams,
          description: template.rewardDesc,
          totalPicks: totalPicks,
          picksMade: picksMade, totalGames: totalGames,
          completedGames: completedGames, maxParticipants: maxP,
          rewardType: template.rewardType, rewardDescription: template.rewardDesc,
        );
        final bb = _BoardBracket(item, addedAt);
        if (status == 'done') { _archiveSingle(item); bb.archived = true; }
        _boardItems.add(bb);
      }
    }

    // ═══ STEP 3: Guarantee Pick 'Em entries on every board ═══
    _seedPickEmBrackets(rng);

    // ═══ STEP 3.5: Seed bot picks for template brackets ═══
    // Since we no longer auto-generate mock picks, bots must explicitly
    // submit their picks so the leaderboard isn't empty when users join.
    _seedBotPicksForTemplateBrackets(rng);

    // ═══ STEP 4: Sort — real live content first, then VIP ═══
    _boardItems.sort((a, b) {
      if (a.archived && !b.archived) return 1;
      if (!a.archived && b.archived) return -1;
      // Real content (live_ prefix) sorts before template content
      final aReal = a.item.id.startsWith('live_') ? 0 : 1;
      final bReal = b.item.id.startsWith('live_') ? 0 : 1;
      if (aReal != bReal) return aReal.compareTo(bReal);
      final statusOrder = {'live': 0, 'upcoming': 1, 'in_progress': 2, 'done': 3};
      final aO = statusOrder[a.item.status] ?? 4;
      final bO = statusOrder[b.item.status] ?? 4;
      if (aO != bO) return aO.compareTo(bO);
      if (a.item.isVipBoosted && !b.item.isVipBoosted) return -1;
      if (!a.item.isVipBoosted && b.item.isVipBoosted) return 1;
      return b.addedAt.compareTo(a.addedAt);
    });
  }

  // ─── PRIVATE: SEED PICK 'EM BRACKETS ────────────────────────────────

  /// Guarantee at least [_minPickEms] Pick 'Em entries are present on the
  /// board. Each uses the correct single-round structure (totalPicks =
  /// teams/2, i.e. the number of independent matchups).
  static const int _minPickEms = 4;

  void _seedPickEmBrackets(Random rng) {
    final pickEmTemplates = _templatePool
        .where((t) => t.gameType == GameType.pickem)
        .toList();

    // Count existing pick 'ems already on board
    final existingCount = _boardItems
        .where((b) => !b.archived && b.item.gameType == GameType.pickem)
        .length;

    if (existingCount >= _minPickEms) return;

    final need = _minPickEms - existingCount;
    final shuffled = List<_BracketTemplate>.from(pickEmTemplates)..shuffle(rng);

    // Pick a variety of statuses so the user sees joinable + in-play entries
    final statuses = ['live', 'live', 'upcoming', 'live'];

    for (var i = 0; i < need; i++) {
      final template = shuffled[i % shuffled.length];
      final host = _hostPool[rng.nextInt(_hostPool.length)];
      final status = statuses[i % statuses.length];
      final id = 'pickem_${_nextId++}';
      final teams = _getTeamsForTemplate(template);
      final totalPicks = (teams.length / 2).floor(); // one pick per matchup
      final botJoiners = 3 + rng.nextInt(4);
      final participants = 1 + botJoiners;
      // CRITICAL FIX: picksMade=0 for joinable pick'em brackets
      final picksMade = (status == 'upcoming' || status == 'live') ? 0 : rng.nextInt(totalPicks + 1);
      final minutesAgo = rng.nextInt(180); // added within last 3 hours
      final addedAt = DateTime.now().subtract(Duration(minutes: minutesAgo));

      final item = BracketItem(
        id: id,
        title: template.title,
        sport: template.sport,
        participants: participants,
        entryFee: template.isFree ? 0 : (template.entryCredits != null ? template.entryCredits! * 0.10 : template.entryFee),
        prizeAmount: template.prizeCredits != null ? template.prizeCredits! * 0.10 : template.prizeAmount,
        host: host,
        status: status,
        gameType: GameType.pickem,
        usesBmbBucks: template.entryCredits != null,
        entryCredits: template.entryCredits,
        prizeCredits: template.prizeCredits,
        isVipBoosted: template.isVipBoosted,
        teams: teams,
        description: template.rewardDesc,
        totalPicks: totalPicks,
        picksMade: picksMade,
        totalGames: 0,
        completedGames: 0,
        maxParticipants: 0,
        rewardType: template.rewardType,
        rewardDescription: template.rewardDesc,
      );
      _boardItems.add(_BoardBracket(item, addedAt));
    }

    if (kDebugMode) {
      debugPrint('[BracketBoardService] Seeded $need Pick \'Em brackets '
          '(total on board: ${existingCount + need})');
    }
  }

  // ─── PRIVATE: SEED BOT PICKS FOR TEMPLATE BRACKETS ───────────────
  /// Bots auto-join every board bracket and submit random picks.
  /// This replaces the old MockDataGenerator approach — now bots are
  /// real participants on the leaderboard, and users always start with
  /// a blank slate when they join.
  void _seedBotPicksForTemplateBrackets(Random rng) {
    final bots = BotService.participantBots;
    int seeded = 0;

    for (final bb in _boardItems) {
      if (bb.archived) continue;
      final item = bb.item;
      // Skip items that already have bot picks (e.g. from DailyContentEngine)
      if (item.id.startsWith('live_')) continue;
      if (item.teams.isEmpty) continue;

      // Build a CreatedBracket for picks submission
      List<String> teams = List.from(item.teams);
      int teamCount = teams.length;
      if (item.gameType == GameType.bracket) {
        int pow2 = 2;
        while (pow2 < teamCount) { pow2 *= 2; }
        while (teams.length < pow2) { teams.add('BYE'); }
        teamCount = pow2;
      } else if (teamCount.isOdd) {
        teams.add('BYE');
        teamCount = teams.length;
      }

      // Determine bracketType string
      String bracketType;
      switch (item.gameType) {
        case GameType.pickem:
        case GameType.props:
          bracketType = 'pickem';
        case GameType.voting:
          bracketType = 'voting';
        case GameType.squares:
        case GameType.trivia:
        case GameType.survivor:
          bracketType = 'nopicks';
        case GameType.bracket:
          bracketType = 'standard';
      }

      final cb = CreatedBracket(
        id: item.id,
        name: item.title,
        templateId: 'board_${item.id}',
        sport: item.sport,
        teamCount: teamCount,
        teams: teams,
        status: item.status,
        createdAt: DateTime.now(),
        hostId: item.host?.id ?? 'unknown',
        hostName: item.host?.name ?? 'Unknown',
        bracketType: bracketType,
      );

      // 3-5 bots join each bracket
      final joinCount = 3 + rng.nextInt(3);
      final shuffled = List<BotAccount>.from(bots)..shuffle(rng);
      for (int i = 0; i < joinCount && i < shuffled.length; i++) {
        final bot = shuffled[i];
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
      seeded++;
    }

    if (kDebugMode) {
      debugPrint('[BracketBoardService] Seeded bot picks for $seeded template brackets');
    }
  }

  // ─── PRIVATE: LIFECYCLE TIMER ──────────────────────────────────────

  void _startLifecycleTimer() {
    _lifecycleTimer?.cancel();
    _lifecycleTimer = Timer.periodic(
      Duration(minutes: _lifecycleCheckMinutes),
      (_) => _runLifecycleCheck(),
    );
  }

  /// Check each board item against its TTL. If expired, either progress it to
  /// the next status or archive it.
  void _runLifecycleCheck() {
    final now = DateTime.now();
    final rng = Random();
    var needsReplenish = false;

    for (var i = 0; i < _boardItems.length; i++) {
      final bb = _boardItems[i];
      if (bb.archived) continue;

      final age = now.difference(bb.addedAt);
      final ttl = visibilityDurations[bb.item.status] ?? const Duration(hours: 24);

      if (age > ttl) {
        // Time to progress this bracket
        switch (bb.item.status) {
          case 'upcoming':
            // Promote to live
            _boardItems[i] = _BoardBracket(
              _copyWithStatus(bb.item, 'live'),
              now, // reset timer for the new status
            );
          case 'live':
            // Move to in_progress
            final tg = 15 + rng.nextInt(48);
            _boardItems[i] = _BoardBracket(
              _copyWithStatus(bb.item, 'in_progress',
                  totalGames: tg, completedGames: rng.nextInt(tg)),
              now,
            );
          case 'in_progress':
            // Complete & archive
            final done = _copyWithStatus(bb.item, 'done',
                totalGames: bb.item.totalGames,
                completedGames: bb.item.totalGames);
            _boardItems[i] = _BoardBracket(done, now);
            _archiveSingle(done);
            _boardItems[i].archived = true;
            needsReplenish = true;
          case 'done':
            // Archive if still on board
            _archiveSingle(bb.item);
            bb.archived = true;
            needsReplenish = true;
        }
      }
    }

    // Remove archived items from the active list
    _boardItems.removeWhere((b) => b.archived);

    // Replenish if board is getting thin
    if (needsReplenish || _boardItems.length < _minBoardSize) {
      final deficit = _minBoardSize - _boardItems.length;
      final toAdd = max(_newPerCycle, deficit);
      for (var i = 0; i < toAdd; i++) {
        _boardItems.insert(0, _generateNewBoardBracket(rng));
      }
    }
  }

  BracketItem _copyWithStatus(BracketItem old, String newStatus, {
    int? totalGames, int? completedGames,
  }) {
    return BracketItem(
      id: old.id,
      title: old.title,
      sport: old.sport,
      participants: old.participants,
      entryFee: old.entryFee,
      prizeAmount: old.prizeAmount,
      imageUrl: old.imageUrl,
      host: old.host,
      authorName: old.authorName,
      status: newStatus,
      usesBmbBucks: old.usesBmbBucks,
      entryCredits: old.entryCredits,
      prizeCredits: old.prizeCredits,
      isVipBoosted: old.isVipBoosted,
      teams: old.teams,               // preserve real teams!
      description: old.description,    // preserve description
      totalGames: totalGames ?? old.totalGames,
      completedGames: completedGames ?? old.completedGames,
      totalPicks: old.totalPicks,
      picksMade: old.picksMade,
      maxParticipants: old.maxParticipants,
      rewardType: old.rewardType,
      rewardDescription: old.rewardDescription,
      gameType: old.gameType,
    );
  }

  // ─── PRIVATE: GENERATE A SINGLE NEW BRACKET ──────────────────────────

  _BoardBracket _generateNewBoardBracket(Random rng) {
    final template = _templatePool[rng.nextInt(_templatePool.length)];
    final host = _hostPool[rng.nextInt(_hostPool.length)];
    final id = 'board_${_nextId++}';
    // REAL participant counts: 1 host + 3-6 bots
    final botJoiners = 3 + rng.nextInt(4);
    final participants = 1 + botJoiners;
    final maxP = 0; // unlimited — no participant cap
    // New brackets start as upcoming or live
    final statuses = ['upcoming', 'live', 'live'];
    final status = statuses[rng.nextInt(statuses.length)];
    final teams = _getTeamsForTemplate(template);
    // Pick 'Em totalPicks = number of matchups (teams/2).
    final totalPicks = template.gameType == GameType.pickem
        ? (teams.length / 2).floor()
        : 7 + rng.nextInt(57);
    // CRITICAL FIX: picksMade=0 for joinable brackets
    final picksMade = (status == 'upcoming' || status == 'live') ? 0 : rng.nextInt(totalPicks + 1);

    final item = BracketItem(
      id: id,
      title: template.title,
      sport: template.sport,
      participants: participants,
      entryFee: template.isFree ? 0 : (template.entryCredits != null ? template.entryCredits! * 0.10 : template.entryFee),
      prizeAmount: template.prizeCredits != null ? template.prizeCredits! * 0.10 : template.prizeAmount,
      host: host,
      status: status,
      gameType: template.gameType,
      usesBmbBucks: template.entryCredits != null,
      entryCredits: template.entryCredits,
      prizeCredits: template.prizeCredits,
      isVipBoosted: template.isVipBoosted,
      teams: teams,
      description: template.rewardDesc,
      totalPicks: totalPicks,
      picksMade: picksMade,
      totalGames: 0,
      completedGames: 0,
      maxParticipants: maxP,
      rewardType: template.rewardType,
      rewardDescription: template.rewardDesc,
    );
    return _BoardBracket(item, DateTime.now());
  }

  // ─── PRIVATE: TEAM GENERATION FOR TEMPLATES ─────────────────────────

  /// Generate realistic team lists for template brackets based on sport.
  static List<String> _getTeamsForTemplate(_BracketTemplate template) {
    final s = template.sport.toLowerCase();
    final t = template.title.toLowerCase();

    if (s.contains('basketball') || s.contains('nba')) {
      if (t.contains('march madness') || t.contains('college')) {
        return ['(1) Auburn', '(16) Norfolk St', '(8) Michigan', '(9) Creighton',
                '(5) Marquette', '(12) VCU', '(4) Oregon', '(13) UC Irvine',
                '(6) Illinois', '(11) Xavier', '(3) Iowa State', '(14) Yale',
                '(7) St. John\'s', '(10) New Mexico', '(2) Duke', '(15) Colgate'];
      }
      if (t.contains('dunk')) {
        return ['Mac McClung', 'Anthony Edwards', 'Jalen Green', 'Ja Morant',
                'Zach LaVine', 'Derrick Jones Jr', 'Jaylen Brown', 'Anfernee Simons'];
      }
      if (t.contains('summer')) {
        return ['Lakers', 'Celtics', 'Thunder', 'Rockets',
                'Spurs', 'Warriors', 'Bulls', 'Knicks'];
      }
      return ['Celtics', 'Thunder', 'Knicks', 'Cavaliers',
              'Nuggets', 'Bucks', 'Timberwolves', 'Warriors',
              'Lakers', 'Suns', 'Mavericks', 'Pacers',
              'Heat', '76ers', 'Kings', 'Rockets'];
    }
    if (s.contains('football') || s.contains('nfl')) {
      if (t.contains('draft')) {
        return ['Shedeur Sanders', 'Cam Ward', 'Travis Hunter', 'Tetairoa McMillan',
                'Mason Graham', 'Abdul Carter', 'Malaki Starks', 'Will Johnson',
                'Luther Burden III', 'Mykel Williams', 'Tyler Warren', 'Kelvin Banks Jr.',
                'Jalon Walker', 'Nick Scourton', 'Ashton Jeanty', 'Will Campbell'];
      }
      if (t.contains('survivor')) {
        return ['Chiefs', 'Bills', 'Ravens', 'Lions',
                'Eagles', '49ers', 'Texans', 'Packers',
                'Cowboys', 'Bengals', 'Dolphins', 'Jets',
                'Steelers', 'Bears', 'Vikings', 'Chargers'];
      }
      return ['Chiefs', 'Eagles', '49ers', 'Ravens',
              'Bills', 'Lions', 'Cowboys', 'Dolphins',
              'Packers', 'Texans', 'Bengals', 'Steelers',
              'Vikings', 'Jets', 'Bears', 'Chargers'];
    }
    if (s.contains('baseball') || s.contains('mlb')) {
      return ['Yankees', 'Dodgers', 'Orioles', 'Braves',
              'Phillies', 'Astros', 'Guardians', 'Padres',
              'Brewers', 'Mets', 'Rangers', 'Twins',
              'Mariners', 'Diamondbacks', 'Red Sox', 'Cubs'];
    }
    if (s.contains('hockey') || s.contains('nhl')) {
      return ['Panthers', 'Oilers', 'Rangers', 'Stars',
              'Avalanche', 'Bruins', 'Hurricanes', 'Canucks',
              'Maple Leafs', 'Jets', 'Wild', 'Lightning',
              'Devils', 'Kings', 'Golden Knights', 'Capitals'];
    }
    if (s.contains('soccer') || s.contains('mls') || s.contains('premier')) {
      if (t.contains('premier') || t.contains('pl')) {
        return ['Arsenal', 'Man City', 'Liverpool', 'Chelsea',
                'Newcastle', 'Tottenham', 'Aston Villa', 'Man United',
                'Brighton', 'West Ham', 'Bournemouth', 'Crystal Palace',
                'Brentford', 'Fulham', 'Wolves', 'Everton'];
      }
      if (t.contains('copa')) {
        return ['Argentina', 'Brazil', 'Uruguay', 'Colombia',
                'Mexico', 'USA', 'Chile', 'Ecuador'];
      }
      return ['Inter Miami', 'LAFC', 'Columbus Crew', 'FC Cincinnati',
              'Atlanta United', 'Seattle Sounders', 'Nashville SC', 'Houston Dynamo'];
    }
    if (s.contains('mma') || s.contains('ufc')) {
      return ['Sean Strickland', 'Anthony Hernandez',
              'Movsar Evloev', 'Diego Lopes',
              'Amanda Lemos', 'Virna Jandiroba',
              'Chris Weidman', 'Dricus Du Plessis'];
    }
    if (s.contains('golf') || s.contains('pga')) {
      return ['Scottie Scheffler', 'Rory McIlroy', 'Viktor Hovland', 'Jon Rahm',
              'Bryson DeChambeau', 'Wyndham Clark', 'Justin Thomas', 'Jordan Spieth'];
    }
    if (s.contains('tennis') || s.contains('atp')) {
      return ['Novak Djokovic', 'Carlos Alcaraz', 'Jannik Sinner', 'Daniil Medvedev',
              'Alexander Zverev', 'Stefanos Tsitsipas', 'Holger Rune', 'Taylor Fritz'];
    }
    if (s.contains('voting')) {
      // Community votes use their title context
      if (t.contains('taco')) return ['Guisados', 'Leo\'s Tacos', 'Mariscos Jalisco', 'Sonoratown', 'Tire Shop Taqueria', 'El Chato', 'Tacos 1986', 'Ave 26'];
      if (t.contains('burger')) return ['Au Cheval', 'Small Cheval', 'Shake Shack', 'Portillo\'s', 'Kuma\'s Corner', 'Red Hot Ranch', 'Fatso\'s', 'The Region'];
      if (t.contains('wing')) return ['Atomic Wings', 'Bonchon', 'Dan & John\'s Wings', 'Blondies', 'International Wings', 'Turntable', 'Pio Pio', 'Hooters'];
      if (t.contains('pizza')) return ['Di Fara', 'L&B Spumoni', 'Joe\'s Pizza', 'Lucali', 'Prince Street', 'Scarr\'s', 'Paulie Gee\'s', 'Roberta\'s'];
      if (t.contains('brunch')) return ['Yardbird', 'Nikki Beach', 'The Surf Club', 'Cecconi\'s', 'Juvia', 'Mandolin', 'KYU', 'La Mar'];
      if (t.contains('coffee')) return ['Blue Bottle', 'Stumptown', 'Intelligentsia', 'Counter Culture', 'La Colombe', 'Verve', 'Onyx', 'George Howell'];
      if (t.contains('bbq')) return ['Franklin BBQ', 'Goldee\'s', 'Snow\'s BBQ', 'Interstellar', 'LeRoy & Lewis', 'la Barbecue', 'Micklethwait', 'Terry Black\'s'];
      if (t.contains('sports bar')) return ['The Sports Bookie', 'Foxhole', 'The Ainsworth', 'Stout', 'Legends', 'The Pony Bar', 'Hudson Station', 'The Playwright'];
      return ['Option A', 'Option B', 'Option C', 'Option D', 'Option E', 'Option F', 'Option G', 'Option H'];
    }
    // General/trivia
    return ['Team Alpha', 'Team Bravo', 'Team Charlie', 'Team Delta',
            'Team Echo', 'Team Foxtrot', 'Team Golf', 'Team Hotel'];
  }

  // ─── PRIVATE: ARCHIVAL ──────────────────────────────────────────────

  void _archiveSingle(BracketItem b) {
    final hostId = b.host?.id ?? 'unknown';
    _archivedByHost.putIfAbsent(hostId, () => []);
    if (!_archivedByHost[hostId]!.any((a) => a.id == b.id)) {
      _archivedByHost[hostId]!.insert(0, b);
    }
  }

  Future<void> _checkDailyRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('last_board_refresh') ?? 0;
    if (lastMs == 0) {
      _lastRefresh = DateTime.now();
      await prefs.setInt('last_board_refresh', _lastRefresh!.millisecondsSinceEpoch);
      return;
    }
    _lastRefresh = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final diff = DateTime.now().difference(_lastRefresh!);
    if (diff.inHours >= 24) {
      await triggerDailyRefresh(force: true);
    }
  }
}

// ─── INTERNAL DATA CLASSES ──────────────────────────────────────────

/// Wraps a BracketItem with metadata for board lifecycle management.
class _BoardBracket {
  BracketItem item;
  final DateTime addedAt;
  bool archived = false;

  _BoardBracket(this.item, this.addedAt);
}

/// Simple template data class for bracket generation.
class _BracketTemplate {
  final String title;
  final String sport;
  final RewardType rewardType;
  final String rewardDesc;
  final bool isFree;
  final double entryFee;
  final double prizeAmount;
  final int? entryCredits;
  final int? prizeCredits;
  final bool isVipBoosted;
  final GameType gameType;

  const _BracketTemplate(this.title, this.sport, this.rewardType,
      this.rewardDesc, this.isFree, this.entryFee, this.prizeAmount,
      this.entryCredits, this.prizeCredits, this.isVipBoosted, this.gameType);
}
