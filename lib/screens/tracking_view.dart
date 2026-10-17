import 'package:flutter/material.dart';

import '../order_chat.dart';

class TrackingView extends StatelessWidget {
  final String orderId;

  final Stream<Map<String, dynamic>?> orderStream;
  final VoidCallback onBack;
  const TrackingView({
    super.key,
    required this.orderId,
    required this.orderStream,
    required this.onBack,
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
            return const Center(
              child: Text(
                'Não foi possível acompanhar o pedido. Tente novamente.',
              ),
            );
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
              data['courierName'] is String && (data['courierName'] as String).trim().isNotEmpty
            ? (data['courierName'] as String).trim() : 'Aguardando atribuição';
          final address = (data['address'] ?? 'Centro - Ponta Porã').toString();
          final double total = ((data['totalBRL'] ?? 0.0) as num).toDouble();

          int currentStep = 0;
          if (status == 'Em Separação') currentStep = 1;
          if (status == 'Saiu para Entrega') currentStep = 2;
          if (status == 'Concluído') currentStep = 3;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mapa em Proporções Mobile
                if (data['financialValidationStatus'] == 'validated' && data['_documentId'] is String)
                  OutlinedButton.icon(icon: const Icon(Icons.chat_outlined),
                    label: const Text('Falar com a loja'),
                    onPressed: () => showDialog<void>(context: context,
                      builder: (_) => AlertDialog(title: const Text('Falar com a loja'),
                        content: SizedBox(width: 520, child: SingleChildScrollView(
                          child: OrderChat(key: ValueKey(data['_documentId']),
                            orderId: data['_documentId'], order: data))),
                        actions: [TextButton(onPressed: () => Navigator.pop(context),
                          child: const Text('Fechar'))]))),
                const SizedBox(height: 16),

                // Card de Linha do Tempo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildStepIndicator(0, 'Recebido', currentStep >= 0),
                          _buildStepLine(currentStep >= 1),
                          _buildStepIndicator(1, 'Separando', currentStep >= 1),
                          _buildStepLine(currentStep >= 2),
                          _buildStepIndicator(2, 'Na Rota', currentStep >= 2),
                          _buildStepLine(currentStep >= 3),
                          _buildStepIndicator(3, 'Entregue', currentStep >= 3),
                        ],
                      ),
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
                    border: Border.all(color: Colors.grey.shade200),
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
                      IconButton(
                        icon: const Icon(
                          Icons.phone_rounded,
                          color: Colors.green,
                        ),
                        onPressed: () {},
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

  Widget _buildStepIndicator(int step, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFCC00) : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? Icons.check : Icons.circle,
            size: 12,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? const Color(0xFFFFCC00) : Colors.grey.shade300,
      ),
    );
  }
}
