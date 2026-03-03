import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';

// ═══════════════════════════════════════════════════════════════
//  HOLOGRAM GUIDE PREVIEW — Standalone demos for V2 + V4
// ═══════════════════════════════════════════════════════════════

/// Preview launcher — lets you toggle between V2 and V4 demos
class HologramGuidePreview extends StatefulWidget {
  const HologramGuidePreview({super.key});

  @override
  State<HologramGuidePreview> createState() => _HologramGuidePreviewState();
}

class _HologramGuidePreviewState extends State<HologramGuidePreview> {
  bool _showV4 = true; // start with the first-timer experience

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient)),

          // Mode switch at top
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: BmbColors.cardDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: BmbColors.textPrimary, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hologram Guide Preview',
                          style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: BmbColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BmbColors.borderColor),
                    ),
                    child: Row(
                      children: [
                        _modeTab('V4: Full Tutorial', 'First-Timer', _showV4, () => setState(() => _showV4 = true)),
                        _modeTab('V2: Character Guide', 'Return User', !_showV4, () => setState(() => _showV4 = false)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _showV4
                        ? const _V4TutorialModeDemo(key: ValueKey('v4'))
                        : const _V2CharacterGuideDemo(key: ValueKey('v2')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(String title, String subtitle, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)])
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(title, style: TextStyle(
                color: active ? Colors.black : BmbColors.textSecondary,
                fontSize: 12,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              )),
              Text(subtitle, style: TextStyle(
                color: active ? Colors.black54 : BmbColors.textTertiary,
                fontSize: 9,
              )),
            ],
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
//  V4 — FULL TUTORIAL MODE (First-Timer Experience)
// ═══════════════════════════════════════════════════════════════

class _V4TutorialModeDemo extends StatefulWidget {
  const _V4TutorialModeDemo({super.key});

  @override
  State<_V4TutorialModeDemo> createState() => _V4TutorialModeDemoState();
}

class _V4TutorialModeDemoState extends State<_V4TutorialModeDemo>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _showConfetti = false;
  late final AnimationController _spotlightAnim;
  late final AnimationController _confettiAnim;
  late final AnimationController _pulseAnim;

  static const _steps = [
    _TutorialStep(
      title: 'Choose Your Bracket Type',
      description: 'Standard is the most popular! Pick the format that fits your event.',
      icon: Icons.category,
      spotlightRect: Rect.fromLTWH(20, 120, 340, 280),
      guideMessage: 'Welcome! Let\'s build your first bracket. Start by picking a type!',
    ),
    _TutorialStep(
      title: 'Name Your Bracket',
      description: 'Give it a catchy name! Something like "March Madness 2025" or "Office Pizza Wars".',
      icon: Icons.edit,
      spotlightRect: Rect.fromLTWH(20, 80, 340, 100),
      guideMessage: 'Great choice! Now give your bracket a name that stands out.',
    ),
    _TutorialStep(
      title: 'Choose a Template',
      description: 'Pick a pre-built template or create your own custom size.',
      icon: Icons.dashboard_customize,
      spotlightRect: Rect.fromLTWH(20, 200, 340, 200),
      guideMessage: 'Templates make setup quick. You can always customize later!',
    ),
    _TutorialStep(
      title: 'Add Team Names',
      description: 'Enter your teams, use search to find real teams, or fill all with TBD.',
      icon: Icons.group,
      spotlightRect: Rect.fromLTWH(20, 80, 340, 320),
      guideMessage: 'Fill in your teams! Use the search icon for real team names.',
    ),
    _TutorialStep(
      title: 'Set Entry & Tie-Breaker',
      description: 'Choose free or paid entry, then set a tie-breaker game.',
      icon: Icons.savings,
      spotlightRect: Rect.fromLTWH(20, 80, 340, 200),
      guideMessage: 'Almost there! Choose how players join and set a tie-breaker.',
    ),
    _TutorialStep(
      title: 'Pick Your Prize',
      description: 'BMB Store, Custom Prize, Charity, or just bragging rights!',
      icon: Icons.emoji_events,
      spotlightRect: Rect.fromLTWH(20, 80, 340, 280),
      guideMessage: 'The fun part! What does the winner get?',
    ),
    _TutorialStep(
      title: 'Set Go Live Date',
      description: 'Schedule when your tournament opens. Players get notified!',
      icon: Icons.calendar_today,
      spotlightRect: Rect.fromLTWH(20, 120, 340, 180),
      guideMessage: 'Set when this goes live. Players will be notified automatically!',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _spotlightAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _confettiAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _spotlightAnim.forward();
  }

  @override
  void dispose() {
    _spotlightAnim.dispose();
    _confettiAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _spotlightAnim.reverse().then((_) {
        setState(() => _currentStep++);
        _spotlightAnim.forward();
      });
    } else {
      // Final step — celebrate!
      setState(() => _showConfetti = true);
      _confettiAnim.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showConfetti = false);
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _spotlightAnim.reverse().then((_) {
        setState(() => _currentStep--);
        _spotlightAnim.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    return Stack(
      children: [
        // ── Fake bracket builder content (simulated sections) ──
        _buildFakeContent(),

        // ── Spotlight overlay ──
        AnimatedBuilder(
          animation: _spotlightAnim,
          builder: (_, __) {
            return CustomPaint(
              size: Size.infinite,
              painter: _SpotlightPainter(
                spotlightRect: step.spotlightRect,
                progress: _spotlightAnim.value,
                pulseValue: _pulseAnim.value,
              ),
            );
          },
        ),

        // ── Guide speech bubble + character at bottom ──
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildGuidePanel(step),
        ),

        // ── Step indicator dots ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) {
              final active = i == _currentStep;
              final completed = i < _currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: completed
                      ? BmbColors.successGreen
                      : active
                          ? const Color(0xFF00E5FF)
                          : BmbColors.borderColor,
                  boxShadow: active
                      ? [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), blurRadius: 8)]
                      : null,
                ),
              );
            }),
          ),
        ),

        // ── Confetti ──
        if (_showConfetti) _buildConfetti(),
      ],
    );
  }

  Widget _buildFakeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulated page header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.borderColor, width: 0.5),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_steps[_currentStep].icon, color: BmbColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Step ${_currentStep + 1} of ${_steps.length}',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                  Text(_steps[_currentStep].title,
                      style: TextStyle(
                        color: BmbColors.textPrimary, fontSize: 16,
                        fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
                      )),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Simulated form sections
          ...List.generate(4, (i) => _fakeSection(i)),
        ],
      ),
    );
  }

  Widget _fakeSection(int index) {
    final labels = ['Primary Selection', 'Details', 'Options', 'Configuration'];
    final icons = [Icons.check_circle_outline, Icons.text_fields, Icons.tune, Icons.settings];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2137FF), Color(0xFF2137FF)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${_currentStep + 1}${String.fromCharCode(97 + index)}',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            ),
            const SizedBox(width: 8),
            Icon(icons[index], color: BmbColors.textSecondary, size: 16),
            const SizedBox(width: 6),
            Text(labels[index], style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
          ]),
          const SizedBox(height: 10),
          // Fake input fields
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: BmbColors.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BmbColors.borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text('Tap to fill...', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
          ),
          if (index == 0) ...[
            const SizedBox(height: 8),
            Row(children: List.generate(3, (j) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: j < 2 ? 8 : 0),
                height: 44,
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: j == 0 ? BmbColors.gold : BmbColors.borderColor, width: j == 0 ? 1.5 : 0.5),
                ),
                child: Center(child: Text('Option ${j + 1}',
                    style: TextStyle(color: j == 0 ? BmbColors.gold : BmbColors.textTertiary, fontSize: 11))),
              ),
            ))),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidePanel(_TutorialStep step) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) {
        final t = _pulseAnim.value;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0D1B4A).withValues(alpha: 0.97),
                const Color(0xFF1A237E).withValues(alpha: 0.97),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3 + 0.2 * t),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.1 + 0.1 * t),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Guide avatar + message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              _buildTutorialAvatar(),
              const SizedBox(width: 12),
              // Message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BMB Guide', style: TextStyle(
                      color: const Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay',
                      letterSpacing: 0.5,
                    )),
                    const SizedBox(height: 4),
                    Text(step.guideMessage, style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Navigation buttons
          Row(
            children: [
              if (_currentStep > 0)
                GestureDetector(
                  onTap: _prevStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: BmbColors.borderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Back', style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12, fontWeight: BmbFontWeights.semiBold,
                    )),
                  ),
                ),
              const Spacer(),
              // Skip tutorial
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Tutorial skipped! You\'re now in normal mode.'),
                    backgroundColor: BmbColors.midNavy,
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: Text('Skip Tutorial', style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 11,
                  decoration: TextDecoration.underline,
                  decorationColor: BmbColors.textTertiary,
                )),
              ),
              const SizedBox(width: 12),
              // Next / Finish
              GestureDetector(
                onTap: _nextStep,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _currentStep < _steps.length - 1 ? 'Next' : 'Finish!',
                      style: TextStyle(
                        color: Colors.black, fontSize: 13,
                        fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
                      ),
                    ),
                    if (_currentStep < _steps.length - 1) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, color: Colors.black, size: 16),
                    ] else ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.celebration, color: Colors.black, size: 16),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) {
        final t = _pulseAnim.value;
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00E5FF).withValues(alpha: 0.8 + 0.2 * t),
                const Color(0xFF2979FF).withValues(alpha: 0.8 + 0.2 * t),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2 + 0.15 * t),
                blurRadius: 12 + 6 * t,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Text('B', style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'ClashDisplay',
            )),
          ),
        );
      },
    );
  }

  Widget _buildConfetti() {
    return AnimatedBuilder(
      animation: _confettiAnim,
      builder: (_, __) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(progress: _confettiAnim.value),
        );
      },
    );
  }
}

// ── Spotlight overlay painter ──
class _SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;
  final double progress;
  final double pulseValue;

  _SpotlightPainter({
    required this.spotlightRect,
    required this.progress,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dimmed background
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7 * progress);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);

    // Cut out the spotlight area
    final inflate = 4.0 + 4.0 * pulseValue;
    final rect = spotlightRect.inflate(inflate);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Clear the spotlight area
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear;
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
    canvas.drawRRect(rrect, clearPaint);
    canvas.restore();

    // Glowing border around spotlight
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6 + 0.4 * pulseValue);
    canvas.drawRRect(rrect, glowPaint);

    // Outer glow
    final outerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.1 + 0.1 * pulseValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect.inflate(4), outerGlow);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => true;
}

// ── Confetti painter ──
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Random _random = Random(42);

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFF00E5FF),
      const Color(0xFFFF6B35),
      const Color(0xFF4CAF50),
      const Color(0xFF9B59FF),
      const Color(0xFFE53935),
      const Color(0xFF2979FF),
    ];

    for (int i = 0; i < 60; i++) {
      final x = _random.nextDouble() * size.width;
      final startY = -20.0 - _random.nextDouble() * 100;
      final endY = size.height + 20;
      final y = startY + (endY - startY) * progress;
      final rotation = progress * pi * 4 * (_random.nextBool() ? 1 : -1);
      final color = colors[i % colors.length];
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Draw small rectangles as confetti
      final w = 4.0 + _random.nextDouble() * 6;
      final h = 3.0 + _random.nextDouble() * 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), const Radius.circular(1)),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}


// ═══════════════════════════════════════════════════════════════
//  V2 — ANIMATED CHARACTER GUIDE (Return-User Experience)
// ═══════════════════════════════════════════════════════════════

class _V2CharacterGuideDemo extends StatefulWidget {
  const _V2CharacterGuideDemo({super.key});

  @override
  State<_V2CharacterGuideDemo> createState() => _V2CharacterGuideDemoState();
}

class _V2CharacterGuideDemoState extends State<_V2CharacterGuideDemo>
    with TickerProviderStateMixin {
  int _selectedCharacter = 0; // 0 = Robot, 1 = Hologram, 2 = Coach
  int _demoAction = 0; // 0 = idle, 1 = wave, 2 = point, 3 = celebrate

  late final AnimationController _idleAnim;
  late final AnimationController _waveAnim;
  late final AnimationController _pointAnim;
  late final AnimationController _celebrateAnim;
  late final AnimationController _floatAnim;
  late final AnimationController _glowAnim;
  bool _speechVisible = true;

  final _characterNames = ['Robot Mascot', 'Hologram Guide', 'Cartoon Coach'];
  final _characterDescriptions = [
    'Techy, playful, fits the bracket/gaming vibe',
    'Futuristic, minimal, glowing silhouette outline',
    'Sporty character with whistle & clipboard energy',
  ];

  @override
  void initState() {
    super.initState();
    _idleAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _waveAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pointAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _celebrateAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _floatAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _glowAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleAnim.dispose();
    _waveAnim.dispose();
    _pointAnim.dispose();
    _celebrateAnim.dispose();
    _floatAnim.dispose();
    _glowAnim.dispose();
    super.dispose();
  }

  void _triggerAnimation(int action) {
    setState(() => _demoAction = action);
    switch (action) {
      case 1: // wave
        _waveAnim.forward(from: 0).then((_) => _waveAnim.reverse());
        break;
      case 2: // point
        _pointAnim.forward(from: 0);
        break;
      case 3: // celebrate
        _celebrateAnim.forward(from: 0).then((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _celebrateAnim.reverse();
          });
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Character selector ──
          Text('Choose a Character Style:', style: TextStyle(
            color: BmbColors.textPrimary, fontSize: 14,
            fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
          )),
          const SizedBox(height: 10),
          Row(
            children: List.generate(3, (i) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCharacter = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: _selectedCharacter == i
                        ? const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)])
                        : BmbColors.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedCharacter == i ? const Color(0xFF00E5FF) : BmbColors.borderColor,
                      width: _selectedCharacter == i ? 1.5 : 0.5,
                    ),
                    boxShadow: _selectedCharacter == i
                        ? [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.25), blurRadius: 12)]
                        : null,
                  ),
                  child: Column(children: [
                    _buildMiniCharacter(i),
                    const SizedBox(height: 6),
                    Text(_characterNames[i], textAlign: TextAlign.center, style: TextStyle(
                      color: _selectedCharacter == i ? Colors.black : BmbColors.textPrimary,
                      fontSize: 9, fontWeight: BmbFontWeights.bold,
                    )),
                  ]),
                ),
              ),
            )),
          ),
          const SizedBox(height: 6),
          Text(_characterDescriptions[_selectedCharacter], style: TextStyle(
            color: BmbColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic,
          )),
          const SizedBox(height: 20),

          // ── Large character preview ──
          Center(
            child: _buildLargeCharacter(),
          ),
          const SizedBox(height: 16),

          // ── Animation triggers ──
          Text('Trigger Animations:', style: TextStyle(
            color: BmbColors.textPrimary, fontSize: 14,
            fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
          )),
          const SizedBox(height: 10),
          Row(
            children: [
              _animButton('Idle', Icons.hourglass_empty, 0),
              _animButton('Wave', Icons.waving_hand, 1),
              _animButton('Point', Icons.touch_app, 2),
              _animButton('Celebrate', Icons.celebration, 3),
            ],
          ),
          const SizedBox(height: 20),

          // ── Speech bubble toggle ──
          Text('Speech Bubble Preview:', style: TextStyle(
            color: BmbColors.textPrimary, fontSize: 14,
            fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
          )),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _speechVisible = !_speechVisible),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _speechVisible ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _speechVisible ? const Color(0xFF00E5FF) : BmbColors.borderColor),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_speechVisible ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    color: _speechVisible ? const Color(0xFF00E5FF) : BmbColors.textTertiary, size: 16),
                const SizedBox(width: 8),
                Text(_speechVisible ? 'Speech Bubble ON' : 'Speech Bubble OFF',
                    style: TextStyle(color: _speechVisible ? const Color(0xFF00E5FF) : BmbColors.textTertiary, fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── How it would look in-app ──
          Text('In-App Position Preview:', style: TextStyle(
            color: BmbColors.textPrimary, fontSize: 14,
            fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
          )),
          const SizedBox(height: 10),
          _buildInAppPreview(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _animButton(String label, IconData icon, int action) {
    final active = _demoAction == action;
    return Expanded(
      child: GestureDetector(
        onTap: () => _triggerAnimation(action),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)])
                : BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFF00E5FF) : BmbColors.borderColor,
              width: active ? 1.5 : 0.5,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: active ? Colors.black : BmbColors.textSecondary, size: 18),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              color: active ? Colors.black : BmbColors.textTertiary,
              fontSize: 9, fontWeight: BmbFontWeights.bold,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildMiniCharacter(int type) {
    switch (type) {
      case 0: return _miniRobot();
      case 1: return _miniHologram();
      case 2: return _miniCoach();
      default: return _miniRobot();
    }
  }

  // ── MINI AVATARS ──
  Widget _miniRobot() {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF2979FF)]),
        boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: const Center(child: Text('\u{1F916}', style: TextStyle(fontSize: 20))),
    );
  }

  Widget _miniHologram() {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [const Color(0xFF00E5FF).withValues(alpha: 0.3), const Color(0xFF00B0FF).withValues(alpha: 0.1)],
        ),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.2), blurRadius: 12)],
      ),
      child: const Center(child: Text('\u{1F47B}', style: TextStyle(fontSize: 18))),
    );
  }

  Widget _miniCoach() {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFD700)]),
        boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: const Center(child: Text('\u{1F3C8}', style: TextStyle(fontSize: 20))),
    );
  }

  // ── LARGE CHARACTER with animations ──
  Widget _buildLargeCharacter() {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleAnim, _floatAnim, _glowAnim, _waveAnim, _pointAnim, _celebrateAnim]),
      builder: (_, __) {
        final floatOffset = -8 * _floatAnim.value;
        final breathScale = 1.0 + 0.03 * _idleAnim.value;
        final waveRotation = _demoAction == 1 ? sin(_waveAnim.value * pi * 3) * 0.15 : 0.0;
        final celebrateScale = _demoAction == 3 ? 1.0 + 0.15 * sin(_celebrateAnim.value * pi * 2) : 1.0;
        final glowAlpha = 0.15 + 0.15 * _glowAnim.value;

        return Transform.translate(
          offset: Offset(_demoAction == 2 ? 10 * _pointAnim.value : 0, floatOffset),
          child: Transform.scale(
            scale: breathScale * celebrateScale,
            child: Transform.rotate(
              angle: waveRotation,
              child: Column(
                children: [
                  // Character body
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _characterGradient(_selectedCharacter),
                      boxShadow: [
                        BoxShadow(
                          color: _characterGlowColor(_selectedCharacter).withValues(alpha: glowAlpha),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse ring
                        if (_demoAction == 3) ...[
                          Container(
                            width: 130 + 20 * _celebrateAnim.value,
                            height: 130 + 20 * _celebrateAnim.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: BmbColors.gold.withValues(alpha: (1 - _celebrateAnim.value) * 0.5),
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                        // Character emoji
                        Text(
                          _characterEmoji(_selectedCharacter, _demoAction),
                          style: const TextStyle(fontSize: 56),
                        ),
                        // Wave hand overlay
                        if (_demoAction == 1 && _waveAnim.value > 0)
                          Positioned(
                            top: 10,
                            right: 5,
                            child: Transform.rotate(
                              angle: sin(_waveAnim.value * pi * 3) * 0.4,
                              child: const Text('\u{1F44B}', style: TextStyle(fontSize: 28)),
                            ),
                          ),
                        // Point finger overlay
                        if (_demoAction == 2)
                          Positioned(
                            right: -5,
                            child: Opacity(
                              opacity: _pointAnim.value,
                              child: Transform.translate(
                                offset: Offset(15 * _pointAnim.value, 0),
                                child: const Text('\u{1F449}', style: TextStyle(fontSize: 24)),
                              ),
                            ),
                          ),
                        // Celebration stars
                        if (_demoAction == 3 && _celebrateAnim.value > 0.2) ...[
                          Positioned(
                            top: -5,
                            left: 10,
                            child: Opacity(
                              opacity: (1 - _celebrateAnim.value).clamp(0, 1),
                              child: Transform.translate(
                                offset: Offset(0, -20 * _celebrateAnim.value),
                                child: const Text('\u2B50', style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -5,
                            right: 10,
                            child: Opacity(
                              opacity: (1 - _celebrateAnim.value).clamp(0, 1),
                              child: Transform.translate(
                                offset: Offset(0, -25 * _celebrateAnim.value),
                                child: const Text('\u{1F389}', style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _actionLabel(_demoAction),
                      style: TextStyle(
                        color: const Color(0xFF00E5FF), fontSize: 11,
                        fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
                      ),
                    ),
                  ),
                  // Speech bubble
                  if (_speechVisible) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 250),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1A237E).withValues(alpha: 0.95),
                            const Color(0xFF0D47A1).withValues(alpha: 0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.15), blurRadius: 12),
                        ],
                      ),
                      child: Text(
                        _speechText(_demoAction),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── In-app position mockup ──
  Widget _buildInAppPreview() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: BmbColors.backgroundGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Stack(
        children: [
          // Fake app content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fake header
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Container(width: 20, height: 20, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 8),
                    Container(width: 100, height: 10, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(4))),
                  ]),
                ),
                const SizedBox(height: 8),
                // Fake sections
                ...List.generate(3, (i) => Container(
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    gradient: BmbColors.cardGradient,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: i == 0 ? const Color(0xFF00E5FF).withValues(alpha: 0.5) : BmbColors.borderColor, width: i == 0 ? 1.5 : 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: i == 0 ? const Color(0xFF00E5FF).withValues(alpha: 0.2) : BmbColors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${i + 1}', style: TextStyle(color: i == 0 ? const Color(0xFF00E5FF) : BmbColors.blue, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 60 + i * 20.0, height: 8, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(4))),
                  ]),
                )),
              ],
            ),
          ),

          // Character in bottom-right
          Positioned(
            right: 12,
            bottom: 50,
            child: AnimatedBuilder(
              animation: _floatAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -4 * _floatAnim.value),
                child: child,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mini speech bubble
                  if (_speechVisible)
                    Container(
                      width: 140,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1A237E).withValues(alpha: 0.95),
                            const Color(0xFF0D47A1).withValues(alpha: 0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 0.5),
                      ),
                      child: Text('Pick a bracket type!', style: TextStyle(color: Colors.white, fontSize: 9, height: 1.3)),
                    ),
                  // Mini character
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, __) {
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _characterGradient(_selectedCharacter),
                          boxShadow: [
                            BoxShadow(
                              color: _characterGlowColor(_selectedCharacter).withValues(alpha: 0.15 + 0.15 * _glowAnim.value),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(_characterEmoji(_selectedCharacter, 0), style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Fake bottom buttons
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Row(
              children: [
                Container(
                  width: 70, height: 32,
                  decoration: BoxDecoration(color: BmbColors.cardDark, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('Back', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10))),
                ),
                const Spacer(),
                Container(
                  width: 90, height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF36B37E), Color(0xFF2D9A6B)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('Continue', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
  Gradient _characterGradient(int type) {
    switch (type) {
      case 0: return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF00E5FF), Color(0xFF2979FF), Color(0xFF1565C0)],
      );
      case 1: return LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.25),
          const Color(0xFF00B0FF).withValues(alpha: 0.1),
          const Color(0xFF0D47A1).withValues(alpha: 0.15),
        ],
      );
      case 2: return const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFFF6B35), Color(0xFFFFD700), Color(0xFFFF8F00)],
      );
      default: return const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF2979FF)]);
    }
  }

  Color _characterGlowColor(int type) {
    switch (type) {
      case 0: return const Color(0xFF00E5FF);
      case 1: return const Color(0xFF00E5FF);
      case 2: return const Color(0xFFFF6B35);
      default: return const Color(0xFF00E5FF);
    }
  }

  String _characterEmoji(int type, int action) {
    if (action == 3) return '\u{1F389}'; // celebrate
    switch (type) {
      case 0: return '\u{1F916}';
      case 1: return '\u{1F47E}';
      case 2: return '\u{1F3C6}';
      default: return '\u{1F916}';
    }
  }

  String _actionLabel(int action) {
    switch (action) {
      case 0: return 'IDLE \u2022 Breathing + Float';
      case 1: return 'WAVE \u2022 Greeting New Users';
      case 2: return 'POINT \u2022 Directing to Section';
      case 3: return 'CELEBRATE \u2022 Step Completed!';
      default: return 'IDLE';
    }
  }

  String _speechText(int action) {
    switch (action) {
      case 0: return 'Hey there! Need help? Tap me anytime.';
      case 1: return 'Welcome back! Ready to build another bracket?';
      case 2: return 'Fill in this section to continue! \u{1F449}';
      case 3: return 'Awesome job! \u{1F389} That section is complete!';
      default: return 'Let\'s build a bracket!';
    }
  }
}

class _TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Rect spotlightRect;
  final String guideMessage;

  const _TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.spotlightRect,
    required this.guideMessage,
  });
}
