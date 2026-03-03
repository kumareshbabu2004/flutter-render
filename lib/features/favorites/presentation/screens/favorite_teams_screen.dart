import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/favorites/data/services/favorite_teams_service.dart';

/// Screen where the user adds/removes favorite teams and individual athletes.
/// Organized by sport with search. Each sport shows its full roster or athlete list.
///
/// Team sports: NFL, NBA, MLB, NHL, MLS, NCAA Basketball, NCAAF
/// Individual sports: NASCAR, Tennis, Golf, UFC / MMA, Boxing
class FavoriteTeamsScreen extends StatefulWidget {
  const FavoriteTeamsScreen({super.key});
  @override
  State<FavoriteTeamsScreen> createState() => _FavoriteTeamsScreenState();
}

class _FavoriteTeamsScreenState extends State<FavoriteTeamsScreen>
    with SingleTickerProviderStateMixin {
  final _service = FavoriteTeamsService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;
  bool _loaded = false;

  final _teamSports = FavoriteTeamsService.teamCatalog.keys.toList();
  final _individualSports = FavoriteTeamsService.athleteCatalog.keys.toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    await _service.init();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
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
              _buildSearchBar(),
              _buildAlertToggle(),
              TabBar(
                controller: _tabController,
                indicatorColor: BmbColors.gold,
                labelColor: BmbColors.gold,
                unselectedLabelColor: BmbColors.textTertiary,
                labelStyle: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Teams'),
                  Tab(text: 'Athletes'),
                ],
              ),
              Expanded(
                child: _loaded
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTeamsList(),
                          _buildAthletesList(),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator(color: BmbColors.gold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final count = _service.allTeamNames.length + _service.allAthleteNames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                Text('My Favorites',
                    style: TextStyle(
                      color: BmbColors.textPrimary, fontSize: 20,
                      fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
                    )),
                Text('$count following \u2014 get score alerts for your favorites',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
        onChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search teams or athletes...',
          hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: BmbColors.textTertiary, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: BmbColors.textTertiary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: BmbColors.cardDark,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.gold)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildAlertToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.08),
          BmbColors.gold.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: BmbColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score Alerts', style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                Text('Get notified when your favorites win, lose, or get injured',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: _service.alertsEnabled,
            onChanged: (v) async {
              await _service.setAlertsEnabled(v);
              setState(() {});
            },
            activeTrackColor: BmbColors.gold.withValues(alpha: 0.5),
            thumbColor: WidgetStatePropertyAll(_service.alertsEnabled ? BmbColors.gold : BmbColors.textTertiary),
          ),
        ],
      ),
    );
  }

  // ─── TEAMS LIST ────────────────────────────────────────────────────

  Widget _buildTeamsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _teamSports.map((sport) {
        final teams = FavoriteTeamsService.teamCatalog[sport] ?? [];
        final filtered = _searchQuery.isEmpty
            ? teams
            : teams.where((t) => t.toLowerCase().contains(_searchQuery)).toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        final favCount = _service.teamsForSport(sport).length;
        return _buildSportSection(
          sport: sport,
          items: filtered,
          isIndividual: false,
          selectedCount: favCount,
        );
      }).toList(),
    );
  }

  // ─── ATHLETES LIST ─────────────────────────────────────────────────

  Widget _buildAthletesList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _individualSports.map((sport) {
        final athletes = FavoriteTeamsService.athleteCatalog[sport] ?? [];
        final filtered = _searchQuery.isEmpty
            ? athletes
            : athletes.where((a) => a.toLowerCase().contains(_searchQuery)).toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        final favCount = _service.athletesForSport(sport).length;
        return _buildSportSection(
          sport: sport,
          items: filtered,
          isIndividual: true,
          selectedCount: favCount,
        );
      }).toList(),
    );
  }

  // ─── SPORT SECTION ─────────────────────────────────────────────────

  Widget _buildSportSection({
    required String sport,
    required List<String> items,
    required bool isIndividual,
    required int selectedCount,
  }) {
    final icon = _sportIcon(sport);
    final color = _sportColor(sport);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sport header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(sport,
                  style: TextStyle(color: color, fontSize: 14, fontWeight: BmbFontWeights.bold)),
              if (selectedCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text('$selectedCount', style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                ),
              ],
            ],
          ),
        ),
        // Items grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isFav = isIndividual
                ? _service.isAthleteFavorite(sport, item)
                : _service.isTeamFavorite(sport, item);
            return GestureDetector(
              onTap: () async {
                HapticFeedback.selectionClick();
                if (isIndividual) {
                  isFav
                      ? await _service.removeAthlete(sport, item)
                      : await _service.addAthlete(sport, item);
                } else {
                  isFav
                      ? await _service.removeTeam(sport, item)
                      : await _service.addTeam(sport, item);
                }
                setState(() {});
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFav
                      ? BmbColors.gold.withValues(alpha: 0.15)
                      : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFav ? BmbColors.gold : BmbColors.borderColor,
                    width: isFav ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFav) ...[
                      Icon(Icons.star, color: BmbColors.gold, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(item,
                          style: TextStyle(
                            color: isFav ? BmbColors.gold : BmbColors.textSecondary,
                            fontSize: 12,
                            fontWeight: isFav ? BmbFontWeights.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────

  IconData _sportIcon(String sport) {
    switch (sport) {
      case 'NFL': case 'NCAAF': return Icons.sports_football;
      case 'NBA': case 'NCAA Basketball': return Icons.sports_basketball;
      case 'MLB': return Icons.sports_baseball;
      case 'NHL': return Icons.sports_hockey;
      case 'MLS': return Icons.sports_soccer;
      case 'NASCAR': return Icons.directions_car;
      case 'Tennis': return Icons.sports_tennis;
      case 'Golf': return Icons.sports_golf;
      case 'UFC / MMA': return Icons.sports_mma;
      case 'Boxing': return Icons.sports_mma;
      default: return Icons.sports;
    }
  }

  Color _sportColor(String sport) {
    switch (sport) {
      case 'NFL': case 'NCAAF': return const Color(0xFF795548);
      case 'NBA': case 'NCAA Basketball': return const Color(0xFFFF6B35);
      case 'MLB': return const Color(0xFFE53935);
      case 'NHL': return const Color(0xFF4CAF50);
      case 'MLS': return const Color(0xFF9C27B0);
      case 'NASCAR': return const Color(0xFFFF9800);
      case 'Tennis': return const Color(0xFF43A047);
      case 'Golf': return const Color(0xFF388E3C);
      case 'UFC / MMA': return const Color(0xFFD32F2F);
      case 'Boxing': return const Color(0xFFB71C1C);
      default: return BmbColors.blue;
    }
  }
}
