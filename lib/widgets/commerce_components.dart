import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/models.dart';
import '../l10n/customer_localizations.dart';
import 'customer_visual.dart';
import 'product_image.dart';

class CommerceHeader extends StatelessWidget {
  const CommerceHeader({
    super.key,
    this.address,
    this.onAddress,
    this.onSearch,
    this.onCart,
    this.cartCount = 0,
    this.actions = const [],
  });
  final String? address;
  final VoidCallback? onAddress, onSearch, onCart;
  final int cartCount;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.lightBg,
              border: Border(
                bottom: BorderSide(color: AppColors.borderLight, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/home/logo_transparent.png',
                  width: constraints.maxWidth < 370 ? 60 : 72,
                  height: 48,
                  fit: BoxFit.contain,
                  semanticLabel: 'Chamaê Delivery',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: onAddress != null,
                    child: InkWell(
                      onTap: onAddress,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppTheme.primaryYellow,
                              size: 21,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (MediaQuery.textScalerOf(context)
                                          .scale(1) <=
                                      1.3)
                                    Text(
                                      Localizations.localeOf(context)
                                                  .languageCode ==
                                              'es'
                                          ? 'Entregar en'
                                          : 'Entregar em',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  LocalizedText(
                                    address?.isNotEmpty == true
                                        ? address!
                                        : 'Escolha seu endereço',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (onAddress != null)
                              const Icon(Icons.expand_more, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (onSearch != null)
                  IconButton(
                    tooltip: localizedLabel(context, 'Buscar produtos'),
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded, size: 26),
                  ),
                if (onCart != null)
                  IconButton(
                    tooltip: localizedLabel(context, 'Carrinho'),
                    onPressed: onCart,
                    icon: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text('$cartCount'),
                      backgroundColor: AppTheme.primaryYellow,
                      textColor: AppTheme.darkBg,
                      child: const Icon(Icons.shopping_cart_outlined, size: 26),
                    ),
                  ),
                ...actions,
              ],
            ),
          );
        },
      );
}

class CommerceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommerceAppBar({
    super.key,
    required this.title,
    this.address,
    this.actions = const [],
  });
  final String title;
  final String? address;
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(66);
  @override
  Widget build(BuildContext context) => AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 66,
        titleSpacing: 0,
        title: CommerceHeader(
          address: address ?? CommerceRouteNavigation.maybeOf(context)?.address,
          onSearch: CommerceRouteNavigation.maybeOf(context)?.onSearch,
          onCart: CommerceRouteNavigation.maybeOf(context)?.onCart,
          onAddress: CommerceRouteNavigation.maybeOf(context)?.onAddress,
          cartCount: CommerceRouteNavigation.maybeOf(context)?.cartCount ?? 0,
          actions: CommerceRouteNavigation.maybeOf(context)?.onCart == null
              ? actions
              : const [],
        ),
      );
}

class CommercePageTitle extends StatelessWidget {
  const CommercePageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onBack != null) ...[
              IconButton(
                tooltip: localizedLabel(context, 'Voltar'),
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceWhite,
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                icon: const Icon(Icons.chevron_left, size: 28),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    LocalizedText(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class CommerceBottomBar extends StatelessWidget {
  const CommerceBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: [
            BoxShadow(
              color: Color(0x16916A16),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == selectedIndex,
                      child: InkWell(
                        onTap: () => onSelected(i),
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                [
                                  Icons.home_rounded,
                                  Icons.grid_view_rounded,
                                  Icons.receipt_long_rounded,
                                  Icons.person_rounded,
                                ][i],
                                size: 24,
                                color: i == selectedIndex
                                    ? const Color(0xFFE09600)
                                    : const Color(0xFF4A4A4A),
                              ),
                              const SizedBox(height: 2),
                              LocalizedText(
                                [
                                  'Início',
                                  'Categorias',
                                  'Pedidos',
                                  'Perfil'
                                ][i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: i == selectedIndex
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: i == selectedIndex
                                      ? const Color(0xFFE09600)
                                      : const Color(0xFF4A4A4A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class GoldPrimaryButton extends StatelessWidget {
  const GoldPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon = Icons.arrow_forward,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null || busy ? null : CustomerVisual.gold,
          color: onPressed == null || busy ? AppColors.mutedSurface : null,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: onPressed == null
                ? AppColors.borderLight
                : const Color(0xFFF1BA17),
          ),
          boxShadow: [
            if (onPressed != null)
              const BoxShadow(
                color: Color(0x32E0A300),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            minimumSize: const Size(48, 52),
          ),
          onPressed: busy ? null : onPressed,
          icon: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: LocalizedText(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class GoldStepper extends StatelessWidget {
  const GoldStepper({
    super.key,
    required this.value,
    required this.decrease,
    required this.increase,
    this.semanticLabel,
    this.compact = false,
  });
  final int value;
  final bool compact;
  final VoidCallback? decrease, increase;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Container(
        decoration: compact
            ? BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight, width: 1),
              )
            : CustomerVisual.panel(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: localizedLabel(context, 'Diminuir quantidade'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: EdgeInsets.zero,
              onPressed: decrease,
              icon: Container(
                width: compact ? 28 : 34,
                height: compact ? 28 : 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: decrease == null
                        ? AppColors.mutedSurface
                        : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.remove,
                  size: compact ? 16 : 20,
                  color: decrease == null
                      ? AppColors.textSecondary
                      : AppTheme.textDark,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 6),
              child: Semantics(
                liveRegion: true,
                label: semanticLabel ?? '$value',
                child: Text(
                  '$value',
                  style: TextStyle(
                      fontSize: compact ? 14 : 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark),
                ),
              ),
            ),
            IconButton(
              tooltip: localizedLabel(context, 'Aumentar quantidade'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: EdgeInsets.zero,
              onPressed: increase,
              icon: Container(
                width: compact ? 28 : 34,
                height: compact ? 28 : 34,
                decoration: BoxDecoration(
                  gradient: increase == null ? null : CustomerVisual.gold,
                  color: increase == null ? AppColors.mutedSurface : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: increase == null
                        ? AppColors.borderLight
                        : AppTheme.goldDeep,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: compact ? 16 : 20,
                  color: AppTheme.obsidianDark,
                ),
              ),
            ),
          ],
        ),
      );
}

class CategoryBannerTile extends StatelessWidget {
  const CategoryBannerTile({
    super.key,
    required this.title,
    this.count = 0,
    required this.imageUrl,
    required this.onTap,
    this.icon = Icons.storefront_outlined,
  });
  final String title, imageUrl;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.obsidianCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderLight,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F111111),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.trim().isNotEmpty)
                  ProductImage(url: imageUrl, darkPlaceholder: true)
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: CustomerVisual.charcoal,
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 38,
                        color: AppTheme.primaryYellow.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x14000000),
                        Color(0x550D0B08),
                        Color(0xEB110E09),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: LocalizedText(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          gradient: CustomerVisual.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.obsidianDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Reflows monetary summaries for enlarged text without clipping either value.
class CommerceSummaryLine extends StatelessWidget {
  const CommerceSummaryLine(
      {super.key,
      required this.label,
      required this.value,
      this.labelStyle,
      this.valueStyle});
  final String label, value;
  final TextStyle? labelStyle, valueStyle;
  @override
  Widget build(BuildContext context) {
    final title = LocalizedText(label, style: labelStyle);
    final amount =
        LocalizedText(value, style: valueStyle, textAlign: TextAlign.end);
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        title,
        const SizedBox(height: 4),
        amount,
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(flex: 2, child: title),
      const SizedBox(width: 10),
      Expanded(
        flex: 3,
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: amount,
          ),
        ),
      ),
    ]);
  }
}

/// Shared cart presentation. Callers retain stock validation and mutation ownership.
class CommerceCartItemCard extends StatelessWidget {
  const CommerceCartItemCard(
      {super.key,
      required this.item,
      required this.decrease,
      required this.increase,
      required this.remove});
  final CartItem item;
  final VoidCallback decrease, increase, remove;
  String money(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: CustomerVisual.panel(),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                    width: 54,
                    height: 54,
                    child: ProductImage(url: item.imageUrl))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: item.name,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${money(item.price)} / un.',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.textSecondary)),
                ])),
            IconButton(
                tooltip: '${localizedLabel(context, 'Remover')} ${item.name}',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: remove,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.textSecondary),
          ]),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, constraints) {
            final price = Text(money(item.totalPrice),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkGold));
            final stepper = GoldStepper(
                value: item.quantity,
                compact: true,
                semanticLabel: '${item.quantity} unidades',
                decrease: decrease,
                increase: increase);
            if (constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    price,
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerRight, child: stepper),
                  ]);
            }
            return Row(children: [Expanded(child: price), stepper]);
          }),
        ]),
      );
}

/// Neutral, code-rendered campaign. No restricted advertising is embedded.
class ConvenienceCampaign extends StatefulWidget {
  const ConvenienceCampaign({super.key, this.compact = false});
  final bool compact;
  @override
  State<ConvenienceCampaign> createState() => _ConvenienceCampaignState();
}

class _ConvenienceCampaignState extends State<ConvenienceCampaign> {
  int selected = 0;
  final pages = PageController();
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: widget.compact ? 12 : 0),
          clipBehavior: Clip.antiAlias,
          decoration: CustomerVisual.panel(dark: true).copyWith(
            borderRadius: widget.compact
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: _campaignHeight(context),
                child: PageView(
                  key: const ValueKey('premium-campaign-carousel'),
                  controller: pages,
                  onPageChanged: (value) => setState(() => selected = value),
                  children: [
                    _slide(
                      es ? 'TU DÍA PIDE' : 'SEU DIA PEDE',
                      es ? 'CONVENIENCIA' : 'CONVENIÊNCIA',
                      es
                          ? 'Encuentra lo que necesitas en nuestro catálogo.'
                          : 'Encontre o que precisa no nosso catálogo.',
                    ),
                    _slide(
                      es ? 'ELIGE A TU MANERA' : 'ESCOLHA DO SEU JEITO',
                      es ? 'PIT STOP V8' : 'PIT STOP V8',
                      es
                          ? 'Explora las categorías y las ofertas disponibles.'
                          : 'Explore as categorias e as ofertas disponíveis.',
                    ),
                  ],
                ),
              ),
              if (!widget.compact)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF15120D),
                    border: Border(top: BorderSide(color: Color(0xFFA5751D))),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        _benefit(
                          Icons.storefront_outlined,
                          es
                              ? 'Catálogo\na tu alcance'
                              : 'Catálogo\nna sua mão',
                        ),
                        const VerticalDivider(
                          color: Color(0xFF6D501F),
                          width: 14,
                        ),
                        _benefit(
                          Icons.lock_outline,
                          es
                              ? 'Compra con\nseguridad'
                              : 'Compra com\nsegurança',
                        ),
                        const VerticalDivider(
                          color: Color(0xFF6D501F),
                          width: 14,
                        ),
                        _benefit(
                          Icons.inventory_2_outlined,
                          es
                              ? 'Conveniencia\npara tu día'
                              : 'Conveniência\npara seu dia',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!widget.compact)
          SizedBox(
            height: 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  Semantics(
                    label:
                        es ? 'Campaña ${i + 1} de 2' : 'Campanha ${i + 1} de 2',
                    selected: selected == i,
                    child: SizedBox(
                      width: 48,
                      child: InkWell(
                        onTap: () => pages.animateToPage(
                          i,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                        child: Center(
                          child: Container(
                            width: selected == i ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: selected == i
                                  ? AppTheme.primaryYellow
                                  : AppColors.borderLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  double _campaignHeight(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final width = (MediaQuery.sizeOf(context).width.clamp(0, 1200) -
            (widget.compact ? 24 : 0) -
            36)
        .clamp(1.0, 1200.0);
    final monogram = !widget.compact &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3 &&
        width >= 380;
    final textWidth = (width * (monogram ? .7 : 1.0)).toDouble();
    double height(String text, TextStyle style, double available) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: available);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final overlines = [
      es ? 'TU DÍA PIDE' : 'SEU DIA PEDE',
      es ? 'ELIGE A TU MANERA' : 'ESCOLHA DO SEU JEITO',
    ];
    final titles = [es ? 'CONVENIENCIA' : 'CONVENIÊNCIA', 'PIT STOP V8'];
    final subtitles = [
      es
          ? 'Encuentra lo que necesitas en nuestro catálogo.'
          : 'Encontre o que precisa no nosso catálogo.',
      es
          ? 'Explora las categorías y las ofertas disponibles.'
          : 'Explore as categorias e as ofertas disponíveis.',
    ];
    final header = height(
      'PIT STOP V8',
      const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
      width - 26,
    );
    var result = widget.compact ? 140.0 : 194.0;
    for (var i = 0; i < 2; i++) {
      final content = (header > 19 ? header : 19) +
          28 +
          10 +
          3 +
          9 +
          4 +
          height(
            overlines[i],
            TextStyle(
              fontSize: widget.compact ? 15 : 21,
              height: 1.05,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
            textWidth,
          ) +
          height(
            titles[i],
            TextStyle(
              fontSize: widget.compact ? 21 : 29,
              height: 1,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
            textWidth,
          ) +
          height(
            subtitles[i],
            const TextStyle(fontSize: 11, height: 1.3),
            textWidth,
          );
      if (content > result) result = content;
    }
    return result;
  }

  Widget _slide(String overline, String title, String subtitle) =>
      PremiumAtmosphere(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/banners/home_hero_pitstop_v8.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xE80B0B0B),
                    Color(0xBA14100A),
                    Color(0x520B0B0B),
                  ],
                  stops: [0.0, 0.58, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: LayoutBuilder(
            builder: (context, constraints) {
              final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        color: AppTheme.primaryYellow,
                        size: 19,
                      ),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'PIT STOP V8',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                overline,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.compact ? 15 : 21,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                title,
                                style: TextStyle(
                                  color: AppTheme.primaryYellow,
                                  fontSize: widget.compact ? 21 : 29,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Color(0xFFECE4D3),
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!largeText &&
                            !widget.compact &&
                            constraints.maxWidth >= 380)
                          const Expanded(
                            flex: 3,
                            child: ExcludeSemantics(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  children: [
                                    Text(
                                      'V8',
                                      style: TextStyle(
                                        color: Color(0xFFFFD96B),
                                        fontSize: 70,
                                        fontWeight: FontWeight.w900,
                                        fontStyle: FontStyle.italic,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xAA000000),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'PIT STOP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
          ],
        ),
      );
  Widget _benefit(IconData icon, String label) => Expanded(
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryYellow, size: 22),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      );
}

class CommerceTrustStrip extends StatelessWidget {
  const CommerceTrustStrip({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final item in [
              (Icons.lock_outline, 'Pagamento seguro'),
              (Icons.receipt_long_outlined, 'Resumo do pedido'),
              (Icons.privacy_tip_outlined, 'Seus dados protegidos'),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$1, color: AppColors.darkGold, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: LocalizedText(
                      item.$2,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
}

/// Route callbacks are supplied by Home; the cart/session remains owned there.
class CommerceRouteNavigation extends InheritedWidget {
  const CommerceRouteNavigation({
    super.key,
    required this.onSelected,
    required super.child,
    this.onSearch,
    this.onCart,
    this.onAddress,
    this.address,
    this.cartCount = 0,
  });
  final ValueChanged<int> onSelected;
  final VoidCallback? onSearch, onCart, onAddress;
  final String? address;
  final int cartCount;
  static CommerceRouteNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommerceRouteNavigation>();
  static Widget? bar(BuildContext context, int selectedIndex) {
    final scope = maybeOf(context);
    return scope == null
        ? null
        : CommerceBottomBar(
            selectedIndex: selectedIndex,
            onSelected: scope.onSelected,
          );
  }

  @override
  bool updateShouldNotify(CommerceRouteNavigation oldWidget) =>
      oldWidget.onSelected != onSelected;
}

class CommerceProductCard extends StatelessWidget {
  const CommerceProductCard({
    super.key,
    required this.product,
    required this.onOpen,
    this.onAdd,
    this.onRemove,
    this.quantity = 0,
    this.isFavorite = false,
    this.onToggleFavorite,
  });
  final Product product;
  final VoidCallback onOpen;
  final VoidCallback? onAdd, onRemove, onToggleFavorite;
  final int quantity;
  final bool isFavorite;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14916A16),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: ProductImage.fallbackBackground,
                        child: ProductImage(url: product.imageUrl),
                      ),
                      if (quantity > 0)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryYellow,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.goldDeep,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                color: AppTheme.obsidianDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IconButton(
                          tooltip: isFavorite
                              ? 'Remover ${product.name} dos favoritos'
                              : 'Favoritar ${product.name}',
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: onToggleFavorite,
                          icon: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.borderLight,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 15,
                              color: isFavorite
                                  ? AppColors.error
                                  : AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 4, 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final price = FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'R\$ ${product.price.toStringAsFixed(2).replaceAll('.', ',')}',
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.darkGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      );
                      final add = IconButton(
                        tooltip: onAdd == null
                            ? localizedLabel(context, 'Indisponível')
                            : 'Adicionar ${product.name}',
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onAdd,
                        icon: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: onAdd == null ? null : CustomerVisual.gold,
                            color:
                                onAdd == null ? AppColors.mutedSurface : null,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: onAdd == null
                                  ? AppColors.borderLight
                                  : AppTheme.goldDeep,
                              width: 1,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppTheme.obsidianDark,
                            ),
                          ),
                        ),
                      );
                      final removeBtn = IconButton(
                        tooltip: 'Diminuir quantidade de ${product.name}',
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onRemove,
                        icon: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.remove_rounded,
                              size: 16,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      );
                      final actionsRow = quantity > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                removeBtn,
                                Text(
                                  '$quantity',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                add,
                              ],
                            )
                          : add;
                      return (constraints.maxWidth < 130 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.3)
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                price,
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: actionsRow,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: price),
                                const SizedBox(width: 4),
                                actionsRow,
                              ],
                            );
                    },
                  ),
                ),
                if (onAdd == null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 5),
                    child: LocalizedText(
                      'Indisponível',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class CommerceOrderTimeline extends StatelessWidget {
  const CommerceOrderTimeline({super.key, required this.currentStep});
  final int currentStep;
  @override
  Widget build(BuildContext context) {
    const labels = [
      'Pedido recebido',
      'Em separação',
      'Saiu para entrega',
      'Entregue',
    ];
    const icons = [
      Icons.receipt_long_outlined,
      Icons.inventory_2_outlined,
      Icons.two_wheeler_rounded,
      Icons.home_outlined,
    ];
    return Container(
      decoration: CustomerVisual.panel(),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 310 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          Widget stage(int i) {
            final active = i <= currentStep;
            final badge = Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: active ? CustomerVisual.gold : null,
                color: active ? null : AppColors.mutedSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      active ? AppTheme.primaryYellow : AppColors.borderLight,
                ),
              ),
              child: Icon(
                i < currentStep ? Icons.check : icons[i],
                size: 23,
                color: active ? AppTheme.darkBg : AppColors.textSecondary,
              ),
            );
            final text = LocalizedText(
              labels[i],
              textAlign: vertical ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.15,
                fontWeight:
                    i == currentStep ? FontWeight.w900 : FontWeight.w600,
              ),
            );
            return Semantics(
              label:
                  '${localizedLabel(context, labels[i])}: ${i < currentStep ? localizedLabel(context, 'Concluída') : i == currentStep ? localizedLabel(context, 'Etapa atual') : localizedLabel(context, 'Aguardando')}',
              excludeSemantics: true,
              child: vertical
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          badge,
                          const SizedBox(width: 12),
                          Expanded(child: text),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [badge, const SizedBox(height: 7), text],
                    ),
            );
          }

          if (vertical) {
            return Column(
              children: [
                const LocalizedText('STATUS DO PEDIDO'),
                for (var i = 0; i < 4; i++) stage(i),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LocalizedText(
                'STATUS DO PEDIDO',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Positioned(
                    top: 18,
                    left: constraints.maxWidth / 8,
                    right: constraints.maxWidth / 8,
                    child: Container(height: 3, color: AppColors.borderLight),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 4; i++) Expanded(child: stage(i)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class CommerceProfileBanner extends StatelessWidget {
  const CommerceProfileBanner({
    super.key,
    required this.name,
    this.phone,
    this.email,
  });
  final String name;
  final String? phone, email;
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: CustomerVisual.panel(dark: true).copyWith(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(18),
            bottom: Radius.circular(28),
          ),
        ),
        child: PremiumAtmosphere(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/profile/profile_card_bg.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xCC0B0B0B),
                        Color(0xAE1D150A),
                        Color(0xD4100E0A),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x55000000),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppTheme.goldMid.withValues(alpha: 0.7),
                        ),
                      ),
                      child: const Text(
                        'PIT STOP V8',
                        style: TextStyle(
                          color: AppTheme.primaryYellow,
                          fontSize: 11,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            gradient: CustomerVisual.gold,
                            shape: BoxShape.circle,
                          ),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFFE8E5DE),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: CustomerVisual.gold,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.obsidianDark,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 12,
                              color: AppTheme.obsidianDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Localizations.localeOf(context).languageCode == 'es'
                                ? 'Hola,'
                                : 'Olá,',
                            style: const TextStyle(
                              color: Color(0xFFECE4D3),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name.isEmpty
                                ? localizedLabel(context, 'Bem-vindo ao Chamaê')
                                : name,
                            style: AppTheme.displayFont(
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (phone?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                phone!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (email?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                email!,
                                style: const TextStyle(
                                  color: Color(0xFFDED4BF),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFB98725)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: AppTheme.primaryYellow,
                        size: 21,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: LocalizedText(
                          'Cliente Chamaê',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
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
        ),
      );
}
