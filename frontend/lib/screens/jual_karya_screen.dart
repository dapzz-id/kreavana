import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kreavana/services/marketplace_service.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../utils/app_errors.dart';
import '../widgets/animated_input_field.dart';
import '../widgets/gradient_button.dart';

/// Form untuk user membuat karya/layanan baru di marketplace.
/// Data dikirim sungguhan ke backend (POST /marketplace).
class JualKaryaScreen extends StatefulWidget {
  const JualKaryaScreen({super.key});

  @override
  State<JualKaryaScreen> createState() => _JualKaryaScreenState();
}

class _JualKaryaScreenState extends State<JualKaryaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _judulCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();

  String _kategori = 'Fotografi';
  String _type = 'paid';
  bool _submitting = false;
  List<PlatformFile> _media = [];

  static const _kategoriItems = [
    'Fotografi',
    'Videografi',
    'Desain',
    'Konten',
    'Branding',
  ];

  @override
  void dispose() {
    _judulCtrl.dispose();
    _deskripsiCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_hargaCtrl.text.trim()) ?? 0;
    if (_type == 'paid' && price <= 0) {
      AppSnackbar.error(context, 'Harga harus lebih dari 0 untuk tipe berbayar.');
      return;
    }
    if (_media.isEmpty) {
      AppSnackbar.error(context, 'Pilih setidaknya 1 foto atau video.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await MarketplaceService.createItem(
        title: _judulCtrl.text.trim(),
        description: _deskripsiCtrl.text.trim().isNotEmpty
            ? _deskripsiCtrl.text.trim()
            : null,
        category: _kategori,
        type: _type,
        price: price,
        media: _media,
      );

      if (!mounted) return;

      if (result['status'] == true) {
        AppSnackbar.success(context, 'Karya berhasil dipublikasikan!');
        Navigator.pop(context, true);
      } else {
        AppSnackbar.error(context, AppErrors.messageFromResult(result));
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
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
          'Jual Karya',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.15),
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
                        Icons.storefront_rounded,
                        color: AppTheme.primaryPurple,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Publikasikan karya atau layanan Anda. Pembeli bisa melihat, memberi ulasan, dan menghubungi Anda langsung.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark
                              ? Colors.white70
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              AnimatedInputField(
                controller: _judulCtrl,
                label: 'Judul Karya',
                hint: 'Contoh: Foto Katalog Produk Makanan',
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
              _KategoriPicker(
                selected: _kategori,
                items: _kategoriItems,
                onChanged: (v) => setState(() => _kategori = v),
              ),
              const SizedBox(height: 18),

              // Type Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tipe Karya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Berbayar', style: TextStyle(fontSize: 14)),
                          value: 'paid',
                          groupValue: _type,
                          onChanged: (v) => setState(() => _type = v!),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.primaryPurple,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Gratis', style: TextStyle(fontSize: 14)),
                          value: 'free',
                          groupValue: _type,
                          onChanged: (v) => setState(() => _type = v!),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_type == 'paid') ...[
                const SizedBox(height: 18),
                AnimatedInputField(
                  controller: _hargaCtrl,
                  label: 'Harga (Rp)',
                  hint: '0',
                  icon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Harga wajib diisi';
                    final num = double.tryParse(val.trim());
                    if (num == null || num <= 0) return 'Format harga tidak valid';
                    return null;
                  },
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 18),

              // File Picker
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardBg : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Foto / Video', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          allowMultiple: true,
                          type: FileType.media,
                        );
                        if (result != null) {
                          setState(() {
                            _media = result.files;
                          });
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Pilih File (Bisa lebih dari 1)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.primaryPurple,
                        elevation: 0,
                      ),
                    ),
                    if (_media.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _media.map((f) => Chip(
                          label: Text(f.name, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _media.remove(f);
                            });
                          },
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _AnimatedTextArea(
                controller: _deskripsiCtrl,
                label: 'Deskripsi Karya',
                hint: 'Jelaskan detail layanan Anda...',
              ),
              const SizedBox(height: 32),

              GradientButton(
                text: 'Publikasikan Karya',
                icon: Icons.rocket_launch_rounded,
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

// ─── Kategori Picker ──────────────────────────────────────────────────────────

class _KategoriPicker extends StatelessWidget {
  final String selected;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _KategoriPicker({
    required this.selected,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((cat) {
            final isSelected = cat == selected;
            return Pressable(
              onTap: () => onChanged(cat),
              pressedScale: 0.95,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            AppTheme.primaryPurple,
                            AppTheme.lightPurple,
                          ],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? AppTheme.inputDark : AppTheme.inputLight),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isDark
                              ? AppTheme.inputBorder
                              : AppTheme.inputBorderLight,
                        ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? AppTheme.textWhite
                            : AppTheme.textDark),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Animated Text Area ───────────────────────────────────────────────────────

class _AnimatedTextArea extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _AnimatedTextArea({
    required this.controller,
    required this.label,
    required this.hint,
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
              borderSide: const BorderSide(
                color: AppTheme.primaryPurple,
                width: 1.8,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
