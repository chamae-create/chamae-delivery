import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/customer_workspace.dart';

void main() {
  test(
      'confirmation consumes original quantities and preserves newer additions',
      () {
    final cart = [
      {'id': 'p1', 'quantity': 5, 'price': 20},
      {'id': 'p2', 'quantity': 1, 'price': 10},
      {'id': 'p3', 'quantity': 2, 'price': 5},
    ];
    final result = remainingCart(cart, [
      {'id': 'p1', 'quantity': 1},
      {'id': 'p1', 'quantity': 2},
      {'id': 'p2', 'quantity': 1},
    ]);
    expect(result, [
      {'id': 'p1', 'quantity': 2, 'price': 20},
      {'id': 'p3', 'quantity': 2, 'price': 5},
    ]);
    expect(cart.first['quantity'], 5);
  });
}
