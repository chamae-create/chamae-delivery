import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const orderChatReplies = [
  'Seu pedido já está em separação.',
  'Seu pedido saiu para entrega.',
  'O motoboy está a caminho.',
  'Pode confirmar o complemento do endereço?',
  'Estamos aguardando a confirmação do pagamento.',
];

bool chatIsClosed(Map<String, dynamic> order, DateTime now) {
  if (order['status'] == 'Cancelado') return true;
  if (order['status'] != 'Concluído') return false;
  final raw = order['completedAt'];
  final completed = raw is Timestamp ? raw.toDate() : raw is DateTime ? raw : null;
  return completed == null || !now.isBefore(completed.add(const Duration(hours: 24)));
}

abstract class OrderChatGateway {
  Stream<List<Map<String, dynamic>>> watch(String orderId);
  Future<void> send(String orderId, String text, String requestId);
  Future<void> read(String orderId);
  Stream<Map<String, dynamic>>? orderChanges(String orderId) => null;
}

Stream<T> chatSessionStream<T>(Stream<String?> sessions, String? Function() current,
    T empty, Stream<T> Function() open) {
  // A conversation belongs to the account that opened it. Never reopen its
  // fixed Firestore path for another account, even from the SDK's local cache.
  final originalUid = current();
  late StreamController<T> controller;
  StreamSubscription<String?>? session;
  StreamSubscription<T>? data;
  var generation = 0;
  controller = StreamController<T>(onListen: () {
    session = sessions.listen((uid) {
      final version = ++generation;
      data?.cancel();
      controller.add(empty);
      if (uid == null || uid != current() || uid != originalUid) return;
      data = open().listen((value) {
        if (generation == version && uid == current()) controller.add(value);
      }, onError: (Object error, StackTrace stack) {
        if (generation == version) {
          controller.add(empty);
          controller.addError(error, stack);
        }
      });
    }, onError: (Object error, StackTrace stack) {
      generation++;
      data?.cancel();
      controller.add(empty);
      controller.addError(error, stack);
    });
  }, onCancel: () async {
    generation++;
    await session?.cancel(); await data?.cancel();
  });
  return controller.stream.where((value) =>
    identical(value, empty) || current() == originalUid);
}

bool chatRolesPermitRead(Object? rawRoles, {required bool anonymous}) {
  final roles = rawRoles is List ? rawRoles.whereType<String>().toSet() : <String>{};
  final operations = !anonymous && roles.any({'operations_admin', 'superadmin'}.contains);
  return operations || !roles.any({'finance', 'catalog_admin'}.contains);
}

class FirebaseOrderChat implements OrderChatGateway {
  FirebaseOrderChat({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : db = firestore ?? FirebaseFirestore.instance,
      functions = functions ?? FirebaseFunctions.instanceFor(region: 'southamerica-east1');
  final FirebaseFirestore db;
  final FirebaseFunctions functions;
  Stream<T> _authorized<T>(Stream<T> Function() read) async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdTokenResult();
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
    if (!chatRolesPermitRead(token.claims?['roles'], anonymous: user.isAnonymous)) {
      throw StateError('Perfil sem acesso à conversa.');
    }
    yield* read();
  }
  @override
  Stream<List<Map<String, dynamic>>> watch(String orderId) => chatSessionStream(
    FirebaseAuth.instance.idTokenChanges().map((u) => u?.uid),
    () => FirebaseAuth.instance.currentUser?.uid,
    <Map<String, dynamic>>[], () => _authorized(() => db
    .collection('orderChats').doc(orderId).collection('messages')
    .orderBy('createdAt').limitToLast(100).snapshots()
    .map((s) => s.docs.map((d) => d.data()).toList())));
  @override
  Stream<Map<String, dynamic>> orderChanges(String orderId) => chatSessionStream(
    FirebaseAuth.instance.idTokenChanges().map((u) => u?.uid),
    () => FirebaseAuth.instance.currentUser?.uid,
    <String, dynamic>{'status': 'Cancelado'},
    () => _authorized(() => db.collection('orders').doc(orderId).snapshots()
      .map((s) => s.data() ?? {'status': 'Cancelado'})));
  @override
  Future<void> send(String orderId, String text, String requestId) async {
    await functions.httpsCallable('chamaeEnviarMensagemPedido').call({
      'orderId': orderId, 'text': text, 'requestId': requestId,
    });
  }
  @override
  Future<void> read(String orderId) async {
    await functions.httpsCallable('chamaeMarcarChatLido').call({'orderId': orderId});
  }
}

class OrderChat extends StatefulWidget {
  const OrderChat({super.key, required this.orderId, required this.order,
    this.merchant = false, this.gateway});
  final String orderId;
  final Map<String, dynamic> order;
  final bool merchant;
  final OrderChatGateway? gateway;
  @override
  State<OrderChat> createState() => _OrderChatState();
}

class _OrderChatState extends State<OrderChat> {
  final _text = TextEditingController();
  late final OrderChatGateway _gateway;
  late final Stream<List<Map<String, dynamic>>> _messages;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  StreamSubscription<Map<String, dynamic>>? _orderSubscription;
  late Map<String, dynamic> _order;
  Timer? _timer;
  bool _sending = false;
  String? _requestId, _retryText, _error;
  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? FirebaseOrderChat();
    _order = widget.order;
    _orderSubscription = _gateway.orderChanges(widget.orderId)?.listen((order) {
      if (mounted) setState(() => _order = order);
    }, onError: (Object _) {
      if (mounted) setState(() => _order = {'status': 'Cancelado'});
    });
    _messages = _gateway.watch(widget.orderId)
      .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
    _subscription = _messages.listen((messages) {
      if (messages.isEmpty) { return; }
      _gateway.read(widget.orderId).catchError((Object _) {});
    }, onError: (Object _) {});
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }
  @override
  void dispose() { _subscription?.cancel(); _orderSubscription?.cancel(); _timer?.cancel(); _text.dispose(); super.dispose(); }
  Future<void> _send() async {
    final text = _text.text.trim();
    if (_sending || text.isEmpty || text.length > 2000 || chatIsClosed(_order, DateTime.now())) return;
    if (_retryText != text) {
      _requestId = '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
      _retryText = text;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await _gateway.send(widget.orderId, text, _requestId!);
      _text.clear(); _requestId = null; _retryText = null;
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível enviar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final closed = chatIsClosed(_order, DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(height: 28),
      Text(widget.merchant ? 'Conversa com o cliente' : 'Conversa com a loja',
        style: const TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 230, child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _messages,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Não foi possível carregar a conversa.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final messages = snapshot.data!;
          if (messages.isEmpty) return const Center(child: Text('Conversa exclusiva deste pedido.'));
          return ListView.builder(reverse: true, itemCount: messages.length, itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            return Padding(padding: const EdgeInsets.all(6), child: Text(
              '${message['senderType'] == 'merchant' ? 'Loja' : 'Cliente'}: ${message['text'] ?? ''}',
            ));
          });
        },
      )),
      if (closed) const Text('Conversa encerrada. Histórico preservado.')
      else ...[
        if (widget.merchant) DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Resposta rápida'),
          isExpanded: true,
          items: orderChatReplies.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: _sending ? null : (s) { if (s != null) _text.text = s; },
        ),
        TextField(controller: _text, maxLength: 2000, minLines: 1, maxLines: 3,
          enabled: !_sending, decoration: const InputDecoration(labelText: 'Mensagem de texto'),
          onSubmitted: (_) => _send()),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        Align(alignment: Alignment.centerRight, child: FilledButton(
          onPressed: _sending ? null : _send, child: Text(_sending ? 'Enviando...' : 'Enviar'),
        )),
      ],
    ]);
  }
}
