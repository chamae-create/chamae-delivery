import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/customer_workspace.dart';
import 'package:chamae_delivery/screens/address_destination_screen.dart';
import 'package:chamae_delivery/screens/address_map_screen.dart';

class MemoryWorkspace implements CustomerWorkspace {
  Map<String, dynamic> data = {};
  bool offline = false;
  @override
  Future<bool> completeOrder(String documentId) async => false;
  @override
  Future<Map<String, dynamic>> read() async {
    if (offline) throw StateError('offline');
    return data;
  }

  @override
  Future<void> save(Map<String, dynamic> fields) async {
    if (offline) throw StateError('offline');
    data.addAll(fields);
  }
}

void main() {
  testWidgets(
      'destination gate never invokes GPS implicitly; last destination is explicitly offered',
      (tester) async {
    final store = MemoryWorkspace()
      ..data = {
        'lastAddress': const DeliveryAddress(
                latitude: -20,
                longitude: -50,
                addressText: 'Último destino',
                street: 'Rua A',
                city: 'Cidade',
                number: '1',
                countryCode: 'BR',
                confirmed: true)
            .toMap()
      };
    var mapCalls = 0;
    await tester.pumpWidget(MaterialApp(
        home: AddressDestinationScreen(
            onboarding: false,
            workspace: store,
            mapPicker: (gps, query) async {
              mapCalls++;
              return null;
            })));
    await tester.pumpAndSettle();
    expect(mapCalls, 0);
    expect(find.text('Reutilizar último destino'), findsOneWidget);
    expect(find.text('Usar minha localização'), findsOneWidget);
    expect(find.text('Digitar endereço'), findsOneWidget);
    expect(find.text('Explorar catálogo sem endereço'), findsOneWidget);
  });
  testWidgets(
      'explicit GPS suggests adjusted map coordinates; review saves Casa and country',
      (tester) async {
    final store = MemoryWorkspace();
    var asked = false;
    await tester.pumpWidget(MaterialApp(
        home: AddressDestinationScreen(
            onboarding: false,
            workspace: store,
            mapPicker: (gps, query) async {
              asked = gps;
              return const AddressMapResult(
                  latitude: -20.02,
                  longitude: -50.03,
                  addressText: 'Rua A',
                  countryCode: 'BR',
                  street: 'Rua A',
                  number: '32',
                  city: 'Cidade');
            })));
    await tester.pumpAndSettle();
    expect(asked, false);
    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();
    expect(asked, true);
    expect(find.text('Destino: Brasil'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Não salvar'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Não salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Casa').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Confirmar destino'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Confirmar destino'));
    await tester.pumpAndSettle();
    final saved = DeliveryAddress.fromMap(
        Map<String, dynamic>.from(store.data['lastAddress']));
    expect(saved.latitude, -20.02);
    expect(saved.longitude, -50.03);
    expect(saved.confirmed, true);
    expect(saved.label, 'Casa');
    expect((store.data['addresses'] as List).length, 1);
  });
  testWidgets(
      'manual street/city and sem número do not request GPS; country PY follows map',
      (tester) async {
    final store = MemoryWorkspace();
    String? searched;
    bool? gpsRequested;
    await tester.pumpWidget(MaterialApp(
        home: AddressDestinationScreen(
            onboarding: false,
            workspace: store,
            mapPicker: (gps, query) async {
              gpsRequested = gps;
              searched = query;
              return const AddressMapResult(
                  latitude: -20.1,
                  longitude: -50.1,
                  addressText: 'Texto livre Brasil',
                  countryCode: 'PY');
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Digitar endereço'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Rua'), 'Rua B');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Cidade'), 'Cidade PY');
    await tester.tap(find.text('Sem número'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar no mapa'));
    await tester.tap(find.text('Confirmar no mapa'));
    await tester.pumpAndSettle();
    expect(gpsRequested, false);
    expect(searched, contains('Rua B'));
    expect(find.text('Destino: Paraguai'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Confirmar destino'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Confirmar destino'));
    await tester.pumpAndSettle();
    expect(store.data['lastAddress']['noNumber'], true);
    expect(store.data['lastAddress']['countryCode'], 'PY');
  });
  testWidgets(
      'unknown country asks fallback; unsupported structured country cannot be confirmed',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: AddressReviewScreen(
            address: DeliveryAddress(
                latitude: -20,
                longitude: -50,
                street: 'Rua',
                city: 'Cidade',
                number: '1'))));
    expect(find.textContaining('Não foi possível identificar o país'),
        findsOneWidget);
    await tester.tap(find.text('Paraguai'));
    await tester.pump();
    expect(find.text('Destino: Paraguai'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: AddressReviewScreen(
            key: ValueKey('other'),
            address: DeliveryAddress(
                latitude: -20,
                longitude: -50,
                street: 'Rua',
                city: 'Cidade',
                number: '1',
                countryCode: 'US'))));
    await tester.scrollUntilVisible(find.text('Confirmar destino'), 200,
        scrollable: find.byType(Scrollable).first);
    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirmar destino'));
    expect(button.onPressed, isNull);
  });
  testWidgets(
      'saved-address failure and cancelled map keep manual entry and retry',
      (tester) async {
    final store = MemoryWorkspace()..offline = true;
    await tester.pumpWidget(MaterialApp(
        home: AddressDestinationScreen(
            workspace: store, mapPicker: (gps, query) async => null)));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();
    expect(find.text('Digitar endereço'), findsOneWidget);
    store.offline = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsNothing);
  });
}
