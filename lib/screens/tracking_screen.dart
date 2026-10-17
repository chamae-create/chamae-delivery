import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/customer_orders.dart';
import 'home_screen.dart';
import 'tracking_view.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  final String? documentId;

  const TrackingScreen({super.key, required this.orderId, this.documentId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final CustomerOrders _orders;
  late Stream<Map<String, dynamic>?> _stream;

  @override
  void initState() {
    super.initState();
    _orders = CustomerOrders(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );
    _stream = widget.documentId == null
        ? _orders.watchFriendlyId(widget.orderId)
        : _orders.watchDocumentId(widget.documentId!);
  }

  @override
  void didUpdateWidget(covariant TrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId || oldWidget.documentId != widget.documentId) {
      _stream = widget.documentId == null
        ? _orders.watchFriendlyId(widget.orderId)
        : _orders.watchDocumentId(widget.documentId!);
    }
  }

  @override
  Widget build(BuildContext context) => TrackingView(
    key: ValueKey(widget.documentId ?? widget.orderId),
    orderId: widget.orderId,
    orderStream: _stream,
    onBack: () => Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DeliveryHomeScreen()),
      (_) => false,
    ),
  );
}
