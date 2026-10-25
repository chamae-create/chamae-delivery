import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/order_confirmation_policy.dart';
import 'customer_visual.dart';

// Presentation only. Only server-confirmed finance/payment may celebrate a
// purchase; the order write acknowledgment alone is not a confirmation.
bool canPresentOrderConfirmation(Map<String, dynamic> data) =>
    orderIsConfirmed(data);

bool customerUsesPix(Map<String, dynamic> data) =>
    data['pixRequested'] == true || data['paymentMethod'] == 'PIX';

String customerPaymentMethod(Map<String, dynamic> data) {
  final method = data['paymentMethod']?.toString() ?? '';
  if (method.startsWith('Maquininha')) return 'Cartão na entrega';
  return method.isEmpty ? 'Pagamento não informado' : method;
}

String customerMoney(num value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

class CustomerOrderSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const CustomerOrderSummary({super.key, required this.data});

  @override
  Widget build(BuildContext context) => Container(
      decoration: CustomerVisual.panel(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Resumo do pedido',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (data['itemsList'] is List)
          for (final item in (data['itemsList'] as List).whereType<Map>())
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                    '${item['quantity'] ?? 1} × ${item['name'] ?? 'Produto'}')),
        const Divider(height: 24),
        Text(customerPaymentMethod(data),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(data['paymentStatus'] == 'Pago'
            ? 'Pagamento confirmado'
            : customerUsesPix(data)
                ? 'Aguardando pagamento'
                : data['paymentMethod'] == null
                    ? 'Pagamento em confirmação'
                    : 'Pagamento na entrega'),
        if (data['financialValidationStatus'] == 'validated') ...[
          const Divider(height: 24),
          for (final (field, label) in const [
            ('itemsTotal', 'Produtos'),
            ('deliveryFee', 'Entrega'),
            ('customerFee', 'Taxa de serviço'),
            ('totalBRL', 'Total'),
          ])
            if (data[field] is num && (data[field] as num).isFinite)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(label)),
                        const SizedBox(width: 12),
                        Flexible(
                            child: Text(customerMoney(data[field] as num),
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                    fontWeight: field == 'totalBRL'
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: field == 'totalBRL'
                                        ? AppColors.darkGold
                                        : AppColors.textMain))),
                      ])),
        ],
      ]));
}

class OrderConfirmationView extends StatelessWidget {
  final String orderId, statusLabel;
  final Map<String, dynamic> data;
  final VoidCallback onTrack;
  const OrderConfirmationView(
      {super.key,
      required this.orderId,
      required this.statusLabel,
      required this.data,
      required this.onTrack});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: CustomerVisual.pagePadding(context),
      child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.scale(scale: .98 + .02 * value, child: child)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(
                liveRegion: true,
                child: CustomerHero(
                    title: 'Pedido confirmado!',
                    subtitle: 'Agora é com a Pit Stop V8.\nPedido $orderId',
                    icon: Icons.check_circle_outline_rounded)),
            const SizedBox(height: 20),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.shopping_bag_outlined,
                  color: AppColors.darkGold),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(statusLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 16),
            CustomerOrderSummary(data: data),
            const SizedBox(height: 16),
            Text(data['address']?.toString().trim().isNotEmpty == true
                ? 'Entrega em: ${data['address']}'
                : 'Endereço não informado'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: onTrack,
                icon: const Icon(Icons.two_wheeler_rounded),
                label: const Text('Acompanhar pedido')),
            const SizedBox(height: 12),
            const Text('As novidades do seu pedido aparecem no acompanhamento.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          ])));
}
