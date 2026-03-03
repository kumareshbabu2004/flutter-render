import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/auto_host/data/services/auto_builder_service.dart';
import 'package:bmb_mobile/features/auto_host/data/services/auto_share_service.dart';
import 'package:bmb_mobile/features/auto_host/data/services/lifecycle_automation_service.dart';
import 'package:bmb_mobile/features/auto_host/data/models/saved_template.dart';
import 'package:bmb_mobile/features/bracket_builder/data/services/speech_input_service.dart';

/// The Auto-Pilot Wizard screen.
/// Host taps mic or types a command → the Auto-Builder generates a bracket
/// → host reviews / edits → approves → bracket saved to dashboard.
class AutoPilotWizardScreen extends StatefulWidget {
  const AutoPilotWizardScreen({super.key});

  @override
  State<AutoPilotWizardScreen> createState() => _AutoPilotWizardScreenState();
}

class _AutoPilotWizardScreenState extends State<AutoPilotWizardScreen>
    with SingleTickerProviderStateMixin {
  final _commandController = TextEditingController();
  final _nameController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _minPlayersController = TextEditingController();
  final _prizeController = TextEditingController();

  AutoBuildResult? _result;
  bool _isListening = false;
  bool _isSaving = false;
  bool _showResult = false;

  // Editable overrides
  late bool _isFreeEntry;
  late int _entryFee;
  late int _minPlayers;
  late String _prizeType;
  late String? _prizeDescription;
  late bool _autoHost;
  late bool _autoShare;
  late bool _isPublic;
  DateTime? _goLiveDate;
  TimeOfDay? _goLiveTime;
  bool _requiresApproval = true;
  bool _saveAsTemplate = false;

  // Recurrence (for save-as-template)
  RecurrenceType _recurrenceType = RecurrenceType.oneTime;
  int? _recurrenceMonth;
  int? _recurrenceDayOfMonth;
  int? _recurrenceDayOfWeek;
  String? _seasonStart;
  String? _seasonEnd;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _commandController.dispose();
    _nameController.dispose();
    _entryFeeController.dispose();
    _minPlayersController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  // ─── VOICE INPUT ──────────────────────────────────────────────────

  Future<void> _startListening() async {
    final speech = SpeechInputService.instance;
    final available = await speech.init();
    if (!available) {
      if (mounted) {
        final errorDetail = speech.lastError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorDetail != null && errorDetail.contains('permission')
                  ? 'Microphone permission denied. Please enable it in Settings.'
                  : 'Voice input not available. Check microphone permissions.',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                speech.reset();
                _startListening();
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    final started = await speech.startListening(
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() => _commandController.text = text);
          if (isFinal) _stopListening();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );

    if (!started && mounted) {
      setState(() => _isListening = false);
      _pulseController.stop();
      _pulseController.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start listening: ${speech.lastError ?? "unknown error"}'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              speech.reset();
              _startListening();
            },
          ),
        ),
      );
    }
  }

  void _stopListening() {
    SpeechInputService.instance.stop();
    setState(() => _isListening = false);
    _pulseController.stop();
    _pulseController.reset();
    if (_commandController.text.isNotEmpty) {
      _processCommand();
    }
  }

  // ─── COMMAND PROCESSING ────────────────────────────────────────────

  void _processCommand() {
    final result = AutoBuilderService.instance.parseCommand(_commandController.text);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not understand that. Try something like "Best 90s rock band"')),
      );
      return;
    }

    setState(() {
      _result = result;
      _showResult = true;
      _nameController.text = result.bracketName;
      _isFreeEntry = result.isFreeEntry;
      _entryFee = result.entryFee;
      _entryFeeController.text = result.entryFee.toString();
      _minPlayers = result.minPlayers;
      _minPlayersController.text = result.minPlayers.toString();
      _prizeType = result.prizeType;
      _prizeDescription = result.prizeDescription;
      _prizeController.text = result.prizeDescription ?? '';
      _autoHost = result.autoHost;
      _autoShare = result.autoShare;
      _isPublic = result.isPublic;
      _goLiveDate = result.suggestedGoLiveDate;
      if (_goLiveDate != null) {
        _goLiveTime = TimeOfDay(hour: _goLiveDate!.hour, minute: _goLiveDate!.minute);
      }
    });
  }

  // ─── SAVE / APPROVE ────────────────────────────────────────────────

  Future<void> _approveAndSave() async {
    if (_result == null) return;
    setState(() => _isSaving = true);

    try {
      final user = CurrentUserService.instance;
      final hostId = user.userId;
      final hostName = user.displayName;

      // Combine date and time for go-live
      DateTime? goLiveDateTime;
      if (_goLiveDate != null) {
        final time = _goLiveTime ?? const TimeOfDay(hour: 18, minute: 0);
        goLiveDateTime = DateTime(
          _goLiveDate!.year, _goLiveDate!.month, _goLiveDate!.day,
          time.hour, time.minute,
        );
      }

      // Build modified result
      final modifiedResult = AutoBuildResult(
        bracketName: _nameController.text.isNotEmpty ? _nameController.text : _result!.bracketName,
        bracketType: _result!.bracketType,
        sport: _result!.sport,
        teamCount: _result!.teamCount,
        teams: _result!.teams,
        isFreeEntry: _isFreeEntry,
        entryFee: _isFreeEntry ? 0 : _entryFee,
        prizeType: _prizeType,
        prizeDescription: _prizeDescription,
        suggestedGoLiveDate: goLiveDateTime,
        minPlayers: _minPlayers,
        knowledgePackId: _result!.knowledgePackId,
        sourceTemplateId: _result!.sourceTemplateId,
        autoHost: _autoHost,
        autoShare: _autoShare,
        isPublic: _isPublic,
      );

      // Create bracket
      final bracketId = await AutoBuilderService.instance.createFromResult(
        result: modifiedResult,
        hostId: hostId,
        hostName: hostName,
      );

      if (bracketId.isEmpty) {
        throw Exception('Failed to save bracket. Please try again.');
      }

      // If approval is immediate, move to upcoming
      if (!_requiresApproval) {
        await LifecycleAutomationService.instance.approveBracket(bracketId);
      }

      // If auto-share is on and status is upcoming, queue share
      if (_autoShare && !_requiresApproval) {
        final message = AutoShareService.instance.generateShareMessage(
          bracketName: modifiedResult.bracketName,
          bracketId: bracketId,
          bracketType: modifiedResult.bracketType,
          hostName: hostName,
          isFreeEntry: modifiedResult.isFreeEntry,
          entryFee: modifiedResult.entryFee,
          prize: modifiedResult.prizeDescription,
          teamCount: modifiedResult.teamCount,
        );
        await AutoShareService.instance.queueShare(
          bracketId: bracketId,
          hostId: hostId,
          message: message,
        );
      }

      // Save as template if requested
      if (_saveAsTemplate) {
        final template = SavedTemplate(
          id: '',
          hostId: hostId,
          name: modifiedResult.bracketName.replaceAll(RegExp(r'\s\d{4}$'), ''),
          description: 'Auto-created from "${_commandController.text}"',
          knowledgePackId: modifiedResult.knowledgePackId,
          sourceTemplateId: modifiedResult.sourceTemplateId,
          bracketType: modifiedResult.bracketType,
          sport: modifiedResult.sport,
          teamCount: modifiedResult.teamCount,
          defaultTeams: modifiedResult.teams,
          isFreeEntry: modifiedResult.isFreeEntry,
          entryFee: modifiedResult.entryFee,
          prizeType: _prizeType,
          prizeDescription: _prizeDescription,
          defaultPrize: _prizeDescription,
          minPlayers: _minPlayers,
          autoHost: _autoHost,
          autoShare: _autoShare,
          isPublic: _isPublic,
          recurrenceType: _recurrenceType,
          recurrenceLabel: _recurrenceLabel(),
          recurrenceMonth: _recurrenceMonth,
          recurrenceDayOfMonth: _recurrenceDayOfMonth,
          recurrenceDayOfWeek: _recurrenceDayOfWeek,
          seasonStart: _seasonStart,
          seasonEnd: _seasonEnd,
          requiresApproval: _requiresApproval,
          createdAt: DateTime.now(),
        );
        await AutoBuilderService.instance.saveTemplate(template);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_requiresApproval
                ? 'Bracket saved! Review it in your dashboard.'
                : 'Bracket is now Upcoming and shared!'),
            backgroundColor: BmbColors.gold,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _recurrenceLabel() {
    switch (_recurrenceType) {
      case RecurrenceType.oneTime: return 'One-time';
      case RecurrenceType.yearly:
        return _recurrenceMonth != null
            ? 'Every ${_monthName(_recurrenceMonth!)}'
            : 'Yearly';
      case RecurrenceType.everyMonth:
        return '${_recurrenceDayOfMonth ?? 1}${_ordSuffix(_recurrenceDayOfMonth ?? 1)} of every month';
      case RecurrenceType.everyWeek:
        return 'Every ${_dayName(_recurrenceDayOfWeek ?? 7)}${_seasonStart != null ? ' ($_seasonStart - $_seasonEnd)' : ''}';
      case RecurrenceType.custom: return 'Custom';
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BmbColors.deepNavy,
      appBar: AppBar(
        title: const Text('Auto-Pilot Wizard', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: BmbColors.midNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _showResult ? _buildResultReview() : _buildCommandInput(),
      ),
    );
  }

  // ─── STEP 1: Voice / Text Input ─────────────────────────────────

  Widget _buildCommandInput() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: BmbColors.gold.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text(
              'What bracket should I build?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the mic or type a command like:\n"Build me an NFL playoff bracket"\n"March Madness bracket"\n"Best 90s rock band voting bracket"',
              style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Mic Button
            GestureDetector(
              onTap: _isListening ? _stopListening : _startListening,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isListening
                              ? [Colors.redAccent, Colors.red.shade700]
                              : [BmbColors.gold, BmbColors.gold.withValues(alpha: 0.7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : BmbColors.gold).withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: _isListening ? 8 : 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isListening) ...[
              const SizedBox(height: 16),
              Text('Listening...', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            ],
            const SizedBox(height: 24),

            // Text Input
            Container(
              decoration: BoxDecoration(
                color: BmbColors.midNavy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Or type your bracket idea...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (_) => _processCommand(),
                    ),
                  ),
                  IconButton(
                    onPressed: _commandController.text.isNotEmpty ? _processCommand : null,
                    icon: Icon(Icons.send, color: BmbColors.gold),
                  ),
                ],
              ),
            ),

            // Quick suggestions
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                // Tournament brackets
                _suggestionChip('NFL Playoff Bracket', icon: Icons.sports_football),
                _suggestionChip('March Madness', icon: Icons.sports_basketball),
                _suggestionChip('College Football Playoff', icon: Icons.sports_football),
                // Voting / opinion brackets
                _suggestionChip('Best 90s Rock Band', icon: Icons.how_to_vote),
                _suggestionChip('Best NFL Quarterback', icon: Icons.how_to_vote),
                _suggestionChip('Best Beer Brand', icon: Icons.how_to_vote),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String label, {IconData? icon}) {
    return GestureDetector(
      onTap: () {
        _commandController.text = label;
        _processCommand();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: BmbColors.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: BmbColors.gold),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(color: BmbColors.gold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── STEP 2: Result Review & Edit ─────────────────────────────────

  Widget _buildResultReview() {
    if (_result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [BmbColors.gold.withValues(alpha: 0.2), BmbColors.midNavy],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_awesome, size: 40, color: BmbColors.gold),
                const SizedBox(height: 8),
                Text('Auto-Built Bracket', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '"${_commandController.text}"',
                  style: TextStyle(color: BmbColors.gold, fontSize: 16, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bracket Name (editable)
          _sectionLabel('Bracket Name'),
          _editableTextField(_nameController, 'Bracket name'),
          const SizedBox(height: 16),

          // Info row
          Row(
            children: [
              _infoChip(
                _result!.bracketType == 'voting' ? Icons.how_to_vote : Icons.account_tree,
                _result!.bracketType == 'voting' ? 'Voting' :
                  _result!.bracketType == 'pickem' ? "Pick'Em" : 'Bracket',
              ),
              const SizedBox(width: 8),
              _infoChip(Icons.sports, _result!.sport),
              const SizedBox(width: 8),
              _infoChip(Icons.groups, '${_result!.teamCount} teams'),
            ],
          ),
          // Source template indicator
          if (_result!.sourceTemplateId != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BmbColors.blue.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: BmbColors.blue),
                  const SizedBox(width: 6),
                  Text('Built from official BMB template',
                      style: TextStyle(color: BmbColors.blue, fontSize: 12)),
                ],
              ),
            ),
          ] else if (_result!.knowledgePackId != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: BmbColors.gold.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: BmbColors.gold),
                  const SizedBox(width: 6),
                  Text('Built from BMB knowledge pack',
                      style: TextStyle(color: BmbColors.gold, fontSize: 12)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Teams preview
          _sectionLabel('Teams / Contestants (${_result!.teams.length})'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.midNavy,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _result!.teams.take(20).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  )).toList(),
                ),
                if (_result!.teams.any((t) => t.startsWith('TBD'))) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: BmbColors.gold.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Team names are TBD — update them when matchups are announced',
                          style: TextStyle(color: BmbColors.gold.withValues(alpha: 0.7), fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
                // Show helpful hint for template brackets with seeded placeholders
                if (_result!.sourceTemplateId != null &&
                    _result!.teams.any((t) => t.contains('#') || t.contains('Bye'))) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: BmbColors.blue.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Seedings from official ${_result!.sport} template — edit team names after matchups are set',
                          style: TextStyle(color: BmbColors.blue.withValues(alpha: 0.7), fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_result!.teams.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${_result!.teams.length - 20} more...', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          const SizedBox(height: 20),

          // Entry Fee
          _sectionLabel('Entry Fee'),
          if (_result!.bracketType == 'voting')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text('FREE — Voting brackets have no entry fee',
                      style: TextStyle(color: Colors.green, fontSize: 14)),
                ],
              ),
            )
          else ...[
            SwitchListTile(
              value: _isFreeEntry,
              onChanged: (v) => setState(() => _isFreeEntry = v),
              title: Text('Free Entry', style: TextStyle(color: Colors.white)),
              activeThumbColor: BmbColors.gold,
              tileColor: BmbColors.midNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            if (!_isFreeEntry) ...[
              const SizedBox(height: 8),
              _editableTextField(_entryFeeController, 'Credits', isNumber: true),
            ],
          ],
          const SizedBox(height: 16),

          // Prize
          _sectionLabel('Prize'),
          _buildPrizePicker(),
          const SizedBox(height: 16),

          // Go-Live Date
          _sectionLabel('Go-Live Date'),
          GestureDetector(
            onTap: _pickGoLiveDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BmbColors.midNavy,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: BmbColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _goLiveDate != null
                        ? '${DateFormat('MMM d, yyyy').format(_goLiveDate!)} at ${_goLiveTime?.format(context) ?? '6:00 PM'}'
                        : 'Select date...',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Min Players
          _sectionLabel('Minimum Players'),
          _editableTextField(_minPlayersController, 'Min players', isNumber: true),
          const SizedBox(height: 16),

          // Toggle switches
          _sectionLabel('Settings'),
          _toggleCard('Auto-Host', 'Automatically go live when conditions are met', _autoHost, (v) => setState(() => _autoHost = v)),
          _toggleCard('Auto-Share', 'Share to social when bracket goes upcoming', _autoShare, (v) => setState(() => _autoShare = v)),
          _toggleCard('Public', 'Visible to all BMB users', _isPublic, (v) => setState(() => _isPublic = v)),
          _toggleCard('Require Approval', 'Review before bracket goes upcoming', _requiresApproval, (v) => setState(() => _requiresApproval = v)),
          const SizedBox(height: 16),

          // Save as template
          _sectionLabel('Save as Template'),
          _toggleCard('Save as Reusable Template', 'Use this bracket config again later', _saveAsTemplate, (v) => setState(() => _saveAsTemplate = v)),
          if (_saveAsTemplate) ...[
            const SizedBox(height: 8),
            _buildRecurrencePicker(),
          ],

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _showResult = false;
                    _result = null;
                  }),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _approveAndSave,
                  icon: _isSaving
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle),
                  label: Text(_isSaving ? 'Saving...' : 'Looks Good!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── UI HELPERS ────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }

  Widget _editableTextField(TextEditingController controller, String hint, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white30),
        filled: true,
        fillColor: BmbColors.midNavy,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: BmbColors.gold)),
      ),
      onChanged: (v) {
        if (isNumber && controller == _entryFeeController) {
          _entryFee = int.tryParse(v) ?? 0;
        } else if (isNumber && controller == _minPlayersController) {
          _minPlayers = int.tryParse(v) ?? 4;
        }
      },
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BmbColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: BmbColors.gold),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _toggleCard(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: BmbColors.midNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 12)),
        activeThumbColor: BmbColors.gold,
        dense: true,
      ),
    );
  }

  Widget _buildPrizePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DefaultPrizes.votingPrizes.map((prize) {
        final isSelected = _prizeDescription == prize['name'];
        return GestureDetector(
          onTap: () => setState(() {
            _prizeType = prize['type']!;
            _prizeDescription = prize['name'];
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? BmbColors.gold.withValues(alpha: 0.2) : BmbColors.midNavy,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? BmbColors.gold : Colors.white12),
            ),
            child: Text(prize['name']!, style: TextStyle(
              color: isSelected ? BmbColors.gold : Colors.white60,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurrencePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Recurrence Rule'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _recurrenceChip('One-time', RecurrenceType.oneTime),
            _recurrenceChip('Every March', RecurrenceType.yearly),
            _recurrenceChip('1st of Every Month', RecurrenceType.everyMonth),
            _recurrenceChip('Every Sunday (NFL)', RecurrenceType.everyWeek),
          ],
        ),
      ],
    );
  }

  Widget _recurrenceChip(String label, RecurrenceType type) {
    final isSelected = _recurrenceType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _recurrenceType = type;
          switch (type) {
            case RecurrenceType.yearly:
              _recurrenceMonth = 3; // March
              break;
            case RecurrenceType.everyMonth:
              _recurrenceDayOfMonth = 1;
              break;
            case RecurrenceType.everyWeek:
              _recurrenceDayOfWeek = 7; // Sunday
              _seasonStart = 'september';
              _seasonEnd = 'february';
              break;
            default:
              break;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? BmbColors.gold.withValues(alpha: 0.2) : BmbColors.midNavy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? BmbColors.gold : Colors.white12),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? BmbColors.gold : Colors.white60,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
    );
  }

  Future<void> _pickGoLiveDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _goLiveDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: BmbColors.gold),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _goLiveTime ?? const TimeOfDay(hour: 18, minute: 0),
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: BmbColors.gold),
          ),
          child: child!,
        ),
      );
      setState(() {
        _goLiveDate = date;
        if (time != null) _goLiveTime = time;
      });
    }
  }

  static String _monthName(int m) {
    const names = ['', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return names[m.clamp(1, 12)];
  }

  static String _dayName(int d) {
    const names = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[d.clamp(1, 7)];
  }

  static String _ordSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}
