import '../l10n/customer_localizations.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class LegalDocumentScreen extends StatelessWidget {
  final String title, version, text;
  final String? sourceUrl;
  final bool draft;
  const LegalDocumentScreen(
      {super.key,
      required this.title,
      required this.version,
      required this.text,
      this.sourceUrl,
      this.draft = false});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: LocalizedText(title)),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: SelectionArea(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    LocalizedText(title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    LocalizedText('Versão $version'),
                    if (draft)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: LocalizedText(
                              'DRAFT • Exclusivo para desenvolvimento. Não é um documento jurídico de produção.',
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold))),
                    const SizedBox(height: 24),
                    SelectableText(text),
                    if (sourceUrl != null && sourceUrl!.isNotEmpty) ...[
                      const Divider(height: 32),
                      const LocalizedText('Fonte oficial'),
                      SelectableText(sourceUrl!),
                    ],
                  ])))));
}
