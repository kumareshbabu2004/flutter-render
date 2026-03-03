import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/dashboard/data/models/user_profile.dart';
import 'package:bmb_mobile/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:bmb_mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:bmb_mobile/features/business/presentation/screens/bmb_starter_kit_screen.dart';
import 'package:bmb_mobile/features/payments/data/config/stripe_config.dart';
import 'package:bmb_mobile/features/payments/data/services/stripe_payment_service.dart';
import 'package:bmb_mobile/core/services/firebase/firebase_auth_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

// ═══════════════════════════════════════════════════════════════════════
// CONFIGURABLE PRICING — change this single constant to update the
// monthly business hosting fee everywhere it's referenced.
// ═══════════════════════════════════════════════════════════════════════
const int kBusinessMonthlyPriceCents = 9900; // $99.00 / month
String get kBusinessMonthlyPriceDisplay =>
    '\$${(kBusinessMonthlyPriceCents / 100).toStringAsFixed(kBusinessMonthlyPriceCents % 100 == 0 ? 0 : 2)}';

class BusinessSignupScreen extends StatefulWidget {
  const BusinessSignupScreen({super.key});
  @override
  State<BusinessSignupScreen> createState() => _BusinessSignupScreenState();
}

class _BusinessSignupScreenState extends State<BusinessSignupScreen> {
  int _step = 0; // 0=business info, 1=address, 2=account credentials, 3=confirmation+starter kit
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _pwVisible = false;
  bool _isBizYearly = false; // false = monthly, true = yearly

  // Step 0 — Business Info
  final _bizNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _salesRepController = TextEditingController();
  String _bizType = 'bar';

  // Step 1 — Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  String? _selectedState;

  // Step 2 — Account
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _bizNameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _salesRepController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ─── VALIDATION & NAVIGATION ──────────────────────────────────────────
  void _next() {
    if (_step == 0) {
      if (_bizNameController.text.trim().isEmpty) {
        _showSnack('Please enter your business name');
        return;
      }
      if (_contactNameController.text.trim().isEmpty) {
        _showSnack('Please enter the main contact person\'s name');
        return;
      }
      if (_phoneController.text.trim().isEmpty) {
        _showSnack('Please enter a phone number');
        return;
      }
    }
    if (_step == 1) {
      if (_selectedState == null) {
        _showSnack('Please select your state');
        return;
      }
      if (_cityController.text.trim().isEmpty) {
        _showSnack('Please enter your city');
        return;
      }
    }
    if (_step == 2) {
      if (_emailController.text.trim().isEmpty) {
        _showSnack('Please enter an email');
        return;
      }
      if (_passwordController.text.length < 8) {
        _showSnack('Password must be at least 8 characters');
        return;
      }
      if (_passwordController.text != _confirmController.text) {
        _showSnack('Passwords do not match');
        return;
      }
      if (!_agreedToTerms) {
        _showSnack('You must agree to the Terms of Service');
        return;
      }
      _completeBizSignup();
      return;
    }
    setState(() => _step++);
  }

  Future<void> _completeBizSignup() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final bizName = _bizNameController.text.trim();

    try {
      // ── Firebase Authentication — Create Business Account ──
      await FirebaseAuthService.instance.signUp(
        email: email,
        password: password,
        displayName: bizName,
        state: _selectedState,
        city: _cityController.text.trim(),
        street: _streetController.text.trim(),
        zip: _zipController.text.trim(),
        isBusiness: true,
        bizName: bizName,
        bizType: _bizType,
        bizPlan: 'business',
        bizContactName: _contactNameController.text.trim(),
        bizPhone: _phoneController.text.trim(),
      );

      // Also sync to SharedPreferences for backwards compatibility
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_email', email);
      await prefs.setBool('is_bmb_plus', true);
      await prefs.setBool('is_business', true);
      await prefs.setString('biz_name', bizName);
      await prefs.setString('biz_type', _bizType);
      await prefs.setString('biz_contact_name', _contactNameController.text.trim());
      await prefs.setString('biz_phone', _phoneController.text.trim());
      if (_salesRepController.text.trim().isNotEmpty) {
        await prefs.setString('biz_sales_rep', _salesRepController.text.trim());
      }
      await prefs.setString('biz_plan', 'business');
      await prefs.setInt('biz_monthly_price_cents', kBusinessMonthlyPriceCents);
      await prefs.setString('user_display_name', bizName);

      // Load the fresh Firestore profile
      await CurrentUserService.instance.load();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = 3; // show confirmation + starter kit offer
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goToDashboard() {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: BmbColors.midNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_step < 3) _buildProgress(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _step == 0
                        ? _buildStep0()
                        : _step == 1
                            ? _buildStep1()
                            : _step == 2
                                ? _buildStep2()
                                : _buildStep3Confirmation(),
                  ),
                ),
              ),
              if (_step < 3) _buildBottom(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: _step > 0 && _step < 3
                ? () => setState(() => _step--)
                : () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Business Account',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Text('For bars, restaurants & venues',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [BmbColors.gold, BmbColors.goldLight]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store, color: BmbColors.deepNavy, size: 14),
                const SizedBox(width: 4),
                Text(_step == 3 && _isBizYearly
                    ? '\$${StripeConfig.bmbBizYearlyPrice.toStringAsFixed(0)}'
                    : '$kBusinessMonthlyPriceDisplay/mo',
                    style: TextStyle(
                        color: BmbColors.deepNavy,
                        fontSize: 11,
                        fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PROGRESS ─────────────────────────────────────────────────────────
  Widget _buildProgress() {
    const steps = ['Business Info', 'Address', 'Account'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        children: [
          Row(
            children: List.generate(3, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i <= _step ? BmbColors.gold : BmbColors.borderColor,
                ),
              ),
            )),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.asMap().entries.map((e) {
              final active = e.key <= _step;
              return Text(e.value,
                  style: TextStyle(
                      color: active ? BmbColors.gold : BmbColors.textTertiary,
                      fontSize: 10,
                      fontWeight: active ? BmbFontWeights.bold : FontWeight.normal));
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── STEP 0: BUSINESS INFO ────────────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      key: const ValueKey('biz_step0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business Information',
            style: TextStyle(
                color: BmbColors.textPrimary, fontSize: 16,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 4),
        Text('Tell us about your establishment',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),

        // Business type
        Text('Business Type',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ('bar', 'Bar', Icons.local_bar),
            ('restaurant', 'Restaurant', Icons.restaurant),
            ('venue', 'Sports Venue', Icons.stadium),
            ('other', 'Other', Icons.store),
          ].map((t) {
            final sel = _bizType == t.$1;
            return GestureDetector(
              onTap: () => setState(() => _bizType = t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? BmbColors.gold.withValues(alpha: 0.15) : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? BmbColors.gold : BmbColors.borderColor,
                    width: sel ? 1.5 : 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$3, color: sel ? BmbColors.gold : BmbColors.textTertiary, size: 18),
                    const SizedBox(width: 6),
                    Text(t.$2, style: TextStyle(
                        color: sel ? BmbColors.gold : BmbColors.textSecondary,
                        fontSize: 12,
                        fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _field('Business Name *', _bizNameController, Icons.store),
        const SizedBox(height: 12),
        _field('Main Contact Person *', _contactNameController, Icons.person),
        const SizedBox(height: 12),
        _field('Phone Number *', _phoneController, Icons.phone,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _field('BMB Sales Rep (if applicable)', _salesRepController, Icons.badge),
        const SizedBox(height: 16),

        // Pricing callout
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              BmbColors.gold.withValues(alpha: 0.12),
              BmbColors.gold.withValues(alpha: 0.04),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.verified, color: BmbColors.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$kBusinessMonthlyPriceDisplay/month — All Inclusive',
                        style: TextStyle(color: BmbColors.gold, fontSize: 13,
                            fontWeight: BmbFontWeights.bold)),
                    Text('Unlimited brackets, BMB Starter Kit, marketing materials, QR codes & more',
                        style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STEP 1: ADDRESS ──────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      key: const ValueKey('biz_step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Business Address',
            style: TextStyle(color: BmbColors.textPrimary, fontSize: 16,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 4),
        Text('We\'ll ship your BMB Starter Kit to this address',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        _field('Street Address *', _streetController, Icons.location_on),
        const SizedBox(height: 12),
        _field('City *', _cityController, Icons.location_city),
        const SizedBox(height: 12),
        _buildStateDropdown(),
        const SizedBox(height: 12),
        _field('ZIP Code *', _zipController, Icons.pin,
            keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BmbColors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_shipping, color: BmbColors.blue, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your BMB Starter Kit (posters, sweatshirts, table tents, QR codes) will be shipped to this address within 5-7 business days after signup.',
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STEP 2: ACCOUNT CREDENTIALS ─────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      key: const ValueKey('biz_step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create Your Account',
            style: TextStyle(color: BmbColors.textPrimary, fontSize: 16,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 4),
        Text('Set up login credentials for ${_bizNameController.text.isNotEmpty ? _bizNameController.text : 'your business'}',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        _field('Email *', _emailController, Icons.email),
        const SizedBox(height: 12),
        _field('Password *', _passwordController, Icons.lock, obscure: true),
        const SizedBox(height: 12),
        _field('Confirm Password *', _confirmController, Icons.lock, obscure: true),
        const SizedBox(height: 8),
        _buildPasswordRequirements(),
        const SizedBox(height: 12),

        // Terms
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                fillColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? BmbColors.blue : null),
                side: BorderSide(color: BmbColors.textTertiary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                children: [
                  Text('I agree to the ', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
                    child: Text('Terms of Service',
                        style: TextStyle(color: BmbColors.blue, fontSize: 12,
                            decoration: TextDecoration.underline, decorationColor: BmbColors.blue)),
                  ),
                  Text(' & ', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                    child: Text('Privacy Policy',
                        style: TextStyle(color: BmbColors.blue, fontSize: 12,
                            decoration: TextDecoration.underline, decorationColor: BmbColors.blue)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BmbColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account Summary', style: TextStyle(
                  color: BmbColors.textPrimary, fontSize: 13,
                  fontWeight: BmbFontWeights.bold)),
              const SizedBox(height: 8),
              _summaryRow(Icons.store, _bizNameController.text),
              _summaryRow(Icons.person, _contactNameController.text),
              _summaryRow(Icons.phone, _phoneController.text),
              _summaryRow(Icons.location_on,
                  '${_cityController.text}${_selectedState != null ? ', $_selectedState' : ''}'),
              if (_salesRepController.text.isNotEmpty)
                _summaryRow(Icons.badge, 'Sales Rep: ${_salesRepController.text}'),
              const Divider(color: BmbColors.borderColor, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Monthly Plan', style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12)),
                  Text('$kBusinessMonthlyPriceDisplay/month', style: TextStyle(
                      color: BmbColors.gold, fontSize: 14,
                      fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: BmbColors.textTertiary, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(text,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // ─── STEP 3: CONFIRMATION + STARTER KIT OFFER ────────────────────────
  Widget _buildStep3Confirmation() {
    final annualEquiv = StripeConfig.bmbBizMonthlyPrice * 12;
    final savings = annualEquiv - StripeConfig.bmbBizYearlyPrice;

    return Column(
      key: const ValueKey('biz_step3'),
      children: [
        const SizedBox(height: 10),
        // Success icon
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [BmbColors.gold, BmbColors.goldLight]),
            boxShadow: [
              BoxShadow(color: BmbColors.gold.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 4),
            ],
          ),
          child: const Icon(Icons.check, color: Colors.black, size: 48),
        ),
        const SizedBox(height: 20),
        Text('Welcome to BMB!', style: TextStyle(
            color: BmbColors.textPrimary, fontSize: 24,
            fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
        const SizedBox(height: 8),
        Text('${_bizNameController.text} is now set up and ready to host tournaments.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 14, height: 1.4)),
        const SizedBox(height: 24),

        // Starter Kit CTA — prominent
        GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BmbStarterKitScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  BmbColors.gold.withValues(alpha: 0.2),
                  BmbColors.gold.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BmbColors.gold, width: 1.5),
              boxShadow: [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.15), blurRadius: 20)],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: BmbColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.inventory_2, color: BmbColors.gold, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Get Your BMB Starter Kit', style: TextStyle(
                              color: BmbColors.gold, fontSize: 16,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                          Text('Everything you need to start hosting now',
                              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: BmbColors.gold, size: 18),
                  ],
                ),
                const SizedBox(height: 14),
                // Kit contents preview
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: [
                    _kitTag(Icons.image, '2 Posters'),
                    _kitTag(Icons.checkroom, '3 QR Sweatshirts'),
                    _kitTag(Icons.table_restaurant, '10 Table Tents'),
                    _kitTag(Icons.qr_code, 'QR Codes'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Quick Start Videos link
        GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BmbStarterKitScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.play_circle_filled, color: BmbColors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Start Videos', style: TextStyle(
                          color: BmbColors.textPrimary, fontSize: 14,
                          fontWeight: BmbFontWeights.bold)),
                      Text('Learn how to host your first tournament in minutes',
                          style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: BmbColors.textTertiary, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ════════════════════════════════════════════════════════════════
        // PLAN SELECTOR — Monthly vs Yearly (BMB+biz)
        // ════════════════════════════════════════════════════════════════
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
              _bizPlanTab('Monthly', !_isBizYearly, () => setState(() => _isBizYearly = false)),
              _bizPlanTab('Yearly', _isBizYearly, () => setState(() => _isBizYearly = true)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Price cards — animated switch
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isBizYearly
              ? _buildBizYearlyPriceCard(annualEquiv, savings)
              : _buildBizMonthlyPriceCard(),
        ),
        const SizedBox(height: 16),

        // Stripe trust badge
        Center(
          child: Container(
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
        ),
        const SizedBox(height: 12),

        // Stripe subscribe / buy CTA
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: () async {
              final email = _emailController.text.trim();
              if (_isBizYearly) {
                await StripePaymentService.checkoutBmbBizYearly(context, email: email);
              } else {
                await StripePaymentService.checkoutBmbBiz(context, email: email);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.gold,
              foregroundColor: BmbColors.deepNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(Icons.payment, size: 20),
            label: Text(
              _isBizYearly
                  ? 'Subscribe — \$${StripeConfig.bmbBizYearlyPrice.toStringAsFixed(0)}/yr'
                  : 'Subscribe — $kBusinessMonthlyPriceDisplay/mo',
              style: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Go to Dashboard
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton(
            onPressed: _goToDashboard,
            style: OutlinedButton.styleFrom(
              foregroundColor: BmbColors.textSecondary,
              side: BorderSide(color: BmbColors.borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Skip to Dashboard', style: TextStyle(
                fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BmbStarterKitScreen()));
          },
          child: Text('View Starter Kit Details First',
              style: TextStyle(color: BmbColors.gold, fontSize: 13)),
        ),
      ],
    );
  }

  // ─── BIZ PLAN TAB ────────────────────────────────────────────────────
  Widget _bizPlanTab(String label, bool selected, VoidCallback onTap) {
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

  // ─── BIZ MONTHLY PRICE CARD ─────────────────────────────────────────
  Widget _buildBizMonthlyPriceCard() {
    return Container(
      key: const ValueKey('biz_monthly'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.1),
          BmbColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
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
              Text('\$${StripeConfig.bmbBizMonthlyPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 36,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('/month',
                    style: TextStyle(color: BmbColors.textSecondary, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Cancel anytime',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── BIZ YEARLY PRICE CARD ──────────────────────────────────────────
  Widget _buildBizYearlyPriceCard(double annualEquiv, double savings) {
    return Container(
      key: const ValueKey('biz_yearly'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.successGreen.withValues(alpha: 0.1),
          BmbColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.4)),
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
          Text('\$${StripeConfig.bmbBizYearlyPrice.toStringAsFixed(0)}',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 36,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
          const SizedBox(height: 4),
          Text('billed annually',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 6),
          Text('Save vs monthly — renews yearly',
              style: TextStyle(
                  color: BmbColors.successGreen, fontSize: 12,
                  fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 4),
          Text('vs \$${annualEquiv.toStringAsFixed(annualEquiv.truncateToDouble() == annualEquiv ? 0 : 2)}/yr on monthly plan',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _kitTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BmbColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: BmbColors.gold, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
              color: BmbColors.gold, fontSize: 11,
              fontWeight: BmbFontWeights.semiBold)),
        ],
      ),
    );
  }

  // ─── BOTTOM BUTTON ────────────────────────────────────────────────────
  Widget _buildBottom() {
    final isLast = _step == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: isLast ? BmbColors.gold : BmbColors.blue,
            foregroundColor: isLast ? BmbColors.deepNavy : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isLast ? 'Create Business Account' : 'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold)),
        ),
      ),
    );
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────────────────
  Widget _field(String label, TextEditingController ctrl, IconData icon, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure && !_pwVisible,
      keyboardType: keyboardType,
      style: TextStyle(color: BmbColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: BmbColors.textTertiary),
        prefixIcon: Icon(icon, color: BmbColors.textSecondary),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(_pwVisible ? Icons.visibility : Icons.visibility_off,
                    color: BmbColors.textTertiary),
                onPressed: () => setState(() => _pwVisible = !_pwVisible))
            : null,
        filled: true,
        fillColor: BmbColors.cardDark,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: BmbColors.blue)),
      ),
    );
  }

  Widget _buildStateDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _selectedState != null ? BmbColors.blue : BmbColors.borderColor),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedState,
        decoration: InputDecoration(
          labelText: 'State *',
          labelStyle: TextStyle(color: BmbColors.textTertiary),
          prefixIcon: const Icon(Icons.location_on, color: BmbColors.textSecondary),
          border: InputBorder.none,
        ),
        dropdownColor: BmbColors.midNavy,
        style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
        items: UserProfile.usStates.map((abbr) {
          final name = UserProfile.stateNames[abbr] ?? abbr;
          return DropdownMenuItem(value: abbr, child: Text('$abbr - $name'));
        }).toList(),
        onChanged: (val) => setState(() => _selectedState = val),
        menuMaxHeight: 300,
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    final p = _passwordController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _req('At least 8 characters', p.length >= 8),
        _req('One uppercase letter', p.contains(RegExp(r'[A-Z]'))),
        _req('One number', p.contains(RegExp(r'[0-9]'))),
      ],
    );
  }

  Widget _req(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? BmbColors.successGreen : BmbColors.textTertiary, size: 14),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(
            color: met ? BmbColors.successGreen : BmbColors.textTertiary, fontSize: 12)),
      ]),
    );
  }
}
