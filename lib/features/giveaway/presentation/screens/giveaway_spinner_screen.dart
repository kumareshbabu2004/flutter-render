import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/giveaway/data/services/giveaway_service.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';

/// Full-screen giveaway spinner with 2x / 1x prize structure.
///
/// Flow:
///  1. Shows bracket name + prize breakdown (2x for 1st, 1x for 2nd)
///  2. "Start Drawing" → spinner cycles names with deceleration
///  3. Lands on Winner #1 → "+{2x credits} credits (DOUBLE!)" celebration
///  4. Auto-chains to Winner #2 → "+{1x credits} credits"
///  5. If leaderboard leader exists → bonus award splash
///  6. Summary with all winners + "Post to BMB Community" button
///  7. Done → returns result + triggers auto community post
class GiveawaySpinnerScreen extends StatefulWidget {
  final CreatedBracket bracket;
  final List<Map<String, String>> participants; // [{id, name}]
  final int contributionAmount; // per-person contribution
  final String? leaderboardLeaderId;
  final String? leaderboardLeaderName;

  const GiveawaySpinnerScreen({
    super.key,
    required this.bracket,
    required this.participants,
    required this.contributionAmount,
    this.leaderboardLeaderId,
    this.leaderboardLeaderName,
  });

  @override
  State<GiveawaySpinnerScreen> createState() => _GiveawaySpinnerScreenState();
}

class _GiveawaySpinnerScreenState extends State<GiveawaySpinnerScreen>
    with TickerProviderStateMixin {
  // Drawing state
  bool _drawingStarted = false;
  bool _spinning = false;
  int _currentWinnerIndex = 0;
  String _displayedName = '';
  GiveawayResult? _result;
  bool _showSummary = false;
  bool _showLeaderBonus = false;
  bool _communityPosted = false;

  // Spin animation
  Timer? _spinTimer;
  int _spinIndex = 0;
  List<String> _spinSequence = [];
  int _spinSpeed = 50;

  // Celebration controllers
  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _celebrationScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_glowController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _celebrationController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  int get _firstPrize => widget.contributionAmount * 2;
  int get _secondPrize => widget.contributionAmount;
  int get _leaderBonus => GiveawayService.leaderboardBonus(widget.contributionAmount);

  Future<void> _startDrawing() async {
    final result = await GiveawayService.performDrawing(
      bracketId: widget.bracket.id,
      bracketName: widget.bracket.name,
      sport: widget.bracket.sport,
      participants: widget.participants,
      contributionAmount: widget.contributionAmount,
      leaderboardLeaderId: widget.leaderboardLeaderId,
      leaderboardLeaderName: widget.leaderboardLeaderName,
    );

    setState(() {
      _result = result;
      _drawingStarted = true;
      _currentWinnerIndex = 0;
    });

    _startSpinForWinner(0);
  }

  void _startSpinForWinner(int winnerIdx) {
    if (_result == null || winnerIdx >= _result!.winners.length) return;

    final winner = _result!.winners[winnerIdx];
    final allNames = widget.participants.map((p) => p['name'] ?? '').toList();

    final sequence = GiveawayService.generateSpinSequence(
      participantNames: allNames,
      winnerName: winner.userName,
      totalSpins: 3,
    );

    setState(() {
      _spinning = true;
      _spinSequence = sequence;
      _spinIndex = 0;
      _spinSpeed = 50;
      _currentWinnerIndex = winnerIdx;
    });

    _runSpin();
  }

  void _runSpin() {
    _spinTimer?.cancel();
    _spinTimer = Timer(Duration(milliseconds: _spinSpeed), () {
      if (_spinIndex >= _spinSequence.length - 1) {
        // Landed on winner
        setState(() {
          _displayedName = _spinSequence.last;
          _spinning = false;
        });
        _celebrationController.forward(from: 0);

        // After celebration, chain to next winner or show leader/summary
        Future.delayed(const Duration(seconds: 3), () {
          if (_currentWinnerIndex == 0 && _result!.winners.length > 1) {
            _startSpinForWinner(1);
          } else if (_result!.leaderboardLeader != null && !_showLeaderBonus) {
            setState(() => _showLeaderBonus = true);
            _celebrationController.forward(from: 0);
            Future.delayed(const Duration(seconds: 3), () {
              setState(() => _showSummary = true);
            });
          } else {
            setState(() => _showSummary = true);
          }
        });
        return;
      }

      setState(() {
        _displayedName = _spinSequence[_spinIndex];
        _spinIndex++;
      });

      // Decelerate in the last 30%
      final progress = _spinIndex / _spinSequence.length;
      if (progress > 0.7) {
        final deceleration = (progress - 0.7) / 0.3;
        _spinSpeed = 50 + (deceleration * 350).toInt();
      }

      _runSpin();
    });
  }

  Future<void> _postToCommunity() async {
    if (_result == null) return;
    // Generate community post data and store in shared prefs
    final postData = GiveawayService.generateCommunityPostData(_result!);
    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getStringList('giveaway_community_posts') ?? [];
    existingRaw.add(
      '${postData['summary']}',
    );
    await prefs.setStringList('giveaway_community_posts', existingRaw);

    // Also store structured post for community chat to pick up
    final splashPosts = prefs.getStringList('giveaway_splash_posts') ?? [];
    final postJson = <String, dynamic>{
      ...postData,
      'id': 'giveaway_${_result!.bracketId}_${DateTime.now().millisecondsSinceEpoch}',
      'postedAt': DateTime.now().toIso8601String(),
    };
    splashPosts.add(postJson.toString());
    await prefs.setStringList('giveaway_splash_posts', splashPosts);

    setState(() => _communityPosted = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.campaign, color: Colors.black, size: 18),
          const SizedBox(width: 8),
          const Expanded(child: Text('Giveaway winners posted to BMB Community!')),
        ]),
        backgroundColor: BmbColors.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: _showSummary
              ? _buildSummary()
              : _showLeaderBonus
                  ? _buildLeaderBonusSplash()
                  : _buildSpinner(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SPINNER SCREEN
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSpinner() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              if (!_drawingStarted)
                IconButton(
                  icon: const Icon(Icons.close, color: BmbColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              const Spacer(),
              Column(
                children: [
                  Text('GIVEAWAY DRAWING',
                      style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 12,
                        fontWeight: BmbFontWeights.bold,
                        letterSpacing: 2,
                      )),
                  const SizedBox(height: 2),
                  Text(widget.bracket.name,
                      style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.semiBold,
                      )),
                ],
              ),
              const Spacer(),
              if (!_drawingStarted) const SizedBox(width: 48),
            ],
          ),
        ),

        const Spacer(),

        // Pre-draw info badges — show prize structure
        if (!_drawingStarted) ...[
          _infoBadge(Icons.people, '${widget.participants.length} Participants'),
          const SizedBox(height: 8),
          _prizeStructureBadge(),
          const SizedBox(height: 8),
          _infoBadge(Icons.shuffle, 'All participants eligible \u2014 regardless of score'),
          const SizedBox(height: 40),
        ],

        // Winner number indicator with prize amount
        if (_drawingStarted) ...[
          Text(
            _currentWinnerIndex == 0 ? '1ST DRAW \u2014 DOUBLE' : '2ND DRAW',
            style: TextStyle(
              color: BmbColors.gold,
              fontSize: 14,
              fontWeight: BmbFontWeights.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentWinnerIndex == 0
                ? '+$_firstPrize credits (2x contribution)'
                : '+$_secondPrize credits (1x contribution)',
            style: TextStyle(
              color: BmbColors.successGreen,
              fontSize: 12,
              fontWeight: BmbFontWeights.semiBold,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Name display (spinning or result)
        if (_drawingStarted)
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              final isWinner = !_spinning && _displayedName.isNotEmpty;
              return Container(
                width: 300,
                height: 90,
                decoration: BoxDecoration(
                  gradient: isWinner
                      ? LinearGradient(
                          colors: [
                            BmbColors.gold.withValues(alpha: _glowAnimation.value * 0.3),
                            BmbColors.gold.withValues(alpha: _glowAnimation.value * 0.1),
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            BmbColors.cardGradientStart,
                            BmbColors.cardGradientEnd,
                          ],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isWinner
                        ? BmbColors.gold
                        : _spinning
                            ? BmbColors.blue.withValues(alpha: 0.5)
                            : BmbColors.borderColor,
                    width: isWinner ? 2.5 : 1,
                  ),
                  boxShadow: isWinner
                      ? [
                          BoxShadow(
                            color: BmbColors.gold.withValues(alpha: _glowAnimation.value * 0.5),
                            blurRadius: 30,
                            spreadRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _displayedName.isEmpty ? '?' : _displayedName,
                    style: TextStyle(
                      color: isWinner ? BmbColors.gold : BmbColors.textPrimary,
                      fontSize: isWinner ? 26 : 20,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),

        // Winner celebration with specific credits
        if (!_spinning && _drawingStarted && _displayedName.isNotEmpty)
          ScaleTransition(
            scale: _celebrationScale,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  const Icon(Icons.celebration, color: BmbColors.gold, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    _currentWinnerIndex == 0
                        ? '+$_firstPrize credits!'
                        : '+$_secondPrize credits!',
                    style: TextStyle(
                      color: BmbColors.successGreen,
                      fontSize: 24,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentWinnerIndex == 0 ? 'DOUBLE their contribution!' : 'Equal to their contribution!',
                    style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 12,
                      fontWeight: BmbFontWeights.semiBold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: BmbColors.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet, color: BmbColors.successGreen, size: 14),
                        const SizedBox(width: 6),
                        Text('Credited to BMB Bucket instantly',
                            style: TextStyle(color: BmbColors.successGreen, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        const Spacer(),

        // Start button
        if (!_drawingStarted)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startDrawing,
                icon: const Icon(Icons.shuffle, size: 22),
                label: Text('Start Drawing',
                    style: TextStyle(fontSize: 18, fontWeight: BmbFontWeights.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: BmbColors.gold.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEADERBOARD LEADER BONUS SPLASH
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLeaderBonusSplash() {
    final leader = _result?.leaderboardLeader;
    if (leader == null) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _celebrationScale,
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BmbColors.blue, const Color(0xFF5B8DEF)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: BmbColors.blue.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.leaderboard, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text('LEADERBOARD LEADER',
                  style: TextStyle(
                    color: BmbColors.blue,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 3,
                  )),
              const SizedBox(height: 4),
              Text('BONUS AWARD',
                  style: TextStyle(
                    color: BmbColors.gold,
                    fontSize: 12,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 24),
              Text(leader.userName,
                  style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 28,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                  )),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        BmbColors.successGreen.withValues(alpha: 0.2),
                        BmbColors.successGreen.withValues(alpha: 0.1),
                      ]),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: BmbColors.successGreen),
                    ),
                    child: Text('+${leader.creditsAwarded} credits',
                        style: TextStyle(
                          color: BmbColors.successGreen,
                          fontSize: 22,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay',
                        )),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('For leading the bracket!',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet, color: BmbColors.successGreen, size: 14),
                    const SizedBox(width: 6),
                    Text('Credited to BMB Bucket instantly',
                        style: TextStyle(color: BmbColors.successGreen, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SUMMARY SCREEN
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSummary() {
    if (_result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.celebration, color: BmbColors.gold, size: 56),
          const SizedBox(height: 12),
          Text('GIVEAWAY COMPLETE',
              style: TextStyle(
                color: BmbColors.gold,
                fontSize: 20,
                fontWeight: BmbFontWeights.bold,
                letterSpacing: 2,
                fontFamily: 'ClashDisplay',
              )),
          const SizedBox(height: 4),
          Text(widget.bracket.name,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),

          // Winner cards
          ...List.generate(_result!.winners.length, (i) {
            final winner = _result!.winners[i];
            final isFirst = i == 0;
            return _buildWinnerCard(
              place: isFirst ? '1ST DRAW \u2014 DOUBLE' : '2ND DRAW',
              winner: winner,
              icon: isFirst ? Icons.looks_one : Icons.looks_two,
              gradientColors: isFirst
                  ? [BmbColors.gold.withValues(alpha: 0.2), BmbColors.gold.withValues(alpha: 0.08)]
                  : [BmbColors.blue.withValues(alpha: 0.15), BmbColors.blue.withValues(alpha: 0.05)],
              borderColor: isFirst ? BmbColors.gold : BmbColors.blue,
              labelColor: isFirst ? BmbColors.gold : BmbColors.blue,
            );
          }),

          // Leaderboard leader card
          if (_result!.leaderboardLeader != null)
            _buildWinnerCard(
              place: 'LEADERBOARD LEADER BONUS',
              winner: _result!.leaderboardLeader!,
              icon: Icons.leaderboard,
              gradientColors: [
                const Color(0xFF5B8DEF).withValues(alpha: 0.15),
                const Color(0xFF5B8DEF).withValues(alpha: 0.05),
              ],
              borderColor: BmbColors.blue,
              labelColor: BmbColors.blue,
            ),

          const SizedBox(height: 16),

          // Stats
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
                _summaryRow('Total Participants', '${_result!.totalParticipants}'),
                const Divider(color: BmbColors.borderColor, height: 20),
                _summaryRow('Contribution Per Person', '${_result!.contributionAmount} credits'),
                const Divider(color: BmbColors.borderColor, height: 20),
                _summaryRow('1st Draw Prize', '$_firstPrize credits (2x)'),
                const Divider(color: BmbColors.borderColor, height: 20),
                _summaryRow('2nd Draw Prize', '$_secondPrize credits (1x)'),
                if (_result!.leaderboardLeader != null) ...[
                  const Divider(color: BmbColors.borderColor, height: 20),
                  _summaryRow('Leader Bonus', '$_leaderBonus credits'),
                ],
                const Divider(color: BmbColors.borderColor, height: 20),
                _summaryRow('Total Credits Awarded', '${_result!.totalCreditsAwarded} credits'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: BmbColors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is a promotional giveaway. Winners were selected at random from all participants regardless of bracket score. Credits deposited instantly.',
                    style: TextStyle(color: BmbColors.blue, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // POST TO BMB COMMUNITY button — big splash!
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _communityPosted ? null : _postToCommunity,
              icon: Icon(_communityPosted ? Icons.check_circle : Icons.campaign, size: 22),
              label: Text(
                _communityPosted ? 'Posted to BMB Community!' : 'Post to BMB Community',
                style: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _communityPosted
                    ? BmbColors.successGreen
                    : BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: _communityPosted ? 0 : 4,
                shadowColor: BmbColors.gold.withValues(alpha: 0.4),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Ticker note
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

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _result),
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
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWinnerCard({
    required String place,
    required GiveawayWinner winner,
    required IconData icon,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color labelColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: borderColor.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: labelColor, size: 18),
              const SizedBox(width: 6),
              Text(place,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Text(winner.userName,
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 22,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: BmbColors.successGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('+${winner.creditsAwarded} credits',
                style: TextStyle(
                  color: BmbColors.successGreen,
                  fontSize: 16,
                  fontWeight: BmbFontWeights.bold,
                )),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet, color: BmbColors.successGreen, size: 12),
              const SizedBox(width: 4),
              Text('Deposited to BMB Bucket',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prizeStructureBadge() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.12),
          BmbColors.gold.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('PRIZE STRUCTURE', style: TextStyle(
            color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _prizeRow('1st Draw', '$_firstPrize credits', '2x contribution'),
          const SizedBox(height: 4),
          _prizeRow('2nd Draw', '$_secondPrize credits', '1x contribution'),
          if (widget.leaderboardLeaderName != null) ...[
            const SizedBox(height: 4),
            _prizeRow('Leader Bonus', '$_leaderBonus credits', 'Leaderboard #1'),
          ],
        ],
      ),
    );
  }

  Widget _prizeRow(String label, String amount, String detail) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label,
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 11))),
        Expanded(
          child: Text(amount,
              style: TextStyle(
                color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
        ),
        Text(detail, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
      ],
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: BmbColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
        Text(value,
            style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 14,
              fontWeight: BmbFontWeights.bold,
            )),
      ],
    );
  }
}
