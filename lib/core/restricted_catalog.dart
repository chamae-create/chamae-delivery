import 'catalog_commercial_policy.dart';
import 'models.dart';

const _ageRestrictedCategories = <String>{
  'cervejas',
  'destilados',
  'vinhos',
  'kaipi fruit',
};

/// Alcoholic beverages and 18+ items allowed for display with delivery age check (LEG03).
bool requiresAgeVerificationProduct(Product product) {
  final category = product.category.trim().toLowerCase();
  return product.isAlcoholic ||
      product.requiresAgeCheck ||
      _ageRestrictedCategories.contains(category);
}

bool requiresAgeVerificationCartItem(CartItem item) {
  final category = item.category.trim().toLowerCase();
  return item.isAlcoholic ||
      item.requiresAgeCheck ||
      _ageRestrictedCategories.contains(category);
}

/// Commercial visibility gate: Tabacaria, Head Shop, and unmapped/blocked items remain hidden.
bool restrictedCatalogProduct(Product product) =>
    product.commercialBlocked ||
    isCommerciallyBlocked({
      'id': product.id,
      'name': product.name,
      'category': product.category,
      'commercialBlocked': product.commercialBlocked,
    });

bool restrictedCartItem(CartItem item) =>
    item.commercialBlocked ||
    isCommerciallyBlocked({
      'id': item.id,
      'name': item.name,
      'category': item.category,
      'commercialBlocked': item.commercialBlocked,
    });
