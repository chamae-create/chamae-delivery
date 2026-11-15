import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/order_notifications.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _sampleProduct() => Product(
      id: 'prod-1',
      name: 'Produto Teste',
      category: 'Refrigerantes & Sucos',
      price: 10.0,
      stock: 5,
      isActive: true,
      imageUrl: '',
      description: 'Bebida de teste',
      isOffer: false,
      isCombo: false,
      salesCount: 1,
    );

void main() {
  testWidgets(
      'DeliveryHomeScreen renders persistent banner when active orders exist',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DeliveryHomeScreen(
          products: Stream.value([_sampleProduct()]),
          activeOrders: Stream.value([
            {
              '_documentId': 'doc-active-1',
              'id': '#CH-ACTIVE1',
              'status': 'Em Separação',
            },
          ]),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Pedido #CH-ACTIVE1'), findsOneWidget);
    expect(
      find.text('Status: Em Separação • Toque para acompanhar'),
      findsOneWidget,
    );
    expect(find.text('Acompanhar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DeliveryHomeScreen hides banner when activeOrders is empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DeliveryHomeScreen(
          products: Stream.value([_sampleProduct()]),
          activeOrders: Stream.value(const []),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Acompanhar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('FirebaseCustomerPushNotifications fails safely when Firebase is uninitialized',
      () async {
    FirebaseCustomerPushNotifications.pendingOrderId = 'order-pending-1';
    expect(
      FirebaseCustomerPushNotifications.pendingOrderId,
      'order-pending-1',
    );
    FirebaseCustomerPushNotifications.pendingOrderId = null;

    await FirebaseCustomerPushNotifications.instance.initializeAndSyncToken();
    await FirebaseCustomerPushNotifications.ensureRegisteredSilently();
    final permission = await FirebaseCustomerPushNotifications.instance
        .requestForOrder('order-1');
    expect(permission, OrderNotificationPermission.unavailable);
  });
}
