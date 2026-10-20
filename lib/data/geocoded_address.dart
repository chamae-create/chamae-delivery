class GeocodedAddress {
  final String text;
  final String? countryCode;
  final String street, number, district, city;
  const GeocodedAddress(this.text, this.countryCode,
      {this.street = '', this.number = '', this.district = '', this.city = ''});
}

class GeocodedPoint {
  final double latitude;
  final double longitude;
  const GeocodedPoint(this.latitude, this.longitude);
}
