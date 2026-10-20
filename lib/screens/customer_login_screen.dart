import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/customer_auth.dart';

class CustomerLoginScreen extends StatefulWidget {
  final CustomerAuth auth;
  const CustomerLoginScreen({super.key, required this.auth});
  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  CustomerProvider? _busy;
  String? _error;
  Future<void> _login(CustomerProvider provider,
      {bool existing = false}) async {
    if (_busy != null) return;
    setState(() {
      _busy = provider;
      _error = null;
    });
    try {
      await widget.auth.signIn(provider, useExistingAccount: existing);
    } on CustomerAuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.existingAccount && !existing) {
        final change = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Conta já existente'),
                    content: Text(widget.auth.current?.anonymous == true
                        ? '${e.message}\n\nAo trocar de conta, você sairá da sessão anônima. Os pedidos, endereços e demais dados dessa sessão poderão ficar inacessíveis. Volte para manter a sessão atual.'
                        : e.message),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Voltar')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Trocar de conta')),
                    ]));
        if (!mounted) return;
        setState(() => _busy = null);
        if (change == true) await _login(provider, existing: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível entrar agora. Confira a conexão e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = defaultTargetPlatform == TargetPlatform.iOS
        ? [CustomerProvider.apple, CustomerProvider.google]
        : [CustomerProvider.google, CustomerProvider.apple];
    return Scaffold(
        body: SafeArea(
            child:
                ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
      const SizedBox(height: 24),
      Container(
          padding: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
              color: AppColors.deepBlack,
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Image.asset('assets/images/logo.png',
              height: 148,
              fit: BoxFit.contain,
              semanticLabel: 'Chamaê Delivery. Bebidas e conveniência.')),
      const SizedBox(height: 32),
      Text('Bem-vindo ao Chamaê',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Text(
          'Bebidas e conveniência, do seu jeito. Entre para encontrar seus endereços e acompanhar seus pedidos.'),
      const SizedBox(height: 32),
      for (final provider in providers)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
                onPressed: _busy == null ? () => _login(provider) : null,
                icon: _busy == provider
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        provider == CustomerProvider.apple
                            ? Icons.apple
                            : Icons.g_mobiledata,
                        size: 28),
                label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(provider == CustomerProvider.apple
                        ? 'Continuar com Apple'
                        : 'Continuar com Google')))),
      if (_error != null)
        Semantics(
            liveRegion: true,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.error)))),
      const SizedBox(height: 12),
      const Text('Entrada por telefone em preparação.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 32),
      const Text(
          'Seus dados ficam vinculados à sua conta. Você poderá conferir os documentos e as informações de privacidade antes de continuar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 32),
      const Text('Loumak',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ])));
  }
}
