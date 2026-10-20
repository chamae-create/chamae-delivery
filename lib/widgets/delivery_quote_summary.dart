import 'package:flutter/material.dart';
import '../data/delivery_quote.dart';

class DeliveryQuoteSummary extends StatelessWidget {
  final DeliveryQuoteController controller;
  final double? subtotal;
  const DeliveryQuoteSummary(
      {super.key, required this.controller, this.subtotal});
  String money(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final quote = controller.value;
        final status = controller.loading
            ? 'Calculando entrega...'
            : controller.error ??
                (quote == null
                    ? 'Entrega a calcular'
                    : 'Entrega ${money(quote.fee)}');
        final fee =
            subtotal == null ? 0.0 : (subtotal! * .01 * 100).round() / 100;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (subtotal != null) ...[
                _line('Produtos', money(subtotal!)),
                _line('Taxa de serviço', money(fee)),
              ],
              Text(status,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: controller.error == null
                          ? null
                          : Theme.of(context).colorScheme.error)),
              if (controller.loading) const LinearProgressIndicator(),
              if (controller.error != null)
                TextButton(
                    onPressed: () =>
                        controller.refresh(controller.destination!),
                    child: const Text('Tentar calcular entrega novamente')),
              if (subtotal != null) ...[
                const Divider(),
                _line(
                    'Total',
                    quote == null
                        ? 'A calcular'
                        : money(subtotal! + fee + quote.fee)),
              ],
            ]);
      });
  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [Expanded(child: Text(label)), Text(value)]));
}
