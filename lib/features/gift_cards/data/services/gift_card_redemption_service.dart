import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/gift_cards/data/models/gift_card_models.dart';
import 'package:bmb_mobile/features/gift_cards/data/services/tremendous_service.dart';

/// Handles the full gift-card redemption flow:
///   1. Verify user balance >= credits required
///   2. Deduct credits from Firestore + SharedPreferences
///   3. Call Tremendous API (or demo mode) to create order
///   4. Log credit_transaction in Firestore
///   5. Save order locally for history
///   6. Refund credits on failure
class GiftCardRedemptionService {
  GiftCardRedemptionService._();
  static final GiftCardRedemptionService instance =
      GiftCardRedemptionService._();

  final _firestore = FirestoreService.instance;
  final _tremendous = TremendousService.instance;
  final _currentUser = CurrentUserService.instance;

  // ═════════════════════════════════════════════════════════════════════
  // USER ACCESSORS (for charity prize flow)
  // ═════════════════════════════════════════════════════════════════════

  String getCurrentUserId() => _currentUser.userId;
  String getCurrentEmail() => _currentUser.email;
  String getCurrentDisplayName() => _currentUser.displayName;

  // ═════════════════════════════════════════════════════════════════════
  // BALANCE HELPERS
  // ═════════════════════════════════════════════════════════════════════

  /// Get the current user's credit balance from Firestore, fallback prefs.
  Future<double> getUserBalance() async {
    try {
      final userId = _currentUser.userId;
      final user = await _firestore.getUser(userId);
      if (user != null) {
        final bal = (user['credits_balance'] as num?)?.toDouble() ?? 0.0;
        // Sync to prefs
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('bmb_bucks_balance', bal);
        return bal;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GCRedemption] Firestore balance read failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('bmb_bucks_balance') ?? 0.0;
  }

  // ═════════════════════════════════════════════════════════════════════
  // REDEMPTION FLOW
  // ═════════════════════════════════════════════════════════════════════

  /// Redeem a gift card. Returns the order on success, null on failure.
  /// Throws [InsufficientCreditsException] if balance too low.
  Future<GiftCardOrder?> redeem({
    required GiftCardBrand brand,
    required double amount,
  }) async {
    final creditsRequired = brand.creditsForAmount(amount);
    final balance = await getUserBalance();
    final userId = _currentUser.userId;
    final email = _currentUser.email;

    // 1. Check balance
    if (balance < creditsRequired) {
      throw InsufficientCreditsException(
        required: creditsRequired,
        available: balance.toInt(),
      );
    }

    // 2. Deduct credits (optimistic)
    final newBalance = balance - creditsRequired;
    await _deductCredits(userId, creditsRequired, newBalance);

    try {
      // 3. Create Tremendous order
      final order = await _tremendous.createOrder(
        userId: userId,
        brandId: brand.id,
        brandName: brand.name,
        amount: amount,
        recipientEmail: email.isNotEmpty ? email : 'user@backmybracket.com',
        recipientName: _currentUser.displayName,
      );

      if (order == null) {
        // Refund on API failure
        await _refundCredits(userId, creditsRequired, balance);
        return null;
      }

      // 4. Log the credit_transaction
      await _logTransaction(userId, creditsRequired, brand.name, amount, order.orderId);

      // 5. Save order locally
      await _saveOrderLocally(userId, order);

      return order;
    } catch (e) {
      // Refund on any error
      if (kDebugMode) debugPrint('[GCRedemption] Order error, refunding: $e');
      await _refundCredits(userId, creditsRequired, balance);
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // ORDER HISTORY
  // ═════════════════════════════════════════════════════════════════════

  Future<List<GiftCardOrder>> getOrderHistory() async {
    final userId = _currentUser.userId;
    return _tremendous.getOrderHistory(userId);
  }

  // ═════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _deductCredits(
      String userId, int amount, double newBalance) async {
    try {
      await _firestore.incrementUserCredits(userId, -amount);
    } catch (e) {
      if (kDebugMode) debugPrint('[GCRedemption] Firestore deduct failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bmb_bucks_balance', newBalance);
  }

  Future<void> _refundCredits(
      String userId, int amount, double originalBalance) async {
    try {
      await _firestore.incrementUserCredits(userId, amount);
    } catch (e) {
      if (kDebugMode) debugPrint('[GCRedemption] Firestore refund failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bmb_bucks_balance', originalBalance);
  }

  Future<void> _logTransaction(String userId, int credits,
      String brandName, double faceValue, String orderId) async {
    try {
      await _firestore.addCreditTransaction({
        'user_id': userId,
        'amount': -credits,
        'type': 'gift_card_redemption',
        'reason': '\$$faceValue $brandName gift card (order: $orderId)',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[GCRedemption] Transaction log failed: $e');
    }
  }

  Future<void> _saveOrderLocally(String userId, GiftCardOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'gc_orders_$userId';
    final orders = prefs.getStringList(key) ?? [];
    orders.insert(0, jsonEncode(order.toMap()));
    await prefs.setStringList(key, orders);
  }
}

/// Thrown when the user does not have enough credits.
class InsufficientCreditsException implements Exception {
  final int required;
  final int available;
  InsufficientCreditsException({required this.required, required this.available});

  @override
  String toString() =>
      'Need $required credits but only have $available.';
}
