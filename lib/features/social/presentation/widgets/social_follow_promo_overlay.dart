import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/social/data/services/social_follow_promo_service.dart';

/// Full-screen promo overlay shown after signup.
///
/// Three stages:
///   1. Welcome Bonus — shows 5 social buttons, claim disabled.
///   2. Progress — visited platforms get green checks; claim enables at 5/5.
///   3. Celebration — confetti + credit award + "Let's Go!" CTA.
class SocialFollowPromoOverlay extends StatefulWidget {
  /// Called when the overlay is dismissed (skip or "Let's Go!").
  final VoidCallback onDismiss;

  const SocialFollowPromoOverlay({super.key, required this.onDismiss});

  @override
  State<SocialFollowPromoOverlay> createState() =>
      _SocialFollowPromoOverlayState();
}

class _SocialFollowPromoOverlayState extends State<SocialFollowPromoOverlay>
    with TickerProviderStateMixin {
  final _promoService = SocialFollowPromoService.instance;
  Set<String> _visited = {};
  int _creditAmount = SocialFollowPromoService.defaultCreditAmount;
  bool _claimed = false;
  bool _allVisited = false;
  bool _showCelebration = false;

  // Animation
  late AnimationController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

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
    _loadState();
  }

  Future<void> _loadState() async {
    final visited = await _promoService.getVisitedPlatforms();
    final amount = await _promoService.getCreditAmount();
    final claimed = await _promoService.hasClaimedPromo();
    if (!mounted) return;
    setState(() {
      _visited = visited;
      _creditAmount = amount;
      _claimed = claimed;
      _allVisited = visited.length >= SocialFollowPromoService.platforms.length;
    });
  }

  Future<void> _openPlatform(SocialPlatform platform) async {
    // Try deep link first, then fallback to web URL
    final deepUri = Uri.parse(platform.deepLink);
    final webUri = Uri.parse(platform.url);

    bool launched = false;
    try {
      launched = await launchUrl(deepUri, mode: LaunchMode.externalApplication);
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

    // Mark visited after launching
    await _promoService.markPlatformVisited(platform.id);
    final visited = await _promoService.getVisitedPlatforms();
    if (!mounted) return;
    setState(() {
      _visited = visited;
      _allVisited = visited.length >= SocialFollowPromoService.platforms.length;
    });
  }

  Future<void> _claimCredits() async {
    if (!_allVisited || _claimed) return;
    final awarded = await _promoService.claimPromoCredits();
    if (awarded > 0 && mounted) {
      setState(() {
        _claimed = true;
        _showCelebration = true;
      });
      _confettiController.forward();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: _showCelebration ? _buildCelebration() : _buildPromoScreen(),
        ),
      ),
    );
  }

  // ─── PROMO SCREEN (Stages 1 & 2) ────────────────────────────────────

  Widget _buildPromoScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Skip button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onDismiss,
              child: Text('Skip for now',
                  style: TextStyle(
                      color: BmbColors.textTertiary,
                      fontSize: 13,
                      fontWeight: BmbFontWeights.medium)),
            ),
          ),
          const SizedBox(height: 8),

          // Header icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [BmbColors.gold, BmbColors.goldLight],
              ),
            ),
            child: const Icon(Icons.card_giftcard,
                color: BmbColors.deepNavy, size: 36),
          ),
          const SizedBox(height: 16),

          // Title
          Text('WELCOME BONUS',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 24,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(
            'Follow us on all 5 socials to receive',
            style:
                TextStyle(color: BmbColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_creditAmount ',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 20,
                      fontWeight: BmbFontWeights.bold)),
              Text('FREE credits!',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.semiBold)),
            ],
          ),
          const SizedBox(height: 6),

          // Progress indicator
          _buildProgressDots(),
          const SizedBox(height: 20),

          // Platform buttons
          Expanded(
            child: ListView.separated(
              itemCount: SocialFollowPromoService.platforms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) =>
                  _buildPlatformRow(SocialFollowPromoService.platforms[i]),
            ),
          ),

          // Claim button
          const SizedBox(height: 16),
          _buildClaimButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    final total = SocialFollowPromoService.platforms.length;
    final visitedCount = _visited.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$visitedCount of $total',
            style: TextStyle(
                color: visitedCount == total
                    ? BmbColors.successGreen
                    : BmbColors.textTertiary,
                fontSize: 12,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(width: 10),
        ...List.generate(total, (i) {
          final filled = i < visitedCount;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? BmbColors.successGreen : BmbColors.borderColor,
              border: Border.all(
                  color: filled
                      ? BmbColors.successGreen
                      : BmbColors.textTertiary,
                  width: 1.5),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlatformRow(SocialPlatform platform) {
    final visited = _visited.contains(platform.id);
    final color = Color(platform.colorHex);

    return GestureDetector(
      onTap: () => _openPlatform(platform),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: visited
              ? LinearGradient(colors: [
                  BmbColors.successGreen.withValues(alpha: 0.12),
                  BmbColors.successGreen.withValues(alpha: 0.04),
                ])
              : BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: visited
                ? BmbColors.successGreen.withValues(alpha: 0.5)
                : color.withValues(alpha: 0.3),
            width: visited ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Platform icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visited
                    ? BmbColors.successGreen.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForPlatform(platform.iconName),
                color: visited ? BmbColors.successGreen : color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Name & handle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(platform.name,
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 15,
                          fontWeight: BmbFontWeights.semiBold)),
                  Text(platform.handle,
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),

            // Status
            if (visited)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: BmbColors.successGreen, size: 14),
                    const SizedBox(width: 4),
                    Text('Visited',
                        style: TextStyle(
                            color: BmbColors.successGreen,
                            fontSize: 11,
                            fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, color: color, size: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimButton() {
    return ScaleTransition(
      scale: _allVisited && !_claimed ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _allVisited && !_claimed ? _claimCredits : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _allVisited ? BmbColors.gold : BmbColors.cardDark,
            foregroundColor:
                _allVisited ? BmbColors.deepNavy : BmbColors.textTertiary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: _allVisited ? 8 : 0,
            shadowColor:
                _allVisited ? BmbColors.gold.withValues(alpha: 0.4) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _allVisited ? Icons.redeem : Icons.lock,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _allVisited
                    ? 'Claim $_creditAmount Credits!'
                    : 'Follow All 5 to Unlock',
                style: TextStyle(
                    fontSize: 16, fontWeight: BmbFontWeights.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CELEBRATION (Stage 3) ───────────────────────────────────────────

  Widget _buildCelebration() {
    return Stack(
      children: [
        // Confetti background
        ...List.generate(30, (i) => _buildConfettiParticle(i)),
        // Content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [BmbColors.gold, BmbColors.goldLight],
                    ),
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

                Text('YOU EARNED',
                    style: TextStyle(
                        color: BmbColors.textSecondary,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.semiBold,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('$_creditAmount CREDITS!',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 36,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay',
                        letterSpacing: 1.5)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            BmbColors.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          color: BmbColors.successGreen, size: 18),
                      const SizedBox(width: 8),
                      Text('Credits deposited to your BMB Bucket',
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.semiBold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Thanks for following! Stay connected for tournament news, giveaways, and community highlights.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 32),

                // Let's Go! button
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
                      shadowColor: BmbColors.blue.withValues(alpha: 0.4),
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
    final left = rng.nextDouble() * MediaQuery.of(context).size.width;
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
            ((_confettiController.value - delay).clamp(0.0, 1.0) / (1.0 - delay))
                .clamp(0.0, 1.0);
        final top = -20.0 + progress * (MediaQuery.of(context).size.height + 40);
        final opacity = progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2);

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
                  borderRadius: BorderRadius.circular(rng.nextBool() ? size : 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
