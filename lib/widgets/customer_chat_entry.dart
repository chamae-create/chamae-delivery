import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../order_chat.dart';

class CustomerChatEntry extends StatefulWidget {
  final Map<String, dynamic> order;
  final Stream<Map<String, dynamic>>? metadata;
  const CustomerChatEntry({super.key, required this.order, this.metadata});
  @override
  State<CustomerChatEntry> createState() => _CustomerChatEntryState();
}

class _CustomerChatEntryState extends State<CustomerChatEntry> {
  Stream<Map<String, dynamic>>? _stream;
  void _watch() {
    _stream = widget.metadata;
    if (_stream == null && Firebase.apps.isNotEmpty) {
      _stream = chatSessionStream(
          FirebaseAuth.instance.idTokenChanges().map((u) => u?.uid),
          () => FirebaseAuth.instance.currentUser?.uid,
          <String, dynamic>{},
          () => FirebaseFirestore.instance
              .collection('orderChats')
              .doc(widget.order['_documentId'])
              .snapshots()
              .map((doc) => doc.data() ?? {}));
    }
  }

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(covariant CustomerChatEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order['_documentId'] != widget.order['_documentId'] ||
        oldWidget.metadata != widget.metadata) {
      _watch();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
      stream: _stream,
      builder: (context, snapshot) {
        final raw = snapshot.data?['unreadCustomer'];
        final unread = raw is num ? raw.toInt().clamp(0, 999) : 0;
        return OutlinedButton.icon(
            icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.chat_outlined)),
            label: Text(unread > 0
                ? 'Falar com a loja • $unread não lidas'
                : 'Falar com a loja'),
            onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    AlertDialog(
                        title: const Text('Falar com a loja'),
                        content: SizedBox(
                            width: 520,
                            child: SingleChildScrollView(
                                child: OrderChat(
                                    orderId:
                                        widget.order['_documentId'] as String,
                                    order: widget.order))),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Fechar'))
                        ])));
      });
}
