import '../widgets/customer_visual.dart';
import '../data/delivery_quote.dart';
import '../widgets/delivery_quote_summary.dart';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/store_hours.dart';
import '../widgets/product_image.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> Function() items;
  final void Function(String id, int delta) change;
  final VoidCallback checkout;
  final String? notice;
  final DeliveryAddress? destination;
  final DeliveryQuoter? quoter;
  const CartScreen(
      {super.key,
      required this.items,
      required this.change,
      required this.checkout,
      this.notice,
      this.destination,
      this.quoter});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final DeliveryQuoteController _delivery =
      DeliveryQuoteController(widget.quoter ?? FirebaseDeliveryQuoter());
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
    if (widget.destination != null &&
        widget.destination != oldWidget.destination) {
      _delivery.refresh(widget.destination!);
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
  Widget build(BuildContext context) {
    final items = widget.items();
    final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    return Scaffold(
      appBar: AppBar(title: const Text('Seu carrinho')),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(AppSpace.lg),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 56, color: AppColors.textSecondary),
                    SizedBox(height: 16),
                    Text('Seu carrinho está vazio.'),
                    Text('Escolha suas bebidas e conveniência.'),
                  ])))
          : SingleChildScrollView(
              padding: CustomerVisual.pagePadding(context),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CustomerSectionTitle(
                        title: 'Confira seu pedido',
                        subtitle: 'Revise seus itens antes de continuar.',
                        icon: Icons.shopping_bag_outlined),
                    if (widget.notice != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(widget.notice!,
                              style: const TextStyle(color: AppColors.error))),
                    for (final item in items)
                      Card(
                          elevation: 0,
                          child: Padding(
                              padding: const EdgeInsets.all(AppSpace.md),
                              child: Column(children: [
                                Row(children: [
                                  SizedBox(
                                      width: 84,
                                      height: 100,
                                      child: ProductImage(url: item.imageUrl)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(item.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        Text('${money(item.price)} por unidade',
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textSecondary)),
                                        Text(money(item.totalPrice),
                                            style: const TextStyle(
                                                color: AppColors.darkGold,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900)),
                                      ])),
                                ]),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                          tooltip: 'Remover ${item.name}',
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: () => setState(() =>
                                              widget.change(
                                                  item.id, -item.quantity))),
                                      IconButton(
                                          tooltip: 'Diminuir quantidade',
                                          icon: const Icon(Icons.remove),
                                          onPressed: () => setState(() =>
                                              widget.change(item.id, -1))),
                                      Text('${item.quantity}',
                                          semanticsLabel:
                                              '${item.quantity} unidades'),
                                      IconButton(
                                          tooltip: 'Aumentar quantidade',
                                          icon: const Icon(Icons.add),
                                          onPressed: () => setState(
                                              () => widget.change(item.id, 1))),
                                    ]),
                              ]))),
                    const SizedBox(height: 16),
                    const CustomerSectionTitle(
                        title: 'Resumo do pedido',
                        icon: Icons.receipt_long_outlined),
                    Container(
                        decoration: CustomerVisual.panel(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (widget.destination != null)
                                DeliveryQuoteSummary(
                                    controller: _delivery, subtotal: subtotal)
                              else ...[
                                _line('Produtos', money(subtotal)),
                                _line(
                                    'Taxa de serviço',
                                    money(
                                        (subtotal * .01 * 100).round() / 100)),
                                _line(
                                    'Produtos e serviço',
                                    money(subtotal +
                                        (subtotal * .01 * 100).round() / 100)),
                                _line('Entrega',
                                    'A calcular após confirmar o endereço'),
                              ],
                            ])),
                    const SizedBox(height: 24),
                    if (!isStoreOpen())
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(storeHoursLabel(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                    ElevatedButton(
                        onPressed: isStoreOpen() &&
                                (widget.destination == null ||
                                    (!_delivery.loading &&
                                        _delivery.value != null))
                            ? widget.checkout
                            : null,
                        child: const Text('Continuar para entrega')),
                  ])),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700)))
        ]),
      );
}
