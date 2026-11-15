import '../core/launch_financial_policy.dart';
import '../l10n/customer_localizations.dart';
import '../widgets/customer_visual.dart';
import '../widgets/commerce_components.dart';
import '../data/customer_orders.dart';
import '../data/delivery_quote.dart';
import '../widgets/delivery_quote_summary.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/store_hours_builder.dart';
import '../widgets/customer_feedback.dart';
import 'tracking_screen.dart';

class CartScreen extends StatefulWidget {
  final List<CartItem> Function() items;
  final void Function(String id, int delta) change;
  final VoidCallback checkout;
  final String? notice;
  final DeliveryAddress? destination;
  final DeliveryQuoter? quoter;
  final Stream<List<Map<String, dynamic>>>? activeOrders;
  const CartScreen({
    super.key,
    required this.items,
    required this.change,
    required this.checkout,
    this.notice,
    this.destination,
    this.quoter,
    this.activeOrders,
  });
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final DeliveryQuoteController _delivery = DeliveryQuoteController(
    widget.quoter ?? FirebaseDeliveryQuoter(),
  );
  Stream<List<Map<String, dynamic>>>? _activeOrdersStream;
  @override
  void initState() {
    super.initState();
    _delivery.addListener(_deliveryChanged);
    if (widget.destination != null) _delivery.refresh(widget.destination!);
    _activeOrdersStream = widget.activeOrders ??
        (widget.quoter == null && Firebase.apps.isNotEmpty
            ? CustomerOrders(
                auth: FirebaseAuth.instance,
                firestore: FirebaseFirestore.instance,
              ).watchActiveOrders()
            : null);
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
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: CustomerVisual.gold,
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(10),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(7),
                                                child: Icon(
                                                  Icons.receipt_long_outlined,
                                                  color: AppTheme.obsidianDark,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10),
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
                                          _line('Frete', 'A calcular'),
                                          _line(
                                            'Taxa de serviço',
                                            money(cartAmounts.customerFee),
                                          ),
                                          const Divider(height: 14),
                                          _line(
                                            'Total',
                                            'A calcular',
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
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
                                  _buildCheckoutAction(open),
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

  Widget _buildCheckoutAction(bool open) {
    final canProceedByQuote = open &&
        (widget.destination == null ||
            (!_delivery.loading && _delivery.value?.isFresh() == true));
    if (_activeOrdersStream == null) {
      return GoldPrimaryButton(
        onPressed: canProceedByQuote ? widget.checkout : null,
        label: 'Continuar para entrega',
        icon: Icons.lock_outline,
      );
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _activeOrdersStream,
      builder: (context, snapshot) {
        final active = snapshot.data ?? const [];
        final activeOrder = active.isEmpty ? null : active.first;
        if (activeOrder == null) {
          return GoldPrimaryButton(
            onPressed: canProceedByQuote ? widget.checkout : null,
            label: 'Continuar para entrega',
            icon: Icons.lock_outline,
          );
        }
        final docId = activeOrder['_documentId']?.toString();
        final friendlyId =
            activeOrder['id']?.toString().trim().isNotEmpty == true
                ? activeOrder['id'].toString().trim()
                : (docId ?? '');
        final status =
            activeOrder['status']?.toString().trim().isNotEmpty == true
                ? activeOrder['status'].toString().trim()
                : 'Em andamento';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.darkGold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LocalizedText(
                          'Você já possui um pedido ativo ($friendlyId • $status).',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const LocalizedText(
                    'Acompanhe o pedido atual antes de finalizar uma nova compra.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GoldPrimaryButton(
                    label: 'Acompanhar pedido ativo',
                    icon: Icons.delivery_dining_rounded,
                    onPressed: friendlyId.isEmpty && docId == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TrackingScreen(
                                  orderId: friendlyId.isNotEmpty
                                      ? friendlyId
                                      : docId!,
                                  documentId: docId,
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
            const GoldPrimaryButton(
              onPressed: null,
              label: 'Continuar para entrega',
              icon: Icons.lock_outline,
            ),
          ],
        );
      },
    );
  }

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
