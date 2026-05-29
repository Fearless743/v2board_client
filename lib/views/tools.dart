import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ToolsView extends ConsumerStatefulWidget {
  const ToolsView({super.key});

  @override
  ConsumerState<ToolsView> createState() => _ToolboxViewState();
}

class _ToolboxViewState extends ConsumerState<ToolsView> {
  ListItem<dynamic> _buildNavigationMenuItem(NavigationItem navigationItem) =>
      ListItem.open(
        leading: navigationItem.icon,
        title: Text(Intl.message(navigationItem.label.name)),
        subtitle: navigationItem.description != null
            ? Text(Intl.message(navigationItem.description!))
            : null,
        delegate: OpenDelegate(
          title: Intl.message(navigationItem.label.name),
          widget: navigationItem.view,
        ),
      );

  Widget _buildNavigationMenu(List<NavigationItem> navigationItems) => Column(
        children: [
          for (final navigationItem in navigationItems) ...[
            _buildNavigationMenuItem(navigationItem),
            navigationItems.last != navigationItem
                ? const Divider(
                    height: 0,
                  )
                : Container(),
          ]
        ],
      );

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    final items = [
      Consumer(
        builder: (_, ref, __) {
          final state = ref.watch(moreToolsSelectorStateProvider);
          if (state.navigationItems.isEmpty) {
            return Container();
          }
          return Column(
            children: [
              ListHeader(title: appLocale.more),
              _buildNavigationMenu(state.navigationItems)
            ],
          );
        },
      ),
    ];
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) => items[index],
      padding: const EdgeInsets.only(bottom: 20),
    );
  }
}
