import 'package:flutter/material.dart';
import '../data/order_notifications.dart';

class OrderNotificationCard extends StatefulWidget {
  final String orderId;
  final OrderNotifications notifications;
  const OrderNotificationCard(
      {super.key,
      required this.orderId,
      this.notifications = const UnconfiguredOrderNotifications()});
  @override
  State<OrderNotificationCard> createState() => _OrderNotificationCardState();
}

class _OrderNotificationCardState extends State<OrderNotificationCard> {
  bool _busy = false;
  String? _message;
  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      final permission =
          await widget.notifications.requestForOrder(widget.orderId);
      if (!mounted) return;
      setState(() => _message = switch (permission) {
            OrderNotificationPermission.granted =>
              'Atualizações ativadas para este pedido.',
            OrderNotificationPermission.denied =>
              'Você pode continuar acompanhando o pedido aqui no app.',
            OrderNotificationPermission.unavailable =>
              'As notificações ainda não estão disponíveis. Acompanhe seu pedido aqui no app.',
          });
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Não foi possível ativar agora. O acompanhamento continua disponível.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Quer receber atualizações deste pedido?'),
            if (_message != null) Text(_message!),
            TextButton(
                onPressed: _busy ? null : _request,
                child: Text(_busy ? 'Aguarde…' : 'Receber atualizações')),
          ])));
}
