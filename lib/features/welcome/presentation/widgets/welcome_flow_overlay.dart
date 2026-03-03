import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/promo/data/services/promo_code_service.dart';
import 'package:bmb_mobile/features/social/data/services/social_follow_promo_service.dart';
import 'package:bmb_mobile/features/notifications/data/services/welcome_notification_service.dart';
import 'package:bmb_mobile/features/companion/data/companion_model.dart';
import 'package:bmb_mobile/features/companion/data/companion_service.dart';
import 'package:bmb_mobile/features/companion/data/companion_audio_player_stub.dart'
    if (dart.library.js_interop) 'package:bmb_mobile/features/companion/data/companion_audio_player.dart';

/// Unified post-signup overlay with FIVE panels:
///
///   Panel 0 — **Thank You / Welcome**       : Welcome message + "Thank you for joining!"
///   Panel 1 — **BMB Companion Picker**       : Pick your BMB companion (Jake, Marcus, Alex).
///   Panel 2 — **Promo Code**                 : Enter a welcome promo code (e.g. WELCOME81).
///   Panel 3 — **Social Follow**              : Follow BMB socials, earn 3 credits per platform.
///                                              User picks the ones they want. Small skip at bottom.
///   Panel 4 — **Profile Stats Summary**      : Shows profile stats (joined=0, hosted=0, wins=0)
///                                              plus total credits earned during signup.
///
/// "Let's Go!" finishes the flow. Every panel is skippable.
class WelcomeFlowOverlay extends StatefulWidget {
  /// Called when the overlay is dismissed (skip or "Let's Go!").
  final VoidCallback onDismiss;

  const WelcomeFlowOverlay({super.key, required this.onDismiss});

  @override
  State<WelcomeFlowOverlay> createState() => _WelcomeFlowOverlayState();
}

class _WelcomeFlowOverlayState extends State<WelcomeFlowOverlay>
    with TickerProviderStateMixin {
  // ─── Services ────────────────────────────────────────────────────────
  final _promoService = PromoCodeService.instance;
  final _socialService = SocialFollowPromoService.instance;
  final _welcomeNotifService = WelcomeNotificationService.instance;
  final _companionService = CompanionService.instance;

  // ─── State ───────────────────────────────────────────────────────────
  static const int _totalPanels = 5;
  int _currentPanel = 0; // 0=welcome, 1=companion, 2=promo, 3=social, 4=summary
  int _totalCreditsEarned = 0;

  // Panel 1 — Companion picker
  int _companionIndex = 0;
  bool _companionConfirmed = false;
  final CompanionAudioPlayer _audioPlayer = CompanionAudioPlayer();
  bool _isPlayingVoice = false;

  // Panel 2 — Promo code
  final _promoController = TextEditingController();
  bool _promoLoading = false;
  String? _promoMessage;
  bool _promoSuccess = false;

  // Panel 3 — Social follow
  Set<String> _visited = {};
  int _socialCreditsEarned = 0;
  bool _socialClaimed = false;

  // Panel 4 — Summary
  // (no extra state needed)

  // Animation
  late AnimationController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _companionGlowController;
  bool _showCelebration = false;

  CompanionPersona get _selectedCompanion =>
      CompanionPersona.all[_companionIndex];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 1.0, end: 1.06).animate(_pulseController);
    _companionGlowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _loadSocialState();
    _initCompanionService();
    // Queue the welcome notification
    _welcomeNotifService.queueWelcomeNotification();

    _audioPlayer.onComplete = () {
      if (mounted) setState(() => _isPlayingVoice = false);
    };
  }

  Future<void> _initCompanionService() async {
    await _companionService.init();
  }

  Future<void> _loadSocialState() async {
    final visited = await _socialService.getVisitedPlatforms();
    final claimed = await _socialService.hasClaimedPromo();
    if (!mounted) return;
    setState(() {
      _visited = visited;
      _socialCreditsEarned =
          visited.length * SocialFollowPromoService.creditsPerPlatform;
      _socialClaimed = claimed;
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    _companionGlowController.dispose();
    _promoController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── COMPANION PICKER ──────────────────────────────────────────────

  void _selectCompanion(int index) {
    if (index == _companionIndex) return;
    _audioPlayer.stop();
    setState(() {
      _companionIndex = index;
      _isPlayingVoice = false;
    });
  }

  Future<void> _playCompanionVoice() async {
    if (_isPlayingVoice) {
      _audioPlayer.stop();
      setState(() => _isPlayingVoice = false);
      return;
    }
    setState(() => _isPlayingVoice = true);
    try {
      await _audioPlayer.play(_selectedCompanion.voiceIntroUrl);
    } catch (_) {
      if (mounted) setState(() => _isPlayingVoice = false);
    }
  }

  Future<void> _confirmCompanion() async {
    setState(() => _companionConfirmed = true);
    await _companionService.selectCompanion(_selectedCompanion);
  }

  // ─── PROMO CODE ──────────────────────────────────────────────────────

  Future<void> _redeemPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _promoMessage = 'Please enter a promo code.';
        _promoSuccess = false;
      });
      return;
    }

    setState(() => _promoLoading = true);
    final result = await _promoService.redeemCode(code);
    if (!mounted) return;
    setState(() {
      _promoLoading = false;
      _promoMessage = result.message;
      _promoSuccess = result.success;
      if (result.success) {
        _totalCreditsEarned += result.creditsAwarded;
      }
    });
  }

  // ─── SOCIAL FOLLOW ───────────────────────────────────────────────────

  Future<void> _openPlatform(SocialPlatform platform) async {
    final deepUri = Uri.parse(platform.deepLink);
    final webUri = Uri.parse(platform.url);

    bool launched = false;
    try {
      launched =
          await launchUrl(deepUri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    if (!launched) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Opening ${platform.name}...'),
            backgroundColor: BmbColors.midNavy,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }

    await _socialService.markPlatformVisited(platform.id);
    final visited = await _socialService.getVisitedPlatforms();
    if (!mounted) return;
    setState(() {
      _visited = visited;
      _socialCreditsEarned =
          visited.length * SocialFollowPromoService.creditsPerPlatform;
    });
  }

  Future<void> _claimSocialCredits() async {
    if (_socialClaimed || _visited.isEmpty) return;
    final awarded = await _socialService.claimPromoCredits();
    if (awarded > 0 && mounted) {
      setState(() {
        _socialClaimed = true;
        _totalCreditsEarned += awarded;
      });
    }
  }

  // ─── NAVIGATION HELPERS ──────────────────────────────────────────────

  void _goNext() {
    // Auto-claim social credits when leaving social panel
    if (_currentPanel == 3 && !_socialClaimed && _visited.isNotEmpty) {
      _claimSocialCredits();
    }
    // Auto-confirm companion when leaving companion panel
    if (_currentPanel == 1 && !_companionConfirmed) {
      _confirmCompanion();
    }
    if (_currentPanel < _totalPanels - 1) {
      setState(() => _currentPanel++);
    } else {
      _finishFlow();
    }
  }

  void _goBack() {
    if (_currentPanel > 0) {
      setState(() => _currentPanel--);
    }
  }

  // ─── FINISH ──────────────────────────────────────────────────────────

  void _finishFlow() {
    // Auto-claim any unclaimed social credits
    if (!_socialClaimed && _visited.isNotEmpty) {
      _claimSocialCredits();
    }
    // Auto-confirm companion if not yet
    if (!_companionConfirmed) {
      _confirmCompanion();
    }

    if (_totalCreditsEarned > 0) {
      setState(() => _showCelebration = true);
      _confettiController.forward();
    } else {
      widget.onDismiss();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child:
              _showCelebration ? _buildCelebration() : _buildFlowContent(),
        ),
      ),
    );
  }

  Widget _buildFlowContent() {
    return Column(
      children: [
        // Top bar: progress dots
        _buildTopBar(),
        // Running credit total
        _buildCreditBanner(),
        // Panel content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _currentPanel == 0
                ? _buildWelcomePanel()
                : _currentPanel == 1
                    ? _buildCompanionPanel()
                    : _currentPanel == 2
                        ? _buildPromoPanel()
                        : _currentPanel == 3
                            ? _buildSocialPanel()
                            : _buildSummaryPanel(),
          ),
        ),
        // Bottom navigation
        _buildBottomNav(),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── TOP BAR ─────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Back arrow (if not on first panel)
          if (_currentPanel > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: BmbColors.textSecondary, size: 18),
              onPressed: _goBack,
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          // Step dots
          Row(
            children: List.generate(_totalPanels, (i) {
              final active = i == _currentPanel;
              final completed = i < _currentPanel;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? BmbColors.gold
                      : completed
                          ? BmbColors.successGreen
                          : BmbColors.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const Spacer(),
          // Skip to dashboard
          TextButton(
            onPressed: _finishFlow,
            child: Text('Skip',
                style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 13,
                    fontWeight: BmbFontWeights.medium)),
          ),
        ],
      ),
    );
  }

  // ─── CREDIT BANNER ───────────────────────────────────────────────────

  Widget _buildCreditBanner() {
    if (_totalCreditsEarned <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.15),
          BmbColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.savings, color: BmbColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            'Credits earned: $_totalCreditsEarned',
            style: TextStyle(
                color: BmbColors.gold,
                fontSize: 14,
                fontWeight: BmbFontWeights.bold),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PANEL 0 — WELCOME / THANK YOU
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildWelcomePanel() {
    return SingleChildScrollView(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Trophy icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [BmbColors.gold, BmbColors.goldLight]),
              boxShadow: [
                BoxShadow(
                  color: BmbColors.gold.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.emoji_events,
                color: BmbColors.deepNavy, size: 52),
          ),
          const SizedBox(height: 24),
          Text('WELCOME TO THE',
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 16,
                  fontWeight: BmbFontWeights.semiBold,
                  letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('BmB FAMILY!',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 34,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                  letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BmbColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: BmbColors.successGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.celebration,
                    color: BmbColors.gold, size: 28),
                const SizedBox(height: 8),
                Text(
                  'Thank you for joining Back My Bracket!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.successGreen,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Let\'s get your account set up so you can start competing, hosting, and building brackets!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // What's coming next
          Text('Here\'s what we\'ll do:',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 15,
                  fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 12),
          _buildSetupStep(Icons.smart_toy, 'Pick Your BMB Companion',
              'Your personal bracket guide', BmbColors.blue),
          const SizedBox(height: 8),
          _buildSetupStep(Icons.confirmation_number, 'Enter Promo Code',
              'Claim free credits if you have a code', BmbColors.gold),
          const SizedBox(height: 8),
          _buildSetupStep(Icons.people_alt, 'Follow Us on Socials',
              'Earn 3 credits for each platform', BmbColors.vipPurple),
          const SizedBox(height: 8),
          _buildSetupStep(Icons.bar_chart, 'See Your Profile',
              'Your stats and credits overview', BmbColors.successGreen),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSetupStep(
      IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.semiBold)),
                Text(subtitle,
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PANEL 1 — BMB COMPANION PICKER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCompanionPanel() {
    return SingleChildScrollView(
      key: const ValueKey('companion'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
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
                color: BmbColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Three avatar pills
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                List.generate(CompanionPersona.all.length, (i) {
              final persona = CompanionPersona.all[i];
              final active = i == _companionIndex;
              return GestureDetector(
                onTap: () => _selectCompanion(i),
                child: AnimatedBuilder(
                  animation: _companionGlowController,
                  builder: (_, child) {
                    final g = _companionGlowController.value;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: active ? 82 : 62,
                      height: active ? 82 : 62,
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
                                      .withValues(
                                          alpha: 0.25 + 0.15 * g),
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
                                  fontSize: active ? 24 : 18,
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
          const SizedBox(height: 16),
          // Selected companion detail
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) {
              final p = _pulseController.value;
              return Container(
                width: 160,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00E5FF)
                        .withValues(alpha: 0.4 + 0.2 * p),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF)
                          .withValues(alpha: 0.1 + 0.1 * p),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    _selectedCompanion.fullAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: BmbColors.cardDark,
                      child: const Icon(Icons.person,
                          color: BmbColors.textTertiary, size: 48),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _selectedCompanion.name,
            style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 24,
              fontWeight: BmbFontWeights.bold,
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedCompanion.nickname,
              style: TextStyle(
                color: const Color(0xFF00E5FF),
                fontSize: 12,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Tagline bubble
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0D1B4A).withValues(alpha: 0.95),
                  const Color(0xFF1A237E).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      const Color(0xFF00E5FF).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '"${_selectedCompanion.tagline}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _playCompanionVoice,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isPlayingVoice
                          ? const Color(0xFF00E5FF)
                              .withValues(alpha: 0.2)
                          : BmbColors.cardDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isPlayingVoice
                            ? const Color(0xFF00E5FF)
                            : BmbColors.borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPlayingVoice
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up,
                          color: _isPlayingVoice
                              ? const Color(0xFF00E5FF)
                              : BmbColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPlayingVoice
                              ? 'Playing...'
                              : 'Hear ${_selectedCompanion.name}\'s Voice',
                          style: TextStyle(
                            color: _isPlayingVoice
                                ? const Color(0xFF00E5FF)
                                : BmbColors.textSecondary,
                            fontSize: 11,
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
          const SizedBox(height: 10),
          Text(
            _selectedCompanion.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BmbColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (_companionConfirmed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: BmbColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: BmbColors.successGreen, size: 16),
                  const SizedBox(width: 6),
                  Text('${_selectedCompanion.name} selected!',
                      style: TextStyle(
                          color: BmbColors.successGreen,
                          fontSize: 13,
                          fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PANEL 2 — PROMO CODE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPromoPanel() {
    return SingleChildScrollView(
      key: const ValueKey('promo'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [BmbColors.gold, BmbColors.goldLight]),
            ),
            child: const Icon(Icons.confirmation_number,
                color: BmbColors.deepNavy, size: 36),
          ),
          const SizedBox(height: 16),
          Text('WELCOME PROMO',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 22,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(
              'Have a promo code? Enter it below to claim your free credits!',
              style: TextStyle(
                  color: BmbColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          // Input field
          TextField(
            controller: _promoController,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 18,
                fontWeight: BmbFontWeights.bold,
                letterSpacing: 2),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'ENTER CODE',
              hintStyle: TextStyle(
                  color: BmbColors.textTertiary,
                  fontSize: 16,
                  letterSpacing: 2),
              prefixIcon:
                  const Icon(Icons.vpn_key, color: BmbColors.gold),
              filled: true,
              fillColor: BmbColors.cardDark,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: BmbColors.gold.withValues(alpha: 0.4))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: BmbColors.gold.withValues(alpha: 0.3))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: BmbColors.gold, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          // Redeem button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  _promoLoading || _promoSuccess ? null : _redeemPromo,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _promoSuccess ? BmbColors.successGreen : BmbColors.gold,
                foregroundColor: BmbColors.deepNavy,
                disabledBackgroundColor: _promoSuccess
                    ? BmbColors.successGreen.withValues(alpha: 0.7)
                    : BmbColors.cardDark,
                disabledForegroundColor:
                    _promoSuccess ? Colors.white : BmbColors.textTertiary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _promoLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: BmbColors.deepNavy))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _promoSuccess
                                ? Icons.check_circle
                                : Icons.redeem,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                            _promoSuccess
                                ? 'Credits Added!'
                                : 'Redeem Code',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: BmbFontWeights.bold)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Result message
          if (_promoMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_promoSuccess
                        ? BmbColors.successGreen
                        : BmbColors.errorRed)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: (_promoSuccess
                            ? BmbColors.successGreen
                            : BmbColors.errorRed)
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _promoSuccess
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: _promoSuccess
                        ? BmbColors.successGreen
                        : BmbColors.errorRed,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_promoMessage!,
                        style: TextStyle(
                            color: _promoSuccess
                                ? BmbColors.successGreen
                                : BmbColors.errorRed,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: BmbColors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: BmbColors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No code? No problem! You can still earn free credits by following us on socials in the next step.',
                    style: TextStyle(
                        color: BmbColors.textSecondary,
                        fontSize: 11,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PANEL 3 — SOCIAL FOLLOW (tiered: 3 credits per platform)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSocialPanel() {
    final totalPlatforms = SocialFollowPromoService.platforms.length;
    final visitedCount = _visited.length;
    final creditsPerPlatform =
        SocialFollowPromoService.creditsPerPlatform;
    final maxCredits = totalPlatforms * creditsPerPlatform;

    return SingleChildScrollView(
      key: const ValueKey('social'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [BmbColors.blue, BmbColors.vipPurple]),
            ),
            child: const Icon(Icons.people_alt,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          Text('FOLLOW & EARN',
              style: TextStyle(
                  color: BmbColors.blue,
                  fontSize: 22,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                  letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(
            'Earn $creditsPerPlatform credits for each platform you follow!',
            style: TextStyle(
                color: BmbColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Running counter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_socialCreditsEarned',
                style: TextStyle(
                    color: BmbColors.gold,
                    fontSize: 28,
                    fontWeight: BmbFontWeights.bold),
              ),
              Text(
                ' / $maxCredits credits',
                style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 16,
                    fontWeight: BmbFontWeights.medium),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: visitedCount / totalPlatforms,
              backgroundColor: BmbColors.borderColor,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(BmbColors.gold),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Follow the ones you use. No need to follow all!',
            style: TextStyle(
                color: BmbColors.textTertiary,
                fontSize: 12,
                fontWeight: BmbFontWeights.medium),
          ),
          const SizedBox(height: 10),
          // Platform rows
          ...SocialFollowPromoService.platforms
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildPlatformRow(p),
                  )),
          const SizedBox(height: 10),
          // Claim button (if they visited at least 1 and haven't claimed yet)
          if (!_socialClaimed && _visited.isNotEmpty)
            ScaleTransition(
              scale: _pulseAnim,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _claimSocialCredits,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.gold,
                    foregroundColor: BmbColors.deepNavy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 6,
                    shadowColor: BmbColors.gold.withValues(alpha: 0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.redeem, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Claim $_socialCreditsEarned Credits!',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: BmbFontWeights.bold),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_socialClaimed)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    BmbColors.successGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: BmbColors.successGreen
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: BmbColors.successGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$_socialCreditsEarned credits claimed!',
                    style: TextStyle(
                        color: BmbColors.successGreen,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.bold),
                  ),
                ],
              ),
            ),
          // Small subtle skip text at the bottom
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _goNext,
            child: Text(
              'skip socials',
              style: TextStyle(
                color: BmbColors.textTertiary.withValues(alpha: 0.5),
                fontSize: 11,
                decoration: TextDecoration.underline,
                decorationColor:
                    BmbColors.textTertiary.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPlatformRow(SocialPlatform platform) {
    final visited = _visited.contains(platform.id);
    final color = Color(platform.colorHex);

    return GestureDetector(
      onTap: () => _openPlatform(platform),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: visited
              ? LinearGradient(colors: [
                  BmbColors.successGreen.withValues(alpha: 0.12),
                  BmbColors.successGreen.withValues(alpha: 0.04),
                ])
              : BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: visited
                ? BmbColors.successGreen.withValues(alpha: 0.5)
                : color.withValues(alpha: 0.3),
            width: visited ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: visited
                    ? BmbColors.successGreen.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForPlatform(platform.iconName),
                color: visited ? BmbColors.successGreen : color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(platform.name,
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 14,
                          fontWeight: BmbFontWeights.semiBold)),
                  Text(platform.handle,
                      style: TextStyle(
                          color: BmbColors.textTertiary,
                          fontSize: 11)),
                ],
              ),
            ),
            // Per-platform credit badge
            if (visited)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BmbColors.successGreen
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: BmbColors.successGreen, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '+${SocialFollowPromoService.creditsPerPlatform}',
                      style: TextStyle(
                          color: BmbColors.successGreen,
                          fontSize: 12,
                          fontWeight: BmbFontWeights.bold),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Follow',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: BmbFontWeights.bold)),
                    const SizedBox(width: 3),
                    Icon(Icons.open_in_new, color: color, size: 11),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PANEL 4 — PROFILE STATS SUMMARY
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSummaryPanel() {
    return SingleChildScrollView(
      key: const ValueKey('summary'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // User avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)]),
              border: Border.all(color: BmbColors.gold, width: 3),
            ),
            child:
                const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 14),
          Text('YOUR PROFILE',
              style: TextStyle(
                  color: BmbColors.blue,
                  fontSize: 22,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                  letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text('Here\'s your starting stats:',
              style: TextStyle(
                  color: BmbColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          // Stats cards row
          Row(
            children: [
              Expanded(child: _buildStatCard('Joined', '0', Icons.group, BmbColors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('Hosted', '0', Icons.star, BmbColors.gold)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard('Wins', '0', Icons.emoji_events, BmbColors.successGreen)),
            ],
          ),
          const SizedBox(height: 20),
          // Credit summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BmbColors.gold.withValues(alpha: 0.15),
                  BmbColors.gold.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: BmbColors.gold.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text('BMB Bucket Balance',
                    style: TextStyle(
                        color: BmbColors.textSecondary,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.medium)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.savings,
                        color: BmbColors.gold, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      '$_totalCreditsEarned',
                      style: TextStyle(
                          color: BmbColors.gold,
                          fontSize: 40,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay'),
                    ),
                    const SizedBox(width: 6),
                    Text('credits',
                        style: TextStyle(
                            color: BmbColors.gold.withValues(alpha: 0.7),
                            fontSize: 16,
                            fontWeight: BmbFontWeights.medium)),
                  ],
                ),
                const SizedBox(height: 12),
                // Credit breakdown
                if (_promoSuccess)
                  _buildCreditLine('Welcome Promo Code', _promoSuccess ? 'Redeemed' : ''),
                if (_socialCreditsEarned > 0)
                  _buildCreditLine(
                      'Social Follow (${_visited.length} platforms)',
                      '+$_socialCreditsEarned'),
                if (_totalCreditsEarned == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Earn credits by using promo codes, following socials, or inviting friends!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: BmbColors.textTertiary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Companion badge
          if (_companionConfirmed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        const Color(0xFF00E5FF).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF00E5FF), width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _selectedCompanion.circleAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: BmbColors.cardDark,
                          child: Text(_selectedCompanion.name[0],
                              style: TextStyle(
                                  color: BmbColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: BmbFontWeights.bold)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Companion',
                            style: TextStyle(
                                color: BmbColors.textTertiary,
                                fontSize: 11)),
                        Text(
                            '${_selectedCompanion.name} "${_selectedCompanion.nickname}"',
                            style: TextStyle(
                                color: const Color(0xFF00E5FF),
                                fontSize: 14,
                                fontWeight: BmbFontWeights.bold)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle,
                      color: BmbColors.successGreen, size: 20),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Motivational text
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: BmbColors.blue.withValues(alpha: 0.2)),
            ),
            child: Text(
              'You\'re all set! Start competing in brackets, hosting tournaments, and climbing the leaderboard. Your journey begins now!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 13,
                  height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 26,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 12,
                  fontWeight: BmbFontWeights.medium)),
        ],
      ),
    );
  }

  Widget _buildCreditLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: BmbColors.textSecondary, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: BmbColors.successGreen,
                  fontSize: 12,
                  fontWeight: BmbFontWeights.bold)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBottomNav() {
    final isLastPanel = _currentPanel == _totalPanels - 1;
    String buttonLabel;
    switch (_currentPanel) {
      case 0:
        buttonLabel = "Let's Get Started!";
      case 1:
        buttonLabel = _companionConfirmed
            ? 'Continue'
            : 'Choose ${_selectedCompanion.name} & Continue';
      case 2:
        buttonLabel = 'Continue to Socials';
      case 3:
        buttonLabel = 'View My Profile';
      default:
        buttonLabel = "Let's Go!";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentPanel > 0)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _goBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BmbColors.textSecondary,
                        side: BorderSide(color: BmbColors.borderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Back',
                          style: TextStyle(
                              fontWeight: BmbFontWeights.semiBold)),
                    ),
                  ),
                ),
              if (_currentPanel > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastPanel
                          ? BmbColors.gold
                          : BmbColors.blue,
                      foregroundColor: isLastPanel
                          ? BmbColors.deepNavy
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      shadowColor: isLastPanel
                          ? BmbColors.gold.withValues(alpha: 0.3)
                          : BmbColors.blue.withValues(alpha: 0.3),
                    ),
                    child: Text(
                      buttonLabel,
                      style: TextStyle(
                          fontSize: isLastPanel ? 18 : 15,
                          fontWeight: BmbFontWeights.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CELEBRATION SCREEN
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCelebration() {
    return Stack(
      children: [
        ...List.generate(30, (i) => _buildConfettiParticle(i)),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [BmbColors.gold, BmbColors.goldLight]),
                    boxShadow: [
                      BoxShadow(
                        color: BmbColors.gold.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: BmbColors.deepNavy, size: 52),
                ),
                const SizedBox(height: 28),
                Text('YOU\'RE ALL SET!',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 32,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay',
                        letterSpacing: 1.5)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: BmbColors.successGreen
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.savings,
                          color: BmbColors.gold, size: 22),
                      const SizedBox(width: 8),
                      Text('$_totalCreditsEarned credits in your bucket!',
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 16,
                              fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Thank you for joining the BmB family! '
                  'Start competing, hosting, and building brackets!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                      shadowColor:
                          BmbColors.blue.withValues(alpha: 0.4),
                    ),
                    child: Text("Let's Go!",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfettiParticle(int index) {
    final rng = Random(index);
    final left =
        rng.nextDouble() * MediaQuery.of(context).size.width;
    final colors = [
      BmbColors.gold,
      BmbColors.blue,
      BmbColors.successGreen,
      BmbColors.vipPurple,
      BmbColors.errorRed,
      BmbColors.goldLight,
    ];
    final color = colors[index % colors.length];
    final size = 6.0 + rng.nextDouble() * 8;
    final delay = rng.nextDouble();

    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        final progress =
            ((_confettiController.value - delay).clamp(0.0, 1.0) /
                    (1.0 - delay))
                .clamp(0.0, 1.0);
        final top = -20.0 +
            progress * (MediaQuery.of(context).size.height + 40);
        final opacity =
            progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2);

        return Positioned(
          left: left + sin(progress * 6 + index) * 30,
          top: top,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: progress * 8 + index.toDouble(),
              child: Container(
                width: size,
                height: size * (rng.nextBool() ? 1 : 0.6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(
                      rng.nextBool() ? size : 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────

  IconData _iconForPlatform(String name) {
    switch (name) {
      case 'instagram':
        return Icons.camera_alt;
      case 'tiktok':
        return Icons.music_note;
      case 'twitter':
        return Icons.chat_bubble;
      case 'facebook':
        return Icons.thumb_up;
      case 'youtube':
        return Icons.play_circle_filled;
      default:
        return Icons.link;
    }
  }
}
