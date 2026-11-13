import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/core/store_hours.dart';
import 'package:chamae_delivery/widgets/commerce_components.dart';
import 'customer_visual_freeze_test.dart' as visuals;

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'compact cart preserves actions and accessibility $width/$scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var increased = 0, decreased = 0, removed = 0;
        const name =
            'Produto sintético com nome deliberadamente longo para verificar truncamento sem perder a identificação acessível';
        await tester.pumpWidget(visuals.app(
            Scaffold(
                body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CommerceCartItemCard(
                item: CartItem(
                    id: 'synthetic',
                    name: name,
                    price: 20,
                    imageUrl: '',
                    quantity: 10),
                increase: () => increased++,
                decrease: () => decreased++,
                remove: () => removed++,
              ),
            )),
            scale));
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.text(name));
        expect(text.maxLines, 2);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.semanticsLabel, name);
        if (scale == 1 && width >= 390) {
          expect(tester.getSize(find.byType(CommerceCartItemCard)).height,
              lessThan(145));
        }
        for (final icon in [Icons.add, Icons.remove, Icons.delete_outline]) {
          final button = find.ancestor(
              of: find.byIcon(icon), matching: find.byType(IconButton));
          final size = tester.getSize(button);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          await tester.tap(button);
        }
        expect([increased, decreased, removed], [1, 1, 1]);
        expect(find.text('R\$ 200,00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('enlarged summary uses full width for both label and amount',
      (tester) async {
    await tester.pumpWidget(visuals.app(
        const Scaffold(
            body: SizedBox(
                width: 264,
                child: CommerceSummaryLine(
                    label: 'Produtos', value: 'R\$ 200,00'))),
        2));
    final label = tester.getRect(find.text('Produtos'));
    final value = tester.getRect(find.text('R\$ 200,00'));
    expect(value.top, greaterThanOrEqualTo(label.bottom));
    expect(label.width, 264);
    expect(tester.takeException(), isNull);
  });
  test('removing decorative hours does not change operational boundaries', () {
    expect(isStoreOpen(DateTime.utc(2026, 11, 13, 11, 59)), isFalse);
    expect(isStoreOpen(DateTime.utc(2026, 11, 13, 12)), isTrue);
    expect(isStoreOpen(DateTime.utc(2026, 11, 14, 3, 59)), isTrue);
    expect(isStoreOpen(DateTime.utc(2026, 11, 14, 4)), isFalse);
  });
}
