class HostRanking {
  final String hostId;
  final String hostName;
  final int globalRank;
  final String tier;
  final int rankingPoints;
  final int totalTournamentsHosted;
  final double averageRating;
  final int totalReviews;
  final int positiveReviews;
  final int totalParticipants;
  final double totalPrizePoolsAwarded;
  final List<String> achievements;

  const HostRanking({
    required this.hostId,
    required this.hostName,
    required this.globalRank,
    required this.tier,
    required this.rankingPoints,
    required this.totalTournamentsHosted,
    required this.averageRating,
    required this.totalReviews,
    required this.positiveReviews,
    required this.totalParticipants,
    required this.totalPrizePoolsAwarded,
    this.achievements = const [],
  });

  double get positiveReviewRate {
    if (totalReviews == 0) return 0.0;
    return positiveReviews / totalReviews;
  }
}
