import 'models.dart';
import 'catalog_commercial_policy.dart';

/// Client preflight only; reservations and final prices remain authoritative
/// on the server. Never accept cached data as a checkout preflight.
String? cartItemIssue(CartItem item, Map<String, dynamic>? data) {
  if (item.quantity < 1 ||
      data == null ||
      data['isActive'] == false ||
      isCommerciallyBlocked(data)) {
    return 'Um produto não está mais disponível. Revise seu carrinho.';
  }
  final available = ((data['stock'] as num?)?.toInt() ?? 0) -
      ((data['reservedStock'] as num?)?.toInt() ?? 0);
  if (available < item.quantity) {
    return 'O estoque mudou. Revise a quantidade de ${item.name}.';
  }
  final price = data['priceBRL'] ?? data['price'];
  if (price is! num ||
      !price.isFinite ||
      price < 0 ||
      (price.toDouble() - item.price).abs() > .001) {
    return 'O preço de ${item.name} mudou. Remova e adicione o produto novamente para conferir o novo valor.';
  }
  return null;
}
