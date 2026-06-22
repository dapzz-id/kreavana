import 'package:flutter/material.dart';
import '../app/theme.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.text = 'Lanjutkan dengan Google',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.inputDark : AppTheme.inputLight;
    final borderColor = isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight;
    final foregroundColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: _GoogleLogo(),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: foregroundColor,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Blue
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      -0.5,
      1.6,
      true,
      bluePaint,
    );

    // Green
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      1.1,
      1.3,
      true,
      greenPaint,
    );

    // Yellow
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      2.4,
      1.1,
      true,
      yellowPaint,
    );

    // Red
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, w, h),
      3.5,
      1.3,
      true,
      redPaint,
    );

    // White center
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      w * 0.3,
      whitePaint,
    );

    // Cut-out right side for the "G" shape
    final cutPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.48, h * 0.38, w * 0.52, h * 0.24),
      cutPaint,
    );

    // White bar on right
    final barPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.48, h * 0.42, w * 0.3, h * 0.16),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
