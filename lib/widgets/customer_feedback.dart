import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Short, actionable feedback without hiding navigation or suggesting success.
class CustomerFeedback extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final bool loading;
  final VoidCallback? onRetry;
  const CustomerFeedback({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
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
          else
            Icon(icon, size: 40, color: AppColors.darkGold),
          const SizedBox(height: 16),
          Semantics(
              liveRegion: true,
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18))),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente')),
          ],
        ]),
      );
}
