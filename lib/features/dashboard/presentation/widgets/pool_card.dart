import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import '../../data/models/pool_item.dart';

class PoolCard extends StatelessWidget {
  final PoolItem pool;
  final VoidCallback? onTap;

  const PoolCard({super.key, required this.pool, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: BmbColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BmbColors.borderColor, width: 0.5),
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
                        child: Text(
                          pool.name,
                          style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 16,
                            fontWeight: BmbFontWeights.semiBold,
                            fontFamily: 'ClashDisplay',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pool.sport,
                    style: TextStyle(color: BmbColors.textTertiary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: BmbColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${pool.players} players',
                        style: TextStyle(color: BmbColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.emoji_events, size: 14, color: BmbColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        '${pool.prizePool.toStringAsFixed(0)} credits',
                        style: TextStyle(color: BmbColors.gold, fontSize: 12, fontWeight: BmbFontWeights.semiBold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (pool.userRank != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: BmbColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events, color: BmbColors.gold, size: 16),
                    const SizedBox(height: 2),
                    Text(
                      '#${pool.userRank}',
                      style: TextStyle(color: BmbColors.gold, fontSize: 14, fontWeight: BmbFontWeights.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final displayText = pool.status.toLowerCase() == 'active' ? 'LIVE' : pool.status.toUpperCase();
    final color = pool.status.toLowerCase() == 'active'
        ? BmbColors.successGreen
        : pool.status.toLowerCase() == 'upcoming'
            ? BmbColors.gold
            : BmbColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(displayText, style: TextStyle(color: color, fontSize: 10, fontWeight: BmbFontWeights.bold)),
    );
  }
}
