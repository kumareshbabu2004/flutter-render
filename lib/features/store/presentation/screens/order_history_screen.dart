import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/features/store/data/models/store_models.dart';
import 'package:bmb_mobile/features/store/data/services/store_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<StoreOrder> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await StoreService.instance.getOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: BmbColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: BmbColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text('My Orders',
                        style: TextStyle(
                            color: BmbColors.textPrimary,
                            fontSize: 20,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long,
                                    color: BmbColors.textTertiary, size: 48),
                                const SizedBox(height: 12),
                                Text('No orders yet',
                                    style: TextStyle(
                                        color: BmbColors.textTertiary,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                    'Redeem products from the BMB Store to see them here.',
                                    style: TextStyle(
                                        color: BmbColors.textTertiary,
                                        fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _orders.length,
                            itemBuilder: (ctx, i) =>
                                _buildOrderCard(_orders[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(StoreOrder order) {
    final statusColor = _statusColor(order.status);
    final isDigital = order.isDigital;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
              Icon(
                isDigital ? Icons.card_giftcard : Icons.local_shipping,
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(order.productName,
                    style: TextStyle(
                        color: BmbColors.textPrimary,
                        fontSize: 14,
                        fontWeight: BmbFontWeights.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(order.statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: BmbFontWeights.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${order.creditsCost} credits',
                  style: TextStyle(
                      color: BmbColors.gold,
                      fontSize: 12,
                      fontWeight: BmbFontWeights.semiBold)),
              const Text(' · ', style: TextStyle(color: BmbColors.textTertiary)),
              Text(_formatDate(order.createdAt),
                  style: TextStyle(
                      color: BmbColors.textTertiary, fontSize: 11)),
            ],
          ),
          if (order.selectedSize != null || order.selectedColor != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (order.selectedSize != null)
                  Text('Size: ${order.selectedSize}',
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 11)),
                if (order.selectedSize != null && order.selectedColor != null)
                  const Text(' · ',
                      style: TextStyle(color: BmbColors.textTertiary)),
                if (order.selectedColor != null)
                  Text('Color: ${order.selectedColor}',
                      style: TextStyle(
                          color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ],
          if (order.bracketName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.account_tree,
                    color: BmbColors.textTertiary, size: 14),
                const SizedBox(width: 4),
                Text('Bracket: ${order.bracketName}',
                    style: TextStyle(
                        color: BmbColors.textTertiary, fontSize: 11)),
              ],
            ),
          ],
          // Gift card code
          if (order.redemptionCode != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: BmbColors.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: BmbColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key,
                      color: BmbColors.successGreen, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(order.redemptionCode!,
                        style: TextStyle(
                            color: BmbColors.successGreen,
                            fontSize: 13,
                            fontWeight: BmbFontWeights.bold,
                            fontFamily: 'ClashDisplay',
                            letterSpacing: 1)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: order.redemptionCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Code copied!'),
                          backgroundColor: BmbColors.successGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy,
                        color: BmbColors.textTertiary, size: 18),
                  ),
                ],
              ),
            ),
          ],
          // Tracking number
          if (order.trackingNumber != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_shipping,
                    color: BmbColors.blue, size: 14),
                const SizedBox(width: 6),
                Text('Tracking: ${order.trackingNumber}',
                    style: TextStyle(color: BmbColors.blue, fontSize: 11)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text('Order ID: ${order.id}',
              style: TextStyle(
                  color: BmbColors.textTertiary, fontSize: 10)),
        ],
      ),
    );
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return BmbColors.gold;
      case OrderStatus.processing:
        return BmbColors.blue;
      case OrderStatus.fulfilled:
        return BmbColors.successGreen;
      case OrderStatus.shipped:
        return BmbColors.blue;
      case OrderStatus.delivered:
        return BmbColors.successGreen;
      case OrderStatus.cancelled:
        return BmbColors.errorRed;
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
