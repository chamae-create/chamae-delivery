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

/// Confirmed daily delivery notice; availability remains governed by isStoreOpen.
const deliveryHoursTimeZone = 'America/Campo_Grande';
const deliveryHoursNotice = 'Delivery todos os dias • 08h às 00h';

String storeHoursNotice([DateTime? instant]) => isStoreOpen(instant)
    ? deliveryHoursNotice
    : '$deliveryHoursNotice\n${storeHoursLabel(instant)}';
