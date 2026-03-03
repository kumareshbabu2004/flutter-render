import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String privacyText = '''
BACK MY BRACKET — PRIVACY POLICY

Last Updated: February 9, 2025

Back My Bracket ("BMB," "we," "us," or "our") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.

1. INFORMATION WE COLLECT

1.1 Information You Provide:
   - Account registration data (display name, email address, password)
   - Address information (street address, city, state abbreviation, ZIP code)
   - Profile information (bio, profile images)
   - Tournament and bracket participation data
   - Chat messages within tournament rooms
   - Payment information for BMB Bucket credit purchases (credit card, Apple Pay, Google Pay) and BMB+ subscriptions
   - Credit transaction data (purchases, deductions, awards, Auto-Replenish events, store redemptions)
   - Tournament hosting data (contributions set, reward configurations, winner confirmations)

1.2 Information Collected Automatically:
   - Device information (device type, operating system, unique device identifiers)
   - Usage data (features accessed, time spent, brackets joined)
   - Log data (IP address, access times, pages viewed)
   - Location data (state/region, derived from your provided address)

1.3 Information from Third Parties:
   - Payment processor data (transaction confirmations, not full card numbers)
   - App store data (purchase history related to our App)

2. HOW WE USE YOUR INFORMATION

We use collected information for the following purposes:
   - To create and manage your account
   - To display your state abbreviation on your profile, bracket cards, leaderboards, and chat
   - To process BMB Bucket credit purchases, Auto-Replenish charges, and BMB+ subscription payments
   - To process BMB Store redemptions, including digital gift card code delivery and physical product shipping
   - To facilitate tournament participation and bracket management
   - To moderate chat rooms and enforce community guidelines
   - To send notifications about tournaments, results, and account activity
   - To improve and optimize the App's performance and features
   - To maintain authoritative records of all credit transactions (purchases, deductions, awards, Auto-Replenish charges)
   - To process host contribution deductions and winner reward credit awards
   - To enforce credit-related Terms of Service provisions
   - To detect, prevent, and address fraud, abuse, and security issues
   - To comply with legal obligations

3. HOW WE SHARE YOUR INFORMATION

3.1 Public Information:
   - Your display name, state abbreviation, and profile information are visible to other users
   - Your tournament participation, ratings, and hosted brackets are publicly visible
   - Chat messages are visible to other participants in the same tournament

3.2 We may share your information with:
   - Service providers who help us operate the App (hosting, analytics, payment processing)
   - Law enforcement when required by law or to protect our rights
   - Other users as part of the App's social features (as described above)

3.3 We do NOT:
   - Sell your personal information to third parties
   - Share your full address with other users (only state abbreviation is displayed)
   - Share your email address with other users
   - Provide your data to advertising networks for targeted advertising

4. DATA RETENTION

4.1 We retain your account data for as long as your account is active.
4.2 Chat messages are retained for the duration of the tournament plus 90 days.
4.3 Upon account deletion, we will remove your personal data within 30 days, except where retention is required by law.
4.4 Anonymized usage data may be retained indefinitely for analytical purposes.

5. DATA SECURITY

5.1 We implement industry-standard security measures including:
   - Encryption of data in transit and at rest
   - Secure password hashing
   - Regular security audits
   - Access controls and authentication for internal systems

5.2 No method of transmission over the Internet is 100% secure. We cannot guarantee absolute security of your data.

6. YOUR RIGHTS

Depending on your jurisdiction, you may have the right to:
   - Access the personal data we hold about you
   - Correct inaccurate personal data
   - Delete your personal data
   - Object to or restrict processing of your data
   - Data portability (receive your data in a structured format)
   - Withdraw consent at any time

To exercise these rights, contact us at privacy@backmybracket.com.

7. CHILDREN'S PRIVACY

Back My Bracket is not intended for users under the age of 18. We do not knowingly collect personal information from children under 18. If we discover we have collected data from a child under 18, we will promptly delete it.

8. STATE-SPECIFIC RIGHTS

8.1 California Residents (CCPA/CPRA):
   - You have the right to know what personal information we collect and how it is used
   - You have the right to request deletion of your personal information
   - You have the right to opt-out of the sale of personal information (we do not sell your data)
   - You will not be discriminated against for exercising your privacy rights

8.2 Other State Privacy Laws:
   - We comply with applicable state privacy laws including those in Virginia (VCDPA), Colorado (CPA), Connecticut (CTDPA), and other states with consumer privacy legislation

9. INTERNATIONAL USERS

If you access the App from outside the United States, your data may be transferred to and processed in the United States. By using the App, you consent to this transfer and processing.

10. COOKIES AND TRACKING

The App may use local storage and similar technologies to enhance your experience. This includes:
   - Remembering your login status
   - Saving your preferences
   - Tracking App performance and usage analytics

11. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. We will notify you of material changes through the App or via email. Your continued use of the App after changes are posted constitutes acceptance of the updated Privacy Policy.

12. CONTACT US

For questions or concerns about this Privacy Policy:

Back My Bracket
Email: privacy@backmybracket.com
General: support@backmybracket.com

For data deletion requests or privacy rights inquiries, please email privacy@backmybracket.com with the subject line "Privacy Request."
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text('Privacy Policy',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 20,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: BmbColors.cardGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: BmbColors.borderColor, width: 0.5),
                    ),
                    child: Text(
                      privacyText,
                      style: TextStyle(
                          color: BmbColors.textSecondary,
                          fontSize: 13,
                          height: 1.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
