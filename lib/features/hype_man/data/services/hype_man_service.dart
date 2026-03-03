import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/features/hype_man/data/services/web_tts_engine_stub.dart'
    if (dart.library.js_interop) 'package:bmb_mobile/features/hype_man/data/services/web_tts_engine.dart';
import 'package:bmb_mobile/core/services/fun_facts_service.dart';

/// Every user action that can trigger the Hype Man.
enum HypeTrigger {
  madePick,
  completedAllPicks,
  changedPick,
  boldPick,
  createdBracket,
  createdSquares,
  createdPickem,
  createdTrivia,
  createdSurvivor,
  createdVote,
  bracketWentLive,
  joinedTournament,
  joinedSquares,
  joinedPickem,
  sharedBracket,
  invitedFriend,
  leftComment,
  ratedHost,
  correctPick,
  pickStreak,
  wonBracket,
  topThreeFinish,
  newHighScore,
  appOpened,
  returnedAfterBreak,
  browsingBoard,
  viewedLeaderboard,
  earnedCredits,
  firstPlayerJoined,
  bracketFillingUp,
  bracketFull,
  /// Fires after a user completes a bracket (all picks submitted).
  /// Prompts them to share to socials and the BMB community.
  bracketCompleted,
  /// Contextual fun-fact nugget delivered during picks (Option C).
  funFactNugget,
}

/// Hype intensity level.
enum HypeLevel { chill, normal, hypeMode }

/// The three natural voice characters.
enum HypeVoice {
  mark,   // Male — warm best-friend hype guy
  eve,    // Female — excited best-friend energy
  chris,  // Black male — smooth confident hype
}

/// Contextual guidance tips the Hype Man can give.
enum GuidanceTip {
  shareOnSocials,
  exploreTab,
  createButton,
  inviteFriends,
  myBracketsTab,
  profileSettings,
  swipeForMore,
  joinBracket,
  stuckOnScreen,
  checkLeaderboard,
  goLive,
  pullToRefresh,
  /// Post-completion: nudge user to share on socials & BMB community.
  postCompletionShare,
}

/// A single hype line — text + per-voice audio URLs.
class HypeLine {
  final String text;
  final String? markUrl;
  final String? eveUrl;
  final String? chrisUrl;
  const HypeLine(this.text, {this.markUrl, this.eveUrl, this.chrisUrl});

  String? urlFor(HypeVoice voice) => switch (voice) {
    HypeVoice.mark => markUrl,
    HypeVoice.eve => eveUrl,
    HypeVoice.chris => chrisUrl,
  };
}

/// A guidance tip line.
class GuidanceLine {
  final String text;
  final String? highlightKey; // Key identifying which UI element to pulse
  final String markUrl;
  const GuidanceLine(this.text, {required this.markUrl, this.highlightKey});
}

/// The BMB Hype Man — plays pre-recorded professional voice clips.
///
/// Three voice options: Mark, Eve (female), Chris (Black male).
/// All use ElevenLabs natural TTS — no robotic voices.
/// Also includes a contextual guidance system for subtle navigation tips.
class HypeManService {
  HypeManService._();
  static final HypeManService instance = HypeManService._();

  final WebTtsEngine _engine = WebTtsEngine();
  final Random _rng = Random();

  // ─── STATE ─────────────────────────────────────────────────────
  bool _enabled = true;
  bool _guidanceEnabled = true;
  HypeLevel _hypeLevel = HypeLevel.normal;
  HypeVoice _voice = HypeVoice.mark;
  double _volume = 0.85;
  bool _initialized = false;
  bool _isSpeaking = false;
  DateTime? _lastSpoke;
  DateTime? _lastTip;
  int _consecutiveCorrect = 0;
  bool _userHasInteracted = false;
  final Set<GuidanceTip> _shownTips = {};
  final Map<String, DateTime> _screenEntryTimes = {};

  // ─── CALLBACKS ─────────────────────────────────────────────────
  void Function(String text)? onSpeechStart;
  VoidCallback? onSpeechEnd;
  /// Called when a fun-fact nugget should overlay on screen (Option C).
  /// The text is the fact, displayed as a toast/overlay during pick.
  void Function(String factText)? onFunFactOverlay;
  VoidCallback? onFunFactDismiss;
  /// Called when a guidance tip wants to highlight a UI element.
  /// The key identifies which button/area to pulse-glow.
  void Function(String highlightKey)? onHighlightElement;
  void Function()? onClearHighlight;

  static const Map<HypeLevel, int> _cooldowns = {
    HypeLevel.chill: 30,
    HypeLevel.normal: 12,
    HypeLevel.hypeMode: 4,
  };

  // ─── PUBLIC API ────────────────────────────────────────────────

  bool get enabled => _enabled;
  bool get guidanceEnabled => _guidanceEnabled;
  HypeLevel get hypeLevel => _hypeLevel;
  HypeVoice get voice => _voice;
  double get volume => _volume;
  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadPreferences();
    _engine.init();
  }

  void markUserInteraction() {
    _userHasInteracted = true;
  }

  /// Track when user enters a screen (for stuck-detection).
  void onScreenEnter(String screenName) {
    _screenEntryTimes[screenName] = DateTime.now();
    // Schedule a stuck check after 45 seconds
    if (_guidanceEnabled) {
      Future.delayed(const Duration(seconds: 45), () {
        _checkIfStuck(screenName);
      });
    }
  }

  void onScreenExit(String screenName) {
    _screenEntryTimes.remove(screenName);
  }

  Future<void> trigger(HypeTrigger event, {String? context}) async {
    if (!_enabled || !_initialized) return;
    if (_isSpeaking) return;
    if (!_userHasInteracted && event == HypeTrigger.appOpened) return;

    final cooldown = _cooldowns[_hypeLevel] ?? 12;
    if (_lastSpoke != null) {
      final elapsed = DateTime.now().difference(_lastSpoke!).inSeconds;
      if (elapsed < cooldown) return;
    }

    final chance = _triggerChance(event);
    if (_rng.nextDouble() > chance) return;

    if (event == HypeTrigger.correctPick) {
      _consecutiveCorrect++;
      if (_consecutiveCorrect >= 3) {
        await _speak(HypeTrigger.pickStreak, context: context);
        return;
      }
    } else if (event != HypeTrigger.pickStreak) {
      _consecutiveCorrect = 0;
    }

    await _speak(event, context: context);
  }

  /// Deliver a contextual fun-fact nugget for a pick (Option C).
  /// Called from the bracket picks screen when a user selects a team.
  /// Shows text overlay + speaks via HypeMan voice.
  Future<void> deliverFunFact({
    required String team,
    required String sport,
    String? opponent,
  }) async {
    if (!_enabled || !_initialized) return;
    if (_isSpeaking) return;

    // Get a contextual fact from FunFactsService
    final fact = opponent != null
        ? FunFactsService.instance.getMatchupFact(team, opponent, sport)
        : FunFactsService.instance.getFactForPick(team, sport);

    if (fact == null) return; // No fact this time (controlled randomness)

    _lastSpoke = DateTime.now();
    _isSpeaking = true;

    // Show the text overlay on screen
    onFunFactOverlay?.call(fact);
    onSpeechStart?.call(fact);

    // Use the funFactNugget trigger audio if available, else fall back
    final lines = _clipBank[HypeTrigger.funFactNugget];
    if (lines != null && lines.isNotEmpty) {
      final line = lines[_rng.nextInt(lines.length)];
      final audioUrl = line.urlFor(_voice);
      if (audioUrl != null) {
        _engine.playClip(
          audioUrl,
          volume: _volume,
          onEnd: () {
            _isSpeaking = false;
            onSpeechEnd?.call();
            // Dismiss overlay after a short delay
            Future.delayed(const Duration(seconds: 3), () {
              onFunFactDismiss?.call();
            });
          },
        );
        return;
      }
    }

    // No audio clip: just show text overlay for 5 seconds
    _isSpeaking = false;
    onSpeechEnd?.call();
    Future.delayed(const Duration(seconds: 5), () {
      onFunFactDismiss?.call();
    });
  }

  Future<void> speakDirect(HypeTrigger event, {String? context}) async {
    if (!_initialized) await init();
    _userHasInteracted = true;
    await _speak(event, context: context, bypassCooldown: true);
  }

  /// Trigger a contextual guidance tip.
  Future<void> showGuidance(GuidanceTip tip) async {
    if (!_guidanceEnabled || !_enabled || !_initialized) return;
    if (_isSpeaking) return;
    if (_shownTips.contains(tip)) return; // Don't repeat tips

    // Guidance tips have a longer cooldown — 90 seconds between tips
    if (_lastTip != null) {
      final elapsed = DateTime.now().difference(_lastTip!).inSeconds;
      if (elapsed < 90) return;
    }

    final line = _guidanceBank[tip];
    if (line == null) return;

    _shownTips.add(tip);
    _lastTip = DateTime.now();
    _lastSpoke = DateTime.now();
    _isSpeaking = true;

    onSpeechStart?.call(line.text);

    // Highlight the relevant UI element
    if (line.highlightKey != null) {
      onHighlightElement?.call(line.highlightKey!);
    }

    _engine.playClip(
      line.markUrl, // Tips use the active voice in future; Mark for now
      volume: _volume,
      onEnd: () {
        _isSpeaking = false;
        onSpeechEnd?.call();
        // Clear highlight after speech ends
        Future.delayed(const Duration(seconds: 2), () {
          onClearHighlight?.call();
        });
      },
    );
  }

  Future<void> stop() async {
    _engine.stop();
    _isSpeaking = false;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) await stop();
    await _savePreferences();
  }

  Future<void> setGuidanceEnabled(bool value) async {
    _guidanceEnabled = value;
    await _savePreferences();
  }

  Future<void> setHypeLevel(HypeLevel level) async {
    _hypeLevel = level;
    await _savePreferences();
  }

  Future<void> setVoice(HypeVoice v) async {
    _voice = v;
    await _savePreferences();
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _savePreferences();
  }

  /// Reset shown tips (e.g., if user wants to see them again).
  void resetGuidance() {
    _shownTips.clear();
    _lastTip = null;
  }

  // ─── PRIVATE: SPEAK ────────────────────────────────────────────

  Future<void> _speak(HypeTrigger event, {
    String? context,
    bool bypassCooldown = false,
  }) async {
    if (_isSpeaking && !bypassCooldown) return;
    if (_isSpeaking) await stop();

    final lines = _clipBank[event];
    if (lines == null || lines.isEmpty) return;

    final line = lines[_rng.nextInt(lines.length)];
    final audioUrl = line.urlFor(_voice);

    String displayText = line.text;
    if (context != null) {
      displayText = displayText
          .replaceAll('{ctx}', context)
          .replaceAll('{sport}', context);
    }

    _lastSpoke = DateTime.now();
    _isSpeaking = true;
    onSpeechStart?.call(displayText);

    if (audioUrl != null) {
      _engine.playClip(
        audioUrl,
        volume: _volume,
        onEnd: () {
          _isSpeaking = false;
          onSpeechEnd?.call();
        },
      );
    } else {
      // If no clip for this voice, try Mark's clip as fallback
      final fallbackUrl = line.markUrl;
      if (fallbackUrl != null) {
        _engine.playClip(
          fallbackUrl,
          volume: _volume,
          onEnd: () {
            _isSpeaking = false;
            onSpeechEnd?.call();
          },
        );
      } else {
        _isSpeaking = false;
        onSpeechEnd?.call();
      }
    }
  }

  void _checkIfStuck(String screenName) {
    if (!_guidanceEnabled || !_enabled) return;
    final entryTime = _screenEntryTimes[screenName];
    if (entryTime == null) return; // Already left

    final elapsed = DateTime.now().difference(entryTime).inSeconds;
    if (elapsed >= 40) {
      // User has been on this screen for 40+ seconds — offer help
      final tip = _screenToTip(screenName);
      if (tip != null) {
        showGuidance(tip);
      }
    }
  }

  GuidanceTip? _screenToTip(String screenName) {
    final lower = screenName.toLowerCase();
    if (lower.contains('home') || lower.contains('dashboard')) {
      return GuidanceTip.exploreTab;
    }
    if (lower.contains('explore') || lower.contains('browse')) {
      return GuidanceTip.joinBracket;
    }
    if (lower.contains('bracket') && lower.contains('detail')) {
      return GuidanceTip.shareOnSocials;
    }
    if (lower.contains('profile')) {
      return GuidanceTip.myBracketsTab;
    }
    return GuidanceTip.stuckOnScreen;
  }

  double _triggerChance(HypeTrigger event) {
    final base = switch (_hypeLevel) {
      HypeLevel.chill => 0.3,
      HypeLevel.normal => 0.6,
      HypeLevel.hypeMode => 0.9,
    };
    return switch (event) {
      HypeTrigger.wonBracket => 1.0,
      HypeTrigger.pickStreak => 1.0,
      HypeTrigger.completedAllPicks => 0.95,
      HypeTrigger.bracketWentLive => 0.95,
      HypeTrigger.appOpened => 0.8,
      HypeTrigger.createdBracket => 0.85,
      HypeTrigger.createdSquares => 0.85,
      HypeTrigger.joinedTournament => 0.75,
      HypeTrigger.newHighScore => 0.9,
      HypeTrigger.topThreeFinish => 0.9,
      HypeTrigger.bracketFull => 0.95,
      HypeTrigger.bracketCompleted => 1.0, // Always fire post-completion
      _ => base,
    };
  }

  // ─── PERSISTENCE ───────────────────────────────────────────────

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('hypeman_enabled') ?? true;
    _guidanceEnabled = prefs.getBool('hypeman_guidance') ?? true;
    _volume = prefs.getDouble('hypeman_volume') ?? 0.85;
    final levelIdx = prefs.getInt('hypeman_level') ?? 1;
    _hypeLevel = HypeLevel.values[levelIdx.clamp(0, 2)];
    final voiceIdx = prefs.getInt('hypeman_voice_v2') ?? 0;
    _voice = HypeVoice.values[voiceIdx.clamp(0, 2)];
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hypeman_enabled', _enabled);
    await prefs.setBool('hypeman_guidance', _guidanceEnabled);
    await prefs.setDouble('hypeman_volume', _volume);
    await prefs.setInt('hypeman_level', _hypeLevel.index);
    await prefs.setInt('hypeman_voice_v2', _voice.index);
  }

  // ═══════════════════════════════════════════════════════════════
  //  GUIDANCE TIP BANK — Pre-recorded with Mark voice (friendly tone)
  // ═══════════════════════════════════════════════════════════════

  // Audio clips are self-hosted in web/audio/{voice}/{id}.mp3
  // Use relative paths so the same-origin web server delivers them.
  // Paths: audio/mark/{id}.mp3, audio/eve/{id}.mp3, audio/chris/{id}.mp3

  static final Map<GuidanceTip, GuidanceLine> _guidanceBank = {
    GuidanceTip.shareOnSocials: GuidanceLine(
      'Hey, did you know you can share this on your socials? Just tap the share button!',
      markUrl: 'audio/mark/HykrXgfA.mp3',
      highlightKey: 'share_button',
    ),
    GuidanceTip.exploreTab: GuidanceLine(
      'Check out the Explore tab! There\'s tons of brackets waiting for you!',
      markUrl: 'audio/mark/X2OWFo9K.mp3',
      highlightKey: 'nav_explore',
    ),
    GuidanceTip.createButton: GuidanceLine(
      'Want to host your own bracket? Hit that Create button in the middle!',
      markUrl: 'audio/mark/p7ywKhVY.mp3',
      highlightKey: 'nav_create',
    ),
    GuidanceTip.inviteFriends: GuidanceLine(
      'Pro tip! Invite your friends to make the bracket even more fun!',
      markUrl: 'audio/mark/7Yq7y5EK.mp3',
      highlightKey: 'invite_button',
    ),
    GuidanceTip.myBracketsTab: GuidanceLine(
      'All your brackets live under the Brackets tab! You can track everything from there!',
      markUrl: 'audio/mark/CflJt0Ps.mp3',
      highlightKey: 'nav_brackets',
    ),
    GuidanceTip.profileSettings: GuidanceLine(
      'Head to your profile to customize your settings and check your stats!',
      markUrl: 'audio/mark/q3cCFjBP.mp3',
      highlightKey: 'nav_profile',
    ),
    GuidanceTip.swipeForMore: GuidanceLine(
      'Try swiping through to see more brackets! There\'s always something new!',
      markUrl: 'audio/mark/hQLMV5dT.mp3',
    ),
    GuidanceTip.joinBracket: GuidanceLine(
      'See a bracket you like? Just tap Join to get in on the action!',
      markUrl: 'audio/mark/GXquhZ0M.mp3',
      highlightKey: 'join_button',
    ),
    GuidanceTip.stuckOnScreen: GuidanceLine(
      'Looking for something? Use the navigation bar at the bottom to jump between sections!',
      markUrl: 'audio/mark/FGwxYSp6.mp3',
      highlightKey: 'nav_bar',
    ),
    GuidanceTip.checkLeaderboard: GuidanceLine(
      'Want to see how you stack up? Check the leaderboard inside any bracket!',
      markUrl: 'audio/mark/Ycxz6XQm.mp3',
      highlightKey: 'leaderboard_button',
    ),
    GuidanceTip.goLive: GuidanceLine(
      'Your bracket is ready! Hit Go Live to start the competition!',
      markUrl: 'audio/mark/U6pyYAQ7.mp3',
      highlightKey: 'go_live_button',
    ),
    GuidanceTip.pullToRefresh: GuidanceLine(
      'Pull down to refresh and see the latest brackets and scores!',
      markUrl: 'audio/mark/2qZeS7QP.mp3',
    ),
    GuidanceTip.postCompletionShare: GuidanceLine(
      'Hey, don\'t forget you can post to your socials and the BMB community!',
      markUrl: 'audio/mark/L8h6wAeh.mp3', // reuse share audio clip
      highlightKey: 'post_completion_share_buttons',
    ),
  };

  // ═══════════════════════════════════════════════════════════════
  //  AUDIO CLIP BANK — 3 voices: Mark, Eve, Chris
  //  All pre-recorded with ElevenLabs natural voice acting.
  // ═══════════════════════════════════════════════════════════════

  // Eve & Chris share representative clips across lines in each
  // category — the displayed TEXT is unique per line, but audio
  // rotates through the recorded pool for that category + voice.

  static final Map<HypeTrigger, List<HypeLine>> _clipBank = {
    // ─── PICKS ──────────────────────────────────────────────────
    // ─── PICKS (Diversified — no repetitive "great pick" spam) ──────
    HypeTrigger.madePick: [
      HypeLine('Interesting. Let\u2019s see how that plays out.',  markUrl: 'audio/mark/F1Qgjw6i.mp3', eveUrl: 'audio/eve/P3mt5Db9.mp3', chrisUrl: 'audio/chris/SAwhPQfY.mp3'),
      HypeLine('You\u2019re going there? Okay, I respect it.',   markUrl: 'audio/mark/OZKcTYRk.mp3', eveUrl: 'audio/eve/yVjiHNhz.mp3', chrisUrl: 'audio/chris/z8BEBxld.mp3'),
      HypeLine('Mmm, that\u2019s a calculated move right there.', markUrl: 'audio/mark/WJn7DA4C.mp3', eveUrl: 'audio/eve/ZHHYk781.mp3', chrisUrl: 'audio/chris/SAwhPQfY.mp3'),
      HypeLine('Locked. No turning back now.',                    markUrl: 'audio/mark/GnYvK8lt.mp3', eveUrl: 'audio/eve/wwaXJ94F.mp3', chrisUrl: 'audio/chris/z8BEBxld.mp3'),
      HypeLine('Ohhh, that\u2019s a spicy one!',                 markUrl: 'audio/mark/a60n6fZ2.mp3', eveUrl: 'audio/eve/TSRoFXN5.mp3', chrisUrl: 'audio/chris/m3m5VNXo.mp3'),
      HypeLine('I see you building something here.',              markUrl: 'audio/mark/egnygC27.mp3', eveUrl: 'audio/eve/Cjo4GR18.mp3', chrisUrl: 'audio/chris/SAwhPQfY.mp3'),
      HypeLine('The confidence is radiating. I feel it.',         markUrl: 'audio/mark/dHyqAzYp.mp3', eveUrl: 'audio/eve/lWlupuG3.mp3', chrisUrl: 'audio/chris/z8BEBxld.mp3'),
      HypeLine('Strategic. That\u2019s a chess move, not checkers.', markUrl: 'audio/mark/CGIuT6oS.mp3', eveUrl: 'audio/eve/YhiVgzyc.mp3', chrisUrl: 'audio/chris/m3m5VNXo.mp3'),
      HypeLine('That pick tells me you\u2019ve done your homework.', markUrl: 'audio/mark/WLHaweDn.mp3', eveUrl: 'audio/eve/E7vwl9oc.mp3', chrisUrl: 'audio/chris/SAwhPQfY.mp3'),
      HypeLine('Not what I expected. But I\u2019m here for it.',   markUrl: 'audio/mark/F1Qgjw6i.mp3', eveUrl: 'audio/eve/P3mt5Db9.mp3', chrisUrl: 'audio/chris/m3m5VNXo.mp3'),
      HypeLine('You know something we don\u2019t? Alright then.', markUrl: 'audio/mark/OZKcTYRk.mp3', eveUrl: 'audio/eve/yVjiHNhz.mp3', chrisUrl: 'audio/chris/SAwhPQfY.mp3'),
      HypeLine('That\u2019s a conviction pick. Love the energy.', markUrl: 'audio/mark/WJn7DA4C.mp3', eveUrl: 'audio/eve/ZHHYk781.mp3', chrisUrl: 'audio/chris/z8BEBxld.mp3'),
    ],
    // ─── FUN FACT NUGGET (Option C delivery) ─────────────────────────
    HypeTrigger.funFactNugget: [
      HypeLine('Quick nugget for you\u2026',  markUrl: 'audio/mark/F1Qgjw6i.mp3', eveUrl: 'audio/eve/P3mt5Db9.mp3', chrisUrl: 'audio/chris/SAwhPQfY.mp3'),
      HypeLine('Before you lock that in\u2026', markUrl: 'audio/mark/OZKcTYRk.mp3', eveUrl: 'audio/eve/yVjiHNhz.mp3', chrisUrl: 'audio/chris/z8BEBxld.mp3'),
      HypeLine('Hey, did you know\u2026',      markUrl: 'audio/mark/WJn7DA4C.mp3', eveUrl: 'audio/eve/ZHHYk781.mp3', chrisUrl: 'audio/chris/SAwhPQfY.mp3'),
      HypeLine('Heads up on this one\u2026',   markUrl: 'audio/mark/GnYvK8lt.mp3', eveUrl: 'audio/eve/wwaXJ94F.mp3', chrisUrl: 'audio/chris/z8BEBxld.mp3'),
      HypeLine('Insider intel incoming\u2026',  markUrl: 'audio/mark/egnygC27.mp3', eveUrl: 'audio/eve/Cjo4GR18.mp3', chrisUrl: 'audio/chris/m3m5VNXo.mp3'),
    ],
    HypeTrigger.completedAllPicks: [
      HypeLine('This is a winning bracket for sure!',         markUrl: 'audio/mark/aqOvYYrf.mp3', eveUrl: 'audio/eve/NjsJD4jm.mp3', chrisUrl: 'audio/chris/sAGGpDh0.mp3'),
      HypeLine('All picks locked in! Let\u2019s GO!',        markUrl: 'audio/mark/FLNMLVj8.mp3', eveUrl: 'audio/eve/b3FSPJux.mp3', chrisUrl: 'audio/chris/sAGGpDh0.mp3'),
      HypeLine('That\u2019s a championship bracket!',        markUrl: 'audio/mark/52u3YeyW.mp3', eveUrl: 'audio/eve/PyXtkftK.mp3', chrisUrl: 'audio/chris/sAGGpDh0.mp3'),
      HypeLine('Done! Now we sit back and watch the magic!',  markUrl: 'audio/mark/5PuIeHP9.mp3', eveUrl: 'audio/eve/NjsJD4jm.mp3', chrisUrl: 'audio/chris/sAGGpDh0.mp3'),
      HypeLine('Every pick filled in. You came to WIN!',     markUrl: 'audio/mark/cWmNyECo.mp3', eveUrl: 'audio/eve/b3FSPJux.mp3', chrisUrl: 'audio/chris/sAGGpDh0.mp3'),
      HypeLine('Bracket complete! Nobody\u2019s stopping you!', markUrl: 'audio/mark/6F4XcEtK.mp3', eveUrl: 'audio/eve/PyXtkftK.mp3', chrisUrl: 'audio/chris/sAGGpDh0.mp3'),
    ],
    HypeTrigger.changedPick: [
      HypeLine('Changed your mind? A wise player adapts!',  markUrl: 'audio/mark/prx825Kc.mp3', eveUrl: 'audio/eve/IwOHlzpQ.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('New pick, new energy! I respect it!',       markUrl: 'audio/mark/7VCbWhb6.mp3', eveUrl: 'audio/eve/IwOHlzpQ.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Switching it up! Bold strategy!',           markUrl: 'audio/mark/jMl2ESTa.mp3', eveUrl: 'audio/eve/IwOHlzpQ.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Re-pick alert! You know something we don\u2019t?', markUrl: 'audio/mark/vQV820R0.mp3', eveUrl: 'audio/eve/IwOHlzpQ.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Trust your gut! Good re-pick!',             markUrl: 'audio/mark/P2OT8rmC.mp3', eveUrl: 'audio/eve/IwOHlzpQ.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
    ],
    HypeTrigger.boldPick: [
      HypeLine('Going with the underdog! I respect the courage!', markUrl: 'audio/mark/Vjyaf1qy.mp3', eveUrl: 'audio/eve/hiYsWMW4.mp3', chrisUrl: 'audio/chris/KKgk2zeY.mp3'),
      HypeLine('That\u2019s a BOLD pick! The upset special!',    markUrl: 'audio/mark/EySKsx36.mp3', eveUrl: 'audio/eve/hiYsWMW4.mp3', chrisUrl: 'audio/chris/KKgk2zeY.mp3'),
      HypeLine('Nobody saw that coming! What do you know?',       markUrl: 'audio/mark/nxkzVM0m.mp3', eveUrl: 'audio/eve/hiYsWMW4.mp3', chrisUrl: 'audio/chris/KKgk2zeY.mp3'),
      HypeLine('Going against the chalk! I love it!',            markUrl: 'audio/mark/MwuZ1G5L.mp3', eveUrl: 'audio/eve/hiYsWMW4.mp3', chrisUrl: 'audio/chris/KKgk2zeY.mp3'),
      HypeLine('The upset pick! If this hits, you\u2019re a legend!', markUrl: 'audio/mark/WtxOqK0K.mp3', eveUrl: 'audio/eve/hiYsWMW4.mp3', chrisUrl: 'audio/chris/KKgk2zeY.mp3'),
    ],

    // ─── BRACKET CREATION ───────────────────────────────────────
    HypeTrigger.createdBracket: [
      HypeLine('A new bracket! Let\u2019s get this party started!',   markUrl: 'audio/mark/ADZkp6WQ.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('You just created a bracket! This is gonna be epic!', markUrl: 'audio/mark/ngBNGhgn.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('Fresh bracket on the board! Who\u2019s ready?',      markUrl: 'audio/mark/MQzdKoWD.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('New bracket alert! The competition starts NOW!',     markUrl: 'audio/mark/hXhhebOr.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('Great looking bracket! Let\u2019s fill it up!',      markUrl: 'audio/mark/KlysClxR.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.createdSquares: [
      HypeLine('Can\u2019t wait to see who joins your squares!',  markUrl: 'audio/mark/cR01PRyD.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('Squares game created! This is gonna be FUN!',    markUrl: 'audio/mark/YeUlZnNe.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('New Squares board! Quarter-by-quarter action!',  markUrl: 'audio/mark/HFJ9MM8n.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.createdPickem: [
      HypeLine('Pick Em created! Let\u2019s see who knows their stuff!', markUrl: 'audio/mark/wpZfUt1D.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('New Pick Em! Time to test that sports knowledge!',       markUrl: 'audio/mark/wpZfUt1D.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.createdTrivia: [
      HypeLine('Trivia night! Who\u2019s the real sports genius?', markUrl: 'audio/mark/QOEEWPbk.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('New Trivia game! Time to flex that brain!',       markUrl: 'audio/mark/QOEEWPbk.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.createdSurvivor: [
      HypeLine('Survivor pool! One wrong pick and you\u2019re out!', markUrl: 'audio/mark/Os9gqtwl.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('New Survivor pool! Only the strongest survive!',     markUrl: 'audio/mark/Os9gqtwl.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.createdVote: [
      HypeLine('Community vote created! Let the people decide!',  markUrl: 'audio/mark/kDd6yvha.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('New vote on the board! Democracy in action!',     markUrl: 'audio/mark/kDd6yvha.mp3', eveUrl: 'audio/eve/X9Yv9Pjg.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.bracketWentLive: [
      HypeLine('It\u2019s game time baby! Your bracket is LIVE!', markUrl: 'audio/mark/azUgcUfW.mp3', eveUrl: 'audio/eve/JY7aypzK.mp3', chrisUrl: 'audio/chris/5YwGIE5B.mp3'),
      HypeLine('Your bracket just went LIVE! Let\u2019s gooo!',   markUrl: 'audio/mark/frHiq5jQ.mp3', eveUrl: 'audio/eve/JY7aypzK.mp3', chrisUrl: 'audio/chris/5YwGIE5B.mp3'),
      HypeLine('LIVE! The competition has officially begun!',     markUrl: 'audio/mark/BqxuGeGu.mp3', eveUrl: 'audio/eve/JY7aypzK.mp3', chrisUrl: 'audio/chris/5YwGIE5B.mp3'),
      HypeLine('Your bracket is live! The crowd goes wild!',      markUrl: 'audio/mark/g69hFAls.mp3', eveUrl: 'audio/eve/JY7aypzK.mp3', chrisUrl: 'audio/chris/5YwGIE5B.mp3'),
    ],

    // ─── JOINING ────────────────────────────────────────────────
    HypeTrigger.joinedTournament: [
      HypeLine('Welcome to the battle! Let\u2019s gooo!',            markUrl: 'audio/mark/tP0z9AfN.mp3', eveUrl: 'audio/eve/FCKRwQiR.mp3', chrisUrl: 'audio/chris/LxbgVoIh.mp3'),
      HypeLine('You\u2019re in! Time to show them what you\u2019ve got!', markUrl: 'audio/mark/KD68O2aO.mp3', eveUrl: 'audio/eve/FCKRwQiR.mp3', chrisUrl: 'audio/chris/LxbgVoIh.mp3'),
      HypeLine('Joined and ready to compete! Love the energy!',      markUrl: 'audio/mark/dHXn2Bly.mp3', eveUrl: 'audio/eve/FCKRwQiR.mp3', chrisUrl: 'audio/chris/LxbgVoIh.mp3'),
      HypeLine('Welcome aboard! This bracket just got interesting!', markUrl: 'audio/mark/dcoQRRcj.mp3', eveUrl: 'audio/eve/FCKRwQiR.mp3', chrisUrl: 'audio/chris/LxbgVoIh.mp3'),
    ],
    HypeTrigger.joinedSquares: [
      HypeLine('Squares joined! Every box is a chance to WIN!', markUrl: 'audio/mark/4qxQnDlD.mp3', eveUrl: 'audio/eve/FCKRwQiR.mp3', chrisUrl: 'audio/chris/LxbgVoIh.mp3'),
      HypeLine('You\u2019re on the board! Let\u2019s hope your numbers hit!', markUrl: 'audio/mark/4qxQnDlD.mp3', eveUrl: 'audio/eve/FCKRwQiR.mp3', chrisUrl: 'audio/chris/LxbgVoIh.mp3'),
    ],
    HypeTrigger.joinedPickem: [
      HypeLine('Pick Em joined! Time to prove you\u2019re the expert!', markUrl: 'audio/mark/GEerXSmb.mp3', eveUrl: 'audio/eve/FCKRwQiR.mp3', chrisUrl: 'audio/chris/LxbgVoIh.mp3'),
      HypeLine('You\u2019re in the Pick Em! Let the picks begin!',      markUrl: 'audio/mark/GEerXSmb.mp3', eveUrl: 'audio/eve/FCKRwQiR.mp3', chrisUrl: 'audio/chris/LxbgVoIh.mp3'),
    ],

    // ─── SOCIAL ─────────────────────────────────────────────────
    HypeTrigger.sharedBracket: [
      HypeLine('Spreading the word! The more the merrier!',  markUrl: 'audio/mark/L8h6wAeh.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Shared! Now watch the players roll in!',     markUrl: 'audio/mark/KSBvfuJ1.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Nice share! Every champion needs competition!', markUrl: 'audio/mark/L8h6wAeh.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
    ],
    HypeTrigger.invitedFriend: [
      HypeLine('Bringing your crew! That\u2019s what it\u2019s about!', markUrl: 'audio/mark/dSRR94lu.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Friend invited! BMB is better with friends!',           markUrl: 'audio/mark/sFosMzG7.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
    ],
    HypeTrigger.leftComment: [
      HypeLine('Talk your talk! The chat is heating up!', markUrl: 'audio/mark/EleKg1dS.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Love the energy in the comments!',        markUrl: 'audio/mark/EleKg1dS.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
    ],
    HypeTrigger.ratedHost: [
      HypeLine('Thanks for the review! Hosts love feedback!', markUrl: 'audio/mark/erYy6QCl.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Your review helps everyone find the best hosts!', markUrl: 'audio/mark/erYy6QCl.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
    ],

    // ─── SCORING / RESULTS ──────────────────────────────────────
    HypeTrigger.correctPick: [
      HypeLine('Nailed it! That pick was money!',          markUrl: 'audio/mark/uyCAxvF6.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
      HypeLine('CORRECT! You called it!',                  markUrl: 'audio/mark/LecdBnZo.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
      HypeLine('Another one right! You\u2019re on fire!',  markUrl: 'audio/mark/5qXu42yB.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
      HypeLine('Boom! Correct pick! Keep \u2019em coming!', markUrl: 'audio/mark/dpAUmihD.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
    ],
    HypeTrigger.pickStreak: [
      HypeLine('You\u2019re on a STREAK! This is insane!',       markUrl: 'audio/mark/fDRnzCcr.mp3', eveUrl: 'audio/eve/nOz1BVDL.mp3', chrisUrl: 'audio/chris/9PGpFczf.mp3'),
      HypeLine('THREE in a ROW! Nobody can stop you!',           markUrl: 'audio/mark/cEpjr9yv.mp3', eveUrl: 'audio/eve/nOz1BVDL.mp3', chrisUrl: 'audio/chris/9PGpFczf.mp3'),
      HypeLine('Hot hand alert! Call the fire department!',       markUrl: 'audio/mark/fDRnzCcr.mp3', eveUrl: 'audio/eve/nOz1BVDL.mp3', chrisUrl: 'audio/chris/9PGpFczf.mp3'),
      HypeLine('On FIRE! That\u2019s a prediction machine!',     markUrl: 'audio/mark/fDRnzCcr.mp3', eveUrl: 'audio/eve/nOz1BVDL.mp3', chrisUrl: 'audio/chris/9PGpFczf.mp3'),
    ],
    HypeTrigger.wonBracket: [
      HypeLine('CHAMPION! You just WON the bracket!',            markUrl: 'audio/mark/Bl6l7nVd.mp3', eveUrl: 'audio/eve/wU5NwHn2.mp3', chrisUrl: 'audio/chris/c68j1fkq.mp3'),
      HypeLine('And the WINNER IS... YOU!',                      markUrl: 'audio/mark/EXpOoao5.mp3', eveUrl: 'audio/eve/wU5NwHn2.mp3', chrisUrl: 'audio/chris/c68j1fkq.mp3'),
      HypeLine('First place! YOU ARE THE CHAMPION!',             markUrl: 'audio/mark/9msrrGWb.mp3', eveUrl: 'audio/eve/wU5NwHn2.mp3', chrisUrl: 'audio/chris/c68j1fkq.mp3'),
      HypeLine('The crown is yours! What a dominant performance!', markUrl: 'audio/mark/CE9zsfVG.mp3', eveUrl: 'audio/eve/wU5NwHn2.mp3', chrisUrl: 'audio/chris/c68j1fkq.mp3'),
    ],
    HypeTrigger.topThreeFinish: [
      HypeLine('Top three finish! That\u2019s podium worthy!', markUrl: 'audio/mark/4taMkbmG.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
      HypeLine('Almost champion! Still an incredible finish!', markUrl: 'audio/mark/hzt4XqCV.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
    ],
    HypeTrigger.newHighScore: [
      HypeLine('NEW personal best! Getting better every time!', markUrl: 'audio/mark/FOBu98mK.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
      HypeLine('High score alert! Best performance yet!',       markUrl: 'audio/mark/FOBu98mK.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
    ],

    // ─── ENGAGEMENT ─────────────────────────────────────────────
    HypeTrigger.appOpened: [
      HypeLine('The king is back! What are we playing today?',  markUrl: 'audio/mark/pfcPQAOD.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('Hey hey! Good to see you! Let\u2019s check the board!', markUrl: 'audio/mark/VtzudVJb.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('Welcome back to Back My Bracket!',              markUrl: 'audio/mark/6HhQP3Pg.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('What\u2019s up champ! Ready to compete today?', markUrl: 'audio/mark/FTcUIsRZ.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('Back for more! I like the dedication!',         markUrl: 'audio/mark/ISt4mqyE.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('The bracket master has entered the building!',  markUrl: 'audio/mark/wRsnPt8a.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
    ],
    HypeTrigger.returnedAfterBreak: [
      HypeLine('Where\u2019ve you been?! We missed you!',              markUrl: 'audio/mark/jDMEhcWl.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('Welcome back! A lot has happened!',                     markUrl: 'audio/mark/8GeF2Yqm.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('You\u2019re back! The board has been waiting for you!', markUrl: 'audio/mark/8GeF2Yqm.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
    ],
    HypeTrigger.browsingBoard: [
      HypeLine('The board is stacked today! Which one catches your eye?', markUrl: 'audio/mark/jG1UCkEc.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('See something you like? Jump in!',                        markUrl: 'audio/mark/Gofw0Cnc.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
      HypeLine('So many brackets, so little time! Pick one!',            markUrl: 'audio/mark/jG1UCkEc.mp3', eveUrl: 'audio/eve/lGZyAyUB.mp3', chrisUrl: 'audio/chris/ZZemWtlb.mp3'),
    ],
    HypeTrigger.viewedLeaderboard: [
      HypeLine('Checking the standings! Where do you rank?', markUrl: 'audio/mark/qXdf0yT0.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
      HypeLine('Rankings check! Are you on top?',            markUrl: 'audio/mark/qXdf0yT0.mp3', eveUrl: 'audio/eve/PShgseM3.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
    ],
    HypeTrigger.earnedCredits: [
      HypeLine('Cha-ching! BMB credits in the bank!',     markUrl: 'audio/mark/AO07OvDS.mp3', eveUrl: 'audio/eve/uGJJ8VCJ.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
      HypeLine('Credits earned! Stack them up!',           markUrl: 'audio/mark/q7Ad1oPg.mp3', eveUrl: 'audio/eve/uGJJ8VCJ.mp3', chrisUrl: 'audio/chris/WQkOe8bN.mp3'),
    ],

    // ─── HOST-SPECIFIC ──────────────────────────────────────────
    HypeTrigger.firstPlayerJoined: [
      HypeLine('Your first player just joined! It\u2019s happening!', markUrl: 'audio/mark/vHTq8ZII.mp3', eveUrl: 'audio/eve/B2iGSdgB.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('Someone joined your bracket! Party\u2019s starting!', markUrl: 'audio/mark/vHTq8ZII.mp3', eveUrl: 'audio/eve/B2iGSdgB.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.bracketFillingUp: [
      HypeLine('Your bracket is filling up fast! Exciting!', markUrl: 'audio/mark/HZYYz1oH.mp3', eveUrl: 'audio/eve/B2iGSdgB.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('Almost packed! Your bracket is a hit!',      markUrl: 'audio/mark/HZYYz1oH.mp3', eveUrl: 'audio/eve/B2iGSdgB.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.bracketFull: [
      HypeLine('FULL HOUSE! Standing room only!',          markUrl: 'audio/mark/LM0jpAxV.mp3', eveUrl: 'audio/eve/B2iGSdgB.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
      HypeLine('Maximum capacity! Every spot is taken!',    markUrl: 'audio/mark/RBtm0S3W.mp3', eveUrl: 'audio/eve/B2iGSdgB.mp3', chrisUrl: 'audio/chris/5Ou4pmNp.mp3'),
    ],
    HypeTrigger.bracketCompleted: [
      HypeLine('Hey don\'t forget you can post to your socials and the BMB community!', markUrl: 'audio/mark/L8h6wAeh.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Nice job! Now share your picks with everyone! Hit those buttons below!', markUrl: 'audio/mark/KSBvfuJ1.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
      HypeLine('Your bracket is locked in! Time to flex on socials and the BMB community!', markUrl: 'audio/mark/L8h6wAeh.mp3', eveUrl: 'audio/eve/bsnIctsU.mp3', chrisUrl: 'audio/chris/8NMkWE1m.mp3'),
    ],
  };
}
