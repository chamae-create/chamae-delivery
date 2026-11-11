import '../l10n/customer_localizations.dart';
import 'package:flutter/material.dart';
import '../data/customer_onboarding.dart';
import '../data/customer_public_policy.dart';
import 'legal_document_screen.dart';

/// Viewing a public document never records acceptance or authenticates a visitor.
class CustomerPublicDocumentScreen extends StatefulWidget {
  final bool privacy;
  final Future<CustomerPolicy> Function()? loadPolicy;
  const CustomerPublicDocumentScreen(
      {super.key, required this.privacy, this.loadPolicy});
  @override
  State<CustomerPublicDocumentScreen> createState() =>
      _CustomerPublicDocumentScreenState();
}

class _CustomerPublicDocumentScreenState
    extends State<CustomerPublicDocumentScreen> {
  late Future<CustomerPolicy> _policy = _load();
  Future<CustomerPolicy> _load() =>
      (widget.loadPolicy ?? CustomerPublicPolicy().load)();
  @override
  Widget build(BuildContext context) => FutureBuilder<CustomerPolicy>(
      future: _policy,
      builder: (context, snapshot) {
        final title =
            widget.privacy ? 'Política de Privacidade' : 'Termos de Uso';
        final policy = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError &&
            policy != null &&
            policy.available) {
          return LegalDocumentScreen(
              title: title,
              version:
                  widget.privacy ? policy.privacyVersion : policy.termsVersion,
              text: widget.privacy ? policy.privacyText : policy.termsText,
              sourceUrl: widget.privacy ? policy.privacyUrl : policy.termsUrl);
        }
        return Scaffold(
            appBar: AppBar(title: LocalizedText(title)),
            body: SafeArea(
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: snapshot.connectionState != ConnectionState.done
                            ? const CircularProgressIndicator()
                            : Column(mainAxisSize: MainAxisSize.min, children: [
                                const LocalizedText(
                                    'O documento oficial não está disponível agora. Confira sua conexão e tente novamente. Nenhum aceite foi registrado.',
                                    textAlign: TextAlign.center),
                                TextButton(
                                    onPressed: () => setState(() {
                                          _policy = _load();
                                        }),
                                    child: const LocalizedText(
                                        'Tentar novamente')),
                              ])))));
      });
}
