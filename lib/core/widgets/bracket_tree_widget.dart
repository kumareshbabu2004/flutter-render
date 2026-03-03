import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/data/team_logos.dart';

/// Premium tournament bracket tree widget — traditional left/right/center layout
/// with intelligent auto-zoom to the active round and celebration animations.
///
/// Features:
/// - Traditional bracket layout: left rounds → center FINAL ← right rounds
/// - Dynamic round labels: "ROUND 1 (L)", "ROUND 2 (L)", … "FINAL" … "ROUND 2 (R)", "ROUND 1 (R)"
/// - AUTO-ZOOM: zooms into the round currently being picked
///   Sequence: L-RD1 → R-RD1 → L-RD2 → R-RD2 → … → Finals → Champion
/// - Pick celebration: starburst flash + team name scale-up on selection
/// - Pulsing glow on matchups awaiting picks in the active round
/// - InteractiveViewer with pan/zoom (pinch on mobile, scroll-wheel on web)
/// - Connector lines with L-shaped bracket connectors
/// - League branding logo (decorative) near trophy
/// - Works for any power-of-two bracket size (4, 8, 16, 32, 64+)
///
/// PRESENTATION ONLY — no data model, API, scoring, or pick-logic changes.
class BracketTreeWidget extends StatefulWidget {
  final List<String> teams;
  final int totalRounds;
  final Map<String, String> picks;
  final void Function(int round, int matchIndex, String team)? onPick;
  final bool submitted;
  final Map<String, GameResult>? results;
  final bool showScoring;
  final int? scorePct;
  final ScrollController? horizontalScrollController;
  final String? sport;

  const BracketTreeWidget({
    super.key,
    required this.teams,
    required this.totalRounds,
    this.picks = const {},
    this.onPick,
    this.submitted = false,
    this.results,
    this.showScoring = false,
    this.scorePct,
    this.horizontalScrollController,
    this.sport,
  });

  @override
  State<BracketTreeWidget> createState() => _BracketTreeWidgetState();
}

class _BracketTreeWidgetState extends State<BracketTreeWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final TransformationController _transformCtrl = TransformationController();
  AnimationController? _zoomAnimCtrl;
  bool _initialZoomDone = false;

  /// True while a programmatic zoom animation is running — prevents
  /// InteractiveViewer interaction callbacks from cancelling the animation.
  bool _isAutoZooming = false;

  // Celebration overlay state
  _CelebrationData? _celebration;
  AnimationController? _celebrationCtrl;

  // Track previous picks map snapshot for detecting ANY change (not just count)
  Map<String, String> _prevPicks = const {};
  String? _lastPickedGid;

  // Cached layout values
  double _totalW = 0;
  double _totalH = 0;
  int _leftCols = 0;
  int _rightCols = 0;
  _BracketSides? _cachedSides;
  int _cachedLeftFirstCount = 0;
  int _cachedRightFirstCount = 0;
  int _cachedMaxFirst = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _prevPicks = Map<String, String>.from(widget.picks);
  }

  @override
  void didUpdateWidget(covariant BracketTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Compare full picks maps to detect ANY change (additions, removals, or
    // modifications — covers downstream clears after pick change).
    final bool picksChanged = !_mapsEqual(widget.picks, _prevPicks);

    if (picksChanged) {
      // Identify the newly added game ID for celebration
      String? newGid;
      for (final key in widget.picks.keys) {
        if (!_prevPicks.containsKey(key) ||
            _prevPicks[key] != widget.picks[key]) {
          newGid = key;
          // Prefer newly-added keys over changed ones
          if (!_prevPicks.containsKey(key)) break;
        }
      }
      _lastPickedGid = newGid;
      _prevPicks = Map<String, String>.from(widget.picks);

      if (kDebugMode) {
        debugPrint('[BMB-ZOOM] didUpdateWidget: PICKS CHANGED. total=${widget.picks.length}, lastGid=$_lastPickedGid');
      }

      // After widget rebuilds with new picks, trigger celebration + auto-zoom.
      // The addPostFrameCallback ensures build() has run and _cachedSides is
      // up to date before we calculate the next zoom target.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_lastPickedGid != null) {
          _playCelebration(_lastPickedGid!);
        }
        // Auto-zoom to next active round after a short celebration window
        Future.delayed(const Duration(milliseconds: 650), () {
          if (mounted) {
            _zoomToActiveRound();
          }
        });
      });
    }
  }

  /// Deep comparison of two String→String maps.
  static bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _zoomAnimCtrl?.dispose();
    _celebrationCtrl?.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  // ─── LAYOUT CONSTANTS ──────────────────────────────────────
  static const double _cellW = 155;
  static const double _cellH = 40;
  static const double _matchGap = 2;
  static const double _connW = 34;
  static const double _champW = 155;
  static const double _champH = 150;
  static const double _headerH = 30;
  static const double _vPad = 20;
  static const double _hPad = 16;
  static const double _firstRoundVGap = 10;
  static const double _champToFinalsGap = 12;

  double get _matchH => _cellH * 2 + _matchGap;

  // ─── ROUND LABEL GENERATION ─────────────────────────────────
  String _leftRoundLabel(int colIndex, int totalLeftCols) {
    return 'ROUND ${colIndex + 1} (L)';
  }

  String _rightRoundLabel(int colIndex, int totalRightCols) {
    return 'ROUND ${colIndex + 1} (R)';
  }

  // ─── SPORT-SPECIFIC TEAM COLORS (PRESERVED EXACTLY) ────────
  static final Map<String, Color> _teamColors = {
    'chiefs': const Color(0xFFE31837), 'eagles': const Color(0xFF004C54),
    '49ers': const Color(0xFFAA0000), 'ravens': const Color(0xFF241773),
    'cowboys': const Color(0xFF003594), 'lions': const Color(0xFF0076B6),
    'bills': const Color(0xFF00338D), 'dolphins': const Color(0xFF008E97),
    'packers': const Color(0xFF203731), 'texans': const Color(0xFF03202F),
    'lakers': const Color(0xFF552583), 'celtics': const Color(0xFF007A33),
    'warriors': const Color(0xFF1D428A), 'nuggets': const Color(0xFF0E2240),
    'heat': const Color(0xFF98002E), 'bucks': const Color(0xFF00471B),
    '76ers': const Color(0xFF006BB6), 'suns': const Color(0xFF1D1160),
    'uconn': const Color(0xFF000E2F), 'duke': const Color(0xFF003087),
    'alabama': const Color(0xFF9E1B32), 'ohio state': const Color(0xFFBB0000),
    'clemson': const Color(0xFFF56600), 'baylor': const Color(0xFF154734),
    'arizona': const Color(0xFFCC0033), 'indiana': const Color(0xFF990000),
    'oregon': const Color(0xFF154733), 'texas tech': const Color(0xFFCC0000),
    'georgia': const Color(0xFFBA0C2F), 'ole miss': const Color(0xFF14213D),
    'tulane': const Color(0xFF006747), 'miami': const Color(0xFFF47321),
    'texas a&m': const Color(0xFF500000), 'oklahoma': const Color(0xFF841617),
    'james madison': const Color(0xFF450084), 'memphis': const Color(0xFF003087),
    'fau': const Color(0xFFCC0000), 'san diego st': const Color(0xFFCC0000),
    'charleston': const Color(0xFF800000), 'new mexico': const Color(0xFFBA0C2F),
    'colgate': const Color(0xFF821019), 'missouri': const Color(0xFFF1B82D),
    'utah st': const Color(0xFF0F2439), 'long beach st': const Color(0xFF000000),
    'stetson': const Color(0xFF006747), 'uab': const Color(0xFF1E6B52),
    'yankees': const Color(0xFF003087), 'dodgers': const Color(0xFF005A9C),
    'astros': const Color(0xFFEB6E1F), 'braves': const Color(0xFFCE1141),
    'rangers': const Color(0xFF003278), 'phillies': const Color(0xFFE81828),
    'diamondbacks': const Color(0xFFA71930), 'twins': const Color(0xFF002B5C),
    'rays': const Color(0xFF092C5C),
    'panthers': const Color(0xFF041E42), 'oilers': const Color(0xFFFF4C00),
    'avalanche': const Color(0xFF6F263D), 'bruins': const Color(0xFFFFB81C),
    'hurricanes': const Color(0xFFCC0000), 'canucks': const Color(0xFF00205B),
    'stars': const Color(0xFF006847),
    'inter miami': const Color(0xFFF7B5CD), 'lafc': const Color(0xFFC39E6D),
    'columbus': const Color(0xFFFEE11A), 'cincinnati': const Color(0xFFF05323),
    'atlanta': const Color(0xFF80000A), 'seattle': const Color(0xFF5D9741),
    'nashville': const Color(0xFFECE83A), 'houston': const Color(0xFFF68712),
    'scheffler': const Color(0xFF2E86AB), 'mcilroy': const Color(0xFF1B4332),
    'hovland': const Color(0xFFBA181B), 'rahm': const Color(0xFFFFB703),
    'dechambeau': const Color(0xFF023047), 'clark': const Color(0xFF3A0CA3),
    'thomas': const Color(0xFF780000), 'spieth': const Color(0xFF003566),
  };

  Color _getTeamColor(String team) {
    final lower = _cleanName(team).toLowerCase();
    if (_teamColors.containsKey(lower)) return _teamColors[lower]!;
    for (final entry in _teamColors.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    final hash = lower.hashCode;
    return HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.65, 0.38).toColor();
  }

  String _cleanName(String team) =>
      team.replaceAll(RegExp(r'^\(\d+\)\s*'), '').trim();

  int? _parseSeed(String team) {
    final match = RegExp(r'^\((\d+)\)').firstMatch(team);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  String _getInitials(String team) {
    final clean = _cleanName(team);
    if (clean.isEmpty || clean == 'TBD') return '?';
    final words = clean.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return clean.length >= 2
        ? clean.substring(0, 2).toUpperCase()
        : clean[0].toUpperCase();
  }

  // ─── LEAGUE LOGO URL (decorative) ──────────────────────────
  String? _leagueLogoUrl() {
    final sport = widget.sport?.toLowerCase();
    if (sport == null) return null;
    if (sport.contains('nfl') || sport.contains('football')) {
      return 'https://a.espncdn.com/i/teamlogos/leagues/500/nfl.png';
    }
    if (sport.contains('nba') || sport.contains('basketball')) {
      return 'https://a.espncdn.com/i/teamlogos/leagues/500/nba.png';
    }
    if (sport.contains('nhl') || sport.contains('hockey')) {
      return 'https://a.espncdn.com/i/teamlogos/leagues/500/nhl.png';
    }
    if (sport.contains('mlb') || sport.contains('baseball')) {
      return 'https://a.espncdn.com/i/teamlogos/leagues/500/mlb.png';
    }
    if (sport.contains('ncaa') || sport.contains('march madness') || sport.contains('college')) {
      return 'https://a.espncdn.com/i/teamlogos/ncaa/500/2000.png';
    }
    if (sport.contains('mls') || sport.contains('soccer')) {
      return 'https://a.espncdn.com/i/teamlogos/leagues/500/mls.png';
    }
    return null;
  }

  // ─── BUILD BRACKET DATA (PRESERVED EXACTLY) ────────────────
  List<List<_Matchup>> _buildRounds() {
    final rounds = <List<_Matchup>>[];
    var currentTeams = List<String>.from(widget.teams);

    for (int r = 0; r < widget.totalRounds; r++) {
      final matchups = <_Matchup>[];
      final next = <String>[];
      for (int m = 0; m < currentTeams.length; m += 2) {
        final t1 = m < currentTeams.length ? currentTeams[m] : 'TBD';
        final t2 = (m + 1) < currentTeams.length ? currentTeams[m + 1] : 'TBD';
        final gid = 'r${r}_g${m ~/ 2}';
        final pick = widget.picks[gid];
        matchups.add(_Matchup(
            t1: t1, t2: t2, gid: gid, round: r, idx: m ~/ 2, pick: pick));
        next.add(pick ?? 'TBD');
      }
      rounds.add(matchups);
      currentTeams = next;
    }
    return rounds;
  }

  // ─── SPLIT ROUNDS INTO LEFT / RIGHT HALVES (PRESERVED) ─────
  _BracketSides _splitBracket(List<List<_Matchup>> rounds) {
    if (rounds.isEmpty) return _BracketSides(left: [], right: [], finals: null);

    final leftRounds = <List<_Matchup>>[];
    final rightRounds = <List<_Matchup>>[];
    _Matchup? finalMatchup;

    for (int ri = 0; ri < rounds.length; ri++) {
      final ms = rounds[ri];
      if (ms.length == 1) {
        finalMatchup = ms[0];
      } else {
        final half = ms.length ~/ 2;
        leftRounds.add(ms.sublist(0, half));
        rightRounds.add(ms.sublist(half));
      }
    }
    return _BracketSides(
      left: leftRounds,
      right: rightRounds,
      finals: finalMatchup,
    );
  }

  // ─── VERTICAL Y FOR A MATCHUP (recursive centering) ────────
  double _sideMatchY(int matchIndex, int colIndex, int firstRoundCount) {
    if (firstRoundCount == 0) return _headerH + _vPad;
    if (colIndex == 0) {
      return _headerH + _vPad + matchIndex * (_matchH + _firstRoundVGap);
    }
    final prevTop = _sideMatchY(matchIndex * 2, colIndex - 1, firstRoundCount);
    final prevBot = _sideMatchY(matchIndex * 2 + 1, colIndex - 1, firstRoundCount);
    return (prevTop + prevBot) / 2;
  }

  // ─── CANVAS DIMENSIONS ─────────────────────────────────────
  double _bracketContentHeight(int maxFirstRoundCount) {
    if (maxFirstRoundCount == 0) return 400;
    return _headerH + _vPad * 2 +
        maxFirstRoundCount * _matchH +
        (maxFirstRoundCount - 1) * _firstRoundVGap;
  }

  double get _centerColW => math.max(_champW, _cellW);

  double _totalWidth(int leftCols, int rightCols) {
    final leftW = leftCols * (_cellW + _connW);
    final rightW = rightCols * (_cellW + _connW);
    final centerW = _centerColW + _connW * 2;
    return _hPad * 2 + leftW + centerW + rightW;
  }

  // ─── COLUMN X POSITIONS ─────────────────────────────────────
  double _leftColX(int colIndex) {
    return _hPad + colIndex * (_cellW + _connW);
  }

  double _centerColX(int leftCols) {
    return _hPad + leftCols * (_cellW + _connW) + _connW;
  }

  double _rightColX(int colIndex, int leftCols, int rightCols) {
    final centerRight = _centerColX(leftCols) + _centerColW + _connW;
    return centerRight + (rightCols - 1 - colIndex) * (_cellW + _connW);
  }

  // ─── CENTER POSITIONS (champion above, finals below) ────────
  double _finalsY(int maxFirst) {
    final h = math.max(_bracketContentHeight(maxFirst), 400.0);
    final centerBlockH = _champH + _champToFinalsGap + _matchH;
    return (h - centerBlockH) / 2 + _champH + _champToFinalsGap;
  }

  double _champY(int maxFirst) {
    return _finalsY(maxFirst) - _champToFinalsGap - _champH;
  }

  double _finalsMatchX(int leftCols) {
    return _centerColX(leftCols) + (_centerColW - _cellW) / 2;
  }

  double _champBoxX(int leftCols) {
    return _centerColX(leftCols) + (_centerColW - _champW) / 2;
  }

  // ═══════════════════════════════════════════════════════════════
  // ACTIVE ROUND DETECTION
  // ═══════════════════════════════════════════════════════════════

  /// Finds the next focus target for auto-zoom.
  /// Sequence: L-RD0 → R-RD0 → L-RD1 → R-RD1 → … → Finals → Champion
  /// Returns null if all picks are complete or widget is read-only.
  _ZoomTarget? _findNextZoomTarget() {
    if (widget.submitted || widget.onPick == null) return null;
    if (_cachedSides == null) return null;

    final sides = _cachedSides!;

    // Check each round index, alternating left then right
    final numSideRounds = math.max(sides.left.length, sides.right.length);
    for (int ri = 0; ri < numSideRounds; ri++) {
      // Check LEFT side first
      if (ri < sides.left.length) {
        final leftMatchups = sides.left[ri];
        final unpicked = <int>[];
        for (int mi = 0; mi < leftMatchups.length; mi++) {
          final m = leftMatchups[mi];
          if (m.pick == null && m.t1 != 'TBD' && m.t2 != 'TBD') {
            unpicked.add(mi);
          }
        }
        if (unpicked.isNotEmpty) {
          return _ZoomTarget(
            side: _Side.left,
            roundIndex: ri,
            matchIndices: unpicked,
            allMatchups: leftMatchups,
          );
        }
      }

      // Then check RIGHT side
      if (ri < sides.right.length) {
        final rightMatchups = sides.right[ri];
        final unpicked = <int>[];
        for (int mi = 0; mi < rightMatchups.length; mi++) {
          final m = rightMatchups[mi];
          if (m.pick == null && m.t1 != 'TBD' && m.t2 != 'TBD') {
            unpicked.add(mi);
          }
        }
        if (unpicked.isNotEmpty) {
          return _ZoomTarget(
            side: _Side.right,
            roundIndex: ri,
            matchIndices: unpicked,
            allMatchups: rightMatchups,
          );
        }
      }
    }

    // Check FINALS
    if (sides.finals != null) {
      final f = sides.finals!;
      if (f.pick == null && f.t1 != 'TBD' && f.t2 != 'TBD') {
        return _ZoomTarget(
          side: _Side.finals,
          roundIndex: 0,
          matchIndices: [0],
          allMatchups: [f],
        );
      }
    }

    return null; // All picks made
  }

  /// Returns the set of game IDs that are in the "active" round (awaiting picks).
  Set<String> _activeMatchGids() {
    final target = _findNextZoomTarget();
    if (target == null) return {};
    return target.allMatchups
        .where((m) => m.pick == null && m.t1 != 'TBD' && m.t2 != 'TBD')
        .map((m) => m.gid)
        .toSet();
  }

  // ═══════════════════════════════════════════════════════════════
  // AUTO-ZOOM TO ACTIVE ROUND
  // ═══════════════════════════════════════════════════════════════

  void _zoomToActiveRound({bool isInitial = false}) {
    final target = _findNextZoomTarget();
    if (kDebugMode) {
      debugPrint('[BMB-ZOOM] _zoomToActiveRound called. isInitial=$isInitial, target=${target?.side}:${target?.roundIndex}, matchIndices=${target?.matchIndices}');
    }

    if (target == null) {
      // All picks done — zoom to champion
      _animateToRegion(
        _champBoxX(_leftCols),
        _champY(_cachedMaxFirst),
        _champW,
        _champH + _champToFinalsGap + _matchH + 40,
        duration: isInitial ? 800 : 500,
      );
      return;
    }

    // Calculate bounding box for the target matchups
    double minY = double.infinity;
    double maxY = 0;
    double colX = 0;

    if (target.side == _Side.left) {
      colX = _leftColX(target.roundIndex);
      for (final mi in target.matchIndices) {
        final y = _sideMatchY(mi, target.roundIndex, _cachedLeftFirstCount);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y + _matchH);
      }
    } else if (target.side == _Side.right) {
      colX = _rightColX(target.roundIndex, _leftCols, _rightCols);
      for (final mi in target.matchIndices) {
        final y = _sideMatchY(mi, target.roundIndex, _cachedRightFirstCount);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y + _matchH);
      }
    } else {
      // Finals
      colX = _finalsMatchX(_leftCols);
      minY = _finalsY(_cachedMaxFirst);
      maxY = minY + _matchH;
    }

    // Add some padding around the target region
    final padX = 30.0;
    final padY = 50.0;
    final regionX = colX - padX;
    final regionY = minY - padY - _headerH;
    final regionW = _cellW + padX * 2;
    final regionH = (maxY - minY) + padY * 2 + _headerH;

    _animateToRegion(
      regionX,
      regionY,
      regionW,
      regionH,
      duration: isInitial ? 1000 : 500,
    );
  }

  /// Smoothly animate the transform to center and zoom a region of the bracket canvas.
  void _animateToRegion(double regionX, double regionY, double regionW, double regionH,
      {int duration = 500}) {
    if (!mounted) return;
    if (kDebugMode) {
      debugPrint('[BMB-ZOOM] _animateToRegion: x=$regionX, y=$regionY, w=$regionW, h=$regionH, dur=$duration');
    }

    // Get viewport size
    final ctx = context;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final viewW = renderBox.size.width;
    final viewH = renderBox.size.height;

    // Calculate scale to fit the region in the viewport
    final scaleX = viewW / regionW;
    final scaleY = viewH / regionH;
    final targetScale = math.min(scaleX, scaleY).clamp(0.5, 2.5);

    // Calculate translation to center the region
    final regionCenterX = regionX + regionW / 2;
    final regionCenterY = regionY + regionH / 2;
    final targetDx = viewW / 2 - regionCenterX * targetScale;
    final targetDy = viewH / 2 - regionCenterY * targetScale;

    // Get current transform values
    final currentMatrix = _transformCtrl.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final currentDx = currentMatrix.getTranslation().x;
    final currentDy = currentMatrix.getTranslation().y;

    // Animate — set _isAutoZooming so InteractiveViewer interaction
    // callbacks don't cancel this programmatic animation.
    _zoomAnimCtrl?.stop();
    _zoomAnimCtrl?.dispose();
    _isAutoZooming = true;

    _zoomAnimCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration),
    );

    final curved = CurvedAnimation(
      parent: _zoomAnimCtrl!,
      curve: Curves.easeInOutCubic,
    );

    curved.addListener(() {
      if (!mounted) return;
      final t = curved.value;
      final dx = currentDx + (targetDx - currentDx) * t;
      final dy = currentDy + (targetDy - currentDy) * t;
      final scale = currentScale + (targetScale - currentScale) * t;
      _transformCtrl.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
    });

    _zoomAnimCtrl!.forward().then((_) {
      if (mounted) {
        _isAutoZooming = false;
        if (kDebugMode) {
          debugPrint('[BMB-ZOOM] Animation complete.');
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // CELEBRATION ANIMATION
  // ═══════════════════════════════════════════════════════════════

  void _playCelebration(String gid) {
    if (_cachedSides == null) return;

    // Find the matchup position for the just-picked game
    _Matchup? pickedMatchup;
    double matchX = 0, matchY = 0;

    // Search left side
    final sides = _cachedSides!;
    for (int ci = 0; ci < sides.left.length; ci++) {
      for (int mi = 0; mi < sides.left[ci].length; mi++) {
        if (sides.left[ci][mi].gid == gid) {
          pickedMatchup = sides.left[ci][mi];
          matchX = _leftColX(ci);
          matchY = _sideMatchY(mi, ci, _cachedLeftFirstCount);
          break;
        }
      }
      if (pickedMatchup != null) break;
    }

    // Search right side
    if (pickedMatchup == null) {
      for (int ci = 0; ci < sides.right.length; ci++) {
        for (int mi = 0; mi < sides.right[ci].length; mi++) {
          if (sides.right[ci][mi].gid == gid) {
            pickedMatchup = sides.right[ci][mi];
            matchX = _rightColX(ci, _leftCols, _rightCols);
            matchY = _sideMatchY(mi, ci, _cachedRightFirstCount);
            break;
          }
        }
        if (pickedMatchup != null) break;
      }
    }

    // Search finals
    if (pickedMatchup == null && sides.finals?.gid == gid) {
      pickedMatchup = sides.finals;
      matchX = _finalsMatchX(_leftCols);
      matchY = _finalsY(_cachedMaxFirst);
    }

    if (pickedMatchup == null) return;

    _celebrationCtrl?.dispose();
    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    setState(() {
      _celebration = _CelebrationData(
        x: matchX + _cellW / 2,
        y: matchY + _matchH / 2,
        teamName: _cleanName(pickedMatchup!.pick ?? ''),
        teamColor: _getTeamColor(pickedMatchup.pick ?? 'TBD'),
      );
    });

    _celebrationCtrl!.forward().then((_) {
      if (mounted) {
        setState(() => _celebration = null);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // MAIN BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final rounds = _buildRounds();
    if (rounds.isEmpty) return const SizedBox();

    final sides = _splitBracket(rounds);
    _cachedSides = sides;
    _leftCols = sides.left.length;
    _rightCols = sides.right.length;

    final leftFirstCount = sides.left.isNotEmpty ? sides.left[0].length : 0;
    final rightFirstCount = sides.right.isNotEmpty ? sides.right[0].length : 0;
    final maxFirst = math.max(leftFirstCount, rightFirstCount);
    _cachedLeftFirstCount = leftFirstCount;
    _cachedRightFirstCount = rightFirstCount;
    _cachedMaxFirst = maxFirst;

    _totalH = math.max(_bracketContentHeight(maxFirst), 400.0);
    _totalW = math.max(_totalWidth(_leftCols, _rightCols), 500.0);

    final activeGids = _activeMatchGids();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Trigger initial zoom on first build
        if (!_initialZoomDone) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_initialZoomDone && mounted) {
              _initialZoomDone = true;
              _zoomToActiveRound(isInitial: true);
            }
          });
        }

        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              // Manual scroll wheel — stop any auto-zoom in progress
              if (!_isAutoZooming) {
                _zoomAnimCtrl?.stop();
              }
              final currentScale = _transformCtrl.value.getMaxScaleOnAxis();
              final delta = event.scrollDelta.dy > 0 ? 0.92 : 1.08;
              final newScale = (currentScale * delta).clamp(0.15, 3.0);
              final fp = event.localPosition;
              final matrix = _transformCtrl.value.clone();
              matrix.translateByDouble(fp.dx, fp.dy, 0, 1);
              matrix.scaleByDouble(newScale / currentScale, newScale / currentScale, newScale / currentScale, 1);
              matrix.translateByDouble(-fp.dx, -fp.dy, 0, 1);
              _transformCtrl.value = matrix;
            }
          },
          child: GestureDetector(
            // Double-tap to re-engage auto-zoom manually
            onDoubleTap: () {
              _zoomToActiveRound();
            },
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 0.1,
              maxScale: 3.5,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(500),
              // Only stop auto-zoom for genuine user pan/pinch
              // (not when tapping a team cell which triggers _isAutoZooming)
              onInteractionStart: (_) {
                if (!_isAutoZooming) {
                  _zoomAnimCtrl?.stop();
                }
              },
              child: SizedBox(
                width: _totalW,
                height: _totalH,
                child: CustomPaint(
                  painter: _TournamentConnectorPainter(
                    sides: sides,
                    picks: widget.picks,
                    cellW: _cellW,
                    cellH: _cellH,
                    matchGap: _matchGap,
                    connW: _connW,
                    champW: _champW,
                    champH: _champH,
                    headerH: _headerH,
                    vPad: _vPad,
                    hPad: _hPad,
                    firstRoundVGap: _firstRoundVGap,
                    matchH: _matchH,
                    leftCols: _leftCols,
                    rightCols: _rightCols,
                    leftFirstCount: leftFirstCount,
                    rightFirstCount: rightFirstCount,
                    centerColW: _centerColW,
                    champToFinalsGap: _champToFinalsGap,
                  ),
                  child: Stack(
                    children: [
                      // Round headers
                      ..._buildHeaders(sides, maxFirst),
                      // Left side matchup cells
                      ..._buildSideCells(sides.left, isLeft: true,
                          firstCount: leftFirstCount, activeGids: activeGids),
                      // Right side matchup cells
                      ..._buildSideCells(sides.right, isLeft: false,
                          firstCount: rightFirstCount, activeGids: activeGids),
                      // Finals matchup
                      if (sides.finals != null)
                        ..._buildFinalsCell(sides.finals!, maxFirst, activeGids: activeGids),
                      // Champion display
                      _buildChampion(rounds, maxFirst),
                      // League branding logo
                      _buildLeagueLogo(maxFirst),
                      // Celebration overlay
                      if (_celebration != null && _celebrationCtrl != null)
                        _buildCelebrationOverlay(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── CELEBRATION OVERLAY ─────────────────────────────────────
  Widget _buildCelebrationOverlay() {
    final c = _celebration!;
    return AnimatedBuilder2(
      animation: _celebrationCtrl!,
      builder: (context, _) {
        final t = _celebrationCtrl!.value;
        // Phase 1 (0-0.3): starburst flash expands
        // Phase 2 (0.3-0.7): team name scales up
        // Phase 3 (0.7-1.0): everything fades out
        final flashT = (t / 0.35).clamp(0.0, 1.0);
        final nameT = ((t - 0.15) / 0.45).clamp(0.0, 1.0);
        final fadeT = ((t - 0.65) / 0.35).clamp(0.0, 1.0);
        final opacity = 1.0 - fadeT;

        return Stack(
          children: [
            // Starburst rays
            if (flashT > 0)
              Positioned(
                left: c.x - 80,
                top: c.y - 80,
                width: 160,
                height: 160,
                child: Opacity(
                  opacity: opacity * (1.0 - flashT * 0.5),
                  child: CustomPaint(
                    painter: _StarburstPainter(
                      progress: flashT,
                      color: c.teamColor,
                    ),
                  ),
                ),
              ),
            // Glowing ring
            if (flashT > 0)
              Positioned(
                left: c.x - 50 * (0.5 + flashT * 0.5),
                top: c.y - 50 * (0.5 + flashT * 0.5),
                width: 100 * (0.5 + flashT * 0.5),
                height: 100 * (0.5 + flashT * 0.5),
                child: Opacity(
                  opacity: opacity * 0.6,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.teamColor.withValues(alpha: 0.8),
                        width: 3 * (1.0 - flashT * 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.teamColor.withValues(alpha: 0.5),
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
                left: c.x - 75,
                top: c.y - 16,
                width: 150,
                height: 32,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: 0.5 + nameT * 0.8,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            c.teamColor.withValues(alpha: 0.9),
                            c.teamColor.withValues(alpha: 0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.teamColor.withValues(alpha: 0.6 * opacity),
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
                        c.teamName.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: c.teamName.length > 16 ? 10.0 : 13.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: c.teamName.length > 16 ? 0.8 : 1.5,
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
              ..._buildSparkles(c, flashT, opacity),
          ],
        );
      },
    );
  }

  List<Widget> _buildSparkles(_CelebrationData c, double t, double opacity) {
    final rng = math.Random(c.teamName.hashCode);
    final sparkles = <Widget>[];
    const count = 12;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + rng.nextDouble() * 0.5;
      final distance = 30 + rng.nextDouble() * 55;
      final dx = math.cos(angle) * distance * t;
      final dy = math.sin(angle) * distance * t;
      final size = 3.0 + rng.nextDouble() * 4;
      final sparkOpacity = opacity * (1.0 - t * 0.6);
      final isGold = i % 3 == 0;

      sparkles.add(Positioned(
        left: c.x + dx - size / 2,
        top: c.y + dy - size / 2,
        width: size,
        height: size,
        child: Opacity(
          opacity: sparkOpacity.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGold
                  ? const Color(0xFFFFD700)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: (isGold ? const Color(0xFFFFD700) : c.teamColor)
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

  // ─── ROUND HEADERS ─────────────────────────────────────────
  List<Widget> _buildHeaders(_BracketSides sides, int maxFirst) {
    final widgets = <Widget>[];

    for (int ci = 0; ci < _leftCols; ci++) {
      widgets.add(Positioned(
        left: _leftColX(ci),
        top: _vPad - 4,
        width: _cellW,
        height: _headerH,
        child: _roundHeader(_leftRoundLabel(ci, _leftCols)),
      ));
    }

    if (sides.finals != null) {
      widgets.add(Positioned(
        left: _finalsMatchX(_leftCols),
        top: _finalsY(maxFirst) - _headerH - 2,
        width: _cellW,
        height: _headerH,
        child: Container(
          alignment: Alignment.center,
          child: Text(
            'FINAL',
            style: TextStyle(
              color: const Color(0xFFFFD700).withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.0,
            ),
          ),
        ),
      ));
    }

    for (int ci = 0; ci < _rightCols; ci++) {
      widgets.add(Positioned(
        left: _rightColX(ci, _leftCols, _rightCols),
        top: _vPad - 4,
        width: _cellW,
        height: _headerH,
        child: _roundHeader(_rightRoundLabel(ci, _rightCols)),
      ));
    }

    return widgets;
  }

  Widget _roundHeader(String text) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: BmbColors.textTertiary.withValues(alpha: 0.7),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  // ─── SIDE CELLS (LEFT or RIGHT) ────────────────────────────
  List<Widget> _buildSideCells(
    List<List<_Matchup>> sideRounds, {
    required bool isLeft,
    required int firstCount,
    required Set<String> activeGids,
  }) {
    final widgets = <Widget>[];

    for (int ci = 0; ci < sideRounds.length; ci++) {
      final ms = sideRounds[ci];
      final x = isLeft
          ? _leftColX(ci)
          : _rightColX(ci, _leftCols, _rightCols);

      for (int mi = 0; mi < ms.length; mi++) {
        final m = ms[mi];
        final y = _sideMatchY(mi, ci, firstCount);
        final isActiveMatch = activeGids.contains(m.gid);

        // Active round glow border behind matchup
        if (isActiveMatch) {
          widgets.add(Positioned(
            left: x - 3,
            top: y - 3,
            width: _cellW + 6,
            height: _matchH + 6,
            child: AnimatedBuilder2(
              animation: _pulseController,
              builder: (context, _) {
                final pulse = _pulseController.value;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFF00E676).withValues(
                          alpha: 0.3 + pulse * 0.4),
                      width: 1.5 + pulse * 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(
                            alpha: 0.1 + pulse * 0.15),
                        blurRadius: 8 + pulse * 8,
                        spreadRadius: pulse * 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ));
        }

        // Team 1
        widgets.add(Positioned(
          left: x,
          top: y,
          width: _cellW,
          height: _cellH,
          child: _TeamCell(
            team: m.t1,
            matchup: m,
            isTop: true,
            isPicked: m.pick == m.t1,
            canTap: !widget.submitted && widget.onPick != null && m.t1 != 'TBD',
            onTap: () {
              _isAutoZooming = true; // Guard: prevent InteractiveViewer from cancelling upcoming zoom
              widget.onPick!(m.round, m.idx, m.t1);
            },
            teamColor: _getTeamColor(m.t1),
            seed: _parseSeed(m.t1),
            cleanName: _cleanName(m.t1),
            initials: _getInitials(m.t1),
            logoUrl: TeamLogos.getLogoUrl(m.t1, sport: widget.sport),
            isActiveRound: isActiveMatch,
          ),
        ));
        // Team 2
        widgets.add(Positioned(
          left: x,
          top: y + _cellH + _matchGap,
          width: _cellW,
          height: _cellH,
          child: _TeamCell(
            team: m.t2,
            matchup: m,
            isTop: false,
            isPicked: m.pick == m.t2,
            canTap: !widget.submitted && widget.onPick != null && m.t2 != 'TBD',
            onTap: () {
              _isAutoZooming = true;
              widget.onPick!(m.round, m.idx, m.t2);
            },
            teamColor: _getTeamColor(m.t2),
            seed: _parseSeed(m.t2),
            cleanName: _cleanName(m.t2),
            initials: _getInitials(m.t2),
            logoUrl: TeamLogos.getLogoUrl(m.t2, sport: widget.sport),
            isActiveRound: isActiveMatch,
          ),
        ));
      }
    }
    return widgets;
  }

  // ─── FINALS CELL ───────────────────────────────────────────
  List<Widget> _buildFinalsCell(_Matchup m, int maxFirst, {required Set<String> activeGids}) {
    final x = _finalsMatchX(_leftCols);
    final y = _finalsY(maxFirst);
    final isActiveMatch = activeGids.contains(m.gid);

    final cells = <Widget>[];

    // Active glow border for finals
    if (isActiveMatch) {
      cells.add(Positioned(
        left: x - 3,
        top: y - 3,
        width: _cellW + 6,
        height: _matchH + 6,
        child: AnimatedBuilder2(
          animation: _pulseController,
          builder: (context, _) {
            final pulse = _pulseController.value;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(
                      alpha: 0.3 + pulse * 0.5),
                  width: 1.5 + pulse * 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(
                        alpha: 0.1 + pulse * 0.2),
                    blurRadius: 10 + pulse * 10,
                    spreadRadius: pulse * 3,
                  ),
                ],
              ),
            );
          },
        ),
      ));
    }

    cells.add(Positioned(
      left: x,
      top: y,
      width: _cellW,
      height: _cellH,
      child: _TeamCell(
        team: m.t1,
        matchup: m,
        isTop: true,
        isPicked: m.pick == m.t1,
        canTap: !widget.submitted && widget.onPick != null && m.t1 != 'TBD',
        onTap: () {
          _isAutoZooming = true;
          widget.onPick!(m.round, m.idx, m.t1);
        },
        teamColor: _getTeamColor(m.t1),
        seed: _parseSeed(m.t1),
        cleanName: _cleanName(m.t1),
        initials: _getInitials(m.t1),
        logoUrl: TeamLogos.getLogoUrl(m.t1, sport: widget.sport),
        isActiveRound: isActiveMatch,
      ),
    ));

    cells.add(Positioned(
      left: x,
      top: y + _cellH + _matchGap,
      width: _cellW,
      height: _cellH,
      child: _TeamCell(
        team: m.t2,
        matchup: m,
        isTop: false,
        isPicked: m.pick == m.t2,
        canTap: !widget.submitted && widget.onPick != null && m.t2 != 'TBD',
        onTap: () {
          _isAutoZooming = true;
          widget.onPick!(m.round, m.idx, m.t2);
        },
        teamColor: _getTeamColor(m.t2),
        seed: _parseSeed(m.t2),
        cleanName: _cleanName(m.t2),
        initials: _getInitials(m.t2),
        logoUrl: TeamLogos.getLogoUrl(m.t2, sport: widget.sport),
        isActiveRound: isActiveMatch,
      ),
    ));

    return cells;
  }

  // ─── CHAMPION DISPLAY ──────────────────────────────────────
  Widget _buildChampion(List<List<_Matchup>> rounds, int maxFirst) {
    final cx = _champBoxX(_leftCols);
    final cy = _champY(maxFirst);

    final lastPick = rounds.isNotEmpty && rounds.last.isNotEmpty
        ? rounds.last[0].pick
        : null;
    final hasChamp = lastPick != null && lastPick != 'TBD';

    return Positioned(
      left: cx,
      top: cy,
      width: _champW,
      height: _champH,
      child: AnimatedBuilder2(
        animation: _pulseController,
        builder: (context, child) {
          return _ChampionDisplay(
            champion: hasChamp ? lastPick : null,
            color: hasChamp ? _getTeamColor(lastPick) : null,
            initials: hasChamp ? _getInitials(lastPick) : null,
            cleanName: hasChamp ? _cleanName(lastPick) : null,
            logoUrl: hasChamp
                ? TeamLogos.getLogoUrl(lastPick, sport: widget.sport)
                : null,
            pulseValue: _pulseController.value,
          );
        },
      ),
    );
  }

  // ─── LEAGUE BRANDING LOGO ──────────────────────────────────
  Widget _buildLeagueLogo(int maxFirst) {
    final logoUrl = _leagueLogoUrl();
    if (logoUrl == null) return const SizedBox.shrink();

    final cx = _centerColX(_leftCols) + (_centerColW - 28) / 2;
    final cy = _finalsY(maxFirst) - _headerH - 6 - 28;

    return Positioned(
      left: cx,
      top: cy,
      width: 28,
      height: 28,
      child: Opacity(
        opacity: 0.25,
        child: Image.network(
          logoUrl,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ZOOM TARGET & SIDES DATA
// ═══════════════════════════════════════════════════════════════

enum _Side { left, right, finals }

class _ZoomTarget {
  final _Side side;
  final int roundIndex;
  final List<int> matchIndices;
  final List<_Matchup> allMatchups;

  const _ZoomTarget({
    required this.side,
    required this.roundIndex,
    required this.matchIndices,
    required this.allMatchups,
  });
}

class _CelebrationData {
  final double x, y;
  final String teamName;
  final Color teamColor;

  const _CelebrationData({
    required this.x,
    required this.y,
    required this.teamName,
    required this.teamColor,
  });
}

class _BracketSides {
  final List<List<_Matchup>> left;
  final List<List<_Matchup>> right;
  final _Matchup? finals;

  const _BracketSides({
    required this.left,
    required this.right,
    required this.finals,
  });
}

// ═══════════════════════════════════════════════════════════════
// DATA CLASSES (PRESERVED EXACTLY)
// ═══════════════════════════════════════════════════════════════

class _Matchup {
  final String t1, t2, gid;
  final int round, idx;
  final String? pick;
  const _Matchup(
      {required this.t1,
      required this.t2,
      required this.gid,
      required this.round,
      required this.idx,
      this.pick});
}

class GameResult {
  final String? winner;
  final bool isCompleted;
  const GameResult({this.winner, this.isCompleted = false});
}

// ═══════════════════════════════════════════════════════════════
// STARBURST PAINTER (celebration effect)
// ═══════════════════════════════════════════════════════════════

class _StarburstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _StarburstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw radiating lines
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
  bool shouldRepaint(covariant _StarburstPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

// ═══════════════════════════════════════════════════════════════
// TEAM CELL WIDGET (enhanced with active-round awareness)
// ═══════════════════════════════════════════════════════════════

class _TeamCell extends StatelessWidget {
  final String team;
  final _Matchup matchup;
  final bool isTop;
  final bool isPicked;
  final bool canTap;
  final VoidCallback onTap;
  final Color teamColor;
  final int? seed;
  final String cleanName;
  final String initials;
  final String? logoUrl;
  final bool isActiveRound;

  const _TeamCell({
    required this.team,
    required this.matchup,
    required this.isTop,
    required this.isPicked,
    required this.canTap,
    required this.onTap,
    required this.teamColor,
    this.seed,
    required this.cleanName,
    required this.initials,
    this.logoUrl,
    this.isActiveRound = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTBD = team == 'TBD';
    final isEliminated =
        matchup.pick != null && matchup.pick != team && !isTBD;

    final Color bgColor;
    final Color borderCol;
    final Color textCol;
    final Color seedBg;
    final Color seedText;

    if (isPicked) {
      bgColor = const Color(0xFF0A2A15);
      borderCol = const Color(0xFF00E676);
      textCol = Colors.white;
      seedBg = const Color(0xFF00E676);
      seedText = const Color(0xFF0A1628);
    } else if (isEliminated) {
      bgColor = const Color(0xFF1A0808).withValues(alpha: 0.5);
      borderCol = const Color(0xFF3D1515).withValues(alpha: 0.4);
      textCol = BmbColors.textTertiary.withValues(alpha: 0.3);
      seedBg = const Color(0xFF1A2540).withValues(alpha: 0.2);
      seedText = BmbColors.textTertiary.withValues(alpha: 0.3);
    } else if (isTBD) {
      bgColor = const Color(0xFF0B1420).withValues(alpha: 0.4);
      borderCol = const Color(0xFF1A2540).withValues(alpha: 0.3);
      textCol = BmbColors.textTertiary.withValues(alpha: 0.35);
      seedBg = Colors.transparent;
      seedText = Colors.transparent;
    } else if (isActiveRound) {
      // Active round: slightly brighter to draw attention
      bgColor = const Color(0xFF0F1F35);
      borderCol = const Color(0xFF264060);
      textCol = BmbColors.textPrimary;
      seedBg = teamColor.withValues(alpha: 0.25);
      seedText = teamColor;
    } else {
      bgColor = const Color(0xFF0F1B2E);
      borderCol = const Color(0xFF1E3050);
      textCol = BmbColors.textPrimary;
      seedBg = teamColor.withValues(alpha: 0.2);
      seedText = teamColor;
    }

    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: isTop ? const Radius.circular(8) : Radius.zero,
            topRight: isTop ? const Radius.circular(8) : Radius.zero,
            bottomLeft: !isTop ? const Radius.circular(8) : Radius.zero,
            bottomRight: !isTop ? const Radius.circular(8) : Radius.zero,
          ),
          border: Border(
            left: BorderSide(
              color: isPicked ? const Color(0xFF00E676) : borderCol,
              width: isPicked ? 3 : 0.5,
            ),
            right: BorderSide(color: borderCol, width: 0.5),
            top: isTop
                ? BorderSide(color: borderCol, width: 0.5)
                : BorderSide.none,
            bottom: !isTop
                ? BorderSide(color: borderCol, width: 0.5)
                : BorderSide.none,
          ),
          boxShadow: isPicked
              ? [
                  BoxShadow(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 0)
                ]
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTBD
                    ? const Color(0xFF1A2540).withValues(alpha: 0.5)
                    : (isPicked
                        ? teamColor.withValues(alpha: 0.15)
                        : teamColor.withValues(alpha: isEliminated ? 0.1 : 0.15)),
                boxShadow: isPicked
                    ? [
                        BoxShadow(
                            color: teamColor.withValues(alpha: 0.4),
                            blurRadius: 8)
                      ]
                    : null,
                border: Border.all(
                  color: isPicked
                      ? teamColor.withValues(alpha: 0.6)
                      : teamColor.withValues(alpha: isEliminated ? 0.15 : 0.3),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: logoUrl != null && !isTBD
                    ? Image.network(
                        logoUrl!,
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: initials.length > 2 ? 8 : 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          isTBD ? '?' : initials,
                          style: TextStyle(
                            color: isTBD
                                ? BmbColors.textTertiary.withValues(alpha: 0.4)
                                : Colors.white,
                            fontSize: isTBD ? 12 : (initials.length > 2 ? 8 : 10),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 6),
            if (seed != null) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: seedBg,
                ),
                child: Center(
                  child: Text(
                    '$seed',
                    style: TextStyle(
                      color: seedText,
                      fontSize: seed! > 9 ? 8 : 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                isTBD ? 'TBD' : cleanName,
                style: TextStyle(
                  color: textCol,
                  fontSize: cleanName.length > 18 ? 9.0 : (cleanName.length > 14 ? 10.0 : 11.0),
                  fontWeight: isPicked ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: isPicked ? 0.3 : 0,
                  decoration: isEliminated ? TextDecoration.lineThrough : null,
                  decorationColor: const Color(0xFFFF5252).withValues(alpha: 0.4),
                  decorationThickness: 2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isEliminated) ...[
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5C1A1A).withValues(alpha: 0.6),
                ),
                child: const Icon(Icons.close, color: Color(0xFFFF5252), size: 11),
              ),
              const SizedBox(width: 6),
            ] else if (isPicked) ...[
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00E676),
                ),
                child: const Icon(Icons.check, color: Color(0xFF0A1628), size: 12),
              ),
              const SizedBox(width: 6),
            ] else if (canTap && isActiveRound) ...[
              // Show a more prominent tap indicator for active round
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.touch_app_rounded,
                    color: Color(0xFF00E676), size: 12),
              ),
              const SizedBox(width: 5),
            ] else if (canTap && !isEliminated) ...[
              Icon(Icons.touch_app_rounded,
                  color: BmbColors.textTertiary.withValues(alpha: 0.3), size: 14),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CHAMPION DISPLAY (PRESERVED EXACTLY)
// ═══════════════════════════════════════════════════════════════

class _ChampionDisplay extends StatelessWidget {
  final String? champion;
  final Color? color;
  final String? initials;
  final String? cleanName;
  final String? logoUrl;
  final double pulseValue;

  const _ChampionDisplay({
    this.champion,
    this.color,
    this.initials,
    this.cleanName,
    this.logoUrl,
    this.pulseValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    final has = champion != null;
    final glowAlpha = has ? 0.15 + (pulseValue * 0.15) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: has
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFD700).withValues(alpha: 0.18),
                  const Color(0xFFFFD700).withValues(alpha: 0.08),
                  const Color(0xFF0A1628).withValues(alpha: 0.8),
                ],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F1B2E).withValues(alpha: 0.6),
                  const Color(0xFF0A1628).withValues(alpha: 0.4),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: has
              ? const Color(0xFFFFD700).withValues(alpha: 0.5 + pulseValue * 0.3)
              : const Color(0xFF1E3050).withValues(alpha: 0.4),
          width: has ? 2.5 : 1,
        ),
        boxShadow: has
            ? [
                BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: glowAlpha),
                    blurRadius: 30,
                    spreadRadius: 4),
                BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: glowAlpha * 0.5),
                    blurRadius: 60,
                    spreadRadius: 8),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (has) ...[
            Text(
              'CHAMPION',
              style: TextStyle(
                color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 4),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFD700), Color(0xFFFFA000), Color(0xFFFFD700)],
              ).createShader(bounds),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 6),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (color ?? BmbColors.gold).withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                      color: (color ?? BmbColors.gold).withValues(alpha: 0.6),
                      blurRadius: 16),
                  BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2),
                ],
                border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                    width: 2.5),
              ),
              child: ClipOval(
                child: logoUrl != null
                    ? Image.network(
                        logoUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initials ?? '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials ?? '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                cleanName ?? champion!,
                style: TextStyle(
                  color: const Color(0xFFFFD700),
                  fontSize: (cleanName ?? champion!).length > 18 ? 10.0 : 12.0,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'ClashDisplay',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  BmbColors.textTertiary.withValues(alpha: 0.3),
                  BmbColors.textTertiary.withValues(alpha: 0.15),
                ],
              ).createShader(bounds),
              child: const Icon(Icons.emoji_events, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 8),
            Text(
              'WHO YOU\nGOT?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BmbColors.textTertiary.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                height: 1.3,
                fontFamily: 'ClashDisplay',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TOURNAMENT CONNECTOR PAINTER
// ═══════════════════════════════════════════════════════════════

class _TournamentConnectorPainter extends CustomPainter {
  final _BracketSides sides;
  final Map<String, String> picks;
  final double cellW, cellH, matchGap, connW, champW, champH;
  final double headerH, vPad, hPad, firstRoundVGap, matchH;
  final int leftCols, rightCols, leftFirstCount, rightFirstCount;
  final double centerColW, champToFinalsGap;

  _TournamentConnectorPainter({
    required this.sides,
    required this.picks,
    required this.cellW,
    required this.cellH,
    required this.matchGap,
    required this.connW,
    required this.champW,
    required this.champH,
    required this.headerH,
    required this.vPad,
    required this.hPad,
    required this.firstRoundVGap,
    required this.matchH,
    required this.leftCols,
    required this.rightCols,
    required this.leftFirstCount,
    required this.rightFirstCount,
    required this.centerColW,
    required this.champToFinalsGap,
  });

  static const activeColor = Color(0xFF00E676);
  static const dimColor = Color(0xFF162035);
  static const champColor = Color(0xFFFFD700);

  double _sideMatchY(int matchIndex, int colIndex, int firstRoundCount) {
    if (firstRoundCount == 0) return headerH + vPad;
    if (colIndex == 0) {
      return headerH + vPad + matchIndex * (matchH + firstRoundVGap);
    }
    final prevTop = _sideMatchY(matchIndex * 2, colIndex - 1, firstRoundCount);
    final prevBot = _sideMatchY(matchIndex * 2 + 1, colIndex - 1, firstRoundCount);
    return (prevTop + prevBot) / 2;
  }

  double _leftColX(int ci) => hPad + ci * (cellW + connW);

  double _centerColX() => hPad + leftCols * (cellW + connW) + connW;

  double _finalsMatchX() => _centerColX() + (centerColW - cellW) / 2;

  double _rightColX(int ci) {
    final centerRight = _centerColX() + centerColW + connW;
    return centerRight + (rightCols - 1 - ci) * (cellW + connW);
  }

  double _bracketContentHeight(int maxFirst) {
    if (maxFirst == 0) return 400;
    return headerH + vPad * 2 + maxFirst * matchH + (maxFirst - 1) * firstRoundVGap;
  }

  double _finalsY() {
    final maxFirst = math.max(leftFirstCount, rightFirstCount);
    final h = math.max(_bracketContentHeight(maxFirst), 400.0);
    final centerBlockH = champH + champToFinalsGap + matchH;
    return (h - centerBlockH) / 2 + champH + champToFinalsGap;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int ri = 0; ri < sides.left.length - 1; ri++) {
      _paintSideConnectors(canvas, sides.left, ri,
          isLeft: true, firstCount: leftFirstCount);
    }

    for (int ri = 0; ri < sides.right.length - 1; ri++) {
      _paintSideConnectors(canvas, sides.right, ri,
          isLeft: false, firstCount: rightFirstCount);
    }

    if (sides.left.isNotEmpty && sides.finals != null) {
      final lastLeft = sides.left.last;
      final lastCI = sides.left.length - 1;
      final fy = _finalsY();
      final fmx = _finalsMatchX();
      for (int mi = 0; mi < lastLeft.length; mi++) {
        final m = lastLeft[mi];
        final hasPick = m.pick != null;
        final mCenterY = _sideMatchY(mi, lastCI, leftFirstCount) + matchH / 2;
        final rightEdge = _leftColX(lastCI) + cellW;
        final midX = rightEdge + (fmx - rightEdge) / 2;
        final targetY = mi == 0 ? fy + cellH / 2 : fy + cellH + matchGap + cellH / 2;
        final col = hasPick ? activeColor : dimColor;

        _drawLine(canvas, Offset(rightEdge, mCenterY), Offset(midX, mCenterY), col, hasPick);
        _drawLine(canvas, Offset(midX, mCenterY), Offset(midX, targetY), col, hasPick);
        _drawLine(canvas, Offset(midX, targetY), Offset(fmx, targetY), col, hasPick);
      }
    }

    if (sides.right.isNotEmpty && sides.finals != null) {
      final lastRight = sides.right.last;
      final lastCI = sides.right.length - 1;
      final fy = _finalsY();
      final fmx = _finalsMatchX();
      final finalsRight = fmx + cellW;
      for (int mi = 0; mi < lastRight.length; mi++) {
        final m = lastRight[mi];
        final hasPick = m.pick != null;
        final mCenterY = _sideMatchY(mi, lastCI, rightFirstCount) + matchH / 2;
        final leftEdge = _rightColX(lastCI);
        final midX = finalsRight + (leftEdge - finalsRight) / 2;
        final targetY = mi == 0 ? fy + cellH / 2 : fy + cellH + matchGap + cellH / 2;
        final col = hasPick ? activeColor : dimColor;

        _drawLine(canvas, Offset(leftEdge, mCenterY), Offset(midX, mCenterY), col, hasPick);
        _drawLine(canvas, Offset(midX, mCenterY), Offset(midX, targetY), col, hasPick);
        _drawLine(canvas, Offset(midX, targetY), Offset(finalsRight, targetY), col, hasPick);
      }
    }

    if (sides.finals != null) {
      final fy = _finalsY();
      final fmx = _finalsMatchX();
      final finalsTopCenter = Offset(fmx + cellW / 2, fy);
      final maxFirst = math.max(leftFirstCount, rightFirstCount);
      final h = math.max(_bracketContentHeight(maxFirst), 400.0);
      final centerBlockH = champH + champToFinalsGap + matchH;
      final champBottom = (h - centerBlockH) / 2 + champH;
      final hasFinal = sides.finals!.pick != null;
      _drawLine(canvas, finalsTopCenter, Offset(fmx + cellW / 2, champBottom),
          hasFinal ? champColor : dimColor, hasFinal, width: 2.5);
    }
  }

  void _paintSideConnectors(Canvas canvas, List<List<_Matchup>> sideRounds,
      int ri, {required bool isLeft, required int firstCount}) {
    final curr = sideRounds[ri];
    final next = sideRounds[ri + 1];

    for (int mi = 0; mi < curr.length; mi += 2) {
      if (mi + 1 >= curr.length) break;
      final nmi = mi ~/ 2;
      if (nmi >= next.length) break;

      final topHasPick = curr[mi].pick != null;
      final botHasPick = curr[mi + 1].pick != null;
      final bothPicked = topHasPick && botHasPick;

      final topMidY = _sideMatchY(mi, ri, firstCount) + matchH / 2;
      final botMidY = _sideMatchY(mi + 1, ri, firstCount) + matchH / 2;
      final nextMidY = _sideMatchY(nmi, ri + 1, firstCount) + matchH / 2;

      if (isLeft) {
        final rightX = _leftColX(ri) + cellW;
        final nextX = _leftColX(ri + 1);
        final midX = rightX + (nextX - rightX) / 2;

        _drawLine(canvas, Offset(rightX, topMidY), Offset(midX, topMidY),
            topHasPick ? activeColor : dimColor, topHasPick);
        _drawLine(canvas, Offset(rightX, botMidY), Offset(midX, botMidY),
            botHasPick ? activeColor : dimColor, botHasPick);
        _drawLine(canvas, Offset(midX, topMidY), Offset(midX, botMidY),
            bothPicked ? activeColor : dimColor, bothPicked);
        _drawLine(canvas, Offset(midX, nextMidY), Offset(nextX, nextMidY),
            bothPicked ? activeColor : dimColor, bothPicked);
      } else {
        final leftX = _rightColX(ri);
        final nextRightX = _rightColX(ri + 1) + cellW;
        final midX = nextRightX + (leftX - nextRightX) / 2;

        _drawLine(canvas, Offset(leftX, topMidY), Offset(midX, topMidY),
            topHasPick ? activeColor : dimColor, topHasPick);
        _drawLine(canvas, Offset(leftX, botMidY), Offset(midX, botMidY),
            botHasPick ? activeColor : dimColor, botHasPick);
        _drawLine(canvas, Offset(midX, topMidY), Offset(midX, botMidY),
            bothPicked ? activeColor : dimColor, bothPicked);
        _drawLine(canvas, Offset(midX, nextMidY), Offset(nextRightX, nextMidY),
            bothPicked ? activeColor : dimColor, bothPicked);
      }
    }
  }

  void _drawLine(Canvas canvas, Offset a, Offset b, Color color, bool glow,
      {double width = 1.5}) {
    if (glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..strokeWidth = width + 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, glowPaint);
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Wrapper for AnimatedBuilder to avoid name collision
class AnimatedBuilder2 extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder2({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _PulseBuilder(animation: animation, builder: builder, child: child);
  }
}

class _PulseBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const _PulseBuilder({
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, child);
}
