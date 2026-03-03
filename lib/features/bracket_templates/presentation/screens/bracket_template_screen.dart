import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/bracket_templates/data/services/svg_bracket_generator.dart';

/// Screen to preview and export SVG bracket templates.
/// Allows the host to choose bracket size (2, 4, 8, 16, 32, 64),
/// enter a custom title, toggle seeds, and export/copy the SVG.
class BracketTemplateScreen extends StatefulWidget {
  const BracketTemplateScreen({super.key});

  @override
  State<BracketTemplateScreen> createState() => _BracketTemplateScreenState();
}

class _BracketTemplateScreenState extends State<BracketTemplateScreen>
    with SingleTickerProviderStateMixin {
  int _selectedSize = 16;
  String _title = 'TOURNAMENT BRACKET';
  bool _showSeeds = true;
  String? _currentSvg;
  bool _isGenerating = false;
  bool _showSvgCode = false;

  final _titleCtrl = TextEditingController(text: 'TOURNAMENT BRACKET');

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _sizes = [2, 4, 8, 16, 32, 64];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // Auto-generate on load
    _generate();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    // Slight delay for feel
    await Future.delayed(const Duration(milliseconds: 200));
    final svg = SvgBracketGenerator.generate(
      teamCount: _selectedSize,
      title: _title,
      showSeeds: _showSeeds,
    );
    if (mounted) {
      setState(() {
        _currentSvg = svg;
        _isGenerating = false;
      });
    }
  }

  void _copySvg() {
    if (_currentSvg == null) return;
    Clipboard.setData(ClipboardData(text: _currentSvg!));
    HapticFeedback.mediumImpact();
    _snack('SVG copied to clipboard!');
  }

  void _exportSvg() {
    if (_currentSvg == null) return;
    // Create a data URI for download
    final bytes = utf8.encode(_currentSvg!);
    final b64 = base64Encode(bytes);
    final dataUri = 'data:image/svg+xml;base64,$b64';
    HapticFeedback.mediumImpact();
    // Show export options
    _showExportSheet(dataUri);
  }

  void _showExportSheet(String dataUri) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BmbColors.midNavy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BmbColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.download, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Bracket SVG',
                          style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay',
                          ),
                        ),
                        Text(
                          '$_selectedSize-team bracket template',
                          style: TextStyle(
                            color: BmbColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // File info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: BmbColors.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: BmbColors.borderColor,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.description, 'Format', 'SVG (Scalable Vector Graphics)'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.straighten, 'Size', '$_selectedSize teams, ${_roundCount(_selectedSize)} rounds'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.data_object, 'File Size', '${(_currentSvg?.length ?? 0) ~/ 1024} KB'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.label, 'Slot IDs', 'slot_{side}_r{round}_m{match}_team{1|2}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _copySvg();
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(
                          'Copy SVG Code',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: BmbFontWeights.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BmbColors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: dataUri));
                          Navigator.pop(ctx);
                          _snack('Data URI copied! Paste in browser to view/save.');
                        },
                        icon: const Icon(Icons.link, size: 18),
                        label: Text(
                          'Copy Data URI',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: BmbFontWeights.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BmbColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Generate all sizes
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _generateAndCopyAll();
                  },
                  icon: const Icon(Icons.batch_prediction, size: 18),
                  label: Text(
                    'Generate All Sizes (2, 4, 8, 16, 32, 64)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: BmbFontWeights.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _generateAndCopyAll() {
    final allSvgs = SvgBracketGenerator.generateAll(title: _title);
    final combined = StringBuffer();
    for (final entry in allSvgs.entries) {
      combined.writeln('<!-- ═══ ${entry.key}-TEAM BRACKET ═══ -->');
      combined.writeln(entry.value);
      combined.writeln('');
    }
    Clipboard.setData(ClipboardData(text: combined.toString()));
    HapticFeedback.heavyImpact();
    _snack('All bracket SVGs copied! (2, 4, 8, 16, 32, 64 teams)');
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: BmbColors.textTertiary, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: BmbColors.textTertiary,
            fontSize: 11,
            fontWeight: BmbFontWeights.medium,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 11,
              fontWeight: BmbFontWeights.semiBold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  int _roundCount(int n) {
    int r = 0;
    while (n > 1) { n ~/= 2; r++; }
    return r;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: BmbColors.midNavy,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSizeSelector(),
                      const SizedBox(height: 14),
                      _buildOptions(),
                      const SizedBox(height: 14),
                      _buildPreview(),
                      const SizedBox(height: 14),
                      _buildSlotReference(),
                      if (_showSvgCode) ...[
                        const SizedBox(height: 14),
                        _buildSvgCodeView(),
                      ],
                      const SizedBox(height: 14),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.account_tree, color: BmbColors.gold, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bracket Templates',
              style: TextStyle(
                color: BmbColors.textPrimary,
                fontSize: 17,
                fontWeight: BmbFontWeights.bold,
                fontFamily: 'ClashDisplay',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: BmbColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SVG Export',
              style: TextStyle(
                color: BmbColors.blue,
                fontSize: 10,
                fontWeight: BmbFontWeights.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SIZE SELECTOR ────────────────────────────────────────────────
  Widget _buildSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BRACKET SIZE',
          style: TextStyle(
            color: BmbColors.textTertiary,
            fontSize: 10,
            fontWeight: BmbFontWeights.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _sizes.map((size) {
            final sel = _selectedSize == size;
            final rounds = _roundCount(size);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedSize = size);
                  _generate();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? BmbColors.gold.withValues(alpha: 0.15)
                        : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? BmbColors.gold : BmbColors.borderColor,
                      width: sel ? 1.5 : 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$size',
                        style: TextStyle(
                          color: sel ? BmbColors.gold : BmbColors.textSecondary,
                          fontSize: 20,
                          fontWeight: BmbFontWeights.bold,
                          fontFamily: 'ClashDisplay',
                        ),
                      ),
                      Text(
                        '$rounds rounds',
                        style: TextStyle(
                          color: sel ? BmbColors.gold : BmbColors.textTertiary,
                          fontSize: 9,
                          fontWeight: BmbFontWeights.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── OPTIONS ──────────────────────────────────────────────────────
  Widget _buildOptions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title input
          Text(
            'BRACKET TITLE',
            style: TextStyle(
              color: BmbColors.textTertiary,
              fontSize: 9,
              fontWeight: BmbFontWeights.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            style: TextStyle(
              color: BmbColors.textPrimary,
              fontSize: 13,
              fontWeight: BmbFontWeights.semiBold,
            ),
            decoration: InputDecoration(
              hintText: 'TOURNAMENT BRACKET',
              hintStyle: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
              filled: true,
              fillColor: BmbColors.cardDark,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: BmbColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: BmbColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: BmbColors.gold),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh, color: BmbColors.gold, size: 18),
                onPressed: () {
                  setState(() => _title = _titleCtrl.text.trim().isEmpty
                      ? 'TOURNAMENT BRACKET'
                      : _titleCtrl.text.trim().toUpperCase());
                  _generate();
                },
              ),
            ),
            onSubmitted: (val) {
              setState(() => _title = val.trim().isEmpty
                  ? 'TOURNAMENT BRACKET'
                  : val.trim().toUpperCase());
              _generate();
            },
          ),
          const SizedBox(height: 10),
          // Seeds toggle
          Row(
            children: [
              Icon(Icons.tag, color: BmbColors.gold, size: 16),
              const SizedBox(width: 8),
              Text(
                'Show Seed Numbers',
                style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 12,
                  fontWeight: BmbFontWeights.semiBold,
                ),
              ),
              const Spacer(),
              Switch(
                value: _showSeeds,
                onChanged: (v) {
                  setState(() => _showSeeds = v);
                  _generate();
                },
                activeTrackColor: BmbColors.gold.withValues(alpha: 0.5),
                thumbColor: WidgetStatePropertyAll(
                  _showSeeds ? BmbColors.gold : BmbColors.textTertiary,
                ),
                inactiveTrackColor: BmbColors.borderColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── PREVIEW ──────────────────────────────────────────────────────
  Widget _buildPreview() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Icon(Icons.preview, color: BmbColors.blue, size: 16),
                const SizedBox(width: 6),
                Text(
                  'PREVIEW',
                  style: TextStyle(
                    color: BmbColors.textTertiary,
                    fontSize: 10,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (_isGenerating)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BmbColors.gold,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BmbColors.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(_currentSvg?.length ?? 0) ~/ 1024} KB',
                      style: TextStyle(
                        color: BmbColors.successGreen,
                        fontSize: 9,
                        fontWeight: BmbFontWeights.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // SVG visualization (represented as a schematic since we can't render SVG inline easily)
          _buildBracketSchematic(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBracketSchematic() {
    if (_isGenerating || _currentSvg == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: BmbColors.gold),
            const SizedBox(height: 12),
            Text(
              'Generating $_selectedSize-team bracket...',
              style: TextStyle(color: BmbColors.textTertiary, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final rounds = _roundCount(_selectedSize);
    final halfTeams = _selectedSize ~/ 2;
    final firstRoundMatches = halfTeams ~/ 2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          // Title bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: BmbColors.cardDark,
              borderRadius: BorderRadius.circular(6),
              border: Border(
                bottom: BorderSide(color: BmbColors.gold.withValues(alpha: 0.4), width: 1),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    color: BmbColors.textPrimary,
                    fontSize: 12,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '$_selectedSize-TEAM SINGLE ELIMINATION',
                  style: TextStyle(
                    color: BmbColors.gold,
                    fontSize: 8,
                    fontWeight: BmbFontWeights.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Schematic bracket visualization
          SizedBox(
            height: _selectedSize <= 8
                ? 160.0
                : _selectedSize <= 16
                    ? 220.0
                    : _selectedSize <= 32
                        ? 280.0
                        : 340.0,
            child: Row(
              children: [
                // Left bracket
                Expanded(
                  child: _buildSideSchematic('LEFT', firstRoundMatches, rounds ~/ 2 + (rounds.isOdd ? 1 : 0)),
                ),
                // Championship
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Container(
                        width: 56,
                        height: 18,
                        decoration: BoxDecoration(
                          color: BmbColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: BmbColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Center(
                          child: Text(
                            'FINAL',
                            style: TextStyle(
                              color: BmbColors.gold,
                              fontSize: 7,
                              fontWeight: BmbFontWeights.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // BMB watermark
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Opacity(
                          opacity: _pulseAnim.value * 0.3,
                          child: Text(
                            'B',
                            style: TextStyle(
                              color: const Color(0xFFD63031),
                              fontSize: 28,
                              fontWeight: BmbFontWeights.bold,
                              fontFamily: 'ClashDisplay',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right bracket
                Expanded(
                  child: _buildSideSchematic('RIGHT', firstRoundMatches, rounds ~/ 2 + (rounds.isOdd ? 1 : 0)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Footer
          Text(
            'BACKMYBRACKET.COM',
            style: TextStyle(
              color: BmbColors.textTertiary,
              fontSize: 8,
              fontWeight: BmbFontWeights.bold,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideSchematic(String label, int firstRoundMatches, int sideRounds) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _BracketSchemaPainter(
            side: label == 'LEFT' ? 'left' : 'right',
            firstRoundMatches: firstRoundMatches,
            sideRounds: sideRounds,
          ),
        );
      },
    );
  }

  // ─── SLOT REFERENCE ──────────────────────────────────────────────
  Widget _buildSlotReference() {
    final rounds = _roundCount(_selectedSize);
    final halfTeams = _selectedSize ~/ 2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: BmbColors.blue, size: 16),
              const SizedBox(width: 6),
              Text(
                'SLOT ID REFERENCE',
                style: TextStyle(
                  color: BmbColors.textTertiary,
                  fontSize: 10,
                  fontWeight: BmbFontWeights.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _refItem('First Round (Left)', 'slot_left_r0_m{0-${halfTeams ~/ 2 - 1}}_team{1|2}'),
          _refItem('First Round (Right)', 'slot_right_r0_m{0-${halfTeams ~/ 2 - 1}}_team{1|2}'),
          _refItem('Semi-Finals', 'slot_{side}_r${rounds ~/ 2 - 1}_m0_team{1|2}'),
          _refItem('Championship', 'slot_champ_team{1|2}'),
          _refItem('Champion', 'slot_champion'),
          _refItem('Score Areas', '{slot_id}_score'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BmbColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BmbColors.gold.withValues(alpha: 0.2)),
            ),
            child: Text(
              'Each slot has a unique ID for programmatic pick injection. '
              'Use these IDs to map user bracket picks into the SVG template.',
              style: TextStyle(
                color: BmbColors.gold,
                fontSize: 10,
                fontWeight: BmbFontWeights.medium,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _refItem(String label, String pattern) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: BmbColors.textSecondary,
                fontSize: 10,
                fontWeight: BmbFontWeights.medium,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BmbColors.cardDark,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                pattern,
                style: TextStyle(
                  color: BmbColors.blue,
                  fontSize: 9,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SVG CODE VIEW ───────────────────────────────────────────────
  Widget _buildSvgCodeView() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.code, color: const Color(0xFF8B5CF6), size: 16),
              const SizedBox(width: 6),
              Text(
                'SVG SOURCE',
                style: TextStyle(
                  color: BmbColors.textTertiary,
                  fontSize: 10,
                  fontWeight: BmbFontWeights.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _copySvg,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BmbColors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 12, color: BmbColors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: BmbColors.blue,
                          fontSize: 10,
                          fontWeight: BmbFontWeights.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 200,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(
                _currentSvg ?? '',
                style: const TextStyle(
                  color: Color(0xFF7EE787),
                  fontSize: 9,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ACTIONS ─────────────────────────────────────────────────────
  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _exportSvg,
                  icon: const Icon(Icons.download, size: 20),
                  label: Text(
                    'Export SVG',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: BmbFontWeights.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _copySvg,
                  icon: const Icon(Icons.copy, size: 20),
                  label: Text(
                    'Copy SVG',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: BmbFontWeights.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _showSvgCode = !_showSvgCode);
            },
            icon: Icon(_showSvgCode ? Icons.visibility_off : Icons.code, size: 18),
            label: Text(
              _showSvgCode ? 'Hide SVG Source' : 'View SVG Source',
              style: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTER: Bracket schematic mini-preview
// ═══════════════════════════════════════════════════════════════════════════

class _BracketSchemaPainter extends CustomPainter {
  final String side;
  final int firstRoundMatches;
  final int sideRounds;

  _BracketSchemaPainter({
    required this.side,
    required this.firstRoundMatches,
    required this.sideRounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isLeft = side == 'left';
    final linePaint = Paint()
      ..color = const Color(0xFF3D4376)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final slotPaint = Paint()
      ..color = const Color(0xFF252949)
      ..style = PaintingStyle.fill;

    final slotBorderPaint = Paint()
      ..color = const Color(0xFF2A3260)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final goldPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final slotW = size.width / (sideRounds + 0.5);
    final slotH = 10.0;
    final matchGap = 4.0;
    final matchH = slotH * 2 + matchGap;

    int matches = firstRoundMatches;

    for (int r = 0; r < sideRounds; r++) {
      final totalH = matches * matchH + (matches - 1) * matchGap * 2;
      final offsetY = (size.height - totalH) / 2;

      for (int m = 0; m < matches; m++) {
        final centerY = offsetY + m * (matchH + matchGap * 2) + matchH / 2;
        final slotX = isLeft ? r * (slotW + 4) : size.width - (r + 1) * (slotW + 4);

        // Top slot
        final topY = centerY - slotH - matchGap / 2;
        final topRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(slotX, topY, slotW, slotH),
          const Radius.circular(2),
        );
        canvas.drawRRect(topRect, slotPaint);
        canvas.drawRRect(topRect, slotBorderPaint);

        // Bottom slot
        final botY = centerY + matchGap / 2;
        final botRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(slotX, botY, slotW, slotH),
          const Radius.circular(2),
        );
        canvas.drawRRect(botRect, slotPaint);
        canvas.drawRRect(botRect, slotBorderPaint);

        // Vertical connector
        final connX = isLeft ? slotX + slotW : slotX;
        canvas.drawLine(
          Offset(connX, topY + slotH / 2),
          Offset(connX, botY + slotH / 2),
          r == sideRounds - 1 ? goldPaint : linePaint,
        );

        // Horizontal connector to next round
        if (r < sideRounds - 1) {
          final hEndX = isLeft ? connX + (slotW + 4) / 2 : connX - (slotW + 4) / 2;
          canvas.drawLine(
            Offset(connX, centerY),
            Offset(hEndX, centerY),
            linePaint,
          );
        } else {
          // Connector to championship
          final hEndX = isLeft ? connX + 12 : connX - 12;
          canvas.drawLine(
            Offset(connX, centerY),
            Offset(hEndX, centerY),
            goldPaint,
          );
        }
      }

      matches = (matches / 2).ceil();
      if (matches < 1) matches = 1;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
