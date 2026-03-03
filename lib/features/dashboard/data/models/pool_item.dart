class PoolItem {
  final String id;
  final String name;
  final String sport;
  final String status;
  final int players;
  final double prizePool;
  final int? userRank;
  final DateTime? endDate;
  final String? imageUrl;

  const PoolItem({
    required this.id,
    required this.name,
    required this.sport,
    required this.status,
    required this.players,
    required this.prizePool,
    this.userRank,
    this.endDate,
    this.imageUrl,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isUpcoming => status == 'upcoming';
}
