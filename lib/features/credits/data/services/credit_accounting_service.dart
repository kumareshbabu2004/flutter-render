import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

/// Credit Accounting Flow — UPDATED CREDIT ECONOMY
///
/// Purchase rate: 1 credit = $0.12 (what users pay)
/// Redemption rate: 1 credit = $0.10 (what credits are worth in store)
/// Spread: $0.02 per credit → BMB margin
///
/// Gift card surcharge: +5 credits per card → $0.50 BMB fee per redemption
///
/// Revenue Flow:
///   User buys 100 credits for $11.99 → Stripe fee $0.65 → BMB nets $1.35 pure margin
///   User redeems 105 credits for $10 gift card → BMB nets $0.50 from surcharge
///
/// Platform Fee (Brackets):
///   Player pays entry credits → 90% to host prize pool, 10% to BMB Admin Bucket
///
/// BMB Admin Account:
///   userId: 'bmb_platform'
///   Purpose: Collects platform fees, tracks total revenue
///
/// Stripe Integration:
///   User buys BMB Credits via Stripe → Stripe charges card → credits added to bucket

class CreditAccountingService {
  static final CreditAccountingService _instance = CreditAccountingService._internal();
  factory CreditAccountingService() => _instance;
  CreditAccountingService._internal();

  static const String bmbAdminId = 'bmb_platform';
  static const String bmbAdminName = 'BMB Platform';
  static const double platformFeeRate = 0.10; // 10% of entry credits to BMB
  static const double creditPurchaseRate = 0.12; // $0.12 per credit (what user pays)
  static const double creditRedemptionRate = 0.10; // $0.10 per credit (store value)
  static const int giftCardSurcharge = 5; // +5 credits per gift card ($0.50 BMB fee)
  static const double stripeProcessingRate = 0.029; // 2.9%
  static const double stripeFixedFee = 0.30; // $0.30

  final _firestore = RestFirestoreService.instance;

  // ─── PLATFORM FEE CALCULATION ───
  /// Calculate BMB platform fee for a bracket
  static PlatformFeeBreakdown calculatePlatformFee({
    required int entryCredits,
    required int playerCount,
    bool isCharity = false,
  }) {
    final totalCreditsCollected = entryCredits * playerCount;
    final bmbPlatformFee = (totalCreditsCollected * platformFeeRate).round();
    final hostOrCharityCredits = totalCreditsCollected - bmbPlatformFee;

    return PlatformFeeBreakdown(
      entryCreditsPerPlayer: entryCredits,
      playerCount: playerCount,
      totalCreditsCollected: totalCreditsCollected,
      bmbPlatformFee: bmbPlatformFee,
      hostPrizePool: isCharity ? 0 : hostOrCharityCredits,
      charityCredits: isCharity ? hostOrCharityCredits : 0,
      isCharity: isCharity,
    );
  }

  // ─── STRIPE FEE CALCULATION ───
  /// Calculate what user pays at checkout (including Stripe processing fee)
  static StripeFeeBreakdown calculateStripeFee(double creditsPurchaseAmount) {
    final stripeFee = (creditsPurchaseAmount * stripeProcessingRate) + stripeFixedFee;
    final totalCharge = creditsPurchaseAmount + stripeFee;

    return StripeFeeBreakdown(
      creditsPurchaseAmount: creditsPurchaseAmount,
      stripeFee: double.parse(stripeFee.toStringAsFixed(2)),
      totalCharge: double.parse(totalCharge.toStringAsFixed(2)),
      bmbNetRevenue: creditsPurchaseAmount,
    );
  }

  // ─── ADMIN BUCKET OPERATIONS (Firestore + SharedPreferences) ───
  /// Record platform fee collection — persists to both local and Firestore.
  Future<void> collectPlatformFee({
    required String bracketId,
    required int feeAmount,
  }) async {
    // Local persistence (fast, offline)
    final prefs = await SharedPreferences.getInstance();
    final currentBalance = prefs.getDouble('bmb_admin_bucket_balance') ?? 0;
    await prefs.setDouble('bmb_admin_bucket_balance', currentBalance + feeAmount);

    final transactions = prefs.getStringList('bmb_admin_transactions') ?? [];
    final timestamp = DateTime.now().toUtc().toIso8601String();
    transactions.add('$timestamp|platform_fee|$bracketId|$feeAmount');
    await prefs.setStringList('bmb_admin_transactions', transactions);

    // Firestore persistence (durable, cross-device)
    try {
      await _firestore.addDocument('credit_transactions', {
        'type': 'platform_fee',
        'bracket_id': bracketId,
        'amount': feeAmount,
        'admin_id': bmbAdminId,
        'timestamp': timestamp,
        'running_balance': currentBalance + feeAmount,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('CreditAccounting: Firestore write error: $e');
    }

    if (kDebugMode) {
      debugPrint('BMB Admin: Collected $feeAmount credits from bracket $bracketId');
      debugPrint('BMB Admin Balance: ${currentBalance + feeAmount}');
    }
  }

  /// Record a credit purchase event.
  Future<void> recordCreditPurchase({
    required String userId,
    required int credits,
    required double amountCharged,
    required double stripeFee,
    String? stripePaymentIntentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    // Local: record in transaction list
    final transactions = prefs.getStringList('bmb_admin_transactions') ?? [];
    transactions.add('$timestamp|credit_purchase|$userId|$credits');
    await prefs.setStringList('bmb_admin_transactions', transactions);

    // Firestore: durable record
    try {
      await _firestore.addDocument('credit_transactions', {
        'type': 'credit_purchase',
        'user_id': userId,
        'credits': credits,
        'amount_charged': amountCharged,
        'stripe_fee': stripeFee,
        'stripe_payment_intent_id': stripePaymentIntentId ?? '',
        'admin_id': bmbAdminId,
        'timestamp': timestamp,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('CreditAccounting: Firestore purchase write error: $e');
    }
  }

  /// Record a gift-card redemption event.
  Future<void> recordGiftCardRedemption({
    required String userId,
    required int creditsSpent,
    required String brand,
    required double faceValue,
    String? tremendousOrderId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toUtc().toIso8601String();

    final transactions = prefs.getStringList('bmb_admin_transactions') ?? [];
    transactions.add('$timestamp|gift_card_redemption|$userId|$creditsSpent');
    await prefs.setStringList('bmb_admin_transactions', transactions);

    try {
      await _firestore.addDocument('credit_transactions', {
        'type': 'gift_card_redemption',
        'user_id': userId,
        'credits_spent': creditsSpent,
        'brand': brand,
        'face_value': faceValue,
        'surcharge_credits': giftCardSurcharge,
        'tremendous_order_id': tremendousOrderId ?? '',
        'timestamp': timestamp,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('CreditAccounting: Firestore redemption write error: $e');
    }
  }

  /// Get BMB admin balance
  Future<double> getAdminBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('bmb_admin_bucket_balance') ?? 0;
  }

  /// Get admin transaction history — tries Firestore first, falls back to local.
  Future<List<AdminTransaction>> getAdminTransactions() async {
    // Try Firestore first for authoritative data
    try {
      final docs = await _firestore.query(
        'credit_transactions',
        whereField: 'admin_id',
        whereValue: bmbAdminId,
      );
      if (docs.isNotEmpty) {
        final firestoreTxns = docs.map((d) => AdminTransaction(
          timestamp: DateTime.tryParse(d['timestamp'] as String? ?? '') ?? DateTime.now(),
          type: d['type'] as String? ?? 'unknown',
          bracketId: d['bracket_id'] as String? ?? d['user_id'] as String? ?? '',
          amount: (d['amount'] is int)
              ? d['amount'] as int
              : int.tryParse(d['amount']?.toString() ?? '0') ?? 0,
        )).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return firestoreTxns;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CreditAccounting: Firestore read fallback to local: $e');
    }

    // Fallback: local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bmb_admin_transactions') ?? [];
    return raw.map((t) {
      final parts = t.split('|');
      return AdminTransaction(
        timestamp: DateTime.parse(parts[0]),
        type: parts[1],
        bracketId: parts[2],
        amount: int.parse(parts[3]),
      );
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ─── REVENUE SUMMARY ───
  Future<RevenueSummary> getRevenueSummary() async {
    final balance = await getAdminBalance();
    final transactions = await getAdminTransactions();
    final totalPlatformFees = transactions
        .where((t) => t.type == 'platform_fee')
        .fold<int>(0, (sum, t) => sum + t.amount);

    return RevenueSummary(
      adminBalance: balance,
      totalPlatformFees: totalPlatformFees,
      totalBrackets: transactions
          .where((t) => t.type == 'platform_fee')
          .map((t) => t.bracketId)
          .toSet()
          .length,
      cashEquivalent: balance * creditRedemptionRate,
    );
  }
}

// ─── DATA MODELS ───

class PlatformFeeBreakdown {
  final int entryCreditsPerPlayer;
  final int playerCount;
  final int totalCreditsCollected;
  final int bmbPlatformFee;
  final int hostPrizePool;
  final int charityCredits;
  final bool isCharity;

  const PlatformFeeBreakdown({
    required this.entryCreditsPerPlayer,
    required this.playerCount,
    required this.totalCreditsCollected,
    required this.bmbPlatformFee,
    required this.hostPrizePool,
    required this.charityCredits,
    required this.isCharity,
  });
}

class StripeFeeBreakdown {
  final double creditsPurchaseAmount;
  final double stripeFee;
  final double totalCharge;
  final double bmbNetRevenue;

  const StripeFeeBreakdown({
    required this.creditsPurchaseAmount,
    required this.stripeFee,
    required this.totalCharge,
    required this.bmbNetRevenue,
  });

  String get feeExplanation =>
      'A small processing fee is added at checkout to cover secure payment handling.';
}

class AdminTransaction {
  final DateTime timestamp;
  final String type;
  final String bracketId;
  final int amount;

  const AdminTransaction({
    required this.timestamp,
    required this.type,
    required this.bracketId,
    required this.amount,
  });
}

class RevenueSummary {
  final double adminBalance;
  final int totalPlatformFees;
  final int totalBrackets;
  final double cashEquivalent;

  const RevenueSummary({
    required this.adminBalance,
    required this.totalPlatformFees,
    required this.totalBrackets,
    required this.cashEquivalent,
  });
}
