import 'package:flutter/foundation.dart';

/// Centralised application configuration.
///
/// Compile-time values come from `--dart-define` flags.
/// Production defaults are baked in so release builds work without
/// explicit overrides.
///
/// Build examples:
///   # Development (localhost)
///   flutter run --dart-define=MERCH_SERVER_URL=http://localhost:3000
///
///   # Production (Render)
///   flutter build apk --release   # uses the default below
///
///   # Override for staging
///   flutter build web --release --dart-define=MERCH_SERVER_URL=https://backmybracket-mobile-version-2.onrender.com
class AppConfig {
  AppConfig._();

  // ── Merch Server ─────────────────────────────────────────────
  /// Base URL of the BMB Merch Server.
  ///
  /// Override at build time:
  ///   --dart-define=MERCH_SERVER_URL=https://backmybracket-mobile-version-2.onrender.com
  ///
  /// Default: production Render deployment.
  static const String merchServerBaseUrl = String.fromEnvironment(
    'MERCH_SERVER_URL',
    defaultValue: 'https://backmybracket-mobile-version-2.onrender.com',
  );

  // ── Shopify ──────────────────────────────────────────────────
  /// Shopify storefront base URL.
  static const String shopifyStoreUrl = String.fromEnvironment(
    'SHOPIFY_STORE_URL',
    defaultValue: 'https://backmybracket.com',
  );

  // ── Diagnostics ──────────────────────────────────────────────
  /// Print the resolved config at startup (debug builds only).
  static void logConfig() {
    if (kDebugMode) {
      debugPrint('[AppConfig] MERCH_SERVER_URL  = $merchServerBaseUrl');
      debugPrint('[AppConfig] SHOPIFY_STORE_URL = $shopifyStoreUrl');
    }
  }
}
