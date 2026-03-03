import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/payments/data/config/stripe_config.dart';
import 'package:bmb_mobile/features/payments/data/services/stripe_payment_service.dart';

class BmbPlusUpgradeScreen extends StatefulWidget {
  const BmbPlusUpgradeScreen({super.key});
  @override
  State<BmbPlusUpgradeScreen> createState() => _BmbPlusUpgradeScreenState();
}

class _BmbPlusUpgradeScreenState extends State<BmbPlusUpgradeScreen> {
  bool _purchasing = false;
  bool _isYearly = false; // false = monthly, true = yearly

  Future<void> _handleUpgrade() async {
    setState(() => _purchasing = true);
    final email = await StripePaymentService.getUserEmail() ?? CurrentUserService.instance.email;
    if (!mounted) return;

    if (_isYearly) {
      await StripePaymentService.checkoutBmbPlusYearly(context, email: email);
    } else {
      await StripePaymentService.checkoutBmbPlus(context, email: email);
    }

    if (!mounted) return;
    setState(() => _purchasing = false);
  }

  Future<void> _handleVipUpgrade() async {
    setState(() => _purchasing = true);
    final email = await StripePaymentService.getUserEmail() ?? CurrentUserService.instance.email;
    if (!mounted) return;
    await StripePaymentService.checkoutBmbVip(context, email: email);
    if (!mounted) return;
    setState(() => _purchasing = false);
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
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: BmbColors.textPrimary),
                        onPressed: () => Navigator.pop(context)),
                    const Spacer(),
                    Text('BMB+',
                        style: TextStyle(
                            color: BmbColors.gold,
                            fontSize: 22,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 24),
                Image.asset('assets/images/splash_dark.png',
                    width: 100, height: 100),
                const SizedBox(height: 20),
                Text('Become a BMB+ Host',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 24,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                const SizedBox(height: 8),
                Text(
                    'Unlock hosting, saving, sharing, and earning from your tournaments',
                    style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),

                // What free users CAN do
                _sectionLabel('Free Users Can:'),
                _permissionRow(Icons.check_circle, BmbColors.successGreen,
                    'Join Tournaments', 'Enter and compete in any bracket'),
                _permissionRow(Icons.check_circle, BmbColors.successGreen,
                    'Build Brackets', 'Use the Bracket Builder to design tournaments'),
                _permissionRow(Icons.check_circle, BmbColors.successGreen,
                    'Purchase Credits', 'Buy credits for your BMB Bucket'),
                _permissionRow(Icons.check_circle, BmbColors.successGreen,
                    'Chat & Social', 'Join chat rooms and follow other users'),
                const SizedBox(height: 16),

                // What BMB+ unlocks
                _sectionLabel('BMB+ Unlocks:'),
                _permissionRow(Icons.star, BmbColors.gold,
                    'Save & Host Brackets', 'Save your built brackets and go live'),
                _permissionRow(Icons.star, BmbColors.gold,
                    'Share with Friends', 'Invite friends to your tournaments'),
                _permissionRow(Icons.star, BmbColors.gold,
                    'Earn Credits from Hosting', 'Keep earnings from player contributions'),
                _permissionRow(Icons.star, BmbColors.gold,
                    'Unlimited Tournaments', 'Create and manage as many as you want'),
                _permissionRow(Icons.star, BmbColors.gold,
                    'Menu Item Challenges', 'Run voting competitions with photo uploads'),
                _permissionRow(Icons.star, BmbColors.gold,
                    'Premium Host Badge', 'Stand out in the community'),
                _permissionRow(Icons.star, BmbColors.gold,
                    'Advanced Analytics', 'Track tournament performance'),
                _permissionRow(Icons.star, BmbColors.gold,
                    'Priority Support', 'Get help when you need it'),
                const SizedBox(height: 28),

                // BMB+ VIP Tier ($2/month)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF9C27B0).withValues(alpha: 0.12),
                      const Color(0xFF9C27B0).withValues(alpha: 0.04)
                    ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.diamond, color: Color(0xFF9C27B0), size: 20),
                      const SizedBox(width: 6),
                      Text('BMB+ VIP', style: TextStyle(color: const Color(0xFF9C27B0), fontSize: 14, fontWeight: BmbFontWeights.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF9C27B0).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text('ADD-ON', style: TextStyle(color: const Color(0xFF9C27B0), fontSize: 8, fontWeight: BmbFontWeights.bold)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('\$2/month', style: TextStyle(color: const Color(0xFF9C27B0), fontSize: 22, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                    const SizedBox(height: 6),
                    Text('Priority bracket visibility in-app (like SEO for your brackets)', style: TextStyle(color: BmbColors.textSecondary, fontSize: 11), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('Your brackets shown first when members open the app', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10), textAlign: TextAlign.center),
                  ]),
                ),
                const SizedBox(height: 24),

                // ════════════════════════════════════════════════════
                // PLAN SELECTOR — Monthly vs One-Time
                // ════════════════════════════════════════════════════
                Text('Choose Your Plan',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold)),
                const SizedBox(height: 12),

                // Toggle
                Container(
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BmbColors.borderColor),
                  ),
                  child: Row(
                    children: [
                      _planTab('Monthly', !_isYearly, () => setState(() => _isYearly = false)),
                      _planTab('Yearly', _isYearly, () => setState(() => _isYearly = true)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Price cards — animated switch
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isYearly ? _buildYearlyPriceCard() : _buildMonthlyPriceCard(),
                ),
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

                // Subscribe / Buy button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _purchasing ? null : _handleUpgrade,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.gold,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: BmbColors.cardDark,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: _purchasing
                        ? const SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _isYearly
                                    ? 'Subscribe BMB+ — \$${StripeConfig.bmbPlusYearlyPrice.toStringAsFixed(2)}/yr'
                                    : 'Subscribe to BMB+ — \$${StripeConfig.bmbPlusMonthlyPrice.toStringAsFixed(2)}/mo',
                                style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // VIP Add-on button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _purchasing ? null : _handleVipUpgrade,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9C27B0),
                      side: BorderSide(color: const Color(0xFF9C27B0).withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.diamond, size: 18),
                        const SizedBox(width: 8),
                        Text('Add VIP — \$2/mo',
                            style: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── PLAN TAB ──────────────────────────────────────────────────────────
  Widget _planTab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? BmbColors.gold.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? BmbColors.gold : Colors.transparent,
              width: selected ? 1.5 : 0,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected ? BmbColors.gold : BmbColors.textTertiary,
                    fontSize: 14,
                    fontWeight: selected ? BmbFontWeights.bold : BmbFontWeights.medium)),
          ),
        ),
      ),
    );
  }

  // ─── MONTHLY PRICE CARD ────────────────────────────────────────────────
  Widget _buildMonthlyPriceCard() {
    return Container(
      key: const ValueKey('monthly'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.1),
          BmbColors.gold.withValues(alpha: 0.05)
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('MONTHLY', style: TextStyle(
                color: BmbColors.blue, fontSize: 10,
                fontWeight: BmbFontWeights.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${StripeConfig.bmbPlusMonthlyPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 36,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('/month',
                    style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Cancel anytime',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── ONE-TIME PRICE CARD ───────────────────────────────────────────────
  Widget _buildYearlyPriceCard() {
    final annualEquiv = StripeConfig.bmbPlusMonthlyPrice * 12;
    final savings = annualEquiv - StripeConfig.bmbPlusYearlyPrice;

    return Container(
      key: const ValueKey('yearly'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.successGreen.withValues(alpha: 0.1),
          BmbColors.gold.withValues(alpha: 0.05)
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: BmbColors.successGreen.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: BmbColors.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('YEARLY', style: TextStyle(
                    color: BmbColors.successGreen, fontSize: 10,
                    fontWeight: BmbFontWeights.bold, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('SAVE \$${savings.toStringAsFixed(savings.truncateToDouble() == savings ? 0 : 2)}', style: TextStyle(
                    color: BmbColors.gold, fontSize: 10,
                    fontWeight: BmbFontWeights.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('\$${StripeConfig.bmbPlusYearlyPrice.toStringAsFixed(2)}',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 36,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
          const SizedBox(height: 4),
          Text('billed annually',
              style: TextStyle(
                  color: BmbColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 6),
          Text('Save vs monthly — renews yearly',
              style: TextStyle(
                  color: BmbColors.successGreen, fontSize: 12,
                  fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 4),
          Text('vs \$${annualEquiv.toStringAsFixed(annualEquiv.truncateToDouble() == annualEquiv ? 0 : 2)}/yr on monthly plan',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── SHARED WIDGETS ────────────────────────────────────────────────────
  static Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 13,
                fontWeight: BmbFontWeights.bold)),
      ),
    );
  }

  static Widget _permissionRow(
      IconData icon, Color color, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BmbColors.borderColor, width: 0.5)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 14,
                          fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: TextStyle(
                          color: BmbColors.textSecondary, fontSize: 12)),
                ]),
          ),
        ],
      ),
    );
  }
}
