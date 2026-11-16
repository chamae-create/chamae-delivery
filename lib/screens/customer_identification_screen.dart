import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../core/theme.dart';
import '../data/binational_identity.dart';
import '../l10n/customer_localizations.dart';
import '../widgets/customer_visual.dart';

enum _WhatsAppCountry {
  br(code: 'BR', dial: '+55', flag: '🇧🇷', hint: '(11) 99999-9999'),
  py(code: 'PY', dial: '+595', flag: '🇵🇾', hint: '(981) 123-456');

  const _WhatsAppCountry({
    required this.code,
    required this.dial,
    required this.flag,
    required this.hint,
  });

  final String code;
  final String dial;
  final String flag;
  final String hint;
}

class _WhatsAppPhoneFormatter extends TextInputFormatter {
  _WhatsAppPhoneFormatter({
    required this.country,
    required this.onDetectedCountry,
  });

  final _WhatsAppCountry country;
  final ValueChanged<_WhatsAppCountry> onDetectedCountry;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text.trim();
    var target = country;
    if (raw.startsWith('+595')) {
      target = _WhatsAppCountry.py;
      raw = raw.substring(4);
      onDetectedCountry(target);
    } else if (raw.startsWith('+55')) {
      target = _WhatsAppCountry.br;
      raw = raw.substring(3);
      onDetectedCountry(target);
    }
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final formatted = formatDigits(digits, target);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatDigits(String rawDigits, _WhatsAppCountry country) {
    final maxLen = country == _WhatsAppCountry.br ? 11 : 10;
    final d = rawDigits.length > maxLen
        ? rawDigits.substring(0, maxLen)
        : rawDigits;
    if (d.isEmpty) return '';
    if (country == _WhatsAppCountry.py) {
      if (d.length <= 3) return '($d';
      if (d.length <= 6) return '(${d.substring(0, 3)}) ${d.substring(3)}';
      return '(${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
    }
    if (d.length <= 2) return '($d';
    if (d.length <= 6) return '(${d.substring(0, 2)}) ${d.substring(2)}';
    if (d.length <= 10) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
    }
    return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  }
}

class CustomerIdentificationScreen extends StatefulWidget {
  const CustomerIdentificationScreen({
    super.key,
    required this.profile,
    required this.repository,
    required this.onComplete,
  });

  final Map<String, dynamic> profile;
  final IdentificationRepository repository;
  final VoidCallback onComplete;

  @override
  State<CustomerIdentificationScreen> createState() => _IdentificationState();
}

class _IdentificationState extends State<CustomerIdentificationScreen> {
  final name = TextEditingController(),
      document = TextEditingController(),
      phone = TextEditingController(),
      issuer = TextEditingController();
  IdentificationType type = IdentificationType.cpf;
  _WhatsAppCountry _whatsCountry = _WhatsAppCountry.br;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final value = BinationalIdentity.fromProfile(widget.profile);
    name.text = value.fullName;
    issuer.text = value.issuer;
    type = value.type;
    _initPhone(value.phone);
  }

  void _initPhone(String saved) {
    final clean = saved.trim();
    if (clean.startsWith('+595')) {
      _whatsCountry = _WhatsAppCountry.py;
      final digits = clean.substring(4).replaceAll(RegExp(r'\D'), '');
      phone.text = _WhatsAppPhoneFormatter.formatDigits(digits, _whatsCountry);
    } else if (clean.startsWith('+55')) {
      _whatsCountry = _WhatsAppCountry.br;
      final digits = clean.substring(3).replaceAll(RegExp(r'\D'), '');
      phone.text = _WhatsAppPhoneFormatter.formatDigits(digits, _whatsCountry);
    } else {
      final digits = clean.replaceAll(RegExp(r'\D'), '');
      phone.text = _WhatsAppPhoneFormatter.formatDigits(digits, _whatsCountry);
    }
  }

  String _fullPhoneE164() {
    final trimmed = phone.text.trim();
    if (trimmed.startsWith('+') &&
        RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(trimmed)) {
      return trimmed;
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return '${_whatsCountry.dial}$digits';
  }

  @override
  void dispose() {
    name.dispose();
    document.dispose();
    phone.dispose();
    issuer.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final l = context.l10n;
    final e164 = _fullPhoneE164();
    if (!documentFormatValid(type, document.text) ||
        name.text.trim().length < 3 ||
        !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(e164) ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(issuer.text)) {
      setState(() => error = l.identityInvalid);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final language = Localizations.localeOf(context).languageCode == 'es'
        ? 'es-PY'
        : 'pt-BR';
    try {
      await widget.repository.save(
        BinationalIdentity(
          fullName: name.text,
          type: type,
          issuer: issuer.text,
          phone: e164,
          language: language,
        ),
      );
      UserSession.fullName = name.text.trim();
      UserSession.whatsapp = e164;
      document.clear();
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) setState(() => error = l.identitySaveFailed);
    } finally {
      document.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(l.identification),
        actions: const [LanguagePicker(compact: true)],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: [
            Container(
              decoration: CustomerVisual.panel(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: Image.asset(
                            'assets/images/states/id_shield.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.verified_user_outlined,
                              color: AppColors.darkGold,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          es
                              ? 'Confirma tus datos para agilizar tus pedidos.'
                              : 'Confirme seus dados para agilizar seus pedidos.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IdentificationType>(
                    initialValue: type,
                    isExpanded: true,
                    items: IdentificationType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              switch (t) {
                                IdentificationType.cpf => l.brazilCpf,
                                IdentificationType.cedula => l.paraguayId,
                                IdentificationType.other => l.otherId,
                              },
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                              type = v!;
                              document.clear();
                              issuer.text = switch (type) {
                                IdentificationType.cpf => 'BR',
                                IdentificationType.cedula => 'PY',
                                IdentificationType.other => '',
                              };
                              if (type == IdentificationType.cpf) {
                                _whatsCountry = _WhatsAppCountry.br;
                              } else if (type == IdentificationType.cedula) {
                                _whatsCountry = _WhatsAppCountry.py;
                              }
                            }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: localizedDecoration(
                      context,
                      InputDecoration(
                        labelText: l.fullName,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: document,
                    enabled: !busy,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: const [],
                    decoration: localizedDecoration(
                      context,
                      InputDecoration(
                        labelText: 'Documento',
                        helperText: es
                            ? 'Solo para validación inicial.'
                            : 'Usado apenas na validação inicial.',
                        helperMaxLines: 1,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: issuer,
                    enabled: !busy && type == IdentificationType.other,
                    textCapitalization: TextCapitalization.characters,
                    decoration: localizedDecoration(
                      context,
                      InputDecoration(
                        labelText: es ? 'País emisor' : 'País emissor',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PopupMenuButton<_WhatsAppCountry>(
                        enabled: !busy,
                        tooltip: 'Selecionar país do WhatsApp',
                        onSelected: (selected) {
                          setState(() {
                            _whatsCountry = selected;
                            final digits = phone.text
                                .replaceAll(RegExp(r'\D'), '');
                            phone.text = _WhatsAppPhoneFormatter.formatDigits(
                              digits,
                              _whatsCountry,
                            );
                          });
                        },
                        itemBuilder: (_) => _WhatsAppCountry.values
                            .map(
                              (c) => PopupMenuItem<_WhatsAppCountry>(
                                value: c,
                                child: Text('${c.flag} ${c.code} (${c.dial})'),
                              ),
                            )
                            .toList(),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_whatsCountry.flag} ${_whatsCountry.dial}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: AppTheme.textDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phone,
                          enabled: !busy,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            _WhatsAppPhoneFormatter(
                              country: _whatsCountry,
                              onDetectedCountry: (c) {
                                if (_whatsCountry != c && mounted) {
                                  setState(() => _whatsCountry = c);
                                }
                              },
                            ),
                          ],
                          decoration: localizedDecoration(
                            context,
                            InputDecoration(
                              labelText: 'WhatsApp',
                              hintText: _whatsCountry.hint,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryYellow,
                foregroundColor: AppTheme.obsidianDark,
                minimumSize: const Size(48, 50),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: busy ? null : save,
              child: Text(l.saveIdentification),
            ),
          ],
        ),
      ),
    );
  }
}
