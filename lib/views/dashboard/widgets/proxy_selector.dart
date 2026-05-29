import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
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
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < groups.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      groups[i].name,
                      style: context.textTheme.bodySmall?.toLight,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Consumer(
                      builder: (_, ref, __) {
                        final proxyName = ref
                            .watch(getSelectedProxyNameProvider(groups[i].name))
                            .getSafeValue("");
                        return EmojiText(
                          proxyName.isEmpty ? "-" : proxyName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: context.textTheme.bodySmall,
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (i < groups.length - 1)
                const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
