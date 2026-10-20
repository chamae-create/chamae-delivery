import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';

// The live dialog and local visual harness share exactly this presentation.
class PixPaymentPresentation extends StatelessWidget {
  final double totalBRL;
  final Uint8List? qrBytes;
  final String? qrCode, errorMessage;
  final String createStatus, paymentStatus;
  final bool paymentApproved;
  final VoidCallback onRetry;
  const PixPaymentPresentation(
      {super.key,
      required this.totalBRL,
      this.qrBytes,
      this.qrCode,
      this.errorMessage,
      required this.createStatus,
      required this.paymentStatus,
      required this.paymentApproved,
      required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final waitingForQr = !paymentApproved &&
        errorMessage == null &&
        (qrCode == null || qrCode!.isEmpty);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                paymentApproved
                    ? Icons.check_circle_rounded
                    : Icons.pix_rounded,
                color: paymentApproved ? Colors.green : Colors.teal,
                size: 26,
              ),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(
                paymentApproved ? 'PIX Aprovado!' : 'Pagamento via PIX',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            paymentApproved
                ? 'Recebimento confirmado pelo Mercado Pago'
                : waitingForQr
                    ? 'Gerando PIX seguro...'
                    : 'Confirmação automática ativa',
            style: TextStyle(
              fontSize: 12,
              color: paymentApproved
                  ? Colors.green.shade800
                  : AppColors.textSecondary,
              fontWeight: paymentApproved ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (paymentApproved) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.accentGreen,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Pagamento Confirmado!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentGreen,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Abrindo acompanhamento do pedido...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (errorMessage != null) ...[
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
              ] else if (waitingForQr) ...[
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.primaryYellow,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Preparando seu PIX...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else ...[
                if (qrBytes != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Image.memory(
                      qrBytes!,
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    width: 180,
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 80,
                      color: Colors.black54,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Total: R\$ ${_formatMoney(totalBRL)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E2124),
                  ),
                ),
                const SizedBox(height: 10),
                if (qrCode != null && qrCode!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            qrCode!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 17,
                          ),
                          tooltip: 'Copiar PIX Copia e Cola',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: qrCode!,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Código PIX Copia e Cola copiado!',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.shade300,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Aguardando confirmação do pagamento...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  paymentStatus == 'Pago'
                      ? 'Pagamento confirmado'
                      : 'Aguardando pagamento',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (errorMessage != null && createStatus != 'error')
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        if (!paymentApproved)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              createStatus == 'error' ? 'Fechar' : 'Fechar',
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  String _formatMoney(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
}
