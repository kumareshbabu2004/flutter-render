import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/widgets/bracket_tree_widget.dart';
import 'package:bmb_mobile/features/sharing/data/services/social_accounts_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// Full-screen read-only bracket tree viewer.
/// Shows the actual bracket tree for a user's picks — no stats, just the
/// traditional bracket tree format with team cells, connectors, and champion.
///
/// Includes a "Post to Socials" button that lets users share their bracket
/// to linked social accounts (one-time link, auto-post thereafter).
class BracketTreeViewerScreen extends StatefulWidget {
  final String userName;
  final String bracketName;
  final String? sport;
  final List<String> teams;
  final Map<String, String> picks;
  final int totalRounds;
  final String? championPick;
  final int? tieBreakerPrediction;
  /// The userId of the bracket owner.  When the current viewer matches this
  /// they see the "Post to BMB Community" action; other users see
  /// "Repost to My Socials".
  final String? ownerUserId;

  const BracketTreeViewerScreen({
    super.key,
    required this.userName,
    required this.bracketName,
    this.sport,
    required this.teams,
    required this.picks,
    required this.totalRounds,
    this.championPick,
    this.tieBreakerPrediction,
    this.ownerUserId,
  });

  @override
  State<BracketTreeViewerScreen> createState() =>
      _BracketTreeViewerScreenState();
}

class _BracketTreeViewerScreenState extends State<BracketTreeViewerScreen> {
  Map<String, LinkedSocialAccount> _linkedAccounts = {};

  @override
  void initState() {
    super.initState();
    _loadLinkedAccounts();
  }

  Future<void> _loadLinkedAccounts() async {
    final accounts = await SocialAccountsService.getLinkedAccounts();
    if (mounted) {
      setState(() {
        _linkedAccounts = accounts;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              if (widget.championPick != null) _buildChampionBanner(),
              Expanded(
                child: BracketTreeWidget(
                  teams: widget.teams,
                  totalRounds: widget.totalRounds,
                  picks: widget.picks,
                  submitted: true, // read-only
                  onPick: null, // no interaction
                  sport: widget.sport,
                ),
              ),
              if (widget.tieBreakerPrediction != null) _buildTieBreakerStrip(),
              _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                Text(
                  '${widget.userName}\'s Bracket',
                  style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.bracketName,
                  style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.sport != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                widget.sport!,
                style: TextStyle(
                  color: BmbColors.blue,
                  fontSize: 10,
                  fontWeight: BmbFontWeights.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChampionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.15),
          BmbColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: BmbColors.gold, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Champion Pick',
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 10)),
              Text(
                widget.championPick!,
                style: TextStyle(
                  color: BmbColors.gold,
                  fontSize: 16,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
            ],
          ),
          if (widget.tieBreakerPrediction != null) ...[
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Tie-Breaker',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 10)),
                Text(
                  '${widget.tieBreakerPrediction} pts',
                  style: TextStyle(
                    color: BmbColors.blue,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTieBreakerStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy,
        border: Border(
          top: BorderSide(
              color: BmbColors.gold.withValues(alpha: 0.3), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_score, color: BmbColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            'Tie-Breaker: ${widget.tieBreakerPrediction} total points',
            style: TextStyle(
              color: BmbColors.gold,
              fontSize: 12,
              fontWeight: BmbFontWeights.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Whether the current logged-in user is the owner of this bracket.
  bool get _isOwner {
    // FIX #9: Use CurrentUserService instead of hardcoded IDs.
    return widget.ownerUserId == null ||
        CurrentUserService.instance.isCurrentUser(widget.ownerUserId!);
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: BmbColors.borderColor, width: 0.5),
        ),
      ),
      child: _isOwner ? _buildOwnerActions(context) : _buildViewerActions(context),
    );
  }

  /// Actions for the bracket OWNER: "Post to Socials" + "Post to BMB Community"
  Widget _buildOwnerActions(BuildContext context) {
    return Row(
      children: [
        // Post to Socials button (primary)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showPostToSocialsSheet(context),
            icon: const Icon(Icons.share, size: 18),
            label: Text(
              'Post to Socials',
              style: TextStyle(
                fontSize: 13,
                fontWeight: BmbFontWeights.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Post to BMB Community button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Bracket already posted to BMB Community!')),
                ]),
                backgroundColor: BmbColors.successGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ));
            },
            icon: const Icon(Icons.forum, size: 18),
            label: Text(
              'Post to BMB',
              style: TextStyle(
                fontSize: 13,
                fontWeight: BmbFontWeights.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: BmbColors.blue,
              side: BorderSide(color: BmbColors.blue.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  /// Actions for OTHER users viewing someone else's bracket:
  /// "Repost to My Socials" — lets them share the bracket to their own linked accounts.
  Widget _buildViewerActions(BuildContext context) {
    return Row(
      children: [
        // Repost to My Socials button (primary CTA for non-owners)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showPostToSocialsSheet(context),
            icon: const Icon(Icons.repeat, size: 18),
            label: Text(
              'Repost to My Socials',
              style: TextStyle(
                fontSize: 13,
                fontWeight: BmbFontWeights.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── POST TO SOCIALS SHEET ────────────────────────────────────────────

  void _showPostToSocialsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PostToSocialsSheet(
        userName: widget.userName,
        bracketName: widget.bracketName,
        championPick: widget.championPick,
        linkedAccounts: _linkedAccounts,
        onAccountsChanged: () => _loadLinkedAccounts(),
        isRepost: !_isOwner,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// POST TO SOCIALS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _PostToSocialsSheet extends StatefulWidget {
  final String userName;
  final String bracketName;
  final String? championPick;
  final Map<String, LinkedSocialAccount> linkedAccounts;
  final VoidCallback onAccountsChanged;
  /// True when another user is reposting someone else's bracket.
  final bool isRepost;

  const _PostToSocialsSheet({
    required this.userName,
    required this.bracketName,
    this.championPick,
    required this.linkedAccounts,
    required this.onAccountsChanged,
    this.isRepost = false,
  });

  @override
  State<_PostToSocialsSheet> createState() => _PostToSocialsSheetState();
}

class _PostToSocialsSheetState extends State<_PostToSocialsSheet> {
  late Map<String, LinkedSocialAccount> _accounts;
  final Set<String> _selectedPlatforms = {};
  bool _isPosting = false;
  bool _posted = false;

  @override
  void initState() {
    super.initState();
    _accounts = Map.from(widget.linkedAccounts);
    // Auto-select all linked platforms with auto-post enabled
    for (final entry in _accounts.entries) {
      if (entry.value.autoPostEnabled) {
        _selectedPlatforms.add(entry.key);
      }
    }
  }

  String get _shareText {
    if (widget.isRepost) {
      final champ = widget.championPick != null
          ? ' They\'re riding with ${widget.championPick} to win it all!'
          : '';
      return 'Check out ${widget.userName}\'s bracket picks for '
          '"${widget.bracketName}"!$champ '
          'Think you can do better? Download @BackMyBracket and prove it! '
          '#BackMyBracket #BMB #BracketPicks';
    }
    final champ = widget.championPick != null
        ? ' I\'m riding with ${widget.championPick} to win it all!'
        : '';
    return 'Check out my bracket picks for "${widget.bracketName}"!$champ '
        'Think you can beat me? Download @BackMyBracket and prove it! '
        '#BackMyBracket #BMB #BracketPicks';
  }

  @override
  Widget build(BuildContext context) {
    final hasLinked = _accounts.isNotEmpty;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BmbColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        const Icon(Icons.share, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isRepost ? 'Repost to My Socials' : 'Post to Socials',
                          style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay',
                          ),
                        ),
                        Text(
                          hasLinked
                              ? '${_accounts.length} account${_accounts.length == 1 ? '' : 's'} linked'
                              : 'Link your socials to share',
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Manage accounts button
                  GestureDetector(
                    onTap: () => _showManageAccountsSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: BmbColors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: BmbColors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings,
                              color: BmbColors.blue, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Manage',
                            style: TextStyle(
                              color: BmbColors.blue,
                              fontSize: 10,
                              fontWeight: BmbFontWeights.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Share text preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: BmbColors.borderColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote,
                            color: BmbColors.blue, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Your post:',
                          style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 10,
                            fontWeight: BmbFontWeights.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _shareText,
                      style: TextStyle(
                        color: BmbColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BmbColors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: BmbColors.blue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_tree,
                              color: BmbColors.blue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your bracket tree image will be attached',
                              style: TextStyle(
                                  color: BmbColors.blue, fontSize: 11),
                            ),
                          ),
                          Icon(Icons.image, color: BmbColors.blue, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Platform selection grid
              if (hasLinked) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: SocialAccountsService.allPlatforms.map((platform) {
                    final isLinked = _accounts.containsKey(platform.id);
                    final isSelected = _selectedPlatforms.contains(platform.id);

                    if (!isLinked) {
                      return _UnlinkedPlatformChip(
                        platform: platform,
                        onLink: () => _showLinkAccountDialog(context, platform),
                      );
                    }

                    return _LinkedPlatformChip(
                      platform: platform,
                      account: _accounts[platform.id]!,
                      isSelected: isSelected,
                      onToggle: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPlatforms.remove(platform.id);
                          } else {
                            _selectedPlatforms.add(platform.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ] else ...[
                // No accounts linked — show link prompt
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: BmbColors.borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.link,
                          color: BmbColors.textTertiary, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        'Link your social accounts',
                        style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 15,
                          fontWeight: BmbFontWeights.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Link once, share forever! Future posts will go out automatically.',
                        style: TextStyle(
                          color: BmbColors.textTertiary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: SocialAccountsService.allPlatforms
                            .map((platform) => _UnlinkedPlatformChip(
                                  platform: platform,
                                  onLink: () => _showLinkAccountDialog(
                                      context, platform),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Post button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _posted
                      ? null
                      : (_selectedPlatforms.isNotEmpty ? _handlePost : null),
                  icon: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_posted ? Icons.check_circle : Icons.send,
                          size: 20),
                  label: Text(
                    _posted
                        ? 'Posted to ${_selectedPlatforms.length} platform${_selectedPlatforms.length == 1 ? '' : 's'}!'
                        : _selectedPlatforms.isEmpty
                            ? 'Select platforms to post'
                            : 'Post to ${_selectedPlatforms.length} platform${_selectedPlatforms.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 15, fontWeight: BmbFontWeights.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _posted
                        ? BmbColors.successGreen
                        : const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: BmbColors.cardDark,
                    disabledForegroundColor: BmbColors.textTertiary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePost() async {
    setState(() => _isPosting = true);

    // Share to each selected platform
    for (final platformId in _selectedPlatforms) {
      final platform = SocialAccountsService.allPlatforms
          .firstWhere((p) => p.id == platformId);

      try {
        final encodedText = Uri.encodeComponent(_shareText);
        String urlStr;

        switch (platformId) {
          case 'twitter':
            urlStr = 'https://twitter.com/intent/tweet?text=$encodedText';
            break;
          case 'facebook':
            urlStr =
                'https://www.facebook.com/sharer/sharer.php?quote=$encodedText';
            break;
          case 'instagram':
            // Instagram doesn't support prefilled posts — copy text
            await Clipboard.setData(ClipboardData(text: _shareText));
            urlStr = 'https://www.instagram.com/';
            break;
          case 'snapchat':
            await Clipboard.setData(ClipboardData(text: _shareText));
            urlStr = 'https://www.snapchat.com/';
            break;
          case 'tiktok':
            await Clipboard.setData(ClipboardData(text: _shareText));
            urlStr = 'https://www.tiktok.com/';
            break;
          default:
            urlStr = platform.shareUrlBase + encodedText;
        }

        final uri = Uri.parse(urlStr);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        // Continue with next platform
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    setState(() {
      _isPosting = false;
      _posted = true;
    });

    final copiedPlatforms = _selectedPlatforms
        .where((id) => ['instagram', 'snapchat', 'tiktok'].contains(id));
    if (copiedPlatforms.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.content_copy, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Caption copied! Paste it in your post.')),
          ]),
          backgroundColor: BmbColors.midNavy,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context);
  }

  // ─── LINK ACCOUNT DIALOG ──────────────────────────────────────────────

  void _showLinkAccountDialog(BuildContext ctx, SocialPlatform platform) {
    final usernameCtrl = TextEditingController();
    final color = Color(platform.color);

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                SocialPlatform.getIcon(platform.id),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Link ${platform.name}',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 16,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your ${platform.name} username to link your account. You only need to do this once!',
              style:
                  TextStyle(color: BmbColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameCtrl,
              style: TextStyle(
                  color: BmbColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: TextStyle(color: color, fontSize: 14),
                hintText: 'username',
                hintStyle: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 14),
                filled: true,
                fillColor: BmbColors.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: BmbColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: BmbColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        BmbColors.successGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: BmbColors.successGreen, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Link once — future posts go out with one tap!',
                      style: TextStyle(
                        color: BmbColors.successGreen,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel',
                style: TextStyle(color: BmbColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = usernameCtrl.text.trim();
              if (username.isEmpty) return;

              await SocialAccountsService.linkAccount(
                platformId: platform.id,
                username: username,
              );

              if (mounted) {
                if (dCtx.mounted) Navigator.pop(dCtx); // BUG #12 FIX
                // Refresh accounts
                final accounts =
                    await SocialAccountsService.getLinkedAccounts();
                if (!mounted) return;
                setState(() {
                  _accounts = accounts;
                  _selectedPlatforms.add(platform.id);
                });
                widget.onAccountsChanged();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text('${platform.name} linked! @$username'),
                    ]),
                    backgroundColor: BmbColors.successGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor:
                  color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Link Account',
                style:
                    TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── MANAGE ACCOUNTS SHEET ────────────────────────────────────────────

  void _showManageAccountsSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (mCtx) => _ManageAccountsSheet(
        accounts: _accounts,
        onChanged: () async {
          final accounts = await SocialAccountsService.getLinkedAccounts();
          if (mounted) {
            setState(() {
              _accounts = accounts;
              // Remove deselected platforms
              _selectedPlatforms
                  .removeWhere((id) => !accounts.containsKey(id));
            });
            widget.onAccountsChanged();
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLATFORM CHIP WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _LinkedPlatformChip extends StatelessWidget {
  final SocialPlatform platform;
  final LinkedSocialAccount account;
  final bool isSelected;
  final VoidCallback onToggle;

  const _LinkedPlatformChip({
    required this.platform,
    required this.account,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(platform.color);
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : BmbColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : BmbColors.borderColor,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 16)
            else
              Icon(
                SocialPlatform.getIcon(platform.id),
                color: color,
                size: 16,
              ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  platform.name,
                  style: TextStyle(
                    color:
                        isSelected ? BmbColors.textPrimary : BmbColors.textSecondary,
                    fontSize: 11,
                    fontWeight: BmbFontWeights.bold,
                  ),
                ),
                Text(
                  '@${account.username}',
                  style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlinkedPlatformChip extends StatelessWidget {
  final SocialPlatform platform;
  final VoidCallback onLink;

  const _UnlinkedPlatformChip({
    required this.platform,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(platform.color);
    return GestureDetector(
      onTap: onLink,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: BmbColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: BmbColors.borderColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              SocialPlatform.getIcon(platform.id),
              color: color.withValues(alpha: 0.5),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '+ Link',
              style: TextStyle(
                color: BmbColors.textTertiary,
                fontSize: 11,
                fontWeight: BmbFontWeights.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MANAGE ACCOUNTS SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _ManageAccountsSheet extends StatefulWidget {
  final Map<String, LinkedSocialAccount> accounts;
  final VoidCallback onChanged;

  const _ManageAccountsSheet({
    required this.accounts,
    required this.onChanged,
  });

  @override
  State<_ManageAccountsSheet> createState() => _ManageAccountsSheetState();
}

class _ManageAccountsSheetState extends State<_ManageAccountsSheet> {
  late Map<String, LinkedSocialAccount> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = Map.from(widget.accounts);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: BmbColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.manage_accounts,
                  color: BmbColors.textPrimary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Manage Linked Accounts',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 16,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No accounts linked yet.\nTap "+ Link" on any platform to get started.',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...SocialAccountsService.allPlatforms
                .where((p) => _accounts.containsKey(p.id))
                .map((platform) {
              final account = _accounts[platform.id]!;
              final color = Color(platform.color);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: BmbColors.borderColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        SocialPlatform.getIcon(platform.id),
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            platform.name,
                            style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.bold,
                            ),
                          ),
                          Text(
                            '@${account.username}',
                            style: TextStyle(
                                color: BmbColors.textTertiary,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Auto-post toggle
                    Column(
                      children: [
                        Switch(
                          value: account.autoPostEnabled,
                          activeTrackColor: color,
                          onChanged: (val) async {
                            await SocialAccountsService.toggleAutoPost(
                                platform.id, val);
                            final updated =
                                await SocialAccountsService.getLinkedAccounts();
                            setState(() => _accounts = updated);
                            widget.onChanged();
                          },
                        ),
                        Text(
                          'Auto-post',
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 8),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    // Unlink button
                    GestureDetector(
                      onTap: () async {
                        await SocialAccountsService.unlinkAccount(
                            platform.id);
                        final updated =
                            await SocialAccountsService.getLinkedAccounts();
                        setState(() => _accounts = updated);
                        widget.onChanged();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text('${platform.name} unlinked'),
                            backgroundColor: BmbColors.midNavy,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              BmbColors.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.link_off,
                            color: BmbColors.errorRed, size: 16),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
