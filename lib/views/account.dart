import 'dart:convert';
import 'dart:io';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/services/v2board_service.dart';
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

class AccountView extends ConsumerStatefulWidget {
  const AccountView({super.key});

  @override
  ConsumerState<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends ConsumerState<AccountView> {
  V2BoardSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await V2BoardSessionStore.load();
    if (mounted) {
      setState(() {
        _session = session;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentProfile = ref.watch(currentProfileProvider);
    final subscriptionInfo = currentProfile?.subscriptionInfo;
    final headers = currentProfile?.providerHeaders ?? {};
    final planName = _decodeBase64IfNeeded(headers['flclashx-servicename']) ??
        headers['v2board-plan-name'];
    final email = _session?.email;
    final vm2 = ref.watch(
      appSettingProvider.select(
        (state) => VM2(a: state.locale, b: state.developerMode),
      ),
    );

    final items = <Widget>[
      // Account info section
      ..._buildAccountSection(context, theme, email, planName),
      // Subscription info section
      if (subscriptionInfo != null)
        ..._buildSubscriptionSection(context, theme, subscriptionInfo),
      // Settings section (moved from Tools)
      ..._buildSettingList(context),
      // Other section
      ..._getOtherList(context, vm2.b),
      // Logout
      ..._buildLogoutSection(context),
    ];

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) => items[index],
      padding: const EdgeInsets.only(bottom: 20),
    );
  }

  String? _decodeBase64IfNeeded(String? value) {
    if (value == null || value.isEmpty) return value;
    try {
      return utf8.decode(base64.decode(value));
    } catch (e) {
      return value;
    }
  }

  List<Widget> _buildAccountSection(
    BuildContext context,
    ThemeData theme,
    String? email,
    String? planName,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 40,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                email,
                style: theme.textTheme.titleMedium,
              ),
            ],
            if (planName != null && planName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                planName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildSubscriptionSection(
    BuildContext context,
    ThemeData theme,
    SubscriptionInfo subscriptionInfo,
  ) {
    final appLocale = AppLocalizations.of(context);
    final isUnlimitedTraffic = subscriptionInfo.total == 0;
    final isPerpetual = subscriptionInfo.expire == 0;

    return generateSection(
      title: appLocale.accountSettings,
      items: [
        // Remaining traffic
        if (!isUnlimitedTraffic)
          Builder(builder: (context) {
            final totalTraffic = TrafficValue(value: subscriptionInfo.total);
            final usedTrafficValue =
                subscriptionInfo.upload + subscriptionInfo.download;
            final remainingTraffic =
                TrafficValue(value: subscriptionInfo.total - usedTrafficValue);

            var progress = 0.0;
            if (subscriptionInfo.total > 0) {
              progress = usedTrafficValue / subscriptionInfo.total;
            }
            progress = progress.clamp(0.0, 1.0);

            Color progressColor = Colors.green;
            if (progress > 0.9) {
              progressColor = Colors.red;
            } else if (progress > 0.7) {
              progressColor = Colors.orange;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appLocale.remainingTraffic,
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        '${remainingTraffic.showValue} ${remainingTraffic.showUnit} / ${totalTraffic.showValue} ${totalTraffic.showUnit}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ],
              ),
            );
          })
        else
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.data_usage),
            title: Text(appLocale.remainingTraffic),
            subtitle: Text(appLocale.trafficUnlimited),
          ),
        // Expiration date
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.calendar_today),
          title: Text(appLocale.expirationDate),
          subtitle: Text(
            isPerpetual
                ? appLocale.subscriptionEternal
                : DateFormat('yyyy-MM-dd').format(
                    DateTime.fromMillisecondsSinceEpoch(
                        subscriptionInfo.expire * 1000)),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSettingList(BuildContext context) =>
      generateSection(
        title: AppLocalizations.of(context).settings,
        items: [
          const _LocaleItem(),
          const _ThemeItem(),
          if (Platform.isWindows) const _LoopbackItem(),
          if (Platform.isAndroid) const _AccessItem(),
          const _ConfigItem(),
          const _SettingItem(),
        ],
      );

  List<Widget> _getOtherList(BuildContext context, bool enableDeveloperMode) =>
      generateSection(
        title: AppLocalizations.of(context).other,
        items: [
          if (enableDeveloperMode) const _DeveloperItem(),
        ],
      );

  List<Widget> _buildLogoutSection(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return generateSection(
      items: [
        ListItem(
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            appLocale.logout,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: Text(appLocale.logoutDesc),
          onTap: () async {
            final confirmed = await globalState.showMessage(
              title: appLocale.logout,
              message: TextSpan(text: appLocale.logoutDesc),
            );
            if (confirmed == true) {
              await globalState.appController.logoutV2Board(
                deleteManagedProfile: true,
              );
              exit(0);
            }
          },
        ),
      ],
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
