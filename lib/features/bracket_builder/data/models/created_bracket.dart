/// Tournament status flow:
/// saved → upcoming → live → in_progress → done
enum TournamentStatus { saved, upcoming, live, inProgress, done }

/// Represents a fully built bracket created by the user.
class CreatedBracket {
  final String id;
  final String name;
  final String templateId; // 'custom' for custom sizes
  final String sport;
  final int teamCount;
  final List<String> teams; // team names or 'TBD'
  final bool isFreeEntry;
  final int entryDonation; // credits amount, 0 if free
  final String prizeType; // 'store', 'custom', 'none', 'charity'
  final String? prizeDescription;
  final String? storePrizeId;
  final String? storePrizeName;
  final int? storePrizeCost; // credits
  final String status; // 'saved', 'upcoming', 'live', 'in_progress', 'done'
  final DateTime createdAt;
  final DateTime? scheduledLiveDate;
  final String hostId;
  final String hostName;
  final String? hostState;
  final List<String>? picks; // user's bracket picks (winner of each matchup)
  final int participantCount;

  // Bracket type: 'standard', 'voting', 'pickem', 'nopicks'
  final String bracketType;

  // Tie-breaker (only required for standard brackets; voting & nopicks skip it)
  final String? tieBreakerGame; // championship game name for tie-break
  final int? tieBreakerPrediction; // user's total-points prediction

  // Auto Host settings
  final bool autoHost; // if ON, auto-transition upcoming→live when conditions met
  final int minPlayers; // minimum joined players to go live
  final bool creditsDeducted; // whether credits have been deducted (on live transition)

  // Charity specific
  final String? charityName;
  final String? charityGoal;
  // NEW: Charity "Play for Their Charity" fields
  final double charityRaiseGoalDollars; // host-set dollar goal (e.g. $450)
  final int charityMinContribution;     // host-set minimum credits to contribute
  final int charityPotCredits;          // total credits in the pot from all contributions
  final double bmbFeePercent;           // BMB's cut (default 10%)
  final List<CharityContribution> charityContributions; // who contributed what

  // Voting specific
  final List<bool>? itemPhotos; // which items have photos uploaded

  // Giveaway settings (configured in wizard for any bracket)
  final bool hasGiveaway; // whether this bracket includes a giveaway drawing
  final int giveawayWinnerCount; // number of random winners to draw
  final int giveawayTokensPerWinner; // credits awarded to each winner

  // Completion timestamp — set when bracket transitions to 'done'
  final DateTime? completedAt;

  // Visibility: public vs private
  final bool isPublic; // true = visible to everyone; false = host + joined only
  final bool addToBracketBoard; // true = show on public bracket board feed

  // Joined players tracking
  final List<JoinedPlayer> joinedPlayers;

  CreatedBracket({
    required this.id,
    required this.name,
    required this.templateId,
    required this.sport,
    required this.teamCount,
    required this.teams,
    this.isFreeEntry = true,
    this.entryDonation = 0,
    this.prizeType = 'none',
    this.prizeDescription,
    this.storePrizeId,
    this.storePrizeName,
    this.storePrizeCost,
    this.status = 'saved',
    required this.createdAt,
    this.scheduledLiveDate,
    required this.hostId,
    required this.hostName,
    this.hostState,
    this.picks,
    this.participantCount = 0,
    this.bracketType = 'standard',
    this.tieBreakerGame,
    this.tieBreakerPrediction,
    this.autoHost = false,
    this.minPlayers = 2,
    this.creditsDeducted = false,
    this.charityName,
    this.charityGoal,
    this.charityRaiseGoalDollars = 0,
    this.charityMinContribution = 10,
    this.charityPotCredits = 0,
    this.bmbFeePercent = 10.0,
    this.charityContributions = const [],
    this.itemPhotos,
    this.hasGiveaway = false,
    this.giveawayWinnerCount = 2,
    this.giveawayTokensPerWinner = 0,
    this.completedAt,
    this.isPublic = true,
    this.addToBracketBoard = true,
    this.joinedPlayers = const [],
  });

  /// Number of rounds in this bracket.
  /// Pick 'Em = always 1 round (single slate of independent matchups).
  /// Standard = log2 (full elimination tree).
  int get totalRounds {
    // Pick 'Em is a single-round format: pick the winner of each matchup,
    // closest tie-breaker score wins. No advancing / no elimination tree.
    if (bracketType == 'pickem') return 1;
    int n = teamCount;
    int rounds = 0;
    while (n > 1) {
      n = (n / 2).ceil();
      rounds++;
    }
    return rounds;
  }

  /// Total number of matchups (games).
  /// Pick 'Em = teamCount / 2 (flat slate).
  /// Standard = teamCount - 1 (full elimination tree).
  int get totalMatchups {
    if (bracketType == 'pickem') return (teamCount / 2).floor();
    return teamCount - 1;
  }

  /// Parsed tournament status enum
  TournamentStatus get tournamentStatus {
    switch (status) {
      case 'saved': return TournamentStatus.saved;
      case 'upcoming': return TournamentStatus.upcoming;
      case 'live': return TournamentStatus.live;
      case 'in_progress': return TournamentStatus.inProgress;
      case 'done': return TournamentStatus.done;
      default: return TournamentStatus.saved;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'saved': return 'Saved';
      case 'upcoming': return 'Upcoming';
      case 'live': return 'LIVE';
      case 'in_progress': return 'In Progress';
      case 'done': return 'Done';
      default: return status;
    }
  }

  /// Status color for UI
  static String statusColor(String status) {
    switch (status) {
      case 'saved': return 'grey';
      case 'upcoming': return 'blue';
      case 'live': return 'green';
      case 'in_progress': return 'gold';
      case 'done': return 'teal';
      default: return 'grey';
    }
  }

  String get entryLabel =>
      isFreeEntry ? 'Free' : '$entryDonation credits';

  String get prizeLabel {
    if (prizeType == 'store' && storePrizeName != null) return storePrizeName!;
    if (prizeType == 'custom' && prizeDescription != null) return prizeDescription!;
    if (prizeType == 'charity' && charityName != null) return 'Charity: $charityName';
    if (prizeType == 'charity') return 'Play for Charity';
    return 'No Prize';
  }

  /// Bracket type display label
  String get bracketTypeLabel {
    switch (bracketType) {
      case 'voting': return 'Voting';
      case 'pickem': return 'Pick \'Em';
      case 'nopicks': return 'No Picks';
      default: return 'Standard';
    }
  }

  /// Whether this bracket type requires user picks
  bool get requiresPicks => bracketType == 'standard' || bracketType == 'pickem';

  /// Whether this is a Pick 'Em style (single round, percentage based)
  bool get isPickEm => bracketType == 'pickem';

  /// Whether this is a voting bracket
  bool get isVoting => bracketType == 'voting';

  /// Whether this is a 1v1 (head-to-head) bracket
  bool get is1v1 => teamCount == 2;

  /// Format label for bracket size (e.g. "1v1", "4-team", "64-team")
  String get sizeLabel => is1v1 ? '1v1' : '$teamCount-team';

  /// Whether players can still join
  bool get canJoin => status == 'upcoming' || status == 'live';

  /// Whether the tournament is locked (no more joins / picks locked)
  bool get isLocked => status == 'in_progress' || status == 'done';

  /// Check if a specific user has joined this bracket.
  /// [isMe] is a function that resolves userId aliases (e.g. 'u1', 'user_0').
  /// Typical usage: `bracket.isUserJoined(CurrentUserService.instance.isCurrentUser)`
  bool isUserJoined(bool Function(String id) isMe) {
    return joinedPlayers.any((p) => isMe(p.userId));
  }

  /// Check if a specific user has already submitted picks.
  bool hasUserMadePicks(bool Function(String id) isMe) {
    final player = joinedPlayers.cast<JoinedPlayer?>().firstWhere(
        (p) => isMe(p!.userId),
        orElse: () => null);
    return player?.hasMadePicks ?? false;
  }

  /// Whether the current user is the host of this bracket.
  bool isUserHost(bool Function(String id) isMe) => isMe(hostId);

  /// Whether minimum players threshold is met
  bool get minPlayersMet => participantCount >= minPlayers;

  /// Whether auto-host conditions are met for going live
  bool get autoHostReady =>
      autoHost &&
      minPlayersMet &&
      scheduledLiveDate != null &&
      !scheduledLiveDate!.isAfter(DateTime.now());

  /// Whether this is a "Play for Their Charity" bracket
  bool get isCharityBracket => prizeType == 'charity';

  /// The total charity pot in dollars (credits * $0.10)
  double get charityPotDollars => charityPotCredits * 0.10;

  /// BMB fee in credits
  int get bmbFeeCredits => (charityPotCredits * bmbFeePercent / 100).round();

  /// Net donation credits (pot minus BMB fee)
  int get charityNetCredits => charityPotCredits - bmbFeeCredits;

  /// Net donation in dollars
  double get charityNetDollars => charityNetCredits * 0.10;

  /// Raise goal in credits (dollars / $0.10)
  int get charityRaiseGoalCredits => (charityRaiseGoalDollars / 0.10).round();

  /// Progress toward the raise goal (0.0 - 1.0+)
  double get charityGoalProgress => charityRaiseGoalCredits > 0
      ? charityPotCredits / charityRaiseGoalCredits
      : 0.0;

  /// Whether the bracket can be fully edited (all fields)
  bool get canFullEdit => status == 'saved';

  /// Whether only TBD team names can be edited
  bool get canTbdEdit => status == 'upcoming' && participantCount == 0;

  /// Whether ANY editing is allowed
  bool get canEdit => canFullEdit || canTbdEdit;

  /// Convert this bracket to a Firestore-compatible map.
  /// Used when saving/updating brackets in the cloud.
  /// Voting brackets always have entry_fee = 0 (free).
  Map<String, dynamic> toFirestoreMap() {
    final isVotingType = bracketType == 'voting';
    return {
      'name': name,
      'sport': sport,
      'bracket_type': bracketType,
      'team_count': teamCount,
      'teams': teams,
      'entry_fee': isVotingType ? 0 : (isFreeEntry ? 0 : entryDonation),
      'entry_type': isVotingType ? 'free' : (isFreeEntry ? 'free' : 'paid'),
      'prize_type': prizeType,
      'prize_description': prizeDescription ?? '',
      'prize_value': storePrizeCost ?? entryDonation,
      'status': status,
      'host_user_id': hostId,
      'host_display_name': hostName,
      'entrants_count': participantCount,
      'max_entrants': 0, // unlimited by default
      'is_featured': false,
      'is_public': isPublic,
      'add_to_bracket_board': addToBracketBoard,
      'created_at': createdAt.toUtc(),
      if (scheduledLiveDate != null)
        'go_live_date': scheduledLiveDate!.toUtc(),
      if (tieBreakerGame != null)
        'tie_breaker_game': tieBreakerGame,
      'auto_host': autoHost,
      'min_players': minPlayers,
      'has_giveaway': hasGiveaway,
      'giveaway_winner_count': giveawayWinnerCount,
      'giveaway_tokens_per_winner': giveawayTokensPerWinner,
      if (charityName != null) 'charity_name': charityName,
      if (charityGoal != null) 'charity_goal': charityGoal,
      'charity_raise_goal_dollars': charityRaiseGoalDollars,
      'charity_min_contribution': charityMinContribution,
      'charity_pot_credits': charityPotCredits,
      'bmb_fee_percent': bmbFeePercent,
      if (storePrizeId != null) 'store_prize_id': storePrizeId,
      if (storePrizeName != null) 'store_prize_name': storePrizeName,
    };
  }

  /// Create a copy with modifications
  CreatedBracket copyWith({
    String? name,
    String? templateId,
    String? sport,
    int? teamCount,
    List<String>? teams,
    bool? isFreeEntry,
    int? entryDonation,
    String? prizeType,
    String? prizeDescription,
    String? storePrizeId,
    String? storePrizeName,
    int? storePrizeCost,
    String? status,
    DateTime? scheduledLiveDate,
    List<String>? picks,
    int? participantCount,
    int? tieBreakerPrediction,
    bool? creditsDeducted,
    List<JoinedPlayer>? joinedPlayers,
    bool? autoHost,
    int? minPlayers,
    String? tieBreakerGame,
    String? charityName,
    String? charityGoal,
    double? charityRaiseGoalDollars,
    int? charityMinContribution,
    int? charityPotCredits,
    double? bmbFeePercent,
    List<CharityContribution>? charityContributions,
    List<bool>? itemPhotos,
    bool? hasGiveaway,
    int? giveawayWinnerCount,
    int? giveawayTokensPerWinner,
    DateTime? completedAt,
    bool? isPublic,
    bool? addToBracketBoard,
  }) {
    return CreatedBracket(
      id: id,
      name: name ?? this.name,
      templateId: templateId ?? this.templateId,
      sport: sport ?? this.sport,
      teamCount: teamCount ?? this.teamCount,
      teams: teams ?? this.teams,
      isFreeEntry: isFreeEntry ?? this.isFreeEntry,
      entryDonation: entryDonation ?? this.entryDonation,
      prizeType: prizeType ?? this.prizeType,
      prizeDescription: prizeDescription ?? this.prizeDescription,
      storePrizeId: storePrizeId ?? this.storePrizeId,
      storePrizeName: storePrizeName ?? this.storePrizeName,
      storePrizeCost: storePrizeCost ?? this.storePrizeCost,
      status: status ?? this.status,
      createdAt: createdAt,
      scheduledLiveDate: scheduledLiveDate ?? this.scheduledLiveDate,
      hostId: hostId,
      hostName: hostName,
      hostState: hostState,
      picks: picks ?? this.picks,
      participantCount: participantCount ?? this.participantCount,
      bracketType: bracketType,
      tieBreakerGame: tieBreakerGame ?? this.tieBreakerGame,
      tieBreakerPrediction: tieBreakerPrediction ?? this.tieBreakerPrediction,
      autoHost: autoHost ?? this.autoHost,
      minPlayers: minPlayers ?? this.minPlayers,
      creditsDeducted: creditsDeducted ?? this.creditsDeducted,
      charityName: charityName ?? this.charityName,
      charityGoal: charityGoal ?? this.charityGoal,
      charityRaiseGoalDollars: charityRaiseGoalDollars ?? this.charityRaiseGoalDollars,
      charityMinContribution: charityMinContribution ?? this.charityMinContribution,
      charityPotCredits: charityPotCredits ?? this.charityPotCredits,
      bmbFeePercent: bmbFeePercent ?? this.bmbFeePercent,
      charityContributions: charityContributions ?? this.charityContributions,
      itemPhotos: itemPhotos ?? this.itemPhotos,
      hasGiveaway: hasGiveaway ?? this.hasGiveaway,
      giveawayWinnerCount: giveawayWinnerCount ?? this.giveawayWinnerCount,
      giveawayTokensPerWinner: giveawayTokensPerWinner ?? this.giveawayTokensPerWinner,
      completedAt: completedAt ?? this.completedAt,
      isPublic: isPublic ?? this.isPublic,
      addToBracketBoard: addToBracketBoard ?? this.addToBracketBoard,
      joinedPlayers: joinedPlayers ?? this.joinedPlayers,
    );
  }
}

/// Represents a player who has joined a tournament
class JoinedPlayer {
  final String userId;
  final String userName;
  final String? userState;
  final DateTime joinedAt;
  final int? tieBreakerPrediction;
  final bool hasMadePicks;

  const JoinedPlayer({
    required this.userId,
    required this.userName,
    this.userState,
    required this.joinedAt,
    this.tieBreakerPrediction,
    this.hasMadePicks = false,
  });
}

/// Mock BMB Store prizes
class BmbStorePrize {
  final String id;
  final String name;
  final String description;
  final int cost; // credits
  final String iconName;

  const BmbStorePrize({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.iconName,
  });

  static const List<BmbStorePrize> storePrizes = [
    BmbStorePrize(
      id: 'prize_1',
      name: 'BMB Champion Hoodie',
      description: 'Premium BMB branded champion hoodie with your bracket printed on back',
      cost: 250,
      iconName: 'checkroom',
    ),
    BmbStorePrize(
      id: 'prize_2',
      name: 'BMB Snapback Cap',
      description: 'Exclusive BMB champion snapback hat',
      cost: 100,
      iconName: 'face',
    ),
    BmbStorePrize(
      id: 'prize_3',
      name: '\$25 Gift Card',
      description: 'Digital gift card redeemable at BMB store',
      cost: 150,
      iconName: 'card_giftcard',
    ),
    BmbStorePrize(
      id: 'prize_4',
      name: 'BMB Pro T-Shirt',
      description: 'Limited edition BMB tournament champion t-shirt',
      cost: 175,
      iconName: 'dry_cleaning',
    ),
    BmbStorePrize(
      id: 'prize_5',
      name: '\$50 Gift Card',
      description: 'Premium digital gift card redeemable at BMB store',
      cost: 300,
      iconName: 'card_giftcard',
    ),
    BmbStorePrize(
      id: 'prize_6',
      name: 'BMB Mystery Box',
      description: 'Surprise box of BMB merchandise and exclusives',
      cost: 200,
      iconName: 'inventory_2',
    ),
  ];
}

/// Tracks an individual contribution to a charity bracket pot.
class CharityContribution {
  final String userId;
  final String userName;
  final int credits;
  final DateTime contributedAt;

  const CharityContribution({
    required this.userId,
    required this.userName,
    required this.credits,
    required this.contributedAt,
  });

  double get dollars => credits * 0.10;
}
