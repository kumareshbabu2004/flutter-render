/// Recurrence frequency for auto-hosted templates.
enum RecurrenceType {
  oneTime,       // "One-time" — manual launch
  everyMonth,    // "1st of every month"
  everyWeek,     // "Every Sunday during NFL season"
  yearly,        // "Every March"
  custom,        // Custom cron-like rule
}

/// A host's saved bracket template with optional recurrence.
class SavedTemplate {
  final String id;
  final String hostId;
  final String name;
  final String description;

  // Template source
  final String? sourceTemplateId;      // BracketTemplate.id or VotingTemplate.id
  final String? knowledgePackId;       // KnowledgePack.id for auto-fill
  final String bracketType;            // 'standard', 'voting', 'pickem'
  final String sport;
  final int teamCount;
  final List<String> defaultTeams;

  // Entry & prize settings
  final bool isFreeEntry;
  final int entryFee;                  // 0 for free / voting brackets
  final String prizeType;              // 'none', 'gift_card', 'merch', 'custom', 'charity'
  final String? prizeDescription;
  final String? defaultPrize;          // Default prize to use (e.g. "$25 Gift Card")

  // Hosting settings
  final int minPlayers;
  final int maxPlayers;
  final bool autoHost;
  final bool isPublic;
  final bool autoShare;                // Auto-share when bracket reaches upcoming

  // Charity settings
  final String? charityName;
  final String? charityGoal;

  // ═══ RECURRENCE RULES ═══
  final RecurrenceType recurrenceType;
  final String recurrenceLabel;        // Human-readable: "Every March", "1st of every month"
  final int? recurrenceMonth;          // 1-12 for yearly (e.g. 3 = March)
  final int? recurrenceDayOfMonth;     // 1-31 for monthly
  final int? recurrenceDayOfWeek;      // 1=Monday .. 7=Sunday for weekly
  final String? seasonStart;           // "september" for NFL season
  final String? seasonEnd;             // "february"
  final bool isPaused;                 // Host can pause auto-scheduling

  // Timestamps
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int timesUsed;
  final bool isFavorite;

  // Approval setting
  final bool requiresApproval;         // If true, host must approve before go-live

  const SavedTemplate({
    required this.id,
    required this.hostId,
    required this.name,
    this.description = '',
    this.sourceTemplateId,
    this.knowledgePackId,
    required this.bracketType,
    required this.sport,
    required this.teamCount,
    this.defaultTeams = const [],
    this.isFreeEntry = true,
    this.entryFee = 0,
    this.prizeType = 'none',
    this.prizeDescription,
    this.defaultPrize,
    this.minPlayers = 4,
    this.maxPlayers = 128,
    this.autoHost = true,
    this.isPublic = true,
    this.autoShare = true,
    this.charityName,
    this.charityGoal,
    this.recurrenceType = RecurrenceType.oneTime,
    this.recurrenceLabel = 'One-time',
    this.recurrenceMonth,
    this.recurrenceDayOfMonth,
    this.recurrenceDayOfWeek,
    this.seasonStart,
    this.seasonEnd,
    this.isPaused = false,
    required this.createdAt,
    this.lastUsedAt,
    this.timesUsed = 0,
    this.isFavorite = false,
    this.requiresApproval = true,
  });

  /// Whether this template has a recurrence schedule.
  bool get isRecurring => recurrenceType != RecurrenceType.oneTime;

  /// Compute the next fire date based on recurrence rules.
  DateTime? get nextFireDate {
    if (!isRecurring || isPaused) return null;
    final now = DateTime.now();

    switch (recurrenceType) {
      case RecurrenceType.yearly:
        if (recurrenceMonth == null) return null;
        var next = DateTime(now.year, recurrenceMonth!, 1);
        if (next.isBefore(now)) {
          next = DateTime(now.year + 1, recurrenceMonth!, 1);
        }
        return next;

      case RecurrenceType.everyMonth:
        final day = recurrenceDayOfMonth ?? 1;
        var next = DateTime(now.year, now.month, day);
        if (next.isBefore(now)) {
          next = DateTime(now.year, now.month + 1, day);
        }
        return next;

      case RecurrenceType.everyWeek:
        final targetDay = recurrenceDayOfWeek ?? 7; // default Sunday
        var next = now;
        while (next.weekday != targetDay || next.isBefore(now.add(const Duration(hours: 1)))) {
          next = next.add(const Duration(days: 1));
          next = DateTime(next.year, next.month, next.day, 10, 0); // 10 AM
        }
        // Check season bounds
        if (seasonStart != null && seasonEnd != null) {
          final startMonth = _monthNumber(seasonStart!);
          final endMonth = _monthNumber(seasonEnd!);
          if (startMonth != null && endMonth != null) {
            final m = next.month;
            bool inSeason;
            if (startMonth <= endMonth) {
              inSeason = m >= startMonth && m <= endMonth;
            } else {
              inSeason = m >= startMonth || m <= endMonth;
            }
            if (!inSeason) return null; // Off-season
          }
        }
        return next;

      case RecurrenceType.custom:
      case RecurrenceType.oneTime:
        return null;
    }
  }

  /// Human-readable description of the recurrence.
  String get recurrenceDescription {
    switch (recurrenceType) {
      case RecurrenceType.oneTime:
        return 'One-time (launch manually)';
      case RecurrenceType.yearly:
        final monthName = recurrenceMonth != null
            ? _monthName(recurrenceMonth!)
            : 'Unknown';
        return 'Every $monthName';
      case RecurrenceType.everyMonth:
        final day = recurrenceDayOfMonth ?? 1;
        final suffix = _ordinalSuffix(day);
        return '$day$suffix of every month';
      case RecurrenceType.everyWeek:
        final dayName = recurrenceDayOfWeek != null
            ? _dayName(recurrenceDayOfWeek!)
            : 'Sunday';
        final season = seasonStart != null
            ? ' during ${seasonStart!.substring(0, 1).toUpperCase()}${seasonStart!.substring(1)} – ${seasonEnd!.substring(0, 1).toUpperCase()}${seasonEnd!.substring(1)} season'
            : '';
        return 'Every $dayName$season';
      case RecurrenceType.custom:
        return recurrenceLabel;
    }
  }

  /// Convert to Firestore map.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'host_id': hostId,
      'name': name,
      'description': description,
      'source_template_id': sourceTemplateId,
      'knowledge_pack_id': knowledgePackId,
      'bracket_type': bracketType,
      'sport': sport,
      'team_count': teamCount,
      'default_teams': defaultTeams,
      'is_free_entry': isFreeEntry,
      'entry_fee': entryFee,
      'prize_type': prizeType,
      'prize_description': prizeDescription,
      'default_prize': defaultPrize,
      'min_players': minPlayers,
      'max_players': maxPlayers,
      'auto_host': autoHost,
      'is_public': isPublic,
      'auto_share': autoShare,
      'charity_name': charityName,
      'charity_goal': charityGoal,
      'recurrence_type': recurrenceType.name,
      'recurrence_label': recurrenceLabel,
      'recurrence_month': recurrenceMonth,
      'recurrence_day_of_month': recurrenceDayOfMonth,
      'recurrence_day_of_week': recurrenceDayOfWeek,
      'season_start': seasonStart,
      'season_end': seasonEnd,
      'is_paused': isPaused,
      'created_at': createdAt.toUtc(),
      'last_used_at': lastUsedAt?.toUtc(),
      'times_used': timesUsed,
      'is_favorite': isFavorite,
      'requires_approval': requiresApproval,
    };
  }

  /// Create from Firestore document.
  factory SavedTemplate.fromFirestore(Map<String, dynamic> data, String docId) {
    return SavedTemplate(
      id: docId,
      hostId: data['host_id'] as String? ?? '',
      name: data['name'] as String? ?? 'Untitled Template',
      description: data['description'] as String? ?? '',
      sourceTemplateId: data['source_template_id'] as String?,
      knowledgePackId: data['knowledge_pack_id'] as String?,
      bracketType: data['bracket_type'] as String? ?? 'standard',
      sport: data['sport'] as String? ?? '',
      teamCount: (data['team_count'] as num?)?.toInt() ?? 16,
      defaultTeams: (data['default_teams'] as List<dynamic>?)?.cast<String>() ?? [],
      isFreeEntry: data['is_free_entry'] as bool? ?? true,
      entryFee: (data['entry_fee'] as num?)?.toInt() ?? 0,
      prizeType: data['prize_type'] as String? ?? 'none',
      prizeDescription: data['prize_description'] as String?,
      defaultPrize: data['default_prize'] as String?,
      minPlayers: (data['min_players'] as num?)?.toInt() ?? 4,
      maxPlayers: (data['max_players'] as num?)?.toInt() ?? 128,
      autoHost: data['auto_host'] as bool? ?? true,
      isPublic: data['is_public'] as bool? ?? true,
      autoShare: data['auto_share'] as bool? ?? true,
      charityName: data['charity_name'] as String?,
      charityGoal: data['charity_goal'] as String?,
      recurrenceType: _parseRecurrenceType(data['recurrence_type'] as String?),
      recurrenceLabel: data['recurrence_label'] as String? ?? 'One-time',
      recurrenceMonth: (data['recurrence_month'] as num?)?.toInt(),
      recurrenceDayOfMonth: (data['recurrence_day_of_month'] as num?)?.toInt(),
      recurrenceDayOfWeek: (data['recurrence_day_of_week'] as num?)?.toInt(),
      seasonStart: data['season_start'] as String?,
      seasonEnd: data['season_end'] as String?,
      isPaused: data['is_paused'] as bool? ?? false,
      createdAt: _parseDateTime(data['created_at']),
      lastUsedAt: data['last_used_at'] != null ? _parseDateTime(data['last_used_at']) : null,
      timesUsed: (data['times_used'] as num?)?.toInt() ?? 0,
      isFavorite: data['is_favorite'] as bool? ?? false,
      requiresApproval: data['requires_approval'] as bool? ?? true,
    );
  }

  SavedTemplate copyWith({
    String? name,
    String? description,
    bool? isFreeEntry,
    int? entryFee,
    String? prizeType,
    String? prizeDescription,
    String? defaultPrize,
    int? minPlayers,
    bool? autoHost,
    bool? autoShare,
    bool? isPublic,
    RecurrenceType? recurrenceType,
    String? recurrenceLabel,
    int? recurrenceMonth,
    int? recurrenceDayOfMonth,
    int? recurrenceDayOfWeek,
    String? seasonStart,
    String? seasonEnd,
    bool? isPaused,
    bool? isFavorite,
    bool? requiresApproval,
    DateTime? lastUsedAt,
    int? timesUsed,
  }) {
    return SavedTemplate(
      id: id,
      hostId: hostId,
      name: name ?? this.name,
      description: description ?? this.description,
      sourceTemplateId: sourceTemplateId,
      knowledgePackId: knowledgePackId,
      bracketType: bracketType,
      sport: sport,
      teamCount: teamCount,
      defaultTeams: defaultTeams,
      isFreeEntry: isFreeEntry ?? this.isFreeEntry,
      entryFee: entryFee ?? this.entryFee,
      prizeType: prizeType ?? this.prizeType,
      prizeDescription: prizeDescription ?? this.prizeDescription,
      defaultPrize: defaultPrize ?? this.defaultPrize,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers,
      autoHost: autoHost ?? this.autoHost,
      isPublic: isPublic ?? this.isPublic,
      autoShare: autoShare ?? this.autoShare,
      charityName: charityName,
      charityGoal: charityGoal,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceLabel: recurrenceLabel ?? this.recurrenceLabel,
      recurrenceMonth: recurrenceMonth ?? this.recurrenceMonth,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
      recurrenceDayOfWeek: recurrenceDayOfWeek ?? this.recurrenceDayOfWeek,
      seasonStart: seasonStart ?? this.seasonStart,
      seasonEnd: seasonEnd ?? this.seasonEnd,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      timesUsed: timesUsed ?? this.timesUsed,
      isFavorite: isFavorite ?? this.isFavorite,
      requiresApproval: requiresApproval ?? this.requiresApproval,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────
  static RecurrenceType _parseRecurrenceType(String? value) {
    switch (value) {
      case 'everyMonth': return RecurrenceType.everyMonth;
      case 'everyWeek': return RecurrenceType.everyWeek;
      case 'yearly': return RecurrenceType.yearly;
      case 'custom': return RecurrenceType.custom;
      default: return RecurrenceType.oneTime;
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    // Firestore Timestamp
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  static int? _monthNumber(String name) {
    const months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4,
      'may': 5, 'june': 6, 'july': 7, 'august': 8,
      'september': 9, 'october': 10, 'november': 11, 'december': 12,
    };
    return months[name.toLowerCase()];
  }

  static String _monthName(int month) {
    const names = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month.clamp(1, 12)];
  }

  static String _dayName(int day) {
    const names = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[day.clamp(1, 7)];
  }

  static String _ordinalSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}

/// Default prize presets for voting brackets (no entry fee).
class DefaultPrizes {
  static const List<Map<String, String>> votingPrizes = [
    {'id': 'gift_card_25', 'name': '\$25 Gift Card', 'type': 'gift_card', 'icon': 'card_giftcard'},
    {'id': 'gift_card_50', 'name': '\$50 Gift Card', 'type': 'gift_card', 'icon': 'card_giftcard'},
    {'id': 'bmb_hoodie', 'name': 'BMB Champion Hoodie', 'type': 'merch', 'icon': 'checkroom'},
    {'id': 'bmb_tshirt', 'name': 'BMB Pro T-Shirt', 'type': 'merch', 'icon': 'dry_cleaning'},
    {'id': 'bmb_cap', 'name': 'BMB Snapback Cap', 'type': 'merch', 'icon': 'face'},
    {'id': 'swag_bag', 'name': 'Swag Bag', 'type': 'merch', 'icon': 'shopping_bag'},
    {'id': 'bragging_rights', 'name': 'Bragging Rights', 'type': 'none', 'icon': 'emoji_events'},
    {'id': 'custom', 'name': 'Custom Prize', 'type': 'custom', 'icon': 'edit'},
  ];

  /// Most commonly used prize for voting brackets.
  static const String defaultVotingPrize = 'Bragging Rights';
}
