import 'catalog_commercial_policy.dart';
import 'models.dart';

bool commerciallyAvailable(Product product) =>
    product.isActive &&
    product.stock > 0 &&
    !isCommerciallyBlocked({
      'name': product.name,
      'category': product.category,
      'commercialBlocked': product.commercialBlocked
    });

/// Every public catalog surface uses the same commercial gate before filters.
List<Product> visibleCatalogProducts(
  Iterable<Product> products, {
  String query = '',
  String category = 'Todos',
  bool onlyOffers = false,
  bool onlyCombos = false,
}) {
  final search = query.trim().toLowerCase();
  final result = products
      .where((p) =>
          p.isActive &&
          !isCommerciallyBlocked({
            'name': p.name,
            'category': p.category,
            'commercialBlocked': p.commercialBlocked
          }) &&
          (category == 'Todos' || p.category == category) &&
          (!onlyOffers || p.isOffer) &&
          (!onlyCombos || p.isCombo) &&
          (search.isEmpty || p.name.toLowerCase().contains(search)))
      .toList();
  result.sort((a, b) => b.salesCount.compareTo(a.salesCount));
  return result;
}
