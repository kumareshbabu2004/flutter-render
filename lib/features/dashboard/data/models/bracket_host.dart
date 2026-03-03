class BracketHost {
  final String id;
  final String name;
  final String? profileImageUrl;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool isTopHost;
  final String? location;
  final int totalHosted;

  const BracketHost({
    required this.id,
    required this.name,
    this.profileImageUrl,
    required this.rating,
    required this.reviewCount,
    this.isVerified = false,
    this.isTopHost = false,
    this.location,
    this.totalHosted = 0,
  });
}
