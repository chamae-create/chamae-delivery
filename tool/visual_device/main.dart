import 'package:chamae_delivery/widgets/customer_order_history_card.dart';
// LOCAL VISUAL HARNESS. Never initializes Firebase or accepts legal documents.
import 'dart:async';
import 'dart:ui' as ui;
import 'local_qr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'package:chamae_delivery/data/customer_verification.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'package:chamae_delivery/screens/address_map_screen.dart';
import 'package:chamae_delivery/widgets/customer_chat_entry.dart';
import 'package:chamae_delivery/widgets/pix_payment_presentation.dart';
import 'package:chamae_delivery/order_chat.dart';
import '../../test/support/customer_flow_fakes.dart';

final products = [
  Product(
      id: 'local-1',
      name:
          'Bebida de homologação com nome extenso e embalagem retornável 1 litro',
      category: 'Refrigerantes & Sucos',
      price: 1234.56,
      stock: 8,
      isActive: true,
      imageUrl: '',
      description:
          'Dados locais controlados. Imagem ausente para testar o fallback.',
      isOffer: true,
      isCombo: false,
      salesCount: 1),
  Product(
      id: 'local-2',
      name: 'Snack local',
      category: 'Snacks & Doces',
      price: 4.5,
      stock: 0,
      isActive: true,
      imageUrl: '',
      description: 'Fixture local sem estoque.',
      isOffer: false,
      isCombo: false,
      salesCount: 0),
];
List<CartItem> items() => [
      CartItem(
          id: 'local-1',
          name: products.first.name,
          price: 1234.56,
          imageUrl: '',
          quantity: 2,
          category: products.first.category),
      CartItem(
          id: 'local-3',
          name: 'Item de homologação',
          price: 4.5,
          imageUrl: '',
          quantity: 1)
    ];

class LocalVerification implements AccountVerification {
  @override
  Future<bool> isVerified() async => true;
  @override
  Future<void> startVerification() async {}
}

class LocalQuote implements DeliveryQuoter {
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) async =>
      const DeliveryQuote(8.5, 'LOCAL-ONLY', 'legacy');
}

class LocalChat extends OrderChatGateway {
  final rows = List.generate(
      12,
      (i) => <String, dynamic>{
            'senderType': i.isEven ? 'merchant' : 'customer',
            'text': i.isEven
                ? 'Mensagem local $i: Olá! Estamos separando os produtos. Pode confirmar o complemento? Esta mensagem longa verifica a quebra de linhas e o scroll da conversa sem comunicação externa.'
                : 'Mensagem local $i: Combinado!',
            'createdAt': DateTime(2026, 10, 20, 10, i)
          });
  final events = StreamController<List<Map<String, dynamic>>>.broadcast();
  @override
  Stream<List<Map<String, dynamic>>> watch(String orderId) async* {
    yield rows;
    yield* events.stream;
  }

  @override
  Future<void> read(String orderId) async {}
  @override
  Future<void> send(String orderId, String text, String requestId) async {
    rows.add(
        {'senderType': 'customer', 'text': text, 'createdAt': DateTime.now()});
    events.add(List.of(rows));
  }
}

final localChat = LocalChat();
final order = <String, dynamic>{
  '_documentId': 'LOCAL-ORDER',
  'id': 'LOCAL-ORDER',
  'status': 'Em Separação',
  'customerName': 'Cliente de homologação',
  'totalBRL': 2491.31,
  'deliveryFee': 8.5,
  'paymentStatus': 'Pago',
  'courierName': 'Entregador de homologação'
};
Uint8List? fixtureQrBytes;
Future<void> main() async {
  if (!kDebugMode) throw UnsupportedError('Visual harness is debug-only.');
  WidgetsFlutterBinding.ensureInitialized();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final dimension = (localQrMatrix.length + 8) * 6;
  canvas.drawRect(
      Rect.fromLTWH(0, 0, dimension.toDouble(), dimension.toDouble()),
      Paint()..color = Colors.white);
  for (var r = 0; r < localQrMatrix.length; r++) {
    for (var c = 0; c < localQrMatrix.length; c++) {
      if (localQrMatrix[r][c] == 1) {
        canvas.drawRect(Rect.fromLTWH((c + 4) * 6.0, (r + 4) * 6.0, 6, 6),
            Paint()..color = Colors.black);
      }
    }
  }
  final image = await recorder.endRecording().toImage(dimension, dimension);
  fixtureQrBytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  image.dispose();
  UserSession.fullName = 'Cliente de homologação';
  UserSession.whatsapp = '';
  runApp(const VisualDeviceApp());
}

class VisualDeviceApp extends StatelessWidget {
  const VisualDeviceApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => Directionality(
            textDirection: TextDirection.ltr,
            child: Column(children: [
              SafeArea(
                  bottom: false,
                  child: Container(
                      width: double.infinity,
                      color: const Color(0xFFFFF3CD),
                      padding: const EdgeInsets.all(3),
                      child: const Text(
                          'HOMOLOGAÇÃO LOCAL • DEBUG • DADOS CONTROLADOS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 9, color: Color(0xFF664D03))))),
              Expanded(child: child!),
            ])),
        onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (context) => scene(context, settings.name ?? '/')),
      );
  Widget scene(BuildContext context, String route) {
    scheduleVisualScene(route);
    if (route == '/product-footer') route = '/product';
    if (route == '/cart-footer') route = '/cart';
    if (route == '/checkout-footer') route = '/checkout';
    if (route == '/profile-footer') route = '/profile';
    if (route == '/map-footer') route = '/map';
    if (route == '/pix-footer') route = '/pix-qr';
    void back() => Navigator.of(context).maybePop();
    if (route == '/home' || route == '/product' || route == '/categories') {
      return DeliveryHomeScreen(
          products: Stream.value(products),
          initialAddress: testCustomerAddress,
          quoter: LocalQuote());
    }
    if (route == '/cart') {
      final cart = items();
      return CartScreen(
          items: () => cart,
          change: (_, __) {},
          checkout: () => Navigator.pushNamed(context, '/checkout'));
    }
    if (route == '/checkout') {
      return CheckoutScreen(
          cartItems: items(),
          verification: LocalVerification(),
          workspace: FlowWorkspace(),
          onCartCleared: () {},
          deliveryAddress: testCustomerAddress,
          quoter: LocalQuote());
    }
    if (route == '/profile') {
      return CustomerProfileScreen(
          address: testCustomerAddress,
          selectAddress: () async {},
          auth: FlowAuth(const CustomerIdentity(
              uid: 'LOCAL-ONLY',
              name: 'Cliente de homologação',
              email: 'visual@example.test',
              providers: ['google.com'])),
          onboarding: FlowOnboarding(accepted: true));
    }
    if (route == '/history') {
      return Scaffold(
          appBar: AppBar(title: const Text('Meus pedidos')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            for (final status in ['Em Separação', 'Concluído', 'Cancelado'])
              CustomerOrderHistoryCard(
                  id: 'LOCAL-$status',
                  total: '2506.86',
                  date: DateTime(2026, 10, 20),
                  status: customerStatus(status),
                  onTap: () => Navigator.pushNamed(context, '/orders')),
          ]));
    }
    if (route == '/orders') {
      return TrackingView(
          orderId: 'LOCAL-ORDER',
          orderStream: Stream.value(order),
          onBack: back);
    }
    if (route == '/map') return const AddressMapScreen();
    if (route.startsWith('/chat')) {
      return Scaffold(
          appBar: AppBar(title: const Text('Chat • homologação local')),
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    CustomerChatEntry(
                        order: order,
                        metadata: Stream.value({'unreadCustomer': 3})),
                    OrderChat(
                        orderId: 'LOCAL-ORDER',
                        order: order,
                        merchant: route == '/chat-merchant',
                        gateway: localChat),
                  ]))));
    }
    if (route.startsWith('/pix-')) {
      final mode = route.substring(5);
      return Scaffold(
          appBar: AppBar(title: Text('PIX local: $mode')),
          body: Center(
              child: PixPaymentPresentation(
            totalBRL: 2491.31,
            qrCode: mode == 'creating' ? null : 'LOCAL-VISUAL-NOT-A-PAYMENT',
            qrBytes: fixtureQrBytes,
            createStatus: mode == 'error' ? 'error' : 'created',
            paymentStatus: mode == 'paid' ? 'Pago' : 'Aguardando confirmação',
            paymentApproved: mode == 'paid',
            errorMessage: mode == 'expired'
                ? 'Este PIX expirou ou não pôde ser concluído. Confira o pagamento do seu pedido.'
                : mode == 'error'
                    ? 'Não foi possível gerar o PIX. Confira o pedido antes de tentar novamente.'
                    : mode == 'retry'
                        ? 'Não foi possível acompanhar o pagamento. Tente novamente.'
                        : null,
            onRetry: () =>
                Navigator.pushReplacementNamed(context, '/pix-creating'),
          )));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Cenários locais')),
        body: ListView(children: [
          for (final name in [
            'home',
            'categories',
            'product',
            'cart',
            'checkout',
            'profile',
            'orders',
            'map',
            'chat',
            'chat-merchant',
            'pix-creating',
            'pix-qr',
            'pix-waiting',
            'pix-paid',
            'pix-expired',
            'pix-error',
            'pix-retry'
          ])
            ListTile(
                title: Text(name),
                onTap: () => Navigator.pushNamed(context, '/$name'))
        ]));
  }
}

// Device capture automation only: exercises existing widget callbacks and scroll
// positions. It never changes application rules or connects a backend.
Iterable<Element> visualElements() sync* {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return;
  final all = <Element>[];
  void visit(Element e) {
    all.add(e);
    e.visitChildren(visit);
  }

  visit(root);
  yield* all;
}

bool visualHasText(Element root, String text) {
  var found = false;
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && (w.data ?? '').contains(text)) found = true;
    e.visitChildren(visit);
  }

  visit(root);
  return found;
}

void visualTapText(String text) {
  for (final e in visualElements().toList().reversed) {
    final w = e.widget;
    if (w is InkWell && w.onTap != null && visualHasText(e, text)) {
      w.onTap!();
      return;
    }
  }
}

void visualScrollEnd() {
  for (final e in visualElements().toList()) {
    if (e is StatefulElement && e.state is ScrollableState) {
      final state = e.state as ScrollableState;
      if (axisDirectionToAxis(state.widget.axisDirection) == Axis.vertical &&
          state.position.hasContentDimensions) {
        state.position.jumpTo(state.position.maxScrollExtent);
      }
    }
  }
}

void scheduleVisualScene(String route) {
  Timer(const Duration(seconds: 2), () {
    if (route == '/categories') {
      visualTapText('Categorias');
      Timer(const Duration(milliseconds: 700), visualScrollEnd);
    }
    if (route.startsWith('/product')) {
      visualScrollEnd();
      Timer(const Duration(milliseconds: 700), () {
        visualTapText(products.first.name.toUpperCase());
        if (route.endsWith('footer')) {
          Timer(const Duration(milliseconds: 700), visualScrollEnd);
        }
      });
    }
    if (route.endsWith('footer') && !route.startsWith('/product')) {
      visualScrollEnd();
    }
    if (route == '/chat-keyboard') {
      for (final e in visualElements().toList()) {
        if (e is StatefulElement && e.state is EditableTextState) {
          (e.state as EditableTextState).requestKeyboard();
        }
      }
      Timer(const Duration(seconds: 6), visualScrollEnd);
    }
  });
}
