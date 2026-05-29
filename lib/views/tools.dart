import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/services/core_updater_service.dart';
import 'package:flclashx/state.dart';
import 'package:flclashx/views/access.dart';
import 'package:flclashx/views/application_setting.dart';
import 'package:flclashx/views/config/config.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show dirname, join;

import 'developer.dart';
import 'theme.dart';

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

  List<Widget> _getOtherList(BuildContext context, bool enableDeveloperMode) =>
      generateSection(
        title: AppLocalizations.of(context).other,
        items: [
          if (enableDeveloperMode) const _DeveloperItem(),
        ],
      );

  List<Widget> _getSettingList(BuildContext context) => generateSection(
        title: AppLocalizations.of(context).settings,
        items: [
          const _LocaleItem(),
          const _ThemeItem(),
          if (Platform.isWindows) const _LoopbackItem(),
          if (Platform.isAndroid) const _AccessItem(),
          const _CoreUpdateItem(),
          const _ConfigItem(),
          const _SettingItem(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final vm2 = ref.watch(
      appSettingProvider.select(
        (state) => VM2(a: state.locale, b: state.developerMode),
      ),
    );
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
      ..._getSettingList(context),
      ..._getOtherList(context, vm2.b),
    ];
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) => items[index],
      padding: const EdgeInsets.only(bottom: 20),
    );
  }
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(BuildContext context, Locale? locale) {
    if (locale == null) return AppLocalizations.of(context).defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = AppLocalizations.of(context);
    final locale =
        ref.watch(appSettingProvider.select((state) => state.locale));
    final subTitle = locale ?? appLocale.defaultText;
    final currentLocale = utils.getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: const Icon(Icons.language_outlined),
      title: Text(appLocale.language),
      subtitle: Text(Intl.message(subTitle)),
      delegate: OptionsDelegate(
        title: appLocale.language,
        options: [null, ...AppLocalizations.delegate.supportedLocales],
        onChanged: (locale) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(locale: locale?.toString()),
              );
        },
        textBuilder: (locale) => _getLocaleString(context, locale),
        value: currentLocale,
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.style),
      title: Text(appLocale.theme),
      subtitle: Text(appLocale.themeDesc),
      delegate: OpenDelegate(
        title: appLocale.theme,
        widget: const ThemeView(),
      ),
    );
  }
}

class _LoopbackItem extends StatelessWidget {
  const _LoopbackItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem(
      leading: const Icon(Icons.lock),
      title: Text(appLocale.loopback),
      subtitle: Text(appLocale.loopbackDesc),
      onTap: () {
        windows?.runas(
          '"${join(dirname(Platform.resolvedExecutable), "EnableLoopback.exe")}"',
          "",
        );
      },
    );
  }
}

class _AccessItem extends StatelessWidget {
  const _AccessItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.view_list),
      title: Text(appLocale.accessControl),
      subtitle: Text(appLocale.accessControlDesc),
      delegate: OpenDelegate(
        title: appLocale.appAccessControl,
        widget: const AccessView(),
      ),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  const _ConfigItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.edit),
      title: Text(appLocale.basicConfig),
      subtitle: Text(appLocale.basicConfigDesc),
      delegate: OpenDelegate(
        title: appLocale.override,
        widget: const ConfigView(),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.settings),
      title: Text(appLocale.application),
      subtitle: Text(appLocale.applicationDesc),
      delegate: OpenDelegate(
        title: appLocale.application,
        widget: const ApplicationSettingView(),
      ),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const Icon(Icons.developer_board),
      title: Text(appLocale.developerMode),
      delegate: OpenDelegate(
        title: appLocale.developerMode,
        widget: const DeveloperView(),
      ),
    );
  }
}

class _CoreUpdateItem extends StatefulWidget {
  const _CoreUpdateItem();

  @override
  State<_CoreUpdateItem> createState() => _CoreUpdateItemState();
}

class _CoreUpdateItemState extends State<_CoreUpdateItem> {
  String _installedVersion = '';
  bool _checking = false;
  bool _downloading = false;
  double _progress = 0.0;
  String _status = '';
  CoreUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await coreUpdater.getInstalledCoreVersion();
    if (!mounted) return;
    setState(() {
      _installedVersion = version;
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checking = true;
      _status = '正在检查更新...';
    });

    try {
      final info = await coreUpdater.checkForCoreUpdate(force: true);
      if (!mounted) return;

      if (info != null) {
        setState(() {
          _updateInfo = info;
          _status = '发现新版本 ${info.tagName}';
        });
      } else {
        setState(() {
          _status = '当前已是最新版本';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '检查更新失败';
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _downloadUpdate() async {
    if (_updateInfo == null) return;

    setState(() {
      _downloading = true;
      _progress = 0;
      _status = '正在下载...';
    });

    final success = await coreUpdater.downloadAndInstall(
      _updateInfo!,
      onProgress: (p, s) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _status = s;
        });
      },
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _installedVersion = _updateInfo!.tagName;
        _updateInfo = null;
        _status = '更新完成，重启后生效';
      });
    } else {
      setState(() {
        _status = '更新失败，请重试';
      });
    }

    setState(() {
      _downloading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _installedVersion.isNotEmpty
        ? 'v$_installedVersion'
        : globalState.coreVersion ?? '';

    return ListItem(
      leading: const Icon(Icons.system_update),
      title: const Text('内核更新'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('当前版本: $subtitle'),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _status,
              style: TextStyle(
                color: _status.contains('失败')
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: _progress),
          ],
        ],
      ),
      onTap: _checking || _downloading
          ? null
          : _updateInfo != null
              ? _downloadUpdate
              : _checkForUpdate,
    );
  }
}
