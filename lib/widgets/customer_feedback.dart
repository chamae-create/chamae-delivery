import '../l10n/customer_localizations.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Short, actionable feedback without hiding navigation or suggesting success.
class CustomerFeedback extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final String? imageAsset;
  final bool loading;
  final VoidCallback? onRetry;
  const CustomerFeedback({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.imageAsset,
    this.loading = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (loading)
            const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                    color: AppColors.darkGold, strokeWidth: 3))
          else if (imageAsset != null)
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                imageAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(icon, size: 40, color: AppColors.darkGold),
                ),
              ),
            )
          else
            Icon(icon, size: 40, color: AppColors.darkGold),
          const SizedBox(height: 16),
          Semantics(
              liveRegion: true,
              child: LocalizedText(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18))),
          const SizedBox(height: 8),
          LocalizedText(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const LocalizedText('Tentar novamente')),
          ],
        ]),
      );
}
