import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  static const String guidelinesText = '''
BACK MY BRACKET — COMMUNITY GUIDELINES

Last Updated: January 1, 2025

Back My Bracket is built on competition, sportsmanship, and community. These guidelines ensure every user has a positive, safe, and fair experience. Violations may result in warnings, suspensions, or permanent bans.

1. RESPECT EVERY USER

1.1 Treat all users with respect, regardless of their skill level, background, or opinions.
1.2 Personal attacks, bullying, intimidation, or targeted harassment are strictly prohibited.
1.3 Discriminatory language based on race, ethnicity, gender, sexual orientation, religion, disability, or any other protected characteristic will result in immediate suspension.
1.4 Do not "dox" or share personal information about other users without their consent.

2. CHAT ROOM CONDUCT

2.1 Tournament chat rooms are for fun banter, discussion, and competition-related conversation.
2.2 Prohibited in all chat rooms:
   - Profanity, vulgar language, or obscene content
   - Harassment, threats, or abusive language
   - Spam, excessive caps, or flooding
   - Solicitation, advertising, or promotional content
   - Links to external websites (unless tournament-related)
   - Hate speech or discriminatory remarks
   - Sexually explicit or suggestive content
   - Graphic violence or disturbing content

2.3 Our automated profanity filter will flag or block inappropriate content. Attempting to bypass the filter (e.g., using special characters, misspellings, or coded language) is a violation.

2.4 If you encounter inappropriate behavior, use the "Report" function by long-pressing on a message. Reports are reviewed by our moderation team.

3. FAIR PLAY

3.1 Compete honestly and fairly in all brackets and tournaments.
3.2 Prohibited activities:
   - Creating multiple accounts to gain unfair advantage
   - Colluding with other users to manipulate bracket outcomes
   - Using automated tools, bots, or scripts to make picks
   - Exploiting bugs or glitches in the App
   - Sharing account credentials with others
   - Intentionally losing or throwing to manipulate results

3.3 Tournament hosts must set clear, fair rules and apply them consistently to all participants.

4. TOURNAMENT HOSTING STANDARDS

4.1 Hosts must:
   - Clearly describe tournament rules before the bracket opens
   - Treat all participants equally
   - Resolve disputes fairly and transparently
   - Not create misleading or deceptive tournament listings
   - Honor advertised rewards and contribution structures

4.2 Hosts must NOT:
   - Create tournaments that violate any laws
   - Use tournaments for gambling or wagering purposes
   - Discriminate against participants
   - Cancel tournaments without valid reason after collecting contributions
   - Manipulate results or outcomes

5. CONTENT STANDARDS

5.1 Profile content (display names, bios, profile images) must be:
   - Appropriate for all audiences
   - Free of offensive, discriminatory, or explicit material
   - Not impersonating another person or organization
   - Not promoting illegal activities

5.2 Tournament titles and descriptions must be:
   - Accurate and not misleading
   - Free of offensive content
   - Not promoting gambling, illegal activities, or harmful behavior

6. NOT A GAMBLING PLATFORM

6.1 Back My Bracket is an entertainment and skill-based competition platform.
6.2 Do NOT use BMB for gambling, wagering, or betting purposes.
6.3 Credits are virtual currency with no real-world monetary value.
6.4 Users who attempt to use the platform for illegal gambling will be permanently banned and reported to appropriate authorities.

7. REPORTING AND ENFORCEMENT

7.1 How to Report:
   - Chat messages: Long-press on the message and select "Report"
   - Users: Go to their profile and tap "Report"
   - Tournaments: Contact support@backmybracket.com

7.2 Enforcement Actions (escalating):
   - First violation: Warning notification
   - Second violation: 24-hour chat suspension
   - Third violation: 7-day account suspension
   - Fourth violation: 30-day account suspension
   - Severe or repeated violations: Permanent ban

7.3 Severe violations (threats of violence, doxxing, illegal gambling, hate speech) may result in immediate permanent ban without prior warnings.

7.4 Banned users forfeit all credits, active tournament entries, and subscription benefits.

8. APPEALS

8.1 If you believe an enforcement action was made in error, you may appeal by emailing appeals@backmybracket.com within 14 days.
8.2 Include your username, the date of the action, and why you believe it was incorrect.
8.3 Appeals are reviewed within 5 business days.
8.4 The decision on appeal is final.

9. GIVEAWAY DRAWINGS

9.1 Select BMB-hosted tournaments may include a promotional giveaway drawing at the conclusion of the tournament.
9.2 Giveaway drawings are PROMOTIONAL — they are NOT prizes for winning the bracket. All participants are equally eligible regardless of bracket score, rank, or outcome.
9.3 Winners are selected at random by the App. The drawing is transparent and fair.
9.4 Two winners are selected per giveaway: 1st place receives DOUBLE their contribution in credits; 2nd place receives credits equal to their contribution. The leaderboard leader may receive a separate bonus.
9.5 Giveaway credits are deposited instantly into the winner's BMB Bucket.
9.6 Giveaway results are announced publicly in the BMB Community and displayed on the ticker for 24 hours.
9.7 Giveaways are available only for qualifying BMB-hosted brackets with paid contributions and sufficient participants.

10. CHARITY & COMMUNITY EVENTS

10.1 BMB supports and encourages charity brackets where contributions benefit a designated cause.
10.2 Local events (bar nights, school tournaments, church fundraisers) are welcome and may be featured in the BMB Community.
10.3 Event hosts are responsible for all local regulations, venue coordination, and event conduct.
10.4 BMB does not endorse, verify, or guarantee any external charity or event.

11. POSITIVE COMMUNITY

We encourage users to:
   - Welcome new members
   - Share bracket strategies and tips
   - Celebrate good sportsmanship
   - Help others learn the platform
   - Give constructive, respectful feedback to hosts
   - Rate hosts and tournaments honestly
   - Support charity brackets and local events
   - Report inappropriate behavior promptly

12. CHANGES TO GUIDELINES

BMB may update these Community Guidelines at any time. We will notify users of significant changes through the App. Continued use of the App constitutes acceptance of the updated guidelines.

11. CONTACT

For questions about these guidelines:
Email: support@backmybracket.com
Appeals: appeals@backmybracket.com

Thank you for being part of the Back My Bracket community. Let's keep it competitive, fun, and respectful for everyone.
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
                    Text('Community Guidelines',
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
                      guidelinesText,
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
