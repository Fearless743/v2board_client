import 'package:flclashx/common/common.dart';
import 'package:flclashx/services/core_updater_service.dart';
import 'package:flclashx/services/v2board_service.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';

enum _GatePhase { coreCheck, coreDownload, sessionCheck, ready }

class V2BoardLoginGate extends StatefulWidget {
  const V2BoardLoginGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<V2BoardLoginGate> createState() => _V2BoardLoginGateState();
}

class _V2BoardLoginGateState extends State<V2BoardLoginGate> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  _GatePhase _phase = _GatePhase.coreCheck;
  bool loggedIn = false;
  String? error;

  // Core update state
  double _coreProgress = 0.0;
  String _coreStatus = '正在检查内核更新...';
  CoreUpdateInfo? _pendingUpdate;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    await _checkCoreUpdate();
    if (!mounted) return;
    await _loadSession();
  }

  Future<void> _checkCoreUpdate() async {
    try {
      final update = await coreUpdater.checkForCoreUpdate(force: true);
      if (!mounted) return;

      if (update == null) {
        setState(() {
          _coreStatus = '内核已是最新版本';
        });
        // Brief pause so user sees the status
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }

      setState(() {
        _pendingUpdate = update;
        _phase = _GatePhase.coreDownload;
        _coreStatus = '发现新内核 ${update.tagName}，正在下载...';
      });

      final success = await coreUpdater.downloadAndInstall(
        update,
        onProgress: (progress, status) {
          if (!mounted) return;
          setState(() {
            _coreProgress = progress;
            _coreStatus = status;
          });
        },
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _coreStatus = '内核更新完成';
        });
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        setState(() {
          _coreStatus = '内核更新失败，将使用当前版本继续';
        });
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _coreStatus = '内核检查失败，继续启动...';
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _loadSession() async {
    setState(() {
      _phase = _GatePhase.sessionCheck;
    });

    final session = await V2BoardSessionStore.load();
    if (session == null) {
      if (!mounted) return;
      setState(() {
        loggedIn = false;
        _phase = _GatePhase.ready;
        error = globalState.v2boardBaseUrl.isEmpty
            ? '未配置 V2Board 面板地址，请在启动参数中设置 V2BOARD_BASE_URL。'
            : null;
      });
      return;
    }

    try {
      final isLoggedIn = await globalState.appController.checkV2BoardLogin(
        clearSessionOnInvalid: true,
        silent: false,
      );
      if (!mounted) return;
      setState(() {
        loggedIn = isLoggedIn;
        _phase = _GatePhase.ready;
        error = isLoggedIn ? null : '登录已失效，请重新登录。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loggedIn = false;
        _phase = _GatePhase.ready;
        error = e.toString();
      });
    }
  }

  Future<void> _login() async {
    final baseUrl = globalState.v2boardBaseUrl;
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (baseUrl.isEmpty || email.isEmpty || password.isEmpty) return;

    setState(() {
      _phase = _GatePhase.sessionCheck;
      error = null;
    });

    try {
      await globalState.appController.loginAndImportV2Board(
        baseUrl: baseUrl,
        email: email,
        password: password,
      );
      if (!mounted) return;
      setState(() {
        loggedIn = true;
        _phase = _GatePhase.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        _phase = _GatePhase.ready;
      });
    }
  }

  Future<void> _skipCoreUpdate() async {
    if (!mounted) return;
    setState(() {
      _phase = _GatePhase.sessionCheck;
    });
    await _loadSession();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _GatePhase.coreCheck || _phase == _GatePhase.coreDownload) {
      return _buildCoreUpdateView();
    }
    if (_phase == _GatePhase.sessionCheck) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (loggedIn) {
      return widget.child;
    }
    return _buildLoginView();
  }

  Widget _buildCoreUpdateView() {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.system_update,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'FlClashX',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_pendingUpdate != null) ...[
                    LinearProgressIndicator(value: _coreProgress),
                    const SizedBox(height: 8),
                    Text(
                      '${(_coreProgress * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _coreStatus,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (_pendingUpdate != null) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _skipCoreUpdate,
                      child: const Text('跳过更新'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    appLocalizations.v2boardLogin,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLocalizations.email,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: appLocalizations.password,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _login,
                    child: Text(appLocalizations.login),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
