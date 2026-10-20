import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/screens/address_destination_screen.dart';
import 'package:chamae_delivery/screens/address_map_screen.dart';
import 'package:chamae_delivery/screens/customer_profile_screen.dart';
import 'package:chamae_delivery/widgets/customer_chat_entry.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'support/customer_flow_fakes.dart';

void main() {
  testWidgets('saved address can become default and be deleted without losing cart', (tester) async {
    final saved = testCustomerAddress.toMap();
    final store = FlowWorkspace()..data = {'addresses':[saved], 'lastAddress':saved,
      'cart':[{'id':'p1','quantity':3}]};
    await tester.pumpWidget(MaterialApp(home: AddressDestinationScreen(onboarding: false, workspace: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opções do endereço')); await tester.pumpAndSettle();
    await tester.tap(find.text('Definir como padrão')); await tester.pumpAndSettle();
    expect(store.data['defaultAddress']['label'], 'Casa');
    await tester.tap(find.byTooltip('Opções do endereço')); await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir endereço')); await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir')); await tester.pumpAndSettle();
    expect(store.data['addresses'], isEmpty); expect(store.data['defaultAddress'], isNull);
    expect(store.data['cart'].single['quantity'], 3);
  });
  testWidgets('editing saved coordinates preserves label and creation timestamp', (tester) async {
    final saved = testCustomerAddress.copyWith(createdAtMs:123, updatedAtMs:123).toMap();
    final store = FlowWorkspace()..data = {'addresses':[saved], 'lastAddress':saved};
    await tester.pumpWidget(MaterialApp(home: AddressDestinationScreen(onboarding: false, workspace: store,
      mapPicker: (gps, query) async => const AddressMapResult(latitude:-20.02,longitude:-50.02,
        addressText:'Rua nova', street:'Rua nova', number:'2', city:'Cidade PY',countryCode:'PY'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opções do endereço')); await tester.pumpAndSettle();
    await tester.tap(find.text('Editar endereço')); await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Confirmar destino'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Confirmar destino')); await tester.pumpAndSettle();
    expect(store.data['addresses'].single['label'], 'Casa');
    expect(store.data['lastAddress']['latitude'], -20.02);
    expect(store.data['lastAddress']['countryCode'], 'PY');
    expect(store.data['lastAddress']['createdAtMs'], 123);
    expect(store.data['lastAddress']['updatedAtMs'], greaterThan(123));
  });
  testWidgets('selecting saved destination keeps existing cart', (tester) async {
    final saved = testCustomerAddress.toMap();
    final store = FlowWorkspace()..data = {'addresses':[saved], 'cart':[{'id':'p1','quantity':3}]};
    String? selected;
    await tester.pumpWidget(MaterialApp(home: AddressDestinationScreen(onboarding:false, workspace:store,
      onComplete:(address) => selected = address?.addressText)));
    await tester.pumpAndSettle(); await tester.tap(find.text('Casa')); await tester.pumpAndSettle();
    expect(selected, 'Rua de teste, 1'); expect(store.data['cart'].single['quantity'], 3);
  });
  testWidgets('chat shows unread and updates without any push service', (tester) async {
    final stream = StreamController<Map<String,dynamic>>(); addTearDown(stream.close);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CustomerChatEntry(
      order: const {'_documentId':'o1'}, metadata:stream.stream))));
    stream.add({'unreadCustomer':2}); await tester.pumpAndSettle();
    expect(find.textContaining('2 não lidas'), findsOneWidget);
    stream.add({'unreadCustomer':0}); await tester.pumpAndSettle();
    expect(find.text('Falar com a loja'), findsOneWidget); expect(find.textContaining('não lidas'), findsNothing);
  });
  testWidgets('profile displays provider, declared DOB and internal documents', (tester) async {
    final auth = FlowAuth(const CustomerIdentity(uid:'buyer', name:'Cliente', email:'buyer@example.test',providers:['google.com']));
    addTearDown(auth.events.close);
    await tester.pumpWidget(MaterialApp(home: CustomerProfileScreen(auth:auth,
      onboarding:FlowOnboarding(accepted:true), selectAddress:() async {})));
    await tester.pumpAndSettle();
    expect(find.text('Google'), findsOneWidget); expect(find.text('buyer@example.test'), findsOneWidget);
    expect(find.text('Data declarada: 01/01/2000'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Termos de Uso'), 300, scrollable:find.byType(Scrollable).first);
    await tester.tap(find.text('Termos de Uso')); await tester.pumpAndSettle();
    expect(find.text('TEST FIXTURE TERMS'), findsOneWidget);
  });
}
