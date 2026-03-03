import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/store/presentation/screens/bmb_store_screen.dart';
import 'package:bmb_mobile/features/payments/data/services/stripe_payment_service.dart';

/// Deep-link target for the BMB Starter Kit.
/// Shows kit contents, quick-start videos, and links to the BMB Store.
class BmbStarterKitScreen extends StatelessWidget {
  const BmbStarterKitScreen({super.key});

  // ── KIT CONTENTS — matches Video 5 script exactly ────────────────────
  static const _kitItems = [
    _KitItem(
      icon: Icons.description,
      title: 'Quick-Start Guide',
      desc: 'Step-by-step guide from creating your account to publishing your first bracket. Laminated and ready to hang behind the bar.',
      qty: '1',
    ),
    _KitItem(
      icon: Icons.image,
      title: 'Branded QR Posters',
      desc: 'Pre-designed, ready to print or frame. Put them at the entrance, by the bar, and in the restrooms. Each poster features your unique QR code.',
      qty: '2',
    ),
    _KitItem(
      icon: Icons.table_restaurant,
      title: 'Table Tent Inserts',
      desc: 'Drop these on every table so customers see "Scan to Play" while they\u2019re eating and drinking. Double-sided with your QR code.',
      qty: '10',
    ),
    _KitItem(
      icon: Icons.checkroom,
      title: 'Branded Merch with QR Code',
      desc: 'Your first two branded merch items with your bar\u2019s QR code built in. Hand them out to your best regulars or your bartenders.',
      qty: '2',
      sizes: 'S, M, L, XL, 2XL',
    ),
  ];

  // ── QUICK-START VIDEOS — links to the actual 6 How-To videos ─────────
  static const _videos = [
    _Video(
      title: 'Host Your First Tournament',
      duration: '0:35',
      desc: 'Create your first bracket in under 60 seconds \u2014 from setup to Go Live.',
      icon: Icons.play_circle_filled,
    ),
    _Video(
      title: 'Menu Item Voting Brackets',
      duration: '0:38',
      desc: 'Let customers vote: Best Wings? Top Burger? Real data on what your crowd loves.',
      icon: Icons.restaurant_menu,
    ),
    _Video(
      title: 'Custom Apparel & QR Codes',
      duration: '0:43',
      desc: 'Turn brackets into custom hoodies, tees, and hats \u2014 walking billboards.',
      icon: Icons.checkroom,
    ),
    _Video(
      title: 'QR Code Setup & Placement',
      duration: '0:44',
      desc: 'Table tents, bar posters, receipts, TVs \u2014 zero friction bracket access.',
      icon: Icons.qr_code_scanner,
    ),
    _Video(
      title: 'BMB Starter Kit',
      duration: '0:41',
      desc: 'Unbox everything: posters, QR gear, table tents, quick-start guide.',
      icon: Icons.inventory_2,
    ),
    _Video(
      title: 'Hosting Local Events',
      duration: '1:13',
      desc: 'Wing-Off Wednesdays, Trivia Brackets, Cocktail Showdowns + dedicated BMB rep.',
      icon: Icons.event,
    ),
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
              SliverToBoxAdapter(child: _buildHeroBanner(context)),
              SliverToBoxAdapter(child: _buildKitContents()),
              SliverToBoxAdapter(child: _buildQuickStartVideos(context)),
              SliverToBoxAdapter(child: _buildOrderCta(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text('BMB Starter Kit',
                style: TextStyle(
                    color: BmbColors.textPrimary, fontSize: 20,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BmbStoreScreen())),
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
                  Icon(Icons.storefront, color: BmbColors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text('BMB Store', style: TextStyle(
                      color: BmbColors.blue, fontSize: 12,
                      fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HERO BANNER ──────────────────────────────────────────────────────
  Widget _buildHeroBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              BmbColors.gold.withValues(alpha: 0.2),
              BmbColors.gold.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BmbColors.gold, width: 1.5),
          boxShadow: [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.12), blurRadius: 20)],
        ),
        child: Column(
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [BmbColors.gold, BmbColors.goldLight]),
                boxShadow: [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.4), blurRadius: 20)],
              ),
              child: const Icon(Icons.inventory_2, color: Colors.black, size: 36),
            ),
            const SizedBox(height: 14),
            Text('Everything You Need to Host',
                style: TextStyle(
                    color: BmbColors.textPrimary, fontSize: 20,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay'),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Your BMB Starter Kit ships free with your business account. '
              'It includes everything you need to launch brackets at your bar on day one: '
              'a Quick-Start Guide, branded QR posters, table tent inserts, and branded merch with your QR code built in. '
              'Unbox it, set it up, and you\'re live by tonight.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_shipping, color: BmbColors.successGreen, size: 16),
                  const SizedBox(width: 6),
                  Text('Free Shipping — Arrives in 5\u20137 Business Days',
                      style: TextStyle(color: BmbColors.successGreen, fontSize: 12,
                          fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── KIT CONTENTS ─────────────────────────────────────────────────────
  Widget _buildKitContents() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, color: BmbColors.gold, size: 22),
              const SizedBox(width: 8),
              Text('What\u2019s in the Kit',
                  style: TextStyle(color: BmbColors.textPrimary, fontSize: 18,
                      fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            ],
          ),
          const SizedBox(height: 14),
          ..._kitItems.map((item) => _kitItemCard(item)),
        ],
      ),
    );
  }

  Widget _kitItemCard(_KitItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: BmbColors.gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title, style: TextStyle(
                          color: BmbColors.textPrimary, fontSize: 14,
                          fontWeight: BmbFontWeights.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: BmbColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('x${item.qty}', style: TextStyle(
                          color: BmbColors.gold, fontSize: 11,
                          fontWeight: BmbFontWeights.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.desc, style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 12, height: 1.3)),
                if (item.sizes != null) ...[
                  const SizedBox(height: 4),
                  Text('Sizes: ${item.sizes}', style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 11,
                      fontWeight: BmbFontWeights.semiBold)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── QUICK-START VIDEOS ───────────────────────────────────────────────
  Widget _buildQuickStartVideos(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.ondemand_video, color: BmbColors.blue, size: 22),
              const SizedBox(width: 8),
              Text('Quick Start Videos',
                  style: TextStyle(color: BmbColors.textPrimary, fontSize: 18,
                      fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            ],
          ),
          const SizedBox(height: 6),
          Text('6 concise trainings to get your bar up and running',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          ..._videos.map((v) => _videoCard(context, v)),
        ],
      ),
    );
  }

  static const String _videoGalleryUrl = 'https://backmybracket.com/how-to-videos';

  void _openVideoGallery(BuildContext context) async {
    final uri = Uri.parse(_videoGalleryUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Visit backmybracket.com/how-to-videos'),
          backgroundColor: BmbColors.midNavy,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _videoCard(BuildContext context, _Video v) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openVideoGallery(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(v.icon, color: BmbColors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title, style: TextStyle(
                      color: BmbColors.textPrimary, fontSize: 13,
                      fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 2),
                  Text(v.desc, style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              children: [
                Icon(Icons.play_arrow, color: BmbColors.blue, size: 22),
                Text(v.duration, style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── ORDER CTA ────────────────────────────────────────────────────────
  Widget _buildOrderCta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          // Buy Starter Kit via Stripe
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final email = await StripePaymentService.getUserEmail();
                if (!context.mounted) return;
                await StripePaymentService.checkoutStarterKit(context, email: email);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: BmbColors.gold.withValues(alpha: 0.4),
              ),
              icon: const Icon(Icons.payment, size: 20),
              label: Text('Order Starter Kit', style: TextStyle(
                  fontSize: 16, fontWeight: BmbFontWeights.bold)),
            ),
          ),
          const SizedBox(height: 8),
          // Stripe trust badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF635BFF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF635BFF).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: const Color(0xFF635BFF), size: 14),
                const SizedBox(width: 6),
                Text('Secure checkout powered by Stripe',
                    style: TextStyle(color: const Color(0xFF635BFF), fontSize: 11,
                        fontWeight: BmbFontWeights.semiBold)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Also visit BMB Store link
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BmbStoreScreen())),
            child: Text('Browse BMB Store for more merch',
                style: TextStyle(color: BmbColors.blue, fontSize: 12)),
          ),
          const SizedBox(height: 4),
          Text('Need additional materials? Visit the BMB Store for extra posters, table tents, sweatshirts, and custom merch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────────
class _KitItem {
  final IconData icon;
  final String title;
  final String desc;
  final String qty;
  final String? sizes;
  const _KitItem({
    required this.icon, required this.title,
    required this.desc, required this.qty, this.sizes,
  });
}

class _Video {
  final String title;
  final String duration;
  final String desc;
  final IconData icon;
  const _Video({
    required this.title, required this.duration,
    required this.desc, required this.icon,
  });
}
