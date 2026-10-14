import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme.dart';
import '../core/models.dart';
import '../widgets/chamae_logo.dart';

class MotoboyAppScreen extends StatelessWidget {
  const MotoboyAppScreen({super.key});

  Future<void> _alterarStatus(
    BuildContext context,
    String documentId,
    String novoStatus,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(documentId)
          .update({'status': novoStatus});
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar pedido: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _abrirQrTemporario(
    BuildContext context,
    OrderModel order,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Confirmar retirada ${order.id}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Código do pedido',
              hintText: order.id,
              prefixIcon: const Icon(Icons.qr_code_scanner),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.deepBlack,
              ),
              onPressed: () async {
                final digitado = controller.text.trim();
                final esperado = order.id.trim();

                if (digitado != esperado) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Código inválido.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);

                await _alterarStatus(
                  context,
                  order.documentId,
                  'Saiu para Entrega',
                );
              },
              child: const Text(
                'Iniciar Entrega',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: AppColors.primaryGold,
              title: const Row(
                children: [
                  ChamaeOfficialLogo(size: 34),
                  SizedBox(width: 10),
                  Text(
                    'App do Motoboy',
                    style: TextStyle(
                      color: AppColors.deepBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar entregas:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGold,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                final orders = docs
                    .map((doc) => OrderModel.fromFirestore(doc))
                    .where(
                      (order) =>
                          order.status == 'Em Separação' ||
                          order.status == 'Saiu para Entrega',
                    )
                    .toList();

                if (orders.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma entrega disponível.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pedido ${order.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  order.status,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              order.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'R\$ ${order.totalBRL.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (order.status == 'Em Separação')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.primaryGold,
                                      foregroundColor:
                                          AppColors.deepBlack,
                                    ),
                                    onPressed: () =>
                                        _abrirQrTemporario(
                                      context,
                                      order,
                                    ),
                                    child: const Text('Retirar'),
                                  )
                                else if (order.status ==
                                    'Saiu para Entrega')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _alterarStatus(
                                      context,
                                      order.documentId,
                                      'Concluído',
                                    ),
                                    child: const Text('Concluir'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}