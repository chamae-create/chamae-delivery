import '../core/theme.dart';
import '../widgets/customer_visual.dart';
import '../widgets/order_notification_card.dart';
import '../widgets/delivery_pin_card.dart';
import 'package:flutter/material.dart';

import '../widgets/customer_chat_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/pix_payment_dialog.dart';
import 'customer_profile_screen.dart';

class TrackingView extends StatelessWidget {
  final String orderId;

  final Stream<Map<String, dynamic>?> orderStream;
  final VoidCallback onBack;
  final VoidCallback? onRetry;
  const TrackingView({
    super.key,
    required this.orderId,
    required this.orderStream,
    required this.onBack,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Acompanhar Pedido $orderId',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Não foi possível acompanhar o pedido.'),
              if (onRetry != null)
                TextButton(
                    onPressed: onRetry, child: const Text('Tentar novamente')),
            ]));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFCC00)),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Text('Pedido indisponível para esta sessão.'),
            );
          }

          final status = (data['status'] ?? 'Novo').toString();
          final courier = data['courierUid'] is String &&
                  (data['courierUid'] as String).trim().isNotEmpty &&
                  data['courierName'] is String &&
                  (data['courierName'] as String).trim().isNotEmpty
              ? (data['courierName'] as String).trim()
              : status == 'Concluído' || status == 'Cancelado'
                  ? 'Entregador não informado'
                  : 'Aguardando atribuição';
          final address = (data['address'] ?? 'Centro - Ponta Porã').toString();
          final double total = ((data['totalBRL'] ?? 0.0) as num).toDouble();

          int currentStep = 0;
          if (status == 'Em Separação') currentStep = 1;
          if (status == 'Aguardando Retirada') currentStep = 2;
          if (status == 'Saiu para Entrega') currentStep = 3;
          if (status == 'Concluído') currentStep = 4;

          return SingleChildScrollView(
            padding: CustomerVisual.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomerHero(
                    title: customerStatus(status),
                    subtitle: 'Pedido $orderId',
                    icon: status == 'Concluído'
                        ? Icons.check_circle_outline
                        : status == 'Cancelado'
                            ? Icons.cancel_outlined
                            : Icons.two_wheeler_rounded),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Resumo do pedido',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              if (data['itemsList'] is List)
                                for (final item in (data['itemsList'] as List)
                                    .whereType<Map>())
                                  Text(
                                      '${item['quantity'] ?? 1} × ${item['name'] ?? 'Produto'}'),
                              const Divider(),
                              Text((data['paymentMethod'] ?? '')
                                      .toString()
                                      .startsWith('Maquininha')
                                  ? 'Cartão na entrega'
                                  : (data['paymentMethod'] ?? 'Pagamento')
                                      .toString()),
                              Text(data['paymentStatus'] == 'Pago'
                                  ? 'Pagamento confirmado'
                                  : data['pixRequested'] == true
                                      ? 'Aguardando pagamento'
                                      : 'Pagamento na entrega'),
                            ]))),
                if (data['pixRequested'] == true &&
                    data['paymentStatus'] != 'Pago' &&
                    status != 'Cancelado' &&
                    data['_documentId'] is String)
                  ElevatedButton.icon(
                      icon: const Icon(Icons.pix),
                      label: const Text('Ver pagamento PIX'),
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => PixPaymentDialog(
                              orderReference: FirebaseFirestore.instance
                                  .collection('orders')
                                  .doc(data['_documentId']),
                              orderId: orderId,
                              totalBRL: total,
                              onPaid: () async {}))),
                // Mapa em Proporções Mobile
                if (data['financialValidationStatus'] == 'validated' &&
                    data['_documentId'] is String)
                  CustomerChatEntry(order: data),
                if (!['Cancelado', 'Concluído'].contains(status)) ...[
                  const DeliveryPinCard(),
                  OrderNotificationCard(
                      orderId: data['_documentId']?.toString() ?? orderId),
                ],
                const SizedBox(height: 16),

                // Card de Linha do Tempo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'STATUS DO PEDIDO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Total: R\$ ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (status != 'Cancelado' &&
                          status != 'Aguardando pagamento')
                        Column(children: [
                          for (final (index, label) in const [
                            'Pedido recebido',
                            'Em separação',
                            'Aguardando retirada',
                            'Saiu para entrega',
                            'Entregue'
                          ].indexed)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(children: [
                                  Icon(
                                      index <= currentStep
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: index <= currentStep
                                          ? AppColors.darkGold
                                          : Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(label,
                                          style: TextStyle(
                                              fontWeight: index == currentStep
                                                  ? FontWeight.w800
                                                  : FontWeight.w400))),
                                ])),
                        ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card do Entregador
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFCC00),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courier,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Destino: $address',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
