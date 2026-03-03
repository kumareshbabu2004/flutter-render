import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/shopify/data/services/shopify_service.dart';

/// Product browser screen — shows all Shopify products with category filters.
/// User selects a product, then proceeds to picks visual + review + checkout.
class ShopifyProductBrowserScreen extends StatefulWidget {
  /// If provided, bracket context is used for custom print products.
  final String? bracketId;
  final String? bracketName;
  final List<String>? picks;

  const ShopifyProductBrowserScreen({
    super.key,
    this.bracketId,
    this.bracketName,
    this.picks,
  });

  @override
  State<ShopifyProductBrowserScreen> createState() => _ShopifyProductBrowserScreenState();
}

class _ShopifyProductBrowserScreenState extends State<ShopifyProductBrowserScreen> {
  List<ShopifyProduct> _products = [];
  List<String> _categories = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final cats = await ShopifyService.fetchCategories();
      final prods = await ShopifyService.fetchProducts();
      if (mounted) {
        setState(() {
          _categories = cats;
          _products = prods;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _isLoading = false; });
    }
  }

  Future<void> _filterByCategory(String cat) async {
    setState(() { _selectedCategory = cat; _isLoading = true; });
    final prods = await ShopifyService.fetchProducts(category: cat);
    if (mounted) setState(() { _products = prods; _isLoading = false; });
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
              _buildCategoryChips(),
              if (widget.bracketName != null) _buildBracketContext(),
              Expanded(child: _buildProductGrid()),
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
          IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.shopping_bag, color: BmbColors.gold, size: 20),
                const SizedBox(width: 6),
                Text('BMB Shop', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              ]),
              Text(ShopifyService.isLinked
                  ? 'Powered by ${ShopifyService.storeInfo?.name ?? "Shopify"}'
                  : 'Browse custom bracket products',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
            ]),
          ),
          // Cart badge
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: BmbColors.textSecondary),
              onPressed: () {}, // TODO: cart screen
            ),
            if (ShopifyService.orders.isNotEmpty)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: BmbColors.errorRed, shape: BoxShape.circle),
                  child: Center(child: Text('${ShopifyService.orders.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 0, 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          padding: const EdgeInsets.only(right: 20),
          itemBuilder: (_, i) {
            final cat = _categories[i];
            final sel = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => _filterByCategory(cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? BmbColors.gold : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? BmbColors.gold : BmbColors.borderColor),
                ),
                child: Text(cat, style: TextStyle(
                  color: sel ? Colors.black : BmbColors.textPrimary,
                  fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal,
                  fontSize: 12,
                )),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBracketContext() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BmbColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.account_tree, color: BmbColors.blue, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Shopping for: ${widget.bracketName}',
          style: TextStyle(color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.semiBold),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: BmbColors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('${widget.picks?.length ?? 0} picks', style: TextStyle(color: BmbColors.blue, fontSize: 9, fontWeight: BmbFontWeights.bold)),
        ),
      ]),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: BmbColors.gold));
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: TextStyle(color: BmbColors.errorRed)));
    }
    if (_products.isEmpty) {
      return Center(child: Text('No products found', style: TextStyle(color: BmbColors.textTertiary)));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _products.length,
      itemBuilder: (_, i) => _buildProductCard(_products[i]),
    );
  }

  Widget _buildProductCard(ShopifyProduct product) {
    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: Container(
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                    child: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                            child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(product)),
                          )
                        : _imagePlaceholder(product),
                  ),
                  // Sale badge
                  if (product.onSale)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: BmbColors.errorRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('SAVE ${product.savingsPercent}%',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  // Custom print badge
                  if (product.supportsCustomPrint)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: BmbColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.brush, color: Colors.black, size: 10),
                          const SizedBox(width: 3),
                          Text('CUSTOM', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: BmbFontWeights.bold)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title,
                        style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(children: [
                      Text('\$${product.price.toStringAsFixed(2)}',
                          style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                      if (product.onSale) ...[
                        const SizedBox(width: 6),
                        Text('\$${product.compareAtPrice!.toStringAsFixed(2)}',
                            style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, decoration: TextDecoration.lineThrough)),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(product.category, style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(ShopifyProduct product) {
    return Center(
      child: Icon(
        product.category == 'Headwear' ? Icons.face
            : product.category == 'Accessories' ? Icons.watch
            : product.category == 'Gift Cards' ? Icons.card_giftcard
            : Icons.checkroom,
        color: BmbColors.textTertiary, size: 40,
      ),
    );
  }

  void _openProductDetail(ShopifyProduct product) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ShopifyProductDetailScreen(
        product: product,
        bracketId: widget.bracketId,
        bracketName: widget.bracketName,
        picks: widget.picks,
      ),
    ));
  }
}

// ─── PRODUCT DETAIL SCREEN ──────────────────────────────────────
class ShopifyProductDetailScreen extends StatefulWidget {
  final ShopifyProduct product;
  final String? bracketId;
  final String? bracketName;
  final List<String>? picks;

  const ShopifyProductDetailScreen({
    super.key,
    required this.product,
    this.bracketId,
    this.bracketName,
    this.picks,
  });

  @override
  State<ShopifyProductDetailScreen> createState() => _ShopifyProductDetailScreenState();
}

class _ShopifyProductDetailScreenState extends State<ShopifyProductDetailScreen> {
  String? _selectedVariant;
  bool _showMockup = false;
  BracketPicksVisual? _mockupVisual;
  bool _generatingMockup = false;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) {
      _selectedVariant = widget.product.variants.first;
    }
  }

  Future<void> _generateMockup() async {
    if (widget.picks == null || widget.bracketName == null) return;
    setState(() => _generatingMockup = true);
    final visual = await ShopifyService.generatePicksVisual(
      productId: widget.product.id,
      bracketName: widget.bracketName!,
      picks: widget.picks!,
      hostName: 'You',
    );
    if (mounted) {
      setState(() {
        _mockupVisual = visual;
        _showMockup = true;
        _generatingMockup = false;
      });
    }
  }

  void _proceedToReview() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ShopifyReviewApprovalScreen(
        product: widget.product,
        selectedVariant: _selectedVariant,
        bracketId: widget.bracketId,
        bracketName: widget.bracketName,
        picks: widget.picks,
        mockupVisual: _mockupVisual,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final hasBracketContext = widget.bracketName != null && widget.picks != null;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  Expanded(child: Text(p.title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Product image / mockup toggle
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey.withValues(alpha: 0.1),
                        border: Border.all(color: BmbColors.borderColor, width: 0.5),
                      ),
                      child: Stack(children: [
                        if (p.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _showMockup && _mockupVisual?.mockupImageUrl != null
                                  ? _mockupVisual!.mockupImageUrl!
                                  : p.imageUrl!,
                              width: double.infinity, height: 280, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(child: Icon(Icons.image, color: BmbColors.textTertiary, size: 60)),
                            ),
                          ),
                        // Mockup overlay indicator
                        if (_showMockup && _mockupVisual != null)
                          Positioned(
                            bottom: 12, left: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: BmbColors.deepNavy.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: BmbColors.gold.withValues(alpha: 0.5)),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Icon(Icons.brush, color: BmbColors.gold, size: 14),
                                  const SizedBox(width: 6),
                                  Text('YOUR BRACKET PICKS', style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
                                ]),
                                const SizedBox(height: 6),
                                Text(widget.bracketName ?? '', style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4, runSpacing: 4,
                                  children: (widget.picks ?? []).take(6).map((pick) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: BmbColors.blue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(pick, style: TextStyle(color: BmbColors.blue, fontSize: 8)),
                                  )).toList(),
                                ),
                                if ((widget.picks?.length ?? 0) > 6)
                                  Text('+${widget.picks!.length - 6} more picks', style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    // Price row
                    Row(children: [
                      Text('\$${p.price.toStringAsFixed(2)}', style: TextStyle(color: BmbColors.gold, fontSize: 24, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                      if (p.onSale) ...[
                        const SizedBox(width: 10),
                        Text('\$${p.compareAtPrice!.toStringAsFixed(2)}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 14, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: BmbColors.errorRed, borderRadius: BorderRadius.circular(4)),
                          child: Text('SAVE ${p.savingsPercent}%', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    Text(p.description, style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5)),
                    const SizedBox(height: 20),
                    // Variant selector
                    if (p.variants.length > 1) ...[
                      Text('Size', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: p.variants.map((v) {
                        final sel = _selectedVariant == v;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedVariant = v),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? BmbColors.blue : BmbColors.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: sel ? BmbColors.blue : BmbColors.borderColor),
                            ),
                            child: Text(v, style: TextStyle(
                              color: sel ? Colors.white : BmbColors.textPrimary,
                              fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal,
                              fontSize: 13,
                            )),
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 20),
                    ],
                    // Custom print info
                    if (p.supportsCustomPrint) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BmbColors.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.brush, color: BmbColors.gold, size: 18),
                            const SizedBox(width: 8),
                            Text('Custom Bracket Print', style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                          ]),
                          const SizedBox(height: 6),
                          Text('Your bracket picks will be printed on the ${p.printArea?.toLowerCase() ?? "product"}. Preview the mockup before ordering!',
                              style: TextStyle(color: BmbColors.gold.withValues(alpha: 0.8), fontSize: 11, height: 1.4)),
                          if (hasBracketContext && !_showMockup) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _generatingMockup ? null : _generateMockup,
                                icon: _generatingMockup
                                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                    : const Icon(Icons.preview, size: 16),
                                label: Text(_generatingMockup ? 'Generating...' : 'Preview with My Picks'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BmbColors.gold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                          if (_showMockup) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              Icon(Icons.check_circle, color: BmbColors.successGreen, size: 14),
                              const SizedBox(width: 6),
                              Text('Mockup preview loaded above', style: TextStyle(color: BmbColors.successGreen, fontSize: 11)),
                            ]),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ]),
                ),
              ),
              // Bottom CTA
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: BmbColors.deepNavy.withValues(alpha: 0.9),
                  border: Border(top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _proceedToReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.shopping_cart, size: 18),
                      const SizedBox(width: 8),
                      Text(hasBracketContext ? 'Continue to Review' : 'Add to Cart — \$${p.price.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── REVIEW & APPROVAL SCREEN ───────────────────────────────────
class ShopifyReviewApprovalScreen extends StatefulWidget {
  final ShopifyProduct product;
  final String? selectedVariant;
  final String? bracketId;
  final String? bracketName;
  final List<String>? picks;
  final BracketPicksVisual? mockupVisual;

  const ShopifyReviewApprovalScreen({
    super.key,
    required this.product,
    this.selectedVariant,
    this.bracketId,
    this.bracketName,
    this.picks,
    this.mockupVisual,
  });

  @override
  State<ShopifyReviewApprovalScreen> createState() => _ShopifyReviewApprovalScreenState();
}

class _ShopifyReviewApprovalScreenState extends State<ShopifyReviewApprovalScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _address1Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _approved = false;
  bool _creatingOrder = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _address1Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _formValid =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().isNotEmpty &&
      _address1Ctrl.text.trim().isNotEmpty &&
      _cityCtrl.text.trim().isNotEmpty &&
      _stateCtrl.text.trim().isNotEmpty &&
      _zipCtrl.text.trim().isNotEmpty;

  Future<void> _createAndCheckout() async {
    if (!_formValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fill in all required shipping fields'),
        backgroundColor: BmbColors.errorRed, behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _creatingOrder = true);

    final result = await ShopifyService.createOrder(
      productId: widget.product.id,
      bracketId: widget.bracketId ?? 'no_bracket',
      bracketName: widget.bracketName ?? 'Direct Purchase',
      picks: widget.picks ?? [],
      customerName: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
      customerEmail: _emailCtrl.text.trim(),
      shippingAddress: ShopifyShippingAddress(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        address1: _address1Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        zip: _zipCtrl.text.trim(),
      ),
      customizationNotes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );

    if (!mounted) return;

    if (result.success && result.order != null) {
      // Auto-approve and proceed to checkout
      await ShopifyService.approveOrder(result.order!.id);
      setState(() {
        _creatingOrder = false;
      });
      // Navigate to in-app checkout
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ShopifyCheckoutScreen(order: result.order!),
        ));
      }
    } else {
      setState(() => _creatingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: BmbColors.errorRed, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  Expanded(child: Text('Review & Checkout', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'))),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ORDER SUMMARY
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: BmbColors.cardGradient,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: BmbColors.borderColor, width: 0.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                          child: p.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(p.imageUrl!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.checkroom, color: BmbColors.textTertiary)),
                                )
                              : const Icon(Icons.checkroom, color: BmbColors.textTertiary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                          if (widget.selectedVariant != null)
                            Text('Size: ${widget.selectedVariant}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                          if (widget.bracketName != null)
                            Text('Bracket: ${widget.bracketName}', style: TextStyle(color: BmbColors.blue, fontSize: 11)),
                        ])),
                        Text('\$${p.price.toStringAsFixed(2)}', style: TextStyle(color: BmbColors.gold, fontSize: 18, fontWeight: BmbFontWeights.bold)),
                      ]),
                    ),

                    // Bracket picks preview (if custom print)
                    if (widget.picks != null && widget.picks!.isNotEmpty && p.supportsCustomPrint) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: BmbColors.gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.brush, color: BmbColors.gold, size: 16),
                            const SizedBox(width: 8),
                            Text('CUSTOM BRACKET PRINT', style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
                          ]),
                          const SizedBox(height: 8),
                          Text('Print Area: ${p.printArea ?? "Back"}', style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
                          const SizedBox(height: 6),
                          Text('Bracket: ${widget.bracketName}', style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 4, runSpacing: 4, children: widget.picks!.map((pick) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: BmbColors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(pick, style: TextStyle(color: BmbColors.blue, fontSize: 9)),
                          )).toList()),
                          const SizedBox(height: 8),
                          // Approval checkbox
                          GestureDetector(
                            onTap: () => setState(() => _approved = !_approved),
                            child: Row(children: [
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: _approved ? BmbColors.successGreen : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _approved ? BmbColors.successGreen : BmbColors.borderColor, width: 1.5),
                                ),
                                child: _approved ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('I approve this bracket print design', style: TextStyle(color: BmbColors.textPrimary, fontSize: 12))),
                            ]),
                          ),
                        ]),
                      ),
                    ],

                    // SHIPPING ADDRESS
                    const SizedBox(height: 20),
                    Text('Shipping Address', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _shippingField(_firstNameCtrl, 'First Name')),
                      const SizedBox(width: 12),
                      Expanded(child: _shippingField(_lastNameCtrl, 'Last Name')),
                    ]),
                    const SizedBox(height: 10),
                    _shippingField(_emailCtrl, 'Email'),
                    const SizedBox(height: 10),
                    _shippingField(_address1Ctrl, 'Street Address'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(flex: 3, child: _shippingField(_cityCtrl, 'City')),
                      const SizedBox(width: 10),
                      Expanded(flex: 1, child: _shippingField(_stateCtrl, 'State')),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _shippingField(_zipCtrl, 'ZIP')),
                    ]),
                    if (p.supportsCustomPrint) ...[
                      const SizedBox(height: 16),
                      Text('Customization Notes (optional)', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      _shippingField(_notesCtrl, 'e.g. "Add my name under the bracket"'),
                    ],
                  ]),
                ),
              ),
              // Bottom CTA
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: BmbColors.deepNavy.withValues(alpha: 0.9),
                  border: Border(top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
                ),
                child: Column(children: [
                  // Order total
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Order Total', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
                    Text('\$${p.price.toStringAsFixed(2)}', style: TextStyle(color: BmbColors.gold, fontSize: 18, fontWeight: BmbFontWeights.bold)),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _creatingOrder ? null : _createAndCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.successGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: BmbColors.successGreen.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _creatingOrder
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              const SizedBox(width: 10),
                              const Text('Creating Order...'),
                            ])
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.lock, size: 16),
                              const SizedBox(width: 8),
                              Text('Proceed to Checkout', style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold)),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.shopping_bag, color: BmbColors.textTertiary, size: 12),
                    const SizedBox(width: 4),
                    Text('Secure checkout powered by Shopify', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shippingField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: BmbColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
        filled: true,
        fillColor: BmbColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.blue)),
      ),
    );
  }
}

// ─── IN-APP CHECKOUT SCREEN (Simulated WebView) ─────────────────
class ShopifyCheckoutScreen extends StatefulWidget {
  final ShopifyOrder order;
  const ShopifyCheckoutScreen({super.key, required this.order});

  @override
  State<ShopifyCheckoutScreen> createState() => _ShopifyCheckoutScreenState();
}

class _ShopifyCheckoutScreenState extends State<ShopifyCheckoutScreen> {
  bool _processing = false;
  bool _completed = false;

  Future<void> _simulatePayment() async {
    setState(() => _processing = true);
    // Simulate Shopify payment processing
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() { _processing = false; _completed = true; });
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
              // Header bar (looks like embedded browser)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                decoration: BoxDecoration(
                  color: BmbColors.deepNavy,
                  border: Border(bottom: BorderSide(color: BmbColors.borderColor, width: 0.5)),
                ),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.close, color: BmbColors.textPrimary), onPressed: () => _showExitDialog()),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.lock, color: BmbColors.successGreen, size: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          ShopifyService.storeDomain ?? 'checkout.shopify.com',
                          style: TextStyle(color: BmbColors.textSecondary, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        )),
                      ]),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: _completed ? _buildConfirmation() : _buildCheckoutForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutForm() {
    final o = widget.order;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Shopify-style checkout header
        Row(children: [
          Icon(Icons.shopping_bag, color: BmbColors.gold, size: 24),
          const SizedBox(width: 8),
          Text('BMB Shop Checkout', style: TextStyle(color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
        ]),
        const SizedBox(height: 20),

        // Order details card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BmbColors.borderColor, width: 0.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order Summary', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text(o.productTitle, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12))),
              Text('\$${o.productPrice.toStringAsFixed(2)}', style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
            ]),
            const Divider(color: BmbColors.borderColor, height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Shipping', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
              Text('FREE', style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
            ]),
            const Divider(color: BmbColors.borderColor, height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
              Text('\$${o.productPrice.toStringAsFixed(2)}', style: TextStyle(color: BmbColors.gold, fontSize: 18, fontWeight: BmbFontWeights.bold)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Shipping info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BmbColors.borderColor, width: 0.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.local_shipping, color: BmbColors.blue, size: 18),
              const SizedBox(width: 8),
              Text('Shipping To', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
            ]),
            const SizedBox(height: 8),
            Text(o.customerName, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13)),
            Text(o.shippingAddress.displayAddress, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            Text(o.customerEmail, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 16),

        // Simulated payment section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BmbColors.borderColor, width: 0.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.credit_card, color: BmbColors.gold, size: 18),
              const SizedBox(width: 8),
              Text('Payment', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
            ]),
            const SizedBox(height: 12),
            // Simulated card input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: BmbColors.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.borderColor),
              ),
              child: Row(children: [
                Icon(Icons.credit_card, color: BmbColors.textTertiary, size: 18),
                const SizedBox(width: 10),
                Text('\u2022\u2022\u2022\u2022 \u2022\u2022\u2022\u2022 \u2022\u2022\u2022\u2022 4242', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, letterSpacing: 1)),
                const Spacer(),
                Icon(Icons.check_circle, color: BmbColors.successGreen, size: 18),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Demo card pre-filled for testing', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic)),
          ]),
        ),
        const SizedBox(height: 24),

        // Pay button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _processing ? null : _simulatePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.successGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BmbColors.successGreen.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _processing
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 10),
                    Text('Processing Payment...', style: TextStyle(fontSize: 15)),
                  ])
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.lock, size: 16),
                    const SizedBox(width: 8),
                    Text('Pay \$${o.productPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold)),
                  ]),
          ),
        ),
        const SizedBox(height: 10),
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_user, color: BmbColors.textTertiary, size: 12),
          const SizedBox(width: 4),
          Text('256-bit SSL encrypted  \u2022  Powered by Shopify', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
        ])),
      ]),
    );
  }

  Widget _buildConfirmation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [BmbColors.successGreen, BmbColors.successGreen.withValues(alpha: 0.7)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: BmbColors.successGreen.withValues(alpha: 0.3), blurRadius: 20)],
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 24),
          Text('Order Confirmed!', style: TextStyle(color: BmbColors.textPrimary, fontSize: 24, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const SizedBox(height: 8),
          Text('Order #${widget.order.id}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
          const SizedBox(height: 16),
          Text(widget.order.productTitle, style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 4),
          Text('\$${widget.order.productPrice.toStringAsFixed(2)}', style: TextStyle(color: BmbColors.gold, fontSize: 20, fontWeight: BmbFontWeights.bold)),
          if (widget.order.bracketName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_tree, color: BmbColors.blue, size: 16),
                const SizedBox(width: 8),
                Text('Bracket: ${widget.order.bracketName}', style: TextStyle(color: BmbColors.blue, fontSize: 12)),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Text('Shipping to: ${widget.order.shippingAddress.displayAddress}',
              textAlign: TextAlign.center,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Text('Confirmation sent to ${widget.order.customerEmail}',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                // Pop all Shopify screens back to main app
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Back to App', style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leave Checkout?', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
        content: Text('Your order will be saved. You can complete checkout later from your profile.',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Stay', style: TextStyle(color: BmbColors.blue))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: BmbColors.errorRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
