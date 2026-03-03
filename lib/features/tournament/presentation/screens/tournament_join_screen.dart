import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/bmb_colors.dart';
import '../../../../core/theme/bmb_font_weights.dart';
import '../../../../core/services/firebase/firestore_service.dart';
import '../../../../core/services/current_user_service.dart';
import '../../../dashboard/data/models/bracket_item.dart'; // GameType, BracketItem
import '../../../bracket_builder/data/models/created_bracket.dart';
import '../../../bmb_bucks/presentation/screens/bmb_bucks_purchase_screen.dart';
import '../../../scoring/presentation/screens/bracket_picks_screen.dart';
import '../../../chat/data/services/chat_access_service.dart';

class TournamentJoinScreen extends StatefulWidget {
  final BracketItem bracket;
  /// Optional CreatedBracket for direct navigation to picks after joining.
  /// If null, the screen will auto-convert from BracketItem.
  final CreatedBracket? createdBracket;
  const TournamentJoinScreen({
    super.key,
    required this.bracket,
    this.createdBracket,
  });
  @override
  State<TournamentJoinScreen> createState() => _TournamentJoinScreenState();
}

class _TournamentJoinScreenState extends State<TournamentJoinScreen> {
  double _balance = 0;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _balance = prefs.getDouble('bmb_bucks_balance') ?? 0);
  }

  /// Build a CreatedBracket from the BracketItem for the picks screen.
  ///
  /// CRITICAL: Uses the actual teams from [BracketItem.teams] which are
  /// populated by the DailyContentEngine (real sports) or BracketBoardService
  /// (template pool). This ensures the picks screen shows the REAL matchups.
  CreatedBracket _buildCreatedBracket() {
    if (widget.createdBracket != null) return widget.createdBracket!;

    final item = widget.bracket;

    // Use the real teams from the bracket item — these come from the
    // DailyContentEngine crawl or the template pool team generation.
    List<String> teams = item.teams;

    // Pad to nearest power of 2 for bracket format, or ensure min 2 for pick'em
    if (teams.isEmpty) {
      teams = _fallbackTeams(item.sport);
    }

    // For bracket game type, pad to nearest power of 2
    int teamCount = teams.length;
    if (item.gameType == GameType.bracket) {
      int pow2 = 2;
      while (pow2 < teamCount) { pow2 *= 2; }
      while (teams.length < pow2) { teams.add('BYE'); }
      teamCount = pow2;
    } else {
      // Pick'em, props, voting — ensure even count for pairing
      if (teamCount.isOdd) {
        teams = List.from(teams)..add('BYE');
        teamCount = teams.length;
      }
    }

    // Map GameType to bracketType string
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

  /// Fallback teams only used if BracketItem.teams is somehow empty.
  /// This should rarely happen since DailyContentEngine and
  /// BracketBoardService both populate teams.
  List<String> _fallbackTeams(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('basketball')) return ['Celtics', 'Thunder', 'Knicks', 'Cavaliers', 'Nuggets', 'Bucks', 'Timberwolves', 'Warriors'];
    if (s.contains('football'))  return ['Chiefs', 'Eagles', '49ers', 'Ravens', 'Bills', 'Lions', 'Cowboys', 'Dolphins'];
    if (s.contains('baseball'))  return ['Yankees', 'Dodgers', 'Orioles', 'Braves', 'Phillies', 'Astros', 'Guardians', 'Padres'];
    if (s.contains('hockey'))    return ['Panthers', 'Oilers', 'Rangers', 'Stars', 'Avalanche', 'Bruins', 'Hurricanes', 'Canucks'];
    if (s.contains('soccer'))    return ['Inter Miami', 'LAFC', 'Columbus Crew', 'Cincinnati', 'Atlanta', 'Seattle', 'Nashville', 'Houston'];
    if (s.contains('mma'))       return ['Fighter A', 'Fighter B', 'Fighter C', 'Fighter D', 'Fighter E', 'Fighter F', 'Fighter G', 'Fighter H'];
    return ['Team 1', 'Team 2', 'Team 3', 'Team 4', 'Team 5', 'Team 6', 'Team 7', 'Team 8'];
  }

  // ─── CONFIRM & JOIN ──────────────────────────────────────────────
  Future<void> _showJoinConfirmation() async {
    final bracket = widget.bracket;
    final cost = bracket.usesBmbBucks ? bracket.bmbBucksCost : bracket.entryFee;

    // If paid with credits and insufficient funds → show bucket prompt
    if (bracket.usesBmbBucks && _balance < cost) {
      BmbBucketPrompt.show(context, needed: cost);
      return;
    }

    // Free brackets skip confirmation
    if (bracket.isFree) {
      _joinTournament();
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings, color: BmbColors.gold, size: 30),
              ),
              const SizedBox(height: 16),
              Text('Confirm Entry',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 12),

              // Tournament name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(bracket.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.semiBold)),
              ),
              const SizedBox(height: 16),

              // Deduction details
              if (bracket.usesBmbBucks) ...[
                _confirmRow('Contribution',
                    '${cost.toInt()} credits', BmbColors.gold),
                const SizedBox(height: 8),
                _confirmRow('Your BMB Bucket',
                    '${_balance.toInt()} credits', BmbColors.textSecondary),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: BmbColors.borderColor, height: 1),
                ),
                _confirmRow('After Joining',
                    '${(_balance - cost).toInt()} credits',
                    BmbColors.successGreen),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: BmbColors.gold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            '${cost.toInt()} BMB credits will be deducted from your BMB Bucket.',
                            style: TextStyle(
                                color: BmbColors.gold, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _confirmRow('Contribution',
                    '${cost.toInt()} credits', BmbColors.gold),
              ],
              const SizedBox(height: 12),
              // Prize award timing info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BmbColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: BmbColors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Credits are deducted when the tournament goes LIVE. Prize credits are awarded only after the host confirms the winner.',
                          style: TextStyle(
                              color: BmbColors.blue, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BmbColors.textSecondary,
                        side: const BorderSide(color: BmbColors.borderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(fontWeight: BmbFontWeights.semiBold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.buttonPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Join Now',
                          style: TextStyle(fontWeight: BmbFontWeights.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      _joinTournament();
    }
  }

  Widget _confirmRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: BmbFontWeights.bold)),
      ],
    );
  }

  Future<void> _joinTournament() async {
    final cost = widget.bracket.usesBmbBucks
        ? widget.bracket.bmbBucksCost
        : widget.bracket.entryFee;

    setState(() => _joining = true);
    await Future.delayed(const Duration(seconds: 2));

    // Record the join for chat room access
    await ChatAccessService.recordJoin(widget.bracket.id);
    if (widget.bracket.usesBmbBucks && cost > 0) {
      final prefs = await SharedPreferences.getInstance();
      final newBalance = _balance - cost;
      await prefs.setDouble('bmb_bucks_balance', newBalance);

      // Check auto-replenish
      final autoReplenish = prefs.getBool('auto_replenish') ?? false;
      if (autoReplenish && newBalance <= 10) {
        await prefs.setDouble('bmb_bucks_balance', newBalance + 10);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Auto-Replenish: 10 credits added to your BMB Bucket'),
              backgroundColor: BmbColors.blue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }

    // ═══ PHASE 3: Record join in Firestore ═══
    try {
      final cu = CurrentUserService.instance;
      final bracketId = widget.bracket.id;
      // Only persist if this is a Firestore bracket (has 'fs_' prefix or alphanumeric ID)
      if (!bracketId.startsWith('board_') && !bracketId.startsWith('pickem_') &&
          !bracketId.startsWith('live_')) {
        final cleanId = bracketId.startsWith('fs_') ? bracketId.substring(3) : bracketId;
        await FirestoreService.instance.submitBracketEntry({
          'bracket_id': cleanId,
          'user_id': cu.userId,
          'display_name': cu.displayName,
          'state': cu.stateAbbr,
          'joined_at': DateTime.now().toUtc(),
          'has_made_picks': false,
        });

        // Deduct credits if entry has a cost
        if (cost > 0) {
          await FirestoreService.instance.addCreditTransaction({
            'user_id': cu.userId,
            'amount': -(cost.toInt()),
            'type': 'bracket_entry',
            'description': 'Entry fee for ${widget.bracket.title}',
            'timestamp': DateTime.now().toUtc(),
          });
          final currentBalance = cu.creditsBalance;
          final newBal = currentBalance - cost.toInt();
          await FirestoreService.instance.updateUser(cu.userId, {
            'credits_balance': newBal > 0 ? newBal : 0,
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Firestore join record failed: $e');
    }

    if (!mounted) return;
    setState(() => _joining = false);

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Successfully joined ${widget.bracket.title}!'),
        backgroundColor: BmbColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

    // ─── NAVIGATE TO PICKS SCREEN INSTEAD OF JUST POPPING ───
    final createdBracket = _buildCreatedBracket();

    if (!mounted) return;

    // Replace TournamentJoinScreen with BracketPicksScreen
    // Using pushReplacement to avoid context issues after pop
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BracketPicksScreen(bracket: createdBracket),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bracket = widget.bracket;
    final cost =
        bracket.usesBmbBucks ? bracket.bmbBucksCost : bracket.entryFee;
    final hasFunds =
        bracket.isFree || !bracket.usesBmbBucks || _balance >= cost;
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: BmbColors.textPrimary),
                        onPressed: () => Navigator.pop(context)),
                    const Spacer(),
                    Text('Join Tournament',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 24),
                // Bracket info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      gradient: BmbColors.cardGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BmbColors.borderColor)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bracket.title,
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 20,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.people,
                              size: 16, color: BmbColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('${bracket.participants} Players',
                              style: TextStyle(
                                  color: BmbColors.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(width: 20),
                          Icon(Icons.emoji_events,
                              size: 16, color: BmbColors.gold),
                          const SizedBox(width: 6),
                          Text(
                              '${bracket.prizeAmount.toStringAsFixed(0)} credits',
                              style: TextStyle(
                                  color: BmbColors.gold,
                                  fontSize: 13,
                                  fontWeight: BmbFontWeights.semiBold)),
                        ],
                      ),
                    ],
                  ),
                ),
                // ═════════════════════════════════════════════
                //  REWARD PREVIEW — what you're playing for
                // ═════════════════════════════════════════════
                if (bracket.rewardType == RewardType.custom ||
                    bracket.rewardType == RewardType.charity) ...[
                  const SizedBox(height: 20),
                  _buildRewardPreview(bracket),
                ],
                const SizedBox(height: 24),
                Text('Contribution',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold)),
                const SizedBox(height: 12),
                // Contribution card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: BmbColors.cardGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: bracket.isFree
                            ? BmbColors.successGreen
                                .withValues(alpha: 0.5)
                            : bracket.usesBmbBucks
                                ? BmbColors.gold.withValues(alpha: 0.5)
                                : BmbColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      if (bracket.isFree)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  color: BmbColors.successGreen, size: 24),
                              const SizedBox(width: 8),
                              Text('FREE ENTRY',
                                  style: TextStyle(
                                      color: BmbColors.successGreen,
                                      fontSize: 20,
                                      fontWeight: BmbFontWeights.bold)),
                            ])
                      else if (bracket.usesBmbBucks) ...[
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.savings,
                                  color: BmbColors.gold, size: 24),
                              const SizedBox(width: 8),
                              Text('${cost.toInt()} credits',
                                  style: TextStyle(
                                      color: BmbColors.gold,
                                      fontSize: 20,
                                      fontWeight: BmbFontWeights.bold)),
                            ]),
                        const SizedBox(height: 16),
                        // BMB Bucket balance row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: hasFunds
                                ? BmbColors.successGreen
                                    .withValues(alpha: 0.08)
                                : BmbColors.errorRed
                                    .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.savings,
                                    color: hasFunds
                                        ? BmbColors.successGreen
                                        : BmbColors.errorRed,
                                    size: 16),
                                const SizedBox(width: 6),
                                Text('BMB Bucket: ',
                                    style: TextStyle(
                                        color: BmbColors.textSecondary,
                                        fontSize: 13)),
                                Text('${_balance.toInt()} credits',
                                    style: TextStyle(
                                        color: hasFunds
                                            ? BmbColors.successGreen
                                            : BmbColors.errorRed,
                                        fontSize: 13,
                                        fontWeight: BmbFontWeights.bold)),
                              ]),
                        ),
                        if (!hasFunds) ...[
                          const SizedBox(height: 10),
                          Text('Not enough credits in your BMB Bucket',
                              style: TextStyle(
                                  color: BmbColors.errorRed,
                                  fontSize: 12)),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: BmbColors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: BmbColors.blue, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                    'Credits are deducted when the tournament goes LIVE. Prizes awarded after the host confirms the winner.',
                                    style: TextStyle(
                                        color: BmbColors.blue,
                                        fontSize: 10)),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        Text('\$${cost.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: BmbColors.blue,
                                fontSize: 20,
                                fontWeight: BmbFontWeights.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Action button
                if (!hasFunds && bracket.usesBmbBucks)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          BmbBucketPrompt.show(context, needed: cost),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: BmbColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      icon: const Icon(Icons.savings, size: 20),
                      label: Text('FILL MY BUCKET',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: BmbFontWeights.bold)),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _joining ? null : _showJoinConfirmation,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: BmbColors.buttonPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: _joining
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('JOIN & MAKE PICKS',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: BmbFontWeights.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CUSTOM REWARDS PREVIEW — make them WANT to join
  // ═══════════════════════════════════════════════════════════════
  //  REWARD PREVIEW — custom or charity
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRewardPreview(BracketItem bracket) {
    final isCharity = bracket.rewardType == RewardType.charity;
    final accentColor = isCharity ? BmbColors.successGreen : const Color(0xFFFF6B35);
    final icon = isCharity ? Icons.volunteer_activism : Icons.card_giftcard;
    final label = isCharity ? 'SUPPORTS A CAUSE' : 'YOU COULD WIN';

    return Container(
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: accentColor.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.2),
                      BmbColors.gold.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: accentColor, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(bracket.rewardDescription,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.semiBold,
                        height: 1.3)),
              ),
            ],
          ),
          if (bracket.prizeAmount > 0 && !isCharity) ...[
            const SizedBox(height: 8),
            Text('+ ${bracket.prizeAmount.toStringAsFixed(0)} credits on top!',
                style: TextStyle(
                    color: BmbColors.gold,
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
