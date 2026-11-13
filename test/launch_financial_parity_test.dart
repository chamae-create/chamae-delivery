import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/core/launch_financial_policy.dart';

void main() {
  test('matches backend launch v1.0 constants and zero active fees', () {
    expect(
      LaunchFinancialPolicy.policyVersion,
      'launch-v1.0-customer-fee-suspended',
    );
    expect(LaunchFinancialPolicy.customerFeeBps, 0);
    expect(LaunchFinancialPolicy.appliedMerchantCommissionBps, 0);
    expect(LaunchFinancialPolicy.futureMerchantCommissionBps, 300);
    expect(
      LaunchFinancialPolicy.merchantCommissionStatus,
      'pending_formalization',
    );
    expect(LaunchFinancialPolicy.loumakTransfersEnabled, isFalse);
  });

  test('computes centavo-exact totals without IEEE-754 float drift', () {
    // 19.99 * 3 + 7.25 in double equals 67.22000000000001; centavos prevent drift.
    final subtotalCentavos = LaunchFinancialPolicy.itemsSubtotalCentavos([
      (unitPrice: 19.99, quantity: 3),
    ]);
    final deliveryCentavos = LaunchFinancialPolicy.toCentavos(7.25);
    final amounts = LaunchFinancialPolicy.calculateOrderAmounts(
      subtotalCentavos: subtotalCentavos,
      deliveryFeeCentavos: deliveryCentavos,
      requirePositiveTotal: true,
    );

    expect(amounts.subtotalCentavos, 5997);
    expect(amounts.deliveryFeeCentavos, 725);
    expect(amounts.customerFeeCentavos, 0);
    expect(amounts.merchantFeeCentavos, 0);
    expect(amounts.merchantNetCentavos, 5997);
    expect(amounts.platformFeeCentavos, 0);
    expect(amounts.totalCentavos, 6722);
    expect(amounts.itemsTotal, 59.97);
    expect(amounts.deliveryFee, 7.25);
    expect(amounts.customerFee, 0.0);
    expect(amounts.merchantFee, 0.0);
    expect(amounts.merchantNet, 59.97);
    expect(amounts.platformFee, 0.0);
    expect(amounts.totalBRL, 67.22);
  });

  test('accumulates 0.10 + 0.20 and per-unit centavo multiplication safely', () {
    final subtotalCentavos = LaunchFinancialPolicy.itemsSubtotalCentavos([
      (unitPrice: 0.10, quantity: 1),
      (unitPrice: 0.20, quantity: 1),
      (unitPrice: 19.90, quantity: 2),
    ]);
    final amounts = LaunchFinancialPolicy.calculateOrderAmounts(
      subtotalCentavos: subtotalCentavos,
      deliveryFeeCentavos: LaunchFinancialPolicy.toCentavos(12.15),
      requirePositiveTotal: true,
    );

    expect(amounts.subtotalCentavos, 4010);
    expect(amounts.itemsTotal, 40.10);
    expect(amounts.totalCentavos, 5225);
    expect(amounts.totalBRL, 52.25);
  });

  test('rejects negative, non-finite, or zero submitted order totals', () {
    expect(() => LaunchFinancialPolicy.toCentavos(-0.01), throwsArgumentError);
    expect(
      () => LaunchFinancialPolicy.toCentavos(double.nan),
      throwsArgumentError,
    );
    expect(
      () => LaunchFinancialPolicy.toCentavos(double.infinity),
      throwsArgumentError,
    );
    expect(
      () => LaunchFinancialPolicy.itemSubtotalCentavos(
        unitPrice: 10,
        quantity: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => LaunchFinancialPolicy.calculateOrderAmounts(
        subtotalCentavos: 0,
        deliveryFeeCentavos: 0,
        requirePositiveTotal: true,
      ),
      throwsArgumentError,
    );
  });
}
