import 'dart:async';

import 'package:flclashx/l10n/l10n.dart';
import 'package:flclashx/models/shop.dart';
import 'package:flclashx/services/v2board_service.dart';
import 'package:flclashx/state.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.tradeNo,
    required this.paymentMethods,
    required this.finalPrice,
  });

  final String tradeNo;
  final List<PaymentMethod> paymentMethods;
  final int finalPrice;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  bool _processing = false;
  Timer? _pollTimer;
  bool _waitingPayment = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _selectPayment(PaymentMethod method) async {
    setState(() => _processing = true);
    try {
      final session = await V2BoardSessionStore.load();
      if (session == null) return;
      final client = V2BoardClient(baseUrl: session.baseUrl, token: session.token);
      final result = await client.checkoutOrder(
        tradeNo: widget.tradeNo,
        methodId: method.id,
      );
      if (!mounted) return;
      setState(() => _processing = false);

      if (result.isFree) {
        _onPaymentSuccess();
        return;
      }

      if (result.isQrCode && result.url != null) {
        _showQrDialog(result.url!);
      } else if (result.isRedirect && result.url != null) {
        launchUrl(Uri.parse(result.url!), mode: LaunchMode.externalApplication);
        _startPolling();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showQrDialog(String qrUrl) {
    final appLocale = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(appLocale.scanQrCode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              qrUrl,
              width: 200,
              height: 200,
              errorBuilder: (_, __, ___) => Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                child: Text(qrUrl, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 12),
            if (_waitingPayment)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(appLocale.paymentWaiting),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pollTimer?.cancel();
              Navigator.pop(ctx);
            },
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
    _startPolling();
  }

  void _startPolling() {
    setState(() => _waitingPayment = true);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final session = await V2BoardSessionStore.load();
        if (session == null) return;
        final client = V2BoardClient(baseUrl: session.baseUrl, token: session.token);
        final status = await client.checkOrderStatus(widget.tradeNo);
        if (!mounted) return;
        if (status == 3) {
          timer.cancel();
          Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
          _onPaymentSuccess();
        } else if (status == 2) {
          timer.cancel();
          setState(() => _waitingPayment = false);
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).orderCancelled)),
          );
        }
      } catch (_) {
        // ignore polling errors
      }
    });
  }

  void _onPaymentSuccess() {
    final appLocale = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(appLocale.paymentSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(appLocale.selectPayment, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          ...widget.paymentMethods.map(
            (method) => ListTile(
              leading: method.icon != null && method.icon!.isNotEmpty
                  ? Text(method.icon!, style: const TextStyle(fontSize: 24))
                  : const Icon(Icons.payment),
              title: Text(method.name),
              trailing: _processing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _processing ? null : () => _selectPayment(method),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              _pollTimer?.cancel();
              try {
                final session = await V2BoardSessionStore.load();
                if (session == null) return;
                final client = V2BoardClient(baseUrl: session.baseUrl, token: session.token);
                await client.cancelOrder(widget.tradeNo);
              } catch (_) {}
              if (mounted) Navigator.pop(context);
            },
            child: Text(appLocale.cancelOrder, style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
