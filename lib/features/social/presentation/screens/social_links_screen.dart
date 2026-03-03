import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';

/// Social media links and "Follow Us" screen to grow the BMB community.
class SocialLinksScreen extends StatelessWidget {
  const SocialLinksScreen({super.key});

  static const _socials = [
    {'name': 'Instagram', 'handle': '@backmybracket', 'url': 'https://instagram.com/backmybracket', 'icon': Icons.camera_alt, 'color': Color(0xFFE4405F), 'followers': '12.4K'},
    {'name': 'Twitter / X', 'handle': '@BackMyBracket', 'url': 'https://twitter.com/BackMyBracket', 'icon': Icons.chat_bubble, 'color': Color(0xFF1DA1F2), 'followers': '8.7K'},
    {'name': 'TikTok', 'handle': '@backmybracket', 'url': 'https://tiktok.com/@backmybracket', 'icon': Icons.music_note, 'color': Color(0xFF000000), 'followers': '25.1K'},
    {'name': 'Facebook', 'handle': 'Back My Bracket', 'url': 'https://facebook.com/backmybracket', 'icon': Icons.thumb_up, 'color': Color(0xFF1877F2), 'followers': '5.3K'},
    {'name': 'YouTube', 'handle': 'Back My Bracket', 'url': 'https://youtube.com/@backmybracket', 'icon': Icons.play_circle_filled, 'color': Color(0xFFFF0000), 'followers': '3.2K'},
    {'name': 'Discord', 'handle': 'BMB Community', 'url': 'https://discord.gg/backmybracket', 'icon': Icons.headphones, 'color': Color(0xFF5865F2), 'followers': '1.8K'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildCommunityBanner()),
              SliverToBoxAdapter(child: _buildSocialGrid(context)),
              SliverToBoxAdapter(child: _buildShareAppCard(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Text('Follow BMB', style: TextStyle(color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
        ],
      ),
    );
  }

  Widget _buildCommunityBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [BmbColors.blue.withValues(alpha: 0.15), BmbColors.blue.withValues(alpha: 0.05)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.groups, color: BmbColors.blue, size: 40),
            const SizedBox(height: 10),
            Text('Join the BMB Community', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 6),
            Text('Follow us on social media for tournament updates, exclusive content, giveaways, and to connect with fellow bracket enthusiasts!',
                textAlign: TextAlign.center, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.5)),
            const SizedBox(height: 12),
            Text('56K+ community members', style: TextStyle(color: BmbColors.blue, fontSize: 13, fontWeight: BmbFontWeights.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Our Channels', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 12),
          ..._socials.map((s) {
            final color = s['color'] as Color;
            return GestureDetector(
              onTap: () => _openUrl(context, s['url'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5)),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(s['icon'] as IconData, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['name'] as String, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                          Text(s['handle'] as String, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(s['followers'] as String, style: TextStyle(color: color, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                        Text('followers', style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_new, color: BmbColors.textTertiary, size: 16),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShareAppCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.12), BmbColors.gold.withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.share, color: BmbColors.gold, size: 28),
            const SizedBox(height: 8),
            Text('Share Back My Bracket', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
            const SizedBox(height: 4),
            Text('Spread the word and help grow the bracket community!', textAlign: TextAlign.center, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Opening share sheet...'), backgroundColor: BmbColors.midNavy, behavior: SnackBarBehavior.floating));
                },
                style: ElevatedButton.styleFrom(backgroundColor: BmbColors.gold, foregroundColor: BmbColors.deepNavy, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: Text('Share App', style: TextStyle(fontWeight: BmbFontWeights.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening $url'), backgroundColor: BmbColors.midNavy, behavior: SnackBarBehavior.floating));
      }
    }
  }
}
