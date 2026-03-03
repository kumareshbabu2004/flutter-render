import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/squares/data/models/squares_game.dart';
import 'package:bmb_mobile/features/squares/data/services/squares_service.dart';
import 'package:bmb_mobile/features/squares/presentation/screens/squares_game_screen.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// Squares Hub — lists all available squares games by status
class SquaresHubScreen extends StatefulWidget {
  const SquaresHubScreen({super.key});

  @override
  State<SquaresHubScreen> createState() => _SquaresHubScreenState();
}

class _SquaresHubScreenState extends State<SquaresHubScreen> {
  final _squaresService = SquaresService();
  late List<SquaresGame> _games;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _games = _squaresService.generateSampleGames();
  }

  List<SquaresGame> get _filtered {
    if (_filter == 'All') return _games;
    // Squares skip "live" status — filter only upcoming/inProgress/done
    final status = {
      'Upcoming': SquaresStatus.upcoming,
      'In Progress': SquaresStatus.inProgress,
      'Completed': SquaresStatus.done,
    }[_filter];
    return _games.where((g) => g.status == status).toList();
  }

  void _openGame(SquaresGame game) {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SquaresGameScreen(existingGame: game),
    ));
  }

  void _createNew() {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const SquaresGameScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildFilterChips(),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('No squares games', style: TextStyle(color: BmbColors.textTertiary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _buildGameCard(_filtered[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNew,
        backgroundColor: BmbColors.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text('New Game', style: TextStyle(fontWeight: BmbFontWeights.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: () => Navigator.pop(context)),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.grid_4x4, color: BmbColors.gold, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Squares', style: TextStyle(color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text('${_games.length} Games', style: TextStyle(color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    // Squares skip "live" status — filter directly from upcoming to in_progress
    final filters = ['All', 'Upcoming', 'In Progress', 'Completed'];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: filters.map((f) {
          final sel = _filter == f;
          Color chipColor;
          switch (f) {
            case 'Upcoming': chipColor = BmbColors.blue;
            case 'In Progress': chipColor = BmbColors.gold;
            case 'Completed': chipColor = const Color(0xFF00BCD4);
            default: chipColor = BmbColors.blue;
          }
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? chipColor.withValues(alpha: 0.15) : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? chipColor : BmbColors.borderColor),
              ),
              child: Center(
                child: Text(f, style: TextStyle(
                  color: sel ? chipColor : BmbColors.textSecondary,
                  fontSize: 12, fontWeight: sel ? BmbFontWeights.bold : BmbFontWeights.medium,
                )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGameCard(SquaresGame game) {
    Color statusColor;
    IconData statusIcon;
    switch (game.status) {
      case SquaresStatus.upcoming:
        statusColor = BmbColors.blue;
        statusIcon = Icons.schedule;
      case SquaresStatus.live:
        statusColor = BmbColors.successGreen;
        statusIcon = Icons.flash_on;
      case SquaresStatus.inProgress:
        statusColor = BmbColors.gold;
        statusIcon = Icons.sports_score;
      case SquaresStatus.done:
        statusColor = const Color(0xFF00BCD4);
        statusIcon = Icons.check_circle;
    }

    IconData sportIcon;
    switch (game.sport) {
      case SquaresSport.football: sportIcon = Icons.sports_football;
      case SquaresSport.basketball: sportIcon = Icons.sports_basketball;
      case SquaresSport.hockey: sportIcon = Icons.sports_hockey;
      case SquaresSport.lacrosse: sportIcon = Icons.sports;
      case SquaresSport.soccer: sportIcon = Icons.sports_soccer;
      case SquaresSport.other: sportIcon = Icons.grid_4x4;
    }

    final myPicks = game.userPickCount(CurrentUserService.instance.userId);
    final winners = game.isDone ? game.getWinners() : <QuarterWinner>[];
    final myWins = winners.where((w) => w.hasWinner && CurrentUserService.instance.isCurrentUser(w.winner!.userId)).length;

    return GestureDetector(
      onTap: () => _openGame(game),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + sport row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(game.statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(sportIcon, size: 14, color: BmbColors.textTertiary),
                const SizedBox(width: 4),
                Text(game.sportLabel, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                const Spacer(),
                if (game.gameEventName != null)
                  Text(game.gameEventName!, style: TextStyle(color: BmbColors.textTertiary, fontSize: 9, fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(height: 8),

            // Game name
            Text(game.name, style: TextStyle(color: BmbColors.textPrimary, fontSize: 15, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
            const SizedBox(height: 4),
            Text('${game.team1}  vs  ${game.team2}', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),

            // Stats row
            Row(
              children: [
                _cardStat(Icons.grid_view, '${game.pickedCount}/100', 'Squares'),
                const SizedBox(width: 12),
                _cardStat(Icons.monetization_on, '${game.creditsPerSquare}c', 'Per Square'),
                const SizedBox(width: 12),
                _cardStat(Icons.emoji_events, '${game.totalPrizePool}c', 'Prize Pool'),
                const SizedBox(width: 12),
                _cardStat(Icons.person, game.hostName, 'Host'),
              ],
            ),
            const SizedBox(height: 8),

            // Bottom info row
            Row(
              children: [
                if (myPicks > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text('$myPicks squares', style: TextStyle(color: BmbColors.blue, fontSize: 9, fontWeight: BmbFontWeights.bold)),
                  ),
                  const SizedBox(width: 6),
                ],
                if (myWins > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text('$myWins wins!', style: TextStyle(color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold)),
                  ),
                ],
                // Scores preview for in_progress / done
                if (game.scores.isNotEmpty) ...[
                  const Spacer(),
                  ...game.scores.take(4).map((s) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('${s.quarter} ${s.team1Score}-${s.team2Score}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 8, fontWeight: BmbFontWeights.bold)),
                    ),
                  )),
                ] else
                  const Spacer(),
                const Icon(Icons.chevron_right, color: BmbColors.textTertiary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: BmbColors.textTertiary),
              const SizedBox(width: 3),
              Flexible(child: Text(value, style: TextStyle(color: BmbColors.textPrimary, fontSize: 11, fontWeight: BmbFontWeights.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 8)),
        ],
      ),
    );
  }
}
