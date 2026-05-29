import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/models/shop.dart';
import 'package:flclashx/services/v2board_service.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/shop/plan_detail_view.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';

class ShopView extends StatefulWidget {
  const ShopView({super.key});

  @override
  State<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<ShopView> {
  List<ShopPlan> _plans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
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
      final client = V2BoardClient(
        baseUrl: session.baseUrl,
        token: session.token,
      );
      final plans = await client.fetchPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
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

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(appLocale.shop)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _fetchPlans,
                        child: Text(appLocale.refresh),
                      ),
                    ],
                  ),
                )
              : _plans.isEmpty
                  ? Center(child: Text(appLocale.noPlans))
                  : RefreshIndicator(
                      onRefresh: _fetchPlans,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _plans.length,
                        itemBuilder: (_, index) => _PlanCard(
                          plan: _plans[index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlanDetailView(plan: _plans[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap});

  final ShopPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocale = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (plan.isSoldOut)
                    Chip(
                      label: Text(appLocale.soldOut),
                      backgroundColor: theme.colorScheme.errorContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  if (plan.tags != null)
                    ...plan.tags!.map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Chip(
                          label: Text(tag),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 12,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (plan.transferEnable > 0)
                    _InfoChip(
                      icon: Icons.data_usage,
                      label: '${plan.transferEnable} GB',
                    ),
                  if (plan.speedLimit != null && plan.speedLimit! > 0)
                    _InfoChip(
                      icon: Icons.speed,
                      label: '${plan.speedLimit} Mbps',
                    ),
                  if (plan.deviceLimit != null && plan.deviceLimit! > 0)
                    _InfoChip(
                      icon: Icons.devices,
                      label: '${plan.deviceLimit}',
                    ),
                ],
              ),
              if (plan.lowestPrice != null) ...[
                const SizedBox(height: 12),
                Text(
                  '¥${(plan.lowestPrice! / 100).toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  appLocale.perMonth,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
