import 'package:chamae_delivery/core/catalog.dart';
import 'package:chamae_delivery/core/catalog_commercial_policy.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Product product(String name, {String category='Bebidas', bool active=true, bool blocked=false}) => Product(
    id:name, name:name, category:category, price:20, stock:10, isActive:active,
    commercialBlocked:blocked, imageUrl:'https://example.test/product.webp', description:'',
    isOffer:true, isCombo:true, salesCount:10);
  final allowed = product('HEINEKEN 330ML');
  final products = [allowed,
    for(final name in ['POD', 'VAPE', 'CIGARRO', 'CIGARROS', 'CIGARRILHO', 'TABACO',
      'MARLBORO BLUE ICE', 'IGNITE V80 ULTRA']) product(name),
    product('Genérico', category:'Tabacaria'), product('Bloqueado', blocked:true),
    product('Inativo', active:false),
  ];
  test('catalog, search, promotions and combos exclude restricted/inactive products', () {
    expect(visibleCatalogProducts(products), [allowed]);
    expect(visibleCatalogProducts(products, onlyOffers:true), [allowed]);
    expect(visibleCatalogProducts(products, onlyCombos:true), [allowed]);
    expect(visibleCatalogProducts(products, query:'pod'), isEmpty);
    expect(visibleCatalogProducts(products, category:'Tabacaria'), isEmpty);
    expect(visibleCatalogProducts(products, query:'heineken').single.imageUrl, allowed.imageUrl);
  });
  test('commercial gate does not rewrite historical cart/order snapshots', () {
    final old = CartItem(id:'old', name:'CIGARRO', price:4, imageUrl:'', quantity:2);
    expect(isCommerciallyBlocked({'name':old.name}), isTrue);
    expect(old.name, 'CIGARRO'); expect(old.quantity,2); expect(old.totalPrice,8);
    expect(isCommerciallyBlocked({'name':'PODIUM ENERGÉTICO'}), isFalse);
    expect(isCommerciallyBlocked({'name':'ERVA TERERÉ'}), isFalse);
  });
}
