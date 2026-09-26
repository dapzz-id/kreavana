import 'package:flutter/material.dart';

/// Official Google Sign-In Button according to Google Identity Branding Guidelines.
class GoogleSignInButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    this.text = 'Lanjutkan dengan Google',
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Google Identity Design System specs
    final bgColor = isDark
        ? (_isHovered ? const Color(0xFF2D3748) : const Color(0xFF1E293B))
        : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white);

    final borderColor = isDark
        ? (_isHovered ? const Color(0xFF64748B) : const Color(0xFF475569))
        : (_isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFDADCE0));

    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF3C4043);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            if (_isHovered && !widget.isLoading)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.isLoading ? null : widget.onPressed,
            splashColor: const Color(0xFF4285F4).withValues(alpha: 0.1),
            highlightColor: const Color(0xFF4285F4).withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: widget.isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFF818CF8) : const Color(0xFF4285F4),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Official Google G Logo
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Image.asset(
                            'assets/google_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const _VectorGoogleLogo(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.text,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback crisp vector Google 'G' icon
class _VectorGoogleLogo extends StatelessWidget {
  const _VectorGoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // Blue section (Right bar & top right)
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    // Green section (Bottom right & bottom)
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    // Yellow section (Bottom left & left)
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    // Red section (Top left & top)
    final redPaint = Paint()..color = const Color(0xFFEA4335);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final innerRect = Rect.fromCircle(center: center, radius: radius * 0.55);

    // Draw 4 distinct arcs
    final pathRed = Path()
      ..arcTo(rect, -2.35, 1.55, false)
      ..arcTo(innerRect, -0.8, -1.55, false)
      ..close();
    canvas.drawPath(pathRed, redPaint);

    final pathYellow = Path()
      ..arcTo(rect, -3.9, 1.55, false)
      ..arcTo(innerRect, -2.35, -1.55, false)
      ..close();
    canvas.drawPath(pathYellow, yellowPaint);

    final pathGreen = Path()
      ..arcTo(rect, 0.75, 1.6, false)
      ..arcTo(innerRect, 2.35, -1.6, false)
      ..close();
    canvas.drawPath(pathGreen, greenPaint);

    final pathBlue = Path()
      ..arcTo(rect, -0.8, 1.55, false)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx, center.dy - radius * 0.35)
      ..lineTo(center.dx + radius * 0.9, center.dy - radius * 0.35)
      ..arcTo(innerRect, 0.75, -1.55, false)
      ..close();
    canvas.drawPath(pathBlue, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
