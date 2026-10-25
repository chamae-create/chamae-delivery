/// A proposal acknowledgment is not an accepted purchase. Monetary values and
/// stock transitions stay in the existing backend; this only gates client UX.
bool orderIsConfirmed(Map<String, dynamic> data) =>
    data['financialValidationStatus'] == 'validated' &&
    data['_hasPendingWrites'] != true &&
    (!(data['pixRequested'] == true || data['paymentMethod'] == 'PIX') ||
        (data['paymentStatus'] == 'Pago' &&
            data['mercadoPagoCreateStatus'] != 'error' &&
            !['cancelled', 'canceled', 'rejected', 'expired', 'refunded', 'charged_back']
                .contains(data['mercadoPagoStatus']))) &&
    !['error', 'requires_review', 'processing']
        .contains(data['stockReservationStatus']) &&
    !['error', 'requires_review', 'processing']
        .contains(data['stockProcessingStatus']) &&
    [
      'Novo',
      'Em Separação',
      'Aguardando Retirada',
      'Saiu para Entrega',
      'Concluído'
    ].contains(data['status']);
