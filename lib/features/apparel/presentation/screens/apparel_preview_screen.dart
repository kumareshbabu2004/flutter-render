import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/widgets/bracket_print_canvas.dart';

class ApparelPreviewScreen extends StatefulWidget {
  final CreatedBracket bracket;
  final List<String> picks;
  const ApparelPreviewScreen(
      {super.key, required this.bracket, required this.picks});
  @override
  State<ApparelPreviewScreen> createState() => _ApparelPreviewScreenState();
}

class _ApparelPreviewScreenState extends State<ApparelPreviewScreen> {
  int _selectedProductIndex = 0;

  final List<_ApparelProduct> _products = const [
    _ApparelProduct(
      name: 'BMB Champion Hoodie',
      price: '\$59.99',
      color: Color(0xFF2D2D2D),
      icon: Icons.checkroom,
      description: 'Premium heavyweight hoodie with your bracket on the back',
    ),
    _ApparelProduct(
      name: 'BMB Classic Tee',
      price: '\$34.99',
      color: Color(0xFF1A1A2E),
      icon: Icons.dry_cleaning,
      description: 'Soft cotton tee with full bracket print on the back',
    ),
    _ApparelProduct(
      name: 'BMB Long Sleeve',
      price: '\$44.99',
      color: Color(0xFF3D1C00),
      icon: Icons.dry_cleaning,
      description: 'Long sleeve with bracket art on the back',
    ),
    _ApparelProduct(
      name: 'BMB Tank Top',
      price: '\$29.99',
      color: Color(0xFF0D2137),
      icon: Icons.dry_cleaning,
      description: 'Athletic tank with your bracket on the back',
    ),
    _ApparelProduct(
      name: 'BMB Crewneck Sweatshirt',
      price: '\$49.99',
      color: Color(0xFF2A0A0A),
      icon: Icons.checkroom,
      description: 'Cozy crewneck with your bracket printed on the back',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final product = _products[_selectedProductIndex];
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Product preview with bracket overlay
                      _buildProductPreview(product),
                      const SizedBox(height: 16),
                      // Product selector
                      _buildProductSelector(),
                      const SizedBox(height: 16),
                      // Product details
                      _buildProductDetails(product),
                      const SizedBox(height: 16),
                      // Bracket preview
                      _buildBracketPreview(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(product),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon:
                const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add to Apparel',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Text('Your bracket. Your style.',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Image.asset('assets/images/splash_dark.png',
              width: 32, height: 32),
        ],
      ),
    );
  }

  Widget _buildProductPreview(_ApparelProduct product) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 360,
      decoration: BoxDecoration(
        color: product.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Product silhouette
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(product.icon,
                    size: 60,
                    color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 8),
                Text('BACK VIEW',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 10,
                        letterSpacing: 2)),
              ],
            ),
          ),
          // Bracket overlay on the back
          Positioned(
            top: 50,
            left: 30,
            right: 30,
            bottom: 50,
            child: _buildMiniBracket(),
          ),
          // BMB splash logo on the mockup
          Positioned(
            bottom: 12,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/splash_dark.png',
                  width: 18, height: 18,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 4),
                Text('BACK MY BRACKET',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 8,
                        letterSpacing: 2,
                        fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the actual bracket tree using the same BracketPrintCanvas
  /// that powers the real hoodie print pipeline. This ensures the
  /// apparel preview accurately represents what gets printed.
  Widget _buildMiniBracket() {
    final teams = widget.bracket.teams;
    final teamCount = widget.bracket.teamCount;
    final championName = widget.picks.isNotEmpty ? widget.picks.last : 'TBD';

    // Build picks map from the List<String> picks.
    // The picks list is ordered: round 0 winners, round 1 winners, ...
    // Convert to the keyed format that BracketPrintCanvas expects.
    final picksMap = <String, String>{};
    final totalRounds = _log2(teamCount);
    int pickIdx = 0;
    int matchesInRound = teamCount ~/ 2;
    for (int r = 0; r < totalRounds; r++) {
      for (int g = 0; g < matchesInRound; g++) {
        if (pickIdx < widget.picks.length) {
          picksMap['r${r}_g$g'] = widget.picks[pickIdx];
          // Also add the keyed format for left/right sides
          final halfMatches = matchesInRound ~/ 2;
          if (g < halfMatches) {
            picksMap['slot_left_r${r + 1}_m${g}_team1'] = widget.picks[pickIdx];
          } else {
            picksMap['slot_right_r${r + 1}_m${g - halfMatches}_team1'] = widget.picks[pickIdx];
          }
          pickIdx++;
        }
      }
      matchesInRound = (matchesInRound / 2).ceil();
    }

    // Ensure teamCount is a power of 2 for the canvas renderer
    int safeTeamCount = teamCount;
    if (safeTeamCount < 4) safeTeamCount = 4;
    // Pad teams list if needed
    final safeTeams = List<String>.from(teams);
    while (safeTeams.length < safeTeamCount) {
      safeTeams.add('TBD');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CustomPaint(
        size: Size.infinite,
        painter: BracketPrintCanvas(
          bracketTitle: widget.bracket.name,
          championName: championName,
          teamCount: safeTeamCount,
          teams: safeTeams,
          picks: picksMap,
          palette: BracketPrintPalette.previewHighContrast,
          renderMode: BracketRenderMode.bracketPreview,
        ),
      ),
    );
  }

  int _log2(int n) {
    int r = 0;
    while (n > 1) { n ~/= 2; r++; }
    return r;
  }

  Widget _buildProductSelector() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _products.length,
        itemBuilder: (ctx, i) {
          final sel = _selectedProductIndex == i;
          final p = _products[i];
          return GestureDetector(
            onTap: () => setState(() => _selectedProductIndex = i),
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: p.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? BmbColors.gold : BmbColors.borderColor,
                  width: sel ? 2 : 0.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(p.icon,
                      color: Colors.white.withValues(alpha: 0.6), size: 24),
                  const SizedBox(height: 4),
                  Text(p.price,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductDetails(_ApparelProduct product) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(product.name,
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 16,
                          fontWeight: BmbFontWeights.bold)),
                ),
                Text(product.price,
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(product.description,
                style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                _featureTag('Your Picks Printed'),
                const SizedBox(width: 8),
                _featureTag('Premium Quality'),
                const SizedBox(width: 8),
                _featureTag('Ships in 5-7 days'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BmbColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(color: BmbColors.blue, fontSize: 9)),
    );
  }

  Widget _buildBracketPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: BmbColors.textSecondary, size: 16),
                const SizedBox(width: 8),
                Text('Your Bracket Image',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.semiBold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This bracket image will be printed on the back of your selected apparel. '
              '"Back My Bracket" \u2014 literally wear your picks!',
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 11,
                  height: 1.4),
            ),
            const SizedBox(height: 8),
            // Show champion pick
            if (widget.picks.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: BmbColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events,
                        color: BmbColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Text('Your Champion: ',
                        style: TextStyle(
                            color: BmbColors.textSecondary, fontSize: 12)),
                    Text(widget.picks.last,
                        style: TextStyle(
                            color: BmbColors.gold,
                            fontSize: 13,
                            fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(_ApparelProduct product) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.95),
        border: Border(
            top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name,
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 13,
                      fontWeight: BmbFontWeights.semiBold)),
              Text(product.price,
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 15,
                      fontWeight: BmbFontWeights.bold)),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.shopping_cart, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'BMB Store integration launching soon \u2014 stay tuned!'),
                    ),
                  ],
                ),
                backgroundColor: BmbColors.blue,
                behavior: SnackBarBehavior.floating,
              ));
            },
            icon: Icon(Icons.shopping_cart, size: 18),
            label: Text('Order Now',
                style: TextStyle(fontWeight: BmbFontWeights.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.gold,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApparelProduct {
  final String name;
  final String price;
  final Color color;
  final IconData icon;
  final String description;

  const _ApparelProduct({
    required this.name,
    required this.price,
    required this.color,
    required this.icon,
    required this.description,
  });
}
