import 'commerce_components.dart';
import '../core/launch_financial_policy.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../l10n/customer_localizations.dart';
import '../l10n/locale_controller.dart';
import 'package:flutter/material.dart';
import '../data/delivery_quote.dart';

class DeliveryQuoteSummary extends StatelessWidget {
  final DeliveryQuoteController controller;
  final double? subtotal;
  const DeliveryQuoteSummary(
      {super.key, required this.controller, this.subtotal});
  String money(BuildContext context, double value) =>
      localizedBrl(context, value);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final quote =
            controller.value?.isFresh() == true ? controller.value : null;
        final status = controller.loading
            ? 'Calculando entrega...'
            : controller.error ??
                (quote == null
                    ? 'Entrega a calcular'
                    : context.l10n
                        .freightAmount(localizedBrl(context, quote.fee)));
        final subtotalCentavos = subtotal == null
            ? 0
            : LaunchFinancialPolicy.toCentavos(subtotal!, name: 'subtotal');
        final subtotalAmounts = LaunchFinancialPolicy.calculateOrderAmounts(
          subtotalCentavos: subtotalCentavos,
        );
        final fee = subtotalAmounts.customerFee;
        final totalAmounts = quote == null || subtotal == null
            ? null
            : LaunchFinancialPolicy.calculateOrderAmounts(
                subtotalCentavos: subtotalCentavos,
                deliveryFeeCentavos:
                    LaunchFinancialPolicy.toCentavos(quote.fee, name: 'fee'),
              );
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (subtotal != null) ...[
                _line('Produtos', money(context, subtotal!)),
                _line('Taxa de serviço', money(context, fee)),
              ],
              LocalizedText(status,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: controller.error == null
                          ? null
                          : Theme.of(context).colorScheme.error)),
              if (quote != null)
                DeliveryRouteDetails(
                    quote: quote,
                    countryCode: controller.destination?.countryCode),
              if (controller.loading) const LinearProgressIndicator(),
              if (controller.error != null && controller.destination != null)
                TextButton(
                    onPressed: () =>
                        controller.refresh(controller.destination!),
                    child: const LocalizedText(
                        'Tentar calcular entrega novamente')),
              if (subtotal != null) ...[
                const Divider(),
                _line(
                    'Total',
                    totalAmounts == null
                        ? 'A calcular'
                        : money(context, totalAmounts.totalBRL)),
              ],
            ]);
      });
  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: CommerceSummaryLine(label: label, value: value),
      );
}

// A presentation of server quote data; never computes a delivery charge.
class DeliveryRouteDetails extends StatelessWidget {
  final DeliveryQuote quote;
  final String? countryCode;
  const DeliveryRouteDetails(
      {super.key, required this.quote, required this.countryCode});
  @override
  Widget build(BuildContext context) {
    final country = countryCode == 'BR'
        ? 'Brasil (BR)'
        : countryCode == 'PY'
            ? (Localizations.localeOf(context).languageCode == 'es'
                ? 'Paraguay (PY)'
                : 'Paraguai (PY)')
            : context.l10n.countryUnknown;
    final locale = LocaleController.resolve(Localizations.localeOf(context))
        .toLanguageTag()
        .replaceAll('-', '_');
    final distance = NumberFormat('0.000', locale)
        .format((quote.distanceMeters ?? 0) / 1000);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(context.l10n.routeDistance(distance)),
      Text(context.l10n.destinationLabel(country)),
      const LocalizedText('Frete cotado em BRL'),
    ]);
  }
}
