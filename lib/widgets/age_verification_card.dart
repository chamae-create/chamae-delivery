import 'package:flutter/material.dart';
import '../l10n/customer_localizations.dart';

class AgeVerificationCard extends StatelessWidget {
  const AgeVerificationCard({super.key});
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.ageCheckTitle),
            Text(context.l10n.ageCheckUnavailable),
            Text(context.l10n.receiptCheck)
          ])));
}
// Activation is deliberately unavailable until a trusted provider is contracted
// and homologated. Neither a checkbox nor local storage can approve AgeCheck.
