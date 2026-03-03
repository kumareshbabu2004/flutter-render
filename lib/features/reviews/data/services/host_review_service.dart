import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/features/reviews/data/models/host_review.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

/// Service that manages host reviews, rating calculation, and host ranking.
///
/// Rating formula: **simple average** of all star ratings.
/// Top Host criteria:
///   1. Average rating >= 4.5 stars
///   2. At least 25 reviews
///   3. At least 20 tournaments hosted
///
/// Top Hosts get **front placement** for their tournaments
/// and do NOT need to pay for the BMB+ VIP tag.

class HostReviewService {
  static final HostReviewService _instance = HostReviewService._internal();
  factory HostReviewService() => _instance;
  HostReviewService._internal();

  // ─── THRESHOLDS ────────────────────────────────────────────────────
  static const double topHostMinRating = 4.5;
  static const int topHostMinReviews = 25;
  static const int topHostMinHosted = 20;

  // ─── FIRESTORE-BACKED STORE ──────────────────────────────────────
  final List<HostReview> _reviews = [];
  bool _loaded = false;
  final _firestore = RestFirestoreService.instance;

  /// Load all reviews from Firestore into memory cache.
  Future<void> loadFromFirestore() async {
    if (_loaded) return;
    try {
      final docs = await _firestore.getCollection('host_reviews');
      _reviews.clear();
      for (final d in docs) {
        _reviews.add(HostReview(
          id: d['doc_id'] as String? ?? '',
          hostId: d['hostId'] as String? ?? '',
          hostName: d['hostName'] as String? ?? '',
          playerId: d['playerId'] as String? ?? '',
          playerName: d['playerName'] as String? ?? '',
          playerState: d['playerState'] as String? ?? '',
          tournamentId: d['tournamentId'] as String? ?? '',
          tournamentName: d['tournamentName'] as String? ?? '',
          stars: (d['stars'] is int) ? d['stars'] as int : int.tryParse(d['stars']?.toString() ?? '5') ?? 5,
          comment: d['comment'] as String?,
          createdAt: DateTime.tryParse(d['createdAt'] as String? ?? '') ?? DateTime.now(),
        ));
      }
      _loaded = true;
      if (kDebugMode) debugPrint('HostReviews: Loaded ${_reviews.length} reviews from Firestore');
    } catch (e) {
      if (kDebugMode) debugPrint('HostReviews: Firestore load error: $e');
      // Fall back to seeded demo reviews
      if (_reviews.isEmpty) seedDemoReviews();
    }
  }

  /// Seed demo reviews for mock hosts.
  void seedDemoReviews() {
    if (_reviews.isNotEmpty) return;
    final now = DateTime.now();

    // NateDoubleDown – 151 reviews, avg ~4.8
    _addBulkReviews('host_nate', 'NateDoubleDown', 151, 4.8, now);

    // SlickRick – 42 reviews, avg ~4.6
    _addBulkReviews('host_slick', 'SlickRick', 42, 4.6, now);

    // CourtneyWins – 39 reviews, avg ~4.7
    _addBulkReviews('host_courtney', 'CourtneyWins', 39, 4.7, now);

    // Back My Bracket – 320 reviews, avg 5.0
    _addBulkReviews('host_bmb', 'Back My Bracket', 320, 5.0, now);
  }

  void _addBulkReviews(
      String hostId, String hostName, int count, double targetAvg, DateTime now) {
    final playerNames = [
      'JamSession81', 'BracketBoss', 'HoopsKing', 'GoldenPick',
      'ThunderDunk', 'SlamJam42', 'FastBreak', 'PickMaster',
      'WinStreak', 'ChalkZone', 'BuzzerBeater', 'FullCourt',
      'DarkHorse', 'LongShot', 'ClutchKing', 'TripleThreat',
    ];
    final states = ['TX', 'CA', 'NY', 'IL', 'FL', 'OH', 'PA', 'MI'];
    final comments = [
      'Great host! Really organized.',
      'Fun tournament, well-run.',
      'Would join again for sure!',
      'Smooth experience from start to finish.',
      'Best bracket host on BMB!',
      'Good communication throughout.',
      'Fair play, no issues.',
      'Awesome prizes and great vibes.',
      null, null, null, // some reviews without comments
    ];

    for (int i = 0; i < count; i++) {
      // Generate stars that converge to targetAvg
      int stars;
      if (targetAvg >= 4.9) {
        stars = 5;
      } else {
        final variance = (i % 5 == 0) ? -1 : (i % 7 == 0) ? -2 : 0;
        stars = (targetAvg.round() + variance).clamp(1, 5);
      }

      _reviews.add(HostReview(
        id: 'rev_${hostId}_$i',
        hostId: hostId,
        hostName: hostName,
        playerId: 'player_$i',
        playerName: playerNames[i % playerNames.length],
        playerState: states[i % states.length],
        tournamentId: 'tourney_${hostId}_$i',
        tournamentName: 'Tournament #${i + 1}',
        stars: stars,
        comment: comments[i % comments.length],
        createdAt: now.subtract(Duration(days: i, hours: i * 3)),
      ));
    }
  }

  // ─── SUBMIT ────────────────────────────────────────────────────────

  /// Submit a review. Returns `true` if successful, `false` if duplicate.
  Future<bool> submitReview(HostReview review) async {
    // Deduplicate: one review per player per tournament.
    final exists = _reviews.any((r) =>
        r.playerId == review.playerId &&
        r.tournamentId == review.tournamentId);
    if (exists) return false;

    _reviews.add(review);

    // Persist to Firestore
    try {
      await _firestore.addDocument('host_reviews', {
        'hostId': review.hostId,
        'hostName': review.hostName,
        'playerId': review.playerId,
        'playerName': review.playerName,
        'playerState': review.playerState,
        'tournamentId': review.tournamentId,
        'tournamentName': review.tournamentName,
        'stars': review.stars,
        'comment': review.comment ?? '',
        'createdAt': review.createdAt.toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('HostReviews: Firestore write error: $e');
    }
    return true;
  }

  /// Check if player already reviewed this tournament's host.
  bool hasReviewed(String playerId, String tournamentId) {
    return _reviews.any((r) =>
        r.playerId == playerId && r.tournamentId == tournamentId);
  }

  // ─── QUERIES ───────────────────────────────────────────────────────

  /// All reviews for a specific host, newest first.
  List<HostReview> getHostReviews(String hostId) {
    return _reviews
        .where((r) => r.hostId == hostId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Average star rating for a host (simple average).
  double getAverageRating(String hostId) {
    final hostReviews = _reviews.where((r) => r.hostId == hostId).toList();
    if (hostReviews.isEmpty) return 0.0;
    final total = hostReviews.fold<int>(0, (sum, r) => sum + r.stars);
    return total / hostReviews.length;
  }

  /// Total review count for a host.
  int getReviewCount(String hostId) {
    return _reviews.where((r) => r.hostId == hostId).length;
  }

  /// Star distribution map {5: count, 4: count, ...}.
  Map<int, int> getStarDistribution(String hostId) {
    final dist = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews.where((r) => r.hostId == hostId)) {
      dist[r.stars] = (dist[r.stars] ?? 0) + 1;
    }
    return dist;
  }

  /// Build a full rating summary for a host.
  HostRatingSummary getRatingSummary(String hostId, String hostName, int totalHosted) {
    final avg = getAverageRating(hostId);
    final count = getReviewCount(hostId);
    return HostRatingSummary(
      hostId: hostId,
      hostName: hostName,
      averageRating: double.parse(avg.toStringAsFixed(1)),
      totalReviews: count,
      totalHosted: totalHosted,
      isTopHost: isTopHost(hostId, totalHosted),
      starDistribution: getStarDistribution(hostId),
    );
  }

  // ─── TOP HOST LOGIC ────────────────────────────────────────────────

  /// Determine if a host qualifies for Top Host status.
  /// Criteria: rating >= 4.5, reviews >= 25, hosted >= 20.
  bool isTopHost(String hostId, int totalHosted) {
    final avg = getAverageRating(hostId);
    final count = getReviewCount(hostId);
    return avg >= topHostMinRating &&
        count >= topHostMinReviews &&
        totalHosted >= topHostMinHosted;
  }

  /// Top hosts get front placement without paying for the VIP tag.
  bool getsFrontPlacement(String hostId, int totalHosted) {
    return isTopHost(hostId, totalHosted);
  }

  /// Top hosts do NOT need the VIP tag for priority visibility.
  bool vipTagWaived(String hostId, int totalHosted) {
    return isTopHost(hostId, totalHosted);
  }

  /// Rank all hosts by composite score (rating + volume).
  /// Returns sorted list, highest rank first.
  List<HostRatingSummary> rankHosts(List<({String id, String name, int hosted})> hosts) {
    final summaries = hosts
        .map((h) => getRatingSummary(h.id, h.name, h.hosted))
        .toList();
    summaries.sort((a, b) => b.rankScore.compareTo(a.rankScore));
    return summaries;
  }

  /// Reviews left by a specific player.
  List<HostReview> getPlayerReviews(String playerId) {
    return _reviews
        .where((r) => r.playerId == playerId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
