import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages one-time social account linking for quick future sharing.
/// Once a user links a social account, future "Post to Socials" actions
/// will automatically create the post without needing to re-link.
class SocialAccountsService {
  static const _prefsKey = 'linked_social_accounts';

  /// Supported social platforms
  static const List<SocialPlatform> allPlatforms = [
    SocialPlatform(
      id: 'twitter',
      name: 'X / Twitter',
      iconName: 'alternate_email',
      color: 0xFF000000,
      shareUrlBase: 'https://twitter.com/intent/tweet?text=',
    ),
    SocialPlatform(
      id: 'instagram',
      name: 'Instagram',
      iconName: 'camera_alt',
      color: 0xFFE1306C,
      shareUrlBase: 'https://www.instagram.com/',
    ),
    SocialPlatform(
      id: 'facebook',
      name: 'Facebook',
      iconName: 'public',
      color: 0xFF1877F2,
      shareUrlBase: 'https://www.facebook.com/sharer/sharer.php?quote=',
    ),
    SocialPlatform(
      id: 'snapchat',
      name: 'Snapchat',
      iconName: 'photo_camera_front',
      color: 0xFFFFFC00,
      shareUrlBase: 'https://www.snapchat.com/',
    ),
    SocialPlatform(
      id: 'tiktok',
      name: 'TikTok',
      iconName: 'music_note',
      color: 0xFF00F2EA,
      shareUrlBase: 'https://www.tiktok.com/',
    ),
  ];

  /// Get all linked social accounts
  static Future<Map<String, LinkedSocialAccount>> getLinkedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
        k,
        LinkedSocialAccount.fromJson(v as Map<String, dynamic>),
      ));
    } catch (_) {
      return {};
    }
  }

  /// Check if a platform is linked
  static Future<bool> isPlatformLinked(String platformId) async {
    final accounts = await getLinkedAccounts();
    return accounts.containsKey(platformId);
  }

  /// Link a social account (one-time setup)
  static Future<void> linkAccount({
    required String platformId,
    required String username,
    String? displayName,
  }) async {
    final accounts = await getLinkedAccounts();
    accounts[platformId] = LinkedSocialAccount(
      platformId: platformId,
      username: username,
      displayName: displayName ?? username,
      linkedAt: DateTime.now(),
      autoPostEnabled: true,
    );
    await _save(accounts);
  }

  /// Unlink a social account
  static Future<void> unlinkAccount(String platformId) async {
    final accounts = await getLinkedAccounts();
    accounts.remove(platformId);
    await _save(accounts);
  }

  /// Toggle auto-post for a platform
  static Future<void> toggleAutoPost(String platformId, bool enabled) async {
    final accounts = await getLinkedAccounts();
    final existing = accounts[platformId];
    if (existing != null) {
      accounts[platformId] = LinkedSocialAccount(
        platformId: existing.platformId,
        username: existing.username,
        displayName: existing.displayName,
        linkedAt: existing.linkedAt,
        autoPostEnabled: enabled,
      );
      await _save(accounts);
    }
  }

  /// Get all platforms with auto-post enabled
  static Future<List<String>> getAutoPostPlatforms() async {
    final accounts = await getLinkedAccounts();
    return accounts.entries
        .where((e) => e.value.autoPostEnabled)
        .map((e) => e.key)
        .toList();
  }

  static Future<void> _save(Map<String, LinkedSocialAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      accounts.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_prefsKey, raw);
  }
}

class SocialPlatform {
  final String id;
  final String name;
  final String iconName;
  final int color;
  final String shareUrlBase;

  const SocialPlatform({
    required this.id,
    required this.name,
    required this.iconName,
    required this.color,
    required this.shareUrlBase,
  });

  /// Returns a Material icon matching this platform.
  /// Uses constant IconData references to avoid tree-shake issues.
  static IconData getIcon(String platformId) {
    switch (platformId) {
      case 'twitter':
        return const IconData(0xe0ac, fontFamily: 'MaterialIcons'); // alternate_email
      case 'instagram':
        return const IconData(0xe3b0, fontFamily: 'MaterialIcons'); // camera_alt
      case 'facebook':
        return const IconData(0xe80b, fontFamily: 'MaterialIcons'); // public
      case 'snapchat':
        return const IconData(0xf0c7, fontFamily: 'MaterialIcons'); // photo_camera_front
      case 'tiktok':
        return const IconData(0xe415, fontFamily: 'MaterialIcons'); // music_note
      default:
        return const IconData(0xe894, fontFamily: 'MaterialIcons'); // share
    }
  }
}

class LinkedSocialAccount {
  final String platformId;
  final String username;
  final String displayName;
  final DateTime linkedAt;
  final bool autoPostEnabled;

  const LinkedSocialAccount({
    required this.platformId,
    required this.username,
    required this.displayName,
    required this.linkedAt,
    required this.autoPostEnabled,
  });

  Map<String, dynamic> toJson() => {
    'platformId': platformId,
    'username': username,
    'displayName': displayName,
    'linkedAt': linkedAt.toIso8601String(),
    'autoPostEnabled': autoPostEnabled,
  };

  factory LinkedSocialAccount.fromJson(Map<String, dynamic> json) {
    return LinkedSocialAccount(
      platformId: json['platformId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      linkedAt: DateTime.tryParse(json['linkedAt'] as String? ?? '') ?? DateTime.now(),
      autoPostEnabled: json['autoPostEnabled'] as bool? ?? true,
    );
  }
}
