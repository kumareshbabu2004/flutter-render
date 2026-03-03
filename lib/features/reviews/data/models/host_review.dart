/// A single player review for a tournament host.
///
/// After a tournament is marked "done", each player who participated
/// can leave ONE review per tournament (deduplicated by
/// `playerId + tournamentId`).
class HostReview {
  final String id;
  final String hostId;
  final String hostName;
  final String playerId;
  final String playerName;
  final String? playerState; // e.g. "TX"
  final String tournamentId;
  final String tournamentName;
  final int stars; // 1-5
  final String? comment; // optional written feedback
  final DateTime createdAt;

  const HostReview({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.playerId,
    required this.playerName,
    this.playerState,
    required this.tournamentId,
    required this.tournamentName,
    required this.stars,
    this.comment,
    required this.createdAt,
  });

  /// Copy with overrides.
  HostReview copyWith({
    int? stars,
    String? comment,
  }) {
    return HostReview(
      id: id,
      hostId: hostId,
      hostName: hostName,
      playerId: playerId,
      playerName: playerName,
      playerState: playerState,
      tournamentId: tournamentId,
      tournamentName: tournamentName,
      stars: stars ?? this.stars,
      comment: comment ?? this.comment,
      createdAt: createdAt,
    );
  }

  /// Relative time string, e.g. "2d ago".
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}y ago';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

/// Aggregate host rating summary used for ranking & display.
class HostRatingSummary {
  final String hostId;
  final String hostName;
  final double averageRating; // simple average of all stars
  final int totalReviews;
  final int totalHosted;
  final bool isTopHost; // computed
  final Map<int, int> starDistribution; // {5: 80, 4: 30, 3: 10, 2: 3, 1: 1}

  const HostRatingSummary({
    required this.hostId,
    required this.hostName,
    required this.averageRating,
    required this.totalReviews,
    required this.totalHosted,
    required this.isTopHost,
    this.starDistribution = const {},
  });

  /// A composite score used for ranking hosts.
  /// Weighted: 70% average rating (normalised to 100) + 30% tournament volume.
  double get rankScore {
    final ratingScore = (averageRating / 5.0) * 70;
    // Cap volume contribution at 200 hosted to prevent runaway numbers.
    final volumeScore = (totalHosted.clamp(0, 200) / 200.0) * 30;
    return ratingScore + volumeScore;
  }
}
