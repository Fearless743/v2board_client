import 'dart:math';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/state.dart';
import 'package:flclashx/views/proxies/card.dart';
import 'package:flclashx/views/proxies/common.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxySelectorWidget extends ConsumerWidget {
  const ProxySelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(currentGroupsStateProvider).value;
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return CommonCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < groups.length; i++) ...[
            _ProxyGroupTile(group: groups[i]),
            if (i < groups.length - 1)
              Divider(height: 1, color: context.colorScheme.outlineVariant.opacity50),
          ],
        ],
      ),
    );
  }
}

class _ProxyGroupTile extends StatefulWidget {
  const _ProxyGroupTile({required this.group});
  final Group group;

  @override
  State<_ProxyGroupTile> createState() => _ProxyGroupTileState();
}

class _ProxyGroupTileState extends State<_ProxyGroupTile> {
  bool _expanded = false;

  String get groupName => widget.group.name;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final columns = max(4 * ((MediaQuery.sizeOf(context).width / 320).ceil()), 8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(groupName, style: context.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Consumer(
                        builder: (_, ref, __) {
                          final proxyName = ref
                              .watch(getSelectedProxyNameProvider(groupName))
                              .getSafeValue("");
                          if (proxyName.isEmpty) return const SizedBox.shrink();
                          return EmojiText(
                            proxyName,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall?.toLight,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                CommonExpandIcon(expand: _expanded),
              ],
            ),
          ),
        ),
        if (_expanded)
          _ProxyGrid(
            group: group,
            columns: columns,
          ),
      ],
    );
  }
}

class _ProxyGrid extends StatelessWidget {
  const _ProxyGrid({required this.group, required this.columns});
  final Group group;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final proxies = group.all;
    final rowCount = (proxies.length / columns).ceil();
    final rowHeight = getItemHeight(ProxyCardType.oneline);
    final totalHeight = rowCount * rowHeight + max(rowCount - 1, 0) * 4.0;
    final bodyHeight = min(totalHeight, MediaQuery.sizeOf(context).height * 0.5);

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      child: SizedBox(
        height: bodyHeight,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: rowCount,
          itemBuilder: (_, rowIndex) {
            final start = rowIndex * columns;
            final end = min(start + columns, proxies.length);
            final rowProxies = proxies.sublist(start, end);
            final children = rowProxies
                .map<Widget>(
                  (proxy) => Flexible(
                    flex: 1,
                    child: ProxyCard(
                      testUrl: group.testUrl,
                      type: ProxyCardType.oneline,
                      groupType: group.type,
                      key: ValueKey('${group.name}.${proxy.name}'),
                      proxy: proxy,
                      groupName: group.name,
                    ),
                  ),
                )
                .toList();
            return Padding(
              padding: EdgeInsets.only(bottom: rowIndex < rowCount - 1 ? 4.0 : 0),
              child: Row(
                children: [
                  ...children,
                  ...List.generate(
                    columns - children.length,
                    (_) => const Flexible(child: SizedBox()),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
