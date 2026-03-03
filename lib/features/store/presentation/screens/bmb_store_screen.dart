import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/store/data/models/store_models.dart';
import 'package:bmb_mobile/features/store/data/services/store_service.dart';
import 'package:bmb_mobile/features/store/presentation/screens/product_detail_screen.dart';
import 'package:bmb_mobile/features/store/presentation/screens/order_history_screen.dart';
import 'package:bmb_mobile/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:bmb_mobile/features/bmb_bucks/presentation/screens/bmb_bucks_purchase_screen.dart';
import 'package:bmb_mobile/features/payments/data/config/stripe_config.dart';
import 'package:bmb_mobile/features/payments/data/services/stripe_payment_service.dart';
import 'package:bmb_mobile/features/subscription/presentation/screens/bmb_plus_upgrade_screen.dart';
import 'package:bmb_mobile/features/business/presentation/screens/business_signup_screen.dart';

class BmbStoreScreen extends StatefulWidget {
  const BmbStoreScreen({super.key});
  @override
  State<BmbStoreScreen> createState() => _BmbStoreScreenState();
}

class _BmbStoreScreenState extends State<BmbStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _balance = 0;
  int _unreadInbox = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _tabs = ['Featured', 'Memberships', 'BMB Credits', 'Gift Cards', 'Merch', 'Digital', 'Bracket Prints'];
  int? _selectedCreditTier;
  bool _creditProcessing = false;
  bool _isBmbPlus = false;
  bool _isBmbVip = false;
  bool _isBusiness = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadData();
  }

  // Track if user already has memberships

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final unread = await StoreService.instance.getUnreadCount();
    if (!mounted) return;
    // Seed default balance on first access — 50 credits welcome bonus
    if (!prefs.containsKey('bmb_bucks_balance')) {
      await prefs.setDouble('bmb_bucks_balance', 50);
    }
    // FIX #4: Read membership flags from auth — never auto-seed them.
    // The user's actual tier is set during login/signup or via upgrade flow.
    setState(() {
      _balance = prefs.getDouble('bmb_bucks_balance') ?? 50;
      _unreadInbox = unread;
      _isBmbPlus = prefs.getBool('is_bmb_plus') ?? false;
      _isBmbVip = prefs.getBool('is_bmb_vip') ?? false;
      _isBusiness = prefs.getBool('is_business') ?? false;
    });
  }

  List<StoreProduct> _getProducts(int tabIndex) {
    if (_searchQuery.isNotEmpty) {
      return StoreService.instance.search(_searchQuery);
    }
    switch (tabIndex) {
      case 0:
        return StoreService.instance.getFeatured();
      case 1:
        return []; // Memberships — handled separately
      case 2:
        return []; // BMB Credits — handled separately
      case 3:
        return StoreService.instance.getByCategory(StoreCategory.giftCards);
      case 4:
        return StoreService.instance.getByCategory(StoreCategory.merch);
      case 5:
        return StoreService.instance.getByCategory(StoreCategory.digital);
      case 6:
        return StoreService.instance.getByCategory(StoreCategory.customBracket);
      default:
        return [];
    }
  }

  void _openProduct(StoreProduct product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
    _loadData(); // refresh balance
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildBalanceBar(),
              _buildSearchBar(),
              _buildTabBar(),
              Expanded(child: _buildTabContent()),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text('BMB Store',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 20,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
          const Spacer(),
          // Inbox button
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.inbox, color: BmbColors.textSecondary),
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const InboxScreen()));
                  _loadData();
                },
              ),
              if (_unreadInbox > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: BmbColors.errorRed, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$_unreadInbox',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
          // Order history
          IconButton(
            icon: const Icon(Icons.receipt_long, color: BmbColors.textSecondary),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  // ─── BALANCE BAR ────────────────────────────────────────────────
  Widget _buildBalanceBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.12),
          BmbColors.gold.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings, color: BmbColors.gold, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your BMB Bucket',
                  style: TextStyle(
                      color: BmbColors.textTertiary,
                      fontSize: 10,
                      fontWeight: BmbFontWeights.medium)),
              Text('${_balance.toInt()} credits',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 34,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BmbBucksPurchaseScreen()));
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: Text('Add Credits',
                  style: TextStyle(
                      fontSize: 12, fontWeight: BmbFontWeights.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SEARCH BAR ─────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: BmbColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: BmbColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
            prefixIcon: const Icon(Icons.search,
                color: BmbColors.textTertiary, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear,
                        color: BmbColors.textTertiary, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
      ),
    );
  }

  // ─── TAB BAR ────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: BmbColors.gold,
        unselectedLabelColor: BmbColors.textTertiary,
        labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: BmbFontWeights.bold),
        unselectedLabelStyle: TextStyle(
            fontSize: 13,
            fontWeight: BmbFontWeights.medium),
        indicatorColor: BmbColors.gold,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.start,
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
        onTap: (_) => setState(() {}),
      ),
    );
  }

  // ─── TAB CONTENT ────────────────────────────────────────────────
  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: List.generate(_tabs.length, (i) {
        // Memberships tab — special layout, no products
        if (i == 1) return _buildMembershipsTab();
        // BMB Credits tab — inline purchase
        if (i == 2) return _buildCreditsTab();

        final products = _getProducts(i);
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.store,
                    color: BmbColors.textTertiary, size: 48),
                const SizedBox(height: 12),
                Text(
                    _searchQuery.isNotEmpty
                        ? 'No products found'
                        : 'Coming soon',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 14)),
              ],
            ),
          );
        }

        // Featured tab uses a different layout
        if (i == 0) return _buildFeaturedGrid(products);

        // Custom Bracket tab gets a special header
        if (i == 6) return _buildCustomBracketTab(products);

        return _buildProductGrid(products);
      }),
    );
  }

  // ─── BMB CREDITS TAB ───────────────────────────────────────────────
  static const _creditTiers = [
    {'credits': 50, 'price': 5.99, 'label': 'Starter', 'badge': '', 'desc': 'Try a couple brackets — perfect for beginners'},
    {'credits': 100, 'price': 11.99, 'label': 'Popular', 'badge': 'Most Popular', 'desc': 'Enough for several tournaments and a gift card'},
    {'credits': 250, 'price': 29.99, 'label': 'Value', 'badge': '', 'desc': 'Host multiple tournaments or redeem gift cards'},
    {'credits': 500, 'price': 59.99, 'label': 'Pro', 'badge': 'Save 10%', 'desc': 'Serious competitor — enter every bracket'},
    {'credits': 1000, 'price': 119.99, 'label': 'Whale', 'badge': 'Best Value', 'desc': 'Maximum credits, maximum savings'},
  ];

  Future<void> _purchaseCredits(int tierIndex) async {
    setState(() {
      _selectedCreditTier = tierIndex;
      _creditProcessing = true;
    });

    final email = await StripePaymentService.getUserEmail();
    if (!mounted) return;

    await StripePaymentService.checkoutBuxPackage(
      context,
      tierIndex: tierIndex,
      email: email,
    );

    if (!mounted) return;
    setState(() => _creditProcessing = false);
  }

  Widget _buildCreditsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BmbColors.gold.withValues(alpha: 0.18),
                BmbColors.gold.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings, color: BmbColors.gold, size: 30),
              ),
              const SizedBox(height: 10),
              Text('BMB Credits',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 20,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 4),
              Text('Credits power everything — enter tournaments, redeem gift cards, buy merch, and more.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4)),
              const SizedBox(height: 14),
              // Current balance badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: BmbColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Text('Your Balance: ',
                        style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
                    Text('${_balance.toInt()} credits',
                        style: TextStyle(
                            color: BmbColors.gold,
                            fontSize: 15,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section title
        Text('Choose a Credit Tier',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 16,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 4),
        Text('One-time purchase — credits go straight into your BMB Bucket',
            style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
        const SizedBox(height: 14),

        // Tier cards
        ...List.generate(_creditTiers.length, (i) => _buildCreditTierCard(i)),

        const SizedBox(height: 16),

        // Promo code banner — directs to BMB Bucket for full promo UI
        GestureDetector(
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BmbBucksPurchaseScreen()));
            _loadData();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                BmbColors.gold.withValues(alpha: 0.1),
                BmbColors.gold.withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.confirmation_number, color: BmbColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Have a Promo Code?',
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.bold)),
                      Text('Redeem in your BMB Bucket for free credits',
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: BmbColors.textTertiary, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // How credits work section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BmbColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: BmbColors.blue, size: 18),
                  const SizedBox(width: 8),
                  Text('How Credits Work',
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 14,
                          fontWeight: BmbFontWeights.bold)),
                ],
              ),
              const SizedBox(height: 12),
              _creditInfoRow(Icons.emoji_events, 'Enter paid tournaments & brackets'),
              _creditInfoRow(Icons.card_giftcard, 'Redeem for real gift cards (Amazon, Nike, DoorDash...)'),
              _creditInfoRow(Icons.checkroom, 'Buy merch & digital items'),
              _creditInfoRow(Icons.volunteer_activism, 'Donate to charity brackets'),
              _creditInfoRow(Icons.confirmation_number, 'Use promo codes for free credits'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stripe trust badge
        Center(
          child: Container(
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
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _creditInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: BmbColors.gold, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildCreditTierCard(int index) {
    final tier = _creditTiers[index];
    final credits = tier['credits'] as int;
    final price = tier['price'] as double;
    final label = tier['label'] as String;
    final badge = tier['badge'] as String;
    final desc = tier['desc'] as String;
    final hasBadge = badge.isNotEmpty;
    final isBestValue = badge == 'Best Value';
    final isProcessingThis = _creditProcessing && _selectedCreditTier == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isBestValue
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BmbColors.gold.withValues(alpha: 0.15),
                  BmbColors.gold.withValues(alpha: 0.05),
                ],
              )
            : BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBestValue ? BmbColors.gold : BmbColors.borderColor,
          width: isBestValue ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: label + badge + price
          Row(
            children: [
              // Bucket icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.savings, color: BmbColors.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$credits credits',
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 18,
                                fontWeight: BmbFontWeights.bold,
                                fontFamily: 'ClashDisplay')),
                        if (hasBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBestValue
                                  ? BmbColors.gold.withValues(alpha: 0.2)
                                  : BmbColors.successGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(badge,
                                style: TextStyle(
                                    color: isBestValue ? BmbColors.gold : BmbColors.successGreen,
                                    fontSize: 10,
                                    fontWeight: BmbFontWeights.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${price.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: BmbColors.gold,
                          fontSize: 22,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay')),
                  Text('one-time',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Description
          Text(desc,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.3)),
          const SizedBox(height: 12),
          // Buy button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: isProcessingThis ? null : () => _purchaseCredits(index),
              style: ElevatedButton.styleFrom(
                backgroundColor: isBestValue ? BmbColors.gold : BmbColors.cardDark,
                foregroundColor: isBestValue ? Colors.black : BmbColors.gold,
                disabledBackgroundColor: BmbColors.cardDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isBestValue
                      ? BorderSide.none
                      : BorderSide(color: BmbColors.gold.withValues(alpha: 0.4)),
                ),
              ),
              icon: isProcessingThis
                  ? const SizedBox.shrink()
                  : Icon(Icons.payment, size: 16),
              label: isProcessingThis
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: BmbColors.gold))
                  : Text('Buy $credits Credits — \$${price.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MEMBERSHIPS TAB ─────────────────────────────────────────────
  Widget _buildMembershipsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BmbColors.gold.withValues(alpha: 0.15),
                BmbColors.blue.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.workspace_premium, color: BmbColors.gold, size: 36),
              const SizedBox(height: 8),
              Text('BMB Memberships',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 4),
              Text(
                  'Unlock hosting, visibility, and business features with a BMB membership.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ═══ BMB+ INDIVIDUAL ═══
        // If user is BMB+Biz, grey out BMB+ since it’s already included in Biz
        _membershipCard(
          title: 'BMB+',
          subtitle: 'Individual Host',
          icon: Icons.star,
          iconColor: BmbColors.gold,
          gradientColors: [BmbColors.gold.withValues(alpha: _isBusiness ? 0.05 : 0.12), BmbColors.gold.withValues(alpha: _isBusiness ? 0.02 : 0.04)],
          borderColor: BmbColors.gold,
          monthlyPrice: StripeConfig.bmbPlusMonthlyPrice,
          yearlyPrice: StripeConfig.bmbPlusYearlyPrice,
          features: [
            'Save & host brackets',
            'Share with friends',
            'Earn credits from hosting',
            'Unlimited tournaments',
            'Menu item challenges',
            'Premium host badge',
            'Analytics & priority support',
          ],
          isActive: _isBmbPlus && !_isBusiness,
          activeLabel: 'Current Plan',
          isIncludedInOtherPlan: _isBusiness, // BMB+Biz includes BMB+
          includedLabel: 'Included in BMB+biz',
          onMonthly: () async {
            final email = await StripePaymentService.getUserEmail();
            if (!mounted) return;
            await StripePaymentService.checkoutBmbPlus(context, email: email);
          },
          onYearly: () async {
            final email = await StripePaymentService.getUserEmail();
            if (!mounted) return;
            await StripePaymentService.checkoutBmbPlusYearly(context, email: email);
          },
          onLearnMore: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BmbPlusUpgradeScreen()));
          },
        ),
        const SizedBox(height: 16),

        // ═══ BMB+ VIP ADD-ON ═══
        // Available for both BMB+ and BMB+Biz users (Biz already includes BMB+)
        _membershipCard(
          title: 'BMB+ VIP',
          subtitle: 'Priority Placement Add-On',
          icon: Icons.diamond,
          iconColor: const Color(0xFF9C27B0),
          gradientColors: [const Color(0xFF9C27B0).withValues(alpha: 0.12), const Color(0xFF9C27B0).withValues(alpha: 0.04)],
          borderColor: const Color(0xFF9C27B0),
          monthlyPrice: StripeConfig.bmbVipMonthlyPrice,
          yearlyPrice: null, // VIP is monthly only
          features: [
            'Brackets shown first in Featured',
            'Premium glow border on cards',
            '3x more visibility on average',
            'Stacks with Top Host status',
          ],
          isActive: _isBmbVip,
          activeLabel: 'Active',
          requiresBmbPlus: true,
          hasBmbPlus: _isBmbPlus || _isBusiness, // BMB+Biz = already BMB+
          onMonthly: () async {
            final email = await StripePaymentService.getUserEmail();
            if (!mounted) return;
            await StripePaymentService.checkoutBmbVip(context, email: email);
          },
          onYearly: null,
        ),
        const SizedBox(height: 16),

        // ═══ BMB+biz BUSINESS ═══
        _membershipCard(
          title: 'BMB+biz',
          subtitle: 'Bars, Restaurants & Venues',
          icon: Icons.store,
          iconColor: BmbColors.blue,
          gradientColors: [BmbColors.blue.withValues(alpha: 0.12), BmbColors.blue.withValues(alpha: 0.04)],
          borderColor: BmbColors.blue,
          monthlyPrice: StripeConfig.bmbBizMonthlyPrice,
          yearlyPrice: StripeConfig.bmbBizYearlyPrice,
          features: [
            'Everything in BMB+',
            'BMB Starter Kit shipped to you',
            'QR code marketing materials',
            'Business analytics dashboard',
            'Dedicated business support',
            'Multi-location management',
          ],
          isActive: _isBusiness,
          activeLabel: 'Current Plan',
          onMonthly: () async {
            final email = await StripePaymentService.getUserEmail();
            if (!mounted) return;
            await StripePaymentService.checkoutBmbBiz(context, email: email);
          },
          onYearly: () async {
            final email = await StripePaymentService.getUserEmail();
            if (!mounted) return;
            await StripePaymentService.checkoutBmbBizYearly(context, email: email);
          },
          onLearnMore: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BusinessSignupScreen()));
          },
        ),
        const SizedBox(height: 16),

        // Stripe trust badge
        Center(
          child: Container(
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
                Text('All payments securely processed by Stripe',
                    style: TextStyle(color: const Color(0xFF635BFF), fontSize: 11,
                        fontWeight: BmbFontWeights.semiBold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── MEMBERSHIP CARD BUILDER ────────────────────────────────────
  Widget _membershipCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required Color borderColor,
    required double monthlyPrice,
    double? yearlyPrice,
    required List<String> features,
    required bool isActive,
    required String activeLabel,
    bool requiresBmbPlus = false,
    bool hasBmbPlus = true,
    bool isIncludedInOtherPlan = false,
    String? includedLabel,
    required VoidCallback onMonthly,
    VoidCallback? onYearly,
    VoidCallback? onLearnMore,
  }) {
    final annualEquiv = monthlyPrice * 12;
    final savings = yearlyPrice != null ? annualEquiv - yearlyPrice : 0.0;

    // If this plan is already included in another plan, grey everything out
    final effectiveIconColor = isIncludedInOtherPlan ? BmbColors.textTertiary : iconColor;
    final effectiveBorderColor = isIncludedInOtherPlan ? BmbColors.borderColor : borderColor;

    return Opacity(
      opacity: isIncludedInOtherPlan ? 0.6 : 1.0,
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isIncludedInOtherPlan
              ? BmbColors.borderColor
              : isActive ? effectiveBorderColor : effectiveBorderColor.withValues(alpha: 0.3),
          width: isActive && !isIncludedInOtherPlan ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                        color: isIncludedInOtherPlan ? BmbColors.textTertiary : BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                    Text(subtitle, style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // "Included in BMB+biz" badge — shown when greyed out
              if (isIncludedInOtherPlan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: BmbColors.blue, size: 14),
                      const SizedBox(width: 4),
                      Text(includedLabel ?? 'Included', style: TextStyle(
                          color: BmbColors.blue, fontSize: 10,
                          fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                )
              else if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: BmbColors.successGreen, size: 14),
                      const SizedBox(width: 4),
                      Text(activeLabel, style: TextStyle(
                          color: BmbColors.successGreen, fontSize: 11,
                          fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Features list
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.check, color: effectiveIconColor, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 12))),
              ],
            ),
          )),
          const SizedBox(height: 16),

          // If included in another plan — show the greyed-out status
          if (isIncludedInOtherPlan) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.blue.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: BmbColors.blue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All BMB+ features are already included in your BMB+biz plan.',
                      style: TextStyle(color: BmbColors.blue, fontSize: 12,
                          fontWeight: BmbFontWeights.medium),
                    ),
                  ),
                ],
              ),
            ),
          ]
          // Pricing + CTA
          else if (!isActive) ...[
            // Requires BMB+ note
            if (requiresBmbPlus && !hasBmbPlus)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: BmbColors.gold, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Requires an active BMB+ membership',
                        style: TextStyle(color: BmbColors.gold, fontSize: 11))),
                  ],
                ),
              ),

            // Monthly button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: (requiresBmbPlus && !hasBmbPlus) ? null : onMonthly,
                style: ElevatedButton.styleFrom(
                  backgroundColor: effectiveIconColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: BmbColors.cardDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.payment, size: 16),
                label: Text(
                  '\$${monthlyPrice.toStringAsFixed(monthlyPrice == monthlyPrice.roundToDouble() ? 0 : 2)}/mo',
                  style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold),
                ),
              ),
            ),

            // Yearly button (if available)
            if (yearlyPrice != null && onYearly != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: (requiresBmbPlus && !hasBmbPlus) ? null : onYearly,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: effectiveIconColor,
                    side: BorderSide(color: effectiveIconColor.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.calendar_month, size: 16),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${yearlyPrice.toStringAsFixed(yearlyPrice == yearlyPrice.roundToDouble() ? 0 : 2)}/yr',
                        style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: BmbColors.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Save \$${savings.toStringAsFixed(savings == savings.roundToDouble() ? 0 : 2)}',
                          style: TextStyle(color: BmbColors.successGreen, fontSize: 10,
                              fontWeight: BmbFontWeights.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Learn more
            if (onLearnMore != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: onLearnMore,
                  child: Text('Learn More',
                      style: TextStyle(color: effectiveIconColor, fontSize: 12)),
                ),
              ),
            ],
          ] else ...[
            // Already active — show status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: BmbColors.successGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('You\'re subscribed! Manage your plan in Settings.',
                        style: TextStyle(color: BmbColors.successGreen, fontSize: 12,
                            fontWeight: BmbFontWeights.semiBold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  // ─── FEATURED GRID ──────────────────────────────────────────────
  Widget _buildFeaturedGrid(List<StoreProduct> products) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Featured banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BmbColors.blue.withValues(alpha: 0.2),
                BmbColors.gold.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.stars, color: BmbColors.gold, size: 36),
              const SizedBox(height: 8),
              Text('Redeem Your Credits',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 4),
              Text(
                  'Trade your BMB credits for gift cards, merch, digital items, and custom bracket prints.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Featured Products',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 16,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 12),
        ...products.map((p) => _buildProductCard(p)),
      ],
    );
  }

  // ─── CUSTOM BRACKET TAB ─────────────────────────────────────────
  Widget _buildCustomBracketTab(List<StoreProduct> products) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Explanation banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF9C27B0).withValues(alpha: 0.15),
              const Color(0xFF9C27B0).withValues(alpha: 0.05),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.brush, color: Color(0xFF9C27B0), size: 32),
              const SizedBox(height: 8),
              Text('Custom Bracket Products',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 6),
              Text(
                  'Get your individual bracket picks printed on posters, canvases, t-shirts, and mugs. '
                  'Select a completed bracket and we\'ll personalize the product with your picks.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Available Products',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 16,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 12),
        ...products.map((p) => _buildProductCard(p)),
      ],
    );
  }

  // ─── PRODUCT GRID ───────────────────────────────────────────────
  Widget _buildProductGrid(List<StoreProduct> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) => _buildGridCard(products[i]),
    );
  }

  // ─── PRODUCT LIST CARD ──────────────────────────────────────────
  Widget _buildProductCard(StoreProduct product) {
    final canAfford = _balance >= product.creditsCost;
    return GestureDetector(
      onTap: () => _openProduct(product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: product.isFeatured
                ? BmbColors.gold.withValues(alpha: 0.3)
                : BmbColors.borderColor,
            width: product.isFeatured ? 1 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _categoryColor(product.category).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _productIcon(product),
                    color: _categoryColor(product.category),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name,
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 14,
                              fontWeight: BmbFontWeights.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      if (product.brand != null)
                        Text(product.brand!,
                            style: TextStyle(
                                color: BmbColors.textTertiary, fontSize: 11)),
                      if (product.faceValue != null)
                        Text('Value: \$${product.faceValue!.toStringAsFixed(0)}',
                            style: TextStyle(
                                color: BmbColors.successGreen, fontSize: 11)),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${product.creditsCost}',
                        style: TextStyle(
                            color: canAfford ? BmbColors.gold : BmbColors.errorRed,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    Text('credits',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Buy with Credits button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _openProduct(product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford
                      ? _categoryColor(product.category).withValues(alpha: 0.15)
                      : BmbColors.cardDark,
                  foregroundColor: canAfford
                      ? _categoryColor(product.category)
                      : BmbColors.textTertiary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: canAfford
                          ? _categoryColor(product.category).withValues(alpha: 0.3)
                          : BmbColors.borderColor,
                    ),
                  ),
                ),
                icon: Icon(canAfford ? Icons.shopping_cart_checkout : Icons.savings, size: 14),
                label: Text(
                  canAfford
                      ? 'Buy with Credits'
                      : 'Need ${(product.creditsCost - _balance).toInt()} more',
                  style: TextStyle(fontSize: 11, fontWeight: BmbFontWeights.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── GRID CARD ──────────────────────────────────────────────────
  Widget _buildGridCard(StoreProduct product) {
    final canAfford = _balance >= product.creditsCost;
    return GestureDetector(
      onTap: () => _openProduct(product),
      child: Container(
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _categoryColor(product.category).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _productIcon(product),
                color: _categoryColor(product.category),
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(product.name,
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 12,
                      fontWeight: BmbFontWeights.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 4),
            if (product.brand != null)
              Text(product.brand!,
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 10)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (canAfford ? BmbColors.gold : BmbColors.errorRed)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${product.creditsCost} credits',
                  style: TextStyle(
                      color: canAfford ? BmbColors.gold : BmbColors.errorRed,
                      fontSize: 11,
                      fontWeight: BmbFontWeights.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────
  Color _categoryColor(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.giftCards:
        return BmbColors.successGreen;
      case StoreCategory.merch:
        return BmbColors.blue;
      case StoreCategory.digital:
        return const Color(0xFFE040FB);
      case StoreCategory.customBracket:
        return const Color(0xFF9C27B0);
    }
  }

  IconData _productIcon(StoreProduct p) {
    switch (p.imageIcon) {
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'credit_card':
        return Icons.credit_card;
      case 'delivery_dining':
        return Icons.delivery_dining;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'sports_tennis':
        return Icons.sports_tennis;
      case 'fastfood':
        return Icons.fastfood;
      case 'checkroom':
        return Icons.checkroom;
      case 'face':
        return Icons.face;
      case 'dry_cleaning':
        return Icons.dry_cleaning;
      case 'inventory_2':
        return Icons.inventory_2;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'dark_mode':
        return Icons.dark_mode;
      case 'military_tech':
        return Icons.military_tech;
      case 'palette':
        return Icons.palette;
      case 'photo_size_select_large':
        return Icons.photo_size_select_large;
      case 'wallpaper':
        return Icons.wallpaper;
      case 'coffee':
        return Icons.coffee;
      default:
        return Icons.shopping_bag;
    }
  }
}
