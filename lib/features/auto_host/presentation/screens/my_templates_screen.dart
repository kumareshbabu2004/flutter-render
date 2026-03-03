import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/auto_host/data/models/saved_template.dart';
import 'package:bmb_mobile/features/auto_host/data/services/auto_builder_service.dart';
import 'package:bmb_mobile/features/auto_host/presentation/screens/auto_pilot_wizard_screen.dart';

/// "My Templates" screen — shows saved bracket templates with ability to
/// custom-build new templates from scratch AND save for future re-use.
class MyTemplatesScreen extends StatefulWidget {
  const MyTemplatesScreen({super.key});

  @override
  State<MyTemplatesScreen> createState() => _MyTemplatesScreenState();
}

class _MyTemplatesScreenState extends State<MyTemplatesScreen> {
  List<SavedTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    final hostId = CurrentUserService.instance.userId;
    final templates = await AutoBuilderService.instance.getHostTemplates(hostId);
    if (mounted) setState(() { _templates = templates; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BmbColors.deepNavy,
      appBar: AppBar(
        title: const Text('My Templates', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: BmbColors.midNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _launchWizard,
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Auto-Pilot',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTemplates,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _templates.length,
                    itemBuilder: (ctx, i) => _buildTemplateCard(_templates[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCustomBuilder,
        icon: const Icon(Icons.add),
        label: const Text('Custom Template'),
        backgroundColor: BmbColors.gold,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 72, color: Colors.white24),
            const SizedBox(height: 16),
            Text('No Saved Templates Yet', style: TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Build a custom template to re-use your\nfavorite bracket setups anytime.',
                style: TextStyle(color: Colors.white38, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            // Primary: Custom Build
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openCustomBuilder,
                icon: const Icon(Icons.build),
                label: const Text('Build Custom Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Secondary: Auto-Pilot
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _launchWizard,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Or use Auto-Pilot'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BmbColors.blue,
                  side: BorderSide(color: BmbColors.blue.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(SavedTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BmbColors.midNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: template.isFavorite ? BmbColors.gold.withValues(alpha: 0.4) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor(template.bracketType).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    template.bracketType == 'voting' ? 'Voting' :
                    template.bracketType == 'pickem' ? "Pick'Em" : 'Standard',
                    style: TextStyle(color: _typeColor(template.bracketType), fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                // Recurrence badge
                if (template.isRecurring) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat, size: 12, color: Colors.purpleAccent),
                      const SizedBox(width: 4),
                      Text(template.recurrenceDescription, style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (template.isPaused) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('PAUSED', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
                const Spacer(),
                // Favorite
                IconButton(
                  onPressed: () => _toggleFavorite(template),
                  icon: Icon(
                    template.isFavorite ? Icons.star : Icons.star_border,
                    color: template.isFavorite ? Colors.amber : Colors.white24,
                    size: 22,
                  ),
                ),
                // More menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                  color: BmbColors.midNavy,
                  onSelected: (v) => _handleMenuAction(v, template),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Template', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate', style: TextStyle(color: Colors.white))),
                    PopupMenuItem(
                      value: template.isPaused ? 'resume' : 'pause',
                      child: Text(template.isPaused ? 'Resume Schedule' : 'Pause Schedule',
                          style: const TextStyle(color: Colors.white)),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ],
            ),
          ),

          // Name & sport
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '${template.sport} \u2022 ${template.teamCount} teams \u2022 ${template.isFreeEntry ? 'Free' : '${template.entryFee} credits'}',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _statChip(Icons.play_arrow, '${template.timesUsed} uses'),
                if (template.lastUsedAt != null) ...[
                  const SizedBox(width: 12),
                  _statChip(Icons.schedule, 'Last: ${DateFormat('MMM d').format(template.lastUsedAt!)}'),
                ],
                if (template.nextFireDate != null) ...[
                  const SizedBox(width: 12),
                  _statChip(Icons.event, 'Next: ${DateFormat('MMM d').format(template.nextFireDate!)}'),
                ],
              ],
            ),
          ),

          // Prize info
          if (template.defaultPrize != null && template.defaultPrize!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text('Prize: ${template.defaultPrize}', style: TextStyle(color: Colors.amber, fontSize: 12)),
                ],
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _useTemplate(template),
                    icon: const Icon(Icons.rocket_launch, size: 18),
                    label: const Text('Use Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmbColors.gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCustomBuilder(existingTemplate: template),
                    icon: Icon(Icons.edit, size: 16, color: BmbColors.blue),
                    label: Text('Edit', style: TextStyle(color: BmbColors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: BmbColors.blue.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'voting': return Colors.purpleAccent;
      case 'pickem': return Colors.tealAccent;
      default: return BmbColors.gold;
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────

  void _launchWizard() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AutoPilotWizardScreen()),
    );
    if (result == true) _loadTemplates();
  }

  /// Opens the full custom template builder bottom sheet.
  /// If [existingTemplate] is provided, pre-fills for editing.
  void _openCustomBuilder({SavedTemplate? existingTemplate}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomTemplateBuilderSheet(
        existingTemplate: existingTemplate,
        onSaved: () {
          Navigator.pop(ctx);
          _loadTemplates();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(existingTemplate != null ? 'Template updated!' : 'Custom template saved!'),
                backgroundColor: BmbColors.gold,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _useTemplate(SavedTemplate template) async {
    final user = CurrentUserService.instance;
    try {
      await AutoBuilderService.instance.useTemplate(
        template: template,
        hostId: user.userId,
        hostName: user.displayName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(template.requiresApproval
                ? 'Bracket created! Check your dashboard to approve.'
                : 'Bracket created and set to Upcoming!'),
            backgroundColor: BmbColors.gold,
          ),
        );
        _loadTemplates();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleFavorite(SavedTemplate template) async {
    await AutoBuilderService.instance.updateTemplate(template.id, {
      'is_favorite': !template.isFavorite,
    });
    _loadTemplates();
  }

  Future<void> _handleMenuAction(String action, SavedTemplate template) async {
    switch (action) {
      case 'edit':
        _openCustomBuilder(existingTemplate: template);
        break;
      case 'duplicate':
        await _duplicateTemplate(template);
        break;
      case 'pause':
      case 'resume':
        await AutoBuilderService.instance.updateTemplate(template.id, {
          'is_paused': action == 'pause',
        });
        _loadTemplates();
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: BmbColors.midNavy,
            title: const Text('Delete Template?', style: TextStyle(color: Colors.white)),
            content: Text('Are you sure you want to delete "${template.name}"?',
                style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await AutoBuilderService.instance.deleteTemplate(template.id);
          _loadTemplates();
        }
        break;
    }
  }

  Future<void> _duplicateTemplate(SavedTemplate template) async {
    final newTemplate = SavedTemplate(
      id: '',
      hostId: CurrentUserService.instance.userId,
      name: '${template.name} (Copy)',
      description: template.description,
      bracketType: template.bracketType,
      sport: template.sport,
      teamCount: template.teamCount,
      defaultTeams: template.defaultTeams,
      isFreeEntry: template.isFreeEntry,
      entryFee: template.entryFee,
      prizeType: template.prizeType,
      prizeDescription: template.prizeDescription,
      defaultPrize: template.defaultPrize,
      minPlayers: template.minPlayers,
      maxPlayers: template.maxPlayers,
      autoHost: template.autoHost,
      isPublic: template.isPublic,
      autoShare: template.autoShare,
      recurrenceType: template.recurrenceType,
      recurrenceLabel: template.recurrenceLabel,
      recurrenceMonth: template.recurrenceMonth,
      recurrenceDayOfMonth: template.recurrenceDayOfMonth,
      recurrenceDayOfWeek: template.recurrenceDayOfWeek,
      seasonStart: template.seasonStart,
      seasonEnd: template.seasonEnd,
      requiresApproval: template.requiresApproval,
      createdAt: DateTime.now(),
    );
    await AutoBuilderService.instance.saveTemplate(newTemplate);
    _loadTemplates();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template duplicated!'), backgroundColor: BmbColors.gold),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// CUSTOM TEMPLATE BUILDER SHEET
// ═══════════════════════════════════════════════════════════════════

class _CustomTemplateBuilderSheet extends StatefulWidget {
  final SavedTemplate? existingTemplate;
  final VoidCallback onSaved;

  const _CustomTemplateBuilderSheet({
    this.existingTemplate,
    required this.onSaved,
  });

  @override
  State<_CustomTemplateBuilderSheet> createState() => _CustomTemplateBuilderSheetState();
}

class _CustomTemplateBuilderSheetState extends State<_CustomTemplateBuilderSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _prizeController = TextEditingController();
  final _teamCountController = TextEditingController();

  String _bracketType = 'standard';
  String _sport = 'Football';
  bool _isFreeEntry = true;
  bool _autoHost = true;
  bool _autoShare = true;
  bool _isPublic = true;
  bool _requiresApproval = true;
  String _prizeType = 'none';
  RecurrenceType _recurrenceType = RecurrenceType.oneTime;
  int? _recurrenceMonth;
  int? _recurrenceDayOfMonth;
  int? _recurrenceDayOfWeek;
  bool _isSaving = false;

  bool get _isEditing => widget.existingTemplate != null;

  static const _sports = ['Football', 'Basketball', 'Baseball', 'Soccer', 'Hockey', 'MMA', 'Golf', 'Tennis', 'Voting', 'Custom'];
  static const _bracketTypes = ['standard', 'voting', 'pickem'];
  static const _prizeTypes = ['none', 'gift_card', 'merch', 'custom', 'charity'];
  static const _teamSizes = [4, 8, 16, 32, 64];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.existingTemplate!;
      _nameController.text = t.name;
      _descController.text = t.description;
      _entryFeeController.text = t.entryFee.toString();
      _prizeController.text = t.defaultPrize ?? '';
      _teamCountController.text = t.teamCount.toString();
      _bracketType = t.bracketType;
      _sport = t.sport;
      _isFreeEntry = t.isFreeEntry;
      _autoHost = t.autoHost;
      _autoShare = t.autoShare;
      _isPublic = t.isPublic;
      _requiresApproval = t.requiresApproval;
      _prizeType = t.prizeType;
      _recurrenceType = t.recurrenceType;
      _recurrenceMonth = t.recurrenceMonth;
      _recurrenceDayOfMonth = t.recurrenceDayOfMonth;
      _recurrenceDayOfWeek = t.recurrenceDayOfWeek;
    } else {
      _teamCountController.text = '8';
      _entryFeeController.text = '10';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _entryFeeController.dispose();
    _prizeController.dispose();
    _teamCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BmbColors.midNavy, BmbColors.deepNavy],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: BmbColors.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(_isEditing ? Icons.edit : Icons.build, color: BmbColors.gold, size: 22),
                  const SizedBox(width: 8),
                  Text(_isEditing ? 'Edit Template' : 'Build Custom Template',
                      style: TextStyle(
                          color: BmbColors.textPrimary, fontSize: 18,
                          fontWeight: BmbFontWeights.bold, fontFamily: 'ClashDisplay')),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: BmbColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: BmbColors.borderColor, height: 1),
            // Scrollable form
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Template Name
                  _sectionLabel('Template Name'),
                  _buildTextField(_nameController, 'e.g., NFL Sunday Bracket', Icons.text_fields),
                  const SizedBox(height: 16),

                  // Description
                  _sectionLabel('Description (optional)'),
                  _buildTextField(_descController, 'Brief description...', Icons.description, maxLines: 2),
                  const SizedBox(height: 20),

                  // Bracket Type
                  _sectionLabel('Bracket Type'),
                  const SizedBox(height: 8),
                  Row(
                    children: _bracketTypes.map((type) {
                      final selected = type == _bracketType;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _bracketType = type;
                            if (type == 'voting') {
                              _isFreeEntry = true;
                            }
                          }),
                          child: Container(
                            margin: EdgeInsets.only(right: type != 'pickem' ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? _typeColorFor(type).withValues(alpha: 0.2) : BmbColors.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? _typeColorFor(type) : BmbColors.borderColor,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(_typeIconFor(type), color: selected ? _typeColorFor(type) : BmbColors.textTertiary, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  type == 'standard' ? 'Standard' : type == 'voting' ? 'Voting' : "Pick'Em",
                                  style: TextStyle(
                                    color: selected ? _typeColorFor(type) : BmbColors.textSecondary,
                                    fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Sport
                  _sectionLabel('Sport / Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sports.map((s) {
                      final selected = s == _sport;
                      return GestureDetector(
                        onTap: () => setState(() => _sport = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? BmbColors.blue.withValues(alpha: 0.2) : BmbColors.cardDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? BmbColors.blue : BmbColors.borderColor),
                          ),
                          child: Text(s, style: TextStyle(
                            color: selected ? BmbColors.blue : BmbColors.textSecondary,
                            fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Team Count
                  _sectionLabel('Team / Item Count'),
                  const SizedBox(height: 8),
                  Row(
                    children: _teamSizes.map((size) {
                      final selected = size.toString() == _teamCountController.text;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _teamCountController.text = size.toString()),
                          child: Container(
                            margin: EdgeInsets.only(right: size != 64 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? BmbColors.successGreen.withValues(alpha: 0.2) : BmbColors.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selected ? BmbColors.successGreen : BmbColors.borderColor),
                            ),
                            child: Center(
                              child: Text('$size', style: TextStyle(
                                color: selected ? BmbColors.successGreen : BmbColors.textSecondary,
                                fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                              )),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Entry fee toggle
                  _sectionLabel('Entry Fee'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isFreeEntry = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isFreeEntry ? BmbColors.successGreen.withValues(alpha: 0.2) : BmbColors.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _isFreeEntry ? BmbColors.successGreen : BmbColors.borderColor),
                            ),
                            child: Center(
                              child: Text('Free Entry', style: TextStyle(
                                color: _isFreeEntry ? BmbColors.successGreen : BmbColors.textSecondary,
                                fontWeight: _isFreeEntry ? FontWeight.w700 : FontWeight.w400,
                              )),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_bracketType != 'voting') {
                              setState(() => _isFreeEntry = false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isFreeEntry ? BmbColors.gold.withValues(alpha: 0.2) : BmbColors.cardDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: !_isFreeEntry ? BmbColors.gold : BmbColors.borderColor),
                            ),
                            child: Center(
                              child: Text('Paid', style: TextStyle(
                                color: !_isFreeEntry ? BmbColors.gold : BmbColors.textSecondary,
                                fontWeight: !_isFreeEntry ? FontWeight.w700 : FontWeight.w400,
                              )),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_isFreeEntry) ...[
                    const SizedBox(height: 12),
                    _buildTextField(_entryFeeController, 'Credits', Icons.monetization_on, keyboardType: TextInputType.number),
                  ],
                  const SizedBox(height: 20),

                  // Prize
                  _sectionLabel('Prize Type'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _prizeTypes.map((p) {
                      final selected = p == _prizeType;
                      final label = p == 'gift_card' ? 'Gift Card' : p == 'merch' ? 'Merch' : p == 'none' ? 'Bragging Rights' : p == 'charity' ? 'Charity' : 'Custom';
                      return GestureDetector(
                        onTap: () => setState(() => _prizeType = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? BmbColors.gold.withValues(alpha: 0.2) : BmbColors.cardDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? BmbColors.gold : BmbColors.borderColor),
                          ),
                          child: Text(label, style: TextStyle(
                            color: selected ? BmbColors.gold : BmbColors.textSecondary,
                            fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          )),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_prizeType != 'none') ...[
                    const SizedBox(height: 12),
                    _buildTextField(_prizeController, 'Prize description', Icons.emoji_events),
                  ],
                  const SizedBox(height: 20),

                  // Recurrence
                  _sectionLabel('Recurrence Schedule'),
                  const SizedBox(height: 8),
                  _buildRecurrenceSelector(),
                  const SizedBox(height: 20),

                  // Hosting options
                  _sectionLabel('Hosting Options'),
                  const SizedBox(height: 8),
                  _buildToggle('Auto Host', 'Automatically go live when min players join', _autoHost, (v) => setState(() => _autoHost = v)),
                  _buildToggle('Auto Share', 'Share link when bracket goes upcoming', _autoShare, (v) => setState(() => _autoShare = v)),
                  _buildToggle('Public', 'Visible on the Bracket Board', _isPublic, (v) => setState(() => _isPublic = v)),
                  _buildToggle('Require Approval', 'You review before it goes live', _requiresApproval, (v) => setState(() => _requiresApproval = v)),
                  const SizedBox(height: 24),

                  // SAVE Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveTemplate,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_isEditing ? Icons.save : Icons.check_circle, size: 20),
                      label: Text(_isEditing ? 'Update Template' : 'Save Template',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmbColors.gold,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: BmbColors.gold.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: TextStyle(
      color: BmbColors.textSecondary, fontSize: 13, fontWeight: BmbFontWeights.semiBold,
    ));
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 14),
          prefixIcon: Icon(icon, color: BmbColors.textTertiary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: BmbColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: BmbColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: BmbColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceSelector() {
    final options = [
      (RecurrenceType.oneTime, 'One-time', Icons.looks_one),
      (RecurrenceType.everyWeek, 'Weekly', Icons.calendar_view_week),
      (RecurrenceType.everyMonth, 'Monthly', Icons.calendar_month),
      (RecurrenceType.yearly, 'Yearly', Icons.date_range),
    ];
    return Column(
      children: [
        Row(
          children: options.map((o) {
            final selected = o.$1 == _recurrenceType;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _recurrenceType = o.$1),
                child: Container(
                  margin: EdgeInsets.only(right: o.$1 != RecurrenceType.yearly ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? Colors.purpleAccent.withValues(alpha: 0.2) : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? Colors.purpleAccent : BmbColors.borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(o.$3, color: selected ? Colors.purpleAccent : BmbColors.textTertiary, size: 18),
                      const SizedBox(height: 4),
                      Text(o.$2, style: TextStyle(
                        color: selected ? Colors.purpleAccent : BmbColors.textSecondary,
                        fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_recurrenceType == RecurrenceType.everyWeek) ...[
          const SizedBox(height: 12),
          _buildDayOfWeekSelector(),
        ],
        if (_recurrenceType == RecurrenceType.everyMonth) ...[
          const SizedBox(height: 12),
          _buildDayOfMonthSelector(),
        ],
        if (_recurrenceType == RecurrenceType.yearly) ...[
          const SizedBox(height: 12),
          _buildMonthSelector(),
        ],
      ],
    );
  }

  Widget _buildDayOfWeekSelector() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 6,
      children: List.generate(7, (i) {
        final dayNum = i + 1;
        final selected = _recurrenceDayOfWeek == dayNum;
        return GestureDetector(
          onTap: () => setState(() => _recurrenceDayOfWeek = dayNum),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.purpleAccent.withValues(alpha: 0.2) : BmbColors.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? Colors.purpleAccent : BmbColors.borderColor),
            ),
            child: Text(days[i], style: TextStyle(
              color: selected ? Colors.purpleAccent : BmbColors.textSecondary, fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            )),
          ),
        );
      }),
    );
  }

  Widget _buildDayOfMonthSelector() {
    return Row(
      children: [
        Text('Day of month:', style: TextStyle(color: BmbColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: BmbColors.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: BmbColors.borderColor),
          ),
          child: DropdownButton<int>(
            value: _recurrenceDayOfMonth ?? 1,
            dropdownColor: BmbColors.midNavy,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
            onChanged: (v) => setState(() => _recurrenceDayOfMonth = v),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(12, (i) {
        final monthNum = i + 1;
        final selected = _recurrenceMonth == monthNum;
        return GestureDetector(
          onTap: () => setState(() => _recurrenceMonth = monthNum),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.purpleAccent.withValues(alpha: 0.2) : BmbColors.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? Colors.purpleAccent : BmbColors.borderColor),
            ),
            child: Text(months[i], style: TextStyle(
              color: selected ? Colors.purpleAccent : BmbColors.textSecondary, fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            )),
          ),
        );
      }),
    );
  }

  Color _typeColorFor(String type) {
    switch (type) {
      case 'voting': return Colors.purpleAccent;
      case 'pickem': return Colors.tealAccent;
      default: return BmbColors.gold;
    }
  }

  IconData _typeIconFor(String type) {
    switch (type) {
      case 'voting': return Icons.how_to_vote;
      case 'pickem': return Icons.checklist;
      default: return Icons.account_tree;
    }
  }

  Future<void> _saveTemplate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final hostId = CurrentUserService.instance.userId;
      final teamCount = int.tryParse(_teamCountController.text) ?? 8;
      final entryFee = _isFreeEntry ? 0 : (int.tryParse(_entryFeeController.text) ?? 10);

      final recurrenceLabel = _buildRecurrenceLabel();

      if (_isEditing) {
        // Update existing template
        await AutoBuilderService.instance.updateTemplate(widget.existingTemplate!.id, {
          'name': name,
          'description': _descController.text.trim(),
          'bracket_type': _bracketType,
          'sport': _sport,
          'team_count': teamCount,
          'is_free_entry': _isFreeEntry,
          'entry_fee': entryFee,
          'prize_type': _prizeType,
          'default_prize': _prizeController.text.trim(),
          'auto_host': _autoHost,
          'auto_share': _autoShare,
          'is_public': _isPublic,
          'requires_approval': _requiresApproval,
          'recurrence_type': _recurrenceType.name,
          'recurrence_label': recurrenceLabel,
          'recurrence_month': _recurrenceMonth,
          'recurrence_day_of_month': _recurrenceDayOfMonth,
          'recurrence_day_of_week': _recurrenceDayOfWeek,
        });
      } else {
        // Create new template
        final template = SavedTemplate(
          id: '',
          hostId: hostId,
          name: name,
          description: _descController.text.trim(),
          bracketType: _bracketType,
          sport: _sport,
          teamCount: teamCount,
          isFreeEntry: _isFreeEntry,
          entryFee: entryFee,
          prizeType: _prizeType,
          defaultPrize: _prizeController.text.trim().isNotEmpty ? _prizeController.text.trim() : null,
          autoHost: _autoHost,
          autoShare: _autoShare,
          isPublic: _isPublic,
          requiresApproval: _requiresApproval,
          recurrenceType: _recurrenceType,
          recurrenceLabel: recurrenceLabel,
          recurrenceMonth: _recurrenceMonth,
          recurrenceDayOfMonth: _recurrenceDayOfMonth,
          recurrenceDayOfWeek: _recurrenceDayOfWeek,
          createdAt: DateTime.now(),
        );
        await AutoBuilderService.instance.saveTemplate(template);
      }

      widget.onSaved();
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

  String _buildRecurrenceLabel() {
    switch (_recurrenceType) {
      case RecurrenceType.oneTime:
        return 'One-time';
      case RecurrenceType.everyWeek:
        const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        return 'Every ${dayNames[_recurrenceDayOfWeek ?? 7]}';
      case RecurrenceType.everyMonth:
        return '${_recurrenceDayOfMonth ?? 1}${_ordinalSuffix(_recurrenceDayOfMonth ?? 1)} of every month';
      case RecurrenceType.yearly:
        const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        return 'Every ${months[_recurrenceMonth ?? 1]}';
      case RecurrenceType.custom:
        return 'Custom';
    }
  }

  String _ordinalSuffix(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}
