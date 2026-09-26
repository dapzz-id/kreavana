import 'package:flutter/material.dart';

enum VerificationBadgeSize { small, medium, large }

class VerificationBadge extends StatelessWidget {
  final String role; // 'creator' or 'user' (client)
  final bool isVerified;
  final VerificationBadgeSize size;
  final bool showLabel;

  const VerificationBadge({
    super.key,
    required this.role,
    required this.isVerified,
    this.size = VerificationBadgeSize.medium,
    this.showLabel = false,
  });

  bool get isCreator => role.toLowerCase() == 'creator';
  bool get isClient => role.toLowerCase() == 'user';

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    final isGreen = isCreator;
    final primaryColor = isGreen ? const Color(0xFF10B981) : const Color(0xFF2563EB);
    final secondaryColor = isGreen ? const Color(0xFF059669) : const Color(0xFF1D4ED8);
    final labelText = isGreen ? 'Kreator Terverifikasi' : 'Klien Terverifikasi';

    double iconSize = 16;
    double fontSize = 11;
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);

    switch (size) {
      case VerificationBadgeSize.small:
        iconSize = 13;
        fontSize = 9.5;
        padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2);
        break;
      case VerificationBadgeSize.medium:
        iconSize = 16;
        fontSize = 11;
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5);
        break;
      case VerificationBadgeSize.large:
        iconSize = 20;
        fontSize = 12.5;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5);
        break;
    }

    if (!showLabel) {
      return Tooltip(
        message: labelText,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            Icons.verified_rounded,
            color: primaryColor,
            size: iconSize,
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.12),
            secondaryColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            color: primaryColor,
            size: iconSize,
          ),
          const SizedBox(width: 4),
          Text(
            labelText,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
