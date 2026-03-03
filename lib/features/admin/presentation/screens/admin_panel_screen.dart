import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';

/// Admin Panel — live Firestore dashboard with 5 tabs:
///   1. Overview (stats cards + recent activity)
///   2. Users (list, search, edit, ban)
///   3. Brackets (moderate, feature, delete, status change)
///   4. Credits (credit flow summary, transactions list)
///   5. Revenue (subscriptions, MRR tracking)
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirestoreService.instance;

  // ─── DATA STATE ──────────────────────────────────────────────────
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _brackets = [];
  List<Map<String, dynamic>> _subscriptions = [];
  List<Map<String, dynamic>> _recentEvents = [];
  List<Map<String, dynamic>> _creditTransactions = [];
  Map<String, dynamic> _creditFlow = {};

  // Search / filter
  String _userSearchQuery = '';
  String _bracketStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _firestore.getAdminDashboardStats(),       // 0
        _firestore.getAllUsers(),                    // 1
        _firestore.getBrackets(),                   // 2
        _firestore.getAllSubscriptions(),            // 3
        _firestore.getRecentEvents(limit: 30),      // 4
        _firestore.getAllCreditTransactions(),       // 5
        _firestore.getCreditFlowSummary(),          // 6
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _users = results[1] as List<Map<String, dynamic>>;
        _brackets = results[2] as List<Map<String, dynamic>>;
        _subscriptions = results[3] as List<Map<String, dynamic>>;
        _recentEvents = results[4] as List<Map<String, dynamic>>;
        _creditTransactions = results[5] as List<Map<String, dynamic>>;
        _creditFlow = results[6] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Admin panel load error: $e');
      if (mounted) setState(() => _loading = false);
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
              // ── HEADER ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Icon(Icons.admin_panel_settings, color: BmbColors.gold, size: 28),
                    const SizedBox(width: 8),
                    Text('Admin Panel',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 22,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: BmbColors.blue),
                      onPressed: _loadAllData,
                      tooltip: 'Refresh all data',
                    ),
                  ],
                ),
              ),
              // ── TABS ──
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: BmbColors.gold,
                unselectedLabelColor: BmbColors.textTertiary,
                indicatorColor: BmbColors.gold,
                labelStyle: TextStyle(fontWeight: BmbFontWeights.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Users'),
                  Tab(text: 'Brackets'),
                  Tab(text: 'Credits'),
                  Tab(text: 'Revenue'),
                ],
              ),
              const Divider(color: BmbColors.borderColor, height: 1),
              // ── BODY ──
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: BmbColors.gold))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildUsersTab(),
                          _buildBracketsTab(),
                          _buildCreditsTab(),
                          _buildRevenueTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1: OVERVIEW
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      color: BmbColors.gold,
      backgroundColor: BmbColors.midNavy,
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Platform Stats', Icons.analytics),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Total Users', '${_stats['total_users'] ?? 0}', Icons.people, BmbColors.blue),
            const SizedBox(width: 12),
            _statCard('Brackets', '${_stats['total_brackets'] ?? 0}', Icons.account_tree, BmbColors.gold),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Live', '${_stats['live_brackets'] ?? 0}', Icons.circle, BmbColors.successGreen),
            const SizedBox(width: 12),
            _statCard('Completed', '${_stats['completed_brackets'] ?? 0}', Icons.check_circle, const Color(0xFF00BCD4)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Draft', '${_stats['draft_brackets'] ?? 0}', Icons.edit_note, BmbColors.textTertiary),
            const SizedBox(width: 12),
            _statCard('Revenue/mo', '\$${(_stats['estimated_monthly_revenue'] ?? 0).toStringAsFixed(0)}', Icons.attach_money, BmbColors.gold),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('User Tiers', Icons.badge),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Free', '${_stats['free_users'] ?? 0}', Icons.person_outline, BmbColors.textTertiary),
            const SizedBox(width: 12),
            _statCard('BMB+', '${_stats['plus_users'] ?? 0}', Icons.workspace_premium, BmbColors.gold),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Business', '${_stats['business_users'] ?? 0}', Icons.business, BmbColors.blue),
            const SizedBox(width: 12),
            _statCard('Active Subs', '${(_stats['active_plus_subscriptions'] ?? 0) + (_stats['active_business_subscriptions'] ?? 0)}', Icons.card_membership, BmbColors.successGreen),
          ]),
          const SizedBox(height: 24),
          // Credit economy quick stats
          _sectionHeader('Credit Economy', Icons.savings),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Net Flow', '${_creditFlow['net_flow'] ?? 0}', Icons.swap_vert, (_creditFlow['net_flow'] ?? 0) >= 0 ? BmbColors.successGreen : BmbColors.errorRed),
            const SizedBox(width: 12),
            _statCard('Transactions', '${_creditFlow['transaction_count'] ?? 0}', Icons.receipt, BmbColors.blue),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Recent Activity', Icons.history),
          const SizedBox(height: 12),
          if (_recentEvents.isEmpty)
            _emptyState('No recent events')
          else
            ..._recentEvents.take(15).map(_buildEventTile),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2: USERS (with search)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildUsersTab() {
    final filtered = _userSearchQuery.isEmpty
        ? _users
        : _users.where((u) {
            final name = (u['display_name'] as String? ?? u['username'] as String? ?? '').toLowerCase();
            final email = (u['email'] as String? ?? '').toLowerCase();
            final q = _userSearchQuery.toLowerCase();
            return name.contains(q) || email.contains(q);
          }).toList();

    return RefreshIndicator(
      color: BmbColors.gold,
      backgroundColor: BmbColors.midNavy,
      onRefresh: _loadAllData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              style: const TextStyle(color: BmbColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: BmbColors.textTertiary, size: 20),
                filled: true,
                fillColor: BmbColors.cardDark,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: BmbColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: BmbColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: BmbColors.gold),
                ),
              ),
              onChanged: (v) => setState(() => _userSearchQuery = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('${filtered.length} users', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                const Spacer(),
                Text('Total credits: ${_users.fold<int>(0, (sum, u) => sum + ((u['credits_balance'] as num?)?.toInt() ?? 0))}',
                    style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _emptyState('No users found')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildUserTile(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final name = user['display_name'] as String? ?? user['username'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final tier = user['subscription_tier'] as String? ?? 'free';
    final credits = (user['credits_balance'] as num?)?.toInt() ?? 0;
    final isAdmin = user['is_admin'] as bool? ?? false;
    final isBanned = user['is_banned'] as bool? ?? false;
    final docId = user['doc_id'] as String? ?? '';
    final city = user['city'] as String? ?? '';
    final state = user['state'] as String? ?? '';
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isBanned ? BmbColors.errorRed.withValues(alpha: 0.1) : BmbColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isBanned ? BmbColors.errorRed.withValues(alpha: 0.3) : BmbColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _tierColor(tier).withValues(alpha: 0.2),
              child: Icon(_tierIcon(tier), color: _tierColor(tier), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(name,
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 14,
                              fontWeight: BmbFontWeights.bold),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      _miniTag('ADMIN', BmbColors.errorRed),
                    ],
                    if (isBanned) ...[
                      const SizedBox(width: 6),
                      _miniTag('BANNED', BmbColors.errorRed),
                    ],
                  ]),
                  Text(email, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                  if (location.isNotEmpty)
                    Text(location, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _tierBadge(tier),
                const SizedBox(height: 4),
                Text('$credits cr', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _actionChip('Edit Credits', Icons.savings, BmbColors.gold, () => _showEditCreditsDialog(docId, name, credits)),
              const SizedBox(width: 8),
              _actionChip(tier == 'free' ? 'Grant Plus' : 'Downgrade', Icons.workspace_premium,
                  tier == 'free' ? BmbColors.blue : BmbColors.textTertiary,
                  () => _toggleUserTier(docId, name, tier)),
              const SizedBox(width: 8),
              _actionChip(isBanned ? 'Unban' : 'Ban', Icons.block,
                  isBanned ? BmbColors.successGreen : BmbColors.errorRed,
                  () => _toggleBan(docId, name, isBanned)),
              const SizedBox(width: 8),
              _actionChip('View TXs', Icons.receipt_long, BmbColors.blue, () => _showUserTransactions(docId, name)),
            ]),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 3: BRACKETS (with filter)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBracketsTab() {
    final filtered = _bracketStatusFilter == 'all'
        ? List<Map<String, dynamic>>.from(_brackets)
        : _brackets.where((b) => b['status'] == _bracketStatusFilter).toList();

    final order = {'live': 0, 'upcoming': 1, 'draft': 2, 'in_progress': 3, 'completed': 4, 'deleted': 5};
    filtered.sort((a, b) {
      final aO = order[a['status']] ?? 9;
      final bO = order[b['status']] ?? 9;
      return aO.compareTo(bO);
    });

    final statusCounts = <String, int>{};
    for (final b in _brackets) {
      final s = b['status'] as String? ?? 'unknown';
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
    }

    return RefreshIndicator(
      color: BmbColors.gold,
      backgroundColor: BmbColors.midNavy,
      onRefresh: _loadAllData,
      child: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _filterChip('All (${_brackets.length})', 'all'),
                ...['live', 'upcoming', 'draft', 'completed', 'deleted'].map((s) =>
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _filterChip('${s[0].toUpperCase()}${s.substring(1)} (${statusCounts[s] ?? 0})', s),
                    )),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _emptyState('No brackets found')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildBracketTile(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _bracketStatusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _bracketStatusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? BmbColors.gold.withValues(alpha: 0.2) : BmbColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? BmbColors.gold : BmbColors.borderColor),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? BmbColors.gold : BmbColors.textTertiary,
                fontSize: 11,
                fontWeight: selected ? BmbFontWeights.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildBracketTile(Map<String, dynamic> bracket) {
    final name = bracket['name'] as String? ?? 'Untitled';
    final sport = bracket['sport'] as String? ?? '';
    final status = bracket['status'] as String? ?? 'draft';
    final host = bracket['host_display_name'] as String? ?? 'Unknown';
    final entrants = (bracket['entrants_count'] as num?)?.toInt() ?? 0;
    final maxEntrants = (bracket['max_entrants'] as num?)?.toInt() ?? 0;
    final isFeatured = bracket['is_featured'] as bool? ?? false;
    final docId = bracket['doc_id'] as String? ?? '';
    final bracketType = bracket['bracket_type'] as String? ?? 'elimination';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(name,
                          style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    _statusBadge(status),
                    if (isFeatured) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: BmbColors.gold, size: 14),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text('$sport  |  $bracketType  |  Host: $host',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                  Text('$entrants${maxEntrants > 0 ? '/$maxEntrants' : ''} entrants',
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _actionChip(isFeatured ? 'Unfeature' : 'Feature', Icons.star,
                  isFeatured ? BmbColors.textTertiary : BmbColors.gold,
                  () => _toggleFeatured(docId, name, isFeatured)),
              const SizedBox(width: 8),
              if (status == 'draft') ...[
                _actionChip('Go Live', Icons.play_circle, BmbColors.successGreen,
                    () => _setBracketStatus(docId, name, 'live')),
                const SizedBox(width: 8),
              ],
              if (status == 'live') ...[
                _actionChip('Complete', Icons.check_circle, const Color(0xFF00BCD4),
                    () => _setBracketStatus(docId, name, 'completed')),
                const SizedBox(width: 8),
              ],
              if (status != 'deleted')
                _actionChip('Delete', Icons.delete, BmbColors.errorRed,
                    () => _deleteBracket(docId, name)),
            ]),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 4: CREDITS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildCreditsTab() {
    return RefreshIndicator(
      color: BmbColors.gold,
      backgroundColor: BmbColors.midNavy,
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Credit Flow Summary', Icons.swap_vert),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Earned', '${_creditFlow['total_earned'] ?? 0}',
                Icons.arrow_upward, BmbColors.successGreen),
            const SizedBox(width: 12),
            _statCard('Spent', '${_creditFlow['total_spent'] ?? 0}',
                Icons.arrow_downward, BmbColors.errorRed),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Net', '${_creditFlow['net_flow'] ?? 0}',
                Icons.balance, (_creditFlow['net_flow'] ?? 0) >= 0 ? BmbColors.successGreen : BmbColors.errorRed),
            const SizedBox(width: 12),
            _statCard('Total TXs', '${_creditFlow['transaction_count'] ?? 0}',
                Icons.receipt, BmbColors.blue),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Signup', '${_creditFlow['signup_bonuses'] ?? 0}',
                Icons.person_add, BmbColors.blue),
            const SizedBox(width: 12),
            _statCard('Entry Fees', '${_creditFlow['entry_fees'] ?? 0}',
                Icons.monetization_on, BmbColors.gold),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Recent Transactions (${_creditTransactions.length})', Icons.receipt_long),
          const SizedBox(height: 12),
          if (_creditTransactions.isEmpty)
            _emptyState('No credit transactions found')
          else
            ..._creditTransactions.take(50).map(_buildCreditTxTile),
        ],
      ),
    );
  }

  Widget _buildCreditTxTile(Map<String, dynamic> tx) {
    final amount = (tx['amount'] as num?)?.toInt() ?? 0;
    final type = tx['type'] as String? ?? 'unknown';
    final userId = tx['user_id'] as String? ?? '';
    final reason = tx['reason'] as String? ?? '';
    final isPositive = amount >= 0;

    IconData icon;
    Color color;
    switch (type) {
      case 'signup_bonus':
        icon = Icons.card_giftcard;
        color = BmbColors.successGreen;
      case 'entry_fee':
        icon = Icons.monetization_on;
        color = BmbColors.errorRed;
      case 'admin_grant':
        icon = Icons.admin_panel_settings;
        color = BmbColors.gold;
      case 'admin_deduction':
        icon = Icons.remove_circle;
        color = BmbColors.errorRed;
      case 'purchase':
        icon = Icons.shopping_cart;
        color = BmbColors.blue;
      case 'winnings':
        icon = Icons.emoji_events;
        color = BmbColors.gold;
      default:
        icon = Icons.receipt;
        color = BmbColors.textTertiary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: color, fontSize: 10, fontWeight: BmbFontWeights.bold)),
              Text('User: ${userId.length > 20 ? '${userId.substring(0, 20)}...' : userId}',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
              if (reason.isNotEmpty)
                Text(reason, style: TextStyle(color: BmbColors.textTertiary, fontSize: 9),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Text('${isPositive ? '+' : ''}$amount',
            style: TextStyle(
                color: isPositive ? BmbColors.successGreen : BmbColors.errorRed,
                fontSize: 14,
                fontWeight: BmbFontWeights.bold)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 5: REVENUE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildRevenueTab() {
    final activeSubs = _subscriptions.where((s) => s['status'] == 'active').toList();
    double monthlyRevenue = 0;
    int plusCount = 0;
    int bizCount = 0;
    for (final s in activeSubs) {
      final plan = s['plan_type'] as String? ?? '';
      final price = (s['price_monthly'] as num?)?.toDouble() ?? 0;
      monthlyRevenue += price;
      if (plan == 'plus') plusCount++;
      if (plan == 'business') bizCount++;
    }

    return RefreshIndicator(
      color: BmbColors.gold,
      backgroundColor: BmbColors.midNavy,
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Subscription Revenue', Icons.attach_money),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Monthly', '\$${monthlyRevenue.toStringAsFixed(2)}', Icons.trending_up, BmbColors.successGreen),
            const SizedBox(width: 12),
            _statCard('Annual Est.', '\$${(monthlyRevenue * 12).toStringAsFixed(0)}', Icons.calendar_month, BmbColors.gold),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statCard('Plus Subs', '$plusCount', Icons.workspace_premium, BmbColors.gold),
            const SizedBox(width: 12),
            _statCard('Biz Subs', '$bizCount', Icons.business, BmbColors.blue),
          ]),
          const SizedBox(height: 24),
          // ARPU card
          if (_users.isNotEmpty) ...[
            _sectionHeader('Key Metrics', Icons.insights),
            const SizedBox(height: 12),
            Row(children: [
              _statCard('ARPU', '\$${_users.isNotEmpty ? (monthlyRevenue / _users.length).toStringAsFixed(2) : '0.00'}',
                  Icons.person, BmbColors.blue),
              const SizedBox(width: 12),
              _statCard('Paid %', '${_users.isNotEmpty ? ((activeSubs.length / _users.length) * 100).toStringAsFixed(1) : '0.0'}%',
                  Icons.pie_chart, BmbColors.gold),
            ]),
            const SizedBox(height: 24),
          ],
          _sectionHeader('Active Subscriptions (${activeSubs.length})', Icons.card_membership),
          const SizedBox(height: 12),
          if (activeSubs.isEmpty)
            _emptyState('No active subscriptions')
          else
            ...activeSubs.map(_buildSubscriptionTile),
          const SizedBox(height: 24),
          _sectionHeader('All Subscriptions (${_subscriptions.length})', Icons.receipt_long),
          const SizedBox(height: 12),
          if (_subscriptions.isEmpty)
            _emptyState('No subscriptions')
          else
            ..._subscriptions.map(_buildSubscriptionTile),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTile(Map<String, dynamic> sub) {
    final plan = sub['plan_type'] as String? ?? 'unknown';
    final status = sub['status'] as String? ?? 'unknown';
    final userId = sub['user_id'] as String? ?? '';
    final price = (sub['price_monthly'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Row(children: [
        Icon(
          plan == 'business' ? Icons.business : Icons.workspace_premium,
          color: plan == 'business' ? BmbColors.blue : BmbColors.gold,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.toUpperCase(),
                  style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.bold)),
              Text('User: ${userId.length > 20 ? '${userId.substring(0, 20)}...' : userId}',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\$${price.toStringAsFixed(2)}/mo',
                style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.bold)),
            _statusBadge(status),
          ],
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ADMIN ACTIONS
  // ═══════════════════════════════════════════════════════════════════

  void _showEditCreditsDialog(String userId, String userName, int currentCredits) {
    final controller = TextEditingController(text: '$currentCredits');
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        title: Text('Edit Credits', style: TextStyle(color: BmbColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('User: $userName', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: BmbColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'New Credits Balance',
                labelStyle: TextStyle(color: BmbColors.textTertiary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: BmbColors.borderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: BmbColors.gold)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              style: TextStyle(color: BmbColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: TextStyle(color: BmbColors.textTertiary),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: BmbColors.borderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: BmbColors.gold)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BmbColors.gold, foregroundColor: BmbColors.deepNavy),
            onPressed: () async {
              final newCredits = int.tryParse(controller.text) ?? currentCredits;
              final diff = newCredits - currentCredits;
              Navigator.pop(ctx);
              try {
                if (diff != 0) {
                  await _firestore.adminAdjustCredits(
                    userId,
                    diff,
                    reasonController.text.isEmpty ? 'Admin credit adjustment' : reasonController.text,
                  );
                }
                _showSnack('Credits updated for $userName: $newCredits (${diff >= 0 ? '+' : ''}$diff)');
                _loadAllData();
              } catch (e) {
                _showSnack('Failed to update credits: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUserTransactions(String userId, String userName) async {
    _showSnack('Loading transactions for $userName...');
    try {
      final txns = await _firestore.getUserCreditTransactions(userId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: BmbColors.deepNavy,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.receipt_long, color: BmbColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$userName Transactions',
                        style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
                  ),
                  Text('${txns.length} total', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                ]),
              ),
              const Divider(color: BmbColors.borderColor, height: 1),
              Expanded(
                child: txns.isEmpty
                    ? _emptyState('No transactions')
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: txns.length,
                        itemBuilder: (_, i) => _buildCreditTxTile(txns[i]),
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnack('Failed to load transactions: $e');
    }
  }

  Future<void> _toggleUserTier(String userId, String name, String currentTier) async {
    final newTier = currentTier == 'free' ? 'plus' : 'free';
    final isBmbPlus = newTier != 'free';
    try {
      await _firestore.updateUser(userId, {
        'subscription_tier': newTier,
        'is_bmb_plus': isBmbPlus,
      });
      _showSnack('$name ${isBmbPlus ? "upgraded to BMB+" : "downgraded to Free"}');
      _loadAllData();
    } catch (e) {
      _showSnack('Failed: $e');
    }
  }

  Future<void> _toggleBan(String userId, String name, bool isBanned) async {
    try {
      await _firestore.updateUser(userId, {'is_banned': !isBanned});
      _showSnack('$name ${isBanned ? "unbanned" : "banned"}');
      _loadAllData();
    } catch (e) {
      _showSnack('Failed: $e');
    }
  }

  Future<void> _toggleFeatured(String bracketId, String name, bool isFeatured) async {
    try {
      await _firestore.updateBracket(bracketId, {'is_featured': !isFeatured});
      _showSnack('"$name" ${isFeatured ? "unfeatured" : "featured"}');
      _loadAllData();
    } catch (e) {
      _showSnack('Failed: $e');
    }
  }

  Future<void> _deleteBracket(String bracketId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        title: Text('Delete Bracket?', style: TextStyle(color: BmbColors.textPrimary)),
        content: Text('This will mark "$name" as deleted.', style: TextStyle(color: BmbColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BmbColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _firestore.updateBracket(bracketId, {'status': 'deleted'});
      _showSnack('"$name" deleted');
      _loadAllData();
    } catch (e) {
      _showSnack('Failed: $e');
    }
  }

  Future<void> _setBracketStatus(String bracketId, String name, String status) async {
    try {
      await _firestore.updateBracket(bracketId, {
        'status': status,
        if (status == 'live') 'go_live_date': DateTime.now().toUtc(),
      });
      _showSnack('"$name" is now ${status.toUpperCase()}');
      _loadAllData();
    } catch (e) {
      _showSnack('Failed: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: BmbColors.midNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, color: BmbColors.gold, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 16,
              fontWeight: BmbFontWeights.bold,
              fontFamily: 'ClashDisplay')),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BmbColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Flexible(
                child: Text(value,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 20,
                        fontWeight: BmbFontWeights.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final colors = {
      'live': BmbColors.successGreen,
      'upcoming': BmbColors.blue,
      'draft': BmbColors.textTertiary,
      'in_progress': BmbColors.gold,
      'completed': const Color(0xFF00BCD4),
      'active': BmbColors.successGreen,
      'cancelled': BmbColors.errorRed,
      'deleted': BmbColors.errorRed,
    };
    final c = colors[status] ?? BmbColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status.toUpperCase().replaceAll('_', ' '),
          style: TextStyle(color: c, fontSize: 9, fontWeight: BmbFontWeights.bold)),
    );
  }

  Widget _tierBadge(String tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _tierColor(tier).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(tier.toUpperCase(),
          style: TextStyle(color: _tierColor(tier), fontSize: 9, fontWeight: BmbFontWeights.bold)),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: BmbFontWeights.bold)),
    );
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'plus': return BmbColors.gold;
      case 'business': return BmbColors.blue;
      default: return BmbColors.textTertiary;
    }
  }

  IconData _tierIcon(String tier) {
    switch (tier) {
      case 'plus': return Icons.workspace_premium;
      case 'business': return Icons.business;
      default: return Icons.person_outline;
    }
  }

  Widget _actionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: BmbFontWeights.bold)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: BmbColors.textTertiary, size: 40),
            const SizedBox(height: 8),
            Text(msg, style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event) {
    final type = event['event_type'] as String? ?? 'unknown';
    final userId = event['user_id'] as String? ?? '';
    final screen = event['screen'] as String? ?? '';

    IconData icon;
    Color color;
    switch (type) {
      case 'signup_completed':
        icon = Icons.person_add;
        color = BmbColors.successGreen;
      case 'login':
        icon = Icons.login;
        color = BmbColors.blue;
      case 'bracket_created':
        icon = Icons.account_tree;
        color = BmbColors.gold;
      case 'bracket_joined':
        icon = Icons.group_add;
        color = const Color(0xFF00BCD4);
      case 'admin_credit_adjustment':
        icon = Icons.admin_panel_settings;
        color = BmbColors.gold;
      default:
        icon = Icons.event;
        color = BmbColors.textTertiary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: color, fontSize: 10, fontWeight: BmbFontWeights.bold)),
              Text('User: ${userId.length > 20 ? '${userId.substring(0, 20)}...' : userId}${screen.isNotEmpty ? ' | $screen' : ''}',
                  style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
            ],
          ),
        ),
      ]),
    );
  }
}
