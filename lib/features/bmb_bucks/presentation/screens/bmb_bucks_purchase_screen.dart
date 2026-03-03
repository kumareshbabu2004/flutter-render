import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';
import 'package:bmb_mobile/features/payments/data/services/stripe_payment_service.dart';
import 'package:bmb_mobile/features/promo/data/services/promo_code_service.dart';

class BmbBucksPurchaseScreen extends StatefulWidget {
  const BmbBucksPurchaseScreen({super.key});
  @override
  State<BmbBucksPurchaseScreen> createState() => _BmbBucksPurchaseScreenState();
}

class _BmbBucksPurchaseScreenState extends State<BmbBucksPurchaseScreen> {
  double _balance = 0;
  int? _selectedPackage;
  bool _processing = false;
  bool _autoReplenish = false;
  bool _promoProcessing = false;
  final _promoController = TextEditingController();
  String? _promoMessage;
  bool _promoSuccess = false;
  // Payment handled by Stripe Payment Links

  // NEW credit economy: $0.12 per credit purchase rate
  // BMB earns $0.02 spread per credit + $0.50 per gift card redemption
  static const _tiers = [
    {'credits': 50, 'price': 6.00, 'label': 'Starter', 'badge': ''},
    {'credits': 100, 'price': 12.00, 'label': 'Popular', 'badge': 'Most Popular'},
    {'credits': 250, 'price': 30.00, 'label': 'Value', 'badge': ''},
    {'credits': 500, 'price': 60.00, 'label': 'Pro', 'badge': 'Save 10%'},
    {'credits': 1000, 'price': 120.00, 'label': 'Whale', 'badge': 'Best Value'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load from Firestore first, fall back to SharedPreferences
    final cu = CurrentUserService.instance;
    final userId = cu.userId;
    if (userId.isNotEmpty) {
      try {
        final userData = await FirestoreService.instance.getUser(userId);
        if (userData != null) {
          final firestoreBalance = (userData['credits_balance'] as num?)?.toDouble() ?? 0;
          setState(() => _balance = firestoreBalance);
          // Sync to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('bmb_bucks_balance', firestoreBalance);
          _autoReplenish = prefs.getBool('auto_replenish') ?? false;
          return;
        }
      } catch (_) {}
    }
    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('bmb_bucks_balance')) {
      await prefs.setDouble('bmb_bucks_balance', 50);
    }
    setState(() {
      _balance = prefs.getDouble('bmb_bucks_balance') ?? 50;
      _autoReplenish = prefs.getBool('auto_replenish') ?? false;
    });
  }

  Future<void> _toggleAutoReplenish(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_replenish', value);
    setState(() => _autoReplenish = value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? 'Auto-Replenish ON — 10 credits will be added when your bucket drops to 10 or below'
            : 'Auto-Replenish turned off'),
        backgroundColor: value ? BmbColors.successGreen : BmbColors.midNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _purchase() async {
    if (_selectedPackage == null) return;
    setState(() => _processing = true);

    final email = await StripePaymentService.getUserEmail();
    if (!mounted) return;

    // Show confirmation before opening Stripe
    final tier = _tiers[_selectedPackage!];
    final credits = tier['credits'] as int;
    final price = tier['price'] as double;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.open_in_new, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Opening Stripe checkout for $credits credits (\$${price.toStringAsFixed(2)})...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF635BFF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );

    await StripePaymentService.checkoutBuxPackage(
      context,
      tierIndex: _selectedPackage!,
      email: email,
    );

    if (!mounted) return;
    setState(() => _processing = false);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text('BMB Bucket',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 20),

                // Balance bucket card
                _buildBucketBalanceCard(),
                const SizedBox(height: 20),

                // Auto-Replenish toggle
                _buildAutoReplenishToggle(),
                const SizedBox(height: 24),

                // Section title
                Text('Choose a Credit Tier',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold)),
                const SizedBox(height: 4),
                Text('Credits go straight into your BMB Bucket',
                    style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),

                // Tier cards (vertical list)
                ...List.generate(_tiers.length, (i) => _buildTierCard(i)),

                const SizedBox(height: 24),

                // ─── PROMO CODE SECTION ────────────────────────────
                _buildPromoCodeSection(),
                const SizedBox(height: 20),

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
                      Icon(Icons.lock, color: const Color(0xFF635BFF), size: 14),
                      const SizedBox(width: 6),
                      Text('Secure checkout powered by Stripe',
                          style: TextStyle(color: const Color(0xFF635BFF), fontSize: 11,
                              fontWeight: BmbFontWeights.semiBold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Purchase button — opens Stripe Checkout
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (_selectedPackage != null && !_processing)
                        ? _purchase
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.gold,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: BmbColors.cardDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _processing
                        ? const SizedBox.shrink()
                        : const Icon(Icons.payment, size: 20),
                    label: _processing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black54))
                        : Text(
                            _selectedPackage != null
                                ? 'Pay \$${(_tiers[_selectedPackage!]['price'] as double).toStringAsFixed(2)} with Stripe'
                                : 'Select a tier to purchase',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: BmbFontWeights.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── BUCKET BALANCE CARD ─────────────────────────────────────────
  Widget _buildBucketBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BmbColors.gold.withValues(alpha: 0.15),
            BmbColors.gold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // Bucket icon + label
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.savings, color: BmbColors.gold, size: 28),
          ),
          const SizedBox(height: 10),
          Text('Your BMB Bucket',
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 13,
                  fontWeight: BmbFontWeights.medium)),
          const SizedBox(height: 4),
          Text('${_balance.toInt()} credits',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 28,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
          if (_autoReplenish) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.autorenew,
                      color: BmbColors.successGreen, size: 14),
                  const SizedBox(width: 4),
                  Text('Auto-Replenish Active',
                      style: TextStyle(
                          color: BmbColors.successGreen,
                          fontSize: 11,
                          fontWeight: BmbFontWeights.semiBold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── AUTO-REPLENISH TOGGLE ───────────────────────────────────────
  Widget _buildAutoReplenishToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _autoReplenish
              ? BmbColors.successGreen.withValues(alpha: 0.4)
              : BmbColors.borderColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _autoReplenish
                      ? BmbColors.successGreen.withValues(alpha: 0.15)
                      : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.autorenew,
                    color: _autoReplenish
                        ? BmbColors.successGreen
                        : BmbColors.textTertiary,
                    size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-Replenish',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 14,
                            fontWeight: BmbFontWeights.semiBold)),
                    const SizedBox(height: 2),
                    Text(
                        'Auto-buy 10 credits when your bucket hits 10 or below',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: _autoReplenish,
                onChanged: _toggleAutoReplenish,
                activeTrackColor: BmbColors.successGreen.withValues(alpha: 0.5),
                thumbColor: WidgetStatePropertyAll(
                  _autoReplenish ? BmbColors.successGreen : BmbColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── PROMO CODE SECTION ───────────────────────────────────────────
  Widget _buildPromoCodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _promoSuccess
              ? BmbColors.successGreen.withValues(alpha: 0.4)
              : BmbColors.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.confirmation_number,
                    color: BmbColors.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Have a Promo Code?',
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 14,
                          fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 2),
                  Text('Enter code to add free credits to your bucket',
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Input row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BmbColors.borderColor),
                  ),
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ENTER CODE',
                      hintStyle: TextStyle(
                        color: BmbColors.textTertiary,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                      prefixIcon: const Icon(Icons.code,
                          color: BmbColors.textTertiary, size: 18),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (_) {
                      if (_promoMessage != null) {
                        setState(() {
                          _promoMessage = null;
                          _promoSuccess = false;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _promoProcessing ? null : _redeemPromoCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.gold,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: BmbColors.cardDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _promoProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black54))
                      : Text('Redeem',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: BmbFontWeights.bold)),
                ),
              ),
            ],
          ),
          // Result message
          if (_promoMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (_promoSuccess
                        ? BmbColors.successGreen
                        : BmbColors.errorRed)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_promoSuccess
                          ? BmbColors.successGreen
                          : BmbColors.errorRed)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _promoSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _promoSuccess
                        ? BmbColors.successGreen
                        : BmbColors.errorRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_promoMessage!,
                        style: TextStyle(
                            color: _promoSuccess
                                ? BmbColors.successGreen
                                : BmbColors.errorRed,
                            fontSize: 12,
                            fontWeight: BmbFontWeights.semiBold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _redeemPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _promoMessage = 'Please enter a promo code.';
        _promoSuccess = false;
      });
      return;
    }

    setState(() => _promoProcessing = true);

    // Small delay for UX feel
    await Future.delayed(const Duration(milliseconds: 500));

    final result = await PromoCodeService.instance.redeemCode(code);

    if (!mounted) return;
    setState(() {
      _promoProcessing = false;
      _promoMessage = result.message;
      _promoSuccess = result.success;
      if (result.success) {
        _balance = result.newBalance.toDouble();
        _promoController.clear();
      }
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.celebration, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '+${result.creditsAwarded} credits added to your BMB Bucket!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: BmbColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (result.abuseFlag != AbuseFlag.none) {
      // Show abuse-specific warning with shield icon
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.abuseFlag == AbuseFlag.rateLimited
                    ? Icons.timer_off
                    : result.abuseFlag == AbuseFlag.suspiciousDevice
                        ? Icons.gpp_bad
                        : Icons.shield,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: BmbColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ─── TIER CARD ───────────────────────────────────────────────────
  Widget _buildTierCard(int index) {
    final tier = _tiers[index];
    final selected = _selectedPackage == index;
    final credits = tier['credits'] as int;
    final price = tier['price'] as double;
    final label = tier['label'] as String;
    final badge = tier['badge'] as String;
    final hasBonus = badge.isNotEmpty;

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [
                  BmbColors.gold.withValues(alpha: 0.2),
                  BmbColors.gold.withValues(alpha: 0.08),
                ])
              : BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? BmbColors.gold : BmbColors.borderColor,
            width: selected ? 2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? BmbColors.gold : BmbColors.textTertiary,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: BmbColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Credits + label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$credits credits',
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 17,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                      if (hasBonus) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: BmbColors.successGreen
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge,
                              style: TextStyle(
                                  color: BmbColors.successGreen,
                                  fontSize: 10,
                                  fontWeight: BmbFontWeights.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            // Price
            Text('\$${price.toStringAsFixed(0)}',
                style: TextStyle(
                    color: BmbColors.gold,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold)),
          ],
        ),
      ),
    );
  }


}

// ═══════════════════════════════════════════════════════════════════
// STATIC HELPER: Show insufficient-credits prompt with tiers
// Call from anywhere: BmbBucketPrompt.show(context, needed: 50)
// ═══════════════════════════════════════════════════════════════════
class BmbBucketPrompt {
  static Future<void> show(BuildContext context, {required double needed}) async {
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('bmb_bucks_balance') ?? 0;
    final shortage = (needed - balance).ceil();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: BmbColors.borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: BmbColors.errorRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.savings, color: BmbColors.errorRed, size: 30),
            ),
            const SizedBox(height: 14),
            Text('Not Enough Credits',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
            const SizedBox(height: 6),
            Text(
                'You need $shortage more credits in your BMB Bucket to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Current balance: ', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                Text('${balance.toInt()} credits',
                    style: TextStyle(color: BmbColors.errorRed, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                Text('  |  Needed: ', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                Text('${needed.toInt()} credits',
                    style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold)),
              ],
            ),
            const SizedBox(height: 20),
            // Tier list
            ..._BmbBucksPurchaseScreenState._tiers.map((tier) {
              final credits = tier['credits'] as int;
              final price = tier['price'] as double;
              final label = tier['label'] as String;
              final badge = tier['badge'] as String;
              final meetsNeed = credits >= shortage;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: meetsNeed
                      ? LinearGradient(colors: [
                          BmbColors.successGreen.withValues(alpha: 0.1),
                          BmbColors.successGreen.withValues(alpha: 0.03),
                        ])
                      : BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: meetsNeed
                        ? BmbColors.successGreen.withValues(alpha: 0.5)
                        : BmbColors.borderColor,
                    width: meetsNeed ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.savings,
                        color: meetsNeed ? BmbColors.successGreen : BmbColors.textTertiary,
                        size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('$credits credits',
                                  style: TextStyle(
                                      color: BmbColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: BmbFontWeights.bold)),
                              if (badge.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: BmbColors.successGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(badge,
                                      style: TextStyle(
                                          color: BmbColors.successGreen,
                                          fontSize: 9,
                                          fontWeight: BmbFontWeights.bold)),
                                ),
                              ],
                            ],
                          ),
                          Text(label,
                              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('\$${price.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: BmbColors.gold,
                            fontSize: 16,
                            fontWeight: BmbFontWeights.bold)),
                    if (meetsNeed) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle,
                          color: BmbColors.successGreen, size: 18),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            // CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BmbBucksPurchaseScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.savings, size: 20),
                label: Text('Fill My Bucket',
                    style: TextStyle(
                        fontSize: 15, fontWeight: BmbFontWeights.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
