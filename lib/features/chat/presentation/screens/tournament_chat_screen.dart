import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/chat/data/models/chat_message.dart';
import 'package:bmb_mobile/features/chat/data/services/profanity_filter.dart';
import 'package:bmb_mobile/features/chat/data/services/chat_access_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

class TournamentChatScreen extends StatefulWidget {
  final String bracketId;
  final String bracketTitle;
  final String hostName;
  final int participantCount;

  const TournamentChatScreen({
    super.key,
    required this.bracketId,
    required this.bracketTitle,
    required this.hostName,
    this.participantCount = 0,
  });

  @override
  State<TournamentChatScreen> createState() => _TournamentChatScreenState();
}

class _TournamentChatScreenState extends State<TournamentChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _showParticipants = false;
  bool _isLoading = true;
  Timer? _pollTimer;
  final _firestore = RestFirestoreService.instance;

  // Participants loaded from Firestore
  final List<_ChatParticipant> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadParticipants();
    // Poll for new messages every 5 seconds (REST doesn't support streams)
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollNewMessages());
  }

  /// Load chat messages from Firestore for this bracket.
  Future<void> _loadMessages() async {
    try {
      final docs = await _firestore.query(
        'chat_messages',
        whereField: 'bracketId',
        whereValue: widget.bracketId,
      );

      final loaded = docs.map((d) => ChatMessage(
        id: d['doc_id'] as String? ?? '',
        bracketId: d['bracketId'] as String? ?? widget.bracketId,
        senderId: d['senderId'] as String? ?? '',
        senderName: d['senderName'] as String? ?? 'Unknown',
        senderLocation: d['senderLocation'] as String?,
        message: d['message'] as String? ?? '',
        timestamp: DateTime.tryParse(d['timestamp'] as String? ?? '') ?? DateTime.now(),
        isSystem: d['isSystem'] == true,
        isFlagged: d['isFlagged'] == true,
        flagReason: d['flagReason'] as String?,
      )).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        setState(() {
          _messages.clear();
          // Always add welcome system message at top if no system msg exists
          if (loaded.isEmpty || !loaded.any((m) => m.isSystem)) {
            _messages.add(ChatMessage(
              id: 'system_welcome',
              bracketId: widget.bracketId,
              senderId: 'system',
              senderName: 'System',
              message: 'Welcome to the ${widget.bracketTitle} chat room! Be respectful and have fun. Harassment and vulgar language will be flagged and may result in removal.',
              timestamp: DateTime.now().subtract(const Duration(hours: 24)),
              isSystem: true,
            ));
          }
          _messages.addAll(loaded);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Chat: Error loading messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Poll for new messages since last known message.
  Future<void> _pollNewMessages() async {
    if (!mounted) return;
    try {
      final docs = await _firestore.query(
        'chat_messages',
        whereField: 'bracketId',
        whereValue: widget.bracketId,
      );
      final existingIds = _messages.map((m) => m.id).toSet();
      final newMsgs = docs
          .where((d) => !existingIds.contains(d['doc_id'] as String? ?? ''))
          .map((d) => ChatMessage(
                id: d['doc_id'] as String? ?? '',
                bracketId: d['bracketId'] as String? ?? widget.bracketId,
                senderId: d['senderId'] as String? ?? '',
                senderName: d['senderName'] as String? ?? 'Unknown',
                senderLocation: d['senderLocation'] as String?,
                message: d['message'] as String? ?? '',
                timestamp: DateTime.tryParse(d['timestamp'] as String? ?? '') ?? DateTime.now(),
                isSystem: d['isSystem'] == true,
                isFlagged: d['isFlagged'] == true,
                flagReason: d['flagReason'] as String?,
              ))
          .toList();

      if (newMsgs.isNotEmpty && mounted) {
        setState(() {
          _messages.addAll(newMsgs);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Chat: Poll error: $e');
    }
  }

  /// Load participant list from Firestore.
  Future<void> _loadParticipants() async {
    try {
      final docs = await _firestore.query(
        'bracket_participants',
        whereField: 'bracketId',
        whereValue: widget.bracketId,
      );
      if (mounted) {
        setState(() {
          _participants.clear();
          final cu = CurrentUserService.instance;
          // Always add current user
          _participants.add(_ChatParticipant(cu.displayName.isNotEmpty ? cu.displayName : 'You', cu.stateAbbr.isNotEmpty ? cu.stateAbbr : null, true));
          for (final d in docs) {
            final name = d['userName'] as String? ?? 'Player';
            final state = d['userState'] as String?;
            final uid = d['userId'] as String? ?? '';
            if (!cu.isCurrentUser(uid)) {
              _participants.add(_ChatParticipant(name, state, false));
            }
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Chat: Error loading participants: $e');
      // Fallback: show current user only
      if (mounted) {
        final cu = CurrentUserService.instance;
        setState(() {
          _participants.clear();
          _participants.add(_ChatParticipant(cu.displayName.isNotEmpty ? cu.displayName : 'You', cu.stateAbbr.isNotEmpty ? cu.stateAbbr : null, true));
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Run comprehensive content moderation filter
    final result = ProfanityFilter.check(text);

    if (result.isBlocked) {
      _showFilterAlert(
        result.reason ?? 'Inappropriate content detected.',
        result.categoryLabel,
      );
      // Record violation for enforcement escalation
      ChatAccessService.recordViolation().then((action) {
        if (mounted) _handleViolationAction(action);
      });
      return;
    }

    final msg = ChatMessage(
      id: 'm${_messages.length}',
      bracketId: widget.bracketId,
      senderId: CurrentUserService.instance.userId,
      senderName: CurrentUserService.instance.displayName.isNotEmpty ? CurrentUserService.instance.displayName : 'BracketKing',
      senderLocation: CurrentUserService.instance.stateAbbr.isNotEmpty ? CurrentUserService.instance.stateAbbr : 'TX',
      message: result.isFlagged ? ProfanityFilter.censor(text) : text,
      timestamp: DateTime.now(),
      isFlagged: result.isFlagged,
      flagReason: result.reason,
    );

    setState(() {
      _messages.add(msg);
      _messageController.clear();
    });

    // Persist to Firestore
    _firestore.addDocument('chat_messages', {
      'bracketId': widget.bracketId,
      'senderId': msg.senderId,
      'senderName': msg.senderName,
      'senderLocation': msg.senderLocation ?? '',
      'message': msg.message,
      'timestamp': msg.timestamp.toUtc().toIso8601String(),
      'isSystem': false,
      'isFlagged': msg.isFlagged,
      'flagReason': msg.flagReason ?? '',
    });

    _scrollToBottom();

    if (result.isFlagged) {
      _showFlaggedNotice(result.reason ?? 'Message flagged for review.');
    }
  }

  void _handleViolationAction(String action) {
    String title;
    String message;
    Color color;

    switch (action) {
      case 'WARNING':
        title = 'Warning';
        message = 'This is your first violation. Continued violations will result in chat suspension.';
        color = BmbColors.gold;
        break;
      case 'SUSPENDED_24_HOURS':
        title = 'Chat Suspended';
        message = 'Your chat access has been suspended for 24 hours due to repeated violations.';
        color = BmbColors.errorRed;
        break;
      case 'SUSPENDED_7_DAYS':
        title = 'Chat Suspended';
        message = 'Your chat access has been suspended for 7 days due to continued violations.';
        color = BmbColors.errorRed;
        break;
      case 'SUSPENDED_30_DAYS':
        title = 'Chat Suspended';
        message = 'Your chat access has been suspended for 30 days. One more violation will result in a permanent ban.';
        color = BmbColors.errorRed;
        break;
      case 'BANNED':
        title = 'Account Banned';
        message = 'Your account has been permanently banned from all BMB chat rooms. Contact appeals@backmybracket.com to appeal.';
        color = BmbColors.errorRed;
        break;
      default:
        return;
    }

    if (action != 'WARNING') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: BmbColors.midNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.gavel, color: color, size: 24),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold)),
            ],
          ),
          content: Text(message,
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 14, height: 1.5)),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (action == 'BANNED' || action.startsWith('SUSPENDED')) {
                  Navigator.pop(context); // Exit chat screen
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
    }
  }

  void _showFilterAlert(String reason, [String? category]) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: BmbColors.errorRed, size: 28),
            const SizedBox(width: 10),
            Text('Message Blocked',
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Category: $category',
                    style: TextStyle(color: BmbColors.gold, fontSize: 11,
                        fontWeight: BmbFontWeights.semiBold)),
              ),
            Text(reason,
                style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BmbColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: BmbColors.errorRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: BmbColors.errorRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Violations are tracked. Repeated offenses will result in escalating penalties: warning, 24-hour suspension, 7-day suspension, 30-day suspension, and permanent ban.',
                      style: TextStyle(
                          color: BmbColors.errorRed, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Understood',
                style: TextStyle(
                    color: BmbColors.blue,
                    fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  void _showFlaggedNotice(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.flag, color: BmbColors.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your message was sent but flagged for moderator review: $reason',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: BmbColors.cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _reportMessage(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Report Message',
            style: TextStyle(
                color: BmbColors.textPrimary,
                fontWeight: BmbFontWeights.bold)),
        content: Text(
            'Report this message from ${msg.senderName} for inappropriate content?',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: BmbColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                      'Message reported. Our moderators will review it.'),
                  backgroundColor: BmbColors.midNavy,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Report',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildChatHeader(),
              if (_showParticipants) _buildParticipantsList(),
              Expanded(child: _buildMessageList()),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BmbColors.midNavy,
        border: Border(
          bottom:
              BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back,
                color: BmbColors.textPrimary, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          // Chat room icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.chat_bubble, color: BmbColors.blue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.bracketTitle,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.semiBold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text('Hosted by ${widget.hostName}',
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 11)),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: BmbColors.successGreen,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('${widget.participantCount} online',
                        style: TextStyle(
                            color: BmbColors.successGreen, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          // Participants toggle
          IconButton(
            onPressed: () =>
                setState(() => _showParticipants = !_showParticipants),
            icon: Icon(Icons.people,
                color: _showParticipants
                    ? BmbColors.blue
                    : BmbColors.textSecondary,
                size: 22),
          ),
          // Rules / Info
          IconButton(
            onPressed: _showChatRules,
            icon: const Icon(Icons.shield_outlined,
                color: BmbColors.textSecondary, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: BmbColors.cardDark.withValues(alpha: 0.5),
        border: Border(
          bottom:
              BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.3)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          final p = _participants[index];
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: p.isCurrentUser
                  ? BmbColors.blue.withValues(alpha: 0.2)
                  : BmbColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: p.isCurrentUser
                    ? BmbColors.blue.withValues(alpha: 0.4)
                    : BmbColors.borderColor,
              ),
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
                const SizedBox(width: 6),
                Text(p.name,
                    style: TextStyle(
                        color: BmbColors.textPrimary, fontSize: 12)),
                if (p.state != null) ...[
                  const SizedBox(width: 4),
                  Text('(${p.state})',
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 10)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: BmbColors.blue));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text('No messages yet. Start the conversation!',
            style: TextStyle(color: BmbColors.textTertiary, fontSize: 14)),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        if (msg.isSystem) return _buildSystemMessage(msg);
        final isMe = CurrentUserService.instance.isCurrentUser(msg.senderId);
        return _buildChatBubble(msg, isMe);
      },
    );
  }

  Widget _buildSystemMessage(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: BmbColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              color: BmbColors.blue, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg.message,
                style: TextStyle(
                    color: BmbColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg, bool isMe) {
    return GestureDetector(
      onLongPress: isMe ? null : () => _reportMessage(msg),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              // Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    BmbColors.blue.withValues(alpha: 0.3),
                    BmbColors.blue.withValues(alpha: 0.1),
                  ]),
                ),
                child: Center(
                  child: Text(
                    msg.senderName[0].toUpperCase(),
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender info
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(msg.senderName,
                              style: TextStyle(
                                  color: BmbColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: BmbFontWeights.semiBold)),
                          if (msg.senderLocation != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color:
                                    BmbColors.textTertiary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(msg.senderLocation!,
                                  style: TextStyle(
                                      color: BmbColors.textTertiary,
                                      fontSize: 9)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  // Message bubble
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? BmbColors.blue
                          : BmbColors.cardDark,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft:
                            Radius.circular(isMe ? 14 : 4),
                        bottomRight:
                            Radius.circular(isMe ? 4 : 14),
                      ),
                      border: msg.isFlagged
                          ? Border.all(
                              color:
                                  BmbColors.gold.withValues(alpha: 0.5),
                              width: 1)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg.message,
                            style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : BmbColors.textPrimary,
                                fontSize: 14)),
                        if (msg.isFlagged)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag,
                                    color: BmbColors.gold.withValues(alpha: 0.7),
                                    size: 12),
                                const SizedBox(width: 4),
                                Text('Under review',
                                    style: TextStyle(
                                        color: BmbColors.gold
                                            .withValues(alpha: 0.7),
                                        fontSize: 9)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Timestamp
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_formatTime(msg.timestamp),
                        style: TextStyle(
                            color: BmbColors.textTertiary, fontSize: 10)),
                  ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: BmbColors.midNavy,
        border: Border(
          top:
              BorderSide(color: BmbColors.borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: BmbColors.cardDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BmbColors.borderColor),
              ),
              child: TextField(
                controller: _messageController,
                style:
                    TextStyle(color: BmbColors.textPrimary, fontSize: 14),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [BmbColors.blue, const Color(0xFF5B6EFF)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatRules() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: BmbColors.borderColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: BmbColors.blue, size: 24),
                  const SizedBox(width: 10),
                  Text('Chat Room Rules',
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 18,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay')),
                ],
              ),
              const SizedBox(height: 16),
              _buildRule(Icons.check_circle, BmbColors.successGreen,
                  'Keep it fun! Trash talk and friendly banter are encouraged.'),
              _buildRule(Icons.check_circle, BmbColors.successGreen,
                  'Discuss picks, predictions, and bracket strategy.'),
              _buildRule(Icons.lock, BmbColors.blue,
                  'This is a private chat room for tournament participants only.'),
              _buildRule(Icons.cancel, BmbColors.errorRed,
                  'No harassment, threats, bullying, or personal attacks.'),
              _buildRule(Icons.cancel, BmbColors.errorRed,
                  'No vulgar language (f*ck, sh*t, b*tch, etc.) or slurs.'),
              _buildRule(Icons.cancel, BmbColors.errorRed,
                  'No discrimination based on race, gender, religion, or identity.'),
              _buildRule(Icons.cancel, BmbColors.errorRed,
                  'No political discussion of any kind.'),
              _buildRule(Icons.cancel, BmbColors.errorRed,
                  'No spam, excessive caps, or disruptive behavior.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: BmbColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: BmbColors.gold, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Messages are automatically screened. Violations may result in chat suspension.',
                        style: TextStyle(
                            color: BmbColors.gold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRule(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: BmbColors.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day}';
  }
}

class _ChatParticipant {
  final String name;
  final String? state;
  final bool isCurrentUser;
  const _ChatParticipant(this.name, this.state, this.isCurrentUser);
}
