import 'package:flutter/material.dart';

/// Visual tokens ported from the vvewell Android reference application.
abstract final class VvewellColors {
  static const primary = Color(0xFF18B6A4);
  static const primaryDark = Color(0xFF087D73);
  static const background = Color(0xFFF4F8F7);
  static const surface = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF17312E);
  static const muted = Color(0xFF718B87);
  static const border = Color(0xFFDCE8E6);
  static const success = Color(0xFF25AE72);
  static const warning = Color(0xFFF0A126);
  static const error = Color(0xFFE54842);
  static const softTeal = Color(0xFFE7F6F3);
  static const softMint = Color(0xFFEAF8EF);
  static const softBlue = Color(0xFFEAF3FA);
  static const softViolet = Color(0xFFF1EDFC);
  static const softOrange = Color(0xFFFFF4DE);
  static const softRed = Color(0xFFFFECEA);
}

ThemeData vvewellTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: VvewellColors.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: VvewellColors.primary,
        onPrimary: Colors.white,
        primaryContainer: VvewellColors.softTeal,
        onPrimaryContainer: VvewellColors.primaryDark,
        secondary: VvewellColors.primaryDark,
        onSecondary: Colors.white,
        secondaryContainer: VvewellColors.softBlue,
        surface: VvewellColors.surface,
        onSurface: VvewellColors.foreground,
        surfaceContainerHighest: const Color(0xFFECF2F1),
        onSurfaceVariant: VvewellColors.muted,
        outlineVariant: VvewellColors.border,
        error: VvewellColors.error,
      );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: VvewellColors.background,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: VvewellColors.foreground,
      displayColor: VvewellColors.foreground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: VvewellColors.background,
      foregroundColor: VvewellColors.foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: VvewellColors.foreground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: VvewellColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: rounded,
      clipBehavior: Clip.antiAlias,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        backgroundColor: VvewellColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: VvewellColors.border,
        disabledForegroundColor: VvewellColors.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        foregroundColor: VvewellColors.primaryDark,
        side: const BorderSide(color: VvewellColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VvewellColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: VvewellColors.muted),
      labelStyle: const TextStyle(color: VvewellColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: VvewellColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: VvewellColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: VvewellColors.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: VvewellColors.softTeal,
      side: const BorderSide(color: VvewellColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(color: VvewellColors.primaryDark),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: VvewellColors.surface,
      indicatorColor: VvewellColors.softTeal,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: VvewellColors.muted),
      ),
    ),
    dividerColor: VvewellColors.border,
  );
}

class VvewellCard extends StatelessWidget {
  const VvewellCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class VvewellSectionTitle extends StatelessWidget {
  const VvewellSectionTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?action,
      ],
    );
  }
}

class VvewellStatusPill extends StatelessWidget {
  const VvewellStatusPill({
    super.key,
    required this.label,
    this.color = VvewellColors.success,
    this.icon = Icons.check_circle_outline,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The vvewell mark used in the reference Android launcher icon and in-app headers.
class VvewellMark extends StatelessWidget {
  const VvewellMark({super.key, this.size = 48, this.showShadow = false});

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .08),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        color: Colors.white,
        border: Border.all(color: VvewellColors.border),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF2457C5).withValues(alpha: .18),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Image.asset(
        'assets/images/vvewell-mark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) =>
            CustomPaint(painter: _VvewellMarkFallbackPainter()),
      ),
    );
  }
}

class _VvewellMarkFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2457C5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .15, size.height * .28)
      ..lineTo(size.width * .34, size.height * .72)
      ..lineTo(size.width * .52, size.height * .35)
      ..lineTo(size.width * .67, size.height * .68)
      ..lineTo(size.width * .86, size.height * .25);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
