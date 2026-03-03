import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';
import 'package:bmb_mobile/features/auto_host/data/models/saved_template.dart';
import 'package:bmb_mobile/features/auto_host/data/services/auto_builder_service.dart';
import 'package:bmb_mobile/features/auto_host/presentation/screens/auto_pilot_wizard_screen.dart';
import 'package:bmb_mobile/features/auto_host/presentation/screens/my_templates_screen.dart';

/// A compact widget that embeds in the host's dashboard.
/// Shows: auto-pilot status, next 3 queued brackets, recurring template badges.
class AutoPilotDashboardWidget extends StatefulWidget {
  final VoidCallback? onBracketCreated;

  const AutoPilotDashboardWidget({super.key, this.onBracketCreated});

  @override
  State<AutoPilotDashboardWidget> createState() => _AutoPilotDashboardWidgetState();
}

class _AutoPilotDashboardWidgetState extends State<AutoPilotDashboardWidget> {
  List<SavedTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final hostId = CurrentUserService.instance.userId;
    final templates = await AutoBuilderService.instance.getHostTemplates(hostId);
    if (mounted) setState(() { _templates = templates; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BmbColors.gold.withValues(alpha: 0.15),
            BmbColors.midNavy,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BmbColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome, color: BmbColors.gold, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-Pilot', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        _templates.isEmpty ? 'No templates yet' :
                        '${_templates.length} template${_templates.length == 1 ? '' : 's'} • '
                        '${_templates.where((t) => t.isRecurring && !t.isPaused).length} recurring',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyTemplatesScreen()),
                  ).then((_) => _loadData()),
                  child: Text('View All', style: TextStyle(color: BmbColors.gold, fontSize: 13)),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_templates.isEmpty)
            _buildEmptyContent()
          else
            _buildTemplateList(),

          // Quick-launch button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AutoPilotWizardScreen()),
                ).then((result) {
                  if (result == true) {
                    _loadData();
                    widget.onBracketCreated?.call();
                  }
                }),
                icon: const Icon(Icons.mic, size: 18),
                label: const Text('New Auto-Pilot Bracket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BmbColors.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.rocket_launch, size: 32, color: Colors.white24),
            const SizedBox(height: 8),
            Text('Say what you want. We build it.',
                style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
            Text('"Host me a best 90s rock band bracket"',
                style: TextStyle(color: BmbColors.gold.withValues(alpha: 0.7), fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateList() {
    // Show max 3 templates
    final display = _templates.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: display.map((t) => _miniTemplateRow(t)).toList(),
      ),
    );
  }

  Widget _miniTemplateRow(SavedTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: template.isPaused ? Colors.orange :
                  template.isRecurring ? Colors.greenAccent : Colors.white38,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    if (template.isRecurring) ...[
                      Icon(Icons.repeat, size: 10, color: Colors.purpleAccent),
                      const SizedBox(width: 3),
                      Text(template.recurrenceDescription, style: TextStyle(color: Colors.purpleAccent, fontSize: 10)),
                      const SizedBox(width: 8),
                    ],
                    if (template.nextFireDate != null)
                      Text('Next: ${DateFormat('MMM d').format(template.nextFireDate!)}',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          // Quick use
          GestureDetector(
            onTap: () => _quickUse(template),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BmbColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Use', style: TextStyle(color: BmbColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickUse(SavedTemplate template) async {
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
            content: Text('Bracket created from "${template.name}"!'),
            backgroundColor: BmbColors.gold,
          ),
        );
        _loadData();
        widget.onBracketCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
