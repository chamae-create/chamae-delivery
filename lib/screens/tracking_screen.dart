import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/customer_orders.dart';
import '../data/customer_workspace.dart';
import '../core/order_confirmation_policy.dart';
import 'home_screen.dart';
import 'tracking_view.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  final String? documentId;
  final bool showConfirmation;

  const TrackingScreen(
      {super.key,
      required this.orderId,
      this.documentId,
      this.showConfirmation = false});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final CustomerOrders _orders;
  late Stream<Map<String, dynamic>?> _stream;
  final _reconciling = <String>{};

  Stream<Map<String, dynamic>?> _watch() {
    final source = widget.documentId == null
        ? _orders.watchFriendlyId(widget.orderId)
        : _orders.watchDocumentId(widget.documentId!);
    return source.map((data) {
      final id = data?['_documentId'];
      if (id is String &&
          !_reconciling.contains(id) &&
          data != null &&
          orderIsConfirmed(data)) {
        _reconciling.add(id);
        unawaited(FirebaseCustomerWorkspace()
            .completeOrder(id)
            .catchError((Object _) => false)
            .whenComplete(() => _reconciling.remove(id)));
      }
      return data;
    });
  }

  @override
  void initState() {
    super.initState();
    _orders = CustomerOrders(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );
    _stream = _watch();
  }

  @override
  void didUpdateWidget(covariant TrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.documentId != widget.documentId) {
      _stream = _watch();
    }
  }

  @override
  Widget build(BuildContext context) => TrackingView(
        key: ValueKey(widget.documentId ?? widget.orderId),
        orderId: widget.orderId,
        showConfirmation: widget.showConfirmation,
        orderStream: _stream,
        onRetry: () => setState(() {
          _stream = _watch();
        }),
        onBack: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const DeliveryHomeScreen()));
          }
        },
      );
}
