import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/companion/data/companion_model.dart';
import 'package:bmb_mobile/features/companion/data/companion_service.dart';
import 'package:bmb_mobile/features/companion/data/companion_audio_player_stub.dart'
    if (dart.library.js_interop) 'package:bmb_mobile/features/companion/data/companion_audio_player.dart';

/// Floating companion avatar that appears on any screen.
/// Shows the user's chosen companion with an expandable speech bubble.
///
/// Usage: Wrap any screen's Scaffold body with a Stack and add this widget:
/// ```dart
/// Stack(children: [
///   YourScreenContent(),
///   FloatingCompanion(message: 'Welcome to this screen!'),
/// ])
/// ```
class FloatingCompanion extends StatefulWidget {
  /// The message to display in the speech bubble.
  final String? message;

  /// Optional voice URL to play when tapped.
  final String? voiceUrl;

  /// Position from bottom.
  final double bottom;

  /// Position from right.
  final double right;

  /// Whether the bubble starts expanded.
  final bool initiallyExpanded;

  /// Called when the companion is dismissed.
  final VoidCallback? onDismiss;

  const FloatingCompanion({
    super.key,
    this.message,
    this.voiceUrl,
    this.bottom = 80,
    this.right = 12,
    this.initiallyExpanded = false,
    this.onDismiss,
  });

  @override
  State<FloatingCompanion> createState() => _FloatingCompanionState();
}

class _FloatingCompanionState extends State<FloatingCompanion>
    with TickerProviderStateMixin {
  bool _expanded = false;
  bool _isPlaying = false;
  final CompanionAudioPlayer _player = CompanionAudioPlayer();

  late final AnimationController _floatAnim;
  late final AnimationController _glowAnim;
  late final AnimationController _bubbleAnim;

  CompanionPersona? _persona;

  @override
  void initState() {
    super.initState();
    _persona = CompanionService.instance.selectedCompanion;
    _expanded = widget.initiallyExpanded;

    _floatAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _glowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _bubbleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (_expanded) _bubbleAnim.forward();

    _player.onComplete = () {
      if (mounted) setState(() => _isPlaying = false);
    };
  }

  @override
  void dispose() {
    _floatAnim.dispose();
    _glowAnim.dispose();
    _bubbleAnim.dispose();
    _player.dispose();
    super.dispose();
  }

  void _toggleBubble() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _bubbleAnim.forward();
    } else {
      _bubbleAnim.reverse();
    }
  }

  Future<void> _playVoice() async {
    final url = widget.voiceUrl ?? _persona?.voiceIntroUrl;
    if (url == null) return;

    if (_isPlaying) {
      _player.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);
    try {
      await _player.play(url);
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_persona == null) return const SizedBox.shrink();

    final service = CompanionService.instance;
    if (!service.companionVisible) return const SizedBox.shrink();

    return Positioned(
      right: widget.right,
      bottom: widget.bottom,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Speech bubble ──
          if (widget.message != null)
            AnimatedBuilder(
              animation: _bubbleAnim,
              builder: (_, child) {
                return Opacity(
                  opacity: _bubbleAnim.value,
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * _bubbleAnim.value,
                    alignment: Alignment.bottomRight,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 200,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0D1B4A).withValues(alpha: 0.97),
                      const Color(0xFF1A237E).withValues(alpha: 0.97),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _persona!.name,
                          style: TextStyle(
                            color: const Color(0xFF00E5FF),
                            fontSize: 10,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        // Voice toggle
                        if (service.voiceEnabled && (widget.voiceUrl != null || _persona!.voiceIntroUrl.isNotEmpty))
                          GestureDetector(
                            onTap: _playVoice,
                            child: Icon(
                              _isPlaying ? Icons.stop_circle : Icons.volume_up,
                              color: _isPlaying
                                  ? const Color(0xFF00E5FF)
                                  : BmbColors.textTertiary,
                              size: 16,
                            ),
                          ),
                        const SizedBox(width: 6),
                        // Close bubble
                        GestureDetector(
                          onTap: _toggleBubble,
                          child: const Icon(Icons.close,
                              color: BmbColors.textTertiary, size: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Avatar ──
          GestureDetector(
            onTap: _toggleBubble,
            child: AnimatedBuilder(
              animation: Listenable.merge([_floatAnim, _glowAnim]),
              builder: (_, __) {
                final floatY = -5 * _floatAnim.value;
                final g = _glowAnim.value;
                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00E5FF)
                            .withValues(alpha: 0.5 + 0.3 * g),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: 0.15 + 0.1 * g),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _persona!.circleAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: BmbColors.cardDark,
                          child: Center(
                            child: Text(
                              _persona!.name[0],
                              style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 22,
                                fontWeight: BmbFontWeights.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
