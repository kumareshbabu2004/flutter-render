import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// Push Notification Service — manages FCM token registration and
/// notification preferences. Uses Firestore to persist tokens for
/// server-side push delivery.
///
/// Web platform: uses Notification API + Web Push.
/// Mobile platform: uses Firebase Cloud Messaging (FCM).
///
/// Production flow:
///   1. App registers for notifications → gets FCM token
///   2. Token stored in Firestore under users/{userId}/fcmToken
///   3. Backend sends push via FCM Admin SDK when events occur
///   4. App receives notification → routes to relevant screen
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _prefsTokenKey = 'bmb_fcm_token';
  static const _prefsEnabledKey = 'bmb_push_enabled';
  static const _prefsTopicsKey = 'bmb_push_topics';

  final _firestore = RestFirestoreService.instance;
  String? _currentToken;
  bool _initialized = false;

  /// Whether push notifications are enabled.
  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? true;
  }

  /// Initialize the push notification service.
  /// On mobile: would call FirebaseMessaging.instance.getToken().
  /// On web: requests Notification permission and registers service worker.
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentToken = prefs.getString(_prefsTokenKey);

      if (kIsWeb) {
        // Web: request Notification permission
        // In production: Notification.requestPermission() then
        // firebase.messaging().getToken(vapidKey: '...')
        if (kDebugMode) {
          debugPrint('[PushNotification] Web platform — notification API ready');
        }
      } else {
        // Mobile: would use FirebaseMessaging to get token
        // final token = await FirebaseMessaging.instance.getToken();
        if (kDebugMode) {
          debugPrint('[PushNotification] Mobile platform — FCM ready');
        }
      }

      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[PushNotification] Init error: $e');
    }
  }

  /// Register the FCM token with the backend (Firestore).
  /// Called after login and whenever the token refreshes.
  Future<void> registerToken(String token) async {
    _currentToken = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTokenKey, token);

    final userId = CurrentUserService.instance.userId;
    if (userId.isEmpty) return;

    try {
      await _firestore.updateDocument('users', userId, {
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toUtc().toIso8601String(),
        'platform': kIsWeb ? 'web' : 'android',
      });
      if (kDebugMode) {
        debugPrint('[PushNotification] Token registered for user $userId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PushNotification] Token register error: $e');
    }
  }

  /// Unregister the FCM token (e.g., on logout).
  Future<void> unregisterToken() async {
    final userId = CurrentUserService.instance.userId;
    if (userId.isEmpty) return;

    try {
      await _firestore.updateDocument('users', userId, {
        'fcmToken': '',
        'fcmTokenUpdatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[PushNotification] Token unregister error: $e');
    }

    _currentToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTokenKey);
  }

  /// Enable or disable push notifications.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, enabled);

    if (!enabled) {
      await unregisterToken();
    }
  }

  /// Subscribe to a notification topic (e.g., 'bracket_updates', 'new_brackets').
  Future<void> subscribeTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final topics = prefs.getStringList(_prefsTopicsKey) ?? [];
    if (!topics.contains(topic)) {
      topics.add(topic);
      await prefs.setStringList(_prefsTopicsKey, topics);
    }

    // In production: await FirebaseMessaging.instance.subscribeToTopic(topic);
    if (kDebugMode) {
      debugPrint('[PushNotification] Subscribed to topic: $topic');
    }
  }

  /// Unsubscribe from a notification topic.
  Future<void> unsubscribeTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final topics = prefs.getStringList(_prefsTopicsKey) ?? [];
    topics.remove(topic);
    await prefs.setStringList(_prefsTopicsKey, topics);

    // In production: await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      debugPrint('[PushNotification] Unsubscribed from topic: $topic');
    }
  }

  /// Get list of subscribed topics.
  Future<List<String>> getSubscribedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsTopicsKey) ?? [];
  }

  /// Handle an incoming notification payload.
  /// Routes to the appropriate screen based on notification data.
  void handleNotification(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final targetId = data['targetId'] as String? ?? '';

    if (kDebugMode) {
      debugPrint('[PushNotification] Received: type=$type, targetId=$targetId');
    }

    // Navigation would be handled by the caller (typically main.dart)
    // based on the type/targetId. Common types:
    // - 'bracket_invite': navigate to join bracket screen
    // - 'bracket_update': navigate to bracket detail
    // - 'chat_message': navigate to chat screen
    // - 'credit_received': navigate to credits screen
    // - 'referral_activated': navigate to referral screen
  }

  /// Get the current FCM token (if registered).
  String? get currentToken => _currentToken;
}
