// Gift Card data models for the BMB Gift Card Store.
//
// Economy: 1 credit = $0.10 redemption value.
// Gift card surcharge: +5 credits ($0.50) per redemption.
// Powered by Tremendous API in production.

class GiftCardBrand {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final List<double> denominations; // face values in USD
  final double minAmount;
  final double maxAmount;
  final bool isPopular;
  final String category;
  final bool isCharity; // true for charity donations

  const GiftCardBrand({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.denominations,
    this.minAmount = 5.0,
    this.maxAmount = 500.0,
    this.isPopular = false,
    this.category = 'General',
    this.isCharity = false,
  });

  /// Credits required for a given face value.
  /// 1 credit = $0.10 + 5 credit surcharge
  int creditsForAmount(double amount) => (amount / 0.10).round() + 5;
}

class GiftCardOrder {
  final String orderId;
  final String userId;
  final String brandId;
  final String brandName;
  final double faceValue;
  final int creditsSpent;
  final String status; // pending, processing, delivered, failed
  final String? redemptionCode;
  final String? redemptionUrl;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String? tremendousOrderId;

  const GiftCardOrder({
    required this.orderId,
    required this.userId,
    required this.brandId,
    required this.brandName,
    required this.faceValue,
    required this.creditsSpent,
    required this.status,
    this.redemptionCode,
    this.redemptionUrl,
    required this.createdAt,
    this.deliveredAt,
    this.tremendousOrderId,
  });

  /// Serialize to Map for Firestore / local storage.
  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'userId': userId,
    'brandId': brandId,
    'brandName': brandName,
    'faceValue': faceValue,
    'creditsSpent': creditsSpent,
    'status': status,
    'redemptionCode': redemptionCode,
    'redemptionUrl': redemptionUrl,
    'createdAt': createdAt.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
    'tremendousOrderId': tremendousOrderId,
  };

  /// Deserialize from Map.
  factory GiftCardOrder.fromMap(Map<String, dynamic> m) => GiftCardOrder(
    orderId: m['orderId'] as String? ?? '',
    userId: m['userId'] as String? ?? '',
    brandId: m['brandId'] as String? ?? '',
    brandName: m['brandName'] as String? ?? '',
    faceValue: (m['faceValue'] as num?)?.toDouble() ?? 0.0,
    creditsSpent: (m['creditsSpent'] as num?)?.toInt() ?? 0,
    status: m['status'] as String? ?? 'pending',
    redemptionCode: m['redemptionCode'] as String?,
    redemptionUrl: m['redemptionUrl'] as String?,
    createdAt: m['createdAt'] != null
        ? DateTime.tryParse(m['createdAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    deliveredAt: m['deliveredAt'] != null
        ? DateTime.tryParse(m['deliveredAt'] as String)
        : null,
    tremendousOrderId: m['tremendousOrderId'] as String?,
  );
}

/// Available gift card categories
enum GiftCardCategory {
  popular,
  food,
  shopping,
  entertainment,
  travel,
  charity,
}

extension GiftCardCategoryX on GiftCardCategory {
  String get label {
    switch (this) {
      case GiftCardCategory.popular: return 'Popular';
      case GiftCardCategory.food: return 'Food & Dining';
      case GiftCardCategory.shopping: return 'Shopping';
      case GiftCardCategory.entertainment: return 'Entertainment';
      case GiftCardCategory.travel: return 'Travel';
      case GiftCardCategory.charity: return 'Charity';
    }
  }

  String get icon {
    switch (this) {
      case GiftCardCategory.popular: return 'star';
      case GiftCardCategory.food: return 'restaurant';
      case GiftCardCategory.shopping: return 'shopping_bag';
      case GiftCardCategory.entertainment: return 'movie';
      case GiftCardCategory.travel: return 'flight';
      case GiftCardCategory.charity: return 'favorite';
    }
  }
}
