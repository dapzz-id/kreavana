import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../utils/app_errors.dart';
import '../services/opportunity_service.dart';
import '../widgets/animated_input_field.dart';
import '../widgets/gradient_button.dart';
import 'daftar_kebutuhan_screen.dart';

class BuatKebutuhanScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialDescription;
  final String? initialKategori;
  final String? initialBudget;

  const BuatKebutuhanScreen({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.initialKategori,
    this.initialBudget,
  });

  @override
  State<BuatKebutuhanScreen> createState() => _BuatKebutuhanScreenState();
}

class _BuatKebutuhanScreenState extends State<BuatKebutuhanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  bool _submitting = false;

  String _selectedKategori = 'fotografi';
  String _selectedBudget = '< Rp 500.000';
  String _selectedDeadline = '1 Minggu';

  static const List<Map<String, dynamic>> _kategoriItems = [
    {'value': 'fotografi', 'label': 'Fotografi', 'icon': Icons.camera_alt_rounded},
    {'value': 'videografi', 'label': 'Videografi', 'icon': Icons.videocam_rounded},
    {'value': 'desain-grafis', 'label': 'Desain Grafis', 'icon': Icons.palette_rounded},
    {'value': 'konten-kreator', 'label': 'Konten Kreator', 'icon': Icons.forum_rounded},
    {'value': 'lainnya', 'label': 'Lainnya', 'icon': Icons.more_horiz_rounded},
  ];

  static const _budgetItems = [
    '< Rp 500.000',
    'Rp 500.000 - 1.000.000',
    'Rp 1.000.000 - 5.000.000',
    '> Rp 5.000.000',
  ];

  static const List<Map<String, dynamic>> _deadlineItems = [
    {'value': '1 Minggu', 'days': 7},
    {'value': '2 Minggu', 'days': 14},
    {'value': '1 Bulan', 'days': 30},
    {'value': '3 Bulan', 'days': 90},
    {'value': 'Fleksibel', 'days': 90},
  ];

  String get subRoleSlug => _selectedKategori;

  String get deadlineDate {
    final days = _deadlineItems.firstWhere((d) => d['value'] == _selectedDeadline)['days'] as int;
    return DateTime.now().add(Duration(days: days)).toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) _judulController.text = widget.initialTitle!;
    if (widget.initialDescription != null) _deskripsiController.text = widget.initialDescription!;
    if (widget.initialKategori != null) _selectedKategori = widget.initialKategori!;
    if (widget.initialBudget != null) _selectedBudget = widget.initialBudget!;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final result = await OpportunityService.createOpportunity(
        title: _judulController.text.trim(),
        subRoleSlug: subRoleSlug,
        type: 'project',
        description: _deskripsiController.text.trim().isNotEmpty
            ? _deskripsiController.text.trim()
            : null,
        budgetRange: _selectedBudget,
        deadline: deadlineDate,
      );

      if (!mounted) return;

      if (result['status'] == true) {
        AppSnackbar.success(context, 'Kebutuhan berhasil dibuat!');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DaftarKebutuhanScreen()),
        );
      } else {
        AppSnackbar.error(context, AppErrors.messageFromResult(result));
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, AppErrors.friendly(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Buat Kebutuhan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: EntranceList(
            stepDelay: const Duration(milliseconds: 60),
            children: [
              // ── Info banner ──
              _InfoBanner(isDark: isDark),
              const SizedBox(height: 28),

              // ── Judul ──
              AnimatedInputField(
                controller: _judulController,
                label: 'Judul Kebutuhan',
                hint: 'Contoh: Foto Katalog Produk Fashion',
                icon: Icons.title_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  if (v.trim().length < 5) return 'Minimal 5 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // ── Kategori ──
              _AnimatedDropdown(
                label: 'Kategori',
                icon: Icons.category_rounded,
                value: _selectedKategori,
                items: _kategoriItems,
                onChanged: (v) => setState(() => _selectedKategori = v!),
              ),
              const SizedBox(height: 18),

              // ── Deskripsi ──
              _AnimatedTextArea(
                controller: _deskripsiController,
                label: 'Deskripsi Kebutuhan',
                hint: 'Jelaskan detail kebutuhan Anda...',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // ── Budget ──
              _AnimatedDropdown(
                label: 'Budget Estimasi',
                icon: Icons.payments_rounded,
                value: _selectedBudget,
                items: _budgetItems
                    .map((e) => <String, dynamic>{'value': e, 'label': e})
                    .toList(),
                onChanged: (v) => setState(() => _selectedBudget = v!),
              ),
              const SizedBox(height: 18),

              // ── Deadline ──
              _AnimatedDropdown(
                label: 'Deadline',
                icon: Icons.event_rounded,
                value: _selectedDeadline,
                items: _deadlineItems
                    .map((e) => <String, dynamic>{'value': e['value'] as String, 'label': e['value'] as String})
                    .toList(),
                onChanged: (v) => setState(() => _selectedDeadline = v!),
              ),
              const SizedBox(height: 32),

              // ── Submit ──
              GradientButton(
                text: 'Kirim Kebutuhan',
                icon: Icons.send_rounded,
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info Banner ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool isDark;
  const _InfoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppTheme.primaryPurple,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Jelaskan kebutuhan Anda agar kreator bisa memberikan proposal yang tepat.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Dropdown ────────────────────────────────────────────────────────

class _AnimatedDropdown extends StatefulWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<String?> onChanged;

  const _AnimatedDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_AnimatedDropdown> createState() => _AnimatedDropdownState();
}

class _AnimatedDropdownState extends State<_AnimatedDropdown> {
  late FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark ? AppTheme.inputDark : AppTheme.inputLight;
    final primary = theme.colorScheme.primary;
    final borderColor = _focused
        ? primary
        : (isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight);

    final selectedLabel = (widget.items
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (e) => e['value'] == widget.value,
          orElse: () => widget.items.cast<Map<String, dynamic>>().first,
        )['label'] ??
        '') as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _focused
                ? primary
                : (isDark ? Colors.white70 : Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showPicker(context),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: borderColor,
                width: _focused ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: _focused
                      ? primary
                      : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.items.map((item) {
                final isSelected = item['value'] == widget.value;
                return ListTile(
                  leading: item['icon'] != null
                      ? Icon(
                          (item['icon'] as IconData?) ?? Icons.image_outlined,
                          color: isSelected
                              ? AppTheme.primaryPurple
                              : (isDark ? Colors.white54 : Colors.grey.shade500),
                          size: 22,
                        )
                      : null,
                  title: Text(
                    item['label'] ?? item['value']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: AppTheme.primaryPurple, size: 20)
                      : null,
                  onTap: () {
                    widget.onChanged(item['value']);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

}

// ─── Animated Text Area ───────────────────────────────────────────────────────

class _AnimatedTextArea extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;

  const _AnimatedTextArea({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
  });

  @override
  State<_AnimatedTextArea> createState() => _AnimatedTextAreaState();
}

class _AnimatedTextAreaState extends State<_AnimatedTextArea> {
  late FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark ? AppTheme.inputDark : AppTheme.inputLight;
    final primary = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: AppMotion.fast,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _focused
                ? primary
                : (isDark ? Colors.white70 : Colors.grey.shade600),
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLines: 5,
          minLines: 3,
          textInputAction: TextInputAction.newline,
          validator: widget.validator,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: fill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(
                color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(
                color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: const BorderSide(color: AppTheme.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.8),
            ),
            errorStyle: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w500),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
