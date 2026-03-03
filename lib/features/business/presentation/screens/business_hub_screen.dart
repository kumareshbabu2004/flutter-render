import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/presentation/screens/bracket_builder_screen.dart';
import 'package:bmb_mobile/features/business/presentation/screens/bmb_starter_kit_screen.dart';
import 'package:bmb_mobile/features/store/presentation/screens/bmb_store_screen.dart';

/// Business hub for bar/restaurant owners — how-to videos, starter kits, resources.
class BusinessHubScreen extends StatelessWidget {
  const BusinessHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildStarterKitCta(context)),
              SliverToBoxAdapter(child: _buildHowToVideos(context)),
              SliverToBoxAdapter(child: _buildStarterKits(context)),
              SliverToBoxAdapter(child: _buildQuickActions(context)),
              SliverToBoxAdapter(child: _buildTips()),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Business Hub',
                    style: TextStyle(
                        color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                Text('Tools & resources for your establishment',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [BmbColors.gold, BmbColors.goldLight]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: BmbColors.deepNavy, size: 12),
                const SizedBox(width: 4),
                Text('BMB+biz', style: TextStyle(color: BmbColors.deepNavy, fontSize: 10, fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── STARTER KIT CTA (prominent, at top) ─────────────────────────
  Widget _buildStarterKitCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BmbStarterKitScreen())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                BmbColors.gold.withValues(alpha: 0.2),
                BmbColors.gold.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BmbColors.gold, width: 1.5),
            boxShadow: [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.12), blurRadius: 16)],
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.inventory_2, color: BmbColors.gold, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BMB Starter Kit',
                        style: TextStyle(
                            color: BmbColors.gold, fontSize: 16,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    Text('Posters, QR sweatshirts, table tents, marketing materials',
                        style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward, color: BmbColors.gold, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Video gallery URL — hosted alongside the Flutter web build.
  static const String _videoGalleryUrl = 'https://backmybracket.com/how-to-videos';

  Widget _buildHowToVideos(BuildContext context) {
    final videos = [
      {'num': '1', 'title': 'Host Your First Tournament', 'duration': '0:35', 'icon': Icons.play_circle_filled, 'desc': 'Create your first bracket in under 60 seconds — from setup to Go Live.'},
      {'num': '2', 'title': 'Menu Item Voting Brackets', 'duration': '0:38', 'icon': Icons.restaurant_menu, 'desc': 'Let customers vote: Best Wings? Top Burger? Real data on what your crowd loves.'},
      {'num': '3', 'title': 'Custom Apparel & QR Codes', 'duration': '0:43', 'icon': Icons.checkroom, 'desc': 'Turn brackets into custom hoodies, tees, and hats — walking billboards.'},
      {'num': '4', 'title': 'QR Code Setup & Placement', 'duration': '0:44', 'icon': Icons.qr_code, 'desc': 'Table tents, bar posters, receipts, TVs — zero friction bracket access.'},
      {'num': '5', 'title': 'BMB Starter Kit', 'duration': '0:41', 'icon': Icons.inventory_2, 'desc': 'Unbox everything you need: posters, QR gear, table tents, quick-start guide.'},
      {'num': '6', 'title': 'Hosting Local Events', 'duration': '1:13', 'icon': Icons.event, 'desc': 'Wing-Off Wednesdays, Trivia Brackets, Cocktail Showdowns + dedicated BMB rep.'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.ondemand_video, color: BmbColors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('How-To Video Series',
                    style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              ),
              GestureDetector(
                onTap: () => _openVideoGallery(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Watch All', style: TextStyle(color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new, color: BmbColors.blue, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('6 concise tutorials to get your bar up and running',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 12),
          ...videos.map((v) => _videoCard(context, v)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _openVideoGallery(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: BmbColors.blue.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.play_circle_outline, color: BmbColors.blue, size: 20),
              label: Text('Open Full Video Gallery', style: TextStyle(
                  color: BmbColors.blue, fontSize: 14, fontWeight: BmbFontWeights.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openVideoGallery(BuildContext context) async {
    final uri = Uri.parse(_videoGalleryUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open video gallery. Visit backmybracket.com/how-to-videos'),
          backgroundColor: BmbColors.midNavy,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _videoCard(BuildContext context, Map<String, dynamic> v) {
    return GestureDetector(
      onTap: () => _openVideoGallery(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: BmbColors.errorRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(v['num'] as String,
                    style: TextStyle(color: BmbColors.errorRed, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v['title'] as String,
                      style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 2),
                  Text(v['desc'] as String,
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              children: [
                Icon(Icons.play_arrow, color: BmbColors.blue, size: 24),
                Text(v['duration'] as String, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarterKits(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag, color: BmbColors.gold, size: 20),
              const SizedBox(width: 8),
              Text('Order Additional Materials',
                  style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            ],
          ),
          const SizedBox(height: 4),
          Text('Need more posters, sweatshirts, or table tents?',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BmbStoreScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.storefront, size: 20),
              label: Text('Visit BMB Store', style: TextStyle(
                  fontSize: 14, fontWeight: BmbFontWeights.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _actionTile(context, 'Host a\nTournament', Icons.add_circle, BmbColors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _actionTile(context, 'Menu Item\nChallenge', Icons.restaurant_menu, BmbColors.gold)),
              const SizedBox(width: 10),
              Expanded(child: _actionTile(context, 'Charity\nFundraiser', Icons.volunteer_activism, BmbColors.successGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionTile(BuildContext context, String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BracketBuilderScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, fontWeight: BmbFontWeights.medium)),
          ],
        ),
      ),
    );
  }

  Widget _buildTips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.1), BmbColors.gold.withValues(alpha: 0.03)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: BmbColors.gold, size: 20),
                const SizedBox(width: 8),
                Text('Pro Tip', style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Bars that host weekly bracket challenges see 40% more repeat customers during game seasons. Start with a simple Pick \'Em for this weekend!',
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
