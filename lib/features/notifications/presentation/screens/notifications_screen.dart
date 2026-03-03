import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/notifications/data/services/reply_notification_service.dart';
import 'package:bmb_mobile/features/favorites/data/services/favorite_teams_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';

  // Push notification preferences
  bool _bracketAlerts = true;
  bool _pickResultAlerts = true;
  bool _chatAlerts = true;
  bool _replyAlerts = true;
  bool _promoAlerts = false;
  bool _scoreAlerts = true;

  final _replyNotifService = ReplyNotificationService();
  final _favService = FavoriteTeamsService();
  bool _replyNotifsLoaded = false;

  // Selection mode
  bool _selectMode = false;
  final Set<int> _selectedIndices = {};

  // Mutable notification list
  late List<_NotifItem> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _buildInitialNotifications();
    _loadReplyNotifs();
    _loadFavAlerts();
  }

  List<_NotifItem> _buildInitialNotifications() {
    return [
      // ─── SCORE ALERTS (personalized from favorites) ───
      _NotifItem(id: 'score_1', icon: Icons.sports_basketball, iconColor: const Color(0xFFFF6B35), title: 'Houston Rockets WIN!',
          subtitle: 'Rockets defeat the Warriors 118-112. Jalen Green with 34 pts. Your team is on a 3-game win streak!', time: '5m ago', isUnread: true, category: 'scores'),
      _NotifItem(id: 'score_2', icon: Icons.sports_football, iconColor: const Color(0xFF795548), title: 'Dallas Cowboys LOSS',
          subtitle: 'Cowboys fall to the Eagles 21-31. Dak Prescott threw 2 INTs in the 4th quarter.', time: '28m ago', isUnread: true, category: 'scores'),
      _NotifItem(id: 'score_3', icon: Icons.sports_basketball, iconColor: const Color(0xFF1E88E5), title: 'NCAA: Duke advances!',
          subtitle: '#2 Duke beats #7 Michigan State 82-73 to reach the Elite Eight. Your team is still alive!', time: '1h ago', isUnread: true, category: 'scores'),
      _NotifItem(id: 'score_4', icon: Icons.report, iconColor: BmbColors.errorRed, title: 'INJURY ALERT: Luka Doncic',
          subtitle: 'Luka Doncic (ankle) is QUESTIONABLE for tomorrow\'s game vs. Celtics. Monitor your brackets.', time: '2h ago', isUnread: true, category: 'scores'),
      _NotifItem(id: 'score_5', icon: Icons.directions_car, iconColor: const Color(0xFFFF9800), title: 'NASCAR: Kyle Larson P1!',
          subtitle: 'Kyle Larson wins the Daytona 500! Your driver takes the checkered flag.', time: '3h ago', isUnread: true, category: 'scores'),

      // ─── BRACKET & PICK ALERTS ───
      _NotifItem(id: 's1', icon: Icons.sports_basketball, iconColor: const Color(0xFFFF6B35), title: 'New Bracket: March Madness 2025',
          subtitle: 'Based on your Basketball preference \u2014 join now before it fills up!', time: '10m ago', isUnread: true, category: 'brackets'),
      _NotifItem(id: 's2', icon: Icons.check_circle, iconColor: BmbColors.successGreen, title: 'Pick Results: Duke beats UNC 78-72',
          subtitle: 'Your Round 2 pick was CORRECT! +2 pts. You\'re now #5 on the leaderboard.', time: '1h ago', isUnread: true, category: 'picks'),
      _NotifItem(id: 's3', icon: Icons.cancel, iconColor: BmbColors.errorRed, title: 'Pick Results: Kansas falls to Miami',
          subtitle: 'Your Round 2 pick was incorrect. Kansas lost 64-68.', time: '1h ago', isUnread: true, category: 'picks'),
      _NotifItem(id: 's4', icon: Icons.emoji_events, iconColor: BmbColors.gold, title: 'You placed 3rd!',
          subtitle: 'March Madness 2025 Ultimate Bracket has ended.', time: '2h ago', isUnread: true, category: 'brackets'),
      _NotifItem(id: 's5', icon: Icons.group_add, iconColor: BmbColors.blue, title: 'New participant joined',
          subtitle: 'SlickRick joined your NFL Playoff Prediction Challenge.', time: '5h ago', isUnread: true, category: 'brackets'),
      _NotifItem(id: 's6', icon: Icons.chat_bubble, iconColor: BmbColors.successGreen, title: 'New chat message',
          subtitle: 'NateDoubleDown sent a message in March Madness chat.', time: '8h ago', isUnread: false, category: 'chat'),
      _NotifItem(id: 's7', icon: Icons.sports_football, iconColor: const Color(0xFF795548), title: 'New Bracket: NFL Wild Card Challenge',
          subtitle: 'Based on your Football preference \u2014 64 spots remaining!', time: '12h ago', isUnread: false, category: 'brackets'),
      _NotifItem(id: 's8', icon: Icons.savings, iconColor: BmbColors.gold, title: 'Credits added to your Bucket!',
          subtitle: '50 credits earned from Best Pizza in NYC bracket and added to your BMB Bucket.', time: '1d ago', isUnread: false, category: 'other'),
      _NotifItem(id: 's9', icon: Icons.star, iconColor: BmbColors.gold, title: 'New review received',
          subtitle: 'CourtneyWins left you a 5-star review.', time: '2d ago', isUnread: false, category: 'other'),
      _NotifItem(id: 's10', icon: Icons.campaign, iconColor: BmbColors.blue, title: 'Tournament starting soon!',
          subtitle: 'Masters 2025 Golf Pick Challenge starts in 1 hour.', time: '3d ago', isUnread: false, category: 'brackets'),
      _NotifItem(id: 's11', icon: Icons.quiz, iconColor: const Color(0xFF9C27B0), title: 'Daily Trivia is LIVE!',
          subtitle: '10 new sports trivia questions! Answer 15 in a row to earn 15 free credits. Play now in BMB Community!', time: '2h ago', isUnread: true, category: 'other'),
      _NotifItem(id: 's12', icon: Icons.local_fire_department, iconColor: BmbColors.gold, title: 'StatGuru42 is on a 22 streak!',
          subtitle: 'Can you beat the trivia streak leaderboard? Head to BMB Community and play trivia!', time: '4h ago', isUnread: true, category: 'other'),
      _NotifItem(id: 's13', icon: Icons.workspace_premium, iconColor: BmbColors.gold, title: 'BMB+ Special Offer',
          subtitle: 'Upgrade to BMB+ and get 500 bonus credits in your BMB Bucket!', time: '5d ago', isUnread: false, category: 'promo'),
      _NotifItem(id: 's14', icon: Icons.storefront, iconColor: BmbColors.successGreen, title: 'New in the BMB Store!',
          subtitle: 'Redeem credits for Amazon, Visa & DoorDash gift cards. Custom bracket prints now available!', time: '6d ago', isUnread: false, category: 'promo'),
    ];
  }

  Future<void> _loadReplyNotifs() async {
    await _replyNotifService.init();
    if (mounted) setState(() => _replyNotifsLoaded = true);
  }

  Future<void> _loadFavAlerts() async {
    await _favService.init();
    if (mounted) setState(() {});
  }

  /// Build the full combined list (reply notifs at top + static notifs)
  List<_NotifItem> get _allItems {
    final items = <_NotifItem>[];

    if (_replyNotifsLoaded && _replyAlerts) {
      for (final rn in _replyNotifService.notifications) {
        final diff = DateTime.now().difference(rn.timestamp);
        String timeStr;
        if (diff.inMinutes < 1) {
          timeStr = 'now';
        } else if (diff.inMinutes < 60) {
          timeStr = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          timeStr = '${diff.inHours}h ago';
        } else {
          timeStr = '${diff.inDays}d ago';
        }

        items.add(_NotifItem(
          id: rn.id,
          icon: Icons.reply,
          iconColor: BmbColors.gold,
          title: '${rn.replierName} replied to your comment',
          subtitle: '"${rn.replyMessage}"',
          time: timeStr,
          isUnread: !rn.isRead,
          category: 'replies',
          originalMessage: rn.originalMessage,
        ));
      }
    }

    // Filter out score alerts if user turned them off
    if (_scoreAlerts) {
      items.addAll(_notifications);
    } else {
      items.addAll(_notifications.where((n) => n.category != 'scores'));
    }
    return items;
  }

  List<_NotifItem> get _filtered {
    final items = _allItems;
    if (_filter == 'All') return items;
    return items.where((n) => n.category == _filter.toLowerCase()).toList();
  }

  int get _totalUnread => _allItems.where((n) => n.isUnread).length;

  // ─── ACTIONS ──────────────────────────────────────────────────────────

  void _markSingleRead(_NotifItem item) {
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == item.id);
      if (idx >= 0) {
        _notifications[idx] = _notifications[idx].copyWith(isUnread: false);
      }
      if (item.category == 'replies') {
        _replyNotifService.markAllRead();
      }
    });
  }

  void _markAllRead() {
    setState(() {
      for (var i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isUnread: false);
      }
    });
    _replyNotifService.markAllRead();
    _showSnack('All notifications marked as read', BmbColors.blue);
  }

  void _markSelectedRead() {
    final filtered = _filtered;
    setState(() {
      for (final idx in _selectedIndices) {
        if (idx < filtered.length) {
          final item = filtered[idx];
          final sIdx = _notifications.indexWhere((n) => n.id == item.id);
          if (sIdx >= 0) {
            _notifications[sIdx] = _notifications[sIdx].copyWith(isUnread: false);
          }
        }
      }
      _selectedIndices.clear();
      _selectMode = false;
    });
    _replyNotifService.markAllRead();
    _showSnack('Selected notifications marked as read', BmbColors.blue);
  }

  void _deleteSelected() {
    final filtered = _filtered;
    final idsToDelete = <String>{};
    for (final idx in _selectedIndices) {
      if (idx < filtered.length) idsToDelete.add(filtered[idx].id);
    }
    setState(() {
      _notifications.removeWhere((n) => idsToDelete.contains(n.id));
      _selectedIndices.clear();
      _selectMode = false;
    });
    _showSnack('${idsToDelete.length} notification(s) deleted', BmbColors.errorRed);
  }

  void _deleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear All Notifications?', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
        content: Text('This will remove all notifications. This cannot be undone.', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _notifications.clear();
                _selectMode = false;
                _selectedIndices.clear();
              });
              _replyNotifService.clearAll();
              _showSnack('All notifications cleared', BmbColors.errorRed);
            },
            style: ElevatedButton.styleFrom(backgroundColor: BmbColors.errorRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Clear All', style: TextStyle(fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteSingle(_NotifItem item) {
    setState(() {
      _notifications.removeWhere((n) => n.id == item.id);
    });
    _showSnack('Notification deleted', BmbColors.midNavy);
  }

  void _selectAll() {
    setState(() {
      final filtered = _filtered;
      if (_selectedIndices.length == filtered.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.clear();
        for (var i = 0; i < filtered.length; i++) {
          _selectedIndices.add(i);
        }
      }
    });
  }

  void _toggleSelect(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _selectMode = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _enterSelectMode(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectMode = true;
      _selectedIndices.clear();
      _selectedIndices.add(index);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIndices.clear();
    });
  }

  void _openNotification(_NotifItem item) {
    _markSingleRead(item);
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _NotificationDetailSheet(item: item, onDelete: () {
        Navigator.pop(ctx);
        _deleteSingle(item);
      }),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _selectMode ? _buildSelectHeader() : _buildHeader(),
              _buildFilterChips(),
              const SizedBox(height: 4),
              Expanded(
                child: _filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) => _buildNotifTile(_filtered[index], index),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, color: BmbColors.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text('No notifications', style: TextStyle(color: BmbColors.textTertiary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('You\'re all caught up!', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── NORMAL HEADER ────────────────────────────────────────────────────
  Widget _buildHeader() {
    final unread = _totalUnread;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 4),
          Text('Notifications', style: TextStyle(color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: BmbColors.blue, borderRadius: BorderRadius.circular(10)),
              child: Text('$unread', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: BmbFontWeights.bold)),
            ),
          ],
          const Spacer(),
          // Select button
          IconButton(
            icon: const Icon(Icons.checklist, color: BmbColors.textSecondary, size: 22),
            tooltip: 'Select',
            onPressed: () => setState(() { _selectMode = true; _selectedIndices.clear(); }),
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings, color: BmbColors.textSecondary, size: 22),
            onPressed: _showNotifSettings,
          ),
          // More menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: BmbColors.textSecondary, size: 22),
            color: BmbColors.midNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'read_all') _markAllRead();
              if (v == 'delete_all') _deleteAll();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'read_all', child: Row(children: [
                Icon(Icons.done_all, color: BmbColors.blue, size: 18),
                const SizedBox(width: 8),
                Text('Mark All Read', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13)),
              ])),
              PopupMenuItem(value: 'delete_all', child: Row(children: [
                Icon(Icons.delete_sweep, color: BmbColors.errorRed, size: 18),
                const SizedBox(width: 8),
                Text('Clear All', style: TextStyle(color: BmbColors.errorRed, fontSize: 13)),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SELECT MODE HEADER ───────────────────────────────────────────────
  Widget _buildSelectHeader() {
    final count = _selectedIndices.length;
    final allSelected = count == _filtered.length && count > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close, color: BmbColors.textPrimary), onPressed: _exitSelectMode),
          Text('$count selected', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
          const Spacer(),
          // Select All
          TextButton.icon(
            onPressed: _selectAll,
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 18, color: BmbColors.blue),
            label: Text(allSelected ? 'Deselect' : 'Select All', style: TextStyle(color: BmbColors.blue, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
          ),
          const SizedBox(width: 4),
          // Mark Read
          _selectActionButton(
            icon: Icons.done_all,
            label: 'Read',
            color: BmbColors.blue,
            onPressed: count > 0 ? _markSelectedRead : null,
          ),
          const SizedBox(width: 6),
          // Delete
          _selectActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: BmbColors.errorRed,
            onPressed: count > 0 ? _deleteSelected : null,
          ),
        ],
      ),
    );
  }

  Widget _selectActionButton({
    required IconData icon, required String label,
    required Color color, VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: BmbFontWeights.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: BmbColors.cardDark,
        disabledForegroundColor: BmbColors.textTertiary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Scores', 'Replies', 'Brackets', 'Picks', 'Chat', 'Other'];
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filters.map((f) {
          final sel = _filter == f;
          final isReplies = f == 'Replies';
          final isScores = f == 'Scores';
          final unread = isReplies ? _replyNotifService.unreadCount : 0;
          final scoreUnread = isScores ? _allItems.where((n) => n.category == 'scores' && n.isUnread).length : 0;
          return GestureDetector(
            onTap: () {
              setState(() {
                _filter = f;
                _selectedIndices.clear();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel
                    ? (isReplies ? BmbColors.gold : isScores ? const Color(0xFFFF6B35) : BmbColors.blue)
                    : BmbColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel
                    ? (isReplies ? BmbColors.gold : isScores ? const Color(0xFFFF6B35) : BmbColors.blue)
                    : BmbColors.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isScores) ...[
                    Icon(Icons.sports_score, size: 12, color: sel ? Colors.white : const Color(0xFFFF6B35)),
                    const SizedBox(width: 4),
                  ],
                  if (isReplies) ...[
                    Icon(Icons.reply, size: 12, color: sel ? Colors.black : BmbColors.gold),
                    const SizedBox(width: 4),
                  ],
                  Text(f, style: TextStyle(
                    color: sel ? (isReplies ? Colors.black : Colors.white) : BmbColors.textSecondary,
                    fontSize: 12, fontWeight: BmbFontWeights.medium,
                  )),
                  if (isReplies && unread > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: sel ? Colors.black.withValues(alpha: 0.2) : BmbColors.gold, borderRadius: BorderRadius.circular(8)),
                      child: Text('$unread', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: BmbFontWeights.bold)),
                    ),
                  ],
                  if (isScores && scoreUnread > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: sel ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(8)),
                      child: Text('$scoreUnread', style: TextStyle(color: sel ? Colors.white : Colors.white, fontSize: 9, fontWeight: BmbFontWeights.bold)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── NOTIFICATION TILE WITH SWIPE ─────────────────────────────────────
  Widget _buildNotifTile(_NotifItem n, int index) {
    final isReply = n.category == 'replies';
    final isScore = n.category == 'scores';
    final isSelected = _selectMode && _selectedIndices.contains(index);

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe left = delete
          _deleteSingle(n);
          return true;
        } else {
          // Swipe right = mark as read
          _markSingleRead(n);
          return false; // don't dismiss, just mark read
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Icon(Icons.done_all, color: BmbColors.blue, size: 20),
          const SizedBox(width: 8),
          Text('Mark Read', style: TextStyle(color: BmbColors.blue, fontSize: 12, fontWeight: BmbFontWeights.bold)),
        ]),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: BmbColors.errorRed.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Delete', style: TextStyle(color: BmbColors.errorRed, fontSize: 12, fontWeight: BmbFontWeights.bold)),
          const SizedBox(width: 8),
          Icon(Icons.delete_outline, color: BmbColors.errorRed, size: 20),
        ]),
      ),
      child: GestureDetector(
        onTap: _selectMode ? () => _toggleSelect(index) : () => _openNotification(n),
        onLongPress: _selectMode ? null : () => _enterSelectMode(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: [BmbColors.blue.withValues(alpha: 0.15), BmbColors.blue.withValues(alpha: 0.08)])
                : n.isUnread
                    ? isReply
                        ? LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.1), BmbColors.cardGradientEnd])
                        : isScore
                            ? LinearGradient(colors: [const Color(0xFFFF6B35).withValues(alpha: 0.08), BmbColors.cardGradientEnd])
                            : LinearGradient(colors: [BmbColors.blue.withValues(alpha: 0.08), BmbColors.cardGradientEnd])
                    : BmbColors.cardGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? BmbColors.blue.withValues(alpha: 0.6)
                  : n.isUnread
                      ? (isReply ? BmbColors.gold.withValues(alpha: 0.4) : isScore ? const Color(0xFFFF6B35).withValues(alpha: 0.3) : BmbColors.blue.withValues(alpha: 0.3))
                      : BmbColors.borderColor,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection checkbox OR icon
              if (_selectMode) ...[
                GestureDetector(
                  onTap: () => _toggleSelect(index),
                  child: Container(
                    width: 24, height: 24,
                    margin: const EdgeInsets.only(right: 10, top: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? BmbColors.blue : Colors.transparent,
                      border: Border.all(color: isSelected ? BmbColors.blue : BmbColors.textTertiary, width: 1.5),
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                  ),
                ),
              ],
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: n.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(n.icon, color: n.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(n.title, style: TextStyle(
                          color: BmbColors.textPrimary, fontSize: 14,
                          fontWeight: n.isUnread ? BmbFontWeights.bold : BmbFontWeights.semiBold,
                        ))),
                        if (n.isUnread && !_selectMode)
                          Container(width: 8, height: 8, decoration: BoxDecoration(
                            color: isReply ? BmbColors.gold : isScore ? const Color(0xFFFF6B35) : BmbColors.blue,
                            shape: BoxShape.circle,
                          )),
                      ],
                    ),
                    // Reply context
                    if (isReply && n.originalMessage != null) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BmbColors.borderColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(left: BorderSide(color: BmbColors.gold, width: 2)),
                        ),
                        child: Text('Your message: "${n.originalMessage}"', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(n.subtitle, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isScore) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFFFF6B35).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text('SCORE', style: TextStyle(color: const Color(0xFFFF6B35), fontSize: 8, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(n.time, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                        if (!_selectMode) ...[
                          const Spacer(),
                          Text(n.isUnread ? 'Swipe to manage' : '', style: TextStyle(color: BmbColors.textTertiary, fontSize: 9)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!_selectMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Icon(Icons.chevron_right, color: BmbColors.textTertiary.withValues(alpha: 0.5), size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SETTINGS ─────────────────────────────────────────────────────────
  void _showNotifSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Push Notification Settings', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                const SizedBox(height: 16),
                _notifToggle(Icons.sports_score, 'Score Alerts', 'Get notified when your favorite teams win, lose, or when key players get injured', _scoreAlerts, (v) {
                  setSheetState(() => _scoreAlerts = v);
                  setState(() => _scoreAlerts = v);
                }),
                _notifToggle(Icons.reply, 'Replies to Your Comments', 'Get notified when someone replies specifically to your message', _replyAlerts, (v) {
                  setSheetState(() => _replyAlerts = v);
                  setState(() => _replyAlerts = v);
                  _replyNotifService.setEnabled(v);
                }),
                _notifToggle(Icons.sports, 'New Brackets', 'Get alerts for new brackets matching your sport preferences', _bracketAlerts, (v) {
                  setSheetState(() => _bracketAlerts = v);
                  setState(() => _bracketAlerts = v);
                }),
                _notifToggle(Icons.scoreboard, 'Pick Results', 'Get notified when results are in for your picks', _pickResultAlerts, (v) {
                  setSheetState(() => _pickResultAlerts = v);
                  setState(() => _pickResultAlerts = v);
                }),
                _notifToggle(Icons.chat, 'Chat Messages', 'Alerts for new messages in bracket chats', _chatAlerts, (v) {
                  setSheetState(() => _chatAlerts = v);
                  setState(() => _chatAlerts = v);
                }),
                _notifToggle(Icons.campaign, 'Promotions', 'BMB offers and updates', _promoAlerts, (v) {
                  setSheetState(() => _promoAlerts = v);
                  setState(() => _promoAlerts = v);
                }),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: BmbColors.gold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Score alerts are based on your favorite teams & athletes. Add favorites in Settings > My Favorites.',
                          style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notifToggle(IconData icon, String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: BmbColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
                Text(desc, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeTrackColor: BmbColors.blue.withValues(alpha: 0.5), thumbColor: WidgetStatePropertyAll(value ? BmbColors.blue : BmbColors.textTertiary)),
        ],
      ),
    );
  }
}

// ─── NOTIFICATION DETAIL SHEET ──────────────────────────────────────────
class _NotificationDetailSheet extends StatelessWidget {
  final _NotifItem item;
  final VoidCallback onDelete;
  const _NotificationDetailSheet({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isReply = item.category == 'replies';
    final isScore = item.category == 'scores';
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: item.iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(item.icon, color: item.iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 17, fontWeight: BmbFontWeights.bold)),
                    const SizedBox(height: 2),
                    Text(item.time, style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isReply && item.originalMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BmbColors.borderColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: BmbColors.gold, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your original message:', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, fontWeight: BmbFontWeights.bold)),
                  const SizedBox(height: 4),
                  Text('"${item.originalMessage}"', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Reply:', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold)),
            const SizedBox(height: 4),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor)),
            child: Text(item.subtitle, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: item.iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(isScore ? 'SCORE ALERT' : item.category.toUpperCase(), style: TextStyle(color: item.iconColor, fontSize: 10, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
              ),
              const Spacer(),
              Icon(Icons.done_all, color: BmbColors.successGreen, size: 16),
              const SizedBox(width: 4),
              Text('Read', style: TextStyle(color: BmbColors.successGreen, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 16, color: BmbColors.errorRed),
                  label: Text('Delete', style: TextStyle(color: BmbColors.errorRed, fontWeight: BmbFontWeights.semiBold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: BmbColors.errorRed.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: BmbColors.borderColor),
                    foregroundColor: BmbColors.textSecondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Close', style: TextStyle(fontWeight: BmbFontWeights.semiBold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── NOTIF ITEM MODEL ───────────────────────────────────────────────────
class _NotifItem {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final String category;
  final String? originalMessage;

  _NotifItem({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.category,
    this.originalMessage,
  });

  _NotifItem copyWith({bool? isUnread}) {
    return _NotifItem(
      id: id,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      time: time,
      isUnread: isUnread ?? this.isUnread,
      category: category,
      originalMessage: originalMessage,
    );
  }
}
