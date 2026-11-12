import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/screens/customer_session_gate.dart';
import 'package:chamae_delivery/screens/customer_identification_screen.dart';
import 'package:chamae_delivery/screens/customer_onboarding_screen.dart';
import 'package:chamae_delivery/screens/address_destination_screen.dart';
import 'package:chamae_delivery/screens/address_map_screen.dart';
import 'package:chamae_delivery/screens/home_screen.dart';
import 'package:chamae_delivery/core/models.dart';
import 'support/customer_flow_fakes.dart';

void main() {
  test(
      'jurisdiction floors reject false, wrong country and lower configured threshold',
      () {
    expect(
        testCustomerPolicy.validDeclaration(
            {'countryCode': 'BR', 'minimumAge': 18, 'declared': true}),
        isTrue);
    expect(
        testCustomerPolicy.validDeclaration(
            {'countryCode': 'PY', 'minimumAge': 18, 'declared': true}),
        isFalse);
    expect(
        testCustomerPolicy.validDeclaration(
            {'countryCode': 'PY', 'minimumAge': 20, 'declared': false}),
        isFalse);
    expect(testCustomerPolicy.legacyNavigationEligible('2020-01-01'), isFalse);
  });
  testWidgets(
      'legitimate personal declaration to actual Home, then restart without identity or DOB',
      (tester) async {
    final auth = FlowAuth(const CustomerIdentity(uid: 'synthetic-navigation'));
    final repository = FlowOnboarding(identified: false),
        workspace = FlowWorkspace();
    addTearDown(auth.events.close);
    Widget app() => MaterialApp(
        home: CustomerSessionGate(
            auth: auth,
            onboarding: (_) => repository,
            workspace: (_) => workspace,
            catalog: (address) => DeliveryHomeScreen(
                products: Stream.value(<Product>[]),
                workspace: workspace,
                initialAddress: address)));
    Future<void> explore() async {
      final explore = find.text('Explorar catálogo sem endereço');
      await tester.scrollUntilVisible(explore, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(explore);
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryHomeScreen), findsOneWidget);
      expect(find.byType(CustomerIdentificationScreen), findsNothing);
    }

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(CustomerOnboardingScreen), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    for (final key in [const Key('navigation-age-declaration')]) {
      final f = find.byKey(key);
      await tester.scrollUntilVisible(f, 100,
          scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(f), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(f);
    }
    for (final text in [
      'Li e aceito os Termos de Uso',
      'Li e estou ciente da Política de Privacidade',
      'Estou ciente das regras para bebidas alcoólicas'
    ]) {
      final f = find.text(text);
      await tester.scrollUntilVisible(f, 100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }
    final next = find.text('Continuar');
    await tester.scrollUntilVisible(next, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(next);
    await tester.pumpAndSettle();
    await explore();
    for (final key in [
      'phone',
      'birthDate',
      'documentType',
      'identificationSchemaVersion'
    ]) {
      expect(repository.profile.containsKey(key), isFalse);
    }
    expect(repository.acceptCalls, 1);
    expect(repository.profile['navigationAgeDeclaration'],
        {'countryCode': 'BR', 'minimumAge': 18, 'declared': true});
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await explore();
    expect(repository.acceptCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'unsaved destination completes session without any workspace write',
      (tester) async {
    final workspace = FlowWorkspace();
    DeliveryAddress? selected;
    await tester.pumpWidget(MaterialApp(
        home: AddressDestinationScreen(
            workspace: workspace,
            mapPicker: (_, __) async => const AddressMapResult(
                latitude: -20,
                longitude: -50,
                addressText: 'Synthetic',
                countryCode: 'BR',
                street: 'Synthetic street',
                number: '1',
                city: 'Synthetic city'),
            onComplete: (value) => selected = value)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar minha localização'));
    await tester.pumpAndSettle();
    final confirm = find.text('Confirmar destino');
    await tester.scrollUntilVisible(confirm, 150,
        scrollable: find
            .descendant(
                of: find.byType(AddressReviewScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(selected?.label, 'Não salvar');
    expect(workspace.data, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('legacy unsaved destination is not restored on restart',
      (tester) async {
    final auth = FlowAuth(const CustomerIdentity(uid: 'synthetic-legacy'));
    addTearDown(auth.events.close);
    final repo = FlowOnboarding(accepted: true, identified: false);
    final workspace = FlowWorkspace()
      ..data = {
        'lastAddress': {...testCustomerAddress.toMap(), 'label': 'Não salvar'}
      };
    await tester.pumpWidget(MaterialApp(
        home: CustomerSessionGate(
            auth: auth,
            onboarding: (_) => repo,
            workspace: (_) => workspace,
            catalog: (_) => const Text('UNEXPECTED_CATALOG'))));
    await tester.pumpAndSettle();
    expect(find.byType(AddressDestinationScreen), findsOneWidget);
    expect(find.text('Reutilizar último destino'), findsNothing);
    expect(find.text('UNEXPECTED_CATALOG'), findsNothing);
  });
}
