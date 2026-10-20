import 'dart:convert';
import 'dart:js_interop';
import 'geocoded_address.dart';

@JS('chamaeReverseGeocode')
external JSPromise<JSString> _lookup(double latitude, double longitude);

@JS('chamaeSearchAddress')
external JSPromise<JSString> _search(JSString query);

Future<GeocodedPoint> searchAddress(String query) async {
  final result =
      await _search(query.toJS).toDart.timeout(const Duration(seconds: 12));
  final data = jsonDecode(result.toDart) as Map<String, dynamic>;
  return GeocodedPoint((data['latitude'] as num).toDouble(),
      (data['longitude'] as num).toDouble());
}

Future<GeocodedAddress> reverseGeocode(double lat, double lng) async {
  final result =
      await _lookup(lat, lng).toDart.timeout(const Duration(seconds: 12));
  final data = jsonDecode(result.toDart) as Map<String, dynamic>;
  return GeocodedAddress(
      data['address'] as String? ?? '', data['countryCode'] as String?,
      street: data['street'] as String? ?? '',
      number: data['number'] as String? ?? '',
      district: data['district'] as String? ?? '',
      city: data['city'] as String? ?? '');
}
