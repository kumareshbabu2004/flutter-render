import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/store/data/models/store_models.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

/// Central service for BMB Store — handles products, orders, redemptions,
/// inbox delivery, and Shopify integration hooks.
class StoreService {
  StoreService._();
  static final StoreService instance = StoreService._();

  final _firestore = RestFirestoreService.instance;

  // ═══════════════════════════════════════════════════════════════════
  // PRODUCTS — Replace with Shopify API calls in production
  // ═══════════════════════════════════════════════════════════════════

  /// All available store products (mock data — will be replaced by Shopify sync)
  static const List<StoreProduct> products = [
    // ── GIFT CARDS — Tremendous API pricing ─────────────────────────
    // Formula: (faceValue / $0.10) + 5 surcharge = creditsCost
    // BMB nets $0.50 per gift card redemption from +5 credit surcharge
    StoreProduct(
      id: 'gc_amazon_10',
      name: '\$10 Amazon Gift Card',
      description: 'Digital Amazon gift card. Code delivered instantly to your in-app inbox via Tremendous.',
      creditsCost: 105,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'card_giftcard',
      brand: 'Amazon',
      faceValue: 10,
      isFeatured: true,
    ),
    StoreProduct(
      id: 'gc_visa_10',
      name: '\$10 Visa Prepaid Card',
      description: 'Prepaid Visa digital gift card. Use anywhere Visa is accepted.',
      creditsCost: 105,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'credit_card',
      brand: 'Visa',
      faceValue: 10,
    ),
    StoreProduct(
      id: 'gc_doordash_25',
      name: '\$25 DoorDash Gift Card',
      description: 'Order your favorite meals with DoorDash. Code sent to inbox.',
      creditsCost: 255,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'delivery_dining',
      brand: 'DoorDash',
      faceValue: 25,
      isFeatured: true,
    ),
    StoreProduct(
      id: 'gc_amazon_25',
      name: '\$25 Amazon Gift Card',
      description: 'Shop millions of items on Amazon with this digital gift card.',
      creditsCost: 255,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'card_giftcard',
      brand: 'Amazon',
      faceValue: 25,
    ),
    StoreProduct(
      id: 'gc_starbucks_10',
      name: '\$10 Starbucks Gift Card',
      description: 'Fuel up with your favorite Starbucks drinks. Digital code.',
      creditsCost: 105,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'local_cafe',
      brand: 'Starbucks',
      faceValue: 10,
    ),
    StoreProduct(
      id: 'gc_nike_25',
      name: '\$25 Nike Gift Card',
      description: 'Shop the latest Nike gear online or in-store.',
      creditsCost: 255,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'sports_tennis',
      brand: 'Nike',
      faceValue: 25,
    ),
    StoreProduct(
      id: 'gc_uber_25',
      name: '\$25 Uber Eats Gift Card',
      description: 'Order food delivery with Uber Eats. Code delivered to inbox.',
      creditsCost: 255,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'fastfood',
      brand: 'Uber Eats',
      faceValue: 25,
    ),
    StoreProduct(
      id: 'gc_amazon_50',
      name: '\$50 Amazon Gift Card',
      description: 'Large value Amazon digital gift card for serious shoppers.',
      creditsCost: 505,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'card_giftcard',
      brand: 'Amazon',
      faceValue: 50,
      isFeatured: true,
    ),
    StoreProduct(
      id: 'gc_visa_50',
      name: '\$50 Visa Prepaid Card',
      description: 'Premium Visa prepaid card. Use anywhere Visa is accepted.',
      creditsCost: 505,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'credit_card',
      brand: 'Visa',
      faceValue: 50,
    ),
    StoreProduct(
      id: 'gc_visa_100',
      name: '\$100 Visa Prepaid Card',
      description: 'Premium Visa prepaid card. Ultimate flexibility — use anywhere.',
      creditsCost: 1005,
      category: StoreCategory.giftCards,
      type: ProductType.digitalGiftCard,
      imageIcon: 'credit_card',
      brand: 'Visa',
      faceValue: 100,
    ),

    // ── MERCH (PHYSICAL) ────────────────────────────────────────────
    StoreProduct(
      id: 'merch_hoodie',
      name: 'BMB Champion Hoodie',
      description: 'Premium BMB branded champion hoodie. Show off your wins.',
      creditsCost: 250,
      category: StoreCategory.merch,
      type: ProductType.physicalMerch,
      imageIcon: 'checkroom',
      shopifyProductId: 'shopify_hoodie_001',
      sizes: ['S', 'M', 'L', 'XL', '2XL'],
      colors: ['Black', 'Navy', 'Grey'],
      isFeatured: true,
    ),
    StoreProduct(
      id: 'merch_snapback',
      name: 'BMB Snapback Cap',
      description: 'Exclusive BMB champion snapback hat. One size fits all.',
      creditsCost: 100,
      category: StoreCategory.merch,
      type: ProductType.physicalMerch,
      imageIcon: 'face',
      shopifyProductId: 'shopify_cap_001',
      colors: ['Black', 'White', 'Navy'],
    ),
    StoreProduct(
      id: 'merch_tshirt',
      name: 'BMB Pro T-Shirt',
      description: 'Limited edition BMB tournament champion t-shirt.',
      creditsCost: 150,
      category: StoreCategory.merch,
      type: ProductType.physicalMerch,
      imageIcon: 'dry_cleaning',
      shopifyProductId: 'shopify_tshirt_001',
      sizes: ['S', 'M', 'L', 'XL', '2XL'],
      colors: ['Black', 'White', 'Gold'],
    ),
    StoreProduct(
      id: 'merch_mystery',
      name: 'BMB Mystery Box',
      description: 'Surprise box of BMB merchandise and exclusives. 3-5 items.',
      creditsCost: 300,
      category: StoreCategory.merch,
      type: ProductType.physicalMerch,
      imageIcon: 'inventory_2',
      shopifyProductId: 'shopify_mystery_001',
      isFeatured: true,
    ),

    // ── DIGITAL ITEMS ───────────────────────────────────────────────
    StoreProduct(
      id: 'dig_avatar_gold',
      name: 'Gold Champion Frame',
      description: 'Premium gold avatar frame displayed on your profile and chat.',
      creditsCost: 25,
      category: StoreCategory.digital,
      type: ProductType.digitalItem,
      imageIcon: 'auto_awesome',
    ),
    StoreProduct(
      id: 'dig_avatar_fire',
      name: 'Fire Avatar Frame',
      description: 'Animated fire avatar frame. Stand out in every chat room.',
      creditsCost: 40,
      category: StoreCategory.digital,
      type: ProductType.digitalItem,
      imageIcon: 'local_fire_department',
    ),
    StoreProduct(
      id: 'dig_theme_dark',
      name: 'Midnight Theme',
      description: 'Exclusive dark bracket theme with neon accents.',
      creditsCost: 30,
      category: StoreCategory.digital,
      type: ProductType.digitalItem,
      imageIcon: 'dark_mode',
    ),
    StoreProduct(
      id: 'dig_badge_mvp',
      name: 'MVP Badge',
      description: 'Display an MVP badge on your profile. Earned through the store.',
      creditsCost: 50,
      category: StoreCategory.digital,
      type: ProductType.digitalItem,
      imageIcon: 'military_tech',
    ),
    StoreProduct(
      id: 'dig_theme_neon',
      name: 'Neon Bracket Theme',
      description: 'Vibrant neon bracket theme with animated transitions.',
      creditsCost: 35,
      category: StoreCategory.digital,
      type: ProductType.digitalItem,
      imageIcon: 'palette',
    ),

    // ── CUSTOM BRACKET PRODUCTS ─────────────────────────────────────
    StoreProduct(
      id: 'cb_poster_18x24',
      name: 'Bracket Poster 18x24',
      description: 'Your completed bracket picks printed on premium 18x24 poster paper. Perfect for framing.',
      creditsCost: 200,
      category: StoreCategory.customBracket,
      type: ProductType.customBracketPrint,
      imageIcon: 'photo_size_select_large',
      shopifyProductId: 'shopify_poster_001',
    ),
    StoreProduct(
      id: 'cb_canvas_16x20',
      name: 'Bracket Canvas 16x20',
      description: 'Your bracket picks printed on gallery-wrapped canvas. Ready to hang.',
      creditsCost: 350,
      category: StoreCategory.customBracket,
      type: ProductType.customBracketPrint,
      imageIcon: 'wallpaper',
      shopifyProductId: 'shopify_canvas_001',
      isFeatured: true,
    ),
    StoreProduct(
      id: 'cb_tshirt',
      name: 'Bracket Picks T-Shirt',
      description: 'Your bracket picks printed on a high-quality t-shirt. Wear your picks proudly.',
      creditsCost: 175,
      category: StoreCategory.customBracket,
      type: ProductType.customBracketPrint,
      imageIcon: 'dry_cleaning',
      shopifyProductId: 'shopify_bracket_tshirt_001',
      sizes: ['S', 'M', 'L', 'XL', '2XL'],
      colors: ['Black', 'White', 'Navy'],
    ),
    StoreProduct(
      id: 'cb_hoodie',
      name: 'Premium Bracket Hoodie',
      description: 'Your bracket picks printed on the back of a premium heavyweight hoodie. Front features the BMB champion crest.',
      creditsCost: 300,
      category: StoreCategory.customBracket,
      type: ProductType.customBracketPrint,
      imageIcon: 'checkroom',
      shopifyProductId: 'shopify_bracket_hoodie_001',
      sizes: ['S', 'M', 'L', 'XL', '2XL'],
      colors: ['Black', 'Navy', 'Charcoal'],
      isFeatured: true,
    ),
    StoreProduct(
      id: 'cb_mug',
      name: 'Bracket Picks Mug',
      description: 'Custom mug with your bracket picks printed on both sides.',
      creditsCost: 125,
      category: StoreCategory.customBracket,
      type: ProductType.customBracketPrint,
      imageIcon: 'coffee',
      shopifyProductId: 'shopify_bracket_mug_001',
    ),
  ];

  /// Get products filtered by category
  List<StoreProduct> getByCategory(StoreCategory cat) =>
      products.where((p) => p.category == cat && p.isAvailable).toList();

  /// Get featured products across all categories
  List<StoreProduct> getFeatured() =>
      products.where((p) => p.isFeatured && p.isAvailable).toList();

  /// Search products by name
  List<StoreProduct> search(String query) {
    final q = query.toLowerCase();
    return products
        .where((p) => p.isAvailable && (p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q) || (p.brand?.toLowerCase().contains(q) ?? false)))
        .toList();
  }

  /// Find product by ID
  StoreProduct? findById(String id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // REDEMPTION / PURCHASE FLOW
  // ═══════════════════════════════════════════════════════════════════

  /// Redeem a product with BMB credits. Returns the order or null if failed.
  Future<StoreOrder?> redeemProduct({
    required StoreProduct product,
    String? selectedSize,
    String? selectedColor,
    String? shippingAddress,
    String? bracketId,
    String? bracketName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('bmb_bucks_balance') ?? 0;

    if (balance < product.creditsCost) return null;

    // Deduct credits
    final newBalance = balance - product.creditsCost;
    await prefs.setDouble('bmb_bucks_balance', newBalance);

    // Generate order
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    // For digital gift cards, generate a mock code
    String? code;
    if (product.type == ProductType.digitalGiftCard) {
      code = _generateGiftCardCode(product.brand ?? 'BMB');
    }

    final order = StoreOrder(
      id: orderId,
      productId: product.id,
      productName: product.name,
      productType: product.type,
      creditsCost: product.creditsCost,
      status: product.isDigitalDelivery
          ? OrderStatus.fulfilled
          : OrderStatus.processing,
      createdAt: DateTime.now(),
      redemptionCode: code,
      selectedSize: selectedSize,
      selectedColor: selectedColor,
      shippingAddress: shippingAddress,
      bracketId: bracketId,
      bracketName: bracketName,
    );

    // Save order to local storage
    await _saveOrder(order);

    // If digital gift card, deliver code to inbox
    if (product.type == ProductType.digitalGiftCard && code != null) {
      await _deliverToInbox(
        title: '${product.name} — Your Code',
        body:
            'Congratulations! Here is your ${product.name} redemption code. '
            'Use it at ${product.brand ?? "the merchant"} to redeem your gift card.',
        code: code,
        orderId: orderId,
        type: 'gift_card',
      );
    }

    // If digital item, deliver confirmation
    if (product.type == ProductType.digitalItem) {
      await _deliverToInbox(
        title: '${product.name} — Activated!',
        body:
            'Your ${product.name} has been activated and is now visible on your profile. Enjoy!',
        orderId: orderId,
        type: 'order_update',
      );
    }

    // In production: trigger Shopify order via webhook for physical products
    if (product.requiresShipping && product.shopifyProductId != null) {
      await _triggerShopifyOrder(order, product);
    }

    return order;
  }

  /// Generate a mock gift card code (production: call actual gift card API)
  String _generateGiftCardCode(String brand) {
    final rng = Random();
    final prefix = brand.substring(0, min(3, brand.length)).toUpperCase();
    final nums = List.generate(12, (_) => rng.nextInt(10)).join();
    // Format: AMZ-XXXX-XXXX-XXXX
    return '$prefix-${nums.substring(0, 4)}-${nums.substring(4, 8)}-${nums.substring(8, 12)}';
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDERS — Persisted to SharedPreferences (production: backend DB)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _saveOrder(StoreOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final orders = prefs.getStringList('store_orders') ?? [];
    // Serialize minimally as pipe-delimited string
    orders.insert(
        0,
        '${order.id}|${order.productId}|${order.productName}|'
            '${order.productType.index}|${order.creditsCost}|'
            '${order.status.index}|${order.createdAt.toIso8601String()}|'
            '${order.redemptionCode ?? ""}|${order.trackingNumber ?? ""}|'
            '${order.selectedSize ?? ""}|${order.selectedColor ?? ""}|'
            '${order.bracketId ?? ""}|${order.bracketName ?? ""}');
    await prefs.setStringList('store_orders', orders);

    // Persist to Firestore for cross-device access and admin tracking
    try {
      await _firestore.addDocument('store_orders', {
        'orderId': order.id,
        'productId': order.productId,
        'productName': order.productName,
        'productType': order.productType.index,
        'creditsCost': order.creditsCost,
        'status': order.status.index,
        'statusLabel': order.status.name,
        'createdAt': order.createdAt.toUtc().toIso8601String(),
        'redemptionCode': order.redemptionCode ?? '',
        'trackingNumber': order.trackingNumber ?? '',
        'selectedSize': order.selectedSize ?? '',
        'selectedColor': order.selectedColor ?? '',
        'bracketId': order.bracketId ?? '',
        'bracketName': order.bracketName ?? '',
      });
    } catch (e) {
      if (kDebugMode) debugPrint('StoreService: Firestore order save error: $e');
    }
  }

  Future<List<StoreOrder>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('store_orders') ?? [];
    return raw.map((line) {
      final p = line.split('|');
      return StoreOrder(
        id: p[0],
        productId: p[1],
        productName: p[2],
        productType: ProductType.values[int.parse(p[3])],
        creditsCost: int.parse(p[4]),
        status: OrderStatus.values[int.parse(p[5])],
        createdAt: DateTime.parse(p[6]),
        redemptionCode: p[7].isEmpty ? null : p[7],
        trackingNumber: p[8].isEmpty ? null : p[8],
        selectedSize: p[9].isEmpty ? null : p[9],
        selectedColor: p[10].isEmpty ? null : p[10],
        bracketId: p.length > 11 && p[11].isNotEmpty ? p[11] : null,
        bracketName: p.length > 12 && p[12].isNotEmpty ? p[12] : null,
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // INBOX — In-app message delivery for digital codes
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _deliverToInbox({
    required String title,
    required String body,
    String? code,
    String? orderId,
    required String type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = prefs.getStringList('inbox_messages') ?? [];
    final id = 'MSG-${DateTime.now().millisecondsSinceEpoch}';
    msgs.insert(
        0,
        '$id|$title|$body|${code ?? ""}|${orderId ?? ""}|'
            '${DateTime.now().toIso8601String()}|false|$type');
    await prefs.setStringList('inbox_messages', msgs);
  }

  Future<List<InboxMessage>> getInboxMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('inbox_messages') ?? [];
    return raw.map((line) {
      final p = line.split('|');
      return InboxMessage(
        id: p[0],
        title: p[1],
        body: p[2],
        code: p[3].isEmpty ? null : p[3],
        orderId: p[4].isEmpty ? null : p[4],
        createdAt: DateTime.parse(p[5]),
        isRead: p[6] == 'true',
        type: p.length > 7 ? p[7] : 'system',
      );
    }).toList();
  }

  Future<void> markInboxRead(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('inbox_messages') ?? [];
    final updated = raw.map((line) {
      if (line.startsWith('$messageId|')) {
        return line.replaceFirst('|false|', '|true|');
      }
      return line;
    }).toList();
    await prefs.setStringList('inbox_messages', updated);
  }

  Future<int> getUnreadCount() async {
    final msgs = await getInboxMessages();
    return msgs.where((m) => !m.isRead).length;
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHOPIFY INTEGRATION HOOKS
  // Production: replace these stubs with actual Shopify Storefront API
  // or Shopify Admin API calls.
  // ═══════════════════════════════════════════════════════════════════

  /// Sync products from Shopify catalog (production implementation)
  /// In production this would call:
  ///   POST https://your-store.myshopify.com/admin/api/2024-01/products.json
  /// with the Shopify Admin API token.
  Future<void> syncFromShopify({
    required String shopifyDomain,
    required String accessToken,
  }) async {
    // TODO: Production — fetch products from Shopify Storefront/Admin API
    // final url = 'https://$shopifyDomain/admin/api/2024-01/products.json';
    // final response = await http.get(Uri.parse(url), headers: {
    //   'X-Shopify-Access-Token': accessToken,
    // });
    // Parse response and update local product catalog
  }

  /// Create a Shopify order for physical products (production implementation)
  Future<void> _triggerShopifyOrder(StoreOrder order, StoreProduct product) async {
    // TODO: Production — create Shopify order via Admin API
    // POST https://your-store.myshopify.com/admin/api/2024-01/orders.json
    // Body includes: product variant ID, shipping address, line items
    // This creates the order in Shopify for fulfillment tracking.
  }

  /// Admin: Add a new custom bracket product to Shopify
  /// In production this creates a product in both BMB and Shopify
  Future<void> addCustomBracketProduct({
    required String name,
    required String description,
    required int creditsCost,
    required String shopifyDomain,
    required String accessToken,
  }) async {
    // TODO: Production — create product in Shopify via Admin API
    // Then sync back to BMB's local product catalog
  }

  /// Webhook receiver endpoint (production: handle Shopify webhooks)
  /// Topics to subscribe: orders/fulfilled, orders/cancelled, products/update
  Future<void> handleShopifyWebhook(Map<String, dynamic> payload) async {
    // TODO: Production — process Shopify webhook events
    // Update order status, sync product changes, etc.
  }
}
