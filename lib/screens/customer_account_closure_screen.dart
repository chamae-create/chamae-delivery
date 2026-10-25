import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/customer_account.dart';
import '../widgets/customer_feedback.dart';
import '../widgets/customer_visual.dart';

class CustomerAccountClosureScreen extends StatefulWidget {
  final CustomerAccountRepository repository;
  const CustomerAccountClosureScreen({super.key, required this.repository});
  @override
  State<CustomerAccountClosureScreen> createState() =>
      _CustomerAccountClosureScreenState();
}

class _CustomerAccountClosureScreenState
    extends State<CustomerAccountClosureScreen> {
  AccountClosureStatus _status = AccountClosureStatus.ready;
  StreamSubscription<AccountClosureStatus>? _subscription;
  bool _accepted = false, _busy = false, _finishing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    _subscription?.cancel();
    _subscription = widget.repository.watch().listen((status) {
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
      if (status == AccountClosureStatus.completed) unawaited(_finish());
    }, onError: (Object error) {
      if (mounted) setState(() => _error = accountClosureError(error));
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await widget.repository.finishSession();
      if (messenger?.mounted == true) {
        messenger!.showSnackBar(
            const SnackBar(content: Text('Sua conta foi excluída.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Sua conta foi excluída. Feche e abra o aplicativo para encerrar a sessão neste aparelho.');
      }
    }
  }

  Future<void> _request() async {
    if (_busy || !_accepted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.reauthenticate();
      if (!mounted) return;
      final status = await widget.repository.request();
      if (!mounted || _status == AccountClosureStatus.completed) return;
      setState(() => _status = status);
      if (status == AccountClosureStatus.completed) await _finish();
    } catch (error) {
      if (mounted) setState(() => _error = accountClosureError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final processing = [
      AccountClosureStatus.requested,
      AccountClosureStatus.processing
    ].contains(_status);
    return Scaffold(
      appBar: AppBar(title: const Text('Excluir minha conta')),
      body: SafeArea(
          child:
              ListView(padding: CustomerVisual.pagePadding(context), children: [
        const CustomerSectionTitle(
            title: 'Você no controle da sua conta',
            icon: Icons.manage_accounts_outlined,
            subtitle: 'Confira o que acontece antes de continuar.'),
        const Text(
            'Seus dados de perfil, endereços, sacola, PIN e conversas serão removidos. '
            'Os pedidos encerrados terão seus dados pessoais minimizados. '
            'Registros financeiros e operacionais necessários serão preservados com acesso restrito.'),
        const SizedBox(height: 16),
        const Text(
            'A conta do Chamaê será excluída. Sua conta Google ou Apple continuará existindo. '
            'Pedidos e pagamentos em andamento precisam ser resolvidos antes da exclusão.'),
        if (_status == AccountClosureStatus.completed)
          const CustomerFeedback(
              title: 'Conta excluída',
              message: 'A exclusão foi concluída. Sua sessão será encerrada.',
              icon: Icons.check_circle_outline)
        else if (processing)
          const CustomerFeedback(
              title: 'Exclusão em andamento',
              message:
                  'A solicitação foi recebida. O processamento continua mesmo se você fechar o app. Verifique o status por aqui.')
        else ...[
          if (_status == AccountClosureStatus.providerPending)
            const CustomerFeedback(
                title: 'Revogação Apple pendente',
                message:
                    'A exclusão não foi concluída. A autorização Apple precisa ser revogada com segurança. '
                    'A solicitação está bloqueada nessa verificação. Uma nova tentativa exige confirmar sua identidade novamente.')
          else if (_status == AccountClosureStatus.blocked)
            const CustomerFeedback(
                title: 'Resolva seu pedido antes de continuar',
                message:
                    'A exclusão não foi concluída. Há um pedido ou pagamento que precisa de atenção.'),
          const SizedBox(height: 20),
          CheckboxListTile(
              value: _accepted,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _accepted = value == true),
              title: const Text('Entendi que a exclusão é definitiva.'),
              controlAffinity: ListTileControlAffinity.leading),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _accepted && !_busy ? _request : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.delete_outline),
              label: Text(_busy
                  ? 'Confirmando sua identidade…'
                  : 'Confirmar identidade e excluir')),
        ],
        if (_error != null)
          Semantics(
              liveRegion: true,
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)))),
        if (_status != AccountClosureStatus.completed)
          TextButton.icon(
              onPressed: _busy ? null : _watch,
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar status')),
      ])),
    );
  }
}
