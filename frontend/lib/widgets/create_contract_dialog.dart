import 'package:flutter/material.dart';
import '../services/contract_escrow_service.dart';

class CreateContractDialog extends StatefulWidget {
  final String creatorId;
  final String creatorName;
  final String clientId;
  final String clientName;

  const CreateContractDialog({
    super.key,
    required this.creatorId,
    required this.creatorName,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<CreateContractDialog> createState() => _CreateContractDialogState();
}

class _CreateContractDialogState extends State<CreateContractDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _termsController = TextEditingController(
    text:
        'Penyelesaian wajib disetujui kedua pihak sebelum pencairan dana. Garansi revisi 2x.',
  );
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final amount =
          double.tryParse(
            _amountController.text.replaceAll('.', '').replaceAll(',', ''),
          ) ??
          0.0;
      final contractId =
          'KONTRAK-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      final deadlineStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final contract = JobContract(
        id: contractId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        amount: amount,
        deadline: deadlineStr,
        terms: _termsController.text.trim(),
        creatorId: widget.creatorId,
        creatorName: widget.creatorName,
        clientId: widget.clientId,
        clientName: widget.clientName,
      );

      Navigator.pop(context, contract);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.description,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Buat Kontrak Pekerjaan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Isi kesepakatan job antara Klien & Kreator secara transparan dan aman.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Pekerjaan / Project',
                    hintText: 'Contoh: Pembuatan Video Promosi Brand',
                    prefixIcon: Icon(Icons.work_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Judul pekerjaan wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi & Lingkup Pekerjaan',
                    hintText:
                        'Tuliskan rincian hasil karya, format deliverable, dan revisi...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Deskripsi pekerjaan wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nilai Kontrak (Rp)',
                    hintText: 'Contoh: 3500000',
                    prefixIcon: Icon(Icons.monetization_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return 'Nilai kontrak wajib diisi';
                    final num = double.tryParse(
                      val.replaceAll('.', '').replaceAll(',', ''),
                    );
                    if (num == null || num <= 0)
                      return 'Nilai kontrak tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tenggat Waktu / Deadline',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedDate.day}-${_selectedDate.month}-${_selectedDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.edit_calendar, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Syarat & Ketentuan',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Ajukan Kontrak'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
