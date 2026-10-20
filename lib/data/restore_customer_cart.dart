import '../core/models.dart';
import '../core/catalog_commercial_policy.dart';

class RestoredCustomerCart {
  final Map<String, CartItem> items;
  final List<String> notices;
  const RestoredCustomerCart(this.items, this.notices);
}

Future<RestoredCustomerCart> restoreCustomerCart(List rawItems,
    {Future<Map<String, dynamic>?> Function(String id)? lookup}) async {
  final items = <String, CartItem>{}, notices = <String>[];
  var offline = false;
  for (final raw in rawItems.take(100).whereType<Map>()) {
    final id = raw['id'], price = raw['price'], quantity = raw['quantity'];
    if (id is! String ||
        id.isEmpty ||
        id.contains('/') ||
        price is! num ||
        !price.isFinite ||
        price < 0 ||
        quantity is! num ||
        quantity < 1 ||
        quantity > 999 ||
        quantity != quantity.toInt()) {
      continue;
    }
    if (isCommerciallyBlocked(Map<String, dynamic>.from(raw))) continue;
    Map<String, dynamic>? product;
    if (lookup != null && !offline) {
      try {
        product = await lookup(id);
        if (product != null && isCommerciallyBlocked(product)) {
          notices.add('${raw['name']} está fora de venda e foi removido.');
          continue;
        }
        final available = (product?['stock'] as num? ?? 0) -
            (product?['reservedStock'] as num? ?? 0);
        if (product == null ||
            product['isActive'] == false ||
            available < quantity) {
          notices.add(
              'Confira a disponibilidade de ${raw['name']} antes de comprar.');
        }
      } catch (_) {
        offline = true;
        notices.add(
            'Sem conexão para conferir os produtos. O carrinho foi mantido.');
      }
    }
    final current = product?['priceBRL'] ?? product?['price'];
    final valid = current is num && current.isFinite && current >= 0;
    if (valid && current != price) {
      notices.add('O preço de ${raw['name']} mudou. Confira o novo total.');
    }
    items[id] = CartItem(
        id: id,
        name: product?['name']?.toString() ??
            raw['name']?.toString() ??
            'Produto',
        price: valid ? (current).toDouble() : price.toDouble(),
        quantity: quantity.toInt(),
        imageUrl: product?['imageUrl']?.toString() ??
            raw['imageUrl']?.toString() ??
            '',
        category: product?['category']?.toString() ??
            raw['category']?.toString() ??
            '',
        commercialBlocked: product?['commercialBlocked'] == true ||
            raw['commercialBlocked'] == true);
  }
  return RestoredCustomerCart(items, notices);
}
