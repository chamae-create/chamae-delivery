import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/screens/customer_login_screen.dart';
import 'package:chamae_delivery/screens/customer_public_document_screen.dart';
import 'support/customer_flow_fakes.dart';

void main() {
  for (final privacy in [false, true]) {
    testWidgets(
        'official document available before authentication: privacy=$privacy',
        (tester) async {
      final auth = FlowAuth();
      addTearDown(auth.events.close);
      var loads = 0;
      await tester.pumpWidget(MaterialApp(
          home: CustomerLoginScreen(
              auth: auth,
              loadPublicPolicy: () async {
                loads++;
                return testCustomerPolicy;
              })));
      final link =
          find.text(privacy ? 'Política de Privacidade' : 'Termos de Uso');
      await tester.scrollUntilVisible(link, 250);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(
          find.text(privacy
              ? testCustomerPolicy.privacyText
              : testCustomerPolicy.termsText),
          findsOneWidget);
      expect(auth.current, isNull);
      expect(loads, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(auth.current, isNull);
    });
  }
  testWidgets('draft never shown as official or accepted; retry reads again',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
        home: CustomerPublicDocumentScreen(
            privacy: true,
            loadPolicy: () async {
              loads++;
              return loads == 1
                  ? developmentCustomerPolicy
                  : testCustomerPolicy;
            })));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum aceite foi registrado'), findsOneWidget);
    expect(find.text(developmentCustomerPolicy.privacyText), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text(testCustomerPolicy.privacyText), findsOneWidget);
    expect(loads, 2);
  });
  testWidgets('read failure does not expose backend details or invent a policy',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CustomerPublicDocumentScreen(
            privacy: false,
            loadPolicy: () async =>
                throw StateError('PRIVATE_BACKEND_DETAIL'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum aceite foi registrado'), findsOneWidget);
    expect(find.textContaining('PRIVATE_BACKEND_DETAIL'), findsNothing);
    expect(find.text(developmentCustomerPolicy.termsText), findsNothing);
  });
}
