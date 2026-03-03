import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/bracket_template.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';
import 'package:bmb_mobile/features/scoring/data/services/scoring_engine.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/leaderboard_screen.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/voting_leaderboard_screen.dart';
import 'package:bmb_mobile/features/community/presentation/widgets/post_to_bmb_sheet.dart';
// ShareBracketSheet now accessed via BracketTreeViewerScreen
import 'package:bmb_mobile/core/widgets/bracket_tree_widget.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/screens/back_it_flow_screen.dart';
import 'package:bmb_mobile/features/sharing/presentation/screens/bracket_tree_viewer_screen.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/hype_man/data/services/hype_man_service.dart';
import 'package:bmb_mobile/core/services/fun_facts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/scoring/data/services/voting_data_service.dart';

/// Screen where users make their bracket picks.
/// Standard brackets include a tie-breaker prediction; voting and no-picks
/// brackets skip it entirely. Voting brackets display vote percentages per
/// matchup (valuable for bars & restaurants) and advance the most-popular pick.
/// [readOnly] prevents making new picks — used for in_progress (view-only)
/// and done (results review) states.
class BracketPicksScreen extends StatefulWidget {
  final CreatedBracket bracket;
  final bool readOnly;
  const BracketPicksScreen({super.key, required this.bracket, this.readOnly = false});
  @override
  State<BracketPicksScreen> createState() => _BracketPicksScreenState();
}

class _BracketPicksScreenState extends State<BracketPicksScreen>
    with TickerProviderStateMixin {
  // Build rounds as list of matchups
  List<List<List<String>>> _rounds = []; // round -> matchup -> [team1, team2]
  final Map<String, String> _picks = {}; // gameId -> picked team
  final _tieBreakerController = TextEditingController();
  final _treeHScrollController = ScrollController();
  int _currentRound = 0;
  bool _submitted = false;
  bool _showScoring = false;
  late bool _showTreeView; // bracket tree is primary for standard; list for pick'em
  bool get _isReadOnly => widget.readOnly || _submitted;
  BracketResults? _results;
  String? _initError;

  // ─── POST-COMPLETION ILLUMINATION ──────────────────────────────
  bool _illuminateShareButtons = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // ─── PICK CELEBRATION (list view — mirrors tree-view starburst) ─────
  AnimationController? _pickCelebrationCtrl;
  String? _celebrationGameId;
  String? _celebrationTeamName;
  Color _celebrationTeamColor = const Color(0xFF00E676);

  // ─── ACTIVE-MATCHUP PULSE (list view) ─────────────────────────
  late AnimationController _listPulseController;

  // ─── FUN FACT OVERLAY (Option C) ──────────────────────────────
  String? _currentFunFact;
  bool _showFunFact = false;

  @override
  void initState() {
    super.initState();
    // Pick 'Em defaults to list view (flat matchup cards); standard uses tree
    _showTreeView = !widget.bracket.isPickEm;
    _glowController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);

    _listPulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Wire HypeMan highlight callback for post-completion buttons
    HypeManService.instance.onHighlightElement = (key) {
      if (key == 'post_completion_share_buttons' && mounted) {
        setState(() => _illuminateShareButtons = true);
      }
    };
    HypeManService.instance.onClearHighlight = () {
      if (mounted) setState(() => _illuminateShareButtons = false);
    };

    // Wire fun-fact overlay callbacks (Option C)
    HypeManService.instance.onFunFactOverlay = (factText) {
      if (mounted) {
        setState(() {
          _currentFunFact = factText;
          _showFunFact = true;
        });
      }
    };
    HypeManService.instance.onFunFactDismiss = () {
      if (mounted) {
        setState(() => _showFunFact = false);
      }
    };

    // Reset fun-fact session for this bracket
    FunFactsService.instance.resetSession();

    try {
      _results = ResultsService.getResults(widget.bracket);
      _buildRounds();
      if (widget.readOnly) {
        // Read-only mode: load picks and lock the UI
        _submitted = true;
        _showScoring = true;
        _loadExistingPicks();
      } else {
        // Editable mode: still load any previously submitted picks so
        // the user can review and update them before the tournament starts.
        _loadExistingPicksEditable();
      }
    } catch (e) {
      _initError = e.toString();
    }
  }

  /// Load existing picks for read-only mode (review/results).
  /// Only loads the CURRENT USER's picks — never falls back to another
  /// user's picks (that was the bug: mock user picks were shown as the
  /// user's own picks, making it look like the bracket was pre-filled).
  void _loadExistingPicks() {
    final allPicks = ResultsService.getAllPicks(widget.bracket);
    if (allPicks.isNotEmpty) {
      final mine = allPicks.cast<UserPicks?>().firstWhere(
        (p) => CurrentUserService.instance.isCurrentUser(p!.userId),
        orElse: () => null,
      );
      if (mine != null && mine.picks.isNotEmpty) {
        _picks.addAll(mine.picks);
        _buildRoundsWithPicks();
      }
    }
  }

  /// Load previously submitted picks for **editable** mode so the user
  /// can review and change them before the tournament starts.
  void _loadExistingPicksEditable() {
    final allPicks = ResultsService.getAllPicks(widget.bracket);
    if (allPicks.isEmpty) return;
    final mine = allPicks.cast<UserPicks?>().firstWhere(
        (p) => CurrentUserService.instance.isCurrentUser(p!.userId),
        orElse: () => null);
    if (mine == null || mine.picks.isEmpty) return;
    // Pre-fill picks but do NOT mark as submitted so the user can still edit
    _picks.addAll(mine.picks);
    _buildRoundsWithPicks();
  }

  @override
  void dispose() {
    _tieBreakerController.dispose();
    _treeHScrollController.dispose();
    _glowController.dispose();
    _pickCelebrationCtrl?.dispose();
    _listPulseController.dispose();
    // Unhook HypeMan callbacks to avoid leaks
    HypeManService.instance.onHighlightElement = null;
    HypeManService.instance.onClearHighlight = null;
    HypeManService.instance.onFunFactOverlay = null;
    HypeManService.instance.onFunFactDismiss = null;
    super.dispose();
  }

  void _buildRounds() {
    _rounds = [];
    var currentTeams = List<String>.from(widget.bracket.teams);

    for (int round = 0; round < widget.bracket.totalRounds; round++) {
      final matchups = <List<String>>[];
      final nextTeams = <String>[];

      for (int m = 0; m < currentTeams.length; m += 2) {
        if (m + 1 < currentTeams.length) {
          matchups.add([currentTeams[m], currentTeams[m + 1]]);
          // Use pick if available, otherwise 'TBD'
          final gameId = 'r${round}_g${m ~/ 2}';
          final pick = _picks[gameId];
          nextTeams.add(pick ?? 'TBD');
        }
      }
      _rounds.add(matchups);
      currentTeams = nextTeams;
    }
  }

  void _selectPick(int round, int matchIndex, String team) {
    final gameId = 'r${round}_g$matchIndex';
    setState(() {
      // Toggle: if user taps the already-picked team, deselect it
      if (_picks[gameId] == team) {
        _picks.remove(gameId);
        _clearDownstreamPicks(round, matchIndex);
        _buildRoundsWithPicks();
        return;
      }

      _picks[gameId] = team;

      // Clear downstream picks that depended on a different choice
      _clearDownstreamPicks(round, matchIndex);

      // Rebuild rounds with updated picks
      _buildRoundsWithPicks();
    });

    // ═══ LIST-VIEW CELEBRATION (mirrors tree-view starburst) ═══
    if (!_showTreeView) {
      _triggerListCelebration(gameId, team);
    }

    // ═══ FUN FACT DELIVERY (Option C) ═══
    // Find the opponent for this matchup to enable matchup-specific facts
    if (round < _rounds.length && matchIndex < _rounds[round].length) {
      final matchup = _rounds[round][matchIndex];
      final opponent = matchup[0] == team ? matchup[1] : matchup[0];
      HypeManService.instance.deliverFunFact(
        team: team,
        sport: widget.bracket.sport,
        opponent: opponent != 'TBD' ? opponent : null,
      );
    }

    // Auto-advance: scroll to the next matchup that needs a pick
    if (_showTreeView && !_submitted) {
      _autoScrollToNextPick(round, matchIndex);
    }
  }

  /// Find the next unpicked matchup and scroll the bracket tree so it's
  /// **centered on screen** — the user should always see the next matchup
  /// that needs their attention without having to manually scroll.
  void _autoScrollToNextPick(int justPickedRound, int justPickedMatch) {
    // Layout constants from BracketTreeWidget
    const double cellW = 165;
    const double connW = 36;

    // First check: is there another unpicked game in the SAME round?
    if (justPickedRound < _rounds.length) {
      final roundMatchups = _rounds[justPickedRound];
      for (int m = justPickedMatch + 1; m < roundMatchups.length; m++) {
        final gid = 'r${justPickedRound}_g$m';
        if (!_picks.containsKey(gid)) {
          // Same round still has unpicked matchups — no horizontal scroll
          return;
        }
      }
    }

    // Find the next round that has a newly available (pickable) matchup
    int targetRound = -1;
    for (int r = justPickedRound + 1; r < widget.bracket.totalRounds; r++) {
      if (r >= _rounds.length) break;
      final roundMatchups = _rounds[r];
      for (int m = 0; m < roundMatchups.length; m++) {
        final gid = 'r${r}_g$m';
        if (!_picks.containsKey(gid)) {
          // Check both teams are available (not TBD)
          final teams = roundMatchups[m];
          if (teams[0] != 'TBD' && teams[1] != 'TBD') {
            targetRound = r;
            break;
          }
        }
      }
      if (targetRound >= 0) break;
    }

    // If all regular picks are done, scroll to champion area
    if (targetRound < 0 && _allPicksMade) {
      final champX = widget.bracket.totalRounds * (cellW + connW);
      _scrollTreeTo(champX, cellW);
      return;
    }

    // Scroll to center the target round
    if (targetRound >= 0) {
      final targetX = targetRound * (cellW + connW);
      _scrollTreeTo(targetX, cellW);
    }
  }

  /// Smoothly scroll the bracket tree so the given X position is
  /// centered on screen (not pinned to the left edge).
  void _scrollTreeTo(double targetX, double cellW) {
    void doScroll() {
      if (!mounted) return;
      if (!_treeHScrollController.hasClients) return;
      final screenWidth = MediaQuery.of(context).size.width;
      final maxScroll = _treeHScrollController.position.maxScrollExtent;
      // Center the target: offset by half screen width, add half cell width
      final scrollTo = (targetX - screenWidth / 2 + cellW / 2)
          .clamp(0.0, maxScroll);
      _treeHScrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_treeHScrollController.hasClients) {
        // Retry after a short delay if controller not attached yet
        Future.delayed(const Duration(milliseconds: 150), doScroll);
      } else {
        doScroll();
      }
    });
  }

  void _buildRoundsWithPicks() {
    _rounds = [];
    var currentTeams = List<String>.from(widget.bracket.teams);

    for (int round = 0; round < widget.bracket.totalRounds; round++) {
      final matchups = <List<String>>[];
      final nextTeams = <String>[];

      for (int m = 0; m < currentTeams.length; m += 2) {
        if (m + 1 < currentTeams.length) {
          matchups.add([currentTeams[m], currentTeams[m + 1]]);
          final gameId = 'r${round}_g${m ~/ 2}';
          final pick = _picks[gameId];
          nextTeams.add(pick ?? 'TBD');
        }
      }
      _rounds.add(matchups);
      currentTeams = nextTeams;
    }
  }

  void _clearDownstreamPicks(int round, int matchIndex) {
    // When a user changes a pick, clear all downstream picks that are affected
    final nextRound = round + 1;
    if (nextRound >= widget.bracket.totalRounds) return;

    final nextMatchIndex = matchIndex ~/ 2;
    final nextGameId = 'r${nextRound}_g$nextMatchIndex';

    if (_picks.containsKey(nextGameId)) {
      _picks.remove(nextGameId);
      _clearDownstreamPicks(nextRound, nextMatchIndex);
    }
  }

  bool get _allPicksMade {
    for (int round = 0; round < widget.bracket.totalRounds; round++) {
      final matchCount = _rounds.length > round ? _rounds[round].length : 0;
      for (int m = 0; m < matchCount; m++) {
        final gameId = 'r${round}_g$m';
        if (!_picks.containsKey(gameId)) return false;
      }
    }
    return true;
  }

  bool get _tieBreakerFilled =>
      _tieBreakerController.text.trim().isNotEmpty;

  /// Standard and pick'em brackets need a tie-breaker prediction.
  /// Voting brackets and no-picks brackets skip it entirely.
  bool get _needsTieBreaker =>
      widget.bracket.bracketType == 'standard' ||
      widget.bracket.bracketType == 'pickem';

  /// Whether this is a voting bracket (most-popular pick advances).
  bool get _isVotingBracket => widget.bracket.isVoting;

  bool get _canSubmit => _allPicksMade && (_needsTieBreaker ? _tieBreakerFilled : true);

  /// Persist that the current user has submitted picks for this bracket.
  /// Dashboard reads this from SharedPreferences to personalize action buttons.
  Future<void> _recordPicksMadeToPrefs(String bracketId) async {
    final prefs = await SharedPreferences.getInstance();
    final pickedList = prefs.getStringList('picked_bracket_ids') ?? [];
    if (!pickedList.contains(bracketId)) {
      pickedList.add(bracketId);
      await prefs.setStringList('picked_bracket_ids', pickedList);
    }
  }

  void _submitPicks() {
    if (!_canSubmit) {
      String msg = 'Please make all your picks before submitting.';
      if (!_allPicksMade) msg = 'Please make all bracket picks before submitting.';
      if (_needsTieBreaker && !_tieBreakerFilled) msg = 'Tie-breaker prediction is required.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: BmbColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    final tiePrediction = _needsTieBreaker
        ? (int.tryParse(_tieBreakerController.text.trim()) ?? 0)
        : 0;

    // Submit picks via ResultsService
    final cu = CurrentUserService.instance;
    ResultsService.submitPicks(UserPicks(
      userId: cu.userId,
      userName: cu.displayName.isNotEmpty ? cu.displayName : 'You',
      userState: cu.stateAbbr.isNotEmpty ? cu.stateAbbr : 'US',
      bracketId: widget.bracket.id,
      picks: Map.from(_picks),
      submittedAt: DateTime.now(),
    ));

    setState(() {
      _submitted = true;
      _showScoring = true;
    });

    // Record that user made picks for this bracket (persisted for dashboard state)
    _recordPicksMadeToPrefs(widget.bracket.id);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_needsTieBreaker
          ? 'Picks submitted! Tie-breaker: $tiePrediction total points.'
          : _isVotingBracket
              ? 'Vote submitted! Results will show the most popular picks.'
              : 'Picks submitted!')),
      ]),
      backgroundColor: BmbColors.successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));

    // ═══ HYPE MAN: Post-completion voice prompt + button illumination ═══
    // Delayed slightly so the success snackbar shows first
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      // Trigger the bracketCompleted voice line which tells user to share
      HypeManService.instance.speakDirect(HypeTrigger.bracketCompleted);
      // Illuminate the share buttons in the bottom bar
      setState(() => _illuminateShareButtons = true);
      // Auto-clear illumination after 8 seconds
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) setState(() => _illuminateShareButtons = false);
      });
    });
  }

  String _roundName(int round) {
    // Pick 'Em: single round of independent matchups
    if (widget.bracket.isPickEm) return 'All Matchups';
    final totalRounds = widget.bracket.totalRounds;
    final remaining = totalRounds - round;
    if (remaining == 0) return 'Champion';
    if (remaining == 1) return 'Finals';
    if (remaining == 2) return 'Semi-Finals';
    if (remaining == 3) return 'Quarter-Finals';
    return 'Round ${round + 1}';
  }

  @override
  Widget build(BuildContext context) {
    // If initialization failed, show error screen
    if (_initError != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text('Make My Picks', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                  ]),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.error_outline, color: BmbColors.errorRed, size: 48),
                        const SizedBox(height: 16),
                        Text('Something went wrong', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold)),
                        const SizedBox(height: 8),
                        Text('Error: $_initError', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _initError = null;
                              try {
                                _results = ResultsService.getResults(widget.bracket);
                                _buildRounds();
                              } catch (e) {
                                _initError = e.toString();
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: BmbColors.blue),
                          child: const Text('Retry'),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If no teams, show empty state
    if (widget.bracket.teams.isEmpty || _rounds.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Make My Picks', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                        Text(widget.bracket.name, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                ),
                Expanded(
                  child: Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.sports_esports_outlined, color: BmbColors.textTertiary, size: 48),
                      const SizedBox(height: 16),
                      Text('Bracket not ready yet', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold)),
                      const SizedBox(height: 8),
                      Text('Teams: ${widget.bracket.teams.length} | Rounds: ${widget.bracket.totalRounds}',
                          style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('The host needs to set up the bracket teams.', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  if (_showScoring) _buildScoringBanner(),
                  if (!_showTreeView) _buildRoundTabs(),
                  Expanded(
                    child: _showTreeView
                        ? Column(
                            children: [
                              Expanded(child: _buildBracketTree()),
                              if (_needsTieBreaker) _buildTieBreakerStrip(),
                            ],
                          )
                        : _buildPicksList(),
                  ),
                  _buildBottomBar(),
                ],
              ),
              // ═══ FUN FACT OVERLAY (Option C) ═══
              if (_showFunFact && _currentFunFact != null)
                _buildFunFactOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.readOnly
                      ? (widget.bracket.status == 'done' ? 'Final Results' : 'My Picks')
                      : widget.bracket.isPickEm ? 'Pick Your Winners'
                      : _isVotingBracket ? 'Cast Your Vote'
                      : 'Make My Picks',
                  style: TextStyle(color: BmbColors.textPrimary, fontSize: 18,
                      fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              Text(widget.bracket.name,
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          // Tree/List toggle (hidden for pick'em — list only)
          if (!widget.bracket.isPickEm)
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _viewToggle(Icons.account_tree, 'Tree', _showTreeView),
                _viewToggle(Icons.view_list, 'List', !_showTreeView),
              ]),
            ),
          if (_submitted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (widget.readOnly
                        ? (widget.bracket.status == 'done'
                            ? const Color(0xFF00BCD4)
                            : BmbColors.gold)
                        : BmbColors.successGreen)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (widget.readOnly
                            ? (widget.bracket.status == 'done'
                                ? const Color(0xFF00BCD4)
                                : BmbColors.gold)
                            : BmbColors.successGreen)
                        .withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    widget.readOnly
                        ? (widget.bracket.status == 'done'
                            ? Icons.emoji_events
                            : Icons.lock)
                        : Icons.check_circle,
                    color: widget.readOnly
                        ? (widget.bracket.status == 'done'
                            ? const Color(0xFF00BCD4)
                            : BmbColors.gold)
                        : BmbColors.successGreen,
                    size: 14),
                const SizedBox(width: 4),
                Text(
                    widget.readOnly
                        ? (widget.bracket.status == 'done'
                            ? 'Completed'
                            : 'Locked')
                        : 'Submitted',
                    style: TextStyle(
                        color: widget.readOnly
                            ? (widget.bracket.status == 'done'
                                ? const Color(0xFF00BCD4)
                                : BmbColors.gold)
                            : BmbColors.successGreen,
                        fontSize: 10,
                        fontWeight: BmbFontWeights.bold)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildScoringBanner() {
    // Show score comparison
    final allPicks = ResultsService.getAllPicks(widget.bracket);
    final cu = CurrentUserService.instance;
    final myPicks = allPicks.firstWhere(
      (p) => cu.isCurrentUser(p.userId),
      orElse: () => UserPicks(userId: cu.userId, userName: cu.displayName.isNotEmpty ? cu.displayName : 'You', bracketId: widget.bracket.id, picks: _picks, submittedAt: DateTime.now()),
    );
    final entry = ScoringEngine.scoreUser(
      userPicks: myPicks, results: _results!,
      totalRounds: widget.bracket.totalRounds, rank: 0, isCurrentUser: true,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BmbColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _scoreStat('Score', '${entry.score}', BmbColors.gold),
          _scoreStat('Correct', '${entry.correctPicks}', BmbColors.successGreen),
          _scoreStat('Wrong', '${entry.incorrectPicks}', BmbColors.errorRed),
          _scoreStat('Pending', '${entry.pendingPicks}', BmbColors.textTertiary),
        ],
      ),
    );
  }

  Widget _scoreStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
      Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
    ]);
  }

  Widget _buildRoundTabs() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        // +1 for tie-breaker tab (only for standard brackets)
        itemCount: widget.bracket.totalRounds + (_needsTieBreaker ? 1 : 0),
        itemBuilder: (ctx, i) {
          final isTieBreakerTab = _needsTieBreaker && i == widget.bracket.totalRounds;
          final sel = _currentRound == i;

          if (isTieBreakerTab) {
            return GestureDetector(
              onTap: () => setState(() => _currentRound = i),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? BmbColors.gold : (_tieBreakerFilled ? BmbColors.gold.withValues(alpha: 0.15) : BmbColors.cardDark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? BmbColors.gold : (_tieBreakerFilled ? BmbColors.gold : BmbColors.borderColor)),
                ),
                child: Row(children: [
                  if (_tieBreakerFilled && !sel) ...[
                    Icon(Icons.check_circle, color: BmbColors.gold, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Text('Tie-Breaker', style: TextStyle(
                    color: sel ? Colors.black : BmbColors.textSecondary,
                    fontSize: 12, fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal)),
                ]),
              ),
            );
          }

          // Regular round tab
          final roundMatchups = _rounds.length > i ? _rounds[i] : <List<String>>[];
          int picksInRound = 0;
          for (int m = 0; m < roundMatchups.length; m++) {
            if (_picks.containsKey('r${i}_g$m')) picksInRound++;
          }
          final allDone = roundMatchups.isNotEmpty && picksInRound == roundMatchups.length;

          return GestureDetector(
            onTap: () => setState(() => _currentRound = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? BmbColors.blue : (allDone ? BmbColors.successGreen.withValues(alpha: 0.15) : BmbColors.cardDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? BmbColors.blue : (allDone ? BmbColors.successGreen : BmbColors.borderColor)),
              ),
              child: Row(children: [
                if (allDone && !sel) ...[
                  Icon(Icons.check_circle, color: BmbColors.successGreen, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(_roundName(i), style: TextStyle(
                  color: sel ? Colors.white : BmbColors.textSecondary,
                  fontSize: 12, fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal)),
                if (!allDone && roundMatchups.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text('$picksInRound/${roundMatchups.length}',
                      style: TextStyle(color: sel ? Colors.white70 : BmbColors.textTertiary, fontSize: 9)),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _viewToggle(IconData icon, String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _showTreeView = label == 'Tree'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? BmbColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? Colors.white : BmbColors.textTertiary, size: 14),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(
            color: active ? Colors.white : BmbColors.textTertiary,
            fontSize: 9, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ─── TIE-BREAKER STRIP (visible in tree view) ──────────────
  Widget _buildTieBreakerStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy,
        border: Border(top: BorderSide(color: BmbColors.gold.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.sports_score, color: BmbColors.gold, size: 18),
          const SizedBox(width: 8),
          Text('Tie-Breaker:', style: TextStyle(
            color: BmbColors.gold, fontSize: 11,
            fontWeight: BmbFontWeights.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: _tieBreakerController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: BmbColors.textPrimary, fontSize: 14,
                  fontWeight: BmbFontWeights.bold),
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Total pts',
                  hintStyle: TextStyle(
                    color: BmbColors.textTertiary.withValues(alpha: 0.5),
                    fontSize: 12),
                  filled: true,
                  fillColor: BmbColors.cardDark,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: BmbColors.gold.withValues(alpha: 0.3))),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: BmbColors.gold.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: BmbColors.gold, width: 1.5)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            _tieBreakerFilled ? Icons.check_circle : Icons.error_outline,
            color: _tieBreakerFilled ? BmbColors.successGreen : BmbColors.textTertiary,
            size: 16,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _showTieBreakerInfo(),
            child: Icon(Icons.info_outline,
              color: BmbColors.textTertiary.withValues(alpha: 0.6), size: 16),
          ),
        ],
      ),
    );
  }

  void _showTieBreakerInfo() {
    final tieBreakerGame = widget.bracket.tieBreakerGame ?? 'Championship Game';
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: BmbColors.borderColor,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Icon(Icons.sports_score, color: BmbColors.gold, size: 36),
          const SizedBox(height: 8),
          Text('Tie-Breaker Prediction', style: TextStyle(
            color: BmbColors.gold, fontSize: 18,
            fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 4),
          Text(tieBreakerGame, style: TextStyle(
            color: BmbColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Text(
            'Predict the TOTAL combined points for the championship game.\n\n'
            'Closest to the actual total WITHOUT going over wins.\n'
            'If both go over, closest to actual wins.',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildBracketTree() {
    // Calculate score percentage for overlay
    int? scorePct;
    if (_showScoring && _results != null) {
      final allPicks = ResultsService.getAllPicks(widget.bracket);
      final cu2 = CurrentUserService.instance;
      final myPicks = allPicks.cast<UserPicks?>().firstWhere(
        (p) => cu2.isCurrentUser(p!.userId),
        orElse: () => null,
      ) ?? UserPicks(userId: cu2.userId, userName: cu2.displayName.isNotEmpty ? cu2.displayName : 'You', bracketId: widget.bracket.id, picks: _picks, submittedAt: DateTime.now());
      final entry = ScoringEngine.scoreUser(
        userPicks: myPicks, results: _results!,
        totalRounds: widget.bracket.totalRounds, rank: 0, isCurrentUser: true,
      );
      final total = entry.correctPicks + entry.incorrectPicks + entry.pendingPicks;
      scorePct = total > 0 ? ((entry.correctPicks / total) * 100).round() : 0;
    }

    return BracketTreeWidget(
      teams: widget.bracket.teams,
      totalRounds: widget.bracket.totalRounds,
      picks: _picks,
      submitted: _isReadOnly,
      scorePct: scorePct,
      sport: widget.bracket.sport,
      horizontalScrollController: _treeHScrollController,
      onPick: _isReadOnly
          ? null
          : (round, matchIndex, team) {
              _selectPick(round, matchIndex, team);
            },
    );
  }

  Widget _buildPicksList() {
    // Tie-breaker tab (only for standard brackets)
    if (_needsTieBreaker && _currentRound == widget.bracket.totalRounds) {
      return _buildTieBreakerTab();
    }

    if (_currentRound >= _rounds.length) {
      return Center(child: Text('No matchups', style: TextStyle(color: BmbColors.textTertiary)));
    }

    final matchups = _rounds[_currentRound];

    // For voting brackets, get the voting data to show percentages
    VotingBracketData? votingData;
    if (_isVotingBracket) {
      votingData = VotingDataService().getVotingData(widget.bracket);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      itemCount: matchups.length,
      itemBuilder: (ctx, idx) => _isVotingBracket
          ? _buildVotingMatchupCard(_currentRound, idx, matchups[idx], votingData)
          : _buildMatchupCard(_currentRound, idx, matchups[idx]),
    );
  }

  Widget _buildTieBreakerTab() {
    final tieBreakerGame = widget.bracket.tieBreakerGame ?? 'Championship Game';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tie-breaker header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                BmbColors.gold.withValues(alpha: 0.15),
                BmbColors.gold.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Icon(Icons.sports_score, color: BmbColors.gold, size: 40),
              const SizedBox(height: 8),
              Text('Tie-Breaker Prediction', style: TextStyle(
                color: BmbColors.gold, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const SizedBox(height: 4),
              Text(tieBreakerGame, style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 20),

          // Rules explanation
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How Tie-Breaker Works:', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                const SizedBox(height: 8),
                _tieRuleRow('1', 'Predict the TOTAL combined points for the championship game'),
                _tieRuleRow('2', 'Closest to actual total WITHOUT going over wins'),
                _tieRuleRow('3', 'If both go over, closest to actual wins'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Example:', style: TextStyle(color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                    const SizedBox(height: 4),
                    Text('Player A predicts: 40 points\nPlayer B predicts: 50 points\nActual total: 46 points\n\nPlayer A wins! (40 is under 46 and closest without going over)',
                        style: TextStyle(color: BmbColors.blue, fontSize: 11, height: 1.5)),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tie-breaker input
          Text('Your Prediction', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 4),
          Text('Enter total combined points for: $tieBreakerGame', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _tieBreakerController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: BmbColors.textPrimary, fontSize: 24, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'),
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 24),
              filled: true, fillColor: BmbColors.cardDark,
              suffixText: 'pts',
              suffixStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: BmbColors.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: BmbColors.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: BmbColors.gold, width: 2)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(_tieBreakerFilled ? Icons.check_circle : Icons.error_outline,
                color: _tieBreakerFilled ? BmbColors.successGreen : BmbColors.errorRed, size: 14),
            const SizedBox(width: 6),
            Text(_tieBreakerFilled ? 'Tie-breaker prediction set!' : 'Required to submit your picks',
                style: TextStyle(color: _tieBreakerFilled ? BmbColors.successGreen : BmbColors.errorRed, fontSize: 11)),
          ]),
        ],
      ),
    );
  }

  Widget _tieRuleRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Center(child: Text(num, style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.3))),
      ]),
    );
  }

  // ─── LIST-VIEW CELEBRATION TRIGGER ──────────────────────────
  void _triggerListCelebration(String gameId, String team) {
    _pickCelebrationCtrl?.dispose();
    _pickCelebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    setState(() {
      _celebrationGameId = gameId;
      _celebrationTeamName = _teamDisplayName(team);
      _celebrationTeamColor = _getListTeamColor(team);
    });
    _pickCelebrationCtrl!.forward().then((_) {
      if (mounted) setState(() => _celebrationGameId = null);
    });
  }

  Color _getListTeamColor(String team) {
    final lower = _teamDisplayName(team).toLowerCase();
    // Subset of the tree-widget team color map for quick lookup
    const teamColors = <String, Color>{
      'chiefs': Color(0xFFE31837), 'eagles': Color(0xFF004C54),
      '49ers': Color(0xFFAA0000), 'ravens': Color(0xFF241773),
      'cowboys': Color(0xFF003594), 'lions': Color(0xFF0076B6),
      'lakers': Color(0xFF552583), 'celtics': Color(0xFF007A33),
      'warriors': Color(0xFF1D428A), 'heat': Color(0xFF98002E),
      'duke': Color(0xFF003087), 'alabama': Color(0xFF9E1B32),
      'yankees': Color(0xFF003087), 'dodgers': Color(0xFF005A9C),
    };
    for (final e in teamColors.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    final hash = lower.hashCode;
    return HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.65, 0.45).toColor();
  }

  /// Whether the given matchup is "active" (ready to pick, both teams present,
  /// no pick yet) — used for the pulsing glow in list view.
  bool _isActiveMatchup(int round, int matchIndex) {
    if (_isReadOnly) return false;
    final gameId = 'r${round}_g$matchIndex';
    if (_picks.containsKey(gameId)) return false;
    if (round >= _rounds.length || matchIndex >= _rounds[round].length) return false;
    final teams = _rounds[round][matchIndex];
    return teams[0] != 'TBD' && teams[1] != 'TBD';
  }

  Widget _buildMatchupCard(int round, int matchIndex, List<String> teams) {
    final gameId = 'r${round}_g$matchIndex';
    final currentPick = _picks[gameId];
    final result = _results?.games[gameId];
    final isCompleted = result?.isCompleted ?? false;
    final isActive = _isActiveMatchup(round, matchIndex);
    final isCelebrating = _celebrationGameId == gameId && _pickCelebrationCtrl != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Active-matchup pulse glow border ──
        if (isActive)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _listPulseController,
              builder: (ctx, _) {
                final pulse = _listPulseController.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF00E676).withValues(alpha: 0.25 + pulse * 0.35),
                      width: 1.5 + pulse * 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(alpha: 0.08 + pulse * 0.12),
                        blurRadius: 8 + pulse * 8,
                        spreadRadius: pulse * 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        // ── Main matchup card ──
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted ? BmbColors.successGreen.withValues(alpha: 0.3) : (currentPick != null ? BmbColors.blue.withValues(alpha: 0.3) : BmbColors.borderColor),
              width: 0.5,
            ),
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.borderColor.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(children: [
                Text(widget.bracket.isPickEm ? 'Matchup ${matchIndex + 1}' : 'Game ${matchIndex + 1}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, fontWeight: BmbFontWeights.semiBold)),
                const Spacer(),
                if (currentPick != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text('Picked', style: TextStyle(color: BmbColors.blue, fontSize: 9, fontWeight: BmbFontWeights.bold)),
                  ),
              ]),
            ),
            // Team 1
            _teamPickRow(round, matchIndex, teams[0], currentPick == teams[0]),
            Divider(color: BmbColors.borderColor, height: 0.5),
            // Team 2
            _teamPickRow(round, matchIndex, teams[1], currentPick == teams[1]),
          ]),
        ),
        // ── Celebration overlay (starburst + team burst + sparkles) ──
        if (isCelebrating)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pickCelebrationCtrl!,
                builder: (ctx, _) {
                  return _buildListCelebration(
                    _pickCelebrationCtrl!.value,
                    _celebrationTeamName ?? '',
                    _celebrationTeamColor,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ─── VOTING BRACKET MATCHUP CARD ──────────────────────────────
  /// Matchup card for voting brackets: shows vote percentages per item,
  /// highlights the most-popular pick that advances, and displays % of
  /// players who selected each item — valuable for bars & restaurants.
  Widget _buildVotingMatchupCard(int round, int matchIndex, List<String> teams, VotingBracketData? votingData) {
    final gameId = 'r${round}_g$matchIndex';
    final currentPick = _picks[gameId];

    // Pull voting stats from VotingDataService
    VotingMatchup? matchup;
    if (votingData != null && round < votingData.rounds.length) {
      final roundData = votingData.rounds[round];
      if (matchIndex < roundData.matchups.length) {
        matchup = roundData.matchups[matchIndex];
      }
    }

    final double pctA = matchup?.pctA ?? 50;
    final double pctB = matchup?.pctB ?? 50;
    final String winner = matchup?.winner ?? '';
    final bool isCompleted = matchup?.isCompleted ?? false;
    final isActive = _isActiveMatchup(round, matchIndex);
    final isCelebrating = _celebrationGameId == gameId && _pickCelebrationCtrl != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Active-matchup pulse glow border ──
        if (isActive)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _listPulseController,
              builder: (ctx, _) {
                final pulse = _listPulseController.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF00E676).withValues(alpha: 0.25 + pulse * 0.35),
                      width: 1.5 + pulse * 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(alpha: 0.08 + pulse * 0.12),
                        blurRadius: 8 + pulse * 8,
                        spreadRadius: pulse * 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        // ── Main voting card ──
        Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: currentPick != null ? BmbColors.blue.withValues(alpha: 0.3) : BmbColors.borderColor,
          width: 0.5,
        ),
      ),
      child: Column(children: [
        // Header — "Matchup X · Voting"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: BmbColors.borderColor.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(Icons.how_to_vote, color: BmbColors.blue, size: 13),
            const SizedBox(width: 5),
            Text('Matchup ${matchIndex + 1}', style: TextStyle(
              color: BmbColors.textTertiary, fontSize: 11,
              fontWeight: BmbFontWeights.semiBold)),
            const Spacer(),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('VOTED', style: TextStyle(
                  color: BmbColors.successGreen, fontSize: 9,
                  fontWeight: BmbFontWeights.bold)),
              ),
            if (currentPick != null && !isCompleted) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4)),
                child: Text('Your Vote', style: TextStyle(
                  color: BmbColors.blue, fontSize: 9,
                  fontWeight: BmbFontWeights.bold)),
              ),
            ],
          ]),
        ),

        // Item A — with vote percentage bar
        _votingItemRow(
          round: round,
          matchIndex: matchIndex,
          team: teams[0],
          isPicked: currentPick == teams[0],
          votePct: pctA,
          isWinner: winner == teams[0] && isCompleted,
          isLoser: winner.isNotEmpty && winner != teams[0] && isCompleted,
        ),

        // Divider with "VS"
        Stack(
          alignment: Alignment.center,
          children: [
            Divider(color: BmbColors.borderColor, height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: BmbColors.deepNavy,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.borderColor, width: 0.5),
              ),
              child: Text('VS', style: TextStyle(
                color: BmbColors.textTertiary, fontSize: 8,
                fontWeight: BmbFontWeights.bold, letterSpacing: 1)),
            ),
          ],
        ),

        // Item B — with vote percentage bar
        _votingItemRow(
          round: round,
          matchIndex: matchIndex,
          team: teams[1],
          isPicked: currentPick == teams[1],
          votePct: pctB,
          isWinner: winner == teams[1] && isCompleted,
          isLoser: winner.isNotEmpty && winner != teams[1] && isCompleted,
        ),

        // Voter count footer (valuable info for bars & restaurants)
        if (matchup != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(Icons.people_outline, color: BmbColors.textTertiary, size: 12),
              const SizedBox(width: 4),
              Text('${matchup.totalVotes} voters', style: TextStyle(
                color: BmbColors.textTertiary, fontSize: 10)),
              const Spacer(),
              if (isCompleted && winner.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.trending_up, color: BmbColors.successGreen, size: 12),
                  const SizedBox(width: 3),
                  Text('${_teamDisplayName(winner)} advances', style: TextStyle(
                    color: BmbColors.successGreen, fontSize: 10,
                    fontWeight: BmbFontWeights.bold)),
                ]),
            ]),
          ),
      ]),
    ),
        // ── Celebration overlay (starburst + team burst + sparkles) ──
        if (isCelebrating)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pickCelebrationCtrl!,
                builder: (ctx, _) {
                  return _buildListCelebration(
                    _pickCelebrationCtrl!.value,
                    _celebrationTeamName ?? '',
                    _celebrationTeamColor,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  /// A single row inside a voting matchup card with a percentage bar.
  Widget _votingItemRow({
    required int round,
    required int matchIndex,
    required String team,
    required bool isPicked,
    required double votePct,
    required bool isWinner,
    required bool isLoser,
  }) {
    final canPick = !_isReadOnly && team != 'TBD';
    final displayName = _teamDisplayName(team);
    final pctLabel = '${votePct.toStringAsFixed(1)}%';

    // Color theming
    final Color barColor;
    final Color textColor;
    if (isWinner) {
      barColor = BmbColors.successGreen;
      textColor = BmbColors.successGreen;
    } else if (isLoser) {
      barColor = BmbColors.errorRed.withValues(alpha: 0.4);
      textColor = BmbColors.textTertiary.withValues(alpha: 0.5);
    } else if (isPicked) {
      barColor = BmbColors.blue;
      textColor = BmbColors.blue;
    } else {
      barColor = BmbColors.textTertiary.withValues(alpha: 0.3);
      textColor = BmbColors.textPrimary;
    }

    return GestureDetector(
      onTap: canPick ? () => _selectPick(round, matchIndex, team) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: isPicked ? BmbColors.blue.withValues(alpha: 0.05) : Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Item name
              Expanded(
                child: Row(children: [
                  if (isWinner) ...[
                    Icon(Icons.emoji_events, color: BmbColors.gold, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: displayName.length > 18 ? 11.0 : (displayName.length > 14 ? 12.0 : 14.0),
                        fontWeight: (isPicked || isWinner) ? BmbFontWeights.bold : FontWeight.normal,
                        decoration: isLoser ? TextDecoration.lineThrough : null,
                        decorationColor: BmbColors.textTertiary.withValues(alpha: 0.3),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: barColor.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Text(pctLabel, style: TextStyle(
                  color: barColor,
                  fontSize: 12,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                )),
              ),
              if (isPicked) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, color: BmbColors.blue, size: 16),
              ],
              if (canPick && !isPicked) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Vote', style: TextStyle(
                    color: BmbColors.blue, fontSize: 9,
                    fontWeight: BmbFontWeights.bold)),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            // Vote percentage bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: votePct / 100.0,
                minHeight: 6,
                backgroundColor: BmbColors.borderColor.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LIST-VIEW CELEBRATION WIDGET ──────────────────────────
  Widget _buildListCelebration(double t, String teamName, Color teamColor) {
    // Phase 1 (0-0.3): starburst flash expands
    // Phase 2 (0.3-0.7): team name scales up
    // Phase 3 (0.7-1.0): everything fades out
    final flashT = (t / 0.35).clamp(0.0, 1.0);
    final nameT = ((t - 0.15) / 0.45).clamp(0.0, 1.0);
    final fadeT = ((t - 0.65) / 0.35).clamp(0.0, 1.0);
    final opacity = 1.0 - fadeT;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cx = constraints.maxWidth / 2;
        final cy = constraints.maxHeight / 2;

        return Stack(
          children: [
            // Starburst rays
            if (flashT > 0)
              Positioned(
                left: cx - 80,
                top: cy - 80,
                width: 160,
                height: 160,
                child: Opacity(
                  opacity: (opacity * (1.0 - flashT * 0.5)).clamp(0.0, 1.0),
                  child: CustomPaint(
                    painter: _ListStarburstPainter(
                      progress: flashT,
                      color: teamColor,
                    ),
                  ),
                ),
              ),
            // Glowing ring
            if (flashT > 0)
              Positioned(
                left: cx - 45 * (0.5 + flashT * 0.5),
                top: cy - 45 * (0.5 + flashT * 0.5),
                width: 90 * (0.5 + flashT * 0.5),
                height: 90 * (0.5 + flashT * 0.5),
                child: Opacity(
                  opacity: (opacity * 0.6).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: teamColor.withValues(alpha: 0.8),
                        width: 3 * (1.0 - flashT * 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: teamColor.withValues(alpha: 0.5),
                          blurRadius: 20 * flashT,
                          spreadRadius: 5 * flashT,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Team name burst
            if (nameT > 0)
              Positioned(
                left: cx - 70,
                top: cy - 14,
                width: 140,
                height: 28,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + nameT * 0.8,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            teamColor.withValues(alpha: 0.9),
                            teamColor.withValues(alpha: 0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: teamColor.withValues(alpha: 0.6 * opacity),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3 * opacity * (1.0 - nameT)),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        teamName.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: teamName.length > 16 ? 9.0 : 12.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: teamName.length > 16 ? 0.8 : 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            // Sparkle particles
            if (flashT > 0.1)
              ..._buildListSparkles(cx, cy, teamName, teamColor, flashT, opacity),
          ],
        );
      },
    );
  }

  List<Widget> _buildListSparkles(
      double cx, double cy, String teamName, Color teamColor, double t, double opacity) {
    final rng = math.Random(teamName.hashCode);
    final sparkles = <Widget>[];
    const count = 12;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + rng.nextDouble() * 0.5;
      final distance = 25 + rng.nextDouble() * 50;
      final dx = math.cos(angle) * distance * t;
      final dy = math.sin(angle) * distance * t;
      final size = 3.0 + rng.nextDouble() * 4;
      final sparkOpacity = (opacity * (1.0 - t * 0.6)).clamp(0.0, 1.0);
      final isGold = i % 3 == 0;

      sparkles.add(Positioned(
        left: cx + dx - size / 2,
        top: cy + dy - size / 2,
        width: size,
        height: size,
        child: Opacity(
          opacity: sparkOpacity,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGold ? const Color(0xFFFFD700) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: (isGold ? const Color(0xFFFFD700) : teamColor)
                      .withValues(alpha: 0.8),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ));
    }
    return sparkles;
  }

  /// Parse seed number from team name like "(5) Duke"
  int? _parseSeed(String team) => BracketTemplate.parseSeed(team);

  /// Get display name without seed prefix: "(5) Duke" -> "Duke"
  String _teamDisplayName(String team) {
    final match = RegExp(r'^\(\d+\)\s*').firstMatch(team);
    if (match != null) return team.substring(match.end);
    return team;
  }

  Widget _teamPickRow(int round, int matchIndex, String team, bool isPicked) {
    final gameId = 'r${round}_g$matchIndex';
    final currentPick = _picks[gameId];
    final canPick = !_isReadOnly && team != 'TBD';
    final seed = _parseSeed(team);
    final displayName = _teamDisplayName(team);
    // The OTHER team was picked — this one is eliminated
    final isEliminated = currentPick != null && currentPick != team && team != 'TBD';

    // Colors based on state
    final Color bgColor;
    final Color badgeColor;
    final Color badgeBorder;
    final Color textColor;
    final Color seedTextColor;

    if (isPicked) {
      bgColor = const Color(0xFF0A2A15).withValues(alpha: 0.3);
      badgeColor = const Color(0xFF00E676);
      badgeBorder = const Color(0xFF00E676);
      textColor = const Color(0xFF00E676);
      seedTextColor = Colors.white;
    } else if (isEliminated) {
      bgColor = const Color(0xFF1A0808).withValues(alpha: 0.2);
      badgeColor = const Color(0xFF3D1515).withValues(alpha: 0.25);
      badgeBorder = const Color(0xFF5C1A1A).withValues(alpha: 0.3);
      textColor = BmbColors.textTertiary.withValues(alpha: 0.3);
      seedTextColor = BmbColors.textTertiary.withValues(alpha: 0.3);
    } else {
      bgColor = Colors.transparent;
      badgeColor = BmbColors.gold.withValues(alpha: 0.2);
      badgeBorder = BmbColors.gold.withValues(alpha: 0.5);
      textColor = team == 'TBD' ? BmbColors.textTertiary : BmbColors.textPrimary;
      seedTextColor = BmbColors.gold;
    }

    return GestureDetector(
      onTap: canPick ? () => _selectPick(round, matchIndex, team) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: bgColor,
        child: Row(children: [
          // Seed badge (replaces generic circle when seed exists)
          if (seed != null)
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isPicked ? badgeColor : badgeColor,
                border: Border.all(color: badgeBorder, width: 1),
              ),
              child: Center(
                child: isPicked
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '$seed',
                        style: TextStyle(
                          color: seedTextColor,
                          fontSize: seed > 9 ? 11 : 13,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay',
                        ),
                      ),
              ),
            )
          else
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPicked ? badgeColor : badgeColor,
                border: Border.all(color: badgeBorder, width: 1),
              ),
              child: Center(
                child: isPicked
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(team.isNotEmpty ? team[0].toUpperCase() : '?',
                        style: TextStyle(color: isEliminated ? textColor : BmbColors.textSecondary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isPicked ? BmbFontWeights.bold : FontWeight.normal,
                decoration: isEliminated ? TextDecoration.lineThrough : null,
                decorationColor: BmbColors.textTertiary.withValues(alpha: 0.3),
              ),
            ),
          ),
          if (isPicked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle, color: const Color(0xFF00E676), size: 12),
                const SizedBox(width: 3),
                Text('YOUR PICK', style: TextStyle(color: const Color(0xFF00E676), fontSize: 9, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
              ]),
            ),
          if (isEliminated)
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5C1A1A).withValues(alpha: 0.4),
              ),
              child: const Icon(Icons.close, color: Color(0xFFFF5252), size: 12),
            )
          else if (canPick && !isPicked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('Pick', style: TextStyle(color: BmbColors.blue, fontSize: 10, fontWeight: BmbFontWeights.bold)),
            ),
        ]),
      ),
    );
  }

  void _openBackIt() {
    // AUTO-SUBMIT: If picks haven't been submitted yet, auto-submit first
    // then proceed to Back It flow. This ensures picks are on the leaderboard.
    if (!_submitted && _allPicksMade) {
      // Auto-fill tie-breaker if empty and needed (default to 0 so submission can proceed)
      if (_needsTieBreaker && !_tieBreakerFilled) {
        _tieBreakerController.text = '0';
      }
      // Submit picks silently (auto-submit)
      final cuBackIt = CurrentUserService.instance;
      ResultsService.submitPicks(UserPicks(
        userId: cuBackIt.userId,
        userName: cuBackIt.displayName.isNotEmpty ? cuBackIt.displayName : 'You',
        userState: cuBackIt.stateAbbr.isNotEmpty ? cuBackIt.stateAbbr : 'US',
        bracketId: widget.bracket.id,
        picks: Map.from(_picks),
        submittedAt: DateTime.now(),
      ));
      setState(() {
        _submitted = true;
        _showScoring = true;
      });
      // Record that user made picks for this bracket (persisted for dashboard state)
      _recordPicksMadeToPrefs(widget.bracket.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Picks auto-submitted! You\'re on the leaderboard. Proceeding to Back It...')),
        ]),
        backgroundColor: BmbColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
    }

    // Build picks map keyed by SVG slot IDs for the print renderer
    final picksMap = <String, String>{};
    for (int r = 0; r < widget.bracket.totalRounds; r++) {
      final matchCount = _rounds.length > r ? _rounds[r].length : 0;
      for (int m = 0; m < matchCount; m++) {
        final gid = 'r${r}_g$m';
        final pick = _picks[gid];
        if (pick != null) {
          final halfSize = matchCount ~/ 2;
          final side = (halfSize > 0 && m >= halfSize) ? 'right' : 'left';
          final sideM = side == 'left' ? m : m - halfSize;
          picksMap['slot_${side}_r${r}_m${sideM}_team1'] = pick;
        }
      }
    }

    // Determine champion: last round, first match pick
    final lastRound = widget.bracket.totalRounds - 1;
    final championGid = 'r${lastRound}_g0';
    final champion = _picks[championGid] ?? 'TBD';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BackItFlowScreen(
          bracketId: widget.bracket.id,
          bracketTitle: widget.bracket.name,
          championName: champion,
          teamCount: widget.bracket.teamCount,
          teams: widget.bracket.teams,
          picks: picksMap,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalPicks = _picks.length;
    final totalNeeded = widget.bracket.totalMatchups;
    final pct = totalNeeded > 0 ? (totalPicks / totalNeeded * 100).toStringAsFixed(0) : '0';

    // Read-only mode: show simplified bottom bar
    if (widget.readOnly) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: BmbColors.deepNavy.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
        ),
        child: Row(children: [
          // BACK TO BOARD button (prominent)
          _BackToBoardButton(onTap: _backToBoard),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _openBackIt,
              icon: const Icon(Icons.checkroom, size: 18),
              label: Text('Back It', style: TextStyle(
                fontSize: 13, fontWeight: BmbFontWeights.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => widget.bracket.isVoting
                  ? VotingLeaderboardScreen(bracket: widget.bracket)
                  : LeaderboardScreen(bracket: widget.bracket))),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.leaderboard, color: BmbColors.blue, size: 18),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Progress row
        Row(children: [
          Expanded(
            child: Text(
              _submitted
                  ? (_isVotingBracket ? 'Votes submitted!' : 'Picks submitted!')
                  : (_isVotingBracket
                      ? '$totalPicks/$totalNeeded votes ($pct%)'
                      : '$totalPicks/$totalNeeded picks ($pct%)'),
              style: TextStyle(
                color: _submitted ? BmbColors.successGreen : BmbColors.textSecondary,
                fontSize: 11, fontWeight: BmbFontWeights.medium),
            ),
          ),
          if (!_submitted && _needsTieBreaker && !_tieBreakerFilled)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sports_score, color: BmbColors.gold, size: 12),
              const SizedBox(width: 3),
              Text('Tie-breaker needed', style: TextStyle(
                color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold)),
            ]),
          if (!_submitted && _isVotingBracket)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.how_to_vote, color: BmbColors.blue, size: 12),
              const SizedBox(width: 3),
              Text('Voting Bracket', style: TextStyle(
                color: BmbColors.blue, fontSize: 9, fontWeight: BmbFontWeights.bold)),
            ]),
        ]),
        const SizedBox(height: 8),
        // Action buttons row
        if (_submitted)
          Row(children: [
            // BACK TO BOARD button (prominent)
            _BackToBoardButton(onTap: _backToBoard),
            const SizedBox(width: 6),
            // BACK IT button (primary CTA after submission)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openBackIt,
                icon: const Icon(Icons.checkroom, size: 18),
                label: Text('Back It', style: TextStyle(
                  fontSize: 13, fontWeight: BmbFontWeights.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Post to BMB — with illumination glow when HypeMan says to share
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (ctx, child) {
                final glow = _illuminateShareButtons;
                return Container(
                  decoration: glow ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: BmbColors.blue.withValues(alpha: _glowAnimation.value * 0.7),
                        blurRadius: 16, spreadRadius: 2,
                      ),
                    ],
                  ) : null,
                  child: _PostToBmbButton(
                    onTap: () {
                      setState(() => _illuminateShareButtons = false);
                      PostToBmbSheet.show(
                        context,
                        bracket: widget.bracket,
                        picks: _picks,
                        userName: 'You',
                        tieBreakerPrediction: int.tryParse(_tieBreakerController.text.trim()),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            // Post to Socials — with illumination glow
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (ctx, child) {
                final glow = _illuminateShareButtons;
                return GestureDetector(
                  onTap: () {
                    setState(() => _illuminateShareButtons = false);
                    final champPick = _picks['r${widget.bracket.totalRounds - 1}_g0'];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BracketTreeViewerScreen(
                          userName: 'You',
                          bracketName: widget.bracket.name,
                          sport: widget.bracket.sport,
                          teams: widget.bracket.teams,
                          picks: _picks,
                          totalRounds: widget.bracket.totalRounds,
                          championPick: champPick,
                          tieBreakerPrediction: int.tryParse(_tieBreakerController.text.trim()),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: glow ? [
                        BoxShadow(
                          color: const Color(0xFFEC4899).withValues(alpha: _glowAnimation.value * 0.7),
                          blurRadius: 16, spreadRadius: 2,
                        ),
                      ] : null,
                    ),
                    child: const Icon(Icons.share, color: Colors.white, size: 18),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            // Leaderboard
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => widget.bracket.isVoting
                    ? VotingLeaderboardScreen(bracket: widget.bracket)
                    : LeaderboardScreen(bracket: widget.bracket))),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.leaderboard, color: BmbColors.blue, size: 18),
              ),
            ),
          ])
        else
          Row(children: [
            // BACK IT button (available before submission too)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _allPicksMade ? _openBackIt : null,
                icon: const Icon(Icons.checkroom, size: 16),
                label: Text('Back It', style: TextStyle(
                  fontSize: 12, fontWeight: BmbFontWeights.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: BmbColors.cardDark,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Submit Picks
            Expanded(
              child: ElevatedButton(
                onPressed: _canSubmit ? _submitPicks : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSubmit ? BmbColors.successGreen : BmbColors.borderColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_isVotingBracket ? 'Submit Vote' : 'Submit Picks', style: TextStyle(
                  fontSize: 13, fontWeight: BmbFontWeights.bold)),
              ),
            ),
          ]),
      ]),
    );
  }

  // ═══ FUN FACT OVERLAY WIDGET (Option C) ══════════════════════════════
  Widget _buildFunFactOverlay() {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showFunFact ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        child: GestureDetector(
          onTap: () => setState(() => _showFunFact = false),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: BmbColors.gold.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lightbulb, color: BmbColors.gold, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BMB Intel', style: TextStyle(
                        color: BmbColors.gold, fontSize: 10,
                        fontWeight: BmbFontWeights.bold,
                        letterSpacing: 1.0,
                      )),
                      const SizedBox(height: 4),
                      Text(
                        _currentFunFact ?? '',
                        style: TextStyle(
                          color: Colors.white, fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showFunFact = false),
                  child: Icon(Icons.close, color: Colors.white54, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate back to the bracket board (dashboard).
  void _backToBoard() {
    // Pop all screens until we're back at the dashboard/board.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

/// Compact "Post to BMB" icon button for the bottom bar.
class _PostToBmbButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PostToBmbButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: BmbColors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.forum, color: BmbColors.blue, size: 18),
          const SizedBox(width: 4),
          Text('Post to BMB', style: TextStyle(
            color: BmbColors.blue, fontSize: 10,
            fontWeight: BmbFontWeights.bold,
          )),
        ]),
      ),
    );
  }
}

/// Prominent "Back to Board" button for returning to the bracket board.
class _BackToBoardButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackToBoardButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BmbColors.blue.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.dashboard, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text('Board', style: TextStyle(
            color: Colors.white, fontSize: 11,
            fontWeight: BmbFontWeights.bold,
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LIST-VIEW STARBURST PAINTER (mirrors tree-widget _StarburstPainter)
// ═══════════════════════════════════════════════════════════════

class _ListStarburstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ListStarburstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Radiating lines
    const rayCount = 16;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * math.pi * 2;
      final innerR = maxRadius * 0.15;
      final outerR = maxRadius * (0.3 + progress * 0.7);
      final startPoint = Offset(
        center.dx + math.cos(angle) * innerR,
        center.dy + math.sin(angle) * innerR,
      );
      final endPoint = Offset(
        center.dx + math.cos(angle) * outerR,
        center.dy + math.sin(angle) * outerR,
      );

      final paint = Paint()
        ..color = (i % 2 == 0 ? color : const Color(0xFFFFD700))
            .withValues(alpha: (0.6 - progress * 0.4).clamp(0.0, 1.0))
        ..strokeWidth = 2.5 * (1.0 - progress * 0.5)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(startPoint, endPoint, paint);
    }

    // Center flash
    if (progress < 0.5) {
      final flashR = maxRadius * 0.3 * (1.0 - progress * 2);
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: (0.8 - progress * 1.6).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, flashR, flashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ListStarburstPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
