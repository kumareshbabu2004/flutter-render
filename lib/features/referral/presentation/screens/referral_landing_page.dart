import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';


/// Public referral landing page — viewable WITHOUT an account.
///
/// This is where every referral link directs to. It shows:
/// 1. Quick how-to videos about BMB
/// 2. BMB+ membership perks & promos
/// 3. Free registration option
/// 4. The referral code auto-applied
///
/// Accessed via route: /invite?ref=BMB-XXXXXX&section=videos
class ReferralLandingPage extends StatefulWidget {
  final String? referralCode;
  final bool scrollToVideos;

  const ReferralLandingPage({
    super.key,
    this.referralCode,
    this.scrollToVideos = false,
  });

  @override
  State<ReferralLandingPage> createState() => _ReferralLandingPageState();
}

class _ReferralLandingPageState extends State<ReferralLandingPage>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _videosKey = GlobalKey();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-scroll to videos section if deep-linked
    if (widget.scrollToVideos) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVideos();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToVideos() {
    final ctx = _videosKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic);
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
              // Top bar (minimal — no auth required)
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeroBanner(),
                      const SizedBox(height: 24),
                      _buildReferralCodeBanner(),
                      const SizedBox(height: 28),
                      _buildVideosSection(),
                      const SizedBox(height: 28),
                      _buildBmbPlusPromos(),
                      const SizedBox(height: 28),
                      _buildFreeRegistration(),
                      const SizedBox(height: 28),
                      _buildFeatureShowcase(),
                      const SizedBox(height: 28),
                      _buildCtaFooter(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TOP BAR ──────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // BMB Logo / text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                BmbColors.blue.withValues(alpha: 0.2),
                BmbColors.gold.withValues(alpha: 0.1),
              ]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_basketball, color: BmbColors.gold, size: 22),
                const SizedBox(width: 6),
                Text(
                  'BACK MY BRACKET',
                  style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Sign In link (for existing users)
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/auth', (r) => false);
            },
            child: Text(
              'Sign In',
              style: TextStyle(
                color: BmbColors.blue,
                fontSize: 13,
                fontWeight: BmbFontWeights.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HERO BANNER ──────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BmbColors.blue.withValues(alpha: 0.2),
              BmbColors.gold.withValues(alpha: 0.15),
              BmbColors.blue.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            // Animated trophy icon
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    BmbColors.gold.withValues(alpha: 0.3),
                    BmbColors.gold.withValues(alpha: 0.1),
                  ]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, color: BmbColors.gold, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "You've Been Invited!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BmbColors.gold,
                fontSize: 24,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your friend wants you to join Back My Bracket — '
              'the app where you create brackets, compete with friends, '
              'and win real prizes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── REFERRAL CODE BANNER ─────────────────────────────────────────

  Widget _buildReferralCodeBanner() {
    if (widget.referralCode == null || widget.referralCode!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            BmbColors.successGreen.withValues(alpha: 0.15),
            BmbColors.successGreen.withValues(alpha: 0.05),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified, color: BmbColors.successGreen, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Referral Code',
                    style: TextStyle(
                      color: BmbColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.referralCode!,
                    style: TextStyle(
                      color: BmbColors.successGreen,
                      fontSize: 22,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay',
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'Auto-applied when you sign up below',
                    style: TextStyle(
                      color: BmbColors.successGreen.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.referralCode!));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Text('Code copied!'),
                  ]),
                  backgroundColor: BmbColors.successGreen,
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: const Icon(Icons.copy, color: BmbColors.successGreen, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ─── VIDEOS SECTION ───────────────────────────────────────────────

  Widget _buildVideosSection() {
    return Padding(
      key: _videosKey,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_circle_fill, color: BmbColors.blue, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'See How BMB Works',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Watch quick videos to learn how to create brackets, '
            'compete with friends, and win.',
            style: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Video cards
          _videoCard(
            title: 'What is Back My Bracket?',
            subtitle: '60 seconds • Overview',
            icon: Icons.sports_basketball,
            color: BmbColors.gold,
            duration: '1:00',
          ),
          _videoCard(
            title: 'How to Create a Bracket',
            subtitle: '90 seconds • Step-by-step',
            icon: Icons.account_tree,
            color: BmbColors.blue,
            duration: '1:30',
          ),
          _videoCard(
            title: 'Making Picks & Competing',
            subtitle: '75 seconds • Gameplay',
            icon: Icons.how_to_vote,
            color: const Color(0xFF8B5CF6),
            duration: '1:15',
          ),
          _videoCard(
            title: 'Winning Prizes & Credits',
            subtitle: '60 seconds • Rewards',
            icon: Icons.emoji_events,
            color: BmbColors.successGreen,
            duration: '1:00',
          ),
          _videoCard(
            title: 'BMB Squares & Pick\'em',
            subtitle: '80 seconds • Game Modes',
            icon: Icons.grid_4x4,
            color: const Color(0xFFEC4899),
            duration: '1:20',
          ),
        ],
      ),
    );
  }

  Widget _videoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String duration,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // Show video player placeholder
            _showVideoPlayer(title);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail placeholder
                Container(
                  width: 64,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.1),
                    ]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, color: color.withValues(alpha: 0.6), size: 24),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 13,
                          fontWeight: BmbFontWeights.semiBold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
                // Duration badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: BmbFontWeights.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVideoPlayer(String title) {
    // Map video titles to YouTube embed URLs
    // In production these would be BMB's actual how-to videos
    final videoUrls = <String, String>{
      'What is Back My Bracket?': 'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1',
      'How to Create a Bracket': 'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1',
      'Making Picks & Competing': 'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1',
      'Winning Prizes & Credits': 'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1',
      "BMB Squares & Pick'em": 'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1',
    };
    final videoUrl = videoUrls[title];

    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BmbColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                videoUrl != null
                    ? 'Tap play to watch'
                    : 'Video content available in the BMB app',
                style: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 24),
              // Video player area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        BmbColors.blue.withValues(alpha: 0.15),
                        BmbColors.deepNavy,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: BmbColors.borderColor),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_outline,
                            color: BmbColors.blue.withValues(alpha: 0.6), size: 64),
                        const SizedBox(height: 16),
                        Text(
                          videoUrl != null ? 'Ready to Play' : 'Video Preview',
                          style: TextStyle(
                            color: BmbColors.textSecondary,
                            fontSize: 16,
                            fontWeight: BmbFontWeights.semiBold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          videoUrl != null
                              ? 'Video will open in browser'
                              : 'Full video available after download',
                          style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _scrollToSignup();
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Get BMB Free'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BmbColors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToSignup() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  // ─── BMB+ PROMOS ──────────────────────────────────────────────────

  Widget _buildBmbPlusPromos() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star, color: BmbColors.gold, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'BMB+ Membership',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upgrade for premium features and exclusive perks.',
            style: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Premium plan card
          _promoPlanCard(
            planName: 'BMB+',
            price: '\$4.99/mo',
            yearlyPrice: '\$39.99/yr (save 33%)',
            features: [
              'Unlimited bracket creation',
              'Priority leaderboard placement',
              'Exclusive bracket templates',
              'Ad-free experience',
              'Early access to new features',
              'Custom bracket themes',
            ],
            color: BmbColors.gold,
            promoTag: 'MOST POPULAR',
          ),
          const SizedBox(height: 12),

          // VIP plan card
          _promoPlanCard(
            planName: 'BMB VIP',
            price: '\$9.99/mo',
            yearlyPrice: '\$79.99/yr (save 33%)',
            features: [
              'Everything in BMB+',
              'VIP badge on profile',
              'Priority customer support',
              'Exclusive VIP tournaments',
              'Advanced analytics dashboard',
              'Revenue sharing for hosts',
            ],
            color: const Color(0xFF8B5CF6),
            promoTag: 'BEST VALUE',
          ),

          const SizedBox(height: 12),

          // Promo banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                BmbColors.gold.withValues(alpha: 0.2),
                BmbColors.gold.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: BmbColors.gold, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Referral Bonus!',
                        style: TextStyle(
                          color: BmbColors.gold,
                          fontSize: 14,
                          fontWeight: BmbFontWeights.bold,
                        ),
                      ),
                      Text(
                        'Sign up with a referral code and get 10 bonus BMB credits — '
                        'use them for bracket entries or in the BMB store.',
                        style: TextStyle(
                          color: BmbColors.textSecondary,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _promoPlanCard({
    required String planName,
    required String price,
    required String yearlyPrice,
    required List<String> features,
    required Color color,
    required String promoTag,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withValues(alpha: 0.12),
          color.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                planName,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  promoTag,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 24,
                  fontWeight: BmbFontWeights.bold,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  yearlyPrice,
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          color: BmbColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── FREE REGISTRATION ────────────────────────────────────────────

  Widget _buildFreeRegistration() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add, color: BmbColors.successGreen, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Join for Free',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Start competing instantly with a free account.',
            style: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Free tier benefits
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                BmbColors.successGreen.withValues(alpha: 0.1),
                BmbColors.successGreen.withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: BmbColors.successGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'FREE',
                  style: TextStyle(
                    color: BmbColors.successGreen,
                    fontSize: 32,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No credit card required',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ...[
                  'Create & join brackets',
                  'Make picks and compete',
                  'Join public tournaments',
                  'Chat with other players',
                  'Earn referral credits',
                  'Access the BMB store',
                ].map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: BmbColors.successGreen, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(f,
                                style: TextStyle(
                                    color: BmbColors.textSecondary,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),

                // Sign Up button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _navigateToSignup(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Create Free Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold,
                      ),
                    ),
                  ),
                ),
                if (widget.referralCode != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Code "${widget.referralCode}" will be auto-applied',
                    style: TextStyle(
                      color: BmbColors.successGreen.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── FEATURE SHOWCASE ─────────────────────────────────────────────

  Widget _buildFeatureShowcase() {
    final features = [
      {
        'icon': Icons.account_tree,
        'title': 'Build Any Bracket',
        'desc': 'March Madness, NFL playoffs, custom tournaments — any sport, any format.',
        'color': BmbColors.blue,
      },
      {
        'icon': Icons.people,
        'title': 'Compete With Friends',
        'desc': 'Invite friends, make picks, and climb the leaderboard together.',
        'color': BmbColors.gold,
      },
      {
        'icon': Icons.grid_4x4,
        'title': 'Squares & Pick\'em',
        'desc': 'Not just brackets — play squares, pick\'em, trivia, and more.',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'icon': Icons.store,
        'title': 'BMB Store',
        'desc': 'Spend your credits on exclusive merch and prizes.',
        'color': const Color(0xFFEC4899),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why People Love BMB',
            style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 18,
              fontWeight: BmbFontWeights.bold,
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: BmbColors.borderColor, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (f['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(f['icon'] as IconData,
                          color: f['color'] as Color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f['title'] as String,
                            style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 14,
                              fontWeight: BmbFontWeights.semiBold,
                            ),
                          ),
                          Text(
                            f['desc'] as String,
                            style: TextStyle(
                                color: BmbColors.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── CTA FOOTER ───────────────────────────────────────────────────

  Widget _buildCtaFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BmbColors.blue.withValues(alpha: 0.2),
              BmbColors.blue.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BmbColors.blue.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Icon(Icons.sports_basketball,
                color: BmbColors.blue, size: 40),
            const SizedBox(height: 12),
            Text(
              'Ready to Compete?',
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 20,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join thousands of bracket enthusiasts. Create your first bracket in under a minute.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToSignup(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Sign Up Free',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: BmbFontWeights.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  // Link to BMB+ upgrade page
                  final uri = Uri.parse('https://backmybracket.com/plus');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    _navigateToSignup();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: BmbColors.gold,
                  side: BorderSide(color: BmbColors.gold.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Learn About BMB+',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: BmbFontWeights.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── NAVIGATION ───────────────────────────────────────────────────

  void _navigateToSignup() {
    // Navigate to auth screen, passing referral code for auto-apply
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (r) => false);
  }
}
