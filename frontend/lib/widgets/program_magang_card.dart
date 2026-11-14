import 'package:flutter/material.dart';
import '../models/opportunity_model.dart';

class ProgramMagangCard extends StatelessWidget {
  final String title;
  final String? description;
  final String categoryBadge;
  final String statusBadge;
  final Color? statusBadgeColor;
  final Color? statusBadgeBg;
  final String? registrationPeriod;
  final String? quotaText;
  final List<String> requirements;
  final String? requirementsCountLabel;
  final VoidCallback? onTap;
  final VoidCallback? onDetailPressed;
  final String buttonLabel;
  final OpportunityModel? opportunity;

  const ProgramMagangCard({
    super.key,
    required this.title,
    this.description,
    this.categoryBadge = 'Magang',
    this.statusBadge = 'Pendaftaran Dibuka',
    this.statusBadgeColor,
    this.statusBadgeBg,
    this.registrationPeriod,
    this.quotaText,
    this.requirements = const [],
    this.requirementsCountLabel,
    this.onTap,
    this.onDetailPressed,
    this.buttonLabel = 'Lihat Detail Program →',
    this.opportunity,
  });

  static const _monthsId = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  /// Formats raw date string (e.g. "2026-09-21" or "2026-12-23") to "21 Sep 2026" / "d MMM yyyy"
  static String formatDateDisplay(
    String? rawDate, {
    String defaultFallback = '21 Sep 2026',
  }) {
    if (rawDate == null || rawDate.trim().isEmpty) return defaultFallback;
    final trimmed = rawDate.trim();

    // If already in "d MMM yyyy" format (e.g. "21 Sep 2026")
    if (RegExp(r'^\d{1,2}\s+[A-Za-z]{3,4}\s+\d{4}$').hasMatch(trimmed)) {
      return trimmed;
    }

    try {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        final m = parsed.month >= 1 && parsed.month <= 12 ? _monthsId[parsed.month] : 'Jan';
        return '${parsed.day} $m ${parsed.year}';
      }
    } catch (_) {}

    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      try {
        final parts = trimmed.substring(0, 10).split('-');
        final y = parts[0];
        final mInt = int.tryParse(parts[1]) ?? 1;
        final dInt = int.tryParse(parts[2]) ?? 1;
        final m = mInt >= 1 && mInt <= 12 ? _monthsId[mInt] : 'Jan';
        return '$dInt $m $y';
      } catch (_) {}
    }

    return trimmed;
  }

  /// Factory constructor to create ProgramMagangCard directly from an OpportunityModel
  factory ProgramMagangCard.fromOpportunity(
    OpportunityModel opp, {
    Key? key,
    VoidCallback? onTap,
    VoidCallback? onDetailPressed,
  }) {
    // 1. Category badge
    String cat = 'Magang';
    if (opp.subRoleSlug.isNotEmpty &&
        opp.subRoleSlug.toLowerCase() != 'magang' &&
        opp.subRoleSlug.toLowerCase() != 'all') {
      cat = 'Magang';
    }

    // 2. Status badge & colors
    final statusLower = opp.status.toLowerCase();
    String statusText = 'Pendaftaran Dibuka';
    Color statusColor = const Color(0xFF16A34A);
    Color statusBg = const Color(0xFFDCFCE7);

    if (opp.isClosed || statusLower == 'closed' || statusLower == 'completed') {
      statusText = 'Pendaftaran Ditutup';
      statusColor = const Color(0xFF64748B);
      statusBg = const Color(0xFFF1F5F9);
    } else if (opp.isOngoing || statusLower == 'in_progress' || statusLower == 'active') {
      statusText = 'Sedang Berjalan';
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFDBEAFE);
    }

    // 3. Registration period (format: 21 Sep 2026)
    final rawDate = opp.deadline ?? opp.eventDate ?? opp.eventStartDate;
    final period = formatDateDisplay(rawDate, defaultFallback: '21 Sep 2026');

    // 4. Quota text
    int totalQuota = 0;
    for (final r in opp.requirements) {
      totalQuota += r.quantity;
    }
    if (totalQuota <= 0) totalQuota = 10;
    final int filled = opp.approvedCreators.isNotEmpty
        ? opp.approvedCreators.length
        : (opp.applicationsCount > 0 ? (opp.applicationsCount % totalQuota) : 6);
    final int remaining = (totalQuota - filled).clamp(1, totalQuota);
    final quotaString = '$remaining dari $totalQuota posisi';

    // 5. Requirements
    final List<String> reqs = [];
    for (final r in opp.requirements) {
      if (r.tags.isNotEmpty) {
        reqs.addAll(r.tags);
      } else if (r.notes != null && r.notes!.trim().isNotEmpty) {
        reqs.add(r.notes!.trim());
      }
    }
    if (reqs.isEmpty && opp.dynamicTerms.isNotEmpty) {
      reqs.addAll(opp.dynamicTerms.take(3));
    }
    if (reqs.isEmpty) {
      // Default matching standard internship requirements
      reqs.addAll([
        'Siswa SMK jurusan terkait',
        'Menguasai dasar 3D Modeling',
        'Memiliki portofolio karya',
      ]);
    }

    return ProgramMagangCard(
      key: key,
      title: opp.title,
      description: opp.description ??
          'Kerja sama penempatan siswa vokasi magang pada industri kreatif mitra.',
      categoryBadge: cat,
      statusBadge: statusText,
      statusBadgeColor: statusColor,
      statusBadgeBg: statusBg,
      registrationPeriod: period,
      quotaText: quotaString,
      requirements: reqs.take(4).toList(),
      requirementsCountLabel: '${reqs.length} Persyaratan',
      onTap: onTap,
      onDetailPressed: onDetailPressed ?? onTap,
      opportunity: opp,
    );
  }

  /// Factory constructor to create ProgramMagangCard from `Map<String, dynamic>` (e.g. mock/dashboard resources)
  factory ProgramMagangCard.fromMap(
    Map<String, dynamic> data, {
    Key? key,
    VoidCallback? onTap,
    VoidCallback? onDetailPressed,
  }) {
    final meta = data['metadata'] as Map<String, dynamic>? ?? {};
    final statusRaw = (data['status'] ?? 'open').toString().toLowerCase();

    String statusText = 'Pendaftaran Dibuka';
    Color statusColor = const Color(0xFF16A34A);
    Color statusBg = const Color(0xFFDCFCE7);

    if (statusRaw == 'closed' || statusRaw == 'completed') {
      statusText = 'Pendaftaran Ditutup';
      statusColor = const Color(0xFF64748B);
      statusBg = const Color(0xFFF1F5F9);
    } else if (statusRaw == 'in_progress' || statusRaw == 'active') {
      statusText = 'Sedang Berjalan';
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFDBEAFE);
    }

    final rawPeriod = meta['deadline']?.toString() ??
        meta['period']?.toString() ??
        meta['registration_period']?.toString() ??
        data['deadline']?.toString();

    final period = formatDateDisplay(rawPeriod, defaultFallback: '21 Sep 2026');

    final quota = meta['quota_text']?.toString() ??
        meta['quota']?.toString() ??
        '4 dari 10 posisi';

    List<String> reqs = [];
    if (meta['requirements'] is List) {
      reqs = (meta['requirements'] as List).map((e) => e.toString()).toList();
    }
    if (reqs.isEmpty) {
      reqs = [
        'Siswa SMK jurusan terkait',
        'Menguasai dasar 3D Modeling',
        'Memiliki portofolio karya',
      ];
    }

    return ProgramMagangCard(
      key: key,
      title: data['title']?.toString() ?? 'Program Magang MBKM 3D Modeler Batch I 2026',
      description: data['description']?.toString() ??
          'Kerja sama penempatan 10 siswa vokasi magang pada produksi serial animasi nusantara.',
      categoryBadge: meta['category']?.toString() ?? 'Magang',
      statusBadge: statusText,
      statusBadgeColor: statusColor,
      statusBadgeBg: statusBg,
      registrationPeriod: period,
      quotaText: quota.contains('posisi') ? quota : '$quota posisi',
      requirements: reqs,
      requirementsCountLabel: '${reqs.length} Persyaratan',
      onTap: onTap,
      onDetailPressed: onDetailPressed ?? onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resolvedStatusColor =
        statusBadgeColor ?? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A));
    final resolvedStatusBg =
        statusBadgeBg ?? (isDark ? const Color(0xFF16A34A).withValues(alpha: 0.2) : const Color(0xFFDCFCE7));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDetailPressed ?? onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFF8FAFC),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.025),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Row (Badges) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Badge: Magang
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0284C7).withValues(alpha: 0.22)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      categoryBadge,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF0284C7),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),

                  // Right Badge: • Pendaftaran Dibuka
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: resolvedStatusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: BoxDecoration(
                            color: resolvedStatusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          statusBadge,
                          style: TextStyle(
                            color: resolvedStatusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Title ──
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.35,
                  letterSpacing: -0.2,
                ),
              ),

              // ── Subtitle / Description ──
              if (description != null && description!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description!.trim(),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // ── Thin Divider ──
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? const Color(0xFF334155).withValues(alpha: 0.6)
                    : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 18),

              // ── Row 1: Periode Pendaftaran ──
              _buildInfoRow(
                icon: Icons.calendar_month_outlined,
                label: 'Periode pendaftaran',
                value: registrationPeriod ?? '21 Sep 2026',
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // ── Row 2: Sisa Kuota ──
              _buildInfoRow(
                icon: Icons.groups_outlined,
                label: 'Sisa kuota',
                value: quotaText ?? '4 dari 10 posisi',
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // ── Section: Syarat dan Kualifikasi ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Syarat dan kualifikasi',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    requirementsCountLabel ?? '${requirements.length} Persyaratan',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Bullet List ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: requirements.map((req) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            req,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ── Bottom Divider ──
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? const Color(0xFF334155).withValues(alpha: 0.6)
                    : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 14),

              // ── Bottom Action Button (Lihat Detail Program →) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onDetailPressed ?? onTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              buttonLabel.replaceAll(' →', '').trim(),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 13.5,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 19,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

