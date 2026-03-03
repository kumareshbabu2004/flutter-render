import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/hype_man/data/services/hype_man_service.dart';

/// Standalone demo playground for the BMB Hype Man voice engine.
///
/// Three natural voice options: Mark, Eve, Chris — all recorded
/// with ElevenLabs. No robotic Web Speech API voices.
/// Includes contextual guidance tips system.
class HypeManDemoScreen extends StatefulWidget {
  const HypeManDemoScreen({super.key});

  @override
  State<HypeManDemoScreen> createState() => _HypeManDemoScreenState();
}

class _HypeManDemoScreenState extends State<HypeManDemoScreen>
    with TickerProviderStateMixin {
  final _hype = HypeManService.instance;

  // Speech bubble state
  String? _currentSpeech;
  bool _showBubble = false;
  Timer? _bubbleTimer;
  late AnimationController _bubbleAnim;
  late Animation<double> _bubbleScale;

  // Guidance highlight state
  String? _highlightedKey;

  @override
  void initState() {
    super.initState();

    _bubbleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bubbleScale =
        CurvedAnimation(parent: _bubbleAnim, curve: Curves.elasticOut);

    _initHypeMan();
  }

  Future<void> _initHypeMan() async {
    await _hype.init();

    _hype.onSpeechStart = (text) {
      if (mounted) {
        setState(() {
          _currentSpeech = text;
          _showBubble = true;
        });
        _bubbleAnim.forward(from: 0);
        _bubbleTimer?.cancel();
        _bubbleTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) {
            _bubbleAnim.reverse();
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) setState(() => _showBubble = false);
            });
          }
        });
      }
    };

    _hype.onSpeechEnd = () {};

    _hype.onHighlightElement = (key) {
      if (mounted) setState(() => _highlightedKey = key);
    };

    _hype.onClearHighlight = () {
      if (mounted) setState(() => _highlightedKey = null);
    };

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _bubbleAnim.dispose();
    _hype.onSpeechStart = null;
    _hype.onSpeechEnd = null;
    _hype.onHighlightElement = null;
    _hype.onClearHighlight = null;
    super.dispose();
  }

  void _fire(HypeTrigger trigger, {String? context}) {
    _hype.speakDirect(trigger, context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BmbColors.deepNavy,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_showBubble && _currentSpeech != null) _buildSpeechBubble(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _buildVoicePickerCard(),
                  const SizedBox(height: 16),
                  _buildSettingsCard(),
                  const SizedBox(height: 16),
                  _buildGuidanceTipsCard(),
                  const SizedBox(height: 16),
                  _buildTriggerSection(
                      'Picks & Brackets', Icons.edit_note, BmbColors.successGreen, [
                    _TriggerBtn('Made a Pick', HypeTrigger.madePick, Icons.check_circle),
                    _TriggerBtn('Completed All Picks', HypeTrigger.completedAllPicks, Icons.done_all),
                    _TriggerBtn('Changed Pick', HypeTrigger.changedPick, Icons.refresh),
                    _TriggerBtn('Bold / Underdog Pick', HypeTrigger.boldPick, Icons.whatshot),
                  ]),
                  const SizedBox(height: 12),
                  _buildTriggerSection(
                      'Creating Games', Icons.add_circle, BmbColors.blue, [
                    _TriggerBtn('Created Bracket', HypeTrigger.createdBracket, Icons.account_tree),
                    _TriggerBtn('Created Squares', HypeTrigger.createdSquares, Icons.grid_4x4),
                    _TriggerBtn('Created Pick Em', HypeTrigger.createdPickem, Icons.checklist),
                    _TriggerBtn('Created Trivia', HypeTrigger.createdTrivia, Icons.quiz),
                    _TriggerBtn('Created Survivor', HypeTrigger.createdSurvivor, Icons.shield),
                    _TriggerBtn('Created Vote', HypeTrigger.createdVote, Icons.how_to_vote),
                    _TriggerBtn('Bracket Went Live!', HypeTrigger.bracketWentLive, Icons.cell_tower),
                  ]),
                  const SizedBox(height: 12),
                  _buildTriggerSection(
                      'Joining', Icons.person_add, const Color(0xFFFF6B35), [
                    _TriggerBtn('Joined Tournament', HypeTrigger.joinedTournament, Icons.group_add),
                    _TriggerBtn('Joined Squares', HypeTrigger.joinedSquares, Icons.grid_4x4),
                    _TriggerBtn('Joined Pick Em', HypeTrigger.joinedPickem, Icons.checklist),
                  ]),
                  const SizedBox(height: 12),
                  _buildTriggerSection(
                      'Social', Icons.people, BmbColors.vipPurple, [
                    _TriggerBtn('Shared Bracket', HypeTrigger.sharedBracket, Icons.share),
                    _TriggerBtn('Invited Friend', HypeTrigger.invitedFriend, Icons.person_add_alt),
                    _TriggerBtn('Left Comment', HypeTrigger.leftComment, Icons.chat_bubble),
                    _TriggerBtn('Rated Host', HypeTrigger.ratedHost, Icons.star),
                  ]),
                  const SizedBox(height: 12),
                  _buildTriggerSection(
                      'Scoring & Results', Icons.emoji_events, BmbColors.gold, [
                    _TriggerBtn('Correct Pick', HypeTrigger.correctPick, Icons.check),
                    _TriggerBtn('Pick Streak (3+)', HypeTrigger.pickStreak, Icons.local_fire_department),
                    _TriggerBtn('WON Bracket!', HypeTrigger.wonBracket, Icons.military_tech),
                    _TriggerBtn('Top 3 Finish', HypeTrigger.topThreeFinish, Icons.workspace_premium),
                    _TriggerBtn('New High Score', HypeTrigger.newHighScore, Icons.trending_up),
                  ]),
                  const SizedBox(height: 12),
                  _buildTriggerSection(
                      'Engagement', Icons.bolt, const Color(0xFF00BCD4), [
                    _TriggerBtn('App Opened', HypeTrigger.appOpened, Icons.login),
                    _TriggerBtn('Returned After Break', HypeTrigger.returnedAfterBreak, Icons.replay),
                    _TriggerBtn('Browsing Board', HypeTrigger.browsingBoard, Icons.explore),
                    _TriggerBtn('Viewed Leaderboard', HypeTrigger.viewedLeaderboard, Icons.leaderboard),
                    _TriggerBtn('Earned Credits', HypeTrigger.earnedCredits, Icons.savings),
                  ]),
                  const SizedBox(height: 12),
                  _buildTriggerSection(
                      'Host Events', Icons.manage_accounts, const Color(0xFFE53935), [
                    _TriggerBtn('First Player Joined', HypeTrigger.firstPlayerJoined, Icons.person_add),
                    _TriggerBtn('Bracket Filling Up', HypeTrigger.bracketFillingUp, Icons.trending_up),
                    _TriggerBtn('Bracket FULL', HypeTrigger.bracketFull, Icons.group),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BmbColors.midNavy, BmbColors.deepNavy],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BmbColors.cardDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back,
                  color: BmbColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [BmbColors.gold, const Color(0xFFFF6B35)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: BmbColors.gold.withValues(alpha: 0.4),
                    blurRadius: 12),
              ],
            ),
            child: const Icon(Icons.record_voice_over,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BMB Hype Man',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 20,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                Text('Voice Demo Playground',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          // Kill switch
          GestureDetector(
            onTap: () async {
              await _hype.setEnabled(!_hype.enabled);
              setState(() {});
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _hype.enabled
                    ? BmbColors.successGreen.withValues(alpha: 0.2)
                    : BmbColors.errorRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _hype.enabled
                      ? BmbColors.successGreen.withValues(alpha: 0.5)
                      : BmbColors.errorRed.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hype.enabled ? Icons.volume_up : Icons.volume_off,
                    color: _hype.enabled
                        ? BmbColors.successGreen
                        : BmbColors.errorRed,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hype.enabled ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: _hype.enabled
                          ? BmbColors.successGreen
                          : BmbColors.errorRed,
                      fontSize: 12,
                      fontWeight: BmbFontWeights.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SPEECH BUBBLE ──────────────────────────────────────────────────
  Widget _buildSpeechBubble() {
    final voiceLabel = switch (_hype.voice) {
      HypeVoice.mark => 'Mark',
      HypeVoice.eve => 'Eve',
      HypeVoice.chris => 'Chris',
    };
    return ScaleTransition(
      scale: _bubbleScale,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              BmbColors.gold.withValues(alpha: 0.2),
              const Color(0xFFFF6B35).withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: BmbColors.gold.withValues(alpha: 0.15),
                blurRadius: 20),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [BmbColors.gold, const Color(0xFFFF6B35)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.record_voice_over,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('BMB Hype Man',
                          style: TextStyle(
                              color: BmbColors.gold,
                              fontSize: 11,
                              fontWeight: BmbFontWeights.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: BmbColors.vipPurple.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(voiceLabel,
                            style: TextStyle(
                              color: BmbColors.vipPurple,
                              fontSize: 9,
                              fontWeight: BmbFontWeights.bold,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_currentSpeech ?? '',
                      style: TextStyle(
                          color: BmbColors.textPrimary,
                          fontSize: 14,
                          fontWeight: BmbFontWeights.medium,
                          height: 1.3)),
                ],
              ),
            ),
            if (_hype.isSpeaking) _buildSoundWave(),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundWave() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: _AnimatedBar(
            delay: Duration(milliseconds: i * 120),
            color: BmbColors.gold,
          ),
        );
      }),
    );
  }

  // ─── VOICE PICKER CARD ──────────────────────────────────────────────
  Widget _buildVoicePickerCard() {
    final voices = [
      (HypeVoice.mark, 'Mark', 'Best-friend hype guy', Icons.person, const Color(0xFF4FC3F7)),
      (HypeVoice.eve, 'Eve', 'Excited best-friend energy', Icons.person, const Color(0xFFFF80AB)),
      (HypeVoice.chris, 'Chris', 'Smooth confident hype', Icons.person, const Color(0xFFFFD54F)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic, color: BmbColors.vipPurple, size: 18),
              const SizedBox(width: 8),
              Text('Voice Selection',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BmbColors.vipPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('3 natural voices',
                    style: TextStyle(
                        color: BmbColors.vipPurple,
                        fontSize: 10,
                        fontWeight: BmbFontWeights.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Tap a voice to select it. Tap the play button to preview.',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 14),
          ...voices.map((v) {
            final (voice, name, desc, icon, color) = v;
            final isSelected = _hype.voice == voice;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : BmbColors.borderColor,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.2),
                              blurRadius: 12)
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    // Select voice (tap the left side)
                    GestureDetector(
                      onTap: () async {
                        await _hype.setVoice(voice);
                        setState(() {});
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.3)
                                  : BmbColors.borderColor.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected ? Icons.check : icon,
                              color: isSelected
                                  ? color
                                  : BmbColors.textTertiary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: TextStyle(
                                      color: isSelected
                                          ? color
                                          : BmbColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: BmbFontWeights.bold)),
                              const SizedBox(height: 2),
                              Text(desc,
                                  style: TextStyle(
                                      color: BmbColors.textTertiary,
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // PLAY BUTTON — always visible and prominent
                    GestureDetector(
                      onTap: () async {
                        // Switch to this voice first, then play
                        await _hype.setVoice(voice);
                        setState(() {});
                        _hype.speakDirect(HypeTrigger.madePick);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isSelected
                                ? [color, color.withValues(alpha: 0.7)]
                                : [BmbColors.borderColor, BmbColors.cardDark],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 8)
                                ]
                              : [],
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: isSelected ? Colors.white : BmbColors.textSecondary,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          // Quick test with current voice — big play button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => _hype.speakDirect(HypeTrigger.wonBracket),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [BmbColors.gold, const Color(0xFFFF6B35)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: BmbColors.gold.withValues(alpha: 0.3),
                        blurRadius: 12),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text('Test Hype Voice',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SETTINGS CARD ──────────────────────────────────────────────────
  Widget _buildSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: BmbColors.blue, size: 18),
              const SizedBox(width: 8),
              Text('Settings',
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold)),
            ],
          ),
          const SizedBox(height: 16),
          // Hype Level
          Text('Hype Level',
              style: TextStyle(
                  color: BmbColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: HypeLevel.values.map((level) {
              final isActive = _hype.hypeLevel == level;
              final labels = {
                HypeLevel.chill: ('Chill', Icons.spa, BmbColors.blue),
                HypeLevel.normal:
                    ('Normal', Icons.equalizer, BmbColors.successGreen),
                HypeLevel.hypeMode:
                    ('HYPE MODE', Icons.local_fire_department, BmbColors.gold),
              };
              final (label, icon, color) = labels[level]!;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: level != HypeLevel.hypeMode ? 8 : 0),
                  child: GestureDetector(
                    onTap: () async {
                      await _hype.setHypeLevel(level);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? color.withValues(alpha: 0.2)
                            : BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive ? color : BmbColors.borderColor,
                          width: isActive ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icon,
                              color: isActive
                                  ? color
                                  : BmbColors.textTertiary,
                              size: 20),
                          const SizedBox(height: 4),
                          Text(label,
                              style: TextStyle(
                                  color: isActive
                                      ? color
                                      : BmbColors.textTertiary,
                                  fontSize: 10,
                                  fontWeight: BmbFontWeights.bold),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Volume
          _buildSlider(
              'Volume', Icons.volume_up, _hype.volume, 0, 1, (v) async {
            await _hype.setVolume(v);
            setState(() {});
          }),
          const SizedBox(height: 16),
          // Guidance toggle
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: BmbColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hype Man Guidance',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 13,
                            fontWeight: BmbFontWeights.medium)),
                    Text(
                        'Subtle tips to help navigate the app',
                        style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: _hype.guidanceEnabled,
                onChanged: (v) async {
                  await _hype.setGuidanceEnabled(v);
                  setState(() {});
                },
                activeThumbColor: BmbColors.gold,
                activeTrackColor: BmbColors.gold.withValues(alpha: 0.3),
                inactiveThumbColor: BmbColors.textTertiary,
                inactiveTrackColor: BmbColors.borderColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, IconData icon, double value, double min,
      double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Icon(icon, color: BmbColors.textTertiary, size: 16),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(label,
              style: TextStyle(
                  color: BmbColors.textSecondary, fontSize: 11)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: BmbColors.blue,
              inactiveTrackColor: BmbColors.borderColor,
              thumbColor: BmbColors.blue,
              overlayColor: BmbColors.blue.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(value.toStringAsFixed(2),
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 10),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  // ─── GUIDANCE TIPS CARD ─────────────────────────────────────────────
  Widget _buildGuidanceTipsCard() {
    final tips = [
      (GuidanceTip.shareOnSocials, 'Share on Socials', Icons.share, 'share_button'),
      (GuidanceTip.exploreTab, 'Explore Tab', Icons.explore, 'nav_explore'),
      (GuidanceTip.createButton, 'Create Button', Icons.add_circle, 'nav_create'),
      (GuidanceTip.inviteFriends, 'Invite Friends', Icons.person_add_alt, 'invite_button'),
      (GuidanceTip.myBracketsTab, 'My Brackets Tab', Icons.list_alt, 'nav_brackets'),
      (GuidanceTip.profileSettings, 'Profile Settings', Icons.settings, 'nav_profile'),
      (GuidanceTip.swipeForMore, 'Swipe for More', Icons.swipe, null),
      (GuidanceTip.joinBracket, 'Join Bracket', Icons.group_add, 'join_button'),
      (GuidanceTip.stuckOnScreen, 'Navigation Help', Icons.help_outline, 'nav_bar'),
      (GuidanceTip.checkLeaderboard, 'Leaderboard', Icons.leaderboard, 'leaderboard_button'),
      (GuidanceTip.goLive, 'Go Live', Icons.cell_tower, 'go_live_button'),
      (GuidanceTip.pullToRefresh, 'Pull to Refresh', Icons.refresh, null),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.lightbulb,
                      color: BmbColors.gold, size: 16),
                ),
                const SizedBox(width: 10),
                Text('Guidance Tips',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 15,
                        fontWeight: BmbFontWeights.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _hype.resetGuidance();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Guidance tips reset!'),
                        backgroundColor: BmbColors.gold,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BmbColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Reset Tips',
                        style: TextStyle(
                            color: BmbColors.gold,
                            fontSize: 10,
                            fontWeight: BmbFontWeights.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
                'Tap a tip to hear the Hype Man guide you. '
                'The relevant button will glow.',
                style: TextStyle(
                    color: BmbColors.textTertiary, fontSize: 11)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tips.map((t) {
                final (tip, label, icon, highlightKey) = t;
                final isHighlighted = _highlightedKey == highlightKey &&
                    highlightKey != null;
                return GestureDetector(
                  onTap: () => _hype.showGuidance(tip),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? BmbColors.gold.withValues(alpha: 0.25)
                          : BmbColors.gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isHighlighted
                            ? BmbColors.gold
                            : BmbColors.gold.withValues(alpha: 0.3),
                        width: isHighlighted ? 1.5 : 1,
                      ),
                      boxShadow: isHighlighted
                          ? [
                              BoxShadow(
                                  color:
                                      BmbColors.gold.withValues(alpha: 0.3),
                                  blurRadius: 10)
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            color: isHighlighted
                                ? BmbColors.gold
                                : BmbColors.textSecondary,
                            size: 14),
                        const SizedBox(width: 6),
                        Text(label,
                            style: TextStyle(
                                color: isHighlighted
                                    ? BmbColors.gold
                                    : BmbColors.textPrimary,
                                fontSize: 12,
                                fontWeight: BmbFontWeights.medium)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TRIGGER SECTION ────────────────────────────────────────────────
  Widget _buildTriggerSection(
      String title, IconData icon, Color color, List<_TriggerBtn> triggers) {
    return Container(
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 15,
                        fontWeight: BmbFontWeights.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${triggers.length}',
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: BmbFontWeights.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: triggers.map((t) {
                return GestureDetector(
                  onTap: () => _fire(t.trigger),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, color: color, size: 14),
                        const SizedBox(width: 6),
                        Text(t.label,
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 12,
                                fontWeight: BmbFontWeights.medium)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HELPER DATA CLASS ────────────────────────────────────────────────

class _TriggerBtn {
  final String label;
  final HypeTrigger trigger;
  final IconData icon;
  const _TriggerBtn(this.label, this.trigger, this.icon);
}

// ─── ANIMATED SOUND WAVE BAR ──────────────────────────────────────────

class _AnimatedBar extends StatefulWidget {
  final Duration delay;
  final Color color;
  const _AnimatedBar({required this.delay, required this.color});

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _height;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _height = Tween<double>(begin: 4, end: 16).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _height,
      builder: (_, __) => Container(
        width: 3,
        height: _height.value,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
