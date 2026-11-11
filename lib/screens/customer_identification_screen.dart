import '../core/models.dart';
import 'package:flutter/material.dart';
import '../data/binational_identity.dart';
import '../l10n/customer_localizations.dart';

class CustomerIdentificationScreen extends StatefulWidget {
  const CustomerIdentificationScreen(
      {super.key,
      required this.profile,
      required this.repository,
      required this.onComplete});
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
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final value = BinationalIdentity.fromProfile(widget.profile);
    name.text = value.fullName;
    phone.text = value.phone;
    issuer.text = value.issuer;
    type = value.type;
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
    if (!documentFormatValid(type, document.text) ||
        name.text.trim().length < 3 ||
        !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone.text) ||
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
      await widget.repository.save(BinationalIdentity(
          fullName: name.text,
          type: type,
          issuer: issuer.text,
          phone: phone.text,
          language: language));
      UserSession.fullName = name.text.trim();
      UserSession.whatsapp = phone.text;
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
    return Scaffold(
        appBar: AppBar(
            title: Text(l.identification), actions: const [LanguagePicker()]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(l.identityNotice),
          DropdownButtonFormField<IdentificationType>(
              initialValue: type,
              items: IdentificationType.values
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(switch (t) {
                        IdentificationType.cpf => l.brazilCpf,
                        IdentificationType.cedula => l.paraguayId,
                        IdentificationType.other => l.otherId
                      })))
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                        type = v!;
                        document.clear();
                        issuer.text = switch (type) {
                          IdentificationType.cpf => 'BR',
                          IdentificationType.cedula => 'PY',
                          IdentificationType.other => ''
                        };
                      })),
          TextField(
              controller: name,
              enabled: !busy,
              decoration: localizedDecoration(
                  context, InputDecoration(labelText: l.fullName))),
          TextField(
              controller: document,
              enabled: !busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [],
              decoration: localizedDecoration(
                  context, InputDecoration(labelText: l.documentTemporary))),
          TextField(
              controller: issuer,
              enabled: !busy && type == IdentificationType.other,
              textCapitalization: TextCapitalization.characters,
              decoration: localizedDecoration(
                  context, InputDecoration(labelText: l.documentIssuer))),
          TextField(
              controller: phone,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              decoration: localizedDecoration(
                  context, InputDecoration(labelText: l.internationalPhone))),
          Text(l.noAgeProof),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
              onPressed: busy ? null : save, child: Text(l.saveIdentification)),
        ]));
  }
}
