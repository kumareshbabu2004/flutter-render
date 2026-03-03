import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firebase_auth.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/sharing/data/services/deep_link_service.dart';

/// Landing screen when a user opens a shared bracket link.
///
/// Flow:
///   1. Fetch bracket data from Firestore.
///   2. If user IS logged in → show bracket preview with "Join & Make Picks" CTA.
///   3. If user is NOT logged in → show bracket preview with "Sign Up to Join" CTA,
///      store the bracket ID as pending, redirect to auth.
///   4. After auth completes, the pending bracket auto-populates on the dashboard.
class JoinBracketScreen extends StatefulWidget {
  final String bracketId;
  const JoinBracketScreen({super.key, required this.bracketId});

  @override
  State<JoinBracketScreen> createState() => _JoinBracketScreenState();
}

class _JoinBracketScreenState extends State<JoinBracketScreen> {
  bool _loading = true;
  bool _notFound = false;
  Map<String, dynamic>? _bracketData;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _loadBracket();
  }

  Future<void> _loadBracket() async {
    final data =
        await DeepLinkService.instance.fetchBracketForJoin(widget.bracketId);
    if (!mounted) return;
    setState(() {
      _bracketData = data;
      _notFound = data == null;
      _loading = false;
    });
  }

  bool get _isLoggedIn => RestFirebaseAuth.instance.isSignedIn;

  Future<void> _joinBracket() async {
    if (_bracketData == null) return;
    setState(() => _joining = true);

    try {
      final cu = CurrentUserService.instance;
      // Record the entry in Firestore
      await FirestoreService.instance.submitBracketEntry({
        'bracket_id': widget.bracketId,
        'user_id': cu.userId,
        'display_name': cu.displayName,
        'state': cu.stateAbbr,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
        'has_made_picks': false,
        'source': 'share_link',
      });

      if (!mounted) return;

      // Navigate to dashboard with the bracket auto-loaded
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'Joined "${_bracketData!['name'] ?? 'bracket'}"! Make your picks!'),
          ),
        ]),
        backgroundColor: BmbColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    } catch (e) {
      if (kDebugMode) debugPrint('JoinBracket: join error: $e');
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to join: $e'),
        backgroundColor: BmbColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _signUpToJoin() async {
    // Store the bracket as pending so it auto-joins after signup
    await DeepLinkService.instance.setPendingBracket(widget.bracketId);
    if (!mounted) return;
    // Navigate to auth screen
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: _loading
              ? _buildLoading()
              : _notFound
                  ? _buildNotFound()
                  : _buildBracketPreview(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(BmbColors.blue),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading bracket...',
            style: TextStyle(
              color: BmbColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, color: BmbColors.textTertiary, size: 64),
            const SizedBox(height: 20),
            Text(
              'Bracket Not Found',
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 22,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This bracket may have expired or been removed. Check with the host for an updated link.',
              style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_isLoggedIn) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/dashboard', (_) => false);
                  } else {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/auth', (_) => false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_isLoggedIn ? 'Go to Dashboard' : 'Sign Up Free',
                    style: TextStyle(fontWeight: BmbFontWeights.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketPreview() {
    final data = _bracketData!;
    final name = data['name'] as String? ?? 'Untitled Bracket';
    final sport = data['sport'] as String? ?? 'General';
    final hostName = data['host_display_name'] as String? ?? 'Unknown Host';
    final entryFee = (data['entry_fee'] as num?)?.toDouble() ?? 0;
    final isFree = entryFee == 0;
    final prizeDesc = data['prize_description'] as String? ?? '';
    final prizeType = data['prize_type'] as String? ?? 'none';
    final teams = List<String>.from(data['teams'] ?? []);
    final teamCount = (data['team_count'] as num?)?.toInt() ?? teams.length;
    final entrants = (data['entrants_count'] as num?)?.toInt() ?? 0;
    final status = data['status'] as String? ?? 'upcoming';
    final bracketType = data['bracket_type'] as String? ?? 'standard';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // ─── BMB BRANDED HEADER ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1a237e),
                  const Color(0xFF4a148c),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: BmbColors.blue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo area
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events,
                        color: BmbColors.gold, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'BACK MY BRACKET',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.bold,
                        letterSpacing: 2,
                        fontFamily: 'ClashDisplay',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'WHO YOU GOT?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: BmbFontWeights.extraBold,
                    fontFamily: 'ClashDisplay',
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ve been invited to join a bracket!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── BRACKET INFO CARD ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: BmbColors.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: BmbColors.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status + type badges
                Row(
                  children: [
                    _statusBadge(status),
                    const SizedBox(width: 8),
                    _typeBadge(bracketType),
                    const SizedBox(width: 8),
                    Text(sport,
                        style: TextStyle(
                            color: BmbColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),

                // Bracket name
                Text(
                  name,
                  style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 22,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                  ),
                ),
                const SizedBox(height: 8),

                // Host
                Row(children: [
                  Icon(Icons.person, color: BmbColors.blue, size: 16),
                  const SizedBox(width: 6),
                  Text('Hosted by ',
                      style: TextStyle(
                          color: BmbColors.textSecondary, fontSize: 13)),
                  Text(hostName,
                      style: TextStyle(
                          color: BmbColors.blue,
                          fontSize: 13,
                          fontWeight: BmbFontWeights.semiBold)),
                ]),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(Icons.people, '$entrants playing',
                        BmbColors.blue),
                    _statItem(
                        Icons.grid_view,
                        '$teamCount ${bracketType == 'voting' ? 'items' : 'teams'}',
                        BmbColors.gold),
                    _statItem(
                        Icons.attach_money,
                        isFree ? 'FREE' : '${entryFee.toInt()} credits',
                        BmbColors.successGreen),
                  ],
                ),

                // Prize
                if (prizeType != 'none' && prizeDesc.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BmbColors.gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: BmbColors.gold.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.emoji_events,
                          color: BmbColors.gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prize',
                                style: TextStyle(
                                    color: BmbColors.gold,
                                    fontSize: 10,
                                    fontWeight: BmbFontWeights.bold)),
                            Text(prizeDesc,
                                style: TextStyle(
                                    color: BmbColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: BmbFontWeights.semiBold)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],

                // Teams preview (show first 8)
                if (teams.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Matchups',
                      style: TextStyle(
                          color: BmbColors.textTertiary,
                          fontSize: 11,
                          fontWeight: BmbFontWeights.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: teams.take(8).map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: BmbColors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  BmbColors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 11)),
                      );
                    }).toList(),
                  ),
                  if (teams.length > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          '+${teams.length - 8} more',
                          style: TextStyle(
                              color: BmbColors.textTertiary, fontSize: 11)),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── CTA BUTTON ───
          if (_isLoggedIn) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _joining ? null : _joinBracket,
                icon: _joining
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      )
                    : const Icon(Icons.play_circle_filled, size: 22),
                label: Text(
                  _joining ? 'Joining...' : 'Join & Make My Picks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.successGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
          ] else ...[
            // NOT LOGGED IN — Sign up prompt
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    BmbColors.blue.withValues(alpha: 0.15),
                    BmbColors.successGreen.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: BmbColors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.person_add,
                      color: BmbColors.blue, size: 32),
                  const SizedBox(height: 10),
                  Text(
                    'Create a free account to join this bracket!',
                    style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 15,
                      fontWeight: BmbFontWeights.semiBold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign up in 30 seconds. Your bracket will be waiting.',
                    style: TextStyle(
                      color: BmbColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _signUpToJoin,
                      icon: const Icon(Icons.flash_on, size: 20),
                      label: Text(
                        'Sign Up Free & Join',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.successGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      // Already have account? Login with pending bracket
                      DeepLinkService.instance
                          .setPendingBracket(widget.bracketId);
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/auth', (_) => false);
                    },
                    child: Text(
                      'Already have an account? Log in',
                      style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.semiBold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Back button
          TextButton.icon(
            onPressed: () {
              if (_isLoggedIn) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/dashboard', (_) => false);
              } else {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/auth', (_) => false);
              }
            },
            icon: Icon(Icons.arrow_back_ios, size: 14, color: BmbColors.textTertiary),
            label: Text(
              _isLoggedIn ? 'Back to Dashboard' : 'Back',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'live': BmbColors.errorRed,
      'upcoming': BmbColors.successGreen,
      'in_progress': BmbColors.blue,
      'saved': BmbColors.textTertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (colors[status] ?? BmbColors.textTertiary)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (colors[status] ?? BmbColors.textTertiary)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: colors[status] ?? BmbColors.textTertiary,
          fontSize: 10,
          fontWeight: BmbFontWeights.bold,
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    final labels = {
      'standard': 'Standard',
      'voting': 'Voting',
      'pickem': "Pick'Em",
      'nopicks': 'No Picks',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BmbColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.emoji_events, color: BmbColors.gold, size: 10),
        const SizedBox(width: 3),
        Text(
          labels[type] ?? 'Standard',
          style: TextStyle(
            color: BmbColors.gold,
            fontSize: 10,
            fontWeight: BmbFontWeights.bold,
          ),
        ),
      ]),
    );
  }

  Widget _statItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 12,
                fontWeight: BmbFontWeights.semiBold)),
      ],
    );
  }
}
