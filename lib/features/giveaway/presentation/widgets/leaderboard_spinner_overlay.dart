import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/giveaway/data/services/giveaway_service.dart';

/// Inline leaderboard spinner overlay.
///
/// Flow:
///  1. Gold "Spin" button appears on the leaderboard page
///  2. Tap → spinner wheel appears center-screen, names cycle rapidly with deceleration
///  3. Lands on a random name → confetti explosion + name rises to prominence
///  4. "1st Place" banner slides in → name recorded
///  5. "Spin" button reappears for 2nd winner (repeat for all configured winners)
///  6. After all winners drawn → shaded leaderboard watermark behind a winner summary
///
/// This widget is a full-screen overlay designed to be placed in a Stack
/// on top of the existing leaderboard content.
class LeaderboardSpinnerOverlay extends StatefulWidget {
  final List<String> participantNames;
  final List<String> participantIds;
  final int winnerCount;
  final int tokensPerWinner;
  final String bracketId;
  final String bracketName;
  final String sport;
  final String? leaderboardLeaderId;
  final String? leaderboardLeaderName;
  final VoidCallback onComplete;
  final ValueChanged<GiveawayResult> onResult;

  const LeaderboardSpinnerOverlay({
    super.key,
    required this.participantNames,
    required this.participantIds,
    required this.winnerCount,
    required this.tokensPerWinner,
    required this.bracketId,
    required this.bracketName,
    required this.sport,
    this.leaderboardLeaderId,
    this.leaderboardLeaderName,
    required this.onComplete,
    required this.onResult,
  });

  @override
  State<LeaderboardSpinnerOverlay> createState() =>
      _LeaderboardSpinnerOverlayState();
}

enum _SpinPhase { idle, spinning, landed, banner, nextReady, allDone }

class _LeaderboardSpinnerOverlayState extends State<LeaderboardSpinnerOverlay>
    with TickerProviderStateMixin {
  _SpinPhase _phase = _SpinPhase.idle;
  GiveawayResult? _result;
  int _currentWinnerIdx = 0;
  String _displayedName = '';

  // Spin animation
  Timer? _spinTimer;
  List<String> _spinSequence = [];
  int _spinIndex = 0;
  int _spinSpeed = 40;

  // Remaining pool (names not yet won)
  late List<String> _remainingNames;
  final List<GiveawayWinner> _drawnWinners = [];

  // Animation controllers
  late AnimationController _confettiController;
  late AnimationController _bannerController;
  late Animation<double> _bannerSlide;
  late AnimationController _nameScaleController;
  late Animation<double> _nameScale;
  late AnimationController _glowPulseController;
  late Animation<double> _glowPulse;

  // Confetti particles
  final _random = Random();
  late List<_ConfettiParticle> _confettiParticles;

  @override
  void initState() {
    super.initState();
    _remainingNames = List.from(widget.participantNames);

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addListener(() => setState(() {}));

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bannerSlide = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _bannerController, curve: Curves.elasticOut),
    );

    _nameScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _nameScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _nameScaleController, curve: Curves.elasticOut),
    );

    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _glowPulse = Tween<double>(begin: 0.4, end: 1.0).animate(_glowPulseController);

    _confettiParticles = List.generate(80, (_) => _ConfettiParticle(_random));
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _confettiController.dispose();
    _bannerController.dispose();
    _nameScaleController.dispose();
    _glowPulseController.dispose();
    super.dispose();
  }

  /// Called when user taps the SPIN button.
  void _startSpin() {
    if (_result == null) {
      // First spin — compute all winners upfront via the service
      _computeResult();
    }
    if (_result == null || _currentWinnerIdx >= _result!.winners.length) return;

    final winner = _result!.winners[_currentWinnerIdx];
    final sequence = GiveawayService.generateSpinSequence(
      participantNames: _remainingNames,
      winnerName: winner.userName,
      totalSpins: 3,
    );

    setState(() {
      _phase = _SpinPhase.spinning;
      _spinSequence = sequence;
      _spinIndex = 0;
      _spinSpeed = 40;
      _displayedName = '';
    });

    _runSpin();
  }

  void _computeResult() {
    // Build participants map from names + ids
    final participants = <Map<String, String>>[];
    for (int i = 0; i < widget.participantNames.length; i++) {
      participants.add({
        'id': i < widget.participantIds.length ? widget.participantIds[i] : 'p_$i',
        'name': widget.participantNames[i],
      });
    }

    // Pre-shuffle and pick winners
    final shuffled = List<Map<String, String>>.from(participants)
      ..shuffle(Random.secure());
    final actualCount = widget.winnerCount.clamp(1, participants.length);

    final winners = <GiveawayWinner>[];
    for (int i = 0; i < actualCount; i++) {
      winners.add(GiveawayWinner(
        userId: shuffled[i]['id'] ?? '',
        userName: shuffled[i]['name'] ?? '',
        creditsAwarded: widget.tokensPerWinner,
        label: '${GiveawayService.ordinal(i + 1)} Place',
      ));
    }

    _result = GiveawayResult(
      oddsMarker: 'gw_${widget.bracketId}_${DateTime.now().millisecondsSinceEpoch}',
      bracketId: widget.bracketId,
      bracketName: widget.bracketName,
      sport: widget.sport,
      winners: winners,
      contributionAmount: widget.tokensPerWinner,
      totalParticipants: participants.length,
      drawnAt: DateTime.now(),
    );
  }

  void _runSpin() {
    _spinTimer?.cancel();
    _spinTimer = Timer(Duration(milliseconds: _spinSpeed), () {
      if (_spinIndex >= _spinSequence.length - 1) {
        // Landed!
        setState(() {
          _displayedName = _spinSequence.last;
          _phase = _SpinPhase.landed;
        });
        _triggerCelebration();
        return;
      }

      setState(() {
        _displayedName = _spinSequence[_spinIndex];
        _spinIndex++;
      });

      // Decelerate in the last 30%
      final progress = _spinIndex / _spinSequence.length;
      if (progress > 0.7) {
        final decel = (progress - 0.7) / 0.3;
        _spinSpeed = 40 + (decel * 400).toInt();
      }

      _runSpin();
    });
  }

  void _triggerCelebration() {
    // Confetti burst
    _confettiParticles = List.generate(80, (_) => _ConfettiParticle(_random));
    _confettiController.forward(from: 0);

    // Name scale-up
    _nameScaleController.forward(from: 0);

    // Banner slide after a brief delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _bannerController.forward(from: 0);
        setState(() => _phase = _SpinPhase.banner);
      }
    });

    // Record winner, move to next after celebration
    final winner = _result!.winners[_currentWinnerIdx];
    _drawnWinners.add(winner);
    _remainingNames.remove(winner.userName);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_currentWinnerIdx + 1 < _result!.winners.length) {
        setState(() {
          _currentWinnerIdx++;
          _phase = _SpinPhase.nextReady;
        });
      } else {
        // All winners drawn — persist and show summary
        _finalizeDrawing();
      }
    });
  }

  Future<void> _finalizeDrawing() async {
    if (_result == null) return;

    // ── CRITICAL: persist the SAME winners that the spinner displayed ──
    // Do NOT re-draw. The _result was computed in _computeResult() and the
    // spinner visually landed on those exact names. We save those directly.

    // Add optional leaderboard-leader bonus (separate from spinner draws)
    GiveawayWinner? leaderWinner;
    if (widget.leaderboardLeaderId != null && widget.leaderboardLeaderName != null) {
      final bonus = GiveawayService.leaderboardBonus(widget.tokensPerWinner);
      leaderWinner = GiveawayWinner(
        userId: widget.leaderboardLeaderId!,
        userName: widget.leaderboardLeaderName!,
        creditsAwarded: bonus,
        label: 'Leaderboard Leader Bonus',
      );
    }

    final finalResult = GiveawayResult(
      oddsMarker: _result!.oddsMarker,
      bracketId: _result!.bracketId,
      bracketName: _result!.bracketName,
      sport: _result!.sport,
      winners: _result!.winners, // exact same winners the spinner landed on
      leaderboardLeader: leaderWinner,
      contributionAmount: _result!.contributionAmount,
      totalParticipants: _result!.totalParticipants,
      drawnAt: _result!.drawnAt,
    );

    // Persist + inject ticker using the EXACT spinner results
    await GiveawayService.saveAndAnnounce(finalResult);

    _result = finalResult;
    widget.onResult(finalResult);

    if (mounted) {
      setState(() => _phase = _SpinPhase.allDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _SpinPhase.allDone) {
      return _buildWinnerSummaryOverlay();
    }

    return Container(
      color: BmbColors.deepNavy.withValues(alpha: 0.92),
      child: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                _buildOverlayHeader(),
                const Spacer(),
                _buildSpinnerArea(),
                const Spacer(),
                _buildSpinButton(),
                const SizedBox(height: 40),
              ],
            ),
            // Confetti layer
            if (_phase == _SpinPhase.landed || _phase == _SpinPhase.banner)
              ..._buildConfetti(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Text('GIVEAWAY DRAWING',
              style: TextStyle(
                color: BmbColors.gold,
                fontSize: 12,
                fontWeight: BmbFontWeights.bold,
                letterSpacing: 3,
              )),
          const SizedBox(height: 2),
          Text(widget.bracketName,
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 14,
                fontWeight: BmbFontWeights.semiBold,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          // Winner progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.winnerCount, (i) {
              final isDrawn = i < _drawnWinners.length;
              final isCurrent = i == _currentWinnerIdx;
              return Container(
                width: isCurrent ? 28 : 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isDrawn
                      ? BmbColors.gold
                      : isCurrent
                          ? BmbColors.blue
                          : BmbColors.borderColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Drawing ${_currentWinnerIdx + 1} of ${widget.winnerCount}',
            style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinnerArea() {
    if (_phase == _SpinPhase.idle || _phase == _SpinPhase.nextReady) {
      // Show "Ready" state
      return Column(
        children: [
          // Show previously drawn winners
          if (_drawnWinners.isNotEmpty) ...[
            ..._drawnWinners.asMap().entries.map((entry) {
              final idx = entry.key;
              final w = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: BmbColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(child: Text('${idx + 1}',
                            style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: BmbFontWeights.bold))),
                      ),
                      const SizedBox(width: 10),
                      Text(w.userName, style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                      const SizedBox(width: 8),
                      Text('+${w.creditsAwarded}c', style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
          AnimatedBuilder(
            animation: _glowPulse,
            builder: (context, child) => Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BmbColors.gold.withValues(alpha: _glowPulse.value * 0.3),
                    BmbColors.gold.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [BmbColors.gold, const Color(0xFFE6A800)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: BmbColors.gold.withValues(alpha: _glowPulse.value * 0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(Icons.celebration, color: Colors.black, size: 42),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _phase == _SpinPhase.nextReady
                ? 'Ready for ${GiveawayService.ordinal(_currentWinnerIdx + 1)} Place!'
                : 'Tap SPIN to start the drawing!',
            style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 16,
              fontWeight: BmbFontWeights.semiBold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.tokensPerWinner} credits per winner',
            style: TextStyle(color: BmbColors.successGreen, fontSize: 13),
          ),
        ],
      );
    }

    // Spinning or landed state
    return Column(
      children: [
        // Current draw label
        Text(
          '${GiveawayService.ordinal(_currentWinnerIdx + 1)} PLACE',
          style: TextStyle(
            color: BmbColors.gold,
            fontSize: 14,
            fontWeight: BmbFontWeights.bold,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '+${widget.tokensPerWinner} credits',
          style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.semiBold),
        ),
        const SizedBox(height: 24),

        // Name display box
        AnimatedBuilder(
          animation: _phase == _SpinPhase.landed || _phase == _SpinPhase.banner
              ? _nameScale
              : const AlwaysStoppedAnimation(1.0),
          builder: (context, child) {
            final isWinner = _phase == _SpinPhase.landed || _phase == _SpinPhase.banner;
            return Transform.scale(
              scale: isWinner ? _nameScale.value : 1.0,
              child: AnimatedBuilder(
                animation: _glowPulse,
                builder: (context, child) => Container(
                  width: 280,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: isWinner
                        ? LinearGradient(colors: [
                            BmbColors.gold.withValues(alpha: _glowPulse.value * 0.3),
                            BmbColors.gold.withValues(alpha: 0.08),
                          ])
                        : LinearGradient(colors: [
                            BmbColors.cardGradientStart,
                            BmbColors.cardGradientEnd,
                          ]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isWinner
                          ? BmbColors.gold
                          : _phase == _SpinPhase.spinning
                              ? BmbColors.blue.withValues(alpha: 0.6)
                              : BmbColors.borderColor,
                      width: isWinner ? 2.5 : 1,
                    ),
                    boxShadow: isWinner
                        ? [BoxShadow(
                            color: BmbColors.gold.withValues(alpha: _glowPulse.value * 0.5),
                            blurRadius: 30,
                            spreadRadius: 6,
                          )]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _displayedName.isEmpty ? '?' : _displayedName,
                      style: TextStyle(
                        color: isWinner ? BmbColors.gold : BmbColors.textPrimary,
                        fontSize: isWinner ? 28 : 22,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Banner
        if (_phase == _SpinPhase.banner)
          AnimatedBuilder(
            animation: _bannerSlide,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _bannerSlide.value),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [BmbColors.gold, const Color(0xFFE6A800)]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
                  ),
                  child: Text(
                    '${GiveawayService.ordinal(_currentWinnerIdx + 1)} PLACE WINNER!',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Credits awarded badge
        if (_phase == _SpinPhase.landed || _phase == _SpinPhase.banner)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet, color: BmbColors.successGreen, size: 16),
                  const SizedBox(width: 6),
                  Text('+${widget.tokensPerWinner} credits deposited to BMB Bucket',
                      style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpinButton() {
    if (_phase == _SpinPhase.spinning ||
        _phase == _SpinPhase.landed ||
        _phase == _SpinPhase.banner) {
      return const SizedBox(height: 56);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _startSpin,
          icon: Icon(Icons.shuffle, size: 22),
          label: Text(
            _phase == _SpinPhase.nextReady ? 'Spin Again' : 'SPIN',
            style: TextStyle(fontSize: 20, fontWeight: BmbFontWeights.bold, letterSpacing: 1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: BmbColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 8,
            shadowColor: BmbColors.gold.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WINNER SUMMARY OVERLAY (shaded leaderboard watermark behind)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWinnerSummaryOverlay() {
    return Container(
      color: BmbColors.deepNavy.withValues(alpha: 0.95),
      child: SafeArea(
        child: Stack(
          children: [
            // Shaded leaderboard watermark in background
            Positioned.fill(
              child: Opacity(
                opacity: 0.06,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.leaderboard, size: 120, color: BmbColors.textPrimary),
                      const SizedBox(height: 8),
                      Text('LEADERBOARD', style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 32,
                        fontWeight: BmbFontWeights.bold,
                        letterSpacing: 8,
                      )),
                      const SizedBox(height: 4),
                      // Show all participant names lightly
                      ...widget.participantNames.take(10).map((name) =>
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(name, style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 14,
                          )),
                        ),
                      ),
                      if (widget.participantNames.length > 10)
                        Text('...', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

            // Winner summary content
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Icon(Icons.celebration, color: BmbColors.gold, size: 56),
                  const SizedBox(height: 12),
                  Text('GIVEAWAY COMPLETE',
                      style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 22,
                        fontWeight: BmbFontWeights.bold,
                        letterSpacing: 2,
                        fontFamily: 'ClashDisplay',
                      )),
                  const SizedBox(height: 4),
                  Text(widget.bracketName,
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),

                  // Winner cards
                  ...(_result?.winners ?? _drawnWinners).asMap().entries.map((entry) {
                    final idx = entry.key;
                    final winner = entry.value;
                    return _buildSummaryWinnerCard(idx, winner);
                  }),

                  // Leaderboard leader bonus
                  if (_result?.leaderboardLeader != null)
                    _buildSummaryWinnerCard(-1, _result!.leaderboardLeader!),

                  const SizedBox(height: 16),

                  // Stats box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: BmbColors.cardGradient,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BmbColors.borderColor, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _statRow('Total Participants', '${_result?.totalParticipants ?? widget.participantNames.length}'),
                        const Divider(color: BmbColors.borderColor, height: 20),
                        _statRow('Winners Drawn', '${_result?.winners.length ?? _drawnWinners.length}'),
                        const Divider(color: BmbColors.borderColor, height: 20),
                        _statRow('Credits Per Winner', '${widget.tokensPerWinner}'),
                        const Divider(color: BmbColors.borderColor, height: 20),
                        _statRow('Total Credits Awarded', '${_result?.totalCreditsAwarded ?? (_drawnWinners.length * widget.tokensPerWinner)}'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Ticker notice
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BmbColors.gold.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.live_tv, color: BmbColors.gold, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Winners will scroll across the LIVE ticker for 24 hours!',
                            style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.semiBold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BmbColors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: BmbColors.blue, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is a promotional giveaway. Winners selected at random from all leaderboard participants regardless of score.',
                            style: TextStyle(color: BmbColors.blue, fontSize: 10, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.buttonPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Done',
                          style: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryWinnerCard(int index, GiveawayWinner winner) {
    final isLeader = index == -1;
    final borderColor = isLeader ? BmbColors.blue : BmbColors.gold;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          borderColor.withValues(alpha: 0.15),
          borderColor.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(isLeader ? Icons.leaderboard : Icons.emoji_events, color: borderColor, size: 18),
            const SizedBox(width: 6),
            Text(
              isLeader ? 'LEADERBOARD LEADER BONUS' : '${winner.label.toUpperCase()} WINNER',
              style: TextStyle(color: borderColor, fontSize: 11, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5),
            ),
          ]),
          const SizedBox(height: 10),
          Text(winner.userName,
              style: TextStyle(color: BmbColors.textPrimary, fontSize: 22, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: BmbColors.successGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('+${winner.creditsAwarded} credits',
                style: TextStyle(color: BmbColors.successGreen, fontSize: 16, fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
        Text(value, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONFETTI PARTICLES
  // ═══════════════════════════════════════════════════════════════

  List<Widget> _buildConfetti() {
    return _confettiParticles.map((particle) {
      final progress = _confettiController.value;
      final x = particle.startX + particle.dx * progress;
      final y = particle.startY + particle.dy * progress + 200 * progress * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: particle.rotation + progress * particle.rotationSpeed,
            child: Container(
              width: particle.size,
              height: particle.size * 0.5,
              decoration: BoxDecoration(
                color: particle.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _ConfettiParticle {
  final double startX;
  final double startY;
  final double dx;
  final double dy;
  final double rotation;
  final double rotationSpeed;
  final double size;
  final Color color;

  _ConfettiParticle(Random random)
      : startX = random.nextDouble() * 400,
        startY = random.nextDouble() * -100 + 100,
        dx = (random.nextDouble() - 0.5) * 300,
        dy = random.nextDouble() * -400 - 100,
        rotation = random.nextDouble() * 2 * pi,
        rotationSpeed = (random.nextDouble() - 0.5) * 10,
        size = random.nextDouble() * 8 + 4,
        color = [
          const Color(0xFFFFD700),
          const Color(0xFFFF4081),
          const Color(0xFF2196F3),
          const Color(0xFF4CAF50),
          const Color(0xFFFF9800),
          const Color(0xFF9C27B0),
          const Color(0xFFFFFFFF),
        ][random.nextInt(7)];
}
