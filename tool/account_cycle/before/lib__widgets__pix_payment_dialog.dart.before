import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pix_payment_presentation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/customer_orders.dart';

class PixPaymentDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> orderReference;
  final String orderId;
  final double totalBRL;
  final Future<void> Function() onPaid;
  const PixPaymentDialog({
    super.key,
    required this.orderReference,
    required this.orderId,
    required this.totalBRL,
    required this.onPaid,
  });
  @override
  State<PixPaymentDialog> createState() => PixPaymentDialogState();
}

class PixPaymentDialogState extends State<PixPaymentDialog> {
  Timer? _waitingTimer;
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
    _listen();
  }

  void _listen() {
    _subscription?.cancel();
    _waitingTimer?.cancel();
    _waitingTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && _qrCode == null && !_paymentApproved) {
        setState(() => _errorMessage =
            'O pagamento está demorando para carregar. Confira sua conexão e tente novamente.');
      }
    });
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
    final nextQrCodeBase64 = data['mercadoPagoQrCodeBase64']?.toString();
    final nextCreateStatus =
        data['mercadoPagoCreateStatus']?.toString() ?? 'creating';
    final nextPaymentStatus =
        data['paymentStatus']?.toString() ?? 'Aguardando confirmação';
    setState(() {
      _qrCode = nextQrCode;
      _qrCodeBase64 = nextQrCodeBase64;
      _createStatus = nextCreateStatus;
      _paymentStatus = nextPaymentStatus;
      _errorMessage = null;
      if (nextCreateStatus == 'error') {
        _errorMessage =
            'Não foi possível gerar o PIX. Confira o pedido antes de tentar novamente.';
      } else if (const ['cancelled', 'rejected', 'expired']
          .contains(data['mercadoPagoStatus'])) {
        _errorMessage =
            'Este PIX expirou ou não pôde ser concluído. Confira o pagamento do seu pedido.';
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
    _waitingTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PixPaymentPresentation(
        totalBRL: widget.totalBRL,
        qrBytes: _decodeQrCode(),
        qrCode: _qrCode,
        createStatus: _createStatus,
        paymentStatus: _paymentStatus,
        paymentApproved: _paymentApproved,
        errorMessage: _errorMessage,
        onRetry: () {
          setState(() => _errorMessage = null);
          _listen();
        },
      );
}
