import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/models/shop.dart';
import 'package:flclashx/services/v2board_service.dart';
import 'package:flclashx/views/shop/payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class PlanDetailView extends StatefulWidget {
  const PlanDetailView({super.key, required this.plan});

  final ShopPlan plan;

  @override
  State<PlanDetailView> createState() => _PlanDetailViewState();
}

class _PlanDetailViewState extends State<PlanDetailView> {
  String? _selectedPeriod;
  final _couponController = TextEditingController();
  CouponCheckResult? _coupon;
  String? _couponError;
  bool _checkingCoupon = false;
  bool _creatingOrder = false;

  @override
  void initState() {
    super.initState();
    final periods = widget.plan.availablePeriods;
    if (periods.isNotEmpty) {
      _selectedPeriod = periods.first.key;
    }
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
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

  int? _priceForPeriod(String? period) {
    return switch (period) {
      'month_price' => widget.plan.monthPrice,
      'quarter_price' => widget.plan.quarterPrice,
      'half_year_price' => widget.plan.halfYearPrice,
      'year_price' => widget.plan.yearPrice,
      'two_year_price' => widget.plan.twoYearPrice,
      'three_year_price' => widget.plan.threeYearPrice,
      'onetime_price' => widget.plan.onetimePrice,
      'reset_price' => widget.plan.resetPrice,
      _ => null,
    };
  }

  int get _originalPrice => _priceForPeriod(_selectedPeriod) ?? 0;

  int get _discountAmount {
    if (_coupon == null) return 0;
    if (_coupon!.isFixed) return _coupon!.value;
    if (_coupon!.isPercentage) return (_originalPrice * _coupon!.value / 100).round();
    return 0;
  }

  int get _finalPrice => (_originalPrice - _discountAmount).clamp(0, _originalPrice);

  Future<void> _checkCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checkingCoupon = true;
      _couponError = null;
      _coupon = null;
    });
    try {
      final session = await V2BoardSessionStore.load();
      if (session == null) return;
      final client = V2BoardClient(baseUrl: session.baseUrl, token: session.token);
      final result = await client.checkCoupon(
        code: code,
        planId: widget.plan.id,
        period: _selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _coupon = result;
          _checkingCoupon = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingCoupon = false;
          _couponError = e.toString();
        });
      }
    }
  }

  Future<void> _createOrder() async {
    if (_selectedPeriod == null || widget.plan.isSoldOut) return;
    setState(() => _creatingOrder = true);
    try {
      final session = await V2BoardSessionStore.load();
      if (session == null) return;
      final client = V2BoardClient(baseUrl: session.baseUrl, token: session.token);
      final tradeNo = await client.saveOrder(
        planId: widget.plan.id,
        period: _selectedPeriod!,
        couponCode: _coupon?.code,
      );
      if (!mounted) return;
      setState(() => _creatingOrder = false);

      final methods = await client.fetchPaymentMethods();
      if (!mounted) return;

      if (_finalPrice == 0) {
        // Free order - checkout immediately
        final result = await client.checkoutOrder(tradeNo: tradeNo, methodId: 0);
        if (!mounted) return;
        if (result.isFree) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).paymentSuccess)),
          );
          Navigator.pop(context);
        }
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => PaymentSheet(
          tradeNo: tradeNo,
          paymentMethods: methods,
          finalPrice: _finalPrice,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _creatingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plan = widget.plan;

    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Plan info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (plan.transferEnable > 0)
                        _DetailInfo(icon: Icons.data_usage, label: appLocale.traffic, value: '${plan.transferEnable} GB'),
                      if (plan.speedLimit != null && plan.speedLimit! > 0)
                        _DetailInfo(icon: Icons.speed, label: appLocale.speedLimit, value: '${plan.speedLimit} Mbps'),
                      if (plan.deviceLimit != null && plan.deviceLimit! > 0)
                        _DetailInfo(icon: Icons.devices, label: appLocale.deviceLimit, value: '${plan.deviceLimit}'),
                    ],
                  ),
                  if (plan.content != null && plan.content!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _PlanContent(content: plan.content!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Period selector
          Text(appLocale.selectPeriod, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plan.availablePeriods.map((entry) {
              final isSelected = _selectedPeriod == entry.key;
              final label = _periodLabel(entry.key, appLocale);
              final price = '¥${(entry.value / 100).toStringAsFixed(2)}';
              return ChoiceChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13)),
                    Text(price, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => setState(() {
                  _selectedPeriod = entry.key;
                  _coupon = null;
                  _couponError = null;
                }),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Coupon input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: InputDecoration(
                    hintText: appLocale.couponCode,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _checkingCoupon ? null : _checkCoupon,
                child: _checkingCoupon
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(appLocale.applyCoupon),
              ),
            ],
          ),
          if (_coupon != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text('${appLocale.couponApplied}: ${_coupon!.name}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() {
                    _coupon = null;
                    _couponController.clear();
                  }),
                ),
              ],
            ),
          ],
          if (_couponError != null) ...[
            const SizedBox(height: 4),
            Text(_couponError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ],

          const SizedBox(height: 24),

          // Price summary
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PriceRow(label: appLocale.originalPrice, value: _originalPrice),
                  if (_discountAmount > 0)
                    _PriceRow(label: appLocale.discount, value: -_discountAmount, color: Colors.green),
                  const Divider(),
                  _PriceRow(
                    label: appLocale.finalPrice,
                    value: _finalPrice,
                    bold: true,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Purchase button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: (plan.isSoldOut || _creatingOrder || _selectedPeriod == null) ? null : _createOrder,
              child: _creatingOrder
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      plan.isSoldOut ? appLocale.soldOut : '${appLocale.purchase} ¥${(_finalPrice / 100).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfo extends StatelessWidget {
  const _DetailInfo({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text('$label: ', style: theme.textTheme.bodySmall),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value, this.bold = false, this.color});

  final String label;
  final int value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('¥${(value / 100).toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _PlanContent extends StatelessWidget {
  const _PlanContent({required this.content});

  final String content;

  static final _htmlTagPattern = RegExp(r'<[a-zA-Z][^>]*>');

  bool get _isHtml => _htmlTagPattern.hasMatch(content);

  bool get _isMarkdown =>
      !_isHtml &&
      (content.contains(RegExp(r'^#{1,6}\s', multiLine: true)) ||
          content.contains(RegExp(r'^\s*[-*+]\s', multiLine: true)) ||
          content.contains(RegExp(r'\[.+\]\(.+\)')) ||
          content.contains(RegExp(r'^\s*>\s', multiLine: true)) ||
          content.contains(RegExp(r'```')));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isHtml) {
      return HtmlWidget(
        content,
        textStyle: theme.textTheme.bodyMedium,
      );
    }

    if (_isMarkdown) {
      return MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyMedium,
        ),
        shrinkWrap: true,
      );
    }

    return Text(content, style: theme.textTheme.bodyMedium);
  }
}
