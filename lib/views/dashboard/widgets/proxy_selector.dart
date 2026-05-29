import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/providers/app.dart';
import 'package:flclashx/providers/state.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxySelectorWidget extends ConsumerWidget {
  const ProxySelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(currentGroupsStateProvider).value;
    if (groups.isEmpty) return const SizedBox.shrink();

    final mainGroup = groups.first;
    final selectedName = ref
        .watch(getSelectedProxyNameProvider(mainGroup.name))
        .getSafeValue("");

    if (selectedName.isEmpty) return const SizedBox.shrink();

    final allGroups = ref.watch(groupsProvider);
    final subGroup = allGroups.where((g) => g.name == selectedName).firstOrNull;

    final displayText = subGroup != null
        ? "$selectedName / ${ref.watch(getSelectedProxyNameProvider(subGroup.name)).getSafeValue("-")}"
        : selectedName;

    return CommonCard(
      onPressed: () {
        globalState.appController.toPage(PageLabel.proxies);
      },
      info: Info(
        label: appLocalizations.proxies,
        iconData: Icons.article,
      ),
      child: Container(
        padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8),
        child: EmojiText(
          displayText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
