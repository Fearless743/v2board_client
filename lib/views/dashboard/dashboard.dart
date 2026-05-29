import 'dart:math';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/start_button.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> with PageMixin {
  @override
  void initState() {
    ref.listenManual(
      isCurrentPageProvider(PageLabel.dashboard),
      (prev, next) {
        if (prev != next && next == true) {
          initPageState();
        }
      },
      fireImmediately: true,
    );
    return super.initState();
  }

  @override
  Widget? get floatingActionButton => null;

  @override
  List<Widget> get actions => [];

  @override
  Widget build(BuildContext context) {
    final viewWidth = ref.watch(viewWidthProvider);
    final columns = max(4 * ((viewWidth / 320).ceil()), 8);
    final spacing = 16.ap;

    final children = DashboardWidget.values
        .where((item) => item.platforms.contains(SupportPlatform.currentPlatform))
        .map((item) => item.widget)
        .toList();

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Grid(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                children: children,
              ),
            ),
          ),
        ),
        const StartButton(),
      ],
    );
  }
}
