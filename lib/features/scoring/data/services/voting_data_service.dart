import 'dart:math';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';

/// Service that generates and manages voting data for Voting Brackets.
///
/// In a Voting Bracket every matchup is decided by community votes (not by
/// the host or a live feed).  The leaderboard for a Voting Bracket therefore
/// ranks **items** (not players) by the percentage of votes each item has
/// received across all completed rounds.
///
/// Data flow:
///  bracket.teams -> round-0 matchups -> votes per matchup -> winners advance
///  -> round-1 matchups -> ... -> champion
class VotingDataService {
  // Singleton
  static final VotingDataService _instance = VotingDataService._();
  factory VotingDataService() => _instance;
  VotingDataService._();

  // Cache of generated voting data keyed by bracketId
  final Map<String, VotingBracketData> _cache = {};

  /// Get (or generate) the full voting data for a bracket.
  VotingBracketData getVotingData(CreatedBracket bracket) {
    return _cache.putIfAbsent(bracket.id, () => _generate(bracket));
  }

  /// Force-regenerate (e.g. after a new vote round completes).
  VotingBracketData regenerate(CreatedBracket bracket) {
    _cache.remove(bracket.id);
    return getVotingData(bracket);
  }

  // ─── GENERATOR ──────────────────────────────────────────────────

  VotingBracketData _generate(CreatedBracket bracket) {
    final rng = Random(bracket.id.hashCode);
    final teams = bracket.teams;
    final totalVoters = 80 + rng.nextInt(420); // 80 – 500 voters

    // We simulate a full bracket tournament through all rounds.
    List<String> currentRound = List.of(teams);
    final allRounds = <VotingRound>[];
    int roundIndex = 0;

    while (currentRound.length > 1) {
      // Pair up items
      final matchups = <VotingMatchup>[];
      for (int i = 0; i < currentRound.length - 1; i += 2) {
        final a = currentRound[i];
        final b = currentRound[i + 1];

        // Simulate votes — skew randomly
        final pctA = 15 + rng.nextInt(71); // 15 – 85 %
        final votesA = (totalVoters * pctA / 100).round();
        final votesB = totalVoters - votesA;
        final winner = votesA >= votesB ? a : b;

        matchups.add(VotingMatchup(
          itemA: a,
          itemB: b,
          votesA: votesA,
          votesB: votesB,
          totalVotes: totalVoters,
          winner: winner,
          isCompleted: true,
        ));
      }

      // Handle odd-numbered item (bye)
      if (currentRound.length.isOdd) {
        final bye = currentRound.last;
        matchups.add(VotingMatchup(
          itemA: bye,
          itemB: '(bye)',
          votesA: totalVoters,
          votesB: 0,
          totalVotes: totalVoters,
          winner: bye,
          isCompleted: true,
        ));
      }

      allRounds.add(VotingRound(
        roundIndex: roundIndex,
        roundName: _roundName(roundIndex, _totalRounds(teams.length)),
        matchups: matchups,
      ));

      // Advance winners
      currentRound = matchups.map((m) => m.winner).toList();
      roundIndex++;
    }

    // Build aggregate item rankings across all rounds
    final itemStats = <String, VotingItemStats>{};
    for (final team in teams) {
      itemStats[team] = VotingItemStats(name: team, totalVotesReceived: 0, totalVotesPossible: 0, roundsParticipated: 0, roundEliminated: null, isChampion: false);
    }

    for (int r = 0; r < allRounds.length; r++) {
      for (final m in allRounds[r].matchups) {
        if (m.itemB == '(bye)') {
          itemStats[m.itemA] = itemStats[m.itemA]!._addRound(m.votesA, m.totalVotes);
          continue;
        }
        itemStats[m.itemA] = itemStats[m.itemA]!._addRound(m.votesA, m.totalVotes);
        itemStats[m.itemB] = itemStats[m.itemB]!._addRound(m.votesB, m.totalVotes);
        // Mark loser as eliminated
        final loser = m.winner == m.itemA ? m.itemB : m.itemA;
        if (itemStats[loser]!.roundEliminated == null) {
          itemStats[loser] = itemStats[loser]!._eliminate(r);
        }
      }
    }

    // Mark champion
    if (currentRound.isNotEmpty) {
      final champ = currentRound.first;
      itemStats[champ] = itemStats[champ]!._setChampion();
    }

    // Rank items by average vote percentage (descending)
    final rankedItems = itemStats.values.toList()
      ..sort((a, b) {
        // Champion first, then by avg vote %
        if (a.isChampion && !b.isChampion) return -1;
        if (!a.isChampion && b.isChampion) return 1;
        // Higher rounds survived = better
        if (a.roundsParticipated != b.roundsParticipated) {
          return b.roundsParticipated.compareTo(a.roundsParticipated);
        }
        return b.avgVotePercent.compareTo(a.avgVotePercent);
      });

    // Assign ranks
    final ranked = <VotingItemStats>[];
    for (int i = 0; i < rankedItems.length; i++) {
      ranked.add(rankedItems[i]._withRank(i + 1));
    }

    return VotingBracketData(
      bracketId: bracket.id,
      totalVoters: totalVoters,
      rounds: allRounds,
      rankedItems: ranked,
      champion: currentRound.isNotEmpty ? currentRound.first : null,
    );
  }

  int _totalRounds(int teamCount) {
    int rounds = 0;
    int n = teamCount;
    while (n > 1) {
      n = (n / 2).ceil();
      rounds++;
    }
    return rounds;
  }

  String _roundName(int index, int total) {
    if (total <= 1) return 'Final';
    final remaining = total - index;
    if (remaining == 1) return 'Championship';
    if (remaining == 2) return 'Semifinals';
    if (remaining == 3) return 'Quarterfinals';
    return 'Round ${index + 1}';
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────

class VotingBracketData {
  final String bracketId;
  final int totalVoters;
  final List<VotingRound> rounds;
  final List<VotingItemStats> rankedItems;
  final String? champion;

  const VotingBracketData({
    required this.bracketId,
    required this.totalVoters,
    required this.rounds,
    required this.rankedItems,
    this.champion,
  });

  int get totalRounds => rounds.length;
  double get completionPercent => 1.0; // mock data is always "complete"
}

class VotingRound {
  final int roundIndex;
  final String roundName;
  final List<VotingMatchup> matchups;

  const VotingRound({
    required this.roundIndex,
    required this.roundName,
    required this.matchups,
  });
}

class VotingMatchup {
  final String itemA;
  final String itemB;
  final int votesA;
  final int votesB;
  final int totalVotes;
  final String winner;
  final bool isCompleted;

  const VotingMatchup({
    required this.itemA,
    required this.itemB,
    required this.votesA,
    required this.votesB,
    required this.totalVotes,
    required this.winner,
    this.isCompleted = false,
  });

  double get pctA => totalVotes > 0 ? votesA / totalVotes * 100 : 0;
  double get pctB => totalVotes > 0 ? votesB / totalVotes * 100 : 0;
}

class VotingItemStats {
  final String name;
  final int totalVotesReceived;
  final int totalVotesPossible;
  final int roundsParticipated;
  final int? roundEliminated; // null = still alive / champion
  final bool isChampion;
  final int rank;

  const VotingItemStats({
    required this.name,
    required this.totalVotesReceived,
    required this.totalVotesPossible,
    required this.roundsParticipated,
    this.roundEliminated,
    this.isChampion = false,
    this.rank = 0,
  });

  double get avgVotePercent =>
      totalVotesPossible > 0 ? totalVotesReceived / totalVotesPossible * 100 : 0;

  String get eliminatedLabel {
    if (isChampion) return 'Champion';
    if (roundEliminated == null) return 'Active';
    return 'Eliminated R${roundEliminated! + 1}';
  }

  VotingItemStats _addRound(int votes, int total) {
    return VotingItemStats(
      name: name,
      totalVotesReceived: totalVotesReceived + votes,
      totalVotesPossible: totalVotesPossible + total,
      roundsParticipated: roundsParticipated + 1,
      roundEliminated: roundEliminated,
      isChampion: isChampion,
      rank: rank,
    );
  }

  VotingItemStats _eliminate(int round) {
    return VotingItemStats(
      name: name,
      totalVotesReceived: totalVotesReceived,
      totalVotesPossible: totalVotesPossible,
      roundsParticipated: roundsParticipated,
      roundEliminated: round,
      isChampion: isChampion,
      rank: rank,
    );
  }

  VotingItemStats _setChampion() {
    return VotingItemStats(
      name: name,
      totalVotesReceived: totalVotesReceived,
      totalVotesPossible: totalVotesPossible,
      roundsParticipated: roundsParticipated,
      roundEliminated: null,
      isChampion: true,
      rank: rank,
    );
  }

  VotingItemStats _withRank(int r) {
    return VotingItemStats(
      name: name,
      totalVotesReceived: totalVotesReceived,
      totalVotesPossible: totalVotesPossible,
      roundsParticipated: roundsParticipated,
      roundEliminated: roundEliminated,
      isChampion: isChampion,
      rank: r,
    );
  }
}
