import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/models.dart';
import '../core/restricted_catalog.dart';
import '../core/theme.dart';
import '../l10n/customer_localizations.dart';
import '../widgets/commerce_components.dart';
import '../widgets/customer_visual.dart';
import '../widgets/product_image.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.remaining,
    required this.add,
    this.recommendations = const [],
    this.onRecommendation,
  });
  final Product product;
  final int Function() remaining;
  final bool Function(int quantity) add;
  final List<Product> recommendations;
  final ValueChanged<Product>? onRecommendation;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int quantity = 1;
  String money(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final restricted = restrictedCatalogProduct(product);
    final available =
        !restricted &&
        commerciallyAvailable(product) &&
        widget.remaining() >= quantity;
    final recommendations = restricted
        ? <Product>[]
        : widget.recommendations
              .where(
                (p) =>
                    p.id != product.id &&
                    !restrictedCatalogProduct(p) &&
                    commerciallyAvailable(p),
              )
              .toList();
    final nav = CommerceRouteNavigation.bar(context, 0);
    return Scaffold(
      appBar: const CommerceAppBar(title: 'Produto'),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                Container(
                  height: (MediaQuery.sizeOf(context).width * .53).clamp(
                    190.0,
                    340.0,
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF9E7), Color(0xFFFFFFFF)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.elliptical(220, 26),
                    ),
                  ),
                  child: restricted
                      ? const Icon(Icons.lock_outline, size: 64)
                      : ProductImage(url: product.imageUrl),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: IconButton(
                    tooltip: localizedLabel(context, 'Voltar'),
                    onPressed: () => Navigator.maybePop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.lightBg,
                      side: const BorderSide(color: AppColors.borderLight),
                    ),
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                ),
              ],
            ),
            Padding(
              padding: CustomerVisual.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  if (product.isCombo)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: LocalizedText(
                        'Combo',
                        style: TextStyle(
                          color: AppColors.darkGold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 23,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (product.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        product.description,
                        style: const TextStyle(fontSize: 14, height: 1.35),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Text(
                        money(product.price),
                        style: const TextStyle(
                          color: AppColors.darkGold,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      GoldStepper(
                        value: quantity,
                        decrease: quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                        increase: !restricted && quantity < widget.remaining()
                            ? () => setState(() => quantity++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: CustomerVisual.panel(),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.darkGold,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LocalizedText(
                                product.category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              LocalizedText(
                                available
                                    ? 'Disponível'
                                    : 'Indisponível no momento',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (recommendations.isNotEmpty &&
                      widget.onRecommendation != null) ...[
                    const CustomerSectionTitle(
                      title: 'Leve também',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    SizedBox(
                      height:
                          180 +
                          150 * (MediaQuery.textScalerOf(context).scale(1) - 1),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recommendations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => SizedBox(
                          width: 126,
                          child: CommerceProductCard(
                            product: recommendations[index],
                            onOpen: () => widget.onRecommendation!(
                              recommendations[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            top: false,
            bottom: nav == null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: CustomerVisual.panel(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final total = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LocalizedText(
                        'Total',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        money(product.price * quantity),
                        style: const TextStyle(
                          color: AppColors.darkGold,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  );
                  final button = GoldPrimaryButton(
                    label: available ? 'Adicionar ao carrinho' : 'Indisponível',
                    icon: Icons.shopping_cart_outlined,
                    onPressed: available
                        ? () {
                            if (widget.add(quantity)) Navigator.pop(context);
                          }
                        : null,
                  );
                  return constraints.maxWidth < 380 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.2
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [total, const SizedBox(height: 6), button],
                        )
                      : Row(
                          children: [
                            total,
                            const SizedBox(width: 16),
                            Expanded(child: button),
                          ],
                        );
                },
              ),
            ),
          ),
          if (nav != null) nav,
        ],
      ),
    );
  }
}
