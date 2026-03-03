import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/bracket_template.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/features/scoring/data/services/live_data_feed_service.dart';
import 'package:bmb_mobile/features/scoring/data/services/official_results_registry.dart';
import 'package:bmb_mobile/features/scoring/data/services/scoring_engine.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';
import 'package:bmb_mobile/features/scoring/data/services/tournament_status_service.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/voting_leaderboard_screen.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/player_picks_viewer_screen.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/giveaway/data/services/giveaway_service.dart';
import 'package:bmb_mobile/features/giveaway/presentation/widgets/leaderboard_spinner_overlay.dart';

class LeaderboardScreen extends StatefulWidget {
  final CreatedBracket bracket;
  const LeaderboardScreen({super.key, required this.bracket});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late BracketResults _results;
  late List<ScoredEntry> _leaderboard;
  bool _isRefreshing = false;
  SyncResult? _lastSyncResult;

  // Giveaway state
  bool _showSpinner = false;
  bool _giveawayCompleted = false;
  GiveawayResult? _giveawayResult;

  // Auto-spinner state (auto-host mode)
  bool _autoSpinnerPending = false;
  int _autoSpinnerCountdown = 5; // seconds of countdown before auto-launch
  Timer? _autoSpinnerTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkGiveawayStatus();

    // Listen for registry updates (template brackets auto-update)
    if (ResultsService.isAutoSynced(widget.bracket)) {
      OfficialResultsRegistry.instance.addListener(_onRegistryUpdate);
    }
  }

  @override
  void dispose() {
    _autoSpinnerTimer?.cancel();
    OfficialResultsRegistry.instance.removeListener(_onRegistryUpdate);
    super.dispose();
  }

  /// Called when OfficialResultsRegistry pushes an update.
  /// All host leaderboards using the same template refresh automatically.
  void _onRegistryUpdate() {
    if (mounted) {
      setState(() => _loadData());
    }
  }

  void _loadData() {
    _results = ResultsService.getResults(widget.bracket);
    final allPicks = ResultsService.getAllPicks(widget.bracket);
    _leaderboard = ScoringEngine.buildLeaderboard(
      allPicks: allPicks,
      results: _results,
      totalRounds: widget.bracket.totalRounds,
      currentUserId: CurrentUserService.instance.userId,
    );
  }

  Future<void> _checkGiveawayStatus() async {
    final done = await GiveawayService.hasGiveawayBeenPerformed(widget.bracket.id);
    if (done) {
      final result = await GiveawayService.getResultForBracket(widget.bracket.id);
      if (mounted) {
        setState(() {
          _giveawayCompleted = true;
          _giveawayResult = result;
        });
      }
    } else {
      // Check if auto-spinner should trigger
      _checkAutoSpinner();
    }
  }

  /// Auto-spinner: when auto-host is ON, the giveaway is enabled, and 15+
  /// minutes have passed since the bracket reached "done", automatically
  /// start a countdown and launch the spinner wheel.
  void _checkAutoSpinner() {
    final b = widget.bracket;
    if (!b.autoHost) return;
    if (!b.hasGiveaway) return;
    if (b.giveawayWinnerCount <= 0) return;
    if (!_isHost) return;

    // Check completedAt timestamp
    final completedAt = b.completedAt;
    if (completedAt == null) return;

    final minutesSinceComplete = DateTime.now().difference(completedAt).inMinutes;
    if (minutesSinceComplete < 15) return;

    // All conditions met — start the auto-spinner countdown
    if (mounted && !_autoSpinnerPending) {
      setState(() {
        _autoSpinnerPending = true;
        _autoSpinnerCountdown = 5;
      });
      _autoSpinnerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _autoSpinnerCountdown--;
        });
        if (_autoSpinnerCountdown <= 0) {
          timer.cancel();
          setState(() {
            _autoSpinnerPending = false;
            _showSpinner = true;
          });
        }
      });
    }
  }

  bool get _isGiveawayEligible =>
      widget.bracket.hasGiveaway &&
      _results.isTournamentComplete &&
      !_giveawayCompleted &&
      widget.bracket.giveawayWinnerCount > 0;

  bool get _isHost =>
      widget.bracket.hostId == CurrentUserService.instance.userId ||
      widget.bracket.hostId == 'u1' ||
      widget.bracket.hostId == 'user_0';

  /// Get the live data source name for display
  String get _dataSourceName {
    final template = BracketTemplate.allTemplates
        .where((t) => t.id == widget.bracket.templateId)
        .firstOrNull;
    return LiveDataFeedService.getDataSourceName(template?.dataFeedId);
  }

  bool get _hasLiveFeed {
    final template = BracketTemplate.allTemplates
        .where((t) => t.id == widget.bracket.templateId)
        .firstOrNull;
    return LiveDataFeedService.isLiveDataAvailable(template?.dataFeedId);
  }

  /// Refresh from the live data feed via the OfficialResultsRegistry.
  Future<void> _refreshResults() async {
    setState(() => _isRefreshing = true);

    if (ResultsService.isAutoSynced(widget.bracket)) {
      // Sync through the registry (one sync updates ALL host brackets)
      final syncResult =
          await ResultsService.syncTemplateLive(widget.bracket);
      _lastSyncResult = syncResult;

      // Check if bracket status should auto-advance
      await TournamentStatusService.onLiveFeedUpdate(widget.bracket);
    }

    setState(() {
      _loadData();
      _isRefreshing = false;
    });
  }

  /// Format a DateTime to a human-readable "time ago" string
  String _timeAgo(DateTime? time) {
    if (time == null) return 'never';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    // Voting brackets have a completely different leaderboard: items ranked
    // by vote popularity instead of players ranked by score.
    if (widget.bracket.isVoting) {
      // Replace this screen with the voting-specific leaderboard.
      // We use a post-frame callback to avoid building during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VotingLeaderboardScreen(bracket: widget.bracket),
            ),
          );
        }
      });
      // Show a brief loading state while the replacement navigates
      return Scaffold(
        body: Container(
          decoration:
              const BoxDecoration(gradient: BmbColors.backgroundGradient),
          child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF9C27B0))),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Main leaderboard content
          Container(
            decoration:
                const BoxDecoration(gradient: BmbColors.backgroundGradient),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  if (_isRefreshing)
                    LinearProgressIndicator(
                        color: BmbColors.gold,
                        backgroundColor: BmbColors.borderColor,
                        minHeight: 2),
                  if (ResultsService.isAutoSynced(widget.bracket))
                    _buildSyncStatusBar(),
                  _buildTournamentInfo(),
                  // Auto-spinner countdown banner
                  if (_autoSpinnerPending)
                    _buildAutoSpinnerCountdown(),
                  // Giveaway button or completed badge
                  if (_isGiveawayEligible && _isHost && !_autoSpinnerPending)
                    _buildGiveawayButton()
                  else if (_giveawayCompleted && _giveawayResult != null)
                    _buildGiveawayCompletedBadge(),
                  _buildScoringLegend(),
                  Expanded(
                    child: RefreshIndicator(
                      color: BmbColors.gold,
                      backgroundColor: BmbColors.midNavy,
                      onRefresh: _refreshResults,
                      child: _buildLeaderboardList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Spinner overlay (covers entire screen when active)
          if (_showSpinner)
            LeaderboardSpinnerOverlay(
              participantNames: _leaderboard.map((e) => e.userName).toList(),
              participantIds: _leaderboard.map((e) => e.userId).toList(),
              winnerCount: widget.bracket.giveawayWinnerCount,
              tokensPerWinner: widget.bracket.giveawayTokensPerWinner,
              bracketId: widget.bracket.id,
              bracketName: widget.bracket.name,
              sport: widget.bracket.sport,
              leaderboardLeaderId: _leaderboard.isNotEmpty ? _leaderboard.first.userId : null,
              leaderboardLeaderName: _leaderboard.isNotEmpty ? _leaderboard.first.userName : null,
              onResult: (result) {
                setState(() {
                  _giveawayResult = result;
                  _giveawayCompleted = true;
                });
              },
              onComplete: () {
                setState(() => _showSpinner = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leaderboard',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Text(widget.bracket.name,
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (ResultsService.isAutoSynced(widget.bracket))
            _buildAutoSyncBadge()
          else
            _buildManualBadge(),
        ],
      ),
    );
  }

  Widget _buildAutoSyncBadge() {
    final feedResult =
        ResultsService.getLastLiveFeedResult(widget.bracket);
    final provider = ResultsService.currentProvider;
    final sourceName = feedResult?.source ?? _dataSourceName;
    final isLive = feedResult?.success == true;
    final liveCount = feedResult?.liveGames ?? 0;

    return GestureDetector(
      onTap: _refreshResults,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isLive ? BmbColors.successGreen : BmbColors.blue)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: (isLive ? BmbColors.successGreen : BmbColors.blue)
                  .withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  _hasLiveFeed ? Icons.cell_tower : Icons.sync,
                  color: isLive
                      ? BmbColors.successGreen
                      : BmbColors.blue,
                  size: 14),
              const SizedBox(width: 4),
              Text(
                  _hasLiveFeed ? 'LIVE Feed' : 'Auto-Sync',
                  style: TextStyle(
                      color: isLive
                          ? BmbColors.successGreen
                          : BmbColors.blue,
                      fontSize: 10,
                      fontWeight: BmbFontWeights.bold)),
            ]),
            if (_hasLiveFeed)
              Text(
                liveCount > 0
                    ? '$sourceName ($liveCount live)'
                    : sourceName,
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 8),
              ),
            // Show data provider tier
            if (provider.isPaid)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  provider.displayName,
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 7,
                      fontWeight: BmbFontWeights.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Compact sync status bar showing last sync time, data source, and result
  Widget _buildSyncStatusBar() {
    final lastSync = ResultsService.getLastSyncTime(widget.bracket);
    final feedResult =
        ResultsService.getLastLiveFeedResult(widget.bracket);
    final provider = ResultsService.currentProvider;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BmbColors.borderColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: BmbColors.borderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Source icon
          Icon(Icons.cloud_sync,
              color: BmbColors.textTertiary, size: 14),
          const SizedBox(width: 6),
          // Source info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Source: ${feedResult?.source ?? provider.displayName}',
                      style: TextStyle(
                          color: BmbColors.textSecondary,
                          fontSize: 10,
                          fontWeight: BmbFontWeights.semiBold),
                    ),
                    if (_lastSyncResult?.gamesUpdated != null &&
                        _lastSyncResult!.gamesUpdated > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color:
                              BmbColors.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '+${_lastSyncResult!.gamesUpdated} updated',
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 8,
                              fontWeight: BmbFontWeights.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Last sync: ${_timeAgo(lastSync ?? feedResult?.lastFetched)}'
                  '${feedResult != null ? " | ${feedResult.completedGames} done, ${feedResult.liveGames} live, ${feedResult.upcomingGames} upcoming" : ""}',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 9),
                ),
              ],
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: _isRefreshing ? null : _refreshResults,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh,
                  color: BmbColors.blue, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BmbColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit, color: BmbColors.gold, size: 14),
          const SizedBox(width: 4),
          Text('Host Updated',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 10,
                  fontWeight: BmbFontWeights.bold)),
        ],
      ),
    );
  }

  Widget _buildTournamentInfo() {
    final pct = (_results.completionPercent * 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildInfoChip(Icons.sports, widget.bracket.sport),
              const SizedBox(width: 8),
              _buildInfoChip(
                  Icons.people, '${_leaderboard.length} participants'),
              const SizedBox(width: 8),
              _buildInfoChip(
                  Icons.emoji_events, widget.bracket.prizeLabel),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tournament Progress',
                            style: TextStyle(
                                color: BmbColors.textSecondary,
                                fontSize: 11)),
                        Text('$pct%',
                            style: TextStyle(
                                color: BmbColors.gold,
                                fontSize: 11,
                                fontWeight: BmbFontWeights.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _results.completionPercent,
                        minHeight: 6,
                        backgroundColor: BmbColors.borderColor,
                        valueColor: AlwaysStoppedAnimation(
                            _results.isTournamentComplete
                                ? BmbColors.gold
                                : BmbColors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('${_results.completedGames}/${_results.totalGames}',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 11)),
            ],
          ),
          if (_results.isTournamentComplete) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events,
                      color: BmbColors.gold, size: 16),
                  const SizedBox(width: 6),
                  Text('Tournament Complete - Final Standings',
                      style: TextStyle(
                          color: BmbColors.gold,
                          fontSize: 12,
                          fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: BmbColors.borderColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: BmbColors.textTertiary, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoringLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Text('Scoring: ',
              style: TextStyle(
                  color: BmbColors.textTertiary,
                  fontSize: 10,
                  fontWeight: BmbFontWeights.semiBold)),
          ...List.generate(
            widget.bracket.totalRounds > 6
                ? 6
                : widget.bracket.totalRounds,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: BmbColors.borderColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'R${i + 1}: ${ScoringEngine.pointsForRound(i)}pt',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 9),
                ),
              ),
            ),
          ),
          if (widget.bracket.totalRounds > 6)
            Text('...',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAutoSpinnerCountdown() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.2),
          BmbColors.gold.withValues(alpha: 0.08),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: BmbColors.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-Host Giveaway',
                        style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                    const SizedBox(height: 2),
                    Text('Giveaway spinner launching automatically...',
                        style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              // Countdown circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  border: Border.all(color: BmbColors.gold, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$_autoSpinnerCountdown',
                    style: TextStyle(color: BmbColors.gold, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'The spinner will start in $_autoSpinnerCountdown second${_autoSpinnerCountdown != 1 ? 's' : ''}. Tap "Skip" to launch now.',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _autoSpinnerTimer?.cancel();
                  setState(() {
                    _autoSpinnerPending = false;
                    _showSpinner = true;
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: BmbColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Skip', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGiveawayButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _showSpinner = true),
          icon: const Icon(Icons.celebration, size: 22),
          label: Text(
            'Giveaway Drawing (${widget.bracket.giveawayWinnerCount} winner${widget.bracket.giveawayWinnerCount > 1 ? 's' : ''} \u00d7 ${widget.bracket.giveawayTokensPerWinner}c)',
            style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: BmbColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 4,
            shadowColor: BmbColors.gold.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildGiveawayCompletedBadge() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.12),
          BmbColors.gold.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.celebration, color: BmbColors.gold, size: 18),
              const SizedBox(width: 8),
              Text('Giveaway Complete', style: TextStyle(color: BmbColors.gold, fontSize: 13, fontWeight: BmbFontWeights.bold)),
              const Spacer(),
              Text('${_giveawayResult!.totalCreditsAwarded}c awarded', style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _giveawayResult!.winners.asMap().entries.map((entry) {
              final idx = entry.key;
              final w = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${GiveawayService.ordinal(idx + 1)}: ', style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                  Text(w.userName, style: TextStyle(color: BmbColors.textPrimary, fontSize: 11, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(width: 4),
                  Text('+${w.creditsAwarded}c', style: TextStyle(color: BmbColors.successGreen, fontSize: 10)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: _leaderboard.length,
      itemBuilder: (ctx, idx) {
        final entry = _leaderboard[idx];
        return _buildLeaderboardRow(entry, idx);
      },
    );
  }

  Widget _buildLeaderboardRow(ScoredEntry entry, int index) {
    final isTop3 = entry.rank <= 3;
    final isCurrentUser = entry.isCurrentUser;

    Color? rankColor;
    IconData? trophy;
    if (entry.rank == 1) {
      rankColor = const Color(0xFFFFD700);
      trophy = Icons.emoji_events;
    } else if (entry.rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      trophy = Icons.emoji_events;
    } else if (entry.rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      trophy = Icons.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: isCurrentUser
            ? LinearGradient(colors: [
                BmbColors.blue.withValues(alpha: 0.15),
                BmbColors.blue.withValues(alpha: 0.05),
              ])
            : isTop3
                ? LinearGradient(colors: [
                    rankColor!.withValues(alpha: 0.08),
                    rankColor.withValues(alpha: 0.02),
                  ])
                : BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? BmbColors.blue.withValues(alpha: 0.4)
              : isTop3
                  ? rankColor!.withValues(alpha: 0.3)
                  : BmbColors.borderColor.withValues(alpha: 0.3),
          width: isCurrentUser ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: isTop3
                  ? Icon(trophy, color: rankColor, size: 24)
                  : Text('#${entry.rank}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: BmbColors.textTertiary,
                          fontSize: 14,
                          fontWeight: BmbFontWeights.bold)),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? BmbColors.blue.withValues(alpha: 0.3)
                    : BmbColors.borderColor.withValues(alpha: 0.4),
                border: isCurrentUser
                    ? Border.all(color: BmbColors.blue, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  entry.userName.isNotEmpty
                      ? entry.userName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: isCurrentUser
                          ? BmbColors.blue
                          : BmbColors.textSecondary,
                      fontSize: 15,
                      fontWeight: BmbFontWeights.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.userName,
                          style: TextStyle(
                            color: isCurrentUser
                                ? BmbColors.blue
                                : BmbColors.textPrimary,
                            fontSize: 13,
                            fontWeight: BmbFontWeights.semiBold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                BmbColors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('YOU',
                              style: TextStyle(
                                  color: BmbColors.blue,
                                  fontSize: 8,
                                  fontWeight: BmbFontWeights.bold,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                      if (entry.userState != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: BmbColors.borderColor
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(entry.userState!,
                              style: TextStyle(
                                  color: BmbColors.textTertiary,
                                  fontSize: 9,
                                  fontWeight: BmbFontWeights.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _buildPickStat(Icons.check_circle,
                          BmbColors.successGreen, '${entry.correctPicks}'),
                      const SizedBox(width: 6),
                      _buildPickStat(Icons.cancel, BmbColors.errorRed,
                          '${entry.incorrectPicks}'),
                      const SizedBox(width: 6),
                      _buildPickStat(Icons.pending,
                          BmbColors.textTertiary, '${entry.pendingPicks}'),
                      if (entry.tieBreakerPrediction != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                BmbColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: BmbColors.gold
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sports_score,
                                    color: BmbColors.gold, size: 10),
                                const SizedBox(width: 2),
                                Text(
                                    'TB: ${entry.tieBreakerPrediction}',
                                    style: TextStyle(
                                        color: BmbColors.gold,
                                        fontSize: 8,
                                        fontWeight:
                                            BmbFontWeights.bold)),
                                if (entry.tieBreakerDiff != null) ...[
                                  const SizedBox(width: 2),
                                  Text(
                                    entry.tieBreakerWentOver == true
                                        ? '(+${entry.tieBreakerDiff})'
                                        : '(-${entry.tieBreakerDiff})',
                                    style: TextStyle(
                                      color: entry.tieBreakerWentOver ==
                                              true
                                          ? BmbColors.errorRed
                                          : BmbColors.successGreen,
                                      fontSize: 7,
                                    ),
                                  ),
                                ],
                              ]),
                        ),
                      ],
                      if (entry.championPick != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.emoji_events,
                            color: entry.isChampionAlive(_results)
                                ? BmbColors.gold
                                : BmbColors.errorRed
                                    .withValues(alpha: 0.5),
                            size: 12),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            entry.championPick!,
                            style: TextStyle(
                              color: entry.isChampionAlive(_results)
                                  ? BmbColors.gold
                                  : BmbColors.textTertiary,
                              fontSize: 9,
                              fontWeight: BmbFontWeights.medium,
                              decoration:
                                  entry.isChampionAlive(_results)
                                      ? null
                                      : TextDecoration.lineThrough,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${entry.score}',
                    style: TextStyle(
                        color: isTop3
                            ? (rankColor ?? BmbColors.gold)
                            : BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Text('${entry.accuracy.toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 10)),
              ],
            ),
            // View Picks button
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _viewPlayerPicks(entry),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BmbColors.blue.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.visibility, color: BmbColors.blue, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewPlayerPicks(ScoredEntry entry) {
    // Find the UserPicks for this entry
    final allPicks = ResultsService.getAllPicks(widget.bracket);
    final userPicks = allPicks.where((p) => p.userId == entry.userId).firstOrNull;
    if (userPicks == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No picks data available for this player.'),
        backgroundColor: BmbColors.midNavy,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPicksViewerScreen(
          bracket: widget.bracket,
          userPicks: userPicks,
          scoredEntry: entry,
        ),
      ),
    );
  }

  Widget _buildPickStat(IconData icon, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 2),
        Text(value,
            style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}
