// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/bracket_template.dart';
import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';
import 'package:bmb_mobile/features/bracket_builder/data/services/team_autocomplete_service.dart';
import 'package:bmb_mobile/features/subscription/presentation/screens/bmb_plus_upgrade_screen.dart';
import 'package:bmb_mobile/features/bracket_builder/data/services/speech_input_service.dart';
import 'package:bmb_mobile/features/bracket_builder/data/services/sports_speech_processor.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/sharing/presentation/widgets/share_bracket_sheet.dart';
import 'package:bmb_mobile/features/shopify/data/services/shopify_service.dart';
import 'package:bmb_mobile/features/shopify/presentation/screens/shopify_product_browser_screen.dart';
import 'package:bmb_mobile/features/companion/data/companion_service.dart';
/// Icon category for bonus rewards during bracket creation.
enum _RewardIconType {
  dinner, sneakers, backpack, gift, jersey, ticket, tech, experience, trophy, merch,
}


class BracketBuilderScreen extends StatefulWidget {
  /// Pass an existing bracket to enter **edit mode**.
  /// When non-null the wizard pre-fills every field and skips step 0 (bracket type).
  final CreatedBracket? editBracket;

  const BracketBuilderScreen({super.key, this.editBracket});
  @override
  State<BracketBuilderScreen> createState() => _BracketBuilderScreenState();
}

class _BracketBuilderScreenState extends State<BracketBuilderScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final _nameController = TextEditingController();
  final _customPrizeController = TextEditingController();
  final _charityNameController = TextEditingController();
  final _charityGoalController = TextEditingController();
  final _charityRaiseGoalController = TextEditingController();

  // Charity "Play for Their Charity" state
  double _charityRaiseGoalDollars = 0; // host-set dollar goal
  int _charityMinContribution = 10;    // host-set minimum credits
  final _tieBreakerController = TextEditingController();
  final _scrollController = ScrollController();

  // Step 0: Bracket Type selection (NEW)
  String _bracketType = 'standard'; // standard, voting, pickem, nopicks

  // Step 1: Template selection
  BracketTemplate? _selectedTemplate;
  bool _isCustomSize = false;
  int _customTeamCount = 8;

  // ── VOTING TEMPLATE STATE ──
  VotingTemplate? _selectedVotingTemplate;
  String _votingAudience = 'all'; // 'all', 'business', 'individual'
  String? _votingCategoryFilter; // null = show all

  // Step 2: Team names (standard / voting / nopicks)
  List<TextEditingController> _teamControllers = [];
  bool _useTBD = false;

  // ── PICK-EM SPECIFIC STATE ──
  String _pickEmSportType = 'NFL'; // NFL, NBA, NCAA Basketball, Custom...
  int _pickEmMatchupCount = 10;
  int? _pickEmNflWeek; // which NFL week to load
  // Each matchup = pair of controllers [teamA, teamB]
  List<List<TextEditingController>> _matchupControllers = [];
  bool _isCustomMatchupCount = false; // true when user entered a custom number
  int? _pickEmTieBreakerIndex; // which matchup is the tie-breaker game
  int? _standardTieBreakerIndex; // which matchup is the tie-breaker for standard/nopicks brackets

  // Voting bracket photo flags
  List<bool> _teamHasPhoto = [];
  bool _isBmbPlus = false;

  // Step 3: Entry donation + Tie-Breaker (required for ALL brackets)
  bool _isFreeEntry = true;
  int _entryDonation = 10;

  // Giveaway settings (visible when paid entry)
  bool _hasGiveaway = false;
  int _giveawayWinnerCount = 2;
  int _giveawayTokensPerWinner = 10;
  final _giveawayTokensController = TextEditingController(text: '10');

  // Step 4: Prize
  String _prizeType = 'none'; // 'none', 'store', 'custom', 'charity'
  BmbStorePrize? _selectedStorePrize;
  int _userCredits = 50;
  double _bucketBalance = 0;

  // Custom Bonus Rewards (aspirational prizes beyond credits)
  final List<_EditableReward> _customRewards = [];

  // Step 5: Auto Host / Go Live / Min Players / Visibility
  bool _autoHost = false;
  bool _isPublic = true;
  bool _addToBracketBoard = true;
  int _minPlayers = 4;
  DateTime? _scheduledLiveDate;
  TimeOfDay? _scheduledLiveTime;
  final _minPlayersController = TextEditingController(text: '4');

  static const _totalSteps = 7;

  /// True when we are editing an existing bracket (skip step 0, preserve id)
  bool get _isEditMode => widget.editBracket != null;

  // ── SPEECH-TO-TEXT STATE ──
  final _speechService = SpeechInputService.instance;
  bool _sttAvailable = false;
  bool _isListening = false;
  String? _listeningFieldId; // identifies which field mic is active

  // ── STEP LABEL PULSE ANIMATION ──
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;  // 0→1→0 smooth pulse

  // ── GUIDED SECTION SCROLL KEYS ──
  // Maps a step label string to a GlobalKey for auto-scrolling
  final Map<String, GlobalKey> _sectionKeys = {};
  Set<String> _prevActiveLabels = {};  // track previous to detect transitions

  // ── HOLOGRAM GUIDE ASSISTANT ──
  bool _guideVisible = true;   // speech bubble shown
  bool _guideDismissed = false; // user explicitly closed guide for this session

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _loadPrefs();
    _initSpeech();
    if (_isEditMode) {
      _prefillFromBracket(widget.editBracket!);
    }
  }

  Future<void> _initSpeech() async {
    final available = await _speechService.init();
    if (mounted) setState(() => _sttAvailable = available);
  }

  /// Start speech recognition and pipe result into [controller].
  ///
  /// When [fieldId] starts with "match" (matchup team fields) and the current
  /// pick-em is a major sports league, the speech output is piped through
  /// [SportsSpeechProcessor] so spoken spread notation like "minus 3 point 5"
  /// is converted to "-3.5".
  Future<void> _startVoiceInput(TextEditingController controller, String fieldId) async {
    // Try to init on-the-fly if not yet available (e.g. user granted mic
    // permission after initial page load).
    if (!_sttAvailable) {
      final ok = await _speechService.init();
      if (mounted) setState(() => _sttAvailable = ok);
    }
    if (!_sttAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
            'Speech recognition not available. '
            'Please allow microphone access and use Chrome or Edge.',
          ),
          backgroundColor: BmbColors.midNavy, behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      }
      return;
    }

    // Determine if we should apply sports-spread post-processing.
    final bool applySportsProcessor =
        fieldId.startsWith('match') && _bracketType == 'pickem';

    setState(() { _isListening = true; _listeningFieldId = fieldId; });
    final started = await _speechService.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          final processed = applySportsProcessor
              ? SportsSpeechProcessor.process(text)
              : text;
          controller.text = processed;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
          if (isFinal) {
            _isListening = false;
            _listeningFieldId = null;
          }
        });
      },
    );
    if (!started && mounted) {
      setState(() { _isListening = false; _listeningFieldId = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _speechService.lastError ?? 'Could not start speech recognition. Check microphone permissions.',
        ),
        backgroundColor: BmbColors.errorRed, behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Future<void> _stopVoiceInput() async {
    await _speechService.stop();
    if (mounted) setState(() { _isListening = false; _listeningFieldId = null; });
  }

  /// Pre-fill every wizard field from an existing bracket.
  void _prefillFromBracket(CreatedBracket b) {
    // Step 0 – bracket type (locked in edit mode)
    _bracketType = b.bracketType;

    // Step 1 – name & template
    _nameController.text = b.name;
    // Try to resolve the template used when creating
    if (b.bracketType == 'voting') {
      _selectedVotingTemplate = VotingTemplate.allTemplates.where((t) => t.id == b.templateId).firstOrNull;
      if (_selectedVotingTemplate == null && !b.templateId.startsWith('custom')) {
        _isCustomSize = true;
        _customTeamCount = b.teamCount;
      }
    } else if (b.bracketType == 'pickem') {
      // Resolve pick-em sport type from templateId
      if (b.templateId.startsWith('nfl_week_')) {
        _pickEmSportType = 'NFL';
        _pickEmNflWeek = int.tryParse(b.templateId.replaceFirst('nfl_week_', ''));
      } else {
        _pickEmSportType = b.sport == 'Custom' ? 'Custom' : b.sport;
      }
      _pickEmMatchupCount = b.teamCount ~/ 2;
    } else {
      _selectedTemplate = BracketTemplate.allTemplates.where((t) => t.id == b.templateId).firstOrNull;
      if (_selectedTemplate == null) {
        _isCustomSize = true;
        _customTeamCount = b.teamCount;
      }
    }

    // Step 2 – teams / matchups
    if (b.bracketType == 'pickem') {
      _matchupControllers = List.generate(b.teamCount ~/ 2, (i) {
        final aIdx = i * 2;
        final bIdx = i * 2 + 1;
        return [
          TextEditingController(text: aIdx < b.teams.length ? b.teams[aIdx] : 'Team A'),
          TextEditingController(text: bIdx < b.teams.length ? b.teams[bIdx] : 'Team B'),
        ];
      });
    } else {
      _teamControllers = List.generate(b.teamCount, (i) {
        return TextEditingController(text: i < b.teams.length ? b.teams[i] : 'Team ${i + 1}');
      });
      _teamHasPhoto = b.itemPhotos ?? List.generate(b.teamCount, (_) => false);
    }

    // Step 3 – entry & tie-breaker + giveaway
    _isFreeEntry = b.isFreeEntry;
    _entryDonation = b.entryDonation;
    _hasGiveaway = b.hasGiveaway;
    _giveawayWinnerCount = b.giveawayWinnerCount;
    _giveawayTokensPerWinner = b.giveawayTokensPerWinner;
    _giveawayTokensController.text = '${b.giveawayTokensPerWinner}';
    if (b.tieBreakerGame != null) {
      _tieBreakerController.text = b.tieBreakerGame!;
      // Try to match tie-breaker to a matchup index for standard brackets
      if (b.bracketType != 'pickem' && b.bracketType != 'voting') {
        for (int i = 0; i < b.teams.length - 1; i += 2) {
          final teamA = b.teams[i];
          final teamB = b.teams[i + 1];
          if (b.tieBreakerGame == '$teamA vs $teamB') {
            _standardTieBreakerIndex = i ~/ 2;
            break;
          }
        }
      }
    }

    // Step 4 – prize
    _prizeType = b.prizeType;
    if (b.prizeType == 'custom' && b.prizeDescription != null) {
      _customPrizeController.text = b.prizeDescription!;
    }
    if (b.prizeType == 'store' && b.storePrizeId != null) {
      _selectedStorePrize = BmbStorePrize.storePrizes.where((p) => p.id == b.storePrizeId).firstOrNull;
    }
    if (b.prizeType == 'charity') {
      if (b.charityName != null) _charityNameController.text = b.charityName!;
      if (b.charityGoal != null) _charityGoalController.text = b.charityGoal!;
      _charityRaiseGoalDollars = b.charityRaiseGoalDollars;
      _charityMinContribution = b.charityMinContribution;
      if (b.charityRaiseGoalDollars > 0) {
        _charityRaiseGoalController.text = b.charityRaiseGoalDollars.toStringAsFixed(0);
      }
    }

    // Step 5 – auto host & go live & visibility
    _autoHost = b.autoHost;
    _minPlayers = b.minPlayers;
    _isPublic = b.isPublic;
    _addToBracketBoard = b.addToBracketBoard;
    _minPlayersController.text = '${b.minPlayers}';
    if (b.scheduledLiveDate != null) {
      _scheduledLiveDate = b.scheduledLiveDate;
      _scheduledLiveTime = TimeOfDay(hour: b.scheduledLiveDate!.hour, minute: b.scheduledLiveDate!.minute);
    }

    // Start at step 1 (skip bracket type selection – it's locked)
    _currentStep = 1;
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userCredits = prefs.getInt('user_bmb_bucks') ?? 50;
      _isBmbPlus = prefs.getBool('is_bmb_plus') ?? false;
      _bucketBalance = prefs.getDouble('bmb_bucks_balance') ?? 0;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nameController.dispose();
    _customPrizeController.dispose();
    _charityNameController.dispose();
    _charityGoalController.dispose();
    _charityRaiseGoalController.dispose();
    _tieBreakerController.dispose();
    _minPlayersController.dispose();
    _scrollController.dispose();
    for (final c in _teamControllers) {
      c.dispose();
    }
    for (final pair in _matchupControllers) {
      for (final c in pair) {
        c.dispose();
      }
    }
    super.dispose();
  }

  /// Returns the set of label strings that should be highlighted right now.
  /// Multiple labels can be active when the user must choose between options
  /// (e.g. all bracket type cards on step 0).
  Set<String> get _activeLabels {
    switch (_currentStep) {
      case 0: // Bracket Type — all choices highlighted
        return {'1', '1a', '1b', '1c', '1d'};
      case 1: // Name & Template — strict sequential flow
        if (_nameController.text.trim().isEmpty) return {'2'};
        // Name filled → now guide to template/sport selection
        if (_bracketType == 'pickem') {
          if (_pickEmSportType == 'NFL' && _pickEmNflWeek == null) return {'2b'};
          return {}; // sport type already selected by default
        }
        if (_bracketType == 'voting') {
          if (_selectedVotingTemplate == null && !_isCustomSize) return {'2c', '2d'};
          return {};
        }
        // Standard / No Picks
        if (_selectedTemplate == null && !_isCustomSize) return {'2a', '2b'};
        return {};
      case 2: // Teams / Matchups — highlight '3' until all names filled
        if (_bracketType == 'pickem') {
          final hasEmpty = _matchupControllers.any((pair) =>
              pair[0].text.trim().isEmpty || pair[1].text.trim().isEmpty);
          return hasEmpty ? {'3'} : {};
        }
        final hasEmpty = _teamControllers.any((c) => c.text.trim().isEmpty);
        return hasEmpty ? {'3'} : {};
      case 3: // Contribution & Tie-Breaker — sequential: 4 → 4a → 4b → 4c
        // Tie-breaker is required for non-voting — guide there if empty
        if (_bracketType != 'voting' && _tieBreakerController.text.trim().isEmpty) {
          return {'4', '4c'};
        }
        // Default: highlight the top section so user sees where they are
        return {'4'};
      case 4: // Prize — guide to selection, then sub-detail
        if (_prizeType == 'none') return {'5'};
        // Once a type is chosen, guide to the detail section
        if (_prizeType == 'store' || _prizeType == 'shopify' || _prizeType == 'custom' || _prizeType == 'charity') {
          return {'5a'};
        }
        return {};
      case 5: // Auto Host & Go Live — sequential: 6a → 6b → 6c → 6d
        if (_scheduledLiveDate == null) return {'6a'};
        // After date set, guide through visibility → min players → auto host
        return {'6b'};
      case 6: // Confirm
        return {};
      default:
        return {};
    }
  }

  /// Get (or create) a GlobalKey for a section label to enable auto-scroll.
  GlobalKey _keyFor(String label) {
    return _sectionKeys.putIfAbsent(label, () => GlobalKey());
  }

  /// Auto-scroll to the first active label's section after a short delay.
  /// Only scrolls when the active set _changes_ (not on every rebuild).
  void _maybeAutoScroll() {
    final labels = _activeLabels;
    if (labels.isEmpty || labels == _prevActiveLabels) return;
    _prevActiveLabels = Set.of(labels);
    _scrollToLabel(labels.first);
  }

  /// Force-scroll to the current active section — called on validation failure
  /// to ensure the user always sees what needs to be completed.
  void _forceScrollToActive() {
    final labels = _activeLabels;
    if (labels.isEmpty) return;
    _prevActiveLabels = {}; // reset so subsequent auto-scroll also works
    setState(() {}); // trigger rebuild to update highlight state
    _scrollToLabel(labels.first);
  }

  /// Smooth-scroll to the widget keyed by [label].
  /// BUG #12 FIX: Avoid using BuildContext across async gap.
  void _scrollToLabel(String label) {
    final key = _sectionKeys[label];
    if (key?.currentContext == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    });
  }

  int get _teamCount {
    if (_bracketType == 'voting' && _selectedVotingTemplate != null && !_isCustomSize) {
      return _selectedVotingTemplate!.itemCount;
    }
    return _isCustomSize ? _customTeamCount : (_selectedTemplate?.teamCount ?? 0);
  }

  void _initTeamControllers() {
    // ── Pick-Em uses matchup pairs, not flat team list ──
    if (_bracketType == 'pickem') {
      _initMatchupControllers();
      return;
    }
    for (final c in _teamControllers) {
      c.dispose();
    }
    final count = _teamCount;
    final List<String> defaults;
    if (_bracketType == 'voting' && _selectedVotingTemplate != null) {
      defaults = _selectedVotingTemplate!.defaultItems;
    } else {
      defaults = _selectedTemplate?.defaultTeams ?? [];
    }
    _teamControllers = List.generate(count, (i) {
      // Template brackets with real team names: keep defaults
      // Otherwise: leave empty — hint text shows "Team 1", "Team 2" etc.
      final hasDefault = !_useTBD && i < defaults.length && defaults[i].isNotEmpty;
      final text = _useTBD ? 'TBD' : (hasDefault ? defaults[i] : '');
      return TextEditingController(text: text);
    });
    _teamHasPhoto = List.generate(count, (_) => false);
  }

  /// Initialize matchup controllers for Pick 'Em mode
  void _initMatchupControllers() {
    for (final pair in _matchupControllers) {
      for (final c in pair) {
        c.removeListener(_teamMemoryListener);
        c.dispose();
      }
    }
    // If NFL week is selected, load from schedule
    if (_pickEmSportType == 'NFL' && _pickEmNflWeek != null) {
      final schedule = TeamAutocompleteService.getNflWeekMatchups(_pickEmNflWeek!);
      _pickEmMatchupCount = schedule.length;
      _matchupControllers = List.generate(schedule.length, (i) {
        return [
          TextEditingController(text: schedule[i][0]),  // Away
          TextEditingController(text: schedule[i][1]),  // Home
        ];
      });
      // Remember all schedule team names for speech auto-correct
      for (final m in schedule) {
        SportsSpeechProcessor.rememberTeam(m[0]);
        SportsSpeechProcessor.rememberTeam(m[1]);
      }
    } else {
      // Try sport-specific schedule first (NBA, NHL, MLB) — preserves
      // correct Away @ Home ordering.
      final schedule = TeamAutocompleteService.getScheduleMatchups(_pickEmSportType);
      if (schedule != null && schedule.isNotEmpty) {
        final count = _pickEmMatchupCount.clamp(1, schedule.length);
        _pickEmMatchupCount = count;
        _matchupControllers = List.generate(count, (i) {
          return [
            TextEditingController(text: schedule[i][0]),  // Away
            TextEditingController(text: schedule[i][1]),  // Home
          ];
        });
        // Remember schedule names for speech auto-correct
        for (int i = 0; i < count; i++) {
          SportsSpeechProcessor.rememberTeam(schedule[i][0]);
          SportsSpeechProcessor.rememberTeam(schedule[i][1]);
        }
      } else {
        // Fallback: generic alphabetical team list or empty for Custom
        final teams = _pickEmSportType != 'Custom'
            ? TeamAutocompleteService.getTeamsForLeague(_pickEmSportType)
            : <String>[];
        _matchupControllers = List.generate(_pickEmMatchupCount, (i) {
          final aIndex = i * 2;
          final bIndex = i * 2 + 1;
          return [
            TextEditingController(
              text: aIndex < teams.length ? teams[aIndex] : '',
            ),
            TextEditingController(
              text: bIndex < teams.length ? teams[bIndex] : '',
            ),
          ];
        });
      }
    }
    // Attach listeners to remember typed team names for speech matching
    for (final pair in _matchupControllers) {
      for (final c in pair) {
        c.addListener(_teamMemoryListener);
      }
    }
  }

  /// Debounced listener that remembers team names typed by the user.
  void _teamMemoryListener() {
    for (final pair in _matchupControllers) {
      for (final c in pair) {
        if (c.text.trim().length >= 3) {
          SportsSpeechProcessor.rememberTeam(c.text.trim());
        }
      }
    }
  }

  /// Show dialog to enter a custom number of matchups
  void _showCustomMatchupCountDialog() {
    final controller = TextEditingController(
      text: _isCustomMatchupCount ? '$_pickEmMatchupCount' : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Custom Number of Games',
          style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter any number between 2 and 50',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'e.g. 6, 11, 25',
                hintStyle: TextStyle(color: BmbColors.textTertiary.withValues(alpha: 0.5), fontSize: 14),
                filled: true,
                fillColor: BmbColors.deepNavy,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.blue)),
              ),
              onSubmitted: (val) {
                final n = int.tryParse(val);
                if (n != null && n >= 2 && n <= 50) {
                  setState(() {
                    _isCustomMatchupCount = true;
                    _pickEmMatchupCount = n;
                  });
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BmbColors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n != null && n >= 2 && n <= 50) {
                setState(() {
                  _isCustomMatchupCount = true;
                  _pickEmMatchupCount = n;
                });
                Navigator.of(ctx).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Please enter a number between 2 and 50'),
                  backgroundColor: BmbColors.errorRed,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: Text('Apply', style: TextStyle(color: Colors.white, fontWeight: BmbFontWeights.bold)),
          ),
        ],
      ),
    );
  }

  /// Add a new empty matchup row at the bottom
  void _addMatchupRow() {
    setState(() {
      _matchupControllers.add([
        TextEditingController(text: ''),
        TextEditingController(text: ''),
      ]);
      _pickEmMatchupCount = _matchupControllers.length;
    });
  }

  /// Remove a matchup row
  void _removeMatchupRow(int index) {
    if (_matchupControllers.length <= 2) return; // min 2 matchups
    setState(() {
      for (final c in _matchupControllers[index]) {
        c.dispose();
      }
      _matchupControllers.removeAt(index);
      _pickEmMatchupCount = _matchupControllers.length;
      // Adjust tie-breaker selection if needed
      if (_pickEmTieBreakerIndex != null) {
        if (_pickEmTieBreakerIndex == index) {
          _pickEmTieBreakerIndex = null;
          _tieBreakerController.text = '';
        } else if (_pickEmTieBreakerIndex! > index) {
          _pickEmTieBreakerIndex = _pickEmTieBreakerIndex! - 1;
        }
      }
    });
  }

  void _fillTBD() {
    if (_bracketType == 'pickem') {
      for (final pair in _matchupControllers) {
        pair[0].text = 'TBD';
        pair[1].text = 'TBD';
      }
    } else {
      for (final c in _teamControllers) {
        c.text = 'TBD';
      }
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: return true; // bracket type
      case 1:
        if (_bracketType == 'pickem') {
          // Pick-Em: just need a name (template/sport selected via _pickEmSportType)
          return _nameController.text.trim().isNotEmpty;
        }
        if (_bracketType == 'voting') {
          return _nameController.text.trim().isNotEmpty && (_selectedVotingTemplate != null || _isCustomSize);
        }
        return _nameController.text.trim().isNotEmpty && (_selectedTemplate != null || _isCustomSize);
      case 2:
        if (_bracketType == 'pickem') {
          return _matchupControllers.every((pair) =>
              pair[0].text.trim().isNotEmpty && pair[1].text.trim().isNotEmpty);
        }
        // Empty fields are OK — treated as TBD when saving
        return true;
      case 3:
        // Voting brackets have no tie-breaker — just entry donation
        if (_bracketType == 'voting') return true;
        // Pick-em uses _pickEmTieBreakerIndex, standard uses _standardTieBreakerIndex or text
        if (_bracketType == 'pickem') return _pickEmTieBreakerIndex != null;
        return _standardTieBreakerIndex != null || _tieBreakerController.text.trim().isNotEmpty; // tie-breaker required
      case 5: return _scheduledLiveDate != null; // go-live date required
      default: return true;
    }
  }

  void _next() {
    if (!_canProceed()) {
      String msg = 'Please complete this step';
      if (_currentStep == 1) msg = 'Enter a name and select a template';
      if (_currentStep == 2) msg = _bracketType == 'pickem' ? 'Please fill in all matchup team names' : 'Please fill in all team names';
      if (_currentStep == 3 && _bracketType != 'voting') msg = 'Tie-breaker game is required for all brackets';
      if (_currentStep == 5) msg = 'Please set a Go Live date';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: BmbColors.errorRed, behavior: SnackBarBehavior.floating,
      ));
      // Force-scroll to the incomplete section so user sees exactly what to do
      _forceScrollToActive();
      return;
    }
    if (_currentStep == 1) {
      // In edit mode, controllers are pre-filled — only re-init if template was changed
      if (!_isEditMode || _teamControllers.isEmpty && _matchupControllers.isEmpty) {
        _initTeamControllers();
      }
    }
    setState(() {
      _currentStep++;
      _prevActiveLabels = {}; // reset so auto-scroll triggers on new page
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _back() {
    final minStep = _isEditMode ? 1 : 0; // edit mode skips step 0
    if (_currentStep > minStep) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  // ─── BMB+ REQUIRED DIALOG ──────────────────────────────────────
  void _showBmbPlusGate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gold premium icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BmbColors.gold, BmbColors.goldLight]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: BmbColors.gold.withValues(alpha: 0.3), blurRadius: 16)],
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.black, size: 34),
              ),
              const SizedBox(height: 16),
              // BMB+ badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BmbColors.gold, BmbColors.goldLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('BMB+ Required',
                    style: TextStyle(color: BmbColors.deepNavy, fontSize: 12, fontWeight: BmbFontWeights.bold)),
              ),
              const SizedBox(height: 14),
              Text('Save & Share Your Bracket',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
              const SizedBox(height: 10),
              Text(
                  'You must be a BMB+ member to save and share brackets with friends. Upgrade now to host tournaments and earn credits!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 20),
              // Benefits summary
              _gateBenefitRow(Icons.save, 'Save brackets to your profile'),
              _gateBenefitRow(Icons.share, 'Share brackets with friends'),
              _gateBenefitRow(Icons.emoji_events, 'Host unlimited tournaments'),
              _gateBenefitRow(Icons.monetization_on, 'Earn credits from hosting'),
              const SizedBox(height: 20),
              // Price
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.1), BmbColors.gold.withValues(alpha: 0.03)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('\$9.99', style: TextStyle(color: BmbColors.gold, fontSize: 24, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                    Text('/month', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Upgrade button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BmbPlusUpgradeScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Upgrade to BMB+', style: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Continue Building', style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gateBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: BmbColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13))),
          const Icon(Icons.check, color: BmbColors.gold, size: 16),
        ],
      ),
    );
  }

  Future<void> _saveBracket() async {
    // ─── BMB+ GATE: free users can BUILD but not SAVE ───
    if (!_isBmbPlus) {
      _showBmbPlusGate();
      return;
    }

    // Credits are NOT deducted at save time — they are deducted when status transitions to LIVE.
    // This is a fail-safe: if the host deletes a "saved" bracket, no one is charged.

    // Build team list — for pick-em, flatten matchup pairs into flat list
    final List<String> teamList;
    final int effectiveTeamCount;
    final String effectiveSport;
    final String effectiveTemplateId;
    if (_bracketType == 'pickem') {
      teamList = _matchupControllers.expand((pair) => [pair[0].text.trim(), pair[1].text.trim()]).toList();
      effectiveTeamCount = _matchupControllers.length * 2;
      effectiveSport = _pickEmSportType == 'Custom' ? 'Custom' : _pickEmSportType;
      effectiveTemplateId = _pickEmSportType == 'NFL' && _pickEmNflWeek != null
          ? 'nfl_week_$_pickEmNflWeek'
          : 'pickem_custom';
    } else {
      teamList = _teamControllers.map((c) {
        final t = c.text.trim();
        return t.isEmpty ? 'TBD' : t;
      }).toList();
      effectiveTeamCount = _teamCount;
      if (_bracketType == 'voting' && _selectedVotingTemplate != null) {
        effectiveSport = 'Voting';
        effectiveTemplateId = _selectedVotingTemplate!.id;
      } else {
        effectiveSport = _isCustomSize ? 'Custom' : (_selectedTemplate?.sport ?? 'Custom');
        effectiveTemplateId = _isCustomSize ? 'custom_$_customTeamCount' : (_selectedTemplate?.id ?? 'custom');
      }
    }
    final bracket = CreatedBracket(
      id: _isEditMode ? widget.editBracket!.id : 'b_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      templateId: effectiveTemplateId,
      sport: effectiveSport,
      teamCount: effectiveTeamCount,
      teams: teamList,
      isFreeEntry: _isFreeEntry,
      entryDonation: _isFreeEntry ? 0 : _entryDonation,
      prizeType: _prizeType,
      prizeDescription: _prizeType == 'custom'
          ? _customPrizeController.text.trim()
          : _prizeType == 'charity'
              ? 'Play for Their Charity'
              : null,
      storePrizeId: _selectedStorePrize?.id,
      storePrizeName: _selectedStorePrize?.name,
      storePrizeCost: _selectedStorePrize?.cost,
      status: _isEditMode ? widget.editBracket!.status : 'saved',
      createdAt: _isEditMode ? widget.editBracket!.createdAt : DateTime.now(),
      scheduledLiveDate: _scheduledLiveDate != null
          ? DateTime(_scheduledLiveDate!.year, _scheduledLiveDate!.month, _scheduledLiveDate!.day,
              _scheduledLiveTime?.hour ?? 12, _scheduledLiveTime?.minute ?? 0)
          : null,
      hostId: CurrentUserService.instance.userId,
      hostName: CurrentUserService.instance.displayName.isNotEmpty ? CurrentUserService.instance.displayName : 'You',
      hostState: CurrentUserService.instance.stateAbbr.isNotEmpty ? CurrentUserService.instance.stateAbbr : null,
      bracketType: _bracketType,
      tieBreakerGame: _bracketType == 'voting' ? null : (_tieBreakerController.text.trim().isNotEmpty ? _tieBreakerController.text.trim() : null),
      autoHost: _autoHost,
      minPlayers: _minPlayers,
      isPublic: _isPublic,
      addToBracketBoard: _addToBracketBoard,
      charityName: null, // Winner selects charity at tournament end
      charityGoal: _prizeType == 'charity' ? _charityGoalController.text.trim() : null,
      charityRaiseGoalDollars: _prizeType == 'charity' ? _charityRaiseGoalDollars : 0,
      charityMinContribution: _prizeType == 'charity' ? _charityMinContribution : 10,
      itemPhotos: _bracketType == 'voting' ? _teamHasPhoto : null,
      hasGiveaway: _hasGiveaway,
      giveawayWinnerCount: _hasGiveaway ? _giveawayWinnerCount : 0,
      giveawayTokensPerWinner: _hasGiveaway ? _giveawayTokensPerWinner : 0,
    );
    if (!mounted) return;
    // Show share sheet for new brackets before popping
    if (!_isEditMode) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: BmbColors.midNavy,
        isScrollControlled: true,
        isDismissible: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => ShareBracketSheet(bracket: bracket, userName: 'You'),
      );
    }
    if (!mounted) return;
    Navigator.pop(context, bracket);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Main wizard content ──
              Column(
                children: [
                  _buildHeader(),
                  _buildProgressBar(),
                  // Listening indicator
                  if (_isListening)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: BmbColors.errorRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BmbColors.errorRed.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: const BoxDecoration(color: BmbColors.errorRed, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text('Listening... Speak now', style: TextStyle(color: BmbColors.errorRed, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _stopVoiceInput,
                          child: Text('Tap to stop', style: TextStyle(color: BmbColors.errorRed.withValues(alpha: 0.7), fontSize: 11)),
                        ),
                      ]),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildCurrentStep(),
                      ),
                    ),
                  ),
                  _buildBottomButtons(),
                ],
              ),
              // ── Hologram Guide Assistant ──
              if (!_guideDismissed) _buildGuideAssistant(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final pageNum = _isEditMode ? _currentStep : _currentStep + 1;
    final titles = [
      'Bracket Type',
      _bracketType == 'pickem' ? 'Name & Sport' : _bracketType == 'voting' ? 'Choose Template' : 'Name & Template',
      _bracketType == 'pickem' ? 'Matchups' : _bracketType == 'voting' ? 'Items' : 'Team Names',
      _bracketType == 'voting' ? 'Contribution Options' : 'Contribution & Tie-Breaker',
      'Select Prize',
      'Auto Host & Go Live',
      'Confirm & Save',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary), onPressed: _back),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEditMode ? 'Edit Bracket' : 'Bracket Builder', style: TextStyle(color: BmbColors.textPrimary, fontSize: 18, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $pageNum',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: BmbFontWeights.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(titles[_currentStep], style: TextStyle(color: BmbColors.textTertiary, fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(_isEditMode
              ? 'Step $_currentStep of ${_totalSteps - 1}'
              : 'Step ${_currentStep + 1} of $_totalSteps',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: List.generate(_totalSteps, (i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 4 : 0),
            height: 4,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: i <= _currentStep ? BmbColors.blue : BmbColors.borderColor),
          ),
        )),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep0BracketType();
      case 1: return _buildStep1NameTemplate();
      case 2: return _buildStep2Teams();
      case 3: return _buildStep3Entry();
      case 4: return _buildStep4Prize();
      case 5: return _buildStep5Status();
      case 6: return _buildStep6Confirm();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: BmbColors.deepNavy.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: BmbColors.borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _back,
                style: OutlinedButton.styleFrom(side: BorderSide(color: BmbColors.borderColor), foregroundColor: BmbColors.textPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep == _totalSteps - 1 ? _saveBracket : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep == _totalSteps - 1 ? BmbColors.successGreen : BmbColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentStep == _totalSteps - 1 && !_isBmbPlus) ...[                    const Icon(Icons.workspace_premium, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(_currentStep == _totalSteps - 1 ? (_isEditMode ? 'Save Changes' : 'Save Bracket') : 'Continue', style: TextStyle(fontSize: 15, fontWeight: BmbFontWeights.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 0: BRACKET TYPE ────────────────────────────────────────
  Widget _buildStep0BracketType() {
    return Column(
      key: const ValueKey('step0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guidedSection(
          label: '1',
          title: 'Choose Bracket Type',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Select how your bracket will work for participants.', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              _bracketTypeCardLabeled('1a', 'standard', 'Standard Bracket', 'Classic elimination bracket. Teams advance round by round until a champion is crowned.',
                  Icons.account_tree, BmbColors.blue),
              const SizedBox(height: 8),
              _bracketTypeCardLabeled('1b', 'voting', 'Voting Bracket', 'Community votes to decide winners. Great for menu item challenges, "Best of" competitions, and fan engagement.',
                  Icons.how_to_vote, const Color(0xFF9C27B0)),
              const SizedBox(height: 8),
              _bracketTypeCardLabeled('1c', 'pickem', 'Pick \'Em (Single Round)', 'One round of matchups. No teams advance. Users pick winners, scored by percentage correct. Includes tie-breaker.',
                  Icons.checklist, BmbColors.gold),
              const SizedBox(height: 8),
              _bracketTypeCardLabeled('1d', 'nopicks', 'No Picks', 'A bracket pre-loaded with teams. Users follow along as outcomes happen without making picks.',
                  Icons.visibility, BmbColors.successGreen),
            ],
          ),
        ),
        if (_bracketType == 'voting' && !_isBmbPlus) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: BmbColors.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Photo uploads for voting brackets require BMB+. Text-only voting is free.', style: TextStyle(color: BmbColors.gold, fontSize: 11))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _bracketTypeCard(String id, String title, String desc, IconData icon, Color color) {
    final sel = _bracketType == id;
    return GestureDetector(
      onTap: () => setState(() => _bracketType = id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: sel ? null : BmbColors.cardGradient,
          color: sel ? color.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color : BmbColors.borderColor, width: sel ? 1.5 : 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: (sel ? color : BmbColors.textSecondary).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: sel ? color : BmbColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
            if (sel) Icon(Icons.check_circle, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  /// Bracket type card with a step sub-label badge.
  Widget _bracketTypeCardLabeled(String label, String id, String title, String desc, IconData icon, Color color) {
    final sel = _bracketType == id;
    return GestureDetector(
      onTap: () => setState(() => _bracketType = id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: sel ? null : BmbColors.cardGradient,
          color: sel ? color.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color : BmbColors.borderColor, width: sel ? 1.5 : 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step label badge on the left
            _stepLabel(label),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: (sel ? color : BmbColors.textSecondary).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: sel ? color : BmbColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
            if (sel) Icon(Icons.check_circle, color: color, size: 22),
          ],
        ),
      ),
    );
  }

  // ─── STEP 1: NAME & TEMPLATE ─────────────────────────────────────
  Widget _buildStep1NameTemplate() {
    // Pick-Em has its own sport-type + matchup-count UI instead of templates
    if (_bracketType == 'pickem') {
      return _buildStep1PickEm();
    }
    // Voting brackets get a dedicated template browser
    if (_bracketType == 'voting') {
      return _buildStep1Voting();
    }
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guidedSection(
          label: '2',
          title: 'Name Your Bracket',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _styledTextField(_nameController, 'e.g. March Madness 2025 Pool', Icons.edit, false),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _guidedSection(
          label: '2a',
          title: 'Choose a Template',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Select a major tournament template or build your own.', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              ...BracketTemplate.allTemplates.map((t) => _templateCard(t)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _guidedSection(
          label: '2b',
          title: 'Or Build Your Own',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _customSizeSelector(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STEP 1 VOTING: template browser with audience + category ───
  Widget _buildStep1Voting() {
    // Filter templates by audience
    List<VotingTemplate> templates;
    if (_votingAudience == 'business') {
      templates = VotingTemplate.businessTemplates;
    } else if (_votingAudience == 'individual') {
      templates = VotingTemplate.individualTemplates;
    } else {
      templates = VotingTemplate.allTemplates;
    }
    // Further filter by category
    if (_votingCategoryFilter != null) {
      templates = templates.where((t) => t.category == _votingCategoryFilter).toList();
    }

    // Determine which categories are available for current audience filter
    final visibleCategoryIds = <String>{};
    final audienceTemplates = _votingAudience == 'business'
        ? VotingTemplate.businessTemplates
        : _votingAudience == 'individual'
            ? VotingTemplate.individualTemplates
            : VotingTemplate.allTemplates;
    for (final t in audienceTemplates) {
      visibleCategoryIds.add(t.category);
    }
    final visibleCategories = VotingTemplate.categories
        .where((c) => visibleCategoryIds.contains(c.id))
        .toList();

    return Column(
      key: const ValueKey('step1_voting'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guidedSection(
          label: '2',
          title: 'Name Your Voting Bracket',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            _styledTextField(_nameController, 'e.g. Best Menu Item 2025', Icons.edit, false),
          ]),
        ),
        const SizedBox(height: 16),

        // ── AUDIENCE TOGGLE (Business / Individual / All) ──
        _guidedSection(
          label: '2a',
          title: 'Who is this for?',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Row(children: [
              _votingAudienceChip('all', 'All', Icons.apps),
              const SizedBox(width: 8),
              _votingAudienceChip('business', 'Business', Icons.storefront),
              const SizedBox(width: 8),
              _votingAudienceChip('individual', 'Personal', Icons.person),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // ── CATEGORY FILTER CHIPS ──
        _guidedSection(
          label: '2b',
          title: 'Category',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _votingCategoryChip(null, 'All', Icons.grid_view),
                ...visibleCategories.map((c) =>
                    _votingCategoryChip(c.id, c.label, _votingCategoryIcon(c.icon))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── TEMPLATE COUNT ──
        _guidedSection(
          label: '2c',
          title: 'Choose a Template',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(
              '${templates.length} template${templates.length == 1 ? '' : 's'} available',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
            ),
            const SizedBox(height: 10),
            // ── TEMPLATE CARDS ──
            ...templates.map((vt) => _votingTemplateCard(vt)),
          ]),
        ),

        const SizedBox(height: 16),
        _guidedSection(
          label: '2d',
          title: 'Or Build Your Own',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            _votingCustomSizeSelector(),
          ]),
        ),
      ],
    );
  }

  Widget _votingAudienceChip(String id, String label, IconData icon) {
    final sel = _votingAudience == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _votingAudience = id;
          _votingCategoryFilter = null; // reset category when audience changes
          _selectedVotingTemplate = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF9C27B0).withValues(alpha: 0.15) : BmbColors.cardDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? const Color(0xFF9C27B0) : BmbColors.borderColor,
              width: sel ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: sel ? const Color(0xFF9C27B0) : BmbColors.textSecondary, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                color: sel ? const Color(0xFF9C27B0) : BmbColors.textPrimary,
                fontSize: 11,
                fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _votingCategoryChip(String? id, String label, IconData icon) {
    final sel = _votingCategoryFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _votingCategoryFilter = id;
          _selectedVotingTemplate = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF9C27B0) : BmbColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel ? const Color(0xFF9C27B0) : BmbColors.borderColor,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: sel ? Colors.white : BmbColors.textSecondary, size: 14),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              color: sel ? Colors.white : BmbColors.textPrimary,
              fontSize: 11,
              fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );
  }

  IconData _votingCategoryIcon(String iconName) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant;
      case 'storefront': return Icons.storefront;
      case 'business_center': return Icons.business_center;
      case 'movie': return Icons.movie;
      case 'music_note': return Icons.music_note;
      case 'sports': return Icons.sports;
      case 'celebration': return Icons.celebration;
      case 'favorite': return Icons.favorite;
      case 'emoji_emotions': return Icons.emoji_emotions;
      default: return Icons.category;
    }
  }

  IconData _votingTemplateIcon(String iconName) {
    switch (iconName) {
      case 'restaurant_menu': return Icons.restaurant_menu;
      case 'local_bar': return Icons.local_bar;
      case 'cake': return Icons.cake;
      case 'coffee': return Icons.coffee;
      case 'sports_bar': return Icons.sports_bar;
      case 'storefront': return Icons.storefront;
      case 'build_circle': return Icons.build_circle;
      case 'palette': return Icons.palette;
      case 'fitness_center': return Icons.fitness_center;
      case 'event': return Icons.event;
      case 'place': return Icons.place;
      case 'movie': return Icons.movie;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'sentiment_very_satisfied': return Icons.sentiment_very_satisfied;
      case 'tv': return Icons.tv;
      case 'animation': return Icons.animation;
      case 'music_note': return Icons.music_note;
      case 'queue_music': return Icons.queue_music;
      case 'album': return Icons.album;
      case 'mic': return Icons.mic;
      case 'sports': return Icons.sports;
      case 'sports_basketball': return Icons.sports_basketball;
      case 'sports_football': return Icons.sports_football;
      case 'ac_unit': return Icons.ac_unit;
      case 'audiotrack': return Icons.audiotrack;
      case 'face_retouching_natural': return Icons.face_retouching_natural;
      case 'dinner_dining': return Icons.dinner_dining;
      case 'flight': return Icons.flight;
      case 'fastfood': return Icons.fastfood;
      case 'directions_run': return Icons.directions_run;
      case 'sports_esports': return Icons.sports_esports;
      case 'shield': return Icons.shield;
      case 'help_outline': return Icons.help_outline;
      case 'flash_on': return Icons.flash_on;
      case 'access_time': return Icons.access_time;
      case 'breakfast_dining': return Icons.breakfast_dining;
      case 'add_circle_outline': return Icons.add_circle_outline;
      default: return Icons.how_to_vote;
    }
  }

  Widget _votingTemplateCard(VotingTemplate vt) {
    final sel = _selectedVotingTemplate?.id == vt.id && !_isCustomSize;
    final isBlank = vt.id == 'vote_blank';
    final purpleAccent = const Color(0xFF9C27B0);
    return GestureDetector(
      onTap: () => setState(() {
        _selectedVotingTemplate = vt;
        _isCustomSize = false;
        _selectedTemplate = null;
        // Auto-fill bracket name if empty and template chosen
        if (_nameController.text.trim().isEmpty && !isBlank) {
          _nameController.text = vt.name;
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: sel ? null : BmbColors.cardGradient,
          color: sel ? purpleAccent.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? purpleAccent : BmbColors.borderColor,
            width: sel ? 1.5 : 0.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: sel ? purpleAccent.withValues(alpha: 0.2) : BmbColors.borderColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_votingTemplateIcon(vt.icon),
                color: sel ? purpleAccent : BmbColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(vt.name, style: TextStyle(
                    color: BmbColors.textPrimary, fontSize: 14,
                    fontWeight: BmbFontWeights.semiBold,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: vt.audience == 'business'
                        ? BmbColors.blue.withValues(alpha: 0.15)
                        : vt.audience == 'individual'
                            ? BmbColors.gold.withValues(alpha: 0.15)
                            : BmbColors.borderColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    vt.audience == 'business' ? 'BIZ' : vt.audience == 'individual' ? 'PERSONAL' : 'ALL',
                    style: TextStyle(
                      color: vt.audience == 'business'
                          ? BmbColors.blue
                          : vt.audience == 'individual'
                              ? BmbColors.gold
                              : BmbColors.textTertiary,
                      fontSize: 7,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text(vt.description, style: TextStyle(
                color: BmbColors.textTertiary, fontSize: 10, height: 1.3,
              ), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                isBlank ? 'Start from scratch' : '${vt.itemCount} items pre-loaded',
                style: TextStyle(color: purpleAccent.withValues(alpha: 0.7), fontSize: 10, fontWeight: BmbFontWeights.medium),
              ),
            ]),
          ),
          if (sel) Icon(Icons.check_circle, color: purpleAccent, size: 22),
        ]),
      ),
    );
  }

  Widget _votingCustomSizeSelector() {
    final purpleAccent = const Color(0xFF9C27B0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: _isCustomSize ? null : BmbColors.cardGradient,
        color: _isCustomSize ? purpleAccent.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCustomSize ? purpleAccent : BmbColors.borderColor,
          width: _isCustomSize ? 1.5 : 0.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.build, color: _isCustomSize ? purpleAccent : BmbColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text('Custom Size', style: TextStyle(
            color: BmbColors.textPrimary, fontSize: 14,
            fontWeight: BmbFontWeights.semiBold,
          )),
        ]),
        const SizedBox(height: 10),
        Text('Select number of items:', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: BracketTemplate.customSizes.map((size) {
            final sel = _isCustomSize && _customTeamCount == size;
            return GestureDetector(
              onTap: () => setState(() {
                _isCustomSize = true;
                _customTeamCount = size;
                _selectedVotingTemplate = null;
                _selectedTemplate = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? purpleAccent : BmbColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? purpleAccent : BmbColors.borderColor),
                ),
                child: Text(size == 2 ? '2 (1v1)' : '$size', style: TextStyle(
                  color: sel ? Colors.white : BmbColors.textPrimary,
                  fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal,
                  fontSize: 13,
                )),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  /// Pick-Em specific Step 1: sport type, NFL week, matchup count
  Widget _buildStep1PickEm() {
    return Column(
      key: const ValueKey('step1_pickem'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guidedSection(
          label: '2',
          title: 'Name Your Pick \'Em',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            _styledTextField(_nameController, 'e.g. NFL Week 15 Pick \'Em', Icons.edit, false),
          ]),
        ),
        const SizedBox(height: 16),
        // ─── SPORT TYPE ───
        _guidedSection(
          label: '2a',
          title: 'Select Sport Type',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text('Team names will auto-populate based on the sport you choose.',
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: TeamAutocompleteService.pickEmSportTypes.map((sport) {
                final sel = _pickEmSportType == sport;
                return GestureDetector(
                  onTap: () => setState(() {
                    _pickEmSportType = sport;
                    _pickEmNflWeek = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? BmbColors.gold : BmbColors.cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? BmbColors.gold : BmbColors.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_pickEmSportIcon(sport), color: sel ? Colors.black : BmbColors.textSecondary, size: 16),
                        const SizedBox(width: 6),
                        Text(sport, style: TextStyle(
                          color: sel ? Colors.black : BmbColors.textPrimary,
                          fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
        ),
        // ─── NFL WEEK SELECTOR ───
        if (_pickEmSportType == 'NFL') ...[
          const SizedBox(height: 16),
          _guidedSection(
            label: '2b',
            title: 'Select NFL Game Week',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              Text('Load the full week\'s schedule automatically.',
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(18, (i) {
                  final week = i + 1;
                  final available = TeamAutocompleteService.availableNflWeeks.contains(week);
                  final sel = _pickEmNflWeek == week;
                  return GestureDetector(
                    onTap: available ? () => setState(() => _pickEmNflWeek = week) : null,
                    child: Container(
                      width: 48, height: 40,
                      decoration: BoxDecoration(
                        color: sel ? BmbColors.blue : available ? BmbColors.cardDark : BmbColors.cardDark.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? BmbColors.blue : available ? BmbColors.borderColor : BmbColors.borderColor.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text('$week', style: TextStyle(
                          color: sel ? Colors.white : available ? BmbColors.textPrimary : BmbColors.textTertiary.withValues(alpha: 0.4),
                          fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                      ),
                    ),
                  );
                }),
              ),
              if (_pickEmNflWeek != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BmbColors.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: BmbColors.successGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Week $_pickEmNflWeek loaded: ${TeamAutocompleteService.getNflWeekMatchups(_pickEmNflWeek!).length} matchups will be pre-filled on the next step.',
                      style: TextStyle(color: BmbColors.successGreen, fontSize: 11),
                    )),
                  ]),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: BmbColors.gold, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Weeks with data are clickable. Others are greyed out — data will be added when the NFL schedule is published.',
                      style: TextStyle(color: BmbColors.gold, fontSize: 11),
                    )),
                  ]),
                ),
              ],
            ]),
          ),
        ],
        // ─── MATCHUP COUNT (non-NFL or no week selected) ───
        if (_pickEmSportType != 'NFL' || _pickEmNflWeek == null) ...[
          const SizedBox(height: 16),
          _guidedSection(
            label: '2b',
            title: 'Select Number of Matchups',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              Text('How many games in this Pick \'Em?',
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  ...[5, 8, 10, 12, 15, 16, 17, 20].map((count) {
                    final sel = _pickEmMatchupCount == count && !_isCustomMatchupCount;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _isCustomMatchupCount = false;
                        _pickEmMatchupCount = count;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? BmbColors.blue : BmbColors.cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? BmbColors.blue : BmbColors.borderColor),
                        ),
                        child: Text('$count', style: TextStyle(
                          color: sel ? Colors.white : BmbColors.textPrimary,
                          fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal,
                          fontSize: 14,
                        )),
                      ),
                    );
                  }),
                  // Custom number chip
                  GestureDetector(
                    onTap: () => _showCustomMatchupCountDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isCustomMatchupCount ? BmbColors.blue : BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isCustomMatchupCount ? BmbColors.blue : BmbColors.borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 13,
                            color: _isCustomMatchupCount ? Colors.white : BmbColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isCustomMatchupCount ? '$_pickEmMatchupCount' : 'Custom',
                            style: TextStyle(
                              color: _isCustomMatchupCount ? Colors.white : BmbColors.textPrimary,
                              fontWeight: _isCustomMatchupCount ? BmbFontWeights.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ],
        // Custom note
        if (_pickEmSportType == 'Custom') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.mic, color: BmbColors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Custom mode: type or speak team names on the next step. Use the mic icon on each input field for talk-to-text.',
                style: TextStyle(color: BmbColors.blue, fontSize: 11),
              )),
            ]),
          ),
        ],
      ],
    );
  }

  IconData _pickEmSportIcon(String sport) {
    switch (sport) {
      case 'NFL': return Icons.sports_football;
      case 'NBA': return Icons.sports_basketball;
      case 'NCAA Basketball': return Icons.sports_basketball;
      case 'NCAA Football': return Icons.sports_football;
      case "NCAA Women's Basketball": return Icons.sports_basketball;
      case 'MLB': return Icons.sports_baseball;
      case 'NHL': return Icons.sports_hockey;
      case 'BMB Weekly Mix': return Icons.auto_awesome;
      case 'Custom': return Icons.edit;
      default: return Icons.sports;
    }
  }

  Widget _templateCard(BracketTemplate t) {
    final selected = !_isCustomSize && _selectedTemplate?.id == t.id;
    return GestureDetector(
      onTap: () => setState(() { _selectedTemplate = t; _isCustomSize = false; }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected ? null : BmbColors.cardGradient,
          color: selected ? BmbColors.blue.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? BmbColors.blue : BmbColors.borderColor, width: selected ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: selected ? BmbColors.blue.withValues(alpha: 0.2) : BmbColors.borderColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_sportIcon(t.sport), color: selected ? BmbColors.blue : BmbColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 2),
                  Text(
                    '${t.teamCount} teams'
                    '${t.hasPlayInGames ? ' + ${t.playInCount * 2} play-in teams (${t.playInCount} games)' : ''}'
                    ' \u2022 ${t.sport}'
                    '${t.dataFeedId != null ? ' \u2022 LIVE Data' : ''}',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: BmbColors.blue, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _customSizeSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: _isCustomSize ? null : BmbColors.cardGradient,
        color: _isCustomSize ? BmbColors.gold.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isCustomSize ? BmbColors.gold : BmbColors.borderColor, width: _isCustomSize ? 1.5 : 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.build, color: _isCustomSize ? BmbColors.gold : BmbColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text('Custom Bracket', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
          ]),
          const SizedBox(height: 10),
          Text(_bracketType == 'pickem' ? 'Select number of matchups:' : 'Select number of teams:', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: BracketTemplate.customSizes.map((size) {
              final sel = _isCustomSize && _customTeamCount == size;
              return GestureDetector(
                onTap: () => setState(() { _isCustomSize = true; _customTeamCount = size; _selectedTemplate = null; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: sel ? BmbColors.gold : BmbColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? BmbColors.gold : BmbColors.borderColor)),
                  child: Text(size == 2 ? '2 (1v1)' : '$size', style: TextStyle(color: sel ? Colors.black : BmbColors.textPrimary, fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal, fontSize: 13)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── TEAM AUTOCOMPLETE ───
  void _showTeamAutocomplete(int index) {
    final sport = _isCustomSize ? null : _selectedTemplate?.sport;
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        List<TeamSuggestion> results = [];
        return StatefulBuilder(builder: (ctx2, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
            builder: (ctx3, sc) {
              return Column(children: [
                Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search teams (NFL, NBA, NCAA...)', hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: BmbColors.textSecondary),
                      filled: true, fillColor: BmbColors.cardDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.blue)),
                    ),
                    onChanged: (v) {
                      setSheetState(() {
                        results = TeamAutocompleteService.search(v, sport: sport);
                      });
                    },
                  ),
                ])),
                Expanded(
                  child: results.isEmpty
                    ? Center(child: Text('Type to search teams...', style: TextStyle(color: BmbColors.textTertiary)))
                    : ListView.builder(
                        controller: sc, itemCount: results.length,
                        itemBuilder: (_, i) {
                          final team = results[i];
                          return ListTile(
                            leading: Icon(Icons.sports, color: BmbColors.blue, size: 20),
                            title: Text(team.name, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13)),
                            subtitle: Text(team.league, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                            onTap: () {
                              _teamControllers[index].text = team.name;
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                ),
              ]);
            },
          );
        });
      },
    );
  }

  // ─── STEP 2: TEAM NAMES / MATCHUPS ──────────────────────────────────
  Widget _buildStep2Teams() {
    if (_bracketType == 'pickem') return _buildStep2PickEmMatchups();
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guidedSection(
          label: '3',
          title: _bracketType == 'voting' ? 'Add Items / Contestants' : 'Add Team Names',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text('$_teamCount ${_bracketType == 'voting' ? 'items' : 'teams'} in this bracket', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            // Quick fill TBD
            GestureDetector(
              onTap: () => setState(() { _useTBD = true; _fillTBD(); }),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3))),
                child: Row(children: [
                  Icon(Icons.flash_on, color: BmbColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Don't have names yet? Tap to fill all with \"TBD\"", style: TextStyle(color: BmbColors.gold, fontSize: 12))),
                ]),
              ),
            ),
        // Voting photo upload prompt
        if (_bracketType == 'voting') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.photo_camera, color: Color(0xFF9C27B0), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _isBmbPlus
                    ? 'Tap the camera icon next to each item to upload a photo for voting.'
                    : 'Upgrade to BMB+ to add photos to your voting bracket items.',
                style: TextStyle(color: const Color(0xFF9C27B0), fontSize: 11),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        // Play-in info for templates with play-in games
        if (_selectedTemplate != null && _selectedTemplate!.hasPlayInGames) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: BmbColors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'This template includes ${_selectedTemplate!.playInCount} play-in games. '
                '${_selectedTemplate!.playInCount * 2} teams play in the First Four, and the '
                '${_selectedTemplate!.playInCount} winners complete the ${_selectedTemplate!.teamCount}-team bracket. '
                'Seeds are shown in brackets like (1), (16) etc.',
                style: TextStyle(color: BmbColors.blue, fontSize: 11, height: 1.4),
              )),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        // Team name list
        ...List.generate(
          _teamControllers.length > 32 ? 32 : _teamControllers.length,
          (i) {
            // Parse seed from the team name
            final seed = BracketTemplate.parseSeed(_teamControllers[i].text);
            return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Seed badge or index number
                if (seed != null)
                  Container(
                    width: 32, height: 26,
                    margin: const EdgeInsets.only(right: 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: BmbColors.gold.withValues(alpha: 0.15),
                      border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Center(child: Text('$seed', style: TextStyle(
                      color: BmbColors.gold, fontSize: seed > 9 ? 10 : 12,
                      fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'))),
                  )
                else
                  SizedBox(width: 32, child: Text('${i + 1}.', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12, fontWeight: BmbFontWeights.semiBold))),
                Expanded(
                  child: _AutoFitTeamField(
                    controller: _teamControllers[i],
                    hintText: _bracketType == 'voting' ? 'Item ${i + 1}' : 'Team Name',
                    isListening: _bracketType != 'voting' && _isListening && _listeningFieldId == 'team_$i',
                    showMic: _bracketType != 'voting',
                    onMicTap: () {
                      if (_bracketType == 'voting') return;
                      if (_isListening && _listeningFieldId == 'team_$i') {
                        _stopVoiceInput();
                      } else {
                        _startVoiceInput(_teamControllers[i], 'team_$i');
                      }
                    },
                    showSearch: _bracketType != 'voting',
                    onSearchTap: () => _showTeamAutocomplete(i),
                  ),
                ),
                // Photo upload for voting brackets (BMB+ only)
                if (_bracketType == 'voting' && _isBmbPlus) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showPhotoUploadDialog(i),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: (i < _teamHasPhoto.length && _teamHasPhoto[i]) ? BmbColors.successGreen.withValues(alpha: 0.15) : BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (i < _teamHasPhoto.length && _teamHasPhoto[i]) ? BmbColors.successGreen : BmbColors.borderColor),
                      ),
                      child: Icon(
                        (i < _teamHasPhoto.length && _teamHasPhoto[i]) ? Icons.check_circle : Icons.camera_alt,
                        color: (i < _teamHasPhoto.length && _teamHasPhoto[i]) ? BmbColors.successGreen : BmbColors.textTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
          },
        ),
        if (_teamControllers.length > 32) ...[
          const SizedBox(height: 8),
          Center(child: Text('+ ${_teamControllers.length - 32} more teams (all pre-filled)', style: TextStyle(color: BmbColors.textTertiary, fontSize: 12))),
        ],
          ]),
        ),
      ],
    );
  }

  // ─── STEP 2 PICK-EM: MATCHUP PAIRS (Team A vs Team B) ────────────
  Widget _buildStep2PickEmMatchups() {
    final isNflWeek = _pickEmSportType == 'NFL' && _pickEmNflWeek != null;
    return Column(
      key: const ValueKey('step2_pickem'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guidedSection(
          label: '3',
          title: 'Set Up Matchups',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(
              isNflWeek
                  ? 'NFL Week $_pickEmNflWeek \u2022 ${_matchupControllers.length} matchups loaded'
                  : '${_matchupControllers.length} matchups \u2022 $_pickEmSportType Pick \'Em',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            // Quick fill TBD for pick-em
            GestureDetector(
              onTap: () => setState(() { _useTBD = true; _fillTBD(); }),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3))),
                child: Row(children: [
                  Icon(Icons.flash_on, color: BmbColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Fill all with \"TBD\"", style: TextStyle(color: BmbColors.gold, fontSize: 11))),
                ]),
              ),
            ),
            // Mic / talk-to-text hint for custom
            if (_pickEmSportType == 'Custom') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2))),
                child: Row(children: [
                  const Icon(Icons.mic, color: BmbColors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Tap the mic icon on any field to speak team names.', style: TextStyle(color: BmbColors.blue, fontSize: 11))),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        // ─── MATCHUP ROWS ───
        ...List.generate(_matchupControllers.length, (i) => _buildMatchupRow(i)),
        const SizedBox(height: 12),
        // Add matchup button
        GestureDetector(
          onTap: _addMatchupRow,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: BmbColors.blue.withValues(alpha: 0.5), width: 1),
              borderRadius: BorderRadius.circular(10),
              color: BmbColors.blue.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, color: BmbColors.blue, size: 18),
                const SizedBox(width: 8),
                Text('Add Matchup', style: TextStyle(color: BmbColors.blue, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
              ],
            ),
          ),
        ),
          ]),
        ),
      ],
    );
  }

  /// Major sports leagues that use Away @ Home format.\n  /// Now applies to ALL Pick 'Em templates per user request.\n  static const _sportsWithHomeAway = {'NFL', 'NBA', 'NHL', 'MLB'};

  /// ALL Pick 'Em templates use "@" instead of "vs" and show Away / Home
  /// labels. This applies to every sport type including Custom.
  bool get _isSportsPickEm => _bracketType == 'pickem';

  /// Calculate auto-fit font size for team names based on text length.
  /// Returns a smaller font when the text is long so it fits in the box.
  double _autoFitFontSize(String text, {double maxFont = 12, double minFont = 8}) {
    if (text.length <= 14) return maxFont;
    if (text.length <= 18) return maxFont - 1;
    if (text.length <= 22) return maxFont - 2;
    if (text.length <= 28) return maxFont - 3;
    return minFont;
  }

  /// A single matchup row: [Game #] | Team A field | "vs"/"@" | Team B field | [X]
  Widget _buildMatchupRow(int index) {
    final pair = _matchupControllers[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game label + optional tie-breaker badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Game ${index + 1}', style: TextStyle(
                  color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold,
                )),
              ),
              if (_pickEmTieBreakerIndex == index) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: BmbColors.blue.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sports_score, color: BmbColors.blue, size: 10),
                    const SizedBox(width: 3),
                    Text('TIE-BREAKER', style: TextStyle(color: BmbColors.blue, fontSize: 7, fontWeight: BmbFontWeights.bold)),
                  ]),
                ),
              ],
              const Spacer(),
              // Remove button (only if more than 2 matchups)
              if (_matchupControllers.length > 2)
                GestureDetector(
                  onTap: () => _removeMatchupRow(index),
                  child: Icon(Icons.remove_circle_outline, color: BmbColors.errorRed.withValues(alpha: 0.6), size: 18),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Team A | vs | Team B
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Team A
              Expanded(
                child: _AutoFitTeamField(
                  controller: pair[0],
                  hintText: _isSportsPickEm ? 'Away' : 'Team A',
                  isListening: _isListening && _listeningFieldId == 'matchA_$index',
                  onMicTap: () => _isListening && _listeningFieldId == 'matchA_$index'
                      ? _stopVoiceInput()
                      : _startVoiceInput(pair[0], 'matchA_$index'),
                  showSearch: _pickEmSportType != 'Custom',
                  onSearchTap: () => _showMatchupAutocomplete(index, 0),
                ),
              ),
              // VS / @ badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_isSportsPickEm ? '@' : 'vs', style: TextStyle(
                    color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.bold,
                    fontFamily: 'ClashDisplay',
                  )),
                ),
              ),
              // Team B
              Expanded(
                child: _AutoFitTeamField(
                  controller: pair[1],
                  hintText: _isSportsPickEm ? 'Home' : 'Team B',
                  isListening: _isListening && _listeningFieldId == 'matchB_$index',
                  onMicTap: () => _isListening && _listeningFieldId == 'matchB_$index'
                      ? _stopVoiceInput()
                      : _startVoiceInput(pair[1], 'matchB_$index'),
                  showSearch: _pickEmSportType != 'Custom',
                  onSearchTap: () => _showMatchupAutocomplete(index, 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Team autocomplete for matchup pair fields
  void _showMatchupAutocomplete(int matchupIndex, int teamSlot) {
    final sport = _pickEmSportType == 'Custom' ? null : _pickEmSportType;
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        List<TeamSuggestion> results = [];
        return StatefulBuilder(builder: (ctx2, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
            builder: (ctx3, sc) {
              return Column(children: [
                Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    style: TextStyle(color: BmbColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: sport != null ? 'Search $sport teams...' : 'Search teams...',
                      hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: BmbColors.textSecondary),
                      filled: true, fillColor: BmbColors.cardDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.blue)),
                    ),
                    onChanged: (v) {
                      setSheetState(() {
                        results = TeamAutocompleteService.search(v, sport: sport);
                      });
                    },
                  ),
                ])),
                Expanded(
                  child: results.isEmpty
                    ? Center(child: Text('Type to search teams...', style: TextStyle(color: BmbColors.textTertiary)))
                    : ListView.builder(
                        controller: sc, itemCount: results.length,
                        itemBuilder: (_, i) {
                          final team = results[i];
                          return ListTile(
                            leading: Icon(Icons.sports, color: BmbColors.blue, size: 20),
                            title: Text(team.name, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13)),
                            subtitle: Text(team.league, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                            onTap: () {
                              _matchupControllers[matchupIndex][teamSlot].text = team.name;
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                ),
              ]);
            },
          );
        });
      },
    );
  }

  void _showPhotoUploadDialog(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmbColors.midNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.photo_camera, color: BmbColors.blue, size: 22),
          const SizedBox(width: 8),
          Text('Upload Photo', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add a photo for "${_teamControllers[index].text}"', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOption(ctx, Icons.camera_alt, 'Take Photo', index),
                _photoOption(ctx, Icons.photo_library, 'From Photos', index),
              ],
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: BmbColors.textTertiary)))],
      ),
    );
  }

  Widget _photoOption(BuildContext ctx, IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        // Simulate permission request
        showDialog(
          context: context,
          builder: (ctx2) => AlertDialog(
            backgroundColor: BmbColors.midNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Allow Access', style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold)),
            content: Text('"Back My Bracket" would like to access your ${label.contains('Take') ? 'Camera' : 'Photos'}', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx2), child: Text("Don't Allow", style: TextStyle(color: BmbColors.textTertiary))),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx2);
                  setState(() {
                    if (index < _teamHasPhoto.length) _teamHasPhoto[index] = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Photo uploaded for ${_teamControllers[index].text}!'),
                    backgroundColor: BmbColors.midNavy, behavior: SnackBarBehavior.floating,
                  ));
                },
                style: ElevatedButton.styleFrom(backgroundColor: BmbColors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Allow'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
        child: Column(children: [
          Icon(icon, color: BmbColors.blue, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: BmbColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }

  // ─── STEP 3: ENTRY & TIE-BREAKER ──────────────────────────────────
  Widget _buildStep3Entry() {
    // ── VOTING BRACKETS: always free entry, no fee option ──
    final bool isVotingBracket = _bracketType == 'voting';
    if (isVotingBracket && !_isFreeEntry) {
      // Force free entry for voting brackets
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _isFreeEntry = true; _entryDonation = 0; });
      });
    }

    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isVotingBracket) ...[
          // Voting bracket: show free entry notice, no choice
          _guidedSection(
            label: '4',
            title: 'Entry Fee',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FREE to Join', style: TextStyle(color: const Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Voting brackets are always free. They\u2019re built for engagement \u2014 bars and hosts use them to drive participation, not collect fees.',
                          style: TextStyle(color: const Color(0xFF4CAF50).withValues(alpha: 0.8), fontSize: 12)),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 12),
              Text('You can still offer prizes (gift cards, merch, swag) to boost engagement!',
                  style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            ]),
          ),
        ] else ...[
          // Standard / Pick'Em: show entry fee choices
          _guidedSection(
            label: '4',
            title: 'Contribution Amount',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              Text('Would you like participants to donate credits to enter?', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              _choiceCard('Free to Enter', 'No credits required. Open to everyone!', Icons.lock_open, _isFreeEntry, () => setState(() => _isFreeEntry = true)),
              const SizedBox(height: 8),
              _choiceCard('Credits Entry Donation', 'Participants donate credits from their BMB Bucket to enter', Icons.savings, !_isFreeEntry, () => setState(() => _isFreeEntry = false)),
            ]),
          ),
        ],
        if (!_isFreeEntry) ...[
          const SizedBox(height: 16),
          _guidedSection(
            label: '4a',
            title: 'Donation Amount (Credits)',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [5, 10, 25, 50, 100, 250].map((amt) {
                final sel = _entryDonation == amt;
                return GestureDetector(
                  onTap: () => setState(() => _entryDonation = amt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: sel ? BmbColors.gold : BmbColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? BmbColors.gold : BmbColors.borderColor)),
                    child: Text('$amt credits', style: TextStyle(color: sel ? Colors.black : BmbColors.textPrimary, fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal, fontSize: 14)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2))),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: BmbColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Credits are deducted from the host AND players only when the tournament goes LIVE — not at save time.', style: TextStyle(color: BmbColors.gold, fontSize: 11))),
                ]),
              ),
            ]),
          ),
        ],
        // ─── GIVEAWAY SPINNER (available for ANY bracket — free or paid) ───
        const SizedBox(height: 20),
        _guidedSection(
          label: '4b',
          title: 'Giveaway Spinner',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(
              'Add a bonus giveaway drawing to your bracket \u2014 works on free and paid brackets.',
              style: TextStyle(color: BmbColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: BmbColors.cardGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _hasGiveaway ? BmbColors.gold.withValues(alpha: 0.5) : BmbColors.borderColor, width: _hasGiveaway ? 1.5 : 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.celebration, color: BmbColors.gold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Include Giveaway Spinner', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                            const SizedBox(height: 4),
                            Text(
                              'A fun spin-the-wheel drawing on the leaderboard after the tournament ends. '
                              'All participants are entered and random winners are drawn \u2014 '
                              'it\u2019s a promotional bonus giveaway, separate from the bracket prize.',
                              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _hasGiveaway,
                        onChanged: (v) => setState(() => _hasGiveaway = v),
                        activeThumbColor: BmbColors.gold,
                        activeTrackColor: BmbColors.gold.withValues(alpha: 0.3),
                        inactiveThumbColor: BmbColors.textTertiary,
                        inactiveTrackColor: BmbColors.borderColor,
                      ),
                    ],
                  ),
                  if (!_hasGiveaway) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BmbColors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: BmbColors.blue, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Toggle this ON to add a random giveaway spinner to your bracket. Winners receive bonus credits on top of any bracket prizes.',
                              style: TextStyle(color: BmbColors.blue, fontSize: 10, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
        if (_hasGiveaway) ...[
            const SizedBox(height: 16),
            _guidedSection(
              label: '4b-i',
              title: 'Number of Winners',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                Text('How many random winners will be drawn from the leaderboard?', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [1, 2, 3, 5].map((count) {
                  final sel = _giveawayWinnerCount == count;
                  return GestureDetector(
                    onTap: () => setState(() => _giveawayWinnerCount = count),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? BmbColors.gold : BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? BmbColors.gold : BmbColors.borderColor),
                      ),
                      child: Text('$count winner${count > 1 ? 's' : ''}', style: TextStyle(
                        color: sel ? Colors.black : BmbColors.textPrimary,
                        fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal, fontSize: 14)),
                    ),
                  );
                }).toList()),
              ]),
            ),
            const SizedBox(height: 16),
            _guidedSection(
              label: '4b-ii',
              title: 'Tokens Per Winner',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                Text('How many credits/tokens does each winner receive?', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [5, 10, 25, 50, 100, 250].map((amt) {
                  final sel = _giveawayTokensPerWinner == amt;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _giveawayTokensPerWinner = amt;
                      _giveawayTokensController.text = '$amt';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? BmbColors.successGreen : BmbColors.cardDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? BmbColors.successGreen : BmbColors.borderColor),
                      ),
                      child: Text('$amt credits', style: TextStyle(
                        color: sel ? Colors.white : BmbColors.textPrimary,
                        fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal, fontSize: 14)),
                    ),
                  );
                }).toList()),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.12), BmbColors.gold.withValues(alpha: 0.04)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(children: [
                    Icon(Icons.celebration, color: BmbColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Giveaway Summary', style: TextStyle(color: BmbColors.gold, fontSize: 13, fontWeight: BmbFontWeights.bold))),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Winners:', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                    Text('$_giveawayWinnerCount', style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Per Winner:', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                    Text('$_giveawayTokensPerWinner credits', style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                  ]),
                  const Divider(color: BmbColors.borderColor, height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Total Giveaway:', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                    Text('${_giveawayWinnerCount * _giveawayTokensPerWinner} credits', style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                  ]),
                ],
              ),
            ),
        ],
        // ─── TIE-BREAKER (NOT used by voting brackets) ───
        if (_bracketType != 'voting') ...[
          const SizedBox(height: 20),
          _guidedSection(
            label: '4c',
            title: 'Tie-Breaker Game',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: BmbColors.errorRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('REQUIRED', style: TextStyle(color: BmbColors.errorRed, fontSize: 8, fontWeight: BmbFontWeights.bold)),
              ),
              // Pick-Em: host selects from their matchup list
              // Standard/NoPicks: host selects from derived team matchups with checkboxes
              if (_bracketType == 'pickem' && _matchupControllers.isNotEmpty) ...[
                Text('Select which game will be used for the tie-breaker. Players will predict total combined points for that game.',
                    style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                ..._buildTieBreakerMatchupList(),
              ] else ...[
                Text('Select the game that will be used for the tie-breaker. Players predict total combined points for that game.',
                    style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                ..._buildStandardTieBreakerMatchupList(),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: BmbColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2))),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: BmbColors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Tie-breaker rule: Players predict total combined points for this game. Closest to actual total WITHOUT going over wins. If Player A picks 40 and Player B picks 50, and the actual is 46, Player A wins.', style: TextStyle(color: BmbColors.blue, fontSize: 11))),
                ]),
              ),
            ]),
          ),
        ],
        // ─── VOTING: no tie-breaker info ───
        if (_bracketType == 'voting') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF9C27B0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.how_to_vote, color: Color(0xFF9C27B0), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Voting brackets don\u2019t use a tie-breaker. The item with the most votes in each matchup advances. Simple majority wins.', style: TextStyle(color: const Color(0xFF9C27B0), fontSize: 11))),
            ]),
          ),
        ],
      ],
    );
  }

  // ─── TIE-BREAKER: MATCHUP SELECTOR (PICK-EM) ──────────────────────
  /// Builds a tappable list of the host's matchups for pick-em tie-breaker selection.
  List<Widget> _buildTieBreakerMatchupList() {
    return List.generate(_matchupControllers.length, (i) {
      final pair = _matchupControllers[i];
      final teamA = pair[0].text.trim().isEmpty ? 'Team A' : pair[0].text.trim();
      final teamB = pair[1].text.trim().isEmpty ? 'Team B' : pair[1].text.trim();
      final isSelected = _pickEmTieBreakerIndex == i;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _pickEmTieBreakerIndex = i;
              _tieBreakerController.text = '$teamA vs $teamB';
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected ? null : BmbColors.cardGradient,
              color: isSelected ? BmbColors.blue.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? BmbColors.blue : BmbColors.borderColor,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                // Game number badge
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BmbColors.blue.withValues(alpha: 0.2)
                        : BmbColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isSelected ? BmbColors.blue : BmbColors.gold,
                        fontSize: 12,
                        fontWeight: BmbFontWeights.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Matchup text
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(fontSize: (teamA.length + teamB.length) > 30 ? 10.0 : 12.0, color: BmbColors.textPrimary),
                      children: [
                        TextSpan(
                          text: teamA,
                          style: TextStyle(fontWeight: BmbFontWeights.semiBold),
                        ),
                        TextSpan(
                          text: '  @  ',
                          style: TextStyle(
                            color: BmbColors.gold,
                            fontWeight: BmbFontWeights.bold,
                            fontSize: 10,
                          ),
                        ),
                        TextSpan(
                          text: teamB,
                          style: TextStyle(fontWeight: BmbFontWeights.semiBold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Selection indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BmbColors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BmbColors.blue.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_score, color: BmbColors.blue, size: 14),
                        const SizedBox(width: 4),
                        Text('TIE-BREAKER', style: TextStyle(
                          color: BmbColors.blue, fontSize: 8,
                          fontWeight: BmbFontWeights.bold,
                        )),
                      ],
                    ),
                  )
                else
                  Icon(Icons.radio_button_off, color: BmbColors.textTertiary.withValues(alpha: 0.4), size: 20),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Build a list of matchups derived from the team list for standard brackets,
  /// each with a checkbox for tie-breaker selection.
  List<Widget> _buildStandardTieBreakerMatchupList() {
    final matchupCount = _teamControllers.length ~/ 2;
    if (matchupCount == 0) {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BmbColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: BmbColors.gold, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Add teams in Step 3 first to see matchups here.',
                style: TextStyle(color: BmbColors.gold, fontSize: 12))),
          ]),
        ),
      ];
    }

    return List.generate(matchupCount, (i) {
      final teamAIdx = i * 2;
      final teamBIdx = i * 2 + 1;
      final teamA = teamAIdx < _teamControllers.length && _teamControllers[teamAIdx].text.trim().isNotEmpty
          ? _teamControllers[teamAIdx].text.trim()
          : 'Team ${teamAIdx + 1}';
      final teamB = teamBIdx < _teamControllers.length && _teamControllers[teamBIdx].text.trim().isNotEmpty
          ? _teamControllers[teamBIdx].text.trim()
          : 'Team ${teamBIdx + 1}';
      final isSelected = _standardTieBreakerIndex == i;

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _standardTieBreakerIndex = isSelected ? null : i;
              _tieBreakerController.text = isSelected ? '' : '$teamA vs $teamB';
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected ? null : BmbColors.cardGradient,
              color: isSelected ? BmbColors.blue.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? BmbColors.blue : BmbColors.borderColor,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                // Checkbox
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? BmbColors.blue
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? BmbColors.blue : BmbColors.textTertiary.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 10),
                // Game number badge
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BmbColors.blue.withValues(alpha: 0.2)
                        : BmbColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isSelected ? BmbColors.blue : BmbColors.gold,
                        fontSize: 12,
                        fontWeight: BmbFontWeights.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Matchup text
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(fontSize: (teamA.length + teamB.length) > 30 ? 10.0 : 12.0, color: BmbColors.textPrimary),
                      children: [
                        TextSpan(
                          text: teamA,
                          style: TextStyle(fontWeight: BmbFontWeights.semiBold),
                        ),
                        TextSpan(
                          text: '  vs  ',
                          style: TextStyle(
                            color: BmbColors.gold,
                            fontWeight: BmbFontWeights.bold,
                            fontSize: 10,
                          ),
                        ),
                        TextSpan(
                          text: teamB,
                          style: TextStyle(fontWeight: BmbFontWeights.semiBold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Selection indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BmbColors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BmbColors.blue.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_score, color: BmbColors.blue, size: 14),
                        const SizedBox(width: 4),
                        Text('TIE-BREAKER', style: TextStyle(
                          color: BmbColors.blue, fontSize: 8,
                          fontWeight: BmbFontWeights.bold,
                        )),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ─── STEP 4: PRIZE ───────────────────────────────────────────────
  Widget _buildStep4Prize() {
    return Column(
      key: const ValueKey('step4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guidedSection(
          label: '5',
          title: 'Select Your Prize',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text('Choose a prize from the BMB Store, add a custom prize, raise money for charity, or skip.', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.savings, color: BmbColors.gold, size: 16),
              const SizedBox(width: 6),
              Text('BMB Bucket: $_userCredits credits', style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
            ]),
            const SizedBox(height: 16),
        _choiceCard('BMB Store Prize', 'Purchase a prize with your credits', Icons.store, _prizeType == 'store', () => setState(() => _prizeType = 'store')),
        const SizedBox(height: 8),
        // Shopify Product Prize
        GestureDetector(
          onTap: () => setState(() => _prizeType = 'shopify'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: _prizeType == 'shopify' ? null : BmbColors.cardGradient,
              color: _prizeType == 'shopify' ? BmbColors.gold.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _prizeType == 'shopify' ? BmbColors.gold : BmbColors.borderColor, width: _prizeType == 'shopify' ? 1.5 : 0.5),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag, color: BmbColors.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Shopify Product', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('NEW', style: TextStyle(color: BmbColors.gold, fontSize: 8, fontWeight: BmbFontWeights.bold)),
                    ),
                  ]),
                  Text('Send the winner a product from our Shopify store with their bracket picks printed on it', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                ]),
              ),
              if (_prizeType == 'shopify') const Icon(Icons.check_circle, color: BmbColors.gold, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        _choiceCard('Custom Prize', 'Describe your own prize', Icons.card_giftcard, _prizeType == 'custom', () => setState(() => _prizeType = 'custom')),
        const SizedBox(height: 8),
        // CHARITY QUICK LINK
        _charityPrizeCard(),
        const SizedBox(height: 8),
        _choiceCard('No Prize', 'Just for fun — bragging rights only!', Icons.sentiment_satisfied, _prizeType == 'none', () => setState(() => _prizeType = 'none')),
          ]),
        ),
        // Shopify product selector
        if (_prizeType == 'shopify') ...[
          const SizedBox(height: 20),
          _guidedSection(
            label: '5a',
            title: 'Browse Shopify Products',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.shopping_bag, color: BmbColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Text('BMB Shop', style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: BmbColors.successGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, color: BmbColors.successGreen, size: 10),
                        const SizedBox(width: 3),
                        Text('CONNECTED', style: TextStyle(color: BmbColors.successGreen, fontSize: 8, fontWeight: BmbFontWeights.bold)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text('Choose a product from the BMB Shop. The winner\'s bracket picks will be printed on the product and shipped directly to them!',
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.4)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Ensure Shopify is linked
                        if (!ShopifyService.isLinked) {
                          await ShopifyService.linkStore(
                            storeDomain: 'bmb-official.myshopify.com',
                            storefrontAccessToken: 'demo_token',
                          );
                        }
                        if (!mounted) return;
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ShopifyProductBrowserScreen(
                            bracketId: _nameController.text.trim(),
                            bracketName: _nameController.text.trim(),
                            picks: _bracketType == 'pickem'
                                ? _matchupControllers.expand((p) => [p[0].text.trim(), p[1].text.trim()]).toList()
                                : _teamControllers.map((c) => c.text.trim()).toList(),
                          ),
                        ));
                      },
                      icon: const Icon(Icons.shopping_bag, size: 16),
                      label: Text('Browse Products', style: TextStyle(fontWeight: BmbFontWeights.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.info_outline, color: BmbColors.textTertiary, size: 12),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Products with the CUSTOM badge support bracket picks printing', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10))),
                  ]),
                ]),
              ),
            ]),
          ),
        ],

        // Store prizes
        if (_prizeType == 'store') ...[
          const SizedBox(height: 20),
          _guidedSection(
            label: '5a',
            title: 'BMB Store Prizes',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              ...BmbStorePrize.storePrizes.map((p) => _storePrizeCard(p)),
            ]),
          ),
        ],
        // Custom prize
        if (_prizeType == 'custom') ...[
          const SizedBox(height: 20),
          _guidedSection(
            label: '5a',
            title: 'Describe Your Prize',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              TextField(
            controller: _customPrizeController, maxLines: 3,
            style: TextStyle(color: BmbColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. "Autographed football from Ahmad Merritt, former Chicago Bear"',
              hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
              filled: true, fillColor: BmbColors.cardDark,
              suffixIcon: IconButton(
                icon: Icon(
                  _isListening && _listeningFieldId == 'customPrize' ? Icons.stop_circle : Icons.mic,
                  color: _isListening && _listeningFieldId == 'customPrize' ? BmbColors.errorRed : BmbColors.blue,
                ),
                onPressed: () => _isListening && _listeningFieldId == 'customPrize'
                    ? _stopVoiceInput()
                    : _startVoiceInput(_customPrizeController, 'customPrize'),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.blue)),
            ),
          ),
            ]),
          ),
        ],
        // Charity details — "Play for Their Charity" flow
        if (_prizeType == 'charity') ...[
          const SizedBox(height: 20),
          _guidedSection(
            label: '5a',
            title: 'Charity Bracket Setup',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              // ── RAISE GOAL IN DOLLARS ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BmbColors.successGreen.withValues(alpha: 0.08), BmbColors.cardGradientEnd]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.flag, color: BmbColors.successGreen, size: 18),
                    const SizedBox(width: 8),
                    Text('Raise Goal', style: TextStyle(color: BmbColors.successGreen, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text('How much do you want to raise? Enter a dollar amount and the app will show the credit equivalent.',
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.4)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('\$', style: TextStyle(color: BmbColors.gold, fontSize: 24, fontWeight: BmbFontWeights.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _charityRaiseGoalController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: BmbColors.textPrimary, fontSize: 20, fontWeight: BmbFontWeights.bold),
                        decoration: InputDecoration(
                          hintText: '450',
                          hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 20),
                          filled: true, fillColor: BmbColors.cardDark,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: BmbColors.successGreen)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) {
                          final dollars = double.tryParse(v) ?? 0;
                          setState(() => _charityRaiseGoalDollars = dollars);
                        },
                      ),
                    ),
                  ]),
                  if (_charityRaiseGoalDollars > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BmbColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.savings, color: BmbColors.gold, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '= ${(_charityRaiseGoalDollars / 0.10).round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} BMB Credits',
                          style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold),
                        )),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              // ── MINIMUM CONTRIBUTION ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BmbColors.borderColor),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.toll, color: BmbColors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text('Minimum Contribution', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Set the minimum credits a player must contribute to enter. Players can donate MORE — there is no maximum.',
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.4)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [5, 10, 20, 50, 100, 150, 250].map((amt) {
                    final sel = _charityMinContribution == amt;
                    return GestureDetector(
                      onTap: () => setState(() => _charityMinContribution = amt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? BmbColors.blue : BmbColors.cardDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? BmbColors.blue : BmbColors.borderColor),
                        ),
                        child: Text('$amt credits', style: TextStyle(
                          color: sel ? Colors.white : BmbColors.textPrimary,
                          fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal, fontSize: 13)),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 8),
                  Text('Min: \$${(_charityMinContribution * 0.10).toStringAsFixed(2)} | Players choose any amount \u2265 $_charityMinContribution credits',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
                ]),
              ),
              const SizedBox(height: 16),
              // ── HOW IT WORKS ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [BmbColors.successGreen.withValues(alpha: 0.06), BmbColors.gold.withValues(alpha: 0.04)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: BmbColors.successGreen, size: 16),
                    const SizedBox(width: 6),
                    Text('How "Play for Their Charity" Works', style: TextStyle(color: BmbColors.successGreen, fontSize: 12, fontWeight: BmbFontWeights.bold)),
                  ]),
                  const SizedBox(height: 10),
                  _charityFlowStep('1', 'Players join and contribute credits (min $_charityMinContribution). The app shows goal progress.'),
                  _charityFlowStep('2', 'All contributions go into a charity pot.'),
                  _charityFlowStep('3', 'When the winner is crowned, they select a charity from our partner list.'),
                  _charityFlowStep('4', 'The full pot is donated to the chosen charity via Tremendous.'),
                  const SizedBox(height: 8),
                  Text('Credits NEVER go to the winner\u2019s personal account \u2014 they go directly to charity.',
                      style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: BmbFontWeights.semiBold, fontStyle: FontStyle.italic)),
                ]),
              ),
              const SizedBox(height: 12),
              // ── CHARITY SUMMARY ──
              if (_charityRaiseGoalDollars > 0) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [BmbColors.gold.withValues(alpha: 0.12), BmbColors.gold.withValues(alpha: 0.04)]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Icon(Icons.auto_awesome, color: BmbColors.gold, size: 16),
                      const SizedBox(width: 6),
                      Text('Charity Bracket Summary', style: TextStyle(color: BmbColors.gold, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                    ]),
                    const SizedBox(height: 10),
                    _summaryRow('Raise Goal', '\$${_charityRaiseGoalDollars.toStringAsFixed(0)} (${(_charityRaiseGoalDollars / 0.10).round()} credits)'),
                    _summaryRow('Min Contribution', '$_charityMinContribution credits (\$${(_charityMinContribution * 0.10).toStringAsFixed(2)})'),
                    _summaryRow('Winner Gets', 'Picks a charity (no personal credits)'),
                  ]),
                ),
              ],

            ]),
          ),
        ],

        // ═══════════════════════════════════════════════════════════
        //  CUSTOM BONUS REWARDS — the "WAIT, REALLY?!" factor
        // ═══════════════════════════════════════════════════════════
        const SizedBox(height: 28),
        _buildCustomRewardsBuilder(),
      ],
    );
  }

  // ─── CUSTOM BONUS REWARDS BUILDER ─────────────────────────────────
  Widget _buildCustomRewardsBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _stepLabel('5b'),
            Icon(Icons.auto_awesome, color: BmbColors.gold, size: 18),
            const SizedBox(width: 6),
            Text('BONUS REWARDS',
                style: TextStyle(
                    color: BmbColors.gold,
                    fontSize: 14,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 0.8)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('OPTIONAL',
                  style: TextStyle(
                      color: const Color(0xFFFF6B35),
                      fontSize: 8,
                      fontWeight: BmbFontWeights.bold)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
            'Add exciting real-world prizes that make people go "WAIT, I could WIN that?!"',
            style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 14),

        // Existing rewards
        ..._customRewards.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withValues(alpha: 0.08),
                  BmbColors.gold.withValues(alpha: 0.04),
                  BmbColors.cardGradientEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: BmbColors.gold.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                        _rewardIconTypeEmoji(r.iconType),
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          style: TextStyle(
                              color: BmbColors.textPrimary,
                              fontSize: 13,
                              fontWeight: BmbFontWeights.semiBold)),
                      if (r.description.isNotEmpty)
                        Text(r.description,
                            style: TextStyle(
                                color: BmbColors.textTertiary,
                                fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      color: BmbColors.errorRed.withValues(alpha: 0.7),
                      size: 18),
                  onPressed: () => setState(() => _customRewards.removeAt(i)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),

        // Add reward button
        if (_customRewards.length < 5)
          GestureDetector(
            onTap: _showAddRewardDialog,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: BmbColors.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: BmbColors.gold.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      color: BmbColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Text('Add Bonus Reward',
                      style: TextStyle(
                          color: BmbColors.gold,
                          fontSize: 14,
                          fontWeight: BmbFontWeights.semiBold)),
                ],
              ),
            ),
          )
        else
          Text('Maximum 5 bonus rewards reached',
              style: TextStyle(
                  color: BmbColors.textTertiary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic)),

        // Quick-add popular suggestions
        if (_customRewards.length < 5) ...[          const SizedBox(height: 12),
          Text('Quick Add Popular Rewards:',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickAddRewards
                .where((qa) => !_customRewards.any((cr) => cr.name == qa.name))
                .take(6)
                .map((qa) {
              return GestureDetector(
                onTap: () => setState(() => _customRewards.add(qa)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BmbColors.borderColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: BmbColors.borderColor, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_rewardIconTypeEmoji(qa.iconType),
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(qa.name,
                            style: TextStyle(
                                color: BmbColors.textPrimary,
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.add, color: BmbColors.gold, size: 14),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  void _showAddRewardDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    _RewardIconType selectedType = _RewardIconType.gift;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          backgroundColor: BmbColors.midNavy,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add Bonus Reward',
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 18,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
                const SizedBox(height: 16),
                // Reward type selector
                Text('Choose Type:',
                    style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _RewardIconType.values.map((type) {
                    final sel = selectedType == type;
                    return GestureDetector(
                      onTap: () => setD(() => selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? BmbColors.gold.withValues(alpha: 0.15)
                              : BmbColors.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: sel
                                  ? BmbColors.gold
                                  : BmbColors.borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_rewardIconTypeEmoji(type),
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(_iconTypeLabel(type),
                                style: TextStyle(
                                    color: sel
                                        ? BmbColors.gold
                                        : BmbColors.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(
                      color: BmbColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Reward name (e.g. Rare Air Jordan 4s)',
                    hintStyle: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: BmbColors.cardDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: BmbColors.borderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: BmbColors.borderColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: BmbColors.gold)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: TextStyle(
                      color: BmbColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: BmbColors.cardDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: BmbColors.borderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: BmbColors.borderColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: BmbColors.gold)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BmbColors.textSecondary,
                          side: const BorderSide(
                              color: BmbColors.borderColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          setState(() {
                            _customRewards.add(_EditableReward(
                              name: name,
                              description: descCtrl.text.trim(),
                              iconType: selectedType,
                            ));
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BmbColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Add',
                            style: TextStyle(
                                fontWeight: BmbFontWeights.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _rewardIconTypeEmoji(_RewardIconType type) {
    switch (type) {
      case _RewardIconType.dinner: return '\u{1F37D}\u{FE0F}';
      case _RewardIconType.sneakers: return '\u{1F45F}';
      case _RewardIconType.backpack: return '\u{1F392}';
      case _RewardIconType.gift: return '\u{1F381}';
      case _RewardIconType.jersey: return '\u{1F3C0}';
      case _RewardIconType.ticket: return '\u{1F3DF}\u{FE0F}';
      case _RewardIconType.tech: return '\u{1F3A7}';
      case _RewardIconType.experience: return '\u2B50';
      case _RewardIconType.trophy: return '\u{1F3C6}';
      case _RewardIconType.merch: return '\u{1F6CD}\u{FE0F}';
    }
  }

  String _iconTypeLabel(_RewardIconType type) {
    switch (type) {
      case _RewardIconType.dinner: return 'Dinner';
      case _RewardIconType.sneakers: return 'Sneakers';
      case _RewardIconType.backpack: return 'Backpack';
      case _RewardIconType.gift: return 'Gift';
      case _RewardIconType.jersey: return 'Jersey';
      case _RewardIconType.ticket: return 'Tickets';
      case _RewardIconType.tech: return 'Tech';
      case _RewardIconType.experience: return 'Experience';
      case _RewardIconType.trophy: return 'Trophy';
      case _RewardIconType.merch: return 'Merch';
    }
  }

  static final _quickAddRewards = [
    _EditableReward(name: 'Dinner with a Local Celebrity', iconType: _RewardIconType.dinner),
    _EditableReward(name: 'Rare Air Jordans', iconType: _RewardIconType.sneakers),
    _EditableReward(name: 'Patagonia Backpack', iconType: _RewardIconType.backpack),
    _EditableReward(name: 'Signed Team Jersey', iconType: _RewardIconType.jersey),
    _EditableReward(name: '\u002450 Gift Card', iconType: _RewardIconType.gift),
    _EditableReward(name: 'VIP Game Day Experience', iconType: _RewardIconType.experience),
    _EditableReward(name: 'Apple AirPods', iconType: _RewardIconType.tech),
    _EditableReward(name: 'Yeti Tumbler', iconType: _RewardIconType.gift),
    _EditableReward(name: 'Custom BMB Hoodie', iconType: _RewardIconType.merch),
    _EditableReward(name: 'Courtside Tickets', iconType: _RewardIconType.ticket),
  ];

  Widget _charityPrizeCard() {
    final sel = _prizeType == 'charity';
    return GestureDetector(
      onTap: () => setState(() => _prizeType = 'charity'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: sel ? null : BmbColors.cardGradient,
          color: sel ? BmbColors.successGreen.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? BmbColors.successGreen : BmbColors.borderColor, width: sel ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.volunteer_activism, color: BmbColors.successGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Play for Their Charity', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: BmbColors.successGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text('NEW', style: TextStyle(color: BmbColors.successGreen, fontSize: 8, fontWeight: BmbFontWeights.bold)),
                    ),
                  ]),
                  Text('Winner chooses a charity for the pot. Credits never go to winner.', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
            if (sel) const Icon(Icons.check_circle, color: BmbColors.successGreen, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _storePrizeCard(BmbStorePrize prize) {
    final sel = _selectedStorePrize?.id == prize.id;
    final canAfford = _userCredits >= prize.cost;
    return GestureDetector(
      onTap: canAfford ? () => setState(() => _selectedStorePrize = prize) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: sel ? null : BmbColors.cardGradient,
          color: sel ? BmbColors.gold.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? BmbColors.gold : canAfford ? BmbColors.borderColor : BmbColors.errorRed.withValues(alpha: 0.3), width: sel ? 1.5 : 0.5),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: sel ? BmbColors.gold.withValues(alpha: 0.2) : BmbColors.borderColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
            child: Icon(_prizeIcon(prize.iconName), color: sel ? BmbColors.gold : BmbColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prize.name, style: TextStyle(color: canAfford ? BmbColors.textPrimary : BmbColors.textTertiary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
            Text(prize.description, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
          ])),
          Column(children: [
            Text('${prize.cost}', style: TextStyle(color: canAfford ? BmbColors.gold : BmbColors.errorRed, fontWeight: BmbFontWeights.bold, fontSize: 14)),
            Text('credits', style: TextStyle(color: BmbColors.textTertiary, fontSize: 10)),
          ]),
          if (sel) ...[const SizedBox(width: 8), Icon(Icons.check_circle, color: BmbColors.gold, size: 20)],
        ]),
      ),
    );
  }

  // ─── STEP 5: AUTO HOST & GO LIVE ──────────────────────────────────
  Widget _buildStep5Status() {
    return Column(
      key: const ValueKey('step5'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status flow explainer
        _guidedSection(
          label: '6',
          title: 'Tournament Status Flow',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: BmbColors.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BmbColors.borderColor, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your tournament will automatically progress through these statuses:',
                      style: TextStyle(color: BmbColors.textSecondary, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 12),
                  _statusFlowItem('Saved', 'Bracket is saved to your profile. You can edit and delete it.', Icons.bookmark, Colors.grey, true),
                  _statusFlowArrow(),
                  _statusFlowItem('Upcoming', 'Share to social media. Players can view and join your bracket.', Icons.event, BmbColors.blue, false),
                  _statusFlowArrow(),
                  _statusFlowItem('Live', 'Players are notified. Picks open. Credits are deducted from host & players.', Icons.play_circle_filled, BmbColors.successGreen, false),
                  _statusFlowArrow(),
                  _statusFlowItem('In Progress', 'First game started. Joining is locked. Scoring and leaderboard active.', Icons.sports_score, BmbColors.gold, false),
                  _statusFlowArrow(),
                  _statusFlowItem('Done', 'All games complete. Tie-breaker determines winner. Prize awarded.', Icons.emoji_events, const Color(0xFF00BCD4), false),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ─── GO LIVE DATE (REQUIRED) ───
        _guidedSection(
          label: '6a',
          title: 'Go Live Date',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: BmbColors.errorRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text('REQUIRED', style: TextStyle(color: BmbColors.errorRed, fontSize: 8, fontWeight: BmbFontWeights.bold)),
            ),
            Text('When should your tournament go LIVE? Credits are deducted at this time.',
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _scheduledLiveDate ?? DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: BmbColors.blue, surface: BmbColors.midNavy)),
                    child: child!,
                  ),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _scheduledLiveTime ?? const TimeOfDay(hour: 12, minute: 0),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: BmbColors.blue, surface: BmbColors.midNavy)),
                      child: child!,
                    ),
                  );
                  setState(() {
                    _scheduledLiveDate = date;
                    _scheduledLiveTime = time ?? const TimeOfDay(hour: 12, minute: 0);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _scheduledLiveDate != null ? BmbColors.blue : BmbColors.borderColor,
                    width: _scheduledLiveDate != null ? 1.5 : 0.5,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: (_scheduledLiveDate != null ? BmbColors.blue : BmbColors.textSecondary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_today,
                        color: _scheduledLiveDate != null ? BmbColors.blue : BmbColors.textSecondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _scheduledLiveDate != null
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Go Live Date:', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                            Text(
                              '${_scheduledLiveDate!.month}/${_scheduledLiveDate!.day}/${_scheduledLiveDate!.year} at ${_scheduledLiveTime?.format(context) ?? '12:00 PM'}',
                              style: TextStyle(color: BmbColors.blue, fontSize: 14, fontWeight: BmbFontWeights.semiBold),
                            ),
                          ])
                        : Text('Tap to set your Go Live date & time', style: TextStyle(color: BmbColors.textTertiary, fontSize: 13)),
                  ),
                  if (_scheduledLiveDate != null)
                    GestureDetector(
                      onTap: () => setState(() { _scheduledLiveDate = null; _scheduledLiveTime = null; }),
                      child: Icon(Icons.close, color: BmbColors.errorRed, size: 18),
                    )
                  else
                    Icon(Icons.chevron_right, color: BmbColors.textTertiary, size: 20),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ─── TOURNAMENT VISIBILITY ───
        _guidedSection(
          label: '6b',
          title: 'Tournament Visibility',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text('Control who can see and find your tournament.',
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
        // Public / Private toggle cards
        GestureDetector(
          onTap: () => setState(() { _isPublic = true; _addToBracketBoard = true; }),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: _isPublic ? null : BmbColors.cardGradient,
              color: _isPublic ? BmbColors.blue.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isPublic ? BmbColors.blue : BmbColors.borderColor,
                width: _isPublic ? 1.5 : 0.5,
              ),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (_isPublic ? BmbColors.blue : BmbColors.textSecondary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.public, color: _isPublic ? BmbColors.blue : BmbColors.textSecondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Public Tournament', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 4),
                  Text('Anyone can discover, view, and join your tournament. Visible on the Bracket Board.',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.4)),
                ]),
              ),
              if (_isPublic) const Icon(Icons.check_circle, color: BmbColors.blue, size: 22),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() { _isPublic = false; _addToBracketBoard = false; }),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: !_isPublic ? null : BmbColors.cardGradient,
              color: !_isPublic ? const Color(0xFF9C27B0).withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !_isPublic ? const Color(0xFF9C27B0) : BmbColors.borderColor,
                width: !_isPublic ? 1.5 : 0.5,
              ),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (!_isPublic ? const Color(0xFF9C27B0) : BmbColors.textSecondary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lock, color: !_isPublic ? const Color(0xFF9C27B0) : BmbColors.textSecondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Private Tournament', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('INVITE ONLY', style: TextStyle(color: const Color(0xFF9C27B0), fontSize: 7, fontWeight: BmbFontWeights.bold, letterSpacing: 0.5)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('Only you and players who receive your invite link can see this tournament. Hidden from the Bracket Board.',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.4)),
                ]),
              ),
              if (!_isPublic) Icon(Icons.check_circle, color: const Color(0xFF9C27B0), size: 22),
            ]),
          ),
        ),
        // Add to Bracket Board toggle (only for public)
        if (_isPublic) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _addToBracketBoard = !_addToBracketBoard),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: BmbColors.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _addToBracketBoard ? BmbColors.successGreen : BmbColors.borderColor,
                  width: _addToBracketBoard ? 1.5 : 0.5,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (_addToBracketBoard ? BmbColors.successGreen : BmbColors.textSecondary).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.dashboard_customize,
                      color: _addToBracketBoard ? BmbColors.successGreen : BmbColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add to Bracket Board', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                    const SizedBox(height: 4),
                    Text(
                      _addToBracketBoard
                          ? 'Your tournament will appear on the public Bracket Board for everyone to discover.'
                          : 'Tournament is public but won\'t appear on the Bracket Board. Share via link only.',
                      style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.4),
                    ),
                  ]),
                ),
                Switch(
                  value: _addToBracketBoard,
                  onChanged: (v) => setState(() => _addToBracketBoard = v),
                  activeTrackColor: BmbColors.successGreen.withValues(alpha: 0.5),
                  activeThumbColor: BmbColors.successGreen,
                  inactiveThumbColor: BmbColors.textTertiary,
                  inactiveTrackColor: BmbColors.borderColor,
                ),
              ]),
            ),
          ),
        ],
        if (!_isPublic) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.link, color: Color(0xFF9C27B0), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Private tournaments can only be joined via a share link. After saving, use the Share button to invite players.',
                style: TextStyle(color: const Color(0xFF9C27B0), fontSize: 11, height: 1.4),
              )),
            ]),
          ),
        ],
          ]),
        ),
        const SizedBox(height: 24),

        // ─── MINIMUM PLAYERS ───
        _guidedSection(
          label: '6c',
          title: 'Minimum Players',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text('How many players must join before the tournament can go Live?',
                style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [2, 4, 8, 16, 32].map((count) {
              final sel = _minPlayers == count;
              return GestureDetector(
                onTap: () => setState(() { _minPlayers = count; _minPlayersController.text = '$count'; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? BmbColors.blue : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? BmbColors.blue : BmbColors.borderColor),
                  ),
                  child: Text(count >= 32 ? '$count+' : '$count', style: TextStyle(
                    color: sel ? Colors.white : BmbColors.textPrimary,
                    fontWeight: sel ? BmbFontWeights.bold : FontWeight.normal, fontSize: 14)),
                ),
              );
            }).toList()),
          ]),
        ),
        const SizedBox(height: 24),

        // ─── AUTO HOST TOGGLE ───
        _guidedSection(
          label: '6d',
          title: 'Auto Host',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _autoHost = !_autoHost),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: _autoHost ? null : BmbColors.cardGradient,
              color: _autoHost ? BmbColors.successGreen.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _autoHost ? BmbColors.successGreen : BmbColors.borderColor,
                width: _autoHost ? 1.5 : 0.5,
              ),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (_autoHost ? BmbColors.successGreen : BmbColors.textSecondary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.smart_toy, color: _autoHost ? BmbColors.successGreen : BmbColors.textSecondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Auto Host Mode', style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
                  const SizedBox(height: 4),
                  Text(
                    _autoHost
                        ? 'ON - When $_minPlayers+ players have joined by your Go Live date, the tournament will automatically switch to LIVE.'
                        : 'OFF - You will manually move the tournament to LIVE when ready.',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, height: 1.4),
                  ),
                ]),
              ),
              Switch(
                value: _autoHost,
                onChanged: (v) => setState(() => _autoHost = v),
                activeTrackColor: BmbColors.successGreen.withValues(alpha: 0.5),
                activeThumbColor: BmbColors.successGreen,
                inactiveThumbColor: BmbColors.textTertiary,
                inactiveTrackColor: BmbColors.borderColor,
              ),
            ]),
          ),
        ),
        if (_autoHost) ...[          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BmbColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: BmbColors.successGreen, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Auto Host will:\n'
                '1. Auto-advance to LIVE when $_minPlayers players join by the Go Live date\n'
                '2. Deduct credits from host & all joined players at go-live\n'
                '3. Send in-app notifications to all joined players\n'
                '4. Lock joining once the first game starts (In Progress)',
                style: TextStyle(color: BmbColors.successGreen, fontSize: 11, height: 1.5),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        // Credit deduction timing reminder
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: BmbColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: BmbColors.gold, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Credits are deducted from the host AND joined players only when the tournament goes LIVE. '
              'If you delete a saved bracket before it goes live, no one is charged.',
              style: TextStyle(color: BmbColors.gold, fontSize: 11, height: 1.4),
            )),
          ]),
        ),
          ]),
        ),
      ],
    );
  }

  Widget _statusFlowItem(String label, String desc, IconData icon, Color color, bool isCurrent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isCurrent ? 0.2 : 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: isCurrent ? 0.8 : 0.3)),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: BmbFontWeights.bold)),
            Text(desc, style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, height: 1.3)),
          ]),
        ),
      ],
    );
  }

  Widget _statusFlowArrow() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      child: Icon(Icons.arrow_downward, color: BmbColors.textTertiary.withValues(alpha: 0.4), size: 14),
    );
  }

  // ─── STEP 6: CONFIRM ─────────────────────────────────────────────
  Widget _buildStep6Confirm() {
    final isPickEm = _bracketType == 'pickem';
    final isVoting = _bracketType == 'voting';
    final String templateName;
    final String sport;
    if (isPickEm) {
      templateName = _pickEmSportType == 'NFL' && _pickEmNflWeek != null
          ? 'NFL Week $_pickEmNflWeek'
          : '$_pickEmSportType (${_matchupControllers.length} matchups)';
      sport = _pickEmSportType;
    } else if (isVoting && _selectedVotingTemplate != null) {
      templateName = _selectedVotingTemplate!.name;
      sport = 'Voting';
    } else {
      templateName = _isCustomSize
          ? (_customTeamCount == 2 ? '1v1 Head-to-Head' : 'Custom ($_customTeamCount items)')
          : (_selectedTemplate?.name ?? 'Unknown');
      sport = _isCustomSize ? 'Custom' : (_selectedTemplate?.sport ?? 'Custom');
    }
    final typeLabels = {'standard': 'Standard Bracket', 'voting': 'Voting Bracket', 'pickem': 'Pick \'Em (Single Round)', 'nopicks': 'No Picks'};

    return Column(
      key: const ValueKey('step6'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _guidedSection(label: '7', title: _isEditMode ? 'Confirm Changes' : 'Confirm Your Bracket', child: const SizedBox(height: 4)),
        const SizedBox(height: 16),
        _confirmRow('Bracket Type', typeLabels[_bracketType] ?? _bracketType),
        _confirmRow('Bracket Name', _nameController.text.trim()),
        _confirmRow('Template', templateName),
        _confirmRow('Sport', sport),
        if (isPickEm)
          _confirmRow('Matchups', '${_matchupControllers.length}')
        else
          _confirmRow(isVoting ? 'Items' : 'Teams', _teamCount == 2 ? '2 (1v1)' : '$_teamCount'),
        _confirmRow('Contribution', _isFreeEntry ? 'Free to Enter' : '$_entryDonation credits'),
        if (_hasGiveaway) ...[
          _confirmRow('Giveaway', '$_giveawayWinnerCount winner${_giveawayWinnerCount > 1 ? 's' : ''} \u00d7 $_giveawayTokensPerWinner credits'),
          _confirmRow('Total Giveaway', '${_giveawayWinnerCount * _giveawayTokensPerWinner} credits'),
        ],
        _confirmRow('Reward', _prizeLabel()),
        if (_customRewards.isNotEmpty)
          _confirmRow('Bonus Rewards', _customRewards.map((r) => r.name).join(', ')),
        _confirmRow('Status', _isEditMode ? '${widget.editBracket!.statusLabel} (editing)' : 'Saved (auto-progresses)'),
        if (!isVoting)
          _confirmRow('Tie-Breaker', _tieBreakerController.text.trim()),
        _confirmRow('Go-Live', _scheduledLiveDate != null
            ? '${_scheduledLiveDate!.month}/${_scheduledLiveDate!.day}/${_scheduledLiveDate!.year} at ${_scheduledLiveTime?.format(context) ?? '12:00 PM'}'
            : 'Not set'),
        _confirmRow('Min Players', '$_minPlayers'),
        _confirmRow('Auto Host', _autoHost ? 'ON' : 'OFF'),
        _confirmRow('Visibility', _isPublic ? 'Public' : 'Private (Invite Only)'),
        _confirmRow('Bracket Board', _addToBracketBoard ? 'Listed' : 'Not Listed'),
        const SizedBox(height: 20),
        // Team / Matchup preview
        if (isPickEm)
          _buildPickEmConfirmPreview()
        else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Team Preview', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _teamControllers.take(16).map((c) {
              final seed = BracketTemplate.parseSeed(c.text);
              final displayName = c.text.replaceFirst(RegExp(r'^\(\d+\)\s*'), '');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: BmbColors.cardDark, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (seed != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: BmbColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('$seed', style: TextStyle(color: BmbColors.gold, fontSize: 9, fontWeight: BmbFontWeights.bold)),
                    ),
                    const SizedBox(width: 4),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(displayName, style: TextStyle(color: BmbColors.textSecondary, fontSize: displayName.length > 18 ? 9.0 : 11.0), overflow: TextOverflow.ellipsis),
                  ),
                ]),
              );
            }).toList()),
            if (_teamControllers.length > 16) Padding(padding: const EdgeInsets.only(top: 6), child: Text('+ ${_teamControllers.length - 16} more teams', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11))),
          ]),
        ),
        const SizedBox(height: 16),
        // Credit deduction timing info for paid brackets
        if (!_isFreeEntry && _entryDonation > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.savings, color: BmbColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Text('Credit Deduction at Go Live', style: TextStyle(color: BmbColors.gold, fontSize: 13, fontWeight: BmbFontWeights.bold)),
                ]),
                const SizedBox(height: 8),
                Text('$_entryDonation credits will be deducted from your BMB Bucket AND each joined player when the tournament goes LIVE. No credits are charged at save time.',
                    style: TextStyle(color: BmbColors.gold.withValues(alpha: 0.9), fontSize: 11, height: 1.4)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('Your Bucket: ', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
                    Text('${_bucketBalance.toInt()} credits', style: TextStyle(
                      color: _bucketBalance >= _entryDonation ? BmbColors.successGreen : BmbColors.gold,
                      fontSize: 11, fontWeight: BmbFontWeights.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Fail-safe: Delete a saved bracket before it goes live and no one is charged.',
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_isBmbPlus)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BmbColors.successGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.info_outline, color: BmbColors.successGreen, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Once saved, your bracket will appear on your profile. Prize credits are awarded to the winner only after you confirm the final results.', style: TextStyle(color: BmbColors.successGreen, fontSize: 11))),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.workspace_premium, color: BmbColors.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('BMB+ membership is required to save and share brackets with friends. Upgrade to unlock hosting!', style: TextStyle(color: BmbColors.gold, fontSize: 11))),
            ]),
          ),
      ],
    );
  }

  /// Pick-Em matchup preview on the Confirm step
  Widget _buildPickEmConfirmPreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: BmbColors.cardGradient, borderRadius: BorderRadius.circular(12), border: Border.all(color: BmbColors.borderColor, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Matchup Preview', style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text('${_matchupControllers.length} games', style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        ...List.generate(
          _matchupControllers.length > 10 ? 10 : _matchupControllers.length,
          (i) {
            final pair = _matchupControllers[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 24, child: Text('${i + 1}.', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11, fontWeight: BmbFontWeights.semiBold))),
                Expanded(child: Text(pair[0].text.trim(), style: TextStyle(color: BmbColors.textPrimary, fontSize: pair[0].text.trim().length > 18 ? 9.0 : 11.0), overflow: TextOverflow.ellipsis, maxLines: 2)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(_isSportsPickEm ? '@' : 'vs', style: TextStyle(color: BmbColors.gold, fontSize: 10, fontWeight: BmbFontWeights.bold)),
                ),
                Expanded(child: Text(pair[1].text.trim(), style: TextStyle(color: BmbColors.textPrimary, fontSize: pair[1].text.trim().length > 18 ? 9.0 : 11.0), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, maxLines: 2)),
              ]),
            );
          },
        ),
        if (_matchupControllers.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('+ ${_matchupControllers.length - 10} more matchups', style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: BmbColors.textTertiary, fontSize: 13))),
        Expanded(child: Text(value, style: TextStyle(color: BmbColors.textPrimary, fontSize: 13, fontWeight: BmbFontWeights.semiBold))),
      ]),
    );
  }

  String _prizeLabel() {
    if (_prizeType == 'store' && _selectedStorePrize != null) return '${_selectedStorePrize!.name} (\$${_selectedStorePrize!.cost} credits)';
    if (_prizeType == 'custom') { final txt = _customPrizeController.text.trim(); return txt.isEmpty ? 'Custom (not described)' : txt; }
    if (_prizeType == 'charity') { return 'Play for Their Charity'; }
    return 'No Prize (bragging rights)';
  }



  // ─── SHARED HELPERS ──────────────────────────────────────────────

  // ── HOLOGRAM GUIDE ASSISTANT ────────────────────────────────────
  /// Returns a contextual hint message for the current step + active labels.
  /// Uses the companion's personality if one is selected.
  String get _guideHint {
    final persona = CompanionService.instance.selectedCompanion;
    if (persona != null) {
      final msgs = persona.bracketGuideMessages;
      final msg = msgs[_currentStep];
      if (msg != null) return msg;
    }
    // Fallback to generic messages
    final labels = _activeLabels;
    switch (_currentStep) {
      case 0:
        return 'Hey! Pick a bracket type to get started. Standard is most popular!';
      case 1:
        if (labels.contains('2')) return 'Give your bracket a name! Something catchy works best.';
        if (_bracketType == 'pickem') {
          if (labels.contains('2b')) return 'Select an NFL week to auto-load matchups.';
          return 'Choose your sport type above, then continue!';
        }
        if (_bracketType == 'voting') {
          if (labels.contains('2c') || labels.contains('2d')) {
            return 'Pick a template or build your own voting bracket.';
          }
          return 'Looking good! Hit Continue when ready.';
        }
        if (labels.contains('2a') || labels.contains('2b')) {
          return 'Now choose a tournament template, or build a custom size.';
        }
        return 'Nice name! Hit Continue to move on.';
      case 2:
        if (labels.contains('3')) {
          return _bracketType == 'pickem'
              ? 'Fill in your matchup teams. Tap "TBD" to auto-fill if needed!'
              : 'Enter team names. You can use the search icon to find real teams!';
        }
        return 'Teams look good! Continue when ready.';
      case 3:
        if (labels.contains('4c')) {
          return 'Scroll down! Set a tie-breaker game — this is required.';
        }
        return 'Choose free or paid entry at the top, then scroll down for giveaway & tie-breaker.';
      case 4:
        if (labels.contains('5a')) {
          return 'Nice choice! Now fill in the details for your prize below.';
        }
        if (labels.contains('5')) {
          return 'Pick a prize type for the winner! Choose from store, custom, charity, or none.';
        }
        return 'Prize is set! Add bonus rewards or continue when ready.';
      case 5:
        if (labels.contains('6a')) {
          return 'Set your Go Live date! This is when the tournament opens.';
        }
        if (labels.contains('6b')) {
          return 'Date is set! Now choose Public or Private visibility.';
        }
        return 'Configure minimum players and auto-host settings below.';
      case 6:
        return 'Review everything and save! You can share right after.';
      default:
        return 'Let\'s build a bracket!';
    }
  }

  Widget _buildGuideAssistant() {
    return Positioned(
      right: 12,
      bottom: 80, // above the bottom buttons
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Speech bubble (shown when _guideVisible) ──
          if (_guideVisible)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) {
                return Transform.translate(
                  offset: Offset(0, -2 * _pulseAnim.value), // subtle float
                  child: child,
                );
              },
              child: Container(
                width: 200,
                margin: const EdgeInsets.only(bottom: 8, right: 4),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A237E).withValues(alpha: 0.95),
                      const Color(0xFF0D47A1).withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (CompanionService.instance.selectedCompanion != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              CompanionService.instance.selectedCompanion!.name,
                              style: TextStyle(
                                color: const Color(0xFF00E5FF),
                                fontSize: 9,
                                fontWeight: BmbFontWeights.bold,
                                fontFamily: 'ClashDisplay',
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _guideVisible = false),
                              child: Icon(Icons.close, color: Colors.white54, size: 14),
                            ),
                          ],
                        ),
                      ),
                    Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _guideHint,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: BmbFontWeights.medium,
                        ),
                      ),
                    ),
                    if (CompanionService.instance.selectedCompanion == null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _guideVisible = false),
                        child: Icon(Icons.close, color: Colors.white54, size: 14),
                      ),
                    ],
                  ],
                ),
                  ],
                ),
              ),
            ),
          // ── Avatar circle ──
          GestureDetector(
            onTap: () {
              setState(() {
                if (_guideVisible) {
                  _guideDismissed = true; // long dismiss
                } else {
                  _guideVisible = true;
                }
              });
            },
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) {
                final t = _pulseAnim.value;
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00E5FF),
                        const Color(0xFF2979FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.2 + 0.2 * t),
                        blurRadius: 12 + 6 * t,
                        spreadRadius: 1 + 2 * t,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Center(
                child: _buildGuideAvatarContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay'));
  }

  /// Small numeric badge. Turns bright cyan when active.
  /// Build the guide avatar content — real companion face or fallback icon.
  Widget _buildGuideAvatarContent() {
    final persona = CompanionService.instance.selectedCompanion;
    if (persona != null) {
      return ClipOval(
        child: Image.asset(
          persona.circleAsset,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackGuideIcon(),
        ),
      );
    }
    return _buildFallbackGuideIcon();
  }

  Widget _buildFallbackGuideIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _guideVisible ? Icons.support_agent : Icons.assistant,
          color: Colors.white,
          size: 22,
        ),
        if (!_guideVisible)
          Text('Help', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: BmbFontWeights.bold)),
      ],
    );
  }

  Widget _stepLabel(String label) {
    final isActive = _activeLabels.contains(label);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFF00E5FF), const Color(0xFF00B0FF)]
              : [BmbColors.blue, BmbColors.blue.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          if (isActive)
            BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), blurRadius: 8)
          else
            BoxShadow(color: BmbColors.blue.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: BmbFontWeights.bold,
          fontFamily: 'ClashDisplay',
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Section title with a step label badge — now uses _guidedSection under the hood
  /// so every labelled section gets the full highlight treatment.
  Widget _labeledSection(String label, String text) {
    // Delegate to _guidedSection with an empty child so existing code
    // that puts content AFTER the _labeledSection() call still works.
    // The child is a zero-height spacer.
    return _guidedSection(label: label, title: text, child: const SizedBox.shrink());
  }

  /// ────────────────────────────────────────────────────────────────
  /// GUIDED SECTION — the main visual guidance wrapper.
  ///
  /// When [label] is in [_activeLabels], the entire section is wrapped
  /// in a prominently highlighted container with:
  ///   • Thick left accent bar (bright cyan / electric blue)
  ///   • Gently pulsing background tint
  ///   • Outer glow / shadow
  ///   • A "→ NEXT" arrow indicator on the right
  ///
  /// When NOT active and the user has already moved past this section,
  /// a subtle ✓ completion checkmark appears.
  /// ────────────────────────────────────────────────────────────────
  Widget _guidedSection({
    required String label,
    required String title,
    required Widget child,
  }) {
    final isActive = _activeLabels.contains(label);

    // Schedule auto-scroll when active sections change
    if (isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoScroll());
    }

    // Section header row
    final header = Row(
      children: [
        _stepLabel(label),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? const Color(0xFF80D8FF) : BmbColors.textPrimary,
              fontSize: 16,
              fontWeight: BmbFontWeights.bold,
              fontFamily: 'ClashDisplay',
            ),
          ),
        ),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.touch_app_rounded, size: 12, color: const Color(0xFF00E5FF)),
              const SizedBox(width: 3),
              Text('DO THIS', style: TextStyle(
                color: const Color(0xFF00E5FF),
                fontSize: 9,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
                letterSpacing: 0.5,
              )),
            ]),
          ),
      ],
    );

    final content = Column(
      key: _keyFor(label),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        child,
      ],
    );

    // ── Not active: plain with minimal styling ──
    if (!isActive) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: content,
      );
    }

    // ── Active: prominent animated highlight ──
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, inner) {
        final t = _pulseAnim.value; // 0 → 1 → 0

        // Interpolate colors for the pulse
        final bgOpacity = 0.04 + 0.06 * t;     // background tint: 4%–10%
        final borderOpacity = 0.3 + 0.3 * t;    // border: 30%–60%
        final glowOpacity = 0.06 + 0.12 * t;    // outer glow: 6%–18%
        final barOpacity = 0.7 + 0.3 * t;       // left bar: 70%–100%

        const accentColor = Color(0xFF00E5FF); // electric cyan

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // Outer glow
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: glowOpacity),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                // Background tint
                color: accentColor.withValues(alpha: bgOpacity),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: borderOpacity),
                  width: 1.5,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Thick left accent bar ──
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: barOpacity),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                    // ── Content ──
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                        child: inner,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: content,
    );
  }

  Widget _styledTextField(TextEditingController ctrl, String hint, IconData icon, bool obscure) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      style: TextStyle(color: BmbColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 13),
        prefixIcon: Icon(icon, color: BmbColors.textSecondary),
        filled: true, fillColor: BmbColors.cardDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.blue)),
      ),
    );
  }

  Widget _choiceCard(String title, String subtitle, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected ? null : BmbColors.cardGradient,
          color: selected ? BmbColors.blue.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? BmbColors.blue : BmbColors.borderColor, width: selected ? 1.5 : 0.5),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? BmbColors.blue : BmbColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: BmbFontWeights.semiBold)),
            Text(subtitle, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
          ])),
          if (selected) Icon(Icons.check_circle, color: BmbColors.blue, size: 20),
        ]),
      ),
    );
  }

  IconData _sportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball': return Icons.sports_basketball;
      case 'football': return Icons.sports_football;
      case 'soccer': return Icons.sports_soccer;
      case 'tennis': return Icons.sports_tennis;
      case 'baseball': return Icons.sports_baseball;
      case 'golf': return Icons.sports_golf;
      case 'hockey': return Icons.sports_hockey;
      case 'mma': return Icons.sports_mma;
      default: return Icons.emoji_events;
    }
  }

  IconData _prizeIcon(String name) {
    switch (name) {
      case 'checkroom': return Icons.checkroom;
      case 'face': return Icons.face;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'dry_cleaning': return Icons.dry_cleaning;
      case 'inventory_2': return Icons.inventory_2;
      default: return Icons.card_giftcard;
    }
  }

  // ─── CHARITY HELPER WIDGETS ──────────────────────────────────
  Widget _charityFlowStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: BmbColors.successGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(num, style: TextStyle(color: BmbColors.successGreen, fontSize: 10, fontWeight: BmbFontWeights.bold))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: BmbColors.textSecondary, fontSize: 11, height: 1.3))),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
        Flexible(child: Text(value, style: TextStyle(color: BmbColors.textPrimary, fontSize: 12, fontWeight: BmbFontWeights.semiBold), textAlign: TextAlign.end)),
      ]),
    );
  }
}

/// Editable reward during bracket creation — converts to a reward description at save time.
class _EditableReward {
  final String name;
  final String description;
  final _RewardIconType iconType;

  const _EditableReward({
    required this.name,
    this.description = '',
    this.iconType = _RewardIconType.gift,
  });
}

/// Auto-fitting text field for team names.
/// Shrinks font size dynamically so long names like "San Francisco 49ers"
/// fit inside the box without truncation or overflow.
class _AutoFitTeamField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isListening;
  final VoidCallback onMicTap;
  final bool showSearch;
  final VoidCallback? onSearchTap;
  final bool showMic;

  const _AutoFitTeamField({
    required this.controller,
    required this.hintText,
    required this.isListening,
    required this.onMicTap,
    this.showSearch = false,
    this.onSearchTap,
    this.showMic = true,
  });

  @override
  State<_AutoFitTeamField> createState() => _AutoFitTeamFieldState();
}

class _AutoFitTeamFieldState extends State<_AutoFitTeamField> {
  double _fontSize = 12;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_recalcFontSize);
    _recalcFontSize();
  }

  @override
  void didUpdateWidget(covariant _AutoFitTeamField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_recalcFontSize);
      widget.controller.addListener(_recalcFontSize);
      _recalcFontSize();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_recalcFontSize);
    super.dispose();
  }

  void _recalcFontSize() {
    final len = widget.controller.text.length;
    double target;
    if (len <= 12) {
      target = 12;
    } else if (len <= 16) {
      target = 11;
    } else if (len <= 20) {
      target = 10;
    } else if (len <= 26) {
      target = 9;
    } else {
      target = 8;
    }
    if (target != _fontSize && mounted) {
      setState(() => _fontSize = target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: TextField(
        controller: widget.controller,
        style: TextStyle(color: BmbColors.textPrimary, fontSize: _fontSize),
        maxLines: 1,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          hintText: widget.hintText,
          hintStyle: TextStyle(color: BmbColors.textTertiary.withValues(alpha: 0.5), fontSize: 11),
          filled: true, fillColor: BmbColors.cardDark,
          suffixIcon: (widget.showMic || widget.showSearch) ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mic button
              if (widget.showMic)
                GestureDetector(
                  onTap: widget.onMicTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      widget.isListening ? Icons.stop_circle : Icons.mic,
                      color: widget.isListening ? BmbColors.errorRed : BmbColors.textTertiary,
                      size: 16,
                    ),
                  ),
                ),
              // Search button
              if (widget.showSearch)
                GestureDetector(
                  onTap: widget.onSearchTap,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.search, color: BmbColors.textTertiary, size: 16),
                  ),
                ),
            ],
          ) : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: BmbColors.blue)),
        ),
      ),
    );
  }
}
