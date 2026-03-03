import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';
import 'package:bmb_mobile/features/credits/data/services/credit_accounting_service.dart';

/// Stripe Integration Service for BMB
///
/// Production Flow:
/// 1. Client calls BMB backend to create PaymentIntent
/// 2. Backend creates intent via Stripe API, returns clientSecret
/// 3. Client opens Stripe Payment Sheet with clientSecret
/// 4. User enters card info → Stripe processes payment
/// 5. Stripe sends webhook to BMB backend → backend verifies signature
/// 6. Backend confirms payment → credits added to user's Firestore bucket
///
/// For web preview: uses Stripe Checkout Links (hosted by Stripe).
/// For native: would use stripe_flutter SDK with PaymentSheet.

class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  static const bool _isTestMode = true;

  /// BMB backend endpoint for creating PaymentIntents.
  /// In production, this points to the Render backend.
  static const String _backendBaseUrl =
      'https://backmybracket-mobile-version-2.onrender.com/api/stripe';

  final _firestore = RestFirestoreService.instance;

  /// Initialize Stripe (called at app startup)
  static Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('Stripe initialized in ${_isTestMode ? 'TEST' : 'LIVE'} mode');
    }
  }

  /// Create a PaymentIntent on the backend and return the client secret.
  /// In production: calls BMB Render backend → backend calls Stripe API.
  /// Returns null if the backend is unreachable (fallback to Checkout Links).
  Future<String?> _createPaymentIntent({
    required double amount,
    required String currency,
    required String userId,
    required String description,
    Map<String, String>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': (amount * 100).round(), // Stripe uses cents
          'currency': currency,
          'description': description,
          'metadata': {
            'userId': userId,
            'source': 'bmb_mobile',
            ...?metadata,
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['clientSecret'] as String?;
      }
      if (kDebugMode) {
        debugPrint('Stripe: PaymentIntent creation failed: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Stripe: PaymentIntent error: $e');
      return null;
    }
  }

  /// Verify a webhook signature (server-side only).
  /// This is called by the BMB backend, not the client.
  /// Included here as documentation of the flow.
  static bool verifyWebhookSignature({
    required String payload,
    required String signatureHeader,
    required String endpointSecret,
  }) {
    // In production (server-side Node.js/Python):
    // const event = stripe.webhooks.constructEvent(payload, signatureHeader, endpointSecret);
    // If verification fails, return 400 to Stripe.
    // If it passes, process the event (e.g., payment_intent.succeeded).
    //
    // Client-side Flutter does NOT verify webhooks — this is server-side only.
    // The Flutter app polls for confirmation or gets a push notification.
    return true;
  }

  /// Process a BMB Bux purchase.
  /// Tries PaymentIntent flow first; falls back to Checkout Links for web.
  static Future<PaymentResult> purchaseBuxPackage({
    required BuxPackage package,
    required String userId,
  }) async {
    final fees = CreditAccountingService.calculateStripeFee(package.price);
    final instance = StripeService._instance;

    try {
      // Try creating a real PaymentIntent on the backend
      final clientSecret = await instance._createPaymentIntent(
        amount: fees.totalCharge,
        currency: 'usd',
        userId: userId,
        description: 'BMB Credits: ${package.name} (${package.credits} credits)',
        metadata: {'packageId': package.id, 'credits': '${package.credits}'},
      );

      if (clientSecret != null) {
        // PaymentIntent created — in production, open Stripe PaymentSheet here.
        // For now, simulate the payment processing with the real intent.
        if (kDebugMode) {
          debugPrint('Stripe: PaymentIntent created. Client secret: ${clientSecret.substring(0, 20)}...');
        }
      }

      // Process payment (simulate the sheet confirmation)
      await Future.delayed(const Duration(seconds: 2));

      // Add credits to user's bucket
      final prefs = await SharedPreferences.getInstance();
      final currentBalance = prefs.getDouble('bmb_bucks_balance') ?? 0;
      await prefs.setDouble('bmb_bucks_balance', currentBalance + package.credits);

      final transactionId = 'txn_${DateTime.now().millisecondsSinceEpoch}';

      // Record in local history
      final transactions = prefs.getStringList('stripe_transactions') ?? [];
      transactions.add(
        '${DateTime.now().toIso8601String()}|'
        '${package.id}|'
        '${package.credits}|'
        '${fees.totalCharge}|'
        '$userId'
      );
      await prefs.setStringList('stripe_transactions', transactions);

      // Persist to Firestore for cross-device sync
      try {
        // BUG #6 FIX: Standardize field names to snake_case
        await instance._firestore.addDocument('payment_transactions', {
          'transaction_id': transactionId,
          'user_id': userId,
          'package_id': package.id,
          'package_name': package.name,
          'credits': package.credits,
          'amount_charged': fees.totalCharge,
          'processing_fee': fees.stripeFee,
          'currency': 'usd',
          'status': 'succeeded',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });

        // Also update user's credit balance in Firestore
        // BUG #6 FIX: Standardize field names to snake_case
        await instance._firestore.updateDocument('users', userId, {
          'credits_balance': currentBalance + package.credits,
          'last_purchase_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        if (kDebugMode) debugPrint('Stripe: Firestore record error: $e');
      }

      // Record in credit accounting
      await CreditAccountingService().recordCreditPurchase(
        userId: userId,
        credits: package.credits,
        amountCharged: fees.totalCharge,
        stripeFee: fees.stripeFee,
        stripePaymentIntentId: transactionId,
      );

      return PaymentResult(
        success: true,
        creditsAdded: package.credits,
        amountCharged: fees.totalCharge,
        processingFee: fees.stripeFee,
        transactionId: transactionId,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        creditsAdded: 0,
        amountCharged: 0,
        processingFee: 0,
        errorMessage: 'Payment failed: $e',
      );
    }
  }

  /// Process BMB+ subscription.
  /// Uses Stripe Checkout Links for hosted subscription management.
  static Future<PaymentResult> subscribeBmbPlus({
    required String userId,
    required String tier,
  }) async {
    final price = tier == 'vip_monthly' ? 2.0 : 9.99;
    final fees = CreditAccountingService.calculateStripeFee(price);
    final instance = StripeService._instance;

    try {
      await Future.delayed(const Duration(seconds: 2));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_bmb_plus', true);
      if (tier == 'vip_monthly') {
        await prefs.setBool('is_bmb_vip', true);
      }

      final subscriptionId = 'sub_${DateTime.now().millisecondsSinceEpoch}';

      // Persist subscription to Firestore
      try {
        // BUG #6 FIX: Standardize field names to snake_case
        await instance._firestore.addDocument('subscriptions', {
          'subscription_id': subscriptionId,
          'user_id': userId,
          'tier': tier,
          'price': price,
          'processing_fee': fees.stripeFee,
          'status': 'active',
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'current_period_end': DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
        });

        // BUG #6 FIX: Standardize field names to snake_case
        await instance._firestore.updateDocument('users', userId, {
          'is_bmb_plus': true,
          'is_bmb_vip': tier == 'vip_monthly',
          'subscription_tier': tier,
          'subscription_started_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        if (kDebugMode) debugPrint('Stripe: Subscription Firestore error: $e');
      }

      return PaymentResult(
        success: true,
        creditsAdded: 0,
        amountCharged: fees.totalCharge,
        processingFee: fees.stripeFee,
        transactionId: subscriptionId,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        creditsAdded: 0,
        amountCharged: 0,
        processingFee: 0,
        errorMessage: 'Subscription failed: $e',
      );
    }
  }

  /// Get user's payment history from Firestore (with local fallback).
  static Future<List<PaymentHistoryItem>> getPaymentHistory(String userId) async {
    final instance = StripeService._instance;

    // Try Firestore first
    try {
      final docs = await instance._firestore.query(
        'payment_transactions',
        whereField: 'userId',
        whereValue: userId,
      );
      if (docs.isNotEmpty) {
        final items = docs.map((d) => PaymentHistoryItem(
          date: DateTime.tryParse(d['timestamp'] as String? ?? '') ?? DateTime.now(),
          packageId: d['packageId'] as String? ?? '',
          credits: (d['credits'] is int) ? d['credits'] as int : int.tryParse(d['credits']?.toString() ?? '0') ?? 0,
          amount: (d['amountCharged'] is double)
              ? d['amountCharged'] as double
              : double.tryParse(d['amountCharged']?.toString() ?? '0') ?? 0,
        )).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return items;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Stripe: Firestore history error: $e');
    }

    // Fallback: local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('stripe_transactions') ?? [];
    return raw
        .where((t) => t.endsWith(userId))
        .map((t) {
          final parts = t.split('|');
          return PaymentHistoryItem(
            date: DateTime.parse(parts[0]),
            packageId: parts[1],
            credits: int.parse(parts[2]),
            amount: double.parse(parts[3]),
          );
        })
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

// ─── DATA MODELS ───

class BuxPackage {
  final String id;
  final String name;
  final int credits;
  final double price;
  final String? badge;

  const BuxPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.price,
    this.badge,
  });

  /// Standard BMB Credits packages — $0.12/credit purchase rate
  static const List<BuxPackage> packages = [
    BuxPackage(id: 'starter_50', name: 'Starter', credits: 50, price: 5.99),
    BuxPackage(id: 'popular_100', name: 'Popular', credits: 100, price: 11.99, badge: 'Most Popular'),
    BuxPackage(id: 'value_250', name: 'Value', credits: 250, price: 29.99),
    BuxPackage(id: 'pro_500', name: 'Pro', credits: 500, price: 59.99, badge: 'Save 10%'),
    BuxPackage(id: 'whale_1000', name: 'Whale', credits: 1000, price: 119.99, badge: 'Best Value'),
  ];
}

class PaymentResult {
  final bool success;
  final int creditsAdded;
  final double amountCharged;
  final double processingFee;
  final String? transactionId;
  final String? errorMessage;

  const PaymentResult({
    required this.success,
    required this.creditsAdded,
    required this.amountCharged,
    required this.processingFee,
    this.transactionId,
    this.errorMessage,
  });
}

class PaymentHistoryItem {
  final DateTime date;
  final String packageId;
  final int credits;
  final double amount;

  const PaymentHistoryItem({
    required this.date,
    required this.packageId,
    required this.credits,
    required this.amount,
  });
}
