import 'package:flclashx/common/mixin.dart';
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
  Widget build(BuildContext context) {
    return const ProxiesListView();
  }
}
