import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/giveaway/data/services/giveaway_service.dart';
import 'package:bmb_mobile/features/favorites/data/services/favorite_teams_service.dart';
import 'package:bmb_mobile/features/ticker/data/services/espn_sports_service.dart';

/// Scrolling live sports ticker — the heartbeat of the BMB experience.
///
/// REAL DATA from ESPN's free public API:
///  - Live scores from games happening NOW (NBA, NFL, MLB, NHL, MLS, NCAA, EPL, PGA, UFC)
///  - Breaking news headlines (injuries, trades, suspensions)
///  - Personalized favorite-team alerts based on actual game results
///
/// INTERNAL BMB data (kept from before):
///  - Bracket winner shoutouts
///  - Giveaway winner announcements
///  - Community & charity events
///  - Pop culture bracket promos
///  - Trivia reminders
///
/// Auto-refreshes every 30 seconds when live games are detected.
class LiveSportsTicker extends StatefulWidget {
  const LiveSportsTicker({super.key});
  @override
  State<LiveSportsTicker> createState() => _LiveSportsTickerState();
}

class _LiveSportsTickerState extends State<LiveSportsTicker> {
  late ScrollController _scrollController;
  Timer? _scrollTimer;
  Timer? _refreshTimer;
  final _favService = FavoriteTeamsService();
  final _espn = EspnSportsService.instance;

  // Combined ticker items: real scores + real news + BMB internal
  final List<_TickerItem> _tickerItems = [];
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadAllData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATA LOADING — Real ESPN + BMB internal
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadAllData() async {
    // Show BMB internal items immediately while ESPN loads
    _buildBmbInternalItems();
    if (mounted) setState(() {});

    // Fetch real ESPN data in parallel
    await Future.wait([
      _loadEspnScores(),
      _loadEspnHeadlines(),
      _loadGiveawayItems(),
      _loadFavoriteTeamAlerts(),
    ]);

    _initialLoadDone = true;
    if (mounted) setState(() {});

    // Auto-refresh: every 30s if live games exist, else every 2 min
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshEspnData();
    });
  }

  Future<void> _refreshEspnData() async {
    final hadLive = _espn.hasLiveGames;
    await _espn.fetchScores(minInterval: hadLive ? 30 : 120);
    await _espn.fetchHeadlines(minInterval: 120);
    _rebuildTickerItems();
    if (mounted) setState(() {});
  }

  // ─── ESPN: Live Scores ──────────────────────────────────────────────

  Future<void> _loadEspnScores() async {
    await _espn.fetchScores(minInterval: 0); // first load, skip cache
  }

  // ─── ESPN: News Headlines ───────────────────────────────────────────

  Future<void> _loadEspnHeadlines() async {
    await _espn.fetchHeadlines(minInterval: 0);
  }

  // ─── GIVEAWAY WINNERS ───────────────────────────────────────────────

  final List<_TickerItem> _giveawayItems = [];

  Future<void> _loadGiveawayItems() async {
    final giveawayRaw = await GiveawayService.getActiveTickerItems();
    for (final item in giveawayRaw) {
      final type = item['type'] as String? ?? '';
      final name = item['winnerName'] as String? ?? 'Unknown';
      final credits = item['credits'] as int? ?? 0;
      final bracket = item['bracketName'] as String? ?? '';
      final place = item['place'] as String? ?? '';
      final multiplier = item['multiplier'] as String? ?? '';

      String text;
      if (type == 'giveaway_winner') {
        text =
            '$place place: $name wins $credits credits ($multiplier) from $bracket giveaway!';
      } else if (type == 'giveaway_leader') {
        text =
            'Leaderboard Leader $name earns $credits bonus credits from $bracket!';
      } else {
        continue;
      }

      _giveawayItems.add(_TickerItem(
        sport: 'BMB',
        text: text,
        status: 'GIVEAWAY',
        icon: Icons.celebration,
        color: BmbColors.gold,
        type: _TickerType.giveaway,
      ));
    }
  }

  // ─── FAVORITE TEAM ALERTS (real data driven) ────────────────────────

  final List<_TickerItem> _favAlerts = [];

  Future<void> _loadFavoriteTeamAlerts() async {
    await _favService.init();
    if (!_favService.alertsEnabled || !_favService.hasFavorites) return;

    // After ESPN scores load, find real games involving favorite teams
    final favTeams = _favService.allTeamNames.map((t) => t.toLowerCase()).toSet();
    for (final score in _espn.scores) {
      final awayMatch = favTeams.contains(score.awayName.toLowerCase()) ||
          favTeams.contains(score.awayAbbr.toLowerCase());
      final homeMatch = favTeams.contains(score.homeName.toLowerCase()) ||
          favTeams.contains(score.homeAbbr.toLowerCase());

      if (!awayMatch && !homeMatch) continue;

      final myTeam = awayMatch ? score.awayName : score.homeName;
      String text;
      String status;

      if (score.isLive) {
        text = '$myTeam PLAYING NOW: ${score.scoreLine} - ${score.statusShort}';
        status = 'LIVE';
      } else if (score.isFinal) {
        final myScore = awayMatch
            ? int.tryParse(score.awayScore) ?? 0
            : int.tryParse(score.homeScore) ?? 0;
        final oppScore = awayMatch
            ? int.tryParse(score.homeScore) ?? 0
            : int.tryParse(score.awayScore) ?? 0;
        if (myScore > oppScore) {
          text = '$myTeam WIN! Final: ${score.scoreLine} - Update your bracket picks!';
          status = 'W';
        } else if (myScore < oppScore) {
          text = '$myTeam lose: ${score.scoreLine} - Your bracket may be shaken up!';
          status = 'L';
        } else {
          text = '$myTeam draw: ${score.scoreLine}';
          status = 'DRAW';
        }
      } else {
        text =
            '$myTeam play today: ${score.awayAbbr} @ ${score.homeAbbr} - ${score.statusShort}';
        status = 'SOON';
      }

      _favAlerts.add(_TickerItem(
        sport: 'YOUR TEAM',
        text: text,
        status: status,
        icon: Icons.star,
        color: const Color(0xFFFFD600),
        type: _TickerType.favoriteAlert,
      ));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  REBUILD TICKER (merges all sources)
  // ═══════════════════════════════════════════════════════════════

  void _rebuildTickerItems() {
    _tickerItems.clear();

    // 1) REAL live scores from ESPN
    for (final score in _espn.scores) {
      if (score.isLive) {
        _tickerItems.add(_TickerItem(
          sport: score.league,
          text: score.scoreLine,
          status: score.tickerStatus,
          icon: _leagueIcon(score.league),
          color: _leagueColor(score.league),
          type: _TickerType.score,
          isLive: true,
        ));
      }
    }

    // 2) Favorite team alerts (real data)
    _tickerItems.addAll(_favAlerts);

    // 3) REAL breaking news / headlines from ESPN
    for (final h in _espn.headlines) {
      if (h.isBreaking) {
        String statusLabel;
        IconData icon;
        switch (h.type) {
          case HeadlineType.injury:
            statusLabel = 'INJURY';
            icon = Icons.local_hospital;
            break;
          case HeadlineType.trade:
            statusLabel = 'TRADE';
            icon = Icons.swap_horiz;
            break;
          case HeadlineType.suspension:
            statusLabel = 'SUSPENDED';
            icon = Icons.gavel;
            break;
          default:
            statusLabel = 'BREAKING';
            icon = Icons.flash_on;
        }
        _tickerItems.add(_TickerItem(
          sport: h.league,
          text: h.headline,
          status: statusLabel,
          icon: icon,
          color: BmbColors.errorRed,
          type: _TickerType.breakingNews,
        ));
      }
    }

    // 4) Giveaway winners
    _tickerItems.addAll(_giveawayItems);

    // 5) BMB internal items (winners, community, promos, trivia)
    _buildBmbInternalItems();

    // 6) REAL final scores (recent — show last few finals)
    int finalsAdded = 0;
    for (final score in _espn.scores) {
      if (score.isFinal && finalsAdded < 8) {
        _tickerItems.add(_TickerItem(
          sport: score.league,
          text: score.scoreLine,
          status: 'FINAL',
          icon: _leagueIcon(score.league),
          color: _leagueColor(score.league),
          type: _TickerType.score,
        ));
        finalsAdded++;
      }
    }

    // 7) General ESPN headlines (non-breaking)
    for (final h in _espn.headlines) {
      if (!h.isBreaking) {
        _tickerItems.add(_TickerItem(
          sport: h.league,
          text: h.headline,
          status: 'NEWS',
          icon: Icons.article,
          color: BmbColors.blue,
          type: _TickerType.news,
        ));
      }
    }

    // 8) Upcoming games (next few)
    int upcomingAdded = 0;
    for (final score in _espn.scores) {
      if (score.isUpcoming && upcomingAdded < 6) {
        _tickerItems.add(_TickerItem(
          sport: score.league,
          text: '${score.awayAbbr} @ ${score.homeAbbr}',
          status: score.statusShort,
          icon: _leagueIcon(score.league),
          color: _leagueColor(score.league).withValues(alpha: 0.7),
          type: _TickerType.upcoming,
        ));
        upcomingAdded++;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BMB INTERNAL ITEMS (winners, community, promos, trivia)
  //  These stay as app-internal data — not from ESPN
  // ═══════════════════════════════════════════════════════════════

  void _buildBmbInternalItems() {
    // Only add once — check if already present
    if (_tickerItems.any((i) => i.type == _TickerType.winner)) return;

    _tickerItems.addAll([
      // Bracket winner shoutouts
      _TickerItem(
          sport: 'BMB',
          text: 'JamSession81 wins NCAA March Madness Bracket Challenge!',
          status: 'WINNER',
          icon: Icons.emoji_events,
          color: BmbColors.gold,
          type: _TickerType.winner),
      _TickerItem(
          sport: 'BMB',
          text: 'SwishKing dominates the NBA Playoff Prediction Pool! Champion!',
          status: 'WINNER',
          icon: Icons.emoji_events,
          color: BmbColors.gold,
          type: _TickerType.winner),

      // Community & charity
      _TickerItem(
          sport: 'BMB',
          text:
              'LOCAL: BMB Charity Bracket Night at Moe\'s Tavern, Austin TX -- Sat 7 PM',
          status: 'EVENT',
          icon: Icons.volunteer_activism,
          color: const Color(0xFF66BB6A),
          type: _TickerType.community),
      _TickerItem(
          sport: 'BMB',
          text:
              'CHARITY: Back My Bracket x Habitat for Humanity -- 100% of contributions donated!',
          status: 'CHARITY',
          icon: Icons.favorite,
          color: const Color(0xFFE91E63),
          type: _TickerType.community),

      // Pop culture promos
      _TickerItem(
          sport: 'BMB',
          text:
              'NEW: Best Movie Villain Bracket is LIVE! Darth Vader vs Thanos -- vote now!',
          status: 'POP',
          icon: Icons.movie,
          color: const Color(0xFF7C4DFF),
          type: _TickerType.popCulture),
      _TickerItem(
          sport: 'BMB',
          text:
              'TRENDING: Best Pizza Topping Bracket -- Pepperoni leads but Pineapple is making a run!',
          status: 'FUN',
          icon: Icons.local_pizza,
          color: const Color(0xFFFF7043),
          type: _TickerType.popCulture),

      // Trivia
      _TickerItem(
          sport: 'BMB',
          text:
              'Daily Trivia is LIVE! Answer 15 in a row for 15 free credits. Play now!',
          status: 'TRIVIA',
          icon: Icons.quiz,
          color: const Color(0xFF9C27B0),
          type: _TickerType.trivia),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  //  AUTO-SCROLL
  // ═══════════════════════════════════════════════════════════════

  void _startAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        final current = _scrollController.offset;
        if (current >= max) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(current + 0.8);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Rebuild item list from latest ESPN data on every build
    if (_initialLoadDone) {
      _rebuildTickerItems();
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.deepNavy,
          BmbColors.midNavy,
        ]),
        border: Border(
          bottom:
              BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // LIVE label — pulses when live games exist
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _espn.hasLiveGames
                  ? BmbColors.errorRed.withValues(alpha: 0.25)
                  : BmbColors.blue.withValues(alpha: 0.15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: _espn.hasLiveGames
                            ? BmbColors.errorRed
                            : BmbColors.blue,
                        shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(
                    _espn.hasLiveGames ? 'LIVE' : 'SCORES',
                    style: TextStyle(
                        color: _espn.hasLiveGames
                            ? BmbColors.errorRed
                            : BmbColors.blue,
                        fontSize: 10,
                        fontWeight: BmbFontWeights.bold,
                        letterSpacing: 1)),
              ],
            ),
          ),
          // Scrolling items
          Expanded(
            child: _tickerItems.isEmpty
                ? Center(
                    child: Text('Loading live scores...',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 11)))
                : ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _tickerItems.length * 3, // loop 3x
                    itemBuilder: (context, index) {
                      final item =
                          _tickerItems[index % _tickerItems.length];
                      return _buildTickerChip(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTickerChip(_TickerItem item) {
    final isBreaking = item.type == _TickerType.breakingNews;
    final isGiveaway = item.type == _TickerType.giveaway;
    final isWinner = item.type == _TickerType.winner;
    final isCommunity = item.type == _TickerType.community;
    final isPopCulture = item.type == _TickerType.popCulture;
    final isTrivia = item.type == _TickerType.trivia;
    final isFavAlert = item.type == _TickerType.favoriteAlert;
    final isLiveScore = item.type == _TickerType.score && item.isLive;
    final isNews = item.type == _TickerType.news;
    final isUpcoming = item.type == _TickerType.upcoming;

    // Text color
    Color textColor = BmbColors.textPrimary;
    if (isBreaking) textColor = BmbColors.errorRed;
    if (isGiveaway || isWinner) textColor = BmbColors.gold;
    if (isCommunity) textColor = item.color;
    if (isPopCulture || isTrivia) textColor = item.color;
    if (isFavAlert) textColor = const Color(0xFFFFD600);
    if (isLiveScore) textColor = Colors.white;
    if (isNews) textColor = BmbColors.textSecondary;
    if (isUpcoming) textColor = BmbColors.textTertiary;

    // Badge color
    Color badgeColor = BmbColors.textTertiary.withValues(alpha: 0.15);
    Color badgeTextColor = BmbColors.textTertiary;
    if (isBreaking) {
      badgeColor = BmbColors.errorRed.withValues(alpha: 0.25);
      badgeTextColor = BmbColors.errorRed;
    }
    if (isGiveaway) {
      badgeColor = BmbColors.gold.withValues(alpha: 0.3);
      badgeTextColor = BmbColors.gold;
    }
    if (isWinner) {
      badgeColor = BmbColors.gold.withValues(alpha: 0.2);
      badgeTextColor = BmbColors.gold;
    }
    if (isLiveScore) {
      badgeColor = BmbColors.successGreen.withValues(alpha: 0.3);
      badgeTextColor = BmbColors.successGreen;
    }
    if (isCommunity) {
      badgeColor = item.color.withValues(alpha: 0.2);
      badgeTextColor = item.color;
    }
    if (isPopCulture) {
      badgeColor = item.color.withValues(alpha: 0.2);
      badgeTextColor = item.color;
    }
    if (isTrivia) {
      badgeColor = item.color.withValues(alpha: 0.2);
      badgeTextColor = item.color;
    }
    if (isFavAlert) {
      badgeColor = const Color(0xFFFFD600).withValues(alpha: 0.25);
      badgeTextColor = const Color(0xFFFFD600);
    }
    if (isNews) {
      badgeColor = BmbColors.blue.withValues(alpha: 0.15);
      badgeTextColor = BmbColors.blue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: item.color, size: 14),
          const SizedBox(width: 4),
          Text(item.sport,
              style: TextStyle(
                  color: item.color,
                  fontSize: 10,
                  fontWeight: BmbFontWeights.bold)),
          const SizedBox(width: 6),
          Text(item.text,
              style: TextStyle(
                color: textColor,
                fontSize: (isGiveaway || isBreaking || isFavAlert || isLiveScore)
                    ? 12
                    : 11,
                fontWeight:
                    (isWinner || isTrivia || isGiveaway || isBreaking ||
                            isFavAlert || isLiveScore)
                        ? BmbFontWeights.semiBold
                        : FontWeight.normal,
              )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(3),
              border: (isGiveaway || isBreaking || isFavAlert || isLiveScore)
                  ? Border.all(
                      color: badgeTextColor.withValues(alpha: 0.5),
                      width: 0.5)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isGiveaway) ...[
                  Icon(Icons.celebration, size: 8, color: BmbColors.gold),
                  const SizedBox(width: 2),
                ],
                if (isBreaking) ...[
                  Icon(Icons.flash_on, size: 8, color: BmbColors.errorRed),
                  const SizedBox(width: 2),
                ],
                if (isFavAlert) ...[
                  Icon(Icons.star, size: 8, color: const Color(0xFFFFD600)),
                  const SizedBox(width: 2),
                ],
                if (isLiveScore) ...[
                  Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: const BoxDecoration(
                          color: BmbColors.successGreen,
                          shape: BoxShape.circle)),
                ],
                Text(item.status,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 9,
                      fontWeight: BmbFontWeights.bold,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
              width: 1,
              height: 16,
              color: BmbColors.borderColor.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  LEAGUE → ICON / COLOR MAPPING
  // ═══════════════════════════════════════════════════════════════

  static IconData _leagueIcon(String league) {
    switch (league) {
      case 'NBA':
      case 'NCAAM':
        return Icons.sports_basketball;
      case 'NFL':
      case 'NCAAF':
        return Icons.sports_football;
      case 'MLB':
        return Icons.sports_baseball;
      case 'NHL':
        return Icons.sports_hockey;
      case 'MLS':
      case 'EPL':
        return Icons.sports_soccer;
      case 'PGA':
        return Icons.sports_golf;
      case 'UFC':
        return Icons.sports_mma;
      default:
        return Icons.sports;
    }
  }

  static Color _leagueColor(String league) {
    switch (league) {
      case 'NBA':
        return const Color(0xFFFF6B35);
      case 'NFL':
        return const Color(0xFF795548);
      case 'MLB':
        return const Color(0xFFE53935);
      case 'NHL':
        return const Color(0xFF4CAF50);
      case 'MLS':
        return const Color(0xFF9C27B0);
      case 'EPL':
        return const Color(0xFF3D195B);
      case 'PGA':
        return const Color(0xFF388E3C);
      case 'UFC':
        return const Color(0xFFD32F2F);
      case 'NCAAM':
        return const Color(0xFF1E88E5);
      case 'NCAAF':
        return const Color(0xFF795548);
      default:
        return BmbColors.blue;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════════

enum _TickerType {
  score,
  upcoming,
  winner,
  giveaway,
  breakingNews,
  news,
  favoriteAlert,
  community,
  popCulture,
  trivia,
}

class _TickerItem {
  final String sport;
  final String text;
  final String status;
  final IconData icon;
  final Color color;
  final _TickerType type;
  final bool isLive;

  const _TickerItem({
    required this.sport,
    required this.text,
    required this.status,
    required this.icon,
    required this.color,
    required this.type,
    this.isLive = false,
  });
}
