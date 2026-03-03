import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages notifications specifically for when someone replies to YOUR comment.
/// Only YOUR replies trigger a notification — no spam from general chat.
///
/// Stored in SharedPreferences so notifications persist across sessions.
class ReplyNotificationService {
  static final ReplyNotificationService _instance = ReplyNotificationService._internal();
  factory ReplyNotificationService() => _instance;
  ReplyNotificationService._internal();

  static const _storageKey = 'bmb_reply_notifications';
  static const _unreadCountKey = 'bmb_reply_unread_count';
  static const _enabledKey = 'bmb_reply_notifs_enabled';

  final List<ReplyNotification> _notifications = [];
  int _unreadCount = 0;
  bool _enabled = true;
  bool _initialized = false;

  List<ReplyNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get enabled => _enabled;

  /// Initialize — load persisted notifications from SharedPreferences
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    _unreadCount = prefs.getInt(_unreadCountKey) ?? 0;

    final stored = prefs.getStringList(_storageKey) ?? [];
    _notifications.clear();
    for (final json in stored) {
      try {
        _notifications.add(ReplyNotification.fromJson(jsonDecode(json)));
      } catch (_) {}
    }
    _initialized = true;
  }

  /// Add a reply notification — only call when someone replies to the current user's message
  Future<void> addReplyNotification({
    required String replierId,
    required String replierName,
    required String replierState,
    required String originalMessage,
    required String replyMessage,
  }) async {
    if (!_enabled) return;

    final notif = ReplyNotification(
      id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
      replierId: replierId,
      replierName: replierName,
      replierState: replierState,
      originalMessage: originalMessage,
      replyMessage: replyMessage,
      timestamp: DateTime.now(),
      isRead: false,
    );

    _notifications.insert(0, notif); // newest first
    _unreadCount++;

    // Keep only last 50 reply notifications
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }

    await _persist();
  }

  /// Mark all reply notifications as read
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _unreadCount = 0;
    await _persist();
  }

  /// Toggle reply notifications on/off
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  /// Clear all reply notifications
  Future<void> clearAll() async {
    _notifications.clear();
    _unreadCount = 0;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _notifications.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
    await prefs.setInt(_unreadCountKey, _unreadCount);
  }
}

class ReplyNotification {
  final String id;
  final String replierId;
  final String replierName;
  final String replierState;
  final String originalMessage;
  final String replyMessage;
  final DateTime timestamp;
  final bool isRead;

  const ReplyNotification({
    required this.id,
    required this.replierId,
    required this.replierName,
    required this.replierState,
    required this.originalMessage,
    required this.replyMessage,
    required this.timestamp,
    this.isRead = false,
  });

  ReplyNotification copyWith({bool? isRead}) {
    return ReplyNotification(
      id: id,
      replierId: replierId,
      replierName: replierName,
      replierState: replierState,
      originalMessage: originalMessage,
      replyMessage: replyMessage,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'replierId': replierId,
    'replierName': replierName,
    'replierState': replierState,
    'originalMessage': originalMessage,
    'replyMessage': replyMessage,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory ReplyNotification.fromJson(Map<String, dynamic> json) {
    return ReplyNotification(
      id: json['id'] ?? '',
      replierId: json['replierId'] ?? '',
      replierName: json['replierName'] ?? '',
      replierState: json['replierState'] ?? '',
      originalMessage: json['originalMessage'] ?? '',
      replyMessage: json['replyMessage'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }
}
