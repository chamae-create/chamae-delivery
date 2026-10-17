import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/models.dart';
import '../data/customer_orders.dart';

import '../core/theme.dart';

import 'tracking_screen.dart';

import 'address_map_screen.dart';

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

  final DeliveryAddress deliveryAddress;

  final String initialCurrency;



  const CheckoutScreen({

    super.key,

    required this.cartItems,

    required this.onCartCleared,

    required this.deliveryAddress,

    this.initialCurrency = 'BRL',

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

  String _cardType = 'Débito';

  bool _splitPayment = false;

  final List<Map<String, dynamic>> _paymentParts = [];

  bool _isLoading = false;



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

    _selectedCurrency = 'BRL';

  }



  @override

  void dispose() {

    _nameCtrl.dispose();

    _phoneCtrl.dispose();

    _cashPaidCtrl.dispose();

    super.dispose();

  }



  Future<void> _alterarEndereco() async {

    final result = await Navigator.push<AddressMapResult>(

      context,

      MaterialPageRoute(

        builder: (context) => const AddressMapScreen(),

      ),

    );



    if (!mounted || result == null) return;



    setState(() {

      _deliveryCountry = null;
      _deliveryAddress = DeliveryAddress(

        latitude: result.latitude,

        longitude: result.longitude,

        addressText: result.addressText,

        complement: result.complement,
      );

    });

  }

  double get _subtotal => widget.cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get _deliveryFee => 10.00;

  double get _customerFee => _subtotal * 0.01; // Taxa de 1% do cliente

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

    return double.tryParse(normalized);

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

        (sum, part) => sum + ((part['amountBRL'] ?? 0) as num).toDouble(),

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



      if (partBRL > remainingBefore + 0.005 &&

          part['method'] != 'Dinheiro') {

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



      if (partBRL > remainingBefore + 0.005 &&

          part['method'] == 'Dinheiro') {

        final currency = part['currency'].toString();

        final amount =

            ((part['amountCurrency'] ?? 0) as num).toDouble();



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
    if (_paymentParts.length >= 3) return;

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
                  if (amount == null || amount <= 0) return;

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

    final prefix =

        currency == 'PYG' ? 'G\$' : currency == 'USD' ? 'US\$' : 'R\$';

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

      (part) =>

          part['method'] == 'Dinheiro' ||

          part['method'] == 'Maquininha',

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

      return 'Maquininha - $_cardType à vista';

    }

    return _paymentMethod;

  }



  bool _validarDadosCliente() {
    if (_deliveryCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione Brasil ou Paraguai para a entrega.'),
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
      'customerName': _nameCtrl.text.trim(),
      'customerPhone': _phoneCtrl.text.trim(),
      'address': _deliveryAddress.addressText,
      'deliveryAddress': {..._deliveryAddress.toMap(), 'country': _deliveryCountry},
      'deliveryLocation': _deliveryAddress.geoPoint,
      'itemsList': itemsList,
      'itemsTotal': _subtotal,
      'deliveryFee': _deliveryFee,
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
      'cardType': _paymentMethod == 'Maquininha' ? _cardType : null,
      'cashCurrency':
          _paymentMethod == 'Dinheiro' ? _selectedCurrency : null,
      'cashTendered':
          _paymentMethod == 'Dinheiro' ? _cashPaidAmount : null,
      'cashTenderedBRL':
          _paymentMethod == 'Dinheiro' ? _cashPaidBRL : null,
      'changeBRL':
          _paymentMethod == 'Dinheiro' ? _cashChangeBRL : null,
      'cashChangeRateUSDToBRL':
          _splitPayment
              ? _usdChangeToBrl
              : _paymentMethod == 'Dinheiro' && _selectedCurrency == 'USD'
                  ? _usdChangeToBrl
                  : null,
      'cashChangeRatePYGPerBRL':
          _splitPayment
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

    final now = DateTime.now();
    final String orderId =
        '#CH-${now.millisecondsSinceEpoch.toString().substring(8)}';

    final reference =
        FirebaseFirestore.instance.collection('orders').doc();

    await reference.set(
      _montarDadosPedido(
        orderId: orderId,
        customerUid: customerUid,
        aguardandoPix: aguardandoPix,
      ),
    );

    return _CreatedOrder(
      reference: reference,
      orderId: orderId,
    );
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

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _PixPaymentDialog(
          orderReference: created.reference,
          orderId: created.orderId,
          totalBRL: _totalFinal,
          onPaid: () async {
            widget.onCartCleared();

            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TrackingScreen(
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
          content: Text('Não foi possível iniciar o PIX: $e'),
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

      widget.onCartCleared();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TrackingScreen(
            orderId: created.orderId,
            documentId: created.reference.id,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar pedido: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Finalizar Pedido')),

      body: _isLoading

          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryYellow))

          : SingleChildScrollView(

              padding: const EdgeInsets.all(16),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  Container(

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: Colors.grey.shade300),

                    ),

                    child: ListView.separated(

                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      itemCount: widget.cartItems.length,

                      separatorBuilder: (_, __) => const Divider(height: 1),

                      itemBuilder: (context, index) {

                        final item = widget.cartItems[index];

                        return ListTile(

                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),

                          subtitle: Text('R\$ ${item.price.toStringAsFixed(2)} un', style: const TextStyle(fontSize: 11, color: Colors.grey)),

                          trailing: Text('${item.quantity}x • R\$ ${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),

                        );

                      },

                    ),

                  ),

                  const SizedBox(height: 14),

                  TextField(

                    controller: _nameCtrl,

                    textCapitalization: TextCapitalization.words,

                    textInputAction: TextInputAction.next,

                    decoration: InputDecoration(

                      labelText: 'Seu Nome *',

                      prefixIcon: const Icon(Icons.person_outline_rounded),

                      filled: true,

                      fillColor: Colors.white,

                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

                    ),

                  ),

                  const SizedBox(height: 8),

                  TextField(

                    controller: _phoneCtrl,

                    keyboardType: TextInputType.phone,

                    textInputAction: TextInputAction.done,

                    inputFormatters: [

                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+() -]')),

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

                  Container(

                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: Colors.grey.shade300),

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

                              DropdownButtonFormField<String>(
                                key: ValueKey(_deliveryAddress),
                                initialValue: _deliveryCountry,
                                decoration: const InputDecoration(labelText: 'País da entrega'),
                                items: const [
                                  DropdownMenuItem(value: 'BR', child: Text('BRASIL')),
                                  DropdownMenuItem(value: 'PY', child: Text('PARAGUAI')),
                                ],
                                onChanged: (value) => setState(() => _deliveryCountry = value),
                              ),
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

                              if (_deliveryAddress.complement.trim().isNotEmpty) ...[

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

                  if (!_splitPayment && _paymentMethod == 'Dinheiro') ...[

                  Container(

                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: Colors.grey.shade300),

                    ),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        const Text(

                          'Moeda',

                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),

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

                                    padding: const EdgeInsets.symmetric(vertical: 11),

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

                          style: const TextStyle(fontSize: 11, color: Colors.black54),

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

                        borderRadius: BorderRadius.circular(14),

                        border: Border.all(color: const Color(0xFFE0E0E0)),

                      ),

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          const Text(

                            'Troco',

                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),

                          ),

                          const SizedBox(height: 4),

                          Text(

                            'Com quanto você vai pagar em $_selectedCurrency?',

                            style: const TextStyle(fontSize: 11, color: Colors.black54),

                          ),

                          const SizedBox(height: 10),

                          TextField(

                            controller: _cashPaidCtrl,

                            keyboardType: const TextInputType.numberWithOptions(decimal: true),

                            inputFormatters: [

                              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),

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

                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

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

                      borderRadius: BorderRadius.circular(14),

                      border: Border.all(color: Colors.grey.shade300),

                    ),

                    child: Column(

                      children: [

                        Row(

                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [

                            const Text('Subtotal', style: TextStyle(fontSize: 13)),

                            Text(_formatCurrency(_subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),

                          ],

                        ),

                        const SizedBox(height: 6),

                        Row(

                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [

                            const Text('Taxa de Entrega', style: TextStyle(fontSize: 13)),

                            Text(_formatCurrency(_deliveryFee), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),

                          ],

                        ),

                        const SizedBox(height: 6),

                        Row(

                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [

                            const Text('Taxa Plataforma (1%)', style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600)),

                            Text('+ ${_formatCurrency(_customerFee)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),

                          ],

                        ),

                        const Divider(height: 16),

                        Row(

                          mainAxisAlignment: MainAxisAlignment.spaceBetween,

                          children: [

                            const Text('TOTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),

                            Text(_formatCurrency(_totalFinal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),

                          ],

                        ),

                      ],

                    ),

                  ),

                  const SizedBox(height: 14),

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

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

                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),

                              Text('Somente dinheiro • até 3 partes',

                                  style: TextStyle(fontSize: 10, color: Colors.black54)),

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

                        borderRadius: BorderRadius.circular(14),

                        border: Border.all(color: const Color(0xFFE0E0E0)),

                      ),

                      child: Column(

                        children: [

                          for (var i = 0; i < _paymentParts.length; i++)

                            ListTile(

                              dense: true,

                              contentPadding: EdgeInsets.zero,

                              title: Text(_partLabel(_paymentParts[i]),

                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),

                              trailing: IconButton(

                                icon: const Icon(Icons.close, size: 18),

                                onPressed: () => setState(() => _paymentParts.removeAt(i)),

                              ),

                            ),

                          Row(

                            children: [

                              Expanded(

                                child: Text(

                                  'Restante: R\$ ${_formatNumberBR(_splitRemainingBRL, decimals: 2)}',

                                  style: const TextStyle(fontWeight: FontWeight.w900),

                                ),

                              ),

                              TextButton.icon(

                                onPressed: _paymentParts.length < 3 ? _addPaymentPart : null,

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

                  Row(

                    children: [

                      for (final method in ['PIX', 'Dinheiro', 'Maquininha']) ...[

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

                              padding: const EdgeInsets.symmetric(vertical: 12),

                              decoration: BoxDecoration(

                                color: _paymentMethod == method

                                    ? AppTheme.primaryYellow

                                    : Colors.white,

                                borderRadius: BorderRadius.circular(10),

                                border: Border.all(

                                  color: _paymentMethod == method

                                      ? Colors.black87

                                      : Colors.grey.shade300,

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

                                    method,

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

                  if (!_splitPayment && _paymentMethod == 'Maquininha') ...[

                    const SizedBox(height: 10),

                    Container(

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(

                        color: Colors.white,

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(color: Colors.grey.shade300),

                      ),

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          const Text(

                            'Pagamento na entrega',

                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),

                          ),

                          const SizedBox(height: 4),

                          const Text(

                            'Aceitamos somente cartões emitidos no Brasil.',

                            style: TextStyle(

                              fontSize: 11,

                              color: Colors.black54,

                              fontWeight: FontWeight.w600,

                            ),

                          ),

                          const SizedBox(height: 8),

                          Row(

                            children: [

                              for (final type in ['Débito', 'Crédito']) ...[

                                Expanded(

                                  child: ChoiceChip(

                                    label: Text(type == 'Crédito' ? 'Crédito à vista' : 'Débito'),

                                    selected: _cardType == type,

                                    onSelected: (_) => setState(() => _cardType = type),

                                  ),

                                ),

                                if (type == 'Débito') const SizedBox(width: 8),

                              ],

                            ],

                          ),

                          const SizedBox(height: 6),

                          const Text(

                            'A maquininha será levada pelo entregador. Crédito sem parcelamento.',

                            style: TextStyle(fontSize: 11, color: Colors.black54),

                          ),

                        ],

                      ),

                    ),

                  ],

                  const SizedBox(height: 20),

                  ElevatedButton(

                    style: ElevatedButton.styleFrom(

                      backgroundColor: AppTheme.primaryYellow,

                      foregroundColor: Colors.black,

                      padding: const EdgeInsets.symmetric(vertical: 16),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                    ),

                    onPressed: () {

                      if (!_validarDadosCliente()) return;



                      if (_splitPayment) {

                        if (_paymentParts.length < 2) {

                          ScaffoldMessenger.of(context).showSnackBar(

                            const SnackBar(content: Text('Adicione pelo menos 2 partes do pagamento.')),

                          );

                          return;

                        }

                        if (_splitPaidBRL + 0.005 < _totalFinal) {

                          ScaffoldMessenger.of(context).showSnackBar(

                            const SnackBar(content: Text('Ainda existe valor restante no pagamento.')),

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





                      if (!_splitPayment && _paymentMethod == 'Dinheiro') {

                        final paidBRL = _cashPaidBRL;

                        if (paidBRL == null) {

                          ScaffoldMessenger.of(context).showSnackBar(

                            const SnackBar(

                              content: Text('Informe com quanto você vai pagar.'),

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

                    child: Text(

                      _splitPayment

                          ? 'Confirmar pagamento dividido ➔'

                          : _paymentMethod == 'PIX'

                              ? 'Pagar com PIX (${_formatCurrency(_totalFinal)}) ➔'

                              : _paymentMethod == 'Maquininha'

                                  ? 'Confirmar • $_cardType na entrega ➔'

                                  : 'Confirmar Pedido ➔',

                      style: const TextStyle(

                        fontWeight: FontWeight.w900,

                        fontSize: 14,

                      ),

                    ),

                  ),

                ],

              ),

            ),

    );

  }

}

class _PixPaymentDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> orderReference;
  final String orderId;
  final double totalBRL;
  final Future<void> Function() onPaid;

  const _PixPaymentDialog({
    required this.orderReference,
    required this.orderId,
    required this.totalBRL,
    required this.onPaid,
  });

  @override
  State<_PixPaymentDialog> createState() => _PixPaymentDialogState();
}

class _PixPaymentDialogState extends State<_PixPaymentDialog> {
  StreamSubscription<Map<String, dynamic>?>? _subscription;

  String? _qrCode;
  String? _qrCodeBase64;
  String _createStatus = 'creating';
  String _paymentStatus = 'Aguardando confirmação';
  bool _paymentApproved = false;
  bool _finishing = false;
  String? _authorizedCustomerUid;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _subscription = CustomerOrders(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    ).watchDocumentId(widget.orderReference.id).listen(
      _handleSnapshot,
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _errorMessage =
              'Não foi possível acompanhar o pagamento. Tente novamente.';
        });
      },
    );
  }

  void _handleSnapshot(
    Map<String, dynamic>? data,
  ) {
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _authorizedCustomerUid = null;
        _qrCode = null;
        _qrCodeBase64 = null;
        _createStatus = 'creating';
        _paymentStatus = 'Aguardando confirmação';
        _paymentApproved = false;
      });
      return;
    }



    _authorizedCustomerUid = data['customerUid'] as String;
    final nextQrCode = data['mercadoPagoQrCode']?.toString();
    final nextQrCodeBase64 =
        data['mercadoPagoQrCodeBase64']?.toString();
    final nextCreateStatus =
        data['mercadoPagoCreateStatus']?.toString() ?? 'creating';
    final nextPaymentStatus =
        data['paymentStatus']?.toString() ?? 'Aguardando confirmação';

    setState(() {
      _qrCode = nextQrCode;
      _qrCodeBase64 = nextQrCodeBase64;
      _createStatus = nextCreateStatus;
      _paymentStatus = nextPaymentStatus;

      if (nextCreateStatus == 'error') {
        _errorMessage =
            'Não foi possível gerar o PIX. Feche e tente novamente.';
      }
    });

    if (nextPaymentStatus == 'Pago' && !_finishing) {
      _finalizarPagamento();
    }
  }

  Future<void> _finalizarPagamento() async {
    if (_finishing) return;
    final customerUid = _authorizedCustomerUid;
    if (customerUid == null) return;

    _finishing = true;

    if (mounted) {
      setState(() {
        _paymentApproved = true;
        _errorMessage = null;
      });
    }

    await Future.delayed(
      const Duration(milliseconds: 1200),
    );

    if (!mounted) return;

    if (_authorizedCustomerUid != customerUid ||
        FirebaseAuth.instance.currentUser?.uid != customerUid) {
      return;
    }

    Navigator.of(context).pop();

    await widget.onPaid();
  }

  Uint8List? _decodeQrCode() {
    final value = _qrCodeBase64;

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      final normalized = value.replaceAll(
        RegExp(r'\s'),
        '',
      );

      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrBytes = _decodeQrCode();

    final waitingForQr =
        !_paymentApproved &&
        _errorMessage == null &&
        (_qrCode == null || _qrCode!.isEmpty);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _paymentApproved
                    ? Icons.check_circle_rounded
                    : Icons.pix_rounded,
                color:
                    _paymentApproved ? Colors.green : Colors.teal,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                _paymentApproved
                    ? 'PIX Aprovado!'
                    : 'Pagamento via PIX',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _paymentApproved
                ? 'Recebimento confirmado pelo Mercado Pago'
                : waitingForQr
                    ? 'Gerando PIX seguro...'
                    : 'Confirmação automática ativa',
            style: TextStyle(
              fontSize: 12,
              color: _paymentApproved
                  ? Colors.green.shade800
                  : Colors.grey,
              fontWeight:
                  _paymentApproved ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_paymentApproved) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.green,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Pagamento Confirmado!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Abrindo acompanhamento do pedido...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
              ] else if (waitingForQr) ...[
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.primaryYellow,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Preparando seu PIX...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else ...[
                if (qrBytes != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Image.memory(
                      qrBytes,
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    width: 180,
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 80,
                      color: Colors.black54,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Total: R\$ ${_formatMoney(widget.totalBRL)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2124),
                  ),
                ),
                const SizedBox(height: 10),
                if (_qrCode != null && _qrCode!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _qrCode!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 17,
                          ),
                          tooltip: 'Copiar PIX Copia e Cola',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: _qrCode!,
                              ),
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Código PIX Copia e Cola copiado!',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.shade300,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Aguardando confirmação do pagamento...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: $_paymentStatus',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!_paymentApproved)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              _createStatus == 'error' ? 'Fechar' : 'Fechar',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  String _formatMoney(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
}

