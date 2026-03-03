import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/chat/data/services/chat_access_service.dart';
import 'package:bmb_mobile/features/dashboard/data/models/bracket_item.dart';

/// Shows a join-gate dialog when a user tries to access a tournament chat
/// without having joined. Also handles TOS acceptance, suspension, and ban
/// screens.
class ChatAccessGate {
  ChatAccessGate._();

  /// Check access and either navigate to chat or show the appropriate gate.
  /// Returns true if access was granted, false otherwise.
  static Future<bool> checkAndNavigate({
    required BuildContext context,
    required String bracketId,
    required String bracketTitle,
    required String hostName,
    required int participantCount,
    BracketItem? bracket,
  }) async {
    final result = await ChatAccessService.checkAccess(bracketId);

    if (result.allowed) return true;

    if (!context.mounted) return false;

    switch (result.reason) {
      case ChatDenialReason.banned:
        _showBannedDialog(context);
        return false;

      case ChatDenialReason.suspended:
        _showSuspendedDialog(context, result.message ?? '');
        return false;

      case ChatDenialReason.tosNotAccepted:
        final accepted = await _showTosAcceptanceDialog(context);
        if (accepted && context.mounted) {
          // BUG #12 FIX: Guard with context.mounted after async gap
          return checkAndNavigate(
            context: context,
            bracketId: bracketId,
            bracketTitle: bracketTitle,
            hostName: hostName,
            participantCount: participantCount,
            bracket: bracket,
          );
        }
        return false;

      case ChatDenialReason.notJoined:
        _showJoinRequiredDialog(
          context: context,
          bracketId: bracketId,
          bracketTitle: bracketTitle,
          hostName: hostName,
          bracket: bracket,
        );
        return false;

      case null:
        return false;
    }
  }

  // ─── BANNED DIALOG ───────────────────────────────────────────────────
  static void _showBannedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: BmbColors.errorRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gavel, color: BmbColors.errorRed, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Account Banned',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 20,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
            const SizedBox(height: 12),
            Text(
              'Your account has been permanently banned from all BMB chat rooms due to repeated violations of our Community Guidelines.\n\nTo appeal this decision, contact:\nappeals@backmybracket.com',
              textAlign: TextAlign.center,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Understood'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SUSPENDED DIALOG ────────────────────────────────────────────────
  static void _showSuspendedDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off, color: BmbColors.gold, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Chat Suspended',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 20,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TOS ACCEPTANCE DIALOG ───────────────────────────────────────────
  static Future<bool> _showTosAcceptanceDialog(BuildContext context) async {
    bool agreed = false;
    final scrollController = ScrollController();
    bool scrolledToBottom = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: BmbColors.midNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.8,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: BmbColors.blue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield, color: BmbColors.blue, size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text('Chat Room Agreement',
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 18,
                                fontWeight: BmbFontWeights.bold,
                                fontFamily: 'ClashDisplay')),
                        const SizedBox(height: 4),
                        Text('Please read and accept to continue',
                            style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scrollable terms
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollEndNotification) {
                          final pixels = scrollController.position.pixels;
                          final max = scrollController.position.maxScrollExtent;
                          if (pixels >= max - 50) {
                            setDialogState(() => scrolledToBottom = true);
                          }
                        }
                        return false;
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: BmbColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BmbColors.borderColor),
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Text(
                            _chatAgreementText,
                            style: TextStyle(
                                color: BmbColors.textSecondary, fontSize: 12, height: 1.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Checkbox
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: agreed,
                            onChanged: scrolledToBottom
                                ? (val) => setDialogState(() => agreed = val ?? false)
                                : null,
                            fillColor: WidgetStateProperty.resolveWith((states) =>
                                states.contains(WidgetState.selected) ? BmbColors.blue : null),
                            side: BorderSide(
                              color: scrolledToBottom
                                  ? BmbColors.textSecondary
                                  : BmbColors.textTertiary.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'I have read and agree to the Terms of Service, Community Guidelines, and Chat Room Agreement',
                            style: TextStyle(
                                color: scrolledToBottom
                                    ? BmbColors.textPrimary
                                    : BmbColors.textTertiary.withValues(alpha: 0.5),
                                fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!scrolledToBottom)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 16, right: 16),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward,
                              color: BmbColors.gold.withValues(alpha: 0.7), size: 14),
                          const SizedBox(width: 6),
                          Text('Scroll down to read the full agreement',
                              style: TextStyle(
                                  color: BmbColors.gold.withValues(alpha: 0.7), fontSize: 10)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BmbColors.textSecondary,
                              side: const BorderSide(color: BmbColors.borderColor),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: agreed
                                ? () async {
                                    await ChatAccessService.acceptTos();
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BmbColors.buttonPrimary,
                              disabledBackgroundColor:
                                  BmbColors.buttonPrimary.withValues(alpha: 0.3),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('I Agree',
                                style: TextStyle(fontWeight: BmbFontWeights.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return result == true;
  }

  // ─── JOIN REQUIRED DIALOG ────────────────────────────────────────────
  static void _showJoinRequiredDialog({
    required BuildContext context,
    required String bracketId,
    required String bracketTitle,
    required String hostName,
    BracketItem? bracket,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, color: BmbColors.blue, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Private Chat Room',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 20,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.5),
                children: [
                  const TextSpan(text: 'The chat room for '),
                  TextSpan(
                    text: bracketTitle,
                    style: TextStyle(
                        color: BmbColors.blue, fontWeight: BmbFontWeights.semiBold),
                  ),
                  const TextSpan(text: ' is only available to tournament participants.\n\n'),
                  const TextSpan(text: 'Join the tournament to access this chat room.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tournament info chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: BmbColors.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BmbColors.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, color: BmbColors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text('Hosted by $hostName',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BmbColors.textSecondary,
                    side: const BorderSide(color: BmbColors.borderColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Navigate to tournament join screen if bracket is provided
                    if (bracket != null) {
                      Navigator.pushNamed(ctx, '/dashboard');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.buttonPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Join Tournament',
                      style: TextStyle(fontWeight: BmbFontWeights.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── CHAT AGREEMENT TEXT ─────────────────────────────────────────────
  static const String _chatAgreementText = '''BACK MY BRACKET - CHAT ROOM AGREEMENT & TERMS OF USE

Last Updated: June 2025

By accessing any chat room within Back My Bracket ("BMB"), you acknowledge that you have read, understood, and agree to abide by the following terms. This agreement is supplemental to and incorporated into the BMB Terms of Service and Community Guidelines.

1. PRIVATE TOURNAMENT CHAT ROOMS

1.1 Each BMB tournament has its own private chat room that is EXCLUSIVELY accessible to users who have successfully joined that tournament.

1.2 You may NOT access, view, or participate in a tournament chat room unless you are a confirmed participant in that specific tournament.

1.3 Chat room access is granted upon successful tournament join and revoked upon leaving, disqualification, or tournament completion.

2. PROHIBITED CONDUCT IN ALL CHAT ROOMS

You agree to REFRAIN from any and all of the following in any BMB chat room:

2.1 VULGAR & INAPPROPRIATE LANGUAGE
You shall not use profanity, obscene language, or vulgar terms including but not limited to: fuck, shit, bitch, whore, asshole, cunt, dick, and any variations, misspellings, abbreviations, or coded versions thereof (e.g., f*ck, b**ch, sh!t, etc.).

2.2 HARASSMENT & BULLYING
You shall not engage in personal attacks, threats, intimidation, stalking, doxxing, or any form of targeted harassment against any user. This includes but is not limited to: telling someone to harm themselves, threatening physical violence, revealing personal information, or sustained unwanted contact.

2.3 DISCRIMINATION (ZERO TOLERANCE)
You shall not engage in any form of discrimination, hate speech, or prejudicial language based on:
  - Race or ethnicity
  - Gender or gender identity
  - Sexual orientation
  - Religion or religious beliefs
  - National origin or citizenship status
  - Disability or medical condition
  - Age
  - Any other protected characteristic

This includes but is not limited to: racial slurs, homophobic language (e.g., "tranny," "faggot"), antisemitic language, Islamophobic language, ableist slurs (e.g., "retard"), and any derogatory references to any group based on the above characteristics.

2.4 POLITICAL DISCUSSION
Political discussion of any kind is NOT PERMITTED in BMB chat rooms. This includes but is not limited to: discussion of political candidates, political parties, political policies, elections, government actions, or politically divisive social issues. BMB is a sports bracket platform - keep it about sports and brackets.

2.5 SEXUALLY EXPLICIT CONTENT
You shall not share, describe, or reference sexually explicit, suggestive, or pornographic content of any kind.

2.6 ILLEGAL ACTIVITY
You shall not promote, encourage, facilitate, or discuss illegal activities including but not limited to: illegal gambling, drug use, fraud, or any other criminal conduct.

2.7 SPAM & DISRUPTION
You shall not engage in spamming, flooding, excessive caps, repeated messages, or any behavior intended to disrupt the chat room experience for other users.

3. AUTOMATED CONTENT MONITORING

3.1 All messages sent in BMB chat rooms are automatically screened by our content moderation system BEFORE they are visible to other users.

3.2 Messages that violate these terms will be BLOCKED and will NOT be sent. You will receive a notification explaining why your message was blocked.

3.3 Flagged messages may be sent but will be reviewed by our moderation team for potential violations.

3.4 Attempting to bypass the content moderation system (e.g., using special characters, letter substitution, coded language, or other obfuscation techniques) is itself a violation and will be treated as such.

4. ENFORCEMENT & PENALTIES

Back My Bracket reserves the right to take any of the following actions at its sole discretion:

4.1 ESCALATING ENFORCEMENT:
  - First violation: Warning notification
  - Second violation: 24-hour chat suspension
  - Third violation: 7-day chat and account suspension
  - Fourth violation: 30-day chat and account suspension
  - Fifth violation or severe offense: PERMANENT BAN

4.2 BMB RESERVES THE RIGHT TO:
  - Delete any message at any time for any reason
  - Suspend your chat access temporarily or permanently
  - Suspend your BMB account temporarily or permanently
  - Permanently ban your account from the BMB platform
  - Block your IP address from accessing BMB services
  - Block your device from accessing BMB services
  - Forfeit any credits, rewards, or tournament entries upon account suspension or ban
  - Report illegal activity to appropriate law enforcement authorities
  - Pursue any and all legal remedies available

4.3 SEVERE VIOLATIONS (including but not limited to threats of violence, doxxing, illegal activity, or severe hate speech) may result in IMMEDIATE PERMANENT BAN without prior warnings.

4.4 Enforcement actions are final and at BMB's sole discretion. Appeals may be submitted to appeals@backmybracket.com within 14 days.

5. YOUR RESPONSIBILITIES

5.1 You are solely responsible for all content you post in BMB chat rooms.

5.2 You acknowledge that BMB monitors all chat content and consent to such monitoring.

5.3 You agree to report any violations you observe using the in-app reporting feature (long-press any message to report).

5.4 You understand that your participation in BMB chat rooms is a privilege, not a right, and can be revoked at any time.

6. DATA & PRIVACY

6.1 Chat messages may be stored, reviewed, and used for moderation, safety, and platform improvement purposes.

6.2 BMB may share chat data with law enforcement if required by law or if there is a credible threat to safety.

6.3 Your chat activity is subject to the BMB Privacy Policy.

7. ACCEPTANCE

BY CHECKING THE BOX BELOW AND CLICKING "I AGREE," YOU ACKNOWLEDGE THAT:
  - You have read and understand this Chat Room Agreement in its entirety
  - You agree to comply with all terms and conditions stated herein
  - You understand that violations may result in suspension, permanent ban, IP blocking, and/or legal action
  - You consent to automated content monitoring of all your chat messages
  - You accept BMB's right to delete, suspend, or ban at its sole discretion
''';
}
