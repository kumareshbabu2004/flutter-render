import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';
import 'package:bmb_mobile/features/community/data/services/community_post_store.dart';

/// Generates a picks summary card and posts it to the BMB Community thread.
/// Now persists the post via [CommunityPostStore] so the community chat
/// can display it when the user navigates there.
class PostToBmbService {
  PostToBmbService._();

  /// Build a text summary of the user's picks for community posting
  static String buildPicksSummary({
    required CreatedBracket bracket,
    required Map<String, String> picks,
    required String userName,
    int? tieBreakerPrediction,
  }) {
    final buf = StringBuffer();
    buf.writeln('$userName\'s Picks for "${bracket.name}"');
    final divider = '\u2500' * 36;
    buf.writeln(divider);
    buf.writeln('${bracket.bracketTypeLabel} | ${bracket.sport}');
    buf.writeln('${bracket.teamCount} teams | ${bracket.totalMatchups} matchups');
    buf.writeln('');

    // Show picks by round
    for (int round = 0; round < bracket.totalRounds; round++) {
      final roundName = _roundName(round, bracket.totalRounds);
      final roundPicks = <String>[];
      int matchupsInRound = bracket.teamCount;
      for (int r = 0; r <= round; r++) {
        matchupsInRound = (matchupsInRound / 2).ceil();
      }
      for (int m = 0; m < matchupsInRound; m++) {
        final gameId = 'r${round}_g$m';
        final pick = picks[gameId];
        if (pick != null) roundPicks.add(pick);
      }
      if (roundPicks.isNotEmpty) {
        buf.writeln('$roundName:');
        for (final pick in roundPicks) {
          buf.writeln('  \u2192 $pick');
        }
        buf.writeln('');
      }
    }

    // Champion pick (last round, game 0)
    final champGameId = 'r${bracket.totalRounds - 1}_g0';
    final champion = picks[champGameId];
    if (champion != null) {
      buf.writeln('Champion Pick: $champion');
    }

    if (tieBreakerPrediction != null) {
      buf.writeln('Tie-Breaker Prediction: $tieBreakerPrediction total points');
    }

    buf.writeln('');
    buf.writeln('#BackMyBracket #BMB');
    return buf.toString();
  }

  /// Post a bracket picks summary to the BMB Community.
  /// Now also writes to [CommunityPostStore] for persistence.
  static Future<CommunityBracketPost> createCommunityPost({
    required CreatedBracket bracket,
    required Map<String, String> picks,
    required String userId,
    required String userName,
    int? tieBreakerPrediction,
  }) async {
    final summary = buildPicksSummary(
      bracket: bracket,
      picks: picks,
      userName: userName,
      tieBreakerPrediction: tieBreakerPrediction,
    );

    final results = ResultsService.getResults(bracket);
    int correct = 0, wrong = 0, pending = 0;
    for (final entry in picks.entries) {
      final result = results.games[entry.key];
      if (result == null || result.winner == null) {
        pending++;
      } else if (result.winner == entry.value) {
        correct++;
      } else {
        wrong++;
      }
    }

    final champPick = picks['r${bracket.totalRounds - 1}_g0'];

    final autoMessage = CommunityPostStore.generateAutoPostMessage(
      bracketName: bracket.name,
      championPick: champPick,
    );

    final post = CommunityBracketPost(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      bracketId: bracket.id,
      bracketName: bracket.name,
      sport: bracket.sport,
      bracketType: bracket.bracketTypeLabel,
      totalPicks: picks.length,
      correct: correct,
      wrong: wrong,
      pending: pending,
      championPick: champPick,
      tieBreakerPrediction: tieBreakerPrediction,
      summary: summary,
      message: autoMessage,
      postedAt: DateTime.now(),
      teams: List<String>.from(bracket.teams),
      picksMap: Map<String, String>.from(picks),
      totalRounds: bracket.totalRounds,
    );

    // Persist so Community Chat can pick it up
    final store = CommunityPostStore();
    await store.init();
    await store.addPost(post);

    return post;
  }

  static String _roundName(int round, int totalRounds) {
    final remaining = totalRounds - round;
    if (remaining == 0) return 'Champion';
    if (remaining == 1) return 'Finals';
    if (remaining == 2) return 'Semi-Finals';
    if (remaining == 3) return 'Quarter-Finals';
    return 'Round ${round + 1}';
  }
}
