import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/l10n/customer_localizations.dart';
import 'package:chamae_delivery/l10n/locale_controller.dart';
import 'package:chamae_delivery/screens/address_destination_screen.dart';
import 'package:chamae_delivery/widgets/customer_order_history_card.dart';
import 'package:chamae_delivery/widgets/customer_visual.dart';

Widget localized(Widget child) => LocaleScope(
    controller: LocaleController(stored: 'es-PY', persist: (_) async {}),
    child: MaterialApp(
        locale: const Locale('es', 'PY'),
        supportedLocales: const [Locale('pt', 'BR'), Locale('es', 'PY')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child)));
void main() {
  test('all locale catalogs share keys and typed placeholder names', () {
    final pt =
        jsonDecode(File('lib/l10n/app_pt.arb').readAsStringSync()) as Map;
    final keys = pt.keys.where((k) => !k.startsWith('@')).toSet();
    for (final tag in ['pt_BR', 'es', 'es_PY']) {
      final other =
          jsonDecode(File('lib/l10n/app_$tag.arb').readAsStringSync()) as Map;
      expect(other.keys.where((k) => !k.startsWith('@')).toSet(), keys);
      for (final key in keys) {
        final fields = RegExp(r'\{([a-zA-Z]+)\}')
            .allMatches(pt[key] as String)
            .map((m) => m[1])
            .toSet();
        expect(
            RegExp(r'\{([a-zA-Z]+)\}')
                .allMatches(other[key] as String)
                .map((m) => m[1])
                .toSet(),
            fields);
      }
    }
  });
  testWidgets('address helper obtains locale from its own Builder',
      (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(
        localized(Form(child: addressField(input, 'Rua', required: true))));
    await tester.pumpAndSettle();
    expect(find.text('Calle'), findsOneWidget);
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Ingresá Calle'), findsOneWidget);
  });
  testWidgets('history localizes status and preserves monetary string',
      (tester) async {
    await tester.pumpWidget(localized(CustomerOrderHistoryCard(
        id: 'UNIT-ORDER',
        total: '21,00',
        status: 'Concluído',
        date: DateTime(2026, 11, 7),
        onTap: () {})));
    await tester.pumpAndSettle();
    expect(find.text('UNIT-ORDER'), findsOneWidget);
    expect(find.textContaining('Completado'), findsOneWidget);
    expect(find.textContaining('21,00'), findsOneWidget);
  });
  testWidgets('a person name identical to a status is never translated',
      (tester) async {
    await tester.pumpWidget(localized(const CustomerHero(
        title: 'Novo',
        subtitle: 'Seu perfil Chamaê',
        icon: Icons.person,
        localizeTitle: false)));
    await tester.pumpAndSettle();
    expect(find.text('Novo'), findsOneWidget);
    expect(find.text('Nuevo'), findsNothing);
  });
  test('failed language persistence does not claim a saved preference',
      () async {
    final c = LocaleController(
        stored: 'pt-BR',
        persist: (_) async {
          throw StateError('UNIT_STORAGE_FAILURE');
        });
    await expectLater(c.set('es-PY'), throwsA(isA<StateError>()));
    expect(c.locale, const Locale('pt', 'BR'));
  });
}
