import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../services/address_service.dart';
import '../utils/app_errors.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/animated_input_field.dart';
import '../widgets/gradient_button.dart';

import '../widgets/skeleton/skeleton_list.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<UserAddress> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final addresses = await AddressService.getAddresses();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.error(context, AppErrors.friendly(e));
      }
    }
  }

  Future<void> _openForm({UserAddress? address}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressFormSheet(address: address),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _confirmDelete(UserAddress address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Alamat?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Alamat "${address.label}" (${address.city}) akan dihapus dari daftar Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final result = await AddressService.deleteAddress(address.id);
      if (!mounted) return;
      if (result['status'] == true) {
        AppSnackbar.success(context, 'Alamat dihapus');
        await _load();
      } else {
        AppSnackbar.error(context, AppErrors.messageFromResult(result));
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
    }
  }

  Future<void> _setDefault(UserAddress address) async {
    try {
      final result = await AddressService.setDefault(address.id);
      if (!mounted) return;
      if (result['status'] == true) {
        AppSnackbar.success(context, 'Alamat ${address.label} kini menjadi alamat utama');
        await _load();
      } else {
        AppSnackbar.error(context, AppErrors.messageFromResult(result));
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, AppErrors.friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_address',
        onPressed: _openForm,
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text('Alamat Saya', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const SkeletonList()
          : _addresses.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryPurple,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      AppEmptyState(
                        icon: Icons.location_on_outlined,
                        title: 'Belum Ada Alamat',
                        subtitle: 'Tambahkan alamat pengiriman untuk memudahkan transaksi di Kreavana.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryPurple,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => AnimatedEntrance(
                      delay: Duration(milliseconds: 80 + i * 70),
                      child: _buildCard(_addresses[i], isDark),
                    ),
                  ),
                ),
    );
  }

  Widget _buildCard(UserAddress a, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBg : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: a.isDefault
              ? AppTheme.primaryPurple.withValues(alpha: 0.5)
              : (isDark ? AppTheme.inputBorder : Colors.grey.shade200),
          width: a.isDefault ? 1.5 : 1,
        ),
        boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_outlined, color: AppTheme.primaryPurple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(a.label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    if (a.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('UTAMA',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: isDark ? AppTheme.cardBg : Colors.white,
                onSelected: (v) {
                  if (v == 'edit') _openForm(address: a);
                  if (v == 'default') _setDefault(a);
                  if (v == 'delete') _confirmDelete(a);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: const Row(children: [
                    Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Ubah')
                  ])),
                  PopupMenuItem(value: 'default', child: const Row(children: [
                    Icon(Icons.star_outline_rounded, size: 18), SizedBox(width: 10), Text('Jadikan Utama')
                  ])),
                  PopupMenuItem(value: 'delete', child: Row(children: [
                    const Icon(Icons.delete_outline, size: 18), const SizedBox(width: 10),
                    Text('Hapus', style: TextStyle(color: AppTheme.error))
                  ])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${a.recipientName} • ${a.phone}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textWhite : AppTheme.textDark)),
          const SizedBox(height: 4),
          Text(a.address,
              style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
          const SizedBox(height: 2),
          Text('${a.city}, ${a.province} ${a.postalCode}',
              style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight)),
        ],
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final UserAddress? address;

  const _AddressFormSheet({this.address});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _postalCtrl;
  bool _isDefault = false;
  bool _isSaving = false;

  static const _labels = ['Rumah', 'Kantor', 'Toko', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _labelCtrl = TextEditingController(text: a?.label ?? 'Rumah');
    _nameCtrl = TextEditingController(text: a?.recipientName ?? '');
    _phoneCtrl = TextEditingController(text: a?.phone ?? '');
    _addressCtrl = TextEditingController(text: a?.address ?? '');
    _cityCtrl = TextEditingController(text: a?.city ?? '');
    _provinceCtrl = TextEditingController(text: a?.province ?? '');
    _postalCtrl = TextEditingController(text: a?.postalCode ?? '');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final province = _provinceCtrl.text.trim();
    final postal = _postalCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || address.isEmpty ||
        city.isEmpty || province.isEmpty || postal.isEmpty) {
      AppSnackbar.error(context, 'Lengkapi semua kolom terlebih dahulu.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = widget.address == null
          ? await AddressService.addAddress(
              label: label, recipientName: name, phone: phone,
              address: address, city: city, province: province,
              postalCode: postal, isDefault: _isDefault)
          : await AddressService.updateAddress(
              id: widget.address!.id,
              label: label, recipientName: name, phone: phone,
              address: address, city: city, province: province,
              postalCode: postal, isDefault: _isDefault);
      if (!mounted) return;
      if (result['status'] == true) {
        Navigator.pop(context, true);
      } else {
        setState(() => _isSaving = false);
        AppSnackbar.error(context, AppErrors.messageFromResult(result));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.error(context, AppErrors.friendly(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.address != null;

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Ubah Alamat' : 'Tambah Alamat',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _labels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final l = _labels[i];
                  final selected = _labelCtrl.text == l;
                  return GestureDetector(
                    onTap: () => setState(() => _labelCtrl.text = l),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(colors: [AppTheme.primaryPurple, AppTheme.lightPurple])
                            : null,
                        color: selected ? null : (isDark ? AppTheme.inputDark : AppTheme.inputLight),
                        borderRadius: BorderRadius.circular(12),
                        border: selected ? null : Border.all(color: isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight),
                      ),
                      child: Text(l,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : (isDark ? AppTheme.textWhite : AppTheme.textDark),
                          )),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            AnimatedInputField(controller: _nameCtrl, label: 'Nama Penerima', hint: 'Nama penerima paket / tagihan', icon: Icons.person_outline),
            const SizedBox(height: 12),
            AnimatedInputField(controller: _phoneCtrl, label: 'No. Telepon', hint: 'Contoh: 0812-3456-7890', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            AnimatedInputField(
              controller: _addressCtrl,
              label: 'Alamat Lengkap',
              hint: 'Jalan, nomor rumah, RT/RW, kelurahan',
              icon: Icons.home_outlined,
            ),
            const SizedBox(height: 12),
            AnimatedInputField(controller: _cityCtrl, label: 'Kota / Kabupaten', hint: 'Contoh: Bandung', icon: Icons.location_city_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: AnimatedInputField(controller: _provinceCtrl, label: 'Provinsi', hint: 'Jawa Barat', icon: Icons.map_outlined)),
                const SizedBox(width: 12),
                Expanded(child: AnimatedInputField(controller: _postalCtrl, label: 'Kode Pos', hint: '40123', icon: Icons.markunread_mailbox_outlined, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jadikan alamat utama', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Digunakan sebagai default alamat pengiriman',
                style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
              ),
              value: _isDefault,
              activeThumbColor: AppTheme.primaryPurple,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 14),
            GradientButton(
              isLoading: _isSaving,
              onPressed: _save,
              text: isEdit ? 'Simpan Perubahan' : 'Simpan Alamat',
            ),
          ],
        ),
      ),
    );
  }
}