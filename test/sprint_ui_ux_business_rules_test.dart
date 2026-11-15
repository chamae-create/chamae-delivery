import 'dart:async';

import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/binational_identity.dart';
import 'package:chamae_delivery/data/customer_verification.dart';
import 'package:chamae_delivery/data/customer_workspace.dart';
import 'package:chamae_delivery/data/delivery_quote.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';
import 'package:chamae_delivery/screens/customer_identification_screen.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'package:chamae_delivery/widgets/commerce_components.dart';
import 'package:chamae_delivery/widgets/customer_order_history_card.dart';
import 'package:chamae_delivery/widgets/delivery_pin_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeWorkspace implements CustomerWorkspace {
  final Map<String, dynamic> data = {'cart': [], 'addresses': []};
  final List<Map<String, dynamic>> saves = [];

  @override
  Future<bool> completeOrder(String documentId) async => true;

  @override
  Future<Map<String, dynamic>> read() async => Map<String, dynamic>.from(data);

  @override
  Future<void> save(Map<String, dynamic> fields) async {
    saves.add(Map<String, dynamic>.from(fields));
    data.addAll(fields);
  }
}

class _FakeQuoter implements DeliveryQuoter {
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DeliveryQuote(
      8.5,
      'a' * 64,
      'routeBands',
      distanceMeters: 2100,
      version: 'v1',
      routingProvider: 'google',
      quotedAtMs: now - 1000,
      expiresAtMs: now + 900000,
    );
  }
}

class _AlwaysVerified implements AccountVerification {
  @override
  Future<bool> isVerified() async => true;

  @override
  Future<void> startVerification() async {}
}

class _FakeIdRepo implements IdentificationRepository {
  BinationalIdentity? saved;

  @override
  Future<void> save(BinationalIdentity identity) async {
    saved = identity;
  }
}

Product _product(String id, {String category = 'Cervejas'}) => Product(
      id: id,
      name: 'Produto $id',
      category: category,
      price: 28.5,
      stock: 5,
      isActive: true,
      imageUrl: '',
      description: 'Descrição teste',
      isOffer: false,
      isCombo: false,
      salesCount: 3,
    );

DeliveryAddress _brAddress() => const DeliveryAddress(
      addressText: 'Av. Brasil, 100, Ponta Porã',
      latitude: -22.5361,
      longitude: -55.7256,
      street: 'Av. Brasil',
      city: 'Ponta Porã',
      number: '100',
      confirmed: true,
      countryCode: 'BR',
    );

void main() {
  test('global theme uses Off-White #FAF9F6 and metallic gold #C9A24D', () {
    expect(AppTheme.lightBg, const Color(0xFFFAF9F6));
    expect(AppColors.borderLight, const Color(0xFFC9A24D));
  });

  testWidgets('Home favorites toggle and persist to workspace', (tester) async {
    final workspace = _FakeWorkspace();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DeliveryHomeScreen(
          products: Stream.value([_product('A')]),
          workspace: workspace,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final favButton = find.byTooltip('Favoritar Produto A').last;
    await tester.ensureVisible(favButton);
    await tester.tap(favButton);
    await tester.pump();
    expect(workspace.data['favorites'], ['A']);
    expect(find.byTooltip('Remover Produto A dos favoritos'), findsWidgets);

    await tester.tap(find.byTooltip('Remover Produto A dos favoritos').last);
    await tester.pump();
    expect(workspace.data['favorites'], isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      '1 active order blocks CartScreen and CheckoutScreen and exposes shortcut',
      (tester) async {
    final activeController =
        StreamController<List<Map<String, dynamic>>>.broadcast();
    addTearDown(activeController.close);

    final item = CartItem(
      id: 'p1',
      name: 'Cerveja Gelada',
      price: 12.5,
      imageUrl: '',
      quantity: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CartScreen(
          items: () => [item],
          change: (_, __) {},
          checkout: () {},
          activeOrders: activeController.stream,
        ),
      ),
    );
    activeController.add([
      {
        '_documentId': 'doc123',
        'id': '#CH-DOC123',
        'status': 'Em Separação',
      },
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Acompanhar pedido ativo'), findsOneWidget);
    final cartBtn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continuar para entrega'),
    );
    expect(cartBtn.onPressed, isNull);

    activeController.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('Acompanhar pedido ativo'), findsNothing);

    final checkoutOrders =
        StreamController<List<Map<String, dynamic>>>.broadcast();
    addTearDown(checkoutOrders.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CheckoutScreen(
          cartItems: [item],
          onCartCleared: () {},
          deliveryAddress: _brAddress(),
          quoter: _FakeQuoter(),
          verification: _AlwaysVerified(),
          workspace: _FakeWorkspace(),
          activeOrders: checkoutOrders.stream,
        ),
      ),
    );
    checkoutOrders.add([
      {
        '_documentId': 'doc123',
        'id': '#CH-DOC123',
        'status': 'Saiu para Entrega',
      },
    ]);
    await tester.pumpAndSettle();

    final finalizeBtn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Finalizar pedido'),
    );
    expect(finalizeBtn.onPressed, isNull);
    expect(find.text('Acompanhar pedido ativo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'DeliveryPinCard limits direct reset to once then switches to support action',
      (tester) async {
    var supportTapped = false;
    var resetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DeliveryPinCard(
            allowReset: true,
            onSupportRequest: () => supportTapped = true,
            pinLoader: ({required bool reset}) async {
              if (reset) {
                resetCalls++;
                return {'pin': '4321', 'canReset': false, 'resetCount': 1};
              }
              return {'pin': '1234', 'canReset': true, 'resetCount': 0};
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Redefinir PIN'), findsOneWidget);
    await tester.tap(find.text('Redefinir PIN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Redefinir'));
    await tester.pumpAndSettle();

    expect(resetCalls, 1);
    expect(find.text('4321'), findsOneWidget);
    expect(find.text('Redefinir PIN'), findsNothing);
    expect(find.text('Abrir chamado com o suporte'), findsOneWidget);

    await tester.tap(find.text('Abrir chamado com o suporte'));
    await tester.pump();
    expect(supportTapped, isTrue);
  });

  testWidgets('CategoryBannerTile hides count and Identification formats WhatsApp',
      (tester) async {
    await initializeDateFormatting('pt_BR');
    final repo = _FakeIdRepo();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  child: CategoryBannerTile(
                    title: 'Refrigerantes & Sucos',
                    count: 14,
                    imageUrl: '',
                    onTap: () {},
                  ),
                ),
                CustomerOrderHistoryCard(
                  id: '#CH-12345678',
                  total: '28.50',
                  status: 'Pedido entregue',
                  itemsSummary: '2x Cerveja Gelada',
                  date: DateTime(2026, 11, 15, 14, 30),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('14'), findsNothing);
    expect(find.text('R\$ 28,50'), findsOneWidget);
    expect(find.text('2x Cerveja Gelada'), findsOneWidget);
    expect(find.text('Ver detalhes'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CustomerIdentificationScreen(
          profile: const {},
          repository: repo,
          onComplete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Maria Silva');
    await tester.enterText(find.byType(TextField).at(1), '12345678909');
    await tester.enterText(find.byType(TextField).at(3), '67999998888');
    await tester.pump();
    expect(find.text('(67) 99999-8888'), findsOneWidget);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repo.saved?.phone, '+5567999998888');
  });

  testWidgets('TrackingView omits manual notification card and duplicated hint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TrackingView(
          orderId: '#CH-TRACK01',
          orderStream: Stream.value({
            'id': '#CH-TRACK01',
            'status': 'Em Separação',
            'address': 'Rua das Flores, 50',
            'totalBRL': 45.0,
            'paymentMethod': 'PIX',
            'paymentStatus': 'Pago',
          }),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quer receber atualizações deste pedido?'), findsNothing);
    expect(
      find.textContaining('localização do entregador ao vivo'),
      findsNothing,
    );
    expect(find.text('PIN de entrega'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
