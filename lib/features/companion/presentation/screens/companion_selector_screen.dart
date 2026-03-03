import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/companion/data/companion_model.dart';
import 'package:bmb_mobile/features/companion/data/companion_service.dart';
import 'package:bmb_mobile/features/companion/data/companion_audio_player_stub.dart'
    if (dart.library.js_interop) 'package:bmb_mobile/features/companion/data/companion_audio_player.dart';

/// Full-screen companion picker shown to first-timers (or from Settings).
class CompanionSelectorScreen extends StatefulWidget {
  /// If true, navigates to dashboard after selection.
  /// If false (from settings), just pops back.
  final bool isOnboarding;

  const CompanionSelectorScreen({super.key, this.isOnboarding = true});

  @override
  State<CompanionSelectorScreen> createState() => _CompanionSelectorScreenState();
}

class _CompanionSelectorScreenState extends State<CompanionSelectorScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isPlaying = false;
  bool _confirmed = false;
  final CompanionAudioPlayer _player = CompanionAudioPlayer();

  late final AnimationController _pulseAnim;
  late final AnimationController _glowAnim;
  late final AnimationController _slideAnim;

  CompanionPersona get _selected => CompanionPersona.all[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _slideAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _player.onComplete = () {
      if (mounted) setState(() => _isPlaying = false);
    };
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    _glowAnim.dispose();
    _slideAnim.dispose();
    _player.dispose();
    super.dispose();
  }

  void _onSelect(int index) {
    if (index == _selectedIndex) return;
    _slideAnim.reverse().then((_) {
      setState(() => _selectedIndex = index);
      _slideAnim.forward();
    });
    _player.stop();
    setState(() => _isPlaying = false);
  }

  Future<void> _playVoice() async {
    if (_isPlaying) {
      _player.stop();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    try {
      await _player.play(_selected.voiceIntroUrl);
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirmed = true);
    await CompanionService.instance.selectCompanion(_selected);

    if (!mounted) return;

    if (widget.isOnboarding) {
      // Go to dashboard (replace stack so they can't go back)
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildAvatarRow(),
              const SizedBox(height: 16),
              Expanded(child: _buildSelectedDetail()),
              _buildConfirmButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          if (!widget.isOnboarding)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: BmbColors.textPrimary, size: 18),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Choose Your BMB Companion',
            style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 22,
              fontWeight: BmbFontWeights.bold,
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your companion guides you through brackets, delivers tips, and keeps you in the game.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BmbColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Three avatar pills ──
  Widget _buildAvatarRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(CompanionPersona.all.length, (i) {
          final persona = CompanionPersona.all[i];
          final active = i == _selectedIndex;
          return GestureDetector(
            onTap: () => _onSelect(i),
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, child) {
                final g = _glowAnim.value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: active ? 88 : 68,
                  height: active ? 88 : 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active
                          ? const Color(0xFF00E5FF)
                          : BmbColors.borderColor,
                      width: active ? 3 : 1.5,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.25 + 0.15 * g),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      persona.circleAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: BmbColors.cardDark,
                        child: Center(
                          child: Text(
                            persona.name[0],
                            style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: active ? 28 : 20,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  // ── Selected companion detail card ──
  Widget _buildSelectedDetail() {
    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (_, child) {
        return Opacity(
          opacity: _slideAnim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _slideAnim.value)),
            child: child,
          ),
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // ── Large portrait ──
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) {
                final p = _pulseAnim.value;
                return Container(
                  width: 200,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E5FF)
                          .withValues(alpha: 0.4 + 0.2 * p),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF)
                            .withValues(alpha: 0.1 + 0.1 * p),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      _selected.fullAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: BmbColors.cardDark,
                        child: const Icon(Icons.person,
                            color: BmbColors.textTertiary, size: 64),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Name + nickname ──
            Text(
              _selected.name,
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 26,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selected.nickname,
                style: TextStyle(
                  color: const Color(0xFF00E5FF),
                  fontSize: 12,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Tagline speech bubble ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0D1B4A).withValues(alpha: 0.95),
                    const Color(0xFF1A237E).withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '"${_selected.tagline}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Play voice button
                  GestureDetector(
                    onTap: _playVoice,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isPlaying
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                            : BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isPlaying
                              ? const Color(0xFF00E5FF)
                              : BmbColors.borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isPlaying
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up,
                            color: _isPlaying
                                ? const Color(0xFF00E5FF)
                                : BmbColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPlaying ? 'Playing...' : 'Hear ${_selected.name}\'s Voice',
                            style: TextStyle(
                              color: _isPlaying
                                  ? const Color(0xFF00E5FF)
                                  : BmbColors.textSecondary,
                              fontSize: 12,
                              fontWeight: BmbFontWeights.semiBold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Description ──
            Text(
              _selected.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Confirm button ──
  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _confirmed ? null : _confirm,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) {
            final p = _pulseAnim.value;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(0xFF00E5FF).withValues(alpha: 0.2 + 0.1 * p),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _confirmed
                    ? 'Setting up...'
                    : widget.isOnboarding
                        ? 'Choose ${_selected.name} & Start'
                        : 'Switch to ${_selected.name}',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _confirmed ? Icons.check_circle : Icons.arrow_forward,
                color: Colors.black,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
