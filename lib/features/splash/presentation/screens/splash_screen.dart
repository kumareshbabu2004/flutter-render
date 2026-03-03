import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firebase_auth.dart';
import 'package:bmb_mobile/features/companion/data/companion_service.dart';
import 'package:bmb_mobile/features/sharing/data/services/deep_link_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
    _checkAuthAndNavigate();

    // Safety-net: force-navigate to auth after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && !_hasNavigated) {
        if (kDebugMode) debugPrint('SplashScreen: safety-timeout — forcing /auth');
        _navigateTo('/auth');
      }
    });
  }

  void _navigateTo(String route) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      // Wait for the animation to finish (1.5 s)
      await Future.delayed(const Duration(milliseconds: 1500));

      // Check REST auth state — instant, no Firebase JS SDK needed
      final isLoggedIn = RestFirebaseAuth.instance.isSignedIn;

      // Load CurrentUserService with timeout
      try {
        await CurrentUserService.instance.load()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        if (kDebugMode) debugPrint('SplashScreen: CurrentUserService.load failed: $e');
      }

      // Init companion service with timeout
      try {
        await CompanionService.instance.init()
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        if (kDebugMode) debugPrint('SplashScreen: CompanionService.init failed: $e');
      }

      if (!mounted || _hasNavigated) return;

      // Ensure minimum 2 second splash display
      await Future.delayed(const Duration(milliseconds: 500));

      // ═══ PHASE 8: Check for deep link in URL (web platform) ═══
      // On web, the URL might be /join/abc123 from a shared link
      try {
        if (kIsWeb) {
          final path = Uri.base.path;
          if (kDebugMode) debugPrint('SplashScreen: URL path = $path');
          final bracketId = DeepLinkService.parseBracketIdFromPath(path);
          if (bracketId != null) {
            if (isLoggedIn) {
              _navigateTo('/join/$bracketId');
            } else {
              // Store for after login
              await DeepLinkService.instance.setPendingBracket(bracketId);
              _navigateTo('/auth');
            }
            return;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('SplashScreen: deep link check failed: $e');
      }

      if (!isLoggedIn) {
        _navigateTo('/auth');
      } else if (CompanionService.instance.isFirstTimer) {
        _navigateTo('/companion-select');
      } else {
        _navigateTo('/dashboard');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SplashScreen: error — navigating to /auth: $e');
      _navigateTo('/auth');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/splash_dark.png',
                        width: 120,
                        height: 120,
                      ),
                      const SizedBox(height: 24),
                      Text('Back My Bracket',
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 24,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                      const SizedBox(height: 40),
                      SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  BmbColors.gold))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}
