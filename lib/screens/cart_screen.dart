import '../core/launch_financial_policy.dart';
import '../l10n/customer_localizations.dart';
import '../widgets/customer_visual.dart';
import '../widgets/commerce_components.dart';
import '../data/delivery_quote.dart';
import '../widgets/delivery_quote_summary.dart';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/store_hours_builder.dart';
import '../widgets/customer_feedback.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> Function() items;
  final void Function(String id, int delta) change;
  final VoidCallback checkout;
  final String? notice;
  final DeliveryAddress? destination;
  final DeliveryQuoter? quoter;
  const CartScreen({
    super.key,
    required this.items,
    required this.change,
    required this.checkout,
    this.notice,
    this.destination,
    this.quoter,
  });
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final DeliveryQuoteController _delivery = DeliveryQuoteController(
    widget.quoter ?? FirebaseDeliveryQuoter(),
  );
  @override
  void initState() {
    super.initState();
    _delivery.addListener(_deliveryChanged);
    if (widget.destination != null) _delivery.refresh(widget.destination!);
  }

  void _deliveryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destination != oldWidget.destination) {
      if (widget.destination == null) {
        _delivery.clear();
      } else {
        _delivery.refresh(widget.destination!);
      }
    }
  }

  @override
  void dispose() {
    _delivery.dispose();
    super.dispose();
  }

  String money(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  @override
  Widget build(BuildContext context) => StoreHoursBuilder(
        builder: (context, open, hoursLabel) {
          final items = widget.items();
          final subtotalCentavos = LaunchFinancialPolicy.itemsSubtotalCentavos(
            items.map((item) => (unitPrice: item.price, quantity: item.quantity)),
          );
          final cartAmounts = LaunchFinancialPolicy.calculateOrderAmounts(
            subtotalCentavos: subtotalCentavos,
          );
          final subtotal = cartAmounts.itemsTotal;
          return Scaffold(
            appBar: CommerceAppBar(
              title: 'Seu carrinho',
              address: widget.destination?.addressText,
            ),
            bottomNavigationBar: CommerceRouteNavigation.bar(context, 0),
            body: SafeArea(
              top: false,
              bottom: false,
              child: items.isEmpty
                  ? const Center(
                      child: SingleChildScrollView(
                        child: CustomerFeedback(
                          title: 'Seu carrinho está vazio.',
                          message: 'Escolha suas bebidas e conveniência.',
                          icon: Icons.shopping_bag_outlined,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: CustomerVisual.pagePadding(context),
                      itemCount: items.length + 2,
                      itemBuilder: (context, index) {
                        if (index > 0 && index <= items.length) {
                          return _cartItem(items[index - 1]);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: index == 0
                              ? [
                                  CommercePageTitle(
                                    title: 'Seu carrinho',
                                    subtitle:
                                        'Confira seus itens antes de finalizar.',
                                    onBack: () => Navigator.maybePop(context),
                                  ),
                                  if (widget.notice != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: LocalizedText(
                                        widget.notice!,
                                        style: const TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                ]
                              : [
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: CustomerVisual.panel(),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.receipt_long_outlined,
                                              color: AppColors.darkGold,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: LocalizedText(
                                                'Resumo do pedido',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (widget.destination != null)
                                          DeliveryQuoteSummary(
                                            controller: _delivery,
                                            subtotal: subtotal,
                                          )
                                        else ...[
                                          _line('Produtos', money(subtotal)),
                                          _line(
                                            'Taxa de serviço',
                                            money(cartAmounts.customerFee),
                                          ),
                                          const Divider(height: 16),
                                          _line(
                                            'Produtos e serviço',
                                            money(cartAmounts.totalBRL),
                                          ),
                                          _line(
                                            'Entrega',
                                            'A calcular após confirmar o endereço',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (!open)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: LocalizedText(
                                        hoursLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  GoldPrimaryButton(
                                    onPressed: open &&
                                            (widget.destination == null ||
                                                (!_delivery.loading &&
                                                    _delivery.value
                                                            ?.isFresh() ==
                                                        true))
                                        ? widget.checkout
                                        : null,
                                    label: 'Continuar para entrega',
                                    icon: Icons.lock_outline,
                                  ),
                                  const SizedBox(height: 8),
                                  const LocalizedText(
                                    'O total será conferido ao confirmar o pedido.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (!open)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: LocalizedText(
                                        'O catálogo continua disponível. Os pedidos voltam às 08:00 (MS).',
                                      ),
                                    ),
                                ],
                        );
                      },
                    ),
            ),
          );
        },
      );

  Widget _cartItem(CartItem item) => CommerceCartItemCard(
        key: ValueKey('cart-item-${item.id}'),
        item: item,
        decrease: () => setState(() => widget.change(item.id, -1)),
        increase: () => setState(() => widget.change(item.id, 1)),
        remove: () => setState(() => widget.change(item.id, -item.quantity)),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: CommerceSummaryLine(
            label: label,
            value: value,
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            valueStyle: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
