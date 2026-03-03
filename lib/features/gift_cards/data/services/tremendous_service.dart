import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/gift_cards/data/models/gift_card_models.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

/// Tremendous API integration service for BMB Gift Card Store.
///
/// Production flow:
///   1. User selects brand + amount in the store UI.
///   2. App checks user has enough credits (amount / $0.10 + 5 surcharge).
///   3. App calls this service to create a Tremendous order.
///   4. Tremendous delivers the gift card instantly via API.
///   5. App shows the redemption code/link to the user.
///   6. Credits are deducted from the user's BMB Bucket.
///
/// Sandbox mode: Uses Tremendous sandbox API for testing.
/// Production mode: Uses live Tremendous API with real gift cards.
class TremendousService {
  TremendousService._();
  static final TremendousService instance = TremendousService._();

  // ═══════════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════

  /// Tremendous API base URLs.
  /// Sandbox: https://testflight.tremendous.com/api/v2
  /// Production: https://api.tremendous.com/api/v2
  static const _sandboxBaseUrl = 'https://testflight.tremendous.com/api/v2';
  static const _prodBaseUrl = 'https://api.tremendous.com/api/v2';

  /// Whether to use sandbox mode (set false for production).
  bool _useSandbox = true;

  /// API key — loaded from secure storage or environment.
  /// NEVER hardcode production keys in source code.
  String? _apiKey;

  /// Tremendous campaign ID (optional — for tracking).
  String? _campaignId;

  /// Tremendous funding source ID (required for orders).
  String? _fundingSourceId;

  /// Optional proxy base URL for web (to avoid CORS issues).
  /// When set, all API calls route through this proxy instead of
  /// directly to Tremendous.
  String? _proxyBaseUrl;

  /// The effective base URL: proxy on web, direct on mobile.
  String get _baseUrl {
    if (_proxyBaseUrl != null && _proxyBaseUrl!.isNotEmpty) return _proxyBaseUrl!;
    return _useSandbox ? _sandboxBaseUrl : _prodBaseUrl;
  }

  // ═══════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════

  /// Initialize the service with API credentials.
  /// Call this at app startup after loading secure config.
  Future<void> init({
    required String apiKey,
    String? campaignId,
    String? fundingSourceId,
    bool sandbox = true,
    String? proxyBaseUrl,
  }) async {
    _apiKey = apiKey;
    _campaignId = campaignId;
    _fundingSourceId = fundingSourceId;
    _useSandbox = sandbox;
    _proxyBaseUrl = proxyBaseUrl;

    if (kDebugMode) {
      debugPrint('[Tremendous] Initialized in ${sandbox ? "SANDBOX" : "PRODUCTION"} mode');
      if (proxyBaseUrl != null) debugPrint('[Tremendous] Using proxy: $proxyBaseUrl');
    }
  }

  /// Initialize with sandbox defaults for development.
  /// On web, auto-configures the CORS proxy.
  /// In production, call init() with real credentials from secure storage.
  Future<void> initSandbox() async {
    // On web, detect the current host and use the proxy on port 5061
    String? proxyUrl;
    if (kIsWeb) {
      // The proxy runs at the same host, port 5061
      // Use compile-time env or fallback to a well-known proxy path
      proxyUrl = const String.fromEnvironment(
        'TREMENDOUS_PROXY_URL',
        defaultValue: '',
      );
      // If not set via env, we'll build it from window.location at runtime
      // For now, use the proxy URL passed via --dart-define
    }

    await init(
      apiKey: const String.fromEnvironment(
        'TREMENDOUS_API_KEY',
        defaultValue: 'TEST_PmLSvF78C--TRuLwTDtU4sbN2Dq1JsQeERXpwqEIc8V',
      ),
      fundingSourceId: const String.fromEnvironment(
        'TREMENDOUS_FUNDING_SOURCE',
        defaultValue: 'RAXF1XI8V1BN',
      ),
      sandbox: true,
      proxyBaseUrl: (proxyUrl != null && proxyUrl.isNotEmpty) ? proxyUrl : null,
    );
  }

  /// Check if the service is configured and ready.
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Whether we're in sandbox mode.
  bool get isSandbox => _useSandbox;

  /// Firestore reference for persisting orders.
  final _firestore = RestFirestoreService.instance;

  /// Whether using proxy mode (web CORS workaround).
  bool get _usingProxy => _proxyBaseUrl != null && _proxyBaseUrl!.isNotEmpty;

  /// Build the full URL for a Tremendous API endpoint.
  /// In proxy mode: proxyBaseUrl + /api/orders
  /// Direct mode:   baseUrl + /orders
  String _apiUrl(String endpoint) {
    if (_usingProxy) return '$_baseUrl/api$endpoint';
    return '$_baseUrl$endpoint';
  }

  // ═══════════════════════════════════════════════════════════════════
  // CATALOG — Available gift card brands
  // ═══════════════════════════════════════════════════════════════════

  /// Get curated BMB gift card brands (with real Tremendous product IDs).
  /// These are the brands shown in the Gift Card Store UI.
  /// For charity-only mode, pass [charityOnly] = true.
  /// The "Let BMB Choose" option is always listed first in charity lists.
  List<GiftCardBrand> getCuratedBrands({bool charityOnly = false}) {
    if (charityOnly) return [_letBmbChooseBrand, ..._charityBrands];
    return [..._giftCardBrands, _letBmbChooseBrand, ..._charityBrands];
  }

  /// Fetch available gift card products from Tremendous API.
  /// Falls back to curated list on failure.
  Future<List<GiftCardBrand>> getAvailableBrands({
    bool charityOnly = false,
  }) async {
    // Always return curated list — Tremendous has 2400+ products,
    // we only show the brands relevant to BMB users.
    return getCuratedBrands(charityOnly: charityOnly);
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDERING — Create gift card / charity donation orders
  // ═══════════════════════════════════════════════════════════════════

  /// Create a gift card order via Tremendous API.
  /// Returns the order details including redemption info.
  ///
  /// For charity prizes: set [isCharityPrize] = true and provide
  /// [bracketId] and [bracketTitle] for tracking.
  Future<GiftCardOrder?> createOrder({
    required String userId,
    required String brandId,
    required String brandName,
    required double amount,
    required String recipientEmail,
    String? recipientName,
    bool isCharityPrize = false,
    String? bracketId,
    String? bracketTitle,
  }) async {
    final creditsRequired = (amount / 0.10).round() + 5;
    final orderId = 'gc_${DateTime.now().millisecondsSinceEpoch}';

    if (!isConfigured) {
      // Demo mode — simulate order creation
      if (kDebugMode) {
        debugPrint('[Tremendous] DEMO MODE: Simulating order for '
            '\$$amount $brandName ${isCharityPrize ? "charity donation" : "gift card"}');
      }

      final order = GiftCardOrder(
        orderId: orderId,
        userId: userId,
        brandId: brandId,
        brandName: brandName,
        faceValue: amount,
        creditsSpent: creditsRequired,
        status: 'delivered',
        redemptionCode: isCharityPrize
            ? null
            : 'DEMO-${orderId.substring(3, 11).toUpperCase()}',
        redemptionUrl: 'https://testflight.tremendous.com/rewards/demo',
        createdAt: DateTime.now(),
        deliveredAt: DateTime.now(),
      );

      await _saveOrderLocally(order);
      return order;
    }

    // ═══ LIVE API CALL ═══
    try {
      final body = {
        'payment': {
          'funding_source_id': _fundingSourceId ?? 'balance',
        },
        // Tremendous API v2 uses 'reward' (singular)
        'reward': {
          'value': {
            'denomination': amount,
            'currency_code': 'USD',
          },
          'delivery': {
            'method': 'LINK', // Generates a unique redemption link
          },
          'recipient': {
            'email': recipientEmail,
            if (recipientName != null) 'name': recipientName,
          },
          'products': [brandId],
        },
        if (_campaignId != null) 'campaign_id': _campaignId,
        // Use external_id for idempotency on charity prizes
        if (isCharityPrize && bracketId != null)
          'external_id': 'charity_${bracketId}_$userId',
      };

      final response = await http.post(
        Uri.parse(_apiUrl('/orders')),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final orderData = data['order'];
        // Response returns 'rewards' (plural array)
        final reward = (orderData['rewards'] as List?)?.firstOrNull;

        final deliveryLink = reward?['delivery']?['link'];
        final redemptionUrl = deliveryLink is String
            ? deliveryLink
            : (deliveryLink is Map ? deliveryLink['url']?.toString() : null);

        final order = GiftCardOrder(
          orderId: orderId,
          userId: userId,
          brandId: brandId,
          brandName: brandName,
          faceValue: amount,
          creditsSpent: creditsRequired,
          status: reward?['delivery']?['status']?.toString().toLowerCase() ?? 'processing',
          redemptionCode: null, // We use redemptionUrl (link) instead
          redemptionUrl: redemptionUrl,
          createdAt: DateTime.now(),
          tremendousOrderId: orderData['id']?.toString(),
        );

        await _saveOrderLocally(order);
        return order;
      } else {
        if (kDebugMode) {
          debugPrint('[Tremendous] Order failed: ${response.statusCode} '
              '${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Tremendous] Order error: $e');
      }
    }

    return null;
  }

  /// Check the status of an existing order.
  Future<String?> checkOrderStatus(String tremendousOrderId) async {
    if (!isConfigured) return 'delivered';

    try {
      final response = await http.get(
        Uri.parse(_apiUrl('/orders/$tremendousOrderId')),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['order']?['status'] as String?;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Tremendous] Status check failed: $e');
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDER HISTORY
  // ═══════════════════════════════════════════════════════════════════

  /// Get the user's gift card order history (stored locally).
  Future<List<GiftCardOrder>> getOrderHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('gc_orders_$userId') ?? [];
    return raw.map((json) {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return GiftCardOrder(
        orderId: m['orderId'] as String,
        userId: m['userId'] as String,
        brandId: m['brandId'] as String,
        brandName: m['brandName'] as String,
        faceValue: (m['faceValue'] as num).toDouble(),
        creditsSpent: m['creditsSpent'] as int,
        status: m['status'] as String,
        redemptionCode: m['redemptionCode'] as String?,
        redemptionUrl: m['redemptionUrl'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        deliveredAt: m['deliveredAt'] != null
            ? DateTime.parse(m['deliveredAt'] as String)
            : null,
        tremendousOrderId: m['tremendousOrderId'] as String?,
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_apiKey ?? ''}',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<void> _saveOrderLocally(GiftCardOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'gc_orders_${order.userId}';
    final orders = prefs.getStringList(key) ?? [];
    orders.insert(0, jsonEncode({
      'orderId': order.orderId,
      'userId': order.userId,
      'brandId': order.brandId,
      'brandName': order.brandName,
      'faceValue': order.faceValue,
      'creditsSpent': order.creditsSpent,
      'status': order.status,
      'redemptionCode': order.redemptionCode,
      'redemptionUrl': order.redemptionUrl,
      'createdAt': order.createdAt.toIso8601String(),
      'deliveredAt': order.deliveredAt?.toIso8601String(),
      'tremendousOrderId': order.tremendousOrderId,
    }));
    await prefs.setStringList(key, orders);

    // Also persist to Firestore for cross-device access
    try {
      await _firestore.addDocument('gift_card_orders', {
        'orderId': order.orderId,
        'userId': order.userId,
        'brandId': order.brandId,
        'brandName': order.brandName,
        'faceValue': order.faceValue,
        'creditsSpent': order.creditsSpent,
        'status': order.status,
        'redemptionCode': order.redemptionCode ?? '',
        'redemptionUrl': order.redemptionUrl ?? '',
        'tremendousOrderId': order.tremendousOrderId ?? '',
        'createdAt': order.createdAt.toUtc().toIso8601String(),
        'deliveredAt': order.deliveredAt?.toUtc().toIso8601String() ?? '',
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[Tremendous] Firestore order save error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // CURATED GIFT CARD BRANDS — Real Tremendous product IDs
  // ═══════════════════════════════════════════════════════════════════

  static const _giftCardBrands = [
    GiftCardBrand(
      id: 'OKMHM2X2OHYV', name: 'Amazon', category: 'Shopping',
      description: 'Shop millions of products on Amazon.com',
      imageUrl: 'https://testflight.tremendous.com/product_images/OKMHM2X2OHYV/logo',
      denominations: [10, 25, 50, 100, 200], isPopular: true,
    ),
    GiftCardBrand(
      id: 'A2J05SWPI2QG', name: 'Visa Prepaid', category: 'Shopping',
      description: 'Use anywhere Visa is accepted',
      imageUrl: 'https://testflight.tremendous.com/product_images/A2J05SWPI2QG/logo',
      denominations: [25, 50, 100, 200, 500], isPopular: true,
    ),
    GiftCardBrand(
      id: '9OEIQ5EWBWT9', name: 'DoorDash', category: 'Food & Dining',
      description: 'Order food delivery from your favorite restaurants',
      imageUrl: 'https://testflight.tremendous.com/product_images/9OEIQ5EWBWT9/logo',
      denominations: [15, 25, 50, 100], isPopular: true,
    ),
    GiftCardBrand(
      id: '2XG0FLQXBDCZ', name: 'Starbucks', category: 'Food & Dining',
      description: 'Enjoy your favorite Starbucks drinks and food',
      imageUrl: 'https://testflight.tremendous.com/product_images/2XG0FLQXBDCZ/logo',
      denominations: [10, 15, 25, 50],
    ),
    GiftCardBrand(
      id: 'SRDHFATO9KHN', name: 'Target', category: 'Shopping',
      description: 'Shop at Target for everything you need',
      imageUrl: 'https://testflight.tremendous.com/product_images/SRDHFATO9KHN/logo',
      denominations: [10, 25, 50, 100],
    ),
    GiftCardBrand(
      id: 'DC82VBYLI4CC', name: 'Apple', category: 'Entertainment',
      description: 'Use for apps, games, music, movies, and more',
      imageUrl: 'https://testflight.tremendous.com/product_images/DC82VBYLI4CC/logo',
      denominations: [10, 25, 50, 100], isPopular: true,
    ),
    GiftCardBrand(
      id: 'HOPB2V9UY5BH', name: 'Uber Eats', category: 'Food & Dining',
      description: 'Order food delivery with Uber Eats',
      imageUrl: 'https://testflight.tremendous.com/product_images/HOPB2V9UY5BH/logo',
      denominations: [15, 25, 50, 100],
    ),
    GiftCardBrand(
      id: 'FGXZUYWP4FII', name: 'Nike', category: 'Shopping',
      description: 'Shop the latest Nike gear and apparel',
      imageUrl: 'https://testflight.tremendous.com/product_images/FGXZUYWP4FII/logo',
      denominations: [25, 50, 100, 150],
    ),
    GiftCardBrand(
      id: 'CRN0ID07Y2XD', name: 'Chipotle', category: 'Food & Dining',
      description: 'Burritos, bowls, and more from Chipotle',
      imageUrl: 'https://testflight.tremendous.com/product_images/CRN0ID07Y2XD/logo',
      denominations: [10, 15, 25, 50],
    ),
    GiftCardBrand(
      id: '46I7B4VZAFES', name: 'Fanatics', category: 'Shopping',
      description: 'Official sports merchandise and jerseys',
      imageUrl: 'https://testflight.tremendous.com/product_images/46I7B4VZAFES/logo',
      denominations: [25, 50, 100, 200], isPopular: true,
    ),
    GiftCardBrand(
      id: '7LTZASQ2T7T1', name: 'Xbox', category: 'Entertainment',
      description: 'Games, add-ons, and more for Xbox',
      imageUrl: 'https://testflight.tremendous.com/product_images/7LTZASQ2T7T1/logo',
      denominations: [10, 25, 50, 100],
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════
  // CURATED CHARITY BRANDS — Real Tremendous charity product IDs
  // ═══════════════════════════════════════════════════════════════════
  //   "LET BMB CHOOSE" — escrow option for charity bracket winners.
  //   When selected, the funds are released to BMB who selects a charity
  //   on the winner's behalf. This is treated as a special charity brand.
  // ═══════════════════════════════════════════════════════════════════

  static const _letBmbChooseBrand = GiftCardBrand(
    id: 'BMB_CHOOSE',
    name: 'Let BMB Choose',
    category: 'Charity',
    description:
        'Can\'t decide? Let the BMB team pick a worthy charity on your behalf. '
        'Funds stay charitable — 100% donated.',
    imageUrl: '',
    denominations: [5, 10, 25, 50, 100],
    isPopular: true,
    isCharity: true,
  );

  // ═══════════════════════════════════════════════════════════════════

  static const _charityBrands = [
    GiftCardBrand(
      id: '53SXYVQGM0II', name: "St. Jude Children's Research Hospital",
      category: 'Charity',
      description: 'Finding cures. Saving children. Families never receive a bill.',
      imageUrl: 'https://testflight.tremendous.com/product_images/53SXYVQGM0II/logo',
      denominations: [5, 10, 25, 50, 100], isPopular: true, isCharity: true,
    ),
    GiftCardBrand(
      id: 'CFMAZHY7FX64', name: 'American Red Cross',
      category: 'Charity',
      description: 'Disaster relief, blood donation, and emergency assistance',
      imageUrl: 'https://testflight.tremendous.com/product_images/CFMAZHY7FX64/logo',
      denominations: [5, 10, 25, 50, 100], isPopular: true, isCharity: true,
    ),
    GiftCardBrand(
      id: 'L0OG7KT5X8YL', name: 'World Wildlife Fund',
      category: 'Charity',
      description: 'Protecting wildlife and wild places around the world',
      imageUrl: 'https://testflight.tremendous.com/product_images/L0OG7KT5X8YL/logo',
      denominations: [5, 10, 25, 50, 100], isCharity: true,
    ),
    GiftCardBrand(
      id: 'V9KL02IPQR84', name: 'Habitat for Humanity',
      category: 'Charity',
      description: 'Building homes, communities, and hope',
      imageUrl: 'https://testflight.tremendous.com/product_images/V9KL02IPQR84/logo',
      denominations: [5, 10, 25, 50, 100], isCharity: true,
    ),
    GiftCardBrand(
      id: 'ESRNAD533W5A', name: 'Save the Children',
      category: 'Charity',
      description: 'Giving children a healthy start, education, and protection',
      imageUrl: 'https://testflight.tremendous.com/product_images/ESRNAD533W5A/logo',
      denominations: [5, 10, 25, 50, 100], isCharity: true,
    ),
    GiftCardBrand(
      id: '4SRZ9TT18C7B', name: 'Doctors Without Borders',
      category: 'Charity',
      description: 'Medical humanitarian aid where it is needed most',
      imageUrl: 'https://testflight.tremendous.com/product_images/4SRZ9TT18C7B/logo',
      denominations: [5, 10, 25, 50, 100], isCharity: true,
    ),
    GiftCardBrand(
      id: 'R6M4YUX31YOW', name: 'Folds of Honor',
      category: 'Charity',
      description: 'Educational scholarships for military families',
      imageUrl: 'https://testflight.tremendous.com/product_images/R6M4YUX31YOW/logo',
      denominations: [5, 10, 25, 50, 100], isCharity: true,
    ),
    GiftCardBrand(
      id: 'WL1R9555NNPX', name: 'Girls Who Code',
      category: 'Charity',
      description: 'Closing the gender gap in technology',
      imageUrl: 'https://testflight.tremendous.com/product_images/WL1R9555NNPX/logo',
      denominations: [5, 10, 25, 50, 100], isCharity: true,
    ),
    GiftCardBrand(
      id: 'WBNO55THTEU5', name: 'American Cancer Society',
      category: 'Charity',
      description: 'Funding cancer research and supporting patients',
      imageUrl: 'https://testflight.tremendous.com/product_images/WBNO55THTEU5/logo',
      denominations: [5, 10, 25, 50, 100], isCharity: true,
    ),
    GiftCardBrand(
      id: 'Z3ABKZQZQ4HT', name: 'Clean Water Fund',
      category: 'Charity',
      description: 'Protecting clean water for communities everywhere',
      imageUrl: 'https://testflight.tremendous.com/product_images/Z3ABKZQZQ4HT/logo',
      denominations: [5, 10, 25, 50, 100], isCharity: true,
    ),
  ];
}
