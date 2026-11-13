import 'catalog_commercial_registry.dart';

/// Commercial visibility only. Never use this to filter historical order items.
String _commercialText(Object? value) => (value ?? '')
    .toString()
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp('[^a-z0-9]+'), ' ')
    .trim();

Iterable<String> _categoryLeaves(Object? value) sync* {
  if (value == null) return;
  if (value is Map) {
    for (final item in value.values) { yield* _categoryLeaves(item); }
  } else if (value is Iterable) {
    for (final item in value) { yield* _categoryLeaves(item); }
  } else { yield value.toString(); }
}
Iterable<String> _fields(Map<String, dynamic> p, List<String> keys) =>
    keys.expand((key) => _categoryLeaves(p[key]));
const _labels = ['category', 'subcategory', 'parentCategory', 'categoryPath', 'categories'];
const _ids = ['categoryId', 'subcategoryId', 'parentCategoryId'];

bool isCommerciallyBlocked(Map<String, dynamic> product) {
  if (product['PRO_CODIGO'] != null || product['commercialBlocked'] == true ||
      restrictedProductIds.contains(product['id']) ||
      _fields(product, _ids).any(restrictedCategoryIds.contains)) {
    return true;
  }
  final text = _commercialText([product['name'] ?? '', ..._fields(product, _labels)].join(' '));
  return RegExp(restrictedTextPattern).hasMatch(text);
}

bool categoryReviewRequired(Map<String, dynamic> product) {
  final labels = _fields(product, _labels).toList();
  final ids = _fields(product, _ids).toList();
  return labels.isEmpty && ids.isEmpty ||
      labels.any((x) => !allowedCategoryNames.contains(_commercialText(x))) ||
      ids.any((x) => !allowedCategoryNames.contains(categoryNamesById[x]));
}
