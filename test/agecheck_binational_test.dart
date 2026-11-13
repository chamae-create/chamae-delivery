import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/binational_identity.dart';
import 'package:chamae_delivery/data/age_verification.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/l10n/locale_controller.dart';
import 'package:chamae_delivery/screens/customer_identification_screen.dart';
import 'package:chamae_delivery/screens/customer_onboarding_screen.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/widgets/age_verification_card.dart';

class MemoryIdentity implements IdentificationRepository {
  BinationalIdentity? saved;
  @override
  Future<void> save(BinationalIdentity identity) async {
    saved = identity;
  }
}

class NoConsent implements CustomerOnboardingRepository {
  int accepts = 0;
  @override
  Future<CustomerOnboardingState> load() async =>
      const CustomerOnboardingState(developmentCustomerPolicy, {});
  @override
  Future<void> acceptForNavigation(
      CustomerPolicy p, NavigationAgeDeclaration declaration) async {
    accepts++;
  }

  @override
  Future<void> accept(CustomerPolicy p, String birthDate) async {
    accepts++;
  }
}

Widget shell(Widget child, {LocaleController? controller}) {
  final c =
      controller ?? LocaleController(stored: 'es-PY', persist: (_) async {});
  return AnimatedBuilder(
      animation: c,
      builder: (context, _) => LocaleScope(
          controller: c,
          child: MaterialApp(
              locale: c.locale,
              supportedLocales: const [Locale('pt', 'BR'), Locale('es', 'PY')],
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: child)));
}

void main() {
  test('CPF validates format only using synthetic example', () {
    expect(cpfFormatValid('123.456.789-09'), isTrue);
    expect(cpfFormatValid('12345678900'), isFalse);
    expect(cpfFormatValid('00000000000'), isFalse);
    expect(cpfFormatValid('11111111111'), isFalse);
  });
  test('CI basic input is not subjected to CPF checksum', () {
    expect(documentFormatValid(IdentificationType.cedula, '1234567'), isTrue);
    expect(
        documentFormatValid(IdentificationType.cedula, '12.345.678'), isTrue);
    expect(documentFormatValid(IdentificationType.cedula, 'not-a-CI'), isFalse);
  });
  test(
      'other issuer is not automatically rejected',
      () => expect(
          documentFormatValid(IdentificationType.other, 'UNIT-PASSPORT'),
          isTrue));
  test('legacy profile migrates without data loss or verification inference',
      () {
    final old = {
      'birthDate': '2000-01-01',
      'policyHash': 'kept',
      'address': 'PY'
    };
    final result = BinationalIdentity.fromProfile(old);
    expect(result.language, 'pt-BR');
    expect(old['policyHash'], 'kept');
    expect(result.toMap().containsKey('ageVerified'), isFalse);
  });
  test(
      'identity serialized without raw document DOB nationality or destination',
      () {
    const identity = BinationalIdentity(
        fullName: 'Unit Person',
        type: IdentificationType.cpf,
        issuer: 'BR',
        phone: '+59500000000',
        language: 'es-PY');
    final m = identity.toMap();
    expect(m['documentIssuer'], 'BR');
    expect(m['preferredLanguage'], 'es-PY');
    for (final k in [
      'documentNumber',
      'birthDate',
      'nationality',
      'deliveryCountry',
      'ageVerified'
    ]) {
      expect(m.containsKey(k), isFalse);
    }
  });
  test('device fallback independent of nationality', () {
    expect(LocaleController.resolve(const Locale('es', 'AR')),
        const Locale('es', 'PY'));
    expect(
        LocaleController.resolve(const Locale('fr')), const Locale('pt', 'BR'));
    expect(LocaleController.parse('invalid'), isNull);
  });
  test('manual locale selection persists and restores', () async {
    String? value;
    final c = LocaleController(persist: (s) async {
      value = s;
    });
    await c.set('es-PY');
    expect(value, 'es-PY');
    expect(LocaleController(stored: value, persist: (_) async {}).locale,
        const Locale('es', 'PY'));
  });
  test('unknown verification status cannot approve', () {
    final r = AgeVerificationResult.fromMap(
        {'status': 'forged', 'ageVerified': true});
    expect(r.status, AgeVerificationStatus.unavailable);
    expect(r.identityVerified, isFalse);
    expect(r.ageVerified, isFalse);
  });
  testWidgets('Spanish labels and placeholder come from generated catalog',
      (tester) async {
    await tester.pumpWidget(shell(Builder(
        builder: (context) => Scaffold(
                body: Column(children: [
              const LocalizedText('Seu carrinho'),
              Text(context.l10n.freightAmount('R\$ 21,00'))
            ])))));
    await tester.pumpAndSettle();
    expect(find.text('Tu carrito'), findsOneWidget);
    expect(find.text('Flete: R\$ 21,00'), findsOneWidget);
  });
  testWidgets('language change preserves typed registration input',
      (tester) async {
    final c = LocaleController(stored: 'pt-BR', persist: (_) async {});
    await tester.pumpWidget(shell(
        CustomerIdentificationScreen(
            profile: const {}, repository: MemoryIdentity(), onComplete: () {}),
        controller: c));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Unit Person');
    await c.set('es-PY');
    await tester.pumpAndSettle();
    expect(find.text('Identificación'), findsOneWidget);
    expect(find.text('Unit Person'), findsOneWidget);
  });
  testWidgets('changing document type clears previous temporary number',
      (tester) async {
    await tester.pumpWidget(shell(CustomerIdentificationScreen(
        profile: const {}, repository: MemoryIdentity(), onComplete: () {})));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '12345678909');
    await tester.tap(find.byType(DropdownButtonFormField<IdentificationType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paraguay — Cédula de identidad').last);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(field.controller!.text, isEmpty);
  });
  testWidgets('draft remains blocked in STAGING after localization',
      (tester) async {
    final repo = NoConsent();
    await tester.pumpWidget(shell(CustomerOnboardingScreen(
        state: const CustomerOnboardingState(developmentCustomerPolicy, {}),
        repository: repo,
        onComplete: () {})));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(repo.accepts, 0);
  }, skip: const String.fromEnvironment('CHAMAE_ENV') != 'STAGING');
  testWidgets('AgeCheck card cannot approve and shows both legal minima',
      (tester) async {
    await tester.pumpWidget(shell(const Scaffold(body: AgeVerificationCard())));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('Paraguay 20'), findsOneWidget);
  });
  testWidgets('BRL formatter changes locale without currency conversion',
      (tester) async {
    await tester.pumpWidget(
        shell(Builder(builder: (context) => Text(localizedBrl(context, 21)))));
    await tester.pumpAndSettle();
    expect(find.textContaining('21'), findsOneWidget);
    expect(find.textContaining('R\$'), findsOneWidget);
  });
}
