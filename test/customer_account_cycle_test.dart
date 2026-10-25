import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/data/customer_account.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/screens/customer_account_closure_screen.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'support/customer_flow_fakes.dart';

class AccountDouble implements CustomerAccountRepository {
  final events = StreamController<AccountClosureStatus>.broadcast();
  int reauth = 0, requests = 0, finishes = 0;
  Object? failure;
  Completer<void>? identity;
  @override
  Future<void> reauthenticate() async {
    reauth++;
    if (identity != null) await identity!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<AccountClosureStatus> request() async {
    requests++;
    return AccountClosureStatus.requested;
  }

  @override
  Stream<AccountClosureStatus> watch() => events.stream;
  @override
  Future<void> finishSession() async {
    finishes++;
  }
}

Widget app(Widget child, {double scale = 1}) => MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: child,
    );

Future<void> consent(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byType(CheckboxListTile), 200);
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await tester.scrollUntilVisible(
      find.text('Confirmar identidade e excluir'), 150);
}

void main() {
  test('status parser fails closed and errors never leak SDK/internal details',
      () {
    for (final entry in {
      'requested': AccountClosureStatus.requested,
      'processing': AccountClosureStatus.processing,
      'completed': AccountClosureStatus.completed,
      'blocked': AccountClosureStatus.blocked
    }.entries) {
      expect(accountClosureStatus({'status': entry.key}), entry.value);
    }
    for (final invalid in [
      null,
      {},
      {'status': 'garbage'},
      {'status': 'ready'}
    ]) {
      expect(() => accountClosureStatus(invalid), throwsStateError);
    }
    expect(accountClosureError(StateError('SECRET_INTERNAL')),
        isNot(contains('SECRET_INTERNAL')));
    expect(
        accountClosureError(FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'INTERNAL',
            details: const {'reason': 'ACTIVE_ORDER'})),
        contains('pedido ou pagamento'));
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets(
        'explicit consent, reauth once and durable status at 320px text $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = AccountDouble()..identity = Completer<void>();
      addTearDown(repo.events.close);
      await tester.pumpWidget(
          app(CustomerAccountClosureScreen(repository: repo), scale: scale));
      final button =
          find.widgetWithText(ElevatedButton, 'Confirmar identidade e excluir');
      await tester.scrollUntilVisible(button, 180);
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
      await consent(tester);
      await tester.tap(button);
      await tester.pump();
      expect(repo.reauth, 1);
      expect(repo.requests, 0);
      expect(find.text('Confirmando sua identidade…'), findsOneWidget);
      repo.identity!.complete();
      await tester.pumpAndSettle();
      expect(repo.requests, 1);
      expect(repo.finishes, 0);
      expect(find.text('Exclusão em andamento'), findsOneWidget);
      repo.events.add(AccountClosureStatus.processing);
      await tester.pumpAndSettle();
      expect(repo.finishes, 0);
      repo.events.add(AccountClosureStatus.completed);
      await tester.pumpAndSettle();
      repo.events.add(AccountClosureStatus.completed);
      await tester.pumpAndSettle();
      expect(repo.finishes, 1);
      expect(find.text('Conta excluída'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'cancelled identity never submits deletion; network error never claims completion',
      (tester) async {
    final repo = AccountDouble()
      ..failure = const CustomerAuthFailure('Confirmação cancelada.');
    addTearDown(repo.events.close);
    await tester
        .pumpWidget(app(CustomerAccountClosureScreen(repository: repo)));
    await consent(tester);
    await tester.tap(find.text('Confirmar identidade e excluir'));
    await tester.pumpAndSettle();
    expect(repo.requests, 0);
    expect(repo.finishes, 0);
    expect(find.text('Confirmação cancelada.'), findsOneWidget);
    repo.events.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Conta excluída'), findsNothing);
    expect(find.textContaining('verifique o status'), findsOneWidget);
    repo.events.add(AccountClosureStatus.blocked);
    await tester.pumpAndSettle();
    expect(find.text('Resolva seu pedido antes de continuar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'profile exposes account deletion and preserves existing auth/profile flow',
      (tester) async {
    final repo = AccountDouble();
    addTearDown(repo.events.close);
    final auth = FlowAuth(
        const CustomerIdentity(uid: 'buyer', providers: ['google.com']));
    addTearDown(auth.events.close);
    await tester.pumpWidget(app(CustomerProfileScreen(
        selectAddress: () async {},
        auth: auth,
        onboarding: FlowOnboarding(accepted: true),
        account: repo)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Excluir minha conta'), 200);
    await tester.tap(find.text('Excluir minha conta'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerAccountClosureScreen), findsOneWidget);
    expect(repo.requests, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
