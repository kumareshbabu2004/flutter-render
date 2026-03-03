import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/reviews/data/models/host_review.dart';
import 'package:bmb_mobile/features/reviews/data/services/host_review_service.dart';

/// Displays all reviews for a specific host with rating summary,
/// star distribution bar, and scrollable review list.
class HostReviewsScreen extends StatefulWidget {
  final String hostId;
  final String hostName;
  final int totalHosted;

  const HostReviewsScreen({
    super.key,
    required this.hostId,
    required this.hostName,
    required this.totalHosted,
  });

  @override
  State<HostReviewsScreen> createState() => _HostReviewsScreenState();
}

class _HostReviewsScreenState extends State<HostReviewsScreen> {
  final _service = HostReviewService();
  late HostRatingSummary _summary;
  late List<HostReview> _reviews;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _summary = _service.getRatingSummary(
        widget.hostId, widget.hostName, widget.totalHosted);
    _reviews = _service.getHostReviews(widget.hostId);
  }

  List<HostReview> get _filteredReviews {
    if (_filter == 'All') return _reviews;
    final stars = int.tryParse(_filter.replaceAll(' Stars', ''));
    if (stars == null) return _reviews;
    return _reviews.where((r) => r.stars == stars).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildRatingSummaryCard()),
                    SliverToBoxAdapter(child: _buildStarDistribution()),
                    SliverToBoxAdapter(child: _buildTopHostBanner()),
                    SliverToBoxAdapter(child: _buildFilterChips()),
                    SliverToBoxAdapter(child: _buildReviewCount()),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildReviewTile(_filteredReviews[index]),
                        childCount: _filteredReviews.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── APP BAR ───────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
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
              child: const Icon(Icons.arrow_back_ios_new,
                  color: BmbColors.textSecondary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${widget.hostName} Reviews',
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 18,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── RATING SUMMARY ───────────────────────────────────────────────
  Widget _buildRatingSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          // Big average number
          Column(
            children: [
              Text(
                _summary.averageRating.toStringAsFixed(1),
                style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 48,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
              // Star row
              Row(
                children: List.generate(5, (i) {
                  if (i < _summary.averageRating.floor()) {
                    return const Icon(Icons.star,
                        color: BmbColors.gold, size: 18);
                  } else if (i < _summary.averageRating) {
                    return const Icon(Icons.star_half,
                        color: BmbColors.gold, size: 18);
                  }
                  return Icon(Icons.star_border,
                      color: BmbColors.gold.withValues(alpha: 0.3), size: 18);
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${_summary.totalReviews} reviews',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Host stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow(Icons.emoji_events, '${_summary.totalHosted}',
                    'Tournaments Hosted', BmbColors.gold),
                const SizedBox(height: 8),
                _buildStatRow(Icons.rate_review, '${_summary.totalReviews}',
                    'Player Reviews', BmbColors.blue),
                const SizedBox(height: 8),
                _buildStatRow(
                    Icons.trending_up,
                    _summary.rankScore.toStringAsFixed(1),
                    'Rank Score',
                    BmbColors.successGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
      IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: BmbFontWeights.bold)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ─── STAR DISTRIBUTION ─────────────────────────────────────────────
  Widget _buildStarDistribution() {
    final dist = _summary.starDistribution;
    final maxCount = dist.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rating Breakdown',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 14,
                  fontWeight: BmbFontWeights.bold)),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = dist[star] ?? 0;
            final fraction = maxCount > 0 ? count / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Text('$star',
                        style: TextStyle(
                            color: BmbColors.textSecondary,
                            fontSize: 12,
                            fontWeight: BmbFontWeights.bold)),
                  ),
                  const Icon(Icons.star, color: BmbColors.gold, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 8,
                        backgroundColor: BmbColors.borderColor,
                        valueColor:
                            AlwaysStoppedAnimation(BmbColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text('$count',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 11),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── TOP HOST BANNER ───────────────────────────────────────────────
  Widget _buildTopHostBanner() {
    if (!_summary.isTopHost) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.2),
          BmbColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.military_tech,
                color: BmbColors.gold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Top Host',
                        style: TextStyle(
                            color: BmbColors.gold,
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BmbColors.successGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('VIP Waived',
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 9,
                              fontWeight: BmbFontWeights.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Earns front placement for all tournaments without VIP tag.',
                  style:
                      TextStyle(color: BmbColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── FILTER CHIPS ──────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = ['All', '5 Stars', '4 Stars', '3 Stars', '2 Stars', '1 Stars'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final selected = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? BmbColors.blue : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        selected ? BmbColors.blue : BmbColors.borderColor),
              ),
              child: Text(f,
                  style: TextStyle(
                      color: selected
                          ? Colors.white
                          : BmbColors.textSecondary,
                      fontSize: 12,
                      fontWeight: BmbFontWeights.medium)),
            ),
          );
        },
      ),
    );
  }

  // ─── REVIEW COUNT ──────────────────────────────────────────────────
  Widget _buildReviewCount() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(
            '${_filteredReviews.length} Reviews',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 15,
                fontWeight: BmbFontWeights.bold),
          ),
          const Spacer(),
          Icon(Icons.sort, color: BmbColors.textTertiary, size: 18),
          const SizedBox(width: 4),
          Text('Newest first',
              style:
                  TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── REVIEW TILE ───────────────────────────────────────────────────
  Widget _buildReviewTile(HostReview review) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Player avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.playerName.isNotEmpty
                        ? review.playerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(review.playerName,
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 13,
                                fontWeight: BmbFontWeights.semiBold)),
                        if (review.playerState != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: BmbColors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(review.playerState!,
                                style: TextStyle(
                                    color: BmbColors.blue, fontSize: 9)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(review.tournamentName,
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 10)),
                  ],
                ),
              ),
              // Stars & time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < review.stars ? Icons.star : Icons.star_border,
                        color: i < review.stars
                            ? BmbColors.gold
                            : BmbColors.gold.withValues(alpha: 0.3),
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(review.timeAgo,
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 10)),
                ],
              ),
            ],
          ),
          if (review.comment != null) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
