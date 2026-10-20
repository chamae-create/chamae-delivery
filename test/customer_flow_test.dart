import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/screens/customer_session_gate.dart';
import 'package:chamae_delivery/screens/customer_login_screen.dart';
import 'package:chamae_delivery/screens/customer_onboarding_screen.dart';
import 'package:chamae_delivery/screens/splash_screen.dart';
import 'support/customer_flow_fakes.dart';

class DeniedOnboarding extends FlowOnboarding {
  @override
  Future<CustomerOnboardingState> load() async => throw FirebaseException(
      plugin: 'cloud_firestore', code: 'permission-denied');
}

Widget gate(FlowAuth auth, FlowOnboarding onboarding, FlowWorkspace workspace,
        {Key? key}) =>
    MaterialApp(
        key: key,
        home: SplashScreen(
            initialize: () async {},
            destination: CustomerSessionGate(
                auth: auth,
                onboarding: (_) => onboarding,
                workspace: (_) => workspace,
                catalog: (address) => Scaffold(
                    body: Text(
                        'Catálogo • ${address?.addressText ?? 'sem destino'}')),
                destination: (complete) => Scaffold(
                        body: Column(children: [
                      const Text('Etapa endereço'),
                      TextButton(
                          onPressed: () async {
                            await workspace.save(
                                {'lastAddress': testCustomerAddress.toMap()});
                            complete(testCustomerAddress);
                          },
                          child: const Text('Destino confirmado'))
                    ])))));

Future<void> accept(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byType(TextField), -200,
      scrollable: find.byType(Scrollable).first);
  await tester.enterText(find.byType(TextField).first, '01/01/2000');
  for (final text in [
    'Li e aceito os Termos de Uso',
    'Li e estou ciente da Política de Privacidade',
    'Estou ciente das regras para bebidas alcoólicas'
  ]) {
    await tester.scrollUntilVisible(find.text(text), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(find.text('Continuar'), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('permission denied is reported as access failure after login',
      (tester) async {
    final auth = FlowAuth(const CustomerIdentity(uid: 'buyer'));
    addTearDown(auth.events.close);
    await tester.pumpWidget(gate(auth, DeniedOnboarding(), FlowWorkspace()));
    await tester.pumpAndSettle();
    expect(find.textContaining('acesso aos dados foi negado'), findsOneWidget);
    expect(find.textContaining('Confira a conexão'), findsNothing);
    expect(auth.current?.uid, 'buyer');
  });
  testWidgets(
      'first visit: splash, Google, versioned consent, destination, catalog',
      (tester) async {
    final auth = FlowAuth(),
        onboarding = FlowOnboarding(),
        workspace = FlowWorkspace();
    addTearDown(auth.events.close);
    await tester.pumpWidget(gate(auth, onboarding, workspace));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo ao Chamaê'), findsOneWidget);
    expect(onboarding.loads, 0);
    await tester.tap(find.text('Continuar com Google'));
    await tester.pumpAndSettle();
    expect(auth.calls, [CustomerProvider.google]);
    expect(find.text('Vamos começar'), findsOneWidget);
    await accept(tester);
    expect(onboarding.acceptCalls, 1);
    expect(onboarding.profile['acceptedAt'], isNotNull);
    expect(find.text('Etapa endereço'), findsOneWidget);
    await tester.tap(find.text('Destino confirmado'));
    await tester.pumpAndSettle();
    expect(find.text('Catálogo • Rua de teste, 1'), findsOneWidget);
  });
  testWidgets(
      'returning valid session reuses confirmed address without login or terms',
      (tester) async {
    final auth =
        FlowAuth(const CustomerIdentity(uid: 'buyer', name: 'Cliente'));
    final onboarding = FlowOnboarding(accepted: true),
        workspace = FlowWorkspace()
          ..data = {'lastAddress': testCustomerAddress.toMap()};
    addTearDown(auth.events.close);
    await tester.pumpWidget(gate(auth, onboarding, workspace));
    await tester.pumpAndSettle();
    expect(find.text('Catálogo • Rua de teste, 1'), findsOneWidget);
    expect(find.text('Vamos começar'), findsNothing);
    expect(auth.calls, isEmpty);
    expect(onboarding.acceptCalls, 0);
  });
  testWidgets('changed document version requests new consent', (tester) async {
    final auth = FlowAuth(const CustomerIdentity(uid: 'buyer'));
    final onboarding = FlowOnboarding(accepted: true);
    onboarding.profile['termsVersion'] = 'TEST-OLDER';
    addTearDown(auth.events.close);
    await tester.pumpWidget(gate(auth, onboarding, FlowWorkspace()));
    await tester.pumpAndSettle();
    expect(find.text('Vamos começar'), findsOneWidget);
    expect(find.text('Etapa endereço'), findsNothing);
  });
  testWidgets('session stream error retries with a fresh subscription',
      (tester) async {
    final auth = FlowAuth(const CustomerIdentity(uid: 'buyer'));
    final workspace = FlowWorkspace()
      ..data = {'lastAddress': testCustomerAddress.toMap()};
    addTearDown(auth.events.close);
    await tester
        .pumpWidget(gate(auth, FlowOnboarding(accepted: true), workspace));
    await tester.pumpAndSettle();
    auth.events.addError(StateError('temporary auth error'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Catálogo • Rua de teste, 1'), findsOneWidget);
  });
  testWidgets('logout disposes private route stack and returns to login',
      (tester) async {
    final auth = FlowAuth(const CustomerIdentity(uid: 'buyer'));
    final workspace = FlowWorkspace()
      ..data = {'lastAddress': testCustomerAddress.toMap()};
    addTearDown(auth.events.close);
    await tester
        .pumpWidget(gate(auth, FlowOnboarding(accepted: true), workspace));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Catálogo • Rua de teste, 1'));
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Pedido privado'))));
    await tester.pumpAndSettle();
    expect(find.text('Pedido privado'), findsOneWidget);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Pedido privado'), findsNothing);
    expect(find.text('Bem-vindo ao Chamaê'), findsOneWidget);
  });
  testWidgets(
      'debug DRAFT opens internally and continues without official acceptance',
      (tester) async {
    final repository = FlowOnboarding(policy: developmentCustomerPolicy);
    var completed = false;
    await tester.pumpWidget(MaterialApp(
        home: CustomerOnboardingScreen(
            state: CustomerOnboardingState(repository.policy, {}),
            repository: repository,
            onComplete: () => completed = true)));
    await tester.scrollUntilVisible(find.text('Termos de Uso'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Termos de Uso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Termos de Uso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não é um documento jurídico de produção'),
        findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continuar'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Continuar'))
            .onPressed,
        isNotNull);
    await accept(tester);
    expect(completed, isTrue);
    expect(repository.acceptCalls, 0);
    expect(repository.profile, isEmpty);
    expect((await repository.load()).acceptedCurrent, isFalse);
  });
  test('build mode gates DRAFT without changing official availability', () {
    expect(developmentCustomerPolicy.canContinueOnboarding(debugMode: true),
        isTrue);
    expect(developmentCustomerPolicy.canContinueOnboarding(debugMode: false),
        isFalse);
    expect(testCustomerPolicy.canContinueOnboarding(debugMode: false), isTrue);
    expect(developmentCustomerPolicy.available, isFalse);
    final forged =
        FlowOnboarding(policy: developmentCustomerPolicy, accepted: true);
    expect(
        CustomerOnboardingState(forged.policy, forged.profile).acceptedCurrent,
        isFalse);
  });

  testWidgets('debug DRAFT reaches destination and catalog, resets on logout',
      (tester) async {
    final auth = FlowAuth(const CustomerIdentity(uid: 'buyer'));
    final onboarding = FlowOnboarding(policy: developmentCustomerPolicy);
    final workspace = FlowWorkspace();
    addTearDown(auth.events.close);
    await tester.pumpWidget(gate(auth, onboarding, workspace));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.textContaining('AMBIENTE DE DESENVOLVIMENTO'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.text(
            'AMBIENTE DE DESENVOLVIMENTO — documentos jurídicos ainda não são os oficiais.'),
        findsOneWidget);
    await accept(tester);
    expect(find.text('Etapa endereço'), findsOneWidget);
    expect(onboarding.acceptCalls, 0);
    expect(onboarding.profile, isEmpty);
    await tester.tap(find.text('Destino confirmado'));
    await tester.pumpAndSettle();
    expect(find.text('Catálogo • Rua de teste, 1'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Catálogo • Rua de teste, 1'), findsOneWidget);
    await auth.signOut();
    await tester.pumpAndSettle();
    auth.change(const CustomerIdentity(uid: 'buyer'));
    await tester.pumpAndSettle();
    expect(find.text('Vamos começar'), findsOneWidget);
    expect(onboarding.profile, isEmpty);
  });

  test(
      'birth date rejects future, impossible date, missing and accepts leap day',
      () {
    expect(parseBirthDate('2025-02-29'), isNull);
    expect(parseBirthDate('2999-01-01'), isNull);
    expect(parseBirthDate(''), isNull);
    expect(parseBirthDate('2000-02-29'), isNotNull);
  });
  testWidgets(
      'iOS gives Apple priority and handles cancellation without technical messages',
      (tester) async {
    final auth = FlowAuth()..fail = true;
    addTearDown(auth.events.close);
    await tester.pumpWidget(MaterialApp(home: CustomerLoginScreen(auth: auth)));
    expect(tester.getTopLeft(find.text('Continuar com Apple')).dy,
        lessThan(tester.getTopLeft(find.text('Continuar com Google')).dy));
    await tester.tap(find.text('Continuar com Apple'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Não foi possível entrar agora'), findsOneWidget);
    expect(find.textContaining('FirebaseException'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('login/onboarding remain usable at $width and enlarged text',
        (tester) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FlowAuth();
      addTearDown(auth.events.close);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!),
          home: CustomerLoginScreen(auth: auth)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Continuar com Apple'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Continuar com Apple'), findsOneWidget);
    });
  }
}
