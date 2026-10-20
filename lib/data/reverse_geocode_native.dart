import 'package:geocoding/geocoding.dart';
import 'geocoded_address.dart';

Future<GeocodedPoint> searchAddress(String query) async {
  final locations = await Geocoding()
      .locationFromAddress(query)
      .timeout(const Duration(seconds: 12));
  if (locations.isEmpty) throw StateError('Endereço não encontrado');
  return GeocodedPoint(locations.first.latitude, locations.first.longitude);
}

Future<GeocodedAddress> reverseGeocode(double lat, double lng) async {
  final places = await Geocoding()
      .placemarkFromCoordinates(lat, lng)
      .timeout(const Duration(seconds: 12));
  if (places.isEmpty) return const GeocodedAddress('', null);
  final p = places.first;
  return GeocodedAddress(
    [p.street, p.subLocality, p.locality, p.administrativeArea]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(', '),
    p.isoCountryCode?.toUpperCase(),
    street: p.thoroughfare ?? '',
    number: p.subThoroughfare ?? '',
    district: p.subLocality ?? '',
    city: p.locality ?? '',
  );
}
