import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/bracket_print_renderer.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/print_product_catalog.dart';

/// Service for creating and managing bracket print orders.
/// Handles order number generation, pricing, and order submission.
class BracketPrintOrderService {
  static final _random = Random();

  /// Generate a unique order ID: BMB-YYYY-XXXXX
  static String generateOrderId() {
    final year = DateTime.now().year;
    final seq = _random.nextInt(90000) + 10000;
    return 'BMB-$year-$seq';
  }

  /// Calculate order pricing.
  static OrderPricing calculatePricing({
    required PrintProduct product,
    required bool expressShipping,
  }) {
    final subtotal = product.totalPrice;
    final shipping = expressShipping
        ? PrintProductCatalog.expressShipping
        : (subtotal >= PrintProductCatalog.freeShippingThreshold
            ? 0.0
            : PrintProductCatalog.standardShipping);
    final taxable = subtotal + shipping;
    final tax = taxable * PrintProductCatalog.taxRate;
    final total = taxable + tax;

    return OrderPricing(
      basePrice: product.basePrice,
      printUpcharge: product.bracketPrintUpcharge,
      subtotal: subtotal,
      shipping: shipping,
      tax: double.parse(tax.toStringAsFixed(2)),
      total: double.parse(total.toStringAsFixed(2)),
      isExpressShipping: expressShipping,
      isFreeShipping: shipping == 0,
    );
  }

  /// Generate the print-ready SVG for the printer.
  ///
  /// Uses [sanitizeBracketForPrint] to strip all UI-only state, then
  /// the canonical [renderBracketPrintSvg] entry point which:
  ///   - Asserts data was sanitized.
  ///   - Runs post-sanitization contamination checks.
  ///   - Enforces portrait-only layout.
  ///   - Ensures RGB colour mode.
  ///
  /// Throws [PreviewUiLayerDetected] if any guard fails (fatal post-
  /// sanitization).
  static String generatePrintSvg({
    required int teamCount,
    required String bracketTitle,
    required String championName,
    required Map<String, String> picks,
    required List<String> teams,
    required GarmentColor garmentColor,
    required BracketPrintStyle style,
    String productId = 'bp_grid_iron',
    PrintProductType productType = PrintProductType.hoodie,
  }) {
    // ── SANITIZE: strip UI-only state at the boundary ──────
    final sanitized = sanitizeBracketForPrint(
      teamCount: teamCount,
      bracketTitle: bracketTitle,
      championName: championName,
      picks: picks,
      teams: teams,
      style: style,
    );

    return renderBracketPrintSvg(
      sanitized,
      ProductPrintConfig(
        productId: productId,
        productType: productType,
        garmentColor: garmentColor,
      ),
    );
  }

  /// Submit order (stub — production would hit Stripe + Firestore).
  static Future<BracketPrintOrder> submitOrder({
    required String bracketId,
    required String bracketTitle,
    required String championName,
    required int teamCount,
    required PrintProduct product,
    required GarmentColor selectedColor,
    required String selectedSize,
    required BracketPrintStyle printStyle,
    required Map<String, String> picks,
    required List<String> teams,
    required String shippingName,
    required String shippingAddress,
    required String shippingCity,
    required String shippingState,
    required String shippingZip,
    required String shippingEmail,
    required String shippingPhone,
    required bool expressShipping,
  }) async {
    // Calculate pricing
    final pricing = calculatePricing(
      product: product,
      expressShipping: expressShipping,
    );

    // Generate order ID
    final orderId = generateOrderId();

    if (kDebugMode) {
      debugPrint('[BracketPrintOrder] Creating order $orderId');
      debugPrint('[BracketPrintOrder] Product: ${product.shortTitle} | ${selectedColor.name} | $selectedSize');
      debugPrint('[BracketPrintOrder] Total: \$${pricing.total}');
    }

    // Create order object
    final order = BracketPrintOrder(
      orderId: orderId,
      bracketId: bracketId,
      bracketTitle: bracketTitle,
      championName: championName,
      teamCount: teamCount,
      product: product,
      selectedColor: selectedColor,
      selectedSize: selectedSize,
      printStyle: printStyle,
      picks: picks,
      shippingName: shippingName,
      shippingAddress: shippingAddress,
      shippingCity: shippingCity,
      shippingState: shippingState,
      shippingZip: shippingZip,
      shippingEmail: shippingEmail,
      shippingPhone: shippingPhone,
      subtotal: pricing.subtotal,
      shippingCost: pricing.shipping,
      tax: pricing.tax,
      total: pricing.total,
      createdAt: DateTime.now(),
      status: 'pending',
    );

    // TODO: Production — create Stripe PaymentIntent, charge card
    // TODO: Production — save order to Firestore
    // TODO: Production — send printer email via SendGrid/Cloud Function

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (kDebugMode) {
      debugPrint('[BracketPrintOrder] Order $orderId submitted successfully');
      _logPrinterEmailPreview(order, teams);
    }

    return order;
  }

  /// Log what the printer email would look like (dev mode).
  static void _logPrinterEmailPreview(BracketPrintOrder order, List<String> teams) {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('  PRINTER EMAIL PREVIEW');
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('  TO: jkim@aceusainc.com');
    debugPrint('  CC: ahmad@backmybracket.com, amchi81@gmail.com');
    debugPrint('  SUBJECT: [BMB Order #${order.orderId}] — ${order.product.shortTitle} ${order.selectedColor.name} ${order.selectedSize}');
    debugPrint('');
    debugPrint('  ORDER DETAILS:');
    debugPrint('  Order #:    ${order.orderId}');
    debugPrint('  Product:    ${order.product.title}');
    debugPrint('  Color:      ${order.selectedColor.name}');
    debugPrint('  Size:       ${order.selectedSize}');
    debugPrint('  Print:      Full back — ${order.printStyle.displayName} style');
    debugPrint('  Bracket:    ${order.bracketTitle} (${order.teamCount}-team)');
    debugPrint('  Champion:   ${order.championName}');
    debugPrint('');
    debugPrint('  SHIPPING TO:');
    debugPrint('  ${order.shippingName}');
    debugPrint('  ${order.shippingAddress}');
    debugPrint('  ${order.shippingCity}, ${order.shippingState} ${order.shippingZip}');
    debugPrint('  Email: ${order.shippingEmail}');
    debugPrint('  Phone: ${order.shippingPhone}');
    debugPrint('');
    debugPrint('  PRICING:');
    debugPrint('  Base:     \$${order.product.basePrice.toStringAsFixed(2)}');
    debugPrint('  Print:    +\$${order.product.bracketPrintUpcharge.toStringAsFixed(2)}');
    debugPrint('  Shipping: \$${order.shippingCost.toStringAsFixed(2)}');
    debugPrint('  Tax:      \$${order.tax.toStringAsFixed(2)}');
    debugPrint('  TOTAL:    \$${order.total.toStringAsFixed(2)}');
    debugPrint('');
    debugPrint('  ATTACHMENTS:');
    debugPrint('  1. bracket_${order.orderId}.svg (vector print file)');
    debugPrint('  2. preview_${order.orderId}.png (reference)');
    debugPrint('═══════════════════════════════════════════════');
  }
}

/// Pricing breakdown for an order.
class OrderPricing {
  final double basePrice;
  final double printUpcharge;
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;
  final bool isExpressShipping;
  final bool isFreeShipping;

  const OrderPricing({
    required this.basePrice,
    required this.printUpcharge,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.isExpressShipping,
    required this.isFreeShipping,
  });
}
