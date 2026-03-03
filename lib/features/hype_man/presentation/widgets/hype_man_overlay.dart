import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/hype_man/data/services/hype_man_service.dart';

/// A persistent overlay that displays the BMB Hype Man speech bubble
/// on top of any screen. Wrap your MaterialApp (or top-level scaffold)
/// with this widget so the Hype Man can talk from anywhere.
///
/// Usage:
/// ```dart
/// HypeManOverlay(
///   child: DashboardScreen(),
/// )
/// ```
class HypeManOverlay extends StatefulWidget {
  final Widget child;
  const HypeManOverlay({super.key, required this.child});

  @override
  State<HypeManOverlay> createState() => HypeManOverlayState();

  /// Global key so any screen can access the overlay to trigger hype.
  static final globalKey = GlobalKey<HypeManOverlayState>();
}

class HypeManOverlayState extends State<HypeManOverlay>
    with TickerProviderStateMixin {
  final _hype = HypeManService.instance;

  String? _currentSpeech;
  bool _showBubble = false;
  Timer? _bubbleTimer;
  late AnimationController _slideAnim;
  late AnimationController _pulseAnim;
  late Animation<Offset> _slideOffset;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    // Slide in from top
    _slideAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slideOffset = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideAnim, curve: Curves.elasticOut));
    _scaleAnim = CurvedAnimation(parent: _slideAnim, curve: Curves.elasticOut);

    // Pulse glow for the avatar
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _hookIntoHypeMan();
  }

  void _hookIntoHypeMan() {
    _hype.onSpeechStart = (text) {
      if (!mounted) return;
      setState(() {
        _currentSpeech = text;
        _showBubble = true;
      });
      _slideAnim.forward(from: 0);
      _pulseAnim.repeat(reverse: true);

      // Auto-dismiss after 5 seconds
      _bubbleTimer?.cancel();
      _bubbleTimer = Timer(const Duration(seconds: 5), _dismissBubble);
    };

    _hype.onSpeechEnd = () {
      // Let the timer handle dismissal — don't hide immediately
      // so users can read the text even after TTS finishes.
    };
  }

  void _dismissBubble() {
    if (!mounted) return;
    _slideAnim.reverse();
    _pulseAnim.stop();
    _pulseAnim.value = 0;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showBubble = false);
    });
  }

  /// Programmatically fire a hype trigger from anywhere.
  void fire(HypeTrigger trigger, {String? context}) {
    _hype.trigger(trigger, context: context);
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _slideAnim.dispose();
    _pulseAnim.dispose();
    _hype.onSpeechStart = null;
    _hype.onSpeechEnd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Floating speech bubble at top
        if (_showBubble && _currentSpeech != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slideOffset,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: GestureDetector(
                  onTap: _dismissBubble,
                  child: _buildBubble(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BmbColors.gold.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: BmbColors.gold.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated avatar
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) {
              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [BmbColors.gold, const Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: BmbColors.gold.withValues(alpha: 0.3 + (_pulseAnim.value * 0.3)),
                      blurRadius: 8 + (_pulseAnim.value * 8),
                      spreadRadius: _pulseAnim.value * 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.record_voice_over, color: Colors.white, size: 22),
              );
            },
          ),
          const SizedBox(width: 12),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('BMB HYPE MAN',
                        style: TextStyle(
                          color: BmbColors.gold,
                          fontSize: 10,
                          fontWeight: BmbFontWeights.bold,
                          letterSpacing: 1.2,
                        )),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: BmbColors.vipPurple.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                          switch (_hype.voice) {
                            HypeVoice.mark => 'MARK',
                            HypeVoice.eve => 'EVE',
                            HypeVoice.chris => 'CHRIS',
                          },
                          style: TextStyle(
                            color: BmbColors.vipPurple,
                            fontSize: 8,
                            fontWeight: BmbFontWeights.bold,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentSpeech!,
                  style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.medium,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Sound wave indicator
          if (_hype.isSpeaking) _buildSoundWave(),
          // Dismiss X
          GestureDetector(
            onTap: () {
              _hype.stop();
              _dismissBubble();
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.close, color: BmbColors.textTertiary, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundWave() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: _AnimatedWaveBar(
            delay: Duration(milliseconds: i * 150),
            color: BmbColors.gold,
          ),
        );
      }),
    );
  }
}

// ─── ANIMATED WAVE BAR ──────────────────────────────────────────────────

class _AnimatedWaveBar extends StatefulWidget {
  final Duration delay;
  final Color color;
  const _AnimatedWaveBar({required this.delay, required this.color});

  @override
  State<_AnimatedWaveBar> createState() => _AnimatedWaveBarState();
}

class _AnimatedWaveBarState extends State<_AnimatedWaveBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _height;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _height = Tween<double>(begin: 4, end: 14).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _height,
      builder: (_, __) => Container(
        width: 3,
        height: _height.value,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
