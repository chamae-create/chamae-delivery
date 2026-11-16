import 'product_detail_screen.dart';
import '../core/restricted_catalog.dart';
import '../l10n/customer_localizations.dart';
import '../widgets/customer_visual.dart';
import '../data/restore_customer_cart.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/catalog.dart';
import '../core/catalog_commercial_policy.dart';
import '../core/theme.dart';
import '../core/store_hours.dart';
import '../widgets/product_image.dart';
import 'cart_screen.dart';
import 'customer_profile_screen.dart';
import '../widgets/commerce_components.dart';
import 'address_destination_screen.dart';
import '../data/customer_workspace.dart';
import '../data/delivery_quote.dart';
import '../data/customer_verification.dart';
import '../data/customer_orders.dart';
import '../data/order_notifications.dart';
import 'checkout_screen.dart';
import 'tracking_screen.dart';

class DeliveryHomeScreen extends StatefulWidget {
  final Stream<List<Product>>? products;
  final Stream<List<Map<String, dynamic>>>? activeOrders;
  final DeliveryAddress? initialAddress;
  final CustomerWorkspace? workspace;
  final DeliveryQuoter? quoter;
  const DeliveryHomeScreen({
    super.key,
    this.products,
    this.activeOrders,
    this.initialAddress,
    this.workspace,
    this.quoter,
  });
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
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _homeScrollCtrl = ScrollController();
  final GlobalKey _searchAnchor = GlobalKey();
  final GlobalKey _catalogAnchor = GlobalKey();
  bool _searchVisible = false;
  final Map<String, CartItem> _cart = {};
  final Set<String> _favorites = {};
  DeliveryAddress? _deliveryAddress;
  DeliveryQuoteController? _deliveryQuote;
  final String _selectedCurrency = 'BRL';
  Timer? _hoursTimer;
  late bool _storeWasOpen;
  CustomerWorkspace? _workspace;
  bool _workspaceReady = true;
  String? _persistenceError;
  String? _cartNotice;
  Future<void>? _cartRestore;
  late Stream<List<Product>> _productsStream;
  Stream<List<Map<String, dynamic>>>? _activeOrdersStream;
  Map<String, Product> _latestProducts = {};
  @override
  void initState() {
    super.initState();
    _deliveryAddress = widget.initialAddress;
    if (widget.products == null || widget.quoter != null) {
      _deliveryQuote = DeliveryQuoteController(
        widget.quoter ?? FirebaseDeliveryQuoter(),
      );
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
    if (widget.activeOrders != null) {
      _activeOrdersStream = widget.activeOrders;
    } else if (widget.products == null && Firebase.apps.isNotEmpty) {
      _activeOrdersStream = CustomerOrders(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      ).watchActiveOrders();
      unawaited(_initPushNotifications());
    }
    _storeWasOpen = isStoreOpen();
    _hoursTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final open = isStoreOpen();
      if (mounted && open != _storeWasOpen) {
        setState(() => _storeWasOpen = open);
      }
    });
  }

  Future<void> _initPushNotifications() async {
    await FirebaseCustomerPushNotifications.instance.initializeAndSyncToken(
      onOrderOpened: _openTrackingFromOrderId,
      onForegroundMessage: (title, body, orderId) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.obsidianDark,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.primaryYellow,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (body.isNotEmpty)
                  Text(
                    body,
                    style: const TextStyle(color: Colors.white),
                  ),
              ],
            ),
            action: orderId != null && orderId.isNotEmpty
                ? SnackBarAction(
                    label: 'Acompanhar',
                    textColor: AppTheme.primaryYellow,
                    onPressed: () => _openTrackingFromOrderId(orderId),
                  )
                : null,
          ),
        );
      },
    );
    final pending = FirebaseCustomerPushNotifications.pendingOrderId;
    if (mounted && pending != null && pending.isNotEmpty) {
      FirebaseCustomerPushNotifications.pendingOrderId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTrackingFromOrderId(pending);
      });
    }
  }

  void _openTrackingFromOrderId(String rawOrderId, {String? documentId}) {
    if (!mounted) return;
    final cleanId = rawOrderId.trim();
    if (cleanId.isEmpty && (documentId == null || documentId.isEmpty)) return;
    final resolvedDocId = documentId ?? (cleanId.startsWith('#') ? null : cleanId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingScreen(
          orderId: cleanId.isNotEmpty ? cleanId : documentId!,
          documentId: resolvedDocId,
        ),
      ),
    );
  }

  // Display BRL until a real commercial FX contract is configured.
  String _formatMoney(double valueBRL) =>
      'R\$ ${valueBRL.toStringAsFixed(2).replaceAll('.', ',')}';

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
    _searchFocus.dispose();
    _homeScrollCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreCart() =>
      _cartRestore ??= _readCart().whenComplete(() => _cartRestore = null);
  Future<void> _readCart() async {
    try {
      final data = await _workspace!.read();
      final restored = await restoreCustomerCart(
        data['cart'] as List? ?? [],
        lookup: widget.products != null
            ? null
            : (id) async => (await FirebaseFirestore.instance
                    .collection('products')
                    .doc(id)
                    .get(const GetOptions(source: Source.server))
                    .timeout(const Duration(seconds: 8)))
                .data(),
      );
      if (!mounted) return;
      setState(() {
        if (restored.items.isNotEmpty || _cart.isEmpty) {
          _cart
            ..clear()
            ..addAll(restored.items);
        }
        _cartNotice = restored.notices.isEmpty
            ? null
            : restored.notices.toSet().join('\n');
        final favs = data['favorites'];
        if (favs is List) {
          _favorites
            ..clear()
            ..addAll(favs.whereType<String>());
        }
        final contact = data['contact'];
        if (contact is Map) {
          if (UserSession.fullName.isEmpty) {
            UserSession.fullName = contact['name']?.toString() ?? '';
          }
          final savedPhone = contact['phone']?.toString() ?? '';
          if (UserSession.whatsapp.isEmpty && savedPhone.isNotEmpty) {
            UserSession.whatsapp = savedPhone;
          }
        }
        _workspaceReady = true;
        _persistenceError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _persistenceError =
              'Não foi possível recuperar seu carrinho. Confira a conexão e tente novamente.',
        );
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
          .map(
            (i) => {
              'id': i.id,
              'name': i.name,
              'price': i.price,
              'imageUrl': i.imageUrl,
              'quantity': i.quantity,
              'category': i.category,
              'isAlcoholic': i.isAlcoholic,
              'requiresAgeCheck': i.requiresAgeCheck,
              'commercialBlocked': i.commercialBlocked,
            },
          )
          .toList(),
    }).catchError((Object _) {
      if (mounted) {
        setState(
          () => _persistenceError =
              'Sem confirmação de conexão. O carrinho foi mantido; tente sincronizar novamente.',
        );
      }
    });
  }

  void _toggleFavorite(Product product) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_favorites.add(product.id)) {
        _favorites.remove(product.id);
      }
    });
    if (_workspace != null && _workspaceReady) {
      _workspace!.save({'favorites': _favorites.toList()}).catchError((Object _) {});
    }
  }

  void _addToCart(Product product) {
    if (!_workspaceReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Aguarde a recuperação do carrinho ou tente novamente.',
          ),
        ),
      );
      return;
    }
    if (!commerciallyAvailable(product) || restrictedCatalogProduct(product)) {
      return;
    }
    if ((_cart[product.id]?.quantity ?? 0) >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Você já adicionou a quantidade disponível.'),
        ),
      );
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
          isAlcoholic: product.isAlcoholic,
          requiresAgeCheck: product.requiresAgeCheck,
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


  void _pruneRestrictedCart() {
    final removed = <String>[];
    for (final item in _cart.values) {
      final latest = _latestProducts[item.id];
      if (restrictedCartItem(item) ||
          (latest != null && restrictedCatalogProduct(latest)) ||
          isCommerciallyBlocked({
            'id': item.id,
            'name': latest?.name ?? item.name,
            'category': latest?.category ?? item.category,
            'commercialBlocked':
                latest?.commercialBlocked ?? item.commercialBlocked,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Itens fora de venda foram removidos do carrinho.',
          ),
        ),
      );
    }
  }

  Future<void> _openCart() async {
    if (_workspace != null) await _restoreCart();
    if (!mounted) return;
    _pruneRestrictedCart();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _commerceRoute(
          CartScreen(
            notice: _cartNotice,
            destination: _deliveryAddress,
            quoter: widget.quoter,
            activeOrders: _activeOrdersStream,
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
          ),
        ),
      ),
    );
  }

  void _showProduct(Product product) {
    if (restrictedCatalogProduct(product)) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _commerceRoute(
          ProductDetailScreen(
            product: product,
            recommendations:
                visibleCatalogProducts(_latestProducts.values.toList())
                    .where(
                      (p) => p.id != product.id && !restrictedCatalogProduct(p),
                    )
                    .take(8)
                    .toList(),
            onRecommendation: _showProduct,
            remaining: () => product.stock - (_cart[product.id]?.quantity ?? 0),
            add: (quantity) {
              final current = _latestProducts[product.id];
              if (!_workspaceReady ||
                  current == null ||
                  !commerciallyAvailable(current) ||
                  restrictedCatalogProduct(current) ||
                  quantity > current.stock - (_cart[current.id]?.quantity ?? 0)) {
                return false;
              }
              for (var i = 0; i < quantity; i++) {
                _addToCart(current);
              }
              return true;
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCheckout() async {
    if (_workspace != null) await _restoreCart();
    if (!mounted || !_workspaceReady) return;
    _pruneRestrictedCart();
    if (!isStoreOpen()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: LocalizedText(storeHoursLabel())));
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Sua sacola está vazia.')),
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
        builder: (context) => _commerceRoute(
          CheckoutScreen(
            cartItems: _cart.values.toList(),
            deliveryAddress: _deliveryAddress!,
            initialCurrency: _selectedCurrency,
            quoter: widget.quoter ?? FirebaseDeliveryQuoter(),
            workspace: _workspace,
            activeOrders: _activeOrdersStream,
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
        builder: (_) =>
            AddressDestinationScreen(onboarding: false, workspace: _workspace),
      ),
    );
    if (!mounted || address == null) return;
    setState(() => _deliveryAddress = address);
    _deliveryQuote?.refresh(address);
  }

  void _abrirMenuApple() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _commerceRoute(
          CustomerProfileScreen(
            address: _deliveryAddress,
            selectAddress: _selectDeliveryLocation,
          ),
        ),
      ),
    );
  }

  bool _isRestrictedCategory(String category) {
    final normalized = category.trim().toLowerCase();
    return normalized.contains('tabacaria') ||
        normalized.contains('head shop') ||
        normalized.contains('headshop');
  }

  String _categoryImageAsset(String category, String fallbackUrl) {
    final normalized = category.trim().toLowerCase();
    if (normalized.contains('cervej')) {
      return 'assets/images/categories/cat_cervejas.jpg';
    }
    if (normalized.contains('destilad') || normalized.contains('vinh')) {
      return 'assets/images/categories/cat_destilados.jpg';
    }
    if (normalized.contains('refrigerant') || normalized.contains('suco')) {
      return 'assets/images/categories/cat_refrigerantes.jpg';
    }
    if (normalized.contains('água') ||
        normalized.contains('agua') ||
        normalized.contains('gelo')) {
      return 'assets/images/categories/cat_agua_gelo.jpg';
    }
    if (normalized.contains('energ')) {
      return 'assets/images/categories/cat_energeticos.jpg';
    }
    if (normalized.contains('snack') || normalized.contains('doce')) {
      return 'assets/images/categories/cat_snacks.jpg';
    }
    if (normalized.contains('conven') ||
        normalized.contains('kaipi') ||
        normalized.contains('promo')) {
      return 'assets/images/categories/cat_conveniencia.jpg';
    }
    return fallbackUrl;
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
      case 'Snacks & Doces':
        return Icons.cookie_outlined;
      case 'Gelo & Conveniência':
        return Icons.ac_unit_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _openSearch() {
    setState(() => _searchVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
      final anchor = _searchAnchor.currentContext;
      if (anchor != null) {
        Scrollable.ensureVisible(
          anchor,
          duration: const Duration(milliseconds: 220),
          alignment: .1,
        );
      }
    });
  }

  Future<void> _showAllProducts() async {
    while (mounted && _homeScrollCtrl.hasClients) {
      final object = _catalogAnchor.currentContext?.findRenderObject();
      if (object is RenderBox && object.hasSize) {
        await Scrollable.ensureVisible(
          _catalogAnchor.currentContext!,
          duration: const Duration(milliseconds: 220),
          alignment: 0,
        );
        return;
      }
      final position = _homeScrollCtrl.position;
      final next = (position.pixels + position.viewportDimension * .7).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next <= position.pixels) return;
      await _homeScrollCtrl.animateTo(
        next,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildHeader() => CommerceHeader(
        address: _deliveryAddress?.addressText,
        onAddress: _selectDeliveryLocation,
        onSearch: _openSearch,
        onCart: _openCart,
        cartCount: _totalItemsCount,
      );

  Widget _buildCategoryOverview(List<Product> catalog) {
    final products = visibleCatalogProducts(catalog)
        .where((p) => !restrictedCatalogProduct(p))
        .toList();
    final categories = products
        .map((p) => p.category)
        .toSet()
        .where(
          (c) =>
              !_isRestrictedCategory(c) &&
              (_searchQuery.isEmpty ||
                  c.toLowerCase().contains(_searchQuery) ||
                  products.any(
                    (p) =>
                        p.category == c &&
                        p.name.toLowerCase().contains(_searchQuery),
                  )),
        )
        .toList();
    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: LocalizedText('Nenhuma categoria disponível.'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3
              ? 1
              : constraints.maxWidth > 850
                  ? 3
                  : 2,
          mainAxisExtent: _categoryGridHeight(
            context,
            constraints.maxWidth,
            categories,
            products,
          ),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final matching =
              products.where((p) => p.category == category).toList();
          return CategoryBannerTile(
            key: ValueKey('category-$category'),
            title: category,
            count: matching.length,
            icon: _categoryIcon(category),
            imageUrl: _categoryImageAsset(
              category,
              matching.isNotEmpty ? matching.first.imageUrl : '',
            ),
            onTap: () => _selectCategory(category),
          );
        },
      ),
    );
  }

  double _categoryGridHeight(
    BuildContext context,
    double width,
    List<String> categories,
    List<Product> products,
  ) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return 126 + 34 * (scale - 1).clamp(0.0, 1.5);
  }

  Widget _sectionTitle(
    String title,
    IconData icon, {
    String? action,
    VoidCallback? onAction,
    Key? key,
  }) =>
      Padding(
        key: key,
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 5),
        child: Row(
          children: [
            Icon(icon, color: AppColors.darkGold, size: 22),
            const SizedBox(width: 7),
            Expanded(
              child: LocalizedText(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LocalizedText(action, style: const TextStyle(fontSize: 11)),
                    const Icon(Icons.chevron_right, size: 17),
                  ],
                ),
              ),
          ],
        ),
      );

  // Only explicitly beverage/ice categories use the ice artwork. Mixed
  // convenience categories do not imply cold storage for each product.
  bool _coldArtwork(Product product) => const {
        'cervejas',
        'energéticos',
        'refrigerantes & sucos',
        'água',
        'gelo',
      }.contains(product.category.trim().toLowerCase());

  BoxDecoration _productBackdrop(Product product) => BoxDecoration(
        color: AppTheme.darkBg,
        gradient: _coldArtwork(product) ? null : CustomerVisual.charcoal,
        image: !_coldArtwork(product)
            ? null
            : const DecorationImage(
                image: ResizeImage(
                  AssetImage('assets/images/home/commerce_backdrop.png'),
                  width: 600,
                ),
                fit: BoxFit.cover,
              ),
      );

  Widget _buildOfferCard(Product product) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      button: true,
      label: 'Ver oferta de ${product.name}',
      child: Material(
        color: AppTheme.darkBg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showProduct(product),
          child: Ink(
            decoration: _productBackdrop(product),
            child: Stack(
              children: [
                Positioned(
                  top: 6,
                  bottom: 6,
                  right: 2,
                  width: scale > 1.3 ? 64 : 76,
                  child: ExcludeSemantics(
                    child: ProductImage(
                      url: product.imageUrl,
                      darkPlaceholder: true,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: .92),
                          Colors.black.withValues(alpha: .55),
                          Colors.transparent,
                        ],
                        stops: const [0, .55, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: SizedBox(
                    width: scale > 1.3 ? 144 : 114,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LocalizedText(
                          'OFERTA DO DIA',
                          style: TextStyle(
                            color: AppTheme.primaryYellow,
                            fontSize: 10,
                            letterSpacing: .6,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        LocalizedText(
                          _formatMoney(product.price),
                          maxLines: 2,
                          style: const TextStyle(
                            color: AppTheme.primaryYellow,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(minHeight: 30),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            gradient: CustomerVisual.gold,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: LocalizedText(
                                  commerciallyAvailable(product)
                                      ? 'Aproveitar'
                                      : 'Indisponível',
                                  style: const TextStyle(
                                    color: AppTheme.darkBg,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppTheme.darkBg,
                                size: 19,
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
          ),
        ),
      ),
    );
  }

  Widget _productGrid(List<Product> products) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.crossAxisExtent > 1100
                  ? 5
                  : constraints.crossAxisExtent > 850
                      ? 4
                      : constraints.crossAxisExtent > 600
                          ? 3
                          : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              mainAxisExtent:
                  252 + 190 * (MediaQuery.textScalerOf(context).scale(1) - 1),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildProductCard(products[index]),
              childCount: products.length,
            ),
          ),
        ),
      );

  List<Widget> _buildCatalogContent(List<Product> source) {
    if (_categoryOverview) {
      return [SliverToBoxAdapter(child: _buildCategoryOverview(source))];
    }
    final products = visibleCatalogProducts(
      source,
      query: _searchQuery,
      category: _selectedCategory,
      onlyOffers: _filterOnlyOffers,
      onlyCombos: _filterOnlyCombos,
    );
    if (products.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 35, 24, 80),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 45,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 10),
                LocalizedText(
                  'Nenhum produto encontrado.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }
    final landing = _selectedCategory == 'Todos' &&
        !_filterOnlyOffers &&
        !_filterOnlyCombos &&
        _searchQuery.isEmpty;
    if (!landing) {
      final title = _filterOnlyOffers
          ? 'Ofertas do Dia'
          : _filterOnlyCombos
              ? 'Combos Festa'
              : _selectedCategory != 'Todos'
                  ? _selectedCategory
                  : 'Resultados da busca';
      return [
        SliverToBoxAdapter(
          child: _sectionTitle(
            title,
            Icons.storefront_outlined,
            action: 'Ver todos',
            onAction: () => setState(() {
              _selectedCategory = 'Todos';
              _filterOnlyOffers = false;
              _filterOnlyCombos = false;
              _searchQuery = '';
              _searchCtrl.clear();
            }),
          ),
        ),
        _productGrid(products),
      ];
    }
    final offers = visibleCatalogProducts(source, onlyOffers: true);
    final popular = products.where((p) => p.salesCount > 0).take(6).toList();
    return [
      if (offers.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _sectionTitle(
            'Promoções do dia',
            Icons.local_fire_department_rounded,
            action: 'Ver todas',
            onAction: _showOffers,
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 144 + 190 * (MediaQuery.textScalerOf(context).scale(1) - 1),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: offers.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, i) => SizedBox(
                width: ((MediaQuery.sizeOf(context).width - 40) / 2).clamp(
                  170.0,
                  310.0,
                ),
                child: _buildOfferCard(offers[i]),
              ),
            ),
          ),
        ),
      ],
      if (popular.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _sectionTitle(
            'Mais pedidos',
            Icons.workspace_premium_outlined,
            action: 'Ver todos',
            onAction: _showAllProducts,
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 170 + 190 * (MediaQuery.textScalerOf(context).scale(1) - 1),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: popular.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) => SizedBox(
                width: ((MediaQuery.sizeOf(context).width - 58) / 4).clamp(
                  106.0,
                  180.0,
                ),
                child: _buildProductCard(popular[i]),
              ),
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: _sectionTitle(
          'Todos os produtos',
          Icons.shopping_bag_outlined,
          key: _catalogAnchor,
        ),
      ),
      _productGrid(products),
    ];
  }

  Widget _buildSearch() {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      key: _searchAnchor,
      child: TextField(
        focusNode: _searchFocus,
        controller: _searchCtrl,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        },
        decoration: localizedDecoration(
          context,
          InputDecoration(
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: _categoryOverview
                ? 'Buscar categorias...'
                : 'Buscar bebidas e conveniência',
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.black,
              size: 25,
            ),
            suffixIcon: const Icon(Icons.tune_rounded, color: Colors.black, size: 21),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 17),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    if (_categoryOverview) {
      return const SizedBox.shrink();
    }
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final eligible = visibleCatalogProducts(_latestProducts.values.toList())
        .where((p) => !restrictedCatalogProduct(p))
        .toList();
    final shortcuts = [
      'Todos',
      ...<String>{
        ..._categories.where(
          (c) =>
              c != 'Todos' &&
              !_isRestrictedCategory(c) &&
              eligible.any((p) => p.category == c),
        ),
        ...eligible
            .map((p) => p.category)
            .where(
              (c) =>
                  c.trim().isNotEmpty &&
                  c != 'Todos' &&
                  !_isRestrictedCategory(c),
            ),
      },
      if (eligible.any((p) => p.isOffer)) 'Ofertas do Dia',
      if (eligible.any((p) => p.isCombo)) 'Combos Festa',
    ];
    return SizedBox(
      height: 86 + 26 * (scale - 1),
      child: ListView.separated(
        controller: _categoryScrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final category = shortcuts[index];
          final offer = category == 'Ofertas do Dia';
          final combo = category == 'Combos Festa';
          final selected = offer
              ? _filterOnlyOffers
              : combo
                  ? _filterOnlyCombos
                  : !_filterOnlyOffers &&
                      !_filterOnlyCombos &&
                      category == _selectedCategory;
          final iconData = category == 'Todos'
              ? Icons.grid_view_rounded
              : offer
                  ? Icons.local_offer_outlined
                  : combo
                      ? Icons.inventory_2_outlined
                      : _categoryIcon(category);
          return Semantics(
            button: true,
            selected: selected,
            child: InkWell(
              onTap: () {
                if (offer) {
                  _showOffers();
                } else if (combo) {
                  _showCombos();
                } else {
                  _selectCategory(category);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 68,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                decoration: BoxDecoration(
                  gradient: selected ? CustomerVisual.gold : null,
                  color: selected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppTheme.goldMid
                        : AppColors.borderLight,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10916A16),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      iconData,
                      size: 22,
                      color: selected
                          ? AppTheme.obsidianDark
                          : AppTheme.textDark,
                    ),
                    const SizedBox(height: 5),
                    LocalizedText(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected
                            ? AppTheme.obsidianDark
                            : AppTheme.textDark,
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

  Widget _buildProductCard(Product product) => CommerceProductCard(
        product: product,
        quantity: _cart[product.id]?.quantity ?? 0,
        isFavorite: _favorites.contains(product.id),
        onToggleFavorite: () => _toggleFavorite(product),
        onOpen: () => _showProduct(product),
        onAdd:
            commerciallyAvailable(product) ? () => _addToCart(product) : null,
        onRemove: () => _removeFromCart(product.id),
      );

  Widget _commerceRoute(Widget child) => CommerceRouteNavigation(
        address: _deliveryAddress?.addressText,
        cartCount: _totalItemsCount,
        onSearch: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          _openSearch();
        },
        onCart: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          _openCart();
        },
        onAddress: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          _selectDeliveryLocation();
        },
        onSelected: (index) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          if (index == 0) _selectCategory('Todos');
          if (index == 1) {
            setState(() {
              _categoryOverview = true;
              _searchVisible = false;
            });
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerHistoryScreen()),
            );
          }
          if (index == 3) _abrirMenuApple();
          if (index < 2 && _homeScrollCtrl.hasClients) {
            _homeScrollCtrl.jumpTo(0);
          }
        },
        child: child,
      );

  Widget _buildActiveOrderBanner() {
    final stream = _activeOrdersStream;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final active = snapshot.data ?? const [];
        if (active.isEmpty) return const SizedBox.shrink();
        final order = active.first;
        final docId = order['_documentId']?.toString();
        final friendlyId =
            order['id']?.toString().trim().isNotEmpty == true
                ? order['id'].toString().trim()
                : (docId ?? '');
        final status =
            order['status']?.toString().trim().isNotEmpty == true
                ? order['status'].toString().trim()
                : 'Em andamento';
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openTrackingFromOrderId(
                friendlyId,
                documentId: docId,
              ),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF19150E), Color(0xFF0E0E0E)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryYellow.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryYellow.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFE047),
                            Color(0xFFF5A623),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Color(0xFF111111),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active.length > 1
                                ? '${active.length} pedidos em andamento • $friendlyId'
                                : 'Pedido $friendlyId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.primaryYellow,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Status: $status • Toque para acompanhar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryYellow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const LocalizedText(
                        'Acompanhar',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() => CommerceBottomBar(
        selectedIndex: _categoryOverview ? 1 : 0,
        onSelected: (index) {
          switch (index) {
            case 0:
              _selectCategory('Todos');
              _homeScrollCtrl.jumpTo(0);
            case 1:
              setState(() {
                _categoryOverview = true;
                _searchVisible = false;
                _searchQuery = '';
                _searchCtrl.clear();
              });
              _homeScrollCtrl.jumpTo(0);
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CustomerHistoryScreen()),
              );
            case 3:
              _abrirMenuApple();
          }
        },
      );

  List<Widget> _catalogSlivers(AsyncSnapshot<List<Product>> snapshot) {
    if (snapshot.hasError) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const LocalizedText('Não foi possível carregar os produtos.'),
                TextButton(
                  onPressed: () => setState(() {
                    _productsStream = widget.products ??
                        FirebaseFirestore.instance
                            .collection('products')
                            .snapshots()
                            .map(
                              (s) => s.docs.map(Product.fromFirestore).toList(),
                            );
                  }),
                  child: const LocalizedText('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    if (!snapshot.hasData) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryYellow),
            ),
          ),
        ),
      ];
    }

    return _buildCatalogContent(
      snapshot.data!.where((p) => !restrictedCatalogProduct(p)).toList(),
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
            child: StreamBuilder<List<Product>>(
              key: const ValueKey('catalog-stream'),
              stream: _productsStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  _latestProducts = {for (final p in snapshot.data!) p.id: p};
                }
                return CustomScrollView(
                  controller: _homeScrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (_cartNotice != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: LocalizedText(
                            _cartNotice!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                    if (_persistenceError != null)
                      SliverToBoxAdapter(
                        child: MaterialBanner(
                          content: LocalizedText(_persistenceError!),
                          actions: [
                            TextButton(
                              onPressed:
                                  _workspaceReady ? _persistCart : _restoreCart,
                              child: const LocalizedText('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    SliverToBoxAdapter(child: _buildHeader()),
                    if (_activeOrdersStream != null)
                      SliverToBoxAdapter(child: _buildActiveOrderBanner()),
                    if (!_categoryOverview)
                      const SliverToBoxAdapter(child: ConvenienceCampaign()),
                    if (_categoryOverview)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(14, 2, 14, 4),
                          child: CustomerSectionTitle(
                            title: 'Categorias',
                            subtitle: 'Encontre o que precisa.',
                            icon: Icons.grid_view_rounded,
                            compact: true,
                          ),
                        ),
                      ),
                    if (_searchVisible)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 3, 14, 4),
                          child: _buildSearch(),
                        ),
                      ),
                    SliverToBoxAdapter(child: _buildCategories()),
                    ..._catalogSlivers(snapshot),
                    SliverToBoxAdapter(
                      child: SizedBox(height: _cart.isNotEmpty ? 100 : 28),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: 'chamae_cart_button',
              tooltip: 'Carrinho',
              elevation: 6,
              backgroundColor: AppTheme.primaryYellow,
              foregroundColor: Colors.black,
              onPressed: _openCart,
              icon: const Icon(Icons.shopping_bag_rounded),
              label: LocalizedText(
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
