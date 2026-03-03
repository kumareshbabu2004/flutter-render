/// A knowledge pack is a curated list of items for a specific topic.
/// The Auto-Builder uses these to populate brackets automatically when
/// a host says something like "Host me a best 90s rock band bracket."
class KnowledgePack {
  final String id;
  final String name;
  final String description;
  final String category; // 'sports', 'music', 'food', 'entertainment', 'culture', 'custom'
  final String bracketType; // 'standard', 'voting', 'pickem'
  final int defaultSize; // 8, 16, 32, 64
  final List<String> items;
  final List<String> keywords; // voice-command matching keywords
  final String? eventDateHint; // e.g. 'march', 'september-february', 'november'
  final bool isSeasonal;

  const KnowledgePack({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.bracketType,
    required this.defaultSize,
    required this.items,
    required this.keywords,
    this.eventDateHint,
    this.isSeasonal = false,
  });

  /// Get the items capped to a specific bracket size.
  List<String> itemsForSize(int size) {
    if (items.length >= size) return items.sublist(0, size);
    // Pad with "TBD" if we have fewer items than the bracket needs
    return [
      ...items,
      ...List.generate(size - items.length, (i) => 'TBD ${items.length + i + 1}'),
    ];
  }
}
