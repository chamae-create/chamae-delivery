import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'package:chamae_delivery/screens/home_screen.dart';

// Debug-only visual fixtures. No Firebase initialization, remote services or orders.
class LocalHomeQuote implements DeliveryQuoter {
  final bool fail;
  LocalHomeQuote({this.fail = false});
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) async {
    if (fail) throw StateError('Fixture de erro da cotação');
    return const DeliveryQuote(8.5, 'HOME-LOCAL-ONLY', 'legacy');
  }
}

Future<String> localCan(Color color, String label) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(46, 20, 100, 214), const Radius.circular(16));
  canvas.drawShadow(Path()..addRRect(body), Colors.black, 6, true);
  canvas.drawRRect(
      body,
      Paint()
        ..shader =
            ui.Gradient.linear(const Offset(46, 0), const Offset(146, 0), [
          color,
          Color.lerp(color, Colors.white, .55)!,
          color,
          Color.lerp(color, Colors.black, .35)!
        ], [
          0,
          .3,
          .6,
          1
        ]));
  canvas.drawOval(const Rect.fromLTWH(46, 16, 100, 24),
      Paint()..color = const Color(0xFFCDCED0));
  canvas.drawOval(const Rect.fromLTWH(57, 20, 78, 14),
      Paint()..color = const Color(0xFF73777B));
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(87, 21, 24, 10), const Radius.circular(4)),
      Paint()..color = const Color(0xFFE1E3E5));
  canvas.drawRect(const Rect.fromLTWH(46, 83, 100, 82),
      Paint()..color = const Color(0xEEFAF7F0));
  final text = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
          text: 'LOCAL\n$label',
          style: const TextStyle(
              color: Color(0xFF191816),
              fontSize: 19,
              fontWeight: FontWeight.w800)));
  text.layout(maxWidth: 96);
  text.paint(canvas, const Offset(48, 96));
  final image = await recorder.endRecording().toImage(192, 256);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
}

final homeVisualNavigator = GlobalKey<NavigatorState>();
final homeCaptureKeys = {
  LogicalKeyboardKey.f1: '/home',
  LogicalKeyboardKey.f2: '/promotions',
  LogicalKeyboardKey.f3: '/popular',
  LogicalKeyboardKey.f4: '/categories-preview',
  LogicalKeyboardKey.f5: '/catalog',
  LogicalKeyboardKey.f6: '/cart-state',
  LogicalKeyboardKey.f7: '/search',
  LogicalKeyboardKey.f8: '/empty',
  LogicalKeyboardKey.f9: '/error',
  LogicalKeyboardKey.f10: '/large-text',
  LogicalKeyboardKey.f11: '/quote-error',
  LogicalKeyboardKey.f12: '/no-address',
};

Future<void> main() async {
  if (!kDebugMode) throw UnsupportedError('Home visual harness is debug-only.');
  WidgetsFlutterBinding.ensureInitialized();
  HardwareKeyboard.instance.addHandler((event) {
    final route = homeCaptureKeys[event.logicalKey];
    if (event is! KeyDownEvent || route == null) return false;
    homeVisualNavigator.currentState?.pushReplacementNamed(route);
    return true;
  });
  final images = await Future.wait([
    localCan(const Color(0xFF308C42), '350 ml'),
    localCan(const Color(0xFF244D9A), '473 ml'),
    localCan(const Color(0xFFB24528), 'Lanche'),
  ]);
  final products = [
    Product(
        id: 'home-local-1',
        name: 'Bebida local 350 ml',
        category: 'Cervejas',
        price: 5.9,
        stock: 8,
        isActive: true,
        imageUrl: images[0],
        description:
            'Produto e imagem locais exclusivos da homologação visual.',
        isOffer: true,
        isCombo: false,
        salesCount: 12),
    Product(
        id: 'home-local-2',
        name: 'Energético local 473 ml',
        category: 'Energéticos',
        price: 8.9,
        stock: 4,
        isActive: true,
        imageUrl: images[1],
        description: 'Fixture local, sem oferta de venda real.',
        isOffer: true,
        isCombo: false,
        salesCount: 8),
    Product(
        id: 'home-local-3',
        name: 'Snack local',
        category: 'Snacks & Doces',
        price: 7.9,
        stock: 2,
        isActive: true,
        imageUrl: images[2],
        description: 'Fixture local.',
        isOffer: false,
        isCombo: true,
        salesCount: 4),
    Product(
        id: 'home-local-4',
        name:
            'Produto local com nome muito extenso e embalagem retornável de um litro',
        category: 'Refrigerantes & Sucos',
        price: 1234.56,
        stock: 0,
        isActive: true,
        imageUrl: '',
        description: 'Fixture sem foto e sem estoque.',
        isOffer: false,
        isCombo: false,
        salesCount: 0),
  ];
  runApp(HomeVisualApp(products));
}

class HomeVisualApp extends StatelessWidget {
  const HomeVisualApp(this.products, {super.key});
  final List<Product> products;
  static const address = DeliveryAddress(
      latitude: -22.5,
      longitude: -55.7,
      addressText: 'Rua de homologação, 123',
      street: 'Rua de homologação',
      number: '123',
      city: 'Cidade de teste',
      countryCode: 'BR',
      confirmed: true);
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: homeVisualNavigator,
        initialRoute: '/', // One Home instance; scenes use the debug keys.
        theme: AppTheme.lightTheme,
        builder: (context, child) => Column(children: [
          SafeArea(
              bottom: false,
              child: Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF3CD),
                  padding: const EdgeInsets.all(3),
                  child: const Text(
                      'HOME LOCAL • DEBUG • DADOS E IMAGENS CONTROLADOS',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 9, color: Color(0xFF664D03))))),
          Expanded(
              child: MediaQuery.removePadding(
                  context: context, removeTop: true, child: child!)),
        ]),
        onGenerateRoute: (settings) {
          final route = settings.name ?? '/';
          scheduleHomeScene(route);
          Stream<List<Product>> stream = Stream.value(products);
          if (route == '/empty') stream = Stream.value([]);
          if (route == '/error') {
            stream = Stream.error(StateError('Fixture offline'));
          }
          if (route == '/loading') stream = const Stream.empty();
          return MaterialPageRoute(
              settings: settings,
              builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(route == '/large-text'
                          ? 1.6
                          : route == '/largest-text'
                              ? 2
                              : 1)),
                  child: DeliveryHomeScreen(
                      products: stream,
                      initialAddress: route == '/no-address' ? null : address,
                      quoter: LocalHomeQuote(fail: route == '/quote-error'))));
        },
      );
}

Element? findHomeElement(bool Function(Widget) matches) {
  Element? result;
  void visit(Element element) {
    if (result != null) return;
    if (matches(element.widget) && ModalRoute.of(element)?.isCurrent == true) {
      result = element;
      return;
    }
    element.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  return result;
}

void scheduleHomeScene(String route) {
  const targets = {
    '/promotions': 'Promoções do dia',
    '/popular': 'Mais pedidos',
    '/categories-preview': 'Compre por categoria',
    '/catalog': 'Todos os produtos',
    '/cart-state': 'Mais pedidos',
    '/unavailable': 'Todos os produtos'
  };
  if (!targets.containsKey(route) && route != '/search') return;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (route == '/search') {
      final element = findHomeElement(
          (w) => w is IconButton && w.tooltip == 'Buscar produtos');
      (element?.widget as IconButton?)?.onPressed?.call();
      return;
    }
    final target =
        findHomeElement((w) => w is Text && w.data == targets[route]);
    if (target == null || !target.mounted) {
      debugPrint('HOME_CAPTURE_TARGET_ABSENT $route');
      return;
    }
    await revealHomeTarget(target);
    if (route == '/cart-state') {
      final add = findHomeElement((w) =>
          w is IconButton && w.tooltip == 'Adicionar Bebida local 350 ml');
      (add?.widget as IconButton?)?.onPressed?.call();
    }
  });
}

Future<void> revealHomeTarget(Element target) async {
  await WidgetsBinding.instance.endOfFrame;
  while (target.mounted) {
    final scrollable = Scrollable.maybeOf(target);
    if (scrollable == null) return;
    final position = scrollable.position;
    if (!position.hasViewportDimension || !position.hasContentDimensions) {
      await WidgetsBinding.instance.endOfFrame;
      continue;
    }
    final object = target.findRenderObject();
    if (object is RenderBox && object.hasSize) {
      await Scrollable.ensureVisible(target,
          alignment: .02, duration: const Duration(milliseconds: 250));
      return;
    }
    final next = (position.pixels + position.viewportDimension * .7)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (next <= position.pixels) return;
    position.jumpTo(next);
    await WidgetsBinding.instance.endOfFrame;
  }
}
