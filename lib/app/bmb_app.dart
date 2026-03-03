import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/features/splash/presentation/screens/splash_screen.dart';
import 'package:bmb_mobile/features/auth/presentation/screens/auth_screen.dart';
import 'package:bmb_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bmb_mobile/features/referral/presentation/screens/referral_landing_page.dart';
import 'package:bmb_mobile/features/referral/data/services/referral_code_service.dart';
import 'package:bmb_mobile/features/guide_preview/hologram_guide_preview.dart';
import 'package:bmb_mobile/features/companion/presentation/screens/companion_selector_screen.dart';
import 'package:bmb_mobile/features/sharing/presentation/screens/join_bracket_screen.dart';
import 'package:bmb_mobile/features/sharing/data/services/deep_link_service.dart';

/// FIX #15: Pruned unused named routes — only '/', '/auth', '/dashboard'
/// are navigated via pushNamed / pushReplacementNamed.
/// All other screens are reached via direct Navigator.push(MaterialPageRoute(...)).
class BmbApp extends StatelessWidget {
  const BmbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Back My Bracket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'ClashDisplay',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BmbColors.deepNavy,
        colorScheme: ColorScheme.dark(
          primary: BmbColors.blue,
          secondary: BmbColors.gold,
          surface: BmbColors.midNavy,
          error: BmbColors.errorRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/guide-preview': (context) => const HologramGuidePreview(),
        '/companion-select': (context) => const CompanionSelectorScreen(isOnboarding: true),
      },
      // Handle deep links: /join/{bracketId} and /invite?ref=CODE
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');

        // ─── BRACKET JOIN DEEP LINK ───
        // Handles: /join/abc123 → JoinBracketScreen
        final bracketId = DeepLinkService.parseBracketIdFromPath(uri.path);
        if (bracketId != null) {
          return MaterialPageRoute(
            builder: (_) => JoinBracketScreen(bracketId: bracketId),
          );
        }

        // ─── REFERRAL DEEP LINK ───
        if (uri.path == ReferralCodeService.landingRoute) {
          final code = uri.queryParameters['ref'];
          final scrollToVideos = uri.queryParameters['section'] == 'videos';
          return MaterialPageRoute(
            builder: (_) => ReferralLandingPage(
              referralCode: code,
              scrollToVideos: scrollToVideos,
            ),
          );
        }
        return null;
      },
    );
  }
}
