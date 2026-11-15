import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/customer_localizations.dart';
import 'customer_visual.dart';

/// Presentation only: immutable IDs and monetary strings are never translated.
class CustomerOrderHistoryCard extends StatelessWidget {
  final String id, total, status;
  final DateTime date;
  final VoidCallback onTap;
  final String? itemsSummary;
  final bool isActive;
  const CustomerOrderHistoryCard({
    super.key,
    required this.id,
    required this.total,
    required this.status,
    required this.date,
    required this.onTap,
    this.itemsSummary,
    this.isActive = false,
  });

  String _formattedTotal() {
    final trimmed = total.trim();
    return 'R\$ ${trimmed.replaceAll('.', ',')}';
  }

  (Color bg, Color fg, IconData icon) _statusStyle() {
    final lower = status.toLowerCase();
    if (lower.contains('cancel')) {
      return (const Color(0xFFFCE8E6), AppColors.error, Icons.cancel_outlined);
    }
    if (lower.contains('entregue') || lower.contains('conclu')) {
      return (
        const Color(0xFFE8F5E9),
        AppColors.accentGreen,
        Icons.check_circle_outline_rounded,
      );
    }
    return (
      const Color(0xFFFFF4D2),
      AppColors.darkGold,
      Icons.local_shipping_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeFg, badgeIcon) = _statusStyle();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14916A16),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: badgeFg.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 14, color: badgeFg),
                            const SizedBox(width: 5),
                            Flexible(
                              child: LocalizedText(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: badgeFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (itemsSummary != null && itemsSummary!.trim().isNotEmpty) ...[
                  Text(
                    itemsSummary!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        localizedDate(context, date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LocalizedText(
                          'Total',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formattedTotal(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkGold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: isActive ? CustomerVisual.gold : null,
                        color: isActive ? null : AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isActive
                              ? AppTheme.goldDeep
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LocalizedText(
                            isActive ? 'Acompanhar' : 'Ver detalhes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppTheme.textDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
