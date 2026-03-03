import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/print_product_catalog.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/bracket_print_order_service.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/merch_preview_service.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/print_shop_delivery_service.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/widgets/bracket_composite_preview.dart';

/// Full "Back It" flow: Product → Color → Style → Preview → Size → Shipping → Checkout
class BackItFlowScreen extends StatefulWidget {
  final String bracketId;
  final String bracketTitle;
  final String championName;
  final int teamCount;
  final List<String> teams;
  final Map<String, String> picks;

  const BackItFlowScreen({
    super.key,
    required this.bracketId,
    required this.bracketTitle,
    required this.championName,
    required this.teamCount,
    required this.teams,
    required this.picks,
  });

  @override
  State<BackItFlowScreen> createState() => _BackItFlowScreenState();
}

class _BackItFlowScreenState extends State<BackItFlowScreen> {
  // Flow state
  int _step = 0; // 0=Product, 1=Color, 2=Style, 3=Preview, 4=Size+Shipping, 5=Confirm, 6=Done

  // Selections
  PrintProduct? _selectedProduct;
  GarmentColor? _selectedColor;
  BracketPrintStyle _selectedStyle = BracketPrintStyle.classic;
  String? _selectedSize;
  bool _expressShipping = false;

  // Shipping form
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Order state
  bool _isSubmitting = false;
  bool _agreedToTerms = false;
  BracketPrintOrder? _completedOrder;

  // Pre-cached from preview step (server returns artifactId in the binary response headers)
  String? _previewArtifactId;

  // Print shop delivery result
  PrintShopDeliveryResult? _printShopDeliveryResult;

  // Product detail expansion
  final Set<String> _expandedProducts = {};

  final _products = PrintProductCatalog.printableProducts;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
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
              if (_step < 6) _buildProgressBar(),
              Expanded(child: _buildStep()),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          if (_step > 0 && _step < 6)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
              onPressed: _prevStep,
            )
          else
            IconButton(
              icon: const Icon(Icons.close, color: BmbColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFD63031), Color(0xFFFF6B6B)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.print, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _step < 6 ? 'Back It — Print Your Bracket' : 'Order Confirmed!',
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 15,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PROGRESS BAR ──────────────────────────────────────────────
  Widget _buildProgressBar() {
    final labels = ['Product', 'Color', 'Style', 'Preview', 'Details', 'Confirm'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isDone
                          ? BmbColors.gold
                          : isActive
                              ? BmbColors.blue
                              : BmbColors.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: isActive ? BmbColors.textPrimary : BmbColors.textTertiary,
                      fontSize: 8,
                      fontWeight: isActive ? BmbFontWeights.bold : BmbFontWeights.medium,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── STEP ROUTER ───────────────────────────────────────────────
  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildProductStep();
      case 1: return _buildColorStep();
      case 2: return _buildStyleStep();
      case 3: return _buildPreviewStep();
      case 4: return _buildDetailsStep();
      case 5: return _buildConfirmStep();
      case 6: return _buildDoneStep();
      default: return const SizedBox();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 0: SELECT PRODUCT
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProductStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Choose Your Product', 'Select a garment for your bracket print'),
          const SizedBox(height: 12),
          ..._products.map((p) => _productCard(p)),
        ],
      ),
    );
  }

  Widget _productCard(PrintProduct product) {
    final isSelected = _selectedProduct?.id == product.id;
    final isExpanded = _expandedProducts.contains(product.id);
    final details = product.details;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? BmbColors.gold : BmbColors.borderColor,
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── Main product row (tap to select) ──
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedProduct = product;
                _selectedColor = product.colors.first;
              });
              _nextStep();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: BmbColors.cardDark, borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(product.frontImageUrl, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, color: BmbColors.textTertiary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.shortTitle, style: TextStyle(
                          color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                        const SizedBox(height: 2),
                        Text(product.description, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(children: [
                          Text('\$${product.basePrice.toStringAsFixed(0)}', style: TextStyle(
                            color: BmbColors.textSecondary, fontSize: 12, fontWeight: BmbFontWeights.medium,
                            decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: BmbColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text('\$${product.totalPrice.toStringAsFixed(0)} with print', style: TextStyle(
                              color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('${product.colors.length} colors', style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
                          const SizedBox(width: 8),
                          ...product.colors.take(6).map((c) => Container(
                            width: 12, height: 12, margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(color: c.color, shape: BoxShape.circle,
                                border: Border.all(color: BmbColors.borderColor, width: 0.5)))),
                          if (product.colors.length > 6)
                            Text('+${product.colors.length - 6}',
                                style: TextStyle(color: BmbColors.textTertiary, fontSize: 8)),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: BmbColors.textTertiary, size: 20),
                ],
              ),
            ),
          ),

          // ── Expand/Collapse toggle bar ──
          GestureDetector(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedProducts.remove(product.id);
              } else {
                _expandedProducts.add(product.id);
              }
            }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: BmbColors.borderColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(isExpanded ? 0 : 14),
                  bottomRight: Radius.circular(isExpanded ? 0 : 14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: BmbColors.textTertiary, size: 13),
                  const SizedBox(width: 6),
                  Text(isExpanded ? 'Hide Details' : 'Product Details, Size Chart & Care',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.medium)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: BmbColors.textTertiary, size: 16),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded details panel ──
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildExpandedDetails(product, details),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(PrintProduct product, ProductDetails details) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── DESCRIPTION ──
          _detailSectionTitle('DESCRIPTION'),
          const SizedBox(height: 4),
          Text(details.fullDescription, style: TextStyle(
            color: BmbColors.textSecondary, fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),

          // ── FEATURES ──
          _detailSectionTitle('FEATURES'),
          const SizedBox(height: 4),
          ...details.features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.check_circle, color: BmbColors.successGreen, size: 10)),
              const SizedBox(width: 6),
              Expanded(child: Text(f, style: TextStyle(color: BmbColors.textSecondary, fontSize: 10, height: 1.3))),
            ]),
          )),
          const SizedBox(height: 10),

          // ── SIZE CHART ──
          _detailSectionTitle('SIZE CHART'),
          const SizedBox(height: 6),
          _buildSizeChart(details),
          const SizedBox(height: 10),

          // ── CARE INSTRUCTIONS ──
          _detailSectionTitle('CARE INSTRUCTIONS'),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.local_laundry_service, color: BmbColors.textTertiary, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(details.fabricCare, style: TextStyle(
              color: BmbColors.textSecondary, fontSize: 10, height: 1.4))),
          ]),
        ],
      ),
    );
  }

  Widget _detailSectionTitle(String title) {
    return Text(title, style: TextStyle(
      color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5));
  }

  Widget _buildSizeChart(ProductDetails details) {
    final sizes = details.sizeChart;
    if (sizes.isEmpty) return const SizedBox();
    // Get measurement keys from first entry
    final keys = sizes.values.first.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: BmbColors.borderColor.withValues(alpha: 0.3), width: 0.5),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.08)),
            children: [
              _sizeCell('Size', isHeader: true),
              ...keys.map((k) => _sizeCell(k, isHeader: true)),
            ],
          ),
          // Data rows
          ...sizes.entries.map((e) => TableRow(
            children: [
              _sizeCell(e.key, isHeader: true),
              ...keys.map((k) => _sizeCell(e.value[k] ?? '-')),
            ],
          )),
        ],
      ),
    );
  }

  Widget _sizeCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(text, style: TextStyle(
        color: isHeader ? BmbColors.textPrimary : BmbColors.textSecondary,
        fontSize: 9,
        fontWeight: isHeader ? BmbFontWeights.bold : BmbFontWeights.regular,
      )),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 1: SELECT COLOR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildColorStep() {
    if (_selectedProduct == null) return const SizedBox();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Choose Color', _selectedProduct!.shortTitle),
          const SizedBox(height: 12),
          // Color grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _selectedProduct!.colors.map((c) {
              final isSelected = _selectedColor?.name == c.name;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedColor = c);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: (MediaQuery.of(context).size.width - 52) / 3,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: BmbColors.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? BmbColors.gold : BmbColors.borderColor,
                      width: isSelected ? 2 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: c.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: BmbColors.borderColor),
                          boxShadow: isSelected
                              ? [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.3), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: c.isDark ? Colors.white : Colors.black, size: 20)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.name,
                        style: TextStyle(
                          color: isSelected ? BmbColors.gold : BmbColors.textSecondary,
                          fontSize: 9,
                          fontWeight: BmbFontWeights.semiBold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            c.isDark ? 'White print' : 'Dark print',
                            style: TextStyle(color: BmbColors.textTertiary, fontSize: 7),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Continue button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedColor != null ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Continue', style: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 2: SELECT PRINT STYLE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Choose Bracket Style', 'How should your bracket look on the garment?'),
          const SizedBox(height: 12),
          ...BracketPrintStyle.values.map((style) {
            final isSelected = _selectedStyle == style;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedStyle = style);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? BmbColors.gold : BmbColors.borderColor,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? BmbColors.gold.withValues(alpha: 0.15)
                            : BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        style == BracketPrintStyle.classic
                            ? Icons.account_tree
                            : style == BracketPrintStyle.premium
                                ? Icons.star
                                : Icons.bolt,
                        color: isSelected ? BmbColors.gold : BmbColors.textTertiary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.displayName,
                            style: TextStyle(
                              color: isSelected ? BmbColors.gold : BmbColors.textPrimary,
                              fontSize: 15,
                              fontWeight: BmbFontWeights.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            style.description,
                            style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: BmbColors.gold, size: 22),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('See Preview', style: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 3: MOCKUP PREVIEW
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPreviewStep() {
    if (_selectedProduct == null || _selectedColor == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionTitle('Your Bracket on ${_selectedProduct!.shortTitle}',
              '${_selectedColor!.name} | ${_selectedStyle.displayName} style'),
          const SizedBox(height: 12),

          // ── PRINT-SAFE PREVIEW (CustomPainter bracket clipped to garment mask) ──
          BracketCompositePreview(
            productId: _selectedProduct!.id,
            garmentColor: _selectedColor!,
            productType: _selectedProduct!.type,
            teamCount: widget.teamCount,
            bracketTitle: widget.bracketTitle,
            championName: widget.championName,
            teams: widget.teams,
            picks: widget.picks,
            printStyle: _selectedStyle,
            product: _selectedProduct,
            garmentImageUrl: _selectedProduct!.colorImageUrls[_selectedColor!.name]
                ?? _selectedProduct!.frontImageUrl,
            backImageAsset: _selectedProduct!.backImageAsset,
            onArtifactReady: (artifactId, _) {
              _previewArtifactId = artifactId;
            },
          ),
          const SizedBox(height: 12),

          // Info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.borderColor, width: 0.5),
            ),
            child: Column(
              children: [
                _previewInfoRow(Icons.account_tree, 'Bracket', '${widget.bracketTitle} (${widget.teamCount}-team)'),
                _previewInfoRow(Icons.emoji_events, 'Champion', widget.championName),
                _previewInfoRow(Icons.palette, 'Print Color', _selectedColor!.isDark ? 'White on dark' : 'Dark on light'),
                _previewInfoRow(Icons.style, 'Style', _selectedStyle.displayName),
                _previewInfoRow(Icons.straighten, 'Print Area', PrintProduct.printAreaForTeamCount(widget.teamCount).label),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _prevStep,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BmbColors.textSecondary,
                      side: const BorderSide(color: BmbColors.borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Change Style', style: TextStyle(fontWeight: BmbFontWeights.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Looks Good!', style: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: BmbColors.textTertiary, size: 14),
          const SizedBox(width: 8),
          Text('$label:', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.medium)),
          const Spacer(),
          Text(value, style: TextStyle(color: BmbColors.textPrimary, fontSize: 10, fontWeight: BmbFontWeights.semiBold)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 4: SIZE + SHIPPING
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Size & Shipping', 'Almost there!'),
          const SizedBox(height: 12),
          // Size selector
          Text('SIZE', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: (_selectedProduct?.sizes ?? []).map((size) {
              final isSelected = _selectedSize == size;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedSize = size);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52, height: 42,
                  decoration: BoxDecoration(
                    color: isSelected ? BmbColors.gold.withValues(alpha: 0.15) : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? BmbColors.gold : BmbColors.borderColor,
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(size,
                      style: TextStyle(
                        color: isSelected ? BmbColors.gold : BmbColors.textSecondary,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Shipping form
          Text('SHIPPING ADDRESS', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _formField(_nameCtrl, 'Full Name', Icons.person),
          _formField(_addressCtrl, 'Street Address', Icons.home),
          Row(
            children: [
              Expanded(flex: 2, child: _formField(_cityCtrl, 'City', Icons.location_city)),
              const SizedBox(width: 8),
              Expanded(child: _formField(_stateCtrl, 'State', Icons.map)),
              const SizedBox(width: 8),
              Expanded(child: _formField(_zipCtrl, 'ZIP', Icons.pin)),
            ],
          ),
          _formField(_emailCtrl, 'Email', Icons.email),
          _formField(_phoneCtrl, 'Phone', Icons.phone),
          const SizedBox(height: 12),
          // Shipping method
          Text('SHIPPING METHOD', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _shippingOption('Standard', '\$${PrintProductCatalog.standardShipping.toStringAsFixed(2)}', '5-7 business days', false),
          _shippingOption('Express', '\$${PrintProductCatalog.expressShipping.toStringAsFixed(2)}', '2-3 business days', true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _canProceedToConfirm() ? _nextStep : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Review Order', style: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        style: TextStyle(color: BmbColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
          prefixIcon: Icon(icon, color: BmbColors.textTertiary, size: 18),
          filled: true,
          fillColor: BmbColors.cardDark,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: BmbColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: BmbColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: BmbColors.gold),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _shippingOption(String label, String price, String time, bool isExpress) {
    final isSelected = _expressShipping == isExpress;
    return GestureDetector(
      onTap: () => setState(() => _expressShipping = isExpress),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? BmbColors.gold : BmbColors.borderColor,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(isExpress ? Icons.local_shipping : Icons.inventory_2,
                color: isSelected ? BmbColors.gold : BmbColors.textTertiary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                  Text(time, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                ],
              ),
            ),
            Text(price, style: TextStyle(color: isSelected ? BmbColors.gold : BmbColors.textSecondary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
          ],
        ),
      ),
    );
  }

  bool _canProceedToConfirm() {
    return _selectedSize != null &&
        _nameCtrl.text.trim().isNotEmpty &&
        _addressCtrl.text.trim().isNotEmpty &&
        _cityCtrl.text.trim().isNotEmpty &&
        _stateCtrl.text.trim().isNotEmpty &&
        _zipCtrl.text.trim().isNotEmpty &&
        _emailCtrl.text.trim().isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 5: ORDER CONFIRMATION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildConfirmStep() {
    if (_selectedProduct == null || _selectedColor == null) return const SizedBox();
    final pricing = BracketPrintOrderService.calculatePricing(
      product: _selectedProduct!,
      expressShipping: _expressShipping,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Confirm Order', 'Review your order details'),
          const SizedBox(height: 12),
          // Order summary card
          Container(
            width: double.infinity,
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
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: _selectedColor!.color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BmbColors.borderColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedProduct!.shortTitle,
                              style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                          Text('${_selectedColor!.name} | Size $_selectedSize',
                              style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
                          Text('${_selectedStyle.displayName} bracket print',
                              style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: BmbColors.borderColor, height: 24),
                _pricingRow('Garment', '\$${pricing.basePrice.toStringAsFixed(2)}'),
                _pricingRow('Bracket Print', '+\$${pricing.printUpcharge.toStringAsFixed(2)}'),
                _pricingRow('Shipping', pricing.isFreeShipping ? 'FREE' : '\$${pricing.shipping.toStringAsFixed(2)}'),
                _pricingRow('Tax', '\$${pricing.tax.toStringAsFixed(2)}'),
                const Divider(color: BmbColors.borderColor, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL', style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                    Text('\$${pricing.total.toStringAsFixed(2)}',
                        style: TextStyle(color: BmbColors.gold, fontSize: 18, fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Shipping address card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BmbColors.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SHIP TO', style: TextStyle(color: BmbColors.textTertiary, fontSize: 9, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Text(_nameCtrl.text, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                Text(_addressCtrl.text, style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
                Text('${_cityCtrl.text}, ${_stateCtrl.text} ${_zipCtrl.text}',
                    style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ─── SALES POLICY & LEGAL APPROVAL ──────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BmbColors.errorRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BmbColors.errorRed.withValues(alpha: 0.25), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel, color: BmbColors.errorRed, size: 16),
                    const SizedBox(width: 8),
                    Text('SALES POLICY', style: TextStyle(
                      color: BmbColors.errorRed,
                      fontSize: 10,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 1.5,
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'All sales are final. Because each item is custom-printed '
                  'with your personal bracket picks, we cannot accept returns, '
                  'exchanges, or issue refunds once your order is placed.',
                  style: TextStyle(
                    color: BmbColors.textSecondary,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please double-check your product, color, size, and shipping '
                  'details above before proceeding.',
                  style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                // Checkbox agreement
                GestureDetector(
                  onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: _agreedToTerms
                              ? BmbColors.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: _agreedToTerms
                                ? BmbColors.gold
                                : BmbColors.textTertiary,
                            width: 1.5,
                          ),
                        ),
                        child: _agreedToTerms
                            ? const Icon(Icons.check, color: Colors.black, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'I understand that all sales are final. '
                          'No refunds or exchanges will be provided '
                          'for custom-printed merchandise.',
                          style: TextStyle(
                            color: _agreedToTerms
                                ? BmbColors.textPrimary
                                : BmbColors.textSecondary,
                            fontSize: 11,
                            fontWeight: _agreedToTerms
                                ? BmbFontWeights.semiBold
                                : BmbFontWeights.regular,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Place Order button — disabled until terms agreed
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: (_isSubmitting || !_agreedToTerms) ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD63031),
                foregroundColor: Colors.white,
                disabledBackgroundColor: BmbColors.borderColor,
                disabledForegroundColor: BmbColors.textTertiary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_agreedToTerms)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.lock, size: 16, color: BmbColors.textTertiary),
                          ),
                        Text(
                          _agreedToTerms
                              ? 'Place Order — \$${pricing.total.toStringAsFixed(2)}'
                              : 'Agree to terms to continue',
                          style: TextStyle(
                            fontWeight: BmbFontWeights.bold,
                            fontSize: _agreedToTerms ? 16 : 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Secure checkout powered by Stripe',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    setState(() => _isSubmitting = true);
    try {
      // ── SANITIZE: strip all UI-only state before server/checkout calls ──
      // The sanitizer removes selected/hovered/active/focused/highlight
      // flags, color overrides, and any other UI-only keys from the
      // picks map. Only clean team names and bracket structure survive.
      final sanitized = sanitizeBracketForPrint(
        teamCount: widget.teamCount,
        bracketTitle: widget.bracketTitle,
        championName: widget.championName,
        teams: widget.teams,
        picks: widget.picks,
        style: _selectedStyle,
      );

      // ── Step 1: Generate server preview to ensure bracket files exist ──
      // This creates the SVG + print-ready PNG on the server,
      // which will be used when the Shopify webhook fires after payment.
      final previewResult = await MerchPreviewService.generatePreview(
        bracketTitle: sanitized.bracketTitle,
        championName: sanitized.championName,
        teamCount: sanitized.teamCount,
        teams: sanitized.teams,
        picks: sanitized.picks,
        style: _selectedStyle.name,
        productId: _selectedProduct!.id,
        colorName: _selectedColor!.name,
        isDarkGarment: _selectedColor!.isDark,
      );

      // Store preview ID for webhook retrieval (bracket_id on the Shopify line item)
      final bracketId = previewResult.isServerRendered
          ? (previewResult.previewId ?? widget.bracketId)
          : widget.bracketId;

      // Capture artifact ID for pre-generated file lookup by webhook.
      // Prefer the freshly-returned one; fall back to the preview-step cache.
      final artifactId = previewResult.isServerRendered
          ? previewResult.artifactId
          : _previewArtifactId;

      // Capture preview URL for line-item property (webhook can reference it)
      final previewUrl = previewResult.isServerRendered
          ? previewResult.previewUrl
          : null;

      // ── Step 2: Build Shopify checkout URL with bracket_id + artifact_id ──
      // When the customer completes checkout on Shopify, the "orders/paid" webhook
      // fires. Our server loads pre-generated files by artifact_id (or regenerates
      // if missing), creates a packing slip PDF, and delivers all attachments to
      // the printer (bracket.svg, print_ready_rgb.png, print_ready_cmyk.pdf,
      // packing_slip.pdf) via configured delivery methods (email/folder/sftp).
      final shopifyUrl = MerchPreviewService.buildShopifyCheckoutUrl(
        productId: _selectedProduct!.id,
        bracketId: bracketId,
        bracketTitle: sanitized.bracketTitle,
        championName: sanitized.championName,
        teamCount: sanitized.teamCount,
        teams: sanitized.teams,
        picks: sanitized.picks,
        printStyle: _selectedStyle.name,
        colorName: _selectedColor!.name,
        size: _selectedSize!,
        isDarkGarment: _selectedColor!.isDark,
        artifactId: artifactId,
        previewUrl: previewUrl,
      );

      // ── Step 3: Launch Shopify checkout in browser ──
      final uri = Uri.parse(shopifyUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // ── Step 4: Submit order internally for local tracking ──
      final order = await BracketPrintOrderService.submitOrder(
        bracketId: bracketId,
        bracketTitle: sanitized.bracketTitle,
        championName: sanitized.championName,
        teamCount: sanitized.teamCount,
        product: _selectedProduct!,
        selectedColor: _selectedColor!,
        selectedSize: _selectedSize!,
        printStyle: _selectedStyle,
        picks: sanitized.picks,
        teams: sanitized.teams,
        shippingName: _nameCtrl.text.trim(),
        shippingAddress: _addressCtrl.text.trim(),
        shippingCity: _cityCtrl.text.trim(),
        shippingState: _stateCtrl.text.trim(),
        shippingZip: _zipCtrl.text.trim(),
        shippingEmail: _emailCtrl.text.trim(),
        shippingPhone: _phoneCtrl.text.trim(),
        expressShipping: _expressShipping,
      );

      // ── Step 5: Deliver order to print shop ──
      // Sends the order details + print-ready file URLs to the
      // local print shop via server/EmailJS/mailto.
      PrintShopDeliveryResult? deliveryResult;
      try {
        deliveryResult = await PrintShopDeliveryService.instance.deliverOrder(
          order: order,
          teams: sanitized.teams,
          previewResult: previewResult,
        );
      } catch (e) {
        // Print shop delivery failure should NOT block order success.
        // The order is already placed with Shopify.
        if (kDebugMode) {
          debugPrint('[BackItFlow] Print shop delivery failed (non-blocking): $e');
        }
      }

      if (mounted) {
        setState(() {
          _completedOrder = order;
          _printShopDeliveryResult = deliveryResult;
          _isSubmitting = false;
          _step = 6;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order failed: $e'), backgroundColor: BmbColors.errorRed),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 6: ORDER COMPLETE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDoneStep() {
    if (_completedOrder == null) return const SizedBox();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Big success icon
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [BmbColors.successGreen.withValues(alpha: 0.20), BmbColors.gold.withValues(alpha: 0.10)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.check_circle, color: BmbColors.successGreen, size: 54),
          ),
          const SizedBox(height: 16),
          Text('Thank You for Your Order!', style: TextStyle(
            color: BmbColors.textPrimary, fontSize: 22, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
          ), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Your custom bracket print is on its way',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
          const SizedBox(height: 18),

          // Order details card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('ORDER #${_completedOrder!.orderId}',
                    style: TextStyle(color: BmbColors.gold, fontSize: 16, fontWeight: BmbFontWeights.bold, letterSpacing: 2)),
                const SizedBox(height: 12),
                _confirmRow('Product', _completedOrder!.product.shortTitle),
                _confirmRow('Color', _completedOrder!.selectedColor.name),
                _confirmRow('Size', _completedOrder!.selectedSize),
                _confirmRow('Style', _completedOrder!.printStyle.displayName),
                _confirmRow('Bracket', '${_completedOrder!.bracketTitle} (${_completedOrder!.teamCount}-team)'),
                _confirmRow('Champion', _completedOrder!.championName),
                const Divider(color: BmbColors.borderColor, height: 20),
                _confirmRow('Total Charged', '\$${_completedOrder!.total.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Confirmation email card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BmbColors.successGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.mark_email_read, color: BmbColors.successGreen, size: 20),
                    const SizedBox(width: 8),
                    Text('Confirmation Email Sent', style: TextStyle(
                      color: BmbColors.successGreen, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'A detailed order confirmation has been sent to:',
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email, color: BmbColors.successGreen, size: 14),
                      const SizedBox(width: 6),
                      Text(_emailCtrl.text,
                          style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your email includes your order number, product details, '
                  'shipping address, and estimated delivery timeline.',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Print shop delivery status card
          _buildPrintShopDeliveryCard(),
          const SizedBox(height: 12),

          // Shipping estimate
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.borderColor, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: BmbColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated Delivery', style: TextStyle(
                          color: BmbColors.textSecondary, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                      Text(
                        _completedOrder!.shippingCost > 6.0
                            ? '2-3 business days (Express)'
                            : '5-7 business days (Standard)',
                        style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold),
                      ),
                    ],
                  ),
                ),
                Text(
                  _completedOrder!.shippingName.split(' ').first,
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Done', style: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
          Text('Thank you for backing your bracket!',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
          Text(value, style: TextStyle(color: BmbColors.textPrimary, fontSize: 11, fontWeight: BmbFontWeights.semiBold)),
        ],
      ),
    );
  }

  // ─── PRINT SHOP DELIVERY STATUS CARD ────────────────────────
  Widget _buildPrintShopDeliveryCard() {
    final delivered = _printShopDeliveryResult?.success == true;
    final method = _printShopDeliveryResult?.method ?? 'none';

    // Determine status colour and icon
    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusMessage;

    if (delivered) {
      statusColor = BmbColors.successGreen;
      statusIcon = Icons.print;
      statusTitle = 'Print Shop Notified';
      switch (method) {
        case 'server':
          statusMessage =
              'Your bracket design and print-ready files have been delivered '
              'directly to our printing partner. '
              'Production will begin shortly.';
          break;
        case 'emailjs':
          statusMessage =
              'A fulfillment order with your bracket design, print-ready files, '
              'and garment specifications has been emailed to our printing partner '
              '(${PrintShopDeliveryService.printerRecipients.first}). '
              'Production will begin shortly.';
          break;
        case 'mailto':
          statusMessage =
              'An order email was prepared for our printing partner. '
              'Please confirm the email was sent from your email client. '
              'Production begins once the printer confirms receipt.';
          break;
        default:
          statusMessage =
              'Our printing partner has been notified about your order.';
      }
    } else {
      statusColor = BmbColors.gold;
      statusIcon = Icons.hourglass_top;
      statusTitle = 'Printer Delivery Pending';
      statusMessage =
          'Your order was placed successfully. Our team will deliver the '
          'bracket design files to the print shop manually. '
          'You\'ll receive a shipping notification once your order ships.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(statusTitle, style: TextStyle(
                  color: statusColor, fontSize: 13,
                  fontWeight: BmbFontWeights.bold,
                )),
              ),
              if (delivered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    method == 'server' ? 'Auto' : 'Email',
                    style: TextStyle(
                      color: statusColor, fontSize: 9,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusMessage,
            style: TextStyle(
              color: BmbColors.textSecondary, fontSize: 10, height: 1.5,
            ),
          ),

          // Show delivery details if successful
          if (delivered && _printShopDeliveryResult!.serverDeliveryId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.confirmation_number, color: statusColor, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'Delivery ID: ${_printShopDeliveryResult!.serverDeliveryId}',
                    style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Show files sent
          if (delivered &&
              _printShopDeliveryResult!.filesSent != null &&
              _printShopDeliveryResult!.filesSent!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _printShopDeliveryResult!.filesSent!.map((file) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(file, style: TextStyle(
                    color: BmbColors.blue, fontSize: 9,
                    fontFamily: 'monospace',
                  )),
                );
              }).toList(),
            ),
          ],

          // Tracking link reminder
          const SizedBox(height: 10),
          Text(
            'You\'ll receive a shipping notification with tracking info once your order ships.',
            style: TextStyle(
              color: BmbColors.textTertiary, fontSize: 9,
              fontStyle: FontStyle.italic, height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────
  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
          color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
        )),
        Text(subtitle, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
      ],
    );
  }
}
