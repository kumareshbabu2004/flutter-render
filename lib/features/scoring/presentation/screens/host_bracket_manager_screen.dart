import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/bracket_template.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/features/scoring/data/services/official_results_registry.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';
import 'package:bmb_mobile/features/scoring/data/services/tournament_status_service.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/leaderboard_screen.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/voting_leaderboard_screen.dart';
import 'package:bmb_mobile/features/giveaway/data/services/giveaway_service.dart';
import 'package:bmb_mobile/features/giveaway/presentation/screens/giveaway_spinner_screen.dart';
import 'package:bmb_mobile/features/charity/data/services/charity_service.dart';
import 'package:bmb_mobile/features/charity/data/services/charity_escrow_service.dart';
import 'package:bmb_mobile/features/bracket_builder/data/services/speech_input_service.dart';

/// Host Bracket Manager — two distinct modes:
///
/// **TEMPLATE MODE** (March Madness, Women's NCAA, NIT, NFL, etc.)
///   BMB pulls results from the best live data source (ESPN / NCAA / paid).
///   Host CANNOT edit results — they see a live-updating read-only view.
///   "BackMyBracket handles this for you."
///
/// **CUSTOM MODE** (neighborhood tournament, local league, etc.)
///   Host MUST manually enter every result — tap a team to select winner,
///   enter optional score, undo mistakes, advance the bracket.
///   "Only you know the results — update them here."
class HostBracketManagerScreen extends StatefulWidget {
  final CreatedBracket bracket;
  const HostBracketManagerScreen({super.key, required this.bracket});
  @override
  State<HostBracketManagerScreen> createState() =>
      _HostBracketManagerScreenState();
}

class _HostBracketManagerScreenState extends State<HostBracketManagerScreen> {
  late BracketResults _results;
  late CreatedBracket _bracket; // mutable copy so host can override status
  int _currentRound = 0;
  bool _isSyncing = false;
  bool _prizeAwarded = false;
  bool _giveawayCompleted = false;
  GiveawayResult? _giveawayResult;
  SyncResult? _lastSyncResult;

  // Auto-spinner state (auto-host mode)
  bool _autoSpinnerPending = false;
  int _autoSpinnerCountdown = 5;
  Timer? _autoSpinnerTimer;

  /// TRUE when the host chose a BMB template (auto-synced from live data).
  /// FALSE when the host built a custom bracket (manual results only).
  bool get _isTemplate => ResultsService.isAutoSynced(_bracket);

  @override
  void initState() {
    super.initState();
    _bracket = widget.bracket; // mutable copy from widget
    _results = ResultsService.getResults(_bracket);
    _checkGiveawayStatus();

    // Template brackets: listen for live feed updates from the registry
    if (_isTemplate) {
      OfficialResultsRegistry.instance.addListener(_onRegistryUpdate);
    }
  }

  @override
  void dispose() {
    _autoSpinnerTimer?.cancel();
    if (_isTemplate) {
      OfficialResultsRegistry.instance.removeListener(_onRegistryUpdate);
    }
    super.dispose();
  }

  /// Registry pushed an update — refresh results for ALL host brackets
  void _onRegistryUpdate() {
    if (mounted) {
      setState(() {
        _results = ResultsService.getResults(_bracket);
      });
    }
  }

  /// Champion from completed results
  String? get _champion {
    if (!_results.isTournamentComplete) return null;
    final finalRound = _bracket.totalRounds - 1;
    final finalGames = _results.games.values
        .where((g) => g.round == finalRound && g.isCompleted)
        .toList();
    if (finalGames.isNotEmpty) return finalGames.first.winner;
    return null;
  }

  // ═══════════════════════════════════════════════════════════════
  //  TEMPLATE MODE: Live Feed Sync
  // ═══════════════════════════════════════════════════════════════

  /// Pull latest results from the live data feed via OfficialResultsRegistry.
  /// One sync updates ALL host brackets using this template.
  Future<void> _triggerLiveSync() async {
    setState(() => _isSyncing = true);

    final syncResult = await ResultsService.syncTemplateLive(_bracket);

    // Auto-advance tournament status if needed
    await TournamentStatusService.onLiveFeedUpdate(_bracket);

    setState(() {
      _results = ResultsService.getResults(_bracket);
      _lastSyncResult = syncResult;
      _isSyncing = false;
    });

    if (mounted) {
      final msg = syncResult.gamesUpdated > 0
          ? '${syncResult.gamesUpdated} game(s) updated from ${syncResult.source ?? "live feed"}!'
          : syncResult.success
              ? 'Already up to date (${_results.completedGames}/${_results.totalGames} complete).'
              : 'Could not reach live feed. Try again later.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            syncResult.gamesUpdated > 0 ? Icons.check_circle : Icons.info,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: syncResult.gamesUpdated > 0
            ? BmbColors.successGreen
            : BmbColors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  CUSTOM MODE: Manual Winner Selection
  // ═══════════════════════════════════════════════════════════════

  /// Host taps a team to select the winner (custom brackets only).
  void _selectWinner(GameResult game, String winner) {
    final scoreController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: BmbColors.midNavy,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Confirm Winner',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 16,
                  fontWeight: BmbFontWeights.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Game ${game.matchIndex + 1} - ${_roundName(game.round)}',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 12)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          BmbColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.emoji_events,
                      color: BmbColors.successGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(winner,
                        style: TextStyle(
                            color: BmbColors.successGreen,
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scoreController,
                style:
                    TextStyle(color: BmbColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Score (optional, e.g. 75-68)',
                  hintStyle: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: BmbColors.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: BmbColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: BmbColors.borderColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: BmbColors.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final updated = ResultsService.setGameResult(
                  bracket: _bracket,
                  gameId: game.gameId,
                  winner: winner,
                  score: scoreController.text.isNotEmpty
                      ? scoreController.text
                      : null,
                );
                setState(() => _results = updated);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$winner advances! Scores updated.'),
                  backgroundColor: BmbColors.successGreen,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.successGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Confirm Winner',
                  style: TextStyle(fontWeight: BmbFontWeights.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Host undo a game result (custom brackets only)
  void _undoResult(GameResult game) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: BmbColors.midNavy,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Undo Result?',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontWeight: BmbFontWeights.bold,
                  fontSize: 16)),
          content: Text(
              'This will remove the winner for ${game.team1} vs ${game.team2} and clear all downstream results.',
              style:
                  TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: BmbColors.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final updated = ResultsService.undoGameResult(
                  bracket: _bracket,
                  gameId: game.gameId,
                );
                setState(() => _results = updated);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Undo',
                  style: TextStyle(fontWeight: BmbFontWeights.bold)),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PRIZE AWARD (both modes)
  // ═══════════════════════════════════════════════════════════════

  void _showConfirmWinnerAndAwardPrize() {
    final champion = _champion;
    if (champion == null) return;
    final bracket = _bracket;
    final isCharity = bracket.prizeType == 'charity';

    // Charity: use pot credits
    final potCredits = bracket.charityPotCredits;
    final bmbFee = CharityService.calculateBmbFee(potCredits, feePercent: bracket.bmbFeePercent);
    final netDonation = potCredits - bmbFee;
    final netDollars = CharityService.creditsToDollars(netDonation);

    // Standard: use entry donation
    final hasPrizeCredits = !isCharity && !bracket.isFreeEntry && bracket.entryDonation > 0;
    final prizeCredits = hasPrizeCredits ? bracket.entryDonation : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: isCharity
                      ? [BmbColors.successGreen, const Color(0xFF66BB6A)]
                      : [BmbColors.gold, BmbColors.goldLight]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: (isCharity ? BmbColors.successGreen : BmbColors.gold).withValues(alpha: 0.3),
                      blurRadius: 16)],
                ),
                child: Icon(isCharity ? Icons.volunteer_activism : Icons.emoji_events,
                    color: isCharity ? Colors.white : Colors.black, size: 34),
              ),
              const SizedBox(height: 16),
              Text(isCharity ? 'Confirm Winner & Donate' : 'Confirm Champion',
                  style: TextStyle(color: BmbColors.textPrimary, fontSize: 18,
                      fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const SizedBox(height: 12),
              // Winner card
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  Icon(isCharity ? Icons.volunteer_activism : Icons.military_tech,
                      color: isCharity ? BmbColors.successGreen : BmbColors.gold, size: 28),
                  const SizedBox(height: 6),
                  Text(champion, style: TextStyle(color: BmbColors.successGreen, fontSize: 16, fontWeight: BmbFontWeights.bold)),
                  Text(isCharity ? 'Will choose the charity' : 'Tournament Champion',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 14),
              // CHARITY: pot breakdown
              if (isCharity) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Total Pot', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                      Text('$potCredits credits (\$${CharityService.creditsToDollars(potCredits).toStringAsFixed(2)})',
                          style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                    ]),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('BMB Fee (${bracket.bmbFeePercent.toStringAsFixed(0)}%)', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                      Text('-$bmbFee credits', style: TextStyle(color: BmbColors.errorRed, fontSize: 12)),
                    ]),
                    const Divider(color: BmbColors.borderColor, height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Donation', style: TextStyle(color: BmbColors.successGreen, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                      Text('\$${netDollars.toStringAsFixed(2)} ($netDonation credits)',
                          style: TextStyle(color: BmbColors.successGreen, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Credits do NOT go to the winner. They select a charity and the donation is sent via Tremendous.',
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, height: 1.3, fontStyle: FontStyle.italic)),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              // STANDARD: credit award info
              if (hasPrizeCredits && !isCharity) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Reward Credits', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                      Text('$prizeCredits credits',
                          style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                    ]),
                    const SizedBox(height: 6),
                    Text("Reward credits will be awarded to the winner's BMB Bucket upon confirmation.",
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, height: 1.3)),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              // Warning
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BmbColors.errorRed.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber, color: BmbColors.errorRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('This action is final and cannot be undone.',
                      style: TextStyle(color: BmbColors.errorRed, fontSize: 10))),
                ]),
              ),
              const SizedBox(height: 18),
              // Action button
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (isCharity) {
                      await _processCharityDonation(champion, potCredits, netDonation);
                    } else {
                      await _awardPrizeCredits(champion, prizeCredits);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCharity ? BmbColors.successGreen : BmbColors.gold,
                    foregroundColor: isCharity ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isCharity ? Icons.volunteer_activism : Icons.emoji_events, size: 18),
                  label: Text(
                      isCharity ? 'Confirm & Choose Charity'
                          : hasPrizeCredits ? 'Confirm & Award $prizeCredits Credits' : 'Confirm Champion',
                      style: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
              ),
            ],
          )),
        ),
      ),
    );
  }

  Future<void> _awardPrizeCredits(String winner, int prizeCredits) async {
    if (prizeCredits > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    setState(() => _prizeAwarded = true);

    // ─── STANDARD BRACKET ───
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.emoji_events, color: Colors.black, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(prizeCredits > 0
                  ? 'Champion confirmed! $prizeCredits credits awarded to $winner.'
                  : 'Champion confirmed! $winner is the tournament winner.')),
        ]),
        backgroundColor: BmbColors.gold,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  /// ─── CHARITY BRACKET: credits go to charity, NOT the winner ───
  Future<void> _processCharityDonation(String winner, int potCredits, int netDonation) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // ── Create charity escrow (pending_selection, 30-day window) ─────
    final escrowDollars = CharityService.creditsToDollars(netDonation);
    try {
      await CharityEscrowService.instance.createEscrow(
        bracketId: _bracket.id,
        bracketName: _bracket.name,
        winnerId: winner,
        winnerName: winner,
        potCredits: potCredits,
        netDonationDollars: escrowDollars,
      );
    } catch (_) {
      // Non-blocking — escrow is tracked locally; server sync in production
    }

    setState(() => _prizeAwarded = true);

    if (!mounted) return;

    final netDollars = CharityService.creditsToDollars(netDonation);

    // Show confirmation that the winner will be notified to choose a charity.
    // The host does NOT choose the charity — the WINNER does via their own flow.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [BmbColors.successGreen, const Color(0xFF66BB6A)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Winner Confirmed!',
              style: TextStyle(
                color: BmbColors.textPrimary, fontSize: 18,
                fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Row(children: [
                  Icon(Icons.emoji_events, color: BmbColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(winner, style: TextStyle(
                    color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold,
                  ))),
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Charity Pot', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                  Text('\$${netDollars.toStringAsFixed(2)}',
                    style: TextStyle(color: BmbColors.successGreen, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Text(
              '$winner will be notified to choose a charity for the \$${netDollars.toStringAsFixed(2)} donation. The donation will be processed via Tremendous once they make their selection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.successGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Got It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  GIVEAWAY DRAWING
  // ═══════════════════════════════════════════════════════════════

  Future<void> _checkGiveawayStatus() async {
    final done = await GiveawayService.hasGiveawayBeenPerformed(_bracket.id);
    if (done) {
      final result = await GiveawayService.getResultForBracket(_bracket.id);
      if (mounted) {
        setState(() {
          _giveawayCompleted = true;
          _giveawayResult = result;
        });
      }
    } else {
      _checkAutoSpinner();
    }
  }

  /// Auto-spinner: when auto-host is ON, giveaway enabled, tournament
  /// complete, prize awarded, and 15+ minutes since completion — auto-launch.
  void _checkAutoSpinner() {
    if (!_bracket.autoHost) return;
    if (!_bracket.hasGiveaway) return;
    if (_bracket.giveawayWinnerCount <= 0) return;
    if (!_results.isTournamentComplete) return;
    if (!_prizeAwarded) return; // wait until champion is confirmed

    final completedAt = _bracket.completedAt;
    if (completedAt == null) return;

    final minutesSinceComplete = DateTime.now().difference(completedAt).inMinutes;
    if (minutesSinceComplete < 15) return;

    if (mounted && !_autoSpinnerPending) {
      setState(() {
        _autoSpinnerPending = true;
        _autoSpinnerCountdown = 5;
      });
      _autoSpinnerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) { timer.cancel(); return; }
        setState(() => _autoSpinnerCountdown--);
        if (_autoSpinnerCountdown <= 0) {
          timer.cancel();
          setState(() => _autoSpinnerPending = false);
          _launchGiveaway();
        }
      });
    }
  }

  bool get _isGiveawayEligible => GiveawayService.isEligibleForGiveaway(
    hostId: _bracket.hostId,
    hasGiveaway: _bracket.hasGiveaway,
    participantCount: _bracket.joinedPlayers.length + 1,
  );

  Future<void> _launchGiveaway() async {
    final participants = <Map<String, String>>[
      {'id': _bracket.hostId, 'name': _bracket.hostName},
      ..._bracket.joinedPlayers.map((p) => {'id': p.userId, 'name': p.userName}),
    ];

    // Determine leaderboard leader (first joined player or host as fallback)
    String? leaderboardLeaderId;
    String? leaderboardLeaderName;
    if (_bracket.joinedPlayers.isNotEmpty) {
      // Use first joined player as leaderboard leader (in real app, this comes from scoring)
      final leader = _bracket.joinedPlayers.first;
      leaderboardLeaderId = leader.userId;
      leaderboardLeaderName = leader.userName;
    }

    final result = await Navigator.push<GiveawayResult>(
      context,
      MaterialPageRoute(
        builder: (_) => GiveawaySpinnerScreen(
          bracket: _bracket,
          participants: participants,
          contributionAmount: _bracket.isFreeEntry
              ? _bracket.giveawayTokensPerWinner
              : _bracket.entryDonation,
          leaderboardLeaderId: leaderboardLeaderId,
          leaderboardLeaderName: leaderboardLeaderName,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _giveawayCompleted = true;
        _giveawayResult = result;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════

  String _roundName(int round) {
    final totalRounds = _bracket.totalRounds;
    final remaining = totalRounds - round;
    if (remaining == 0) return 'Champion';
    if (remaining == 1) return 'Finals';
    if (remaining == 2) return 'Semi-Finals';
    if (remaining == 3) return 'Quarter-Finals';
    return 'Round ${round + 1}';
  }

  String _timeAgo(DateTime? time) {
    if (time == null) return 'never';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ═══════════════════════════════════════════════════════════════
  //  HOST STATUS OVERRIDE
  // ═══════════════════════════════════════════════════════════════

  /// The valid statuses a host can manually set.
  static const _statusOptions = [
    ('upcoming', 'Upcoming', Icons.schedule, BmbColors.blue),
    ('live', 'LIVE', Icons.play_circle_filled, BmbColors.successGreen),
    ('in_progress', 'In Progress', Icons.lock, BmbColors.gold),
    ('done', 'Done', Icons.check_circle, Color(0xFF00BCD4)),
  ];

  void _showStatusOverrideSheet() {
    final currentStatus = _bracket.status;
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.admin_panel_settings, color: BmbColors.gold, size: 22),
                const SizedBox(width: 8),
                Text('Override Tournament Status',
                    style: TextStyle(color: BmbColors.textPrimary, fontSize: 16,
                        fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              ]),
              const SizedBox(height: 6),
              Text('As the host, you can manually change the status at any time, '
                   'even if auto-host is enabled. This overrides all automatic transitions.',
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.3)),
              if (_bracket.autoHost) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.smart_toy, color: BmbColors.gold, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                        'Auto-Host is ON. Your manual override takes priority.',
                        style: TextStyle(color: BmbColors.gold, fontSize: 11))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              ..._statusOptions.map((opt) {
                final (value, label, icon, color) = opt;
                final isCurrent = currentStatus == value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isCurrent ? null : () {
                        Navigator.pop(ctx);
                        _applyStatusOverride(value);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? color.withValues(alpha: 0.12)
                              : BmbColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? color : BmbColors.borderColor,
                            width: isCurrent ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(children: [
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(label,
                              style: TextStyle(
                                  color: isCurrent ? color : BmbColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: isCurrent ? BmbFontWeights.bold : FontWeight.normal))),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('CURRENT', style: TextStyle(
                                  color: color, fontSize: 9, fontWeight: BmbFontWeights.bold)),
                            ),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _applyStatusOverride(String newStatus) {
    setState(() {
      _bracket = _bracket.copyWith(status: newStatus);
      // If moving to live and credits weren't deducted yet, mark them deducted
      if (newStatus == 'live' && !_bracket.creditsDeducted) {
        _bracket = _bracket.copyWith(creditsDeducted: true);
      }
    });
    final label = _statusOptions.firstWhere((o) => o.$1 == newStatus).$2;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('Status updated to "$label"'),
      ]),
      backgroundColor: BmbColors.successGreen,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_isTemplate) _buildTemplateBanner(),
              if (!_isTemplate) _buildCustomBanner(),
              _buildProgressBar(),
              _buildRoundTabs(),
              Expanded(child: _buildGamesList()),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────

  void _toggleAutoHost() {
    setState(() {
      _bracket = _bracket.copyWith(autoHost: !_bracket.autoHost);
    });
    final label = _bracket.autoHost ? 'ON' : 'OFF';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(_bracket.autoHost ? Icons.smart_toy : Icons.person, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('Auto-Host turned $label'),
      ]),
      backgroundColor: _bracket.autoHost ? BmbColors.successGreen : BmbColors.textTertiary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _buildHeader() {
    // Status badge color
    Color statusColor;
    switch (_bracket.status) {
      case 'upcoming': statusColor = BmbColors.blue; break;
      case 'live': statusColor = BmbColors.successGreen; break;
      case 'in_progress': statusColor = BmbColors.gold; break;
      case 'done': statusColor = const Color(0xFF00BCD4); break;
      default: statusColor = BmbColors.textTertiary;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon:
                const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _isTemplate
                        ? 'Live Results'
                        : 'Update Results',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Row(children: [
                  Flexible(child: Text(_bracket.name,
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 6),
                  // Tappable status badge → opens override sheet
                  GestureDetector(
                    onTap: _showStatusOverrideSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_bracket.statusLabel,
                            style: TextStyle(color: statusColor, fontSize: 9,
                                fontWeight: BmbFontWeights.bold)),
                        const SizedBox(width: 3),
                        Icon(Icons.edit, color: statusColor, size: 9),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          // Auto-Host toggle (host can override auto by toggling off)
          GestureDetector(
            onTap: _toggleAutoHost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _bracket.autoHost
                    ? BmbColors.successGreen.withValues(alpha: 0.12)
                    : BmbColors.borderColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _bracket.autoHost
                      ? BmbColors.successGreen.withValues(alpha: 0.4)
                      : BmbColors.borderColor,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _bracket.autoHost ? Icons.smart_toy : Icons.person,
                  color: _bracket.autoHost ? BmbColors.successGreen : BmbColors.textTertiary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _bracket.autoHost ? 'Auto' : 'Manual',
                  style: TextStyle(
                    color: _bracket.autoHost ? BmbColors.successGreen : BmbColors.textTertiary,
                    fontSize: 9,
                    fontWeight: BmbFontWeights.bold,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          if (_isTemplate)
            IconButton(
              icon: _isSyncing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: BmbColors.blue))
                  : Icon(Icons.sync, color: BmbColors.blue, size: 22),
              onPressed: _isSyncing ? null : _triggerLiveSync,
              tooltip: 'Sync Latest Results',
            ),
        ],
      ),
    );
  }

  // ─── MODE BANNERS ─────────────────────────────────────────────

  /// Template mode: BMB handles results — read-only for the host
  Widget _buildTemplateBanner() {
    final provider = ResultsService.currentProvider;
    final lastSync = ResultsService.getLastSyncTime(_bracket);
    final feedResult =
        ResultsService.getLastLiveFeedResult(_bracket);
    final template = BracketTemplate.allTemplates
        .where((t) => t.id == _bracket.templateId)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.blue.withValues(alpha: 0.12),
          BmbColors.successGreen.withValues(alpha: 0.08),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: BmbColors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.cell_tower,
                color: BmbColors.successGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'BackMyBracket handles results for you',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 13,
                    fontWeight: BmbFontWeights.bold),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Results auto-update from live data feeds as games finish. '
            'You and all participants using this ${template?.name ?? "template"} '
            'bracket will see the same scores in real time.',
            style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 11,
                height: 1.4),
          ),
          const SizedBox(height: 8),
          // Source and sync info
          Row(children: [
            Icon(Icons.cloud_sync,
                color: BmbColors.textTertiary, size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Source: ${feedResult?.source ?? provider.displayName}'
                ' | Synced: ${_timeAgo(lastSync ?? feedResult?.lastFetched)}'
                '${_lastSyncResult != null ? " | ${_lastSyncResult!.message}" : ""}',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 9),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// Custom mode: host must update manually — this is THEIR tournament
  Widget _buildCustomBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.12),
          BmbColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.edit_note, color: BmbColors.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Manual results — update as games finish',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 13,
                    fontWeight: BmbFontWeights.bold),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Tap a team to select the winner for each game. '
            'Enter the score (optional) and the bracket will advance automatically. '
            'You can undo a result if you made a mistake.',
            style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 11,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  // ─── PROGRESS ─────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final pct = (_results.completionPercent * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  '${_results.completedGames} of ${_results.totalGames} games completed',
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12)),
              Text('$pct%',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 12,
                      fontWeight: BmbFontWeights.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _results.completionPercent,
              minHeight: 8,
              backgroundColor: BmbColors.borderColor,
              valueColor: AlwaysStoppedAnimation(
                  _results.isTournamentComplete
                      ? BmbColors.gold
                      : BmbColors.successGreen),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ROUND TABS ───────────────────────────────────────────────

  Widget _buildRoundTabs() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _bracket.totalRounds,
        itemBuilder: (ctx, i) {
          final sel = _currentRound == i;
          final roundGames =
              _results.games.values.where((g) => g.round == i).toList();
          final completedInRound =
              roundGames.where((g) => g.isCompleted).length;
          final allDone = roundGames.isNotEmpty &&
              completedInRound == roundGames.length;

          return GestureDetector(
            onTap: () => setState(() => _currentRound = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? BmbColors.blue
                    : allDone
                        ? BmbColors.successGreen
                            .withValues(alpha: 0.15)
                        : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel
                      ? BmbColors.blue
                      : allDone
                          ? BmbColors.successGreen
                          : BmbColors.borderColor,
                ),
              ),
              child: Row(children: [
                if (allDone && !sel) ...[
                  Icon(Icons.check_circle,
                      color: BmbColors.successGreen, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(_roundName(i),
                    style: TextStyle(
                        color:
                            sel ? Colors.white : BmbColors.textSecondary,
                        fontSize: 12,
                        fontWeight: sel
                            ? BmbFontWeights.bold
                            : FontWeight.normal)),
                if (!allDone && roundGames.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text('$completedInRound/${roundGames.length}',
                      style: TextStyle(
                          color: sel
                              ? Colors.white70
                              : BmbColors.textTertiary,
                          fontSize: 9)),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  // ─── GAMES LIST ───────────────────────────────────────────────

  Widget _buildGamesList() {
    final roundGames = _results.games.values
        .where((g) => g.round == _currentRound)
        .toList();
    roundGames.sort((a, b) => a.matchIndex.compareTo(b.matchIndex));

    if (roundGames.isEmpty) {
      return Center(
        child: Text('No games in this round',
            style: TextStyle(
                color: BmbColors.textTertiary, fontSize: 14)),
      );
    }

    return RefreshIndicator(
      color: _isTemplate ? BmbColors.blue : BmbColors.gold,
      backgroundColor: BmbColors.midNavy,
      onRefresh: _isTemplate ? _triggerLiveSync : () async {},
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        itemCount: roundGames.length,
        itemBuilder: (ctx, idx) => _buildGameCard(roundGames[idx]),
      ),
    );
  }

  /// Show a dialog letting host pick which team won (for entire card tap).
  /// If both teams are TBD, shows a "name the teams" dialog first.
  void _showTeamSelectionDialog(GameResult game) {
    if (game.isCompleted || _isTemplate) return;

    final bothTBD = game.team1 == 'TBD' && game.team2 == 'TBD';
    final oneTBD = game.team1 == 'TBD' || game.team2 == 'TBD';

    if (bothTBD || oneTBD) {
      _showNameTeamsAndSelectWinner(game);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Select Winner',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 16,
                fontWeight: BmbFontWeights.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Game ${game.matchIndex + 1} - ${_roundName(game.round)}',
                style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
            const SizedBox(height: 16),
            _teamSelectionTile(game, game.team1),
            const SizedBox(height: 8),
            _teamSelectionTile(game, game.team2),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary)),
          ),
        ],
      ),
    );
  }

  /// When teams are TBD, let host name them and pick winner in one dialog.
  void _showNameTeamsAndSelectWinner(GameResult game) {
    final team1Ctrl = TextEditingController(
        text: game.team1 == 'TBD' ? '' : game.team1);
    final team2Ctrl = TextEditingController(
        text: game.team2 == 'TBD' ? '' : game.team2);
    final scoreCtrl = TextEditingController();
    String? selectedWinner;
    final sttService = SpeechInputService.instance;
    bool isListening = false;
    String? listeningField; // 'team1' or 'team2'

    Future<void> startMic(
      TextEditingController ctrl,
      String fieldId,
      void Function(void Function()) setDialogState,
    ) async {
      await sttService.init();
      if (!sttService.isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Speech recognition not available. Allow microphone access and use Chrome or Edge.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      setDialogState(() { isListening = true; listeningField = fieldId; });
      final started = await sttService.startListening(
        onResult: (text, isFinal) {
          setDialogState(() {
            ctrl.text = text;
            ctrl.selection = TextSelection.fromPosition(
              TextPosition(offset: ctrl.text.length),
            );
            if (isFinal) { isListening = false; listeningField = null; }
          });
        },
      );
      if (!started) {
        setDialogState(() { isListening = false; listeningField = null; });
      }
    }

    Future<void> stopMic(void Function(void Function()) setDialogState) async {
      await sttService.stop();
      setDialogState(() { isListening = false; listeningField = null; });
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final team1Name = team1Ctrl.text.trim().isNotEmpty
                ? team1Ctrl.text.trim()
                : null;
            final team2Name = team2Ctrl.text.trim().isNotEmpty
                ? team2Ctrl.text.trim()
                : null;
            final bothNamed = team1Name != null && team2Name != null;

            return AlertDialog(
              backgroundColor: BmbColors.midNavy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Update Game ${game.matchIndex + 1}',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_roundName(game.round),
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 16),
                    // Step 1: Name teams
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BmbColors.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: BmbColors.gold.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.edit, color: BmbColors.gold, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                'Name the teams, then pick the winner',
                                style: TextStyle(
                                    color: BmbColors.gold, fontSize: 11))),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    // Listening indicator
                    if (isListening)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: BmbColors.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: BmbColors.errorRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: BmbColors.errorRed, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Listening...', style: TextStyle(color: BmbColors.errorRed, fontSize: 11, fontWeight: BmbFontWeights.semiBold)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => stopMic(setDialogState),
                            child: Text('Stop', style: TextStyle(color: BmbColors.errorRed.withValues(alpha: 0.7), fontSize: 11)),
                          ),
                        ]),
                      ),
                    // Team 1 name field
                    Text('Team 1',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: team1Ctrl,
                      autofocus: game.team1 == 'TBD',
                      style: TextStyle(
                          color: BmbColors.textPrimary, fontSize: 14),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Team Name',
                        hintStyle: TextStyle(
                            color: BmbColors.textTertiary.withValues(alpha: 0.5), fontSize: 13),
                        filled: true,
                        fillColor: BmbColors.cardDark,
                        suffixIcon: GestureDetector(
                          onTap: () => isListening && listeningField == 'team1'
                              ? stopMic(setDialogState)
                              : startMic(team1Ctrl, 'team1', setDialogState),
                          child: Icon(
                            isListening && listeningField == 'team1' ? Icons.stop_circle : Icons.mic,
                            color: isListening && listeningField == 'team1' ? BmbColors.errorRed : BmbColors.textTertiary,
                            size: 20,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: BmbColors.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: BmbColors.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: BmbColors.blue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Team 2 name field
                    Text('Team 2',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 11)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: team2Ctrl,
                      style: TextStyle(
                          color: BmbColors.textPrimary, fontSize: 14),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Team Name',
                        hintStyle: TextStyle(
                            color: BmbColors.textTertiary.withValues(alpha: 0.5), fontSize: 13),
                        filled: true,
                        fillColor: BmbColors.cardDark,
                        suffixIcon: GestureDetector(
                          onTap: () => isListening && listeningField == 'team2'
                              ? stopMic(setDialogState)
                              : startMic(team2Ctrl, 'team2', setDialogState),
                          child: Icon(
                            isListening && listeningField == 'team2' ? Icons.stop_circle : Icons.mic,
                            color: isListening && listeningField == 'team2' ? BmbColors.errorRed : BmbColors.textTertiary,
                            size: 20,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: BmbColors.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: BmbColors.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: BmbColors.blue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Step 2: Select winner (only when both named)
                    if (bothNamed) ...[
                      Text('SELECT WINNER',
                          style: TextStyle(
                              color: BmbColors.textTertiary,
                              fontSize: 10,
                              fontWeight: BmbFontWeights.bold,
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      // Team 1 as winner
                      GestureDetector(
                        onTap: () => setDialogState(
                            () => selectedWinner = team1Name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedWinner == team1Name
                                ? BmbColors.successGreen
                                    .withValues(alpha: 0.12)
                                : BmbColors.cardDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedWinner == team1Name
                                  ? BmbColors.successGreen
                                  : BmbColors.borderColor,
                              width:
                                  selectedWinner == team1Name ? 1.5 : 0.5,
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              selectedWinner == team1Name
                                  ? Icons.check_circle
                                  : Icons.radio_button_off,
                              color: selectedWinner == team1Name
                                  ? BmbColors.successGreen
                                  : BmbColors.textTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(team1Name,
                                    style: TextStyle(
                                        color: selectedWinner == team1Name
                                            ? BmbColors.successGreen
                                            : BmbColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: selectedWinner ==
                                                team1Name
                                            ? BmbFontWeights.bold
                                            : FontWeight.normal))),
                            if (selectedWinner == team1Name)
                              Text('WINNER',
                                  style: TextStyle(
                                      color: BmbColors.successGreen,
                                      fontSize: 9,
                                      fontWeight: BmbFontWeights.bold,
                                      letterSpacing: 0.5)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Team 2 as winner
                      GestureDetector(
                        onTap: () => setDialogState(
                            () => selectedWinner = team2Name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedWinner == team2Name
                                ? BmbColors.successGreen
                                    .withValues(alpha: 0.12)
                                : BmbColors.cardDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedWinner == team2Name
                                  ? BmbColors.successGreen
                                  : BmbColors.borderColor,
                              width:
                                  selectedWinner == team2Name ? 1.5 : 0.5,
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              selectedWinner == team2Name
                                  ? Icons.check_circle
                                  : Icons.radio_button_off,
                              color: selectedWinner == team2Name
                                  ? BmbColors.successGreen
                                  : BmbColors.textTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(team2Name,
                                    style: TextStyle(
                                        color: selectedWinner == team2Name
                                            ? BmbColors.successGreen
                                            : BmbColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: selectedWinner ==
                                                team2Name
                                            ? BmbFontWeights.bold
                                            : FontWeight.normal))),
                            if (selectedWinner == team2Name)
                              Text('WINNER',
                                  style: TextStyle(
                                      color: BmbColors.successGreen,
                                      fontSize: 9,
                                      fontWeight: BmbFontWeights.bold,
                                      letterSpacing: 0.5)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Optional score
                      TextField(
                        controller: scoreCtrl,
                        style: TextStyle(
                            color: BmbColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Score (optional, e.g. 75-68)',
                          hintStyle: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: BmbColors.cardDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: BmbColors.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: BmbColors.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BmbColors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline,
                              color: BmbColors.blue, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  'Enter both team names above to select the winner.',
                                  style: TextStyle(
                                      color: BmbColors.blue,
                                      fontSize: 11))),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: BmbColors.textTertiary)),
                ),
                if (bothNamed && selectedWinner != null)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // First rename the TBD teams in the results, then set winner
                      _renameAndSetWinner(
                        game: game,
                        newTeam1: team1Name,
                        newTeam2: team2Name,
                        winner: selectedWinner!,
                        score: scoreCtrl.text.isNotEmpty
                            ? scoreCtrl.text
                            : null,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Confirm Winner',
                        style:
                            TextStyle(fontWeight: BmbFontWeights.bold)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Rename TBD teams in the bracket results and set the winner.
  void _renameAndSetWinner({
    required GameResult game,
    required String newTeam1,
    required String newTeam2,
    required String winner,
    String? score,
  }) {
    // Update team names in the results first
    final updatedResults =
        ResultsService.renameTeamsAndSetResult(
      bracket: _bracket,
      gameId: game.gameId,
      newTeam1: newTeam1,
      newTeam2: newTeam2,
      winner: winner,
      score: score,
    );
    setState(() => _results = updatedResults);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$winner advances! Scores updated.'),
        backgroundColor: BmbColors.successGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Widget _teamSelectionTile(GameResult game, String team) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(context);
          _selectWinner(game, team);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BmbColors.blue.withValues(alpha: 0.15),
              ),
              child: Center(child: Text(team.isNotEmpty ? team[0].toUpperCase() : '?',
                  style: TextStyle(color: BmbColors.blue, fontSize: 14, fontWeight: BmbFontWeights.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(team, style: TextStyle(
                color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Select', style: TextStyle(
                  color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.bold)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildGameCard(GameResult game) {
    final isCompleted = game.isCompleted;
    // Entire card is tappable for custom brackets with pending games
    // TBD teams ARE tappable — host can name them and pick winner
    final canTapCard = !isCompleted && !_isTemplate;

    return GestureDetector(
      onTap: canTapCard ? () => _showTeamSelectionDialog(game) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCompleted
                ? BmbColors.successGreen.withValues(alpha: 0.3)
                : canTapCard
                    ? BmbColors.gold.withValues(alpha: 0.4)
                    : BmbColors.borderColor,
            width: canTapCard ? 1.0 : 0.5,
          ),
        ),
        child: Column(children: [
          // Game header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isCompleted
                  ? BmbColors.successGreen.withValues(alpha: 0.08)
                  : canTapCard
                      ? BmbColors.gold.withValues(alpha: 0.06)
                      : BmbColors.borderColor.withValues(alpha: 0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Text('Game ${game.matchIndex + 1}',
                  style: TextStyle(
                      color: BmbColors.textTertiary,
                      fontSize: 11,
                      fontWeight: BmbFontWeights.semiBold)),
              const Spacer(),
              if (isCompleted) ...[
                if (game.score != null)
                  Text(game.score!,
                      style: TextStyle(
                          color: BmbColors.textSecondary,
                          fontSize: 11,
                          fontWeight: BmbFontWeights.medium)),
                const SizedBox(width: 8),
                Icon(Icons.check_circle,
                    color: BmbColors.successGreen, size: 14),
                const SizedBox(width: 4),
                Text('Final',
                    style: TextStyle(
                        color: BmbColors.successGreen, fontSize: 10)),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isTemplate
                        ? BmbColors.blue.withValues(alpha: 0.15)
                        : BmbColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isTemplate
                          ? BmbColors.blue.withValues(alpha: 0.3)
                          : BmbColors.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!_isTemplate) ...[
                      Icon(Icons.touch_app, color: BmbColors.gold, size: 12),
                      const SizedBox(width: 4),
                    ],
                    Text(
                        _isTemplate ? 'Awaiting Result' : 'TAP TO UPDATE',
                        style: TextStyle(
                            color: _isTemplate
                                ? BmbColors.blue
                                : BmbColors.gold,
                            fontSize: 9,
                            fontWeight: BmbFontWeights.bold,
                            letterSpacing: _isTemplate ? 0 : 0.5)),
                  ]),
                ),
              ],
            ]),
          ),
          // Team 1
          _buildTeamRow(
              game, game.team1, isCompleted && game.winner == game.team1),
          Divider(color: BmbColors.borderColor, height: 0.5),
          // Team 2
          _buildTeamRow(
              game, game.team2, isCompleted && game.winner == game.team2),
          // Undo button for completed games (CUSTOM brackets only)
          if (isCompleted && !_isTemplate)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextButton.icon(
                onPressed: () => _undoResult(game),
                icon:
                    Icon(Icons.undo, size: 14, color: BmbColors.errorRed),
                label: Text('Undo Result',
                    style: TextStyle(
                        color: BmbColors.errorRed, fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildTeamRow(
      GameResult game, String team, bool isWinner) {
    // Custom brackets: host can tap to select winner
    // Template brackets: read-only — BMB handles it
    // TBD teams open the rename-and-select dialog
    final isTBD = team == 'TBD';
    final canSelect = !game.isCompleted && !_isTemplate;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canSelect
            ? () {
                if (isTBD) {
                  _showNameTeamsAndSelectWinner(game);
                } else {
                  _selectWinner(game, team);
                }
              }
            : null,
        splashColor: canSelect ? BmbColors.blue.withValues(alpha: 0.1) : null,
        highlightColor: canSelect ? BmbColors.blue.withValues(alpha: 0.05) : null,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: isWinner
              ? BmbColors.successGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isWinner
                    ? BmbColors.successGreen
                    : canSelect
                        ? BmbColors.blue.withValues(alpha: 0.15)
                        : BmbColors.borderColor.withValues(alpha: 0.4),
              ),
              child: Center(
                child: isWinner
                    ? Icon(Icons.check, color: Colors.white, size: 16)
                    : isTBD && canSelect
                        ? Icon(Icons.edit, color: BmbColors.gold, size: 16)
                        : Text(
                            team.isNotEmpty ? team[0].toUpperCase() : '?',
                            style: TextStyle(
                                color: canSelect
                                    ? BmbColors.blue
                                    : BmbColors.textSecondary,
                                fontSize: 14,
                                fontWeight: BmbFontWeights.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(isTBD && canSelect ? 'Tap to name team' : team,
                  style: TextStyle(
                    color: isWinner
                        ? BmbColors.successGreen
                        : isTBD
                            ? canSelect
                                ? BmbColors.gold
                                : BmbColors.textTertiary
                            : BmbColors.textPrimary,
                    fontSize: 14,
                    fontWeight: isWinner
                        ? BmbFontWeights.bold
                        : isTBD && canSelect
                            ? BmbFontWeights.medium
                            : FontWeight.normal,
                    fontStyle: isTBD && canSelect ? FontStyle.italic : FontStyle.normal,
                  )),
            ),
            if (isWinner)
              Text('WINNER',
                  style: TextStyle(
                      color: BmbColors.successGreen,
                      fontSize: 10,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 1)),
            if (canSelect)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isTBD
                      ? BmbColors.gold.withValues(alpha: 0.15)
                      : BmbColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isTBD
                      ? BmbColors.gold.withValues(alpha: 0.3)
                      : BmbColors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isTBD ? Icons.edit : Icons.touch_app,
                      color: isTBD ? BmbColors.gold : BmbColors.blue, size: 12),
                  const SizedBox(width: 3),
                  Text(isTBD ? 'Name' : 'Select',
                      style: TextStyle(
                          color: isTBD ? BmbColors.gold : BmbColors.blue,
                          fontSize: 10,
                          fontWeight: BmbFontWeights.bold)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  // ─── BOTTOM ACTIONS ───────────────────────────────────────────

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.95),
        border: Border(
            top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Giveaway eligibility notice
          if (_results.isTournamentComplete && !_prizeAwarded && _isGiveawayEligible) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration, color: BmbColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After confirming the winner, a Giveaway Spinner will be available \u2014 random winners are drawn from all participants and bonus credits are awarded!',
                      style: TextStyle(color: BmbColors.gold, fontSize: 10, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Confirm Winner & Award Reward (both modes)
          if (_results.isTournamentComplete && !_prizeAwarded) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _showConfirmWinnerAndAwardPrize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.emoji_events, size: 20),
                label: Text('Confirm Winner & Award Credits',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: BmbFontWeights.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Prize awarded banner
          if (_prizeAwarded) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: BmbColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: BmbColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Text('Champion confirmed! Reward awarded.',
                      style: TextStyle(
                          color: BmbColors.gold,
                          fontSize: 12,
                          fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      _results.isTournamentComplete
                          ? (_prizeAwarded
                              ? 'Tournament Finalized!'
                              : 'Tournament Complete!')
                          : '${_results.completedGames}/${_results.totalGames} games scored',
                      style: TextStyle(
                          color: _results.isTournamentComplete
                              ? BmbColors.gold
                              : BmbColors.textSecondary,
                          fontSize: 12,
                          fontWeight: BmbFontWeights.medium)),
                  if (_isTemplate && !_results.isTournamentComplete)
                    Text('Results update automatically from live feed',
                        style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 10)),
                  if (!_isTemplate && !_results.isTournamentComplete)
                    Text('Tap a team to select the winner',
                        style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 10)),
                  if (_results.isTournamentComplete && !_prizeAwarded)
                    Text('Confirm the winner to award reward credits',
                        style: TextStyle(
                            color: BmbColors.gold, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Auto-spinner countdown badge
            if (_autoSpinnerPending)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    _autoSpinnerTimer?.cancel();
                    setState(() => _autoSpinnerPending = false);
                    _launchGiveaway();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: BmbColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BmbColors.gold, width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_awesome, color: BmbColors.gold, size: 14),
                      const SizedBox(width: 4),
                      Text('Giveaway in ${_autoSpinnerCountdown}s',
                          style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                    ]),
                  ),
                ),
              ),
            // Giveaway Drawing button (BMB-hosted brackets only)
            if (_prizeAwarded && _isGiveawayEligible && !_giveawayCompleted && !_autoSpinnerPending)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: _launchGiveaway,
                  icon: const Icon(Icons.celebration, size: 16),
                  label: Text('Giveaway',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: BmbFontWeights.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            if (_giveawayCompleted && _giveawayResult != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.celebration, color: BmbColors.successGreen, size: 14),
                          const SizedBox(width: 4),
                          Text('Giveaway done',
                              style: TextStyle(
                                color: BmbColors.successGreen,
                                fontSize: 10,
                                fontWeight: BmbFontWeights.bold,
                              )),
                        ],
                      ),
                      Text('${_giveawayResult!.totalCreditsAwarded}c awarded',
                          style: TextStyle(
                            color: BmbColors.gold,
                            fontSize: 8,
                            fontWeight: BmbFontWeights.semiBold,
                          )),
                    ],
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _bracket.isVoting
                        ? VotingLeaderboardScreen(bracket: _bracket)
                        : LeaderboardScreen(bracket: _bracket),
                  ),
                );
              },
              icon: Icon(Icons.leaderboard, size: 18),
              label: Text('Leaderboard',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: BmbFontWeights.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
