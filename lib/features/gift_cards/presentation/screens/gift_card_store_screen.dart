// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/gift_cards/data/models/gift_card_models.dart';
import 'package:bmb_mobile/features/gift_cards/data/services/tremendous_service.dart';
import 'package:bmb_mobile/features/gift_cards/data/services/gift_card_redemption_service.dart';
import 'package:bmb_mobile/features/charity/data/services/charity_escrow_service.dart';

/// BMB Gift Card Store — redeem credits for real gift cards.
///
/// Economy: 1 credit = $0.10 redemption value + $0.50 (5 credits) surcharge.
/// Example: $25 Amazon gift card = 250 + 5 = 255 credits.
///
/// Charity Prize Mode:
///   When opened with [charityOnly] = true and [prizeCredits] set,
///   the store shows ONLY charities and the winner picks where the
///   donation goes. The amount is pre-set from the bracket prize pool.
///
/// Charity Pot Mode ([charityPotMode] = true):
///   Credits come from the bracket pot, NOT the winner's personal balance.
///   The donation amount is pre-set (net of BMB fee) and the winner simply
///   picks which charity receives the donation.
class GiftCardStoreScreen extends StatefulWidget {
  /// If true, only show charity options (used for bracket prize redemption).
  final bool charityOnly;

  /// Pre-set credits for charity prize redemption.
  /// When set, the amount is fixed and comes from the bracket prize pool.
  final int? prizeCredits;

  /// Bracket ID that awarded this charity prize (for tracking).
  final String? bracketId;

  /// Bracket title (for display in confirmation).
  final String? bracketTitle;

  /// If true, credits come from the charity POT, not the winner's personal balance.
  /// The winner never receives credits — the pot is donated directly.
  final bool charityPotMode;

  const GiftCardStoreScreen({
    super.key,
    this.charityOnly = false,
    this.prizeCredits,
    this.bracketId,
    this.bracketTitle,
    this.charityPotMode = false,
  });

  @override
  State<GiftCardStoreScreen> createState() => _GiftCardStoreScreenState();
}

class _GiftCardStoreScreenState extends State<GiftCardStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<GiftCardBrand> _brands = [];
  List<GiftCardOrder> _orders = [];
  bool _loading = true;
  bool _ordersLoading = true;
  String _selectedCategory = 'All';
  double _userBalance = 0;

  final _redemptionService = GiftCardRedemptionService.instance;

  bool get _isCharityPrizeMode =>
      widget.charityOnly && widget.prizeCredits != null && widget.prizeCredits! > 0;

  /// True when the donation is funded by the bracket pot (NOT the winner's balance)
  bool get _isCharityPotMode => _isCharityPrizeMode && widget.charityPotMode;

  /// The dollar value of the prize credits (for display).
  double get _prizeAmount => (widget.prizeCredits ?? 0) * 0.10;

  @override
  void initState() {
    super.initState();
    // In charity-only mode, no Orders tab needed
    _tabController = TabController(
      length: widget.charityOnly ? 1 : 2,
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final balance = await _redemptionService.getUserBalance();
    final brands = TremendousService.instance.getCuratedBrands(
      charityOnly: widget.charityOnly,
    );
    final orders = widget.charityOnly
        ? <GiftCardOrder>[]
        : await _redemptionService.getOrderHistory();
    if (mounted) {
      setState(() {
        _userBalance = balance;
        _brands = brands;
        _orders = orders;
        _loading = false;
        _ordersLoading = false;
      });
    }
  }

  List<GiftCardBrand> get _filteredBrands {
    if (widget.charityOnly) return _brands; // All are charities
    if (_selectedCategory == 'All') return _brands;
    if (_selectedCategory == 'Popular') {
      return _brands.where((b) => b.isPopular).toList();
    }
    if (_selectedCategory == 'Charity') {
      return _brands.where((b) => b.isCharity).toList();
    }
    return _brands.where((b) => b.category == _selectedCategory).toList();
  }

  // ═════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildBalanceCard(),
              if (_isCharityPrizeMode) _buildCharityPrizeBanner(),
              if (!widget.charityOnly) _buildTabs(),
              Expanded(
                child: widget.charityOnly
                    ? _buildStoreTab()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStoreTab(),
                          _buildOrdersTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // HEADER
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final isCharity = widget.charityOnly;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isCharity ? 'Choose a Charity' : 'Gift Card Store',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 20,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Text(
                    isCharity
                        ? 'Pick where your prize donation goes'
                        : 'Redeem your credits for real rewards',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isCharity ? BmbColors.successGreen : BmbColors.gold)
                      .withValues(alpha: 0.2),
                  (isCharity ? BmbColors.successGreen : BmbColors.gold)
                      .withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
                isCharity ? Icons.volunteer_activism : Icons.card_giftcard,
                color: isCharity ? BmbColors.successGreen : BmbColors.gold,
                size: 24),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // CHARITY PRIZE BANNER — shown when winner is choosing charity
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildCharityPrizeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BmbColors.successGreen.withValues(alpha: 0.15),
            BmbColors.successGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BmbColors.successGreen.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events,
                color: BmbColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('You Won! ',
                        style: TextStyle(
                            color: BmbColors.successGreen,
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                    if (widget.bracketTitle != null)
                      Expanded(
                        child: Text(widget.bracketTitle!,
                            style: TextStyle(
                                color: BmbColors.textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    'Choose a charity below to donate your ${widget.prizeCredits} won credits (\$${_prizeAmount.toStringAsFixed(2)})',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // BALANCE CARD
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BmbColors.gold.withValues(alpha: 0.15),
            BmbColors.gold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: BmbColors.gold, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your BMB Bucket',
                    style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                Text('${_userBalance.toInt()} credits',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 22,
                        fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Redeemable Value',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
              Text('\$${(_userBalance * 0.10).toStringAsFixed(2)}',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.semiBold)),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // TABS
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: BmbColors.gold.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
        ),
        labelColor: BmbColors.gold,
        unselectedLabelColor: BmbColors.textTertiary,
        labelStyle: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 13),
        unselectedLabelStyle:
            TextStyle(fontWeight: BmbFontWeights.medium, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront, size: 16),
                const SizedBox(width: 6),
                const Text('Browse'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 16),
                const SizedBox(width: 6),
                Text('My Cards${_orders.isNotEmpty ? ' (${_orders.length})' : ''}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // STORE TAB
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildStoreTab() {
    return Column(
      children: [
        const SizedBox(height: 8),
        if (!widget.charityOnly) _buildCategoryFilter(),
        if (!widget.charityOnly) const SizedBox(height: 4),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: BmbColors.gold))
              : _buildBrandGrid(),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      'All',
      'Popular',
      'Food & Dining',
      'Shopping',
      'Entertainment',
      'Charity',
    ];
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          final sel = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? BmbColors.gold.withValues(alpha: 0.2)
                    : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? BmbColors.gold : BmbColors.borderColor,
                  width: sel ? 1.5 : 0.5,
                ),
              ),
              child: Text(cat,
                  style: TextStyle(
                    color: sel ? BmbColors.gold : BmbColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        sel ? BmbFontWeights.bold : BmbFontWeights.medium,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrandGrid() {
    final brands = _filteredBrands;
    if (brands.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: BmbColors.textTertiary, size: 48),
            const SizedBox(height: 8),
            Text('No gift cards in this category',
                style: TextStyle(color: BmbColors.textTertiary)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: brands.length,
      itemBuilder: (ctx, i) => _buildBrandCard(brands[i]),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // BRAND CARD — with real logos
  // ═════════════════════════════════════════════════════════════════════

  /// Map brand IDs to their official brand colors for card accents.
  static const Map<String, Color> _brandColors = {
    'OKMHM2X2OHYV': Color(0xFFFF9900),   // Amazon
    'A2J05SWPI2QG': Color(0xFF1A1F71),    // Visa
    '9OEIQ5EWBWT9': Color(0xFFFF3008),    // DoorDash
    '2XG0FLQXBDCZ': Color(0xFF00704A),    // Starbucks
    'SRDHFATO9KHN': Color(0xFFCC0000),    // Target
    'DC82VBYLI4CC': Color(0xFF555555),     // Apple
    'HOPB2V9UY5BH': Color(0xFF06C167),    // Uber Eats
    'FGXZUYWP4FII': Color(0xFFFA5400),    // Nike
    'CRN0ID07Y2XD': Color(0xFF441500),    // Chipotle
    '46I7B4VZAFES': Color(0xFF003DA5),    // Fanatics
  };

  /// Map brand IDs to icon data for fallback when logo image fails.
  static const Map<String, IconData> _brandIcons = {
    'OKMHM2X2OHYV': Icons.shopping_cart,     // Amazon
    'A2J05SWPI2QG': Icons.credit_card,        // Visa
    '9OEIQ5EWBWT9': Icons.delivery_dining,    // DoorDash
    '2XG0FLQXBDCZ': Icons.local_cafe,         // Starbucks
    'SRDHFATO9KHN': Icons.gps_fixed,           // Target
    'DC82VBYLI4CC': Icons.apple,               // Apple
    'HOPB2V9UY5BH': Icons.fastfood,            // Uber Eats
    'FGXZUYWP4FII': Icons.directions_run,      // Nike
    'CRN0ID07Y2XD': Icons.lunch_dining,        // Chipotle
    '46I7B4VZAFES': Icons.sports_basketball,   // Fanatics
  };

  Color _getAccentColor(GiftCardBrand brand) {
    if (brand.isCharity) return BmbColors.successGreen;
    return _brandColors[brand.id] ?? BmbColors.gold;
  }

  IconData _getIcon(GiftCardBrand brand) {
    if (brand.isCharity) return Icons.volunteer_activism;
    return _brandIcons[brand.id] ?? Icons.card_giftcard;
  }

  Widget _buildBrandCard(GiftCardBrand brand) {
    final isCharity = brand.isCharity;
    final brandColor = _getAccentColor(brand);
    final brandIcon = _getIcon(brand);

    final minCredits = brand.creditsForAmount(brand.denominations.first);
    final canAfford = _userBalance >= minCredits;

    final costLabel = 'From $minCredits cr (\$${brand.denominations.first.toStringAsFixed(0)})';

    return GestureDetector(
      onTap: () => _showRedeemSheet(brand),
      child: Container(
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand logo area
            Container(
              height: 85,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    brandColor.withValues(alpha: 0.15),
                    brandColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Stack(
                children: [
                  // Brand logo (from network)
                  Center(
                    child: brand.imageUrl.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.network(
                              brand.imageUrl,
                              height: 52,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => _brandFallback(brand, brandColor, brandIcon),
                            ),
                          )
                        : _brandFallback(brand, brandColor, brandIcon),
                  ),
                  // Popular / Charity badge
                  if (brand.isPopular || isCharity)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCharity ? BmbColors.successGreen : BmbColors.gold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                            isCharity ? 'CHARITY' : 'POPULAR',
                            style: TextStyle(
                                color: isCharity ? Colors.white : Colors.black,
                                fontSize: 7,
                                fontWeight: BmbFontWeights.bold)),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand.name,
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 13,
                            fontWeight: BmbFontWeights.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(brand.description,
                        style: TextStyle(
                            color: BmbColors.textSecondary, fontSize: 10),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          canAfford
                              ? (isCharity ? Icons.volunteer_activism : Icons.check_circle_outline)
                              : Icons.lock_outline,
                          size: 12,
                          color: canAfford
                              ? (isCharity ? BmbColors.successGreen : BmbColors.successGreen)
                              : BmbColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            costLabel,
                            style: TextStyle(
                              color: canAfford
                                  ? BmbColors.successGreen
                                  : BmbColors.textTertiary,
                              fontSize: 10,
                              fontWeight: BmbFontWeights.semiBold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandFallback(
      GiftCardBrand brand, Color brandColor, IconData brandIcon) {
    return Icon(brandIcon, size: 40, color: brandColor);
  }

  // ═════════════════════════════════════════════════════════════════════
  // REDEEM BOTTOM SHEET (used for both gift cards and charity donations)
  // ═════════════════════════════════════════════════════════════════════

  void _showRedeemSheet(GiftCardBrand brand) {
    // ─── "Let BMB Choose" special flow ─────────────────────────────────
    if (brand.id == 'BMB_CHOOSE' && _isCharityPotMode) {
      _showLetBmbChooseConfirmation();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.deepNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RedeemSheet(
        brand: brand,
        userBalance: _userBalance,
        brandColor: _getAccentColor(brand),
        brandIcon: _getIcon(brand),
        onRedeem: (amount) => _processRedemption(brand, amount),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // "LET BMB CHOOSE" CONFIRMATION — routes through CharityEscrowService
  // ═════════════════════════════════════════════════════════════════════

  void _showLetBmbChooseConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volunteer_activism,
                  color: BmbColors.successGreen, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Let BMB Choose',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 17,
                      fontWeight: BmbFontWeights.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The BMB team will select a worthy charity on your behalf.',
              style: TextStyle(
                  color: BmbColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: BmbColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings, color: BmbColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '\$${_prizeAmount.toStringAsFixed(2)} donation',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 15,
                        fontWeight: BmbFontWeights.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The full donation amount stays charitable \u2014 100% will be donated.',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: BmbColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.bracketId != null) {
                await CharityEscrowService.instance
                    .letBmbChoose(widget.bracketId!);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text(
                      'Thank you! BMB will choose a charity on your behalf.'),
                  backgroundColor: BmbColors.successGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
                Navigator.pop(context); // Close the store
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.successGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Confirm',
                style: TextStyle(fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processRedemption(
      GiftCardBrand brand, double amount) async {
    try {
      final order = await _redemptionService.redeem(
        brand: brand,
        amount: amount,
      );

      if (!mounted) return;

      if (order != null) {
        // Refresh balance and orders
        final newBal = await _redemptionService.getUserBalance();
        final newOrders = await _redemptionService.getOrderHistory();
        setState(() {
          _userBalance = newBal;
          _orders = newOrders;
        });

        if (!mounted) return; // BUG #12 FIX
        Navigator.pop(context); // Close bottom sheet
        _showSuccessDialog(order);
      } else {
        if (!mounted) return; // BUG #12 FIX
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order failed. Credits have been refunded.'),
          backgroundColor: Colors.red,
        ));
      }
    } on InsufficientCreditsException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Something went wrong: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // SUCCESS DIALOG
  // ═════════════════════════════════════════════════════════════════════

  void _showSuccessDialog(GiftCardOrder order) {
    // Determine if this was a charity donation
    final isCharityOrder = _brands
        .where((b) => b.id == order.brandId)
        .any((b) => b.isCharity);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.deepNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isCharityOrder ? BmbColors.successGreen : BmbColors.successGreen)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    isCharityOrder ? Icons.volunteer_activism : Icons.celebration,
                    color: BmbColors.successGreen, size: 40),
              ),
              const SizedBox(height: 16),
              Text(isCharityOrder ? 'Donation Made!' : 'Gift Card Delivered!',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 20,
                      fontWeight: BmbFontWeights.bold)),
              const SizedBox(height: 8),
              Text(
                  isCharityOrder
                      ? '\$${order.faceValue.toStringAsFixed(0)} donated to ${order.brandName}'
                      : '${order.brandName} \$${order.faceValue.toStringAsFixed(0)} Gift Card',
                  style: TextStyle(
                      color: isCharityOrder ? BmbColors.successGreen : BmbColors.gold,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.semiBold),
                  textAlign: TextAlign.center),
              if (isCharityOrder && widget.bracketTitle != null) ...[
                const SizedBox(height: 6),
                Text('On behalf of ${widget.bracketTitle}',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 12,
                        fontWeight: BmbFontWeights.semiBold),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              if (order.redemptionUrl != null) ...[
                Text(isCharityOrder ? 'Donation Receipt' : 'Your Redemption Link',
                    style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: order.redemptionUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Link copied to clipboard!'),
                      backgroundColor: BmbColors.successGreen,
                      duration: Duration(seconds: 2),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link, color: BmbColors.gold, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('Tap to copy redemption link',
                              style: TextStyle(
                                  color: BmbColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: BmbFontWeights.semiBold)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.copy, color: BmbColors.gold, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Tap to copy',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 10)),
              ] else if (order.redemptionCode != null) ...[
                Text('Your Redemption Code',
                    style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: order.redemptionCode!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Code copied to clipboard!'),
                      backgroundColor: BmbColors.successGreen,
                      duration: Duration(seconds: 2),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(order.redemptionCode!,
                              style: TextStyle(
                                  color: BmbColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: BmbFontWeights.bold,
                                  fontFamily: 'monospace',
                                  letterSpacing: 1.5)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.copy, color: BmbColors.gold, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Tap to copy',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 10)),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        color: BmbColors.textTertiary, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                          isCharityOrder
                              ? '${order.creditsSpent} credits used for this donation'
                              : '${order.creditsSpent} credits deducted (incl. \$0.50 fee)',
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    // In charity prize mode, also close the store to go back to bracket
                    if (_isCharityPrizeMode && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCharityOrder ? BmbColors.successGreen : BmbColors.gold,
                    foregroundColor: isCharityOrder ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isCharityOrder ? 'Done' : 'Awesome!',
                      style: TextStyle(
                          fontWeight: BmbFontWeights.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // ORDERS TAB
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildOrdersTab() {
    if (_ordersLoading) {
      return const Center(
          child: CircularProgressIndicator(color: BmbColors.gold));
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard,
                color: BmbColors.textTertiary.withValues(alpha: 0.5), size: 64),
            const SizedBox(height: 12),
            Text("No gift cards yet",
                style: TextStyle(
                    color: BmbColors.textSecondary,
                    fontSize: 16,
                    fontWeight: BmbFontWeights.semiBold)),
            const SizedBox(height: 4),
            Text("Redeem your credits to get started!",
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.storefront, size: 18),
              label: const Text('Browse Gift Cards'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: _orders.length,
      itemBuilder: (ctx, i) => _buildOrderCard(_orders[i]),
    );
  }

  Widget _buildOrderCard(GiftCardOrder order) {
    final brandColor = _brandColors[order.brandId] ?? BmbColors.gold;
    final brandIcon = _brandIcons[order.brandId] ?? Icons.card_giftcard;

    final isDelivered = order.status == 'delivered' || order.status == 'succeeded';
    final statusColor = isDelivered
        ? BmbColors.successGreen
        : order.status == 'failed'
            ? BmbColors.errorRed
            : BmbColors.gold;
    final statusText = order.status[0].toUpperCase() + order.status.substring(1);

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
          onTap: (order.redemptionCode != null || order.redemptionUrl != null)
              ? () => _showOrderDetail(order)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Brand icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(brandIcon, color: brandColor, size: 24),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(order.brandName,
                              style: TextStyle(
                                  color: BmbColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: BmbFontWeights.bold)),
                          const Spacer(),
                          Text('\$${order.faceValue.toStringAsFixed(0)}',
                              style: TextStyle(
                                  color: BmbColors.gold,
                                  fontSize: 16,
                                  fontWeight: BmbFontWeights.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(statusText,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: BmbFontWeights.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('${order.creditsSpent} credits',
                              style: TextStyle(
                                  color: BmbColors.textTertiary,
                                  fontSize: 11)),
                          const Spacer(),
                          Text(_formatDate(order.createdAt),
                              style: TextStyle(
                                  color: BmbColors.textTertiary,
                                  fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (order.redemptionCode != null || order.redemptionUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.chevron_right,
                        color: BmbColors.textTertiary, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetail(GiftCardOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.deepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BmbColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.card_giftcard,
                color: _brandColors[order.brandId] ?? BmbColors.gold,
                size: 40),
            const SizedBox(height: 12),
            Text(
                '${order.brandName} \$${order.faceValue.toStringAsFixed(0)} Gift Card',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold)),
            const SizedBox(height: 16),
            if (order.redemptionUrl != null) ...[
              Text('Redemption Link',
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: order.redemptionUrl!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Link copied!'),
                    backgroundColor: BmbColors.successGreen,
                    duration: Duration(seconds: 2),
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: BmbColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, color: BmbColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('Tap to copy link',
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 14,
                                fontWeight: BmbFontWeights.semiBold)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.copy, color: BmbColors.gold, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Tap to copy',
                  style:
                      TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
            ] else if (order.redemptionCode != null) ...[
              Text('Redemption Code',
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: order.redemptionCode!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Code copied!'),
                    backgroundColor: BmbColors.successGreen,
                    duration: Duration(seconds: 2),
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: BmbColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(order.redemptionCode!,
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 18,
                                fontWeight: BmbFontWeights.bold,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.copy, color: BmbColors.gold, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Tap to copy',
                  style:
                      TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
            ],
            const SizedBox(height: 16),
            _detailRow('Status', order.status.toUpperCase()),
            _detailRow('Credits Spent', '${order.creditsSpent}'),
            _detailRow('Date', _formatDate(order.createdAt)),
            _detailRow('Order ID', order.orderId),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Done',
                    style: TextStyle(fontWeight: BmbFontWeights.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          Flexible(
            child: Text(value,
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 12,
                    fontWeight: BmbFontWeights.semiBold),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// REDEEM BOTTOM SHEET — denomination picker + confirmation
// ═══════════════════════════════════════════════════════════════════════

class _RedeemSheet extends StatefulWidget {
  final GiftCardBrand brand;
  final double userBalance;
  final Color brandColor;
  final IconData brandIcon;
  final Future<void> Function(double amount) onRedeem;

  const _RedeemSheet({
    required this.brand,
    required this.userBalance,
    required this.brandColor,
    required this.brandIcon,
    required this.onRedeem,
  });

  @override
  State<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends State<_RedeemSheet> {
  int _selectedDenomIdx = 0;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final brand = widget.brand;
    final amount = brand.denominations[_selectedDenomIdx];
    final credits = brand.creditsForAmount(amount);
    final canAfford = widget.userBalance >= credits;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BmbColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Brand header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.brandColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: brand.imageUrl.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.network(brand.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                Icon(widget.brandIcon,
                                    color: widget.brandColor, size: 24)),
                      )
                    : Icon(widget.brandIcon,
                        color: widget.brandColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand.name,
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 20,
                            fontWeight: BmbFontWeights.bold)),
                    Text(brand.description,
                        style: TextStyle(
                            color: BmbColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Denomination picker
          Text('Select Amount',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 14,
                  fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(brand.denominations.length, (i) {
              final d = brand.denominations[i];
              final sel = _selectedDenomIdx == i;
              final creds = brand.creditsForAmount(d);
              final affordable = widget.userBalance >= creds;
              return GestureDetector(
                onTap: () => setState(() => _selectedDenomIdx = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? widget.brandColor.withValues(alpha: 0.2)
                        : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? widget.brandColor
                          : BmbColors.borderColor,
                      width: sel ? 2 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('\$${d.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: affordable
                                ? BmbColors.textPrimary
                                : BmbColors.textTertiary,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                          )),
                      const SizedBox(height: 2),
                      Text('$creds cr',
                          style: TextStyle(
                            color: affordable
                                ? BmbColors.textSecondary
                                : BmbColors.textTertiary,
                            fontSize: 10,
                          )),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Cost summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BmbColors.cardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.borderColor),
            ),
            child: Column(
              children: [
                _summaryRow(
                    brand.isCharity ? 'Donation Amount' : 'Gift Card Value',
                    '\$${amount.toStringAsFixed(0)}'),
                _summaryRow('Credits Required', '${credits - 5}'),
                _summaryRow('Processing Fee', '5 credits (\$0.50)'),
                const Divider(color: BmbColors.borderColor, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                    Text('$credits credits',
                        style: TextStyle(
                            color: BmbColors.gold,
                            fontSize: 16,
                            fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Redeem button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (canAfford && !_processing)
                  ? () async {
                      setState(() => _processing = true);
                      await widget.onRedeem(amount);
                      if (mounted) setState(() => _processing = false);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford
                    ? (brand.isCharity ? BmbColors.successGreen : BmbColors.gold)
                    : BmbColors.cardDark,
                foregroundColor: brand.isCharity ? Colors.white : Colors.black,
                disabledBackgroundColor:
                    BmbColors.textTertiary.withValues(alpha: 0.2),
                disabledForegroundColor: BmbColors.textTertiary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _processing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(canAfford
                            ? (brand.isCharity ? Icons.volunteer_activism : Icons.card_giftcard)
                            : Icons.lock,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          canAfford
                              ? (brand.isCharity
                                  ? 'Donate for $credits Credits'
                                  : 'Redeem for $credits Credits')
                              : 'Need $credits credits (have ${widget.userBalance.toInt()})',
                          style: TextStyle(
                              fontWeight: BmbFontWeights.bold, fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 12,
                  fontWeight: BmbFontWeights.semiBold)),
        ],
      ),
    );
  }
}
