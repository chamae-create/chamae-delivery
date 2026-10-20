import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/restore_customer_cart.dart';

void main() {
  final cart = [
    {'id': 'p1', 'name': 'Produto', 'price': 20, 'quantity': 2}
  ];
  test(
      'restoration refreshes official price and warns stock without deleting items',
      () async {
    final result = await restoreCustomerCart(cart,
        lookup: (_) async => {'priceBRL': 25, 'stock': 1});
    expect(result.items['p1']!.price, 25);
    expect(result.items['p1']!.quantity, 2);
    expect(result.notices.join(' '), contains('preço'));
    expect(result.notices.join(' '), contains('disponibilidade'));
  });
  test('connection failure keeps cart and avoids repeated failing reads',
      () async {
    var reads = 0;
    final result = await restoreCustomerCart([
      ...cart,
      {'id': 'p2', 'price': 10, 'quantity': 1}
    ], lookup: (_) async {
      reads++;
      throw StateError('offline');
    });
    expect(result.items.length, 2);
    expect(result.items['p1']!.price, 20);
    expect(reads, 1);
    expect(result.notices.single, contains('mantido'));
  });
  test('commercial restrictions apply to authoritative product metadata',
      () async {
    final result = await restoreCustomerCart(cart,
        lookup: (_) async => {'name': 'POD', 'priceBRL': 20, 'stock': 2});
    expect(result.items, isEmpty);
    expect(result.notices.single, contains('removido'));
  });
}
