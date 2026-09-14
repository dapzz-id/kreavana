import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/opportunity_model.dart';
import '../models/opportunity_application_model.dart';
import '../services/opportunity_service.dart';
import '../services/chat_service.dart';
import '../screens/direct_message_screen.dart';
import '../widgets/responsive_modal.dart';
import '../app/theme.dart';
import '../services/app_router.dart';
import 'package:go_router/go_router.dart';

class OpportunityDetailSheet extends StatefulWidget {
  final OpportunityModel opportunity;
  final String currentUserId;
  final bool isCreator;

  const OpportunityDetailSheet({
    super.key,
    required this.opportunity,
    required this.currentUserId,
    this.isCreator = true,
  });

  static Future<void> show(
    BuildContext context, {
    required OpportunityModel opportunity,
    String? currentUserId,
    bool isCreator = true,
  }) {
    return ResponsiveModal.show(
      context: context,
      title: opportunity.title,
      subtitle: opportunity.location ?? 'Lokasi Fleksibel',
      maxWidth: 680,
      body: OpportunityDetailSheet(
        opportunity: opportunity,
        currentUserId: currentUserId ?? '',
        isCreator: isCreator,
      ),
    );
  }

  @override
  State<OpportunityDetailSheet> createState() => _OpportunityDetailSheetState();
}

class _OpportunityDetailSheetState extends State<OpportunityDetailSheet> {
  bool get _isOwner =>
      widget.currentUserId.isNotEmpty &&
      widget.opportunity.postedBy != null &&
      widget.opportunity.postedBy == widget.currentUserId;

  bool get _isGuest => widget.currentUserId.isEmpty;

  void _openChat(
    BuildContext context, {
    required String userId,
    String? name,
  }) async {
    if (_isGuest) {
      _showLoginPrompt(context, 'menghubungi pembuat proyek via chat');
      return;
    }

    try {
      final result = await ChatService.startPersonalChat(userId);
      if (!context.mounted) return;

      final chatData = result['data'];
      if (chatData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal membuka chat.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      final chatId = chatData['id'] as String;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectMessageScreen(
            chatId: chatId,
          ),
        ),
      );
    } catch (_) {}
  }

  void _showLoginPrompt(BuildContext context, String actionDesc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Masuk Diperlukan'),
        content: Text('Silakan masuk atau daftar akun terlebih dahulu untuk $actionDesc.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop(); // Close detail sheet
              context.push(AppRoutes.login);
            },
            child: const Text('Masuk Sekarang', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showApplicationDialog(BuildContext context) {
    if (_isGuest) {
      _showLoginPrompt(context, 'mengajukan lamaran proyek ini');
      return;
    }

    final reqs = widget.opportunity.requirements.isNotEmpty
        ? widget.opportunity.requirements
        : [OpportunityRequirementModel(subRoleSlug: widget.opportunity.subRoleSlug)];

    String selectedSlug = reqs.first.subRoleSlug;
    final pitchCtrl = TextEditingController();
    final questionsCtrl = TextEditingController();
    final bidCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.assignment_turned_in, color: AppTheme.primaryPurple),
                SizedBox(width: 8),
                Text('Ambil Peluang Proyek', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih posisi yang ingin Anda ambil:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: reqs.map((r) {
                        final isSelected = selectedSlug == r.subRoleSlug;
                        return ChoiceChip(
                          label: Text(r.label),
                          selected: isSelected,
                          selectedColor: Colors.teal.withValues(alpha: 0.2),
                          onSelected: (_) {
                            setModalState(() => selectedSlug = r.subRoleSlug);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pitchCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Pesan / Pitching Lamaran *',
                        hintText: 'Jelaskan mengapa Anda cocok untuk proyek ini & pengalaman relevan...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bidCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Penawaran Tarif (Opsional)',
                        hintText: 'Kosongkan jika mengikuti anggaran pemilik proyek',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: questionsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Pertanyaan untuk Klien (Opsional)',
                        hintText: 'Misal: Mengenai rundown acara atau peralatan yang disediakan...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final pitch = pitchCtrl.text.trim();
                        if (pitch.length < 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pesan lamaran minimal 10 karakter.')),
                          );
                          return;
                        }

                        setModalState(() => isSubmitting = true);
                        final bid = double.tryParse(bidCtrl.text.trim());
                        final res = await OpportunityService.applyToOpportunity(
                          opportunityId: widget.opportunity.id ?? '',
                          subRoleSlug: selectedSlug,
                          pitchMessage: pitch,
                          bidPrice: bid,
                          questionsNotes: questionsCtrl.text.trim().isNotEmpty ? questionsCtrl.text.trim() : null,
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Lamaran berhasil dikirim!'),
                              backgroundColor: res['status'] == true ? Colors.teal : Colors.red,
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kirim Lamaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showApplicationsManagerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return FutureBuilder<List<OpportunityApplicationModel>>(
            future: OpportunityService.getOpportunityApplications(widget.opportunity.id ?? ''),
            builder: (context, snapshot) {
              final apps = snapshot.data ?? [];
              final isLoading = snapshot.connectionState == ConnectionState.waiting;

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    const Icon(Icons.people_outline, color: AppTheme.primaryPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Persetujuan Pelamar (${apps.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 550,
                  height: 450,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : apps.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada kreator yang mengajukan diri untuk proyek ini.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: apps.length,
                              separatorBuilder: (_, __) => const Divider(height: 16),
                              itemBuilder: (context, index) {
                                final app = apps[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundImage: app.creator?.avatarUrl != null
                                                ? CachedNetworkImageProvider(app.creator!.avatarUrl!)
                                                : null,
                                            child: app.creator?.avatarUrl == null
                                                ? const Icon(Icons.person, size: 20)
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(app.creator?.name ?? 'Kreator',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                Text('Peran: ${app.subRoleSlug}',
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: app.isApproved
                                                  ? Colors.green.shade100
                                                  : (app.isRejected ? Colors.red.shade100 : Colors.amber.shade100),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              app.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: app.isApproved
                                                    ? Colors.green.shade800
                                                    : (app.isRejected ? Colors.red.shade800 : Colors.amber.shade900),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(app.pitchMessage, style: const TextStyle(fontSize: 13)),
                                      if (app.questionsNotes != null && app.questionsNotes!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('Pertanyaan: ${app.questionsNotes}',
                                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, fontStyle: FontStyle.italic)),
                                      ],
                                      if (app.bidPrice != null) ...[
                                        const SizedBox(height: 4),
                                        Text('Tawaran: Rp ${app.bidPrice!.toStringAsFixed(0)}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                      ],
                                      if (app.isPending) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red.shade700,
                                                side: BorderSide(color: Colors.red.shade300),
                                              ),
                                              onPressed: () async {
                                                await OpportunityService.reviewApplication(
                                                  applicationId: app.id,
                                                  decision: 'reject',
                                                  reason: 'Maaf, kuota belum terpenuhi atau profil belum sesuai.',
                                                );
                                                setDialogState(() {});
                                              },
                                              child: const Text('Tolak'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green.shade700,
                                              ),
                                              onPressed: () async {
                                                await OpportunityService.reviewApplication(
                                                  applicationId: app.id,
                                                  decision: 'approve',
                                                );
                                                setDialogState(() {});
                                              },
                                              child: const Text('Setujui', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showCreatorPublicProfile(BuildContext context, OpportunityPoster poster) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Profil Pembuat Proyek', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage: poster.avatarUrl != null
                  ? CachedNetworkImageProvider(poster.avatarUrl!)
                  : null,
              child: poster.avatarUrl == null ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(height: 12),
            Text(poster.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (poster.selectedSubRole != null) ...[
              const SizedBox(height: 4),
              Text(poster.selectedSubRole!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kontak privat (telepon & email) dilindungi. Komunikasi dilakukan melalui sistem chat resmi Kreavana.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (poster.id != null && poster.id != widget.currentUserId)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
              onPressed: () {
                Navigator.pop(ctx);
                _openChat(context, userId: poster.id!, name: poster.name);
              },
              icon: const Icon(Icons.chat, size: 16, color: Colors.white),
              label: const Text('Kirim Pesan', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opp = widget.opportunity;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Poster Banner (if present)
        if (opp.posterUrl != null && opp.posterUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: opp.posterUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 120,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. Status Badge & Category Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: opp.status == 'open'
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                opp.status == 'open' ? 'TERBUKA' : opp.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: opp.status == 'open' ? Colors.green.shade800 : Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                opp.subRoleLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Procurement-Style Info Cards (SPSE-like)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Jadwal Acara Klien',
                value: opp.eventDate != null
                    ? '${opp.eventDate} ${opp.eventStartTime != null ? '(${opp.eventStartTime} - ${opp.eventEndTime ?? ''})' : ''}'
                    : (opp.deadline != null ? 'Batas Waktu: ${opp.deadline}' : 'Fleksibel'),
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.place_outlined,
                label: 'Lokasi Event',
                value: opp.address ?? opp.location ?? 'Indonesia',
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.payments_outlined,
                label: 'Perkiraan Budget',
                value: opp.budgetRange ?? 'Sesuai Kesepakatan',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Required Capabilities (Multi-Role Breakdown)
        const Text(
          'Keahlian yang Dibutuhkan:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (opp.requirements.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opp.requirements.map((r) {
              return Chip(
                avatar: const Icon(Icons.check_circle_outline, size: 16, color: Colors.teal),
                label: Text(r.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: Colors.teal.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          )
        else
          Chip(
            label: Text(opp.subRoleLabel),
            backgroundColor: Colors.teal.shade50,
          ),
        const SizedBox(height: 16),

        // 5. Approved Creators (Transparency)
        if (opp.approvedCreators.isNotEmpty) ...[
          const Text(
            'Kreator Terpilih & Disetujui:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: opp.approvedCreators.map((ac) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        ac.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        ac.capability ?? ac.subRole ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 6. Creator Public Profile Inspection
        if (opp.poster != null) ...[
          const Text(
            'Pemilik Peluang Proyek:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showCreatorPublicProfile(context, opp.poster!),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      opp.poster!.name.isNotEmpty ? opp.poster!.name[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opp.poster!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (opp.poster!.username.isNotEmpty)
                          Text(
                            '@${opp.poster!.username}',
                            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  const Text(
                    'Lihat Profil →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 7. Action Area
        if (_isOwner) ...[
          ElevatedButton.icon(
            onPressed: () => _showApplicationsManagerDialog(context),
            icon: const Icon(Icons.how_to_reg, color: Colors.white),
            label: const Text('Kelola & Persetujuan Pelamar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: opp.status == 'open' ? () => _showApplicationDialog(context) : null,
                  icon: const Icon(Icons.assignment_turned_in, color: Colors.white),
                  label: Text(
                    opp.status == 'open' ? 'Ambil Peluang' : 'Proyek Ditutup',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (opp.postedBy != null && opp.postedBy != widget.currentUserId) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _openChat(context, userId: opp.postedBy!, name: opp.poster?.name),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
