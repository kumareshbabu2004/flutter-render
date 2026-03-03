import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/app/bmb_app.dart';
import 'package:bmb_mobile/core/config/app_config.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/features/companion/data/companion_service.dart';
import 'package:bmb_mobile/features/gift_cards/data/services/tremendous_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler: show styled error screen instead of blank white page
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Something went wrong',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(details.exceptionAsString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // No Firebase JS SDK initialization needed — using REST API directly.
  // This eliminates all iframe/sandbox/import() issues.
  if (kDebugMode) debugPrint('BMB: Using Firebase REST API (no JS SDK required)');

  // Init companion service early (non-critical)
  try {
    await CompanionService.instance.init()
        .timeout(const Duration(seconds: 3));
  } catch (e) {
    if (kDebugMode) debugPrint('main: CompanionService init failed/timed out: $e');
  }

  // Initialize Tremendous API (sandbox mode for development)
  try {
    await TremendousService.instance.initSandbox();
  } catch (e) {
    if (kDebugMode) debugPrint('main: Tremendous init failed: $e');
  }

  // Log resolved configuration (debug builds only)
  AppConfig.logConfig();

  runApp(const BmbApp());
}
