import '../l10n/customer_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
    if (_busy) return;
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
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FirebaseFunctionsException &&
                error.code == 'permission-denied'
            ? (Localizations.localeOf(context).languageCode == 'es'
                ? 'Esta cuenta no tiene permiso para el registro de Cliente. Salga e ingrese con una cuenta exclusiva de Cliente. Si el problema persiste, contacte al soporte.'
                : 'Esta conta não tem permissão para o cadastro de Cliente. Saia e entre com uma conta exclusiva de Cliente. Se o bloqueio persistir, contate o suporte.')
            : 'Não foi possível registrar o aceite. Confira a conexão e tente novamente. Se os documentos mudaram, atualize esta etapa.');
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

  String _text(String pt, String es) =>
      Localizations.localeOf(context).languageCode == 'es' ? es : pt;
  static const _ink = Color(0xFF191816);
  static const _gold = Color(0xFFFFC400);
  static const _muted = Color(0xFF615D54);

  Widget _notice(String message, {bool error = false}) => Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: error ? const Color(0xFFFFECE8) : const Color(0xFFFFF1C6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  error ? const Color(0xFFE8B4AA) : const Color(0xFFF6D875))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 21, color: error ? AppColors.error : const Color(0xFF785400)),
        const SizedBox(width: 10),
        Expanded(
            child: LocalizedText(message,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: error ? AppColors.error : const Color(0xFF514118)))),
      ]));

  Widget _consent(
          {required String label,
          required String title,
          required IconData icon,
          required bool value,
          required ValueChanged<bool?> changed,
          required VoidCallback open}) =>
      AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
              color: value ? const Color(0xFFFFFAEA) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: value ? const Color(0xFFE6B829) : const Color(0xFFEEE9E0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x15754F22),
                    blurRadius: 14,
                    offset: Offset(0, 4))
              ]),
          child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: CheckboxListTile(
                  value: value,
                  onChanged: _busy ? null : changed,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  controlAffinity: ListTileControlAffinity.trailing,
                  activeColor: _ink,
                  checkColor: _gold,
                  checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  side: const BorderSide(color: Color(0xFF645F56), width: 1.5),
                  secondary: Container(
                      width: 36,
                      height: 40,
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFFFF0B4), Color(0xFFFFD75C)]),
                          borderRadius: BorderRadius.circular(13)),
                      child: Icon(icon, color: _ink, size: 24)),
                  title:
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextButton(
                        onPressed: _busy ? null : open,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 48),
                            alignment: Alignment.centerLeft,
                            foregroundColor: _ink),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LocalizedText(title,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                        child: LocalizedText('Ver documento',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF805600),
                                                decoration:
                                                    TextDecoration.underline))),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 16, color: Color(0xFF805600)),
                                  ]),
                            ])),
                    Padding(
                        padding: const EdgeInsets.only(top: 1, bottom: 4),
                        child: LocalizedText(label,
                            style: const TextStyle(
                                fontSize: 12, height: 1.4, color: _muted))),
                  ]))));

  Widget _ageCard(int? minimum) => Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [Color(0xFFFFEDAC), Color(0xFFFFF7DE)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _ageDeclared ? const Color(0xFFD3A315) : Colors.white),
          boxShadow: const [
            BoxShadow(
                color: Color(0x10A57A00), blurRadius: 12, offset: Offset(0, 4))
          ]),
      child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: CheckboxListTile(
              key: const Key('navigation-age-declaration'),
              value: _ageDeclared,
              onChanged: _busy || minimum == null
                  ? null
                  : (value) => setState(() => _ageDeclared = value == true),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              activeColor: _ink,
              checkColor: _gold,
              checkboxShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
              side: const BorderSide(color: Color(0xFF645F56), width: 1.5),
              secondary: ExcludeSemantics(
                  child: Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _ink, width: 2), color: const Color(0xFFFFE58C)), child: Text('${minimum ?? '—'}+', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)))),
              title: Text(_text('Declaro ter pelo menos ${minimum ?? '—'} anos.', 'Declaro tener al menos ${minimum ?? '—'} años.'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 3), child: Text(_text('Idade mínima para navegação na jurisdição indicada.', 'Edad mínima para navegar en la jurisdicción indicada.'), style: const TextStyle(fontSize: 12, height: 1.35, color: _muted))))));

  Widget _brandHeader() => LayoutBuilder(builder: (context, bounds) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
            bounds.maxWidth < 330;
        final size = largeText
            ? 88.0
            : bounds.maxWidth > 500
                ? 120.0
                : 104.0;
        final brand = Semantics(
            image: true,
            label: 'Chamaê Delivery. Bebidas & conveniência.',
            child: ExcludeSemantics(
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(size * .245),
                    child: Image.asset(
                        'assets/images/onboarding/official_app_icon.png',
                        width: size,
                        height: size,
                        fit: BoxFit.contain))));
        final controls =
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (Navigator.of(context).canPop())
            IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: _busy ? null : () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back))
          else
            const SizedBox(width: 48),
          if (context.dependOnInheritedWidgetOfExactType<LocaleScope>() != null)
            AbsorbPointer(
                absorbing: _busy,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF0AD),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x15926000),
                              blurRadius: 12,
                              offset: Offset(0, 4))
                        ]),
                    child: Theme(
                        data: Theme.of(context).copyWith(
                            textTheme: Theme.of(context).textTheme.copyWith(
                                titleMedium: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: 12))),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: LanguagePicker(compact: largeText || MediaQuery.sizeOf(context).width < 360))))),
        ]);
        return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: largeText
                ? Column(children: [controls, const SizedBox(height: 4), brand])
                : SizedBox(
                    height: size + 4,
                    child: Stack(children: [
                      Align(alignment: Alignment.bottomCenter, child: brand),
                      Align(alignment: Alignment.topCenter, child: controls),
                    ])));
      });

  @override
  Widget build(BuildContext context) {
    final policy = widget.state.policy;
    final minimum = policy.navigationMinimum(_country);
    // Preserve the existing debug-only preview; submission still validates all
    // declarations and never records legal acceptance for development DRAFT.
    final ready = !_busy &&
        policy.canContinueOnboarding() &&
        (policy.allowsDevelopmentOnboarding() ||
            (minimum != null &&
                _ageDeclared &&
                _terms &&
                _privacy &&
                _alcohol));
    return Theme(
        data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _ink, onPrimary: _gold, surface: Colors.white),
            listTileTheme: Theme.of(context).listTileTheme.copyWith(
                horizontalTitleGap: 10,
                minLeadingWidth: 36,
                minVerticalPadding: 2),
            textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: _ink))),
        child: Scaffold(
            backgroundColor: _gold,
            body: Stack(children: [
              const Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                            Color(0xFFFFD62C),
                            Color(0xFFFFBB00),
                            Color(0xFFFFD524)
                          ])),
                      child: CustomPaint(painter: _GoldenBackdrop()))),
              SafeArea(
                  child: LayoutBuilder(
                      builder: (context, viewport) => Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: ListView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 4, 14, 18),
                                  children: [
                                    _brandHeader(),
                                    Container(
                                        padding: const EdgeInsets.fromLTRB(
                                            14, 18, 14, 16),
                                        decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white,
                                                  Color(0xFFFAF7F1)
                                                ]),
                                            borderRadius:
                                                BorderRadius.circular(32),
                                            border: Border.all(
                                                color: Colors.white,
                                                width: 1.5),
                                            boxShadow: const [
                                              BoxShadow(
                                                  color: Color(0x247B510B),
                                                  blurRadius: 26,
                                                  offset: Offset(0, 9))
                                            ]),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(children: [
                                                const Expanded(
                                                    child: Divider(
                                                        color:
                                                            Color(0xFFE8C34F),
                                                        endIndent: 14)),
                                                Flexible(
                                                    flex: 3,
                                                    child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 15,
                                                                vertical: 7),
                                                        decoration: BoxDecoration(
                                                            color: const Color(
                                                                0xFFFFEDAB),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    20)),
                                                        child: Text(
                                                            _text(
                                                                'Antes de começar',
                                                                'Antes de empezar'),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight.w700,
                                                                color: _ink)))),
                                                const Expanded(
                                                    child: Divider(
                                                        color:
                                                            Color(0xFFE8C34F),
                                                        indent: 14))
                                              ]),
                                              const SizedBox(height: 12),
                                              Semantics(
                                                  header: true,
                                                  child: const LocalizedText(
                                                      'Vamos começar',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          fontSize: 30,
                                                          letterSpacing: -1,
                                                          height: 1.12,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: _ink))),
                                              Center(
                                                  child: Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              top: 9,
                                                              bottom: 13),
                                                      width: 82,
                                                      height: 3,
                                                      decoration: BoxDecoration(
                                                          color: _gold,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      10)))),
                                              Text(
                                                  _text(
                                                      'Confirme a idade mínima e leia os documentos para continuar.',
                                                      'Confirme la edad mínima y lea los documentos para continuar.'),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      height: 1.4,
                                                      color: _muted)),
                                              const SizedBox(height: 13),
                                              DropdownButtonFormField<String>(
                                                  key: const Key(
                                                      'navigation-jurisdiction'),
                                                  initialValue: _country,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                      labelText: _text(
                                                          'Jurisdição para navegação',
                                                          'Jurisdicción para navegar'),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 14,
                                                              vertical: 10),
                                                      border: OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(14),
                                                          borderSide:
                                                              const BorderSide(
                                                                  color: Color(
                                                                      0xFFE6DCC4)))),
                                                  items: const [
                                                    DropdownMenuItem(
                                                        value: 'BR',
                                                        child: Text('Brasil')),
                                                    DropdownMenuItem(
                                                        value: 'PY',
                                                        child: Text('Paraguay'))
                                                  ],
                                                  onChanged: _busy
                                                      ? null
                                                      : (value) => setState(() {
                                                            _country = value!;
                                                            _ageDeclared =
                                                                false;
                                                          })),
                                              _ageCard(minimum),
                                              _consent(
                                                  label:
                                                      'Li e aceito os Termos de Uso',
                                                  title: 'Termos de Uso',
                                                  icon: Icons
                                                      .description_outlined,
                                                  value: _terms,
                                                  changed: (v) => setState(
                                                      () => _terms = v == true),
                                                  open: () => _document(false)),
                                              _consent(
                                                  label:
                                                      'Li e estou ciente da Política de Privacidade',
                                                  title:
                                                      'Política de Privacidade',
                                                  icon: Icons.shield_outlined,
                                                  value: _privacy,
                                                  changed: (v) => setState(() =>
                                                      _privacy = v == true),
                                                  open: () => _document(true)),
                                              _consent(
                                                  label:
                                                      'Estou ciente das regras para bebidas alcoólicas',
                                                  title: _text(
                                                      'Regras para bebidas alcoólicas',
                                                      'Reglas para bebidas alcohólicas'),
                                                  icon: Icons.wine_bar_outlined,
                                                  value: _alcohol,
                                                  changed: (v) => setState(() =>
                                                      _alcohol = v == true),
                                                  open: _alcoholDocument),
                                              _notice(_text(
                                                  'Esta declaração não comprova identidade ou idade e não habilita compras restritas nem operação no Paraguai.',
                                                  'Esta declaración no comprueba identidad ni edad y no habilita compras restringidas ni operaciones en Paraguay.')),
                                              if (policy
                                                  .allowsDevelopmentOnboarding()) ...[
                                                _notice(
                                                    'AMBIENTE DE DESENVOLVIMENTO — documentos jurídicos ainda não são os oficiais.'),
                                                _notice(
                                                    'A passagem vale somente nesta sessão de homologação e não registra aceite jurídico oficial.')
                                              ],
                                              if (!policy
                                                  .canContinueOnboarding())
                                                _notice(
                                                    'Documentos DRAFT de desenvolvimento. O primeiro acesso será liberado quando os documentos oficiais estiverem disponíveis.',
                                                    error: true),
                                              if (_error != null)
                                                Semantics(
                                                    liveRegion: true,
                                                    child: _notice(_error!,
                                                        error: true)),
                                              const SizedBox(height: 12),
                                              ElevatedButton(
                                                  key: const Key(
                                                      'onboarding-continue'),
                                                  style: ElevatedButton.styleFrom(
                                                      backgroundColor: _ink,
                                                      foregroundColor: _gold,
                                                      disabledBackgroundColor:
                                                          const Color(
                                                              0xFFE2DED4),
                                                      disabledForegroundColor:
                                                          const Color(
                                                              0xFF68645A),
                                                      minimumSize: const Size.fromHeight(
                                                          56),
                                                      elevation: ready ? 5 : 0,
                                                      shadowColor: const Color(
                                                          0x778A6100),
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  28))),
                                                  onPressed:
                                                      ready ? _submit : null,
                                                  child: Padding(
                                                      padding: const EdgeInsets.symmetric(
                                                          vertical: 13),
                                                      child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            if (_busy) ...[
                                                              const SizedBox(
                                                                  width: 20,
                                                                  height: 20,
                                                                  child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                      color:
                                                                          _ink)),
                                                              const SizedBox(
                                                                  width: 10)
                                                            ],
                                                            Flexible(
                                                                child: LocalizedText(
                                                                    _busy
                                                                        ? 'Registrando…'
                                                                        : 'Continuar',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            20,
                                                                        fontWeight:
                                                                            FontWeight.w800))),
                                                            if (!_busy)
                                                              const Padding(
                                                                  padding: EdgeInsets
                                                                      .only(
                                                                          left:
                                                                              8),
                                                                  child: Icon(Icons
                                                                      .chevron_right_rounded))
                                                          ]))),
                                              if (widget.onRetry != null)
                                                TextButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : widget.onRetry,
                                                    child: const LocalizedText(
                                                        'Atualizar documentos')),
                                              if (widget.onSignOut != null)
                                                TextButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : widget.onSignOut,
                                                    child: const LocalizedText(
                                                        'Sair da conta')),
                                              const SizedBox(height: 13),
                                              Row(children: [
                                                const Expanded(
                                                    child: Divider(
                                                        indent: 28,
                                                        endIndent: 12)),
                                                Flexible(
                                                    flex: 3,
                                                    child: Text(
                                                        _text('UMA SOLUÇÃO',
                                                            'UNA SOLUCIÓN'),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            letterSpacing: 2,
                                                            color: _muted))),
                                                const Expanded(
                                                    child: Divider(
                                                        indent: 12,
                                                        endIndent: 28))
                                              ]),
                                              const SizedBox(height: 8),
                                              const Text('LOUMAK',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 21,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: 1.2,
                                                      color: _ink)),
                                              const Text('TECNOLOGIA',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      letterSpacing: 3,
                                                      color: _muted)),
                                            ])),
                                  ]))))),
            ])));
  }
}

class _GoldenBackdrop extends CustomPainter {
  const _GoldenBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x26FFF9C5);
    final top = Path()
      ..moveTo(0, size.height * .22)
      ..cubicTo(size.width * .15, size.height * .08, size.width * .42,
          size.height * .08, size.width * .47, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(top, paint);
    canvas.drawPath(
        top,
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7);
    final side = Path()
      ..moveTo(size.width, size.height * .15)
      ..quadraticBezierTo(size.width * .65, size.height * .23, size.width * .68,
          size.height * .45)
      ..lineTo(size.width, size.height * .6)
      ..close();
    canvas.drawPath(side, paint..color = const Color(0x18FFFFFF));
  }

  @override
  bool shouldRepaint(covariant _GoldenBackdrop oldDelegate) => false;
}
