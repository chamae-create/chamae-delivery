/// Mato Grosso do Sul uses UTC-4. Midnight is closed; opening is at 08:00.
bool isStoreOpen([DateTime? instant]) =>
    (instant ?? DateTime.now())
        .toUtc()
        .subtract(const Duration(hours: 4))
        .hour >=
    8;

String storeHoursLabel([DateTime? instant]) => isStoreOpen(instant)
    ? 'Delivery até 00:00'
    : 'Loja fechada • abre às 08:00 (MS)';
