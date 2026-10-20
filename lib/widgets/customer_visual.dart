import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Presentation tokens derived from design/references/customer_app/official.
abstract final class CustomerVisual {
  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFED8A), AppTheme.primaryYellow, Color(0xFFF2AF00)],
  );
  static const charcoal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF30281A), AppTheme.darkBg, Color(0xFF493413)],
  );
  static BoxDecoration panel({bool dark = false}) => BoxDecoration(
        color: dark ? null : AppColors.surfaceWhite,
        gradient: dark ? charcoal : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: dark ? AppTheme.primaryYellow : AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11916A16), blurRadius: 18, offset: Offset(0, 5))
        ],
      );
  static EdgeInsets pagePadding(BuildContext context, {double maxWidth = 880}) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = width > maxWidth ? (width - maxWidth) / 2 + 16 : 16.0;
    return EdgeInsets.fromLTRB(inset, 16, inset, 24);
  }
}

class CustomerSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const CustomerSectionTitle(
      {super.key, required this.title, required this.icon, this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.darkGold, size: 28),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ])),
        ]),
      );
}

class CustomerHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  const CustomerHero(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.trailing});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: CustomerVisual.panel(dark: true),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  gradient: CustomerVisual.gold, shape: BoxShape.circle),
              child: Icon(icon, color: AppTheme.darkBg, size: 30)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.primaryYellow,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white, height: 1.4)),
                if (trailing != null) ...[
                  const SizedBox(height: 12),
                  trailing!
                ],
              ])),
        ]),
      );
}
