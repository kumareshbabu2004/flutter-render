import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/store/data/models/store_models.dart';
import 'package:bmb_mobile/features/store/data/services/store_service.dart';
import 'package:bmb_mobile/features/bmb_bucks/presentation/screens/bmb_bucks_purchase_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final StoreProduct product;
  const ProductDetailScreen({super.key, required this.product});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  double _balance = 0;
  bool _redeeming = false;
  String? _selectedSize;
  String? _selectedColor;
  String? _selectedBracketId;
  String? _selectedBracketName;

  // Mock user brackets for custom bracket products
  final _userBrackets = [
    {'id': 'b_1', 'name': 'March Madness 2025'},
    {'id': 'b_2', 'name': 'NFL Playoff Picks'},
    {'id': 'b_3', 'name': 'NBA All-Star Bracket'},
  ];

  StoreProduct get product => widget.product;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    if (product.sizes != null && product.sizes!.isNotEmpty) {
      _selectedSize = product.sizes![1]; // default M
    }
    if (product.colors != null && product.colors!.isNotEmpty) {
      _selectedColor = product.colors![0];
    }
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _balance = prefs.getDouble('bmb_bucks_balance') ?? 0);
  }

  bool get _canAfford => _balance >= product.creditsCost;

  bool get _canRedeem {
    if (!_canAfford) return false;
    if (product.requiresShipping) {
      if (product.sizes != null && _selectedSize == null) return false;
      if (product.colors != null && _selectedColor == null) return false;
    }
    if (product.type == ProductType.customBracketPrint &&
        _selectedBracketId == null) {
      return false;
    }
    return true;
  }

  Future<void> _redeemProduct() async {
    // Show confirmation dialog first
    final confirmed = await _showRedeemConfirmation();
    if (confirmed != true) return;

    setState(() => _redeeming = true);
    await Future.delayed(const Duration(seconds: 2)); // simulate processing

    final order = await StoreService.instance.redeemProduct(
      product: product,
      selectedSize: _selectedSize,
      selectedColor: _selectedColor,
      bracketId: _selectedBracketId,
      bracketName: _selectedBracketName,
    );

    if (!mounted) return;
    setState(() => _redeeming = false);

    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Redemption failed. Not enough credits.'),
          backgroundColor: BmbColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Show success with appropriate info
    if (order.isDigital && order.redemptionCode != null) {
      _showGiftCardSuccess(order);
    } else if (order.isDigital) {
      _showDigitalSuccess(order);
    } else {
      _showPhysicalSuccess(order);
    }

    _loadBalance();
  }

  Future<bool?> _showRedeemConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_cart_checkout,
                    color: BmbColors.gold, size: 30),
              ),
              const SizedBox(height: 14),
              Text('Confirm Redemption',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 16),
              _confirmRow('Product', product.name),
              _confirmRow('Cost', '${product.creditsCost} credits'),
              _confirmRow('Your Bucket', '${_balance.toInt()} credits'),
              _confirmRow('After Redemption',
                  '${(_balance - product.creditsCost).toInt()} credits'),
              if (_selectedSize != null)
                _confirmRow('Size', _selectedSize!),
              if (_selectedColor != null)
                _confirmRow('Color', _selectedColor!),
              if (_selectedBracketName != null)
                _confirmRow('Bracket', _selectedBracketName!),
              const SizedBox(height: 12),
              // Info banner
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
                    const Icon(Icons.info_outline,
                        color: BmbColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          '${product.creditsCost} BMB credits will be deducted from your BMB Bucket.',
                          style: TextStyle(
                              color: BmbColors.gold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              if (product.type == ProductType.digitalGiftCard) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inbox,
                          color: BmbColors.successGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Your gift card code will be delivered to your in-app inbox.',
                            style: TextStyle(
                                color: BmbColors.successGreen, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BmbColors.textSecondary,
                        side: BorderSide(color: BmbColors.borderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Redeem Now',
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
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 13)),
          Flexible(
            child: Text(value,
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 13,
                    fontWeight: BmbFontWeights.semiBold),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  void _showGiftCardSuccess(StoreOrder order) {
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: BmbColors.successGreen, size: 40),
              ),
              const SizedBox(height: 14),
              Text('Gift Card Redeemed!',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 12),
              Text('Your ${product.name} code:',
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              // Code display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: BmbColors.successGreen.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(order.redemptionCode!,
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 16,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay',
                              letterSpacing: 1.5),
                          textAlign: TextAlign.center),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          color: BmbColors.textTertiary, size: 20),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: order.redemptionCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Code copied to clipboard!'),
                            backgroundColor: BmbColors.successGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inbox, color: BmbColors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'This code has also been saved to your in-app inbox for safekeeping.',
                          style: TextStyle(
                              color: BmbColors.blue, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // back to store
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.buttonPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Back to Store',
                      style: TextStyle(fontWeight: BmbFontWeights.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDigitalSuccess(StoreOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome,
                  color: BmbColors.gold, size: 48),
              const SizedBox(height: 14),
              Text('Item Activated!',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 8),
              Text(
                  '${product.name} has been activated on your profile. Check your inbox for details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.buttonPrimary,
                    foregroundColor: Colors.white,
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
      ),
    );
  }

  void _showPhysicalSuccess(StoreOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping,
                  color: BmbColors.blue, size: 48),
              const SizedBox(height: 14),
              Text('Order Placed!',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 8),
              Text(
                  'Your ${product.name} is being processed! We\'ll send tracking info to your inbox once shipped.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Text('Order ID: ${order.id}',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 11)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.buttonPrimary,
                    foregroundColor: Colors.white,
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Product Details',
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 18,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductHero(),
                      const SizedBox(height: 20),
                      _buildInfoSection(),
                      if (product.sizes != null) ...[
                        const SizedBox(height: 20),
                        _buildSizeSelector(),
                      ],
                      if (product.colors != null) ...[
                        const SizedBox(height: 20),
                        _buildColorSelector(),
                      ],
                      if (product.type == ProductType.customBracketPrint) ...[
                        const SizedBox(height: 20),
                        _buildBracketSelector(),
                      ],
                      const SizedBox(height: 24),
                      _buildDeliveryInfo(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildProductHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _catColor.withValues(alpha: 0.15),
            _catColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _catColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _catColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(_icon, color: _catColor, size: 44),
          ),
          const SizedBox(height: 16),
          if (product.brand != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _catColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(product.brand!,
                  style: TextStyle(
                      color: _catColor,
                      fontSize: 11,
                      fontWeight: BmbFontWeights.bold)),
            ),
            const SizedBox(height: 8),
          ],
          Text(product.name,
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 22,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay'),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          if (product.faceValue != null)
            Text('Face Value: \$${product.faceValue!.toStringAsFixed(0)}',
                style: TextStyle(
                    color: BmbColors.successGreen,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 4),
          Text(product.categoryLabel,
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About this product',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 15,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 8),
        Text(product.description,
            style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 13,
                height: 1.5)),
        if (product.shopifyProductId != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront, color: BmbColors.blue, size: 14),
                const SizedBox(width: 4),
                Text('Fulfilled by BMB Store',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 10,
                        fontWeight: BmbFontWeights.medium)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Size',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 14,
                fontWeight: BmbFontWeights.semiBold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: product.sizes!.map((size) {
            final sel = _selectedSize == size;
            return GestureDetector(
              onTap: () => setState(() => _selectedSize = size),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? BmbColors.gold.withValues(alpha: 0.15)
                      : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? BmbColors.gold : BmbColors.borderColor,
                    width: sel ? 1.5 : 0.5,
                  ),
                ),
                child: Text(size,
                    style: TextStyle(
                        color: sel ? BmbColors.gold : BmbColors.textSecondary,
                        fontSize: 13,
                        fontWeight:
                            sel ? BmbFontWeights.bold : BmbFontWeights.medium)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Color',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 14,
                fontWeight: BmbFontWeights.semiBold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: product.colors!.map((color) {
            final sel = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? BmbColors.blue.withValues(alpha: 0.15)
                      : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? BmbColors.blue : BmbColors.borderColor,
                    width: sel ? 1.5 : 0.5,
                  ),
                ),
                child: Text(color,
                    style: TextStyle(
                        color: sel ? BmbColors.blue : BmbColors.textSecondary,
                        fontSize: 13,
                        fontWeight:
                            sel ? BmbFontWeights.bold : BmbFontWeights.medium)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBracketSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Your Bracket',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 14,
                fontWeight: BmbFontWeights.semiBold)),
        const SizedBox(height: 4),
        Text('Choose which bracket picks to print on this product.',
            style: TextStyle(
                color: BmbColors.textTertiary, fontSize: 12)),
        const SizedBox(height: 10),
        ..._userBrackets.map((b) {
          final sel = _selectedBracketId == b['id'];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedBracketId = b['id'];
              _selectedBracketName = b['name'];
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: sel
                    ? LinearGradient(colors: [
                        const Color(0xFF9C27B0).withValues(alpha: 0.15),
                        const Color(0xFF9C27B0).withValues(alpha: 0.05),
                      ])
                    : BmbColors.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel
                      ? const Color(0xFF9C27B0)
                      : BmbColors.borderColor,
                  width: sel ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_tree,
                      color: sel
                          ? const Color(0xFF9C27B0)
                          : BmbColors.textTertiary,
                      size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(b['name']!,
                        style: TextStyle(
                            color: sel
                                ? BmbColors.textPrimary
                                : BmbColors.textSecondary,
                            fontSize: 14,
                            fontWeight: sel
                                ? BmbFontWeights.bold
                                : BmbFontWeights.medium)),
                  ),
                  if (sel)
                    const Icon(Icons.check_circle,
                        color: Color(0xFF9C27B0), size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDeliveryInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Information',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 14,
                  fontWeight: BmbFontWeights.bold)),
          const SizedBox(height: 10),
          if (product.type == ProductType.digitalGiftCard) ...[
            _deliveryRow(Icons.inbox, 'Code delivered to your in-app inbox'),
            _deliveryRow(Icons.bolt, 'Instant delivery'),
            _deliveryRow(Icons.lock, 'Code saved securely in your inbox'),
          ] else if (product.type == ProductType.digitalItem) ...[
            _deliveryRow(Icons.auto_awesome, 'Activated instantly on your profile'),
            _deliveryRow(Icons.inbox, 'Confirmation sent to inbox'),
          ] else ...[
            _deliveryRow(Icons.local_shipping, 'Shipped to your address on file'),
            _deliveryRow(Icons.schedule, 'Processing: 3-5 business days'),
            _deliveryRow(Icons.inbox, 'Tracking info sent to inbox'),
            if (product.shopifyProductId != null)
              _deliveryRow(Icons.storefront, 'Fulfilled via BMB Store (Shopify)'),
          ],
        ],
      ),
    );
  }

  Widget _deliveryRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: BmbColors.textTertiary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy,
        border: Border(
            top:
                BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Price and balance
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.savings,
                          color: BmbColors.gold, size: 18),
                      const SizedBox(width: 4),
                      Text('${product.creditsCost} credits',
                          style: TextStyle(
                              color: BmbColors.gold,
                              fontSize: 18,
                              fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                  Text(
                      _canAfford
                          ? 'Balance: ${_balance.toInt()} credits'
                          : 'Need ${(product.creditsCost - _balance).toInt()} more credits',
                      style: TextStyle(
                          color: _canAfford
                              ? BmbColors.textTertiary
                              : BmbColors.errorRed,
                          fontSize: 11)),
                ],
              ),
            ),
            // Action button
            SizedBox(
              height: 50,
              child: _canAfford
                  ? ElevatedButton.icon(
                      onPressed: _canRedeem && !_redeeming
                          ? _redeemProduct
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.buttonPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: BmbColors.cardDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _redeeming
                          ? const SizedBox.shrink()
                          : const Icon(Icons.shopping_cart_checkout, size: 18),
                      label: _redeeming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Redeem',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: BmbFontWeights.bold)),
                    )
                  : ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const BmbBucksPurchaseScreen()));
                        _loadBalance();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.savings, size: 18),
                      label: Text('Add Credits',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: BmbFontWeights.bold)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _catColor {
    switch (product.category) {
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

  IconData get _icon {
    switch (product.imageIcon) {
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
