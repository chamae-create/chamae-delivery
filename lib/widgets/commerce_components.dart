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
          border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0DB77A08),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          children: [
            Image.asset(
              'assets/images/home/logo_transparent.png',
              width: constraints.maxWidth < 370 ? 94 : 122,
              height: 60,
              fit: BoxFit.contain,
              semanticLabel: 'Chamaê Delivery',
            ),
            Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.borderLight,
            ),
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
                              const Text(
                                'Pit Stop V8',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              LocalizedText(
                                address?.isNotEmpty == true
                                    ? address!
                                    : 'Escolha seu endereço',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
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
                  fontSize: 24,
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      border: Border(top: BorderSide(color: Color(0xFFFFDF72))),
      boxShadow: [
        BoxShadow(
          color: Color(0x17916A16),
          blurRadius: 15,
          offset: Offset(0, -3),
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
                              Icons.receipt_long_outlined,
                              Icons.person_outline_rounded,
                            ][i],
                            size: 24,
                            color: i == selectedIndex
                                ? AppTheme.primaryYellow
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 2),
                          LocalizedText(
                            ['Início', 'Categorias', 'Pedidos', 'Perfil'][i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: i == selectedIndex
                                  ? AppColors.darkGold
                                  : AppColors.textSecondary,
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
  });
  final int value;
  final VoidCallback? decrease, increase;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => Container(
    decoration: CustomerVisual.panel(),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: localizedLabel(context, 'Diminuir quantidade'),
          onPressed: decrease,
          icon: const Icon(Icons.remove),
        ),
        Semantics(
          liveRegion: true,
          label: semanticLabel ?? '$value',
          child: Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: localizedLabel(context, 'Aumentar quantidade'),
          onPressed: increase,
          style: IconButton.styleFrom(backgroundColor: AppTheme.primaryYellow),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

class CategoryBannerTile extends StatelessWidget {
  const CategoryBannerTile({
    super.key,
    required this.title,
    required this.count,
    required this.imageUrl,
    required this.onTap,
    this.icon = Icons.storefront_outlined,
  });
  final String title, imageUrl;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.darkBg,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Ink(
        decoration: CustomerVisual.panel(dark: true),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: imageUrl.isNotEmpty
                    ? ProductImage(url: imageUrl)
                    : Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFB98725)),
                          ),
                          child: Icon(
                            icon,
                            size: 28,
                            color: AppTheme.primaryYellow,
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 9, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LocalizedText(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$count ' +
                          (Localizations.localeOf(context).languageCode == 'es'
                              ? (count == 1 ? 'producto' : 'productos')
                              : (count == 1 ? 'produto' : 'produtos')),
                      style: const TextStyle(
                        color: Color(0xFFDED4BF),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: CustomerVisual.gold,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          size: 22,
                          color: AppTheme.darkBg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
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
            borderRadius: BorderRadius.circular(widget.compact ? 20 : 24),
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
                    label: es
                        ? 'Campaña ${i + 1} de 2'
                        : 'Campanha ${i + 1} de 2',
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
    final width =
        (MediaQuery.sizeOf(context).width.clamp(0, 1200) -
                (widget.compact ? 24 : 0) -
                36)
            .clamp(1.0, 1200.0);
    final monogram =
        !widget.compact &&
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
      final content =
          (header > 19 ? header : 19) +
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
        child: Padding(
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
  });
  final Product product;
  final VoidCallback onOpen;
  final VoidCallback? onAdd, onRemove;
  final int quantity;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceWhite,
    elevation: 1,
    shadowColor: const Color(0x22916A16),
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
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
                  color: const Color(0xFFFFFEFB),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ProductImage(url: product.imageUrl),
                  ),
                ),
                if (quantity > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      tooltip: 'Diminuir quantidade de ${product.name}',
                      onPressed: onRemove,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.lightGold,
                      ),
                      icon: const Icon(Icons.remove),
                    ),
                  ),
                if (quantity > 0)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Badge(
                      label: Text('$quantity'),
                      backgroundColor: AppTheme.primaryYellow,
                      textColor: AppTheme.darkBg,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 5, 7, 0),
            child: Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final price = Text(
                  'R\$ ${product.price.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    color: AppColors.darkGold,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                );
                final add = IconButton(
                  tooltip: onAdd == null
                      ? localizedLabel(context, 'Indisponível')
                      : 'Adicionar ${product.name}',
                  onPressed: onAdd,
                  icon: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: onAdd == null ? null : CustomerVisual.gold,
                      color: onAdd == null ? AppColors.mutedSurface : null,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.add_rounded, size: 20),
                    ),
                  ),
                );
                return constraints.maxWidth < 130 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          price,
                          Align(alignment: Alignment.centerRight, child: add),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: price),
                          add,
                        ],
                      );
              },
            ),
          ),
          if (onAdd == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(7, 0, 7, 5),
              child: LocalizedText(
                'Indisponível',
                style: TextStyle(fontSize: 10),
              ),
            ),
        ],
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
          final vertical =
              constraints.maxWidth < 310 ||
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
                  color: active
                      ? AppTheme.primaryYellow
                      : AppColors.borderLight,
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
                fontWeight: i == currentStep
                    ? FontWeight.w900
                    : FontWeight.w600,
              ),
            );
            return Semantics(
              label:
                  '${localizedLabel(context, labels[i])}: ${i < currentStep
                      ? localizedLabel(context, 'Concluída')
                      : i == currentStep
                      ? localizedLabel(context, 'Etapa atual')
                      : localizedLabel(context, 'Aguardando')}',
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

          if (vertical)
            return Column(
              children: [
                const LocalizedText('STATUS DO PEDIDO'),
                for (var i = 0; i < 4; i++) stage(i),
              ],
            );
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
    decoration: CustomerVisual.panel(dark: true),
    child: PremiumAtmosphere(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'PIT STOP V8',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.primaryYellow,
                fontSize: 14,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
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
                    child: Icon(Icons.person, color: Colors.white, size: 50),
                  ),
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
                      const SizedBox(height: 4),
                      Text(
                        name.isEmpty
                            ? localizedLabel(context, 'Bem-vindo ao Chamaê')
                            : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (phone?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
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
                          padding: const EdgeInsets.only(top: 4),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x66000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB98725)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: AppTheme.primaryYellow,
                    size: 23,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: LocalizedText(
                      'Seu perfil Chamaê',
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
    ),
  );
}
