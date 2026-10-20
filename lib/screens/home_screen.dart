import '../widgets/customer_visual.dart';
import '../widgets/delivery_quote_summary.dart';
import '../data/restore_customer_cart.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/catalog.dart';
import '../core/catalog_commercial_policy.dart';
import '../core/theme.dart';
import '../core/store_hours.dart';
import '../widgets/product_image.dart';
import 'cart_screen.dart';
import 'customer_profile_screen.dart';
import '../widgets/sponsor_video_banner.dart';
import 'address_destination_screen.dart';
import '../data/customer_workspace.dart';
import '../data/delivery_quote.dart';
import '../data/customer_verification.dart';
import 'checkout_screen.dart';

class DeliveryHomeScreen extends StatefulWidget {
  final Stream<List<Product>>? products;
  final DeliveryAddress? initialAddress;
  final CustomerWorkspace? workspace;
  final DeliveryQuoter? quoter;
  const DeliveryHomeScreen(
      {super.key,
      this.products,
      this.initialAddress,
      this.workspace,
      this.quoter});
  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  bool _categoryOverview = false;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  bool _filterOnlyOffers = false;
  bool _filterOnlyCombos = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _categoryScrollCtrl = ScrollController();
  final Map<String, CartItem> _cart = {};
  DeliveryAddress? _deliveryAddress;
  DeliveryQuoteController? _deliveryQuote;
  String _selectedCurrency = 'BRL';
  Timer? _hoursTimer;
  CustomerWorkspace? _workspace;
  bool _workspaceReady = true;
  String? _persistenceError;
  String? _cartNotice;
  Future<void>? _cartRestore;
  late Stream<List<Product>> _productsStream;
  Map<String, Product> _latestProducts = {};
  @override
  void initState() {
    super.initState();
    _deliveryAddress = widget.initialAddress;
    if (widget.products == null || widget.quoter != null) {
      _deliveryQuote =
          DeliveryQuoteController(widget.quoter ?? FirebaseDeliveryQuoter());
      if (_deliveryAddress != null) _deliveryQuote!.refresh(_deliveryAddress!);
    }
    if (widget.products == null || widget.workspace != null) {
      _workspace = widget.workspace ?? FirebaseCustomerWorkspace();
      _workspaceReady = false;
      _restoreCart();
    }
    _productsStream = widget.products ??
        FirebaseFirestore.instance
            .collection('products')
            .snapshots()
            .map((s) => s.docs.map(Product.fromFirestore).toList());
    _hoursTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  static const double _pygPerBrl = 1500.0;
  static const double _brlPerUsd = 5.0;

  double _convertFromBRL(double valueBRL) {
    switch (_selectedCurrency) {
      case 'PYG':
        return valueBRL * _pygPerBrl;
      case 'USD':
        return valueBRL / _brlPerUsd;
      default:
        return valueBRL;
    }
  }

  String _formatMoney(double valueBRL) {
    final converted = _convertFromBRL(valueBRL);

    switch (_selectedCurrency) {
      case 'PYG':
        return 'G\$ ${converted.toStringAsFixed(0)}';
      case 'USD':
        return 'US\$ ${converted.toStringAsFixed(2)}';
      default:
        return 'R\$ ${converted.toStringAsFixed(2)}';
    }
  }

  final List<String> _categories = [
    'Todos',
    'Cervejas',
    'Destilados',
    'Kaipi Fruit',
    'Energéticos',
    'Vinhos',
    'Refrigerantes & Sucos',
    'Snacks & Doces',
    'Gelo & Conveniência',
  ];
  @override
  void dispose() {
    _deliveryQuote?.dispose();
    _hoursTimer?.cancel();
    _searchCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreCart() =>
      _cartRestore ??= _readCart().whenComplete(() => _cartRestore = null);
  Future<void> _readCart() async {
    try {
      final data = await _workspace!.read();
      final restored = await restoreCustomerCart(data['cart'] as List? ?? [],
          lookup: widget.products != null
              ? null
              : (id) async => (await FirebaseFirestore.instance
                      .collection('products')
                      .doc(id)
                      .get(const GetOptions(source: Source.server))
                      .timeout(const Duration(seconds: 8)))
                  .data());
      if (!mounted) return;
      setState(() {
        _cart
          ..clear()
          ..addAll(restored.items);
        _cartNotice = restored.notices.isEmpty
            ? null
            : restored.notices.toSet().join('\n');
        final contact = data['contact'];
        if (contact is Map) {
          if (UserSession.fullName.isEmpty) {
            UserSession.fullName = contact['name']?.toString() ?? '';
          }
          UserSession.whatsapp = contact['phone']?.toString() ?? '';
        }
        _workspaceReady = true;
        _persistenceError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _persistenceError =
            'Não foi possível recuperar seu carrinho. Confira a conexão e tente novamente.');
      }
    }
  }

  void _persistCart() {
    if (_workspace == null || !_workspaceReady) return;
    if (mounted && _persistenceError != null) {
      setState(() => _persistenceError = null);
    }
    _workspace!.save({
      'cart': _cart.values
          .map((i) => {
                'id': i.id,
                'name': i.name,
                'price': i.price,
                'imageUrl': i.imageUrl,
                'quantity': i.quantity,
                'category': i.category,
                'commercialBlocked': i.commercialBlocked
              })
          .toList()
    }).catchError((Object _) {
      if (mounted) {
        setState(() => _persistenceError =
            'Sem confirmação de conexão. O carrinho foi mantido; tente sincronizar novamente.');
      }
    });
  }

  void _addToCart(Product product) {
    if (!_workspaceReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Aguarde a recuperação do carrinho ou tente novamente.')));
      return;
    }
    if (!commerciallyAvailable(product)) return;
    if ((_cart[product.id]?.quantity ?? 0) >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Você já adicionou a quantidade disponível.')));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      if (_cart.containsKey(product.id)) {
        if (_cart[product.id]!.quantity < product.stock) {
          _cart[product.id]!.quantity++;
        }
      } else {
        _cart[product.id] = CartItem(
          id: product.id,
          category: product.category,
          commercialBlocked: product.commercialBlocked,
          name: product.name,
          price: product.price,
          imageUrl: product.imageUrl,
          quantity: 1,
        );
      }
    });
    _persistCart();
  }

  void _removeFromCart(String id) {
    setState(() {
      if (!_cart.containsKey(id)) return;
      if (_cart[id]!.quantity > 1) {
        _cart[id]!.quantity--;
      } else {
        _cart.remove(id);
      }
    });
    _persistCart();
  }

  int get _totalItemsCount {
    return _cart.values.fold(
      0,
      (accumulated, item) => accumulated + item.quantity,
    );
  }

  double get _subtotalPrice {
    return _cart.values.fold(
      0.0,
      (accumulated, item) => accumulated + item.totalPrice,
    );
  }

  Widget _buildProductImage(String url) => ProductImage(url: url);

  void _pruneRestrictedCart() {
    final removed = <String>[];
    for (final item in _cart.values) {
      final latest = _latestProducts[item.id];
      if (isCommerciallyBlocked({
        'name': latest?.name ?? item.name,
        'category': latest?.category ?? item.category,
        'commercialBlocked': latest?.commercialBlocked ?? item.commercialBlocked
      })) {
        removed.add(item.id);
      }
    }
    if (removed.isNotEmpty) {
      setState(() {
        for (final id in removed) {
          _cart.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Itens fora de venda foram removidos do carrinho.')));
    }
  }

  Future<void> _openCart() async {
    if (_workspace != null) await _restoreCart();
    if (!mounted) return;
    _pruneRestrictedCart();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CartScreen(
                  notice: _cartNotice,
                  destination: _deliveryAddress,
                  quoter: widget.quoter,
                  items: () => _cart.values.toList(),
                  change: (id, delta) {
                    if (delta > 0) {
                      final product = _latestProducts[id];
                      if (product != null) _addToCart(product);
                    } else {
                      for (var i = 0; i < -delta; i++) {
                        _removeFromCart(id);
                      }
                    }
                  },
                  checkout: () {
                    Navigator.pop(context);
                    _openCheckout();
                  },
                )));
  }

  void _showProduct(Product product) {
    var quantity = 1;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 760),
        showDragHandle: true,
        backgroundColor: AppTheme.lightBg,
        builder: (ctx) => SafeArea(
                child: StatefulBuilder(
              builder: (ctx, update) => SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                                tooltip: 'Fechar',
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close))),
                        SizedBox(
                            height: MediaQuery.sizeOf(ctx).height * .32,
                            child: Container(
                                decoration: CustomerVisual.panel(),
                                padding: const EdgeInsets.all(16),
                                child: ProductImage(url: product.imageUrl))),
                        const SizedBox(height: 24),
                        Text(product.name,
                            style: Theme.of(ctx)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(_formatMoney(product.price),
                            style: const TextStyle(
                                color: AppColors.darkGold,
                                fontSize: 32,
                                fontWeight: FontWeight.w900)),
                        Text(commerciallyAvailable(product)
                            ? 'Disponível'
                            : 'Indisponível no momento'),
                        if (product.description.trim().isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(product.description)),
                        if (commerciallyAvailable(product))
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    tooltip: 'Diminuir quantidade',
                                    onPressed: quantity > 1
                                        ? () => update(() => quantity--)
                                        : null,
                                    icon: const Icon(Icons.remove)),
                                Text('$quantity'),
                                IconButton(
                                    tooltip: 'Aumentar quantidade',
                                    onPressed: quantity < product.stock
                                        ? () => update(() => quantity++)
                                        : null,
                                    icon: const Icon(Icons.add)),
                              ]),
                        const SizedBox(height: 16),
                        Text(_formatMoney(product.price * quantity),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                color: AppColors.darkGold,
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: commerciallyAvailable(product)
                                ? () {
                                    final remaining = product.stock -
                                        (_cart[product.id]?.quantity ?? 0);
                                    if (quantity > remaining) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Ajuste a quantidade ao estoque disponível.')));
                                      return;
                                    }
                                    for (var i = 0; i < quantity; i++) {
                                      _addToCart(product);
                                    }
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Adicionado ao carrinho.')));
                                  }
                                : null,
                            child: Text(commerciallyAvailable(product)
                                ? 'Adicionar ao carrinho'
                                : 'Indisponível')),
                      ])),
            )));
  }

  Future<void> _openCheckout() async {
    if (_workspace != null) await _restoreCart();
    if (!mounted || !_workspaceReady) return;
    _pruneRestrictedCart();
    if (!isStoreOpen()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(storeHoursLabel())));
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua sacola está vazia.'),
        ),
      );
      return;
    }

    if (_deliveryAddress == null) {
      await _selectDeliveryLocation();

      if (!mounted || _deliveryAddress == null) return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: _cart.values.toList(),
          deliveryAddress: _deliveryAddress!,
          initialCurrency: _selectedCurrency,
          quoter: widget.quoter ?? FirebaseDeliveryQuoter(),
          workspace: _workspace,
          verification: ConfiguredAccountVerification(),
          onCartCleared: () {},
          onOrderConfirmed: (consumed) {
            if (!mounted) return;
            setState(() {
              for (final row in consumed) {
                final item = _cart[row['id']];
                if (item == null) continue;
                item.quantity -= (row['quantity'] as num).toInt();
                if (item.quantity <= 0) _cart.remove(item.id);
              }
            });
            _persistCart();
          },
        ),
      ),
    );
  }

  void _selectCategory(String category) {
    setState(() {
      _categoryOverview = false;
      _selectedCategory = category;
      _filterOnlyOffers = false;
      _filterOnlyCombos = false;
    });
  }

  void _showOffers() {
    setState(() {
      _categoryOverview = false;
      _filterOnlyOffers = !_filterOnlyOffers;
      _filterOnlyCombos = false;
      _selectedCategory = 'Todos';
    });
  }

  void _showCombos() {
    setState(() {
      _categoryOverview = false;
      _filterOnlyCombos = !_filterOnlyCombos;
      _filterOnlyOffers = false;
      _selectedCategory = 'Todos';
    });
  }

  Future<void> _selectDeliveryLocation() async {
    final address = await Navigator.push<DeliveryAddress>(
        context,
        MaterialPageRoute(
            builder: (_) => AddressDestinationScreen(
                onboarding: false, workspace: _workspace)));
    if (!mounted || address == null) return;
    setState(() => _deliveryAddress = address);
    _deliveryQuote?.refresh(address);
  }

  void _abrirMenuApple() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CustomerProfileScreen(
                address: _deliveryAddress,
                selectAddress: _selectDeliveryLocation)));
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Todos':
        return Icons.grid_view_rounded;
      case 'Cervejas':
        return Icons.sports_bar_rounded;
      case 'Destilados':
        return Icons.liquor_rounded;
      case 'Kaipi Fruit':
        return Icons.local_dining_rounded;
      case 'Energéticos':
        return Icons.battery_charging_full_rounded;
      case 'Vinhos':
        return Icons.wine_bar_rounded;
      case 'Refrigerantes & Sucos':
        return Icons.local_drink_rounded;
      case 'Tabacaria':
        return Icons.smoking_rooms_rounded;
      case 'Snacks & Doces':
        return Icons.cookie_outlined;
      case 'Gelo & Conveniência':
        return Icons.ac_unit_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
          color: AppTheme.lightBg,
          border: Border(bottom: BorderSide(color: AppColors.borderLight))),
      child: SafeArea(
        bottom: false,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Image.asset('assets/images/logo.png',
                        width: 76,
                        height: 64,
                        semanticLabel: 'Chamaê Delivery',
                        fit: BoxFit.contain),
                    const SizedBox(width: 12),
                    Expanded(
                        child: InkWell(
                            onTap: _selectDeliveryLocation,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(children: [
                                  const Icon(Icons.location_on_rounded,
                                      color: AppColors.darkGold),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        const Text('Entregar em',
                                            style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12)),
                                        Text(
                                            _deliveryAddress?.addressText ??
                                                'Escolha seu endereço',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800)),
                                      ])),
                                  const Icon(Icons.expand_more, size: 18),
                                ])))),
                    IconButton(
                        tooltip: 'Carrinho',
                        onPressed: _openCart,
                        icon: Badge(
                            isLabelVisible: _totalItemsCount > 0,
                            label: Text('$_totalItemsCount'),
                            backgroundColor: AppTheme.primaryYellow,
                            textColor: AppTheme.darkBg,
                            child: const Icon(Icons.shopping_cart_outlined))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.circle,
                        size: 7,
                        color: isStoreOpen()
                            ? AppColors.accentGreen
                            : AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(storeHoursLabel(),
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                    PopupMenuButton<String>(
                        tooltip: 'Moeda de exibição',
                        initialValue: _selectedCurrency,
                        onSelected: (currency) =>
                            setState(() => _selectedCurrency = currency),
                        itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'BRL', child: Text('Real (BRL)')),
                              PopupMenuItem(
                                  value: 'PYG', child: Text('Guarani (PYG)')),
                              PopupMenuItem(
                                  value: 'USD', child: Text('Dólar (USD)')),
                            ],
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_selectedCurrency,
                                style: const TextStyle(
                                    color: AppColors.darkGold,
                                    fontWeight: FontWeight.w800)))),
                  ]),
                  if (_deliveryAddress != null && _deliveryQuote != null)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: DeliveryQuoteSummary(
                                controller: _deliveryQuote!))),
                ])),
      ),
    );
  }

  Widget _buildCategoryOverview(List<Product> catalog) {
    final products = visibleCatalogProducts(catalog);
    final categories = _categories
        .where((c) =>
            c != 'Todos' &&
            products.any((p) => p.category == c) &&
            (_searchQuery.isEmpty ||
                c.toLowerCase().contains(_searchQuery) ||
                products.any((p) =>
                    p.category == c &&
                    p.name.toLowerCase().contains(_searchQuery))))
        .toList();
    if (categories.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma categoria disponível.'));
    }
    return LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth > 850 ? 3 : 2,
                  mainAxisExtent: 200 +
                      65 * (MediaQuery.textScalerOf(context).scale(1) - 1),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final matching =
                    products.where((p) => p.category == category).toList();
                return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('category-$category'),
                      onTap: () => _selectCategory(category),
                      borderRadius: BorderRadius.circular(24),
                      child: Ink(
                          decoration: CustomerVisual.panel(dark: true),
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: ProductImage(
                                                url: matching.first.imageUrl))),
                                    const SizedBox(height: 10),
                                    Text(category,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Expanded(
                                          child: Text(
                                              '${matching.length} produto(s)',
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12))),
                                      const Icon(Icons.arrow_circle_right,
                                          color: AppTheme.primaryYellow),
                                    ]),
                                  ]))),
                    ));
              },
            ));
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          height: 64 + 50 * (MediaQuery.textScalerOf(context).scale(1) - 1),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryYellow : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: AppTheme.primaryYellow,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.black : AppColors.darkGold,
                size: 25,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.black : AppColors.textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected ? Colors.black87 : AppColors.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: selected ? Colors.black : AppColors.textMain,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        },
        decoration: const InputDecoration(
          hintText: 'Buscar bebidas e conveniência',
          hintStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.black,
            size: 25,
          ),
          suffixIcon: Icon(
            Icons.tune_rounded,
            color: Colors.black,
            size: 21,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 104 + 65 * (MediaQuery.textScalerOf(context).scale(1) - 1),
      child: ListView.builder(
        controller: _categoryScrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ),
            child: InkWell(
              onTap: () {
                _selectCategory(category);
              },
              borderRadius: BorderRadius.circular(50),
              child: SizedBox(
                width: 100,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 180,
                      ),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: selected
                            ? AppTheme.primaryYellow
                            : AppColors.surfaceWhite,
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryYellow
                              : AppColors.borderLight,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        _categoryIcon(category),
                        size: 25,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final cartQty = _cart[product.id]?.quantity ?? 0;
    return GestureDetector(
        onTap: () => _showProduct(product),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  cartQty > 0 ? AppTheme.primaryYellow : AppColors.borderLight,
              width: cartQty > 0 ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.055),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 56,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Color(0xFFFFFFFF), Color(0xFFF1E6D1)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter)),
                        padding: const EdgeInsets.all(8),
                        child: _buildProductImage(
                          product.imageUrl,
                        ),
                      ),
                    ),
                    if (product.isOffer)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryYellow,
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'PROMOÇÃO',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 44,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    9,
                    8,
                    9,
                    9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF171717),
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formatMoney(product.price),
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          )),
                      const SizedBox(height: 7),
                      if (cartQty == 0)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AppTheme.primaryYellow,
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  9,
                                ),
                              ),
                            ),
                            onPressed: commerciallyAvailable(product)
                                ? () {
                                    _addToCart(product);
                                  }
                                : null,
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 16,
                            ),
                            label: Text(
                              commerciallyAvailable(product)
                                  ? 'Adicionar'
                                  : 'Indisponível',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryYellow,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    _removeFromCart(
                                      product.id,
                                    );
                                  },
                                  child: const Center(
                                    child: Icon(
                                      Icons.remove_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '$cartQty',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    _addToCart(product);
                                  },
                                  child: const Center(
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
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
            ],
          ),
        ));
  }

  Widget _buildBottomNavigation() => Container(
        decoration: BoxDecoration(
            color: AppTheme.lightBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14916A16),
                  blurRadius: 20,
                  offset: Offset(0, -4))
            ]),
        child: SafeArea(
            top: false,
            child: SizedBox(
              height: 72 + 90 * (MediaQuery.textScalerOf(context).scale(1) - 1),
              child: Row(children: [
                _bottomItem(
                    icon: Icons.home_rounded,
                    label: 'Início',
                    selected: !_categoryOverview &&
                        _selectedCategory == 'Todos' &&
                        !_filterOnlyOffers &&
                        !_filterOnlyCombos,
                    onTap: () => _selectCategory('Todos')),
                _bottomItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Categorias',
                    selected: _categoryOverview,
                    onTap: () => setState(() => _categoryOverview = true)),
                _bottomItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Pedidos',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CustomerHistoryScreen()))),
                _bottomItem(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Carrinho',
                    badge: _totalItemsCount,
                    onTap: _openCart),
                _bottomItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Perfil',
                    onTap: _abrirMenuApple),
              ]),
            )),
      );
  Widget _bottomItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    int badge = 0,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color:
                      selected ? AppColors.darkGold : AppColors.textSecondary,
                ),
                if (badge > 0)
                  Positioned(
                    right: -11,
                    top: -8,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 19,
                        minHeight: 19,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                      ),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryYellow,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.darkGold : AppColors.textSecondary,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SafeArea(
          bottom: false,
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (_cartNotice != null)
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_cartNotice!,
                              style: const TextStyle(color: AppColors.error)))),
                if (_persistenceError != null)
                  SliverToBoxAdapter(
                      child: MaterialBanner(
                          content: Text(_persistenceError!),
                          actions: [
                        TextButton(
                            onPressed:
                                _workspaceReady ? _persistCart : _restoreCart,
                            child: const Text('Tentar novamente'))
                      ])),
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
                const SliverToBoxAdapter(
                  child: SponsorVideoBanner(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      2,
                      16,
                      8,
                    ),
                    child: Row(
                      children: [
                        _buildFeatureButton(
                          icon: Icons.local_fire_department_rounded,
                          title: 'Ofertas do Dia',
                          subtitle: 'Preços imperdíveis',
                          selected: _filterOnlyOffers,
                          onTap: _showOffers,
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureButton(
                          icon: Icons.local_bar_rounded,
                          title: 'Combos Festa',
                          subtitle: 'Monte seu combo',
                          selected: _filterOnlyCombos,
                          onTap: _showCombos,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      2,
                      16,
                      10,
                    ),
                    child: _buildSearch(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildCategories(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      3,
                      16,
                      10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            size: 24, color: AppColors.darkGold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _categoryOverview
                                ? 'Categorias'
                                : _filterOnlyOffers
                                    ? 'Ofertas do Dia'
                                    : _filterOnlyCombos
                                        ? 'Combos Festa'
                                        : _selectedCategory != 'Todos'
                                            ? _selectedCategory
                                            : 'Produtos em Destaque',
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (_selectedCategory != 'Todos' ||
                            _filterOnlyOffers ||
                            _filterOnlyCombos)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = 'Todos';
                                _filterOnlyOffers = false;
                                _filterOnlyCombos = false;
                              });
                            },
                            child: const Text(
                              'Ver todos',
                              style: TextStyle(
                                color: Color(0xFF111111),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<List<Product>>(
                  key: const ValueKey('catalog-stream'),
                  stream: _productsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(children: [
                                const Text(
                                    'Não foi possível carregar os produtos.'),
                                TextButton(
                                    onPressed: () => setState(() {
                                          _productsStream = widget.products ??
                                              FirebaseFirestore.instance
                                                  .collection('products')
                                                  .snapshots()
                                                  .map((s) => s.docs
                                                      .map(
                                                          Product.fromFirestore)
                                                      .toList());
                                        }),
                                    child: const Text('Tentar novamente')),
                              ])));
                    }
                    if (!snapshot.hasData) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryYellow,
                            ),
                          ),
                        ),
                      );
                    }
                    _latestProducts = {for (final p in snapshot.data!) p.id: p};
                    if (_categoryOverview) {
                      return SliverToBoxAdapter(
                          child: _buildCategoryOverview(snapshot.data!));
                    }
                    final products = visibleCatalogProducts(
                      snapshot.data!,
                      query: _searchQuery,
                      category: _selectedCategory,
                      onlyOffers: _filterOnlyOffers,
                      onlyCombos: _filterOnlyCombos,
                    );
                    if (products.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            35,
                            24,
                            120,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 45,
                                color: Color(0xFFB5B5B5),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Nenhum produto encontrado.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF777777),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        24,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.sizeOf(context).width > 1100
                                  ? 5
                                  : MediaQuery.sizeOf(context).width > 850
                                      ? 4
                                      : MediaQuery.sizeOf(context).width > 600
                                          ? 3
                                          : 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 330 +
                              180 *
                                  (MediaQuery.textScalerOf(context).scale(1) -
                                      1),
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildProductCard(
                              products[index],
                            );
                          },
                          childCount: products.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ))),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: 'chamae_cart_button',
              elevation: 6,
              backgroundColor: AppTheme.primaryYellow,
              foregroundColor: Colors.black,
              onPressed: _openCart,
              icon: const Icon(
                Icons.shopping_bag_rounded,
              ),
              label: Text(
                '$_totalItemsCount • ${_formatMoney(_subtotalPrice)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            )
          : null,
    );
  }
}
