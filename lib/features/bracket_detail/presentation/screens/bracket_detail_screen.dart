import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/dashboard/data/models/bracket_item.dart';
import 'package:bmb_mobile/features/chat/presentation/screens/tournament_chat_screen.dart';
import 'package:bmb_mobile/features/chat/presentation/widgets/chat_access_gate.dart';
import 'package:bmb_mobile/features/chat/data/services/chat_access_service.dart';
import 'package:bmb_mobile/features/tournament/presentation/screens/tournament_join_screen.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/screens/back_it_flow_screen.dart';
import 'package:bmb_mobile/features/gift_cards/presentation/screens/gift_card_store_screen.dart';
import 'package:bmb_mobile/features/charity/data/services/charity_service.dart';
// CharityEscrowService is used by the GiftCardStoreScreen when the winner
// opens the charity picker — no direct usage needed here.
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/scoring/presentation/screens/bracket_picks_screen.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

class BracketDetailScreen extends StatefulWidget {
  final BracketItem bracket;
  /// Optional hint from the caller (e.g., the Joined tab already knows the
  /// user joined this bracket).  When `true` we skip the SharedPreferences
  /// lookup and show "Re-Pick" immediately.
  final bool? hasJoinedHint;
  const BracketDetailScreen({super.key, required this.bracket, this.hasJoinedHint});

  @override
  State<BracketDetailScreen> createState() => _BracketDetailScreenState();
}

class _BracketDetailScreenState extends State<BracketDetailScreen> {
  bool _hasJoined = false;
  bool _checkingJoin = true;

  BracketItem get bracket => widget.bracket;

  @override
  void initState() {
    super.initState();
    _checkJoinStatus();
  }

  Future<void> _checkJoinStatus() async {
    // If the caller already told us the user joined, trust it immediately
    // but still persist the join to SharedPreferences for consistency.
    if (widget.hasJoinedHint == true) {
      // Ensure SharedPreferences is in sync
      await ChatAccessService.recordJoin(bracket.id);
      if (mounted) {
        setState(() {
          _hasJoined = true;
          _checkingJoin = false;
        });
      }
      return;
    }
    final joined = await ChatAccessService.hasJoinedTournament(bracket.id);
    if (mounted) {
      setState(() {
        _hasJoined = joined;
        _checkingJoin = false;
      });
    }
  }

  /// Build a CreatedBracket from the BracketItem using the REAL teams data.
  /// This ensures picks screen shows the correct matchups that match the card.
  CreatedBracket _buildCreatedBracketFromItem() {
    final item = bracket;
    List<String> teams = List.from(item.teams);

    if (teams.isEmpty) {
      // Absolute last resort fallback
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
      status: item.status,
      createdAt: DateTime.now(),
      hostId: item.host?.id ?? 'unknown',
      hostName: item.host?.name ?? 'Unknown Host',
      hostState: item.host?.location,
      bracketType: bracketType,
      isFreeEntry: item.isFree,
      entryDonation: item.entryCredits ?? item.entryFee.toInt(),
    );
  }

  /// Navigate to picks screen for re-picking (already joined)
  void _navigateToRePick() {
    final createdBracket = _buildCreatedBracketFromItem();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BracketPicksScreen(bracket: createdBracket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = bracket.host;
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Bracket Details',
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 20,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                    ),
                    // Chat button (join-gated)
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: BmbColors.blue),
                      onPressed: () async {
                        final allowed = await ChatAccessGate.checkAndNavigate(
                          context: context,
                          bracketId: bracket.id,
                          bracketTitle: bracket.title,
                          hostName: host?.name ?? 'Unknown',
                          participantCount: bracket.participants,
                          bracket: bracket,
                        );
                        if (allowed && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentChatScreen(
                                bracketId: bracket.id,
                                bracketTitle: bracket.title,
                                hostName: host?.name ?? 'Unknown',
                                participantCount: bracket.participants,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    // Share button
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: BmbColors.textSecondary),
                      onPressed: () => _showShareSheet(context, bracket),
                    ),
                    // Back It button
                    IconButton(
                      icon: const Icon(Icons.checkroom,
                          color: Color(0xFF9C27B0)),
                      tooltip: 'Back It',
                      onPressed: () {
                        final teams = bracket.teams.isNotEmpty
                            ? bracket.teams
                            : List.generate(8, (i) => 'Team ${i + 1}');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BackItFlowScreen(
                              bracketId: bracket.id,
                              bracketTitle: bracket.title,
                              championName: 'TBD',
                              teamCount: teams.length,
                              teams: teams,
                              picks: const {},
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sport icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _getSportColor(bracket.sport)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(_getSportIcon(bracket.sport),
                                color: _getSportColor(bracket.sport),
                                size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(bracket.title,
                                    style: TextStyle(
                                        color: BmbColors.textPrimary,
                                        fontSize: 20,
                                        fontWeight: BmbFontWeights.bold,
                                        fontFamily: 'ClashDisplay')),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: bracket.status == 'live'
                                            ? BmbColors.successGreen
                                                .withValues(alpha: 0.2)
                                            : BmbColors.gold
                                                .withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (bracket.status == 'live')
                                            Container(
                                              width: 6,
                                              height: 6,
                                              margin: const EdgeInsets
                                                  .only(right: 4),
                                              decoration:
                                                  const BoxDecoration(
                                                      color: BmbColors
                                                          .successGreen,
                                                      shape:
                                                          BoxShape.circle),
                                            ),
                                          Text(
                                            bracket.status.toUpperCase(),
                                            style: TextStyle(
                                              color: bracket.status ==
                                                      'live'
                                                  ? BmbColors.successGreen
                                                  : BmbColors.gold,
                                              fontSize: 10,
                                              fontWeight:
                                                  BmbFontWeights.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(bracket.sport,
                                        style: TextStyle(
                                            color: BmbColors.textTertiary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Description (venue, time, etc.)
                      if (bracket.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: BmbColors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BmbColors.blue.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: BmbColors.blue, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(bracket.description,
                                    style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Teams preview
                      if (bracket.teams.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('${bracket.gameTypeLabel} — ${bracket.teams.length} ${bracket.gameType == GameType.voting ? "options" : "teams/picks"}',
                            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: bracket.teams.take(16).map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: BmbColors.cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: BmbColors.borderColor, width: 0.5),
                            ),
                            child: Text(t, style: TextStyle(color: BmbColors.textPrimary, fontSize: 11, fontWeight: BmbFontWeights.medium)),
                          )).toList(),
                        ),
                        if (bracket.teams.length > 16)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('+${bracket.teams.length - 16} more',
                                style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                          ),
                      ],
                      const SizedBox(height: 24),

                      // Stats row
                      Row(
                        children: [
                          _buildStatBox('Players',
                              '${bracket.participants}', Icons.people,
                              BmbColors.blue),
                          const SizedBox(width: 12),
                          _buildStatBox(
                              'Reward',
                              bracket.prizeAmount > 0
                                  ? '${bracket.prizeAmount.toStringAsFixed(0)} credits'
                                  : 'None',
                              Icons.emoji_events,
                              BmbColors.gold),
                          const SizedBox(width: 12),
                          _buildStatBox(
                              'Contribute',
                              bracket.isFree
                                  ? 'FREE'
                                  : bracket.usesBmbBucks
                                      ? '${bracket.bmbBucksCost.toInt()} credits'
                                      : '${bracket.entryFee.toStringAsFixed(0)} credits',
                              Icons.confirmation_number,
                              bracket.isFree
                                  ? BmbColors.successGreen
                                  : BmbColors.gold),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ═══════════════════════════════════════════════
                      //  REWARD SECTION — custom or charity
                      // ═══════════════════════════════════════════════
                      if (bracket.rewardType == RewardType.custom ||
                          bracket.rewardType == RewardType.charity) ...[
                        _buildRewardSection(),
                        const SizedBox(height: 24),
                      ],

                      // ═══════════════════════════════════════════════
                      //  CHARITY WINNER CTA — ONLY for the actual winner
                      // ═══════════════════════════════════════════════
                      if (bracket.rewardType == RewardType.charity &&
                          bracket.isDone &&
                          !bracket.charityDonationCompleted &&
                          bracket.championName != null &&
                          bracket.championName ==
                              CurrentUserService.instance.displayName) ...[
                        _buildCharityWinnerCTA(),
                        const SizedBox(height: 24),
                      ],

                      // Host card
                      if (host != null) ...[
                        Text('Hosted by',
                            style: TextStyle(
                                color: BmbColors.textSecondary,
                                fontSize: 13,
                                fontWeight: BmbFontWeights.semiBold)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: BmbColors.cardGradient,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: BmbColors.borderColor,
                                width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: host.name ==
                                          'Back My Bracket'
                                      ? LinearGradient(colors: [
                                          BmbColors.blue,
                                          BmbColors.blue
                                              .withValues(alpha: 0.7)
                                        ])
                                      : LinearGradient(colors: [
                                          BmbColors.gold
                                              .withValues(alpha: 0.3),
                                          BmbColors.gold
                                              .withValues(alpha: 0.1)
                                        ]),
                                  border: Border.all(
                                    color:
                                        host.name == 'Back My Bracket'
                                            ? BmbColors.blue
                                            : BmbColors.gold,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  host.name == 'Back My Bracket'
                                      ? Icons.emoji_events
                                      : Icons.person,
                                  color:
                                      host.name == 'Back My Bracket'
                                          ? Colors.white
                                          : BmbColors.gold,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(host.name,
                                            style: TextStyle(
                                                color:
                                                    BmbColors.textPrimary,
                                                fontSize: 15,
                                                fontWeight: BmbFontWeights
                                                    .semiBold)),
                                        if (host.isVerified) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified,
                                              color: BmbColors.blue,
                                              size: 16),
                                        ],
                                        if (host.location != null) ...[
                                          const SizedBox(width: 6),
                                          Text(host.location!,
                                              style: TextStyle(
                                                  color: BmbColors
                                                      .textTertiary,
                                                  fontSize: 12)),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star,
                                            color: BmbColors.gold,
                                            size: 14),
                                        const SizedBox(width: 3),
                                        Text('${host.rating}',
                                            style: TextStyle(
                                                color: BmbColors.gold,
                                                fontSize: 12,
                                                fontWeight:
                                                    BmbFontWeights.bold)),
                                        Text(
                                            ' (${host.reviewCount}) \u2022 ${host.totalHosted} Hosting',
                                            style: TextStyle(
                                                color: BmbColors
                                                    .textTertiary,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (host.isTopHost &&
                                  host.name != 'Back My Bracket')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: BmbColors.gold
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text('Top Host',
                                      style: TextStyle(
                                          color: BmbColors.gold,
                                          fontSize: 10,
                                          fontWeight:
                                              BmbFontWeights.bold)),
                                ),
                              if (host.name == 'Back My Bracket')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: BmbColors.blue
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text('Official',
                                      style: TextStyle(
                                          color: BmbColors.blue,
                                          fontSize: 10,
                                          fontWeight:
                                              BmbFontWeights.bold)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ═══════════════════════════════════════════════
                      //  BRACKET PROGRESS BAR
                      // ═══════════════════════════════════════════════
                      if (bracket.totalGames > 0 ||
                          bracket.totalPicks > 0 ||
                          bracket.participants > 0) ...[
                        _buildDetailProgressSection(),
                        const SizedBox(height: 24),
                      ],

                      // Rules / Description
                      Text('Tournament Rules',
                          style: TextStyle(
                              color: BmbColors.textSecondary,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.semiBold)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: BmbColors.cardGradient,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: BmbColors.borderColor, width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRule('Single elimination bracket'),
                            _buildRule('Picks lock at game start time'),
                            _buildRule(
                                'Tiebreakers decided by total points scored'),
                            _buildRule(
                                'Must complete all picks to be eligible for prizes'),
                            if (bracket.usesBmbBucks)
                              _buildRule(
                                  'Credits deducted from your BMB Bucket — non-refundable'),
                            if (!bracket.isFree && !bracket.usesBmbBucks)
                              _buildRule(
                                  'Entry credits — refund available until first game starts'),
                            if (bracket.usesBmbBucks || (bracket.prizeCredits != null && bracket.prizeCredits! > 0))
                              _buildRule(
                                  'Reward credits redeemable at the BMB Store for gift cards, merch & more'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Participants preview
                      Text('Participants (${bracket.participants})',
                          style: TextStyle(
                              color: BmbColors.textSecondary,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.semiBold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        child: Row(
                          children: [
                            // Stacked avatars
                            SizedBox(
                              width: 120,
                              child: Stack(
                                children: List.generate(
                                    4,
                                    (i) => Positioned(
                                          left: i * 28.0,
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: [
                                                BmbColors.blue,
                                                BmbColors.gold,
                                                BmbColors.successGreen,
                                                BmbColors.greyBlue,
                                              ][i],
                                              border: Border.all(
                                                  color:
                                                      BmbColors.deepNavy,
                                                  width: 2),
                                            ),
                                            child: const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 20),
                                          ),
                                        )),
                              ),
                            ),
                            Text(
                                '+${bracket.participants - 4} more',
                                style: TextStyle(
                                    color: BmbColors.textTertiary,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── BACK IT CTA ────────────────────
                      GestureDetector(
                        onTap: () {
                          // Use REAL teams from the bracket, not generic placeholders
                          final teams = bracket.teams.isNotEmpty
                              ? bracket.teams
                              : List.generate(8, (i) => 'Team ${i + 1}');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BackItFlowScreen(
                                bracketId: bracket.id,
                                bracketTitle: bracket.title,
                                championName: 'TBD',
                                teamCount: teams.length,
                                teams: teams,
                                picks: const {},
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF9C27B0).withValues(alpha: 0.15),
                                BmbColors.gold.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFF9C27B0).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.checkroom,
                                    color: Color(0xFF9C27B0), size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Back It',
                                        style: TextStyle(
                                            color: BmbColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: BmbFontWeights.bold,
                                            fontFamily: 'ClashDisplay')),
                                    const SizedBox(height: 2),
                                    Text('Get your bracket picks printed on premium apparel',
                                        style: TextStyle(
                                            color: BmbColors.textSecondary,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  color: Color(0xFF9C27B0), size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 80), // room for bottom button
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Sticky bottom button — changes based on join status
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: BmbColors.deepNavy,
          border: Border(
              top: BorderSide(
                  color: BmbColors.borderColor.withValues(alpha: 0.5))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Price info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasJoined)
                      Text('JOINED',
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 18,
                              fontWeight: BmbFontWeights.bold))
                    else if (bracket.isFree)
                      Text('FREE ENTRY',
                          style: TextStyle(
                              color: BmbColors.successGreen,
                              fontSize: 18,
                              fontWeight: BmbFontWeights.bold))
                    else if (bracket.usesBmbBucks)
                      Row(
                        children: [
                          const Icon(Icons.savings,
                              color: BmbColors.gold, size: 20),
                          const SizedBox(width: 4),
                          Text('${bracket.bmbBucksCost.toInt()} credits',
                              style: TextStyle(
                                  color: BmbColors.gold,
                                  fontSize: 18,
                                  fontWeight: BmbFontWeights.bold)),
                        ],
                      )
                    else
                      Text(
                          '${bracket.entryFee.toStringAsFixed(0)} credits',
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 18,
                              fontWeight: BmbFontWeights.bold)),
                    Text(_hasJoined ? 'Update your picks' : 'Contribution',
                        style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 11)),
                  ],
                ),
              ),
              // Join / Re-Pick button — dynamically changes
              if (_checkingJoin)
                const SizedBox(
                  width: 50, height: 50,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_hasJoined)
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToRePick,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: Text('Re-Pick',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: BmbFontWeights.bold)),
                  ),
                )
              else
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TournamentJoinScreen(bracket: bracket),
                        ),
                      );
                      // Re-check join status when returning from join screen
                      _checkJoinStatus();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.buttonPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Join & Make Picks',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: BmbFontWeights.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: BmbColors.borderColor, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 16,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay')),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle,
              color: BmbColors.successGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: BmbColors.textSecondary,
                    fontSize: 13,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball': return Icons.sports_basketball;
      case 'football': return Icons.sports_football;
      case 'baseball': return Icons.sports_baseball;
      case 'soccer': return Icons.sports_soccer;
      case 'hockey': return Icons.sports_hockey;
      case 'golf': return Icons.sports_golf;
      case 'tennis': return Icons.sports_tennis;
      case 'voting': return Icons.how_to_vote;
      default: return Icons.emoji_events;
    }
  }

  Color _getSportColor(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball': return const Color(0xFFFF6B35);
      case 'football': return const Color(0xFF795548);
      case 'baseball': return const Color(0xFFE53935);
      case 'soccer': return const Color(0xFF4CAF50);
      case 'hockey': return const Color(0xFF1E88E5);
      case 'golf': return const Color(0xFF388E3C);
      case 'tennis': return const Color(0xFFFDD835);
      case 'voting': return const Color(0xFF9C27B0);
      default: return BmbColors.gold;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BRACKET PROGRESS BAR — visual status at a glance
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDetailProgressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bracket Progress',
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 13,
                  fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(height: 12),
          // Participant count bar (no cap — unlimited)
          if (bracket.participants > 0) ...[
            _buildProgressRow(
              label: 'Joined',
              value: (bracket.participants / 50).clamp(0.0, 1.0),
              trailing:
                  '${bracket.participants} players',
              color: BmbColors.blue,
              icon: Icons.people,
            ),
            const SizedBox(height: 12),
          ],
          // User picks bar
          if (bracket.totalPicks > 0) ...[
            _buildProgressRow(
              label: 'Your Picks',
              value: bracket.picksProgress,
              trailing: '${bracket.picksMade}/${bracket.totalPicks}',
              color: BmbColors.successGreen,
              icon: Icons.edit_note,
            ),
            const SizedBox(height: 12),
          ],
          // Tournament games bar
          if (bracket.totalGames > 0)
            _buildProgressRow(
              label: bracket.isDone ? 'Completed' : 'Games Played',
              value: bracket.tournamentProgress,
              trailing:
                  '${bracket.completedGames}/${bracket.totalGames} games',
              color: bracket.isDone
                  ? BmbColors.gold
                  : const Color(0xFFFF6B35),
              icon: bracket.isDone
                  ? Icons.emoji_events
                  : Icons.sports_score,
            ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required double value,
    required String trailing,
    required Color color,
    required IconData icon,
  }) {
    final pct = (value.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 12,
                    fontWeight: BmbFontWeights.medium)),
            const Spacer(),
            Text(trailing,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: BmbFontWeights.semiBold)),
            const SizedBox(width: 6),
            Text('$pct%',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: BmbColors.borderColor.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  REWARD SECTION — custom description or charity
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRewardSection() {
    final isCharity = bracket.rewardType == RewardType.charity;
    final accentColor = isCharity ? BmbColors.successGreen : const Color(0xFFFF6B35);
    final icon = isCharity ? Icons.volunteer_activism : Icons.card_giftcard;
    final label = isCharity ? 'CHARITY' : 'CUSTOM REWARD';
    final subtitle = isCharity
        ? 'Proceeds from this bracket support:'
        : 'The champion wins:';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 0.8)),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(
                color: BmbColors.textTertiary, fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.10),
                BmbColors.gold.withValues(alpha: 0.04),
                BmbColors.cardGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: accentColor.withValues(alpha: 0.35), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.25),
                      BmbColors.gold.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: accentColor, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(bracket.rewardDescription,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 15,
                        fontWeight: BmbFontWeights.bold,
                        height: 1.35)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showShareSheet(BuildContext context, BracketItem bracket) {
    final host = bracket.host;
    final shareText = '${bracket.title} hosted by ${host?.name ?? 'Unknown'}\n'
        'Sport: ${bracket.sport} | ${bracket.participants} players\n'
        'Join on BackMyBracket.com!';

    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Share Bracket', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                  Text(bracket.title, style: TextStyle(color: BmbColors.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
              ]),
              const SizedBox(height: 20),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
                child: Text(shareText, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.5)),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _buildSharePlatformBtn(ctx, Icons.sms, 'Text', BmbColors.successGreen, shareText),
                _buildSharePlatformBtn(ctx, Icons.alternate_email, 'X / Twitter', BmbColors.textPrimary, shareText),
                _buildSharePlatformBtn(ctx, Icons.camera_alt, 'Instagram', const Color(0xFFE1306C), shareText),
                _buildSharePlatformBtn(ctx, Icons.copy, 'Copy Link', BmbColors.blue, shareText),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// CTA for the charity bracket winner to choose their charity.
  /// Only shown when the bracket is done AND the current user is the
  /// confirmed champion AND the charity donation has not been processed yet.
  Widget _buildCharityWinnerCTA() {
    final potCredits = bracket.prizeCredits ?? 0;
    final netDonation = CharityService.calculateNetDonation(potCredits);
    final netDollars = CharityService.creditsToDollars(netDonation);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BmbColors.successGreen.withValues(alpha: 0.15),
            BmbColors.gold.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: BmbColors.successGreen.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [BmbColors.successGreen, const Color(0xFF66BB6A)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose Your Charity',
            style: TextStyle(
              color: BmbColors.successGreen, fontSize: 16,
              fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Congratulations! As the winner, you get to choose where the \$${netDollars.toStringAsFixed(2)} donation goes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GiftCardStoreScreen(
                      charityOnly: true,
                      prizeCredits: netDonation,
                      bracketId: bracket.id,
                      bracketTitle: bracket.title,
                      charityPotMode: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.favorite, color: Colors.white, size: 18),
              label: const Text('Select a Charity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.successGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharePlatformBtn(BuildContext ctx, IconData icon, String label, Color color, String text) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Copied! Share to $label'),
          backgroundColor: BmbColors.midNavy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      },
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontWeight: BmbFontWeights.medium)),
      ]),
    );
  }
}
