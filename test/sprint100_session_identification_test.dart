import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/data/binational_identity.dart';
import 'package:chamae_delivery/screens/customer_identification_screen.dart';
import 'support/customer_flow_fakes.dart';

// Test-only adapter. No document/age provider exists in the application runtime.
class IdentificationFixture implements IdentificationRepository {
  IdentificationFixture(this.profile);
  final FlowOnboarding profile;
  Map<String, dynamic>? sent;
  @override
  Future<void> save(BinationalIdentity identity) async {
    sent = identity.toMap();
    profile.profile.addAll(
        {...sent!, 'identificationSchemaVersion': 1, 'identityRevision': 1});
  }
}

void main() {
  testWidgets(
      'operational identification remains validated without sending raw document',
      (tester) async {
    final auth =
        FlowAuth(const CustomerIdentity(uid: 'synthetic-existing-uid'));
    final profile = FlowOnboarding(accepted: true, identified: false);
    final identification = IdentificationFixture(profile);
    addTearDown(auth.events.close);
    addTearDown(UserSession.clearPersonalData);
    var completed = false;
    await tester.pumpWidget(MaterialApp(
        home: CustomerIdentificationScreen(
            profile: profile.profile,
            repository: identification,
            onComplete: () => completed = true)));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerIdentificationScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Pessoa Sintética');
    await tester.enterText(find.byType(TextField).at(1), '12345678909');
    await tester.enterText(find.byType(TextField).at(3), '+55000000000');
    await tester.scrollUntilVisible(find.byType(FilledButton), 180, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(auth.current?.uid, 'synthetic-existing-uid');
    expect(profile.acceptCalls, 0);
    expect(identification.sent, isNot(contains('documentNumber')));
    expect(identification.sent, isNot(contains('ageVerified')));
    expect(profile.profile['identityRevision'], 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
