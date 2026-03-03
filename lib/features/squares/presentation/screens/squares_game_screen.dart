import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/squares/data/models/squares_game.dart';
import 'package:bmb_mobile/features/squares/data/services/squares_service.dart';
import 'package:bmb_mobile/features/squares/data/services/live_score_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

class SquaresGameScreen extends StatefulWidget {
  final SquaresGame? existingGame;
  const SquaresGameScreen({super.key, this.existingGame});

  @override
  State<SquaresGameScreen> createState() => _SquaresGameScreenState();
}

class _SquaresGameScreenState extends State<SquaresGameScreen> with TickerProviderStateMixin {
  late SquaresGame _game;
  final _squaresService = SquaresService();
  final _scoreService = LiveScoreService();

  // Create form controllers
  final _nameCtrl = TextEditingController();
  final _team1Ctrl = TextEditingController();
  final _team2Ctrl = TextEditingController();
  bool _isCreating = true;

  // Current user
  String get _uid => CurrentUserService.instance.userId;
  String get _uname => CurrentUserService.instance.displayName.isNotEmpty ? CurrentUserService.instance.displayName : 'BracketKing';
  int _userCredits = 350;

  // UI State
  SquaresSport _selectedSport = SquaresSport.football;
  int _creditsPerSquare = 1;
  int _maxPerPlayer = 10;
  int _prizePerQ = 25;
  int _grandPrize = 50;
  bool _showResults = false;
  Timer? _espnPollTimer;

  // Builder: auto-host, min players, go-live date
  bool _autoHost = false;
  int _minPlayers = 4;
  DateTime? _goLiveDate;

  // Visibility: public vs private
  bool _isPublic = true;
  bool _addToBracketBoard = true;

  // Countdown timer
  Timer? _countdownTimer;

  // Score entry controllers
  final _scoreT1Ctrl = TextEditingController();
  final _scoreT2Ctrl = TextEditingController();
  String _selectedQuarter = 'Q1';

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    if (widget.existingGame != null) {
      _game = widget.existingGame!;
      _isCreating = false;
      _autoHost = _game.autoHost;
      _minPlayers = _game.minPlayers;
      _goLiveDate = _game.goLiveDate;
      // Start countdown timer and auto-transition check
      _startCountdownTimer();
    } else {
      _game = SquaresGame.create(
        name: '', team1: '', team2: '',
        hostId: _uid, hostName: _uname,
      );
    }
    _loadCredits();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Check auto-transition
      if (_game.canAutoTransition) {
        _autoTransitionToInProgress();
      }
      // Refresh UI for countdown
      if (_game.goLiveDate != null && _game.isUpcoming) {
        setState(() {});
      }
    });
  }

  Future<void> _autoTransitionToInProgress() async {
    _countdownTimer?.cancel();
    // Skip live status for squares: upcoming -> in_progress directly
    final (updated, messages) = await _squaresService.transitionToLive(_game);
    final finalGame = _squaresService.transitionToInProgress(updated);
    HapticFeedback.heavyImpact();
    setState(() {
      _game = finalGame;
    });
    _loadCredits();
    _snack('Game auto-started! Board is locked. Credits charged & numbers assigned.');
  }

  Future<void> _loadCredits() async {
    final c = await _squaresService.getUserCredits(_uid);
    if (mounted) setState(() => _userCredits = c);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nameCtrl.dispose();
    _team1Ctrl.dispose();
    _team2Ctrl.dispose();
    _scoreT1Ctrl.dispose();
    _scoreT2Ctrl.dispose();
    _scoreService.stopPolling();
    _espnPollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ─── GAME CREATION ────────────────────────────────────────────────────

  void _createGame() {
    if (_nameCtrl.text.trim().isEmpty || _team1Ctrl.text.trim().isEmpty || _team2Ctrl.text.trim().isEmpty) {
      _snack('Please fill in all fields', isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _game = SquaresGame.create(
        name: _nameCtrl.text.trim(),
        team1: _team1Ctrl.text.trim(),
        team2: _team2Ctrl.text.trim(),
        sport: _selectedSport,
        hostId: _uid,
        hostName: _uname,
        creditsPerSquare: _creditsPerSquare,
        maxSquaresPerPlayer: _maxPerPlayer,
        prizePerQuarter: _prizePerQ,
        grandPrizeBonus: _grandPrize,
        autoHost: _autoHost,
        minPlayers: _minPlayers,
        goLiveDate: _goLiveDate,
        isPublic: _isPublic,
        addToBracketBoard: _addToBracketBoard,
      );
      _isCreating = false;
    });
    _startCountdownTimer();
  }

  // ─── SQUARE PICKING ───────────────────────────────────────────────────

  Future<void> _pickSquare(int row, int col) async {
    if (!_game.isUpcoming) return;
    final pick = _game.getSquarePick(row, col);

    // If it's my square, deselect it (free — no credits involved yet)
    if (pick != null && pick.userId == _uid) {
      final (updated, ok, msg) = await _squaresService.deselectSquare(
        game: _game, row: row, col: col, userId: _uid,
      );
      if (ok) {
        HapticFeedback.lightImpact();
        setState(() => _game = updated);
        _snack(msg);
      } else {
        _snack(msg, isError: true);
      }
      return;
    }

    // Pick new square (NO credit deduction — that happens at Go LIVE)
    final (updated, ok, msg) = await _squaresService.pickSquare(
      game: _game, row: row, col: col, userId: _uid, userName: _uname,
    );
    if (ok) {
      HapticFeedback.mediumImpact();
      setState(() => _game = updated);
      _snack(msg);
    } else {
      _snack(msg, isError: true);
    }
  }

  // ─── STATUS TRANSITIONS ───────────────────────────────────────────────

  Future<void> _goLive() async {
    // Confirmation dialog
    final totalCost = _game.pickedCount * _game.creditsPerSquare;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.flash_on, color: BmbColors.gold, size: 22),
            const SizedBox(width: 8),
            Text('Start Game?', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will:', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            _confirmItem(Icons.monetization_on, 'Deduct $totalCost total credits from ${_game.picks.values.map((p) => p.userId).toSet().length} players'),
            _confirmItem(Icons.casino, 'Randomly assign numbers to all rows & columns'),
            _confirmItem(Icons.visibility, 'Reveal numbers & LOCK the board'),
            const SizedBox(height: 10),
            Text('This cannot be undone!', style: TextStyle(color: BmbColors.errorRed, fontSize: 11, fontWeight: BmbFontWeights.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: BmbColors.successGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Start Game', style: TextStyle(fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Skip "live" status for squares — go straight to in_progress
    final (liveGame, messages) = await _squaresService.transitionToLive(_game);
    final updated = _squaresService.transitionToInProgress(liveGame);
    HapticFeedback.heavyImpact();
    setState(() => _game = updated);
    _loadCredits();

    // Show how many were released
    final released = updated.releasedUserIds.length;
    if (released > 0) {
      _snack('Game started! Credits charged, numbers revealed, board locked! $released player(s) released.');
    } else {
      _snack('Game started! Credits charged, numbers revealed, board locked!');
    }
  }

  Widget _confirmItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BmbColors.gold, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, height: 1.3))),
        ],
      ),
    );
  }

  void _startGame() {
    HapticFeedback.heavyImpact();
    setState(() => _game = _squaresService.transitionToInProgress(_game));
    _snack('Game started! Board is locked.');
  }

  void _enterScore() {
    final t1 = int.tryParse(_scoreT1Ctrl.text.trim());
    final t2 = int.tryParse(_scoreT2Ctrl.text.trim());
    if (t1 == null || t2 == null) {
      _snack('Enter valid scores', isError: true);
      return;
    }
    final labels = _game.periodLabels;
    final qIdx = labels.indexOf(_selectedQuarter);
    final isFinal = qIdx == labels.length - 1;

    setState(() {
      _game = _squaresService.enterQuarterScore(
        game: _game,
        quarter: _selectedQuarter,
        team1Score: t1,
        team2Score: t2,
        isFinal: isFinal,
      );
    });
    _scoreT1Ctrl.clear();
    _scoreT2Ctrl.clear();

    if (_game.isDone) {
      _squaresService.distributePrizes(_game);
      _loadCredits();
      _snack('Game complete! Winners awarded!');
    } else {
      // Auto-advance to next quarter
      if (qIdx + 1 < labels.length) {
        setState(() => _selectedQuarter = labels[qIdx + 1]);
      }
      _snack('$_selectedQuarter score saved');
    }
  }

  void _simulateFullGame() {
    final sportKey = _game.sport == SquaresSport.basketball ? 'basketball'
        : _game.sport == SquaresSport.hockey ? 'hockey' : 'football';
    final simScores = LiveScoreService.simulateScores(sportKey, _game.team1, _game.team2);
    final labels = _game.periodLabels;

    var game = _game;
    for (int i = 0; i < simScores.length && i < labels.length; i++) {
      game = _squaresService.enterQuarterScore(
        game: game,
        quarter: labels[i],
        team1Score: simScores[i].team1Score,
        team2Score: simScores[i].team2Score,
        isFinal: simScores[i].isFinal,
      );
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _game = game;
      _showResults = true;
    });
    _squaresService.distributePrizes(_game);
    _loadCredits();
    _snack('Simulated full game! Winners awarded!');
  }

  // ─── ESPN FETCH ───────────────────────────────────────────────────────

  Future<void> _fetchEspnScores() async {
    final sportKey = _game.sport == SquaresSport.basketball ? 'basketball'
        : _game.sport == SquaresSport.hockey ? 'hockey' : 'football';
    final games = await _scoreService.fetchLiveScores(sportKey);

    if (games.isEmpty) {
      _snack('No live ESPN games found — use manual entry or simulate', isError: true);
      return;
    }

    // Show game picker
    if (!mounted) return;
    _showEspnGamePicker(games);
  }

  void _showEspnGamePicker(List<EspnGame> games) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.sports, color: BmbColors.gold, size: 22),
                const SizedBox(width: 8),
                Text('ESPN Live Games', style: TextStyle(color: BmbColors.textPrimary, fontSize: 17, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              ],
            ),
            const SizedBox(height: 12),
            ...games.take(6).map((g) => _buildEspnGameTile(g, ctx)),
          ],
        ),
      ),
    );
  }

  Widget _buildEspnGameTile(EspnGame game, BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _applyEspnGame(game);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: game.isLive ? BmbColors.successGreen.withValues(alpha: 0.5) : BmbColors.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.shortName, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                  Text('${game.awayScore} - ${game.homeScore}', style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (game.isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: BmbColors.successGreen, borderRadius: BorderRadius.circular(4)),
                child: Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: BmbFontWeights.bold)),
              )
            else if (game.isFinal)
              Text('FINAL', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.bold)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: BmbColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  void _applyEspnGame(EspnGame game) {
    final labels = _game.periodLabels;
    final quarterScores = _scoreService.getQuarterScores(game, labels);

    var updated = _game;
    for (final qs in quarterScores) {
      updated = _squaresService.enterQuarterScore(
        game: updated,
        quarter: qs.quarter,
        team1Score: qs.team1Score,
        team2Score: qs.team2Score,
        isFinal: qs.isFinal,
        isFromEspn: true,
      );
    }

    setState(() {
      _game = updated;
      _showResults = true;
    });

    if (_game.isDone) {
      _squaresService.distributePrizes(_game);
      _loadCredits();
      _snack('ESPN scores applied! Game complete!');
    } else {
      _snack('ESPN scores applied for ${quarterScores.length} periods');
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? BmbColors.errorRed : BmbColors.midNavy,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Color get _statusColor {
    switch (_game.status) {
      case SquaresStatus.upcoming: return BmbColors.blue;
      case SquaresStatus.live: return BmbColors.successGreen;
      case SquaresStatus.inProgress: return BmbColors.gold;
      case SquaresStatus.done: return const Color(0xFF00BCD4);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ─── BUILD ────────────────────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isCreating ? _buildCreateForm() : _buildGameView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: () => Navigator.pop(context)),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.grid_4x4, color: BmbColors.gold, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isCreating ? 'Create Squares' : _game.name,
              style: TextStyle(color: BmbColors.textPrimary, fontSize: 15, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_isCreating) ...[
            // Share button for host in upcoming state
            if (_game.isUpcoming && _game.hostId == _uid)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showUpcomingShareSheet();
                },
                child: Container(
                  width: 32, height: 32,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.share, color: Color(0xFF8B5CF6), size: 15),
                ),
              ),
            // Status badge
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: _game.isLive || _game.isInProgress ? _pulseAnim.value * 0.2 : 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_game.isLive || _game.isInProgress)
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor),
                      ),
                    Text(_game.statusLabel, style: TextStyle(color: _statusColor, fontSize: 9, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Credits badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: BmbColors.gold, size: 12),
                  const SizedBox(width: 3),
                  Text('$_userCredits', style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── CREATE FORM ──────────────────────────────────────────────────────

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero icon
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.2), BmbColors.gold.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.grid_4x4, color: BmbColors.gold, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text('Squares Game', style: TextStyle(color: BmbColors.textPrimary, fontSize: 22, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'))),
          const SizedBox(height: 6),
          Center(child: Text(
            '10x10 grid • Pick squares • Win each quarter',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12),
          )),
          const SizedBox(height: 24),

          _sectionLabel('Game Name'),
          _textField(_nameCtrl, 'e.g. Super Bowl LIX Squares'),
          const SizedBox(height: 16),

          // Sport selector
          _sectionLabel('Sport'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: SquaresSport.values.where((s) => s != SquaresSport.other).map((s) {
              final sel = _selectedSport == s;
              final label = s == SquaresSport.football ? 'Football' : s == SquaresSport.basketball ? 'Basketball' : s == SquaresSport.hockey ? 'Hockey' : s == SquaresSport.lacrosse ? 'Lacrosse' : 'Soccer';
              final icon = s == SquaresSport.football ? Icons.sports_football : s == SquaresSport.basketball ? Icons.sports_basketball : s == SquaresSport.hockey ? Icons.sports_hockey : s == SquaresSport.lacrosse ? Icons.sports : Icons.sports_soccer;
              return GestureDetector(
                onTap: () => setState(() => _selectedSport = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? BmbColors.blue.withValues(alpha: 0.15) : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? BmbColors.blue : BmbColors.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: sel ? BmbColors.blue : BmbColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(label, style: TextStyle(color: sel ? BmbColors.blue : BmbColors.textSecondary, fontSize: 12, fontWeight: sel ? BmbFontWeights.bold : BmbFontWeights.medium)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _sectionLabel('Team 1 (Columns)'),
          _textField(_team1Ctrl, 'e.g. Kansas City Chiefs'),
          const SizedBox(height: 16),

          _sectionLabel('Team 2 (Rows)'),
          _textField(_team2Ctrl, 'e.g. Philadelphia Eagles'),
          const SizedBox(height: 20),

          // Credits settings
          _sectionLabel('Credits Per Square'),
          const SizedBox(height: 8),
          _chipRow([1, 2, 3, 5, 10], _creditsPerSquare, (v) => setState(() => _creditsPerSquare = v)),
          const SizedBox(height: 16),

          _sectionLabel('Max Squares Per Player'),
          const SizedBox(height: 8),
          _chipRow([5, 10, 15, 20, 25], _maxPerPlayer, (v) => setState(() => _maxPerPlayer = v)),
          const SizedBox(height: 16),

          // Prize settings
          _sectionLabel('Prize Per Quarter (credits)'),
          const SizedBox(height: 8),
          _chipRow([10, 25, 50, 100], _prizePerQ, (v) => setState(() => _prizePerQ = v)),
          const SizedBox(height: 16),

          _sectionLabel('Grand Prize Bonus (final quarter)'),
          const SizedBox(height: 8),
          _chipRow([25, 50, 100, 250], _grandPrize, (v) => setState(() => _grandPrize = v)),
          const SizedBox(height: 8),

          // Prize pool preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: BmbColors.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Total Prize Pool: ${_prizePerQ * 4 + _grandPrize} credits  |  Revenue: ${_creditsPerSquare * 100} credits (100 squares)',
                  style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.semiBold),
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── VISIBILITY: PUBLIC / PRIVATE ───────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                const Color(0xFF8B5CF6).withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_isPublic ? Icons.public : Icons.lock,
                      color: const Color(0xFF8B5CF6), size: 18),
                    const SizedBox(width: 8),
                    Text('Visibility', style: TextStyle(
                      color: BmbColors.textPrimary, fontSize: 14,
                      fontWeight: BmbFontWeights.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Public card
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isPublic = true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isPublic
                                ? BmbColors.successGreen.withValues(alpha: 0.12)
                                : BmbColors.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isPublic
                                  ? BmbColors.successGreen
                                  : BmbColors.borderColor,
                              width: _isPublic ? 1.5 : 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.public,
                                color: _isPublic ? BmbColors.successGreen : BmbColors.textTertiary,
                                size: 24),
                              const SizedBox(height: 6),
                              Text('Public', style: TextStyle(
                                color: _isPublic ? BmbColors.successGreen : BmbColors.textSecondary,
                                fontSize: 13, fontWeight: BmbFontWeights.bold)),
                              const SizedBox(height: 2),
                              Text('Anyone can find & join',
                                style: TextStyle(color: BmbColors.textTertiary, fontSize: 9),
                                textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Private card
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isPublic = false;
                          _addToBracketBoard = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: !_isPublic
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                : BmbColors.cardDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !_isPublic
                                  ? const Color(0xFF8B5CF6)
                                  : BmbColors.borderColor,
                              width: !_isPublic ? 1.5 : 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.lock,
                                color: !_isPublic ? const Color(0xFF8B5CF6) : BmbColors.textTertiary,
                                size: 24),
                              const SizedBox(height: 6),
                              Text('Private', style: TextStyle(
                                color: !_isPublic ? const Color(0xFF8B5CF6) : BmbColors.textSecondary,
                                fontSize: 13, fontWeight: BmbFontWeights.bold)),
                              const SizedBox(height: 2),
                              Text('Invite only via link',
                                style: TextStyle(color: BmbColors.textTertiary, fontSize: 9),
                                textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Add to Bracket Board toggle (only if public)
                if (_isPublic) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: BmbColors.cardDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BmbColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.dashboard_customize,
                          color: _addToBracketBoard ? BmbColors.blue : BmbColors.textTertiary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add to Bracket Board', style: TextStyle(
                                color: BmbColors.textPrimary, fontSize: 12,
                                fontWeight: BmbFontWeights.semiBold)),
                              Text('Show this game on the public feed',
                                style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _addToBracketBoard,
                          onChanged: (v) => setState(() => _addToBracketBoard = v),
                          activeTrackColor: BmbColors.blue.withValues(alpha: 0.5),
                          thumbColor: WidgetStatePropertyAll(
                            _addToBracketBoard ? BmbColors.blue : BmbColors.textTertiary),
                          inactiveTrackColor: BmbColors.borderColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── AUTO HOST SETTINGS ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                BmbColors.blue.withValues(alpha: 0.1),
                BmbColors.blue.withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.smart_toy, color: BmbColors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text('Auto Host', style: TextStyle(
                      color: BmbColors.textPrimary, fontSize: 14,
                      fontWeight: BmbFontWeights.bold)),
                    const Spacer(),
                    Switch(
                      value: _autoHost,
                      onChanged: (v) => setState(() => _autoHost = v),
                      activeTrackColor: BmbColors.blue.withValues(alpha: 0.5),
                      thumbColor: WidgetStatePropertyAll(_autoHost ? BmbColors.blue : BmbColors.textTertiary),
                      inactiveTrackColor: BmbColors.borderColor,
                    ),
                  ],
                ),
                Text(
                  'When enabled, the game auto-transitions from Upcoming to In Progress at the Go Live date. Skips manual intervention.',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, height: 1.3),
                ),
                if (_autoHost) ...[
                  const SizedBox(height: 14),
                  // Min Players
                  _sectionLabel('Minimum Players'),
                  const SizedBox(height: 8),
                  _chipRow([2, 4, 6, 8, 10], _minPlayers, (v) => setState(() => _minPlayers = v)),
                  const SizedBox(height: 4),
                  Text(
                    'Game won\'t start until at least $_minPlayers unique players have joined.',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
                  ),
                  const SizedBox(height: 14),
                  // Go Live Date
                  _sectionLabel('Go Live Date'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final currentContext = context;
                      final date = await showDatePicker(
                        context: currentContext,
                        initialDate: _goLiveDate ?? DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: BmbColors.blue,
                              surface: BmbColors.midNavy,
                              onSurface: BmbColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (date == null) return;
                      if (!currentContext.mounted) return; // BUG #12 FIX
                      final time = await showTimePicker(
                        context: currentContext,
                        initialTime: TimeOfDay(hour: 18, minute: 0),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: BmbColors.blue,
                              surface: BmbColors.midNavy,
                              onSurface: BmbColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (time == null) return;
                      setState(() {
                        _goLiveDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _goLiveDate != null ? BmbColors.blue : BmbColors.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: _goLiveDate != null ? BmbColors.blue : BmbColors.textTertiary, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _goLiveDate != null
                                  ? '${_goLiveDate!.month}/${_goLiveDate!.day}/${_goLiveDate!.year} at ${_goLiveDate!.hour.toString().padLeft(2, '0')}:${_goLiveDate!.minute.toString().padLeft(2, '0')}'
                                  : 'Select date & time',
                              style: TextStyle(
                                color: _goLiveDate != null ? BmbColors.textPrimary : BmbColors.textTertiary,
                                fontSize: 13, fontWeight: BmbFontWeights.medium,
                              ),
                            ),
                          ),
                          if (_goLiveDate != null)
                            GestureDetector(
                              onTap: () => setState(() => _goLiveDate = null),
                              child: Icon(Icons.close, color: BmbColors.textTertiary, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_goLiveDate == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Required for auto-host. The game will lock at this time.',
                        style: TextStyle(color: BmbColors.errorRed, fontSize: 10),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Create button
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _createGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_4x4, size: 20),
                  const SizedBox(width: 8),
                  Text('Create Squares Game', style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── GAME VIEW (board + controls) ─────────────────────────────────────

  Widget _buildGameView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
      child: Column(
        children: [
          // Info bar
          _buildInfoBar(),
          const SizedBox(height: 8),

          // Quarter results (if any scores)
          if (_game.scores.isNotEmpty) ...[
            _buildQuarterResults(),
            const SizedBox(height: 8),
          ],

          // Status-aware banner
          _buildStatusBanner(),
          const SizedBox(height: 8),

          // The 10x10 grid
          _buildGrid(),
          const SizedBox(height: 10),

          // Stats row
          _buildStatsRow(),
          const SizedBox(height: 10),

          // Status-aware action buttons
          _buildActionArea(),

          // Winners section (done state)
          if (_game.isDone || _showResults) ...[
            const SizedBox(height: 12),
            _buildWinnersSection(),
          ],
        ],
      ),
    );
  }

  // ─── INFO BAR ─────────────────────────────────────────────────────────

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          // Sport badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _sportColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_sportIcon, size: 13, color: _sportColor),
                const SizedBox(width: 4),
                Text(_game.sportLabel, style: TextStyle(color: _sportColor, fontSize: 10, fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_game.team1}  vs  ${_game.team2}', style: TextStyle(color: BmbColors.textPrimary, fontSize: 11, fontWeight: BmbFontWeights.semiBold), overflow: TextOverflow.ellipsis),
                Text('${_game.creditsPerSquare} credits/sq • Max ${_game.maxSquaresPerPlayer}/player', style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
              ],
            ),
          ),
          // Prize pool
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, color: BmbColors.gold, size: 14),
                  const SizedBox(width: 3),
                  Text('${_game.totalPrizePool}', style: TextStyle(color: BmbColors.gold, fontSize: 13, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                ],
              ),
              Text('Prize Pool', style: TextStyle(color: BmbColors.textTertiary, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── STATUS BANNER ────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    String text;
    IconData icon;
    Color color;

    switch (_game.status) {
      case SquaresStatus.upcoming:
        text = 'Pick your squares BLIND! Numbers are hidden until Go LIVE. No credits charged yet.';
        icon = Icons.touch_app;
        color = BmbColors.blue;
      case SquaresStatus.live:
        text = 'Numbers revealed! Credits deducted. Check your lucky numbers!';
        icon = Icons.casino;
        color = BmbColors.successGreen;
      case SquaresStatus.inProgress:
        text = 'Board LOCKED • Game in progress • Scores update per quarter';
        icon = Icons.sports_score;
        color = BmbColors.gold;
      case SquaresStatus.done:
        text = 'Game over! Quarter winners calculated. Prizes distributed!';
        icon = Icons.celebration;
        color = const Color(0xFF00BCD4);
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: BmbFontWeights.medium, height: 1.3))),
            ],
          ),
        ),
        // Countdown timer for upcoming games with a go-live date
        if (_game.isUpcoming && _game.goLiveDate != null) ...[
          const SizedBox(height: 6),
          _buildCountdownBanner(),
        ],
      ],
    );
  }

  /// Countdown banner showing time remaining to join before the game locks.
  Widget _buildCountdownBanner() {
    final remaining = _game.timeUntilGoLive ?? Duration.zero;
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    final isUrgent = remaining.inHours < 2;

    String countdownText;
    if (remaining == Duration.zero) {
      countdownText = 'Locking now...';
    } else if (days > 0) {
      countdownText = '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      countdownText = '${hours}h ${minutes}m ${seconds}s';
    } else {
      countdownText = '${minutes}m ${seconds}s';
    }

    final bannerColor = isUrgent ? BmbColors.errorRed : BmbColors.gold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          bannerColor.withValues(alpha: 0.15),
          bannerColor.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: bannerColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrgent ? 'HURRY! Game locks soon' : 'Time left to join',
                  style: TextStyle(color: bannerColor, fontSize: 9,
                    fontWeight: BmbFontWeights.bold, letterSpacing: 0.5),
                ),
                Text(
                  countdownText,
                  style: TextStyle(color: bannerColor, fontSize: 16,
                    fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'),
                ),
              ],
            ),
          ),
          // Player count vs minimum
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _game.uniquePlayerCount >= _game.minPlayers
                  ? BmbColors.successGreen.withValues(alpha: 0.15)
                  : BmbColors.errorRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text('${_game.uniquePlayerCount}/${_game.minPlayers}',
                  style: TextStyle(
                    color: _game.uniquePlayerCount >= _game.minPlayers
                        ? BmbColors.successGreen : BmbColors.errorRed,
                    fontSize: 12, fontWeight: BmbFontWeights.bold)),
                Text('Players', style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── QUARTER RESULTS ──────────────────────────────────────────────────

  Widget _buildQuarterResults() {
    final winners = _game.getWinners();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.scoreboard, color: BmbColors.gold, size: 16),
              const SizedBox(width: 6),
              Text('Scoreboard', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const Spacer(),
              if (_game.scores.any((s) => s.isFromEspn))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: BmbColors.errorRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports, color: BmbColors.errorRed, size: 10),
                      const SizedBox(width: 3),
                      Text('ESPN', style: TextStyle(color: BmbColors.errorRed, fontSize: 8, fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Score table header
          Row(
            children: [
              SizedBox(width: 60, child: Text('', style: TextStyle(color: BmbColors.textTertiary, fontSize: 9))),
              ...winners.map((w) => Expanded(
                child: Center(child: Text(w.quarter, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.bold))),
              )),
            ],
          ),
          const SizedBox(height: 4),
          // Team 1 scores
          Row(
            children: [
              SizedBox(width: 60, child: Text(_game.team1, style: TextStyle(color: BmbColors.blue, fontSize: 9, fontWeight: BmbFontWeights.bold), overflow: TextOverflow.ellipsis)),
              ...winners.map((w) => Expanded(
                child: Center(child: Text('${w.score.team1Score}', style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.bold))),
              )),
            ],
          ),
          const SizedBox(height: 2),
          // Team 2 scores
          Row(
            children: [
              SizedBox(width: 60, child: Text(_game.team2, style: TextStyle(color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold), overflow: TextOverflow.ellipsis)),
              ...winners.map((w) => Expanded(
                child: Center(child: Text('${w.score.team2Score}', style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.bold))),
              )),
            ],
          ),
          const SizedBox(height: 6),
          // Winners per quarter
          Row(
            children: [
              SizedBox(width: 60, child: Text('Winner', style: TextStyle(color: BmbColors.textTertiary, fontSize: 9))),
              ...winners.map((w) => Expanded(
                child: Center(
                  child: w.hasWinner
                      ? Column(
                          children: [
                            Text(
                              w.winner!.userName,
                              style: TextStyle(
                                color: w.winner!.userId == _uid ? BmbColors.gold : BmbColors.successGreen,
                                fontSize: 8, fontWeight: BmbFontWeights.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (w.prize > 0) Text('+${w.prize}c', style: TextStyle(color: BmbColors.gold, fontSize: 7)),
                          ],
                        )
                      : Text('—', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  // ─── THE 10x10 GRID ──────────────────────────────────────────────────

  Widget _buildGrid() {
    final showNumbers = _game.areNumbersVisible;

    // Determine winning squares for highlighting
    final winCoords = <String>{};
    if (_game.scores.isNotEmpty && showNumbers) {
      for (final score in _game.scores) {
        final coords = _game.getWinningCoords(score);
        if (coords != null) winCoords.add('${coords.$1}_${coords.$2}');
      }
    }

    return Column(
      children: [
        // Column header (Team 1 numbers — hidden during upcoming)
        Row(
          children: [
            const SizedBox(width: 34),
            ...List.generate(10, (col) => Expanded(
              child: Container(
                height: 28,
                margin: const EdgeInsets.all(0.5),
                decoration: BoxDecoration(
                  color: showNumbers
                      ? BmbColors.blue.withValues(alpha: 0.15)
                      : BmbColors.textTertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: showNumbers
                      ? Text('${_game.colNumbers[col]}', style: TextStyle(color: BmbColors.blue, fontSize: 10, fontWeight: BmbFontWeights.bold))
                      : Icon(Icons.help_outline, color: BmbColors.textTertiary.withValues(alpha: 0.4), size: 12),
                ),
              ),
            )),
          ],
        ),
        // Team 1 name label
        Padding(
          padding: const EdgeInsets.only(top: 1, bottom: 2),
          child: Text(
            showNumbers ? _game.team1 : '${_game.team1} (numbers hidden)',
            style: TextStyle(color: BmbColors.blue, fontSize: 9, fontWeight: BmbFontWeights.bold),
          ),
        ),
        // Grid rows
        ...List.generate(10, (row) => Row(
          children: [
            // Row header (Team 2 numbers — hidden during upcoming)
            SizedBox(
              width: 34, height: 30,
              child: Container(
                margin: const EdgeInsets.all(0.5),
                decoration: BoxDecoration(
                  color: showNumbers
                      ? BmbColors.gold.withValues(alpha: 0.15)
                      : BmbColors.textTertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: showNumbers
                      ? Text('${_game.rowNumbers[row]}', style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold))
                      : Icon(Icons.help_outline, color: BmbColors.textTertiary.withValues(alpha: 0.4), size: 12),
                ),
              ),
            ),
            // Squares
            ...List.generate(10, (col) {
              final pick = _game.getSquarePick(row, col);
              final isPicked = pick != null;
              final isMe = isPicked && pick.userId == _uid;
              final isWinner = winCoords.contains('${row}_$col');

              Color bgColor;
              Color borderColor;
              if (isWinner) {
                bgColor = BmbColors.gold.withValues(alpha: 0.35);
                borderColor = BmbColors.gold;
              } else if (isMe) {
                bgColor = BmbColors.blue.withValues(alpha: 0.3);
                borderColor = BmbColors.blue;
              } else if (isPicked) {
                bgColor = BmbColors.textTertiary.withValues(alpha: 0.1);
                borderColor = BmbColors.borderColor.withValues(alpha: 0.3);
              } else if (_game.isUpcoming) {
                bgColor = BmbColors.cardDark;
                borderColor = BmbColors.borderColor.withValues(alpha: 0.3);
              } else {
                bgColor = BmbColors.cardDark.withValues(alpha: 0.5);
                borderColor = BmbColors.borderColor.withValues(alpha: 0.15);
              }

              return Expanded(
                child: GestureDetector(
                  onTap: () => _game.isUpcoming ? _pickSquare(row, col) : _showSquareInfo(row, col),
                  child: Container(
                    height: 30,
                    margin: const EdgeInsets.all(0.5),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: borderColor, width: isWinner ? 1.5 : 0.5),
                    ),
                    child: Center(
                      child: isPicked
                          ? isWinner
                              ? const Icon(Icons.emoji_events, color: BmbColors.gold, size: 12)
                              : Text(
                                  pick.userName.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: isMe ? BmbColors.blue : BmbColors.textTertiary,
                                    fontSize: 9,
                                    fontWeight: BmbFontWeights.bold,
                                  ),
                                )
                          : _game.isUpcoming
                              ? Icon(Icons.add, color: BmbColors.textTertiary.withValues(alpha: 0.3), size: 10)
                              : null,
                    ),
                  ),
                ),
              );
            }),
          ],
        )),
        // Team 2 name label
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                showNumbers ? _game.team2 : '${_game.team2} (numbers hidden)',
                style: TextStyle(color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSquareInfo(int row, int col) {
    final pick = _game.getSquarePick(row, col);
    final showNumbers = _game.areNumbersVisible;

    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            if (showNumbers) ...[
              Text('Square [${_game.colNumbers[col]}, ${_game.rowNumbers[row]}]', style: TextStyle(color: BmbColors.textPrimary, fontSize: 17, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const SizedBox(height: 8),
              Text('${_game.team1} last digit: ${_game.colNumbers[col]}  •  ${_game.team2} last digit: ${_game.rowNumbers[row]}', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            ] else ...[
              Text('Square [Row $row, Col $col]', style: TextStyle(color: BmbColors.textPrimary, fontSize: 17, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const SizedBox(height: 8),
              Text('Numbers will be revealed when the host goes LIVE!', style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.medium)),
            ],
            const SizedBox(height: 12),
            if (pick != null) ...[
              Row(
                children: [
                  Icon(Icons.person, color: pick.userId == _uid ? BmbColors.blue : BmbColors.textSecondary, size: 18),
                  const SizedBox(width: 6),
                  Text('Claimed by: ${pick.userName}${pick.userId == _uid ? " (You)" : ""}',
                    style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pick.creditDeducted
                    ? 'Credits deducted'
                    : 'Credits will be charged at Go LIVE (${_game.creditsPerSquare}/square)',
                style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
              ),
            ] else
              Text('This square is unclaimed', style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
            // Check if this square won any quarter
            ..._game.getWinners().where((w) => w.winningRow == row && w.winningCol == col).map((w) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: BmbColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      '${w.quarter} Winner! ${w.score.team1Score}-${w.score.team2Score} → +${w.prize} credits',
                      style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold),
                    )),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── STATS ROW ────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final myPicks = _game.userPickCount(_uid);
    final myCredits = myPicks * _game.creditsPerSquare;
    final isPending = _game.isUpcoming;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Picked', '${_game.pickedCount}', BmbColors.blue),
          _statItem('Available', '${_game.availableCount}', BmbColors.successGreen),
          _statItem('Your Picks', '$myPicks', BmbColors.gold),
          _statItem(
            isPending ? 'Pending' : 'Charged',
            '${myCredits}c',
            isPending ? BmbColors.gold : BmbColors.errorRed,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
      ],
    );
  }

  // ─── ACTION AREA (status-aware) ───────────────────────────────────────

  Widget _buildActionArea() {
    switch (_game.status) {
      case SquaresStatus.upcoming:
        return _buildUpcomingActions();
      case SquaresStatus.live:
        return _buildLiveActions();
      case SquaresStatus.inProgress:
        return _buildInProgressActions();
      case SquaresStatus.done:
        return _buildDoneActions();
    }
  }

  Widget _buildUpcomingActions() {
    final totalCost = _game.pickedCount * _game.creditsPerSquare;
    final myPicks = _game.userPickCount(_uid);
    final isHost = _game.hostId == _uid;
    return Column(
      children: [
        // ── SHARE BUTTON (host only, upcoming) ────────────────────
        if (isHost) ...[
          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showUpcomingShareSheet();
              },
              icon: const Icon(Icons.share, size: 18),
              label: Text(
                'Share Game — Invite Players',
                style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Visibility badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _game.isPublic
                  ? BmbColors.successGreen.withValues(alpha: 0.08)
                  : const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _game.isPublic
                    ? BmbColors.successGreen.withValues(alpha: 0.3)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _game.isPublic ? Icons.public : Icons.lock,
                  color: _game.isPublic ? BmbColors.successGreen : const Color(0xFF8B5CF6),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _game.isPublic
                        ? 'Public — anyone can find & join this game'
                        : 'Private — only people with the link can join',
                    style: TextStyle(
                      color: _game.isPublic ? BmbColors.successGreen : const Color(0xFF8B5CF6),
                      fontSize: 10, fontWeight: BmbFontWeights.medium, height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // "Make My Picks" button — similar to tournament flow
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _snack('Tap any empty square on the grid to claim it!');
            },
            icon: const Icon(Icons.touch_app, size: 18),
            label: Text(
              myPicks > 0
                  ? 'Keep Picking! ($myPicks/${_game.maxSquaresPerPlayer} squares)'
                  : 'Make My Picks \u2014 Tap Squares to Claim',
              style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Cost preview
        if (_game.pickedCount > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: BmbColors.gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'At Go LIVE: ${_game.pickedCount} squares x ${_game.creditsPerSquare} = $totalCost credits will be deducted & numbers randomly assigned',
                    style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.medium, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        // Go Live button (host only or demo)
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton.icon(
            onPressed: _game.pickedCount > 0 ? _goLive : null,
            icon: const Icon(Icons.flash_on, size: 18),
            label: Text('Start Game — Charge Credits & Lock Board', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.successGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BmbColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _game.autoHost && _game.goLiveDate != null
              ? 'Auto-host is ON. Game will auto-start at Go Live date. Credits charged, numbers assigned & board locked automatically.'
              : 'Starting the game will charge credits, randomly assign numbers, and lock the board. Players who can\'t afford will be released.',
          style: TextStyle(color: BmbColors.textTertiary, fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Squares skip "live" status — this is a fallback if a game somehow ends up in live state.
  Widget _buildLiveActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton.icon(
            onPressed: _startGame,
            icon: const Icon(Icons.sports_score, size: 18),
            label: Text('Start Game — Lock Board', style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Once started, no more squares can be picked or released',
          style: TextStyle(color: BmbColors.textTertiary, fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInProgressActions() {
    final labels = _game.periodLabels;
    final scoredQuarters = _game.scores.map((s) => s.quarter).toSet();

    return Column(
      children: [
        // Score entry section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, color: BmbColors.gold, size: 18),
                  const SizedBox(width: 6),
                  Text('Enter Score', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                  const Spacer(),
                  // ESPN button
                  GestureDetector(
                    onTap: _fetchEspnScores,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BmbColors.errorRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: BmbColors.errorRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sports, color: BmbColors.errorRed, size: 12),
                          const SizedBox(width: 4),
                          Text('ESPN Auto', style: TextStyle(color: BmbColors.errorRed, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Quarter selector chips
              Row(
                children: labels.map((q) {
                  final sel = _selectedQuarter == q;
                  final scored = scoredQuarters.contains(q);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedQuarter = q),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? BmbColors.gold.withValues(alpha: 0.2) : scored ? BmbColors.successGreen.withValues(alpha: 0.1) : BmbColors.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sel ? BmbColors.gold : scored ? BmbColors.successGreen.withValues(alpha: 0.3) : BmbColors.borderColor),
                        ),
                        child: Column(
                          children: [
                            Text(q, style: TextStyle(color: sel ? BmbColors.gold : scored ? BmbColors.successGreen : BmbColors.textSecondary, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                            if (scored) Icon(Icons.check_circle, color: BmbColors.successGreen, size: 10),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              // Score inputs
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(_game.team1, style: TextStyle(color: BmbColors.blue, fontSize: 9, fontWeight: BmbFontWeights.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _scoreT1Ctrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold),
                          decoration: InputDecoration(
                            hintText: '0', hintStyle: TextStyle(color: BmbColors.textTertiary),
                            filled: true, fillColor: BmbColors.cardDark,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.blue)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.blue)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('vs', style: TextStyle(color: BmbColors.textTertiary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(_game.team2, style: TextStyle(color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _scoreT2Ctrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold),
                          decoration: InputDecoration(
                            hintText: '0', hintStyle: TextStyle(color: BmbColors.textTertiary),
                            filled: true, fillColor: BmbColors.cardDark,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.gold)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.gold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: _enterScore,
                        icon: const Icon(Icons.check, size: 16),
                        label: Text('Save $_selectedQuarter', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BmbColors.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: _simulateFullGame,
                      icon: const Icon(Icons.fast_forward, size: 16),
                      label: Text('Simulate', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BmbColors.gold,
                        side: BorderSide(color: BmbColors.gold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoneActions() {
    return SizedBox(
      width: double.infinity, height: 44,
      child: OutlinedButton.icon(
        onPressed: _showShareSheet,
        icon: const Icon(Icons.share, size: 16),
        label: Text('Share Results', style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: BmbColors.blue,
          side: BorderSide(color: BmbColors.blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ─── UPCOMING SHARE SHEET ─────────────────────────────────────────────
  void _showUpcomingShareSheet() {
    final shareMsg = StringBuffer();
    shareMsg.writeln('Join my Squares game on BackMyBracket!');
    shareMsg.writeln('');
    shareMsg.writeln(_game.name);
    shareMsg.writeln('${_game.team1} vs ${_game.team2}');
    shareMsg.writeln('');
    shareMsg.writeln('Sport: ${_game.sportLabel}');
    shareMsg.writeln('Cost: ${_game.creditsPerSquare} credit${_game.creditsPerSquare > 1 ? "s" : ""} per square');
    shareMsg.writeln('Max: ${_game.maxSquaresPerPlayer} squares per player');
    shareMsg.writeln('Prize Pool: ${_game.totalPrizePool} credits');
    shareMsg.writeln('');
    shareMsg.writeln('${_game.availableCount}/100 squares still open!');
    if (_game.goLiveDate != null) {
      final d = _game.goLiveDate!;
      shareMsg.writeln('Locks: ${d.month}/${d.day}/${d.year} at ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}');
    }
    shareMsg.writeln('');
    shareMsg.writeln('backmybracket.com/squares/${_game.id}');
    final shareText = shareMsg.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              // Header
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Share Squares Game', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                  Text('Invite players to join before it locks', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 16),
              // Game summary card
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BmbColors.borderColor, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.grid_4x4, color: BmbColors.gold, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_game.name, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _game.isPublic
                                ? BmbColors.successGreen.withValues(alpha: 0.15)
                                : const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_game.isPublic ? Icons.public : Icons.lock,
                                size: 10,
                                color: _game.isPublic ? BmbColors.successGreen : const Color(0xFF8B5CF6)),
                              const SizedBox(width: 3),
                              Text(_game.isPublic ? 'Public' : 'Private', style: TextStyle(
                                color: _game.isPublic ? BmbColors.successGreen : const Color(0xFF8B5CF6),
                                fontSize: 9, fontWeight: BmbFontWeights.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${_game.team1} vs ${_game.team2}', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _shareInfoChip(Icons.grid_view, '${_game.availableCount} open'),
                        const SizedBox(width: 8),
                        _shareInfoChip(Icons.monetization_on, '${_game.creditsPerSquare}c/sq'),
                        const SizedBox(width: 8),
                        _shareInfoChip(Icons.emoji_events, '${_game.totalPrizePool}c pool'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Share message preview
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BmbColors.borderColor),
                ),
                child: Text(shareText, style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.4)),
              ),
              const SizedBox(height: 20),
              // Share buttons row
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _upcomingShareBtn(ctx, Icons.sms, 'Text', BmbColors.successGreen, shareText),
                _upcomingShareBtn(ctx, Icons.alternate_email, 'X / Twitter', BmbColors.textPrimary, shareText),
                _upcomingShareBtn(ctx, Icons.camera_alt, 'Instagram', const Color(0xFFE1306C), shareText),
                _upcomingShareBtn(ctx, Icons.copy, 'Copy Link', BmbColors.blue, shareText),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BmbColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: BmbColors.gold),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold)),
        ],
      ),
    );
  }

  Widget _upcomingShareBtn(BuildContext ctx, IconData icon, String label, Color color, String text) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        Navigator.pop(ctx);
        _snack('Copied! Share to $label');
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.medium)),
      ]),
    );
  }

  void _showShareSheet() {
    final winners = _game.getWinners();
    final shareMsg = StringBuffer();
    shareMsg.writeln('${_game.name} - Squares Results');
    shareMsg.writeln('${_game.team1} vs ${_game.team2}');
    for (final w in winners) {
      shareMsg.writeln('${w.quarter}: ${w.winner?.userName ?? 'N/A'} (${w.score.team1Score}-${w.score.team2Score})');
    }
    shareMsg.writeln('\nPlayed on BackMyBracket.com');
    final shareText = shareMsg.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Share Results', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                  Text(_game.name, style: TextStyle(color: BmbColors.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
              ]),
              const SizedBox(height: 20),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
                child: Text(shareText, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.5)),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _shareBtn(ctx, Icons.sms, 'Text', BmbColors.successGreen, shareText),
                _shareBtn(ctx, Icons.alternate_email, 'X / Twitter', BmbColors.textPrimary, shareText),
                _shareBtn(ctx, Icons.camera_alt, 'Instagram', const Color(0xFFE1306C), shareText),
                _shareBtn(ctx, Icons.copy, 'Copy Link', BmbColors.blue, shareText),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareBtn(BuildContext ctx, IconData icon, String label, Color color, String text) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        Navigator.pop(ctx);
        _snack('Copied! Share to $label');
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.medium)),
      ]),
    );
  }

  // ─── WINNERS SECTION ──────────────────────────────────────────────────

  Widget _buildWinnersSection() {
    final winners = _game.getWinners();
    final leaderboard = _game.getLeaderboard();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [BmbColors.gold.withValues(alpha: 0.08), BmbColors.cardGradientEnd],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: BmbColors.gold, size: 20),
              const SizedBox(width: 8),
              Text('Quarter Winners', style: TextStyle(color: BmbColors.gold, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            ],
          ),
          const SizedBox(height: 12),

          // Each quarter winner card
          ...winners.map((w) {
            final isMyWin = w.hasWinner && w.winner!.userId == _uid;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMyWin ? BmbColors.gold.withValues(alpha: 0.12) : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isMyWin ? BmbColors.gold.withValues(alpha: 0.5) : BmbColors.borderColor),
              ),
              child: Row(
                children: [
                  // Quarter badge
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: w.score.isFinal ? BmbColors.gold.withValues(alpha: 0.2) : BmbColors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(w.quarter, style: TextStyle(color: w.score.isFinal ? BmbColors.gold : BmbColors.blue, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                          if (w.score.isFinal) Text('FINAL', style: TextStyle(color: BmbColors.gold, fontSize: 6, fontWeight: BmbFontWeights.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Score + winner info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_game.team1} ${w.score.team1Score} — ${_game.team2} ${w.score.team2Score}',
                          style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                        Text(
                          'Last digits: ${w.score.team1Score % 10}, ${w.score.team2Score % 10}',
                          style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
                        ),
                        if (w.hasWinner) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${w.winner!.userName}${isMyWin ? " (You!)" : ""}',
                            style: TextStyle(
                              color: isMyWin ? BmbColors.gold : BmbColors.successGreen,
                              fontSize: 12, fontWeight: BmbFontWeights.bold,
                            ),
                          ),
                        ] else
                          Text('No winner (unclaimed square)', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                      ],
                    ),
                  ),
                  // Prize
                  if (w.prize > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BmbColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('+${w.prize}c', style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                    ),
                ],
              ),
            );
          }),

          // Leaderboard
          if (leaderboard.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Leaderboard', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 8),
            ...leaderboard.asMap().entries.map((e) {
              final idx = e.key;
              final p = e.value;
              final isMe = p.userId == _uid;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? BmbColors.gold.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 22, child: Text('#${idx + 1}', style: TextStyle(color: idx == 0 ? BmbColors.gold : BmbColors.textTertiary, fontSize: 12, fontWeight: BmbFontWeights.bold))),
                    Expanded(child: Text('${p.userName}${isMe ? " (You)" : ""}', style: TextStyle(color: isMe ? BmbColors.gold : BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold))),
                    Text('${p.quartersWon}Q', style: TextStyle(color: BmbColors.textSecondary, fontSize: 10)),
                    const SizedBox(width: 8),
                    Text('${p.totalCredits}c', style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── HELPER WIDGETS ───────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold));

  Widget _textField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: BmbColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
        filled: true, fillColor: BmbColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.blue)),
      ),
    );
  }

  Widget _chipRow(List<int> values, int selected, ValueChanged<int> onChanged) {
    return Row(
      children: values.map((v) {
        final sel = selected == v;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(v),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? BmbColors.blue.withValues(alpha: 0.15) : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sel ? BmbColors.blue : BmbColors.borderColor),
              ),
              child: Center(child: Text('$v', style: TextStyle(color: sel ? BmbColors.blue : BmbColors.textSecondary, fontSize: 13, fontWeight: sel ? BmbFontWeights.bold : BmbFontWeights.medium))),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData get _sportIcon {
    switch (_game.sport) {
      case SquaresSport.football: return Icons.sports_football;
      case SquaresSport.basketball: return Icons.sports_basketball;
      case SquaresSport.hockey: return Icons.sports_hockey;
      case SquaresSport.lacrosse: return Icons.sports;
      case SquaresSport.soccer: return Icons.sports_soccer;
      case SquaresSport.other: return Icons.grid_4x4;
    }
  }

  Color get _sportColor {
    switch (_game.sport) {
      case SquaresSport.football: return const Color(0xFF795548);
      case SquaresSport.basketball: return const Color(0xFFFF6B35);
      case SquaresSport.hockey: return BmbColors.blue;
      case SquaresSport.lacrosse: return BmbColors.successGreen;
      case SquaresSport.soccer: return const Color(0xFF388E3C);
      case SquaresSport.other: return BmbColors.gold;
    }
  }
}
