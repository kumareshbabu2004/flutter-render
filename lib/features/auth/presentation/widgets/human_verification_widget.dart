import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';

/// A bracket-themed "Verify You're Human" challenge.
///
/// The user is presented with a mini 4-team bracket and asked
/// to drag the correct champion to the trophy slot.
/// Optionally a math question about seedings is also shown.
class HumanVerificationWidget extends StatefulWidget {
  final VoidCallback onVerified;
  final VoidCallback? onCancel;

  const HumanVerificationWidget({
    super.key,
    required this.onVerified,
    this.onCancel,
  });

  @override
  State<HumanVerificationWidget> createState() =>
      _HumanVerificationWidgetState();
}

class _HumanVerificationWidgetState extends State<HumanVerificationWidget>
    with TickerProviderStateMixin {
  // Challenge types
  static const int _challengeSeedMath = 0;
  static const int _challengeDragChamp = 1;
  static const int _challengeTapCorrect = 2;

  late int _challengeType;
  bool _verified = false;
  bool _failed = false;
  int _attempts = 0;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _successController;
  late Animation<double> _pulseAnim;
  late Animation<double> _successScale;

  // ── Seed Math challenge ──
  late int _seedA;
  late int _seedB;
  late int _correctSum;
  String _userAnswer = '';

  // ── Drag Champion challenge ──
  late List<String> _teams;
  late String _champion;
  String? _droppedTeam;

  // ── Tap Correct challenge ──
  late String _targetSport;
  late List<_SportIcon> _sportIcons;
  int? _tappedIndex;

  final _rng = Random();

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _successController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut));

    _generateChallenge();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _generateChallenge() {
    _challengeType = _rng.nextInt(3);
    _failed = false;
    _userAnswer = '';
    _droppedTeam = null;
    _tappedIndex = null;
    _mathOptionsCache = []; // BUG #15 FIX: Clear cache when generating new challenge

    switch (_challengeType) {
      case _challengeSeedMath:
        _seedA = _rng.nextInt(12) + 1;
        _seedB = _rng.nextInt(12) + 1;
        _correctSum = _seedA + _seedB;
        break;

      case _challengeDragChamp:
        final allTeams = [
          'Duke', 'UConn', 'Kansas', 'Kentucky', 'UNC', 'Gonzaga',
          'Villanova', 'Michigan', 'UCLA', 'Baylor', 'Auburn', 'Purdue',
          'Houston', 'Arizona', 'Tennessee', 'Alabama',
        ];
        allTeams.shuffle(_rng);
        _teams = allTeams.take(4).toList();
        _champion = _teams[_rng.nextInt(4)];
        break;

      case _challengeTapCorrect:
        _sportIcons = [
          _SportIcon('Basketball', Icons.sports_basketball, BmbColors.gold),
          _SportIcon('Football', Icons.sports_football, BmbColors.successGreen),
          _SportIcon('Baseball', Icons.sports_baseball, BmbColors.errorRed),
          _SportIcon('Soccer', Icons.sports_soccer, BmbColors.blue),
          _SportIcon('Hockey', Icons.sports_hockey, BmbColors.vipPurple),
          _SportIcon('Tennis', Icons.sports_tennis, BmbColors.goldLight),
        ];
        _sportIcons.shuffle(_rng);
        _sportIcons = _sportIcons.take(4).toList();
        _targetSport = _sportIcons[_rng.nextInt(4)].name;
        break;
    }
    if (mounted) setState(() {});
  }

  void _onSuccess() {
    setState(() => _verified = true);
    _pulseController.stop();
    _successController.forward();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onVerified();
    });
  }

  void _onFail() {
    _attempts++;
    setState(() => _failed = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _generateChallenge();
    });
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BmbColors.midNavy,
            BmbColors.deepNavy.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _verified
              ? BmbColors.successGreen
              : _failed
                  ? BmbColors.errorRed
                  : BmbColors.blue.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_verified
                    ? BmbColors.successGreen
                    : _failed
                        ? BmbColors.errorRed
                        : BmbColors.blue)
                .withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: _verified ? _buildSuccessState() : _buildChallengeContent(),
    );
  }

  Widget _buildSuccessState() {
    return ScaleTransition(
      scale: _successScale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [BmbColors.successGreen, BmbColors.buttonGlow],
              ),
              boxShadow: [
                BoxShadow(
                  color: BmbColors.successGreen.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text('Human Verified!',
              style: TextStyle(
                  color: BmbColors.successGreen,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
          const SizedBox(height: 4),
          Text('Welcome to the bracket.',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildChallengeContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                  scale: _pulseAnim.value, child: child),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [BmbColors.blue, BmbColors.vipPurple],
                  ),
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verify You\'re Human',
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 15,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay')),
                  Text('Complete this bracket challenge',
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
            if (widget.onCancel != null)
              IconButton(
                icon: const Icon(Icons.close, color: BmbColors.textTertiary, size: 20),
                onPressed: widget.onCancel,
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Divider
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                BmbColors.blue.withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Challenge body
        _buildChallenge(),
        // Fail feedback
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: BmbColors.errorRed, size: 16),
                const SizedBox(width: 6),
                Text('Incorrect — try again!',
                    style: TextStyle(
                        color: BmbColors.errorRed, fontSize: 12)),
              ],
            ),
          ),
        // Attempt counter
        if (_attempts > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Attempt ${_attempts + 1}',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 10)),
          ),
      ],
    );
  }

  Widget _buildChallenge() {
    switch (_challengeType) {
      case _challengeSeedMath:
        return _buildSeedMathChallenge();
      case _challengeDragChamp:
        return _buildDragChampionChallenge();
      case _challengeTapCorrect:
        return _buildTapSportChallenge();
      default:
        return _buildSeedMathChallenge();
    }
  }

  // ─── CHALLENGE 1: Seed Math ────────────────────────────────────────────
  Widget _buildSeedMathChallenge() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'If seed '),
              TextSpan(
                  text: '#$_seedA',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontWeight: BmbFontWeights.bold)),
              const TextSpan(text: ' plays seed '),
              TextSpan(
                  text: '#$_seedB',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontWeight: BmbFontWeights.bold)),
              const TextSpan(text: ',\nwhat is the sum of their seeds?'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Mini bracket visual
        _buildMiniBracketVisual(),
        const SizedBox(height: 16),
        // Answer row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final options = _generateMathOptions();
            final opt = options[i];
            final isSelected = _userAnswer == opt.toString();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _userAnswer = opt.toString());
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (opt == _correctSum) {
                      _onSuccess();
                    } else {
                      _onFail();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BmbColors.blue.withValues(alpha: 0.3)
                        : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? BmbColors.blue : BmbColors.borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text('$opt',
                        style: TextStyle(
                            color: isSelected
                                ? BmbColors.blue
                                : BmbColors.textPrimary,
                            fontSize: 16,
                            fontWeight: BmbFontWeights.bold)),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  List<int> _mathOptionsCache = [];
  List<int> _generateMathOptions() {
    if (_mathOptionsCache.isNotEmpty) return _mathOptionsCache;
    final options = <int>{_correctSum};
    while (options.length < 4) {
      final off = _rng.nextInt(7) - 3;
      final val = _correctSum + off;
      if (val > 0 && val != _correctSum) options.add(val);
      if (options.length < 4) {
        options.add(_correctSum + _rng.nextInt(5) + 1);
      }
    }
    _mathOptionsCache = options.take(4).toList()..shuffle(_rng);
    return _mathOptionsCache;
  }

  Widget _buildMiniBracketVisual() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _seedBox('#$_seedA', BmbColors.blue),
          const SizedBox(width: 8),
          Text('VS',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 14,
                  fontWeight: BmbFontWeights.bold)),
          const SizedBox(width: 8),
          _seedBox('#$_seedB', BmbColors.vipPurple),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: BmbColors.textTertiary, size: 16),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
            ),
            child: Text('? + ? = ?',
                style: TextStyle(
                    color: BmbColors.gold,
                    fontSize: 13,
                    fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  Widget _seedBox(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: BmbFontWeights.bold)),
    );
  }

  // ─── CHALLENGE 2: Drag Champion ────────────────────────────────────────
  Widget _buildDragChampionChallenge() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'Drag '),
              TextSpan(
                  text: _champion,
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontWeight: BmbFontWeights.bold)),
              const TextSpan(text: ' to the trophy to advance'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Team chips (draggable)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _teams.map((team) {
            if (_droppedTeam == team) {
              return Opacity(
                opacity: 0.3,
                child: _teamChip(team, false),
              );
            }
            return Draggable<String>(
              data: team,
              feedback: Material(
                color: Colors.transparent,
                child: _teamChip(team, true),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _teamChip(team, false),
              ),
              child: _teamChip(team, false),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Trophy drop zone
        DragTarget<String>(
          onAcceptWithDetails: (details) {
            setState(() => _droppedTeam = details.data);
            if (details.data == _champion) {
              _onSuccess();
            } else {
              _onFail();
            }
          },
          builder: (ctx, candidateData, rejectedData) {
            final hovering = candidateData.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              height: 64,
              decoration: BoxDecoration(
                color: hovering
                    ? BmbColors.gold.withValues(alpha: 0.2)
                    : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hovering
                      ? BmbColors.gold
                      : BmbColors.borderColor,
                  width: hovering ? 2 : 1,
                ),
                boxShadow: hovering
                    ? [
                        BoxShadow(
                          color: BmbColors.gold.withValues(alpha: 0.3),
                          blurRadius: 12,
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: hovering ? BmbColors.gold : BmbColors.textTertiary,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hovering ? 'Drop here!' : 'Champion',
                    style: TextStyle(
                      color: hovering ? BmbColors.gold : BmbColors.textTertiary,
                      fontSize: 11,
                      fontWeight: BmbFontWeights.semiBold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _teamChip(String team, bool isDragging) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: isDragging
            ? LinearGradient(colors: [BmbColors.blue, BmbColors.vipPurple])
            : null,
        color: isDragging ? null : BmbColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDragging ? BmbColors.gold : BmbColors.borderColor,
          width: isDragging ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [BoxShadow(color: BmbColors.blue.withValues(alpha: 0.4), blurRadius: 10)]
            : [],
      ),
      child: Text(team,
          style: TextStyle(
              color:
                  isDragging ? Colors.white : BmbColors.textPrimary,
              fontSize: 13,
              fontWeight: BmbFontWeights.semiBold)),
    );
  }

  // ─── CHALLENGE 3: Tap Correct Sport ────────────────────────────────────
  Widget _buildTapSportChallenge() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 13),
            children: [
              const TextSpan(text: 'Tap the '),
              TextSpan(
                  text: _targetSport,
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontWeight: BmbFontWeights.bold)),
              const TextSpan(text: ' icon'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_sportIcons.length, (i) {
            final sport = _sportIcons[i];
            final tapped = _tappedIndex == i;
            return GestureDetector(
              onTap: () {
                setState(() => _tappedIndex = i);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (sport.name == _targetSport) {
                    _onSuccess();
                  } else {
                    _onFail();
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: tapped
                      ? sport.color.withValues(alpha: 0.25)
                      : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tapped ? sport.color : BmbColors.borderColor,
                    width: tapped ? 2 : 1,
                  ),
                  boxShadow: tapped
                      ? [BoxShadow(color: sport.color.withValues(alpha: 0.3), blurRadius: 8)]
                      : [],
                ),
                child: Icon(sport.icon,
                    color: tapped ? sport.color : BmbColors.textSecondary,
                    size: 28),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SportIcon {
  final String name;
  final IconData icon;
  final Color color;
  const _SportIcon(this.name, this.icon, this.color);
}
