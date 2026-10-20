import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/screens/checkout_screen.dart';
import 'package:chamae_delivery/screens/cart_screen.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'package:chamae_delivery/screens/tracking_view.dart';
import 'customer_visual_freeze_test.dart' as visuals;
import 'support/customer_flow_fakes.dart';

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('small Android keyboard and footer at text $scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      final items = [
        CartItem(
            id: 'test',
            name: 'Produto de teste com nome longo',
            price: 20,
            imageUrl: '',
            quantity: 2)
      ];
      await tester.pumpWidget(visuals.app(
          CheckoutScreen(
              cartItems: items,
              onCartCleared: () {},
              deliveryAddress: testCustomerAddress),
          scale));
      await tester.pumpAndSettle();
      final name = find.widgetWithText(TextField, 'Seu Nome *');
      await tester.ensureVisible(name);
      await tester.showKeyboard(name);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(name);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(name).bottom, lessThanOrEqualTo(380));
      await tester.ensureVisible(find.text('Finalizar pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Finalizar pedido').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.text('Finalizar pedido')).bottom,
          lessThanOrEqualTo(380));
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(visuals.app(
          CustomerProfileScreen(
              selectAddress: () async {},
              onboarding: FlowOnboarding(accepted: true)),
          scale));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta').hitTestable(), findsOneWidget);
      expect(find.text('Política de Privacidade'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(visuals.app(
          CartScreen(items: () => items, change: (_, __) {}, checkout: () {}),
          scale));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('R\$ 40,40'));
      await tester.pumpAndSettle();
      final feeRight = tester.getRect(find.text('R\$ 0,40')).right;
      final totalRight = tester.getRect(find.text('R\$ 40,40')).right;
      expect((feeRight - totalRight).abs(), lessThan(.5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('terminal tracking does not imply pending courier assignment',
      (tester) async {
    for (final status in ['Concluído', 'Cancelado']) {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: TrackingView(
              key: ValueKey(status),
              orderId: 'TEST',
              onBack: () {},
              orderStream: Stream.value({'status': status, 'totalBRL': 0}))));
      await tester.pumpAndSettle();
      expect(find.text('Aguardando atribuição'), findsNothing);
      expect(find.text('Entregador não informado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
