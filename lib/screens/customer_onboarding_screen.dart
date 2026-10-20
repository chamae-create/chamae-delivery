import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/customer_onboarding.dart';
import 'legal_document_screen.dart';

class CustomerOnboardingScreen extends StatefulWidget {
  final CustomerOnboardingState state;
  final CustomerOnboardingRepository repository;
  final VoidCallback onComplete;
  final VoidCallback? onRetry, onSignOut;
  const CustomerOnboardingScreen(
      {super.key,
      required this.state,
      required this.repository,
      required this.onComplete,
      this.onRetry,
      this.onSignOut});
  @override
  State<CustomerOnboardingScreen> createState() =>
      _CustomerOnboardingScreenState();
}

class _CustomerOnboardingScreenState extends State<CustomerOnboardingScreen> {
  final _birth = TextEditingController();
  bool _terms = false, _privacy = false, _alcohol = false, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final profile = widget.state.profile, policy = widget.state.policy;
    final accepted = profile['acceptedAt'] != null;
    _terms = accepted && profile['termsVersion'] == policy.termsVersion;
    _privacy = accepted && profile['privacyVersion'] == policy.privacyVersion;
    _alcohol = accepted && profile['alcoholVersion'] == policy.alcoholVersion;
    final value = widget.state.profile['birthDate'];
    if (value is String && parseBirthDate(value) != null) {
      final parts = value.split('-');
      _birth.text = '${parts[2]}/${parts[1]}/${parts[0]}';
    }
  }

  @override
  void dispose() {
    _birth.dispose();
    super.dispose();
  }

  void _document(bool privacy) {
    final p = widget.state.policy;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LegalDocumentScreen(
                title: privacy ? 'Política de Privacidade' : 'Termos de Uso',
                version: privacy ? p.privacyVersion : p.termsVersion,
                text: privacy ? p.privacyText : p.termsText,
                sourceUrl: privacy ? p.privacyUrl : p.termsUrl,
                draft: p.draft)));
  }

  Future<void> _submit() async {
    final parts = _birth.text.trim().split('/');
    final iso = parts.length == 3
        ? '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}'
        : '';
    if (parseBirthDate(iso) == null || !_terms || !_privacy || !_alcohol) {
      setState(() => _error =
          'Informe uma data de nascimento válida e confira os três aceites.');
      return;
    }
    if (!widget.state.policy.canContinueOnboarding()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // DRAFT is a local development passage, never a legal acceptance.
      // Do not call the repository or persist DOB, versions or consent events.
      if (!widget.state.policy.allowsDevelopmentOnboarding()) {
        await widget.repository.accept(widget.state.policy, iso);
      }
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível registrar o aceite. Confira a conexão e tente novamente. Se os documentos mudaram, atualize esta etapa.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Vamos começar')),
      body: SafeArea(
          child:
              ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
        if (widget.state.policy.allowsDevelopmentOnboarding()) ...[
          const SizedBox(height: 16),
          const Card(
              color: Color(0xFFFFF3CD),
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'AMBIENTE DE DESENVOLVIMENTO — documentos jurídicos ainda não são os oficiais.',
                      style: TextStyle(
                          color: Color(0xFF664D03),
                          fontWeight: FontWeight.bold)))),
          const Text(
              'A passagem vale somente nesta sessão de homologação e não registra aceite jurídico oficial.'),
        ],
        const Icon(Icons.verified_user_outlined, size: 44),
        const SizedBox(height: 24),
        Text('Uma experiência feita para você',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(
            'Precisamos da sua data de nascimento e da confirmação dos documentos para continuar.'),
        const SizedBox(height: 24),
        TextField(
            controller: _birth,
            enabled: !_busy && widget.state.profile['birthDate'] == null,
            keyboardType: TextInputType.datetime,
            autofillHints: const [AutofillHints.birthday],
            decoration: const InputDecoration(
                labelText: 'Data de nascimento', hintText: 'DD/MM/AAAA')),
        const SizedBox(height: 12),
        const Text(
            'A data informada não comprova sua identidade. Conforme o produto e o destino, um documento poderá ser solicitado no recebimento.'),
        const SizedBox(height: 16),
        CheckboxListTile(
            value: _terms,
            onChanged: _busy ? null : (v) => setState(() => _terms = v!),
            contentPadding: EdgeInsets.zero,
            title: const Text('Li e aceito os Termos de Uso')),
        TextButton(
            onPressed: () => _document(false),
            child: const Text('Termos de Uso')),
        CheckboxListTile(
            value: _privacy,
            onChanged: _busy ? null : (v) => setState(() => _privacy = v!),
            contentPadding: EdgeInsets.zero,
            title: const Text('Li e estou ciente da Política de Privacidade')),
        TextButton(
            onPressed: () => _document(true),
            child: const Text('Política de Privacidade')),
        CheckboxListTile(
            value: _alcohol,
            onChanged: _busy ? null : (v) => setState(() => _alcohol = v!),
            contentPadding: EdgeInsets.zero,
            title:
                const Text('Estou ciente das regras para bebidas alcoólicas')),
        Text(widget.state.policy.alcoholNotice),
        if (!widget.state.policy.canContinueOnboarding()) ...[
          const SizedBox(height: 16),
          const Text(
              'Documentos DRAFT de desenvolvimento. O primeiro acesso será liberado quando os documentos oficiais estiverem disponíveis.',
              style: TextStyle(color: AppColors.error)),
        ],
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.error))),
        const SizedBox(height: 24),
        ElevatedButton(
            onPressed: _busy || !widget.state.policy.canContinueOnboarding()
                ? null
                : _submit,
            child: Text(_busy ? 'Registrando…' : 'Continuar')),
        if (widget.onRetry != null)
          TextButton(
              onPressed: _busy ? null : widget.onRetry,
              child: const Text('Atualizar documentos')),
        if (widget.onSignOut != null)
          TextButton(
              onPressed: _busy ? null : widget.onSignOut,
              child: const Text('Sair da conta')),
      ])));
}
