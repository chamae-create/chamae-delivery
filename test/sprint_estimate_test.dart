import 'package:chamae_delivery/main_staging.dart' show initializeCustomerStagingSession;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/journey_estimate.dart';
import 'package:chamae_delivery/widgets/customer_journey_map.dart';

Map<String, dynamic> payload() => {
      'available': true,
      'illustrativeOnly': true,
      'liveGps': false,
      'provider': 'google-routes',
      'orderId': 'test-order',
      'status': 'Saiu para Entrega',
      'durationSeconds': 120,
      'departureAtMs': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
      'origin': {'latitude': -22.1, 'longitude': -55.1},
      'destination': {'latitude': -22.0, 'longitude': -55.0}
    };
void main() {
  test('ETA is capped illustration and never implies arrival', () {
    final e = JourneyEstimate.parse(payload())!;
    expect(e.progress(DateTime.now().toUtc()), 0.9);
    expect(e.overdue(DateTime.now().toUtc()), true);
  });
  test(
      'future departure and undeparted estimate cannot show completed animation',
      () {
    final p = payload();
    p['departureAtMs'] = null;
    expect(JourneyEstimate.parse(p)!.progress(DateTime.now()), 0);
    p['departureAtMs'] =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    expect(JourneyEstimate.parse(p)!.progress(DateTime.now()), 0);
  });
  test('invalid or actual GPS projection is rejected', () {
    final p = payload();
    p['liveGps'] = true;
    expect(JourneyEstimate.parse(p), null);
    p['liveGps'] = false;
    p['durationSeconds'] = 0;
    expect(JourneyEstimate.parse(p), null);
  });
  testWidgets(
      'illustration identifies absence of GPS and never changes status at overdue ETA',
      (tester) async {
    var requests = 0;
    double? progress;
    await tester.pumpWidget(MaterialApp(
        home: CustomerJourneyMap(
            orderId: 'test-order',
            status: 'Saiu para Entrega',
            estimateLoader: (_) async {
              requests++;
              return payload();
            },
            illustrationBuilder: (p, e) {
              progress = p;
              return const SizedBox();
            })));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('não é GPS real'), findsOneWidget);
    expect(find.textContaining('não confirma chegada'), findsOneWidget);
    expect(find.textContaining('Estimativa excedida'), findsOneWidget);
    expect(progress, lessThanOrEqualTo(0.9));
    expect(requests, 1);
    await tester.pump(const Duration(seconds: 15));
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('terminal status hides map and triggers no request',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
        home: CustomerJourneyMap(
            orderId: 'test-order',
            status: 'Concluído',
            estimateLoader: (_) async {
              requests++;
              return payload();
            },
            illustrationBuilder: (_, __) => const SizedBox())));
    await tester.pump();
    expect(requests, 0);
    expect(find.textContaining('Moto ilustrativa'), findsNothing);
  });
  testWidgets('late estimate from previous order cannot appear for a new order',
      (tester) async {
    final data = payload();
    data['orderId'] = 'wrong-order';
    await tester.pumpWidget(MaterialApp(
        home: CustomerJourneyMap(
            orderId: 'test-order',
            status: 'Saiu para Entrega',
            estimateLoader: (_) async => data,
            illustrationBuilder: (_, __) => const SizedBox())));
    await tester.pump();
    expect(find.textContaining('Moto ilustrativa'), findsNothing);
  });

  test('staging entrypoint rejects missing explicit configuration before Firebase',()async{
    await expectLater(initializeCustomerStagingSession(),throwsStateError);
  });
}
