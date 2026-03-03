import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/support/presentation/screens/ai_support_chat_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      ('How do I join a bracket?', 'Tap "Join" on any live bracket from the Home or Explore tab. Free brackets let you join instantly. Paid brackets require credits from your BMB Bucket. You\'ll see a confirmation before any credits are deducted.'),
      ('What is the BMB Bucket?', 'Your BMB Bucket holds your credits. Purchase credits using a credit card, Apple Pay, or Google Pay. Credits are used for bracket contributions, rewards, and the BMB Store. You can also turn on Auto-Replenish to automatically add 10 credits whenever your bucket drops to 10 or below.'),
      ('How do I host a tournament?', 'Any user can build brackets using the Bracket Builder. However, saving, sharing, and hosting tournaments requires a BMB+ membership. Tap the "+" button to start building, and upgrade when you\'re ready to go live!'),
      ('How does the chat work?', 'Each tournament has a private chat room. Tap the chat bubble icon on any bracket to join the conversation. Our profanity filter keeps things clean.'),
      ('What is BMB+?', 'BMB+ is our premium membership. Hosts get unlimited tournaments, revenue sharing, analytics, a premium badge, and priority support.'),
      ('How do I edit my profile?', 'Go to Profile tab > Account Settings. You can change your display name, address, and state abbreviation.'),
      ('How are winners determined?', 'Winners are determined by the bracket host based on the tournament rules. Once all games are complete, the host must use the "Confirm Winner & Award Credits" button in the Results Manager. Reward credits are NOT distributed until the host explicitly confirms the champion. This protects against premature or incorrect credit awards.'),
      ('What is the BMB Store?', 'The BMB Store is where you can redeem your credits for real products. Browse digital gift cards (Amazon, Visa, DoorDash, Starbucks, Nike, Uber Eats), BMB merchandise (hoodies, snapbacks, t-shirts, mystery boxes), digital items (avatar frames, bracket themes, badges), and custom bracket products with your picks printed on posters, canvases, t-shirts, and mugs.'),
      ('How do digital gift cards work?', 'When you redeem a digital gift card, the redemption code is delivered instantly to your in-app inbox. You can copy the code and use it at the respective merchant (Amazon, Visa, etc.). Codes are also saved in your order history for safekeeping.'),
      ('What are custom bracket products?', 'Custom bracket products let you get your individual bracket picks printed on physical items like posters, canvases, t-shirts, and mugs. Select a completed bracket, choose a product, and we\'ll create a personalized item shipped to your address.'),
      ('Where do I find my gift card codes?', 'All digital gift card codes are delivered to your in-app inbox (accessible from the BMB Store or your profile). Codes are also visible in your order history. You can copy codes anytime.'),
      ('How does the credit flow work for hosts?', 'When you create a bracket with a credits contribution, the total contribution amount is deducted from YOUR BMB Bucket when the tournament goes LIVE. If you don\'t have enough credits, you\'ll be prompted to add more or, if Auto-Replenish is on, credits will be purchased automatically. The contribution amount you set is what participants will also contribute from their own buckets when they join.'),
      ('When are reward credits awarded to winners?', 'Reward credits are awarded ONLY after the host confirms the champion in the Results Manager. Credits are held by the platform during the tournament. The host must explicitly tap "Confirm Winner & Award Credits" once all games are complete. This ensures accurate and fair credit distribution. Credits are never awarded speculatively or during the tournament.'),
      ('Can I transfer credits to another user?', 'No. Credits CANNOT be exchanged, sent, gifted, or transferred between users under any circumstances. All credit movements happen exclusively between individual users and the BMB platform. There is no mechanism to transfer credits from one account to another.'),
      ('What happens if I don\'t have enough credits to join a bracket?', 'You\'ll see a "Fill My Bucket" prompt to purchase more credits. If you have Auto-Replenish enabled and your balance drops to 10 or below, credits will be purchased automatically. You can always check your bucket balance before joining.'),
      ('Is the BMB Store gambling?', 'No. BMB is NOT a gambling platform. The BMB Store is a rewards marketplace. Credits are purchased or earned as tournament rewards and can be redeemed for products. Credits have no real-world monetary value and cannot be converted to cash. There are no peer-to-peer transfers, no cash-out, and all outcomes are skill-based - not chance-based.'),
    ];

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
                    Text('Help & Support',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 20,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ═════════════════════════════════════════════════
                    //  AI LIVE CHAT — primary CTA
                    // ═════════════════════════════════════════════════
                    _buildLiveChatCard(context),
                    const SizedBox(height: 16),

                    // ═════════════════════════════════════════════════
                    //  EMAIL CONTACT — secondary option
                    // ═════════════════════════════════════════════════
                    _buildEmailCard(context),
                    const SizedBox(height: 24),

                    // ═════════════════════════════════════════════════
                    //  FAQ SECTION
                    // ═════════════════════════════════════════════════
                    Text('Frequently Asked Questions',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 16,
                            fontWeight: BmbFontWeights.bold)),
                    const SizedBox(height: 12),
                    ...faqs.map((faq) => _buildFaqTile(faq.$1, faq.$2)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AI LIVE CHAT CARD ──────────────────────────────────────────
  Widget _buildLiveChatCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiSupportChatScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            BmbColors.blue.withValues(alpha: 0.15),
            const Color(0xFF36B37E).withValues(alpha: 0.08),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BmbColors.blue.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: BmbColors.blue.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: BmbColors.blue.withValues(alpha: 0.3), blurRadius: 12),
                ],
              ),
              child: const Icon(Icons.support_agent, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Live Chat Support',
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 17,
                              fontWeight: BmbFontWeights.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: BmbColors.successGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: BmbColors.successGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('Online',
                                style: TextStyle(
                                    color: BmbColors.successGreen,
                                    fontSize: 10,
                                    fontWeight: BmbFontWeights.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Get instant answers from our AI assistant.\nCan\'t resolve it? We\'ll create a tech ticket.',
                      style: TextStyle(
                          color: BmbColors.textSecondary,
                          fontSize: 13,
                          height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: BmbColors.blue, size: 16),
          ],
        ),
      ),
    );
  }

  // ── EMAIL CONTACT CARD ─────────────────────────────────────────
  Widget _buildEmailCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BmbColors.borderColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.email_outlined, color: BmbColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email Us Directly',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.semiBold)),
                const SizedBox(height: 2),
                Text('tech@backmybracket.com',
                    style: TextStyle(color: BmbColors.blue, fontSize: 13)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Email client opening...'),
                  backgroundColor: BmbColors.midNavy,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Text('Send',
                style: TextStyle(
                    color: BmbColors.blue,
                    fontSize: 13,
                    fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: BmbColors.blue,
        collapsedIconColor: BmbColors.textTertiary,
        title: Text(question,
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 14,
                fontWeight: BmbFontWeights.semiBold)),
        children: [
          Text(answer,
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 13,
                  height: 1.5)),
        ],
      ),
    );
  }
}
