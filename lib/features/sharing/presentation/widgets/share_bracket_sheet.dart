import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/sharing/data/services/share_bracket_service.dart';

/// A reusable bottom sheet that lets users share a bracket via
/// SMS, Twitter/X, Instagram, TikTok, or copy link.
class ShareBracketSheet extends StatelessWidget {
  final CreatedBracket bracket;
  final String userName;

  const ShareBracketSheet({
    super.key,
    required this.bracket,
    required this.userName,
  });

  /// Convenience: call this static method to show the sheet.
  static void show(BuildContext context, {
    required CreatedBracket bracket,
    required String userName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ShareBracketSheet(bracket: bracket, userName: userName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shareText = ShareBracketService.shareText(
      bracket: bracket,
      userName: userName,
    );
    final shareLink = ShareBracketService.bracketLink(bracket);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BmbColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [BmbColors.blue, const Color(0xFF5B6EFF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.share, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Your Bracket',
                          style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay',
                          ),
                        ),
                        Text(
                          bracket.name,
                          style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Preview of the share message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: BmbColors.borderColor,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote, color: BmbColors.blue, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Your share message:',
                          style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 11,
                            fontWeight: BmbFontWeights.semiBold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      shareText,
                      style: TextStyle(
                        color: BmbColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Share platform buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SharePlatformButton(
                    icon: Icons.sms,
                    label: 'Text',
                    color: BmbColors.successGreen,
                    onTap: () {
                      Navigator.pop(context);
                      ShareBracketService.shareViaSms(
                        bracket: bracket, userName: userName, context: context,
                      );
                    },
                  ),
                  _SharePlatformButton(
                    icon: Icons.alternate_email,
                    label: 'X / Twitter',
                    color: BmbColors.textPrimary,
                    onTap: () {
                      Navigator.pop(context);
                      ShareBracketService.shareViaTwitter(
                        bracket: bracket, userName: userName, context: context,
                      );
                    },
                  ),
                  _SharePlatformButton(
                    icon: Icons.camera_alt,
                    label: 'Instagram',
                    color: const Color(0xFFE1306C),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: shareText));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Message copied! Paste in Instagram.'),
                        backgroundColor: BmbColors.midNavy,
                        behavior: SnackBarBehavior.floating,
                      ));
                      ShareBracketService.shareViaInstagram(
                        bracket: bracket, userName: userName, context: context,
                      );
                    },
                  ),
                  _SharePlatformButton(
                    icon: Icons.music_note,
                    label: 'TikTok',
                    color: const Color(0xFF00F2EA),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: shareText));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Message copied! Paste in TikTok.'),
                        backgroundColor: BmbColors.midNavy,
                        behavior: SnackBarBehavior.floating,
                      ));
                      ShareBracketService.shareViaTikTok(
                        bracket: bracket, userName: userName, context: context,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Copy link button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareLink));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text('Bracket link copied!'),
                      ]),
                      backgroundColor: BmbColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                    ));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.link),
                  label: Text(
                    'Copy Bracket Link',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: BmbFontWeights.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BmbColors.blue,
                    side: BorderSide(color: BmbColors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Copy full message button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        const Text('Full message copied!'),
                      ]),
                      backgroundColor: BmbColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                    ));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(
                    'Copy Full Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: BmbFontWeights.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

class _SharePlatformButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SharePlatformButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: BmbColors.textSecondary,
              fontSize: 10,
              fontWeight: BmbFontWeights.medium,
            ),
          ),
        ],
      ),
    );
  }
}
