import 'package:flutter/material.dart';
import '../app/theme.dart';

class RoleToggle extends StatelessWidget {
  final String currentRole;
  final bool isCreator;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback? onApplyPressed;

  const RoleToggle({
    super.key,
    required this.currentRole,
    required this.isCreator,
    required this.onRoleChanged,
    this.onApplyPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Toggle User Role
          Expanded(
            child: GestureDetector(
              onTap: () => onRoleChanged('user'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: currentRole == 'user'
                      ? (isDark ? theme.colorScheme.primary : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: currentRole == 'user' && !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Klien / User',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: currentRole == 'user'
                          ? (isDark ? Colors.white : theme.colorScheme.primary)
                          : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Toggle Creator Role
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isCreator) {
                  onRoleChanged('creator');
                } else if (onApplyPressed != null) {
                  onApplyPressed!();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: currentRole == 'creator'
                      ? (isDark ? theme.colorScheme.secondary : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: currentRole == 'creator' && !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Creator',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: currentRole == 'creator'
                              ? (isDark ? Colors.white : theme.colorScheme.secondary)
                              : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
                        ),
                      ),
                      if (!isCreator) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
