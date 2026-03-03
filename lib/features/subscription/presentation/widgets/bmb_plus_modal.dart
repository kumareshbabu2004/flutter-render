import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/subscription/presentation/screens/bmb_plus_upgrade_screen.dart';
import 'package:bmb_mobile/features/payments/data/config/stripe_config.dart';
import 'package:bmb_mobile/features/payments/data/services/stripe_payment_service.dart';

/// In-app promotional modal for BMB+ upgrade.
class BmbPlusModal {
  /// Show upgrade prompt — more prominent for non-BMB+ users.
  static void show(BuildContext context, {bool isBmbPlus = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BmbPlusModalContent(isBmbPlus: isBmbPlus),
    );
  }

  /// Show hosting promotion modal (NON BMB+ users only)
  static void showHostingPromo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _HostingPromoContent(),
    );
  }

  /// Show VIP upsell modal (BMB+ members only — NOT yet VIP)
  /// Pitches the 2 credits/month upgrade for front placement.
  /// Credits are deducted from user's BMB Bucket and sent to BMB Company Bucket.
  static void showVipUpsell(BuildContext context, {VoidCallback? onActivated}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VipUpsellContent(onActivated: onActivated),
    );
  }
}

// ─── BMB+ UPGRADE MODAL (for non-BMB+ users) ───────────────────────────
class _BmbPlusModalContent extends StatefulWidget {
  final bool isBmbPlus;
  const _BmbPlusModalContent({required this.isBmbPlus});

  @override
  State<_BmbPlusModalContent> createState() => _BmbPlusModalContentState();
}

class _BmbPlusModalContentState extends State<_BmbPlusModalContent> {
  bool _isYearly = false; // false = monthly, true = yearly

  @override
  Widget build(BuildContext context) {
    final annualEquiv = StripeConfig.bmbPlusMonthlyPrice * 12;
    final savings = annualEquiv - StripeConfig.bmbPlusYearlyPrice;

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [BmbColors.midNavy, BmbColors.deepNavy],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            // Gold gradient icon
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [BmbColors.gold, BmbColors.goldLight]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: const Icon(Icons.workspace_premium, color: Colors.black, size: 36),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [BmbColors.gold, BmbColors.goldLight]), borderRadius: BorderRadius.circular(10)),
              child: Text('BMB+', style: TextStyle(color: BmbColors.deepNavy, fontSize: 14, fontWeight: BmbFontWeights.bold)),
            ),
            const SizedBox(height: 12),
            Text(widget.isBmbPlus ? 'Your Premium Benefits' : 'Upgrade to BMB+',
                style: TextStyle(color: BmbColors.textPrimary, fontSize: 22, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 6),
            Text(widget.isBmbPlus ? 'You\'re already enjoying premium features!' : 'Unlock the full tournament experience',
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            // Features
            ..._features.map((f) => _featureRow(f['icon'] as IconData, f['title'] as String, f['desc'] as String)),
            const SizedBox(height: 20),
            if (!widget.isBmbPlus) ...[
              // ── Plan selector ──
              Container(
                decoration: BoxDecoration(
                  color: BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BmbColors.borderColor),
                ),
                child: Row(
                  children: [
                    _modalPlanTab('Monthly', !_isYearly, () => setState(() => _isYearly = false)),
                    _modalPlanTab('Yearly', _isYearly, () => setState(() => _isYearly = true)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Price card ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isYearly
                    ? Container(
                        key: const ValueKey('modal_yearly'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            BmbColors.successGreen.withValues(alpha: 0.1),
                            BmbColors.gold.withValues(alpha: 0.03),
                          ]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: BmbColors.gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('SAVE \$${savings.toStringAsFixed(savings.truncateToDouble() == savings ? 0 : 2)}',
                                      style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('\$${StripeConfig.bmbPlusYearlyPrice.toStringAsFixed(2)}',
                                style: TextStyle(color: BmbColors.gold, fontSize: 32, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                            const SizedBox(height: 4),
                            Text('Save vs monthly — renews yearly',
                                style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                          ],
                        ),
                      )
                    : Container(
                        key: const ValueKey('modal_monthly'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.1), BmbColors.gold.withValues(alpha: 0.03)]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('\$${StripeConfig.bmbPlusMonthlyPrice.toStringAsFixed(2)}',
                                    style: TextStyle(color: BmbColors.gold, fontSize: 32, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                                Text('/month', style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Cancel anytime', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final email = await StripePaymentService.getUserEmail();
                    if (!context.mounted) return;
                    if (_isYearly) {
                      await StripePaymentService.checkoutBmbPlusYearly(context, email: email);
                    } else {
                      await StripePaymentService.checkoutBmbPlus(context, email: email);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.gold,
                    foregroundColor: BmbColors.deepNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(Icons.payment, size: 18),
                  label: Text(
                    _isYearly
                        ? 'Subscribe — \$${StripeConfig.bmbPlusYearlyPrice.toStringAsFixed(2)}/yr'
                        : 'Subscribe Now — \$${StripeConfig.bmbPlusMonthlyPrice.toStringAsFixed(2)}/mo',
                    style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BmbPlusUpgradeScreen()));
                },
                child: Text('Learn More', style: TextStyle(color: BmbColors.gold, fontSize: 13)),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Maybe Later', style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BmbColors.gold,
                    side: BorderSide(color: BmbColors.gold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Got It'),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Plan tab for modal ───
  Widget _modalPlanTab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                    fontSize: 13,
                    fontWeight: selected ? BmbFontWeights.bold : BmbFontWeights.medium)),
          ),
        ),
      ),
    );
  }

  static const _features = [
    {'icon': Icons.save, 'title': 'Save & Host Brackets', 'desc': 'Save your built brackets and share with friends'},
    {'icon': Icons.emoji_events, 'title': 'Unlimited Tournaments', 'desc': 'Host as many tournaments as you want'},
    {'icon': Icons.monetization_on, 'title': 'Earn Credits', 'desc': 'Keep credits earned from hosting contributions'},
    {'icon': Icons.restaurant_menu, 'title': 'Menu Item Challenges', 'desc': 'Upload photos and run voting competitions'},
    {'icon': Icons.volunteer_activism, 'title': 'Charity Fundraising', 'desc': 'Host brackets for charitable causes'},
    {'icon': Icons.analytics, 'title': 'Analytics & Priority Support', 'desc': 'Track performance and get help faster'},
  ];

  Widget _featureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: BmbColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
                Text(desc, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: BmbColors.gold, size: 18),
        ],
      ),
    );
  }
}

// ─── HOSTING PROMO MODAL (non-BMB+ users) ───────────────────────────────
class _HostingPromoContent extends StatefulWidget {
  const _HostingPromoContent();

  @override
  State<_HostingPromoContent> createState() => _HostingPromoContentState();
}

class _HostingPromoContentState extends State<_HostingPromoContent> {
  bool _isYearly = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 120),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [BmbColors.midNavy, BmbColors.deepNavy]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.add_circle, color: BmbColors.blue, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Try the Bracket Builder!', style: TextStyle(color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 8),
            Text('Build and preview brackets for free! When you\'re ready to save, share, and host \u2014 upgrade to BMB+.',
                textAlign: TextAlign.center, style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),
            // What free users can do
            Row(children: [
              Icon(Icons.check_circle, color: BmbColors.successGreen, size: 16),
              const SizedBox(width: 8),
              Text('Build & preview brackets', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.check_circle, color: BmbColors.successGreen, size: 16),
              const SizedBox(width: 8),
              Text('Join any tournament', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.workspace_premium, color: BmbColors.gold, size: 16),
              const SizedBox(width: 8),
              Text('BMB+ required to save & host', style: TextStyle(color: BmbColors.gold, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
            ]),
            const SizedBox(height: 16),

            // Plan toggle — compact for this modal
            Container(
              decoration: BoxDecoration(
                color: BmbColors.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.borderColor),
              ),
              child: Row(
                children: [
                  _promoTab('\$${StripeConfig.bmbPlusMonthlyPrice.toStringAsFixed(2)}/mo', !_isYearly, () => setState(() => _isYearly = false)),
                  _promoTab('\$${StripeConfig.bmbPlusYearlyPrice.toStringAsFixed(2)}/yr', _isYearly, () => setState(() => _isYearly = true)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BmbColors.textSecondary,
                      side: const BorderSide(color: BmbColors.borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Got It', style: TextStyle(fontWeight: BmbFontWeights.semiBold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final email = await StripePaymentService.getUserEmail();
                      if (!context.mounted) return;
                      if (_isYearly) {
                        await StripePaymentService.checkoutBmbPlusYearly(context, email: email);
                      } else {
                        await StripePaymentService.checkoutBmbPlus(context, email: email);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: BmbColors.gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: Icon(Icons.payment, size: 16),
                    label: Text(_isYearly ? 'Subscribe Yearly' : 'Subscribe', style: TextStyle(fontWeight: BmbFontWeights.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _promoTab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? BmbColors.gold.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? BmbColors.gold : Colors.transparent,
              width: selected ? 1.5 : 0,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected ? BmbColors.gold : BmbColors.textTertiary,
                    fontSize: 12,
                    fontWeight: selected ? BmbFontWeights.bold : BmbFontWeights.medium)),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ─── BMB+ VIP UPSELL MODAL ──────────────────────────────────────────────
// Shown to BMB+ members who are NOT yet VIP.
// 2 credits/month deducted from user's BMB Bucket → sent to BMB Company Bucket.
// ═══════════════════════════════════════════════════════════════════════════
class _VipUpsellContent extends StatefulWidget {
  final VoidCallback? onActivated;
  const _VipUpsellContent({this.onActivated});

  @override
  State<_VipUpsellContent> createState() => _VipUpsellContentState();
}

class _VipUpsellContentState extends State<_VipUpsellContent> {
  bool _activating = false;
  final bool _activated = false;
  int _userCredits = 0;

  static const int _vipMonthlyCost = 2; // 2 credits/month

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userCredits = prefs.getInt('user_bmb_credits_u1') ?? 50;
      });
    }
  }

  // VIP activation now handled by Stripe Payment Link checkout.
  // After payment confirmation via webhook, the server sets is_bmb_vip.

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BmbColors.vipPurple.withValues(alpha: 0.12),
            BmbColors.midNavy,
            BmbColors.deepNavy,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: BmbColors.vipPurple.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _activated ? _buildActivatedView() : _buildUpsellView(),
      ),
    );
  }

  // ─── ACTIVATED (success) VIEW ─────────────────────────────────────────
  Widget _buildActivatedView() {
    return Column(
      children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: BmbColors.vipPurple.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 30),
        // Success animation
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [BmbColors.vipPurple, BmbColors.vipPurpleLight]),
            boxShadow: [
              BoxShadow(color: BmbColors.vipPurple.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4),
            ],
          ),
          child: const Icon(Icons.diamond, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [BmbColors.vipPurple, BmbColors.vipPurpleLight]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('BMB+ VIP ACTIVE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 16),
        Text('You\'re VIP!', style: TextStyle(color: BmbColors.textPrimary, fontSize: 24, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
        const SizedBox(height: 8),
        Text('$_vipMonthlyCost credits deducted from your BMB Bucket.\nYour brackets now get featured front & center!',
          textAlign: TextAlign.center,
          style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        // New balance
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BmbColors.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, color: BmbColors.gold, size: 20),
              const SizedBox(width: 8),
              Text('New Balance: ', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
              Text('$_userCredits credits', style: TextStyle(color: BmbColors.gold, fontSize: 15, fontWeight: BmbFontWeights.bold)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BmbColors.vipPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BmbColors.vipPurple.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: BmbColors.vipPurple, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$_vipMonthlyCost credits/month auto-renews from your BMB Bucket. Cancel anytime in Settings.',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.vipPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Let\'s Go!', style: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── UPSELL VIEW ──────────────────────────────────────────────────────
  Widget _buildUpsellView() {
    final hasEnoughCredits = _userCredits >= _vipMonthlyCost;

    return Column(
      children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: BmbColors.vipPurple.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 24),
        // Diamond icon with glow
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [BmbColors.vipPurple, BmbColors.vipPurpleLight],
            ),
            boxShadow: [
              BoxShadow(color: BmbColors.vipPurple.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 4),
              BoxShadow(color: BmbColors.vipPurple.withValues(alpha: 0.2), blurRadius: 60, spreadRadius: 10),
            ],
          ),
          child: const Icon(Icons.diamond, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        // VIP badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [BmbColors.vipPurple, BmbColors.vipPurpleLight]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: BmbColors.vipPurple.withValues(alpha: 0.3), blurRadius: 12)],
          ),
          child: Text('BMB+ VIP',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: BmbFontWeights.bold, letterSpacing: 1.5)),
        ),
        const SizedBox(height: 16),
        Text('Get Featured Front & Center',
            style: TextStyle(color: BmbColors.textPrimary, fontSize: 22, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Your brackets deserve the spotlight. VIP puts them at the top of the Bracket Board for everyone to see.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),

        // VIP benefits
        _vipBenefitRow(Icons.bolt, 'Priority Featured Placement',
            'Your brackets appear first in the Bracket Board section \u2014 more eyes, more players.'),
        _vipBenefitRow(Icons.auto_awesome, 'Stand-Out Card Design',
            'Your bracket cards get a premium glow border and VIP badge \u2014 players notice them instantly.'),
        _vipBenefitRow(Icons.trending_up, 'More Visibility = More Players',
            'VIP brackets get 3x more joins on average. Fill your tournaments faster.'),
        _vipBenefitRow(Icons.workspace_premium, 'Stack with Top Host',
            'Already a Top Host? VIP stacks on top \u2014 double the front placement priority.'),

        const SizedBox(height: 20),

        // Price card with balance
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              BmbColors.vipPurple.withValues(alpha: 0.15),
              BmbColors.vipPurple.withValues(alpha: 0.05),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BmbColors.vipPurple.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.savings, color: BmbColors.vipPurple, size: 28),
                  const SizedBox(width: 8),
                  Text('$_vipMonthlyCost', style: TextStyle(color: BmbColors.vipPurple, fontSize: 42, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('credits/month', style: TextStyle(color: BmbColors.vipPurpleLight, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Deducted from your BMB Bucket \u2192 BMB Company Bucket',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              const SizedBox(height: 10),
              // Current balance indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasEnoughCredits
                      ? BmbColors.successGreen.withValues(alpha: 0.1)
                      : BmbColors.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasEnoughCredits
                        ? BmbColors.successGreen.withValues(alpha: 0.3)
                        : BmbColors.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasEnoughCredits ? Icons.check_circle : Icons.warning,
                      color: hasEnoughCredits ? BmbColors.successGreen : BmbColors.errorRed,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Your balance: $_userCredits credits',
                      style: TextStyle(
                        color: hasEnoughCredits ? BmbColors.successGreen : BmbColors.errorRed,
                        fontSize: 12, fontWeight: BmbFontWeights.semiBold,
                      ),
                    ),
                    if (hasEnoughCredits) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(\u2192 ${_userCredits - _vipMonthlyCost} after)',
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Where credits go explanation
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BmbColors.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance, color: BmbColors.gold, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your $_vipMonthlyCost credits go to the BMB Company Bucket \u2014 same place the 1-credit platform fee is sent from player contributions.',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, height: 1.3),
                ),
              ),
            ],
          ),
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
        const SizedBox(height: 12),

        // CTA button — Stripe VIP subscription
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _activating ? null : () async {
              setState(() => _activating = true);
              final email = await StripePaymentService.getUserEmail();
              if (!mounted) return;
              await StripePaymentService.checkoutBmbVip(context, email: email);
              if (mounted) setState(() => _activating = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.vipPurple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BmbColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 6,
              shadowColor: BmbColors.vipPurple.withValues(alpha: 0.5),
            ),
            icon: _activating
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.diamond, size: 20),
            label: Text(
              _activating ? 'Opening Stripe...' : 'Subscribe to VIP \u2014 \$2/mo',
              style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Not Now', style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _vipBenefitRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: BmbColors.vipPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: BmbColors.vipPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
