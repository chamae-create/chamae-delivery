import 'package:geolocator/geolocator.dart';

class CustomerLocationFailure implements Exception {
  final String message;
  const CustomerLocationFailure(this.message);
}

abstract class LocationAccess {
  Future<bool> enabled();
  Future<LocationPermission> permission();
  Future<LocationPermission> requestPermission();
  Future<Position> position();
}

class DeviceLocationAccess implements LocationAccess {
  const DeviceLocationAccess();
  @override
  Future<bool> enabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> permission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
  @override
  Future<Position> position() => Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
}

class CustomerLocation {
  final LocationAccess access;
  const CustomerLocation([this.access = const DeviceLocationAccess()]);

  /// Call only after the customer explicitly chooses their current location.
  Future<Position> request() async {
    if (!await access.enabled()) {
      throw const CustomerLocationFailure(
          'A localização do aparelho está desativada. Digite seu endereço ou ajuste o mapa.');
    }
    var permission = await access.permission();
    if (permission == LocationPermission.denied) {
      permission = await access.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const CustomerLocationFailure(
          'A permissão está bloqueada. Você pode digitar seu endereço ou escolher o ponto no mapa.');
    }
    if (![LocationPermission.always, LocationPermission.whileInUse]
        .contains(permission)) {
      throw const CustomerLocationFailure(
          'Permissão não concedida. Você pode digitar seu endereço ou escolher o ponto no mapa.');
    }
    return access.position();
  }
}
