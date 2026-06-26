import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/opportunity_model.dart';
import '../services/opportunity_service.dart';
import '../app/theme.dart';

class OpportunityDetailSheet extends StatelessWidget {
  final OpportunityModel opportunity;
  final int currentUserId;

  const OpportunityDetailSheet({
    super.key,
    required this.opportunity,
    required this.currentUserId,
  });

  static Future<void> show(
    BuildContext context, {
    required OpportunityModel opportunity,
    required int currentUserId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OpportunityDetailSheet(
        opportunity: opportunity,
        currentUserId: currentUserId,
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showReportDialog(BuildContext context) {
    final reasons = [
      'Konten palsu / penipuan',
      'Informasi kontak tidak valid',
      'Lokasi tidak sesuai',
      'Spam / iklan',
      'Lainnya',
    ];
    String selectedReason = reasons.first;
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Laporkan Peluang'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih alasan laporan:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...reasons.map(
                  (r) => RadioListTile<String>(
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) => setState(() => selectedReason = v!),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Detail (opsional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await OpportunityService.submitReport(
                  targetType: 'opportunity',
                  targetId: opportunity.id,
                  reason: selectedReason,
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Laporan terkirim'),
                      backgroundColor: result['success'] == true
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Kirim Laporan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final poster = opportunity.poster;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardBg : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: opportunity.isLocation
                          ? Colors.teal.withValues(alpha: 0.15)
                          : Colors.indigo.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      opportunity.isLocation ? 'Peluang Lokasi' : 'Peluang Proyek',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: opportunity.isLocation
                            ? Colors.teal.shade700
                            : Colors.indigo.shade700,
                      ),
                    ),
                  ),
                  if (opportunity.locationCategory != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        opportunity.locationCategoryLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                opportunity.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (opportunity.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  opportunity.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (opportunity.location != null)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: opportunity.address ?? opportunity.location!,
                ),
              if (opportunity.budgetRange != null)
                _InfoRow(
                  icon: Icons.payments_outlined,
                  label: opportunity.budgetRange!,
                ),
              if (opportunity.deadline != null)
                _InfoRow(
                  icon: Icons.event_outlined,
                  label: 'Deadline: ${opportunity.deadline}',
                ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Kontak Pembuat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (poster != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: poster.avatarUrl != null &&
                              poster.avatarUrl!.isNotEmpty
                          ? NetworkImage(poster.avatarUrl!)
                          : null,
                      child: poster.avatarUrl == null ||
                              poster.avatarUrl!.isEmpty
                          ? Text(
                              poster.name.isNotEmpty
                                  ? poster.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poster.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '@${poster.username}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (poster.phone != null && poster.phone!.isNotEmpty)
                  _ContactButton(
                    icon: Icons.phone,
                    label: poster.phone!,
                    color: Colors.green,
                    onTap: () => _callPhone(poster.phone!),
                  ),
                if (poster.email != null && poster.email!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ContactButton(
                    icon: Icons.email_outlined,
                    label: poster.email!,
                    color: Colors.blue,
                    onTap: () => _sendEmail(poster.email!),
                  ),
                ],
                if ((poster.phone == null || poster.phone!.isEmpty) &&
                    (poster.email == null || poster.email!.isEmpty))
                  Text(
                    'Kontak tidak tersedia. Hubungi via chat Kreavana.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                    ),
                  ),
              ] else
                const Text(
                  'Memuat informasi kontak...',
                  style: TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 20),
              if (poster != null && poster.id != currentUserId)
                OutlinedButton.icon(
                  onPressed: () => _showReportDialog(context),
                  icon: const Icon(Icons.flag_outlined, color: Colors.red),
                  label: const Text(
                    'Laporkan Peluang',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color.shade700,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color.shade400),
          ],
        ),
      ),
    );
  }
}

extension on Color {
  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  Color get shade400 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
  }
}
