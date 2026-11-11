import '../l10n/customer_localizations.dart';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Presentation tokens derived from design/references/customer_app/official.
abstract final class CustomerVisual {
  static const gold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF1A8),
      Color(0xFFFFDC27),
      AppTheme.primaryYellow,
      Color(0xFFEFA900),
      Color(0xFFFFDE48),
    ],
    stops: [0, .18, .5, .88, 1],
  );
  static const charcoal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF30281A), AppTheme.darkBg, Color(0xFF493413)],
  );
  static BoxDecoration panel({bool dark = false}) => BoxDecoration(
    color: dark ? null : AppColors.surfaceWhite,
    gradient: dark ? charcoal : null,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: dark ? AppTheme.primaryYellow : AppColors.borderLight,
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x11916A16), blurRadius: 18, offset: Offset(0, 5)),
    ],
  );
  static EdgeInsets pagePadding(BuildContext context, {double maxWidth = 880}) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = width > maxWidth ? (width - maxWidth) / 2 + 16 : 16.0;
    return EdgeInsets.fromLTRB(inset, 4, inset, 20);
  }
}

class CustomerSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const CustomerSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.darkGold, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                LocalizedText(
                  subtitle!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class CustomerHero extends StatelessWidget {
  final String title;
  final bool localizeTitle;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  const CustomerHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.localizeTitle = true,
  });
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: CustomerVisual.panel(dark: true),
    child: PremiumAtmosphere(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: CustomerVisual.gold,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.darkBg, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizeTitle ? localizedLabel(context, title) : title,
                    style: const TextStyle(
                      color: AppTheme.primaryYellow,
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LocalizedText(
                    subtitle,
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 12),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Decorative lighting and ribbons, separate from catalog photographs.
class PremiumAtmosphere extends StatelessWidget {
  const PremiumAtmosphere({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF080808), Color(0xFF34230D), Color(0xFF0D0C0A)],
      ),
    ),
    child: CustomPaint(painter: const _PremiumRibbonPainter(), child: child),
  );
}

class _PremiumRibbonPainter extends CustomPainter {
  const _PremiumRibbonPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.75, -.8),
          radius: 1,
          colors: [Color(0x887E500E), Color(0x007E500E)],
        ).createShader(bounds),
    );
    final ribbon = Path()
      ..moveTo(0, size.height * .94)
      ..cubicTo(
        size.width * .26,
        size.height * .42,
        size.width * .7,
        size.height * 1.2,
        size.width,
        size.height * .62,
      );
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = const Color(0x667E500E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = const Color(0x99FFC400)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    for (var i = 0; i < 18; i++) {
      final position = Offset(
        size.width * ((i * 37 % 97) / 97),
        size.height * ((i * 29 % 89) / 89),
      );
      canvas.drawCircle(
        position,
        i % 3 == 0 ? 1.5 : .65,
        Paint()..color = const Color(0x55FFDA70),
      );
    }
  }

  @override
  bool shouldRepaint(_PremiumRibbonPainter oldDelegate) => false;
}
