import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import '../../data/models/bracket_item.dart';

class EnhancedBracketCard extends StatelessWidget {
  final BracketItem bracket;
  final VoidCallback? onJoinTap;
  final VoidCallback? onPrizeTap;
  final VoidCallback? onPicksTap;

  /// Whether the current user has joined this bracket.
  /// When true, buttons show user-contextual labels ("Make My Picks", etc.)
  final bool currentUserJoined;

  /// Whether the current user has already submitted picks.
  final bool currentUserMadePicks;

  const EnhancedBracketCard({
    super.key,
    required this.bracket,
    this.onJoinTap,
    this.onPrizeTap,
    this.onPicksTap,
    this.currentUserJoined = false,
    this.currentUserMadePicks = false,
  });

  @override
  Widget build(BuildContext context) {
    final host = bracket.host;
    final isVip = bracket.isVipBoosted;

    // VIP cards get a purple glow border & backlit shadow treatment
    final cardDecoration = isVip
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BmbColors.vipPurple.withValues(alpha: 0.15),
                BmbColors.cardGradientStart,
                BmbColors.cardGradientEnd,
                BmbColors.vipPurple.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BmbColors.vipPurple.withValues(alpha: 0.7), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: BmbColors.vipPurple.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4)),
              BoxShadow(
                  color: BmbColors.vipPurple.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 6),
            ],
          )
        : BoxDecoration(
            gradient: BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BmbColors.borderColor, width: 0.5),
            boxShadow: [
              BoxShadow(
                  color: BmbColors.blue.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6)),
            ],
          );

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: cardDecoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // VIP badge strip at top
            if (isVip) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [BmbColors.vipPurple, BmbColors.vipPurpleLight],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(color: BmbColors.vipPurple.withValues(alpha: 0.3), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.diamond, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('VIP FEATURED',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: BmbFontWeights.bold,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
            ],
            // Host info row
            if (host != null) ...[
              Row(
                children: [
                  _buildHostAvatar(host),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(host.name,
                                  style: TextStyle(
                                      color: BmbColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: BmbFontWeights.semiBold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (host.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: BmbColors.blue, size: 14),
                            ],
                            if (host.location != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                    color: BmbColors.textTertiary
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3)),
                                child: Text(host.location!,
                                    style: TextStyle(
                                        color: BmbColors.textSecondary,
                                        fontSize: 10)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: BmbColors.gold, size: 12),
                            const SizedBox(width: 2),
                            Text('${host.rating}',
                                style: TextStyle(
                                    color: BmbColors.gold,
                                    fontSize: 12,
                                    fontWeight: BmbFontWeights.semiBold)),
                            const SizedBox(width: 4),
                            Text('(${host.reviewCount})',
                                style: TextStyle(
                                    color: BmbColors.textTertiary,
                                    fontSize: 11)),
                            const SizedBox(width: 8),
                            Text('${host.totalHosted} Hosted',
                                style: TextStyle(
                                    color: BmbColors.textTertiary,
                                    fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Badge
                  if (host.name == 'Back My Bracket')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: BmbColors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6)),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified,
                                color: BmbColors.blue, size: 10),
                            const SizedBox(width: 3),
                            Text('Official',
                                style: TextStyle(
                                    color: BmbColors.blue,
                                    fontSize: 10,
                                    fontWeight: BmbFontWeights.bold)),
                          ]),
                    )
                  else if (host.isTopHost)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: BmbColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6)),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: BmbColors.gold, size: 10),
                            const SizedBox(width: 3),
                            Text('Top Host',
                                style: TextStyle(
                                    color: BmbColors.gold,
                                    fontSize: 10,
                                    fontWeight: BmbFontWeights.bold)),
                          ]),
                    )
                  else if (isVip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [BmbColors.vipPurple, BmbColors.vipPurpleLight],
                          ),
                          borderRadius: BorderRadius.circular(6)),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.diamond,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text('VIP',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: BmbFontWeights.bold)),
                          ]),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Status Badge Row
            _buildStatusBadge(),
            const SizedBox(height: 6),
            // Title + Sport Icon
            Row(
              children: [
                _buildSportIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(bracket.title,
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 16,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Entry + Players
            Row(
              children: [
                _buildEntryBadge(),
                const SizedBox(width: 8),
                const Icon(Icons.people,
                    size: 14, color: BmbColors.textSecondary),
                const SizedBox(width: 4),
                Text('${bracket.participants} Players',
                    style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 13)),
              ],
            ),

            // ═══════════════════════════════════════════════════════════
            //  PROGRESS BARS — tournament progress + fill/picks
            // ═══════════════════════════════════════════════════════════
            const SizedBox(height: 8),
            _buildProgressBars(),

            const SizedBox(height: 8),
            // Action Buttons — status-aware
            _buildActionButtons(),
            const SizedBox(height: 6),
            Center(
              child: Text('BackMyBracket.com',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROGRESS BARS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildProgressBars() {
    final status = bracket.status;

    // Pick the right bar based on bracket state
    if (status == 'upcoming') {
      // Participant count bar (no cap — the more the merrier)
      return _buildBarRow(
        label: 'Joined',
        value: (bracket.participants / 50).clamp(0.0, 1.0),
        trailing: '${bracket.participants} players',
        color: BmbColors.blue,
        icon: Icons.people,
      );
    }

    if (status == 'live') {
      if (currentUserJoined && currentUserMadePicks && bracket.totalPicks > 0) {
        // User has joined + made picks → show completed picks progress
        return _buildBarRow(
          label: 'Your Picks',
          value: 1.0,
          trailing: '${bracket.totalPicks}/${bracket.totalPicks}',
          color: BmbColors.successGreen,
          icon: Icons.check_circle,
        );
      } else if (currentUserJoined && bracket.totalPicks > 0) {
        // User joined but hasn't made picks yet → show 0 progress
        return _buildBarRow(
          label: 'Your Picks',
          value: 0.0,
          trailing: '0/${bracket.totalPicks}',
          color: BmbColors.successGreen,
          icon: Icons.edit_note,
        );
      } else {
        // Not joined → show participant count, not "Your Picks"
        return _buildBarRow(
          label: 'Players',
          value: (bracket.participants / 50).clamp(0.0, 1.0),
          trailing: '${bracket.participants} players',
          color: BmbColors.blue,
          icon: Icons.people,
        );
      }
    }

    if ((status == 'in_progress' || status == 'done') && bracket.totalGames > 0) {
      // Tournament progress
      return _buildBarRow(
        label: status == 'done' ? 'Completed' : 'Tournament',
        value: bracket.tournamentProgress,
        trailing: '${bracket.completedGames}/${bracket.totalGames} games',
        color: status == 'done' ? BmbColors.gold : const Color(0xFFFF6B35),
        icon: status == 'done' ? Icons.emoji_events : Icons.sports_score,
      );
    }

    // Default: participant count (no cap)
    return _buildBarRow(
      label: 'Active',
      value: (bracket.participants / 50).clamp(0.0, 1.0),
      trailing: '${bracket.participants} players',
      color: BmbColors.textTertiary,
      icon: Icons.people,
    );
  }

  Widget _buildBarRow({
    required String label,
    required double value,
    required String trailing,
    required Color color,
    required IconData icon,
  }) {
    final pct = (value * 100).toStringAsFixed(0);
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 11,
                    fontWeight: BmbFontWeights.medium)),
            const Spacer(),
            Text(trailing,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: BmbFontWeights.semiBold)),
            const SizedBox(width: 4),
            Text('$pct%',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: BmbColors.borderColor.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ─── STATUS BADGE + GAME TYPE BADGE ──────────────────────────────────
  Widget _buildStatusBadge() {
    Color statusColor;
    IconData statusIcon;
    bool pulsing = false;

    switch (bracket.status) {
      case 'saved':
        statusColor = Colors.grey;
        statusIcon = Icons.bookmark_outline;
        break;
      case 'upcoming':
        statusColor = BmbColors.blue;
        statusIcon = Icons.schedule;
        break;
      case 'live':
        statusColor = BmbColors.successGreen;
        statusIcon = Icons.circle;
        pulsing = true;
        break;
      case 'in_progress':
        statusColor = BmbColors.gold;
        statusIcon = Icons.play_circle_outline;
        pulsing = true;
        break;
      case 'done':
        statusColor = const Color(0xFF00BCD4);
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusColor = BmbColors.textTertiary;
        statusIcon = Icons.info_outline;
    }

    // Game type badge styling
    final (gameIcon, gameColor) = _getGameTypeStyle(bracket.gameType);

    return Row(
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pulsing)
                _PulsingDot(color: statusColor)
              else
                Icon(statusIcon, color: statusColor, size: 10),
              const SizedBox(width: 4),
              Text(bracket.statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Game type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: gameColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: gameColor.withValues(alpha: 0.35), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(gameIcon, color: gameColor, size: 10),
              const SizedBox(width: 3),
              Text(bracket.gameTypeLabel,
                  style: TextStyle(
                      color: gameColor,
                      fontSize: 10,
                      fontWeight: BmbFontWeights.bold)),
            ],
          ),
        ),
        const Spacer(),
        // Sport tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: BmbColors.borderColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(bracket.sport,
              style: TextStyle(
                  color: BmbColors.textSecondary,
                  fontSize: 10,
                  fontWeight: BmbFontWeights.semiBold)),
        ),
      ],
    );
  }

  /// Returns (icon, color) for each game type.
  static (IconData, Color) _getGameTypeStyle(GameType type) {
    switch (type) {
      case GameType.bracket:
        return (Icons.account_tree, const Color(0xFF2137FF));
      case GameType.pickem:
        return (Icons.checklist, const Color(0xFFFF6B35));
      case GameType.squares:
        return (Icons.grid_4x4, const Color(0xFFFFC107));
      case GameType.trivia:
        return (Icons.quiz, const Color(0xFF9C27B0));
      case GameType.props:
        return (Icons.trending_up, const Color(0xFF00BCD4));
      case GameType.survivor:
        return (Icons.shield, const Color(0xFFE53935));
      case GameType.voting:
        return (Icons.how_to_vote, const Color(0xFF9C27B0));
    }
  }

  // ─── STATUS-AWARE ACTION BUTTONS ────────────────────────────────────
  Widget _buildActionButtons() {
    switch (bracket.status) {
      case 'upcoming':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: currentUserJoined ? onPicksTap : onJoinTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentUserJoined ? BmbColors.successGreen : BmbColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(currentUserJoined ? Icons.check_circle : Icons.arrow_forward, size: 14),
                    const SizedBox(width: 4),
                    Text(currentUserJoined ? 'Joined' : 'Join Now',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildPrizeButton(),
          ],
        );
      case 'live':
        // If user joined + made picks → Re-Pick; joined + no picks → Make My Picks; not joined → Join Now
        final String liveLabel;
        final IconData liveIcon;
        final Color liveBg;
        final VoidCallback? liveAction;
        if (currentUserJoined && currentUserMadePicks) {
          liveLabel = 'Re-Pick';
          liveIcon = Icons.refresh;
          liveBg = BmbColors.blue;
          liveAction = onPicksTap;
        } else if (currentUserJoined) {
          liveLabel = 'Make My Picks';
          liveIcon = Icons.edit_note;
          liveBg = BmbColors.successGreen;
          liveAction = onPicksTap;
        } else {
          liveLabel = 'Join Now';
          liveIcon = Icons.person_add;
          liveBg = BmbColors.blue;
          liveAction = onJoinTap;
        }
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: liveAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: liveBg,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(liveIcon, size: 16),
                    const SizedBox(width: 4),
                    Text(liveLabel,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildPrizeButton(),
          ],
        );
      case 'in_progress':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: currentUserJoined ? onPicksTap : onJoinTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: currentUserJoined ? BmbColors.gold : BmbColors.blue,
                  foregroundColor: currentUserJoined ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(currentUserJoined ? Icons.lock : Icons.visibility, size: 16),
                    const SizedBox(width: 4),
                    Text(currentUserJoined ? 'View My Picks' : 'View Bracket',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildPrizeButton(),
          ],
        );
      case 'done':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: onPicksTap ?? onJoinTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(currentUserJoined ? Icons.lock : Icons.emoji_events, size: 16),
                    const SizedBox(width: 4),
                    Text(currentUserJoined ? 'View My Picks' : 'Results',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildPrizeButton(),
          ],
        );
      default: // fallback — same as upcoming
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: onJoinTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.buttonPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Join Now',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: BmbFontWeights.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildPrizeButton(),
          ],
        );
    }
  }

  Widget _buildPrizeButton() {
    return ElevatedButton(
      onPressed: onPrizeTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: BmbColors.cardDark,
        foregroundColor: BmbColors.textSecondary,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.card_giftcard, size: 14),
        const SizedBox(width: 4),
        const Text('Reward', style: TextStyle(fontSize: 13)),
      ]),
    );
  }

  Widget _buildHostAvatar(host) {
    final isOfficial = host.name == 'Back My Bracket';
    final isVip = bracket.isVipBoosted;
    final borderColor = isOfficial
        ? BmbColors.blue
        : host.isTopHost
            ? BmbColors.gold
            : isVip
                ? BmbColors.vipPurple
                : BmbColors.borderColor;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        gradient: isOfficial
            ? LinearGradient(
                colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)])
            : isVip
                ? LinearGradient(
                    colors: [BmbColors.vipPurple.withValues(alpha: 0.3), BmbColors.vipPurpleLight.withValues(alpha: 0.1)])
                : null,
      ),
      child: ClipOval(
        child: Icon(
          isOfficial ? Icons.emoji_events : Icons.person,
          color: isOfficial ? Colors.white : isVip ? BmbColors.vipPurpleLight : BmbColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildEntryBadge() {
    if (bracket.isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: BmbColors.successGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6)),
        child: Text('FREE',
            style: TextStyle(
                color: BmbColors.successGreen,
                fontSize: 12,
                fontWeight: BmbFontWeights.bold)),
      );
    }
    if (bracket.usesBmbBucks) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: BmbColors.gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.savings,
              color: BmbColors.gold, size: 12),
          const SizedBox(width: 3),
          Text('${bracket.entryCredits} credits',
              style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 12,
                  fontWeight: BmbFontWeights.bold)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: BmbColors.gold.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.savings, color: BmbColors.gold, size: 12),
        const SizedBox(width: 3),
        Text('${bracket.entryFee.toStringAsFixed(0)} credits',
            style: TextStyle(
                color: BmbColors.gold,
                fontSize: 12,
                fontWeight: BmbFontWeights.bold)),
      ]),
    );
  }

  Widget _buildSportIcon() {
    final sportData = _getSportData(bracket.title);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: sportData.$2.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(sportData.$1, color: sportData.$2, size: 18),
    );
  }

  (IconData, Color) _getSportData(String title) {
    final t = title.toLowerCase();
    if (t.contains('basketball') ||
        t.contains('nba') ||
        t.contains('march madness') ||
        t.contains('ncaa')) {
      return (Icons.sports_basketball, const Color(0xFFFF6B35));
    }
    if (t.contains('football') ||
        t.contains('nfl') ||
        t.contains('super bowl')) {
      return (Icons.sports_football, const Color(0xFF795548));
    }
    if (t.contains('baseball') || t.contains('mlb')) {
      return (Icons.sports_baseball, const Color(0xFFE53935));
    }
    if (t.contains('soccer') ||
        t.contains('mls') ||
        t.contains('fifa')) {
      return (Icons.sports_soccer, const Color(0xFF4CAF50));
    }
    if (t.contains('hockey') || t.contains('nhl')) {
      return (Icons.sports_hockey, const Color(0xFF1E88E5));
    }
    if (t.contains('golf') ||
        t.contains('pga') ||
        t.contains('masters')) {
      return (Icons.sports_golf, const Color(0xFF388E3C));
    }
    if (t.contains('tennis') || t.contains('wimbledon')) {
      return (Icons.sports_tennis, const Color(0xFFFDD835));
    }
    if (t.contains('ufc') || t.contains('mma') || t.contains('fight night')) {
      return (Icons.sports_mma, const Color(0xFFD32F2F));
    }
    if (t.contains('vot') ||
        t.contains('poll') ||
        t.contains('best of') ||
        t.contains('favorite') ||
        t.contains('pizza') ||
        t.contains('brunch') ||
        t.contains('best ')) {
      return (Icons.how_to_vote, const Color(0xFF9C27B0));
    }
    if (t.contains('trivia') || t.contains('quiz')) {
      return (Icons.quiz, const Color(0xFF9C27B0));
    }
    if (t.contains('props') || t.contains('prop bet')) {
      return (Icons.trending_up, const Color(0xFF00BCD4));
    }
    if (t.contains('survivor')) {
      return (Icons.shield, const Color(0xFFE53935));
    }
    if (t.contains('pick') && (t.contains('em') || t.contains('\u2019em'))) {
      return (Icons.checklist, const Color(0xFFFF6B35));
    }
    if (t.contains('squares')) {
      return (Icons.grid_4x4, const Color(0xFFFFC107));
    }
    return (Icons.emoji_events, BmbColors.gold);
  }
}

/// Small pulsing dot indicator for LIVE / IN PROGRESS statuses
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _animation.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _animation.value * 0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
