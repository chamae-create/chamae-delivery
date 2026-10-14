import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/sponsor_video_banner.dart';
import 'address_map_screen.dart';
import 'checkout_screen.dart';
class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});
  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}
class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  bool _filterOnlyOffers = false;
  bool _filterOnlyCombos = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _categoryScrollCtrl = ScrollController();
  final Map<String, CartItem> _cart = {};
  DeliveryAddress? _deliveryAddress;
  String _selectedCurrency = 'BRL';

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
    'Tabacaria',
    'Snacks & Doces',
    'Gelo & Conveniência',
  ];
  @override
  void dispose() {
    _searchCtrl.dispose();
    _categoryScrollCtrl.dispose();
    super.dispose();
  }
  void _addToCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        if (_cart[product.id]!.quantity < product.stock) {
          _cart[product.id]!.quantity++;
        }
      } else {
        _cart[product.id] = CartItem(
          id: product.id,
          name: product.name,
          price: product.price,
          imageUrl: product.imageUrl,
          quantity: 1,
        );
      }
    });
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
  }
  int get _totalItemsCount {
    return _cart.values.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  }
  double get _subtotalPrice {
    return _cart.values.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
  }
  String _formatPrice(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
  Widget _buildProductImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.local_drink_outlined,
              size: 44,
              color: Color(0xFFD1D5DB),
            );
          },
        );
      } catch (_) {
        return const Icon(
          Icons.local_drink_outlined,
          size: 44,
          color: Color(0xFFD1D5DB),
        );
      }
    }
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.local_drink_outlined,
            size: 44,
            color: Color(0xFFD1D5DB),
          );
        },
      );
    }
    return const Icon(
      Icons.local_drink_outlined,
      size: 44,
      color: Color(0xFFD1D5DB),
    );
  }
  Future<void> _openCheckout() async {
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
          onCartCleared: () {
            setState(() {
              _cart.clear();
            });
          },
        ),
      ),
    );
  }
  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filterOnlyOffers = false;
      _filterOnlyCombos = false;
    });
  }
  void _showOffers() {
    setState(() {
      _filterOnlyOffers = !_filterOnlyOffers;
      _filterOnlyCombos = false;
      _selectedCategory = 'Todos';
    });
  }
  void _showCombos() {
    setState(() {
      _filterOnlyCombos = !_filterOnlyCombos;
      _filterOnlyOffers = false;
      _selectedCategory = 'Todos';
    });
  }
  Future<void> _selectDeliveryLocation() async {
    final result = await Navigator.push<AddressMapResult>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressMapScreen(),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _deliveryAddress = DeliveryAddress(
        latitude: result.latitude,
        longitude: result.longitude,
        addressText: result.addressText,
        complement: result.complement,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Local de entrega selecionado.'),
      ),
    );
  }
  void _abrirMenuApple() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Configurações & Privacidade',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                  ),
                  title: const Text(
                    'Política de Privacidade & Termos',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Excluir Minha Conta',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.redAccent,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text(
                            'Excluir Dados e Conta?',
                          ),
                          content: const Text(
                            'A exclusão definitiva da conta será conectada '
                            'ao sistema de usuários antes da publicação do app.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                              },
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                              },
                              child: const Text('Entendi'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
      color: const Color(0xFF0C0C0C),
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        14,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryYellow,
                      width: 2,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Icon(
                        Icons.local_bar_rounded,
                        color: AppTheme.primaryYellow,
                        size: 25,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chamaê',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'DELIVERY • FRONTEIRA',
                        style: TextStyle(
                          color: Color(0xFFB9B9B9),
                          fontSize: 10,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Escolher moeda',
                  initialValue: _selectedCurrency,
                  onSelected: (currency) {
                    setState(() {
                      _selectedCurrency = currency;
                    });
                  },
                  color: Colors.white,
                  position: PopupMenuPosition.under,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'BRL', child: Text('R\$  Real (BRL)')),
                    PopupMenuItem(value: 'PYG', child: Text('G\$  Guarani (PYG)')),
                    PopupMenuItem(value: 'USD', child: Text('US\$  Dólar (USD)')),
                  ],
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFF4B4B4B)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      r'$',
                      style: TextStyle(
                        color: AppTheme.primaryYellow,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Configurações',
                  onPressed: _abrirMenuApple,
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: AppTheme.primaryYellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDeliveryLocation,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171717),
                        borderRadius:
                            BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFF4B4B4B),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppTheme.primaryYellow,
                            size: 25,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Entregar em',
                                  style: TextStyle(
                                    color: Color(0xFFAAAAAA),
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _deliveryAddress == null
                                      ? 'Selecionar endereço'
                                      : (_deliveryAddress!.addressText.isNotEmpty
                                          ? _deliveryAddress!.addressText
                                          : 'Local selecionado'),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _deliveryAddress == null
                                        ? Colors.white
                                        : AppTheme.primaryYellow,
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                InkWell(
                  onTap: _selectDeliveryLocation,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    height: 58,
                    width: 108,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryYellow,
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 19,
                          color: Colors.black,
                        ),
                        SizedBox(height: 2),
                        Text(
                          _deliveryAddress == null
                              ? 'Calcular entrega'
                              : 'Local definido',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          height: 64,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryYellow
                : const Color(0xFF111111),
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
                color: selected
                    ? Colors.black
                    : AppTheme.primaryYellow,
                size: 25,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.black
                            : Colors.white,
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
                        color: selected
                            ? Colors.black87
                            : Colors.white60,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: selected
                    ? Colors.black
                    : Colors.white,
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
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1E4E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          setState(() {
            _searchQuery =
                value.trim().toLowerCase();
          });
        },
        decoration: const InputDecoration(
          hintText:
              'Buscar cervejas, whisky, energéticos...',
          hintStyle: TextStyle(
            color: Color(0xFF9CA3AF),
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
      height: 92,
      child: ListView.builder(
        controller: _categoryScrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected =
              category == _selectedCategory;
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
                width: 66,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 180,
                      ),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? const Color(0xFF111111)
                            : Colors.white,
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryYellow
                              : const Color(0xFFE5E7EB),
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        _categoryIcon(category),
                        size: 25,
                        color: selected
                            ? AppTheme.primaryYellow
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 9,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w600,
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
    final cartQty =
        _cart[product.id]?.quantity ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cartQty > 0
              ? AppTheme.primaryYellow
              : const Color(0xFFE5E7EB),
          width: cartQty > 0 ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 56,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFF7F7F7),
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
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE21B23),
                        borderRadius:
                            BorderRadius.only(
                          bottomRight:
                              Radius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'PROMOÇÃO',
                        style: TextStyle(
                          color: Colors.white,
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                  Text(
                    _formatMoney(product.price),
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (cartQty == 0)
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor:
                              AppTheme.primaryYellow,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              9,
                            ),
                          ),
                        ),
                        onPressed: () {
                          _addToCart(product);
                        },
                        icon: const Icon(
                          Icons
                              .add_shopping_cart_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Adicionar',
                          style: TextStyle(
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
                        borderRadius:
                            BorderRadius.circular(9),
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
                              fontWeight:
                                  FontWeight.w900,
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
    );
  }
  Widget _buildBottomNavigation() {
    return Container(
      height: 67,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _bottomItem(
              icon: Icons.home_rounded,
              label: 'Início',
              selected: true,
              onTap: () {},
            ),
            _bottomItem(
              icon: Icons.grid_view_rounded,
              label: 'Categorias',
              onTap: () {
                if (_categoryScrollCtrl.hasClients) {
                  _categoryScrollCtrl.animateTo(
                    0,
                    duration: const Duration(
                      milliseconds: 300,
                    ),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
            _bottomItem(
              icon: Icons.local_offer_outlined,
              label: 'Ofertas',
              onTap: _showOffers,
            ),
            _bottomItem(
              icon: Icons.shopping_cart_outlined,
              label: 'Carrinho',
              badge: _totalItemsCount,
              onTap: _openCheckout,
            ),
            _bottomItem(
              icon: Icons.person_outline_rounded,
              label: 'Perfil',
              onTap: _abrirMenuApple,
            ),
          ],
        ),
      ),
    );
  }
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: selected
                      ? AppTheme.primaryYellow
                      : Colors.white,
                ),
                if (badge > 0)
                  Positioned(
                    right: -11,
                    top: -8,
                    child: Container(
                      constraints:
                          const BoxConstraints(
                        minWidth: 19,
                        minHeight: 19,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 5,
                      ),
                      decoration:
                          const BoxDecoration(
                        color: Color(0xFFE21B23),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 99
                            ? '99+'
                            : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight:
                              FontWeight.w900,
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
                color: selected
                    ? AppTheme.primaryYellow
                    : Colors.white,
                fontSize: 9,
                fontWeight: selected
                    ? FontWeight.w900
                    : FontWeight.w500,
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
      backgroundColor: const Color(0xFFF4F5F7),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 460),
          child: Scaffold(
            backgroundColor:
                const Color(0xFFF4F5F7),
            body: CustomScrollView(
              physics:
                  const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(),
                ),
                const SliverToBoxAdapter(
                  child: SponsorVideoBanner(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      2,
                      16,
                      8,
                    ),
                    child: Row(
                      children: [
                        _buildFeatureButton(
                          icon:
                              Icons.local_fire_department_rounded,
                          title: 'Ofertas do Dia',
                          subtitle:
                              'Preços imperdíveis',
                          selected:
                              _filterOnlyOffers,
                          onTap: _showOffers,
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureButton(
                          icon:
                              Icons.local_bar_rounded,
                          title: 'Combos Festa',
                          subtitle:
                              'Monte seu combo',
                          selected:
                              _filterOnlyCombos,
                          onTap: _showCombos,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
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
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      3,
                      16,
                      10,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '🔥',
                          style:
                              TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _filterOnlyOffers
                                ? 'Ofertas do Dia'
                                : _filterOnlyCombos
                                    ? 'Combos Festa'
                                    : _selectedCategory !=
                                            'Todos'
                                        ? _selectedCategory
                                        : 'Produtos em Destaque',
                            style: const TextStyle(
                              color:
                                  Color(0xFF111111),
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                        if (_selectedCategory !=
                                'Todos' ||
                            _filterOnlyOffers ||
                            _filterOnlyCombos)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory =
                                    'Todos';
                                _filterOnlyOffers =
                                    false;
                                _filterOnlyCombos =
                                    false;
                              });
                            },
                            child: const Text(
                              'Ver todos',
                              style: TextStyle(
                                color:
                                    Color(0xFF111111),
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              EdgeInsets.all(30),
                          child: Center(
                            child: Text(
                              'Não foi possível carregar os produtos.',
                            ),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              EdgeInsets.all(40),
                          child: Center(
                            child:
                                CircularProgressIndicator(
                              color: AppTheme
                                  .primaryYellow,
                            ),
                          ),
                        ),
                      );
                    }
                    final products = snapshot
                        .data!.docs
                        .map(
                          (doc) =>
                              Product.fromFirestore(
                            doc,
                          ),
                        )
                        .where((product) {
                      if (!product.isActive ||
                          product.stock <= 0) {
                        return false;
                      }
                      if (_filterOnlyOffers &&
                          !product.isOffer) {
                        return false;
                      }
                      if (_filterOnlyCombos &&
                          !product.isCombo) {
                        return false;
                      }
                      if (_selectedCategory !=
                              'Todos' &&
                          product.category !=
                              _selectedCategory) {
                        return false;
                      }
                      if (_searchQuery.isNotEmpty &&
                          !product.name
                              .toLowerCase()
                              .contains(
                                _searchQuery,
                              )) {
                        return false;
                      }
                      return true;
                    }).toList();
                    products.sort(
                      (a, b) => b.salesCount
                          .compareTo(a.salesCount),
                    );
                    if (products.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              EdgeInsets.fromLTRB(
                            24,
                            35,
                            24,
                            120,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons
                                    .search_off_rounded,
                                size: 45,
                                color:
                                    Color(0xFFB5B5B5),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Nenhum produto encontrado.',
                                textAlign:
                                    TextAlign.center,
                                style: TextStyle(
                                  color:
                                      Color(0xFF777777),
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        24,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.68,
                        ),
                        delegate:
                            SliverChildBuilderDelegate(
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
            bottomNavigationBar:
                _buildBottomNavigation(),
            floatingActionButton:
                _cart.isNotEmpty
                    ? FloatingActionButton.extended(
                        heroTag:
                            'chamae_cart_button',
                        elevation: 6,
                        backgroundColor:
                            AppTheme.primaryYellow,
                        foregroundColor:
                            Colors.black,
                        onPressed: _openCheckout,
                        icon: const Icon(
                          Icons
                              .shopping_bag_rounded,
                        ),
                        label: Text(
                          '$_totalItemsCount • ${_formatMoney(_subtotalPrice)}',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      )
                    : null,
          ),
        ),
      ),
    );
  }
}
