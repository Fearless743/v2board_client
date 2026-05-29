import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/models/shop.dart';
import 'package:flclashx/services/v2board_service.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderHistoryView extends StatefulWidget {
  const OrderHistoryView({super.key});

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  List<ShopOrder> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await V2BoardSessionStore.load();
      if (session == null) {
        setState(() {
          _loading = false;
          _error = '未登录';
        });
        return;
      }
      final client = V2BoardClient(baseUrl: session.baseUrl, token: session.token);
      final orders = await client.fetchOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _statusLabel(ShopOrder order, AppLocalizations locale) {
    if (order.isPending) return locale.orderPending;
    if (order.isProcessing) return locale.orderProcessing;
    if (order.isCancelled) return locale.orderCancelled;
    if (order.isCompleted) return locale.orderCompleted;
    if (order.isDiscounted) return locale.orderDiscounted;
    return '';
  }

  Color _statusColor(ShopOrder order, ThemeData theme) {
    if (order.isPending) return Colors.orange;
    if (order.isProcessing) return Colors.blue;
    if (order.isCancelled) return theme.colorScheme.error;
    if (order.isCompleted) return Colors.green;
    return theme.colorScheme.onSurfaceVariant;
  }

  String _typeLabel(ShopOrder order, AppLocalizations locale) {
    if (order.isNewPurchase) return locale.orderType1;
    if (order.isRenewal) return locale.orderType2;
    if (order.isUpgrade) return locale.orderType3;
    if (order.isResetTraffic) return locale.orderType4;
    return '';
  }

  String _periodLabel(String period, AppLocalizations locale) {
    return switch (period) {
      'month_price' => locale.monthPrice,
      'quarter_price' => locale.quarterPrice,
      'half_year_price' => locale.halfYearPrice,
      'year_price' => locale.yearPrice,
      'two_year_price' => locale.twoYearPrice,
      'three_year_price' => locale.threeYearPrice,
      'onetime_price' => locale.onetimePrice,
      'reset_price' => locale.resetPrice,
      _ => period,
    };
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _fetchOrders,
                      child: Text(appLocale.refresh),
                    ),
                  ],
                ),
              )
            : _orders.isEmpty
                ? Center(child: Text(appLocale.noOrders))
                : RefreshIndicator(
                    onRefresh: _fetchOrders,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (_, index) => _OrderCard(
                        order: _orders[index],
                        statusLabel: _statusLabel(_orders[index], appLocale),
                        statusColor: _statusColor(_orders[index], theme),
                        typeLabel: _typeLabel(_orders[index], appLocale),
                        periodLabel: _periodLabel(_orders[index].period, appLocale),
                        onCancel: _orders[index].isPending ? () => _cancelOrder(_orders[index]) : null,
                      ),
                    ),
                  );
  }

  Future<void> _cancelOrder(ShopOrder order) async {
    final appLocale = AppLocalizations.of(context);
    final confirmed = await globalState.showMessage(
      title: appLocale.cancelOrder,
      message: TextSpan(text: '${appLocale.cancelOrder} ${order.tradeNo}?'),
    );
    if (confirmed != true) return;
    try {
      final session = await V2BoardSessionStore.load();
      if (session == null) return;
      final client = V2BoardClient(baseUrl: session.baseUrl, token: session.token);
      await client.cancelOrder(order.tradeNo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appLocale.orderCancelled)),
        );
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusLabel,
    required this.statusColor,
    required this.typeLabel,
    required this.periodLabel,
    this.onCancel,
  });

  final ShopOrder order;
  final String statusLabel;
  final Color statusColor;
  final String typeLabel;
  final String periodLabel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planName = order.plan?.name ?? 'Plan #${order.planId}';
    final date = DateFormat('yyyy-MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(order.createdAt * 1000),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    planName,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(typeLabel, style: theme.textTheme.bodySmall),
                const SizedBox(width: 8),
                Text(periodLabel, style: theme.textTheme.bodySmall),
                const Spacer(),
                Text(
                  '¥${(order.totalAmount / 100).toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${order.tradeNo}  $date',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: Text(
                    AppLocalizations.of(context).cancelOrder,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
