import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:chamae_delivery/data/customer_location.dart';

class TestPosition extends Fake implements Position {}

class Access implements LocationAccess {
  bool on = true;
  LocationPermission initial = LocationPermission.denied,
      answer = LocationPermission.whileInUse;
  int prompts = 0, positions = 0;
  @override
  Future<bool> enabled() async => on;
  @override
  Future<LocationPermission> permission() async => initial;
  @override
  Future<LocationPermission> requestPermission() async {
    prompts++;
    return answer;
  }

  @override
  Future<Position> position() async {
    positions++;
    return TestPosition();
  }
}

void main() {
  test(
      'permission prompt waits for explicit request; allowed location is a suggestion',
      () async {
    final access = Access();
    final location = CustomerLocation(access);
    expect(access.prompts, 0);
    expect(access.positions, 0);
    await location.request();
    expect(access.prompts, 1);
    expect(access.positions, 1);
  });
  test('denied permission does not read GPS and offers manual address',
      () async {
    final access = Access()..answer = LocationPermission.denied;
    await expectLater(
        CustomerLocation(access).request(),
        throwsA(isA<CustomerLocationFailure>().having((e) => e.message,
            'manual fallback', contains('digitar seu endereço'))));
    expect(access.positions, 0);
  });
  test('disabled or permanently denied does not repeatedly prompt', () async {
    final access = Access()..on = false;
    await expectLater(CustomerLocation(access).request(),
        throwsA(isA<CustomerLocationFailure>()));
    expect(access.prompts, 0);
    access.on = true;
    access.initial = LocationPermission.deniedForever;
    await expectLater(CustomerLocation(access).request(),
        throwsA(isA<CustomerLocationFailure>()));
    expect(access.prompts, 0);
    expect(access.positions, 0);
  });
}
