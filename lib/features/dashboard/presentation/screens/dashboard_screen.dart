// ignore_for_file: unused_element, no_leading_underscores_for_local_identifiers
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/dashboard/data/models/bracket_item.dart';
import 'package:bmb_mobile/features/dashboard/data/models/bracket_host.dart';
import 'package:bmb_mobile/features/dashboard/data/models/user_profile.dart';
import 'package:bmb_mobile/features/dashboard/presentation/widgets/enhanced_bracket_card.dart';
import 'package:bmb_mobile/features/dashboard/presentation/widgets/stats_card.dart';
import 'package:bmb_mobile/features/chat/presentation/screens/tournament_chat_screen.dart';
import 'package:bmb_mobile/features/chat/presentation/widgets/chat_access_gate.dart';
import 'package:bmb_mobile/features/chat/data/services/chat_access_service.dart';
import 'package:bmb_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:bmb_mobile/features/settings/presentation/screens/account_settings_screen.dart';
import 'package:bmb_mobile/features/settings/presentation/screens/help_support_screen.dart';
import 'package:bmb_mobile/features/settings/presentation/screens/about_screen.dart';
import 'package:bmb_mobile/features/bracket_detail/presentation/screens/bracket_detail_screen.dart';
import 'package:bmb_mobile/features/bmb_bucks/presentation/screens/bmb_bucks_purchase_screen.dart';
import 'package:bmb_mobile/features/subscription/presentation/screens/bmb_plus_upgrade_screen.dart';
import 'package:bmb_mobile/features/tournament/presentation/screens/tournament_join_screen.dart';
import 'package:bmb_mobile/features/bracket_builder/presentation/screens/bracket_builder_screen.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/bracket_picks_screen.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/leaderboard_screen.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/voting_leaderboard_screen.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/host_bracket_manager_screen.dart';
import 'package:bmb_mobile/features/scoring/data/services/results_service.dart';
import 'package:bmb_mobile/features/scoring/data/services/scoring_engine.dart';
import 'package:bmb_mobile/features/ticker/presentation/widgets/live_sports_ticker.dart';
import 'package:bmb_mobile/features/subscription/presentation/widgets/bmb_plus_modal.dart';
import 'package:bmb_mobile/features/referral/presentation/screens/referral_screen.dart';
import 'package:bmb_mobile/features/social/presentation/screens/social_links_screen.dart';
import 'package:bmb_mobile/features/auth/data/services/biometric_auth_service.dart';
import 'package:bmb_mobile/features/auth/data/services/bot_account_service.dart';
import 'package:bmb_mobile/core/services/firebase/firebase_auth_service.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/profile/presentation/screens/profile_photo_screen.dart';
import 'package:bmb_mobile/features/business/presentation/screens/business_hub_screen.dart';
import 'package:bmb_mobile/features/business/presentation/screens/bmb_starter_kit_screen.dart';
import 'package:bmb_mobile/features/store/presentation/screens/bmb_store_screen.dart';
import 'package:bmb_mobile/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:bmb_mobile/features/community/presentation/screens/community_chat_screen.dart';
import 'package:bmb_mobile/features/squares/presentation/screens/squares_hub_screen.dart';
import 'package:bmb_mobile/features/favorites/presentation/screens/favorite_teams_screen.dart';
import 'package:bmb_mobile/features/reviews/data/services/host_review_service.dart';
import 'package:bmb_mobile/features/reviews/presentation/screens/host_reviews_screen.dart';
import 'package:bmb_mobile/features/reviews/presentation/screens/post_tournament_review_screen.dart';
import 'package:bmb_mobile/features/support/presentation/screens/ai_support_chat_screen.dart';
import 'package:bmb_mobile/features/dashboard/data/services/bracket_board_service.dart';
import 'package:bmb_mobile/features/shopify/data/services/shopify_service.dart';
import 'package:bmb_mobile/features/shopify/presentation/screens/shopify_product_browser_screen.dart';
import 'package:bmb_mobile/features/bracket_templates/presentation/screens/bracket_template_screen.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/screens/back_it_flow_screen.dart';
import 'package:bmb_mobile/features/social/presentation/screens/social_promo_admin_screen.dart';
import 'package:bmb_mobile/features/hype_man/data/services/hype_man_service.dart';
import 'package:bmb_mobile/features/hype_man/presentation/widgets/hype_man_overlay.dart';
import 'package:bmb_mobile/features/hype_man/presentation/screens/hype_man_demo_screen.dart';
import 'package:bmb_mobile/features/companion/data/companion_service.dart';
import 'package:bmb_mobile/features/companion/presentation/widgets/floating_companion.dart';
import 'package:bmb_mobile/features/admin/presentation/screens/admin_panel_screen.dart';
import 'package:bmb_mobile/features/auto_host/presentation/widgets/auto_pilot_dashboard_widget.dart';
import 'package:bmb_mobile/features/auto_host/presentation/screens/my_templates_screen.dart';
import 'package:bmb_mobile/features/auto_host/presentation/screens/auto_pilot_wizard_screen.dart';
import 'package:bmb_mobile/features/sharing/presentation/widgets/share_bracket_sheet.dart';
import 'package:bmb_mobile/features/sharing/data/services/deep_link_service.dart';
import 'package:bmb_mobile/features/gift_cards/presentation/screens/gift_card_store_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0;
  bool _isBmbPlus = false;
  bool _isBmbVip = false;
  bool _isBusiness = false;
  bool _isAdmin = false;
  bool _hasShownPromo = false;
  int _avatarIndex = 0;
  String _bracketFilter = 'All';
  String _featuredSortBy = 'VIP First'; // active sort for featured brackets
  bool _topHostsExpanded = false; // collapsed by default
  late UserProfile _currentUser;
  late List<BracketHost> _topHosts;
  final List<CreatedBracket> _createdBrackets = [];
  final _reviewService = HostReviewService();
  final _boardService = BracketBoardService.instance;
  final _hypeMan = HypeManService.instance;
  int _newTodayCount = 0;

  /// The live Bracket Board — delegates to BracketBoardService.
  /// Only active brackets (live, upcoming, in_progress) appear here.
  List<BracketItem> get _featuredBrackets => _boardService.boardBrackets;

  @override
  void initState() {
    super.initState();
    // IMPORTANT: _initMockData is sync and sets _currentUser first.
    // _loadUserData is async and overrides fields from SharedPreferences.
    _initMockData();
    _loadUserData();
    _reviewService.seedDemoReviews();
    _recomputeTopHosts();
    _initBoardService();
    _initHypeMan();
    _loadBoardUserState();
    // ═══ PHASE 8: Check for pending bracket from deep link ═══
    _checkPendingBracketJoin();
  }

  /// If the user arrived here after signup/login with a pending shared
  /// bracket, automatically redirect to the join screen.
  Future<void> _checkPendingBracketJoin() async {
    final pendingId = await DeepLinkService.instance.consumePendingBracket();
    if (pendingId != null && pendingId.isNotEmpty && mounted) {
      // Small delay to let dashboard render first
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushNamed(context, '/join/$pendingId');
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    // Load fresh user profile from Firestore (falls back to SharedPreferences)
    await CurrentUserService.instance.load();
    final cu = CurrentUserService.instance;

    // Also sync SharedPreferences for backward compat with old widgets
    final prefs = await SharedPreferences.getInstance();

    // ─── CREDIT SYNC: Firestore is now the source of truth ──────
    final liveCredits = cu.creditsBalance > 0
        ? cu.creditsBalance
        : (prefs.getDouble('bmb_bucks_balance') ?? 50).toInt();

    if (!mounted) return;
    setState(() {
      _isBmbPlus = cu.isBmbPlus;
      _isBmbVip = cu.isBmbVip;
      _isBusiness = cu.isBusiness;
      _isAdmin = cu.isAdmin;
      _avatarIndex = cu.avatarIndex;
      // Compute accurate stats from actual bracket data
      final hostedCount = _createdBrackets.where((b) => CurrentUserService.instance.isCurrentUser(b.hostId)).length;
      final joinedFromCreated = _createdBrackets.where((b) => b.joinedPlayers.any((p) => CurrentUserService.instance.isCurrentUser(p.userId))).length;
      // Include board brackets the user joined (tracked in SharedPreferences)
      final joinedFromBoard = _joinedBoardBracketIds.length;
      final joinedCount = joinedFromCreated + joinedFromBoard;
      final winCount = _createdBrackets.where((b) => b.status == 'done' && b.joinedPlayers.isNotEmpty && b.joinedPlayers.first.userId == cu.userId && b.joinedPlayers.first.hasMadePicks).length;

      // Rebuild current user from Firestore-backed CurrentUserService
      _currentUser = UserProfile(
        id: cu.userId,
        username: cu.displayName.isNotEmpty ? cu.displayName : 'BracketKing',
        displayName: cu.displayName.isNotEmpty ? cu.displayName : null,
        bio: 'Sports fanatic. Bracket builder. Competitor.',
        rating: 4.5,
        reviewCount: 23,
        isVerified: true,
        isBmbPlus: cu.isBmbPlus,
        isBmbVip: cu.isBmbVip,
        isAdmin: cu.isAdmin,
        stateAbbr: cu.stateAbbr.isNotEmpty ? cu.stateAbbr : 'TX',
        city: cu.city.isNotEmpty ? cu.city : 'Houston',
        streetAddress: cu.street.isNotEmpty ? cu.street : null,
        zipCode: cu.zip.isNotEmpty ? cu.zip : null,
        totalPools: hostedCount + joinedCount,
        wins: winCount,
        earnings: 0.0, // Will be updated from Firestore
        bmbCredits: cu.isAdmin ? 999999 : liveCredits,
        hostedTournaments: hostedCount,
        joinedTournaments: joinedCount,
      );
    });

    // Load user's real brackets from Firestore in the background
    _loadFirestoreBrackets();

    // ── Show promo modal AFTER prefs are loaded so _isBmbPlus is correct ──
    _showPromoModalIfNeeded();
  }

  /// Load real brackets from Firestore and inject them into the board.
  /// Phase 2: Now loads full user stats, injects active brackets into the
  /// BracketBoardService, and loads real top hosts from Firestore.
  Future<void> _loadFirestoreBrackets() async {
    try {
      final firestoreSvc = FirestoreService.instance;
      final cu = CurrentUserService.instance;

      // ═══ 1. LOAD FULL USER STATS FROM FIRESTORE ═══
      final userStats = await firestoreSvc.getUserStats(cu.userId);

      // ═══ 2. LOAD USER'S OWN BRACKETS + ENTRIES ═══
      final userBrackets = await firestoreSvc.getUserBrackets(cu.userId);
      final userEntries = await firestoreSvc.getUserEntries(cu.userId);

      // ═══ 3. LOAD ALL ACTIVE BRACKETS FOR THE BOARD ═══
      final activeBrackets = await firestoreSvc.getActiveBrackets();

      // ═══ 4. LOAD REAL TOP HOSTS ═══
      final topHostsData = await firestoreSvc.getTopHosts(limit: 8);

      if (!mounted) return;

      // ─── Inject active Firestore brackets into the Bracket Board ───
      _boardService.injectFirestoreBrackets(activeBrackets);

      // ─── Convert user's own brackets to CreatedBracket for "My Brackets" ───
      for (final fb in userBrackets) {
        final alreadyExists = _createdBrackets.any((cb) => cb.id == fb['doc_id']);
        if (!alreadyExists) {
          _createdBrackets.insert(0, CreatedBracket(
            id: fb['doc_id'] ?? '',
            name: fb['name'] as String? ?? 'Untitled Bracket',
            templateId: 'custom',
            sport: fb['sport'] as String? ?? 'General',
            teamCount: (fb['team_count'] as num?)?.toInt() ?? 8,
            teams: List<String>.from(fb['teams'] ?? []),
            isFreeEntry: (fb['entry_fee'] as num? ?? 0) == 0,
            entryDonation: (fb['entry_fee'] as num? ?? 0).toInt(),
            prizeType: fb['prize_type'] as String? ?? 'custom',
            prizeDescription: fb['prize_description'] as String? ?? '',
            status: fb['status'] as String? ?? 'draft',
            createdAt: _timestampToDateTime(fb['created_at']),
            hostId: cu.userId,
            hostName: cu.displayName,
            hostState: cu.stateAbbr,
            participantCount: (fb['entrants_count'] as num?)?.toInt() ?? 0,
            bracketType: fb['bracket_type'] as String? ?? 'standard',
          ));
        }
      }

      // ─── Merge real top hosts into _topHosts list ───
      if (topHostsData.isNotEmpty) {
        final firestoreHosts = topHostsData.map((h) {
          return BracketHost(
            id: h['user_id'] as String? ?? '',
            name: h['display_name'] as String? ?? 'Unknown',
            rating: 4.5, // will be recalculated by review service
            reviewCount: 0,
            isVerified: true,
            isTopHost: (h['brackets_created'] as int? ?? 0) >= 3,
            location: h['state'] as String? ?? '',
            totalHosted: h['brackets_created'] as int? ?? 0,
          );
        }).toList();

        // Merge: keep existing mock hosts, add Firestore hosts that aren't already in list
        for (final fh in firestoreHosts) {
          final alreadyExists = _topHosts.any((h) => h.id == fh.id);
          if (!alreadyExists) {
            _topHosts.add(fh);
          }
        }
        _recomputeTopHosts();
      }

      // ─── Update user profile with real Firestore stats ───
      final firestoreCredits = userStats['credits_balance'] as int? ?? 0;
      final firestoreWins = userStats['wins'] as int? ?? 0;
      final firestoreEarnings = (userStats['total_winnings'] as num?)?.toDouble() ?? 0;

      // Merge Firestore real stats with local bracket data
      final localHosted = _createdBrackets.where((b) => cu.isCurrentUser(b.hostId)).length;
      final localJoined = _createdBrackets.where((b) => b.joinedPlayers.any((p) => cu.isCurrentUser(p.userId))).length;
      final realHosted = userBrackets.isNotEmpty ? userBrackets.length : localHosted;
      final realJoined = userEntries.isNotEmpty ? userEntries.length : localJoined;

      setState(() {
        _currentUser = UserProfile(
          id: _currentUser.id,
          username: _currentUser.username,
          displayName: _currentUser.displayName,
          bio: _currentUser.bio,
          rating: _currentUser.rating,
          reviewCount: _currentUser.reviewCount,
          isVerified: _currentUser.isVerified,
          isBmbPlus: _currentUser.isBmbPlus,
          isBmbVip: _currentUser.isBmbVip,
          isAdmin: _currentUser.isAdmin,
          stateAbbr: _currentUser.stateAbbr,
          city: _currentUser.city,
          streetAddress: _currentUser.streetAddress,
          zipCode: _currentUser.zipCode,
          totalPools: realHosted + realJoined,
          wins: firestoreWins > 0 ? firestoreWins : _currentUser.wins,
          earnings: firestoreEarnings > 0 ? firestoreEarnings : _currentUser.earnings,
          bmbCredits: _isAdmin ? 999999 : (firestoreCredits > 0 ? firestoreCredits : _currentUser.bmbCredits),
          hostedTournaments: realHosted,
          joinedTournaments: realJoined,
        );
      });
    } catch (e) {
      // Silently fail — mock data remains as fallback
      if (kDebugMode) debugPrint('Dashboard: Firestore load failed: $e');
    }
  }

  /// Helper to safely convert Firestore Timestamp to DateTime.
  /// Handles: DateTime, ISO 8601 string, and cloud_firestore Timestamp.
  DateTime _timestampToDateTime(dynamic ts) {
    if (ts == null) return DateTime.now();
    if (ts is DateTime) return ts;
    if (ts is String) {
      return DateTime.tryParse(ts) ?? DateTime.now();
    }
    // cloud_firestore Timestamp
    try {
      return (ts as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PHASE 3: FIRESTORE BRACKET SYNC HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Update an existing bracket in Firestore. Silently fails if bracket
  /// has a local-only ID (starts with 'b_' or 'sample_').
  Future<void> _syncBracketToFirestore(String bracketId, Map<String, dynamic> data) async {
    // Skip local-only brackets that were never persisted to Firestore
    if (bracketId.startsWith('b_') || bracketId.startsWith('sample_') ||
        bracketId.startsWith('giveaway_test_')) {
      return;
    }
    try {
      await FirestoreService.instance.updateBracket(bracketId, data);
      if (kDebugMode) debugPrint('Bracket $bracketId synced to Firestore');
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore bracket sync failed: $e');
    }
  }

  /// Delete a bracket from Firestore by doc ID.
  Future<void> _deleteBracketFromFirestore(String bracketId) async {
    if (bracketId.startsWith('b_') || bracketId.startsWith('sample_') ||
        bracketId.startsWith('giveaway_test_')) {
      return;
    }
    try {
      await FirestoreService.instance.updateBracket(bracketId, {
        'status': 'deleted',
      });
      if (kDebugMode) debugPrint('Bracket $bracketId marked deleted in Firestore');
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore bracket delete failed: $e');
    }
  }

  /// Record a bracket join in Firestore — creates bracket_entry doc and
  /// deducts credits from the user's balance if the entry has a fee.
  /// Note: Primary join logic is in TournamentJoinScreen._joinTournament().
  /// This method is available for programmatic joins from the dashboard.
  Future<void> _recordJoinInFirestore(String bracketId, {int creditCost = 0}) async {
    final cu = CurrentUserService.instance;
    try {
      // 1. Create bracket entry document
      await FirestoreService.instance.submitBracketEntry({
        'bracket_id': bracketId,
        'user_id': cu.userId,
        'display_name': cu.displayName,
        'state': cu.stateAbbr,
        'joined_at': DateTime.now().toUtc(),
        'has_made_picks': false,
      });

      // 2. Deduct credits if entry has a fee
      if (creditCost > 0) {
        await FirestoreService.instance.addCreditTransaction({
          'user_id': cu.userId,
          'amount': -creditCost,
          'type': 'bracket_entry',
          'description': 'Entry fee for bracket $bracketId',
          'timestamp': DateTime.now().toUtc(),
        });

        // Update user credits balance
        final currentBalance = cu.creditsBalance;
        final newBalance = currentBalance - creditCost;
        await FirestoreService.instance.updateUser(cu.userId, {
          'credits_balance': newBalance > 0 ? newBalance : 0,
        });
      }

      if (kDebugMode) debugPrint('Join recorded in Firestore for bracket $bracketId');
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore join record failed: $e');
    }
  }

  /// Trigger the appropriate first-visit modal based on the user's tier.
  /// Called once after _loadUserData() completes so the flags are accurate.
  void _showPromoModalIfNeeded() {
    if (_hasShownPromo) return;
    _hasShownPromo = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isBmbPlus && !_isBmbVip) {
        // BMB+ members who are NOT yet VIP see VIP upsell (2 credits/mo)
        BmbPlusModal.showVipUpsell(context, onActivated: () {
          _loadUserData();
        });
      } else if (!_isBmbPlus) {
        // Non-BMB+ users see hosting promo ("Try the Bracket Builder")
        BmbPlusModal.showHostingPromo(context);
      }
      // BMB+ VIP users see NO modal — they're fully upgraded
    });
  }

  void _initMockData() {
    // Mock hosts per the screenshots
    const nateHost = BracketHost(
      id: 'host_nate',
      name: 'NateDoubleDown',
      rating: 4.8,
      reviewCount: 151,
      isVerified: true,
      isTopHost: true,
      location: 'IL',
      totalHosted: 201,
    );
    const slickHost = BracketHost(
      id: 'host_slick',
      name: 'SlickRick',
      rating: 4.6,
      reviewCount: 42,
      isVerified: true,
      isTopHost: true,
      location: 'CA',
      totalHosted: 78,
    );
    const courtneyHost = BracketHost(
      id: 'host_courtney',
      name: 'CourtneyWins',
      rating: 4.7,
      reviewCount: 39,
      isVerified: true,
      isTopHost: true,
      location: 'NY',
      totalHosted: 51,
    );
    const bmbOfficial = BracketHost(
      id: 'host_bmb',
      name: 'Back My Bracket',
      rating: 5.0,
      reviewCount: 320,
      isVerified: true,
      isTopHost: false,
      location: 'US',
      totalHosted: 500,
    );

    // ─── REALISTIC BOT HOSTS (with profile photos) ───
    const marcusHost = BracketHost(
      id: 'bot_marcus',
      name: 'Marc_Buckets',
      profileImageUrl: 'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?auto=compress&cs=tinysrgb&w=256&h=256&fit=crop',
      rating: 4.9,
      reviewCount: 67,
      isVerified: true,
      isTopHost: true,
      location: 'TX',
      totalHosted: 42,
    );
    const jessHost = BracketHost(
      id: 'bot_jess',
      name: 'Queen_of_Upsets',
      profileImageUrl: 'https://images.pexels.com/photos/733872/pexels-photo-733872.jpeg?auto=compress&cs=tinysrgb&w=256&h=256&fit=crop',
      rating: 4.7,
      reviewCount: 53,
      isVerified: true,
      isTopHost: true,
      location: 'FL',
      totalHosted: 35,
    );

    _topHosts = [nateHost, marcusHost, jessHost, slickHost, courtneyHost, bmbOfficial];

    // No longer need static seed brackets — the board service generates them

    final _cuSvc = CurrentUserService.instance;
    _currentUser = UserProfile(
      id: _cuSvc.userId,
      username: _cuSvc.displayName.isNotEmpty ? _cuSvc.displayName : 'BracketKing',
      displayName: 'Bracket King',
      bio: 'Sports fanatic. Bracket builder. Competitor.',
      rating: 4.5,
      reviewCount: 23,
      isVerified: true,
      isBmbPlus: false,
      isAdmin: _cuSvc.isAdmin,
      stateAbbr: 'TX',
      city: 'Houston',
      totalPools: 0, // Will be computed after _seedSampleBrackets
      wins: 0,
      earnings: 0.0,
      bmbCredits: _cuSvc.isAdmin ? 999999 : 50,
      hostedTournaments: 0,
      joinedTournaments: 0,
    );

    // ─── SAMPLE BRACKETS FOR TESTING ─────────────────────────────────
    // Pre-seed "My Brackets" with playable sample brackets so the picks
    // flow, scoring, leaderboard, and host review can all be tested.
    _seedSampleBrackets();

    // ── Recompute stats from seeded brackets ──
    final hostedCount = _createdBrackets.where((b) =>
        b.hostId == 'u1' || b.hostId == _cuSvc.userId).length;
    final joinedCount = _createdBrackets.where((b) =>
        b.joinedPlayers.any((p) => p.userId == 'u1' || p.userId == _cuSvc.userId)).length;
    final doneWins = _createdBrackets.where((b) =>
        b.status == 'done' && (b.hostId == 'u1' || b.hostId == _cuSvc.userId)).length;
    _currentUser = UserProfile(
      id: _currentUser.id,
      username: _currentUser.username,
      displayName: _currentUser.displayName,
      bio: _currentUser.bio,
      rating: _currentUser.rating,
      reviewCount: _currentUser.reviewCount,
      isVerified: _currentUser.isVerified,
      isBmbPlus: _currentUser.isBmbPlus,
      isAdmin: _currentUser.isAdmin,
      stateAbbr: _currentUser.stateAbbr,
      city: _currentUser.city,
      totalPools: hostedCount + joinedCount,
      wins: doneWins,
      earnings: _currentUser.earnings,
      bmbCredits: _currentUser.bmbCredits,
      hostedTournaments: hostedCount,
      joinedTournaments: joinedCount,
    );
  }

  void _seedSampleBrackets() {
    final now = DateTime.now();

    // 1) LIVE 8-team NBA Playoff bracket — tap "Make My Picks"
    _createdBrackets.add(CreatedBracket(
      id: 'sample_live_1',
      name: 'NBA Playoff Showdown',
      templateId: 'custom',
      sport: 'Basketball',
      teamCount: 8,
      teams: [
        'Boston Celtics',
        'Miami Heat',
        'Denver Nuggets',
        'LA Lakers',
        'Milwaukee Bucks',
        'Philadelphia 76ers',
        'Phoenix Suns',
        'Golden State Warriors',
      ],
      isFreeEntry: true,
      entryDonation: 0,
      prizeType: 'custom',
      prizeDescription: '500 BMB Credits to the winner!',
      status: 'live',
      createdAt: now.subtract(const Duration(hours: 6)),
      hostId: 'host_nate',
      hostName: 'NateDoubleDown',
      hostState: 'IL',
      participantCount: 24,
      bracketType: 'standard',
      tieBreakerGame: 'NBA Finals Game 7',
      autoHost: false,
      minPlayers: 2,
      creditsDeducted: true,
      hasGiveaway: true,
      giveawayWinnerCount: 2,
      giveawayTokensPerWinner: 25,
      joinedPlayers: [
        JoinedPlayer(userId: 'u1', userName: 'BracketKing', userState: 'TX', joinedAt: now.subtract(const Duration(hours: 4)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_marcus', userName: 'Marc_Buckets', userState: 'TX', joinedAt: now.subtract(const Duration(hours: 3)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_jess', userName: 'Queen_of_Upsets', userState: 'FL', joinedAt: now.subtract(const Duration(hours: 2))),
        JoinedPlayer(userId: 'bot_1', userName: 'HoopsKing', userState: 'CA', joinedAt: now.subtract(const Duration(hours: 1))),
      ],
    ));

    // 2) LIVE 16-team NCAA Pick'Em — more complex picks experience
    _createdBrackets.add(CreatedBracket(
      id: 'sample_live_2',
      name: 'March Madness Sweet 16',
      templateId: 'custom',
      sport: 'Basketball',
      teamCount: 16,
      teams: [
        '(1) UConn', '(16) Stetson',
        '(8) Memphis', '(9) FAU',
        '(5) San Diego St', '(12) UAB',
        '(4) Alabama', '(13) Charleston',
        '(6) Clemson', '(11) New Mexico',
        '(3) Baylor', '(14) Colgate',
        '(7) Missouri', '(10) Utah St',
        '(2) Arizona', '(15) Long Beach St',
      ],
      isFreeEntry: false,
      entryDonation: 10,
      prizeType: 'custom',
      prizeDescription: '1000 credits to 1st place!',
      status: 'live',
      createdAt: now.subtract(const Duration(hours: 12)),
      hostId: 'host_slick',
      hostName: 'SlickRick',
      hostState: 'CA',
      participantCount: 48,
      bracketType: 'pickem',
      tieBreakerGame: 'National Championship',
      autoHost: true,
      minPlayers: 4,
      creditsDeducted: true,
      joinedPlayers: [
        JoinedPlayer(userId: 'u1', userName: 'BracketKing', userState: 'TX', joinedAt: now.subtract(const Duration(hours: 10))),
        JoinedPlayer(userId: 'bot_marcus', userName: 'Marc_Buckets', userState: 'TX', joinedAt: now.subtract(const Duration(hours: 9))),
        JoinedPlayer(userId: 'bot_jess', userName: 'Queen_of_Upsets', userState: 'FL', joinedAt: now.subtract(const Duration(hours: 8))),
      ],
    ));

    // 3) DONE 8-team NFL bracket — paid with GIVEAWAY enabled
    _createdBrackets.add(CreatedBracket(
      id: 'sample_done_1',
      name: 'NFL Playoff Bracket Challenge',
      templateId: 'custom',
      sport: 'Football',
      teamCount: 8,
      teams: [
        'Kansas City Chiefs',
        'Buffalo Bills',
        'Baltimore Ravens',
        'Houston Texans',
        'San Francisco 49ers',
        'Detroit Lions',
        'Dallas Cowboys',
        'Green Bay Packers',
      ],
      isFreeEntry: false,
      entryDonation: 25,
      prizeType: 'custom',
      prizeDescription: 'BMB Official T-Shirt + 250 credits',
      status: 'done',
      createdAt: now.subtract(const Duration(days: 3)),
      hostId: 'u1',
      hostName: 'BracketKing',
      hostState: 'TX',
      participantCount: 32,
      bracketType: 'standard',
      tieBreakerGame: 'Super Bowl LVIII',
      autoHost: true,
      minPlayers: 2,
      creditsDeducted: true,
      hasGiveaway: true,
      giveawayWinnerCount: 3,
      giveawayTokensPerWinner: 50,
      completedAt: now.subtract(const Duration(minutes: 20)),
      joinedPlayers: [
        JoinedPlayer(userId: 'u1', userName: 'BracketKing', userState: 'TX', joinedAt: now.subtract(const Duration(days: 6)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_courtney', userName: 'CourtneyWins', userState: 'NY', joinedAt: now.subtract(const Duration(days: 5)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_3', userName: 'GoldenPick', userState: 'FL', joinedAt: now.subtract(const Duration(days: 5)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_4', userName: 'ClutchKing', userState: 'OH', joinedAt: now.subtract(const Duration(days: 4)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_5', userName: 'TD_Machine', userState: 'IL', joinedAt: now.subtract(const Duration(days: 4)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_6', userName: 'PuntKing', userState: 'PA', joinedAt: now.subtract(const Duration(days: 3)), hasMadePicks: true),
      ],
    ));

    // 3b) FRESH DONE bracket with GIVEAWAY — for re-testing the spinner
    //     Uses a unique timestamp-based ID so giveaway is never "already run"
    _createdBrackets.add(CreatedBracket(
      id: 'giveaway_test_${now.millisecondsSinceEpoch}',
      name: 'NBA All-Star Weekend Bracket',
      templateId: 'custom',
      sport: 'Basketball',
      teamCount: 8,
      teams: [
        'Team LeBron',
        'Team Giannis',
        'Team Curry',
        'Team Durant',
        'Team Tatum',
        'Team Luka',
        'Team Jokic',
        'Team Edwards',
      ],
      isFreeEntry: false,
      entryDonation: 15,
      prizeType: 'custom',
      prizeDescription: 'Jordan 4 Retros + 300 BMB Credits',
      status: 'done',
      createdAt: now.subtract(const Duration(hours: 8)),
      hostId: 'u1',
      hostName: 'You',
      hostState: 'IL',
      participantCount: 18,
      bracketType: 'standard',
      tieBreakerGame: 'All-Star Game Final Score',
      autoHost: true,
      minPlayers: 4,
      creditsDeducted: true,
      hasGiveaway: true,
      giveawayWinnerCount: 2,
      giveawayTokensPerWinner: 30,
      completedAt: now.subtract(const Duration(minutes: 5)),
      joinedPlayers: [
        JoinedPlayer(userId: 'u1', userName: 'You', userState: 'IL', joinedAt: now.subtract(const Duration(hours: 7)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_marcus', userName: 'Marc_Buckets', userState: 'TX', joinedAt: now.subtract(const Duration(hours: 6)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_jess', userName: 'Queen_of_Upsets', userState: 'FL', joinedAt: now.subtract(const Duration(hours: 5)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_courtney', userName: 'CourtneyWins', userState: 'NY', joinedAt: now.subtract(const Duration(hours: 4)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_7', userName: 'SlamDunkSam', userState: 'CA', joinedAt: now.subtract(const Duration(hours: 3)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_8', userName: 'HoopsQueen', userState: 'GA', joinedAt: now.subtract(const Duration(hours: 2)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_9', userName: 'AirBall_Andy', userState: 'OH', joinedAt: now.subtract(const Duration(hours: 1)), hasMadePicks: true),
        JoinedPlayer(userId: 'bot_10', userName: 'FastBreak_Flo', userState: 'MI', joinedAt: now.subtract(const Duration(minutes: 30)), hasMadePicks: true),
      ],
    ));

    // 4) DONE 4-team quick bracket — another completed one for review testing
    _createdBrackets.add(CreatedBracket(
      id: 'sample_done_2',
      name: 'Best BBQ in Texas - Vote',
      templateId: 'custom',
      sport: 'Voting',
      teamCount: 4,
      teams: [
        'Franklin BBQ (Austin)',
        'Snow\'s BBQ (Lexington)',
        'Pecan Lodge (Dallas)',
        'Goldee\'s BBQ (Fort Worth)',
      ],
      isFreeEntry: true,
      entryDonation: 0,
      prizeType: 'none',
      status: 'done',
      createdAt: now.subtract(const Duration(days: 7)),
      hostId: 'host_bmb',
      hostName: 'Back My Bracket',
      hostState: 'US',
      participantCount: 156,
      bracketType: 'voting',
      tieBreakerGame: 'Final Taste Test',
      joinedPlayers: [
        JoinedPlayer(userId: 'u1', userName: 'BracketKing', userState: 'TX', joinedAt: now.subtract(const Duration(days: 8))),
      ],
    ));

    // 5a) LIVE bracket hosted by Marc_Buckets (bot)
    _createdBrackets.add(CreatedBracket(
      id: 'sample_marcus_1',
      name: 'Texas NFL Showdown',
      templateId: 'custom',
      sport: 'Football',
      teamCount: 8,
      teams: [
        'Houston Texans',
        'Dallas Cowboys',
        'Kansas City Chiefs',
        'Buffalo Bills',
        'Baltimore Ravens',
        'Detroit Lions',
        'San Francisco 49ers',
        'Green Bay Packers',
      ],
      isFreeEntry: false,
      entryDonation: 5,
      prizeType: 'custom',
      prizeDescription: '200 credits to the winner!',
      status: 'live',
      createdAt: now.subtract(const Duration(hours: 4)),
      hostId: 'bot_marcus',
      hostName: 'Marc_Buckets',
      hostState: 'TX',
      participantCount: 38,
      bracketType: 'standard',
      tieBreakerGame: 'Super Bowl LVIX',
      autoHost: false,
      minPlayers: 4,
      creditsDeducted: true,
      joinedPlayers: [
        JoinedPlayer(userId: 'u1', userName: 'BracketKing', userState: 'TX', joinedAt: now.subtract(const Duration(hours: 3))),
        JoinedPlayer(userId: 'bot_jess', userName: 'Queen_of_Upsets', userState: 'FL', joinedAt: now.subtract(const Duration(hours: 2))),
        JoinedPlayer(userId: 'bot_jam81', userName: 'JamSession81', userState: 'IL', joinedAt: now.subtract(const Duration(hours: 1))),
      ],
    ));

    // 5b) LIVE bracket hosted by Queen_of_Upsets (bot)
    _createdBrackets.add(CreatedBracket(
      id: 'sample_jess_1',
      name: 'March Madness Upset Special',
      templateId: 'custom',
      sport: 'Basketball',
      teamCount: 16,
      teams: [
        '(1) Duke', '(16) Robert Morris',
        '(8) Florida', '(9) Creighton',
        '(5) Marquette', '(12) McNeese',
        '(4) Auburn', '(13) Yale',
        '(6) Michigan St', '(11) Drake',
        '(3) Wisconsin', '(14) Lipscomb',
        '(7) Texas Tech', '(10) Arkansas',
        '(2) Tennessee', '(15) Wofford',
      ],
      isFreeEntry: true,
      entryDonation: 0,
      prizeType: 'custom',
      prizeDescription: '500 BMB Credits + bragging rights!',
      status: 'live',
      createdAt: now.subtract(const Duration(hours: 8)),
      hostId: 'bot_jess',
      hostName: 'Queen_of_Upsets',
      hostState: 'FL',
      participantCount: 72,
      bracketType: 'pickem',
      tieBreakerGame: 'National Championship Game',
      autoHost: true,
      minPlayers: 8,
      creditsDeducted: true,
      joinedPlayers: [
        JoinedPlayer(userId: 'u1', userName: 'BracketKing', userState: 'TX', joinedAt: now.subtract(const Duration(hours: 7))),
        JoinedPlayer(userId: 'bot_marcus', userName: 'Marc_Buckets', userState: 'TX', joinedAt: now.subtract(const Duration(hours: 6))),
        JoinedPlayer(userId: 'bot_swish', userName: 'SwishKing', userState: 'CA', joinedAt: now.subtract(const Duration(hours: 5))),
      ],
    ));

    // 5c) LIVE bracket where current user has NOT joined — shows "Join Now"
    _createdBrackets.add(CreatedBracket(
      id: 'sample_notjoined_1',
      name: 'Premier League Fantasy Bracket',
      templateId: 'custom',
      sport: 'Soccer',
      teamCount: 8,
      teams: [
        'Manchester City', 'Arsenal', 'Liverpool', 'Chelsea',
        'Newcastle', 'Tottenham', 'Aston Villa', 'Man United',
      ],
      isFreeEntry: false,
      entryDonation: 10,
      prizeType: 'custom',
      prizeDescription: '400 credits to the winner!',
      status: 'live',
      createdAt: now.subtract(const Duration(hours: 2)),
      hostId: 'bot_marcus',
      hostName: 'Marc_Buckets',
      hostState: 'TX',
      participantCount: 18,
      bracketType: 'standard',
      tieBreakerGame: 'Champions League Final',
      autoHost: false,
      minPlayers: 4,
      creditsDeducted: true,
      joinedPlayers: [
        JoinedPlayer(userId: 'bot_jess', userName: 'Queen_of_Upsets', userState: 'FL', joinedAt: now.subtract(const Duration(hours: 1))),
        JoinedPlayer(userId: 'bot_swish', userName: 'SwishKing', userState: 'CA', joinedAt: now.subtract(const Duration(minutes: 30))),
      ],
    ));

    // 6) IN_PROGRESS bracket — shows locked state with View My Picks
    _createdBrackets.add(CreatedBracket(
      id: 'sample_inprogress_1',
      name: 'MLB World Series Picks',
      templateId: 'custom',
      sport: 'Baseball',
      teamCount: 8,
      teams: [
        'LA Dodgers',
        'Atlanta Braves',
        'Houston Astros',
        'Texas Rangers',
        'Philadelphia Phillies',
        'Arizona Diamondbacks',
        'Minnesota Twins',
        'Tampa Bay Rays',
      ],
      isFreeEntry: false,
      entryDonation: 5,
      prizeType: 'custom',
      prizeDescription: '300 credits',
      status: 'in_progress',
      createdAt: now.subtract(const Duration(days: 1)),
      hostId: 'host_nate',
      hostName: 'NateDoubleDown',
      hostState: 'IL',
      participantCount: 16,
      bracketType: 'standard',
      tieBreakerGame: 'World Series Game 7',
      autoHost: false,
      minPlayers: 4,
      creditsDeducted: true,
      joinedPlayers: [
        JoinedPlayer(userId: 'u1', userName: 'BracketKing', userState: 'TX', joinedAt: now.subtract(const Duration(days: 2))),
      ],
    ));
  }

  // ─── HYPE MAN INIT ──────────────────────────────────────────────────
  Future<void> _initHypeMan() async {
    await _hypeMan.init();
    // Fire the "app opened" trigger after a short delay so the UI is ready
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _hypeMan.trigger(HypeTrigger.appOpened);
    });
  }

  // ─── BRACKET BOARD SERVICE INIT ──────────────────────────────────────
  Future<void> _initBoardService() async {
    // Board service generates brackets dynamically — no seeds needed
    await _boardService.init();
    // Check for daily refresh
    final added = await _boardService.triggerDailyRefresh();
    if (mounted) {
      setState(() {
        _newTodayCount = _boardService.newTodayCount;
      });
      if (added > 0) {
        _showSnack('$added new brackets added to the board today!');
      }
    }
  }

  // ─── SEED BRACKETS (legacy — no longer used; board is 100% dynamic) ──
  // The bracket board service now generates all brackets from its template pool.
  // ignore: unused_field
  final List<BracketItem> _seedBrackets = [];

  // Legacy placeholder for removed seed data. Old static brackets (b1..b13)
  // have been replaced by BracketBoardService._generateFreshBoard().
  // Keeping a dummy block so the line count stays stable for downstream refs.
  //
  // Original static seed brackets removed: b1 (March Madness), b2 (NFL Playoff),
  // b3 (Pizza Vote), b4 (BMB Official), b5 (Golf), b6 (MLB), b_marcus_1/2,
  // b_jess_1/2, b7 (NHL), b8 (NBA Finals), b_pickem_nba/nfl/mm,
  // b_squares_nba/sb/mnf, b_props_nba/nfl, b_survivor_nfl, b_trivia_nba,
  // b9..b13_done (archived)
  //
  // All brackets are now generated dynamically by BracketBoardService with:
  //  - Configurable visibility durations per status
  //  - Auto-lifecycle progression (upcoming→live→in_progress→done)
  //  - Continuous rotation with new brackets added every cycle
  //  - Auto-archival when brackets expire their TTL
  // Board is now 100% dynamic — all brackets generated by BracketBoardService.
  // ~450 lines of static BracketItem declarations removed.
  // See BracketBoardService._templatePool for the full bracket template catalog.

  /// Recompute isTopHost dynamically from review data instead of hardcoded values.
  /// Also sorts _topHosts so highest-ranked appear first.
  /// Top hosts get front placement without needing VIP tag.
  void _recomputeTopHosts() {
    _topHosts = _topHosts.map((h) {
      final avg = _reviewService.getAverageRating(h.id);
      final count = _reviewService.getReviewCount(h.id);
      final isTop = _reviewService.isTopHost(h.id, h.totalHosted);
      return BracketHost(
        id: h.id,
        name: h.name,
        profileImageUrl: h.profileImageUrl,
        rating: avg > 0 ? double.parse(avg.toStringAsFixed(1)) : h.rating,
        reviewCount: count > 0 ? count : h.reviewCount,
        isVerified: h.isVerified,
        isTopHost: isTop,
        location: h.location,
        totalHosted: h.totalHosted,
      );
    }).toList();
    // Sort: Top hosts first, then by rating descending
    _topHosts.sort((a, b) {
      if (a.isTopHost && !b.isTopHost) return -1;
      if (!a.isTopHost && b.isTopHost) return 1;
      return b.rating.compareTo(a.rating);
    });

    // Sort board brackets via service
    _boardService.sortBoard(_featuredSortBy);
  }

  @override
  Widget build(BuildContext context) {
    // Promo modal is now triggered from _loadUserData() after prefs are
    // loaded, so the correct _isBmbPlus / _isBmbVip state is available.
    return HypeManOverlay(
      key: HypeManOverlay.globalKey,
      child: Scaffold(
      body: Stack(
        children: [
        Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Live sports ticker at top
              const LiveSportsTicker(),
              Expanded(
                child: IndexedStack(
                  index: _currentNavIndex,
                  children: [
                    _buildHomeTab(),
                    _buildExploreTab(),
                    _buildMyBracketsTab(),
                    _buildProfileTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // ── Floating BMB Companion ──
      if (CompanionService.instance.hasChosenCompanion)
        FloatingCompanion(
          message: _companionDashboardMessage,
          initiallyExpanded: true,
          bottom: 90,
        ),
      ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    ),
    );
  }

  // ─── HOME TAB ───────────────────────────────────────────────────────────
  Widget _buildHomeTab() {
    return RefreshIndicator(
      color: BmbColors.gold,
      backgroundColor: BmbColors.midNavy,
      onRefresh: () async {
        final added = await _boardService.triggerDailyRefresh();
        if (mounted) {
          setState(() {
            _newTodayCount = _boardService.newTodayCount;
            _recomputeTopHosts();
          });
          if (added > 0) {
            _showSnack('$added new brackets just dropped on the board!');
          }
        }
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildQuickStats()),
          SliverToBoxAdapter(child: _buildFeaturedBracketsHeader()),
          SliverToBoxAdapter(child: _buildFeaturedBrackets()),
          SliverToBoxAdapter(child: _buildCollapsibleTopHosts()),
          // ─── AUTO-PILOT HOSTING ───
          SliverToBoxAdapter(child: AutoPilotDashboardWidget(
            onBracketCreated: () => _loadFirestoreBrackets(),
          )),
          // ─── COMMUNITY & SQUARES ───
          SliverToBoxAdapter(child: _buildCommunityAndSquares()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ROW 1: Avatar + Name + Notification bell ──
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _currentNavIndex = 3),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [_avatarColor, _avatarColor.withValues(alpha: 0.7)]),
                    border: Border.all(
                        color: _isBmbPlus ? BmbColors.gold : BmbColors.borderColor,
                        width: 2),
                  ),
                  child: Icon(_avatarIcon, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Welcome back!',
                            style: TextStyle(
                                color: BmbColors.textSecondary, fontSize: 13)),
                        if (_isBmbPlus) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [BmbColors.gold, BmbColors.goldLight]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_isBusiness ? 'BMB+biz' : 'BMB+',
                                style: TextStyle(
                                    color: BmbColors.deepNavy,
                                    fontSize: 10,
                                    fontWeight: BmbFontWeights.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _currentUser.displayNameOrUsername,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 18,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay'),
                    ),
                  ],
                ),
              ),
              // Notification bell
              Stack(
                children: [
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                    icon: const Icon(Icons.notifications_outlined,
                        color: BmbColors.textSecondary, size: 26),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: BmbColors.errorRed, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── ROW 2: Credits + Store (own row so they don't squeeze the name) ──
          Row(
            children: [
              // BMB Bucket
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BmbBucksPurchaseScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.savings,
                          color: BmbColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text(_isAdmin ? '\u221E credits' : '${_currentUser.bmbCredits} credits',
                          style: TextStyle(
                              color: BmbColors.gold,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Store shortcut
              GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const BmbStoreScreen()));
                  _loadUserData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront,
                          color: BmbColors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text('Store',
                          style: TextStyle(
                              color: BmbColors.blue,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Shopify Shop shortcut
              GestureDetector(
                onTap: () {
                  // Auto-link demo store if not yet linked
                  if (!ShopifyService.isLinked) {
                    ShopifyService.linkStore(
                      storeDomain: 'bmb-official.myshopify.com',
                      storefrontAccessToken: 'demo_token',
                    );
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopifyProductBrowserScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag, color: BmbColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text('Shop',
                          style: TextStyle(
                              color: BmbColors.gold,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── BUSINESS STARTER KIT BANNER (shown only for business accounts) ──
  Widget _buildBusinessStarterKitBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BmbStarterKitScreen())),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                BmbColors.gold.withValues(alpha: 0.2),
                BmbColors.gold.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BmbColors.gold, width: 1.5),
            boxShadow: [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.1), blurRadius: 12)],
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2, color: BmbColors.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Get Your BMB Starter Kit',
                        style: TextStyle(
                            color: BmbColors.gold, fontSize: 14,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    Text('Posters, QR sweatshirts, table tents & more',
                        style: TextStyle(
                            color: BmbColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward, color: BmbColors.gold, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
              child: StatsCard(
                  title: 'Playing',
                  value: '${_currentUser.joinedTournaments}',
                  icon: Icons.group,
                  iconColor: BmbColors.blue)),
          const SizedBox(width: 12),
          Expanded(
              child: StatsCard(
                  title: 'Wins',
                  value: '${_currentUser.wins}',
                  icon: Icons.emoji_events,
                  iconColor: BmbColors.gold)),
          const SizedBox(width: 12),
          Expanded(
              child: StatsCard(
                  title: 'Hosting',
                  value: '${_currentUser.hostedTournaments}',
                  icon: Icons.star,
                  iconColor: BmbColors.successGreen)),
        ],
      ),
    );
  }

  // ─── BRACKET BOARD HEADER WITH SORT + TTL INFO ─────────────────────
  Widget _buildFeaturedBracketsHeader() {
    final archivedCount = _boardService.allArchived.length;
    final boardCount = _featuredBrackets.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ROW 1: Title + badges ──
          Row(
            children: [
              Text('Bracket Board',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(width: 6),
              // Live count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$boardCount',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 11,
                        fontWeight: BmbFontWeights.bold)),
              ),
              if (_newTodayCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: BmbColors.successGreen, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text('+$_newTodayCount New',
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 10,
                              fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
              ],
              if (archivedCount > 0) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showArchivedBracketsSheet(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2, color: const Color(0xFF00BCD4), size: 12),
                        const SizedBox(width: 3),
                        Text('$archivedCount Archived',
                            style: TextStyle(
                                color: const Color(0xFF00BCD4),
                                fontSize: 10,
                                fontWeight: BmbFontWeights.bold)),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Sort button
              GestureDetector(
                onTap: _showSortOptions,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BmbColors.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, color: BmbColors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text(_featuredSortBy,
                          style: TextStyle(
                              color: BmbColors.blue,
                              fontSize: 12,
                              fontWeight: BmbFontWeights.semiBold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _currentNavIndex = 1),
                child: Text('See All',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.semiBold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ── ROW 2: Visibility durations + Refresh ──
          Row(
            children: [
              Icon(Icons.timer_outlined, color: BmbColors.textTertiary, size: 12),
              const SizedBox(width: 4),
              Text(
                'Upcoming ${BracketBoardService.visibilityLabel('upcoming')} '
                '\u2022 Live ${BracketBoardService.visibilityLabel('live')} '
                '\u2022 In Play ${BracketBoardService.visibilityLabel('in_progress')}',
                style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 10),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _refreshBracketBoard,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: BmbColors.blue, size: 12),
                      const SizedBox(width: 3),
                      Text('Refresh',
                          style: TextStyle(
                              color: BmbColors.blue,
                              fontSize: 10,
                              fontWeight: BmbFontWeights.semiBold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Refresh / reset the bracket board with fresh brackets.
  void _refreshBracketBoard() {
    setState(() {
      _boardService.resetBoard();
      _boardUserStateLoaded = false;
      _newTodayCount = _boardService.newTodayCount;
    });
    _loadBoardUserState();
    _showSnack('Bracket Board refreshed with new brackets!');
  }

  void _showSortOptions() {
    final options = [
      ('VIP First', Icons.diamond, BmbColors.vipPurple),
      ('Top Rated', Icons.star, BmbColors.gold),
      ('Most Players', Icons.people, BmbColors.blue),
      ('Free Entry', Icons.money_off, BmbColors.successGreen),
      ('Newest', Icons.schedule, BmbColors.textSecondary),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BmbColors.midNavy, BmbColors.deepNavy],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: BmbColors.borderColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Sort Bracket Board',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 16,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
            const SizedBox(height: 16),
            ...options.map((o) {
              final isActive = _featuredSortBy == o.$1;
              return ListTile(
                leading: Icon(o.$2,
                    color: isActive ? o.$3 : BmbColors.textTertiary, size: 22),
                title: Text(o.$1,
                    style: TextStyle(
                        color: isActive ? o.$3 : BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: isActive
                            ? BmbFontWeights.bold
                            : BmbFontWeights.regular)),
                trailing: isActive
                    ? Icon(Icons.check_circle, color: o.$3, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _applySortOption(o.$1);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _applySortOption(String sortBy) {
    setState(() {
      _featuredSortBy = sortBy;
      _boardService.sortBoard(sortBy);
    });
  }

  Widget _buildSectionHeader(String title, String? action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
          if (action != null)
            GestureDetector(
              onTap: () {
                // Navigate to Explore tab which shows all brackets
                setState(() => _currentNavIndex = 1);
              },
              child: Text(action,
                  style: TextStyle(
                      color: BmbColors.blue,
                      fontSize: 13,
                      fontWeight: BmbFontWeights.semiBold)),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBrackets() {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _featuredBrackets.length,
        itemBuilder: (context, index) {
          final item = _featuredBrackets[index];
          // Simulate user join/picks status for board cards
          // In production this would come from a real user-bracket join service
          final userJoined = _isUserJoinedBoardBracket(item.id);
          final userPicked = _hasUserPickedBoardBracket(item.id);
          return EnhancedBracketCard(
            bracket: item,
            currentUserJoined: userJoined,
            currentUserMadePicks: userPicked,
            onJoinTap: () {
              _hypeMan.trigger(HypeTrigger.joinedTournament, context: item.sport);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TournamentJoinScreen(bracket: item))).then((_) {
                // Refresh join state when returning from join/picks flow
                _loadBoardUserState();
              });
            },
            onPrizeTap: () => _showPrizeSheet(item),
            onPicksTap: item.isPlayable
                ? () => _openFeaturedBracketPicks(item)
                : item.isDone
                    ? () => _showFeaturedBracketResults(item)
                    : null,
          );
        },
      ),
    );
  }

  // ─── BOARD BRACKET USER STATE ──────────────────────────────────────
  // Uses SharedPreferences via ChatAccessService as the single source of
  // truth for which brackets the current user has joined. This ensures
  // that once a user joins via TournamentJoinScreen, the dashboard cards
  // immediately reflect the correct state (Re-Pick, View My Picks, etc.).
  Set<String> _joinedBoardBracketIds = {};
  Set<String> _pickedBoardBracketIds = {};
  bool _boardUserStateLoaded = false;

  /// Load the real join state from SharedPreferences.
  /// Called once lazily on first card render and again after returning
  /// from a join or picks screen.
  Future<void> _loadBoardUserState() async {
    final joinedList = await ChatAccessService.getJoinedBrackets();
    final prefs = await SharedPreferences.getInstance();
    final pickedList = prefs.getStringList('picked_bracket_ids') ?? [];
    if (mounted) {
      setState(() {
        _joinedBoardBracketIds = joinedList.toSet();
        _pickedBoardBracketIds = pickedList.toSet();
        _boardUserStateLoaded = true;
      });
    }
  }

  /// Record that the user made picks for a bracket (persisted).
  Future<void> _recordPicksMade(String bracketId) async {
    final prefs = await SharedPreferences.getInstance();
    final pickedList = prefs.getStringList('picked_bracket_ids') ?? [];
    if (!pickedList.contains(bracketId)) {
      pickedList.add(bracketId);
      await prefs.setStringList('picked_bracket_ids', pickedList);
    }
    _pickedBoardBracketIds.add(bracketId);
  }

  bool _isUserJoinedBoardBracket(String bracketId) {
    if (!_boardUserStateLoaded) {
      // Trigger async load; return false until loaded
      _loadBoardUserState();
      return false;
    }
    return _joinedBoardBracketIds.contains(bracketId);
  }

  bool _hasUserPickedBoardBracket(String bracketId) {
    if (!_boardUserStateLoaded) return false;
    return _pickedBoardBracketIds.contains(bracketId);
  }

  /// Build a CreatedBracket from a BracketItem using the REAL teams.
  ///
  /// CRITICAL FIX: Uses [item.teams] — the actual team/option names that
  /// were populated by the DailyContentEngine or BracketBoardService
  /// template pool. This ensures the picks screen always shows the exact
  /// matchups that correspond to the bracket card the user tapped.
  CreatedBracket _buildCreatedBracketFromBoardItem(BracketItem item, {String? statusOverride}) {
    List<String> teams = List.from(item.teams);

    // Fallback only if teams are somehow empty (should never happen)
    if (teams.isEmpty) {
      teams = List.generate(8, (i) => 'Team ${i + 1}');
    }

    // For bracket game type, pad to nearest power of 2
    int teamCount = teams.length;
    if (item.gameType == GameType.bracket) {
      int pow2 = 2;
      while (pow2 < teamCount) { pow2 *= 2; }
      while (teams.length < pow2) { teams.add('BYE'); }
      teamCount = pow2;
    } else {
      if (teamCount.isOdd) {
        teams.add('BYE');
        teamCount = teams.length;
      }
    }

    // Map GameType → bracketType string
    String bracketType;
    switch (item.gameType) {
      case GameType.pickem:
      case GameType.props:
        bracketType = 'pickem';
      case GameType.voting:
        bracketType = 'voting';
      case GameType.squares:
      case GameType.trivia:
      case GameType.survivor:
        bracketType = 'nopicks';
      case GameType.bracket:
        bracketType = 'standard';
    }

    return CreatedBracket(
      id: item.id,
      name: item.title,
      templateId: 'live_${item.id}',
      sport: item.sport,
      teamCount: teamCount,
      teams: teams,
      status: statusOverride ?? item.status,
      createdAt: DateTime.now(),
      hostId: item.host?.id ?? 'unknown',
      hostName: item.host?.name ?? 'Unknown Host',
      hostState: item.host?.location,
      bracketType: bracketType,
      isFreeEntry: item.isFree,
      entryDonation: item.entryCredits ?? item.entryFee.toInt(),
    );
  }

  /// Convert a featured BracketItem into a CreatedBracket and open picks screen.
  /// Uses REAL teams from the BracketItem — not generic sport placeholders.
  void _openFeaturedBracketPicks(BracketItem item) {
    final bracket = _buildCreatedBracketFromBoardItem(item);

    // IN_PROGRESS: show read-only picks
    final readOnly = item.status == 'in_progress';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BracketPicksScreen(bracket: bracket, readOnly: readOnly)),
    ).then((_) {
      // After returning from picks screen, refresh state
      // Note: picks recording is now handled by BracketPicksScreen._recordPicksMadeToPrefs()
      // which only fires when the user actually submits picks.
      _loadBoardUserState();
    });
  }

  /// Show final results for completed brackets in read-only bracket tree.
  /// Uses REAL teams from the BracketItem.
  void _showFeaturedBracketResults(BracketItem item) {
    final bracket = _buildCreatedBracketFromBoardItem(item, statusOverride: 'done');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BracketPicksScreen(bracket: bracket, readOnly: true),
      ),
    );
  }

  // ─── COLLAPSIBLE TOP HOSTS ──────────────────────────────────────────────
  Widget _buildCollapsibleTopHosts() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _topHostsExpanded = !_topHostsExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Text('Top Hosts',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _topHostsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down, color: BmbColors.textTertiary, size: 24),
                ),
                const Spacer(),
                if (_topHostsExpanded)
                  GestureDetector(
                    onTap: () => setState(() => _currentNavIndex = 1),
                    child: Text('View All',
                        style: TextStyle(
                            color: BmbColors.blue,
                            fontSize: 13,
                            fontWeight: BmbFontWeights.semiBold)),
                  ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildTopHostsSection(),
          crossFadeState: _topHostsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  // ─── TOP HOSTS SECTION ──────────────────────────────────────────────────
  Widget _buildTopHostsSection() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _topHosts.length,
        itemBuilder: (context, index) {
          final host = _topHosts[index];
          return _buildHostCard(host);
        },
      ),
    );
  }

  Widget _buildHostCard(BracketHost host) {
    final isOfficial = host.name == 'Back My Bracket';
    return GestureDetector(
      onTap: () => _showHostProfile(host),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOfficial
                ? BmbColors.blue.withValues(alpha: 0.4)
                : host.isTopHost
                    ? BmbColors.gold.withValues(alpha: 0.3)
                    : BmbColors.borderColor,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: host.profileImageUrl == null
                        ? (isOfficial
                            ? LinearGradient(
                                colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)])
                            : LinearGradient(colors: [
                                BmbColors.gold.withValues(alpha: 0.3),
                                BmbColors.gold.withValues(alpha: 0.1)
                              ]))
                        : null,
                    image: host.profileImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(host.profileImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: Border.all(
                      color: isOfficial ? BmbColors.blue : BmbColors.gold,
                      width: 2,
                    ),
                  ),
                  child: host.profileImageUrl != null
                      ? null
                      : Icon(
                          isOfficial ? Icons.emoji_events : Icons.person,
                          color: isOfficial ? Colors.white : BmbColors.gold,
                          size: 26,
                        ),
                ),
                if (host.isVerified)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: BmbColors.midNavy, shape: BoxShape.circle),
                      child: const Icon(Icons.verified,
                          color: BmbColors.blue, size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              host.name,
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 13,
                  fontWeight: BmbFontWeights.semiBold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Location
            if (host.location != null)
              Text(host.location!,
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 11)),
            const SizedBox(height: 6),
            // Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: BmbColors.gold, size: 14),
                const SizedBox(width: 2),
                Text('${host.rating}',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 12,
                        fontWeight: BmbFontWeights.bold)),
                const SizedBox(width: 4),
                Text('(${host.reviewCount})',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            // Hosted count
            Text('${host.totalHosted} Hosted',
                style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 11)),
            // Top Host / Official badge
            const SizedBox(height: 6),
            if (isOfficial)
              _buildBadgeChip('Official', BmbColors.blue)
            else if (host.isTopHost)
              _buildBadgeChip('Top Host', BmbColors.gold),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: BmbFontWeights.bold)),
    );
  }

  // ─── COMMUNITY & SQUARES QUICK ACCESS ────────────────────────────────
  Widget _buildCommunityAndSquares() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // BMB Community Chat
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityChatScreen())),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BmbColors.blue.withValues(alpha: 0.15), BmbColors.blue.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.forum, color: BmbColors.blue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BMB Community', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                    Text('Chat, trivia, winners', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                  ])),
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: BmbColors.successGreen, shape: BoxShape.circle),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Squares Game
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SquaresHubScreen())),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.12), BmbColors.gold.withValues(alpha: 0.04)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.grid_4x4, color: BmbColors.gold, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Squares Game', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                    Row(children: [
                      Text('10x10 grid', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text('NEW', style: TextStyle(color: BmbColors.gold, fontSize: 7, fontWeight: BmbFontWeights.bold)),
                      ),
                    ]),
                  ])),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIVE BRACKETS LIST ─────────────────────────────────────────────────
  Widget _buildLiveBracketsList() {
    final live =
        _featuredBrackets.where((b) => b.status == 'live').toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: live
            .map((bracket) => _buildLiveBracketTile(bracket))
            .toList(),
      ),
    );
  }

  Widget _buildLiveBracketTile(BracketItem bracket) {
    final userJoined = _isUserJoinedBoardBracket(bracket.id);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BracketDetailScreen(bracket: bracket, hasJoinedHint: userJoined ? true : null))).then((_) => _loadBoardUserState()),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          // Sport icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getSportColor(bracket.sport).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getSportIcon(bracket.sport),
                color: _getSportColor(bracket.sport), size: 24),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bracket.title,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.semiBold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (bracket.host != null) ...[
                      Icon(Icons.person,
                          size: 12, color: BmbColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(bracket.host!.name,
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.people,
                        size: 12, color: BmbColors.textTertiary),
                    const SizedBox(width: 3),
                    Text('${bracket.participants}',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 11)),
                    const SizedBox(width: 8),
                    // Live indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BmbColors.successGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: BmbColors.successGreen,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text('LIVE',
                              style: TextStyle(
                                  color: BmbColors.successGreen,
                                  fontSize: 9,
                                  fontWeight: BmbFontWeights.bold)),
                        ],
                      ),
                    ),
                    // Game type badge (only if not a plain bracket)
                    if (bracket.gameType != GameType.bracket) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _gameTypeColor(bracket.gameType).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_gameTypeIcon(bracket.gameType),
                                color: _gameTypeColor(bracket.gameType), size: 9),
                            const SizedBox(width: 3),
                            Text(bracket.gameTypeLabel,
                                style: TextStyle(
                                    color: _gameTypeColor(bracket.gameType),
                                    fontSize: 8,
                                    fontWeight: BmbFontWeights.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Chat button
          GestureDetector(
            onTap: () => _openChat(bracket),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  color: BmbColors.blue, size: 16),
            ),
          ),
          // Join / Re-Pick button — state-aware
          Builder(builder: (_) {
            final userJoined = _isUserJoinedBoardBracket(bracket.id);
            final userPicked = _hasUserPickedBoardBracket(bracket.id);
            if (userJoined && userPicked) {
              // Already joined + made picks → Re-Pick
              return ElevatedButton(
                onPressed: () {
                  _openFeaturedBracketPicks(bracket);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.refresh, size: 12),
                  const SizedBox(width: 3),
                  Text('Re-Pick', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                ]),
              );
            } else if (userJoined) {
              // Joined but no picks yet → Make Picks
              return ElevatedButton(
                onPressed: () {
                  _openFeaturedBracketPicks(bracket);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.edit_note, size: 12),
                  const SizedBox(width: 3),
                  Text('Picks', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                ]),
              );
            } else {
              // Not joined → Join
              return ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TournamentJoinScreen(bracket: bracket),
                  )).then((_) => _loadBoardUserState());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.buttonPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Join', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
              );
            }
          }),
        ],
      ),
    ),
    );
  }

  // ─── EXPLORE TAB ────────────────────────────────────────────────────────
  Widget _buildExploreTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Explore',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 24,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
          ),
        ),
        SliverToBoxAdapter(child: _buildSearchBar()),
        SliverToBoxAdapter(
            child: _buildSectionHeader('Categories', null)),
        SliverToBoxAdapter(child: _buildCategoryGrid()),
        SliverToBoxAdapter(
            child: _buildSectionHeader('Trending Brackets', null)),
        SliverToBoxAdapter(child: _buildFeaturedBrackets()),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: BmbColors.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.borderColor),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: BmbColors.textTertiary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search brackets, hosts, sports...',
                  hintStyle:
                      TextStyle(color: BmbColors.textTertiary, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.tune, color: BmbColors.blue, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      ('Basketball', Icons.sports_basketball, const Color(0xFFFF6B35)),
      ('Football', Icons.sports_football, const Color(0xFF795548)),
      ('Baseball', Icons.sports_baseball, const Color(0xFFE53935)),
      ('Soccer', Icons.sports_soccer, const Color(0xFF4CAF50)),
      ('Hockey', Icons.sports_hockey, const Color(0xFF1E88E5)),
      ('MMA', Icons.sports_mma, const Color(0xFFD32F2F)),
      ('Golf', Icons.sports_golf, const Color(0xFF388E3C)),
      ('Voting', Icons.how_to_vote, const Color(0xFF9C27B0)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final (name, icon, color) = categories[index];
          return GestureDetector(
            onTap: () => _showFilteredBrackets(name),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: color.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 6),
                  Text(name,
                      style: TextStyle(
                          color: BmbColors.textSecondary,
                          fontSize: 11,
                          fontWeight: BmbFontWeights.medium),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── MY BRACKETS TAB ───────────────────────────────────────────────────
  Widget _buildMyBracketsTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Brackets',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 24,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                ElevatedButton.icon(
                  onPressed: _openBracketBuilder,
                  icon: Icon(_isBmbPlus ? Icons.add : Icons.construction, size: 18),
                  label: Text(_isBmbPlus ? 'Create' : 'Build',
                      style: TextStyle(fontWeight: BmbFontWeights.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                _buildFilterChip('All', _bracketFilter == 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Hosted', _bracketFilter == 'Hosted'),
                const SizedBox(width: 8),
                _buildFilterChip('Joined', _bracketFilter == 'Joined'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', _bracketFilter == 'Completed'),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _buildMyBracketsList(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _bracketFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? BmbColors.blue : BmbColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  selected ? BmbColors.blue : BmbColors.borderColor),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? Colors.white
                    : BmbColors.textSecondary,
                fontSize: 13,
                fontWeight: BmbFontWeights.medium)),
      ),
    );
  }

  Widget _buildMyBracketsList() {
    // Filter created brackets by status
    List<CreatedBracket> createdFiltered;
    switch (_bracketFilter) {
      case 'Hosted':
        createdFiltered = _createdBrackets;
        break;
      case 'Joined':
        createdFiltered = [];
        break;
      case 'Completed':
        createdFiltered =
            _createdBrackets.where((b) => b.status == 'done').toList();
        break;
      default: // 'All'
        createdFiltered = _createdBrackets;
    }

    // Also keep the original bracket items for "Joined" view.
    // CRITICAL FIX: The "Joined" tab must only show brackets the user
    // has ACTUALLY joined (tracked in _joinedBoardBracketIds), not just
    // arbitrary board brackets.
    List<BracketItem> joinedFiltered;
    switch (_bracketFilter) {
      case 'Hosted':
        joinedFiltered = [];
        break;
      case 'Joined':
        // Show ONLY brackets the user truly joined
        joinedFiltered = _featuredBrackets
            .where((b) => _isUserJoinedBoardBracket(b.id))
            .toList();
        break;
      case 'Completed':
        joinedFiltered =
            _featuredBrackets.where((b) => b.status == 'upcoming').toList();
        break;
      default:
        joinedFiltered = _featuredBrackets.take(4).toList();
    }

    if (createdFiltered.isEmpty && joinedFiltered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                color: BmbColors.textTertiary, size: 48),
            const SizedBox(height: 12),
            Text('No brackets in this category',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 14)),
            const SizedBox(height: 8),
            if (!_isBmbPlus)
              Text('BMB+ required to save brackets',
                  style: TextStyle(color: BmbColors.gold, fontSize: 12)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openBracketBuilder,
              icon: const Icon(Icons.add, size: 16),
              label: Text(_isBmbPlus ? 'Create Your First Bracket' : 'Try Bracket Builder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Created brackets (user-built)
          ...createdFiltered.map((b) => _buildCreatedBracketTile(b)),
          // Original brackets (joined)
          ...joinedFiltered.map((b) => _buildMyBracketTile(b)),
        ],
      ),
    );
  }

  Widget _buildCreatedBracketTile(CreatedBracket bracket) {
    Color statusColor;
    switch (bracket.status) {
      case 'saved':
        statusColor = Colors.grey;
        break;
      case 'upcoming':
        statusColor = BmbColors.blue;
        break;
      case 'live':
        statusColor = BmbColors.successGreen;
        break;
      case 'in_progress':
        statusColor = BmbColors.gold;
        break;
      case 'done':
        statusColor = const Color(0xFF00BCD4);
        break;
      default:
        statusColor = BmbColors.textTertiary;
    }

    // Bracket type badge color
    Color typeColor;
    IconData typeIcon;
    switch (bracket.bracketType) {
      case 'voting':
        typeColor = const Color(0xFF9C27B0);
        typeIcon = Icons.how_to_vote;
        break;
      case 'pickem':
        typeColor = BmbColors.gold;
        typeIcon = Icons.checklist;
        break;
      case 'nopicks':
        typeColor = BmbColors.successGreen;
        typeIcon = Icons.visibility;
        break;
      default:
        typeColor = BmbColors.blue;
        typeIcon = Icons.account_tree;
    }

    final isMe = CurrentUserService.instance.isCurrentUser;
    final userJoined = bracket.isUserJoined(isMe);
    final userMadePicks = bracket.hasUserMadePicks(isMe);
    final userIsHost = bracket.isUserHost(isMe);

    return GestureDetector(
      onTap: null, // Navigation handled by explicit action buttons below
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(bracket.statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: BmbFontWeights.bold)),
                ),
                const SizedBox(width: 6),
                // Bracket type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, color: typeColor, size: 10),
                      const SizedBox(width: 3),
                      Text(bracket.bracketTypeLabel,
                          style: TextStyle(
                              color: typeColor,
                              fontSize: 9,
                              fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: BmbColors.borderColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(bracket.sport,
                      style: TextStyle(
                          color: BmbColors.textSecondary, fontSize: 10)),
                ),
                const Spacer(),
                if (bracket.hasGiveaway)
                  Icon(Icons.celebration, color: BmbColors.gold, size: 16),
                if (bracket.scheduledLiveDate != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.schedule, color: BmbColors.blue, size: 16),
                  ),
                if (bracket.prizeType == 'charity')
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.volunteer_activism, color: BmbColors.successGreen, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(bracket.name,
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 15,
                    fontWeight: BmbFontWeights.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.people, color: BmbColors.textTertiary, size: 14),
                const SizedBox(width: 4),
                Text('${bracket.teamCount} ${bracket.isVoting ? 'items' : 'teams'}',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.monetization_on,
                    color: BmbColors.textTertiary, size: 14),
                const SizedBox(width: 4),
                Text(bracket.entryLabel,
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.emoji_events,
                    color: BmbColors.gold, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(bracket.prizeLabel,
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            // Tie-breaker info for Pick 'Em
            if (bracket.isPickEm && bracket.tieBreakerGame != null && bracket.tieBreakerGame!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.sports_score, color: BmbColors.gold, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Tie-breaker: ${bracket.tieBreakerGame}',
                        style: TextStyle(color: BmbColors.gold, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            // Charity info
            if (bracket.prizeType == 'charity' && bracket.charityName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.favorite, color: BmbColors.successGreen, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Raising funds for: ${bracket.charityName}',
                        style: TextStyle(color: BmbColors.successGreen, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            // ── YOUR PICK % BAR ── (only for in_progress/done + user joined + made picks)
            if ((bracket.status == 'in_progress' || bracket.status == 'done') &&
                userJoined && userMadePicks && bracket.requiresPicks) ...[
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final results = ResultsService.getResults(bracket);
                final allPicks = ResultsService.getAllPicks(bracket);
                final leaderboard = ScoringEngine.buildLeaderboard(
                  allPicks: allPicks,
                  results: results,
                  totalRounds: bracket.totalRounds,
                  currentUserId: CurrentUserService.instance.userId,
                );
                final myEntry = leaderboard.where((e) => e.isCurrentUser).firstOrNull;
                if (myEntry == null) return const SizedBox.shrink();
                final correct = myEntry.correctPicks;
                final total = myEntry.correctPicks + myEntry.incorrectPicks + myEntry.pendingPicks;
                final pct = total > 0 ? (correct / total * 100) : 0.0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: BmbColors.successGreen, size: 14),
                          const SizedBox(width: 6),
                          Text('Your Pick %',
                              style: TextStyle(color: BmbColors.successGreen, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                          const Spacer(),
                          Text('$correct/$total correct',
                              style: TextStyle(color: BmbColors.textSecondary, fontSize: 10)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: BmbColors.successGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${pct.toStringAsFixed(0)}%',
                                style: TextStyle(color: BmbColors.successGreen, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                          ),
                          if (myEntry.rank > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BmbColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('#${myEntry.rank}',
                                  style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: total > 0 ? correct / total : 0,
                          minHeight: 6,
                          backgroundColor: BmbColors.borderColor.withValues(alpha: 0.4),
                          valueColor: AlwaysStoppedAnimation(BmbColors.successGreen),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            // Giveaway spinner indicator (only show for non in_progress/done OR when no pick bar)
            if (bracket.hasGiveaway && bracket.status != 'in_progress' && bracket.status != 'done') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.celebration, color: BmbColors.gold, size: 14),
                  const SizedBox(width: 4),
                  Text('Giveaway Spinner',
                      style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: BmbColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${bracket.giveawayWinnerCount} winner${bracket.giveawayWinnerCount > 1 ? 's' : ''} \u00d7 ${bracket.giveawayTokensPerWinner}c',
                      style: TextStyle(color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold),
                    ),
                  ),
                ],
              ),
            ],
            // Giveaway spinner indicator (compact, for in_progress/done)
            if (bracket.hasGiveaway && (bracket.status == 'in_progress' || bracket.status == 'done')) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.celebration, color: BmbColors.gold, size: 12),
                  const SizedBox(width: 4),
                  Text('Giveaway: ${bracket.giveawayWinnerCount} winner${bracket.giveawayWinnerCount > 1 ? 's' : ''} \u00d7 ${bracket.giveawayTokensPerWinner}c',
                      style: TextStyle(color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.semiBold)),
                ],
              ),
            ],
            // ─── STATUS-AWARE ACTION BUTTONS ───
            // Saved: Share button to advance to Upcoming
            if (bracket.status == 'saved') ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Advance to upcoming first
                      setState(() {
                        final idx = _createdBrackets.indexOf(bracket);
                        if (idx >= 0) {
                          _createdBrackets[idx] = bracket.copyWith(status: 'upcoming');
                        }
                      });
                      // ═══ PHASE 3: Sync status to Firestore ═══
                      _syncBracketToFirestore(bracket.id, {'status': 'upcoming'});
                      _hypeMan.trigger(HypeTrigger.sharedBracket, context: bracket.sport);
                      // ═══ PHASE 8: Open branded share sheet ═══
                      ShareBracketSheet.show(context, bracket: bracket, userName: CurrentUserService.instance.displayName.isNotEmpty ? CurrentUserService.instance.displayName : 'You');
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: Text('Share & Go Upcoming', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.blue, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── EDIT button (full edit – opens wizard) ──
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _editBracketFull(bracket),
                    icon: Icon(Icons.edit, size: 14, color: BmbColors.gold),
                    label: Text('Edit', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: BmbColors.gold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () {
                      // Delete saved bracket
                      final bracketId = bracket.id;
                      setState(() => _createdBrackets.remove(bracket));
                      // ═══ PHASE 3: Mark deleted in Firestore ═══
                      _deleteBracketFromFirestore(bracketId);
                      _showSnack('Bracket deleted. No credits were charged.');
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: BmbColors.errorRed), foregroundColor: BmbColors.errorRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text('Delete', style: TextStyle(fontSize: 11, fontWeight: BmbFontWeights.bold)),
                  ),
                ),
              ]),
            ],
            // Upcoming: Go Live button, join count, scheduled date
            if (bracket.status == 'upcoming') ...[
              const SizedBox(height: 10),
              // Min players & auto host info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.people, color: BmbColors.blue, size: 14),
                  const SizedBox(width: 6),
                  Text('${bracket.participantCount}/${bracket.minPlayers} players playing',
                      style: TextStyle(color: BmbColors.blue, fontSize: 11)),
                  const Spacer(),
                  if (bracket.autoHost)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.smart_toy, color: BmbColors.successGreen, size: 12),
                      const SizedBox(width: 3),
                      Text('Auto Host', style: TextStyle(color: BmbColors.successGreen, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                    ]),
                ]),
              ),
              if (bracket.scheduledLiveDate != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.calendar_today, color: BmbColors.blue, size: 14),
                  const SizedBox(width: 4),
                  Text('Go Live: ${bracket.scheduledLiveDate!.month}/${bracket.scheduledLiveDate!.day}/${bracket.scheduledLiveDate!.year}',
                      style: TextStyle(color: BmbColors.blue, fontSize: 11)),
                ]),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        final idx = _createdBrackets.indexOf(bracket);
                        if (idx >= 0) {
                          _createdBrackets[idx] = bracket.copyWith(status: 'live', creditsDeducted: true);
                        }
                      });
                      // ═══ PHASE 3: Sync live status to Firestore ═══
                      _syncBracketToFirestore(bracket.id, {
                        'status': 'live',
                        'go_live_date': DateTime.now().toUtc(),
                      });
                      _showSnack('Tournament is LIVE! Credits deducted from host & players.');
                      _hypeMan.trigger(HypeTrigger.bracketWentLive, context: bracket.sport);
                    },
                    icon: const Icon(Icons.play_circle_filled, size: 16),
                    label: Text('Go Live Now', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.successGreen, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => ShareBracketSheet.show(context, bracket: bracket, userName: CurrentUserService.instance.displayName.isNotEmpty ? CurrentUserService.instance.displayName : 'You'),
                    icon: Icon(Icons.share, size: 16, color: BmbColors.blue),
                    label: Text('Share', style: TextStyle(color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: BmbColors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ]),
              // ── EDIT TBD NAMES: only when no players have joined ──
              if (bracket.teams.any((t) => t.trim().toUpperCase() == 'TBD')) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _editBracketTbdOnly(bracket),
                    icon: Icon(Icons.edit_note, size: 16, color: BmbColors.gold),
                    label: Text('Edit TBD Names', style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: BmbColors.gold.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
            // ─── LIVE STATUS ───
            if (bracket.status == 'live') ...[
              const SizedBox(height: 10),
              // CASE 1: User is joined (host is auto-joined)
              if (userJoined || userIsHost) ...[
                Row(
                  children: [
                    if (bracket.requiresPicks)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openBracketPicks(bracket),
                          icon: Icon(userMadePicks ? Icons.refresh : Icons.edit_note, size: 16),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: userMadePicks ? BmbColors.blue : BmbColors.successGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          label: Text(
                              userMadePicks ? 'Re-Pick' : 'Make My Picks',
                              style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showNoPicks(bracket),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: typeColor, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('View Bracket', style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
                        ),
                      ),
                    if (userIsHost) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: () => _openHostManager(bracket),
                          icon: Icon(ResultsService.isAutoSynced(bracket) ? Icons.sync : Icons.edit_note, size: 16, color: BmbColors.blue),
                          label: Text(ResultsService.isAutoSynced(bracket) ? 'Results' : 'Manage',
                              style: TextStyle(color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: BmbColors.blue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () => _openLeaderboard(bracket),
                        icon: Icon(Icons.leaderboard, size: 16, color: BmbColors.gold),
                        label: Text('Rank', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: BmbColors.gold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                if (userMadePicks && !userIsHost) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.info_outline, color: BmbColors.textTertiary, size: 12),
                    const SizedBox(width: 4),
                    Text('You can re-pick until the tournament starts.',
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                  ]),
                ],
              ]
              // CASE 2: User is NOT joined → show Join Now
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TournamentJoinScreen(bracket: _toBracketItem(bracket))));
                    },
                    icon: const Icon(Icons.person_add, size: 16),
                    label: Text('Join Now', style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.buttonPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
            // ─── IN PROGRESS STATUS ───
            if (bracket.status == 'in_progress') ...[
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.lock, color: BmbColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Tournament in progress. Picks are locked.', style: TextStyle(color: BmbColors.gold, fontSize: 11))),
                ]),
              ),
              Row(
                children: [
                  // Only show View Picks if user joined
                  if (userJoined && bracket.requiresPicks)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openBracketPicks(bracket),
                        icon: const Icon(Icons.lock, size: 14),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BmbColors.gold, foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        label: Text('View My Picks',
                            style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
                      ),
                    )
                  else if (!bracket.requiresPicks)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showNoPicks(bracket),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: typeColor, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('View Bracket', style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold)),
                      ),
                    ),
                  if (userIsHost) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () => _openHostManager(bracket),
                        icon: Icon(ResultsService.isAutoSynced(bracket) ? Icons.sync : Icons.edit_note, size: 16, color: BmbColors.blue),
                        label: Text(ResultsService.isAutoSynced(bracket) ? 'Results' : 'Update',
                            style: TextStyle(color: BmbColors.blue, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: BmbColors.blue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () => _openLeaderboard(bracket),
                      icon: Icon(Icons.leaderboard, size: 16, color: BmbColors.gold),
                      label: Text('Rank', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: BmbColors.gold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Done: View Picks (if joined), Leaderboard & Rate Host
            if (bracket.status == 'done') ...[
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.emoji_events, color: const Color(0xFF00BCD4), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Tournament complete! Final standings available.', style: TextStyle(color: const Color(0xFF00BCD4), fontSize: 11))),
                ]),
              ),
              Row(children: [
                // View Picks button — only if user was a participant
                if ((userJoined || userIsHost) && bracket.requiresPicks) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openBracketPicks(bracket),
                      icon: const Icon(Icons.lock, size: 14),
                      label: Text('View My Picks', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4), foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLeaderboard(bracket),
                    icon: const Icon(Icons.leaderboard, size: 16),
                    label: Text('Final Leaderboard', style: TextStyle(fontSize: 12, fontWeight: BmbFontWeights.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.gold, foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (userIsHost) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () => _openHostManager(bracket),
                      icon: Icon(Icons.military_tech, size: 16, color: BmbColors.gold),
                      label: Text('Results', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: BmbColors.gold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ],
              ]),
              // Rate Host button (shown after tournament is done)
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Builder(builder: (ctx) {
                  final alreadyReviewed = _reviewService.hasReviewed(
                      _currentUser.id, bracket.id);
                  return ElevatedButton.icon(
                    onPressed: alreadyReviewed
                        ? null
                        : () => _openPostTournamentReview(bracket),
                    icon: Icon(
                      alreadyReviewed ? Icons.check_circle : Icons.star,
                      size: 16,
                    ),
                    label: Text(
                      alreadyReviewed ? 'Review Submitted' : 'Rate Your Host',
                      style: TextStyle(
                          fontSize: 12, fontWeight: BmbFontWeights.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alreadyReviewed
                          ? BmbColors.cardDark
                          : BmbColors.blue,
                      foregroundColor: alreadyReviewed
                          ? BmbColors.textTertiary
                          : Colors.white,
                      disabledBackgroundColor: BmbColors.cardDark,
                      disabledForegroundColor: BmbColors.textTertiary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyBracketTile(BracketItem bracket) {
    // Determine join state from our local tracking sets so we can pass a
    // hint to BracketDetailScreen.  Tiles rendered inside the "Joined" tab
    // are by definition brackets the user joined, so we also check the
    // current filter as a fallback.
    final userJoined = _isUserJoinedBoardBracket(bracket.id) ||
        _bracketFilter == 'Joined';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BracketDetailScreen(
            bracket: bracket,
            hasJoinedHint: userJoined ? true : null,
          ),
        ),
      ).then((_) => _loadBoardUserState()),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      _getSportColor(bracket.sport).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getSportIcon(bracket.sport),
                    color: _getSportColor(bracket.sport), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bracket.title,
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 14,
                            fontWeight: BmbFontWeights.semiBold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (bracket.host != null) ...[
                          Text('Hosted by ${bracket.host!.name}',
                              style: TextStyle(
                                  color: BmbColors.textTertiary,
                                  fontSize: 11)),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bracket.status == 'live'
                                ? BmbColors.successGreen.withValues(alpha: 0.2)
                                : BmbColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bracket.status.toUpperCase(),
                            style: TextStyle(
                              color: bracket.status == 'live'
                                  ? BmbColors.successGreen
                                  : BmbColors.gold,
                              fontSize: 9,
                              fontWeight: BmbFontWeights.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Chat button
              GestureDetector(
                onTap: () => _openChat(bracket),
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: BmbColors.blue, size: 16),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: BmbColors.textTertiary),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.65,
              minHeight: 4,
              backgroundColor: BmbColors.borderColor,
              valueColor: AlwaysStoppedAnimation(BmbColors.blue),
            ),
          ),
          const SizedBox(height: 6),
          Text('Round 2 of 4 - 65% Complete',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 11)),
        ],
      ),
    ),
    );
  }

  // ─── PROFILE TAB ────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Profile header with photo edit
          GestureDetector(
          onTap: () async {
            final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ProfilePhotoScreen()));
            if (updated == true) _loadUserData();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    _avatarColor,
                    _avatarColor.withValues(alpha: 0.7)
                  ]),
                  border: Border.all(
                      color: _isBmbPlus
                          ? BmbColors.gold
                          : BmbColors.borderColor,
                      width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: _avatarColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2),
                  ],
                ),
                child: Icon(_avatarIcon,
                    color: Colors.white, size: 44),
              ),
              if (_currentUser.isVerified)
                Positioned(
                  bottom: 0,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: BmbColors.midNavy,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.verified,
                        color: BmbColors.blue, size: 22),
                  ),
                ),
              // Camera edit icon
              Positioned(
                bottom: -2,
                left: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: BmbColors.blue, shape: BoxShape.circle, border: Border.all(color: BmbColors.deepNavy, width: 2)),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_currentUser.displayNameOrUsername,
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 22,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              if (_isBmbPlus) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [BmbColors.gold, BmbColors.goldLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_isBusiness ? 'BMB+biz' : 'BMB+',
                      style: TextStyle(
                          color: BmbColors.deepNavy,
                          fontSize: 11,
                          fontWeight: BmbFontWeights.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (_currentUser.location != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on,
                    color: BmbColors.textTertiary, size: 14),
                const SizedBox(width: 4),
                if (_currentUser.city != null)
                  Text('${_currentUser.city}, ',
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: BmbColors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Text(_currentUser.location!,
                      style: TextStyle(
                          color: BmbColors.blue,
                          fontSize: 12,
                          fontWeight: BmbFontWeights.bold)),
                ),
              ],
            ),
          const SizedBox(height: 6),
          // Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: BmbColors.gold, size: 16),
              const SizedBox(width: 4),
              Text('${_currentUser.rating}',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 14,
                      fontWeight: BmbFontWeights.bold)),
              const SizedBox(width: 4),
              Text('(${_currentUser.reviewCount} reviews)',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentUser.bio != null)
            Text(_currentUser.bio!,
                style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          const SizedBox(height: 20),
          // Stats grid
          Row(
            children: [
              Expanded(
                  child: _buildProfileStatCard(
                      'Hosting', '${_currentUser.hostedTournaments}',
                      Icons.star, BmbColors.gold)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildProfileStatCard(
                      'Playing', '${_currentUser.joinedTournaments}',
                      Icons.group, BmbColors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildProfileStatCard(
                      'Wins', '${_currentUser.wins}',
                      Icons.emoji_events, BmbColors.successGreen)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildProfileStatCard(
                      'Earnings',
                      '${_currentUser.earnings.toStringAsFixed(0)} cr',
                      Icons.savings, BmbColors.gold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildProfileStatCard(
                      'BMB Bucket',
                      _isAdmin ? '\u221E' : '${_currentUser.bmbCredits}',
                      Icons.savings, BmbColors.gold)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildProfileStatCard(
                      'Win Rate',
                      _currentUser.joinedTournaments > 0
                          ? '${(_currentUser.wins / _currentUser.joinedTournaments * 100).toStringAsFixed(0)}%'
                          : '0%',
                      Icons.trending_up,
                      BmbColors.successGreen)),
            ],
          ),
          // ── ADMIN: Credit Management ──
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            _buildAdminCreditManager(),
          ],
          const SizedBox(height: 24),
          // ─── ARCHIVED BRACKETS ─────────────────────────────────
          _buildProfileArchivedBrackets(),
          const SizedBox(height: 24),
          // Menu items
          _buildProfileMenu(),
          const SizedBox(height: 24),
          // ── DEV: Hologram Guide Preview ──
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/guide-preview'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00E5FF).withValues(alpha: 0.1), const Color(0xFF00B0FF).withValues(alpha: 0.05)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF2979FF)]),
                  ),
                  child: const Center(child: Text('\u{1F916}', style: TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hologram Guide Preview', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('V2 Character + V4 Tutorial demos', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('DEV', style: TextStyle(color: const Color(0xFF00E5FF), fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BmbColors.errorRed,
                side: BorderSide(
                    color: BmbColors.errorRed.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 18,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: BmbColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  /// Admin-only credit management panel.
  /// Allows admins to add or deduct credits from ANY user's account.
  /// Admin accounts skip payment — credits are directly granted/deducted.
  Widget _buildAdminCreditManager() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BmbColors.gold.withValues(alpha: 0.15), BmbColors.gold.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: BmbColors.gold, size: 20),
              const SizedBox(width: 8),
              Text('Admin Credit Manager',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 14,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('HOUSE',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 9,
                        fontWeight: BmbFontWeights.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Add or deduct credits from any user account.\nAdmin accounts skip payment.',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAdminCreditDialog(isAdd: true),
                  icon: const Icon(Icons.add_circle, size: 16),
                  label: const Text('Add Credits'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAdminCreditDialog(isAdd: false),
                  icon: const Icon(Icons.remove_circle, size: 16),
                  label: const Text('Deduct'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.errorRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAdminCreditDialog({required bool isAdd}) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    // Load all users for the selector
    List<Map<String, dynamic>> allUsers = [];
    try {
      allUsers = await FirestoreService.instance.getAllUsers();
      // Sort: admin accounts first, then alphabetically by display name
      allUsers.sort((a, b) {
        final aAdmin = a['is_admin'] as bool? ?? false;
        final bAdmin = b['is_admin'] as bool? ?? false;
        if (aAdmin && !bAdmin) return -1;
        if (!aAdmin && bAdmin) return 1;
        final aName = (a['display_name'] as String? ?? a['email'] as String? ?? '').toLowerCase();
        final bName = (b['display_name'] as String? ?? b['email'] as String? ?? '').toLowerCase();
        return aName.compareTo(bName);
      });
    } catch (e) {
      if (mounted) _showSnack('Failed to load users: $e');
      return;
    }

    if (!mounted) return;

    // Default to the current admin's own account
    final myUserId = CurrentUserService.instance.userId;
    String? selectedUserId = myUserId;
    String selectedUserLabel = 'My Account (${CurrentUserService.instance.displayName})';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: BmbColors.midNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(isAdd ? Icons.add_circle : Icons.remove_circle,
                    color: isAdd ? BmbColors.successGreen : BmbColors.errorRed, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(isAdd ? 'Add Credits' : 'Deduct Credits',
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 16,
                          fontWeight: BmbFontWeights.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── User Selector ──
                  Text('Select User Account',
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: BmbColors.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedUserId,
                        dropdownColor: BmbColors.midNavy,
                        icon: const Icon(Icons.keyboard_arrow_down, color: BmbColors.gold),
                        style: TextStyle(color: BmbColors.textPrimary, fontSize: 13),
                        menuMaxHeight: 300,
                        items: allUsers.map((user) {
                          final uid = user['doc_id'] as String? ?? '';
                          final name = user['display_name'] as String? ?? user['email'] as String? ?? 'Unknown';
                          final email = user['email'] as String? ?? '';
                          final credits = (user['credits_balance'] as num?)?.toInt() ?? 0;
                          final userIsAdmin = user['is_admin'] as bool? ?? false;
                          final isMe = uid == myUserId;
                          return DropdownMenuItem<String>(
                            value: uid,
                            child: Row(
                              children: [
                                Icon(
                                  userIsAdmin ? Icons.admin_panel_settings : Icons.person,
                                  color: userIsAdmin ? BmbColors.gold : BmbColors.textTertiary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${isMe ? "(ME) " : ""}$name',
                                        style: TextStyle(
                                          color: BmbColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: isMe ? BmbFontWeights.bold : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (email.isNotEmpty)
                                        Text(email,
                                            style: TextStyle(color: BmbColors.textTertiary, fontSize: 9),
                                            overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Text('$credits cr',
                                    style: TextStyle(
                                        color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedUserId = val;
                            final user = allUsers.firstWhere(
                              (u) => u['doc_id'] == val,
                              orElse: () => <String, dynamic>{},
                            );
                            selectedUserLabel = user['display_name'] as String? ?? user['email'] as String? ?? 'Unknown';
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Amount field ──
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: BmbColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Credit Amount',
                      labelStyle: TextStyle(color: BmbColors.textTertiary),
                      prefixIcon: const Icon(Icons.monetization_on, color: BmbColors.textSecondary),
                      filled: true,
                      fillColor: BmbColors.cardDark,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: BmbColors.borderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: BmbColors.borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: BmbColors.blue)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Reason field ──
                  TextField(
                    controller: reasonController,
                    style: TextStyle(color: BmbColors.textPrimary),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Reason (optional)',
                      labelStyle: TextStyle(color: BmbColors.textTertiary),
                      prefixIcon: const Icon(Icons.note, color: BmbColors.textSecondary),
                      filled: true,
                      fillColor: BmbColors.cardDark,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: BmbColors.borderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: BmbColors.borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: BmbColors.blue)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Admin hint
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BmbColors.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: BmbColors.gold, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isAdd
                                ? 'Credits will be added directly — no payment required for admin.'
                                : 'Credits will be deducted from the selected user\'s balance.',
                            style: TextStyle(color: BmbColors.gold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = int.tryParse(amountController.text.trim()) ?? 0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: const Text('Please enter a valid amount greater than 0'),
                          backgroundColor: BmbColors.errorRed),
                    );
                    return;
                  }
                  if (selectedUserId == null || selectedUserId!.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: const Text('Please select a user'),
                          backgroundColor: BmbColors.errorRed),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final actualAmount = isAdd ? amount : -amount;
                  final reason = reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : (isAdd ? 'Admin credit addition' : 'Admin credit deduction');
                  try {
                    // Use adminAdjustCredits which BOTH updates balance AND logs transaction
                    await FirestoreService.instance.adminAdjustCredits(
                      selectedUserId!,
                      actualAmount,
                      reason,
                    );
                    _showSnack(
                      '${isAdd ? "Added" : "Deducted"} $amount credits ${isAdd ? "to" : "from"} $selectedUserLabel',
                    );
                    // Reload dashboard data to reflect changes
                    _loadUserData();
                  } catch (e) {
                    _showSnack('Error adjusting credits: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdd ? BmbColors.successGreen : BmbColors.errorRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isAdd ? 'Add Credits' : 'Deduct Credits'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── ARCHIVED BRACKETS IN PROFILE ──────────────────────────────────
  Widget _buildProfileArchivedBrackets() {
    final archived = _boardService.allArchived;
    if (archived.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2, color: Color(0xFF00BCD4), size: 20),
            const SizedBox(width: 8),
            Text('Archived Brackets',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${archived.length}',
                  style: TextStyle(
                      color: const Color(0xFF00BCD4),
                      fontSize: 12,
                      fontWeight: BmbFontWeights.bold)),
            ),
            const Spacer(),
            if (archived.length > 3)
              GestureDetector(
                onTap: () => _showArchivedBracketsSheet(),
                child: Text('See All',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.semiBold)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Show first 3 archived brackets
        ...archived.take(3).map((b) => _buildArchivedBracketTile(b)),
      ],
    );
  }

  Widget _buildArchivedBracketTile(BracketItem bracket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
          // Sport icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _getSportColor(bracket.sport).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getSportIcon(bracket.sport),
                color: _getSportColor(bracket.sport), size: 24),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bracket.title,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.semiBold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (bracket.host != null) ...[
                      Icon(Icons.person, size: 12, color: BmbColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(bracket.host!.name,
                          style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.people, size: 12, color: BmbColors.textTertiary),
                    const SizedBox(width: 3),
                    Text('${bracket.participants}',
                        style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                    const SizedBox(width: 8),
                    // Completed badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: const Color(0xFF00BCD4), size: 10),
                          const SizedBox(width: 3),
                          Text('COMPLETED',
                              style: TextStyle(
                                  color: const Color(0xFF00BCD4),
                                  fontSize: 9,
                                  fontWeight: BmbFontWeights.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Reward indicator
          if (bracket.rewardType == RewardType.custom)
            Icon(Icons.card_giftcard, color: const Color(0xFFFF6B35), size: 18)
          else if (bracket.rewardType == RewardType.credits)
            Icon(Icons.savings, color: BmbColors.gold, size: 18)
          else if (bracket.rewardType == RewardType.charity)
            Icon(Icons.volunteer_activism, color: BmbColors.successGreen, size: 18)
          else
            Icon(Icons.emoji_events, color: BmbColors.textTertiary, size: 18),
        ],
      ),
    );
  }

  void _showArchivedBracketsSheet() {
    final archived = _boardService.allArchived;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BmbColors.midNavy, BmbColors.deepNavy],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: BmbColors.borderColor,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Color(0xFF00BCD4), size: 22),
                    const SizedBox(width: 8),
                    Text('Archived Brackets',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${archived.length}',
                          style: TextStyle(
                              color: const Color(0xFF00BCD4),
                              fontSize: 12,
                              fontWeight: BmbFontWeights.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Completed brackets are archived here. They no longer appear on the board.',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: BmbColors.borderColor, height: 1),
              // List
              Expanded(
                child: archived.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, color: BmbColors.textTertiary, size: 48),
                            const SizedBox(height: 12),
                            Text('No archived brackets yet',
                                style: TextStyle(color: BmbColors.textTertiary, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: archived.length,
                        itemBuilder: (_, i) => _buildArchivedBracketTile(archived[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HOW TO VIDEOS LAUNCHER ──────────────────────────────────────────
  void _openHowToVideos({required bool business}) async {
    // Use relative path so it works on any host (sandbox or production)
    final base = Uri.base.toString().replaceAll(RegExp(r'[#?].*'), '');
    final page = business ? 'video-gallery.html' : 'how-to-play.html';
    final url = '$base$page';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Visit $url'),
          backgroundColor: BmbColors.midNavy,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _buildProfileMenu() {
    final items = [
      ('Account Settings', Icons.settings, () async {
        final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
        if (updated == true) _loadUserData();
      }),
      ('Profile Photo', Icons.camera_alt, () async {
        final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ProfilePhotoScreen()));
        if (updated == true) _loadUserData();
      }),
      ('My Favorites', Icons.star, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteTeamsScreen()))),
      (_isBusiness ? 'BMB+biz Account' : 'Upgrade to BMB+', Icons.workspace_premium, () {
        if (_isBmbPlus) { BmbPlusModal.show(context, isBmbPlus: true); }
        else { Navigator.push(context, MaterialPageRoute(builder: (_) => const BmbPlusUpgradeScreen())); }
      }),
      ('BMB Bucket', Icons.savings, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BmbBucksPurchaseScreen()))),
      ('BMB Store', Icons.storefront, () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const BmbStoreScreen()));
        _loadUserData();
      }),
      ('Gift Card Store', Icons.card_giftcard, () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftCardStoreScreen()));
        _loadUserData();
      }),
      ('Inbox', Icons.inbox, () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()));
      }),
      ('BMB Community', Icons.forum, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityChatScreen()))),
      ('Squares Game', Icons.grid_4x4, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SquaresHubScreen()))),
      ('Bracket Templates', Icons.account_tree, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BracketTemplateScreen()))),
      ('Back It — Print', Icons.checkroom, () => Navigator.push(context, MaterialPageRoute(builder: (_) => BackItFlowScreen(
        bracketId: 'demo_bracket',
        bracketTitle: 'MARCH MADNESS 2025',
        championName: 'DUKE',
        teamCount: 16,
        teams: const ['Duke', 'Auburn', 'Florida', 'Tennessee', 'Houston', 'Gonzaga', 'Alabama', 'Purdue', 'UConn', 'Iowa State', 'Michigan State', 'Arizona', 'Baylor', 'Marquette', 'Kentucky', 'Kansas'],
        picks: const {},
      )))),
      ('Refer a Friend', Icons.card_giftcard, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralScreen()))),
      ('Follow Us', Icons.share, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialLinksScreen()))),
      ('BMB Hype Man', Icons.record_voice_over, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HypeManDemoScreen()))),
      ('Auto-Pilot Wizard', Icons.auto_awesome, () async {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AutoPilotWizardScreen()));
        if (result == true) { _loadFirestoreBrackets(); }
      }),
      ('My Templates', Icons.folder_special, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTemplatesScreen()))),
      if (_isAdmin) ('Admin Panel', Icons.admin_panel_settings, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()))),
      if (_isAdmin) ('Social Follow Promo', Icons.campaign, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialPromoAdminScreen()))),
      if (_isBusiness) ('How To', Icons.ondemand_video, () => _openHowToVideos(business: true)),
      if (!_isBusiness) ('How To', Icons.ondemand_video, () => _openHowToVideos(business: false)),
      if (_isBusiness || _isBmbPlus) ('Business Hub', Icons.storefront, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessHubScreen()))),
      ('Live Chat Support', Icons.support_agent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSupportChatScreen()))),
      ('Help & Support', Icons.help_outline, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
      ('About', Icons.info_outline, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()))),
    ];
    return Column(
      children: items.map((item) {
        final (label, icon, onTap) = item;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: BmbColors.borderColor, width: 0.5),
          ),
          child: ListTile(
            leading: Icon(icon, color: BmbColors.textSecondary, size: 22),
            title: Text(label,
                style: TextStyle(
                    color: BmbColors.textPrimary, fontSize: 14)),
            trailing: const Icon(Icons.chevron_right,
                color: BmbColors.textTertiary, size: 20),
            onTap: onTap,
            dense: true,
          ),
        );
      }).toList(),
    );
  }

  // ─── BOTTOM NAV ─────────────────────────────────────────────────────────
  // ── Companion context-aware message for dashboard ──
  String get _companionDashboardMessage {
    final persona = CompanionService.instance.selectedCompanion;
    if (persona == null) return '';
    final tabs = ['Home', 'Explore', 'My Brackets', 'Profile'];
    final tab = tabs[_currentNavIndex];
    switch (persona.id) {
      case 'jake':
        switch (_currentNavIndex) {
          case 0: return 'Yo! Welcome back! Ready to crush some brackets today?';
          case 1: return 'Check out what\'s trending! Some fire tournaments here!';
          case 2: return 'Your brackets are looking solid! Let\'s build another one!';
          case 3: return 'Looking good! Make sure your profile is fresh!';
          default: return 'Let\'s GO!';
        }
      case 'marcus':
        switch (_currentNavIndex) {
          case 0: return 'What\'s up. Let\'s see what\'s on the board today.';
          case 1: return 'Some interesting matchups here. I see a few worth joining.';
          case 2: return 'Your bracket portfolio. Let\'s analyze what\'s working.';
          case 3: return 'Keep your profile updated. Credibility matters.';
          default: return 'Let\'s get to work.';
        }
      case 'alex':
        switch (_currentNavIndex) {
          case 0: return 'Hey! Let\'s see what we\'re working with today.';
          case 1: return 'Ooh, some good ones in here. I\'ve already spotted a few picks.';
          case 2: return 'Your brackets! Let\'s see how our strategy is playing out.';
          case 3: return 'Profile looking sharp. Don\'t forget to update your faves!';
          default: return 'Let\'s do this!';
        }
      default:
        return 'Welcome to $tab!';
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: BmbColors.deepNavy,
        border: Border(
            top: BorderSide(
                color: BmbColors.borderColor.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.explore_outlined, 'Explore'),
              // Center Create button
              _buildCenterButton(),
              _buildNavItem(2, Icons.view_list_rounded, 'Brackets'),
              _buildNavItem(3, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? BmbColors.blue : BmbColors.textTertiary,
                size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: isSelected
                        ? BmbColors.blue
                        : BmbColors.textTertiary,
                    fontSize: 10,
                    fontWeight:
                        isSelected ? BmbFontWeights.bold : BmbFontWeights.regular)),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: _openBracketBuilder,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [BmbColors.blue, const Color(0xFF5B6EFF)]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: BmbColors.blue.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────
  // ─── AVATAR HELPERS ──────────────────────────────
  static const _avatarColors = [
    Color(0xFF2137FF), Color(0xFFFF6B35), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFFE53935), Color(0xFF1E88E5),
    Color(0xFFFDD835), Color(0xFF795548), Color(0xFF00BCD4),
  ];
  static const _avatarIcons = [
    Icons.person, Icons.sports_basketball, Icons.sports_football,
    Icons.sports_baseball, Icons.sports_soccer, Icons.sports_hockey,
    Icons.emoji_events, Icons.star, Icons.sports_tennis,
  ];
  Color get _avatarColor => _avatarColors[_avatarIndex % _avatarColors.length];
  IconData get _avatarIcon => _avatarIcons[_avatarIndex % _avatarIcons.length];

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball':
        return Icons.sports_basketball;
      case 'football':
        return Icons.sports_football;
      case 'baseball':
        return Icons.sports_baseball;
      case 'soccer':
        return Icons.sports_soccer;
      case 'hockey':
        return Icons.sports_hockey;
      case 'golf':
        return Icons.sports_golf;
      case 'tennis':
        return Icons.sports_tennis;
      case 'mma':
        return Icons.sports_mma;
      case 'voting':
        return Icons.how_to_vote;
      case 'general':
        return Icons.quiz;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getSportColor(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball':
        return const Color(0xFFFF6B35);
      case 'football':
        return const Color(0xFF795548);
      case 'baseball':
        return const Color(0xFFE53935);
      case 'soccer':
        return const Color(0xFF4CAF50);
      case 'hockey':
        return const Color(0xFF1E88E5);
      case 'golf':
        return const Color(0xFF388E3C);
      case 'tennis':
        return const Color(0xFFFDD835);
      case 'mma':
        return const Color(0xFFD32F2F);
      case 'voting':
        return const Color(0xFF9C27B0);
      case 'general':
        return const Color(0xFF9C27B0);
      default:
        return BmbColors.gold;
    }
  }

  // ─── GAME TYPE HELPERS ──────────────────────────────────────────────
  IconData _gameTypeIcon(GameType type) {
    switch (type) {
      case GameType.bracket: return Icons.account_tree;
      case GameType.pickem: return Icons.checklist;
      case GameType.squares: return Icons.grid_4x4;
      case GameType.trivia: return Icons.quiz;
      case GameType.props: return Icons.trending_up;
      case GameType.survivor: return Icons.shield;
      case GameType.voting: return Icons.how_to_vote;
    }
  }

  Color _gameTypeColor(GameType type) {
    switch (type) {
      case GameType.bracket: return const Color(0xFF2137FF);
      case GameType.pickem: return const Color(0xFFFF6B35);
      case GameType.squares: return const Color(0xFFFFC107);
      case GameType.trivia: return const Color(0xFF9C27B0);
      case GameType.props: return const Color(0xFF00BCD4);
      case GameType.survivor: return const Color(0xFFE53935);
      case GameType.voting: return const Color(0xFF9C27B0);
    }
  }

  void _showFilteredBrackets(String sportName) {
    final filtered = _featuredBrackets
        .where((b) => b.sport.toLowerCase() == sportName.toLowerCase())
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: BmbColors.borderColor,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 16),
                      Text('$sportName Brackets',
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 20,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getSportIcon(sportName),
                                  color: BmbColors.textTertiary, size: 48),
                              const SizedBox(height: 12),
                              Text('No $sportName brackets right now',
                                  style: TextStyle(
                                      color: BmbColors.textTertiary,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Check back soon!',
                                  style: TextStyle(
                                      color: BmbColors.textTertiary,
                                      fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final b = filtered[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => BracketDetailScreen(bracket: b, hasJoinedHint: _isUserJoinedBoardBracket(b.id) ? true : null)));
                              },
                              child: _buildLiveBracketTile(b),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openChat(BracketItem bracket) async {
    final allowed = await ChatAccessGate.checkAndNavigate(
      context: context,
      bracketId: bracket.id,
      bracketTitle: bracket.title,
      hostName: bracket.host?.name ?? 'Unknown',
      participantCount: bracket.participants,
      bracket: bracket,
    );
    if (allowed && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentChatScreen(
            bracketId: bracket.id,
            bracketTitle: bracket.title,
            hostName: bracket.host?.name ?? 'Unknown',
            participantCount: bracket.participants,
          ),
        ),
      );
    }
  }

  Future<void> _openBracketBuilder() async {
    final result = await Navigator.push<CreatedBracket>(
      context,
      MaterialPageRoute(builder: (_) => const BracketBuilderScreen()),
    );
    if (result != null && mounted) {
      // ═══ PHASE 3: Save bracket to Firestore ═══
      String? firestoreId;
      try {
        firestoreId = await FirestoreService.instance.createBracket(result.toFirestoreMap());
        if (kDebugMode) debugPrint('Bracket saved to Firestore: $firestoreId');
      } catch (e) {
        if (kDebugMode) debugPrint('Firestore save failed (local only): $e');
      }

      // Use Firestore ID if available, otherwise keep local ID
      final savedBracket = firestoreId != null
          ? CreatedBracket(
              id: firestoreId,
              name: result.name,
              templateId: result.templateId,
              sport: result.sport,
              teamCount: result.teamCount,
              teams: result.teams,
              isFreeEntry: result.isFreeEntry,
              entryDonation: result.entryDonation,
              prizeType: result.prizeType,
              prizeDescription: result.prizeDescription,
              storePrizeId: result.storePrizeId,
              storePrizeName: result.storePrizeName,
              storePrizeCost: result.storePrizeCost,
              status: result.status,
              createdAt: result.createdAt,
              scheduledLiveDate: result.scheduledLiveDate,
              hostId: result.hostId,
              hostName: result.hostName,
              hostState: result.hostState,
              bracketType: result.bracketType,
              tieBreakerGame: result.tieBreakerGame,
              autoHost: result.autoHost,
              minPlayers: result.minPlayers,
              isPublic: result.isPublic,
              addToBracketBoard: result.addToBracketBoard,
              charityName: result.charityName,
              charityGoal: result.charityGoal,
              hasGiveaway: result.hasGiveaway,
              giveawayWinnerCount: result.giveawayWinnerCount,
              giveawayTokensPerWinner: result.giveawayTokensPerWinner,
              joinedPlayers: result.joinedPlayers,
            )
          : result;

      setState(() => _createdBrackets.insert(0, savedBracket));
      _showSnack('Bracket "${result.name}" saved! Check My Brackets tab.');
      // Fire hype trigger for bracket creation
      final gameType = result.templateId.toLowerCase();
      if (gameType.contains('squares')) {
        _hypeMan.trigger(HypeTrigger.createdSquares, context: result.sport);
      } else if (gameType.contains('pickem') || gameType.contains('pick_em')) {
        _hypeMan.trigger(HypeTrigger.createdPickem, context: result.sport);
      } else if (gameType.contains('trivia')) {
        _hypeMan.trigger(HypeTrigger.createdTrivia, context: result.sport);
      } else if (gameType.contains('survivor')) {
        _hypeMan.trigger(HypeTrigger.createdSurvivor, context: result.sport);
      } else if (gameType.contains('vote') || gameType.contains('community')) {
        _hypeMan.trigger(HypeTrigger.createdVote, context: result.sport);
      } else {
        _hypeMan.trigger(HypeTrigger.createdBracket, context: result.sport);
      }
      // Auto-switch to My Brackets tab
      setState(() => _currentNavIndex = 2);
      // Reload prefs in case user upgraded during builder flow
      _loadUserData();
    }
  }

  // ─── FULL EDIT: open wizard pre-filled with existing bracket ───
  Future<void> _editBracketFull(CreatedBracket bracket) async {
    final result = await Navigator.push<CreatedBracket>(
      context,
      MaterialPageRoute(builder: (_) => BracketBuilderScreen(editBracket: bracket)),
    );
    if (result != null && mounted) {
      setState(() {
        final idx = _createdBrackets.indexWhere((b) => b.id == result.id);
        if (idx >= 0) {
          _createdBrackets[idx] = result;
        }
      });
      // ═══ PHASE 3: Update bracket in Firestore ═══
      _syncBracketToFirestore(result.id, result.toFirestoreMap());
      _showSnack('Bracket "${result.name}" updated!');
    }
  }

  // ─── TBD-ONLY EDIT: bottom sheet for changing TBD to real team names ───
  void _editBracketTbdOnly(CreatedBracket bracket) {
    final controllers = bracket.teams.map((t) => TextEditingController(text: t)).toList();
    final isPickEm = bracket.isPickEm;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: BmbColors.midNavy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ─ Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              // ─ Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: BmbColors.blue, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Team Names', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                          Text('Replace TBD with actual ${bracket.isVoting ? 'item' : 'team'} names', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: BmbColors.borderColor, height: 1),
              // ─ Sync banner for BMB template brackets
              if (bracket.templateId != 'custom' && !bracket.templateId.startsWith('custom_') &&
                  !bracket.templateId.startsWith('pickem_') && !bracket.templateId.startsWith('voting_')) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.sync, color: BmbColors.successGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'This bracket uses a BMB template. TBD names will auto-sync when the official schedule is released.',
                      style: TextStyle(color: BmbColors.successGreen, fontSize: 11, height: 1.3),
                    )),
                  ]),
                ),
              ],
              // ─ Team list
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: isPickEm ? controllers.length ~/ 2 : controllers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (isPickEm) {
                      final aCtrl = controllers[i * 2];
                      final bCtrl = controllers[i * 2 + 1];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: BmbColors.cardGradient,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: BmbColors.borderColor, width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Matchup ${i + 1}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(child: _tbdTextField(aCtrl, 'Team A')),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('vs', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                              ),
                              Expanded(child: _tbdTextField(bCtrl, 'Team B')),
                            ]),
                          ],
                        ),
                      );
                    }
                    final ctrl = controllers[i];
                    final isTbd = ctrl.text.trim().toUpperCase() == 'TBD';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: BmbColors.cardGradient,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isTbd ? BmbColors.gold.withValues(alpha: 0.4) : BmbColors.borderColor, width: 0.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: isTbd ? BmbColors.gold.withValues(alpha: 0.15) : BmbColors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}', style: TextStyle(
                            color: isTbd ? BmbColors.gold : BmbColors.blue,
                            fontSize: 11, fontWeight: BmbFontWeights.bold,
                          )),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _tbdTextField(ctrl, bracket.isVoting ? 'Item ${i + 1}' : 'Team ${i + 1}')),
                      ]),
                    );
                  },
                ),
              ),
              // ─ Save button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: BmbColors.deepNavy.withValues(alpha: 0.9),
                  border: Border(top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          for (final c in controllers) { c.dispose(); }
                          Navigator.pop(ctx);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: BmbColors.borderColor),
                          foregroundColor: BmbColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final newTeams = controllers.map((c) => c.text.trim()).toList();
                          setState(() {
                            final idx = _createdBrackets.indexWhere((b) => b.id == bracket.id);
                            if (idx >= 0) {
                              _createdBrackets[idx] = bracket.copyWith(teams: newTeams);
                            }
                          });
                          for (final c in controllers) { c.dispose(); }
                          Navigator.pop(ctx);
                          _showSnack('Team names updated!');
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: Text('Save Names', style: TextStyle(fontWeight: BmbFontWeights.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BmbColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Text field for TBD editing — highlights TBD fields
  Widget _tbdTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: BmbColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        hintText: hint,
        hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
        filled: true,
        fillColor: BmbColors.cardDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.borderColor, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.blue, width: 1)),
      ),
    );
  }

  void _openPostTournamentReview(CreatedBracket bracket) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostTournamentReviewScreen(
          hostId: bracket.hostId,
          hostName: bracket.hostName,
          tournamentId: bracket.id,
          tournamentName: bracket.name,
          playerId: _currentUser.id,
          playerName: _currentUser.displayNameOrUsername,
          playerState: _currentUser.stateAbbr,
        ),
      ),
    );
    if (result == true && mounted) {
      // Refresh host ratings after a new review
      setState(() => _recomputeTopHosts());
      _showSnack('Review submitted! Host ratings updated.');
      _hypeMan.trigger(HypeTrigger.ratedHost);
    }
  }

  void _openBracketPicks(CreatedBracket bracket) {
    final readOnly = bracket.status == 'in_progress' || bracket.status == 'done';
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BracketPicksScreen(bracket: bracket, readOnly: readOnly)),
    );
  }

  void _openHostManager(CreatedBracket bracket) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => HostBracketManagerScreen(bracket: bracket)),
    );
  }

  /// Convert a [CreatedBracket] to a [BracketItem] for screens that expect it.
  BracketItem _toBracketItem(CreatedBracket b) {
    // Look up host from the _topHosts list or create a fallback
    final host = _topHosts.cast<BracketHost?>().firstWhere(
        (h) => h!.id == b.hostId, orElse: () => BracketHost(
          id: b.hostId, name: b.hostName,
          rating: 4.0, reviewCount: 0, isVerified: false,
          isTopHost: false, location: b.hostState ?? '', totalHosted: 0));
    return BracketItem(
      id: b.id,
      title: b.name,
      sport: b.sport,
      participants: b.participantCount,
      entryFee: b.isFreeEntry ? 0.0 : b.entryDonation.toDouble(),
      prizeAmount: 0,
      host: host,
      status: b.status,
      gameType: b.bracketType == 'pickem' ? GameType.pickem
          : b.bracketType == 'voting' ? GameType.voting
          : GameType.bracket,
      usesBmbBucks: !b.isFreeEntry,
      entryCredits: b.isFreeEntry ? null : b.entryDonation,
      isPublic: b.isPublic,
      rewardType: b.prizeType == 'custom' ? RewardType.custom
          : b.prizeType == 'charity' ? RewardType.charity
          : b.prizeType == 'none' ? RewardType.none
          : RewardType.credits,
      rewardDescription: b.prizeDescription ?? '',
      totalGames: b.totalMatchups,
      maxParticipants: 0, // unlimited — no participant cap
    );
  }

  void _openLeaderboard(CreatedBracket bracket) {
    _hypeMan.trigger(HypeTrigger.viewedLeaderboard);
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => bracket.isVoting
              ? VotingLeaderboardScreen(bracket: bracket)
              : LeaderboardScreen(bracket: bracket)),
    );
  }

  void _showNoPicks(CreatedBracket bracket) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx2, sc) {
            return SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Icon(bracket.isVoting ? Icons.how_to_vote : Icons.visibility, color: bracket.isVoting ? const Color(0xFF9C27B0) : BmbColors.successGreen, size: 40),
                  const SizedBox(height: 12),
                  Text(bracket.name, style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: BmbColors.successGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text(bracket.bracketTypeLabel, style: TextStyle(color: BmbColors.successGreen, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                  ),
                  const SizedBox(height: 20),
                  Text(bracket.bracketType == 'nopicks'
                      ? 'This bracket has pre-loaded teams. Follow along as outcomes unfold — no picks needed!'
                      : 'Cast your votes for each matchup!',
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  // Team list
                  ...List.generate(
                    (bracket.teamCount > 16 ? 16 : bracket.teamCount),
                    (i) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
                      child: Row(children: [
                        Text('${i + 1}', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(bracket.teams[i], style: TextStyle(color: BmbColors.textPrimary, fontSize: 13))),
                        if (bracket.isVoting && bracket.itemPhotos != null && i < bracket.itemPhotos!.length && bracket.itemPhotos![i])
                          const Icon(Icons.photo, color: Color(0xFF9C27B0), size: 16),
                      ]),
                    ),
                  ),
                  if (bracket.teamCount > 16)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text('+ ${bracket.teamCount - 16} more', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12))),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: BmbColors.midNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showPrizeSheet(BracketItem bracket) {
    // Determine icon, color, and content based on reward type
    IconData rewardIcon;
    Color rewardColor;
    String rewardLabel;

    switch (bracket.rewardType) {
      case RewardType.custom:
        rewardIcon = Icons.card_giftcard;
        rewardColor = const Color(0xFFFF6B35);
        rewardLabel = 'CUSTOM REWARD';
        break;
      case RewardType.charity:
        rewardIcon = Icons.volunteer_activism;
        rewardColor = BmbColors.successGreen;
        rewardLabel = 'CHARITY';
        break;
      case RewardType.none:
        rewardIcon = Icons.emoji_events;
        rewardColor = BmbColors.textTertiary;
        rewardLabel = 'FOR THE LOVE OF THE GAME';
        break;
      case RewardType.credits:
        rewardIcon = Icons.savings;
        rewardColor = BmbColors.gold;
        rewardLabel = 'CREDITS REWARD';
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: BmbColors.borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),

              // Reward type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: rewardColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rewardColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(rewardIcon, color: rewardColor, size: 16),
                    const SizedBox(width: 6),
                    Text(rewardLabel,
                        style: TextStyle(
                            color: rewardColor,
                            fontSize: 11,
                            fontWeight: BmbFontWeights.bold,
                            letterSpacing: 0.8)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Large reward icon
              Icon(rewardIcon, color: rewardColor, size: 48),
              const SizedBox(height: 12),

              Text('Reward Details',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 20,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 8),
              Text(bracket.title,
                  style: TextStyle(
                      color: BmbColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),

              // ── REWARD CONTENT ────────────────────────────────
              if (bracket.rewardType == RewardType.credits) ...[
                // Credits display
                if (bracket.prizeCredits != null && bracket.prizeCredits! > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.savings, color: BmbColors.gold, size: 28),
                      const SizedBox(width: 8),
                      Text('${bracket.prizeCredits} credits',
                          style: TextStyle(
                              color: BmbColors.gold,
                              fontSize: 32,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                    ],
                  )
                else if (bracket.prizeAmount > 0)
                  Text('${bracket.prizeAmount.toStringAsFixed(0)} credits',
                      style: TextStyle(
                          color: BmbColors.gold,
                          fontSize: 32,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay')),
              ] else if (bracket.rewardType == RewardType.custom) ...[
                // Custom reward description from host
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFFFF6B35).withValues(alpha: 0.1),
                      BmbColors.gold.withValues(alpha: 0.06),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(bracket.rewardDescription,
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 18,
                              fontWeight: BmbFontWeights.bold,
                              height: 1.4),
                          textAlign: TextAlign.center),
                      if (bracket.prizeAmount > 0) ...[
                        const SizedBox(height: 10),
                        Text('+ ${bracket.prizeAmount.toStringAsFixed(0)} credits',
                            style: TextStyle(
                                color: BmbColors.gold,
                                fontSize: 16,
                                fontWeight: BmbFontWeights.semiBold)),
                      ],
                    ],
                  ),
                ),
              ] else if (bracket.rewardType == RewardType.charity) ...[
                // Charity display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      BmbColors.successGreen.withValues(alpha: 0.1),
                      BmbColors.successGreen.withValues(alpha: 0.04),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.volunteer_activism,
                          color: BmbColors.successGreen, size: 28),
                      const SizedBox(height: 8),
                      Text('All proceeds support:',
                          style: TextStyle(
                              color: BmbColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(bracket.rewardDescription,
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 18,
                              fontWeight: BmbFontWeights.bold,
                              height: 1.3),
                          textAlign: TextAlign.center),
                      if (bracket.prizeAmount > 0) ...[
                        const SizedBox(height: 10),
                        Text('Winner also receives ${bracket.prizeAmount.toStringAsFixed(0)} credits',
                            style: TextStyle(
                                color: BmbColors.gold,
                                fontSize: 14,
                                fontWeight: BmbFontWeights.semiBold)),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // No reward — bragging rights
                Text(bracket.rewardDescription.isNotEmpty
                    ? bracket.rewardDescription
                    : 'No credits reward — just pure bragging rights!',
                    style: TextStyle(
                        color: BmbColors.textSecondary,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.medium,
                        height: 1.4),
                    textAlign: TextAlign.center),
              ],

              const SizedBox(height: 24),
              // ── PERSONALIZED ACTION BUTTON ──
              // Shows different label/action based on whether user has joined
              Builder(builder: (innerCtx) {
                final userJoined = _isUserJoinedBoardBracket(bracket.id);
                final userPicked = _hasUserPickedBoardBracket(bracket.id);

                if (userJoined && userPicked) {
                  // Already joined + made picks → View/Re-Pick
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(innerCtx);
                        _openFeaturedBracketPicks(bracket);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text('Re-Pick',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: BmbFontWeights.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                } else if (userJoined) {
                  // Joined but no picks → Make Picks
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(innerCtx);
                        _openFeaturedBracketPicks(bracket);
                      },
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: Text('Make My Picks',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: BmbFontWeights.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                } else {
                  // Not joined → Join Now
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(innerCtx);
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => TournamentJoinScreen(bracket: bracket))).then((_) {
                          _loadBoardUserState();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.buttonPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Join Now',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: BmbFontWeights.bold)),
                    ),
                  );
                }
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showHostProfile(BracketHost host) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final isOfficial = host.name == 'Back My Bracket';
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: BmbColors.borderColor,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  // Host avatar
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: host.profileImageUrl == null
                              ? (isOfficial
                                  ? LinearGradient(colors: [
                                      BmbColors.blue,
                                      BmbColors.blue.withValues(alpha: 0.7)
                                    ])
                                  : LinearGradient(colors: [
                                      BmbColors.gold.withValues(alpha: 0.3),
                                      BmbColors.gold.withValues(alpha: 0.1)
                                    ]))
                              : null,
                          image: host.profileImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(host.profileImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          border: Border.all(
                            color: isOfficial
                                ? BmbColors.blue
                                : BmbColors.gold,
                            width: 3,
                          ),
                        ),
                        child: host.profileImageUrl != null
                            ? null
                            : Icon(
                                isOfficial ? Icons.emoji_events : Icons.person,
                                color: isOfficial ? Colors.white : BmbColors.gold,
                                size: 40,
                              ),
                      ),
                      if (host.isVerified)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: BmbColors.midNavy,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.verified,
                                color: BmbColors.blue, size: 20),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(host.name,
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 20,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                      if (host.isTopHost && !isOfficial) ...[
                        const SizedBox(width: 8),
                        _buildBadgeChip('Top Host', BmbColors.gold),
                      ],
                      if (isOfficial) ...[
                        const SizedBox(width: 8),
                        _buildBadgeChip('Official', BmbColors.blue),
                      ],
                    ],
                  ),
                  if (host.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on,
                            color: BmbColors.textTertiary, size: 14),
                        const SizedBox(width: 4),
                        Text(host.location!,
                            style: TextStyle(
                                color: BmbColors.textTertiary,
                                fontSize: 13)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Rating (live from reviews)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...List.generate(5, (i) {
                        final liveRating = _reviewService.getAverageRating(host.id);
                        final rating = liveRating > 0 ? liveRating : host.rating;
                        if (i < rating.floor()) {
                          return const Icon(Icons.star,
                              color: BmbColors.gold, size: 20);
                        } else if (i < rating) {
                          return const Icon(Icons.star_half,
                              color: BmbColors.gold, size: 20);
                        }
                        return Icon(Icons.star_border,
                            color: BmbColors.gold.withValues(alpha: 0.3),
                            size: 20);
                      }),
                      const SizedBox(width: 8),
                      Builder(builder: (_) {
                        final liveRating = _reviewService.getAverageRating(host.id);
                        final liveCount = _reviewService.getReviewCount(host.id);
                        final rating = liveRating > 0 ? liveRating : host.rating;
                        final count = liveCount > 0 ? liveCount : host.reviewCount;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(rating.toStringAsFixed(1),
                                style: TextStyle(
                                    color: BmbColors.gold,
                                    fontSize: 16,
                                    fontWeight: BmbFontWeights.bold)),
                            Text(' ($count reviews)',
                                style: TextStyle(
                                    color: BmbColors.textTertiary,
                                    fontSize: 12)),
                          ],
                        );
                      }),
                    ],
                  ),
                  // Top Host earned badge
                  if (_reviewService.isTopHost(host.id, host.totalHosted)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.2), BmbColors.gold.withValues(alpha: 0.05)]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.military_tech, color: BmbColors.gold, size: 16),
                          const SizedBox(width: 4),
                          Text('Top Host', style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: BmbColors.successGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text('VIP Waived', style: TextStyle(color: BmbColors.successGreen, fontSize: 8, fontWeight: BmbFontWeights.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // View All Reviews button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => HostReviewsScreen(
                            hostId: host.id,
                            hostName: host.name,
                            totalHosted: host.totalHosted,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.rate_review, size: 18),
                      label: Text('View All Reviews (${_reviewService.getReviewCount(host.id)})',
                          style: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BmbColors.gold,
                        side: BorderSide(color: BmbColors.gold.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHostStatBubble(
                          '${host.totalHosted}', 'Hosted', BmbColors.gold),
                      const SizedBox(width: 24),
                      _buildHostStatBubble(
                          '${host.reviewCount}', 'Reviews', BmbColors.blue),
                      const SizedBox(width: 24),
                      _buildHostStatBubble('${host.rating}', 'Rating',
                          BmbColors.successGreen),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Active brackets by this host
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Active Brackets',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 16,
                            fontWeight: BmbFontWeights.bold)),
                  ),
                  const SizedBox(height: 12),
                  ..._featuredBrackets
                      .where((b) => b.host?.id == host.id)
                      .map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildLiveBracketTile(b),
                          )),
                  // ─── ARCHIVED BRACKETS FOR THIS HOST ───
                  Builder(builder: (_) {
                    final hostArchived = _boardService.archivedForHost(host.id);
                    if (hostArchived.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.inventory_2, color: Color(0xFF00BCD4), size: 18),
                            const SizedBox(width: 6),
                            Text('Archived Brackets',
                                style: TextStyle(
                                    color: BmbColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: BmbFontWeights.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${hostArchived.length}',
                                  style: TextStyle(
                                      color: const Color(0xFF00BCD4),
                                      fontSize: 11,
                                      fontWeight: BmbFontWeights.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...hostArchived.map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildArchivedBracketTile(b),
                            )),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHostStatBubble(String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: BmbFontWeights.bold)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: BmbColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Future<void> _handleLogout() async {
    // FIX #3: Clear biometric credentials + bot verification state on logout
    await BiometricAuthService.instance.clearSavedCredentials();
    await BotAccountService.instance.clearVerification();
    CurrentUserService.instance.clear();

    // Sign out from Firebase
    await FirebaseAuthService.instance.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/auth');
  }
}
