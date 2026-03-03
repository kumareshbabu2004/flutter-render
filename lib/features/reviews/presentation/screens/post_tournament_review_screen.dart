import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/reviews/data/models/host_review.dart';
import 'package:bmb_mobile/features/reviews/data/services/host_review_service.dart';

/// Full-screen review form shown after a completed tournament.
/// The player rates the host 1-5 stars and optionally leaves a comment.
class PostTournamentReviewScreen extends StatefulWidget {
  final String hostId;
  final String hostName;
  final String tournamentId;
  final String tournamentName;
  final String playerId;
  final String playerName;
  final String? playerState;

  const PostTournamentReviewScreen({
    super.key,
    required this.hostId,
    required this.hostName,
    required this.tournamentId,
    required this.tournamentName,
    required this.playerId,
    required this.playerName,
    this.playerState,
  });

  @override
  State<PostTournamentReviewScreen> createState() =>
      _PostTournamentReviewScreenState();
}

class _PostTournamentReviewScreenState
    extends State<PostTournamentReviewScreen> with SingleTickerProviderStateMixin {
  int _selectedStars = 0;
  final _commentController = TextEditingController();
  bool _submitted = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a star rating'),
          backgroundColor: BmbColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final review = HostReview(
      id: 'rev_${widget.hostId}_${DateTime.now().millisecondsSinceEpoch}',
      hostId: widget.hostId,
      hostName: widget.hostName,
      playerId: widget.playerId,
      playerName: widget.playerName,
      playerState: widget.playerState,
      tournamentId: widget.tournamentId,
      tournamentName: widget.tournamentName,
      stars: _selectedStars,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    final success = await HostReviewService().submitReview(review);

    if (success) {
      setState(() => _submitted = true);
      _pulseController.forward();
    } else {
      if (!mounted) return; // BUG #12 FIX
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You already reviewed this tournament'),
          backgroundColor: BmbColors.gold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: _submitted ? _buildThankYou() : _buildReviewForm(),
        ),
      ),
    );
  }

  // ─── THANK YOU SCREEN ──────────────────────────────────────────────
  Widget _buildThankYou() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(
                  parent: _pulseController, curve: Curves.elasticOut),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [BmbColors.gold, BmbColors.goldLight],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: BmbColors.gold.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Thank You!',
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 28,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your $_selectedStars-star review for ${widget.hostName} has been submitted.',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps the BMB community find the best hosts.',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Back to Brackets',
                    style: TextStyle(
                        fontSize: 16, fontWeight: BmbFontWeights.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── REVIEW FORM ───────────────────────────────────────────────────
  Widget _buildReviewForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top bar
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BmbColors.borderColor),
                  ),
                  child: const Icon(Icons.close,
                      color: BmbColors.textSecondary, size: 20),
                ),
              ),
              const Spacer(),
              Text(
                'Rate Your Host',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
              const Spacer(),
              const SizedBox(width: 40), // balance
            ],
          ),
          const SizedBox(height: 32),

          // Host avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                BmbColors.gold.withValues(alpha: 0.3),
                BmbColors.gold.withValues(alpha: 0.1),
              ]),
              border: Border.all(color: BmbColors.gold, width: 3),
            ),
            child: const Icon(Icons.person, color: BmbColors.gold, size: 40),
          ),
          const SizedBox(height: 14),
          Text(
            widget.hostName,
            style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 22,
              fontWeight: BmbFontWeights.bold,
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.tournamentName,
              style: TextStyle(color: BmbColors.blue, fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),

          // "How was your experience?"
          Text(
            'How was your experience?',
            style: TextStyle(
              color: BmbColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),

          // Star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starNum = i + 1;
              final isSelected = starNum <= _selectedStars;
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = starNum),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    isSelected ? Icons.star : Icons.star_border,
                    color: isSelected
                        ? BmbColors.gold
                        : BmbColors.textTertiary,
                    size: isSelected ? 48 : 42,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Label under stars
          Text(
            _starLabel,
            style: TextStyle(
              color: _selectedStars > 0 ? BmbColors.gold : BmbColors.textTertiary,
              fontSize: 14,
              fontWeight: BmbFontWeights.semiBold,
            ),
          ),
          const SizedBox(height: 28),

          // Optional comment
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Leave a comment (optional)',
              style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 13,
                fontWeight: BmbFontWeights.medium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: BmbColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BmbColors.borderColor),
            ),
            child: TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 300,
              style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    'Tell others about your experience with this host...',
                hintStyle:
                    TextStyle(color: BmbColors.textTertiary, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterStyle:
                    TextStyle(color: BmbColors.textTertiary, fontSize: 10),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedStars > 0 ? _submitReview : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _selectedStars > 0 ? BmbColors.gold : BmbColors.cardDark,
                foregroundColor:
                    _selectedStars > 0 ? Colors.black : BmbColors.textTertiary,
                disabledBackgroundColor: BmbColors.cardDark,
                disabledForegroundColor: BmbColors.textTertiary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: _selectedStars > 0 ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star,
                      size: 20,
                      color: _selectedStars > 0
                          ? Colors.black
                          : BmbColors.textTertiary),
                  const SizedBox(width: 8),
                  Text(
                    'Submit Review',
                    style: TextStyle(
                        fontSize: 16, fontWeight: BmbFontWeights.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Skip
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Skip for now',
              style: TextStyle(
                  color: BmbColors.textTertiary,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: BmbColors.textTertiary),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String get _starLabel {
    switch (_selectedStars) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Great';
      case 5:
        return 'Excellent!';
      default:
        return 'Tap a star to rate';
    }
  }
}
