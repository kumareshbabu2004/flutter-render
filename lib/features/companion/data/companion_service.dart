import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/companion/data/companion_model.dart';

/// Persists and retrieves companion-related settings.
class CompanionService {
  static const _keyCompanionId = 'bmb_companion_id';
  static const _keyHasSeenTutorial = 'bmb_has_seen_tutorial';
  static const _keyVoiceEnabled = 'bmb_companion_voice_enabled';
  static const _keyCompanionVisible = 'bmb_companion_visible';

  // ─── Singleton ───────────────────────────────────────────
  CompanionService._();
  static final CompanionService instance = CompanionService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ─── Companion selection ─────────────────────────────────
  /// Returns the chosen persona, or null if user hasn't picked yet.
  CompanionPersona? get selectedCompanion {
    final id = _prefs?.getString(_keyCompanionId);
    if (id == null) return null;
    try {
      return CompanionPersona.all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> selectCompanion(CompanionPersona persona) async {
    await _prefs?.setString(_keyCompanionId, persona.id);
  }

  bool get hasChosenCompanion => _prefs?.getString(_keyCompanionId) != null;

  // ─── Tutorial state ──────────────────────────────────────
  bool get hasSeenTutorial => _prefs?.getBool(_keyHasSeenTutorial) ?? false;

  Future<void> markTutorialSeen() async {
    await _prefs?.setBool(_keyHasSeenTutorial, true);
  }

  Future<void> resetTutorial() async {
    await _prefs?.setBool(_keyHasSeenTutorial, false);
  }

  /// Whether this is a first-time user (no companion chosen yet).
  bool get isFirstTimer => !hasChosenCompanion;

  // ─── Voice toggle ────────────────────────────────────────
  bool get voiceEnabled => _prefs?.getBool(_keyVoiceEnabled) ?? true;

  Future<void> setVoiceEnabled(bool enabled) async {
    await _prefs?.setBool(_keyVoiceEnabled, enabled);
  }

  // ─── Companion visibility toggle ─────────────────────────
  bool get companionVisible => _prefs?.getBool(_keyCompanionVisible) ?? true;

  Future<void> setCompanionVisible(bool visible) async {
    await _prefs?.setBool(_keyCompanionVisible, visible);
  }

  // ─── Full reset (for testing) ────────────────────────────
  Future<void> resetAll() async {
    await _prefs?.remove(_keyCompanionId);
    await _prefs?.remove(_keyHasSeenTutorial);
    await _prefs?.remove(_keyVoiceEnabled);
    await _prefs?.remove(_keyCompanionVisible);
  }
}
