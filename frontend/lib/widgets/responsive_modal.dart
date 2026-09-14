import 'package:flutter/material.dart';
import '../app/theme.dart';

class ResponsiveModal extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final double maxWidth;
  final double maxHeightFactor;
  final VoidCallback? onClose;

  const ResponsiveModal({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.footer,
    this.maxWidth = 640,
    this.maxHeightFactor = 0.88,
    this.onClose,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget body,
    Widget? footer,
    double maxWidth = 640,
    double maxHeightFactor = 0.88,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (!isDesktop) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * maxHeightFactor,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? AppTheme.cardBg
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _buildHeader(ctx, title, subtitle, null),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: body,
                    ),
                  ),
                  if (footer != null) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: footer,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(ctx).size.height * maxHeightFactor,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).brightness == Brightness.dark
                  ? AppTheme.cardBg
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(ctx, title, subtitle, () => Navigator.of(ctx).pop()),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: body,
                    ),
                  ),
                  if (footer != null) ...[
                    const Divider(height: 1),
                    Container(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: footer,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader(BuildContext context, String title, String? subtitle, VoidCallback? onClose) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Tutup',
            onPressed: onClose ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, title, subtitle, onClose),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: body,
                ),
              ),
              if (footer != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: footer,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
