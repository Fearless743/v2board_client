import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/proxies/list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> with PageMixin {
  @override
  void initState() {
    super.initState();
    initPageState();
  }

  @override
  Widget? get leading => IconButton(
        icon: const BackButtonIcon(),
        onPressed: () {
          globalState.appController.toPage(PageLabel.dashboard);
        },
      );

  @override
  List<Widget> get actions => [
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: appLocalizations.update,
          onPressed: () {
            globalState.appController.setupClashConfig();
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return const ProxiesListView();
  }
}
