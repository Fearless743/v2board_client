import 'dart:math';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';

class ProxiesListView extends StatelessWidget {
  const ProxiesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, __) {
        final groups = ref.watch(currentGroupsStateProvider).value;
        if (groups.isEmpty) {
          return NullStatus(
            label: appLocalizations.nullTip(appLocalizations.proxies),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (_, index) => ProxyGroupCard(group: groups[index]),
        );
      },
    );
  }
}

class ProxyGroupCard extends StatefulWidget {
  const ProxyGroupCard({
    super.key,
    required this.group,
    this.initiallyExpanded = false,
  });
  final Group group;
  final bool initiallyExpanded;

  @override
  State<ProxyGroupCard> createState() => _ProxyGroupCardState();
}

class _ProxyGroupCardState extends State<ProxyGroupCard>
    with AutomaticKeepAliveClientMixin {
  final _expansibleController = ExpansibleController();

  String get groupName => widget.group.name;

  @override
  void dispose() {
    _expansibleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpanded) {
      _expansibleController.expand();
    }
  }

  void _toggleExpansion() {
    setState(() {
      if (_expansibleController.isExpanded) {
        _expansibleController.collapse();
      } else {
        _expansibleController.expand();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = context.colorScheme;
    final columns = max(
      4 * ((MediaQuery.sizeOf(context).width / 320).ceil()),
      8,
    );
    final proxies = widget.group.all;
    final rowCount = (proxies.length / columns).ceil();
    final rowHeight = getItemHeight(ProxyCardType.expand);
    final totalHeight = rowCount * rowHeight + max(rowCount - 1, 0) * 4.0;
    final bodyHeight = min(totalHeight, MediaQuery.sizeOf(context).height * 0.72);

    return RepaintBoundary(
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Expansible(
          maintainState: false,
          controller: _expansibleController,
          headerBuilder: (context, animation) => GestureDetector(
            onTap: _toggleExpansion,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.opacity80,
                borderRadius: BorderRadius.circular(16.0),
              ),
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: context.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Consumer(
                            builder: (_, ref, __) {
                              final proxyName = ref
                                  .watch(getSelectedProxyNameProvider(groupName))
                                  .getSafeValue("");
                              if (proxyName.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return EmojiText(
                                overflow: TextOverflow.ellipsis,
                                proxyName,
                                style: context.textTheme.labelMedium?.toLight,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _toggleExpansion,
                    icon: CommonExpandIcon(expand: _expansibleController.isExpanded),
                  ),
                ],
              ),
            ),
          ),
          bodyBuilder: (context, animation) {
            return RepaintBoundary(
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: FadeTransition(
                  opacity: animation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
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
                                  child: RepaintBoundary(
                                    child: ProxyCard(
                                      testUrl: widget.group.testUrl,
                                      type: ProxyCardType.expand,
                                      groupType: widget.group.type,
                                      key: ValueKey('$groupName.${proxy.name}'),
                                      proxy: proxy,
                                      groupName: groupName,
                                    ),
                                  ),
                                ),
                              )
                              .toList();
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: rowIndex < rowCount - 1 ? 4.0 : 0,
                            ),
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
                  ),
                ),
              ),
            );
          },
          expansibleBuilder: (context, header, body, animation) =>
              Column(children: [header, body]),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
