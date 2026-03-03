import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Manages the welcome notification ("Thank you for joining the BmB family!")
/// shown once after a new user completes signup.
///
/// This service:
///   - Queues a welcome notification on account creation
///   - Tracks whether the notification has been shown / dismissed
///   - Provides the notification content for display
///
/// In production: push notification is sent server-side via FCM / APNs.
/// This local service provides the in-app fallback and instant feedback.
class WelcomeNotificationService {
  WelcomeNotificationService._();
  static final WelcomeNotificationService instance =
      WelcomeNotificationService._();

  // ─── Keys ────────────────────────────────────────────────────────────
  static const _kWelcomeSent = 'bmb_welcome_notif_sent';
  static const _kWelcomeDismissed = 'bmb_welcome_notif_dismissed';
  static const _kWelcomeTimestamp = 'bmb_welcome_notif_ts';

  // ─── Notification content ────────────────────────────────────────────
  static const String welcomeTitle = 'Welcome to the BmB Family!';
  static const String welcomeBody =
      'Thank you for joining Back My Bracket! '
      'Start by exploring tournaments, building your first bracket, '
      'and connecting with the community. '
      'We\'re glad you\'re here!';
  static const String welcomeSubtitle =
      'Your journey to becoming a bracket champion starts now.';

  /// Called after successful signup. Queues the welcome notification.
  Future<void> queueWelcomeNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySent = prefs.getBool(_kWelcomeSent) ?? false;
    if (alreadySent) return;

    await prefs.setBool(_kWelcomeSent, true);
    await prefs.setString(
        _kWelcomeTimestamp, DateTime.now().toIso8601String());

    if (kDebugMode) {
      debugPrint('[WelcomeNotif] Welcome notification queued');
    }
  }

  /// Whether the welcome notification should be shown.
  /// True if: notification was queued AND has not been dismissed yet.
  Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final sent = prefs.getBool(_kWelcomeSent) ?? false;
    final dismissed = prefs.getBool(_kWelcomeDismissed) ?? false;
    return sent && !dismissed;
  }

  /// Mark the welcome notification as dismissed by the user.
  Future<void> dismissWelcomeNotification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcomeDismissed, true);
    if (kDebugMode) {
      debugPrint('[WelcomeNotif] Welcome notification dismissed');
    }
  }

  /// Get the timestamp when the welcome notification was sent.
  Future<DateTime?> getWelcomeTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kWelcomeTimestamp);
    return raw != null ? DateTime.tryParse(raw) : null;
  }
}
