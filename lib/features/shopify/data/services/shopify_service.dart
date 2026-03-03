import 'package:flutter/foundation.dart';

/// Shopify Integration Service
///
/// End-to-end flow:
/// 1. Host links their Shopify store (domain + storefront access token)
/// 2. BMB pulls product catalog via Storefront API
/// 3. User makes bracket picks -> picks file is generated
/// 4. Picks are sent to Shopify to create a custom order (with bracket visual on product)
/// 5. User reviews/approves the mockup with their picks overlaid
/// 6. Seamless in-app checkout via Shopify web checkout URL
///
/// This service manages all Shopify-related data and operations.

class ShopifyService {
  static final ShopifyService _instance = ShopifyService._internal();
  factory ShopifyService() => _instance;
  ShopifyService._internal();

  static bool _isLinked = false;
  static String? _storeDomain;
  // ignore: unused_field
  static String? _storefrontToken;
  static ShopifyStoreInfo? _storeInfo;

  // ─── ACCOUNT STATUS ──────────────────────────────────────────
  static bool get isLinked => _isLinked;
  static String? get storeDomain => _storeDomain;
  static ShopifyStoreInfo? get storeInfo => _storeInfo;

  /// Link a Shopify store
  static Future<ShopifyLinkResult> linkStore({
    required String storeDomain,
    required String storefrontAccessToken,
  }) async {
    try {
      // In production: validate token against Shopify Storefront API
      await Future.delayed(const Duration(seconds: 1));

      _isLinked = true;
      _storeDomain = storeDomain;
      _storefrontToken = storefrontAccessToken;
      _storeInfo = ShopifyStoreInfo(
        domain: storeDomain,
        name: _extractStoreName(storeDomain),
        currency: 'USD',
        productCount: _demoProducts.length,
        isActive: true,
      );

      if (kDebugMode) {
        debugPrint('Shopify linked: $storeDomain');
      }

      return const ShopifyLinkResult(success: true, message: 'Store linked successfully!');
    } catch (e) {
      return ShopifyLinkResult(success: false, message: 'Failed to link: $e');
    }
  }

  /// Unlink Shopify store
  static void unlinkStore() {
    _isLinked = false;
    _storeDomain = null;
    _storefrontToken = null;
    _storeInfo = null;
  }

  static String _extractStoreName(String domain) {
    final parts = domain.replaceAll('.myshopify.com', '').split('.');
    return parts.last.split('-').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  // ─── PRODUCT CATALOG ─────────────────────────────────────────
  /// Fetch all products from linked Shopify store
  static Future<List<ShopifyProduct>> fetchProducts({String? category}) async {
    if (!_isLinked) return [];
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 600));

    if (category != null && category != 'All') {
      return _demoProducts.where((p) => p.category == category).toList();
    }
    return List.unmodifiable(_demoProducts);
  }

  /// Fetch product categories
  static Future<List<String>> fetchCategories() async {
    if (!_isLinked) return [];
    await Future.delayed(const Duration(milliseconds: 300));
    return ['All', 'Apparel', 'Headwear', 'Accessories', 'Gift Cards', 'Bundles'];
  }

  /// Fetch a single product by ID
  static Future<ShopifyProduct?> fetchProduct(String productId) async {
    if (!_isLinked) return null;
    await Future.delayed(const Duration(milliseconds: 300));
    return _demoProducts.where((p) => p.id == productId).firstOrNull;
  }

  // ─── ORDER CREATION ──────────────────────────────────────────
  /// Create a Shopify order from bracket picks
  /// This sends the user's picks + bracket visual to Shopify as a custom order
  static Future<ShopifyOrderResult> createOrder({
    required String productId,
    required String bracketId,
    required String bracketName,
    required List<String> picks,
    required String customerName,
    required String customerEmail,
    required ShopifyShippingAddress shippingAddress,
    String? customizationNotes,
  }) async {
    if (!_isLinked) {
      return const ShopifyOrderResult(
        success: false,
        message: 'Shopify store not linked',
      );
    }

    try {
      // Simulate API call to create order
      await Future.delayed(const Duration(seconds: 2));

      final product = _demoProducts.where((p) => p.id == productId).firstOrNull;
      if (product == null) {
        return const ShopifyOrderResult(success: false, message: 'Product not found');
      }

      final orderId = 'BMB-${DateTime.now().millisecondsSinceEpoch}';
      final order = ShopifyOrder(
        id: orderId,
        productId: productId,
        productTitle: product.title,
        productPrice: product.price,
        bracketId: bracketId,
        bracketName: bracketName,
        picks: picks,
        status: OrderStatus.pendingApproval,
        createdAt: DateTime.now(),
        customerName: customerName,
        customerEmail: customerEmail,
        shippingAddress: shippingAddress,
        customizationNotes: customizationNotes,
        checkoutUrl: 'https://$_storeDomain/cart/$productId:1?checkout[email]=$customerEmail',
        mockupImageUrl: product.mockupImageUrl,
      );

      _orders.add(order);

      return ShopifyOrderResult(
        success: true,
        message: 'Order created successfully!',
        order: order,
      );
    } catch (e) {
      return ShopifyOrderResult(success: false, message: 'Order failed: $e');
    }
  }

  /// Approve an order (after user reviews the mockup)
  static Future<bool> approveOrder(String orderId) async {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return false;
    await Future.delayed(const Duration(milliseconds: 500));
    _orders[idx] = _orders[idx].copyWith(status: OrderStatus.approved);
    return true;
  }

  /// Get checkout URL for an approved order
  static String? getCheckoutUrl(String orderId) {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null || order.status != OrderStatus.approved) return null;
    return order.checkoutUrl;
  }

  /// Get all orders for the current user
  static List<ShopifyOrder> get orders => List.unmodifiable(_orders);

  /// Get order by ID
  static ShopifyOrder? getOrder(String orderId) =>
      _orders.where((o) => o.id == orderId).firstOrNull;

  // ─── PICKS VISUAL GENERATION ─────────────────────────────────
  /// Generate a bracket picks visual (image overlay on product mockup)
  /// Returns a local path to the generated image
  static Future<BracketPicksVisual> generatePicksVisual({
    required String productId,
    required String bracketName,
    required List<String> picks,
    required String hostName,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    final product = _demoProducts.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      return const BracketPicksVisual(
        success: false,
        message: 'Product not found',
      );
    }

    return BracketPicksVisual(
      success: true,
      message: 'Mockup generated!',
      productTitle: product.title,
      productPrice: product.price,
      productImageUrl: product.imageUrl,
      mockupImageUrl: product.mockupImageUrl,
      bracketName: bracketName,
      picks: picks,
      hostName: hostName,
    );
  }

  // ─── PRIVATE DATA ────────────────────────────────────────────
  static final List<ShopifyOrder> _orders = [];

  static const List<ShopifyProduct> _demoProducts = [
    ShopifyProduct(
      id: 'sp_hoodie_champ',
      title: 'BMB Champion Hoodie',
      description: 'Premium heavyweight hoodie with your custom bracket picks printed on the back. Celebrate your winning bracket in style!',
      price: 59.99,
      compareAtPrice: 79.99,
      imageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=800&h=800&fit=crop',
      available: true,
      category: 'Apparel',
      variants: ['S', 'M', 'L', 'XL', '2XL'],
      supportsCustomPrint: true,
      printArea: 'Back',
    ),
    ShopifyProduct(
      id: 'sp_tee_bracket',
      title: 'BMB Bracket Tee',
      description: 'Lightweight premium tee with your bracket picks screen-printed on the front. Show off your picks game day!',
      price: 34.99,
      compareAtPrice: 44.99,
      imageUrl: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800&h=800&fit=crop',
      available: true,
      category: 'Apparel',
      variants: ['S', 'M', 'L', 'XL', '2XL'],
      supportsCustomPrint: true,
      printArea: 'Front',
    ),
    ShopifyProduct(
      id: 'sp_snapback',
      title: 'BMB Snapback Cap',
      description: 'Structured snapback with embroidered BMB logo. The official cap of bracket champions.',
      price: 29.99,
      imageUrl: 'https://images.unsplash.com/photo-1588850561407-ed78c334e67a?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1588850561407-ed78c334e67a?w=800&h=800&fit=crop',
      available: true,
      category: 'Headwear',
      variants: ['One Size'],
      supportsCustomPrint: false,
    ),
    ShopifyProduct(
      id: 'sp_joggers',
      title: 'BMB Bracket Joggers',
      description: 'Tech fleece joggers with subtle BMB branding. Bracket-day comfort from tip-off to final buzzer.',
      price: 49.99,
      imageUrl: 'https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?w=800&h=800&fit=crop',
      available: true,
      category: 'Apparel',
      variants: ['S', 'M', 'L', 'XL'],
      supportsCustomPrint: false,
    ),
    ShopifyProduct(
      id: 'sp_crewneck',
      title: 'BMB Picks Crewneck',
      description: 'Midweight crewneck sweatshirt with your bracket picks printed on the back. Perfect for game-day layers.',
      price: 49.99,
      compareAtPrice: 64.99,
      imageUrl: 'https://images.unsplash.com/photo-1578768079470-fa604cf498a4?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1578768079470-fa604cf498a4?w=800&h=800&fit=crop',
      available: true,
      category: 'Apparel',
      variants: ['S', 'M', 'L', 'XL', '2XL'],
      supportsCustomPrint: true,
      printArea: 'Back',
    ),
    ShopifyProduct(
      id: 'sp_beanie',
      title: 'BMB Knit Beanie',
      description: 'Cuffed knit beanie with embroidered BMB logo. Winter bracket season essential.',
      price: 24.99,
      imageUrl: 'https://images.unsplash.com/photo-1576871337622-98d48d1cf531?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1576871337622-98d48d1cf531?w=800&h=800&fit=crop',
      available: true,
      category: 'Headwear',
      variants: ['One Size'],
      supportsCustomPrint: false,
    ),
    ShopifyProduct(
      id: 'sp_tumbler',
      title: 'BMB Insulated Tumbler',
      description: '30oz insulated tumbler with BMB branding. Keeps your drink cold through overtime.',
      price: 34.99,
      imageUrl: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=800&h=800&fit=crop',
      available: true,
      category: 'Accessories',
      variants: ['30oz'],
      supportsCustomPrint: false,
    ),
    ShopifyProduct(
      id: 'sp_gift25',
      title: '\$25 BMB Gift Card',
      description: 'Digital gift card redeemable at the BMB Store. Perfect gift for your bracket crew.',
      price: 25.00,
      imageUrl: 'https://images.unsplash.com/photo-1549465220-1a8b9238f537?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1549465220-1a8b9238f537?w=800&h=800&fit=crop',
      available: true,
      category: 'Gift Cards',
      variants: ['\$25'],
      supportsCustomPrint: false,
    ),
    ShopifyProduct(
      id: 'sp_gift50',
      title: '\$50 BMB Gift Card',
      description: 'Premium digital gift card. Level up your bracket champion rewards.',
      price: 50.00,
      imageUrl: 'https://images.unsplash.com/photo-1549465220-1a8b9238f537?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1549465220-1a8b9238f537?w=800&h=800&fit=crop',
      available: true,
      category: 'Gift Cards',
      variants: ['\$50'],
      supportsCustomPrint: false,
    ),
    ShopifyProduct(
      id: 'sp_bundle_champ',
      title: 'Champion Bundle',
      description: 'The ultimate bracket champion package: Hoodie + Snapback + Tumbler. Save 20% vs buying separately!',
      price: 99.99,
      compareAtPrice: 124.97,
      imageUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&h=600&fit=crop',
      mockupImageUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=800&h=800&fit=crop',
      available: true,
      category: 'Bundles',
      variants: ['S', 'M', 'L', 'XL'],
      supportsCustomPrint: true,
      printArea: 'Hoodie Back',
    ),
  ];
}

// ─── DATA CLASSES ──────────────────────────────────────────────

class ShopifyLinkResult {
  final bool success;
  final String message;
  const ShopifyLinkResult({required this.success, required this.message});
}

class ShopifyStoreInfo {
  final String domain;
  final String name;
  final String currency;
  final int productCount;
  final bool isActive;
  const ShopifyStoreInfo({
    required this.domain,
    required this.name,
    required this.currency,
    required this.productCount,
    required this.isActive,
  });
}

class ShopifyProduct {
  final String id;
  final String title;
  final String description;
  final double price;
  final double? compareAtPrice;
  final String? imageUrl;
  final String? mockupImageUrl;
  final bool available;
  final String category;
  final List<String> variants;
  final bool supportsCustomPrint;
  final String? printArea;

  const ShopifyProduct({
    required this.id,
    required this.title,
    this.description = '',
    required this.price,
    this.compareAtPrice,
    this.imageUrl,
    this.mockupImageUrl,
    required this.available,
    this.category = 'General',
    this.variants = const [],
    this.supportsCustomPrint = false,
    this.printArea,
  });

  bool get onSale => compareAtPrice != null && compareAtPrice! > price;
  double get savings => onSale ? compareAtPrice! - price : 0;
  int get savingsPercent => onSale ? ((savings / compareAtPrice!) * 100).round() : 0;
}

enum OrderStatus {
  pendingApproval,
  approved,
  checkoutStarted,
  paid,
  processing,
  shipped,
  delivered,
  cancelled,
}

class ShopifyOrder {
  final String id;
  final String productId;
  final String productTitle;
  final double productPrice;
  final String bracketId;
  final String bracketName;
  final List<String> picks;
  final OrderStatus status;
  final DateTime createdAt;
  final String customerName;
  final String customerEmail;
  final ShopifyShippingAddress shippingAddress;
  final String? customizationNotes;
  final String? checkoutUrl;
  final String? mockupImageUrl;

  const ShopifyOrder({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.productPrice,
    required this.bracketId,
    required this.bracketName,
    required this.picks,
    required this.status,
    required this.createdAt,
    required this.customerName,
    required this.customerEmail,
    required this.shippingAddress,
    this.customizationNotes,
    this.checkoutUrl,
    this.mockupImageUrl,
  });

  ShopifyOrder copyWith({OrderStatus? status, String? checkoutUrl}) {
    return ShopifyOrder(
      id: id,
      productId: productId,
      productTitle: productTitle,
      productPrice: productPrice,
      bracketId: bracketId,
      bracketName: bracketName,
      picks: picks,
      status: status ?? this.status,
      createdAt: createdAt,
      customerName: customerName,
      customerEmail: customerEmail,
      shippingAddress: shippingAddress,
      customizationNotes: customizationNotes,
      checkoutUrl: checkoutUrl ?? this.checkoutUrl,
      mockupImageUrl: mockupImageUrl,
    );
  }

  String get statusLabel {
    switch (status) {
      case OrderStatus.pendingApproval: return 'Review & Approve';
      case OrderStatus.approved: return 'Ready to Checkout';
      case OrderStatus.checkoutStarted: return 'Checkout In Progress';
      case OrderStatus.paid: return 'Payment Received';
      case OrderStatus.processing: return 'Processing';
      case OrderStatus.shipped: return 'Shipped';
      case OrderStatus.delivered: return 'Delivered';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }
}

class ShopifyShippingAddress {
  final String firstName;
  final String lastName;
  final String address1;
  final String? address2;
  final String city;
  final String state;
  final String zip;
  final String country;

  const ShopifyShippingAddress({
    required this.firstName,
    required this.lastName,
    required this.address1,
    this.address2,
    required this.city,
    required this.state,
    required this.zip,
    this.country = 'US',
  });

  String get fullName => '$firstName $lastName';
  String get displayAddress => '$address1${address2 != null ? ', $address2' : ''}, $city, $state $zip';
}

class ShopifyOrderResult {
  final bool success;
  final String message;
  final ShopifyOrder? order;
  const ShopifyOrderResult({required this.success, required this.message, this.order});
}

class BracketPicksVisual {
  final bool success;
  final String message;
  final String? productTitle;
  final double? productPrice;
  final String? productImageUrl;
  final String? mockupImageUrl;
  final String? bracketName;
  final List<String>? picks;
  final String? hostName;

  const BracketPicksVisual({
    required this.success,
    required this.message,
    this.productTitle,
    this.productPrice,
    this.productImageUrl,
    this.mockupImageUrl,
    this.bracketName,
    this.picks,
    this.hostName,
  });
}
