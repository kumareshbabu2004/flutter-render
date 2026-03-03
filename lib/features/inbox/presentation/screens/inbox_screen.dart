import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/store/data/models/store_models.dart';
import 'package:bmb_mobile/features/store/data/services/store_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<InboxMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final msgs = await StoreService.instance.getInboxMessages();
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
  }

  Future<void> _markRead(InboxMessage msg) async {
    await StoreService.instance.markInboxRead(msg.id);
    _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
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
                    const SizedBox(width: 8),
                    Text('Inbox',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 20,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                    const Spacer(),
                    if (_messages.any((m) => !m.isRead))
                      TextButton(
                        onPressed: () async {
                          for (final m in _messages.where((m) => !m.isRead)) {
                            await StoreService.instance.markInboxRead(m.id);
                          }
                          _loadMessages();
                        },
                        child: Text('Mark all read',
                            style: TextStyle(
                                color: BmbColors.blue,
                                fontSize: 12,
                                fontWeight: BmbFontWeights.semiBold)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Info banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: BmbColors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: BmbColors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Digital gift card codes and order updates are delivered here.',
                            style: TextStyle(
                                color: BmbColors.blue, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox,
                                    color: BmbColors.textTertiary, size: 48),
                                const SizedBox(height: 12),
                                Text('Your inbox is empty',
                                    style: TextStyle(
                                        color: BmbColors.textTertiary,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                    'Gift card codes and order updates will appear here.',
                                    style: TextStyle(
                                        color: BmbColors.textTertiary,
                                        fontSize: 12),
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _messages.length,
                            itemBuilder: (ctx, i) =>
                                _buildMessageCard(_messages[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(InboxMessage msg) {
    final typeColor = _typeColor(msg.type);
    final typeIcon = _typeIcon(msg.type);
    return GestureDetector(
      onTap: () {
        if (!msg.isRead) _markRead(msg);
        _showMessageDetail(msg);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: msg.isRead
              ? BmbColors.cardGradient
              : LinearGradient(colors: [
                  typeColor.withValues(alpha: 0.08),
                  typeColor.withValues(alpha: 0.02),
                ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: msg.isRead
                ? BmbColors.borderColor
                : typeColor.withValues(alpha: 0.4),
            width: msg.isRead ? 0.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(typeIcon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(msg.title,
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 13,
                                fontWeight: msg.isRead
                                    ? BmbFontWeights.medium
                                    : BmbFontWeights.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (!msg.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: typeColor, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(msg.body,
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (msg.code != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BmbColors.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.vpn_key,
                              color: BmbColors.successGreen, size: 12),
                          const SizedBox(width: 4),
                          Text(msg.code!,
                              style: TextStyle(
                                  color: BmbColors.successGreen,
                                  fontSize: 10,
                                  fontWeight: BmbFontWeights.bold,
                                  letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(_formatTime(msg.createdAt),
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageDetail(InboxMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Icon(_typeIcon(msg.type),
                color: _typeColor(msg.type), size: 40),
            const SizedBox(height: 14),
            Text(msg.title,
                style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 18,
                    fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay'),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(msg.body,
                style: TextStyle(
                    color: BmbColors.textSecondary,
                    fontSize: 13,
                    height: 1.5),
                textAlign: TextAlign.center),
            if (msg.code != null) ...[
              const SizedBox(height: 16),
              Text('Your Code',
                  style: TextStyle(
                      color: BmbColors.textTertiary,
                      fontSize: 11,
                      fontWeight: BmbFontWeights.semiBold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: BmbColors.successGreen.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text(msg.code!,
                        style: TextStyle(
                            color: BmbColors.successGreen,
                            fontSize: 20,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay',
                            letterSpacing: 2),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: msg.code!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Code copied to clipboard!'),
                              backgroundColor: BmbColors.successGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BmbColors.successGreen,
                          side: BorderSide(
                              color: BmbColors.successGreen
                                  .withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Code'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(_formatTime(msg.createdAt),
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 11)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.buttonPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'gift_card':
        return BmbColors.successGreen;
      case 'order_update':
        return BmbColors.blue;
      case 'promo':
        return BmbColors.gold;
      default:
        return BmbColors.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'gift_card':
        return Icons.card_giftcard;
      case 'order_update':
        return Icons.local_shipping;
      case 'promo':
        return Icons.campaign;
      default:
        return Icons.mail;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
