import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/data/services/voting_data_service.dart';

/// Voting Bracket Leaderboard
///
/// Unlike a standard bracket leaderboard (which ranks *players* by score),
/// the Voting Bracket leaderboard ranks **items** by vote popularity.
///
/// - Shows every item ranked #1 → last by overall vote percentage.
/// - Each row shows: rank, item name, vote bar, %, round eliminated/status.
/// - A round-by-round breakdown tab lets the host see each matchup result.
/// - Business use-cases: best menu item, best 80s song, best Christmas movie, etc.
class VotingLeaderboardScreen extends StatefulWidget {
  final CreatedBracket bracket;
  const VotingLeaderboardScreen({super.key, required this.bracket});
  @override
  State<VotingLeaderboardScreen> createState() =>
      _VotingLeaderboardScreenState();
}

class _VotingLeaderboardScreenState extends State<VotingLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late VotingBracketData _data;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _data = VotingDataService().getVotingData(widget.bracket);
    // Tabs: "Rankings" + one per round
    _tabController =
        TabController(length: 1 + _data.totalRounds, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildChampionBanner(),
              _buildSummaryBar(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRankingsTab(),
                    ...List.generate(
                        _data.totalRounds, (i) => _buildRoundTab(i)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────
  Widget _buildHeader() {
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
                Text('Vote Popularity',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Text(widget.bracket.name,
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Voting badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.how_to_vote,
                  color: Color(0xFF9C27B0), size: 14),
              const SizedBox(width: 4),
              Text('Voting',
                  style: TextStyle(
                      color: const Color(0xFF9C27B0),
                      fontSize: 10,
                      fontWeight: BmbFontWeights.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── CHAMPION BANNER ─────────────────────────────────────────────
  Widget _buildChampionBanner() {
    if (_data.champion == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.15),
          BmbColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [BmbColors.gold, BmbColors.goldLight]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: BmbColors.gold.withValues(alpha: 0.3),
                    blurRadius: 12)
              ],
            ),
            child: const Icon(Icons.emoji_events,
                color: Colors.black, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Most Popular',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 10,
                        fontWeight: BmbFontWeights.bold)),
                Text(_data.champion!,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Text(
                    'Won ${_data.totalRounds} round${_data.totalRounds == 1 ? '' : 's'} of voting',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('#1',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 22,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              Text('CHAMPION',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 8,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SUMMARY BAR ─────────────────────────────────────────────────
  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          _summaryChip(Icons.list_alt, '${widget.bracket.teams.length} items'),
          const SizedBox(width: 8),
          _summaryChip(
              Icons.people, '${_data.totalVoters} voters'),
          const SizedBox(width: 8),
          _summaryChip(Icons.format_list_numbered,
              '${_data.totalRounds} rounds'),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: BmbColors.borderColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BmbColors.textTertiary, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB BAR ─────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      height: 36,
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: const Color(0xFF9C27B0).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.5)),
        ),
        labelColor: const Color(0xFF9C27B0),
        unselectedLabelColor: BmbColors.textTertiary,
        labelStyle:
            TextStyle(fontSize: 11, fontWeight: BmbFontWeights.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        dividerHeight: 0,
        tabAlignment: TabAlignment.start,
        tabs: [
          const Tab(text: 'Rankings'),
          ...List.generate(
              _data.totalRounds,
              (i) => Tab(
                  text: _data.rounds[i].roundName.length > 12
                      ? 'R${i + 1}'
                      : _data.rounds[i].roundName)),
        ],
      ),
    );
  }

  // ─── RANKINGS TAB ────────────────────────────────────────────────
  Widget _buildRankingsTab() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: _data.rankedItems.length,
      itemBuilder: (ctx, idx) => _buildRankRow(_data.rankedItems[idx]),
    );
  }

  Widget _buildRankRow(VotingItemStats item) {
    final isChamp = item.isChampion;
    final isTop3 = item.rank <= 3;

    Color accentColor;
    if (item.rank == 1) {
      accentColor = const Color(0xFFFFD700);
    } else if (item.rank == 2) {
      accentColor = const Color(0xFFC0C0C0);
    } else if (item.rank == 3) {
      accentColor = const Color(0xFFCD7F32);
    } else {
      accentColor = const Color(0xFF9C27B0);
    }

    final pct = item.avgVotePercent;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: isChamp
            ? LinearGradient(colors: [
                BmbColors.gold.withValues(alpha: 0.10),
                BmbColors.gold.withValues(alpha: 0.03),
              ])
            : isTop3
                ? LinearGradient(colors: [
                    accentColor.withValues(alpha: 0.08),
                    accentColor.withValues(alpha: 0.02),
                  ])
                : BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChamp
              ? BmbColors.gold.withValues(alpha: 0.4)
              : isTop3
                  ? accentColor.withValues(alpha: 0.3)
                  : BmbColors.borderColor.withValues(alpha: 0.3),
          width: isChamp ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: isTop3
                ? Icon(Icons.emoji_events, color: accentColor, size: 22)
                : Text('#${item.rank}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: BmbColors.textTertiary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.bold)),
          ),
          const SizedBox(width: 10),
          // Item info + vote bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.name,
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.semiBold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isChamp) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: BmbColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events,
                                  color: BmbColors.gold, size: 9),
                              const SizedBox(width: 2),
                              Text('WINNER',
                                  style: TextStyle(
                                      color: BmbColors.gold,
                                      fontSize: 7,
                                      fontWeight: BmbFontWeights.bold,
                                      letterSpacing: 0.5)),
                            ]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Vote bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: BmbColors.borderColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (pct / 100).clamp(0, 1),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            accentColor.withValues(alpha: 0.8),
                            accentColor.withValues(alpha: 0.5),
                          ]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Stats row
                Row(
                  children: [
                    Text('${pct.toStringAsFixed(1)}% avg',
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: BmbFontWeights.bold)),
                    const SizedBox(width: 8),
                    Icon(Icons.how_to_vote,
                        color: BmbColors.textTertiary, size: 10),
                    const SizedBox(width: 2),
                    Text('${item.totalVotesReceived} votes',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 10)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: item.isChampion
                            ? BmbColors.gold.withValues(alpha: 0.15)
                            : BmbColors.borderColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.isChampion
                            ? 'Champion'
                            : 'Eliminated R${(item.roundEliminated ?? 0) + 1}',
                        style: TextStyle(
                          color: item.isChampion
                              ? BmbColors.gold
                              : BmbColors.textTertiary,
                          fontSize: 9,
                          fontWeight: BmbFontWeights.semiBold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Percentage
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: isTop3 ? accentColor : BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              Text('R${item.roundsParticipated}',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── ROUND TABS ──────────────────────────────────────────────────
  Widget _buildRoundTab(int roundIndex) {
    final round = _data.rounds[roundIndex];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        // Round header
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BmbColors.borderColor, width: 0.5),
          ),
          child: Row(children: [
            Icon(Icons.format_list_numbered,
                color: const Color(0xFF9C27B0), size: 18),
            const SizedBox(width: 8),
            Text(round.roundName,
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.bold)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF9C27B0).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${round.matchups.length} matchups',
                  style: TextStyle(
                      color: const Color(0xFF9C27B0),
                      fontSize: 9,
                      fontWeight: BmbFontWeights.bold)),
            ),
          ]),
        ),
        // Matchup cards
        ...round.matchups
            .map((m) => _buildMatchupCard(m, roundIndex)),
      ],
    );
  }

  Widget _buildMatchupCard(VotingMatchup matchup, int roundIndex) {
    final isBye = matchup.itemB == '(bye)';
    if (isBye) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: BmbColors.borderColor.withValues(alpha: 0.3),
              width: 0.5),
        ),
        child: Row(children: [
          Icon(Icons.skip_next,
              color: BmbColors.textTertiary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${matchup.itemA}  (bye)',
                style: TextStyle(
                    color: BmbColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ),
          Text('Auto-advance',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 10)),
        ]),
      );
    }

    final aWon = matchup.winner == matchup.itemA;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: BmbColors.borderColor.withValues(alpha: 0.3),
            width: 0.5),
      ),
      child: Column(
        children: [
          // Item A row
          _buildVoteRow(
            name: matchup.itemA,
            votes: matchup.votesA,
            pct: matchup.pctA,
            isWinner: aWon,
            color: const Color(0xFF9C27B0),
          ),
          const SizedBox(height: 8),
          // Item B row
          _buildVoteRow(
            name: matchup.itemB,
            votes: matchup.votesB,
            pct: matchup.pctB,
            isWinner: !aWon,
            color: BmbColors.blue,
          ),
          const SizedBox(height: 6),
          // Total votes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people, color: BmbColors.textTertiary, size: 11),
              const SizedBox(width: 4),
              Text('${matchup.totalVotes} total votes',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoteRow({
    required String name,
    required int votes,
    required double pct,
    required bool isWinner,
    required Color color,
  }) {
    return Row(
      children: [
        // Winner indicator
        SizedBox(
          width: 20,
          child: isWinner
              ? Icon(Icons.check_circle,
                  color: BmbColors.successGreen, size: 16)
              : Icon(Icons.cancel,
                  color: BmbColors.errorRed.withValues(alpha: 0.4),
                  size: 14),
        ),
        const SizedBox(width: 6),
        // Item name
        Expanded(
          flex: 3,
          child: Text(name,
              style: TextStyle(
                color: isWinner
                    ? BmbColors.textPrimary
                    : BmbColors.textTertiary,
                fontSize: 12,
                fontWeight:
                    isWinner ? BmbFontWeights.semiBold : FontWeight.normal,
                decoration:
                    isWinner ? null : TextDecoration.lineThrough,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        // Vote bar
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: BmbColors.borderColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (pct / 100).clamp(0, 1),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      color.withValues(alpha: isWinner ? 0.8 : 0.3),
                      color.withValues(alpha: isWinner ? 0.5 : 0.15),
                    ]),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 4),
                  child: pct > 15
                      ? Text('${pct.toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: isWinner
                                  ? Colors.white
                                  : BmbColors.textTertiary,
                              fontSize: 8,
                              fontWeight: BmbFontWeights.bold))
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Vote count
        SizedBox(
          width: 50,
          child: Text('$votes',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: isWinner
                      ? BmbColors.textPrimary
                      : BmbColors.textTertiary,
                  fontSize: 11,
                  fontWeight: BmbFontWeights.semiBold)),
        ),
      ],
    );
  }
}
