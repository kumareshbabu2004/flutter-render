import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import '../../data/models/pool_item.dart';

class AnimatedPoolCard extends StatefulWidget {
  final PoolItem pool;
  final VoidCallback? onTap;
  const AnimatedPoolCard({super.key, required this.pool, this.onTap});

  @override
  State<AnimatedPoolCard> createState() => _AnimatedPoolCardState();
}

class _AnimatedPoolCardState extends State<AnimatedPoolCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    if (widget.pool.isActive) {
      _pulseController.repeat(reverse: true);
      _startCountdown();
    }
  }

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    if (widget.pool.endDate == null) return;
    final diff = widget.pool.endDate!.difference(DateTime.now());
    if (diff.isNegative) {
      setState(() => _countdown = 'Ended');
      _countdownTimer?.cancel();
      return;
    }
    setState(() {
      if (diff.inDays > 0) {
        _countdown = '${diff.inDays}d ${diff.inHours % 24}h ${diff.inMinutes % 60}m';
      } else if (diff.inHours > 0) {
        _countdown = '${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s';
      } else {
        _countdown = '${diff.inMinutes}m ${diff.inSeconds % 60}s';
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.pool.isActive ? BmbColors.successGreen.withValues(alpha: 0.3) : BmbColors.borderColor, width: widget.pool.isActive ? 1 : 0.5),
          boxShadow: widget.pool.isActive ? [BoxShadow(color: BmbColors.successGreen.withValues(alpha: 0.1), blurRadius: 12)] : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.pool.name, style: TextStyle(color: BmbColors.textPrimary, fontSize: 16, fontWeight: BmbFontWeights.semiBold, fontFamily: 'ClashDisplay'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(widget.pool.sport, style: TextStyle(color: BmbColors.textTertiary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: BmbColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${widget.pool.players} players', style: TextStyle(color: BmbColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.emoji_events, size: 14, color: BmbColors.gold),
                      const SizedBox(width: 4),
                      Text('${widget.pool.prizePool.toStringAsFixed(0)} credits', style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.semiBold)),
                    ],
                  ),
                  if (_countdown.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: BmbColors.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: BmbColors.successGreen.withValues(alpha: 0.3)),
                      ),
                      child: Text('Ends in $_countdown', style: TextStyle(color: BmbColors.successGreen, fontSize: 11, fontWeight: BmbFontWeights.semiBold)),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.pool.userRank != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: BmbColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events, color: BmbColors.gold, size: 16),
                    const SizedBox(height: 2),
                    Text('#${widget.pool.userRank}', style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isActive = widget.pool.status.toLowerCase() == 'active';
    final displayText = isActive ? 'LIVE' : widget.pool.status.toUpperCase();
    final color = isActive ? BmbColors.successGreen : widget.pool.status.toLowerCase() == 'upcoming' ? BmbColors.gold : BmbColors.textTertiary;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isActive ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActive) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(shape: BoxShape.circle, color: BmbColors.successGreen)),
                Text(displayText, style: TextStyle(color: color, fontSize: 10, fontWeight: BmbFontWeights.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}
