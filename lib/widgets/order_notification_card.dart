import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../data/order_notifications.dart';

class OrderNotificationCard extends StatefulWidget {
  final String orderId;
  final OrderNotifications? notifications;
  const OrderNotificationCard({
    super.key,
    required this.orderId,
    this.notifications,
  });
  @override
  State<OrderNotificationCard> createState() => _OrderNotificationCardState();
}

class _OrderNotificationCardState extends State<OrderNotificationCard> {
  bool _busy = false;
  String? _message;
  OrderNotifications get _adapter =>
      widget.notifications ??
      (Firebase.apps.isNotEmpty
          ? FirebaseCustomerPushNotifications.instance
          : const UnconfiguredOrderNotifications());

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      final permission = await _adapter.requestForOrder(widget.orderId);
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
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.asset(
                      'assets/images/states/notification_bell.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.notifications_active_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Quer receber atualizações deste pedido?'),
                ),
              ],
            ),
            if (_message != null) Text(_message!),
            TextButton(
                onPressed: _busy ? null : _request,
                child: Text(_busy ? 'Aguarde…' : 'Receber atualizações')),
          ])));
}
