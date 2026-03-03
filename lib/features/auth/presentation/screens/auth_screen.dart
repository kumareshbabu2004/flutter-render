import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/core/services/firebase/firebase_auth_service.dart';
import 'package:bmb_mobile/features/dashboard/data/models/user_profile.dart';
import 'package:bmb_mobile/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:bmb_mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:bmb_mobile/features/legal/presentation/screens/community_guidelines_screen.dart';
import 'package:bmb_mobile/features/business/presentation/screens/business_signup_screen.dart';
import 'package:bmb_mobile/features/chat/data/services/chat_access_service.dart';
import 'package:bmb_mobile/features/auth/data/services/biometric_auth_service.dart';
import 'package:bmb_mobile/features/auth/data/services/bot_account_service.dart';
import 'package:bmb_mobile/features/auth/presentation/widgets/human_verification_widget.dart';
import 'package:bmb_mobile/features/auth/presentation/widgets/biometric_login_dialog.dart';
import 'package:bmb_mobile/features/welcome/presentation/widgets/welcome_flow_overlay.dart';
import 'package:bmb_mobile/features/promo/data/services/promo_code_service.dart';
import 'package:bmb_mobile/core/services/device_fingerprint_service.dart';
import 'package:bmb_mobile/features/sharing/data/services/deep_link_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login fields
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginPasswordVisible = false;

  // Remember Me / Biometric
  bool _rememberMe = false;
  bool _biometricEnabled = false;
  bool _hasSavedCredentials = false;
  String? _savedEmail;

  // Signup fields
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmController = TextEditingController();
  final _signupDisplayNameController = TextEditingController();
  final _signupStreetController = TextEditingController();
  final _signupCityController = TextEditingController();
  final _signupZipController = TextEditingController();
  String? _selectedState;
  bool _signupPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreedToTerms = false;

  // Track the current signup step
  // -1 = account type chooser, 0 = account info, 1 = address, 2 = human verification
  int _signupStep = -1;

  // Human verification state
  bool _humanVerified = false;

  final _bioService = BiometricAuthService.instance;
  final _botService = BotAccountService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    _rememberMe = await _bioService.isRememberMeEnabled();
    _biometricEnabled = await _bioService.isBiometricEnabled();

    if (_rememberMe) {
      // BiometricAuthService.getSavedCredentials now checks SharedPreferences
      // first (reliable on web), then falls back to secure storage.
      final creds = await _bioService.getSavedCredentials();
      if (creds != null &&
          creds['email'] != null && creds['email']!.isNotEmpty &&
          creds['password'] != null && creds['password']!.isNotEmpty) {
        _hasSavedCredentials = true;
        _savedEmail = creds['email'];
        _loginEmailController.text = creds['email']!;
        _loginPasswordController.text = creds['password']!;
      }
    }

    if (mounted) setState(() {});

    // Auto-show biometric if remember-me + biometric is on
    if (_rememberMe && _biometricEnabled && _hasSavedCredentials) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBiometricLogin();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmController.dispose();
    _signupDisplayNameController.dispose();
    _signupStreetController.dispose();
    _signupCityController.dispose();
    _signupZipController.dispose();
    super.dispose();
  }

  // ─── BIOMETRIC LOGIN ─────────────────────────────────────────────────

  void _showBiometricLogin() {
    if (_savedEmail == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => BiometricLoginDialog(
          email: _savedEmail!,
          onAuthenticated: () async {
            // Dismiss the overlay first
            if (mounted) Navigator.of(context).pop();
            // Small delay to let the Navigator transition finish
            await Future.delayed(const Duration(milliseconds: 200));
            final creds = await _bioService.getSavedCredentials();
            if (creds != null && creds['email'] != null && creds['password'] != null) {
              _loginEmailController.text = creds['email']!;
              _loginPasswordController.text = creds['password']!;
              await _handleLogin();
            } else {
              // Credentials missing — clear biometric state and ask for manual login
              await _bioService.clearSavedCredentials();
              if (mounted) {
                setState(() {
                  _biometricEnabled = false;
                  _hasSavedCredentials = false;
                  _savedEmail = null;
                });
                _showSnack('Face ID credentials expired. Please log in manually.');
              }
            }
          },
          onCancel: () {
            if (mounted) Navigator.of(context).pop();
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ─── EMAIL VALIDATION ────────────────────────────────────────────────────

  /// BUG #10 FIX: Updated regex to accept:
  ///   - Plus aliases (user+tag@domain.com)
  ///   - TLDs longer than 4 chars (.travel, .museum, .company)
  ///   - Dots in local part (first.last@domain.com)
  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w\+\-\.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(email);
  }

  // ─── LOGIN ──────────────────────────────────────────────────────────────

  /// BUG #5 FIX: Removed hard-coded admin/demo credentials from client code.
  /// All authentication now flows through the Firebase Auth REST API.
  /// Admin accounts are managed server-side via Firebase Console.
  /// This prevents credential exposure in compiled app binaries.

  Future<void> _handleLogin() async {
    if (_loginEmailController.text.isEmpty ||
        _loginPasswordController.text.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }

    final email = _loginEmailController.text.toLowerCase().trim();

    // FIX #7: Validate email format
    if (!_isValidEmail(email)) {
      _showSnack('Please enter a valid email address');
      return;
    }

    setState(() => _isLoading = true);

    final password = _loginPasswordController.text;

    try {
      // ── Firebase Authentication (with timeout) ──
      try {
        await FirebaseAuthService.instance.signIn(
          email: email,
          password: password,
        ).timeout(const Duration(seconds: 10));
      } catch (authErr) {
        // Re-throw with better context
        throw Exception('Auth failed: $authErr');
      }

      // Load user profile from Firestore (with timeout — don't block login)
      try {
        await CurrentUserService.instance.load()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Profile load failed but auth succeeded — continue to dashboard
      }

      // Save credentials if Remember Me is on
      try {
        await _saveCredentialsIfNeeded(email, password);
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isLoading = false);
      _navigateAfterAuth();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Show error in a prominent dialog so user definitely sees it
      _showErrorDialog(e.toString());
    }
  }

  // ═══ DEEP LINK: Check for pending bracket after login/signup ═══
  /// If a pending bracket exists (from shared link), navigate directly to
  /// the join screen. Otherwise, go to the dashboard.
  void _navigateAfterAuth() async {
    final pendingId = await DeepLinkService.instance.consumePendingBracket();
    if (!mounted) return;
    if (pendingId != null && pendingId.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/join/$pendingId');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  /// Same as above but from a different BuildContext (e.g. SocialPromo overlay).
  /// BUG #12 FIX: Guard navigation with context.mounted check.
  void _navigateAfterAuthFrom(BuildContext routeContext) async {
    final pendingId = await DeepLinkService.instance.consumePendingBracket();
    if (!routeContext.mounted) return;
    if (pendingId != null && pendingId.isNotEmpty) {
      Navigator.of(routeContext).pushReplacementNamed('/join/$pendingId');
    } else {
      Navigator.of(routeContext).pushReplacementNamed('/dashboard');
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Login Error', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
          ],
        ),
        content: SelectableText(
          error,
          style: TextStyle(color: BmbColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: BmbColors.blue)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCredentialsIfNeeded(String email, String password) async {
    if (_rememberMe) {
      // saveCredentials writes to BOTH secure storage AND SharedPreferences
      await _bioService.saveCredentials(email, password);
      await _bioService.setRememberMe(true);
      if (_biometricEnabled) {
        await _bioService.setBiometricEnabled(true);
      }
      // Update local state so the biometric button appears immediately
      if (mounted) {
        setState(() {
          _hasSavedCredentials = true;
          _savedEmail = email;
        });
      }
    } else {
      // Remember Me is off — clear any saved credentials (both stores)
      await _bioService.setRememberMe(false);
      await _bioService.clearSavedCredentials();
    }
  }

  // ─── SIGNUP STEPS ────────────────────────────────────────────────────

  void _goToAddressStep() async {
    if (_signupEmailController.text.isEmpty ||
        _signupPasswordController.text.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }

    // FIX #7: Validate email format on signup
    final email = _signupEmailController.text.toLowerCase().trim();
    if (!_isValidEmail(email)) {
      _showSnack('Please enter a valid email address');
      return;
    }

    // FIX #1 (email taken check): Verify email not already registered
    final alreadyRegistered = await CurrentUserService.instance.isEmailRegistered(email);
    if (alreadyRegistered) {
      if (!mounted) return;
      _showSnack('This email is already registered. Please log in instead.');
      return;
    }

    // BUG #5 FIX: Admin email blocking now handled server-side.
    // Reserved emails will fail at Firebase Auth signup.

    if (_signupPasswordController.text != _signupConfirmController.text) {
      _showSnack('Passwords do not match');
      return;
    }
    if (_signupPasswordController.text.length < 8) {
      _showSnack('Password must be at least 8 characters');
      return;
    }
    if (_signupDisplayNameController.text.isEmpty) {
      _showSnack('Please enter a display name');
      return;
    }
    if (!_agreedToTerms) {
      _showSnack('You must agree to the Terms of Service');
      return;
    }
    setState(() => _signupStep = 1);
  }

  /// After address step, go to human verification (step 2)
  void _goToVerificationStep() {
    if (_selectedState == null) {
      _showSnack('Please select your state');
      return;
    }
    if (_signupCityController.text.isEmpty) {
      _showSnack('Please enter your city');
      return;
    }
    setState(() => _signupStep = 2);
  }

  Future<void> _handleSignup() async {
    setState(() => _isLoading = true);

    final email = _signupEmailController.text.toLowerCase().trim();
    final password = _signupPasswordController.text;
    final displayName = _signupDisplayNameController.text.trim();

    try {
      // ── Firebase Authentication — Create Account + Firestore Profile ──
      await FirebaseAuthService.instance.signUp(
        email: email,
        password: password,
        displayName: displayName,
        state: _selectedState,
        city: _signupCityController.text.trim(),
        street: _signupStreetController.text.trim(),
        zip: _signupZipController.text.trim(),
      );

      // Accept ToS in local storage
      if (_agreedToTerms) {
        await ChatAccessService.acceptTos();
      }

      // Mark as human-verified
      await _botService.markHumanVerified();

      // Load the fresh Firestore profile into CurrentUserService
      await CurrentUserService.instance.load();

      // ── Anti-Abuse: Record account creation time + device fingerprint ──
      await PromoCodeService.instance.recordAccountCreation();
      await DeviceFingerprintService.instance.getDeviceId();

      if (!mounted) return;
      setState(() => _isLoading = false);

      // ── Welcome Flow Overlay (companion + promo + social + profile stats) ──
      // Always show the welcome flow for new signups — covers all onboarding steps.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (routeContext) => WelcomeFlowOverlay(
              onDismiss: () {
                _navigateAfterAuthFrom(routeContext);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(e.toString());
    }
  }

  void _showForgotPassword() {
    final resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Password',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your email and we\'ll send you a reset link.',
                style:
                    TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              style: TextStyle(color: BmbColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: BmbColors.textTertiary),
                prefixIcon:
                    const Icon(Icons.email, color: BmbColors.textSecondary),
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
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: BmbColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final resetEmail = resetEmailController.text.trim();
              Navigator.pop(ctx);
              if (resetEmail.isNotEmpty) {
                try {
                  await FirebaseAuthService.instance.sendPasswordResetEmail(resetEmail);
                  _showSnack('Password reset link sent to $resetEmail');
                } catch (e) {
                  _showSnack(e.toString());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: BmbColors.midNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 30),
                _buildLogo(),
                const SizedBox(height: 16),
                Text('Back My Bracket',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 24,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                const SizedBox(height: 8),
                Text('Join the ultimate tournament experience',
                    style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 28),
                // Tab bar
                Container(
                  decoration: BoxDecoration(
                      color: BmbColors.cardDark,
                      borderRadius: BorderRadius.circular(12)),
                  child: TabBar(
                    controller: _tabController,
                    onTap: (_) {
                      setState(() {
                        _signupStep = -1;
                        _humanVerified = false;
                      });
                    },
                    indicator: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        BmbColors.blue,
                        BmbColors.blue.withValues(alpha: 0.8)
                      ]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: BmbColors.textTertiary,
                    tabs: const [Tab(text: 'Login'), Tab(text: 'Sign Up')],
                  ),
                ),
                const SizedBox(height: 24),
                // Tab content
                SizedBox(
                  height: _calcTabHeight(),
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLoginForm(), _buildSignupContent()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calcTabHeight() {
    switch (_signupStep) {
      case 2:
        return 380; // verification step
      case 1:
        return 560; // address step
      default:
        return 520; // login / signup step 0 / chooser
    }
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/splash_dark.png',
      width: 120,
      height: 120,
    );
  }

  // ─── LOGIN FORM ─────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('Email', _loginEmailController, Icons.email, false),
        const SizedBox(height: 16),
        _buildTextField(
            'Password', _loginPasswordController, Icons.lock, true,
            isPassword: true,
            visible: _loginPasswordVisible,
            onToggle: () =>
                setState(() => _loginPasswordVisible = !_loginPasswordVisible)),
        const SizedBox(height: 12),

        // ── Remember Me + Biometric toggles ──
        _buildRememberMeRow(),
        const SizedBox(height: 4),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPassword,
            child: Text('Forgot Password?',
                style: TextStyle(color: BmbColors.blue, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 12),
        _buildPrimaryButton('Login', _isLoading ? null : _handleLogin),

        // ── Biometric quick-login button ──
        if (_hasSavedCredentials && _biometricEnabled) ...[
          const SizedBox(height: 14),
          _buildBiometricButton(),
        ],
      ],
    );
  }

  Widget _buildRememberMeRow() {
    return Column(
      children: [
        // Remember Me
        Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (val) async {
                  final v = val ?? false;
                  setState(() => _rememberMe = v);
                  await _bioService.setRememberMe(v);
                  if (!v) {
                    setState(() {
                      _biometricEnabled = false;
                      _hasSavedCredentials = false;
                      _savedEmail = null;
                    });
                  }
                },
                fillColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? BmbColors.blue : null),
                checkColor: Colors.white,
                side: BorderSide(
                  color:
                      _rememberMe ? BmbColors.blue : BmbColors.textTertiary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 8),
            Text('Remember Me',
                style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 13)),
            const Spacer(),
            // Biometric toggle (only visible when Remember Me is on)
            if (_rememberMe)
              Row(
                children: [
                  Icon(Icons.face,
                      color: _biometricEnabled
                          ? BmbColors.blue
                          : BmbColors.textTertiary,
                      size: 18),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 36,
                    height: 20,
                    child: Switch(
                      value: _biometricEnabled,
                      onChanged: (val) async {
                        setState(() => _biometricEnabled = val);
                        await _bioService.setBiometricEnabled(val);
                      },
                      activeThumbColor: BmbColors.blue,
                      activeTrackColor:
                          BmbColors.blue.withValues(alpha: 0.3),
                      inactiveThumbColor: BmbColors.textTertiary,
                      inactiveTrackColor:
                          BmbColors.borderColor,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Face ID',
                      style: TextStyle(
                          color: _biometricEnabled
                              ? BmbColors.blue
                              : BmbColors.textTertiary,
                          fontSize: 11,
                          fontWeight: BmbFontWeights.semiBold)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBiometricButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _showBiometricLogin,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: BmbColors.blue.withValues(alpha: 0.5)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [BmbColors.blue, BmbColors.vipPurple],
                ),
              ),
              child:
                  const Icon(Icons.face, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Sign in with Face ID',
                style: TextStyle(
                    color: BmbColors.blue,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.semiBold)),
          ],
        ),
      ),
    );
  }

  // ─── SIGNUP CONTENT (4-step: chooser → account → address → verify) ───
  Widget _buildSignupContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _signupStep == -1
          ? _buildAccountTypeChooser()
          : _signupStep == 0
              ? _buildSignupStep1()
              : _signupStep == 1
                  ? _buildSignupStep2()
                  : _buildSignupStep3Verification(),
    );
  }

  /// Step -1: Choose account type (Individual or Business)
  Widget _buildAccountTypeChooser() {
    return Column(
      key: const ValueKey('chooser'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How will you use BMB?',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 18,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay')),
        const SizedBox(height: 6),
        Text('Choose your account type to get started.',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        _accountTypeCard(
          icon: Icons.person,
          title: 'Individual',
          subtitle:
              'Join tournaments, build brackets, and compete with friends.',
          color: BmbColors.blue,
          onTap: () => setState(() => _signupStep = 0),
        ),
        const SizedBox(height: 14),
        _accountTypeCard(
          icon: Icons.store,
          title: 'Bar / Restaurant / Venue',
          subtitle:
              'Host tournaments at your establishment and drive customer engagement.',
          color: BmbColors.gold,
          badge: 'BUSINESS',
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BusinessSignupScreen()));
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BmbColors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: BmbColors.blue, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Business accounts get a dedicated BMB Starter Kit, marketing materials, QR codes, and hosting tools.',
                  style: TextStyle(
                      color: BmbColors.textSecondary,
                      fontSize: 11,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04)
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 15,
                              fontWeight: BmbFontWeights.bold)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(badge,
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: BmbFontWeights.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: BmbColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  /// Step 1: Email, display name, password (Individual flow)
  Widget _buildSignupStep1() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _signupStep = -1),
          child: Row(
            children: [
              const Icon(Icons.arrow_back, color: BmbColors.blue, size: 18),
              const SizedBox(width: 4),
              Text('Back',
                  style: TextStyle(
                      color: BmbColors.blue,
                      fontSize: 13,
                      fontWeight: BmbFontWeights.semiBold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Step 1 of 3',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 11,
                        fontWeight: BmbFontWeights.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildTextField('Display Name', _signupDisplayNameController,
            Icons.person, false),
        const SizedBox(height: 14),
        _buildTextField(
            'Email', _signupEmailController, Icons.email, false),
        const SizedBox(height: 14),
        _buildTextField(
            'Password', _signupPasswordController, Icons.lock, true,
            isPassword: true,
            visible: _signupPasswordVisible,
            onToggle: () => setState(
                () => _signupPasswordVisible = !_signupPasswordVisible)),
        const SizedBox(height: 14),
        _buildTextField('Confirm Password', _signupConfirmController,
            Icons.lock, true,
            isPassword: true,
            visible: _confirmPasswordVisible,
            onToggle: () => setState(
                () => _confirmPasswordVisible = !_confirmPasswordVisible)),
        const SizedBox(height: 8),
        _buildPasswordRequirements(),
        const SizedBox(height: 12),
        _buildTermsCheckbox(),
        const SizedBox(height: 12),
        _buildPrimaryButton('Continue to Address', _goToAddressStep),
      ],
    );
  }

  /// Step 2: Address with required state
  Widget _buildSignupStep2() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _signupStep = 0),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back,
                      color: BmbColors.blue, size: 18),
                  const SizedBox(width: 4),
                  Text('Back',
                      style: TextStyle(
                          color: BmbColors.blue,
                          fontSize: 13,
                          fontWeight: BmbFontWeights.semiBold)),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Step 2 of 3',
                  style: TextStyle(
                      color: BmbColors.blue,
                      fontSize: 11,
                      fontWeight: BmbFontWeights.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Your Address',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 18,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(height: 4),
        Text(
            'We need your state to display with your profile across the platform.',
            style:
                TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        _buildTextField('Street Address (optional)',
            _signupStreetController, Icons.home, false),
        const SizedBox(height: 14),
        _buildTextField(
            'City', _signupCityController, Icons.location_city, false),
        const SizedBox(height: 14),
        _buildStateDropdown(),
        const SizedBox(height: 14),
        _buildTextField(
            'ZIP Code (optional)', _signupZipController, Icons.pin, false,
            keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BmbColors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: BmbColors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your state abbreviation (e.g. TX, NY, CA) will appear next to your name on bracket cards, leaderboards, and your profile.',
                  style:
                      TextStyle(color: BmbColors.blue, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildPrimaryButton(
            'Continue to Verification', _goToVerificationStep),
      ],
    );
  }

  /// Step 3: Human Verification Challenge
  Widget _buildSignupStep3Verification() {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _signupStep = 1),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back,
                      color: BmbColors.blue, size: 18),
                  const SizedBox(width: 4),
                  Text('Back',
                      style: TextStyle(
                          color: BmbColors.blue,
                          fontSize: 13,
                          fontWeight: BmbFontWeights.semiBold)),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _humanVerified
                    ? BmbColors.successGreen.withValues(alpha: 0.15)
                    : BmbColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_humanVerified)
                    const Icon(Icons.verified,
                        color: BmbColors.successGreen, size: 12),
                  if (_humanVerified) const SizedBox(width: 4),
                  Text(
                    _humanVerified ? 'Verified' : 'Step 3 of 3',
                    style: TextStyle(
                        color: _humanVerified
                            ? BmbColors.successGreen
                            : BmbColors.blue,
                        fontSize: 11,
                        fontWeight: BmbFontWeights.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Human verification widget
        HumanVerificationWidget(
          onVerified: () {
            setState(() => _humanVerified = true);
          },
          onCancel: () => setState(() => _signupStep = 1),
        ),
        const SizedBox(height: 20),
        // Create Account button (only enabled after verification)
        AnimatedOpacity(
          opacity: _humanVerified ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 300),
          child: _buildPrimaryButton(
            'Create Account',
            _humanVerified && !_isLoading ? _handleSignup : null,
          ),
        ),
        if (!_humanVerified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Complete the challenge above to create your account',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStateDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedState != null
              ? BmbColors.blue
              : BmbColors.borderColor,
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedState,
        decoration: InputDecoration(
          labelText: 'State *',
          labelStyle: TextStyle(color: BmbColors.textTertiary),
          prefixIcon: const Icon(Icons.location_on,
              color: BmbColors.textSecondary),
          border: InputBorder.none,
        ),
        dropdownColor: BmbColors.midNavy,
        style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
        icon: const Icon(Icons.keyboard_arrow_down,
            color: BmbColors.textSecondary),
        items: UserProfile.usStates.map((abbr) {
          final name = UserProfile.stateNames[abbr] ?? abbr;
          return DropdownMenuItem(
            value: abbr,
            child: Text('$abbr - $name',
                style: TextStyle(
                    color: BmbColors.textPrimary, fontSize: 14)),
          );
        }).toList(),
        onChanged: (val) => setState(() => _selectedState = val),
        validator: (val) => val == null ? 'State is required' : null,
        menuMaxHeight: 300,
      ),
    );
  }

  // ─── SHARED WIDGETS ─────────────────────────────────────────────────────
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool obscure, {
    bool isPassword = false,
    bool visible = false,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !visible,
      keyboardType: keyboardType,
      style: TextStyle(color: BmbColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: BmbColors.textTertiary),
        prefixIcon: Icon(icon, color: BmbColors.textSecondary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    visible ? Icons.visibility : Icons.visibility_off,
                    color: BmbColors.textTertiary),
                onPressed: onToggle)
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

  Widget _buildPrimaryButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
            backgroundColor: BmbColors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: _isLoading && onTap == null
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(label,
                style: TextStyle(
                    fontSize: 16, fontWeight: BmbFontWeights.bold)),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (val) =>
                setState(() => _agreedToTerms = val ?? false),
            fillColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? BmbColors.blue : null),
            checkColor: Colors.white,
            side: BorderSide(
              color:
                  _agreedToTerms ? BmbColors.blue : BmbColors.textTertiary,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            children: [
              Text('I agree to the ',
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12)),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const TermsOfServiceScreen())),
                child: Text('Terms of Service',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: BmbColors.blue)),
              ),
              Text(', ',
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12)),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const PrivacyPolicyScreen())),
                child: Text('Privacy Policy',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: BmbColors.blue)),
              ),
              Text(' & ',
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 12)),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const CommunityGuidelinesScreen())),
                child: Text('Community Guidelines',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: BmbColors.blue)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final p = _signupPasswordController.text;
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
        Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? BmbColors.successGreen : BmbColors.textTertiary,
            size: 14),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                color:
                    met ? BmbColors.successGreen : BmbColors.textTertiary,
                fontSize: 12)),
      ]),
    );
  }
}
