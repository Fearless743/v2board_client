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

    final testUrl = subGroup?.testUrl ?? mainGroup.testUrl;
    final delay = ref.watch(getDelayProvider(
      proxyName: selectedName,
      testUrl: testUrl,
    ));

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
        child: Row(
          children: [
            Expanded(
              child: EmojiText(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            _buildDelayText(context, delay),
          ],
        ),
      ),
    );
  }

  Widget _buildDelayText(BuildContext context, int? delay) {
    if (delay == null || delay == 0) {
      return SizedBox(
        width: 14,
        height: 14,
        child: delay == 0
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.bolt, size: 14),
      );
    }
    return Text(
      delay > 0 ? '$delay ms' : "Timeout",
      style: context.textTheme.labelSmall?.copyWith(
        color: utils.getDelayColor(delay),
      ),
    );
  }
}
