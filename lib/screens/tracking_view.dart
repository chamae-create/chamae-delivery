import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/operational_order_id.dart';
import '../core/theme.dart';
import '../data/order_notifications.dart';
import '../l10n/customer_localizations.dart';
import '../widgets/commerce_components.dart';
import '../widgets/customer_chat_entry.dart';
import '../widgets/customer_feedback.dart';
import '../widgets/customer_journey_map.dart';
import '../widgets/customer_visual.dart';
import '../widgets/delivery_pin_card.dart';
import '../widgets/order_confirmation.dart';
import '../widgets/pix_payment_dialog.dart';
import 'customer_profile_screen.dart';

class TrackingView extends StatefulWidget {
  final String orderId;

  final Stream<Map<String, dynamic>?> orderStream;
  final VoidCallback onBack;
  final VoidCallback? onRetry;
  final bool showConfirmation;
  const TrackingView({
    super.key,
    required this.orderId,
    required this.orderStream,
    required this.onBack,
    this.onRetry,
    this.showConfirmation = false,
  });

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<TrackingView> {
  bool _confirmationDismissed = false;
  String get orderId => widget.orderId;
  VoidCallback get onBack => widget.onBack;
  VoidCallback? get onRetry => widget.onRetry;

  @override
  void initState() {
    super.initState();
    if (Firebase.apps.isNotEmpty) {
      unawaited(FirebaseCustomerPushNotifications.ensureRegisteredSilently());
    }
  }

  @override
  void didUpdateWidget(TrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) _confirmationDismissed = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommerceAppBar(title: 'Acompanhar pedido'),
      bottomNavigationBar: CommerceRouteNavigation.bar(context, 2),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: widget.orderStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                child: CustomerFeedback(
                  title: 'Não foi possível acompanhar o pedido.',
                  message: 'Confira sua conexão e tente novamente. Essa falha não confirma o cancelamento do pedido.',
                  icon: Icons.cloud_off_outlined,
                  onRetry: onRetry,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SingleChildScrollView(
                child: CustomerFeedback(
                  title: 'Buscando seu pedido',
                  message: 'Só um instante para conferir as novidades.',
                  loading: true,
                ),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: SingleChildScrollView(
                child: CustomerFeedback(
                  title: 'Pedido indisponível para esta sessão.',
                  message:
                      'Confira se você entrou com a conta usada na compra.',
                  icon: Icons.receipt_long_outlined,
                  onRetry: onRetry,
                ),
              ),
            );
          }

          final status = (data['status'] ?? 'Novo').toString();
          if (widget.showConfirmation &&
              !_confirmationDismissed &&
              canPresentOrderConfirmation(data)) {
            return OrderConfirmationView(
              orderId: orderId,
              data: data,
              statusLabel: customerStatus(status),
              onTrack: () => setState(() => _confirmationDismissed = true),
            );
          }
          final pendingValidation =
              data['financialValidationStatus'] != 'validated' &&
              ['Novo', 'Aguardando pagamento'].contains(status);
          final needsReview =
              data['financialValidationStatus'] == 'rejected' ||
              ['Revisão financeira', 'Revisão de estoque'].contains(status);
          final courier =
              data['courierUid'] is String &&
                  (data['courierUid'] as String).trim().isNotEmpty &&
                  data['courierName'] is String &&
                  (data['courierName'] as String).trim().isNotEmpty
              ? (data['courierName'] as String).trim()
              : [
                  'Novo',
                  'Em Separação',
                  'Aguardando Retirada',
                  'Aguardando pagamento',
                ].contains(status)
              ? 'Aguardando atribuição'
              : 'Entregador não informado';
          final address = data['address']?.toString().trim().isNotEmpty == true
              ? data['address'].toString()
              : 'Endereço não informado';
          final total =
              data['totalBRL'] is num && (data['totalBRL'] as num).isFinite
              ? (data['totalBRL'] as num).toDouble()
              : null;

          final currentStep = pendingValidation || needsReview
              ? -1
              : switch (status) {
                  'Novo' => 0,
                  'Em Separação' || 'Aguardando Retirada' => 1,
                  'Saiu para Entrega' => 2,
                  'Concluído' => 3,
                  _ => -1,
                };

          return SingleChildScrollView(
            padding: CustomerVisual.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CommercePageTitle(
                  title: 'Acompanhar pedido',
                  subtitle: 'Confira as etapas da sua entrega.',
                  onBack: onBack,
                  trailing: onRetry == null
                      ? null
                      : IconButton(
                          tooltip: localizedLabel(context, 'Atualizar'),
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                        ),
                ),
                Semantics(
                  liveRegion: true,
                  child: CustomerHero(
                    title: needsReview
                        ? 'Vamos conferir seu pedido'
                        : pendingValidation && status == 'Novo'
                        ? 'Conferindo seu pedido'
                        : customerStatus(status),
                    subtitle: 'Pedido ${customerOrderLabel(data, orderId)}',
                    icon: status == 'Concluído'
                        ? Icons.check_circle_outline
                        : status == 'Cancelado'
                        ? Icons.cancel_outlined
                        : Icons.two_wheeler_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                if (pendingValidation || needsReview)
                  CustomerFeedback(
                    title: needsReview
                        ? 'Seu pedido precisa de atenção'
                        : 'Estamos conferindo os detalhes',
                    message: needsReview
                        ? 'A confirmação não foi concluída. Confira o pagamento e fale com a loja pelo pedido quando essa opção estiver disponível.'
                        : 'Aguarde a confirmação por aqui antes de fazer outro pedido.',
                    icon: Icons.receipt_long_outlined,
                  ),
                Container(
                  decoration: CustomerVisual.panel(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const labelWidget = LocalizedText(
                        'Total do pedido',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      );
                      final valueWidget = LocalizedText(
                        total == null || pendingValidation
                            ? 'Em confirmação'
                            : customerMoney(total),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkGold,
                        ),
                      );
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                          constraints.maxWidth < 250;
                      if (largeText) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            labelWidget,
                            const SizedBox(height: 4),
                            valueWidget,
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(child: labelWidget),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: valueWidget,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                if (status != 'Cancelado' && status != 'Aguardando pagamento')
                  CommerceOrderTimeline(currentStep: currentStep),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: CustomerVisual.panel(),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          gradient: CustomerVisual.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          size: 22,
                          color: AppTheme.obsidianDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LocalizedText(
                              'Endereço de entrega',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                CustomerOrderSummary(data: data),
                if (data['_documentId'] is String &&
                    data['_hasPendingWrites'] != true)
                  CustomerJourneyMap(
                    orderId: data['_documentId'],
                    status: status,
                  ),
                if (data['pixRequested'] == true &&
                    data['paymentStatus'] != 'Pago' &&
                    status != 'Cancelado' &&
                    total != null &&
                    data['_documentId'] is String)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.pix),
                      label: const LocalizedText('Ver pagamento PIX'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => PixPaymentDialog(
                          orderReference: FirebaseFirestore.instance
                              .collection('orders')
                              .doc(data['_documentId']),
                          orderId: orderId,
                          totalBRL: total,
                          onPaid: () async {},
                        ),
                      ),
                    ),
                  ),
                if (data['financialValidationStatus'] == 'validated' &&
                    data['_documentId'] is String)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CustomerChatEntry(order: data),
                  ),
                if (!['Cancelado', 'Concluído'].contains(status))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: DeliveryPinCard(compact: true),
                  ),

                // Card do Entregador
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: CustomerVisual.panel(),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          gradient: CustomerVisual.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          size: 22,
                          color: AppTheme.obsidianDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LocalizedText(
                              'Entrega',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            LocalizedText(
                              courier,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
