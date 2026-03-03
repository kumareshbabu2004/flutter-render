import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/sharing/data/services/social_accounts_service.dart';
import 'package:bmb_mobile/features/referral/data/services/referral_code_service.dart';
import 'package:bmb_mobile/features/referral/presentation/screens/referral_landing_page.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _codeService = ReferralCodeService.instance;

  String _referralCode = '...';
  String _referralLink = '';
  String _shareMessage = '';
  String _socialMessage = '';
  bool _loading = true;

  List<Map<String, dynamic>> _referrals = [];
  Map<String, dynamic> _stats = {};

  Map<String, LinkedSocialAccount> _linkedAccounts = {};

  @override
  void initState() {
    super.initState();
    _initReferralData();
    _loadLinkedAccounts();
  }

  Future<void> _initReferralData() async {
    final code = await _codeService.getOrCreateCode();
    final link = await _codeService.getReferralLink(deepLinkToVideos: true);
    final msg = await _codeService.buildShareMessage();
    final social = await _codeService.buildSocialMessage();
    final history = await _codeService.getReferralHistory();
    final stats = await _codeService.getStats();

    if (mounted) {
      setState(() {
        _referralCode = code;
        _referralLink = link;
        _shareMessage = msg;
        _socialMessage = social;
        _referrals = history;
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _loadLinkedAccounts() async {
    final accounts = await SocialAccountsService.getLinkedAccounts();
    if (mounted) {
      setState(() => _linkedAccounts = accounts);
    }
  }

  // ─── SHARE ACTIONS ──────────────────────────────────────────────

  Future<void> _shareViaText() async {
    // Copy code to clipboard first
    await Clipboard.setData(ClipboardData(text: _referralCode));

    // Build SMS URI with pre-filled body including the referral link
    // The link contains &section=videos to direct them to how-to videos
    final body = Uri.encodeComponent(_shareMessage);
    final smsUri = Uri.parse('sms:?body=$body');

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: on web, sms: might not work — just confirm copy
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Code & link copied! Paste into your messaging app.')),
          ]),
          backgroundColor: BmbColors.successGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  Future<void> _shareViaEmail() async {
    await Clipboard.setData(ClipboardData(text: _referralCode));

    final subject = Uri.encodeComponent('You\'re invited to Back My Bracket!');
    final body = Uri.encodeComponent(_shareMessage);
    final emailUri = Uri.parse('mailto:?subject=$subject&body=$body');

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Code & link copied! Paste into your email app.')),
          ]),
          backgroundColor: BmbColors.blue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  Future<void> _shareViaSocial() async {
    if (_linkedAccounts.isEmpty) {
      _showConnectSocialsSheet();
    } else {
      _showSocialSharePicker();
    }
  }

  void _showSocialSharePicker() {
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
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: BmbColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.share, color: BmbColors.gold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Share to Socials', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                        Text('Your referral code & video link included', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Preview message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BmbColors.borderColor, width: 0.5),
                ),
                child: Text(_socialMessage, style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.5)),
              ),
              const SizedBox(height: 16),

              // Linked platforms
              ..._linkedAccounts.entries.map((entry) {
                final platform = SocialAccountsService.allPlatforms
                    .firstWhere((p) => p.id == entry.key, orElse: () => SocialAccountsService.allPlatforms.first);
                final color = Color(platform.color);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Clipboard.setData(ClipboardData(text: _socialMessage));
                        await _launchSocialShare(platform, _socialMessage);
                      },
                      icon: Icon(SocialPlatform.getIcon(platform.id), size: 20),
                      label: Text(
                        'Share to ${platform.name} (@${entry.value.username})',
                        style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.semiBold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color.withValues(alpha: 0.15),
                        foregroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 8),

              // Copy for manual paste
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: _socialMessage));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text('Copied! Paste to any social app.'),
                      ]),
                      backgroundColor: BmbColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('Copy Message', style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BmbColors.textSecondary,
                    side: BorderSide(color: BmbColors.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showConnectSocialsSheet();
                },
                child: Text('Connect more accounts', style: TextStyle(color: BmbColors.blue, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchSocialShare(SocialPlatform platform, String text) async {
    late Uri uri;
    switch (platform.id) {
      case 'twitter':
        final encoded = Uri.encodeComponent(text);
        uri = Uri.parse('https://twitter.com/intent/tweet?text=$encoded');
        break;
      case 'facebook':
        final encoded = Uri.encodeComponent(text);
        uri = Uri.parse('https://www.facebook.com/sharer/sharer.php?quote=$encoded&u=${Uri.encodeComponent(_referralLink)}');
        break;
      default:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Message copied! Paste it in ${platform.name}.'),
            backgroundColor: BmbColors.midNavy,
            behavior: SnackBarBehavior.floating,
          ));
        }
        uri = Uri.parse(platform.shareUrlBase);
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showConnectSocialsSheet() {
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
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.people, color: BmbColors.blue, size: 40),
              const SizedBox(height: 12),
              Text('Connect Your Socials', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const SizedBox(height: 6),
              Text('Link your social accounts to share referrals instantly.', textAlign: TextAlign.center, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 20),

              ...SocialAccountsService.allPlatforms.map((platform) {
                final isLinked = _linkedAccounts.containsKey(platform.id);
                final color = Color(platform.color);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLinked
                          ? null
                          : () => _linkSocialAccount(ctx, platform),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLinked ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.15),
                        foregroundColor: color,
                        disabledBackgroundColor: color.withValues(alpha: 0.08),
                        disabledForegroundColor: color.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        side: BorderSide(color: color.withValues(alpha: isLinked ? 0.15 : 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(SocialPlatform.getIcon(platform.id), size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Text(platform.name, style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.semiBold))),
                          if (isLinked) ...[
                            const Icon(Icons.check_circle, size: 18),
                            const SizedBox(width: 4),
                            Text('@${_linkedAccounts[platform.id]!.username}', style: TextStyle(fontSize: 11)),
                          ] else
                            Text('Connect', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _linkSocialAccount(BuildContext sheetCtx, SocialPlatform platform) async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Connect ${platform.name}', style: TextStyle(color: BmbColors.textPrimary, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay', fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your ${platform.name} username:', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: BmbColors.textPrimary),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: TextStyle(color: BmbColors.textTertiary),
                hintText: 'username',
                hintStyle: TextStyle(color: BmbColors.textTertiary),
                filled: true,
                fillColor: BmbColors.deepNavy,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Color(platform.color))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Color(platform.color), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (username != null && username.isNotEmpty) {
      await SocialAccountsService.linkAccount(platformId: platform.id, username: username);
      await _loadLinkedAccounts();
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${platform.name} connected!'),
          ]),
          backgroundColor: BmbColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: BmbColors.blue))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildRewardCard()),
                    SliverToBoxAdapter(child: _buildShareSection()),
                    SliverToBoxAdapter(child: _buildHowItWorks()),
                    SliverToBoxAdapter(child: _buildReferralHistory()),
                    SliverToBoxAdapter(child: _buildReferralLandingInfo()),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Refer a Friend', style: TextStyle(color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                Text('Earn 10 credits for every friend who joins!', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard() {
    final totalCredits = _stats['totalCredits'] ?? 0;
    final active = _stats['active'] ?? 0;
    final pending = _stats['pending'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.15), BmbColors.gold.withValues(alpha: 0.05)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Icon(Icons.card_giftcard, color: BmbColors.gold, size: 40),
            const SizedBox(height: 12),
            Text('Your Earnings', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text('$totalCredits credits', style: TextStyle(color: BmbColors.gold, fontSize: 36, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 4),
            Text('$active successful referral${active != 1 ? 's' : ''}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statBubble('$active', 'Active', BmbColors.successGreen),
                _statBubble('$pending', 'Pending', BmbColors.gold),
                _statBubble('10', 'Credits/Ref', BmbColors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBubble(String val, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Center(child: Text(val, style: TextStyle(color: color, fontSize: 16, fontWeight: BmbFontWeights.bold))),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
      ],
    );
  }

  Widget _buildShareSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share Your Code', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 12),
          // Code display
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Unique Referral Code', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(_referralCode, style: TextStyle(color: BmbColors.blue, fontSize: 20, fontWeight: BmbFontWeights.bold, letterSpacing: 2)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text('Referral code copied!'),
                      ]),
                      backgroundColor: BmbColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  icon: const Icon(Icons.copy, color: BmbColors.blue, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Link display — shows the full URL with ?ref=CODE&section=videos
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
            child: Row(
              children: [
                const Icon(Icons.link, color: BmbColors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_referralLink, style: TextStyle(color: BmbColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 2),
                      const SizedBox(height: 2),
                      Text(
                        'Links to videos, BMB+ promos & free signup',
                        style: TextStyle(color: BmbColors.blue.withValues(alpha: 0.7), fontSize: 9),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _referralLink));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text('Referral link copied!'),
                      ]),
                      backgroundColor: BmbColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                  icon: const Icon(Icons.copy, color: BmbColors.textSecondary, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ─── REAL SHARE BUTTONS ─────────────────────────────────
          Row(
            children: [
              Expanded(child: _shareButton('Text', Icons.message, BmbColors.successGreen, _shareViaText)),
              const SizedBox(width: 10),
              Expanded(child: _shareButton('Email', Icons.email, BmbColors.blue, _shareViaEmail)),
              const SizedBox(width: 10),
              Expanded(child: _shareButton('Social', Icons.share, BmbColors.gold, _shareViaSocial)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shareButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      {'step': '1', 'title': 'Share Your Code', 'desc': 'Send your unique referral code or link — it opens a page with how-to videos & signup'},
      {'step': '2', 'title': 'Friend Watches & Signs Up', 'desc': 'They see BMB videos, BMB+ promos, and can create a free account instantly'},
      {'step': '3', 'title': 'You Earn 10 Credits', 'desc': '10 credits added to your BMB Bucket when they join'},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How It Works', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 12),
          ...steps.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Center(child: Text(s['step']!, style: TextStyle(color: BmbColors.blue, fontWeight: BmbFontWeights.bold, fontSize: 16))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['title']!, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
                      Text(s['desc']!, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
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

  Widget _buildReferralHistory() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Referral History', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 12),
          ..._referrals.map((r) {
            final isActive = r['status'] == 'active';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: (isActive ? BmbColors.successGreen : BmbColors.gold).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text((r['name'] as String)[0], style: TextStyle(color: isActive ? BmbColors.successGreen : BmbColors.gold, fontWeight: BmbFontWeights.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['name'] as String, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
                        Text('Joined ${r['date']}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isActive ? BmbColors.successGreen : BmbColors.gold).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isActive ? 'Earned ${r['earned']}' : 'Pending',
                        style: TextStyle(color: isActive ? BmbColors.successGreen : BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// What happens when the referral link is clicked — landing page info.
  Widget _buildReferralLandingInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [BmbColors.blue.withValues(alpha: 0.12), BmbColors.blue.withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: BmbColors.blue, size: 20),
                const SizedBox(width: 8),
                Text('When They Click Your Link', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              ],
            ),
            const SizedBox(height: 12),
            _landingItem(Icons.play_circle_outline, 'Quick How-To Videos', 'Five short videos showing how BMB works — no account needed'),
            _landingItem(Icons.star_outline, 'BMB+ Membership Perks', 'See premium features, pricing & promo deals'),
            _landingItem(Icons.person_add_alt_1, 'Free Registration', 'One-tap account creation — no credit card, code auto-applied'),
            _landingItem(Icons.emoji_events, 'Referral Bonus', '10 credits for both of you when they sign up'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Open the in-app landing page preview
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReferralLandingPage(
                        referralCode: _referralCode,
                        scrollToVideos: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('Preview Landing Page', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BmbColors.blue,
                  side: BorderSide(color: BmbColors.blue.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landingItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BmbColors.blue.withValues(alpha: 0.7), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                Text(desc, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
