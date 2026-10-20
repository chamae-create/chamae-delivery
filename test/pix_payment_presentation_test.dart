import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/theme.dart';
import 'package:chamae_delivery/widgets/pix_payment_presentation.dart';

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('PIX states fit small Android at text $scale', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final mode in [
        'creating',
        'qr',
        'waiting',
        'paid',
        'expired',
        'error',
        'retry'
      ]) {
        var retried = false;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: PixPaymentPresentation(
            totalBRL: 2491.31,
            qrCode: mode == 'creating' ? null : 'LOCAL-SEM-VALOR-DE-PAGAMENTO',
            createStatus: mode == 'error' ? 'error' : 'created',
            paymentStatus: mode == 'paid' ? 'Pago' : 'Aguardando confirmação',
            paymentApproved: mode == 'paid',
            errorMessage: ['expired', 'error', 'retry'].contains(mode)
                ? 'Pagamento local indisponível. Confira o pedido e tente novamente.'
                : null,
            onRetry: () {
              retried = true;
            },
          )),
        ));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: mode);
        if (mode == 'retry') {
          expect(find.text('Tentar novamente').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Tentar novamente'));
          expect(retried, isTrue);
        }
        if (mode != 'paid') {
          expect(find.text('Fechar').hitTestable(), findsOneWidget);
        }
      }
    });
  }
}
