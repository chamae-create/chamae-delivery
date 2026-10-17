import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/chamae_logo.dart';

// Protótipo desativado, mantido apenas como referência de desenvolvimento.
// Motoboy não acessa orders.
// Dados de entrega serão fornecidos por courierDeliveries sanitizado.
// Nenhuma consulta ou atualização é iniciada por esta tela, mesmo aberta
// diretamente. A integração depende do futuro backend e app de entregadores.
class MotoboyAppScreen extends StatelessWidget {
  const MotoboyAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: AppColors.primaryGold,
              title: const Row(
                children: [
                  ChamaeOfficialLogo(size: 34),
                  SizedBox(width: 10),
                  Text(
                    'App do Motoboy',
                    style: TextStyle(
                      color: AppColors.deepBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Acesso de entregadores indisponível neste aplicativo.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
