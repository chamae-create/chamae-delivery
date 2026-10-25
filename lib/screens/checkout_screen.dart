import '../widgets/customer_visual.dart';
import '../widgets/customer_feedback.dart';
import '../widgets/store_hours_builder.dart';
import '../widgets/product_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/models.dart';
import '../core/store_hours.dart';
import '../core/cart_validation.dart';
import '../core/catalog_commercial_policy.dart';
import '../widgets/pix_payment_dialog.dart';
import '../data/order_attempt.dart';
import '../core/theme.dart';
import 'tracking_screen.dart';
import 'address_destination_screen.dart';
import '../data/delivery_quote.dart';
import '../data/customer_workspace.dart';
import '../data/customer_verification.dart';

class _CreatedOrder {
  final DocumentReference<Map<String, dynamic>> reference;
  final String orderId;
  const _CreatedOrder({
    required this.reference,
    required this.orderId,
  });
}

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final VoidCallback onCartCleared;
  final ValueChanged<List<Map<String, dynamic>>>? onOrderConfirmed;
  final DeliveryAddress deliveryAddress;
  final String initialCurrency;
  final DeliveryQuoter? quoter;
  final AccountVerification? verification;
  final CustomerWorkspace? workspace;
  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.onCartCleared,
    required this.deliveryAddress,
    this.initialCurrency = 'BRL',
    this.quoter,
    this.verification,
    this.workspace,
    this.onOrderConfirmed,
  });
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cashPaidCtrl = TextEditingController();
  late DeliveryAddress _deliveryAddress;
  String _paymentMethod = 'PIX';
  String? _deliveryCountry;
  String _selectedCurrency = 'BRL';
  _CreatedOrder? _pendingOrder;
  Map<String, dynamic>? _pendingPayload;
  OrderAttempt? _orderAttempt;
  bool _splitPayment = false;
  final List<Map<String, dynamic>> _paymentParts = [];
  bool _isLoading = false;
  DeliveryQuote? _quote;
  bool _quoting = false;
  int _quoteGeneration = 0;
  String? _quoteError;
  bool _pendingLoaded = false;
  bool _verified = false;
  bool _editName = false, _editPhone = false;
  CustomerWorkspace? _workspace;
  AccountVerification get _verification =>
      widget.verification ?? ConfiguredAccountVerification();
  static const double _pygPerBrl = 1500.0;
  static const double _brlPerUsd = 5.0;
  // Cotações internas exclusivas para devolução de troco em Real.
  // Não são exibidas ao cliente.
  static const double _usdChangeToBrl = 4.70;
  static const double _pygChangePerBrl = 1600.0;
  @override
  void initState() {
    super.initState();
    _deliveryAddress = widget.deliveryAddress;
    _deliveryCountry = _supportedCountry(_deliveryAddress.countryCode);
    _selectedCurrency = 'BRL';
    _nameCtrl.text = UserSession.fullName;
    _phoneCtrl.text = UserSession.whatsapp;
    _refreshQuote();
    if (widget.verification != null) {
      _verification.isVerified().then((verified) {
        if (mounted) setState(() => _verified = verified);
      }).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cashPaidCtrl.dispose();
    super.dispose();
  }

  Future<void> _alterarEndereco() async {
    final address = await Navigator.push<DeliveryAddress>(
        context,
        MaterialPageRoute(
            builder: (_) => AddressDestinationScreen(
                onboarding: false, workspace: widget.workspace)));
    if (!mounted || address == null) return;
    setState(() {
      _deliveryAddress = address;
      _deliveryCountry = _supportedCountry(address.countryCode);
      _quote = null;
      _paymentParts.clear();
      _cashPaidCtrl.clear();
      if (_deliveryCountry != 'BR' && _paymentMethod == 'Maquininha') {
        _paymentMethod = 'PIX';
      }
    });
    await _refreshQuote();
  }

  Future<void> _refreshQuote() async {
    final generation = ++_quoteGeneration;
    final destination = _deliveryAddress;
    setState(() {
      _quoting = true;
      _quote = null;
      _quoteError = null;
    });
    try {
      final value =
          await (widget.quoter ?? FirebaseDeliveryQuoter()).quote(destination);
      if (mounted &&
          generation == _quoteGeneration &&
          identical(destination, _deliveryAddress)) {
        setState(() => _quote = value);
      }
    } on DeliveryQuoteException catch (error) {
      if (mounted &&
          generation == _quoteGeneration &&
          identical(destination, _deliveryAddress)) {
        setState(() {
          _quote = null;
          _quoteError = error.message;
        });
      }
    } catch (_) {
      if (mounted &&
          generation == _quoteGeneration &&
          identical(destination, _deliveryAddress)) {
        setState(() {
          _quote = null;
          _quoteError =
              'Não foi possível calcular a entrega agora. Tente novamente.';
        });
      }
    } finally {
      if (mounted && generation == _quoteGeneration) {
        setState(() => _quoting = false);
      }
    }
  }

  Future<void> _verifyAccount() async {
    try {
      final verified = await _verification.isVerified();
      if (mounted) setState(() => _verified = verified);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível atualizar a sessão. Entre novamente pela tela inicial.')));
      }
    }
  }

  double get _subtotal => widget.cartItems
      .fold(0.0, (accumulated, i) => accumulated + i.totalPrice);
  // Zero is only an internal placeholder; pending totals cannot be displayed
  // or submitted until the server supplies a quote.
  double get _deliveryFee => _quote?.fee ?? 0;
  double get _customerFee =>
      (_subtotal * .01 * 100).round() / 100; // Taxa de 1% do cliente
  double get _totalFinal => _subtotal + _deliveryFee + _customerFee;
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

  String _formatNumberBR(double value, {required int decimals}) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final integer = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      if (i > 0 && (integer.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(integer[i]);
    }
    if (decimals == 0) return buffer.toString();
    return '${buffer.toString()},${parts[1]}';
  }

  double _displayAmountForCurrency(double valueBRL, String currency) {
    switch (currency) {
      case 'PYG':
        return (valueBRL * _pygPerBrl).roundToDouble();
      case 'USD':
        return double.parse((valueBRL / _brlPerUsd).toStringAsFixed(2));
      default:
        return double.parse(valueBRL.toStringAsFixed(2));
    }
  }

  String _formatCurrency(double valueBRL) {
    final converted = _displayAmountForCurrency(valueBRL, _selectedCurrency);
    switch (_selectedCurrency) {
      case 'PYG':
        return 'G\$ ${_formatNumberBR(converted, decimals: 0)}';
      case 'USD':
        return 'US\$ ${_formatNumberBR(converted, decimals: 2)}';
      default:
        return 'R\$ ${_formatNumberBR(converted, decimals: 2)}';
    }
  }

  double? get _cashPaidAmount {
    final raw = _cashPaidCtrl.text.trim();
    if (raw.isEmpty) return null;
    var normalized = raw.replaceAll(RegExp(r'[^0-9,.]'), '');
    if (normalized.isEmpty) return null;
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.contains(',')) {
      normalized = normalized.replaceAll(',', '.');
    }
    final amount = double.tryParse(normalized);
    return amount != null && amount.isFinite && amount > 0 ? amount : null;
  }

  double? get _cashPaidBRL {
    final amount = _cashPaidAmount;
    if (amount == null) return null;
    switch (_selectedCurrency) {
      case 'PYG':
        return amount / _pygPerBrl;
      case 'USD':
        return amount * _brlPerUsd;
      default:
        return amount;
    }
  }

  bool get _cashAmountIsEnough {
    final amount = _cashPaidAmount;
    if (amount == null) return false;
    return amount >= _displayAmountForCurrency(_totalFinal, _selectedCurrency);
  }

  double get _cashChangeBRL {
    final amount = _cashPaidAmount;
    if (amount == null) return 0;
    final displayedTotal =
        _displayAmountForCurrency(_totalFinal, _selectedCurrency);
    switch (_selectedCurrency) {
      case 'USD':
        final surplusUSD = amount - displayedTotal;
        if (surplusUSD <= 0) return 0;
        return surplusUSD * _usdChangeToBrl;
      case 'PYG':
        final surplusPYG = amount - displayedTotal;
        if (surplusPYG <= 0) return 0;
        return surplusPYG / _pygChangePerBrl;
      default:
        final surplusBRL = amount - displayedTotal;
        return surplusBRL > 0 ? surplusBRL : 0;
    }
  }

  String get _cashCurrencyPrefix {
    switch (_selectedCurrency) {
      case 'PYG':
        return 'G\$';
      case 'USD':
        return 'US\$';
      default:
        return 'R\$';
    }
  }

  double _partToBRL(String currency, double amount) {
    switch (currency) {
      case 'PYG':
        return amount / _pygPerBrl;
      case 'USD':
        return amount * _brlPerUsd;
      default:
        return amount;
    }
  }

  double get _splitPaidBRL => _paymentParts.fold<double>(
        0,
        (accumulated, part) =>
            accumulated + ((part['amountBRL'] ?? 0) as num).toDouble(),
      );
  double get _splitRemainingBRL {
    final value = _totalFinal - _splitPaidBRL;
    return value > 0 ? value : 0;
  }

  double get _splitOverpaymentBRL {
    final value = _splitPaidBRL - _totalFinal;
    return value > 0 ? value : 0;
  }

  bool get _splitHasNonCashOverpayment {
    double accumulatedBRL = 0;
    for (final part in _paymentParts) {
      final partBRL = ((part['amountBRL'] ?? 0) as num).toDouble();
      final remainingBefore = _totalFinal - accumulatedBRL;
      if (partBRL > remainingBefore + 0.005 && part['method'] != 'Dinheiro') {
        return true;
      }
      accumulatedBRL += partBRL;
    }
    return false;
  }

  double get _splitCashChangeBRL {
    if (_splitOverpaymentBRL <= 0 || _paymentParts.isEmpty) return 0;
    double accumulatedBRL = 0;
    for (final part in _paymentParts) {
      final partBRL = ((part['amountBRL'] ?? 0) as num).toDouble();
      final remainingBefore = _totalFinal - accumulatedBRL;
      if (partBRL > remainingBefore + 0.005 && part['method'] == 'Dinheiro') {
        final currency = part['currency'].toString();
        final amount = ((part['amountCurrency'] ?? 0) as num).toDouble();
        if (currency == 'USD') {
          final neededUSD = remainingBefore / _brlPerUsd;
          final surplusUSD = amount - neededUSD;
          return surplusUSD > 0 ? surplusUSD * _usdChangeToBrl : 0;
        }
        if (currency == 'PYG') {
          final neededPYG = remainingBefore * _pygPerBrl;
          final surplusPYG = amount - neededPYG;
          return surplusPYG > 0 ? surplusPYG / _pygChangePerBrl : 0;
        }
        return partBRL - remainingBefore;
      }
      accumulatedBRL += partBRL;
    }
    return 0;
  }

  Future<void> _addPaymentPart() async {
    if (_paymentParts.length >= 3 || _splitRemainingBRL <= .005) return;
    String currency = 'BRL';
    double typedAmount = 0;
    final amountCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final typedBRL =
              typedAmount > 0 ? _partToBRL(currency, typedAmount) : 0.0;
          final remainingAfterBRL = (_splitRemainingBRL - typedBRL) > 0
              ? (_splitRemainingBRL - typedBRL)
              : 0.0;
          return AlertDialog(
            title: const Text('Adicionar pagamento em dinheiro'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pagamento dividido disponível somente em dinheiro.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Moeda'),
                    items: ['BRL', 'PYG', 'USD']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        currency = value;
                        typedAmount = 0;
                        amountCtrl.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Falta pagar: R\$ ${_formatNumberBR(_splitRemainingBRL, decimals: 2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    onChanged: (value) {
                      var raw = value.trim();
                      if (raw.contains(',') && raw.contains('.')) {
                        raw = raw.replaceAll('.', '').replaceAll(',', '.');
                      } else {
                        raw = raw.replaceAll(',', '.');
                      }
                      setDialogState(() {
                        typedAmount = double.tryParse(raw) ?? 0;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Valor desta parte em $currency',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Restará pagar',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        'R\$ ${_formatNumberBR(remainingAfterBRL, decimals: 2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  var raw = amountCtrl.text.trim();
                  if (raw.contains(',') && raw.contains('.')) {
                    raw = raw.replaceAll('.', '').replaceAll(',', '.');
                  } else {
                    raw = raw.replaceAll(',', '.');
                  }
                  final amount = double.tryParse(raw);
                  if (amount == null || !amount.isFinite || amount <= 0) return;
                  final amountBRL = _partToBRL(currency, amount);
                  Navigator.pop(dialogContext, {
                    'method': 'Dinheiro',
                    'currency': currency,
                    'amountCurrency': amount,
                    'amountBRL': amountBRL,
                    'cardType': null,
                    'status': 'Pendente na entrega',
                  });
                },
                child: const Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && mounted) {
      setState(() => _paymentParts.add(result));
    }
  }

  String _partLabel(Map<String, dynamic> part) {
    final method = part['method'].toString();
    final currency = part['currency'].toString();
    final amount = ((part['amountCurrency'] ?? 0) as num).toDouble();
    final prefix = currency == 'PYG'
        ? 'G\$'
        : currency == 'USD'
            ? 'US\$'
            : 'R\$';
    final cardType = part['cardType']?.toString();
    final methodLabel = method == 'Maquininha' && cardType != null
        ? 'Maquininha • ${cardType == 'Crédito' ? 'Crédito à vista' : 'Débito'}'
        : method;
    return '$methodLabel • $prefix ${_formatNumberBR(amount, decimals: currency == 'PYG' ? 0 : 2)}';
  }

  String get _splitPaymentStatus {
    if (!_splitPayment) {
      return _paymentMethod == 'PIX'
          ? 'Aguardando confirmação'
          : 'Pendente na entrega';
    }
    final hasPix = _paymentParts.any(
      (part) => part['method'] == 'PIX',
    );
    final hasDeliveryPayment = _paymentParts.any(
      (part) => part['method'] == 'Dinheiro' || part['method'] == 'Maquininha',
    );
    if (hasPix) return 'Aguardando confirmação';
    if (hasDeliveryPayment) return 'Pendente na entrega';
    return 'Pendente';
  }

  String get _paymentMethodForOrder {
    if (_splitPayment) {
      return 'Pagamento dividido';
    }
    if (_paymentMethod == 'Maquininha') {
      return 'Maquininha';
    }
    return _paymentMethod;
  }

  String? _supportedCountry(String? code) =>
      const ['BR', 'PY'].contains(code?.toUpperCase())
          ? code!.toUpperCase()
          : null;

  Future<void> _confirmCountry() async {
    final country = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Esta entrega é no Brasil ou Paraguai?'),
              content: const Text(
                  'Não conseguimos identificar o país deste endereço. Confira o ponto selecionado.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'BR'),
                    child: const Text('Brasil')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'PY'),
                    child: const Text('Paraguai')),
              ],
            ));
    if (!mounted || country == null) return;
    setState(() {
      _deliveryCountry = country;
      if (country != 'BR' && _paymentMethod == 'Maquininha') {
        _paymentMethod = 'PIX';
      }
    });
  }

  bool _validarDadosCliente() {
    if (!_deliveryAddress.confirmed || !_deliveryAddress.hasCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Confirme o destino da entrega antes de continuar.')));
      return false;
    }
    if (_quoting || _quote == null) return false;
    if (!isStoreOpen()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(storeHoursLabel())));
      return false;
    }
    if (_deliveryCountry != 'BR' && _paymentMethod == 'Maquininha') {
      return false;
    }
    if (_deliveryAddress.countryCode != null &&
        _supportedCountry(_deliveryAddress.countryCode) == null) {
      return false;
    }
    if (widget.cartItems.any((item) => isCommerciallyBlocked({
          'name': item.name,
          'category': item.category,
          'commercialBlocked': item.commercialBlocked,
        }))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Um produto da sacola está fora de venda. Remova-o para continuar.'),
      ));
      return false;
    }
    if (_deliveryCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Confirme o país do endereço para continuar.'),
      ));
      return false;
    }
    final name = _nameCtrl.text.trim();
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe seu nome para continuar.'),
        ),
      );
      return false;
    }
    if (phoneDigits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um WhatsApp válido com DDD.'),
        ),
      );
      return false;
    }
    return true;
  }

  Map<String, dynamic> _montarDadosPedido({
    required String orderId,
    required String customerUid,
    required bool aguardandoPix,
  }) {
    final double merchantFee = _subtotal * 0.03;
    final double merchantNet = _subtotal - merchantFee;
    final double platformFee = _customerFee + merchantFee;
    final List<Map<String, dynamic>> itemsList = widget.cartItems.map((item) {
      return {
        'id': item.id,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
      };
    }).toList();
    return {
      'id': orderId,
      'customerUid': customerUid,
      'customerFlowVersion': 2,
      'customerName': _nameCtrl.text.trim(),
      'customerPhone': _phoneCtrl.text.trim(),
      'address': _deliveryAddress.addressText,
      'deliveryAddress': {
        ..._deliveryAddress.toMap(),
        'country': _deliveryCountry
      },
      'deliveryLocation': _deliveryAddress.geoPoint,
      'itemsList': itemsList,
      'itemsTotal': _subtotal,
      'deliveryFee': _deliveryFee,
      if (_quote?.id != null) 'deliveryQuoteId': _quote!.id,
      'customerFee': _customerFee,
      'merchantFee': merchantFee,
      'merchantNet': merchantNet,
      'platformFee': platformFee,
      'totalBRL': _totalFinal,
      'displayCurrency': _selectedCurrency,
      'displayTotal': _convertFromBRL(_totalFinal),
      'exchangeRatePYGPerBRL': _pygPerBrl,
      'exchangeRateBRLPerUSD': _brlPerUsd,
      'exchangeRateSource': 'fixed_initial',
      'exchangeRateCapturedAt': FieldValue.serverTimestamp(),
      'paymentMethod': _paymentMethodForOrder,
      'paymentStatus':
          aguardandoPix ? 'Aguardando confirmação' : _splitPaymentStatus,
      'cardType': null,
      'cashCurrency': _paymentMethod == 'Dinheiro' ? _selectedCurrency : null,
      'cashTendered': _paymentMethod == 'Dinheiro' ? _cashPaidAmount : null,
      'cashTenderedBRL': _paymentMethod == 'Dinheiro' ? _cashPaidBRL : null,
      'changeBRL': _paymentMethod == 'Dinheiro' ? _cashChangeBRL : null,
      'cashChangeRateUSDToBRL': _splitPayment
          ? _usdChangeToBrl
          : _paymentMethod == 'Dinheiro' && _selectedCurrency == 'USD'
              ? _usdChangeToBrl
              : null,
      'cashChangeRatePYGPerBRL': _splitPayment
          ? _pygChangePerBrl
          : _paymentMethod == 'Dinheiro' && _selectedCurrency == 'PYG'
              ? _pygChangePerBrl
              : null,
      'splitPayment': _splitPayment,
      'paymentParts': _splitPayment ? _paymentParts : null,
      'splitPaidBRL': _splitPayment ? _splitPaidBRL : null,
      'splitRemainingBRL': _splitPayment ? _splitRemainingBRL : null,
      'splitChangeBRL': _splitPayment ? _splitCashChangeBRL : null,
      'status': aguardandoPix ? 'Aguardando pagamento' : 'Novo',
      'pixRequested': aguardandoPix,
      'pixRequestVersion': aguardandoPix ? 1 : null,
      'courierPaid': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<_CreatedOrder> _criarPedidoDocumento({
    required bool aguardandoPix,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      throw StateError(
        'Não foi possível autenticar. Reinicie o app e tente novamente.',
      );
    }
    final customerUid = user.uid;
    UserSession.fullName = _nameCtrl.text.trim();
    UserSession.whatsapp = _phoneCtrl.text.trim();
    if (_pendingOrder != null &&
        _pendingPayload?['customerUid'] != customerUid) {
      throw StateError('Sua sessão mudou. Reabra o checkout.');
    }
    _workspace ??= widget.workspace ?? FirebaseCustomerWorkspace();
    if (!_pendingLoaded) {
      final saved = (await _workspace!.read())['pending'];
      _pendingLoaded = true;
      if (saved is Map &&
          saved['payload'] is Map &&
          saved['documentId'] is String) {
        final payload = Map<String, dynamic>.from(saved['payload']);
        if (payload['customerUid'] != customerUid) {
          throw StateError('Sua sessão mudou.');
        }
        _pendingOrder = _CreatedOrder(
            reference: FirebaseFirestore.instance
                .collection('orders')
                .doc(saved['documentId']),
            orderId: payload['id']);
        _pendingPayload = {
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
          'exchangeRateCapturedAt': FieldValue.serverTimestamp()
        };
        _createAttempt(recovered: true);
      }
    }
    if (_pendingOrder == null) {
      if (!await _verification.isVerified()) {
        throw StateError(
            'Verifique sua conta antes da primeira compra. A navegação continua disponível.');
      }
      await _checkEligibility(_deliveryAddress.countryCode,
          widget.cartItems.map((i) => i.id).toList());
      await _workspace!.save({
        'contact': {'name': UserSession.fullName, 'phone': UserSession.whatsapp}
      });
      final previousFee = _quote?.fee;
      await _refreshQuote();
      if (_quote == null) {
        throw StateError(
            'Não foi possível calcular a entrega agora. Tente novamente.');
      }
      if (previousFee != null && previousFee != _quote!.fee) {
        throw StateError(
            'A taxa de entrega mudou. Confira o total e o pagamento antes de continuar.');
      }
      await _revalidateCart();
      final reference = FirebaseFirestore.instance.collection('orders').doc();
      final orderId = '#CH-${reference.id.substring(0, 8).toUpperCase()}';
      _pendingOrder = _CreatedOrder(reference: reference, orderId: orderId);
      _pendingPayload = _montarDadosPedido(
          orderId: orderId,
          customerUid: customerUid,
          aguardandoPix: aguardandoPix);
      _createAttempt();
    }
    // Persist only inside the guarded write. A retry that discovers an already
    // received order must not resurrect a proposal already reconciled away.
    await _orderAttempt!.submit();
    return _pendingOrder!;
  }

  void _notifyOrderConfirmed() {
    final consumed = (_pendingPayload?['itemsList'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (widget.onOrderConfirmed != null) {
      widget.onOrderConfirmed!(consumed);
    } else {
      widget.onCartCleared();
    }
  }

  void _createAttempt({bool recovered = false}) {
    _orderAttempt = OrderAttempt(
        previouslyAttempted: recovered,
        existsOnServer: () async {
          final snapshot = await _pendingOrder!.reference
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 15));
          if (snapshot.exists) {
            if (snapshot.metadata.hasPendingWrites) {
              throw StateError(
                  'A confirmação do envio ainda está pendente. Confira a conexão e tente novamente.');
            }
            final data = snapshot.data()!;
            if (data['customerUid'] != FirebaseAuth.instance.currentUser?.uid) {
              throw StateError('Pedido indisponível nesta sessão.');
            }
            _pendingPayload = data;
          }
          return snapshot.exists;
        },
        write: () async {
          if (!await _verification.isVerified()) {
            throw StateError('Verifique sua conta para concluir a compra.');
          }
          // A recovered proposal still has no order on the server. Revalidate
          // its original items and destination, never a later edited cart.
          final payload = _pendingPayload!;
          final rows = (payload['itemsList'] as List).cast<Map>();
          for (final row in rows) {
            final item = CartItem(
                id: row['id'] as String,
                name: row['name']?.toString() ?? 'Produto',
                price: (row['price'] as num).toDouble(),
                imageUrl: '',
                quantity: (row['quantity'] as num).toInt());
            final product = await FirebaseFirestore.instance
                .collection('products')
                .doc(item.id)
                .get(const GetOptions(source: Source.server))
                .timeout(const Duration(seconds: 12));
            final issue = cartItemIssue(item, product.data());
            if (issue != null) throw StateError(issue);
          }
          final destination = DeliveryAddress.fromMap(
              Map<String, dynamic>.from(payload['deliveryAddress']));
          await _checkEligibility(destination.countryCode,
              rows.map((row) => row['id'] as String).toList());
          final current = await (widget.quoter ?? FirebaseDeliveryQuoter())
              .quote(destination);
          if (current.fee != (payload['deliveryFee'] as num).toDouble()) {
            throw StateError(
                'A entrega mudou de valor. O pedido não foi enviado. Confira a cotação antes de continuar.');
          }
          if (current.id != null) payload['deliveryQuoteId'] = current.id;
          final persisted = Map<String, dynamic>.from(payload)
            ..remove('createdAt')
            ..remove('exchangeRateCapturedAt');
          await _workspace!.save({
            'pending': {
              'documentId': _pendingOrder!.reference.id,
              'payload': persisted
            }
          });
          await _pendingOrder!.reference
              .set(_pendingPayload!)
              .timeout(const Duration(seconds: 20));
        });
  }

  Future<void> _revisePending() async {
    if (_isLoading || _pendingOrder == null) return;
    setState(() => _isLoading = true);
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
              .httpsCallable('chamaeDescartarPropostaPedido')
              .call({'orderDocumentId': _pendingOrder!.reference.id}).timeout(
                  const Duration(seconds: 20));
      if (!mounted) return;
      if (result.data['cancelled'] == true) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Seu pedido já foi recebido. Use Verificar pedido ou Retomar PIX para acompanhá-lo.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível confirmar a revisão. O carrinho foi mantido. Confira a conexão e tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _revalidateCart() async {
    for (final item in widget.cartItems) {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(item.id)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      final issue = cartItemIssue(item, snapshot.data());
      if (issue != null) throw StateError(issue);
    }
  }

  Future<void> _checkEligibility(String? country, List<String> ids) async {
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
              .httpsCallable('chamaeConferirElegibilidadeCompra')
              .call({'countryCode': country, 'productIds': ids}).timeout(
                  const Duration(seconds: 15));
      if (result.data['eligible'] != true) {
        throw StateError(
            'Confira sua elegibilidade e os documentos para continuar.');
      }
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      if (details is Map && details['reason'] == 'AGE_RESTRICTED') {
        throw StateError(
            'Um produto da sacola não está disponível para sua faixa etária neste destino.');
      }
      throw StateError(
          'Não foi possível confirmar sua elegibilidade para a compra. Confira seus documentos no perfil e tente novamente.');
    }
  }

  Future<void> _iniciarPagamentoPixReal() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final created = await _criarPedidoDocumento(
        aguardandoPix: true,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (_pendingPayload?['pixRequested'] != true) {
        if (!mounted) return;
        if (await _workspace!.completeOrder(created.reference.id)) {
          _notifyOrderConfirmed();
        }
        if (!mounted) return;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => TrackingScreen(
                    showConfirmation: true,
                    orderId: created.orderId,
                    documentId: created.reference.id)));
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PixPaymentDialog(
          orderReference: created.reference,
          orderId: created.orderId,
          totalBRL:
              (_pendingPayload?['totalBRL'] as num?)?.toDouble() ?? _totalFinal,
          onPaid: () async {
            if (await _workspace!.completeOrder(created.reference.id)) {
              _notifyOrderConfirmed();
            }
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TrackingScreen(
                  showConfirmation: true,
                  orderId: created.orderId,
                  documentId: created.reference.id,
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError
              ? e.message.toString()
              : 'Não foi possível iniciar o PIX. Confira sua conexão e tente novamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _gravarPedidoFirestore() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final created = await _criarPedidoDocumento(
        aguardandoPix: false,
      );
      if (_pendingPayload?['pixRequested'] != true) {
        if (await _workspace!.completeOrder(created.reference.id)) {
          _notifyOrderConfirmed();
        }
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TrackingScreen(
            showConfirmation: true,
            orderId: created.orderId,
            documentId: created.reference.id,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError
              ? e.message.toString()
              : 'Não foi possível enviar o pedido. Confira sua conexão e tente novamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _summaryLine(String label, String value, {bool total = false}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: total ? 18 : 13,
                      fontWeight: total ? FontWeight.w900 : FontWeight.w500))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: total ? 24 : 13,
                      color: total ? AppColors.darkGold : AppColors.textMain,
                      fontWeight: FontWeight.w800))),
        ],
      );
  @override
  Widget build(BuildContext context) =>
      StoreHoursBuilder(builder: _buildScreen);

  Widget _buildScreen(BuildContext context, bool storeOpen, String hoursLabel) {
    if (_pendingOrder != null && !_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seu pedido')),
        body: SafeArea(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 64),
                          const SizedBox(height: 24),
                          const Text(
                              'Seu pedido foi iniciado. Confira a confirmação para continuar.',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          ElevatedButton(
                              onPressed:
                                  _pendingPayload?['pixRequested'] == true
                                      ? _iniciarPagamentoPixReal
                                      : _gravarPedidoFirestore,
                              child: Text(
                                  _pendingPayload?['pixRequested'] == true
                                      ? 'Retomar PIX'
                                      : 'Verificar pedido')),
                          TextButton(
                              onPressed: _revisePending,
                              child:
                                  const Text('Revisar sacola antes de enviar')),
                        ])))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar Pedido')),
      persistentFooterButtons: !storeOpen ? [Text(hoursLabel)] : null,
      body: _isLoading
          ? const Center(
              child: SingleChildScrollView(
                  child: CustomerFeedback(
                      title: 'Conferindo os detalhes do seu pedido',
                      message:
                          'Aguarde por aqui. Seu carrinho continua guardado.',
                      loading: true)))
          : SingleChildScrollView(
              padding: CustomerVisual.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CustomerSectionTitle(
                      title: 'Confira os detalhes',
                      subtitle:
                          'Seu endereço, seus itens e a forma de pagamento.',
                      icon: Icons.shopping_bag_outlined),
                  if (!storeOpen)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                            'O catálogo continua disponível. Os pedidos voltam às 08:00 (MS).')),
                  if (!_verified) ...[
                    const Text(
                        'Sua sessão precisa estar atualizada para comprar.'),
                    TextButton(
                        onPressed: _verifyAccount,
                        child: const Text('Atualizar sessão'))
                  ],
                  if (_quoting) const LinearProgressIndicator(),
                  if (_quoteError != null)
                    CustomerFeedback(
                        title: _quoteError!,
                        message:
                            'Confira o endereço e tente calcular a entrega novamente.',
                        icon: Icons.local_shipping_outlined,
                        onRetry: _refreshQuote),
                  const Text('Entrega',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0C916A16),
                            blurRadius: 14,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppTheme.primaryYellow,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_deliveryCountry != null)
                                Text(
                                    'Destino: ${_deliveryCountry == 'BR' ? 'Brasil' : 'Paraguai'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))
                              else if (_deliveryAddress.countryCode != null)
                                const Text('Destino fora da área atendida')
                              else
                                TextButton(
                                    onPressed: _confirmCountry,
                                    child: const Text(
                                        'Confirmar país da entrega')),
                              const SizedBox(height: 8),
                              const Text(
                                'Entregar em',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _deliveryAddress.addressText.isNotEmpty
                                    ? _deliveryAddress.addressText
                                    : 'Endereço selecionado',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (_deliveryAddress.complement
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _deliveryAddress.complement.trim(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _alterarEndereco,
                          child: const Text(
                            'Alterar',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Resumo',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0C916A16),
                            blurRadius: 14,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.cartItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = widget.cartItems[index];
                        return Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    width: 48,
                                    height: 64,
                                    child: ProductImage(url: item.imageUrl)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'R\$ ${item.price.toStringAsFixed(2).replaceAll('.', ',')} un',
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                          '${item.quantity}x • R\$ ${item.totalPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                                          style: const TextStyle(
                                              color: AppColors.darkGold,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16)),
                                    ])),
                              ]),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_nameCtrl.text.isNotEmpty && !_editName)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_nameCtrl.text),
                        subtitle: const Text('Nome para a entrega'),
                        trailing: TextButton(
                            onPressed: () => setState(() => _editName = true),
                            child: const Text('Editar nome')))
                  else
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Seu Nome *',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_phoneCtrl.text.isNotEmpty && !_editPhone)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_phoneCtrl.text),
                        subtitle: const Text('Contato para a entrega'),
                        trailing: TextButton(
                            onPressed: () => setState(() => _editPhone = true),
                            child: const Text('Editar contato')))
                  else
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+() -]')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Telefone / WhatsApp *',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (!_splitPayment && _paymentMethod == 'Dinheiro') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x0C916A16),
                              blurRadius: 14,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Moeda',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final currency in ['BRL', 'PYG', 'USD']) ...[
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedCurrency = currency;
                                        _cashPaidCtrl.clear();
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11),
                                      decoration: BoxDecoration(
                                        color: _selectedCurrency == currency
                                            ? AppTheme.primaryYellow
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _selectedCurrency == currency
                                              ? Colors.black87
                                              : Colors.grey.shade300,
                                          width: 1.4,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        currency,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (currency != 'USD') const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedCurrency == 'BRL'
                                ? 'Valores em Real'
                                : _selectedCurrency == 'PYG'
                                    ? 'Valores em Guarani'
                                    : 'Valores em Dólar',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (!_splitPayment && _paymentMethod == 'Dinheiro') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Troco',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Com quanto você vai pagar em $_selectedCurrency?',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _cashPaidCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9,.]')),
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              prefixText: '$_cashCurrencyPrefix ',
                              hintText: _selectedCurrency == 'PYG'
                                  ? 'Ex.: 100000'
                                  : 'Ex.: 100,00',
                              labelText: 'Valor que será entregue',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          if (_cashPaidAmount != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F6F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: !_cashAmountIsEnough
                                  ? const Text(
                                      'Valor insuficiente para este pedido.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red,
                                      ),
                                    )
                                  : Text(
                                      'Troco em Real: R\$ ${_formatNumberBR(_cashChangeBRL, decimals: 2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ],
                          const SizedBox(height: 7),
                          const Text(
                            'O troco será entregue sempre em Real (R\$).',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x0C916A16),
                            blurRadius: 14,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      children: [
                        _summaryLine('Subtotal', _formatCurrency(_subtotal)),
                        const SizedBox(height: 6),
                        _summaryLine(
                            'Taxa de Entrega',
                            _quote == null
                                ? 'Aguardando cotação'
                                : _formatCurrency(_deliveryFee)),
                        const SizedBox(height: 6),
                        _summaryLine('Taxa de serviço',
                            '+ ${_formatCurrency(_customerFee)}'),
                        const Divider(height: 16),
                        _summaryLine(
                            'TOTAL',
                            _quote == null
                                ? 'Aguardando entrega'
                                : _formatCurrency(_totalFinal),
                            total: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dividir pagamento',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900)),
                              Text('Somente dinheiro • até 3 partes',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.black54)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _splitPayment,
                          onChanged: (value) {
                            setState(() {
                              _splitPayment = value;
                              if (!value) _paymentParts.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_splitPayment) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _paymentParts.length; i++)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(_partLabel(_paymentParts[i]),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () =>
                                    setState(() => _paymentParts.removeAt(i)),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Restante: R\$ ${_formatNumberBR(_splitRemainingBRL, decimals: 2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _paymentParts.length < 3 &&
                                        _splitRemainingBRL > .005
                                    ? _addPaymentPart
                                    : null,
                                icon: const Icon(Icons.add),
                                label: const Text('Adicionar'),
                              ),
                            ],
                          ),
                          if (_splitOverpaymentBRL > 0 &&
                              !_splitHasNonCashOverpayment) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Troco em Real: R\$ ${_formatNumberBR(_splitCashChangeBRL, decimals: 2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!_splitPayment)
                    const CustomerSectionTitle(
                        title: 'Forma de pagamento',
                        icon: Icons.payments_outlined),
                  if (!_splitPayment)
                    Row(
                      children: [
                        for (final method in [
                          'PIX',
                          'Dinheiro',
                          if (_deliveryCountry == 'BR') 'Maquininha'
                        ]) ...[
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _paymentMethod = method;
                                  _selectedCurrency = method == 'Dinheiro'
                                      ? widget.initialCurrency
                                      : 'BRL';
                                  _cashPaidCtrl.clear();
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _paymentMethod == method
                                      ? AppColors.lightGold
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _paymentMethod == method
                                        ? AppColors.darkGold
                                        : AppColors.borderLight,
                                    width: 1.6,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      method == 'PIX'
                                          ? Icons.pix_rounded
                                          : method == 'Dinheiro'
                                              ? Icons.payments_outlined
                                              : Icons.credit_card_rounded,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      method == 'Maquininha'
                                          ? 'Cartão na entrega'
                                          : method,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (method != 'Maquininha') const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _quoting || _quote == null || !storeOpen
                        ? null
                        : () {
                            if (!_validarDadosCliente()) return;
                            if (_splitPayment) {
                              if (_paymentParts.length < 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Adicione pelo menos 2 partes do pagamento.')),
                                );
                                return;
                              }
                              if (_splitPaidBRL + 0.005 < _totalFinal) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Ainda existe valor restante no pagamento.')),
                                );
                                return;
                              }
                              if (_splitHasNonCashOverpayment) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'PIX e maquininha não podem gerar troco. Ajuste os valores.',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                            if (!_splitPayment &&
                                _paymentMethod == 'Dinheiro') {
                              final paidBRL = _cashPaidBRL;
                              if (paidBRL == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Informe com quanto você vai pagar.'),
                                  ),
                                );
                                return;
                              }
                              if (!_cashAmountIsEnough) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'O valor informado é menor que o total do pedido.',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                            if (_splitPayment) {
                              final hasInvalidPart = _paymentParts.any(
                                (part) => part['method'] != 'Dinheiro',
                              );
                              if (hasInvalidPart) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Pagamento dividido aceita somente dinheiro.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _gravarPedidoFirestore();
                            } else if (_paymentMethod == 'PIX') {
                              _iniciarPagamentoPixReal();
                            } else {
                              _gravarPedidoFirestore();
                            }
                          },
                    child: const Text('Finalizar pedido'),
                  ),
                ],
              ),
            ),
    );
  }
}
