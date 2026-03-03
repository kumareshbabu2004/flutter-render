import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// Result of a giveaway drawing
class GiveawayResult {
  final String oddsMarker; // unique draw ID
  final String bracketId;
  final String bracketName;
  final String sport;
  final List<GiveawayWinner> winners;
  final GiveawayWinner? leaderboardLeader;
  final int contributionAmount; // original contribution per person
  final int totalParticipants;
  final DateTime drawnAt;

  GiveawayResult({
    required this.oddsMarker,
    required this.bracketId,
    required this.bracketName,
    this.sport = '',
    required this.winners,
    this.leaderboardLeader,
    required this.contributionAmount,
    required this.totalParticipants,
    required this.drawnAt,
  });

  /// Total credits given out across spinner winners + leaderboard
  int get totalCreditsAwarded {
    int total = winners.fold(0, (sum, w) => sum + w.creditsAwarded);
    if (leaderboardLeader != null) total += leaderboardLeader!.creditsAwarded;
    return total;
  }

  Map<String, dynamic> toJson() => {
    'oddsMarker': oddsMarker,
    'bracketId': bracketId,
    'bracketName': bracketName,
    'sport': sport,
    'winners': winners.map((w) => w.toJson()).toList(),
    'leaderboardLeader': leaderboardLeader?.toJson(),
    'contributionAmount': contributionAmount,
    'totalParticipants': totalParticipants,
    'drawnAt': drawnAt.toIso8601String(),
  };

  factory GiveawayResult.fromJson(Map<String, dynamic> json) => GiveawayResult(
    oddsMarker: json['oddsMarker'] ?? '',
    bracketId: json['bracketId'] ?? '',
    bracketName: json['bracketName'] ?? '',
    sport: json['sport'] ?? '',
    winners: (json['winners'] as List? ?? [])
        .map((w) => GiveawayWinner.fromJson(w))
        .toList(),
    leaderboardLeader: json['leaderboardLeader'] != null
        ? GiveawayWinner.fromJson(json['leaderboardLeader'])
        : null,
    contributionAmount: json['contributionAmount'] ?? json['creditsPerWinner'] ?? 0,
    totalParticipants: json['totalParticipants'] ?? 0,
    drawnAt: DateTime.tryParse(json['drawnAt'] ?? '') ?? DateTime.now(),
  );
}

class GiveawayWinner {
  final String userId;
  final String userName;
  final int creditsAwarded;
  final String label; // e.g. "1st Draw — 2x", "2nd Draw — 1x", "Leaderboard Leader"

  GiveawayWinner({
    required this.userId,
    required this.userName,
    required this.creditsAwarded,
    this.label = '',
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'creditsAwarded': creditsAwarded,
    'label': label,
  };

  factory GiveawayWinner.fromJson(Map<String, dynamic> json) => GiveawayWinner(
    userId: json['userId'] ?? '',
    userName: json['userName'] ?? '',
    creditsAwarded: json['creditsAwarded'] ?? 0,
    label: json['label'] ?? '',
  );
}

/// Manages tournament giveaway drawings for BMB-hosted tournaments.
///
/// Prize structure:
///   1st draw from spinner  → 2x their contribution (DOUBLE)
///   2nd draw from spinner  → 1x their contribution (EQUAL)
///   Leaderboard leader     → Bonus credits (separate award)
///
/// All credits deposit INSTANTLY into each winner's BMB Bucket.
/// This is a PROMOTIONAL GIVEAWAY — not a prize for winning.
class GiveawayService {
  static const String _storageKey = 'giveaway_results';
  static const String _tickerKey = 'giveaway_ticker_items';
  static final _random = Random.secure();

  /// Leaderboard leader bonus = contribution amount (can be adjusted)
  static int leaderboardBonus(int contribution) => contribution;

  /// Check if a bracket is eligible for a giveaway drawing.
  ///
  /// Giveaway is available on ANY bracket (free or paid) as long as the
  /// host toggled it ON during creation and there are enough participants.
  static bool isEligibleForGiveaway({
    required String hostId,
    required bool hasGiveaway,
    required int participantCount,
  }) {
    if (!hasGiveaway) return false;
    // Host must be a real user (current user or BMB official accounts)
    final isBmbHosted = hostId == 'bmb_official' ||
        hostId == 'bmb_admin' ||
        CurrentUserService.instance.isCurrentUser(hostId);
    return isBmbHosted && participantCount >= 3;
  }

  /// Perform the random giveaway drawing.
  ///
  /// 1st draw → 2x contribution
  /// 2nd draw → 1x contribution
  /// Leaderboard leader → bonus credits (separate)
  ///
  /// Credits are deposited into each winner's BMB Bucket INSTANTLY.
  static Future<GiveawayResult> performDrawing({
    required String bracketId,
    required String bracketName,
    required String sport,
    required List<Map<String, String>> participants, // [{id, name}]
    required int contributionAmount,
    String? leaderboardLeaderId,
    String? leaderboardLeaderName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Shuffle and pick 2 random winners
    final shuffled = List<Map<String, String>>.from(participants)..shuffle(_random);
    final winnerCount = participants.length >= 2 ? 2 : participants.length;

    final selectedWinners = <GiveawayWinner>[];
    for (int i = 0; i < winnerCount; i++) {
      final p = shuffled[i];
      final isFirst = i == 0;
      final credits = isFirst ? contributionAmount * 2 : contributionAmount;
      final label = isFirst ? '1st Draw \u2014 2x' : '2nd Draw \u2014 1x';

      selectedWinners.add(GiveawayWinner(
        userId: p['id'] ?? '',
        userName: p['name'] ?? '',
        creditsAwarded: credits,
        label: label,
      ));

      // INSTANT bucket credit for current user
      if (p['id'] == 'user_0' || p['id'] == 'u1') {
        final balance = prefs.getDouble('bmb_bucks_balance') ?? 350;
        await prefs.setDouble('bmb_bucks_balance', balance + credits);
      }
    }

    // Leaderboard leader bonus (separate from spinner)
    GiveawayWinner? leaderWinner;
    if (leaderboardLeaderId != null && leaderboardLeaderName != null) {
      final bonus = leaderboardBonus(contributionAmount);
      leaderWinner = GiveawayWinner(
        userId: leaderboardLeaderId,
        userName: leaderboardLeaderName,
        creditsAwarded: bonus,
        label: 'Leaderboard Leader Bonus',
      );

      // Instant bucket credit for current user
      if (leaderboardLeaderId == 'user_0' || leaderboardLeaderId == 'u1') {
        final balance = prefs.getDouble('bmb_bucks_balance') ?? 350;
        await prefs.setDouble('bmb_bucks_balance', balance + bonus);
      }
    }

    final result = GiveawayResult(
      oddsMarker: 'gw_${bracketId}_${DateTime.now().millisecondsSinceEpoch}',
      bracketId: bracketId,
      bracketName: bracketName,
      sport: sport,
      winners: selectedWinners,
      leaderboardLeader: leaderWinner,
      contributionAmount: contributionAmount,
      totalParticipants: participants.length,
      drawnAt: DateTime.now(),
    );

    // Persist result
    await _saveResult(result);

    // Auto-inject into ticker for 24hr visibility
    await _injectTickerAnnouncement(result);

    return result;
  }

  /// Generate the ordered spin list for the visual spinner.
  static List<String> generateSpinSequence({
    required List<String> participantNames,
    required String winnerName,
    int totalSpins = 3,
  }) {
    final names = List<String>.from(participantNames)..shuffle(_random);
    final sequence = <String>[];

    for (int i = 0; i < totalSpins; i++) {
      final shuffledCycle = List<String>.from(names)..shuffle(_random);
      sequence.addAll(shuffledCycle);
    }

    sequence.removeWhere((n) => n == winnerName);
    sequence.add(winnerName);

    return sequence;
  }

  /// Perform a variable-count giveaway drawing (used by leaderboard spinner).
  ///
  /// [winnerCount] and [tokensPerWinner] are configured during bracket wizard.
  /// All leaderboard participants are eligible regardless of score.
  static Future<GiveawayResult> performVariableDrawing({
    required String bracketId,
    required String bracketName,
    required String sport,
    required List<Map<String, String>> participants,
    required int winnerCount,
    required int tokensPerWinner,
    String? leaderboardLeaderId,
    String? leaderboardLeaderName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final shuffled = List<Map<String, String>>.from(participants)..shuffle(_random);
    final actualWinnerCount = winnerCount.clamp(1, participants.length);

    final selectedWinners = <GiveawayWinner>[];
    for (int i = 0; i < actualWinnerCount; i++) {
      final p = shuffled[i];
      final ordinalLabel = ordinal(i + 1);

      selectedWinners.add(GiveawayWinner(
        userId: p['id'] ?? '',
        userName: p['name'] ?? '',
        creditsAwarded: tokensPerWinner,
        label: '$ordinalLabel Place',
      ));

      // Instant bucket credit for current user
      if (p['id'] == 'user_0' || p['id'] == 'u1') {
        final balance = prefs.getDouble('bmb_bucks_balance') ?? 350;
        await prefs.setDouble('bmb_bucks_balance', balance + tokensPerWinner);
      }
    }

    // Leaderboard leader bonus (separate, optional)
    GiveawayWinner? leaderWinner;
    if (leaderboardLeaderId != null && leaderboardLeaderName != null) {
      final bonus = leaderboardBonus(tokensPerWinner);
      leaderWinner = GiveawayWinner(
        userId: leaderboardLeaderId,
        userName: leaderboardLeaderName,
        creditsAwarded: bonus,
        label: 'Leaderboard Leader Bonus',
      );
      if (leaderboardLeaderId == 'user_0' || leaderboardLeaderId == 'u1') {
        final balance = prefs.getDouble('bmb_bucks_balance') ?? 350;
        await prefs.setDouble('bmb_bucks_balance', balance + bonus);
      }
    }

    final result = GiveawayResult(
      oddsMarker: 'gw_${bracketId}_${DateTime.now().millisecondsSinceEpoch}',
      bracketId: bracketId,
      bracketName: bracketName,
      sport: sport,
      winners: selectedWinners,
      leaderboardLeader: leaderWinner,
      contributionAmount: tokensPerWinner,
      totalParticipants: participants.length,
      drawnAt: DateTime.now(),
    );

    await _saveResult(result);
    await _injectTickerAnnouncement(result);
    return result;
  }

  /// Ordinal suffix helper
  static String ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }

  /// Check if a giveaway has already been performed for a bracket.
  static Future<bool> hasGiveawayBeenPerformed(String bracketId) async {
    final results = await getResults();
    return results.any((r) => r.bracketId == bracketId);
  }

  /// Get all past giveaway results.
  static Future<List<GiveawayResult>> getResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((j) => GiveawayResult.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get giveaway result for a specific bracket.
  static Future<GiveawayResult?> getResultForBracket(String bracketId) async {
    final results = await getResults();
    try {
      return results.firstWhere((r) => r.bracketId == bracketId);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  TICKER INTEGRATION — 24hr scrolling announcement
  // ═══════════════════════════════════════════════════════════════

  /// Inject giveaway winner announcements into the ticker storage.
  /// These items will be picked up by LiveSportsTicker for 24 hours.
  static Future<void> _injectTickerAnnouncement(GiveawayResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRaw = prefs.getString(_tickerKey);
    final existing = <Map<String, dynamic>>[];
    if (existingRaw != null) {
      try {
        final list = jsonDecode(existingRaw) as List;
        existing.addAll(list.cast<Map<String, dynamic>>());
      } catch (_) {}
    }

    // Remove expired items (older than 24 hours)
    final now = DateTime.now();
    existing.removeWhere((item) {
      final createdAt = DateTime.tryParse(item['createdAt'] ?? '');
      if (createdAt == null) return true;
      return now.difference(createdAt).inHours >= 24;
    });

    // Add new winner announcements
    for (int i = 0; i < result.winners.length; i++) {
      final w = result.winners[i];
      final isFirst = i == 0;
      existing.add({
        'type': 'giveaway_winner',
        'bracketName': result.bracketName,
        'winnerName': w.userName,
        'credits': w.creditsAwarded,
        'place': isFirst ? '1st' : '2nd',
        'multiplier': isFirst ? '2x' : '1x',
        'createdAt': now.toIso8601String(),
      });
    }

    // Leaderboard leader
    if (result.leaderboardLeader != null) {
      existing.add({
        'type': 'giveaway_leader',
        'bracketName': result.bracketName,
        'winnerName': result.leaderboardLeader!.userName,
        'credits': result.leaderboardLeader!.creditsAwarded,
        'createdAt': now.toIso8601String(),
      });
    }

    await prefs.setString(_tickerKey, jsonEncode(existing));
  }

  /// Get active ticker announcements (within 24 hours).
  static Future<List<Map<String, dynamic>>> getActiveTickerItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tickerKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final now = DateTime.now();
      return list.cast<Map<String, dynamic>>().where((item) {
        final createdAt = DateTime.tryParse(item['createdAt'] ?? '');
        if (createdAt == null) return false;
        return now.difference(createdAt).inHours < 24;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  COMMUNITY POST — auto-post splash card
  // ═══════════════════════════════════════════════════════════════

  /// Generate community post data for a giveaway result.
  /// Returns a map that can be stored in CommunityPostStore.
  static Map<String, dynamic> generateCommunityPostData(GiveawayResult result) {
    final w1 = result.winners.isNotEmpty ? result.winners[0] : null;
    final w2 = result.winners.length > 1 ? result.winners[1] : null;
    final leader = result.leaderboardLeader;

    final buffer = StringBuffer();
    buffer.writeln('GIVEAWAY WINNERS');
    buffer.writeln(result.bracketName);
    buffer.writeln('');
    if (w1 != null) {
      buffer.writeln('1st Draw: ${w1.userName} \u2014 +${w1.creditsAwarded} credits (DOUBLE)');
    }
    if (w2 != null) {
      buffer.writeln('2nd Draw: ${w2.userName} \u2014 +${w2.creditsAwarded} credits');
    }
    if (leader != null) {
      buffer.writeln('Leaderboard Leader: ${leader.userName} \u2014 +${leader.creditsAwarded} credits');
    }
    buffer.writeln('');
    buffer.writeln('${result.totalParticipants} participants | ${result.totalCreditsAwarded} total credits awarded');

    return {
      'type': 'giveaway_splash',
      'bracketId': result.bracketId,
      'bracketName': result.bracketName,
      'sport': result.sport,
      'winner1Name': w1?.userName ?? '',
      'winner1Credits': w1?.creditsAwarded ?? 0,
      'winner2Name': w2?.userName ?? '',
      'winner2Credits': w2?.creditsAwarded ?? 0,
      'leaderName': leader?.userName ?? '',
      'leaderCredits': leader?.creditsAwarded ?? 0,
      'contributionAmount': result.contributionAmount,
      'totalParticipants': result.totalParticipants,
      'totalCreditsAwarded': result.totalCreditsAwarded,
      'summary': buffer.toString(),
      'drawnAt': result.drawnAt.toIso8601String(),
    };
  }

  /// Persist an already-drawn giveaway result and inject ticker announcements.
  ///
  /// Use this when the spinner overlay has already determined the winners
  /// visually and you just need to save + announce them (no re-draw).
  static Future<void> saveAndAnnounce(GiveawayResult result) async {
    // Award credits to current user if they won
    final prefs = await SharedPreferences.getInstance();
    final cuSvc = CurrentUserService.instance;
    for (final w in result.winners) {
      if (cuSvc.isCurrentUser(w.userId)) {
        final balance = prefs.getDouble('bmb_bucks_balance') ?? 350;
        await prefs.setDouble('bmb_bucks_balance', balance + w.creditsAwarded);
      }
    }
    if (result.leaderboardLeader != null &&
        cuSvc.isCurrentUser(result.leaderboardLeader!.userId)) {
      final balance = prefs.getDouble('bmb_bucks_balance') ?? 350;
      await prefs.setDouble(
          'bmb_bucks_balance', balance + result.leaderboardLeader!.creditsAwarded);
    }

    await _saveResult(result);
    await _injectTickerAnnouncement(result);
  }

  static Future<void> _saveResult(GiveawayResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final results = await getResults();
    results.add(result);
    await prefs.setString(_storageKey, jsonEncode(results.map((r) => r.toJson()).toList()));
  }
}
