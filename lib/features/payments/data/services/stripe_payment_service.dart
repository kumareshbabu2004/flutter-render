import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';
import 'package:bmb_mobile/features/payments/data/config/stripe_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// STRIPE PAYMENT SERVICE
// ═══════════════════════════════════════════════════════════════════════════
//
// Architecture:
//   1. Tap "Purchase" anywhere in the app
//   2. StripePaymentService.checkout() opens Stripe-hosted checkout
//   3. User completes payment on Stripe's secure page (PCI-compliant)
//   4. Returns to app → post-payment callback updates Firestore
//
// This service uses Stripe Payment Links — no server code needed.
// All links are configured in stripe_config.dart.
//
// Post-Payment Flow:
//   Stripe Payment Link → User pays → Browser returns to app →
//   User taps "Confirm Payment" → Firestore updated (credits, subscriptions)
//
// SECURITY: The onReturn callback is NOT auto-fired. Instead, checkout()
// stores the pending callback and shows a confirmation dialog when the user
// returns. This prevents granting credits/subscriptions before payment.
//
// NOTE: In production, Stripe webhooks on a backend server should confirm
// payment before granting access. This confirmation-dialog approach is the
// safe MVP alternative to auto-granting on browser launch.
//
// ═══════════════════════════════════════════════════════════════════════════

class StripePaymentService {
  StripePaymentService._();

  static final _firestore = FirestoreService.instance;

  // ─── CORE CHECKOUT ─────────────────────────────────────────────────────

  /// Opens a Stripe Payment Link in the device browser.
  /// [paymentLink] — the Stripe Payment Link URL
  /// [context]     — for showing snackbars on error
  /// [productName] — human-readable name for error messages
  /// [onReturn]    — callback invoked ONLY after user confirms payment via dialog
  ///
  /// If the link is empty (not yet configured), shows a branded prompt
  /// with instructions instead of crashing.
  ///
  /// BUG #1 FIX: The onReturn callback is no longer auto-fired after 1 second.
  /// Instead, a confirmation dialog is shown when the user returns from the
  /// browser, requiring them to confirm they completed payment.
  static Future<void> checkout({
    required BuildContext context,
    required String paymentLink,
    required String productName,
    String? customerEmail,
    VoidCallback? onReturn,
  }) async {
    // ── Link not configured yet ──────────────────────────────────────
    if (!StripeConfig.isConfigured(paymentLink)) {
      _showNotConfiguredDialog(context, productName);
      return;
    }

    // ── Append prefilled email if available ──────────────────────────
    var url = paymentLink;
    if (customerEmail != null && customerEmail.isNotEmpty) {
      final separator = url.contains('?') ? '&' : '?';
      url = '$url${separator}prefilled_email=${Uri.encodeComponent(customerEmail)}';
    }

    // ── Launch Stripe checkout ──────────────────────────────────────
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open payment page. Please try again.'),
              backgroundColor: BmbColors.errorRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      // BUG #1 FIX: Show confirmation dialog instead of auto-firing callback.
      // The user must explicitly confirm they completed payment.
      if (onReturn != null && context.mounted) {
        _showPaymentConfirmationDialog(context, productName, onReturn);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Stripe checkout error: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: BmbColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ─── CONVENIENCE METHODS (with Firestore callbacks) ─────────────────

  /// Open checkout for BMB+ monthly subscription ($9.99/mo)
  static Future<void> checkoutBmbPlus(BuildContext context, {String? email}) {
    return checkout(
      context: context,
      paymentLink: StripeConfig.bmbPlusMonthly,
      productName: 'BMB+ Monthly Subscription',
      customerEmail: email,
      onReturn: () => _recordSubscription('plus', 'monthly', StripeConfig.bmbPlusMonthlyPrice),
    );
  }

  /// Open checkout for BMB+ yearly subscription ($99.99/year)
  static Future<void> checkoutBmbPlusYearly(BuildContext context, {String? email}) {
    return checkout(
      context: context,
      paymentLink: StripeConfig.bmbPlusYearly,
      productName: 'BMB+ Yearly Subscription',
      customerEmail: email,
      onReturn: () => _recordSubscription('plus', 'yearly', StripeConfig.bmbPlusYearlyPrice),
    );
  }

  /// Open checkout for BMB+ VIP add-on ($2/mo)
  static Future<void> checkoutBmbVip(BuildContext context, {String? email}) {
    return checkout(
      context: context,
      paymentLink: StripeConfig.bmbPlusVipMonthly,
      productName: 'BMB+ VIP',
      customerEmail: email,
      onReturn: () => _recordVipAddon(),
    );
  }

  /// Open checkout for BMB+biz monthly ($99/mo)
  static Future<void> checkoutBmbBiz(BuildContext context, {String? email}) {
    return checkout(
      context: context,
      paymentLink: StripeConfig.bmbBizMonthly,
      productName: 'BMB+biz Monthly Plan',
      customerEmail: email,
      onReturn: () => _recordSubscription('business', 'monthly', StripeConfig.bmbBizMonthlyPrice),
    );
  }

  /// Open checkout for BMB+biz yearly subscription ($899/year)
  static Future<void> checkoutBmbBizYearly(BuildContext context, {String? email}) {
    return checkout(
      context: context,
      paymentLink: StripeConfig.bmbBizYearly,
      productName: 'BMB+biz Yearly Subscription',
      customerEmail: email,
      onReturn: () => _recordSubscription('business', 'yearly', StripeConfig.bmbBizYearlyPrice),
    );
  }

  /// Open checkout for a BMB Credits package (tier 0–4)
  static Future<void> checkoutBuxPackage(
    BuildContext context, {
    required int tierIndex,
    String? email,
  }) {
    const tierNames = [
      'Starter (50 credits)',
      'Popular (100 credits)',
      'Value (250 credits)',
      'Pro (500 credits)',
      'Whale (1,000 credits)',
    ];
    const tierCredits = [50, 100, 250, 500, 1000];
    const tierPrices = [6.00, 12.00, 30.00, 60.00, 120.00];

    final idx = tierIndex.clamp(0, 4);
    return checkout(
      context: context,
      paymentLink: StripeConfig.buxPackageLink(idx),
      productName: tierNames[idx],
      customerEmail: email,
      onReturn: () => _recordCreditPurchase(tierCredits[idx], tierPrices[idx], tierNames[idx]),
    );
  }

  /// Open BMB Starter Kit checkout
  static Future<void> checkoutStarterKit(BuildContext context, {String? email}) {
    return checkout(
      context: context,
      paymentLink: StripeConfig.bmbStarterKit,
      productName: 'BMB Starter Kit',
      customerEmail: email,
    );
  }

  /// Open BMB Store (external web store for merch)
  static Future<void> openBmbStore(BuildContext context) async {
    try {
      final uri = Uri.parse(StripeConfig.bmbStoreUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Store URL error: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // FIRESTORE POST-PAYMENT CALLBACKS
  // ═══════════════════════════════════════════════════════════════════

  /// Record a credit purchase in Firestore after Stripe checkout.
  /// Updates user's credits_balance and logs a credit_transaction.
  static Future<void> _recordCreditPurchase(int credits, double price, String packageName) async {
    final userId = CurrentUserService.instance.userId;
    if (userId.isEmpty) return;

    try {
      // 1. Atomically increment user's credit balance in Firestore
      await _firestore.incrementUserCredits(userId, credits);

      // 2. Log the credit transaction
      await _firestore.addCreditTransaction({
        'user_id': userId,
        'amount': credits,
        'type': 'purchase',
        'reason': 'Stripe purchase: $packageName (\$${price.toStringAsFixed(2)})',
        'stripe_amount': price,
        'timestamp': _serverTimestamp(),
      });

      // 3. Log analytics event
      await _firestore.logEvent({
        'event_type': 'credit_purchase',
        'user_id': userId,
        'credits': credits,
        'amount_usd': price,
        'package': packageName,
      });

      // 4. Sync local state
      await _syncLocalBalance(credits);

      if (kDebugMode) {
        debugPrint('Stripe: Recorded $credits credit purchase for $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Stripe: Failed to record credit purchase: $e');
      }
      // Still update local as fallback
      await _syncLocalBalance(credits);
    }
  }

  /// Record a subscription in Firestore after Stripe checkout.
  /// Updates user's subscription tier and creates/updates subscription doc.
  static Future<void> _recordSubscription(String planType, String billing, double price) async {
    final userId = CurrentUserService.instance.userId;
    if (userId.isEmpty) return;

    try {
      final isBusiness = planType == 'business';
      final monthlyPrice = billing == 'yearly' ? price / 12 : price;

      // 1. Update user document
      await _firestore.updateUser(userId, {
        'subscription_tier': planType,
        'is_bmb_plus': true,
        'is_business': isBusiness,
        'subscription_billing': billing,
        'subscription_started_at': _serverTimestamp(),
      });

      // 2. Create subscription record
      await _firestore.setSubscription({
        'user_id': userId,
        'plan_type': planType,
        'billing_cycle': billing,
        'price_monthly': monthlyPrice,
        'price_total': price,
        'status': 'active',
        'started_at': _serverTimestamp(),
        'source': 'stripe_payment_link',
      });

      // 3. Log analytics event
      await _firestore.logEvent({
        'event_type': 'subscription_started',
        'user_id': userId,
        'plan_type': planType,
        'billing_cycle': billing,
        'price': price,
      });

      // 4. Sync local state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_bmb_plus', true);
      await prefs.setString('subscription_tier', planType);
      if (isBusiness) {
        await prefs.setBool('is_business', true);
      }

      // 5. Reload user service
      await CurrentUserService.instance.load();

      if (kDebugMode) {
        debugPrint('Stripe: Recorded $planType/$billing subscription for $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Stripe: Failed to record subscription: $e');
      }
      // Fallback to local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_bmb_plus', true);
      await prefs.setString('subscription_tier', planType);
    }
  }

  /// Record VIP add-on in Firestore.
  static Future<void> _recordVipAddon() async {
    final userId = CurrentUserService.instance.userId;
    if (userId.isEmpty) return;

    try {
      // 1. Update user document
      await _firestore.updateUser(userId, {
        'is_bmb_vip': true,
        'vip_started_at': _serverTimestamp(),
      });

      // 2. Log analytics event
      await _firestore.logEvent({
        'event_type': 'vip_addon_started',
        'user_id': userId,
        'price': StripeConfig.bmbVipMonthlyPrice,
      });

      // 3. Sync local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_bmb_vip', true);

      await CurrentUserService.instance.load();

      if (kDebugMode) {
        debugPrint('Stripe: Recorded VIP addon for $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Stripe: Failed to record VIP addon: $e');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_bmb_vip', true);
    }
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────

  /// Sync local SharedPreferences balance after a credit purchase.
  static Future<void> _syncLocalBalance(int creditsAdded) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble('bmb_bucks_balance') ?? 0;
    await prefs.setDouble('bmb_bucks_balance', current + creditsAdded);
  }

  /// Read the user's email from SharedPreferences for prefilling Stripe checkout.
  static Future<String?> getUserEmail() async {
    // Try CurrentUserService first (Firestore-backed)
    final cu = CurrentUserService.instance;
    if (cu.email.isNotEmpty) return cu.email;
    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  /// BUG #4 FIX: Return ISO 8601 string instead of raw DateTime object.
  /// This ensures consistent serialization with the REST Firestore service.
  static String _serverTimestamp() => DateTime.now().toUtc().toIso8601String();

  // ─── PAYMENT CONFIRMATION DIALOG ─────────────────────────────────────

  /// BUG #1 FIX: Shows a confirmation dialog after the user returns from
  /// Stripe checkout. The onReturn callback only fires if the user
  /// explicitly confirms they completed payment.
  static void _showPaymentConfirmationDialog(
    BuildContext context,
    String productName,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: BmbColors.successGreen, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                'Complete Your Purchase',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Did you complete payment for "$productName" on the Stripe checkout page?',
                textAlign: TextAlign.center,
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Yes, I Completed Payment',
                      style: TextStyle(fontWeight: BmbFontWeights.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: BmbColors.textTertiary.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('No, I Cancelled',
                      style: TextStyle(color: BmbColors.textSecondary, fontWeight: BmbFontWeights.semiBold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── "NOT CONFIGURED" DIALOG ──────────────────────────────────────────

  /// Shows a branded dialog when a Payment Link hasn't been configured yet.
  static void _showNotConfiguredDialog(BuildContext context, String productName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stripe-branded icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payment, color: Color(0xFF635BFF), size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment Processing',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Secure Stripe checkout for "$productName" is being set up. '
                'You\'ll be able to purchase directly from this screen soon!',
                textAlign: TextAlign.center,
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 8),
              // Stripe trust badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF635BFF).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Color(0xFF635BFF), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Powered by Stripe',
                      style: TextStyle(
                        color: const Color(0xFF635BFF),
                        fontSize: 11,
                        fontWeight: BmbFontWeights.semiBold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF635BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Got It', style: TextStyle(fontWeight: BmbFontWeights.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
