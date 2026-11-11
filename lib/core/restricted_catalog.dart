import 'models.dart';

/// Presentation gate only. Purchase eligibility is always enforced by backend.
/// No trusted age provider is active, so restricted campaigns/items stay hidden.
bool restrictedCatalogProduct(Product product) {
  final category = product.category.trim().toLowerCase();
  return product.isAlcoholic || product.requiresAgeCheck ||
      const {'cervejas', 'destilados', 'vinhos', 'kaipi fruit'}.contains(category);
}

bool restrictedCartItem(CartItem item) => item.isAlcoholic || item.requiresAgeCheck ||
    const {'cervejas', 'destilados', 'vinhos', 'kaipi fruit'}.contains(item.category.trim().toLowerCase());
