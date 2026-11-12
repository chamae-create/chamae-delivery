import '../l10n/customer_localizations.dart';
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
  String _country = 'BR';
  bool _ageDeclared = false;
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
    final declaration = profile['navigationAgeDeclaration'];
    if (declaration is Map &&
        ['BR', 'PY'].contains(declaration['countryCode'])) {
      _country = declaration['countryCode'];
    }
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
    final minimum = widget.state.policy.navigationMinimum(_country);
    if (!_ageDeclared || minimum == null || !_terms || !_privacy || !_alcohol) {
      setState(() => _error =
          Localizations.localeOf(context).languageCode == 'es'
              ? 'Confirme la edad mínima y revise las tres manifestaciones.'
              : 'Confirme a idade mínima e confira as três manifestações.');
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
        await widget.repository.acceptForNavigation(
            widget.state.policy, NavigationAgeDeclaration(_country, minimum));
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

  void _alcoholDocument() {
    final p = widget.state.policy;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LegalDocumentScreen(
                  title: 'Estou ciente das regras para bebidas alcoólicas',
                  version: p.alcoholVersion,
                  text: p.alcoholNotice,
                  draft: p.draft,
                )));
  }

  Widget _referenceCrop({required double width, required bool footer}) {
    // Display the approved pixels directly; no redraw or generated substitute.
    final scale = width / 480;
    return Semantics(
      image: true,
      label: footer
          ? 'Loumak Tecnologia'
          : localizedLabel(context, 'Chamaê Delivery. Bebidas e conveniência.'),
      child: ExcludeSemantics(
          child: SizedBox(
        width: width,
        height: (footer ? 130 : 350) * scale,
        child: ClipRect(
            child: Stack(children: [
          Positioned(
            left: -230 * scale,
            top: -(footer ? 1535 : 36) * scale,
            width: 941 * scale,
            height: 1672 * scale,
            child: Image.asset(
                'assets/images/onboarding/approved_onboarding_reference.png',
                fit: BoxFit.fill),
          )
        ])),
      )),
    );
  }

  Widget _consent(
          {required String label,
          required String document,
          required IconData icon,
          required bool value,
          required ValueChanged<bool?> changed,
          required VoidCallback open}) =>
      Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: CheckboxListTile(
              value: value,
              onChanged: _busy ? null : changed,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              secondary: Icon(icon, color: Colors.black, size: 25),
              activeColor: Colors.black,
              checkColor: const Color(0xFFFFD600),
              title: Row(children: [
                Expanded(
                    flex: 3,
                    child: LocalizedText(label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black))),
                const SizedBox(width: 4),
                Flexible(
                    flex: 2,
                    child: TextButton(
                      onPressed: open,
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero),
                      child: LocalizedText(document,
                          style: const TextStyle(fontSize: 12)),
                    )),
              ]),
            ),
          ));

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.black,
              onPrimary: const Color(0xFFFFD600),
              surface: Colors.white),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFFFD600),
          body: DecoratedBox(
            decoration: const BoxDecoration(
                gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [Color(0xFFFFE329), Color(0xFFFFD000)],
            )),
            child: SafeArea(
                child: LayoutBuilder(
              builder: (context, viewport) => Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (Navigator.of(context).canPop())
                                  const BackButton(color: Colors.black)
                                else
                                  const SizedBox(width: 48),
                                const LanguagePicker(),
                              ]),
                          Center(
                              child: _referenceCrop(
                                  width: viewport.maxHeight < 680 ? 175 : 225,
                                  footer: false)),
                          Semantics(
                              header: true,
                              child: const LocalizedText('Vamos começar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 30,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black))),
                          const SizedBox(height: 10),
                          LocalizedText(
                              Localizations.localeOf(context).languageCode ==
                                      'es'
                                  ? 'Confirme la edad mínima y los documentos para continuar.'
                                  : 'Confirme a idade mínima e os documentos para continuar.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black)),
                          const SizedBox(height: 18),
                          if (widget.state.policy
                              .allowsDevelopmentOnboarding()) ...[
                            const Card(
                                color: Color(0xFFFFF3CD),
                                child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: LocalizedText(
                                        'AMBIENTE DE DESENVOLVIMENTO — documentos jurídicos ainda não são os oficiais.'))),
                            const LocalizedText(
                                'A passagem vale somente nesta sessão de homologação e não registra aceite jurídico oficial.'),
                            const SizedBox(height: 12),
                          ],
                          DropdownButtonFormField<String>(
                            initialValue: _country,
                            isExpanded: true,
                            decoration: InputDecoration(
                                labelText: Localizations.localeOf(context)
                                            .languageCode ==
                                        'es'
                                    ? 'Jurisdicción'
                                    : 'Jurisdição'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'BR', child: Text('Brasil')),
                              DropdownMenuItem(
                                  value: 'PY', child: Text('Paraguay'))
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                      _country = value!;
                                      _ageDeclared = false;
                                    }),
                          ),
                          CheckboxListTile(
                            key: const Key('navigation-age-declaration'),
                            value: _ageDeclared,
                            onChanged: _busy ||
                                    widget.state.policy
                                            .navigationMinimum(_country) ==
                                        null
                                ? null
                                : (value) => setState(
                                    () => _ageDeclared = value == true),
                            title: Text(Localizations.localeOf(context)
                                        .languageCode ==
                                    'es'
                                ? 'Declaro tener al menos ${widget.state.policy.navigationMinimum(_country) ?? "—"} años.'
                                : 'Declaro ter pelo menos ${widget.state.policy.navigationMinimum(_country) ?? "—"} anos.'),
                          ),
                          const SizedBox(height: 10),
                          Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFF2BF),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: Colors.black),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: LocalizedText(
                                            Localizations.localeOf(context)
                                                        .languageCode ==
                                                    'es'
                                                ? 'Esta declaración no comprueba identidad ni edad y no habilita compras restringidas ni operaciones en Paraguay.'
                                                : 'Esta declaração não comprova identidade ou idade e não habilita compras restritas nem operação no Paraguai.',
                                            style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 13))),
                                  ])),
                          _consent(
                              label: 'Li e aceito os Termos de Uso',
                              document: 'Termos de Uso',
                              icon: Icons.description_outlined,
                              value: _terms,
                              changed: (v) => setState(() => _terms = v!),
                              open: () => _document(false)),
                          _consent(
                              label:
                                  'Li e estou ciente da Política de Privacidade',
                              document: 'Política de Privacidade',
                              icon: Icons.privacy_tip_outlined,
                              value: _privacy,
                              changed: (v) => setState(() => _privacy = v!),
                              open: () => _document(true)),
                          _consent(
                              label:
                                  'Estou ciente das regras para bebidas alcoólicas',
                              document: Localizations.localeOf(context)
                                          .languageCode ==
                                      'es'
                                  ? 'Ver reglas'
                                  : 'Ver regras',
                              icon: Icons.no_drinks_outlined,
                              value: _alcohol,
                              changed: (v) => setState(() => _alcohol = v!),
                              open: _alcoholDocument),
                          if (!widget.state.policy.canContinueOnboarding()) ...[
                            const SizedBox(height: 12),
                            const LocalizedText(
                                'Documentos DRAFT de desenvolvimento. O primeiro acesso será liberado quando os documentos oficiais estiverem disponíveis.',
                                style: TextStyle(color: AppColors.error)),
                          ],
                          if (_error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: LocalizedText(_error!,
                                    style: const TextStyle(
                                        color: AppColors.error))),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: const Color(0xFFFFD600),
                                disabledBackgroundColor:
                                    const Color(0xFF333333),
                                disabledForegroundColor:
                                    const Color(0xFFFFE477),
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22))),
                            onPressed: _busy ||
                                    !widget.state.policy.canContinueOnboarding()
                                ? null
                                : _submit,
                            child: LocalizedText(
                                _busy ? 'Registrando…' : 'Continuar',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800)),
                          ),
                          if (widget.onRetry != null)
                            TextButton(
                                onPressed: _busy ? null : widget.onRetry,
                                child: const LocalizedText(
                                    'Atualizar documentos')),
                          if (widget.onSignOut != null)
                            TextButton(
                                onPressed: _busy ? null : widget.onSignOut,
                                child: const LocalizedText('Sair da conta')),
                          const SizedBox(height: 14),
                          Center(
                              child: _referenceCrop(width: 210, footer: true)),
                        ],
                      ))),
            )),
          ),
        ),
      );
}
