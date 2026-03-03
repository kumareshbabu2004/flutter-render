import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/social/data/services/social_follow_promo_service.dart';

/// Admin-only screen for managing the Social Follow Promo.
///
/// Visible ONLY to BMB Admin accounts (isAdmin == true).
/// Controls:
///   - Toggle promo on/off (manual)
///   - Automated schedule with start & end date/time
///   - Admin override: force ON or OFF regardless of schedule
///   - Custom credit amount (free-text number input)
///   - Live status + countdown
class SocialPromoAdminScreen extends StatefulWidget {
  const SocialPromoAdminScreen({super.key});
  @override
  State<SocialPromoAdminScreen> createState() => _SocialPromoAdminScreenState();
}

class _SocialPromoAdminScreenState extends State<SocialPromoAdminScreen> {
  final _promoService = SocialFollowPromoService.instance;
  final _amountController = TextEditingController();

  // ── State ──
  bool _manualToggle = true;
  bool _adminOverride = false;
  bool _scheduleEnabled = false;
  DateTime? _scheduleStart;
  DateTime? _scheduleEnd;
  PromoStatus? _status;
  int _currentAmount = SocialFollowPromoService.defaultCreditAmount;
  bool _saving = false;
  bool _loaded = false;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final manualOn = await _promoService.isManualToggleOn();
    final override = await _promoService.isAdminOverride();
    final schedEnabled = await _promoService.isScheduleEnabled();
    final start = await _promoService.getScheduleStart();
    final end = await _promoService.getScheduleEnd();
    final status = await _promoService.getPromoStatus();
    final amount = await _promoService.getCreditAmount();
    if (!mounted) return;
    setState(() {
      _manualToggle = manualOn;
      _adminOverride = override;
      _scheduleEnabled = schedEnabled;
      _scheduleStart = start;
      _scheduleEnd = end;
      _status = status;
      _currentAmount = amount;
      _amountController.text = amount.toString();
      _loaded = true;
    });
    _startCountdownTimer();
  }

  /// Refresh status from the service (re-computes active state).
  Future<void> _refreshStatus() async {
    final status = await _promoService.getPromoStatus();
    if (!mounted) return;
    setState(() => _status = status);
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _refreshStatus();
    });
  }

  // ── Manual toggle ──
  Future<void> _toggleManual(bool value) async {
    setState(() => _manualToggle = value);
    await _promoService.setManualToggle(value);
    await _refreshStatus();
    if (!mounted) return;
    _showSnack(value ? 'Promo toggled ON' : 'Promo toggled OFF');
  }

  // ── Admin override ──
  Future<void> _toggleOverride(bool value) async {
    setState(() => _adminOverride = value);
    await _promoService.setAdminOverride(value);
    await _refreshStatus();
    if (!mounted) return;
    _showSnack(value
        ? 'Admin Override ON — manual toggle now controls the promo'
        : 'Admin Override OFF — schedule takes priority');
  }

  // ── Schedule ──
  Future<void> _toggleSchedule(bool value) async {
    setState(() => _scheduleEnabled = value);
    if (value) {
      // If enabling with no dates, set sensible defaults
      _scheduleStart ??= DateTime.now();
      _scheduleEnd ??= DateTime.now().add(const Duration(days: 7));
      await _promoService.setSchedule(_scheduleStart!, _scheduleEnd!);
    } else {
      await _promoService.clearSchedule();
    }
    await _refreshStatus();
  }

  Future<void> _pickStartDateTime() async {
    final dt = await _pickDateTime(
      initial: _scheduleStart ?? DateTime.now(),
      helpText: 'Select Promo START date & time',
    );
    if (dt == null) return;
    setState(() => _scheduleStart = dt);
    if (_scheduleEnd != null) {
      await _promoService.setSchedule(dt, _scheduleEnd!);
    }
    await _refreshStatus();
  }

  Future<void> _pickEndDateTime() async {
    final initial = _scheduleEnd ??
        (_scheduleStart ?? DateTime.now()).add(const Duration(days: 7));
    final dt = await _pickDateTime(
      initial: initial,
      helpText: 'Select Promo END date & time',
      firstDate: _scheduleStart,
    );
    if (dt == null) return;
    setState(() => _scheduleEnd = dt);
    if (_scheduleStart != null) {
      await _promoService.setSchedule(_scheduleStart!, dt);
    }
    await _refreshStatus();
  }

  /// Combined date + time picker.
  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    required String helpText,
    DateTime? firstDate,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(2024),
      lastDate: DateTime(2030),
      helpText: helpText,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: BmbColors.blue,
            onPrimary: Colors.white,
            surface: BmbColors.midNavy,
            onSurface: BmbColors.textPrimary,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: BmbColors.deepNavy,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: helpText,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: BmbColors.blue,
            onPrimary: Colors.white,
            surface: BmbColors.midNavy,
            onSurface: BmbColors.textPrimary,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: BmbColors.deepNavy,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── Credit amount ──
  Future<void> _saveAmount() async {
    final text = _amountController.text.trim();
    final amount = int.tryParse(text);
    if (amount == null || amount < 1) {
      _showSnack('Please enter a valid number (1 or more)');
      return;
    }
    setState(() => _saving = true);
    await _promoService.setCreditAmount(amount);
    if (!mounted) return;
    setState(() {
      _currentAmount = amount;
      _saving = false;
    });
    _showSnack('Credit amount updated to $amount');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: BmbColors.midNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  // ─── BUILD ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: _loaded
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildStatusCard(),
                      const SizedBox(height: 20),
                      _buildScheduleCard(),
                      const SizedBox(height: 20),
                      _buildOverrideCard(),
                      const SizedBox(height: 20),
                      _buildCreditAmountCard(),
                      const SizedBox(height: 20),
                      _buildPlatformsList(),
                      const SizedBox(height: 20),
                      _buildPreviewCard(),
                      const SizedBox(height: 30),
                    ],
                  ),
                )
              : const Center(
                  child:
                      CircularProgressIndicator(color: BmbColors.blue)),
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: BmbColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text('Social Follow Promo',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 20,
                  fontWeight: BmbFontWeights.bold,
                  fontFamily: 'ClashDisplay')),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: BmbColors.errorRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: BmbColors.errorRed.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings,
                  color: BmbColors.errorRed, size: 14),
              const SizedBox(width: 4),
              Text('ADMIN',
                  style: TextStyle(
                      color: BmbColors.errorRed,
                      fontSize: 10,
                      fontWeight: BmbFontWeights.bold,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STATUS CARD (dynamic) ─────────────────────────────────────────

  Widget _buildStatusCard() {
    final status = _status;
    final active = status?.isActive ?? _manualToggle;
    final reason = status?.reason ?? '';

    // Colours
    final Color mainColor;
    final IconData mainIcon;
    final String label;

    switch (status?.mode) {
      case PromoMode.scheduledLive:
        mainColor = BmbColors.successGreen;
        mainIcon = Icons.timer;
        label = 'LIVE — SCHEDULED';
      case PromoMode.scheduled:
        mainColor = BmbColors.blue;
        mainIcon = Icons.schedule;
        label = 'SCHEDULED';
      case PromoMode.expired:
        mainColor = BmbColors.textTertiary;
        mainIcon = Icons.timer_off;
        label = 'EXPIRED';
      case PromoMode.override:
        mainColor = BmbColors.vipPurple;
        mainIcon = Icons.admin_panel_settings;
        label = active ? 'OVERRIDE — ON' : 'OVERRIDE — OFF';
      default:
        mainColor = active ? BmbColors.successGreen : BmbColors.errorRed;
        mainIcon = active ? Icons.campaign : Icons.campaign_outlined;
        label = active ? 'ACTIVE' : 'INACTIVE';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          mainColor.withValues(alpha: 0.12),
          mainColor.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(mainIcon, color: mainColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Promo Status',
                        style: TextStyle(
                            color: BmbColors.textSecondary,
                            fontSize: 12,
                            fontWeight: BmbFontWeights.semiBold)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(
                            color: mainColor,
                            fontSize: 18,
                            fontWeight: BmbFontWeights.bold,
                            letterSpacing: 1)),
                  ],
                ),
              ),
              // Manual toggle — always visible
              Switch(
                value: _manualToggle,
                onChanged: _toggleManual,
                activeThumbColor: BmbColors.successGreen,
                activeTrackColor:
                    BmbColors.successGreen.withValues(alpha: 0.4),
                inactiveThumbColor: BmbColors.errorRed,
                inactiveTrackColor:
                    BmbColors.errorRed.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Reason banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BmbColors.cardDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: mainColor.withValues(alpha: 0.7), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(reason,
                      style: TextStyle(
                          color: BmbColors.textTertiary,
                          fontSize: 11,
                          height: 1.4)),
                ),
              ],
            ),
          ),

          // Countdown / schedule summary when scheduled & live
          if (status?.mode == PromoMode.scheduledLive &&
              status?.scheduleEnd != null) ...[
            const SizedBox(height: 10),
            _buildCountdown(status!.scheduleEnd!),
          ],

          // Countdown to start
          if (status?.mode == PromoMode.scheduled &&
              status?.scheduleStart != null) ...[
            const SizedBox(height: 10),
            _buildCountdownToStart(status!.scheduleStart!),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdown(DateTime endTime) {
    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative) {
      return const SizedBox.shrink();
    }
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BmbColors.successGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: BmbColors.successGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom,
              color: BmbColors.successGreen, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ends in',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 10)),
                Text(
                  d > 0
                      ? '${d}d ${h}h ${m}m ${s}s'
                      : h > 0
                          ? '${h}h ${m}m ${s}s'
                          : '${m}m ${s}s',
                  style: TextStyle(
                      color: BmbColors.successGreen,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay'),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM d, h:mm a').format(endTime),
            style: TextStyle(
                color: BmbColors.textTertiary,
                fontSize: 11,
                fontWeight: BmbFontWeights.semiBold),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownToStart(DateTime startTime) {
    final remaining = startTime.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: BmbColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: BmbColors.blue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: BmbColors.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starts in',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 10)),
                Text(
                  d > 0
                      ? '${d}d ${h}h ${m}m ${s}s'
                      : h > 0
                          ? '${h}h ${m}m ${s}s'
                          : '${m}m ${s}s',
                  style: TextStyle(
                      color: BmbColors.blue,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay'),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM d, h:mm a').format(startTime),
            style: TextStyle(
                color: BmbColors.textTertiary,
                fontSize: 11,
                fontWeight: BmbFontWeights.semiBold),
          ),
        ],
      ),
    );
  }

  // ─── SCHEDULE CARD ─────────────────────────────────────────────────

  Widget _buildScheduleCard() {
    final fmt = DateFormat('MMM d, yyyy — h:mm a');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.blue.withValues(alpha: 0.1),
          BmbColors.blue.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + toggle
          Row(
            children: [
              const Icon(Icons.date_range, color: BmbColors.blue, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Automated Schedule',
                    style: TextStyle(
                        color: BmbColors.blue,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
              ),
              Switch(
                value: _scheduleEnabled,
                onChanged: _toggleSchedule,
                activeThumbColor: BmbColors.blue,
                activeTrackColor: BmbColors.blue.withValues(alpha: 0.4),
                inactiveThumbColor: BmbColors.textTertiary,
                inactiveTrackColor: BmbColors.borderColor,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set a start and end time. The promo will auto-activate at start and auto-deactivate at the end.',
            style: TextStyle(
                color: BmbColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Start date/time
          _buildDateTimeRow(
            label: 'Start',
            icon: Icons.play_circle_outline,
            color: BmbColors.successGreen,
            value: _scheduleStart != null ? fmt.format(_scheduleStart!) : 'Not set',
            enabled: _scheduleEnabled,
            onTap: _scheduleEnabled ? _pickStartDateTime : null,
          ),
          const SizedBox(height: 10),

          // End date/time
          _buildDateTimeRow(
            label: 'End',
            icon: Icons.stop_circle_outlined,
            color: BmbColors.errorRed,
            value: _scheduleEnd != null ? fmt.format(_scheduleEnd!) : 'Not set',
            enabled: _scheduleEnabled,
            onTap: _scheduleEnabled ? _pickEndDateTime : null,
          ),

          // Validation warning
          if (_scheduleEnabled &&
              _scheduleStart != null &&
              _scheduleEnd != null &&
              _scheduleEnd!.isBefore(_scheduleStart!)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BmbColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: BmbColors.errorRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: BmbColors.errorRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'End time must be after start time.',
                      style: TextStyle(
                          color: BmbColors.errorRed, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTimeRow({
    required String label,
    required IconData icon,
    required Color color,
    required String value,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: BmbColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: enabled
                    ? color.withValues(alpha: 0.3)
                    : BmbColors.borderColor),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text('$label:',
                  style: TextStyle(
                      color: BmbColors.textSecondary,
                      fontSize: 13,
                      fontWeight: BmbFontWeights.semiBold)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(value,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 13,
                        fontWeight: BmbFontWeights.bold)),
              ),
              if (enabled)
                Icon(Icons.edit_calendar,
                    color: BmbColors.textTertiary, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── OVERRIDE CARD ─────────────────────────────────────────────────

  Widget _buildOverrideCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.vipPurple.withValues(alpha: 0.1),
          BmbColors.vipPurple.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: BmbColors.vipPurple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings,
                  color: BmbColors.vipPurple, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Admin Override',
                    style: TextStyle(
                        color: BmbColors.vipPurple,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold,
                        fontFamily: 'ClashDisplay')),
              ),
              Switch(
                value: _adminOverride,
                onChanged: _toggleOverride,
                activeThumbColor: BmbColors.vipPurple,
                activeTrackColor:
                    BmbColors.vipPurple.withValues(alpha: 0.4),
                inactiveThumbColor: BmbColors.textTertiary,
                inactiveTrackColor: BmbColors.borderColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BmbColors.cardDark.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _adminOverride ? Icons.lock_open : Icons.lock,
                  color: _adminOverride
                      ? BmbColors.vipPurple
                      : BmbColors.textTertiary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _adminOverride
                        ? 'Override is ON — the manual toggle at the top directly controls the promo, ignoring the schedule.'
                        : 'Override is OFF — if a schedule is set, it controls the promo automatically. You can turn this ON at any time to take manual control.',
                    style: TextStyle(
                        color: BmbColors.textTertiary,
                        fontSize: 11,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CREDIT AMOUNT CARD ────────────────────────────────────────────

  Widget _buildCreditAmountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.gold.withValues(alpha: 0.1),
          BmbColors.gold.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: BmbColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on,
                  color: BmbColors.gold, size: 24),
              const SizedBox(width: 10),
              Text('Credit Reward Amount',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 16,
                      fontWeight: BmbFontWeights.bold,
                      fontFamily: 'ClashDisplay')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter any amount you want to reward new followers.',
            style: TextStyle(
                color: BmbColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Current display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: BmbColors.cardDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BmbColors.borderColor),
            ),
            child: Row(
              children: [
                Text('Current:',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 13)),
                const SizedBox(width: 8),
                Text('$_currentAmount credits',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 16,
                        fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Input + Save
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                      color: BmbColors.textPrimary,
                      fontSize: 18,
                      fontWeight: BmbFontWeights.bold),
                  decoration: InputDecoration(
                    hintText: 'Enter amount...',
                    hintStyle: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 14),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Text('C',
                          style: TextStyle(
                              color: BmbColors.gold,
                              fontSize: 20,
                              fontWeight: BmbFontWeights.bold)),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 36, minHeight: 0),
                    filled: true,
                    fillColor: BmbColors.cardDark,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: BmbColors.borderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: BmbColors.borderColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: BmbColors.gold)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveAmount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BmbColors.gold,
                    foregroundColor: BmbColors.deepNavy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: BmbColors.deepNavy))
                      : Text('Save',
                          style: TextStyle(
                              fontWeight: BmbFontWeights.bold,
                              fontSize: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick-set
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [5, 10, 25, 50, 100].map((amount) {
              final isSelected = _amountController.text == amount.toString();
              return GestureDetector(
                onTap: () {
                  _amountController.text = amount.toString();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BmbColors.gold.withValues(alpha: 0.2)
                        : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? BmbColors.gold
                          : BmbColors.borderColor,
                    ),
                  ),
                  child: Text('$amount',
                      style: TextStyle(
                          color: isSelected
                              ? BmbColors.gold
                              : BmbColors.textSecondary,
                          fontSize: 13,
                          fontWeight: BmbFontWeights.bold)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── PLATFORMS LIST ────────────────────────────────────────────────

  Widget _buildPlatformsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: BmbColors.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Linked Platforms',
              style: TextStyle(
                  color: BmbColors.textPrimary,
                  fontSize: 14,
                  fontWeight: BmbFontWeights.bold)),
          const SizedBox(height: 4),
          Text('Users must visit all 5 to claim credits',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 12),
          ...SocialFollowPromoService.platforms.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(p.colorHex).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_iconFor(p.iconName),
                        color: Color(p.colorHex), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p.name,
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 13,
                            fontWeight: BmbFontWeights.semiBold)),
                  ),
                  Text(p.handle,
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 11)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── PREVIEW CARD ──────────────────────────────────────────────────

  Widget _buildPreviewCard() {
    final active = _status?.isActive ?? _manualToggle;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          BmbColors.blue.withValues(alpha: 0.08),
          BmbColors.blue.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BmbColors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.preview, color: BmbColors.blue, size: 20),
              const SizedBox(width: 8),
              Text('User Preview',
                  style: TextStyle(
                      color: BmbColors.blue,
                      fontSize: 14,
                      fontWeight: BmbFontWeights.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This is what new users will see after signing up:',
            style: TextStyle(
                color: BmbColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: BmbColors.backgroundGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BmbColors.borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.card_giftcard,
                    color: BmbColors.gold, size: 28),
                const SizedBox(height: 6),
                Text('WELCOME BONUS',
                    style: TextStyle(
                        color: BmbColors.gold,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                        color: BmbColors.textSecondary, fontSize: 11),
                    children: [
                      const TextSpan(
                          text: 'Follow all 5 socials to receive '),
                      TextSpan(
                        text: '$_currentAmount FREE credits',
                        style: TextStyle(
                            color: BmbColors.gold,
                            fontWeight: BmbFontWeights.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? BmbColors.gold
                        : BmbColors.cardDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    active
                        ? 'Claim $_currentAmount Credits!'
                        : 'Promo Disabled',
                    style: TextStyle(
                        color: active
                            ? BmbColors.deepNavy
                            : BmbColors.textTertiary,
                        fontSize: 12,
                        fontWeight: BmbFontWeights.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'instagram':
        return Icons.camera_alt;
      case 'tiktok':
        return Icons.music_note;
      case 'twitter':
        return Icons.chat_bubble;
      case 'facebook':
        return Icons.thumb_up;
      case 'youtube':
        return Icons.play_circle_filled;
      default:
        return Icons.link;
    }
  }
}
