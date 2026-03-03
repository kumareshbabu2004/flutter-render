import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:bmb_mobile/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:bmb_mobile/features/legal/presentation/screens/community_guidelines_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text('About',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 20,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                  ],
                ),
                const SizedBox(height: 32),

                // Logo — BMB brand mark
                Image.asset(
                  'assets/images/splash_dark.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 16),
                Text('Back My Bracket',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 24,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                const SizedBox(height: 4),
                Text('Version 2.0.0',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 13)),
                const SizedBox(height: 24),

                // Description
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: BmbColors.cardGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: BmbColors.borderColor, width: 0.5),
                  ),
                  child: Text(
                    'Back My Bracket is the ultimate tournament bracket platform. '
                    'Create, host, and compete in brackets for any sport, topic, or event. '
                    'From March Madness to pizza polls, BMB brings the competitive fun '
                    'to your fingertips.\n\n'
                    'Join thousands of bracket enthusiasts, follow top hosts, '
                    'earn credits, and climb the leaderboards. '
                    'Whether you\'re a casual fan or a serious competitor, '
                    'Back My Bracket has something for you.',
                    style: TextStyle(
                        color: BmbColors.textSecondary,
                        fontSize: 14,
                        height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),

                // Links
                _buildLinkTile(context, 'Terms of Service',
                    Icons.description, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TermsOfServiceScreen()));
                }),
                _buildLinkTile(context, 'Privacy Policy',
                    Icons.privacy_tip, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()));
                }),
                _buildLinkTile(context, 'Community Guidelines',
                    Icons.people, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const CommunityGuidelinesScreen()));
                }),
                _buildLinkTile(
                    context, 'Licenses', Icons.gavel, () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Back My Bracket',
                    applicationVersion: '2.0.0',
                  );
                }),
                const SizedBox(height: 24),

                // Footer
                Text('Made with love for bracket fans everywhere',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('\u00a9 2025 Back My Bracket. All rights reserved.',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkTile(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: ListTile(
        leading: Icon(icon, color: BmbColors.textSecondary, size: 22),
        title: Text(title,
            style: TextStyle(
                color: BmbColors.textPrimary, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right,
            color: BmbColors.textTertiary, size: 20),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
