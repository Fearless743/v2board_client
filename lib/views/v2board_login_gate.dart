import 'package:flclashx/common/common.dart';
import 'package:flclashx/services/v2board_service.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';

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
  bool loading = true;
  bool loggedIn = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await V2BoardSessionStore.load();
    if (session == null) {
      if (!mounted) return;
      setState(() {
        loggedIn = false;
        loading = false;
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
        loading = false;
        error = isLoggedIn ? null : '登录已失效，请重新登录。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loggedIn = false;
        loading = false;
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
      loading = true;
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
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (loggedIn) {
      return widget.child;
    }
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
