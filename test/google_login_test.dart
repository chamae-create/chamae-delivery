import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/screens/customer_login_screen.dart';
import 'support/customer_flow_fakes.dart';

class LoginAuth extends FlowAuth {
  final pending = Completer<void>();
  final attempts = <bool>[];
  bool conflict = false;
  LoginAuth()
      : super(const CustomerIdentity(uid: 'anonymous-uid', anonymous: true));
  @override
  Future<void> signIn(CustomerProvider provider,
      {bool useExistingAccount = false}) async {
    attempts.add(useExistingAccount);
    if (conflict && !useExistingAccount) {
      throw const CustomerAuthFailure(
          'Conta já vinculada. Sem mesclagem automática.',
          existingAccount: true);
    }
    await pending.future;
  }
}

void main() {
  testWidgets(
      'Google loading prevents repeated clicks and resets after completion',
      (tester) async {
    final auth = LoginAuth();
    addTearDown(auth.events.close);
    await tester.pumpWidget(MaterialApp(home: CustomerLoginScreen(auth: auth)));
    await tester.tap(find.text('Continuar com Google'));
    await tester.pump();
    await tester.tap(find.text('Continuar com Google'));
    await tester.pump();
    expect(auth.attempts, [false]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    auth.pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Continuar com Google'))
            .onPressed,
        isNotNull);
  });

  for (final switchAccount in [false, true]) {
    testWidgets(
        'Google conflict requires explicit choice: switch=$switchAccount',
        (tester) async {
      final auth = LoginAuth()..conflict = true;
      auth.pending.complete();
      addTearDown(auth.events.close);
      await tester
          .pumpWidget(MaterialApp(home: CustomerLoginScreen(auth: auth)));
      await tester.tap(find.text('Continuar com Google'));
      // The loading indicator intentionally keeps animating behind the dialog.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, [false]);
      expect(find.textContaining('poderão ficar inacessíveis'), findsOneWidget);
      await tester.tap(find.text(switchAccount ? 'Trocar de conta' : 'Voltar'));
      await tester.pumpAndSettle();
      expect(auth.attempts, switchAccount ? [false, true] : [false]);
      expect(auth.current?.uid, 'anonymous-uid');
    });
  }
}
