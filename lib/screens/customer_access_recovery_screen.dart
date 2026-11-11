import '../l10n/customer_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/customer_auth.dart';
import '../data/customer_sign_in_configuration.dart';

/// Recovery is owned by the existing identity provider, never a Chamaê password.
class CustomerAccessRecoveryScreen extends StatelessWidget {
  const CustomerAccessRecoveryScreen({super.key});
  static const destinations = {
    CustomerProvider.google: 'https://accounts.google.com/signin/recovery',
    CustomerProvider.apple: 'https://iforgot.apple.com/',
  };

  Future<void> _copy(BuildContext context, String address) async {
    try {
      await Clipboard.setData(ClipboardData(text: address));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: LocalizedText(
                'Endereço oficial copiado. Abra no seu navegador.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: LocalizedText(
                'Não foi possível copiar. Use o endereço exibido abaixo.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const LocalizedText('Recuperar acesso')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        const LocalizedText('Esqueceu a senha?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const LocalizedText(
            'A entrada no Chamaê usa sua conta Google ou Apple. Recupere a senha diretamente no provedor; o Chamaê não recebe nem altera essa senha.'),
        const SizedBox(height: 12),
        const LocalizedText(
            'Depois, volte e entre com a mesma conta usada no cadastro para recuperar seus pedidos e endereços. Criar outra conta não transfere esses dados.'),
        const SizedBox(height: 20),
        for (final provider in CustomerProvider.values)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LocalizedText(
                            provider == CustomerProvider.google
                                ? 'Conta Google'
                                : 'Conta Apple',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SelectableText(destinations[provider]!),
                        TextButton.icon(
                            onPressed: () =>
                                _copy(context, destinations[provider]!),
                            icon: const Icon(Icons.copy_outlined),
                            label: LocalizedText(
                                provider == CustomerProvider.google
                                    ? 'Copiar endereço Google'
                                    : 'Copiar endereço Apple')),
                        OutlinedButton(
                            onPressed: CustomerSignInConfiguration.enabled(
                                    provider.name)
                                ? () => Navigator.pop(context, provider)
                                : null,
                            child: LocalizedText(
                                provider == CustomerProvider.google
                                    ? 'Voltar e entrar com Google'
                                    : 'Voltar e entrar com Apple')),
                      ]))),
        const SizedBox(height: 12),
        const LocalizedText(
            'A recuperação e seus prazos dependem do provedor. Nenhuma senha foi redefinida por esta tela.'),
      ])));
}
