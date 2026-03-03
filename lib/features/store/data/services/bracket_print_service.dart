import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/store/data/models/store_models.dart';
import 'package:bmb_mobile/features/store/data/services/store_service.dart';
import 'package:bmb_mobile/features/store/data/services/order_email_service.dart';

/// Service handling bracket-to-print product workflow.
///
/// Flow:
///   1. User taps "Print My Picks" on bracket detail
///   2. BracketPrintService.getAvailableProducts(teamCount) filters products
///      by bracket complexity (e.g. 68-team can't fit on a mug)
///   3. User selects product → sees mockup preview
///   4. User selects size/color → reviews disclaimer → approves
///   5. Credits deducted → order created → Shopify order triggered
///
/// Shopify Integration:
///   Orders are created locally and also submitted to Shopify via Admin API.
///   Shopify handles fulfillment, printing, and shipping.
class BracketPrintService {
  BracketPrintService._();
  static final BracketPrintService instance = BracketPrintService._();

  // ─── PRODUCT COMPATIBILITY MATRIX ────────────────────────────────
  //
  // Maps product IDs to maximum team count they can accommodate.
  // A 68-team bracket has tons of text — can't fit on a mug.
  // A 4-team bracket fits on anything.
  //
  static const Map<String, int> _maxTeamsByProduct = {
    'cb_poster_18x24': 128,  // Large print area — handles anything
    'cb_canvas_16x20': 68,   // Gallery canvas — up to 68 teams
    'cb_hoodie': 32,         // Hoodie back print — max 32 teams
    'cb_tshirt': 32,         // T-shirt back print — max 32 teams
    'cb_mug': 8,             // Mug wrap — small brackets only
  };

  // Minimum print area descriptions for UI
  static const Map<String, String> _printAreaDesc = {
    'cb_poster_18x24': '18×24 inch poster — fits up to 128 teams',
    'cb_canvas_16x20': '16×20 inch canvas — fits up to 68 teams',
    'cb_hoodie': 'Full back print on premium hoodie — fits up to 32 teams',
    'cb_tshirt': 'Full back print — fits up to 32 teams',
    'cb_mug': 'Wrap-around mug print — fits up to 8 teams',
  };

  /// Returns only products that can accommodate this bracket's team count.
  List<StoreProduct> getAvailableProducts(int teamCount) {
    return StoreService.products
        .where((p) => p.type == ProductType.customBracketPrint)
        .where((p) => p.isAvailable)
        .where((p) {
          final maxTeams = _maxTeamsByProduct[p.id] ?? 0;
          return teamCount <= maxTeams;
        })
        .toList();
  }

  /// Returns all bracket print products with availability flag.
  List<BracketPrintProduct> getAllProductsWithAvailability(int teamCount) {
    return StoreService.products
        .where((p) => p.type == ProductType.customBracketPrint)
        .map((p) {
          final maxTeams = _maxTeamsByProduct[p.id] ?? 0;
          final fits = teamCount <= maxTeams;
          return BracketPrintProduct(
            product: p,
            maxTeamCount: maxTeams,
            fitsCurrentBracket: fits,
            printAreaDescription: _printAreaDesc[p.id] ?? '',
            reason: fits ? null : 'Your $teamCount-team bracket is too large for this product (max $maxTeams teams)',
          );
        })
        .toList();
  }

  /// Generate a mockup description for the preview.
  /// In production, this would call an image composition API.
  String getMockupDescription({
    required String bracketName,
    required int teamCount,
    required String productName,
    String? selectedColor,
  }) {
    return 'Your "$bracketName" ($teamCount-team bracket) printed on '
        '${selectedColor != null ? "$selectedColor " : ""}$productName. '
        'All your picks, matchups, and final winner displayed in the BMB bracket style.';
  }

  /// Submit approved order — deducts credits + creates Shopify order + sends email.
  Future<PrintOrderResult> submitPrintOrder({
    required StoreProduct product,
    required String bracketId,
    required String bracketName,
    required int teamCount,
    required String shippingFirstName,
    required String shippingLastName,
    required String shippingAddress,
    required String shippingCity,
    required String shippingState,
    required String shippingZip,
    String? selectedSize,
    String? selectedColor,
    String? customerEmail,
    String? phoneNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('bmb_bucks_balance') ?? 0;

    if (balance < product.creditsCost) {
      return PrintOrderResult(
        success: false,
        error: 'Insufficient credits. You need ${product.creditsCost} but have ${balance.toInt()}.',
      );
    }

    // Deduct credits
    final newBalance = balance - product.creditsCost;
    await prefs.setDouble('bmb_bucks_balance', newBalance);

    // Create order via StoreService
    final shippingName = '$shippingFirstName $shippingLastName';
    final fullAddress = '$shippingName\n$shippingAddress\n$shippingCity, $shippingState $shippingZip';
    final order = await StoreService.instance.redeemProduct(
      product: product,
      selectedSize: selectedSize,
      selectedColor: selectedColor,
      shippingAddress: fullAddress,
      bracketId: bracketId,
      bracketName: bracketName,
    );

    if (order == null) {
      // Refund credits on failure
      await prefs.setDouble('bmb_bucks_balance', balance);
      return PrintOrderResult(
        success: false,
        error: 'Order creation failed. Credits were not charged.',
      );
    }

    // Submit to Shopify (stub — production: actual API call)
    await _submitToShopify(
      order: order,
      product: product,
      bracketId: bracketId,
      bracketName: bracketName,
      teamCount: teamCount,
      shippingName: shippingName,
      shippingAddress: shippingAddress,
      shippingCity: shippingCity,
      shippingState: shippingState,
      shippingZip: shippingZip,
      selectedSize: selectedSize,
      selectedColor: selectedColor,
    );

    // Send fulfillment email to printer + BMB team
    try {
      final emailResult = await OrderEmailService.instance.sendOrderEmail(
        orderId: order.id,
        customerFirstName: shippingFirstName,
        customerLastName: shippingLastName,
        streetAddress: shippingAddress,
        city: shippingCity,
        state: shippingState,
        zip: shippingZip,
        productName: product.name,
        creditsCost: product.creditsCost,
        bracketId: bracketId,
        bracketName: bracketName,
        teamCount: teamCount,
        selectedSize: selectedSize,
        selectedColor: selectedColor,
        customerEmail: customerEmail,
        phoneNumber: phoneNumber,
      );
      if (kDebugMode) {
        debugPrint('Order email sent via ${emailResult.method}: ${emailResult.success}');
      }
    } catch (e) {
      // Email failure should NOT block order success — order is already placed
      if (kDebugMode) debugPrint('Order email failed (non-blocking): $e');
    }

    return PrintOrderResult(
      success: true,
      orderId: order.id,
      newBalance: newBalance,
    );
  }

  /// Shopify Admin API order submission stub.
  /// Production: POST https://your-store.myshopify.com/admin/api/2024-01/orders.json
  Future<void> _submitToShopify({
    required StoreOrder order,
    required StoreProduct product,
    required String bracketId,
    required String bracketName,
    required int teamCount,
    required String shippingName,
    required String shippingAddress,
    required String shippingCity,
    required String shippingState,
    required String shippingZip,
    String? selectedSize,
    String? selectedColor,
  }) async {
    // TODO: Production Shopify integration
    //
    // final shopifyPayload = {
    //   "order": {
    //     "line_items": [{
    //       "variant_id": product.shopifyVariantId,
    //       "quantity": 1,
    //       "properties": [
    //         {"name": "Bracket ID", "value": bracketId},
    //         {"name": "Bracket Name", "value": bracketName},
    //         {"name": "Team Count", "value": "$teamCount"},
    //         {"name": "BMB Order ID", "value": order.id},
    //         if (selectedSize != null) {"name": "Size", "value": selectedSize},
    //         if (selectedColor != null) {"name": "Color", "value": selectedColor},
    //       ],
    //     }],
    //     "shipping_address": {
    //       "name": shippingName,
    //       "address1": shippingAddress,
    //       "city": shippingCity,
    //       "province": shippingState,
    //       "zip": shippingZip,
    //       "country": "US",
    //     },
    //     "financial_status": "paid",
    //     "note": "BMB Bracket Print — $bracketName ($teamCount teams)",
    //     "tags": "bmb-bracket-print, bmb-order-${order.id}",
    //   }
    // };
    //
    // final response = await http.post(
    //   Uri.parse('https://your-store.myshopify.com/admin/api/2024-01/orders.json'),
    //   headers: {
    //     'X-Shopify-Access-Token': shopifyAccessToken,
    //     'Content-Type': 'application/json',
    //   },
    //   body: jsonEncode(shopifyPayload),
    // );
  }
}

/// Wraps a StoreProduct with bracket-print-specific metadata.
class BracketPrintProduct {
  final StoreProduct product;
  final int maxTeamCount;
  final bool fitsCurrentBracket;
  final String printAreaDescription;
  final String? reason; // why it doesn't fit, if applicable

  const BracketPrintProduct({
    required this.product,
    required this.maxTeamCount,
    required this.fitsCurrentBracket,
    required this.printAreaDescription,
    this.reason,
  });
}

/// Result of a print order submission.
class PrintOrderResult {
  final bool success;
  final String? orderId;
  final double? newBalance;
  final String? error;

  const PrintOrderResult({
    required this.success,
    this.orderId,
    this.newBalance,
    this.error,
  });
}
