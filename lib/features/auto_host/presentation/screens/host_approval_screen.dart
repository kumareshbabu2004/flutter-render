import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/features/auto_host/data/services/lifecycle_automation_service.dart';
import 'package:bmb_mobile/core/services/firebase/firestore_service.dart';

/// Host Approval Screen — the final review gate before a bracket goes live.
/// Host can edit bracket name, teams, entry fee, prize, go-live date, etc.
/// Then tap "Approve & Go Upcoming" to move the bracket to upcoming status.
class HostApprovalScreen extends StatefulWidget {
  final String bracketId;
  const HostApprovalScreen({super.key, required this.bracketId});

  @override
  State<HostApprovalScreen> createState() => _HostApprovalScreenState();
}

class _HostApprovalScreenState extends State<HostApprovalScreen> {
  Map<String, dynamic>? _bracket;
  bool _isLoading = true;
  bool _isSaving = false;

  // Editable fields
  final _nameController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _minPlayersController = TextEditingController();
  final _prizeController = TextEditingController();
  bool _autoShare = true;

  @override
  void initState() {
    super.initState();
    _loadBracket();
  }

  Future<void> _loadBracket() async {
    setState(() => _isLoading = true);
    final data = await FirestoreService.instance.getBracket(widget.bracketId);
    if (data != null && mounted) {
      setState(() {
        _bracket = data;
        _nameController.text = data['name'] as String? ?? '';
        _entryFeeController.text = '${(data['entry_fee'] as num?)?.toInt() ?? 0}';
        _minPlayersController.text = '${(data['min_players'] as num?)?.toInt() ?? 4}';
        _prizeController.text = data['prize_description'] as String? ?? '';
        _autoShare = data['auto_share'] as bool? ?? true;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve() async {
    if (_bracket == null) return;
    setState(() => _isSaving = true);

    try {
      // Save edits
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'entry_fee': int.tryParse(_entryFeeController.text) ?? 0,
        'entry_type': (int.tryParse(_entryFeeController.text) ?? 0) == 0 ? 'free' : 'paid',
        'min_players': int.tryParse(_minPlayersController.text) ?? 4,
        'prize_description': _prizeController.text.trim(),
        'auto_share': _autoShare,
      };
      await FirestoreService.instance.updateBracket(widget.bracketId, updates);

      // Move to upcoming
      await LifecycleAutomationService.instance.approveBracket(widget.bracketId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bracket approved and set to Upcoming!'), backgroundColor: BmbColors.gold),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BmbColors.deepNavy,
      appBar: AppBar(
        title: const Text('Approve Bracket', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: BmbColors.midNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bracket == null
              ? const Center(child: Text('Bracket not found', style: TextStyle(color: Colors.white60)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final b = _bracket!;
    final bracketType = b['bracket_type'] as String? ?? 'standard';
    final teams = (b['teams'] as List<dynamic>?)?.cast<String>() ?? [];
    final teamCount = (b['team_count'] as num?)?.toInt() ?? teams.length;
    final goLiveDateStr = b['go_live_date']?.toString();
    final goLiveDate = goLiveDateStr != null ? DateTime.tryParse(goLiveDateStr) : null;
    final isVoting = bracketType == 'voting';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Awaiting Your Approval', style: TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('Review and edit the details below, then approve to go upcoming.',
                          style: TextStyle(color: Colors.amber.withValues(alpha: 0.7), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Type & info
          Row(
            children: [
              _infoBadge(bracketType == 'voting' ? 'Voting' : bracketType == 'pickem' ? "Pick'Em" : 'Standard'),
              const SizedBox(width: 8),
              _infoBadge('$teamCount teams'),
              const SizedBox(width: 8),
              _infoBadge(b['sport'] as String? ?? 'Custom'),
            ],
          ),
          const SizedBox(height: 20),

          // Bracket Name
          _label('Bracket Name'),
          _textField(_nameController, 'Bracket name'),
          const SizedBox(height: 16),

          // Teams preview
          _label('Teams / Contestants'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BmbColors.midNavy,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: teams.take(24).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              )).toList(),
            ),
          ),
          if (teams.length > 24)
            Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('+ ${teams.length - 24} more', style: TextStyle(color: Colors.white38, fontSize: 11))),
          const SizedBox(height: 16),

          // Entry Fee
          _label('Entry Fee'),
          if (isVoting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Text('FREE — Voting brackets have no entry fee', style: TextStyle(color: Colors.green, fontSize: 13)),
            )
          else
            _textField(_entryFeeController, 'Credits', isNumber: true),
          const SizedBox(height: 16),

          // Prize
          _label('Prize'),
          _textField(_prizeController, 'Prize description (optional)'),
          const SizedBox(height: 16),

          // Min Players
          _label('Minimum Players'),
          _textField(_minPlayersController, 'Min players to go live', isNumber: true),
          const SizedBox(height: 16),

          // Go-Live Date
          if (goLiveDate != null) ...[
            _label('Scheduled Go-Live'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BmbColors.midNavy,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: BmbColors.gold, size: 18),
                  const SizedBox(width: 10),
                  Text(DateFormat('EEEE, MMM d, yyyy \'at\' h:mm a').format(goLiveDate),
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Auto-share toggle
          Container(
            decoration: BoxDecoration(
              color: BmbColors.midNavy,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: SwitchListTile(
              value: _autoShare,
              onChanged: (v) => setState(() => _autoShare = v),
              title: Text('Auto-Share', style: TextStyle(color: Colors.white)),
              subtitle: Text('Post to social when bracket goes upcoming', style: TextStyle(color: Colors.white38, fontSize: 12)),
              activeThumbColor: BmbColors.gold,
            ),
          ),
          const SizedBox(height: 32),

          // Approve button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _approve,
              icon: _isSaving
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label: Text(_isSaving ? 'Approving...' : 'Approve & Go Upcoming'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BmbColors.gold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Delete button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel (Keep as Draft)', style: TextStyle(color: Colors.white38)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _textField(TextEditingController controller, String hint, {bool isNumber = false}) {
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
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BmbColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _entryFeeController.dispose();
    _minPlayersController.dispose();
    _prizeController.dispose();
    super.dispose();
  }
}
