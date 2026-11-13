/// New-order policy only. Never recalculate historical financial snapshots.
class LaunchOrderAmounts {
  final int subtotalCentavos;
  final int deliveryFeeCentavos;
  final int customerFeeCentavos;
  final int merchantFeeCentavos;
  final int merchantNetCentavos;
  final int platformFeeCentavos;
  final int totalCentavos;

  const LaunchOrderAmounts({
    required this.subtotalCentavos,
    required this.deliveryFeeCentavos,
    required this.customerFeeCentavos,
    required this.merchantFeeCentavos,
    required this.merchantNetCentavos,
    required this.platformFeeCentavos,
    required this.totalCentavos,
  });

  String get policyVersion => LaunchFinancialPolicy.policyVersion;
  int get customerFeeBps => LaunchFinancialPolicy.customerFeeBps;
  int get appliedMerchantCommissionBps =>
      LaunchFinancialPolicy.appliedMerchantCommissionBps;
  int get futureMerchantCommissionBps =>
      LaunchFinancialPolicy.futureMerchantCommissionBps;

  double get itemsTotal => LaunchFinancialPolicy.fromCentavos(subtotalCentavos);
  double get deliveryFee =>
      LaunchFinancialPolicy.fromCentavos(deliveryFeeCentavos);
  double get customerFee =>
      LaunchFinancialPolicy.fromCentavos(customerFeeCentavos);
  double get merchantFee =>
      LaunchFinancialPolicy.fromCentavos(merchantFeeCentavos);
  double get merchantNet =>
      LaunchFinancialPolicy.fromCentavos(merchantNetCentavos);
  double get platformFee =>
      LaunchFinancialPolicy.fromCentavos(platformFeeCentavos);
  double get totalBRL => LaunchFinancialPolicy.fromCentavos(totalCentavos);
}

abstract final class LaunchFinancialPolicy {
  // Mirrors functions/launch-financial-policy.js (launchAmounts).
  static const policyVersion = 'launch-v1.0-customer-fee-suspended';
  static const customerFeeBps = 0;
  static const appliedMerchantCommissionBps = 0;
  static const futureMerchantCommissionBps = 300;
  static const merchantCommissionStatus = 'pending_formalization';
  static const loumakTransfersEnabled = false;

  // Match JS IEEE-754 EPSILON shift used in functions/index.js:200.
  static const double _jsNumberEpsilon = 2.220446049250313e-16;

  static int toCentavos(double amount, {String name = 'amount'}) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(amount, name);
    }
    return ((amount + _jsNumberEpsilon) * 100).round();
  }

  static double fromCentavos(int centavos) {
    if (centavos < 0) {
      throw ArgumentError.value(centavos, 'centavos');
    }
    return centavos / 100.0;
  }

  static int itemSubtotalCentavos({
    required double unitPrice,
    required int quantity,
  }) {
    if (quantity < 0) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    return toCentavos(unitPrice, name: 'unitPrice') * quantity;
  }

  static int itemsSubtotalCentavos(
    Iterable<({double unitPrice, int quantity})> items,
  ) {
    var total = 0;
    for (final item in items) {
      total += itemSubtotalCentavos(
        unitPrice: item.unitPrice,
        quantity: item.quantity,
      );
    }
    return total;
  }

  static LaunchOrderAmounts calculateOrderAmounts({
    required int subtotalCentavos,
    int deliveryFeeCentavos = 0,
    bool requirePositiveTotal = false,
  }) {
    if (subtotalCentavos < 0) {
      throw ArgumentError.value(subtotalCentavos, 'subtotalCentavos');
    }
    if (deliveryFeeCentavos < 0) {
      throw ArgumentError.value(deliveryFeeCentavos, 'deliveryFeeCentavos');
    }
    final totalCentavos = subtotalCentavos + deliveryFeeCentavos;
    if (requirePositiveTotal && totalCentavos <= 0) {
      throw ArgumentError('VALOR_PEDIDO_INVALIDO');
    }
    const customerFeeCentavos = 0;
    const merchantFeeCentavos = 0;
    const platformFeeCentavos = customerFeeCentavos + merchantFeeCentavos;
    final merchantNetCentavos = subtotalCentavos - merchantFeeCentavos;
    return LaunchOrderAmounts(
      subtotalCentavos: subtotalCentavos,
      deliveryFeeCentavos: deliveryFeeCentavos,
      customerFeeCentavos: customerFeeCentavos,
      merchantFeeCentavos: merchantFeeCentavos,
      merchantNetCentavos: merchantNetCentavos,
      platformFeeCentavos: platformFeeCentavos,
      totalCentavos: totalCentavos,
    );
  }

  static double customerFee(double subtotal) {
    if (!subtotal.isFinite || subtotal < 0) {
      throw ArgumentError.value(subtotal, 'subtotal');
    }
    return 0;
  }

  static double merchantFee(double subtotal) => customerFee(subtotal);
}
