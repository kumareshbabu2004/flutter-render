/// BMB Store product categories
enum StoreCategory {
  giftCards,
  merch,
  digital,
  customBracket,
}

/// Product type determines redemption flow
enum ProductType {
  digitalGiftCard, // delivers a code to in-app inbox
  physicalMerch, // requires shipping address
  digitalItem, // instant delivery (avatars, themes, badges)
  customBracketPrint, // printed bracket picks (physical, requires shipping)
}

/// A product in the BMB Store (can be synced with Shopify)
class StoreProduct {
  final String id;
  final String name;
  final String description;
  final int creditsCost; // price in BMB credits
  final StoreCategory category;
  final ProductType type;
  final String imageIcon; // icon name for fallback display
  final String? imageUrl; // Shopify CDN or local asset URL
  final String? shopifyProductId; // linked Shopify product ID (nullable)
  final String? shopifyVariantId; // Shopify variant ID
  final String? brand; // e.g. "Amazon", "Visa", "Nike"
  final double? faceValue; // real dollar value for gift cards
  final bool isAvailable;
  final bool isFeatured;
  final List<String>? sizes; // for merch (S, M, L, XL, etc.)
  final List<String>? colors; // for merch
  final Map<String, dynamic>? metadata; // extra Shopify or custom fields

  const StoreProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.creditsCost,
    required this.category,
    required this.type,
    this.imageIcon = 'card_giftcard',
    this.imageUrl,
    this.shopifyProductId,
    this.shopifyVariantId,
    this.brand,
    this.faceValue,
    this.isAvailable = true,
    this.isFeatured = false,
    this.sizes,
    this.colors,
    this.metadata,
  });

  String get categoryLabel {
    switch (category) {
      case StoreCategory.giftCards:
        return 'Gift Cards';
      case StoreCategory.merch:
        return 'Merch';
      case StoreCategory.digital:
        return 'Digital';
      case StoreCategory.customBracket:
        return 'Custom Bracket';
    }
  }

  bool get isDigitalDelivery =>
      type == ProductType.digitalGiftCard || type == ProductType.digitalItem;

  bool get requiresShipping =>
      type == ProductType.physicalMerch || type == ProductType.customBracketPrint;
}

/// Order status for tracking
enum OrderStatus {
  pending,
  processing,
  fulfilled,
  shipped,
  delivered,
  cancelled,
}

/// A redeemed / purchased order
class StoreOrder {
  final String id;
  final String productId;
  final String productName;
  final ProductType productType;
  final int creditsCost;
  final OrderStatus status;
  final DateTime createdAt;
  final String? redemptionCode; // for digital gift cards
  final String? trackingNumber; // for physical orders
  final String? selectedSize;
  final String? selectedColor;
  final String? shippingAddress;
  final String? bracketId; // for custom bracket prints
  final String? bracketName;
  final Map<String, dynamic>? metadata;

  const StoreOrder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productType,
    required this.creditsCost,
    required this.status,
    required this.createdAt,
    this.redemptionCode,
    this.trackingNumber,
    this.selectedSize,
    this.selectedColor,
    this.shippingAddress,
    this.bracketId,
    this.bracketName,
    this.metadata,
  });

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.fulfilled:
        return 'Fulfilled';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isDigital =>
      productType == ProductType.digitalGiftCard ||
      productType == ProductType.digitalItem;
}

/// In-app inbox message for delivering gift card codes
class InboxMessage {
  final String id;
  final String title;
  final String body;
  final String? code; // gift card / digital code
  final String? orderId;
  final DateTime createdAt;
  final bool isRead;
  final String type; // 'gift_card', 'order_update', 'promo', 'system'

  const InboxMessage({
    required this.id,
    required this.title,
    required this.body,
    this.code,
    this.orderId,
    required this.createdAt,
    this.isRead = false,
    this.type = 'system',
  });
}
