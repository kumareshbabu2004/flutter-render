import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/community/data/services/post_to_bmb_service.dart';

/// Bottom sheet that lets users review and post their bracket picks to the
/// BMB Community thread as a formatted picks card.
class PostToBmbSheet extends StatefulWidget {
  final CreatedBracket bracket;
  final Map<String, String> picks;
  final String userName;
  final int? tieBreakerPrediction;

  const PostToBmbSheet({
    super.key,
    required this.bracket,
    required this.picks,
    required this.userName,
    this.tieBreakerPrediction,
  });

  /// Convenience method to show the sheet.
  static Future<bool?> show(
    BuildContext context, {
    required CreatedBracket bracket,
    required Map<String, String> picks,
    required String userName,
    int? tieBreakerPrediction,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PostToBmbSheet(
        bracket: bracket,
        picks: picks,
        userName: userName,
        tieBreakerPrediction: tieBreakerPrediction,
      ),
    );
  }

  @override
  State<PostToBmbSheet> createState() => _PostToBmbSheetState();
}

class _PostToBmbSheetState extends State<PostToBmbSheet> {
  bool _isPosting = false;
  bool _posted = false;

  @override
  Widget build(BuildContext context) {
    final summary = PostToBmbService.buildPicksSummary(
      bracket: widget.bracket,
      picks: widget.picks,
      userName: widget.userName,
      tieBreakerPrediction: widget.tieBreakerPrediction,
    );
    final champPick = widget.picks['r${widget.bracket.totalRounds - 1}_g0'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: BmbColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [BmbColors.blue, const Color(0xFF5B6EFF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.forum, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post to BMB Community',
                        style: TextStyle(
                          color: BmbColors.textPrimary, fontSize: 18,
                          fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
                        ),
                      ),
                      Text(
                        'Share your picks with the BMB fam',
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // Picks card preview
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BmbColors.borderColor, width: 0.5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bracket info header
                      Row(children: [
                        Icon(Icons.account_tree, color: BmbColors.blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.bracket.name,
                            style: TextStyle(
                              color: BmbColors.textPrimary, fontSize: 14,
                              fontWeight: BmbFontWeights.bold,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.bracket.bracketTypeLabel} | ${widget.bracket.sport} | ${widget.picks.length} picks',
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
                      ),
                      if (champPick != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              BmbColors.gold.withValues(alpha: 0.15),
                              BmbColors.gold.withValues(alpha: 0.05),
                            ]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            Icon(Icons.emoji_events, color: BmbColors.gold, size: 16),
                            const SizedBox(width: 6),
                            Text('Champion Pick: ', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                            Expanded(
                              child: Text(
                                champPick,
                                style: TextStyle(
                                  color: BmbColors.gold, fontSize: 14,
                                  fontWeight: BmbFontWeights.bold,
                                ),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                        ),
                      ],
                      if (widget.tieBreakerPrediction != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.sports_score, color: BmbColors.blue, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Tie-Breaker: ${widget.tieBreakerPrediction} pts',
                            style: TextStyle(color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.semiBold),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 12),
                      // Summary text
                      Text(
                        summary,
                        style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, color: BmbColors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will post a clickable picks card to the BMB Community chat. Other players can view your full bracket picks.',
                      style: TextStyle(color: BmbColors.blue, fontSize: 11),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Post button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _posted ? null : _handlePost,
                  icon: _isPosting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_posted ? Icons.check_circle : Icons.send, size: 20),
                  label: Text(
                    _posted ? 'Posted to BMB Community!' : 'Post to BMB Community',
                    style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _posted ? BmbColors.successGreen : BmbColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePost() async {
    setState(() => _isPosting = true);

    // Create the community post (now persists to CommunityPostStore)
    await PostToBmbService.createCommunityPost(
      bracket: widget.bracket,
      picks: widget.picks,
      userId: 'user_0',
      userName: widget.userName,
      tieBreakerPrediction: widget.tieBreakerPrediction,
    );

    // Brief delay for feel
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() {
      _isPosting = false;
      _posted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        const Text('Your picks are now live in the BMB Community!'),
      ]),
      backgroundColor: BmbColors.successGreen,
      behavior: SnackBarBehavior.floating,
    ));

    // Auto-dismiss after a beat
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pop(context, true);
  }
}
