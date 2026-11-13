import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/data/customer_sign_in_configuration.dart';
import 'package:chamae_delivery/screens/customer_login_screen.dart';
import 'package:chamae_delivery/screens/customer_access_recovery_screen.dart';
import 'support/customer_flow_fakes.dart';

class RecoveryAuth extends FlowAuth {
  final existingChoices = <bool>[];
  RecoveryAuth()
      : super(const CustomerIdentity(
            uid: 'anonymous-preserved', anonymous: true));
  @override
  Future<void> signIn(CustomerProvider provider,
      {bool useExistingAccount = false}) async {
    calls.add(provider);
    existingChoices.add(useExistingAccount);
  }
}

void main() {
  testWidgets('recovery does not sign in, switch UID or claim password success',
      (tester) async {
    final auth = RecoveryAuth();
    addTearDown(auth.events.close);
    await tester.pumpWidget(MaterialApp(home: CustomerLoginScreen(auth: auth)));
    await tester.scrollUntilVisible(
        find.text('Esqueceu a senha ou perdeu o acesso?'), 200);
    await tester.tap(find.text('Esqueceu a senha ou perdeu o acesso?'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperar acesso'), findsOneWidget);
    expect(auth.calls, isEmpty);
    expect(auth.current?.uid, 'anonymous-preserved');
    await tester.scrollUntilVisible(
        find.textContaining('Nenhuma senha foi redefinida'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Nenhuma senha foi redefinida'), findsOneWidget);
    if (CustomerSignInConfiguration.enabled('google')) {
      await tester.scrollUntilVisible(
          find.text('Voltar e entrar com Google'), -200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Voltar e entrar com Google'));
      await tester.pumpAndSettle();
      expect(auth.calls, [CustomerProvider.google]);
      expect(auth.existingChoices, [false]);
      expect(auth.current?.uid, 'anonymous-preserved');
    }
  });
  testWidgets('copy sends only official recovery address to platform clipboard',
      (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester
        .pumpWidget(const MaterialApp(home: CustomerAccessRecoveryScreen()));
    for (final name in ['Google', 'Apple']) {
      final button = find.text('Copiar endereço $name');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }
    expect(copied, [
      'https://accounts.google.com/signin/recovery',
      'https://iforgot.apple.com/'
    ]);
  });
  testWidgets(
      'clipboard rejection keeps official address and never claims success',
      (tester) async {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard-denied');
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester
        .pumpWidget(const MaterialApp(home: CustomerAccessRecoveryScreen()));
    await tester.tap(find.text('Copiar endereço Google'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível copiar'), findsOneWidget);
    expect(find.textContaining('Endereço oficial copiado'), findsNothing);
    expect(find.text('https://accounts.google.com/signin/recovery'),
        findsOneWidget);
  });
  testWidgets('recovery respects provider gate and enlarged text at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: const CustomerAccessRecoveryScreen()));
    await tester.pumpAndSettle();
    for (final provider in ['Google', 'Apple']) {
      final button =
          find.widgetWithText(OutlinedButton, 'Voltar e entrar com $provider');
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.widget<OutlinedButton>(button).onPressed != null,
          CustomerSignInConfiguration.enabled(provider.toLowerCase()));
    }
    expect(tester.takeException(), isNull);
  });
}
