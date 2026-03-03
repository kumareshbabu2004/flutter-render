import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/store/data/models/store_models.dart';
import 'package:bmb_mobile/features/store/data/services/bracket_print_service.dart';
import 'package:bmb_mobile/features/store/data/services/store_service.dart';
import 'package:bmb_mobile/features/bmb_bucks/presentation/screens/bmb_bucks_purchase_screen.dart';

/// Full bracket-to-print flow:
///   Step 1: Select product (filtered by bracket size)
///   Step 2: Customize (size, color) + mockup preview
///   Step 3: Shipping address
///   Step 4: Review + approve (disclaimer, all sales final)
class BracketPrintFlowScreen extends StatefulWidget {
  final String bracketId;
  final String bracketName;
  final int teamCount;
  final List<String>? picks;
  final List<String>? teams; // original seeded team names

  const BracketPrintFlowScreen({
    super.key,
    required this.bracketId,
    required this.bracketName,
    required this.teamCount,
    this.picks,
    this.teams,
  });

  @override
  State<BracketPrintFlowScreen> createState() => _BracketPrintFlowScreenState();
}

class _BracketPrintFlowScreenState extends State<BracketPrintFlowScreen> {
  int _step = 0; // 0=product, 1=customize, 2=shipping, 3=review
  double _balance = 0;
  bool _submitting = false;
  bool _disclaimerAccepted = false;

  // Step 1: Product selection
  StoreProduct? _selectedProduct;
  late List<BracketPrintProduct> _allProducts;

  // Step 2: Customization
  String? _selectedSize;
  String? _selectedColor;

  // Step 3: Shipping
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _phoneController = TextEditingController();

  List<StoreOrder> _existingBracketOrders = [];

  @override
  void initState() {
    super.initState();
    _allProducts = BracketPrintService.instance
        .getAllProductsWithAvailability(widget.teamCount);
    _loadBalance();
    _checkExistingOrders();
  }

  /// Check if user has previously ordered products for this bracket.
  Future<void> _checkExistingOrders() async {
    final orders = await StoreService.instance.getOrders();
    final bracketOrders = orders.where((o) =>
        o.bracketId == widget.bracketId &&
        o.productType == ProductType.customBracketPrint).toList();
    if (!mounted) return;
    setState(() {
      _existingBracketOrders = bracketOrders;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _balance = prefs.getDouble('bmb_bucks_balance') ?? 0);
  }

  bool get _canAfford =>
      _selectedProduct != null && _balance >= _selectedProduct!.creditsCost;

  bool get _shippingValid =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty &&
      _cityController.text.trim().isNotEmpty &&
      _stateController.text.trim().isNotEmpty &&
      _zipController.text.trim().length >= 5;

  void _nextStep() {
    if (_step < 3) setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  /// Shows a confirmation dialog if the user already has orders for this bracket.
  /// Returns true if user confirms they want to proceed, false otherwise.
  Future<bool> _confirmDuplicateOrder() async {
    if (_existingBracketOrders.isEmpty) return true;

    final count = _existingBracketOrders.length;
    final previousProducts = _existingBracketOrders
        .map((o) => o.productName)
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: BmbColors.gold, size: 32),
              ),
              const SizedBox(height: 14),
              Text('Duplicate Order', style: TextStyle(
                  color: BmbColors.textPrimary, fontSize: 18,
                  fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const SizedBox(height: 10),
              Text(
                'You have already ordered $count product${count > 1 ? 's' : ''} '
                'for this bracket:',
                textAlign: TextAlign.center,
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ...previousProducts.map((name) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: BmbColors.successGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: TextStyle(
                        color: BmbColors.textPrimary, fontSize: 12,
                        fontWeight: BmbFontWeights.semiBold))),
                  ],
                ),
              )),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: BmbColors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Ordering again is fine if this is for a friend, '
                      'family member, or a different size/product. '
                      'Just making sure this isn\u2019t a mistake!',
                      style: TextStyle(color: BmbColors.blue, fontSize: 11, height: 1.4),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BmbColors.textSecondary,
                        side: BorderSide(color: BmbColors.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(fontWeight: BmbFontWeights.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Yes, Order Again',
                          style: TextStyle(fontWeight: BmbFontWeights.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return confirmed == true;
  }

  Future<void> _submitOrder() async {
    if (_selectedProduct == null || !_disclaimerAccepted) return;

    // Check for duplicate orders before proceeding
    final proceed = await _confirmDuplicateOrder();
    if (!proceed || !mounted) return;

    setState(() => _submitting = true);

    // Simulate brief processing delay
    await Future.delayed(const Duration(seconds: 1));

    final result = await BracketPrintService.instance.submitPrintOrder(
      product: _selectedProduct!,
      bracketId: widget.bracketId,
      bracketName: widget.bracketName,
      teamCount: widget.teamCount,
      shippingFirstName: _firstNameController.text.trim(),
      shippingLastName: _lastNameController.text.trim(),
      shippingAddress: _addressController.text.trim(),
      shippingCity: _cityController.text.trim(),
      shippingState: _stateController.text.trim(),
      shippingZip: _zipController.text.trim(),
      selectedSize: _selectedSize,
      selectedColor: _selectedColor,
      phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      _showSuccess(result.orderId!, result.newBalance!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Order failed. Please try again.'),
          backgroundColor: BmbColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showSuccess(String orderId, double newBalance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: BmbColors.successGreen, size: 40),
              ),
              const SizedBox(height: 14),
              Text('Order Approved!', style: TextStyle(
                  color: BmbColors.textPrimary, fontSize: 20,
                  fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const SizedBox(height: 8),
              Text('Your custom bracket print is being processed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              _successRow('Order ID', orderId),
              _successRow('Product', _selectedProduct!.name),
              _successRow('Bracket', widget.bracketName),
              if (_selectedSize != null) _successRow('Size', _selectedSize!),
              if (_selectedColor != null) _successRow('Color', _selectedColor!),
              _successRow('Credits Charged', '${_selectedProduct!.creditsCost}'),
              _successRow('New Balance', '${newBalance.toInt()} credits'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: BmbColors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        'Shipping updates will be sent to your inbox. Allow 5-7 business days.',
                        style: TextStyle(color: BmbColors.blue, fontSize: 11))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // back to bracket detail
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Done', style: TextStyle(fontWeight: BmbFontWeights.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _successRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
          Flexible(child: Text(value, style: TextStyle(
              color: BmbColors.textPrimary, fontSize: 12,
              fontWeight: BmbFontWeights.semiBold), textAlign: TextAlign.right)),
        ],
      ),
    );
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
              _buildProgressBar(),
              Expanded(child: _buildStepContent()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    final titles = ['Select Product', 'Preview Design', 'Shipping', 'Review & Approve'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: _step > 0 ? _prevStep : () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text('Print My Picks', style: TextStyle(
                    color: BmbColors.textPrimary, fontSize: 16,
                    fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                Text(titles[_step], style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ─── PROGRESS BAR ───────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: List.generate(4, (i) {
          final active = i <= _step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              decoration: BoxDecoration(
                color: active ? BmbColors.gold : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── STEP CONTENT ───────────────────────────────────────────────
  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildStep0Product();
      case 1: return _buildStep1Customize();
      case 2: return _buildStep2Shipping();
      case 3: return _buildStep3Review();
      default: return const SizedBox();
    }
  }

  // ═══ STEP 0: SELECT PRODUCT ═══════════════════════════════════
  Widget _buildStep0Product() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bracket info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF9C27B0).withValues(alpha: 0.12),
              const Color(0xFF9C27B0).withValues(alpha: 0.04),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_tree, color: Color(0xFF9C27B0), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.bracketName, style: TextStyle(
                        color: BmbColors.textPrimary, fontSize: 14,
                        fontWeight: BmbFontWeights.bold)),
                    Text('${widget.teamCount} teams \u2022 ${widget.teamCount - 1} matchups',
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('Available Products', style: TextStyle(
            color: BmbColors.textPrimary, fontSize: 15,
            fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 4),
        Text('Products are filtered based on your bracket size.',
            style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
        const SizedBox(height: 12),

        ..._allProducts.map((bp) => _buildProductOption(bp)),
      ],
    );
  }

  Widget _buildProductOption(BracketPrintProduct bp) {
    final selected = _selectedProduct?.id == bp.product.id;
    final disabled = !bp.fitsCurrentBracket;
    final canAfford = _balance >= bp.product.creditsCost;

    return GestureDetector(
      onTap: disabled ? null : () => setState(() {
        _selectedProduct = bp.product;
        // Reset customization when product changes
        _selectedSize = bp.product.sizes != null && bp.product.sizes!.isNotEmpty
            ? bp.product.sizes![1 < bp.product.sizes!.length ? 1 : 0]
            : null;
        _selectedColor = bp.product.colors != null && bp.product.colors!.isNotEmpty
            ? bp.product.colors![0]
            : null;
      }),
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [
                    const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    const Color(0xFF9C27B0).withValues(alpha: 0.05),
                  ])
                : BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFF9C27B0) : BmbColors.borderColor,
              width: selected ? 2 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_productIcon(bp.product.imageIcon),
                        color: const Color(0xFF9C27B0), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bp.product.name, style: TextStyle(
                            color: BmbColors.textPrimary, fontSize: 15,
                            fontWeight: BmbFontWeights.bold)),
                        Text(bp.printAreaDescription, style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${bp.product.creditsCost}', style: TextStyle(
                          color: canAfford && !disabled ? BmbColors.gold : BmbColors.errorRed,
                          fontSize: 20, fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay')),
                      Text('credits', style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              if (disabled && bp.reason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BmbColors.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: BmbColors.errorRed, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text(bp.reason!, style: TextStyle(
                          color: BmbColors.errorRed, fontSize: 10))),
                    ],
                  ),
                ),
              ],
              if (selected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: BmbColors.successGreen, size: 14),
                      const SizedBox(width: 6),
                      Text('Selected', style: TextStyle(
                          color: BmbColors.successGreen, fontSize: 11,
                          fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══ STEP 1: CUSTOMIZE ═══════════════════════════════════════
  Widget _buildStep1Customize() {
    if (_selectedProduct == null) return const SizedBox();

    final isApparel = _selectedProduct!.id == 'cb_tshirt' || _selectedProduct!.id == 'cb_hoodie';
    final productLabel = _selectedProduct!.id == 'cb_hoodie' ? 'HOODIE' : 'T-SHIRT';
    final picks = widget.picks ?? [];
    final teams = widget.teams ?? [];
    final totalRounds = _computeTotalRounds(widget.teamCount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Apparel: show BACK VIEW with bracket tree first
        if (isApparel) ...[
          _buildApparelMockup(productLabel),
          const SizedBox(height: 16),
          // Front design preview for apparel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF9C27B0).withValues(alpha: 0.15),
                  BmbColors.gold.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(_productIcon(_selectedProduct!.imageIcon),
                          color: const Color(0xFF9C27B0).withValues(alpha: 0.3), size: 60),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/splash_dark.png',
                              width: 36, height: 36,
                              errorBuilder: (_, __, ___) => Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: BmbColors.gold.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.shield, color: BmbColors.gold, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('BMB', style: TextStyle(
                              color: BmbColors.gold, fontSize: 12,
                              fontWeight: BmbFontWeights.bold, letterSpacing: 2)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text('Front Design \u2014 Champion Crest', style: TextStyle(
                    color: BmbColors.textPrimary, fontSize: 14,
                    fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                const SizedBox(height: 4),
                Text(
                  'Front features the BMB champion crest logo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],

        // Non-apparel: show bracket tree preview as the product mockup
        if (!isApparel) ...[
          _buildProductBracketPreview(picks, teams, totalRounds),
          const SizedBox(height: 10),
          Text(
            BracketPrintService.instance.getMockupDescription(
              bracketName: widget.bracketName,
              teamCount: widget.teamCount,
              productName: _selectedProduct!.name,
              selectedColor: _selectedColor,
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
        const SizedBox(height: 20),

        // Size selector
        if (_selectedProduct!.sizes != null && _selectedProduct!.sizes!.isNotEmpty) ...[
          Text('Select Size', style: TextStyle(
              color: BmbColors.textPrimary, fontSize: 14,
              fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _selectedProduct!.sizes!.map((size) {
              final sel = _selectedSize == size;
              return GestureDetector(
                onTap: () => setState(() => _selectedSize = size),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? BmbColors.gold.withValues(alpha: 0.15) : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? BmbColors.gold : BmbColors.borderColor,
                      width: sel ? 1.5 : 0.5,
                    ),
                  ),
                  child: Text(size, style: TextStyle(
                      color: sel ? BmbColors.gold : BmbColors.textSecondary,
                      fontSize: 14, fontWeight: sel ? BmbFontWeights.bold : BmbFontWeights.medium)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Color selector with swatch previews
        if (_selectedProduct!.colors != null && _selectedProduct!.colors!.isNotEmpty) ...[
          Text('Select Color', style: TextStyle(
              color: BmbColors.textPrimary, fontSize: 14,
              fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _selectedProduct!.colors!.map((color) {
              final sel = _selectedColor == color;
              final swatchColor = _colorFromName(color);
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? BmbColors.blue.withValues(alpha: 0.15) : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? BmbColors.blue : BmbColors.borderColor,
                      width: sel ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: swatchColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: swatchColor.computeLuminance() > 0.7
                                ? Colors.grey.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(color, style: TextStyle(
                          color: sel ? BmbColors.blue : BmbColors.textSecondary,
                          fontSize: 14, fontWeight: sel ? BmbFontWeights.bold : BmbFontWeights.medium)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ═══ STEP 2: SHIPPING ════════════════════════════════════════
  Widget _buildStep2Shipping() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BmbColors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.local_shipping, color: BmbColors.blue, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  'Shipping is included. Allow 5\u20137 business days after processing.',
                  style: TextStyle(color: BmbColors.blue, fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _shippingField('First Name', _firstNameController, Icons.person)),
            const SizedBox(width: 12),
            Expanded(child: _shippingField('Last Name', _lastNameController, Icons.person_outline)),
          ],
        ),
        _shippingField('Street Address', _addressController, Icons.home),
        _shippingField('City', _cityController, Icons.location_city),
        Row(
          children: [
            Expanded(child: _shippingField('State', _stateController, Icons.map)),
            const SizedBox(width: 12),
            Expanded(child: _shippingField('ZIP Code', _zipController, Icons.pin_drop,
                keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BmbColors.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: BmbColors.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Phone number is used for shipping updates and order communications via SMS.',
                style: TextStyle(color: BmbColors.gold, fontSize: 11),
              )),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _shippingField('Phone Number', _phoneController, Icons.phone,
            keyboardType: TextInputType.phone),
      ],
    );
  }

  Widget _shippingField(String label, TextEditingController controller, IconData icon,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: BmbColors.textPrimary, fontSize: 14),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
          prefixIcon: Icon(icon, color: BmbColors.textTertiary, size: 20),
          filled: true,
          fillColor: BmbColors.cardDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.gold, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ═══ STEP 3: REVIEW & APPROVE ════════════════════════════════
  Widget _buildStep3Review() {
    if (_selectedProduct == null) return const SizedBox();

    final isApparel = _selectedProduct!.id == 'cb_tshirt' || _selectedProduct!.id == 'cb_hoodie';
    final productLabel = _selectedProduct!.id == 'cb_hoodie' ? 'HOODIE' : 'T-SHIRT';
    final picks = widget.picks ?? [];
    final teams = widget.teams ?? [];
    final totalRounds = _computeTotalRounds(widget.teamCount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── DESIGN PREVIEW (mandatory rendering before approval) ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF9C27B0).withValues(alpha: 0.1),
              BmbColors.gold.withValues(alpha: 0.05),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.preview, color: const Color(0xFF9C27B0), size: 20),
                  const SizedBox(width: 8),
                  Text('Your Design Preview', style: TextStyle(
                      color: BmbColors.textPrimary, fontSize: 15,
                      fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                ],
              ),
              const SizedBox(height: 4),
              Text('This is how your bracket picks will appear on the ${_selectedProduct!.name}.',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              const SizedBox(height: 12),
              // Show the apparel mockup for hoodies/tshirts, or bracket tree for other products
              if (isApparel)
                _buildApparelMockup(productLabel)
              else
                _buildProductBracketPreview(picks, teams, totalRounds),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Duplicate order warning banner (if applicable)
        if (_existingBracketOrders.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: BmbColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'You have ${_existingBracketOrders.length} existing order${_existingBracketOrders.length > 1 ? 's' : ''} for this bracket. '
                  'A confirmation will appear before placing this order.',
                  style: TextStyle(color: BmbColors.gold, fontSize: 11, height: 1.3),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Order summary
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BmbColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order Summary', style: TextStyle(
                  color: BmbColors.textPrimary, fontSize: 16,
                  fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
              const SizedBox(height: 14),
              _reviewRow('Product', _selectedProduct!.name),
              _reviewRow('Bracket', widget.bracketName),
              _reviewRow('Teams', '${widget.teamCount} teams'),
              if (_selectedSize != null) _reviewRow('Size', _selectedSize!),
              if (_selectedColor != null) _reviewRow('Color', _selectedColor!),
              const Divider(color: BmbColors.borderColor, height: 24),
              _reviewRow('Ship To', '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'),
              _reviewRow('Address', '${_addressController.text.trim()}\n${_cityController.text.trim()}, ${_stateController.text.trim()} ${_zipController.text.trim()}'),
              if (_phoneController.text.trim().isNotEmpty)
                _reviewRow('Phone', _phoneController.text.trim()),
              const Divider(color: BmbColors.borderColor, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: TextStyle(
                      color: BmbColors.textPrimary, fontSize: 15,
                      fontWeight: BmbFontWeights.bold)),
                  Row(
                    children: [
                      Icon(Icons.savings, color: BmbColors.gold, size: 18),
                      const SizedBox(width: 4),
                      Text('${_selectedProduct!.creditsCost} credits', style: TextStyle(
                          color: BmbColors.gold, fontSize: 18,
                          fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Balance after: ${(_balance - _selectedProduct!.creditsCost).toInt()} credits',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ALL SALES FINAL DISCLAIMER
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BmbColors.errorRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BmbColors.errorRed.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel, color: BmbColors.errorRed, size: 20),
                  const SizedBox(width: 8),
                  Text('All Sales Final', style: TextStyle(
                      color: BmbColors.errorRed, fontSize: 14,
                      fontWeight: BmbFontWeights.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Custom bracket prints are made-to-order and personalized with your picks. '
                'Once approved, this order cannot be cancelled, returned, refunded, or reprinted. '
                'Please verify your product selection, size, color, and shipping address are correct '
                'before approving.\n\n'
                'By tapping "Approve & Place Order" below, you acknowledge that:\n'
                '\u2022 This is a custom, non-returnable product\n'
                '\u2022 No refunds or exchanges will be issued\n'
                '\u2022 You have verified all details above are correct\n'
                '\u2022 BMB is not responsible for incorrect size, color, or address selections',
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.5),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _disclaimerAccepted = !_disclaimerAccepted),
                child: Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: _disclaimerAccepted
                            ? BmbColors.successGreen.withValues(alpha: 0.2)
                            : BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _disclaimerAccepted ? BmbColors.successGreen : BmbColors.borderColor,
                          width: 1.5,
                        ),
                      ),
                      child: _disclaimerAccepted
                          ? const Icon(Icons.check, color: BmbColors.successGreen, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                        'I have reviewed my order and understand all sales are final.',
                        style: TextStyle(color: BmbColors.textPrimary, fontSize: 12,
                            fontWeight: BmbFontWeights.semiBold))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
          const SizedBox(width: 16),
          Flexible(child: Text(value, style: TextStyle(
              color: BmbColors.textPrimary, fontSize: 12,
              fontWeight: BmbFontWeights.semiBold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  // ─── BOTTOM BAR ─────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy,
        border: Border(top: BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        child: _buildStepButton(),
      ),
    );
  }

  Widget _buildStepButton() {
    switch (_step) {
      case 0: // Select Product
        return SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _selectedProduct != null && _canAfford ? _nextStep : (_selectedProduct != null && !_canAfford ? () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const BmbBucksPurchaseScreen()));
              _loadBalance();
            } : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedProduct != null && _canAfford ? const Color(0xFF9C27B0) : BmbColors.gold,
              foregroundColor: _selectedProduct != null && _canAfford ? Colors.white : Colors.black,
              disabledBackgroundColor: BmbColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(_selectedProduct != null && !_canAfford ? Icons.savings : Icons.arrow_forward, size: 18),
            label: Text(
              _selectedProduct == null
                  ? 'Select a product'
                  : !_canAfford
                      ? 'Add Credits (need ${(_selectedProduct!.creditsCost - _balance).toInt()} more)'
                      : 'Continue \u2014 ${_selectedProduct!.creditsCost} credits',
              style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold),
            ),
          ),
        );

      case 1: // Customize
        return SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text('Continue to Shipping',
                style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold)),
          ),
        );

      case 2: // Shipping
        return SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _shippingValid ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              foregroundColor: Colors.white,
              disabledBackgroundColor: BmbColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text('Review Order',
                style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold)),
          ),
        );

      case 3: // Approve
        return SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _disclaimerAccepted && !_submitting ? _submitOrder : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.successGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BmbColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _submitting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle, size: 18),
            label: Text(_submitting ? 'Processing...' : 'Approve & Place Order',
                style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold)),
          ),
        );

      default:
        return const SizedBox();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTRAST-AWARE APPAREL BRACKET SYSTEM (v2 — Premium Redesign)
  // Dark garment -> light/vibrant text; Light garment -> dark text
  // Team picks render inside CIRCLES with neon glow
  // No trophy. No "March Madness". BMB logo prominent.
  // Bracket sits BELOW the hood. Maximized size.
  // ═══════════════════════════════════════════════════════════════════

  /// Maps a color name string to a real Color.
  Color _colorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'black':    return const Color(0xFF111111);
      case 'navy':     return const Color(0xFF1B2838);
      case 'charcoal': return const Color(0xFF2C2C2C);
      case 'white':    return const Color(0xFFF5F5F5);
      case 'grey':
      case 'gray':     return const Color(0xFFBDBDBD);
      case 'gold':     return const Color(0xFFFFD700);
      default:         return const Color(0xFF111111);
    }
  }

  /// Determines the full color palette based on garment color selection.
  _ApparelPalette _getPalette() {
    final sel = _selectedColor?.toLowerCase() ?? 'black';
    switch (sel) {
      case 'white':
        return _ApparelPalette(
          garment: const Color(0xFFF5F5F5),
          isDark: false,
          primary: const Color(0xFF0D1B2A),
          secondary: const Color(0xFF0D1B2A).withValues(alpha: 0.6),
          tertiary: const Color(0xFF0D1B2A).withValues(alpha: 0.3),
          winnerBg: const Color(0xFF00796B).withValues(alpha: 0.2),
          winnerText: const Color(0xFF00796B),
          winnerGlow: const Color(0xFF00796B).withValues(alpha: 0.3),
          loserText: const Color(0xFF0D1B2A).withValues(alpha: 0.4),
          cellBg: const Color(0xFF0D1B2A).withValues(alpha: 0.06),
          cellBorder: const Color(0xFF0D1B2A).withValues(alpha: 0.12),
          accent: const Color(0xFFB8860B),
          accentSoft: const Color(0xFFB8860B).withValues(alpha: 0.15),
          divider: const Color(0xFF0D1B2A).withValues(alpha: 0.08),
          leftRegion: const Color(0xFF1565C0),
          rightRegion: const Color(0xFFC62828),
          champBg: const Color(0xFF00796B).withValues(alpha: 0.12),
          champBorder: const Color(0xFF00796B).withValues(alpha: 0.35),
          connectorLine: const Color(0xFF0D1B2A).withValues(alpha: 0.12),
          teamCircleBg: const Color(0xFF0D1B2A).withValues(alpha: 0.05),
        );
      case 'grey':
      case 'gray':
        return _ApparelPalette(
          garment: const Color(0xFFBDBDBD),
          isDark: false,
          primary: const Color(0xFF1A1A2E),
          secondary: const Color(0xFF1A1A2E).withValues(alpha: 0.65),
          tertiary: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
          winnerBg: const Color(0xFF1565C0).withValues(alpha: 0.2),
          winnerText: const Color(0xFF0D47A1),
          winnerGlow: const Color(0xFF1565C0).withValues(alpha: 0.3),
          loserText: const Color(0xFF1A1A2E).withValues(alpha: 0.4),
          cellBg: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
          cellBorder: const Color(0xFF1A1A2E).withValues(alpha: 0.12),
          accent: const Color(0xFFB8860B),
          accentSoft: const Color(0xFFB8860B).withValues(alpha: 0.15),
          divider: const Color(0xFF1A1A2E).withValues(alpha: 0.08),
          leftRegion: const Color(0xFF1565C0),
          rightRegion: const Color(0xFFC62828),
          champBg: const Color(0xFF1565C0).withValues(alpha: 0.12),
          champBorder: const Color(0xFF1565C0).withValues(alpha: 0.35),
          connectorLine: const Color(0xFF1A1A2E).withValues(alpha: 0.12),
          teamCircleBg: const Color(0xFF1A1A2E).withValues(alpha: 0.05),
        );
      case 'navy':
        return _ApparelPalette(
          garment: const Color(0xFF1B2838),
          isDark: true,
          primary: Colors.white,
          secondary: Colors.white.withValues(alpha: 0.65),
          tertiary: Colors.white.withValues(alpha: 0.3),
          winnerBg: const Color(0xFF00E676).withValues(alpha: 0.2),
          winnerText: const Color(0xFF00E676),
          winnerGlow: const Color(0xFF00E676).withValues(alpha: 0.35),
          loserText: Colors.white.withValues(alpha: 0.4),
          cellBg: Colors.white.withValues(alpha: 0.06),
          cellBorder: Colors.white.withValues(alpha: 0.1),
          accent: const Color(0xFFFFD54F),
          accentSoft: const Color(0xFFFFD54F).withValues(alpha: 0.12),
          divider: Colors.white.withValues(alpha: 0.06),
          leftRegion: const Color(0xFF64B5F6),
          rightRegion: const Color(0xFFEF5350),
          champBg: const Color(0xFF00E676).withValues(alpha: 0.12),
          champBorder: const Color(0xFF00E676).withValues(alpha: 0.4),
          connectorLine: Colors.white.withValues(alpha: 0.08),
          teamCircleBg: Colors.white.withValues(alpha: 0.06),
        );
      case 'charcoal':
        return _ApparelPalette(
          garment: const Color(0xFF2C2C2C),
          isDark: true,
          primary: Colors.white,
          secondary: Colors.white.withValues(alpha: 0.65),
          tertiary: Colors.white.withValues(alpha: 0.3),
          winnerBg: const Color(0xFF00E676).withValues(alpha: 0.2),
          winnerText: const Color(0xFF00E676),
          winnerGlow: const Color(0xFF00E676).withValues(alpha: 0.35),
          loserText: Colors.white.withValues(alpha: 0.4),
          cellBg: Colors.white.withValues(alpha: 0.07),
          cellBorder: Colors.white.withValues(alpha: 0.12),
          accent: const Color(0xFFFFD54F),
          accentSoft: const Color(0xFFFFD54F).withValues(alpha: 0.12),
          divider: Colors.white.withValues(alpha: 0.07),
          leftRegion: const Color(0xFF64B5F6),
          rightRegion: const Color(0xFFEF5350),
          champBg: const Color(0xFF00E676).withValues(alpha: 0.12),
          champBorder: const Color(0xFF00E676).withValues(alpha: 0.4),
          connectorLine: Colors.white.withValues(alpha: 0.08),
          teamCircleBg: Colors.white.withValues(alpha: 0.07),
        );
      default: // Black
        return _ApparelPalette(
          garment: const Color(0xFF111111),
          isDark: true,
          primary: Colors.white,
          secondary: Colors.white.withValues(alpha: 0.65),
          tertiary: Colors.white.withValues(alpha: 0.3),
          winnerBg: const Color(0xFF00E676).withValues(alpha: 0.22),
          winnerText: const Color(0xFF00E676),
          winnerGlow: const Color(0xFF00E676).withValues(alpha: 0.4),
          loserText: Colors.white.withValues(alpha: 0.42),
          cellBg: Colors.white.withValues(alpha: 0.07),
          cellBorder: Colors.white.withValues(alpha: 0.12),
          accent: const Color(0xFFFFD54F),
          accentSoft: const Color(0xFFFFD54F).withValues(alpha: 0.15),
          divider: Colors.white.withValues(alpha: 0.07),
          leftRegion: const Color(0xFF64B5F6),
          rightRegion: const Color(0xFFEF5350),
          champBg: const Color(0xFF00E676).withValues(alpha: 0.15),
          champBorder: const Color(0xFF00E676).withValues(alpha: 0.5),
          connectorLine: Colors.white.withValues(alpha: 0.1),
          teamCircleBg: Colors.white.withValues(alpha: 0.07),
        );
    }
  }

  // ─── APPAREL MOCKUP (v2 — Premium with circles) ──────────────────
  Widget _buildApparelMockup(String productLabel) {
    final picks = widget.picks ?? [];
    final teams = widget.teams ?? [];
    final totalRounds = _computeTotalRounds(widget.teamCount);
    final p = _getPalette();
    final bool hasPicks = picks.isNotEmpty;
    final bool isHoodie = _selectedProduct?.id == 'cb_hoodie';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.garment.withValues(alpha: 0.97), p.garment],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: p.accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: 0.15),
            blurRadius: 30, spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── BACK VIEW banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rotate_90_degrees_ccw, color: p.accent, size: 12),
                const SizedBox(width: 5),
                Text('BACK VIEW \u2014 $productLabel', style: TextStyle(
                  color: p.accent, fontSize: 10,
                  fontWeight: BmbFontWeights.bold, letterSpacing: 1.2)),
              ],
            ),
          ),

          // ── HOOD ZONE (only for hoodies — clear separation) ──
          if (isHoodie) ...[
            Container(
              width: double.infinity,
              height: 44,
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    p.garment.withValues(alpha: 0.6),
                    p.garment.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(70)),
                border: Border(
                  left: BorderSide(color: p.divider, width: 0.5),
                  right: BorderSide(color: p.divider, width: 0.5),
                  bottom: BorderSide(color: p.divider.withValues(alpha: 0.4), width: 0.5),
                ),
              ),
              child: Center(
                child: Text('HOOD', style: TextStyle(
                  color: p.tertiary, fontSize: 7,
                  fontWeight: BmbFontWeights.bold, letterSpacing: 2)),
              ),
            ),
            // Clear gap between hood and print area
            const SizedBox(height: 8),
            // Dashed separator line showing "print starts here"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(40, (i) => Expanded(
                  child: Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: i.isEven ? p.accent.withValues(alpha: 0.2) : Colors.transparent,
                  ),
                )),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // ── PRINT AREA (below hood, maximized) ──
          Padding(
            padding: EdgeInsets.fromLTRB(8, isHoodie ? 2 : 14, 8, 6),
            child: Column(
              children: [
                // ── BMB LOGO (prominent, top of print) ──
                _buildBmbLogo(p),
                const SizedBox(height: 4),

                // ── BRACKET TITLE PLATE ──
                _buildTitlePlate(p),
                const SizedBox(height: 8),

                // ── BRACKET TREE (with user picks in circles) ──
                if (!hasPicks)
                  _buildNoPicks(p)
                else
                  _buildFullBracketTree(picks, teams, totalRounds, p),

                const SizedBox(height: 8),

                // ── Champion badge ──
                if (hasPicks) ...[
                  _buildChampionCallout(picks, totalRounds, p),
                  const SizedBox(height: 6),
                ],

                // ── WHO YOU GOT? + date ──
                Text('WHO YOU GOT?', style: TextStyle(
                  color: p.secondary,
                  fontSize: 8, fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay', letterSpacing: 2)),
                const SizedBox(height: 3),
                Text(_bracketDateStamp, style: TextStyle(
                  color: p.tertiary,
                  fontSize: 7, fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay', letterSpacing: 1.5)),
              ],
            ),
          ),

          // ── BRANDING FOOTER ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: p.isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(23)),
            ),
            child: Text('BACKMYBRACKET.COM', textAlign: TextAlign.center,
              style: TextStyle(
                color: p.tertiary, fontSize: 7, letterSpacing: 2.0)),
          ),
        ],
      ),
    );
  }

  /// BMB Logo rendered at top of print area — uses the exact splash logo.
  Widget _buildBmbLogo(_ApparelPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          p.accent.withValues(alpha: 0.18),
          p.accent.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.accent.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Splash logo image — same as the BMB splash screen logo
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              'assets/images/splash_dark.png',
              width: 24, height: 24,
              errorBuilder: (_, __, ___) => Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      p.accent.withValues(alpha: 0.3),
                      p.accent.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(Icons.shield, color: p.accent, size: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('BMB', style: TextStyle(
            color: p.accent, fontSize: 16,
            fontWeight: BmbFontWeights.bold,
            fontFamily: 'ClashDisplay', letterSpacing: 4)),
        ],
      ),
    );
  }

  /// Title plate showing bracket name + team/matchup count.
  Widget _buildTitlePlate(_ApparelPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          p.accent.withValues(alpha: 0.1),
          p.accent.withValues(alpha: 0.02),
        ]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.accent.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            widget.bracketName.toUpperCase(),
            style: TextStyle(
              color: p.primary.withValues(alpha: 0.8), fontSize: 8,
              fontWeight: BmbFontWeights.bold,
              fontFamily: 'ClashDisplay', letterSpacing: 1.5),
            textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.teamCount} TEAMS \u2022 ${widget.teamCount - 1} MATCHUPS',
            style: TextStyle(
              color: p.tertiary, fontSize: 5.5,
              fontWeight: BmbFontWeights.bold, letterSpacing: 1.0),
          ),
        ],
      ),
    );
  }

  /// Empty-picks placeholder.
  Widget _buildNoPicks(_ApparelPalette p) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.cellBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.cellBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree, color: p.tertiary, size: 36),
          const SizedBox(height: 8),
          Text('No picks available for preview', style: TextStyle(
            color: p.secondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Make picks first, then return here to print', style: TextStyle(
            color: p.tertiary, fontSize: 10)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SPLIT BRACKET TREE (v2 — circles, neon glow, gradient cells)
  // ═══════════════════════════════════════════════════════════════════

  String get _bracketDateStamp {
    final now = DateTime.now();
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  Widget _buildFullBracketTree(
    List<String> picks, List<String> teams, int totalRounds,
    _ApparelPalette p,
  ) {
    final halfTeams = widget.teamCount ~/ 2;
    final leftTeams = teams.length >= halfTeams
        ? teams.sublist(0, halfTeams) : List<String>.from(teams);
    final rightTeams = teams.length > halfTeams
        ? teams.sublist(halfTeams) : <String>[];
    final halfRounds = totalRounds > 0 ? totalRounds - 1 : 0;

    final leftPicks = <String>[];
    final rightPicks = <String>[];
    _splitPicksByRound(picks, totalRounds, leftPicks, rightPicks);

    final String? champion = picks.isNotEmpty ? picks.last : null;
    final leftRounds = _reconstructHalfBracket(leftPicks, leftTeams, halfRounds);
    final rightRounds = _reconstructHalfBracket(rightPicks, rightTeams, halfRounds);
    final leftFinalist = leftPicks.isNotEmpty ? leftPicks.last : null;
    final rightFinalist = rightPicks.isNotEmpty ? rightPicks.last : null;
    final leftLabel = _getRegionLabel(leftTeams);
    final rightLabel = _getRegionLabel(rightTeams);

    final firstRoundCount = max(
      leftRounds.isNotEmpty ? leftRounds[0].length : 1,
      rightRounds.isNotEmpty ? rightRounds[0].length : 1,
    );
    // Larger tree height for maximized bracket
    final treeHeight = max(firstRoundCount * 42.0, 160.0).clamp(160.0, 620.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.cellBg.withValues(alpha: 0.4),
            p.cellBg.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.divider),
      ),
      child: Column(
        children: [
          // ── CHAMPIONSHIP at top ──
          _buildChampionshipBanner(champion, leftFinalist, rightFinalist, p),
          const SizedBox(height: 6),

          // ── Region labels ──
          Row(
            children: [
              Expanded(child: Center(child: Text(leftLabel, style: TextStyle(
                color: p.leftRegion, fontSize: 6.5,
                fontWeight: BmbFontWeights.bold, letterSpacing: 1.2)))),
              const SizedBox(width: 6),
              Expanded(child: Center(child: Text(rightLabel, style: TextStyle(
                color: p.rightRegion, fontSize: 6.5,
                fontWeight: BmbFontWeights.bold, letterSpacing: 1.2)))),
            ],
          ),
          const SizedBox(height: 5),

          // ── Split bracket body ──
          SizedBox(
            height: treeHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildHalfBracket(leftRounds, flowsRight: true, p: p)),
                // Glowing center divider
                Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        p.accent.withValues(alpha: 0.5),
                        p.accent.withValues(alpha: 0.1),
                        p.accent.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(color: p.accent.withValues(alpha: 0.2), blurRadius: 4),
                    ],
                  ),
                ),
                Expanded(child: _buildHalfBracket(rightRounds, flowsRight: false, p: p)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Championship banner — finalists + winner badge (no trophy).
  Widget _buildChampionshipBanner(
    String? champion, String? leftFinalist, String? rightFinalist,
    _ApparelPalette p,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          p.accentSoft, p.accentSoft.withValues(alpha: 0.02),
        ]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.accent.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        children: [
          // CHAMPIONSHIP label
          Text('CHAMPIONSHIP', style: TextStyle(
            color: p.accent.withValues(alpha: 0.7), fontSize: 6,
            fontWeight: BmbFontWeights.bold, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          // Finalists
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leftFinalist != null) ...[
                _buildFinalistChip(leftFinalist, isLeft: true, p: p),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text('VS', style: TextStyle(
                    color: p.tertiary, fontSize: 6,
                    fontWeight: BmbFontWeights.bold, letterSpacing: 1)),
                ),
              ],
              if (rightFinalist != null)
                _buildFinalistChip(rightFinalist, isLeft: false, p: p),
              if (leftFinalist == null && rightFinalist == null)
                Text('TBD', style: TextStyle(
                  color: p.tertiary, fontSize: 7,
                  fontWeight: BmbFontWeights.bold)),
            ],
          ),
          // Winner
          if (champion != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: p.champBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.champBorder, width: 0.5),
                boxShadow: [
                  BoxShadow(color: p.winnerGlow, blurRadius: 10, spreadRadius: 1),
                ],
              ),
              child: Text(
                _truncateName(champion, maxLen: 16).toUpperCase(),
                style: TextStyle(
                  color: p.winnerText, fontSize: 8,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay', letterSpacing: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalistChip(String name, {required bool isLeft, required _ApparelPalette p}) {
    final color = isLeft ? p.leftRegion : p.rightRegion;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        _truncateName(name, maxLen: 10),
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 6.5, fontWeight: BmbFontWeights.bold),
      ),
    );
  }

  void _splitPicksByRound(List<String> allPicks, int totalRounds,
      List<String> leftPicks, List<String> rightPicks) {
    int pickIdx = 0;
    int matchupsInRound = widget.teamCount ~/ 2;
    for (int r = 0; r < totalRounds && pickIdx < allPicks.length; r++) {
      if (r == totalRounds - 1) {
        pickIdx++;
      } else {
        final halfCount = matchupsInRound ~/ 2;
        for (int m = 0; m < halfCount && pickIdx < allPicks.length; m++) {
          leftPicks.add(allPicks[pickIdx++]);
        }
        for (int m = 0; m < halfCount && pickIdx < allPicks.length; m++) {
          rightPicks.add(allPicks[pickIdx++]);
        }
        matchupsInRound = (matchupsInRound / 2).ceil();
      }
    }
  }

  /// One half of the split bracket with rounded circle team cells.
  Widget _buildHalfBracket(
    List<List<_MatchupData>> rounds, {
    required bool flowsRight,
    required _ApparelPalette p,
  }) {
    if (rounds.isEmpty) return const SizedBox();
    final orderedRounds = flowsRight ? rounds : rounds.reversed.toList();
    final isLeft = flowsRight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int col = 0; col < orderedRounds.length; col++) ...[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int m = 0; m < orderedRounds[col].length; m++)
                  _buildMatchupPair(
                    orderedRounds[col][m],
                    roundDepth: col,
                    totalCols: orderedRounds.length,
                    isLeft: isLeft,
                    p: p,
                  ),
              ],
            ),
          ),
          // Connector lines between rounds
          if (col < orderedRounds.length - 1)
            SizedBox(
              width: 4,
              child: Center(child: Container(
                width: 1,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      p.connectorLine,
                      p.connectorLine.withValues(alpha: 0.3),
                      p.connectorLine,
                    ],
                  ),
                ),
              )),
            ),
        ],
      ],
    );
  }

  /// Matchup pair — CIRCLE team cells with vibrant winner glow.
  Widget _buildMatchupPair(_MatchupData matchup, {
    required int roundDepth,
    required int totalCols,
    required bool isLeft,
    required _ApparelPalette p,
  }) {
    final t1IsWinner = _isTeamMatch(matchup.team1, matchup.winner);
    final t2IsWinner = _isTeamMatch(matchup.team2, matchup.winner);
    final isFinalCol = isLeft ? roundDepth == totalCols - 1 : roundDepth == 0;
    final isFirstCol = isLeft ? roundDepth == 0 : roundDepth == totalCols - 1;
    final fontSize = isFirstCol ? 5.0 : (isFinalCol ? 7.0 : 5.5);
    final maxChars = isFirstCol ? 7 : (isFinalCol ? 13 : 9);
    // Circle diameter scales with round
    final circleSize = isFirstCol ? 22.0 : (isFinalCol ? 32.0 : 26.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTeamCircle(
            _truncateName(matchup.team1, maxLen: maxChars),
            isWinner: t1IsWinner,
            fontSize: fontSize,
            circleSize: circleSize,
            isLeft: isLeft,
            p: p,
          ),
          // Thin connector between the two teams in a matchup
          Container(
            height: 3,
            width: 1,
            color: p.connectorLine,
          ),
          _buildTeamCircle(
            _truncateName(matchup.team2, maxLen: maxChars),
            isWinner: t2IsWinner,
            fontSize: fontSize,
            circleSize: circleSize,
            isLeft: isLeft,
            p: p,
          ),
        ],
      ),
    );
  }

  /// Single team rendered as a CIRCLE (pill/rounded capsule).
  /// Winners get neon glow background + bold text.
  Widget _buildTeamCircle(String name, {
    required bool isWinner,
    required double fontSize,
    required double circleSize,
    required bool isLeft,
    required _ApparelPalette p,
  }) {
    final bgColor = isWinner ? p.winnerBg : p.teamCircleBg;
    final textColor = isWinner ? p.winnerText : p.loserText;
    final borderColor = isWinner
        ? p.winnerText.withValues(alpha: 0.5)
        : p.cellBorder;

    return Container(
      constraints: BoxConstraints(
        minWidth: circleSize,
        minHeight: circleSize,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: circleSize > 28 ? 6 : 3,
        vertical: circleSize > 28 ? 3 : 2,
      ),
      decoration: BoxDecoration(
        gradient: isWinner
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  bgColor,
                  p.winnerGlow.withValues(alpha: 0.15),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bgColor, bgColor.withValues(alpha: 0.5)],
              ),
        borderRadius: BorderRadius.circular(circleSize / 2),
        border: Border.all(color: borderColor, width: isWinner ? 1.0 : 0.5),
        boxShadow: isWinner ? [
          BoxShadow(
            color: p.winnerGlow,
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ] : null,
      ),
      child: Center(
        child: Text(
          name,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: isWinner ? BmbFontWeights.bold : BmbFontWeights.medium,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  bool _isTeamMatch(String team, String winner) {
    final a = team.replaceAll(RegExp(r'^\(\d+\)\s*'), '').trim().toLowerCase();
    final b = winner.replaceAll(RegExp(r'^\(\d+\)\s*'), '').trim().toLowerCase();
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    return false;
  }

  String _getRegionLabel(List<String> teams) {
    if (teams.isEmpty) return 'BRACKET';
    final regions = <String>{};
    const knownRegions = [
      'East', 'West', 'South', 'Midwest', 'North',
      'AFC', 'NFC', 'AL', 'NL',
      'Albany', 'Portland', 'Birmingham', 'Tampa',
      'Omaha', 'Memphis', 'San Antonio', 'Seattle',
    ];
    for (final r in knownRegions) {
      if (teams.any((t) => t.contains(r))) regions.add(r);
    }
    return regions.isNotEmpty ? regions.take(2).join(' / ').toUpperCase() : 'BRACKET';
  }

  /// Non-apparel product preview (poster, canvas, mug) — uses dark palette always.
  Widget _buildProductBracketPreview(
      List<String> picks, List<String> teams, int totalRounds) {
    final hasPicks = picks.isNotEmpty;
    // Non-apparel always uses a dark poster palette
    final posterP = _ApparelPalette(
      garment: const Color(0xFF0A0E1A), isDark: true,
      primary: Colors.white,
      secondary: Colors.white.withValues(alpha: 0.6),
      tertiary: Colors.white.withValues(alpha: 0.3),
      winnerBg: const Color(0xFF00E676).withValues(alpha: 0.22),
      winnerText: const Color(0xFF00E676),
      winnerGlow: const Color(0xFF00E676).withValues(alpha: 0.4),
      loserText: Colors.white.withValues(alpha: 0.42),
      cellBg: Colors.white.withValues(alpha: 0.07),
      cellBorder: Colors.white.withValues(alpha: 0.12),
      accent: const Color(0xFFFFD54F),
      accentSoft: const Color(0xFFFFD54F).withValues(alpha: 0.15),
      divider: Colors.white.withValues(alpha: 0.07),
      leftRegion: const Color(0xFF64B5F6),
      rightRegion: const Color(0xFFEF5350),
      champBg: const Color(0xFF00E676).withValues(alpha: 0.15),
      champBorder: const Color(0xFF00E676).withValues(alpha: 0.5),
      connectorLine: Colors.white.withValues(alpha: 0.1),
      teamCircleBg: Colors.white.withValues(alpha: 0.07),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF0A0E1A), const Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: posterP.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: posterP.accent.withValues(alpha: 0.1), blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Column(
        children: [
          _buildBmbLogo(posterP),
          const SizedBox(height: 6),
          _buildTitlePlate(posterP),
          const SizedBox(height: 10),
          if (!hasPicks)
            _buildNoPicks(posterP)
          else ...[
            _buildFullBracketTree(picks, teams, totalRounds, posterP),
            const SizedBox(height: 8),
            _buildChampionCallout(picks, totalRounds, posterP),
          ],
          const SizedBox(height: 8),
          Text('WHO YOU GOT?', style: TextStyle(
            color: posterP.secondary,
            fontSize: 8, fontWeight: BmbFontWeights.bold,
            fontFamily: 'ClashDisplay', letterSpacing: 2)),
          const SizedBox(height: 3),
          Text(_bracketDateStamp, style: TextStyle(
            color: posterP.tertiary,
            fontSize: 7, fontWeight: BmbFontWeights.bold,
            fontFamily: 'ClashDisplay', letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text('BACKMYBRACKET.COM', style: TextStyle(
            color: posterP.tertiary, fontSize: 7, letterSpacing: 2.0)),
        ],
      ),
    );
  }

  /// Champion callout badge — shield icon + name (no trophy).
  Widget _buildChampionCallout(List<String> picks, int totalRounds, _ApparelPalette p) {
    final champion = picks.isNotEmpty ? picks.last : 'TBD';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          p.accentSoft,
          p.accentSoft.withValues(alpha: 0.02),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.accent.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/images/splash_dark.png',
              width: 20, height: 20,
              errorBuilder: (_, __, ___) => Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      p.accent.withValues(alpha: 0.3),
                      p.accent.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.shield, color: p.accent, size: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHAMPION PICK', style: TextStyle(
                color: p.accent.withValues(alpha: 0.6),
                fontSize: 6, fontWeight: BmbFontWeights.bold,
                letterSpacing: 1.0)),
              Text(champion.toUpperCase(), style: TextStyle(
                color: p.accent, fontSize: 12,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay', letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  List<List<_MatchupData>> _reconstructHalfBracket(
      List<String> picks, List<String> teams, int halfRounds) {
    if (picks.isEmpty || teams.isEmpty) return [];
    final rounds = <List<_MatchupData>>[];
    int pickIdx = 0;
    int matchupsInRound = teams.length ~/ 2;
    List<String> currentSlots = List<String>.from(teams);

    for (int r = 0; r < halfRounds && pickIdx < picks.length; r++) {
      final roundMatchups = <_MatchupData>[];
      final nextSlots = <String>[];
      for (int m = 0; m < matchupsInRound && pickIdx < picks.length; m++) {
        final t1 = m * 2 < currentSlots.length ? currentSlots[m * 2] : '???';
        final t2 = m * 2 + 1 < currentSlots.length ? currentSlots[m * 2 + 1] : '???';
        final winner = picks[pickIdx];
        roundMatchups.add(_MatchupData(team1: t1, team2: t2, winner: winner));
        nextSlots.add(winner);
        pickIdx++;
      }
      rounds.add(roundMatchups);
      currentSlots = nextSlots;
      matchupsInRound = (matchupsInRound / 2).ceil();
    }
    if (rounds.length > 4) return rounds.sublist(rounds.length - 4);
    return rounds;
  }

  String _truncateName(String name, {int maxLen = 10}) {
    final clean = name.replaceAll(RegExp(r'^\(\d+\)\s*'), '');
    return clean.length > maxLen ? '${clean.substring(0, maxLen - 1)}\u2026' : clean;
  }

  int _computeTotalRounds(int teamCount) {
    int n = teamCount;
    int rounds = 0;
    while (n > 1) { n = (n / 2).ceil(); rounds++; }
    return rounds;
  }

  IconData _productIcon(String iconName) {
    switch (iconName) {
      case 'photo_size_select_large': return Icons.photo_size_select_large;
      case 'wallpaper': return Icons.wallpaper;
      case 'dry_cleaning': return Icons.dry_cleaning;
      case 'checkroom': return Icons.checkroom;
      case 'coffee': return Icons.coffee;
      default: return Icons.shopping_bag;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════════════

/// Full color palette for contrast-aware apparel rendering.
class _ApparelPalette {
  final Color garment;         // The garment base color
  final bool isDark;           // Whether this is a dark garment
  final Color primary;         // Main text color
  final Color secondary;       // Secondary text
  final Color tertiary;        // Subtle text / borders
  final Color winnerBg;        // Winner cell background
  final Color winnerText;      // Winner text color
  final Color winnerGlow;      // Glow shadow for winners
  final Color loserText;       // Loser/dimmed text
  final Color cellBg;          // Matchup cell background
  final Color cellBorder;      // Matchup cell border
  final Color accent;          // Gold/accent color (titles, branding)
  final Color accentSoft;      // Soft accent bg
  final Color divider;         // Thin separator lines
  final Color leftRegion;      // Left bracket region label color
  final Color rightRegion;     // Right bracket region label color
  final Color champBg;         // Champion badge background
  final Color champBorder;     // Champion badge border
  final Color connectorLine;   // Connector lines between rounds
  final Color teamCircleBg;    // Default team circle background

  const _ApparelPalette({
    required this.garment,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.winnerBg,
    required this.winnerText,
    required this.winnerGlow,
    required this.loserText,
    required this.cellBg,
    required this.cellBorder,
    required this.accent,
    required this.accentSoft,
    required this.divider,
    required this.leftRegion,
    required this.rightRegion,
    required this.champBg,
    required this.champBorder,
    required this.connectorLine,
    required this.teamCircleBg,
  });
}

/// Data holder for a single matchup in the bracket tree rendering.
class _MatchupData {
  final String team1;
  final String team2;
  final String winner;
  const _MatchupData({required this.team1, required this.team2, required this.winner});
}
