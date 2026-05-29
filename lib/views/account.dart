import 'dart:io';

import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/services/v2board_service.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/tools.dart';
import 'package:flclashx/views/shop/shop_view.dart';
import 'package:flclashx/views/shop/order_history_view.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AccountView extends ConsumerStatefulWidget {
  const AccountView({super.key});

  @override
  ConsumerState<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends ConsumerState<AccountView> {
  V2BoardSession? _session;
  V2BoardUserInfo? _userInfo;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSessionAndFetch();
  }

  Future<void> _loadSessionAndFetch() async {
    final session = await V2BoardSessionStore.load();
    if (!mounted || session == null) return;
    setState(() {
      _session = session;
    });
    await _fetchSubscribe();
  }

  Future<void> _fetchSubscribe() async {
    final session = _session;
    if (session == null) return;
    setState(() => _loading = true);
    try {
      final client = V2BoardClient(
        baseUrl: session.baseUrl,
        token: session.token,
      );
      final userInfo = await client.getSubscribe();
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final email = _userInfo?.email ?? _session?.email;
    final planName = _userInfo?.planName;
    final subscriptionInfo = _userInfo != null
        ? _userInfo!.subscriptionInfo
        : ref.watch(currentProfileProvider)?.subscriptionInfo;

    final items = <Widget>[
      ..._buildInfoSection(context, theme, email, planName, subscriptionInfo),
      ..._buildActionsSection(context),
      ..._buildLogoutSection(context),
    ];

    return Stack(
      children: [
        ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, index) => items[index],
          padding: const EdgeInsets.only(bottom: 20),
        ),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  List<Widget> _buildInfoSection(
    BuildContext context,
    ThemeData theme,
    String? email,
    String? planName,
    SubscriptionInfo? subscriptionInfo,
  ) {
    final appLocale = AppLocalizations.of(context);
    final labelStyle = theme.textTheme.bodyLarge;
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final isUnlimitedTraffic = subscriptionInfo == null || subscriptionInfo.total == 0;
    final isPerpetual = subscriptionInfo == null || subscriptionInfo.expire == 0;

    return generateSection(
      separated: false,
      items: [
        if (email != null && email.isNotEmpty)
          _InfoRow(label: appLocale.email, value: email),
        if (planName != null && planName.isNotEmpty)
          _InfoRow(label: appLocale.subscriptionPlan, value: planName),
        if (!isUnlimitedTraffic)
          Builder(builder: (context) {
            final totalTraffic = TrafficValue(value: subscriptionInfo.total);
            final usedTrafficValue =
                subscriptionInfo.upload + subscriptionInfo.download;
            final remainingTraffic =
                TrafficValue(value: subscriptionInfo.total - usedTrafficValue);

            var progress = 0.0;
            if (subscriptionInfo.total > 0) {
              progress = usedTrafficValue / subscriptionInfo.total;
            }
            progress = progress.clamp(0.0, 1.0);

            Color progressColor = Colors.green;
            if (progress > 0.9) {
              progressColor = Colors.red;
            } else if (progress > 0.7) {
              progressColor = Colors.orange;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(appLocale.remainingTraffic, style: labelStyle),
                      Text(
                        '${remainingTraffic.showValue} ${remainingTraffic.showUnit} / ${totalTraffic.showValue} ${totalTraffic.showUnit}',
                        style: valueStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
              ),
            );
          })
        else if (subscriptionInfo != null)
          _InfoRow(
            label: appLocale.remainingTraffic,
            value: appLocale.trafficUnlimited,
          ),
        if (subscriptionInfo != null)
          _InfoRow(
            label: appLocale.expirationDate,
            value: isPerpetual
                ? appLocale.subscriptionEternal
                : DateFormat('yyyy-MM-dd').format(
                    DateTime.fromMillisecondsSinceEpoch(
                        subscriptionInfo.expire * 1000)),
          ),
      ],
    );
  }

  List<Widget> _buildActionsSection(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return generateSection(
      items: [
        ListItem(
          leading: const Icon(Icons.sync),
          title: Text(appLocale.refresh),
          onTap: _fetchSubscribe,
        ),
        ListItem.open(
          leading: const Icon(Icons.store),
          title: Text(appLocale.shop),
          delegate: OpenDelegate(
            title: appLocale.shop,
            widget: const ShopView(),
          ),
        ),
        ListItem.open(
          leading: const Icon(Icons.receipt_long),
          title: Text(appLocale.orderHistory),
          delegate: OpenDelegate(
            title: appLocale.orderHistory,
            widget: const OrderHistoryView(),
          ),
        ),
        ListItem.open(
          leading: const Icon(Icons.settings),
          title: Text(appLocale.settings),
          delegate: OpenDelegate(
            title: appLocale.settings,
            widget: const ToolsView(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildLogoutSection(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return generateSection(
      items: [
        ListItem(
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            appLocale.logout,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: Text(appLocale.logoutDesc),
          onTap: () async {
            final confirmed = await globalState.showMessage(
              title: appLocale.logout,
              message: TextSpan(text: appLocale.logoutDesc),
            );
            if (confirmed == true) {
              await globalState.appController.logoutV2Board(
                deleteManagedProfile: true,
              );
              exit(0);
            }
          },
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
