import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/models/scoring_models.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';

/// Read-only view of any player's picks for a tournament.
/// Opened from the leaderboard by tapping the "view picks" icon.
class PlayerPicksViewerScreen extends StatelessWidget {
  final CreatedBracket bracket;
  final UserPicks userPicks;
  final ScoredEntry scoredEntry;

  const PlayerPicksViewerScreen({
    super.key,
    required this.bracket,
    required this.userPicks,
    required this.scoredEntry,
  });

  @override
  Widget build(BuildContext context) {
    final results = ResultsService.getResults(bracket);
    final teams = bracket.teams;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildScoreCard(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    // Picks by round
                    ...List.generate(bracket.totalRounds, (round) {
                      return _buildRoundSection(round, teams, results);
                    }),
                    // Tie-breaker prediction
                    if (scoredEntry.tieBreakerPrediction != null)
                      _buildTieBreakerSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${userPicks.userName}'s Picks",
                  style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                  ),
                ),
                Text(
                  bracket.name,
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Rank badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _rankColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scoredEntry.rank <= 3)
                  Icon(Icons.emoji_events, color: _rankColor, size: 14),
                if (scoredEntry.rank <= 3) const SizedBox(width: 4),
                Text(
                  '#${scoredEntry.rank}',
                  style: TextStyle(
                    color: _rankColor,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _rankColor {
    if (scoredEntry.rank == 1) return const Color(0xFFFFD700);
    if (scoredEntry.rank == 2) return const Color(0xFFC0C0C0);
    if (scoredEntry.rank == 3) return const Color(0xFFCD7F32);
    return BmbColors.blue;
  }

  Widget _buildScoreCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('Score', '${scoredEntry.score}', BmbColors.gold),
          _stat('Correct', '${scoredEntry.correctPicks}', BmbColors.successGreen),
          _stat('Wrong', '${scoredEntry.incorrectPicks}', BmbColors.errorRed),
          _stat('Pending', '${scoredEntry.pendingPicks}', BmbColors.textTertiary),
          _stat('Accuracy', '${scoredEntry.accuracy.toStringAsFixed(0)}%', BmbColors.blue),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: BmbFontWeights.bold,
            fontFamily: 'ClashDisplay',
          ),
        ),
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
      ],
    );
  }

  Widget _buildRoundSection(int round, List<String> teams, BracketResults results) {
    // Build the matchups for this round
    final matchups = <_PickMatchup>[];
    // We need to figure out how many matchups in this round
    int matchupsInRound = bracket.teamCount;
    for (int r = 0; r <= round; r++) {
      matchupsInRound = (matchupsInRound / 2).ceil();
    }

    for (int m = 0; m < matchupsInRound; m++) {
      final gameId = 'r${round}_g$m';
      final pick = userPicks.picks[gameId];
      final result = results.games[gameId];
      final winner = result?.winner;
      final isCorrect = pick != null && winner != null && pick == winner;
      final isWrong = pick != null && winner != null && pick != winner;

      matchups.add(_PickMatchup(
        gameId: gameId,
        pick: pick,
        actualWinner: winner,
        isCorrect: isCorrect,
        isWrong: isWrong,
        isPending: pick != null && winner == null,
      ));
    }

    final roundName = _roundName(round);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roundName,
                style: TextStyle(
                  color: BmbColors.blue,
                  fontSize: 12,
                  fontWeight: BmbFontWeights.bold,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${matchups.where((m) => m.pick != null).length}/${matchups.length} picked',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...matchups.map((m) => _buildPickRow(m)),
      ],
    );
  }

  Widget _buildPickRow(_PickMatchup matchup) {
    Color bgColor = BmbColors.cardDark;
    Color borderColor = BmbColors.borderColor;
    IconData statusIcon = Icons.pending;
    Color statusColor = BmbColors.textTertiary;

    if (matchup.isCorrect) {
      bgColor = BmbColors.successGreen.withValues(alpha: 0.08);
      borderColor = BmbColors.successGreen.withValues(alpha: 0.3);
      statusIcon = Icons.check_circle;
      statusColor = BmbColors.successGreen;
    } else if (matchup.isWrong) {
      bgColor = BmbColors.errorRed.withValues(alpha: 0.08);
      borderColor = BmbColors.errorRed.withValues(alpha: 0.3);
      statusIcon = Icons.cancel;
      statusColor = BmbColors.errorRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  matchup.pick ?? 'No pick',
                  style: TextStyle(
                    color: matchup.pick != null
                        ? BmbColors.textPrimary
                        : BmbColors.textTertiary,
                    fontSize: 13,
                    fontWeight: BmbFontWeights.semiBold,
                    decoration: matchup.isWrong ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (matchup.actualWinner != null && matchup.isWrong)
                  Text(
                    'Actual: ${matchup.actualWinner}',
                    style: TextStyle(
                      color: BmbColors.successGreen,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            matchup.gameId.replaceAll('r', 'R').replaceAll('_g', ' G'),
            style: TextStyle(color: BmbColors.textTertiary, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildTieBreakerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              BmbColors.gold.withValues(alpha: 0.12),
              BmbColors.gold.withValues(alpha: 0.04),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.sports_score, color: BmbColors.gold, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tie-Breaker Prediction',
                      style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.bold,
                      ),
                    ),
                    Text(
                      '${scoredEntry.tieBreakerPrediction} total points',
                      style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay',
                      ),
                    ),
                    if (scoredEntry.tieBreakerDiff != null)
                      Text(
                        scoredEntry.tieBreakerWentOver == true
                            ? 'Over by ${scoredEntry.tieBreakerDiff}'
                            : 'Under by ${scoredEntry.tieBreakerDiff}',
                        style: TextStyle(
                          color: scoredEntry.tieBreakerWentOver == true
                              ? BmbColors.errorRed
                              : BmbColors.successGreen,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _roundName(int round) {
    final totalRounds = bracket.totalRounds;
    final remaining = totalRounds - round;
    if (remaining == 0) return 'Champion';
    if (remaining == 1) return 'Finals';
    if (remaining == 2) return 'Semi-Finals';
    if (remaining == 3) return 'Quarter-Finals';
    return 'Round ${round + 1}';
  }
}

class _PickMatchup {
  final String gameId;
  final String? pick;
  final String? actualWinner;
  final bool isCorrect;
  final bool isWrong;
  final bool isPending;

  const _PickMatchup({
    required this.gameId,
    this.pick,
    this.actualWinner,
    required this.isCorrect,
    required this.isWrong,
    required this.isPending,
  });
}
