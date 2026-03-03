import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bmb_mobile/core/config/app_config.dart';

/// Client service that calls the BMB Merch Server for bracket preview generation.
///
/// Architecture:
///   Flutter App  -->  BMB Merch Server  -->  Shopify (checkout redirect)
///                    (Node.js + Express)
///
/// Flow:
///   1. Flutter sends bracket JSON + shopifyProductId to POST /generate-preview
///   2. Server resolves product config, selects correct mockup, generates SVG
///   3. Server composites bracket PNG onto the correct garment mockup
///   4. Server persists all files under a unique artifactId
///   5. Server returns preview.jpg (or JSON with URLs + artifactId)
///   6. On checkout, Flutter redirects to Shopify cart with bracket_id,
///      artifact_id, preview_url, and product_id as line-item properties
///   7. Shopify "orders/paid" webhook loads artifacts by artifactId
///      and delivers files to the printer (email + optional folder/sftp)
///
/// Configuration:
///   The server URL is read from [AppConfig.merchServerBaseUrl].
///   Override at build time:
///     flutter build apk --dart-define=MERCH_SERVER_URL=https://backmybracket-mobile-version-2.onrender.com
///   Default (production): https://backmybracket-mobile-version-2.onrender.com
class MerchPreviewService {
  /// Resolved merch-server base URL (from AppConfig, never localhost in release).
  static String get _baseUrl => AppConfig.merchServerBaseUrl;

  /// Shopify store product base URL.
  static String get _shopifyStoreUrl => AppConfig.shopifyStoreUrl;

  /// Tag used in all log lines from this service.
  static const String _tag = 'MerchPreview';

  /// Product ID -> Shopify product handle mapping.
  static const Map<String, String> _shopifyProductHandles = {
    'bp_grid_iron': 'bmb-grid-iron-tech-fleece-hoodie',
    'bp_tri_tee': 'bmb-perfect-tri-tee',
    'bp_street_lounge': 'bmb-street-lounge-french-terry-hoodie',
    'bp_on_the_go': 'bmb-on-the-go-tri-blend-hoodie',
    'bp_all_day': 'bmb-all-day-tri-blend-fleece-hoodie',
  };

  /// Product ID -> Shopify numeric product ID mapping.
  static const Map<String, String> _shopifyProductIds = {
    'bp_grid_iron': '9208241586344',
    'bp_tri_tee': '9202022514856',
    'bp_street_lounge': '9202019598504',
    'bp_on_the_go': '9202016387240',
    'bp_all_day': '9201709580456',
  };

  /// Product ID -> Shopify variant ID mapping (first/default variant).
  static const Map<String, String> _shopifyVariantIds = {
    'bp_grid_iron': '48123456789000',
    'bp_tri_tee': '48123456789001',
    'bp_street_lounge': '48123456789002',
    'bp_on_the_go': '48123456789003',
    'bp_all_day': '48123456789004',
  };

  // ─── SERVER PREVIEW ────────────────────────────────────────────

  /// Generate a bracket preview via the merch server (JSON response).
  ///
  /// Returns [PreviewResult] with previewUrl, artifactId, print-ready URLs,
  /// and metadata. Falls back to an empty result if the server is unreachable.
  static Future<PreviewResult> generatePreview({
    required String bracketTitle,
    required String championName,
    required int teamCount,
    required List<String> teams,
    required Map<String, String> picks,
    required String style,
    required String productId,
    required String colorName,
    required bool isDarkGarment,
    String? mockupUrl,
  }) async {
    _log('generatePreview → POST $_baseUrl/generate-preview (product=$productId, color=$colorName)');
    try {
      final shopifyProductId = _shopifyProductIds[productId];
      final shopifyVariantId = _shopifyVariantIds[productId];

      final response = await http.post(
        Uri.parse('$_baseUrl/generate-preview?format=json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bracketTitle': bracketTitle,
          'championName': championName,
          'teamCount': teamCount,
          'teams': teams,
          'picks': picks,
          'style': style,
          'productId': productId,
          if (shopifyProductId != null) 'shopifyProductId': shopifyProductId,
          if (shopifyVariantId != null) 'shopifyVariantId': shopifyVariantId,
          'colorName': colorName,
          'isDarkGarment': isDarkGarment,
          if (mockupUrl != null) 'mockupUrl': mockupUrl,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = PreviewResult(
          previewUrl: json['previewUrl'] as String,
          svgUrl: json['svgUrl'] as String?,
          printReadyRgbUrl: json['printReadyRgbUrl'] as String?,
          printReadyCmykUrl: json['printReadyCmykUrl'] as String?,
          artifactId: json['artifactId'] as String?,
          previewId: json['previewId'] as String?,
          colorModes: (json['colorModes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
          productMetadata: json['product'] != null
              ? Map<String, dynamic>.from(json['product'] as Map)
              : null,
          isServerRendered: true,
        );
        _log('generatePreview ← SERVER OK  artifactId=${result.artifactId}  previewUrl=${result.previewUrl}');
        return result;
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _log('generatePreview ← FALLBACK  error=$e');
      return PreviewResult(
        previewUrl: '',
        isServerRendered: false,
        error: e.toString(),
      );
    }
  }

  /// Fetch preview image bytes (binary JPEG) AND parse artifactId + previewUrl
  /// from response headers.
  ///
  /// The server returns:
  ///   - Body: JPEG image bytes
  ///   - Header X-Artifact-Id: the artifact ID for checkout
  ///   - Header X-Preview-Id: the preview file ID
  ///
  /// Returns a [PreviewImageResult] containing the image bytes and metadata,
  /// or null if the server is unreachable.
  static Future<PreviewImageResult?> fetchPreviewImageWithMeta({
    required String bracketTitle,
    required String championName,
    required int teamCount,
    required List<String> teams,
    required Map<String, String> picks,
    required String style,
    required String productId,
    required String colorName,
    required bool isDarkGarment,
  }) async {
    _log('fetchPreviewImage → POST $_baseUrl/generate-preview (product=$productId, color=$colorName)');
    try {
      final shopifyProductId = _shopifyProductIds[productId];

      final response = await http.post(
        Uri.parse('$_baseUrl/generate-preview'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bracketTitle': bracketTitle,
          'championName': championName,
          'teamCount': teamCount,
          'teams': teams,
          'picks': picks,
          'style': style,
          'productId': productId,
          if (shopifyProductId != null) 'shopifyProductId': shopifyProductId,
          'colorName': colorName,
          'isDarkGarment': isDarkGarment,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final artifactId = response.headers['x-artifact-id'];
        final previewId = response.headers['x-preview-id'];
        _log('fetchPreviewImage ← SERVER OK  ${response.bodyBytes.length} bytes  '
            'artifactId=$artifactId  previewId=$previewId');
        return PreviewImageResult(
          imageBytes: response.bodyBytes,
          artifactId: artifactId,
          previewId: previewId,
        );
      }
      _log('fetchPreviewImage ← SERVER ${response.statusCode}');
    } catch (e) {
      _log('fetchPreviewImage ← FALLBACK (garment widget)  error=$e');
    }
    return null;
  }

  /// Legacy: fetch preview image bytes only (no metadata).
  /// Kept for backward compat; prefer [fetchPreviewImageWithMeta].
  static Future<Uint8List?> fetchPreviewImage({
    required String bracketTitle,
    required String championName,
    required int teamCount,
    required List<String> teams,
    required Map<String, String> picks,
    required String style,
    required String productId,
    required String colorName,
    required bool isDarkGarment,
  }) async {
    final result = await fetchPreviewImageWithMeta(
      bracketTitle: bracketTitle,
      championName: championName,
      teamCount: teamCount,
      teams: teams,
      picks: picks,
      style: style,
      productId: productId,
      colorName: colorName,
      isDarkGarment: isDarkGarment,
    );
    return result?.imageBytes;
  }

  // ─── SHOPIFY CHECKOUT ──────────────────────────────────────────

  /// Build the Shopify checkout URL with bracket data as line-item properties.
  ///
  /// URL format:
  ///   https://backmybracket.com/cart/{variantId}:1?properties[artifact_id]=...&properties[bracket_id]=...
  ///
  /// Property keys MUST match the webhook's extractOrderData() expectations:
  ///   bracket_id       -> identifies which bracket design
  ///   bracket_title    -> display name of the bracket
  ///   champion_name    -> champion pick text
  ///   team_count       -> number as string ("16")
  ///   teams            -> JSON-encoded array of team names
  ///   picks            -> JSON-encoded map of bracket picks
  ///   print_style      -> "classic" | "premium" | "bold"
  ///   color            -> garment color ("Black")
  ///   size             -> garment size ("L")
  ///   palette          -> "light" (dark garment) | "dark" (light garment)
  ///   product_id       -> internal BMB product ID ("bp_grid_iron")
  ///   artifact_id      -> links to pre-generated print files
  ///   preview_url      -> URL to the preview JPEG (for reference)
  ///
  /// All values are URI-encoded. Shopify stores them as line_item.properties
  /// and forwards them in the orders/paid webhook payload.
  static String buildShopifyCheckoutUrl({
    required String productId,
    required String bracketId,
    required String bracketTitle,
    required String championName,
    required int teamCount,
    required List<String> teams,
    required Map<String, String> picks,
    required String printStyle,
    required String colorName,
    required String size,
    required bool isDarkGarment,
    String? artifactId,
    String? previewUrl,
    String? shopifyProductUrl,
    String? variantIdOverride,
  }) {
    final variantId = variantIdOverride
        ?? _shopifyVariantIds[productId]
        ?? '';

    // Build the line-item properties map.
    // Key order: artifact_id and bracket_id first so they appear early in the URL.
    final properties = <String, String>{
      'bracket_id': bracketId,
      if (artifactId != null && artifactId.isNotEmpty) 'artifact_id': artifactId,
      if (previewUrl != null && previewUrl.isNotEmpty) 'preview_url': previewUrl,
      'bracket_title': bracketTitle,
      'champion_name': championName,
      'team_count': teamCount.toString(),
      'teams': jsonEncode(teams),
      'picks': jsonEncode(picks),
      'print_style': printStyle,
      'color': colorName,
      'size': size,
      'palette': isDarkGarment ? 'light' : 'dark',
      'product_id': productId,
    };

    // Shopify cart permalink: /cart/<variantId>:<qty>?properties[key]=value&...
    // All property keys and values are URI-encoded.
    String buildQuery(Map<String, String> props) {
      return props.entries
          .map((e) =>
              'properties%5B${Uri.encodeComponent(e.key)}%5D=${Uri.encodeComponent(e.value)}')
          .join('&');
    }

    if (variantId.isNotEmpty) {
      final url = '$_shopifyStoreUrl/cart/$variantId:1?${buildQuery(properties)}';
      _log('buildShopifyCheckoutUrl → cart URL  artifactId=$artifactId');
      return url;
    }

    // Fallback: product page deep link (when variant ID is unknown)
    final handle = _shopifyProductHandles[productId] ?? 'bmb-grid-iron-tech-fleece-hoodie';
    final baseUrl = shopifyProductUrl ?? '$_shopifyStoreUrl/products/$handle';
    return '$baseUrl?${buildQuery(properties)}';
  }

  /// Get the Shopify product page URL for a given product ID.
  static String getShopifyProductUrl(String productId) {
    final handle = _shopifyProductHandles[productId] ?? 'bmb-grid-iron-tech-fleece-hoodie';
    return '$_shopifyStoreUrl/products/$handle';
  }

  /// Get the Shopify numeric product ID for a given internal product ID.
  static String? getShopifyProductId(String productId) {
    return _shopifyProductIds[productId];
  }

  // ─── FULFILLMENT STATUS ────────────────────────────────────────

  /// Check the fulfillment status of a Shopify order.
  static Future<Map<String, dynamic>?> getFulfillmentStatus(String shopifyOrderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/fulfillment/$shopifyOrderId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      _log('getFulfillmentStatus failed: $e');
    }
    return null;
  }

  // ─── HEALTH CHECK ──────────────────────────────────────────────

  /// Check if the merch server is reachable.
  static Future<bool> isServerAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── LOGGING ───────────────────────────────────────────────────

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[$_tag] $message');
    }
  }
}

/// Result of a JSON preview generation request.
class PreviewResult {
  final String previewUrl;
  final String? svgUrl;
  final String? printReadyRgbUrl;
  final String? printReadyCmykUrl;
  final String? artifactId;
  final String? previewId;
  final List<String>? colorModes;
  final Map<String, dynamic>? productMetadata;
  final bool isServerRendered;
  final String? error;

  const PreviewResult({
    required this.previewUrl,
    this.svgUrl,
    this.printReadyRgbUrl,
    this.printReadyCmykUrl,
    this.artifactId,
    this.previewId,
    this.colorModes,
    this.productMetadata,
    required this.isServerRendered,
    this.error,
  });

  /// Legacy getter for backward compatibility
  String? get printReadyUrl => printReadyRgbUrl;
}

/// Result of a binary preview image fetch, including server-returned metadata.
class PreviewImageResult {
  final Uint8List imageBytes;
  final String? artifactId;
  final String? previewId;

  const PreviewImageResult({
    required this.imageBytes,
    this.artifactId,
    this.previewId,
  });
}
