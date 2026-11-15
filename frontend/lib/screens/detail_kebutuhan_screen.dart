import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/opportunity_model.dart';
import '../models/opportunity_application_model.dart';
import '../models/job_contract.dart';
import '../models/user_model.dart';
import '../services/opportunity_service.dart';
import '../services/chat_service.dart';
import '../screens/direct_message_screen.dart';
import '../app/theme.dart';
import '../utils/app_errors.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/user_profile_modal.dart';
import '../widgets/verification_badge.dart';
import '../widgets/upgrade_plan_modal.dart';
import '../widgets/app_sweet_alert.dart';
import '../widgets/app_pagination_bar.dart';
import '../services/user_store.dart';
import '../services/wallet_service.dart';
import '../services/contract_pdf_service.dart';
import 'wallet_screen.dart';
import 'proyek_saya_screen.dart';

class _IndividualContractEntry {
  final String? applicationId;
  final String creatorId;
  final String creatorName;
  final String creatorUsername;
  final String subRoleLabel;
  final String contractNumber;
  final double agreedPrice;
  final String paymentSchemeLabel;
  final String? clientSignature;
  final String? clientSignedAt;
  final String? creatorSignature;
  final String? creatorSignedAt;
  final List<String> dynamicTerms;

  const _IndividualContractEntry({
    required this.applicationId,
    required this.creatorId,
    required this.creatorName,
    required this.creatorUsername,
    required this.subRoleLabel,
    required this.contractNumber,
    required this.agreedPrice,
    required this.paymentSchemeLabel,
    this.clientSignature,
    this.clientSignedAt,
    this.creatorSignature,
    this.creatorSignedAt,
    required this.dynamicTerms,
  });

  bool get isClientSigned =>
      (clientSignedAt != null && clientSignedAt!.isNotEmpty) ||
      (clientSignature != null && clientSignature!.isNotEmpty);

  bool get isCreatorSigned =>
      (creatorSignedAt != null && creatorSignedAt!.isNotEmpty) ||
      (creatorSignature != null && creatorSignature!.isNotEmpty);

  bool get isContractFinal => isClientSigned && isCreatorSigned;
}

class DetailKebutuhanScreen extends StatefulWidget {
  final OpportunityModel opportunity;
  final UserModel? user;
  final JobContract? initialContract;

  const DetailKebutuhanScreen({
    super.key,
    required this.opportunity,
    this.user,
    this.initialContract,
  });

  @override
  State<DetailKebutuhanScreen> createState() => _DetailKebutuhanScreenState();
}

class _DetailKebutuhanScreenState extends State<DetailKebutuhanScreen> {
  late OpportunityModel _opp;
  List<OpportunityApplicationModel> _applications = [];
  bool _loadingApps = true;
  String _selectedFilter = 'Semua'; // 'Semua', 'pending', 'approved', 'rejected'
  String _aiFilterSubRole = 'Semua';
  bool _actionLoading = false;
  int _contractListPage = 1;
  static const int _contractListPageSize = 5;

  UserModel? get _effectiveUser => widget.user ?? currentUserNotifier.value;

  bool get _isOwner {
    final myId = _effectiveUser?.id ?? '';
    return myId.isNotEmpty && _opp.postedBy != null && _opp.postedBy == myId;
  }

  bool get _isSubscriber {
    final t = (_effectiveUser?.subscriptionTier ?? '').toLowerCase();
    return t == 'plus' || t == 'pro' || t == 'super';
  }

  bool get _isMarketingOrAdmin {
    final role = (_effectiveUser?.role ?? '').toLowerCase();
    return role == 'marketing' || role == 'admin';
  }

  OpportunityApplicationModel? get _myApplication {
    final myId = _effectiveUser?.id ?? '';
    if (myId.isNotEmpty) {
      for (final app in _applications) {
        if (app.creatorId == myId || app.creator?.id == myId) {
          return app;
        }
      }
    }
    if (!_isOwner && !_isMarketingOrAdmin && _applications.isNotEmpty) {
      return _applications.first;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _opp = widget.opportunity;
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() => _loadingApps = true);
    try {
      final apps = await OpportunityService.getOpportunityApplications(_opp.id ?? '');
      if (mounted) {
        setState(() {
          if (apps.isEmpty && (_opp.approvedCreators.isNotEmpty || widget.initialContract != null)) {
            final approvedList = _opp.approvedCreators.isNotEmpty
                ? _opp.approvedCreators
                : (widget.initialContract != null
                    ? [
                        OpportunityApprovedCreatorModel(
                          id: widget.initialContract!.creatorId,
                          name: widget.initialContract!.creatorName,
                          username: widget.initialContract!.creatorName.toLowerCase().replaceAll(' ', '_'),
                          avatarUrl: widget.initialContract!.creator?['avatar_url'],
                          subRole: _opp.subRoleSlug,
                          creatorSignature: widget.initialContract!.creatorSignature,
                          creatorSignedAt: widget.initialContract!.creatorSignedAt?.toIso8601String() ??
                              (widget.initialContract!.creatorApproved ? DateTime.now().toIso8601String() : null),
                        )
                      ]
                    : <OpportunityApprovedCreatorModel>[]);

            final fallbackCount = approvedList.isNotEmpty ? approvedList.length : 1;
            final fallbackPerPerson = (_opp.escrowAmount ?? 0) > 0
                ? (_opp.escrowAmount! / fallbackCount)
                : (widget.initialContract?.agreedPrice ?? 0.0);
            _applications = approvedList.map((c) {
              return OpportunityApplicationModel(
                id: (c.applicationId != null && c.applicationId!.isNotEmpty)
                    ? c.applicationId!
                    : 'app_${c.id}',
                opportunityId: _opp.id ?? '',
                rawCreatorId: c.id,
                creator: OpportunityApplicantModel(
                  id: c.id,
                  name: c.name,
                  username: c.username,
                  avatarUrl: c.avatarUrl,
                  subRole: c.subRole ?? _opp.subRoleSlug,
                  isVerified: true,
                ),
                subRoleSlug: c.capability ?? c.subRole ?? _opp.subRoleSlug,
                pitchMessage: widget.initialContract?.description ?? 'Kontrak kerja sama aktif untuk proyek ${_opp.title}.',
                bidPrice: c.agreedPrice > 0
                    ? c.agreedPrice
                    : (fallbackPerPerson > 0 ? fallbackPerPerson : null),
                status: 'approved',
                contractNumber: c.contractNumber,
                clientSignature: c.clientSignature ?? _opp.clientSignature,
                clientSignedAt: c.clientSignedAt ?? _opp.clientSignedAt,
                creatorSignature: c.creatorSignature,
                creatorSignedAt: c.creatorSignedAt,
                dynamicTerms: c.dynamicTerms,
                workerStatus: widget.initialContract?.workStatus ?? 'in_progress',
                workerProgress: widget.initialContract?.workerProgress ?? 0,
                submittedDeliverables: widget.initialContract?.deliverables ?? const [],
                paymentScheme: widget.initialContract?.paymentScheme ?? 'full_at_end',
                paymentTerms: widget.initialContract?.paymentTerms ?? const [],
              );
            }).toList();
          } else {
            _applications = apps;
          }
          _loadingApps = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_opp.approvedCreators.isNotEmpty || widget.initialContract != null) {
            final approvedList = _opp.approvedCreators.isNotEmpty
                ? _opp.approvedCreators
                : (widget.initialContract != null
                    ? [
                        OpportunityApprovedCreatorModel(
                          id: widget.initialContract!.creatorId,
                          name: widget.initialContract!.creatorName,
                          username: widget.initialContract!.creatorName.toLowerCase().replaceAll(' ', '_'),
                          avatarUrl: widget.initialContract!.creator?['avatar_url'],
                          subRole: _opp.subRoleSlug,
                          creatorSignature: widget.initialContract!.creatorSignature,
                          creatorSignedAt: widget.initialContract!.creatorSignedAt?.toIso8601String() ??
                              (widget.initialContract!.creatorApproved ? DateTime.now().toIso8601String() : null),
                        )
                      ]
                    : <OpportunityApprovedCreatorModel>[]);

            final fallbackCount = approvedList.isNotEmpty ? approvedList.length : 1;
            final fallbackPerPerson = (_opp.escrowAmount ?? 0) > 0
                ? (_opp.escrowAmount! / fallbackCount)
                : (widget.initialContract?.agreedPrice ?? 0.0);
            _applications = approvedList.map((c) {
              return OpportunityApplicationModel(
                id: (c.applicationId != null && c.applicationId!.isNotEmpty)
                    ? c.applicationId!
                    : 'app_${c.id}',
                opportunityId: _opp.id ?? '',
                rawCreatorId: c.id,
                creator: OpportunityApplicantModel(
                  id: c.id,
                  name: c.name,
                  username: c.username,
                  avatarUrl: c.avatarUrl,
                  subRole: c.subRole ?? _opp.subRoleSlug,
                  isVerified: true,
                ),
                subRoleSlug: c.capability ?? c.subRole ?? _opp.subRoleSlug,
                pitchMessage: widget.initialContract?.description ?? 'Kontrak kerja sama aktif untuk proyek ${_opp.title}.',
                bidPrice: c.agreedPrice > 0
                    ? c.agreedPrice
                    : (fallbackPerPerson > 0 ? fallbackPerPerson : null),
                status: 'approved',
                contractNumber: c.contractNumber,
                clientSignature: c.clientSignature ?? _opp.clientSignature,
                clientSignedAt: c.clientSignedAt ?? _opp.clientSignedAt,
                creatorSignature: c.creatorSignature,
                creatorSignedAt: c.creatorSignedAt,
                dynamicTerms: c.dynamicTerms,
                workerStatus: widget.initialContract?.workStatus ?? 'in_progress',
                workerProgress: widget.initialContract?.workerProgress ?? 0,
                submittedDeliverables: widget.initialContract?.deliverables ?? const [],
                paymentScheme: widget.initialContract?.paymentScheme ?? 'full_at_end',
                paymentTerms: widget.initialContract?.paymentTerms ?? const [],
              );
            }).toList();
          }
          _loadingApps = false;
        });
      }
    }
  }

  Future<void> _handleReview(OpportunityApplicationModel app, String decision) async {
    final isApprove = decision == 'approve';
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    String dealInfo = '';
    if (isApprove) {
      if (app.counterOfferPrice != null && app.counterOfferStatus == 'accepted') {
        dealInfo = '\n\nDana Kesepakatan: ${currencyFmt.format(app.counterOfferPrice)}';
      } else if (app.bidPrice != null && app.bidPrice! > 0) {
        dealInfo = '\n\nDana Ajuan Pelamar: ${currencyFmt.format(app.bidPrice)}';
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Setujui Pelamar?' : 'Tolak Pelamar?'),
        content: Text(
          isApprove
              ? 'Anda akan menyetujui ${app.creator?.name ?? "kreator"} untuk proyek ini.$dealInfo'
              : 'Anda akan menolak lamaran dari ${app.creator?.name ?? "kreator"}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green.shade700 : Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isApprove ? 'Ya, Setujui' : 'Ya, Tolak',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.reviewApplication(
        applicationId: app.id,
        decision: decision,
        reason: isApprove ? null : 'Kuota belum sesuai atau profil belum memenuhi syarat.',
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(
            context,
            isApprove
                ? '${app.creator?.name ?? "Pelamar"} berhasil disetujui!'
                : 'Lamaran telah ditolak.',
          );
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memproses lamaran.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleConsiderDialog(OpportunityApplicationModel app) async {
    if (app.counterOfferStatus == 'accepted') {
      AppSweetAlert.info(
        context,
        'Pelamar telah menyetujui tawaran negosiasi sebelumnya. Anda tidak dapat melakukan negosiasi lagi, silakan klik Setujui (Deal) atau Tolak lamaran.',
        title: 'Negosiasi Telah Disepakati',
      );
      return;
    }

    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final initialPriceText = app.counterOfferPrice != null
        ? app.counterOfferPrice!.toStringAsFixed(0)
        : (app.bidPrice != null ? app.bidPrice!.toStringAsFixed(0) : '');

    final priceController = TextEditingController(text: initialPriceText);
    final notesController = TextEditingController(text: app.counterOfferNotes ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDarkDialog = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.handshake_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pertimbangkan & Nego Dana',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajukan tawaran dana kesepakatan baru kepada ${app.creator?.name ?? "pelamar"} untuk posisi ${app.subRoleLabel}. Jika pelamar menyetujui, tawaran baru ini akan menjadi acuan pertimbangan.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDarkDialog ? AppTheme.textMuted : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (app.bidPrice != null && app.bidPrice! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDarkDialog ? const Color(0xFF13111E) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDarkDialog ? AppTheme.inputBorder : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF059669)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ajuan Dana Awal Pelamar: ${currencyFmt.format(app.bidPrice)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tawaran Dana Baru dari Anda (Rp)*',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Contoh: 1500000',
                      prefixText: 'Rp ',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Nominal tawaran wajib diisi';
                      }
                      final n = double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', ''));
                      if (n == null || n <= 0) {
                        return 'Masukkan nominal yang valid (> 0)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pesan / Catatan Pertimbangan',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Misal: Apakah bersedia untuk paket 1 hari kerja include transport?',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text(
                'Kirim Tawaran',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final parsedPrice = double.tryParse(priceController.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
    final notes = notesController.text.trim();

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.reviewApplication(
        applicationId: app.id,
        decision: 'consider',
        counterOfferPrice: parsedPrice,
        counterOfferNotes: notes.isNotEmpty ? notes : null,
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(
            context,
            'Tawaran dana pertimbangan berhasil diajukan ke ${app.creator?.name ?? "pelamar"}.',
          );
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal mengajukan pertimbangan.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Widget _buildCounterOfferStatusBadge(String? status, [String? counterOfferBy]) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    if (status == 'accepted') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.15);
      text = const Color(0xFF059669);
      label = 'Disepakati (Deal)';
      icon = Icons.check_circle_rounded;
    } else if (status == 'declined') {
      bg = Colors.red.withValues(alpha: 0.15);
      text = Colors.red.shade700;
      label = 'Nego Ditolak';
      icon = Icons.cancel_rounded;
    } else {
      bg = Colors.amber.withValues(alpha: 0.15);
      text = const Color(0xFFD97706);
      if (counterOfferBy == 'creator') {
        label = 'Nego Pelamar (Menunggu Klien)';
        icon = Icons.mark_email_unread_outlined;
      } else {
        label = 'Nego Klien (Menunggu Pelamar)';
        icon = Icons.hourglass_top_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreatorCounterDialog(OpportunityApplicationModel app) async {
    final priceController = TextEditingController(
      text: app.counterOfferPrice != null
          ? app.counterOfferPrice!.toInt().toString()
          : (app.bidPrice != null ? app.bidPrice!.toInt().toString() : ''),
    );
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDarkDialog = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDarkDialog ? const Color(0xFF1E1B33) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handshake_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tawar Balik / Nego Ulang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Berikan nominal penawaran baru Anda kepada pemilik proyek "${_opp.title}". Anda dan pemilik proyek dapat bernegosiasi berkali-kali hingga tercapai kesepakatan bersama.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDarkDialog ? AppTheme.textMuted : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (app.counterOfferPrice != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDarkDialog ? const Color(0xFF13111E) : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tawaran Nego Terakhir: ${currencyFmt.format(app.counterOfferPrice)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Nominal Tawaran Baru Anda (Rp)*',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Contoh: 1500000',
                      prefixText: 'Rp ',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Nominal tawaran wajib diisi';
                      }
                      final n = double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', ''));
                      if (n == null || n <= 0) {
                        return 'Masukkan nominal yang valid (> 0)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Catatan / Alasan Tawaran',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Misal: Harga tersebut sudah mencakup transport dan revisi.',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text(
                'Kirim Penawaran',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final parsedPrice = double.tryParse(priceController.text.trim().replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
    final notes = notesController.text.trim();

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.respondCounterOffer(
        applicationId: app.id,
        action: 'counter',
        counterOfferPrice: parsedPrice,
        counterOfferNotes: notes.isNotEmpty ? notes : null,
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(
            context,
            'Penawaran balik berhasil dikirim ke pemilik proyek.',
          );
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal mengajukan penawaran.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _openChatWithUser(String userId, String? name) async {
    try {
      final result = await ChatService.startPersonalChat(userId);
      if (!mounted) return;
      final chatData = result['data'];
      if (chatData != null && chatData['id'] != null) {
        final chatMap = Map<String, dynamic>.from(chatData);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(
              chatId: chatData['id']?.toString(),
              initialChat: chatMap,
              targetUserId: userId,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(targetUserId: userId),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(targetUserId: userId),
          ),
        );
      }
    }
  }

  Future<void> _handleStartEvent() async {
    final approvedApps = _applications.where((a) => a.isApproved).toList();
    if (approvedApps.isEmpty && _opp.approvedCreators.isEmpty) {
      AppSnackbar.warning(
        context,
        'Belum ada kreator yang disetujui! Setujui minimal 1 pelamar sebelum memulai acara.',
      );
      return;
    }

    // Hitung total escrow yang diperlukan
    double totalEscrow = 0;
    for (final a in approvedApps) {
      final price = (a.counterOfferPrice != null && a.counterOfferPrice! > 0)
          ? a.counterOfferPrice!
          : (a.bidPrice ?? 0);
      totalEscrow += price;
    }
    if (totalEscrow <= 0 && _opp.escrowAmount != null && _opp.escrowAmount! > 0) {
      totalEscrow = _opp.escrowAmount!;
    }

    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // KASUS 1: Budget >= 100 Jt -> Wajib Tanda Tangan Basah Dokumen Fisik (3 Pihak)
    if (_opp.isWetSignatureBudget) {
      if (!_opp.isMeetingVerified) {
        if (!_opp.isMeetingPending && !_opp.isMeetingInProcess) {
          // 1. Muncul form atur tanggal pertemuan fisik 3 pihak
          await _handleScheduleMeeting();
          return;
        } else if (_opp.isMeetingCounterByAdmin) {
          // 1b. Admin mengajukan nego tanggal / waktu / lokasi alternatif
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.handshake_rounded, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Admin Mengajukan Nego Jadwal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                ],
              ),
              content: Text(
                'Admin Kreavana telah meninjau pengajuan jadwal Anda dan mengusulkan penyesuaian waktu/tempat:\n\n'
                '• Tanggal: ${_opp.meetingCounterDate ?? "-"}\n'
                '• Waktu: ${_opp.meetingCounterTime ?? "-"}\n'
                '• Lokasi: ${_opp.meetingCounterLocation ?? "-"}\n'
                '• Alasan/Catatan: ${_opp.meetingCounterNotes ?? "-"}\n\n'
                'Silakan terima usulan ini atau tawar balik jadwal pertemuan.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleRespondMeetingCounter('counter');
                  },
                  child: const Text('Tawar Balik', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleRespondMeetingCounter('accept');
                  },
                  child: const Text('Terima Jadwal Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          return;
        } else if (_opp.isMeetingPending) {
          // 2. Status pending jika sudah submit tanggal
          if (_isMarketingOrAdmin) {
            await _handleAdminReviewMeeting();
          } else {
            if (!mounted) return;
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(child: Text('Jadwal Menunggu Persetujuan Admin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  ],
                ),
                content: Text(
                  'Jadwal pertemuan fisik tanda tangan basah telah diajukan:\n\n'
                  '• Tanggal: ${_opp.meetingDate ?? "-"}\n'
                  '• Waktu: ${_opp.meetingTime ?? "-"}\n'
                  '• Lokasi: ${_opp.meetingLocation ?? "-"}\n\n'
                  'Status saat ini: PENDING.\n'
                  'Sedang menunggu persetujuan dari Admin Kreavana.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                ],
              ),
            );
          }
          return;
        } else if (_opp.isMeetingInProcess) {
          // 3. Status diproses jika admin menyetujui tanggalnya
          if (_isMarketingOrAdmin) {
            await _handleAdminStartEventAfterWetSignature();
          } else {
            if (!mounted) return;
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Jadwal Disetujui (DIPROSES)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  ],
                ),
                content: Text(
                  'Jadwal pertemuan fisik tanda tangan basah telah disetujui Admin Kreavana (Status: Diproses).\n\n'
                  'Acara akan dimulai secara resmi oleh Admin Kreavana setelah pertemuan tatap muka 3 pihak (Admin, Penyelenggara, dan Pekerja) serta penandatanganan dokumen MoU basah selesai dilakukan.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
                ],
              ),
            );
          }
          return;
        }
      }
    }

    // KASUS 2: Cek Saldo Wallet untuk Escrow Hold
    setState(() => _actionLoading = true);
    double userBalance = 0;
    try {
      final walletInfo = await WalletService.getWalletInfo();
      if (walletInfo['success'] == true) {
        userBalance = (walletInfo['balance'] as num).toDouble();
      }
    } catch (_) {}
    setState(() => _actionLoading = false);

    if (totalEscrow > 0 && userBalance < totalEscrow) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text('Saldo Tidak Mencukupi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Untuk memulai acara, saldo Anda harus mencukupi untuk ditahan menjadi Escrow Rekber Kreavana bagi kreator yang telah disetujui.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Escrow Diperlukan:', style: TextStyle(fontSize: 12)),
                        Text(currencyFmt.format(totalEscrow), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Anda Saat Ini:', style: TextStyle(fontSize: 12)),
                        Text(currencyFmt.format(userBalance), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kekurangan Dana:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(currencyFmt.format(totalEscrow - userBalance), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            if (widget.user != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WalletScreen(
                        user: widget.user!,
                        onUserUpdated: (_) {},
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_card_rounded, size: 16, color: Colors.white),
                label: const Text('Top Up Saldo Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      );
      return;
    }

    // KASUS 3: Konfirmasi & Validasi Dokumen Kontrak Digital 3 Pihak (< 100 Jt) — 1 Orang 1 Kontrak
    if (_opp.isDynamicSignatureBudget) {
      final contractEntries = _getIndividualContractEntries();
      final unsignedClientEntries = contractEntries
          .where((e) => !e.isClientSigned)
          .toList();

      // 1. Cek apakah Pihak Pertama (Klien) sudah menandatangani seluruh kontrak individu
      final isClientSigned = contractEntries.isNotEmpty
          ? unsignedClientEntries.isEmpty
          : (_opp.clientSignedAt != null && _opp.clientSignedAt!.isNotEmpty);
      if (!isClientSigned) {
        if (!mounted) return;
        final proceedToSign = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.draw_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Lengkapi Kontrak Digital (1 Orang 1 Kontrak)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Text(
              'Sebelum acara dapat dimulai, seluruh Dokumen Kontrak Digital Individu (3 Pihak) wajib disetujui dan ditandatangani kedua belah pihak.\n\n'
              'Terdapat ${unsignedClientEntries.isEmpty ? 1 : unsignedClientEntries.length} kontrak yang belum Anda tandatangani sebagai Pihak Pertama (Penyelenggara).',
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.edit_document, size: 16, color: Colors.white),
                label: const Text('Buka Dokumen Kontrak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (proceedToSign == true) {
          await _showTripartiteContractModal(
            initialApplicationId: unsignedClientEntries.firstOrNull?.applicationId,
            initialCreatorId: unsignedClientEntries.firstOrNull?.creatorId,
          );
        }
        return;
      }

      // 2. Cek apakah SELURUH pelamar/kreator yang disetujui sudah menandatangani kontrak individu masing-masing
      final unsignedCreators = <String>[];
      for (final entry in contractEntries) {
        if (!entry.isCreatorSigned) {
          unsignedCreators.add('${entry.creatorName} (${entry.subRoleLabel})');
        }
      }

      if (unsignedCreators.isNotEmpty) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Menunggu Persetujuan Pekerja', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kontrak digital telah Anda tandatangani, namun acara belum dapat dimulai karena masih menunggu persetujuan dan tanda tangan digital dari pekerja/kreator terpilih:',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daftar Pekerja Belum TTD:',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 6),
                      ...unsignedCreators.map((name) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            const Text('Belum TTD', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sesuai prosedur keamanan platform, seluruh pekerja yang terlibat wajib menandatangani kontrak digital sebelum acara resmi dimulai.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showTripartiteContractModal();
                },
                icon: const Icon(Icons.description_outlined, size: 16, color: Colors.white),
                label: const Text('Lihat Dokumen Kontrak', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }

      // 3. Konfirmasi Mulai Acara jika kedua belah pihak sudah lengkap tanda tangan
      if (!mounted) return;
      final startConfirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Mulai Acara & Amankan Escrow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dokumen Kontrak Digital telah LENGKAP disetujui & ditandatangani oleh kedua belah pihak (Penyelenggara dan Seluruh Pekerja Kreatif).',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nilai Kontrak Escrow:', style: TextStyle(fontSize: 12)),
                        Text(currencyFmt.format(totalEscrow), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status Kontrak:', style: TextStyle(fontSize: 12)),
                        Text('SAH 3 PIHAK (100% LENGKAP)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Saldo sebesar ${currencyFmt.format(totalEscrow)} akan ditahan di Escrow Rekber Kreavana dan baru diteruskan ke pekerja setelah hasil pekerjaan disetujui.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.35),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Mulai Acara Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (startConfirmed != true) return;
    } else {
      // Untuk budget >= 100jt yang dokumen basahnya sudah verified
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Mulai Acara (TTD Basah Terverifikasi)?'),
            ],
          ),
          content: Text(
            'Dokumen MoU fisik & Tanda Tangan Basah telah terverifikasi.\n\n'
            'Saldo sebesar ${currencyFmt.format(totalEscrow)} akan dialihkan ke dalam penampungan Escrow resmi.\n'
            'Pendaftaran ditutup dan acara resmi berjalan.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Mulai Acara', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Eksekusi Mulai Acara ke API
    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.startEvent(
        _opp.id ?? '',
        signature: _opp.clientSignature,
        signatureType: _opp.isWetSignatureBudget ? 'wet_signature' : 'dynamic_electronic',
        dynamicTerms: _opp.dynamicTerms.isNotEmpty ? _opp.dynamicTerms : null,
      );
      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() {
            _opp = res['data'] as OpportunityModel;
          });
          AppSnackbar.success(
            context,
            'Acara resmi dimulai dan saldo berhasil diamankan ke dalam Escrow Rekber!',
          );
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memulai acara.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  List<String> get _defaultContractTerms => const [
    'Penyelenggara (Pihak Pertama) wajib menyediakan akses lokasi, jadwal rundown yang jelas, dan koordinasi teknis di venue.',
    'Penyediaan fasilitas dan alat kerja utama (seperti kamera, lensa, instrumen, dll) disepakati tertulis antara pembuat event dan pekerja.',
    'Pekerja (Pihak Kedua) berkewajiban hadir tepat waktu dan menyerahkan hasil kerja sesuai standar profesional yang disepakati.',
    'Honorarium kerja diamankan 100% pada sistem Escrow Rekber Aplikasi Kreavana (CV Transforma Alam Kreasi) dan hanya dicairkan setelah hasil pekerjaan disetujui.',
  ];

  double _parseBudgetFallback() {
    if ((_opp.escrowAmount ?? 0) > 0) return _opp.escrowAmount!;
    final raw = _opp.budgetRange ?? '';
    final match = RegExp(r'(\d[\d\.\,]*)').firstMatch(raw);
    if (match != null) {
      final cleaned = match.group(1)!.replaceAll(RegExp(r'[\.\,]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0.0;
  }

  /// Menghasilkan klausul kontrak dinamis yang berbeda-beda sesuai nama pekerja, posisi/sub-role, nominal, dan catatan negosiasi individu.
  List<String> _buildIndividualDefaultTerms({
    required String creatorName,
    required String subRoleSlug,
    required String subRoleLabel,
    required double agreedPrice,
    required bool isTermPayment,
    String? counterOfferNotes,
    String? questionsNotes,
  }) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final formattedPrice = agreedPrice > 0
        ? currencyFmt.format(agreedPrice)
        : (_opp.budgetRange ?? 'Sesuai Kesepakatan');
    final schemeLabel = isTermPayment
        ? 'Bertahap (Termin Progress)'
        : 'Penuh di Akhir Acara (100% Lunas via Escrow)';
    final slugKey = subRoleSlug.trim().toLowerCase();

    final terms = <String>[
      'Lingkup Tugas Individu: Pihak Kedua ($creatorName) bertugas khusus sebagai $subRoleLabel pada proyek "${_opp.title}" dan bertanggung jawab penuh atas target kerja posisi $subRoleLabel sesuai jadwal penyelenggara.',
    ];

    if ([
      'videographer',
      'videografi',
      'photographer',
      'fotografi',
      'drone',
    ].contains(slugKey)) {
      terms.add(
        'Spesifikasi Teknis & Perangkat ($subRoleLabel): Penyediaan unit kamera utama, lensa, memori, baterai cadangan, serta penyerahan file mentah (RAW/Footage) dan hasil akhir kurasi untuk posisi $subRoleLabel ($creatorName) disepakati bersama Penyelenggara.',
      );
    } else if ([
      'editor',
      'animator',
      'desain_grafis',
      'designer',
      'illustrator',
    ].contains(slugKey)) {
      terms.add(
        'Spesifikasi Produksi & Revisi ($subRoleLabel): Pihak Kedua ($creatorName) wajib menyerahkan preview draf tepat waktu, mengakomodasi revisi sesuai kesepakatan kerja, dan menyerahkan master file resolusi penuh.',
      );
    } else if (['mc', 'singer', 'tukang_kendang', 'model'].contains(slugKey)) {
      terms.add(
        'Kesiapan Panggung & Gladi Bersih ($subRoleLabel): Pihak Kedua ($creatorName) wajib mengikuti sesi briefing/gladi bersih (soundcheck), mematuhi ketentuan kostum/wardrobe acara, dan tampil tepat waktu sesuai rundown.',
      );
    } else if (slugKey == 'makeup_artist') {
      terms.add(
        'Standar Perlengkapan & Higienitas ($subRoleLabel): Pihak Kedua ($creatorName) wajib menyediakan perlengkapan kosmetik berstandar profesional yang higienis dan hadir sesuai jadwal persiapan talent.',
      );
    } else {
      terms.add(
        'Fasilitas & Koordinasi Teknis ($subRoleLabel): Penyediaan peralatan kerja utama, akses lokasi, konsumsi, dan koordinasi teknis di lapangan untuk $creatorName ($subRoleLabel) disepakati tertulis bersama Penyelenggara.',
      );
    }

    terms.add(
      'Honorarium Individu & Proteksi Escrow: Nilai kontrak individu untuk $creatorName ($subRoleLabel) disepakati sebesar $formattedPrice dengan skema pembayaran $schemeLabel, dijamin melalui Rekening Bersama CV Transforma Alam Kreasi (Aplikasi Kreavana).',
    );

    if (counterOfferNotes != null && counterOfferNotes.trim().isNotEmpty) {
      terms.add(
        'Catatan Kesepakatan Negosiasi ($creatorName): ${counterOfferNotes.trim()}',
      );
    } else if (questionsNotes != null && questionsNotes.trim().isNotEmpty) {
      terms.add(
        'Catatan Teknis & Fasilitas Pelamar ($creatorName): ${questionsNotes.trim()}',
      );
    } else {
      terms.add(
        'Pengesahan 2 Arah & Finalitas: Kontrak individu ini mengikat secara sah dan terkunci permanen (Kontrak Fix) setelah disetujui serta ditandatangani secara elektronik oleh Pembuat Acara dan $creatorName.',
      );
    }

    return terms;
  }

  String _fallbackContractNumber(String appOrCreatorId) {
    final oppPrefix = (_opp.id != null && _opp.id!.length >= 4)
        ? _opp.id!.substring(0, 4).toUpperCase()
        : 'KVN0';
    final appPrefix = appOrCreatorId.length >= 4
        ? appOrCreatorId.substring(0, 4).toUpperCase()
        : 'CTR1';
    final datePart = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'KVN/TAK/CTR/$datePart/$oppPrefix-$appPrefix';
  }

  /// Menghasilkan daftar kontrak individu (1 orang = 1 kontrak 3 pihak).
  /// Jika terdapat 10 atau 13 pelamar yang disetujui, maka daftar ini menghasilkan 10/13 kontrak terpisah dengan klausul & nominal masing-masing.
  List<_IndividualContractEntry> _getIndividualContractEntries([
    List<JobContract> fetchedContracts = const [],
  ]) {
    final approvedApps = _applications.where((a) => a.isApproved).toList();
    final entries = <_IndividualContractEntry>[];
    final seenCreatorIds = <String>{};
    final totalApprovedCount = approvedApps.isNotEmpty
        ? approvedApps.length
        : (_opp.approvedCreators.isNotEmpty ? _opp.approvedCreators.length : 1);
    final totalBudgetFallback = _parseBudgetFallback();
    final perPersonFallbackFee = totalBudgetFallback > 0
        ? (totalBudgetFallback / totalApprovedCount).roundToDouble()
        : 0.0;

    for (final app in approvedApps) {
      final cid = app.creatorId;
      if (cid.isNotEmpty && seenCreatorIds.contains(cid)) continue;
      if (cid.isNotEmpty) seenCreatorIds.add(cid);
      final matchedCreator = _opp.approvedCreators
          .where((c) => (app.id.isNotEmpty && c.applicationId == app.id) || (cid.isNotEmpty && c.id == cid))
          .firstOrNull;
      final matchedJobContract = fetchedContracts
          .where((jc) => cid.isNotEmpty && jc.creatorId == cid)
          .firstOrNull;

      final clientSig = app.clientSignature ??
          matchedCreator?.clientSignature ??
          matchedJobContract?.clientSignature ??
          _opp.clientSignature;
      final clientSignedAt = app.clientSignedAt ??
          matchedCreator?.clientSignedAt ??
          matchedJobContract?.clientSignedAt?.toIso8601String() ??
          _opp.clientSignedAt;
      final creatorSig = app.creatorSignature ??
          matchedCreator?.creatorSignature ??
          matchedJobContract?.creatorSignature;
      final creatorSignedAt = app.creatorSignedAt ??
          matchedCreator?.creatorSignedAt ??
          matchedJobContract?.creatorSignedAt?.toIso8601String();

      final fee = app.agreedFee > 0
          ? app.agreedFee
          : (matchedCreator != null && matchedCreator.agreedPrice > 0
              ? matchedCreator.agreedPrice
              : ((matchedJobContract?.agreedPrice ?? 0.0) > 0
                  ? matchedJobContract!.agreedPrice
                  : perPersonFallbackFee));

      final creatorName = app.creator?.name ?? matchedCreator?.name ?? 'Pekerja Kreatif';
      final rawSubRole = app.subRoleSlug.isNotEmpty
          ? app.subRoleSlug
          : (app.creator?.subRole ?? matchedCreator?.capability ?? matchedCreator?.subRole ?? _opp.subRoleSlug);
      final subRoleLabel = app.subRoleLabel;

      final terms = app.dynamicTerms.isNotEmpty
          ? List<String>.from(app.dynamicTerms)
          : (matchedCreator != null && matchedCreator.dynamicTerms.isNotEmpty
              ? List<String>.from(matchedCreator.dynamicTerms)
              : (matchedJobContract != null && matchedJobContract.dynamicTerms.isNotEmpty
                  ? List<String>.from(matchedJobContract.dynamicTerms)
                  : _buildIndividualDefaultTerms(
                      creatorName: creatorName,
                      subRoleSlug: rawSubRole,
                      subRoleLabel: subRoleLabel,
                      agreedPrice: fee,
                      isTermPayment: app.isTermPayment,
                      counterOfferNotes: app.counterOfferNotes,
                      questionsNotes: app.questionsNotes,
                    )));

      entries.add(
        _IndividualContractEntry(
          applicationId: app.id,
          creatorId: cid,
          creatorName: creatorName,
          creatorUsername: app.creator?.username ?? matchedCreator?.username ?? 'kreator',
          subRoleLabel: subRoleLabel,
          contractNumber: (app.contractNumber != null && app.contractNumber!.isNotEmpty)
              ? app.contractNumber!
              : ((matchedCreator?.contractNumber != null && matchedCreator!.contractNumber!.isNotEmpty)
                  ? matchedCreator.contractNumber!
                  : (matchedJobContract?.contractNumber ?? _fallbackContractNumber(app.id))),
          agreedPrice: fee,
          paymentSchemeLabel: app.isTermPayment
              ? 'Pembayaran Bertahap (Termin)'
              : 'Pembayaran Sekaligus (100% Setelah Pekerjaan Selesai)',
          clientSignature: clientSig,
          clientSignedAt: clientSignedAt,
          creatorSignature: creatorSig,
          creatorSignedAt: creatorSignedAt,
          dynamicTerms: terms,
        ),
      );
    }

    for (final c in _opp.approvedCreators) {
      if (c.id.isNotEmpty && seenCreatorIds.contains(c.id)) continue;
      if (c.id.isNotEmpty) seenCreatorIds.add(c.id);
      final matchedJobContract = fetchedContracts
          .where((jc) => c.id.isNotEmpty && jc.creatorId == c.id)
          .firstOrNull;

      final clientSig = c.clientSignature ??
          matchedJobContract?.clientSignature ??
          _opp.clientSignature;
      final clientSignedAt = c.clientSignedAt ??
          matchedJobContract?.clientSignedAt?.toIso8601String() ??
          _opp.clientSignedAt;
      final creatorSig = c.creatorSignature ?? matchedJobContract?.creatorSignature;
      final creatorSignedAt = c.creatorSignedAt ??
          matchedJobContract?.creatorSignedAt?.toIso8601String();

      final fee = c.agreedPrice > 0
          ? c.agreedPrice
          : ((matchedJobContract?.agreedPrice ?? 0.0) > 0
              ? matchedJobContract!.agreedPrice
              : perPersonFallbackFee);
      final creatorName = c.name.isNotEmpty ? c.name : 'Pekerja Kreatif';
      final rawSubRole = c.capability ?? c.subRole ?? _opp.subRoleSlug;
      final subRoleLabel = rawSubRole.replaceAll('_', ' ');

      final terms = c.dynamicTerms.isNotEmpty
          ? List<String>.from(c.dynamicTerms)
          : (matchedJobContract != null && matchedJobContract.dynamicTerms.isNotEmpty
              ? List<String>.from(matchedJobContract.dynamicTerms)
              : _buildIndividualDefaultTerms(
                  creatorName: creatorName,
                  subRoleSlug: rawSubRole,
                  subRoleLabel: subRoleLabel,
                  agreedPrice: fee,
                  isTermPayment: false,
                ));

      entries.add(
        _IndividualContractEntry(
          applicationId: c.applicationId,
          creatorId: c.id,
          creatorName: creatorName,
          creatorUsername: c.username.isNotEmpty ? c.username : 'kreator',
          subRoleLabel: subRoleLabel,
          contractNumber: (c.contractNumber != null && c.contractNumber!.isNotEmpty)
              ? c.contractNumber!
              : (matchedJobContract?.contractNumber ?? _fallbackContractNumber(c.applicationId ?? c.id)),
          agreedPrice: fee,
          paymentSchemeLabel: 'Pembayaran Sekaligus (100% Setelah Pekerjaan Selesai)',
          clientSignature: clientSig,
          clientSignedAt: clientSignedAt,
          creatorSignature: creatorSig,
          creatorSignedAt: creatorSignedAt,
          dynamicTerms: terms,
        ),
      );
    }

    return entries;
  }

  OfficialContractDocumentData _buildOfficialContractDocData(
    _IndividualContractEntry entry, {
    List<String>? overrideClauses,
  }) {
    final clientName = (_opp.poster?.name.isNotEmpty == true)
        ? _opp.poster!.name
        : (_isOwner ? (_effectiveUser?.name ?? 'Penyelenggara Acara') : 'Penyelenggara Acara');
    final clientUsername = (_opp.poster?.username.isNotEmpty == true)
        ? _opp.poster!.username
        : (_isOwner ? (_effectiveUser?.username ?? 'client') : 'client');
    final scheduleParts = <String>[];
    if (_opp.eventStartDate != null && _opp.eventStartDate!.isNotEmpty) {
      scheduleParts.add(_opp.eventStartDate!);
    } else if (_opp.eventDate != null && _opp.eventDate!.isNotEmpty) {
      scheduleParts.add(_opp.eventDate!);
    }
    if (_opp.eventEndDate != null &&
        _opp.eventEndDate!.isNotEmpty &&
        _opp.eventEndDate != _opp.eventStartDate) {
      scheduleParts.add('s/d ${_opp.eventEndDate!}');
    }
    final scheduleText = scheduleParts.isNotEmpty
        ? scheduleParts.join(' ')
        : (_opp.deadline ?? 'Sesuai kesepakatan proyek');

    double fee = entry.agreedPrice;
    if (fee <= 0 && (_opp.escrowAmount ?? 0) > 0) {
      final totalCount = _getIndividualContractEntries().length;
      fee = (_opp.escrowAmount ?? 0) / (totalCount > 0 ? totalCount : 1);
    }

    return OfficialContractDocumentData(
      contractNumber: entry.contractNumber,
      companyHeader: 'CV TRANSFORMA ALAM KREASI',
      platformSource:
          'Aplikasi Kreavana — Platform Ekosistem Kreatif & Rekening Bersama (Escrow)',
      projectTitle: _opp.title,
      projectDescription: _opp.description ?? '',
      projectLocation: _opp.location ?? _opp.address ?? 'Indonesia',
      projectSchedule: scheduleText,
      agreedPrice: fee,
      paymentSchemeLabel: entry.paymentSchemeLabel,
      clauses: overrideClauses ?? entry.dynamicTerms,
      isFinal: entry.isContractFinal,
      issuedDateText: ContractPdfService.formatOfficialDate(
        DateTime.tryParse(entry.creatorSignedAt ?? entry.clientSignedAt ?? '') ??
            DateTime.now(),
      ),
      clientName: clientName,
      clientUsername: clientUsername,
      clientRoleLabel: 'Penyelenggara Proyek / Klien (Pihak Pertama)',
      clientSignature: entry.clientSignature,
      clientSignedAtText:
          ContractPdfService.formatOfficialDateTime(entry.clientSignedAt),
      creatorName: entry.creatorName,
      creatorUsername: entry.creatorUsername,
      creatorSubRoleLabel: entry.subRoleLabel,
      creatorSignature: entry.creatorSignature,
      creatorSignedAtText:
          ContractPdfService.formatOfficialDateTime(entry.creatorSignedAt),
      adminCompanyName: 'CV Transforma Alam Kreasi',
      adminTitle: 'Otoritas Penjamin Escrow & Legalitas Platform Aplikasi Kreavana',
      adminSignedAtText: ContractPdfService.formatOfficialDateTime(
        _opp.adminSignedAt ?? entry.clientSignedAt ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<void> _downloadOfficialContractA4(
    _IndividualContractEntry entry, {
    List<String>? overrideClauses,
  }) async {
    try {
      final docData = _buildOfficialContractDocData(
        entry,
        overrideClauses: overrideClauses,
      );
      final savedPath = await ContractPdfService.downloadOfficialContractPdf(
        data: docData,
      );
      if (mounted) {
        AppSnackbar.success(
          context,
          'Dokumen Kontrak Resmi A4 (${entry.contractNumber}) berhasil diunduh: $savedPath',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal mengunduh PDF Kontrak A4: $e');
      }
    }
  }

  Future<void> _showTripartiteContractModal({
    int? initialIndex,
    String? initialApplicationId,
    String? initialCreatorId,
  }) async {
    setState(() => _actionLoading = true);
    List<JobContract> contracts = [];
    try {
      contracts = await OpportunityService.getOpportunityContracts(_opp.id ?? '');
    } catch (_) {}
    if (contracts.isEmpty && widget.initialContract != null) {
      contracts = [widget.initialContract!];
    }
    setState(() => _actionLoading = false);

    if (!mounted) return;

    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<_IndividualContractEntry> entries = _getIndividualContractEntries(contracts);
    if (entries.isEmpty) {
      entries = [
        _IndividualContractEntry(
          applicationId: null,
          creatorId: '',
          creatorName: 'Menunggu Pelamar Disetujui (1 Orang 1 Kontrak)',
          creatorUsername: 'kreator',
          subRoleLabel: _opp.subRoleSlug.replaceAll('_', ' '),
          contractNumber: _fallbackContractNumber('DRAFT'),
          agreedPrice: _opp.escrowAmount ?? 0.0,
          paymentSchemeLabel: 'Pembayaran Sekaligus (100% Setelah Pekerjaan Selesai)',
          clientSignature: _opp.clientSignature,
          clientSignedAt: _opp.clientSignedAt,
          creatorSignature: null,
          creatorSignedAt: null,
          dynamicTerms: _opp.dynamicTerms.isNotEmpty
              ? List<String>.from(_opp.dynamicTerms)
              : List<String>.from(_defaultContractTerms),
        ),
      ];
    }

    int selectedIndex = initialIndex ?? 0;
    final myUserId = _effectiveUser?.id ?? '';
    if (initialApplicationId != null && initialApplicationId.isNotEmpty) {
      final found = entries.indexWhere((e) => e.applicationId == initialApplicationId);
      if (found >= 0) selectedIndex = found;
    } else if (initialCreatorId != null && initialCreatorId.isNotEmpty) {
      final found = entries.indexWhere((e) => e.creatorId == initialCreatorId);
      if (found >= 0) selectedIndex = found;
    } else if (!_isOwner && myUserId.isNotEmpty) {
      final myIdx = entries.indexWhere((e) => e.creatorId == myUserId);
      if (myIdx >= 0) selectedIndex = myIdx;
    }
    selectedIndex = selectedIndex.clamp(0, entries.length - 1);

    List<String> currentDynamicTerms = List<String>.from(
      entries[selectedIndex].dynamicTerms.isNotEmpty
          ? entries[selectedIndex].dynamicTerms
          : _defaultContractTerms,
    );

    void selectEntry(int newIdx, StateSetter setModalState) {
      final clamped = newIdx.clamp(0, entries.length - 1);
      setModalState(() {
        selectedIndex = clamped;
        currentDynamicTerms = List<String>.from(
          entries[selectedIndex].dynamicTerms.isNotEmpty
              ? entries[selectedIndex].dynamicTerms
              : _defaultContractTerms,
        );
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF13111E) : const Color(0xFFF1F5F9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            entries = _getIndividualContractEntries(contracts);
            if (entries.isEmpty) {
              entries = [
                _IndividualContractEntry(
                  applicationId: null,
                  creatorId: '',
                  creatorName: 'Menunggu Pelamar Disetujui (1 Orang 1 Kontrak)',
                  creatorUsername: 'kreator',
                  subRoleLabel: _opp.subRoleSlug.replaceAll('_', ' '),
                  contractNumber: _fallbackContractNumber('DRAFT'),
                  agreedPrice: _opp.escrowAmount ?? 0.0,
                  paymentSchemeLabel: 'Pembayaran Sekaligus (100% Setelah Pekerjaan Selesai)',
                  clientSignature: _opp.clientSignature,
                  clientSignedAt: _opp.clientSignedAt,
                  creatorSignature: null,
                  creatorSignedAt: null,
                  dynamicTerms: _opp.dynamicTerms.isNotEmpty
                      ? List<String>.from(_opp.dynamicTerms)
                      : List<String>.from(_defaultContractTerms),
                ),
              ];
            }
            if (selectedIndex >= entries.length) {
              selectedIndex = entries.length - 1;
            }

            final activeEntry = entries[selectedIndex];
            final isClientSigned = activeEntry.isClientSigned;
            final isPihakKeduaSigned = activeEntry.isCreatorSigned;
            final isContractLocked =
                activeEntry.isContractFinal || _opp.isOngoing || _opp.status != 'open';
            final allContractsFinal =
                entries.isNotEmpty && entries.every((e) => e.isContractFinal);
            final unsignedClientCount =
                entries.where((e) => !e.isClientSigned && e.creatorId.isNotEmpty).length;

            final isClientUser =
                (_effectiveUser?.id == _opp.postedBy || _effectiveUser?.role == 'admin');
            final canSignAsClient = isClientUser && !isClientSigned;
            final isCurrentUserThisCreator =
                myUserId.isNotEmpty && activeEntry.creatorId == myUserId;
            final canSignAsCreator = isCurrentUserThisCreator && !isPihakKeduaSigned;
            final canEditClauses =
                !isContractLocked && (isClientUser || isCurrentUserThisCreator);

            final individualFee = activeEntry.agreedPrice > 0
                ? activeEntry.agreedPrice
                : ((_opp.escrowAmount ?? 0) > 0
                    ? (_opp.escrowAmount! / (entries.isNotEmpty ? entries.length : 1))
                    : 0.0);

            final issuedDateStr = ContractPdfService.formatOfficialDate(
              DateTime.tryParse(
                    activeEntry.creatorSignedAt ?? activeEntry.clientSignedAt ?? '',
                  ) ??
                  DateTime.now(),
            );

            return DraggableScrollableSheet(
              initialChildSize: 0.92,
              maxChildSize: 0.97,
              minChildSize: 0.55,
              expand: false,
              builder: (ctx, scrollController) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // NAVIGASI DAFTAR KONTRAK INDIVIDU (1 ORANG = 1 KONTRAK)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.assignment_ind_rounded,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dokumen Kontrak Individu (${selectedIndex + 1} dari ${entries.length} Kontrak — 1 Orang 1 Kontrak)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                if (entries.length > 1) ...[
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                    onPressed: selectedIndex > 0
                                        ? () => selectEntry(selectedIndex - 1, setModalState)
                                        : null,
                                    tooltip: 'Kontrak Sebelumnya',
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                    onPressed: selectedIndex < entries.length - 1
                                        ? () => selectEntry(selectedIndex + 1, setModalState)
                                        : null,
                                    tooltip: 'Kontrak Berikutnya',
                                  ),
                                ],
                              ],
                            ),
                            if (entries.length > 1) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 34,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: entries.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                                  itemBuilder: (_, idx) {
                                    final item = entries[idx];
                                    final isSelected = idx == selectedIndex;
                                    final statusColor = item.isContractFinal
                                        ? const Color(0xFF059669)
                                        : (item.isClientSigned || item.isCreatorSigned
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF2563EB));
                                    return ChoiceChip(
                                      selected: isSelected,
                                      onSelected: (_) => selectEntry(idx, setModalState),
                                      selectedColor: statusColor.withValues(alpha: 0.2),
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            item.isContractFinal
                                                ? Icons.verified_rounded
                                                : Icons.description_outlined,
                                            size: 13,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${idx + 1}. ${item.creatorName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            if (isClientUser && unsignedClientCount > 1) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF059669)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    _showSignContractDialog(
                                      roleTitle:
                                          'Pihak Pertama (Penyelenggara) — TTD Sekaligus Seluruh ${entries.length} Kontrak',
                                      defaultSignerName:
                                          _effectiveUser?.name ?? (_opp.poster?.name ?? ''),
                                      currentTerms: currentDynamicTerms,
                                      applicationId: null,
                                      signAll: true,
                                      onSignedSuccess: (updatedOpp) async {
                                        await _fetchApplications();
                                        setModalState(() => _opp = updatedOpp);
                                        setState(() => _opp = updatedOpp);
                                      },
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.done_all_rounded,
                                    size: 16,
                                    color: Color(0xFF059669),
                                  ),
                                  label: Text(
                                    'Tandatangani Sekaligus Seluruh Kontrak Belum TTD ($unsignedClientCount Dokumen)',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // LEMBAR KERTAS RESMI A4 (OFFICIAL A4 DOCUMENT TEMPLATE)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 794),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF181625) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: activeEntry.isContractFinal
                                    ? const Color(0xFF059669).withValues(alpha: 0.6)
                                    : const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // KOP SURAT RESMI A4: CV TRANSFORMA ALAM KREASI
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.verified_user_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'CV TRANSFORMA ALAM KREASI',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                const Text(
                                                  'Sumber Resmi: Aplikasi Kreavana — Platform Ekosistem Kreatif & Rekening Bersama (Escrow)',
                                                  style: TextStyle(
                                                    color: Color(0xFFBAE6FD),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Tanggal Dokumen: $issuedDateStr  •  Standar Dokumen: A4 Resmi (210 × 297 mm)',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 10.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(color: Colors.white24, height: 1),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            'No. Kontrak: ${activeEntry.contractNumber}',
                                            style: const TextStyle(
                                              color: Colors.cyanAccent,
                                              fontSize: 11.5,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: activeEntry.isContractFinal
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFD97706),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              activeEntry.isContractFinal
                                                  ? 'KONTRAK FIX & FINAL (TERKUNCI)'
                                                  : 'MENUNGGU TANDA TANGAN LENGKAP',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                const Center(
                                  child: Text(
                                    'SURAT PERJANJIAN KERJA KREATIF & JAMINAN ESCROW (3 PIHAK)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13.5,
                                      letterSpacing: 0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Center(
                                  child: Text(
                                    'Proyek: ${_opp.title}  |  Lokasi: ${_opp.location ?? "Indonesia"}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // PARA PIHAK BERIKATAN (3 PIHAK — 1 ORANG 1 KONTRAK)
                                const Text(
                                  'PASAL 1 — PARA PIHAK YANG BERSEPAKAT (1 ORANG 1 KONTRAK):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                const SizedBox(height: 8),
                                _buildPartyCard(
                                  title: 'PIHAK PERTAMA (Pembuat Event / Penyelenggara)',
                                  name: _opp.poster?.name.isNotEmpty == true
                                      ? _opp.poster!.name
                                      : (_effectiveUser?.name ?? 'Klien Penyelenggara'),
                                  role: 'Penyelenggara Proyek',
                                  statusText: isClientSigned
                                      ? 'Telah Ditandatangani Secara Sah (${ContractPdfService.formatOfficialDateTime(activeEntry.clientSignedAt)})'
                                      : 'Menunggu Tanda Tangan Pihak Pertama',
                                  isSigned: isClientSigned,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 8),
                                _buildPartyCard(
                                  title: 'PIHAK KEDUA (Pekerja Kreatif Individu — Kontrak #${selectedIndex + 1})',
                                  name: '${activeEntry.creatorName} (@${activeEntry.creatorUsername})',
                                  role: 'Bidang Kerja: ${activeEntry.subRoleLabel}',
                                  statusText: isPihakKeduaSigned
                                      ? 'Telah Ditandatangani Secara Sah (${ContractPdfService.formatOfficialDateTime(activeEntry.creatorSignedAt)})'
                                      : 'Menunggu Tanda Tangan Pekerja Ini',
                                  isSigned: isPihakKeduaSigned,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 8),
                                _buildPartyCard(
                                  title: 'PIHAK KETIGA (Badan Usaha Penjamin Escrow & Platform)',
                                  name: 'CV Transforma Alam Kreasi — Aplikasi Kreavana',
                                  role: _opp.adminName ?? 'Otoritas Penjamin Escrow & Legalitas Sistem',
                                  statusText: 'Disahkan Otomatis oleh Sistem Resmi Aplikasi Kreavana',
                                  isSigned: true,
                                  isAdmin: true,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),

                                // PASAL 2 — NILAI HONORARIUM INDIVIDU & PROTEKSI ESCROW
                                const Text(
                                  'PASAL 2 — NILAI HONORARIUM INDIVIDU & PROTEKSI ESCROW:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF059669).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_rounded,
                                        color: Color(0xFF059669),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Honorarium Kontrak Individu (${activeEntry.creatorName}):',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              currencyFmt.format(individualFee),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                            Text(
                                              'Skema: ${activeEntry.paymentSchemeLabel}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _opp.escrowStatus == 'held' ||
                                                      _opp.status == 'in_progress'
                                                  ? 'Status: DANA TELAH DITAHAN AMAN DI ESCROW KREAVANA'
                                                  : 'Status: Dijamin Rekening Bersama saat Acara Dimulai',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // PASAL 3 — KETENTUAN KHUSUS & KLAUSUL KONTRAK (TERKUNCI SAAT KONTRAK FIX)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'PASAL 3 — KETENTUAN KHUSUS & KLAUSUL INDIVIDU (${activeEntry.creatorName} • ${activeEntry.subRoleLabel}):',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                    if (canEditClauses)
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () => _showAddOrEditClauseDialog(
                                          currentTerms: currentDynamicTerms,
                                          applicationId: activeEntry.applicationId,
                                          setModalState: setModalState,
                                        ),
                                        icon: const Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 16,
                                          color: Color(0xFF2563EB),
                                        ),
                                        label: const Text(
                                          'Tambah Klausul Individu',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lock_outline_rounded,
                                              size: 13,
                                              color: Color(0xFF059669),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'FINAL (TIDAK DAPAT DIEDIT)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isContractLocked
                                      ? 'Kontrak individu untuk ${activeEntry.creatorName} (${activeEntry.subRoleLabel}) telah disetujui dan ditandatangani kedua belah pihak (Kontrak Fix & Final) sehingga seluruh klausul telah dikunci secara permanen.'
                                      : 'Klausul khusus untuk ${activeEntry.creatorName} (${activeEntry.subRoleLabel}) ini terpisah dari pelamar lain dan dapat diedit oleh Pembuat Acara maupun Pelamar ini. Jika ada perubahan klausul, kedua belah pihak wajib menandatangani versi terbaru hingga menjadi FINAL:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E1B2E)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: currentDynamicTerms.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final term = entry.value;
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8.0),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF13111E)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.grey.withValues(alpha: 0.15),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 1.0),
                                              child: Text(
                                                '${idx + 1}. ',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2563EB),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                term,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ),
                                            if (canEditClauses) ...[
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 16,
                                                  color: Color(0xFF2563EB),
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(
                                                  minWidth: 26,
                                                  minHeight: 26,
                                                ),
                                                tooltip: 'Ubah Ketentuan',
                                                onPressed: () => _showAddOrEditClauseDialog(
                                                  currentTerms: currentDynamicTerms,
                                                  editIndex: idx,
                                                  applicationId: activeEntry.applicationId,
                                                  setModalState: setModalState,
                                                ),
                                              ),
                                              if (currentDynamicTerms.length > 1)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 16,
                                                    color: Colors.redAccent,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(
                                                    minWidth: 26,
                                                    minHeight: 26,
                                                  ),
                                                  tooltip: 'Hapus Ketentuan',
                                                  onPressed: () async {
                                                    setModalState(() {
                                                      currentDynamicTerms.removeAt(idx);
                                                    });
                                                    try {
                                                      final res = await OpportunityService
                                                          .updateDynamicTerms(
                                                        opportunityId: _opp.id ?? '',
                                                        applicationId:
                                                            activeEntry.applicationId,
                                                        dynamicTerms: currentDynamicTerms,
                                                      );
                                                      if (res['status'] == true &&
                                                          res['data'] != null) {
                                                        final updatedOpp =
                                                            res['data'] as OpportunityModel;
                                                        await _fetchApplications();
                                                        setModalState(
                                                          () => _opp = updatedOpp,
                                                        );
                                                        setState(() => _opp = updatedOpp);
                                                      }
                                                    } catch (_) {}
                                                  },
                                                ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // 3 KOLOM TANDA TANGAN DIGITAL BERDAMPINGAN
                                const Text(
                                  'PASAL 4 — LEMBAR PENGESAHAN TANDA TANGAN DIGITAL (3 PIHAK):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // TTD Pihak Pertama (Klien)
                                    Expanded(
                                      child: _buildSignatureBox(
                                        title: 'Pihak Pertama\n(Penyelenggara)',
                                        signer: _opp.poster?.name ??
                                            (_effectiveUser?.name ?? 'Klien Penyelenggara'),
                                        signature: activeEntry.clientSignature ?? '',
                                        date: (activeEntry.clientSignedAt != null &&
                                                activeEntry.clientSignedAt!.length >= 10)
                                            ? activeEntry.clientSignedAt!.substring(0, 10)
                                            : '-',
                                        isSigned: isClientSigned,
                                        canSign: canSignAsClient,
                                        onSignTap: () {
                                          _showSignContractDialog(
                                            roleTitle:
                                                'Pihak Pertama (Penyelenggara) — Kontrak ${activeEntry.creatorName}',
                                            defaultSignerName: _effectiveUser?.name ??
                                                (_opp.poster?.name ?? ''),
                                            currentTerms: currentDynamicTerms,
                                            applicationId: activeEntry.applicationId,
                                            onSignedSuccess: (updatedOpp) async {
                                              await _fetchApplications();
                                              setModalState(() => _opp = updatedOpp);
                                              setState(() => _opp = updatedOpp);
                                            },
                                          );
                                        },
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // TTD Pihak Kedua (Kreator Individu)
                                    Expanded(
                                      child: _buildSignatureBox(
                                        title: 'Pihak Kedua\n(Pekerja Individu)',
                                        signer: activeEntry.creatorName,
                                        signature: activeEntry.creatorSignature ?? '',
                                        date: (activeEntry.creatorSignedAt != null &&
                                                activeEntry.creatorSignedAt!.length >= 10)
                                            ? activeEntry.creatorSignedAt!.substring(0, 10)
                                            : '-',
                                        isSigned: isPihakKeduaSigned,
                                        canSign: canSignAsCreator,
                                        onSignTap: () {
                                          _showSignContractDialog(
                                            roleTitle:
                                                'Pihak Kedua (Pekerja: ${activeEntry.creatorName})',
                                            defaultSignerName:
                                                _effectiveUser?.name ?? activeEntry.creatorName,
                                            currentTerms: currentDynamicTerms,
                                            applicationId: activeEntry.applicationId,
                                            onSignedSuccess: (updatedOpp) async {
                                              await _fetchApplications();
                                              setModalState(() => _opp = updatedOpp);
                                              setState(() => _opp = updatedOpp);
                                            },
                                          );
                                        },
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // TTD Pihak Ketiga (CV Transforma Alam Kreasi — Aplikasi Kreavana)
                                    Expanded(
                                      child: _buildSignatureBox(
                                        title: 'Pihak Ketiga\n(Penjamin Escrow)',
                                        signer: 'CV Transforma Alam Kreasi\n(Aplikasi Kreavana)',
                                        signature: 'TAK-KREAVANA-VERIFIED',
                                        date: (_opp.adminSignedAt != null &&
                                                _opp.adminSignedAt!.length >= 10)
                                            ? _opp.adminSignedAt!.substring(0, 10)
                                            : DateTime.now()
                                                .toIso8601String()
                                                .substring(0, 10),
                                        isSigned: true,
                                        isAdmin: true,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Diterbitkan oleh CV Transforma Alam Kreasi • Sumber: Aplikasi Kreavana',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? AppTheme.textMuted
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Format: A4 Resmi',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppTheme.textMuted
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // TOMBOL AKSI: TANDA TANGAN & UNDUH KONTRAK FIX A4
                      if (canSignAsClient) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            _showSignContractDialog(
                              roleTitle:
                                  'Pihak Pertama (Penyelenggara) — Kontrak ${activeEntry.creatorName}',
                              defaultSignerName:
                                  _effectiveUser?.name ?? (_opp.poster?.name ?? ''),
                              currentTerms: currentDynamicTerms,
                              applicationId: activeEntry.applicationId,
                              onSignedSuccess: (updatedOpp) async {
                                await _fetchApplications();
                                setModalState(() => _opp = updatedOpp);
                                setState(() => _opp = updatedOpp);
                              },
                            );
                          },
                          icon: const Icon(
                            Icons.draw_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Text(
                            'Tandatangani Kontrak ${activeEntry.creatorName} (Pihak Pertama)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ] else if (canSignAsCreator) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            _showSignContractDialog(
                              roleTitle:
                                  'Pihak Kedua (Pekerja: ${activeEntry.creatorName})',
                              defaultSignerName:
                                  _effectiveUser?.name ?? activeEntry.creatorName,
                              currentTerms: currentDynamicTerms,
                              applicationId: activeEntry.applicationId,
                              onSignedSuccess: (updatedOpp) async {
                                await _fetchApplications();
                                setModalState(() => _opp = updatedOpp);
                                setState(() => _opp = updatedOpp);
                              },
                            );
                          },
                          icon: const Icon(
                            Icons.draw_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Bubuhi Tanda Tangan Pihak Kedua (Setujui Kontrak Fix)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // TOMBOL UNDUH DOKUMEN KONTRAK RESMI A4 (PDF)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeEntry.isContractFinal
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFF475569),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _downloadOfficialContractA4(
                          activeEntry,
                          overrideClauses: currentDynamicTerms,
                        ),
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          activeEntry.isContractFinal
                              ? 'Unduh Kontrak Fix Resmi A4 — ${activeEntry.creatorName} (PDF)'
                              : 'Unduh Pratinjau Kontrak A4 — ${activeEntry.creatorName} (PDF)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (activeEntry.isContractFinal) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF059669).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: Color(0xFF059669),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'KONTRAK FIX & FINAL: Kontrak individu ${activeEntry.creatorName} (${activeEntry.contractNumber}) telah disahkan 3 pihak, tidak dapat diubah lagi, dan siap diunduh dalam format A4.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_isOwner &&
                            !_opp.isOngoing &&
                            _opp.status == 'open' &&
                            allContractsFinal) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleStartEvent();
                            },
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: Text(
                              'Seluruh ${entries.length} Kontrak Fix — Mulai Acara Sekarang',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ] else if (isClientSigned && !isPihakKeduaSigned) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD97706).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.hourglass_top_rounded,
                                color: Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Kontrak ini telah ditandatangani Pihak Pertama. Menunggu tanda tangan digital dari ${activeEntry.creatorName} (Pihak Kedua) agar menjadi Kontrak Fix.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? const Color(0xFF27273A) : const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Tutup Dokumen Kontrak',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showAddOrEditClauseDialog({
    required List<String> currentTerms,
    int? editIndex,
    String? applicationId,
    required StateSetter setModalState,
  }) async {
    final termController = TextEditingController(
      text: editIndex != null ? currentTerms[editIndex] : '',
    );

    await showDialog(
      context: context,
      builder: (diagCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                editIndex != null ? Icons.edit_note_rounded : Icons.playlist_add_rounded,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                editIndex != null ? 'Ubah Ketentuan Khusus' : 'Tambah Ketentuan Khusus',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tuliskan kesepakatan tertulis antara Penyelenggara dan Pekerja (misal: kamera disiapkan oleh EO/WO, konsumsi, akomodasi, dll):',
                style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.35),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: termController,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Contoh: Kamera Sony A7IV & lensa disiapkan oleh pihak EO/WO.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(diagCtx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final text = termController.text.trim();
                if (text.isEmpty) return;

                setModalState(() {
                  if (editIndex != null) {
                    currentTerms[editIndex] = text;
                  } else {
                    currentTerms.add(text);
                  }
                });
                Navigator.pop(diagCtx);

                try {
                  final res = await OpportunityService.updateDynamicTerms(
                    opportunityId: _opp.id ?? '',
                    applicationId: applicationId,
                    dynamicTerms: currentTerms,
                  );
                  if (res['status'] == true && res['data'] != null) {
                    final updatedOpp = res['data'] as OpportunityModel;
                    await _fetchApplications();
                    setModalState(() => _opp = updatedOpp);
                    setState(() => _opp = updatedOpp);
                    if (mounted) {
                      AppSnackbar.success(context, 'Ketentuan khusus kontrak berhasil disimpan!');
                    }
                  } else if (mounted) {
                    AppSnackbar.error(
                      context,
                      res['message'] ?? 'Kontrak telah terkunci (Final) dan tidak dapat diedit.',
                    );
                  }
                } catch (e) {
                  if (mounted) AppSnackbar.error(context, e.toString());
                }
              },
              child: Text(
                editIndex != null ? 'Simpan Perubahan' : 'Tambahkan',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSignContractDialog({
    required String roleTitle,
    required String defaultSignerName,
    required List<String> currentTerms,
    String? applicationId,
    bool signAll = false,
    required Function(OpportunityModel updatedOpp) onSignedSuccess,
  }) async {
    final signerController = TextEditingController(text: defaultSignerName);
    bool agreeChecked = false;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (diagCtx) {
        return StatefulBuilder(
          builder: (diagCtx, setDiagState) {
            final isDark = Theme.of(diagCtx).brightness == Brightness.dark;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.draw_rounded, color: Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tanda Tangan Digital Dinamis',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengesahan Dokumen: $roleTitle',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Nama Lengkap Penandatangan *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: signerController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                        hintText: 'Nama lengkap Anda...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),

                    // Hash dan Penjamin Escrow Info
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.security_rounded, size: 14, color: Color(0xFF059669)),
                              SizedBox(width: 6),
                              Text('Validasi Legal Kriptografis (3 Pihak)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tanda tangan elektronik ini terikat secara legal dengan CV Transforma Alam Kreasi melalui sistem penjamin Escrow Rekber Aplikasi Kreavana. Setelah disetujui kedua belah pihak, kontrak menjadi FINAL (Kontrak Fix) dan tidak dapat diubah lagi.',
                            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, height: 1.35),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Digital Token: SIG-${DateTime.now().millisecondsSinceEpoch}-${widget.user?.id?.substring(0, 6) ?? "0000"}',
                            style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Checkbox
                    InkWell(
                      onTap: () {
                        setDiagState(() => agreeChecked = !agreeChecked);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: agreeChecked,
                            activeColor: const Color(0xFF059669),
                            onChanged: (val) {
                              setDiagState(() => agreeChecked = val ?? false);
                            },
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Saya menyatakan menyetujui seluruh klausul dan secara sadar menandatangani surat perjanjian kerja 3 pihak ini menjadi Kontrak Fix.',
                                style: TextStyle(fontSize: 11.5, height: 1.35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(diagCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (agreeChecked && signerController.text.trim().isNotEmpty)
                        ? const Color(0xFF059669)
                        : Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (agreeChecked && signerController.text.trim().isNotEmpty && !isSubmitting)
                      ? () async {
                          setDiagState(() => isSubmitting = true);
                          try {
                            final signerName = signerController.text.trim();
                            final sigPayload = 'DIGITAL_SIGNATURE:$signerName:${DateTime.now().toIso8601String()}:SECURE_ESCROW';
                            final res = await OpportunityService.signContract(
                              opportunityId: _opp.id ?? '',
                              applicationId: applicationId,
                              signAll: signAll,
                              signature: sigPayload,
                              signatureType: 'dynamic_electronic',
                              dynamicTerms: currentTerms,
                            );

                            if (res['status'] == true && res['data'] != null) {
                              if (diagCtx.mounted) Navigator.pop(diagCtx);
                              final updated = res['data'] as OpportunityModel;
                              onSignedSuccess(updated);
                              if (mounted) {
                                AppSnackbar.success(context, 'Tanda tangan digital Anda berhasil dibubuhkan secara sah!');
                              }
                            } else {
                              if (mounted) {
                                AppSnackbar.error(context, res['message'] ?? 'Gagal menandatangani kontrak.');
                              }
                            }
                          } catch (e) {
                            if (mounted) AppSnackbar.error(context, e.toString());
                          } finally {
                            if (mounted) setDiagState(() => isSubmitting = false);
                          }
                        }
                      : null,
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Bubuhkan Tanda Tangan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPartyCard({
    required String title,
    required String name,
    required String role,
    required String statusText,
    required bool isSigned,
    bool isAdmin = false,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAdmin ? Colors.blue.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.verified_user_rounded : (isSigned ? Icons.check_circle_rounded : Icons.pending_rounded),
            color: isAdmin ? const Color(0xFF2563EB) : (isSigned ? const Color(0xFF059669) : Colors.orange),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isAdmin ? const Color(0xFF2563EB) : Colors.grey.shade600)),
                Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                Text('$role • $statusText', style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBox({
    required String title,
    required String signer,
    required String signature,
    required String date,
    required bool isSigned,
    bool isAdmin = false,
    bool canSign = false,
    VoidCallback? onSignTap,
    required bool isDark,
  }) {
    final statusColor = isAdmin
        ? const Color(0xFF2563EB)
        : (isSigned ? const Color(0xFF059669) : Colors.orange);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAdmin
              ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
              : (isSigned
                  ? const Color(0xFF059669).withValues(alpha: 0.4)
                  : Colors.orange.withValues(alpha: 0.3)),
          width: isSigned ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          if (canSign && !isSigned)
            InkWell(
              onTap: onSignTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(Icons.edit_document, size: 20, color: Colors.white),
                    SizedBox(height: 2),
                    Text(
                      'TANDA TANGANI\nSEKARANG',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Icon(
                    isAdmin ? Icons.verified_rounded : (isSigned ? Icons.verified_rounded : Icons.pending_actions_rounded),
                    size: 20,
                    color: statusColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAdmin
                        ? 'STEMPEL RESMI\nKREAVANA'
                        : (isSigned ? 'TERVERIFIKASI\nDIGITAL SIGN' : 'MENUNGGU\nPENGESAHAN'),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(signer, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          Text(isSigned ? 'Tgl: $date' : 'Status: Menunggu TTD', style: TextStyle(fontSize: 8.5, color: isSigned ? Colors.grey.shade600 : Colors.orange), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _handleUpdateProgress(int progress) async {
    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.updateProgress(_opp.id ?? '', progress);
      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() {
            _opp = res['data'] as OpportunityModel;
          });
          AppSnackbar.success(context, 'Progress acara berhasil diperbarui ke $progress%!');
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memperbarui progress.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleMarketingConfirm() async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Konfirmasi MoU & Dana Diterima'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sebagai Tim Marketing / Admin Kreavana, konfirmasikan bahwa dokumen perjanjian kerjasama (MoU) formal telah ditandatangani dan dana proyek (>= 20 Jt) telah diverifikasi secara sah.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan Verifikasi Marketing',
                hintText: 'Misal: Dokumen MoU No. 042/MoU/2026 telah ditandatangani di Kantor Sudirman.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi & Setujui', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.confirmOpportunityPayment(
        opportunityId: _opp.id ?? '',
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );
      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, 'Status MoU dan penerimaan dana telah diverifikasi oleh Marketing!');
          final oppRes = await OpportunityService.getOpportunityById(_opp.id ?? '');
          if (oppRes != null) {
            setState(() => _opp = oppRes);
          }
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal konfirmasi.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleSubmitDeliverable(OpportunityApplicationModel app) async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedType = 'link'; // 'link', 'image', 'video', 'document'

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.upload_file_rounded, color: AppTheme.primaryPurple),
                SizedBox(width: 8),
                Text('Unggah Hasil Kerja (Deliverables)'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pekerja dapat mengunggah bukti hasil kerja berupa Tautan (Link Drive/Figma), Foto/Gambar, Video Dokumentasi, atau Dokumen Berkas.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  const Text('Pilih Tipe Hasil Kerja:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('🔗 Link URL', style: TextStyle(fontSize: 11)),
                        selected: selectedType == 'link',
                        onSelected: (val) => setDialogState(() => selectedType = 'link'),
                      ),
                      ChoiceChip(
                        label: const Text('🖼️ Foto / Image', style: TextStyle(fontSize: 11)),
                        selected: selectedType == 'image',
                        onSelected: (val) => setDialogState(() => selectedType = 'image'),
                      ),
                      ChoiceChip(
                        label: const Text('🎥 Video', style: TextStyle(fontSize: 11)),
                        selected: selectedType == 'video',
                        onSelected: (val) => setDialogState(() => selectedType = 'video'),
                      ),
                      ChoiceChip(
                        label: const Text('📄 Dokumen', style: TextStyle(fontSize: 11)),
                        selected: selectedType == 'document',
                        onSelected: (val) => setDialogState(() => selectedType = 'document'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Judul Hasil Kerja / Berkas *',
                      hintText: 'Misal: Link RAW Files Foto / Final Video Highlight',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: selectedType == 'link'
                          ? 'Tautan URL (Drive / Figma / YouTube) *'
                          : 'Tautan / URL Berkas *',
                      hintText: 'https://...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Keterangan (Opsional)',
                      hintText: 'Akses link telah dibuka, password zip...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
                    AppSnackbar.error(ctx, 'Judul dan URL tautan hasil kerja wajib diisi.');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Kirim Hasil Kerja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.uploadDeliverable(
        applicationId: app.id,
        type: selectedType,
        title: titleCtrl.text.trim(),
        url: urlCtrl.text.trim(),
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, 'Hasil kerja ($selectedType) berhasil dikirimkan!');
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal mengunggah hasil kerja.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleUpdateWorkerProgress(OpportunityApplicationModel app) async {
    int current = app.workerProgress;
    String selectedStatus = app.workerStatus;
    final notesCtrl = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.trending_up_rounded, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update Progress: ${app.creator?.name ?? app.subRoleLabel}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atur persentase penyelesaian tugas untuk posisi ${app.subRoleLabel}:',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '$current%',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                    ),
                  ),
                  Slider(
                    value: current.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '$current%',
                    activeColor: const Color(0xFF059669),
                    onChanged: (val) {
                      setDialogState(() {
                        current = val.round();
                        if (current >= 100) {
                          selectedStatus = 'completed';
                        } else if (selectedStatus == 'completed') {
                          selectedStatus = 'in_progress';
                        }
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [0, 25, 50, 75, 100].map((step) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            current = step;
                            if (current >= 100) {
                              selectedStatus = 'completed';
                            } else if (selectedStatus == 'completed') {
                              selectedStatus = 'in_progress';
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: current == step
                                ? const Color(0xFF059669).withValues(alpha: 0.15)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$step%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: current == step ? const Color(0xFF059669) : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Status Pengerjaan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('⏳ Sedang Berjalan', style: TextStyle(fontSize: 11)),
                        selected: selectedStatus == 'in_progress',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedStatus = 'in_progress');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('🔍 Siap Ditinjau Klien', style: TextStyle(fontSize: 11)),
                        selected: selectedStatus == 'review',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedStatus = 'review');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('🔄 Sedang Revisi', style: TextStyle(fontSize: 11)),
                        selected: selectedStatus == 'revision',
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedStatus = 'revision');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('✅ Selesai 100%', style: TextStyle(fontSize: 11)),
                        selected: selectedStatus == 'completed',
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selectedStatus = 'completed';
                              current = 100;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Progress (Opsional)',
                      hintText: 'Misal: Pengambilan gambar selesai, tahap editing video...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                onPressed: () => Navigator.pop(ctx, {
                  'progress': current,
                  'status': selectedStatus,
                  'notes': notesCtrl.text.trim(),
                }),
                child: const Text('Simpan Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    final targetProgress = result['progress'] as int;
    final targetStatus = result['status'] as String?;
    final targetNotes = (result['notes'] as String?)?.isNotEmpty == true ? result['notes'] as String : null;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.updateWorkerProgress(
        applicationId: app.id,
        progress: targetProgress,
        notes: targetNotes,
        workerStatus: targetStatus,
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, 'Progress berhasil diperbarui menjadi $targetProgress%!');
          await _fetchApplications();
          final updatedOpp = await OpportunityService.getOpportunityById(_opp.id ?? '');
          if (updatedOpp != null && mounted) {
            setState(() => _opp = updatedOpp);
          }
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memperbarui progress.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleRequestRevision(OpportunityApplicationModel app) async {
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_late_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Minta Revisi Hasil Kerja',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kirimkan instruksi dan rincian perbaikan kepada ${app.creator?.name ?? "pekerja"} (${app.subRoleLabel}):',
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan & Rincian Revisi *',
                hintText: 'Misal: Mohon sesuaikan color grading video dan rapikan file resolusi tinggi.',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () {
              if (notesCtrl.text.trim().isEmpty) {
                AppSnackbar.error(ctx, 'Catatan rincian revisi wajib diisi.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text('Kirim Catatan Revisi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.updateWorkerProgress(
        applicationId: app.id,
        progress: app.workerProgress,
        notes: notesCtrl.text.trim(),
        workerStatus: 'revision',
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, 'Permintaan revisi berhasil dikirimkan ke pekerja.');
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal mengirim permintaan revisi.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleApproveWorkerWork(OpportunityApplicationModel app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Setujui Hasil Kerja',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda puas dengan hasil kerja dari ${app.creator?.name ?? "pekerja"} (${app.subRoleLabel})?\n\n'
          'Pekerjaan akan ditandai selesai 100% dan Anda dapat melanjutkan proses pencairan honorarium.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Setujui Selesai 100%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.updateWorkerProgress(
        applicationId: app.id,
        progress: 100,
        notes: 'Hasil kerja telah disetujui oleh penyelenggara acara.',
        workerStatus: 'completed',
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, 'Hasil kerja disetujui! Pekerjaan telah selesai 100%.');
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal menyetujui hasil kerja.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handlePayWorkerTerm(
    OpportunityApplicationModel app, {
    int? milestoneIndex,
    double? amount,
    String? title,
    String? note,
  }) async {
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final targetAmount = amount ?? (milestoneIndex != null && milestoneIndex < app.paymentTerms.length
        ? (double.tryParse(app.paymentTerms[milestoneIndex]['amount']?.toString() ?? '0') ?? 0.0)
        : app.remainingUnpaidFee);

    final termTitle = note ?? title ?? (milestoneIndex != null && milestoneIndex < app.paymentTerms.length
        ? (app.paymentTerms[milestoneIndex]['title'] ?? 'Termin ${milestoneIndex + 1}')
        : 'Pelunasan Penuh');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Konfirmasi Pencairan Honor'),
          ],
        ),
        content: Text(
          'Anda akan mencairkan pembayaran honor dari Escrow Rekber Kreavana:\n\n'
          '• Penerima: ${app.creator?.name ?? "Pekerja"}\n'
          '• Peran: ${app.subRoleLabel}\n'
          '• Tahap: $termTitle\n'
          '• Nominal: ${currencyFmt.format(targetAmount)}\n\n'
          'Dana sebesar ${currencyFmt.format(targetAmount)} akan langsung diteruskan ke dompet saldo pekerja secara aman.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Cairkan Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.payWorker(
        applicationId: app.id,
        milestoneIndex: milestoneIndex,
        amount: targetAmount,
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, res['message'] ?? 'Pembayaran berhasil dicairkan ke pekerja!');
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal mencairkan pembayaran.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleAutoReleaseEscrow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Auto-Release Dana Escrow?'),
          ],
        ),
        content: const Text(
          'Masa tenggang 1 bulan pasca tanggal acara telah lewat.\n\n'
          'Sistem akan mencairkan seluruh sisa dana Escrow yang belum dibayarkan langsung ke masing-masing pekerja sesuai kesepakatan nego resmi.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eksekusi Auto-Release', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.autoReleaseEscrow(_opp.id ?? '');
      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, res['message'] ?? 'Auto-release berhasil dijalankan!');
          await _fetchApplications();
          final updated = await OpportunityService.getOpportunityById(_opp.id ?? '');
          if (updated != null && mounted) setState(() => _opp = updated);
        } else {
          AppSnackbar.info(context, res['message'] ?? 'Masa tenggang 1 bulan belum terpenuhi.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleAdminCounterMeeting() async {
    final dateCtrl = TextEditingController(text: _opp.meetingCounterDate ?? _opp.meetingDate ?? '');
    final timeCtrl = TextEditingController(text: _opp.meetingCounterTime ?? _opp.meetingTime ?? '15:30 WIB');
    final locCtrl = TextEditingController(text: _opp.meetingCounterLocation ?? _opp.meetingLocation ?? 'Kantor Pusat Kreavana Creative Hub');
    final notesCtrl = TextEditingController(text: _opp.meetingCounterNotes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.handshake_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nego Jadwal & Lokasi Temu (Admin)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Sebagai Admin, jika jadwal sedang padat pada jam tersebut atau lokasi pemohon terlalu jauh, '
                  'Anda dapat mengusulkan tanggal, waktu, dan lokasi alternatif untuk pertemuan fisik.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Alternatif (YYYY-MM-DD) *',
                  hintText: '2026-11-20',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Waktu Alternatif *',
                  hintText: '16:00 WIB',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lokasi Alternatif *',
                  hintText: 'Kantor Pusat Kreavana Creative Hub',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alasan Nego Jadwal / Lokasi *',
                  hintText: 'Contoh: Jam 14:00 jadwal padat rapat legal, lokasi sebelumnya kejauhan...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            onPressed: () {
              if (dateCtrl.text.trim().isEmpty || timeCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty) {
                AppSnackbar.error(ctx, 'Tanggal, waktu, dan lokasi wajib diisi.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Kirim Nego Jadwal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.reviewMeeting(
        opportunityId: _opp.id ?? '',
        decision: 'counter',
        counterDate: dateCtrl.text.trim(),
        counterTime: timeCtrl.text.trim(),
        counterLocation: locCtrl.text.trim(),
        counterNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() => _opp = res['data'] as OpportunityModel);
          AppSnackbar.success(context, 'Tawaran alternatif jadwal dan lokasi berhasil dikirim ke pembuat acara!');
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal mengirim usulan jadwal.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleRespondMeetingCounter(String action) async {
    if (action == 'accept') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Expanded(child: Text('Terima Jadwal Usulan Admin?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(
            'Apakah Anda menyetujui jadwal dan lokasi temu yang diusulkan oleh Admin Kreavana?\n\n'
            '• Tanggal: ${_opp.meetingCounterDate ?? _opp.meetingDate ?? "-"}\n'
            '• Waktu: ${_opp.meetingCounterTime ?? _opp.meetingTime ?? "-"}\n'
            '• Lokasi: ${_opp.meetingCounterLocation ?? _opp.meetingLocation ?? "-"}\n'
            '• Catatan: ${_opp.meetingCounterNotes ?? "-"}\n\n'
            'Setelah disetujui, status jadwal pertemuan resmi menjadi DIPROSES.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Setujui Jadwal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _actionLoading = true);
      try {
        final res = await OpportunityService.respondMeetingCounter(
          opportunityId: _opp.id ?? '',
          action: 'accept',
        );

        if (mounted) {
          if (res['status'] == true && res['data'] != null) {
            setState(() => _opp = res['data'] as OpportunityModel);
            AppSnackbar.success(context, 'Jadwal usulan Admin disetujui! Status: DIPROSES.');
          } else {
            AppSnackbar.error(context, res['message'] ?? 'Gagal menerima usulan jadwal.');
          }
        }
      } catch (e) {
        if (mounted) AppSnackbar.error(context, e.toString());
      } finally {
        if (mounted) setState(() => _actionLoading = false);
      }
      return;
    }

    if (action == 'counter') {
      // Penyelenggara tawar balik
      final dateCtrl = TextEditingController(text: _opp.meetingDate ?? '');
      final timeCtrl = TextEditingController(text: _opp.meetingTime ?? '15:00 WIB');
      final locCtrl = TextEditingController(text: _opp.meetingLocation ?? '');
      final notesCtrl = TextEditingController();

      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.handshake_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(child: Text('Tawar Balik Jadwal & Lokasi ke Admin', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ajukan waktu atau tempat alternatif yang lebih cocok bagi Anda untuk ditinjau kembali oleh Admin Kreavana:',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Pertemuan (YYYY-MM-DD) *',
                    hintText: '2026-11-20',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Waktu Pertemuan *',
                    hintText: '15:00 WIB',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lokasi Pertemuan *',
                    hintText: 'Contoh: Kafe X / Kantor Penyelenggara',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan / Alasan Tawar Balik',
                    hintText: 'Misal: Lokasi usulan admin kejauhan dari studio kami...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              onPressed: () {
                if (dateCtrl.text.trim().isEmpty || timeCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty) {
                  AppSnackbar.error(ctx, 'Tanggal, waktu, dan lokasi wajib diisi.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Kirim Tawaran Balik', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (result != true) return;

      setState(() => _actionLoading = true);
      try {
        final res = await OpportunityService.respondMeetingCounter(
          opportunityId: _opp.id ?? '',
          action: 'counter',
          date: dateCtrl.text.trim(),
          time: timeCtrl.text.trim(),
          location: locCtrl.text.trim(),
          notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        );

        if (mounted) {
          if (res['status'] == true && res['data'] != null) {
            setState(() => _opp = res['data'] as OpportunityModel);
            AppSnackbar.success(context, 'Tawaran balik berhasil dikirim ke Admin Kreavana!');
          } else {
            AppSnackbar.error(context, res['message'] ?? 'Gagal mengirim tawaran balik.');
          }
        }
      } catch (e) {
        if (mounted) AppSnackbar.error(context, e.toString());
      } finally {
        if (mounted) setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _handleAdminReviewMeeting({bool approveDirectly = false}) async {
    if (approveDirectly) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Expanded(child: Text('Setujui Jadwal Temu Fisik?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(
            'Apakah Anda menyetujui jadwal dan lokasi temu yang diajukan pembuat acara?\n\n'
            '• Tanggal: ${_opp.meetingDate ?? "-"}\n'
            '• Waktu: ${_opp.meetingTime ?? "-"}\n'
            '• Lokasi: ${_opp.meetingLocation ?? "-"}\n\n'
            'Setelah disetujui, status jadwal akan resmi berubah menjadi DIPROSES.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Setujui', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      setState(() => _actionLoading = true);
      try {
        final res = await OpportunityService.reviewMeeting(
          opportunityId: _opp.id ?? '',
          decision: 'approve',
        );
        if (mounted) {
          if (res['status'] == true && res['data'] != null) {
            setState(() => _opp = res['data'] as OpportunityModel);
            AppSnackbar.success(context, 'Jadwal pertemuan fisik disetujui! Status: DIPROSES.');
          } else {
            AppSnackbar.error(context, res['message'] ?? 'Gagal memperbarui status jadwal.');
          }
        }
      } catch (e) {
        if (mounted) AppSnackbar.error(context, e.toString());
      } finally {
        if (mounted) setState(() => _actionLoading = false);
      }
      return;
    }

    final notesCtrl = TextEditingController();

    final decision = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Expanded(child: Text('Tinjau Jadwal Temu Fisik (Admin)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Penyelenggara mengajukan jadwal temu tanda tangan basah:\n'
                '• Tanggal: ${_opp.meetingDate ?? "-"}\n'
                '• Waktu: ${_opp.meetingTime ?? "-"}\n'
                '• Lokasi: ${_opp.meetingLocation ?? "-"}\n'
                '• Catatan: ${_opp.meetingNotes ?? "-"}\n\n'
                'Silakan pilih tindakan berikut:',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan Admin (Opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'reject'),
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF6366F1))),
            onPressed: () => Navigator.pop(ctx, 'counter'),
            icon: const Icon(Icons.handshake_rounded, size: 14, color: Color(0xFF6366F1)),
            label: const Text('Nego Jadwal & Tempat', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, 'approve'),
            child: const Text('Setujui', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (decision == null) return;

    if (decision == 'counter') {
      await _handleAdminCounterMeeting();
      return;
    }

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.reviewMeeting(
        opportunityId: _opp.id ?? '',
        decision: decision,
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() => _opp = res['data'] as OpportunityModel);
          AppSnackbar.success(context, res['message'] ?? 'Status jadwal berhasil diperbarui!');
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memperbarui status jadwal.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleAdminStartEventAfterWetSignature() async {
    final docCtrl = TextEditingController(text: _opp.wetSignatureDocumentUrl ?? '');
    final notesCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(child: Text('Verifikasi TTD Basah & Mulai Acara', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pertemuan fisik telah disetujui (Status: Diproses).\n\n'
                'Admin akan memverifikasi bahwa penandatanganan dokumen MoU fisik basah telah selesai dilakukan oleh ketiga pihak, menahan saldo Escrow secara resmi, dan mengaktifkan acara.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: docCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL / Bukti Dokumen MoU Basah (Opsional)',
                  hintText: 'https://storage... / scan-mou.pdf',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.picture_as_pdf_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan Verifikasi Admin Legal (Opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verifikasi & Mulai Acara Resmi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.adminStartEvent(
        opportunityId: _opp.id ?? '',
        documentMouUrl: docCtrl.text.trim().isNotEmpty ? docCtrl.text.trim() : null,
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() => _opp = res['data'] as OpportunityModel);
          AppSnackbar.success(context, 'Acara resmi dimulai oleh Admin setelah verifikasi tanda tangan basah fisik!');
          await _fetchApplications();
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal memulai acara.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  int _computeAiScore(OpportunityApplicationModel app) {
    int score = 65;
    final rating = app.creator?.rating ?? 4.5;
    score += ((rating / 5.0) * 18).round();
    if (app.creator?.isUpgraded == true) score += 10;
    if (app.creator?.isVerified == true) score += 5;
    final completed = app.creator?.completedProjectsCount ?? 0;
    if (completed >= 5) score += 2;
    return score.clamp(50, 99);
  }

  Future<void> _handleScheduleMeeting() async {
    final dateCtrl = TextEditingController(text: _opp.meetingDate ?? '');
    final timeCtrl = TextEditingController(text: _opp.meetingTime ?? '14:00 WIB');
    final locCtrl = TextEditingController(text: _opp.meetingLocation ?? 'Kantor Kreavana Creative Hub');
    final notesCtrl = TextEditingController(text: _opp.meetingNotes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.handshake_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('Jadwal Temu Tanda Tangan Basah Dokumen Fisik (3 Pihak)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pertemuan tatap muka penandatanganan berkas MoU fisik asli untuk proyek bernilai >= Rp 100.000.000.\n\n'
                  'Dihadiri oleh 3 Pihak:\n'
                  '1. Admin Kreavana (Tim Legal & Penjamin Escrow)\n'
                  '2. Pembuat Acara (Penyelenggara)\n'
                  '3. Penerima Kerjaan (Kreator yang disetujui)\n\n'
                  'Setelah diajukan, status jadwal adalah PENDING menunggu persetujuan Admin Kreavana. Jika disetujui Admin, status menjadi DIPROSES.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Pertemuan (YYYY-MM-DD) *',
                  hintText: '2026-11-20',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Waktu Pertemuan *',
                  hintText: '14:00 WIB',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lokasi Pertemuan Tatap Muka *',
                  hintText: 'Kreavana Creative Hub, Jakarta Selatan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan Dokumen Fisik (Opsional)',
                  hintText: 'Membawa draft dokumen pengadaan fisik asli...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () {
              if (dateCtrl.text.trim().isEmpty) {
                AppSnackbar.error(ctx, 'Tanggal pertemuan wajib diisi.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Ajukan Jadwal Temu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.scheduleMeeting(
        opportunityId: _opp.id ?? '',
        meetingDate: dateCtrl.text.trim(),
        meetingTime: timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : '14:00 WIB',
        meetingLocation: locCtrl.text.trim().isNotEmpty ? locCtrl.text.trim() : 'Kantor Kreavana Creative Hub',
        meetingNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );
      if (mounted) {
        if (res['status'] == true && res['data'] != null) {
          setState(() {
            _opp = res['data'] as OpportunityModel;
          });
          AppSnackbar.success(context, 'Jadwal pertemuan fisik tanda tangan basah diajukan! Status: PENDING (Menunggu Persetujuan Admin Kreavana).');
        } else {
          AppSnackbar.error(context, res['message'] ?? 'Gagal menjadwalkan pertemuan.');
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Widget _buildBannerDisplay(String url) {
    if (url.startsWith('data:image')) {
      final commaIndex = url.indexOf(',');
      final base64Part = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
      try {
        return Image.memory(
          base64Decode(base64Part),
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return Image.network(
      url,
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _handleUpdateBanner() async {
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.photo_library_outlined, color: AppTheme.primaryPurple, size: 22),
            SizedBox(width: 8),
            Text('Ganti / Pasang Banner Acara', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.25)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppTheme.primaryPurple),
                        SizedBox(width: 6),
                        Text(
                          'Ketentuan Format & Ukuran Banner:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Dimensi Rekomendasi: 1200 × 675 px (Rasio 16:9)\n• Ukuran Maksimal: 5 MB\n• Format: JPG, PNG, WebP',
                      style: TextStyle(fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.file_upload_outlined, size: 20),
                  label: const Text('Upload Foto dari Perangkat', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    try {
                      final fileRes = await FilePicker.pickFiles(
                        type: FileType.image,
                        allowMultiple: false,
                        withData: true,
                      );
                      if (fileRes == null || fileRes.files.isEmpty) return;
                      final file = fileRes.files.first;
                      if (file.size > 5 * 1024 * 1024) {
                        if (ctx.mounted) {
                          AppSweetAlert.warning(
                            ctx,
                            'Ukuran file banner (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB) melebihi batas maksimal 5 MB.',
                            title: 'Ukuran Melebihi Batas',
                          );
                        }
                        return;
                      }
                      Uint8List? bytes = file.bytes;
                      if (bytes == null && file.path != null && !kIsWeb) {
                        final f = File(file.path!);
                        if (await f.exists()) bytes = await f.readAsBytes();
                      }
                      if (bytes != null && bytes.isNotEmpty) {
                        final ext = (file.extension?.toLowerCase() ?? 'jpg').replaceAll('.', '');
                        final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
                        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
                        if (ctx.mounted) Navigator.pop(ctx, dataUri);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        AppSnackbar.error(ctx, 'Gagal memilih gambar: $e');
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Atau Pilih Preset Tema Siap Pakai:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.music_note, size: 14),
                    label: const Text('Konser Musik', style: TextStyle(fontSize: 12)),
                    onPressed: () => Navigator.pop(ctx, 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=1200&q=80'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.directions_run, size: 14),
                    label: const Text('Marathon & Olahraga', style: TextStyle(fontSize: 12)),
                    onPressed: () => Navigator.pop(ctx, 'https://images.unsplash.com/photo-1452626038306-9aae5e071dd3?w=1200&q=80'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.palette, size: 14),
                    label: const Text('Pameran Kreatif', style: TextStyle(fontSize: 12)),
                    onPressed: () => Navigator.pop(ctx, 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1200&q=80'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.favorite, size: 14),
                    label: const Text('Wedding & Event', style: TextStyle(fontSize: 12)),
                    onPressed: () => Navigator.pop(ctx, 'https://images.unsplash.com/photo-1519741497674-611481863552?w=1200&q=80'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (_opp.bannerUrl != null && _opp.bannerUrl!.isNotEmpty)
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, ''),
              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
              label: const Text('Hapus Banner', style: TextStyle(color: Color(0xFFEF4444))),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Batal')),
        ],
      ),
    );

    if (result == null) return;

    setState(() {
      _opp = _opp.copyWith(bannerUrl: result.isEmpty ? null : result);
    });
    if (mounted) {
      AppSnackbar.success(
        context,
        result.isEmpty ? 'Banner acara berhasil dihapus.' : 'Banner acara berhasil diperbarui!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    final filteredApps = _applications.where((a) {
      if (_selectedFilter == 'Semua') return true;
      return a.status.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    final content = Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0D15) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Detail Kebutuhan Proyek',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF14121F) : Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang Pelamar',
            onPressed: _loadingApps ? null : _fetchApplications,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: isDesktop ? 28 : 16,
        ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Breadcrumbs ──
                AppBreadcrumbs(
                  items: [
                    BreadcrumbItem(
                      label: 'Proyek Saya',
                      icon: Icons.folder_outlined,
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProyekSayaScreen(user: widget.user),
                            ),
                          );
                        }
                      },
                    ),
                    const BreadcrumbItem(
                      label: 'Detail Kebutuhan',
                      icon: Icons.assignment_outlined,
                    ),
                    BreadcrumbItem(
                      label: _opp.title,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Hero Header Card ──
                _buildHeroHeader(isDark),
                const SizedBox(height: 24),

                // ── Event Progress Milestone Tracker (if in progress or completed) ──
                if (_opp.isOngoing || _opp.eventProgress > 0) ...[
                  _buildEventProgressCard(isDark),
                  const SizedBox(height: 24),
                ],

                // ── Escrow (<20 Jt) or Legal MoU Meeting (>=20 Jt) Card ──
                _buildHighValueMoUCard(isDark),
                const SizedBox(height: 24),

                // ── 2-Column Responsive Layout on Desktop ──
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: AI Recommendations + Applications + Description (62%)
                      Expanded(
                        flex: 62,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isOwner) ...[
                              _buildAiRecommendationsSection(isDark),
                              const SizedBox(height: 24),
                              _buildApplicationsSection(filteredApps, isDark),
                              const SizedBox(height: 24),
                            ] else if (_loadingApps) ...[
                              _buildMyApplicationLoadingCard(isDark),
                              const SizedBox(height: 24),
                            ] else if (_myApplication != null) ...[
                              _buildMyApplicationStatusSection(_myApplication!, isDark),
                              const SizedBox(height: 24),
                            ],
                            _buildDescriptionSection(isDark),
                            const SizedBox(height: 24),
                            _buildRequirementsSection(isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Right Column: Project Info & Summary (38%)
                      Expanded(
                        flex: 38,
                        child: Column(
                          children: [
                            _buildProjectInfoCard(isDark),
                            const SizedBox(height: 20),
                            _buildOwnerCard(isDark),
                            if (_opp.approvedCreators.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _buildApprovedCreatorsCard(isDark),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  // Mobile Single Column
                  if (_isOwner) ...[
                    _buildAiRecommendationsSection(isDark),
                    const SizedBox(height: 20),
                    _buildApplicationsSection(filteredApps, isDark),
                    const SizedBox(height: 20),
                  ] else if (_loadingApps) ...[
                    _buildMyApplicationLoadingCard(isDark),
                    const SizedBox(height: 20),
                  ] else if (_myApplication != null) ...[
                    _buildMyApplicationStatusSection(_myApplication!, isDark),
                    const SizedBox(height: 20),
                  ],
                  _buildProjectInfoCard(isDark),
                  const SizedBox(height: 20),
                  _buildDescriptionSection(isDark),
                  const SizedBox(height: 20),
                  _buildRequirementsSection(isDark),
                  const SizedBox(height: 20),
                  _buildOwnerCard(isDark),
                  if (_opp.approvedCreators.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildApprovedCreatorsCard(isDark),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
        ),
    );

    if (isDesktop && widget.user != null) {
      return DesktopSidebarLayout(
        user: widget.user!,
        activeRoute: 'proyek_saya',
        child: content,
      );
    }

    return content;
  }

  // ── Hero Header ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(bool isDark) {
    final hasBanner = _opp.effectiveBannerUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Optional Banner Image ──
          if (hasBanner)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: Stack(
                children: [
                  _buildBannerDisplay(_opp.effectiveBannerUrl),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_size_select_actual_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Banner Acara Resmi',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_isOwner)
                          TextButton.icon(
                            onPressed: _handleUpdateBanner,
                            icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                            label: const Text('Ganti Banner', style: TextStyle(color: Colors.white, fontSize: 11)),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status Badge
                    if (_opp.isOngoing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill_rounded, size: 12, color: Color(0xFF059669)),
                            SizedBox(width: 5),
                            Text(
                              'SEDANG BERLANGSUNG',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _opp.status == 'open'
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _opp.status == 'open' ? 'MENCARI KREATOR' : _opp.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _opp.status == 'open'
                                ? const Color(0xFF059669)
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),

                    // SubRole Category Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.category_rounded, size: 13, color: AppTheme.primaryPurple),
                          const SizedBox(width: 5),
                          Text(
                            _opp.subRoleLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Duration Display Chip
                    if (_opp.durationDisplay.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.date_range_rounded, size: 13, color: Colors.blue),
                            const SizedBox(width: 5),
                            Text(
                              _opp.durationDisplay,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),
                    if (_opp.createdAt != null && _opp.createdAt!.isNotEmpty)
                      Text(
                        'Dibuat: ${_opp.createdAt!.substring(0, 10)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title & Action Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _opp.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_isOwner && !_opp.isOngoing && _opp.status == 'open')
                      ElevatedButton.icon(
                        onPressed: _actionLoading ? null : _handleStartEvent,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Mulai Acara',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),

                if (_opp.isOngoing) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_clock_rounded, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Acara sedang berlangsung. Pendaftaran pelamar baru telah ditutup, namun proyek tetap dapat dilihat publik beserta tim kreator yang berpartisipasi.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pelamar Application & Counter Offer Section ─────────────────────────────
  Widget _buildMyApplicationStatusSection(OpportunityApplicationModel app, bool isDark) {
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isConsideration = app.isConsideration || app.counterOfferPrice != null;
    final isApproved = app.isApproved;
    final isRejected = app.isRejected;

    final borderColor = isApproved
        ? Colors.green.shade400
        : (isConsideration
            ? const Color(0xFFF59E0B)
            : (isRejected ? Colors.red.shade400 : AppTheme.primaryPurple));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isApproved
                      ? Icons.check_circle_rounded
                      : (isConsideration ? Icons.handshake_rounded : Icons.assignment_ind_rounded),
                  color: borderColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Lamaran Anda',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Posisi: ${app.subRoleLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildApplicationStatusBadge(app.status),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Proposal Detail
          Row(
            children: [
              Text(
                'Ajuan Dana Awal Anda:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                app.bidPrice != null && app.bidPrice! > 0
                    ? currencyFmt.format(app.bidPrice)
                    : 'Sesuai Kesepakatan',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          if (app.pitchMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Pesan Lamaran: "${app.pitchMessage}"',
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ],

          // ── KOTAK TAWARAN NEGO DANA DARI PEMILIK PROYEK ───────────────────
          if (isConsideration && app.counterOfferPrice != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.handshake_rounded, color: Color(0xFFD97706), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.counterOfferBy == 'creator'
                                  ? 'Penawaran Balik dari Anda'
                                  : 'Tawaran Nego Dana dari Pemilik Proyek',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app.counterOfferBy == 'creator'
                                  ? 'Anda telah mengajukan penawaran baru kepada pemilik proyek:'
                                  : 'Pemilik proyek mempertimbangkan lamaran Anda dengan tawaran nilai kesepakatan:',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFmt.format(app.counterOfferPrice),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            if (app.counterOfferNotes != null && app.counterOfferNotes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                app.counterOfferBy == 'creator'
                                    ? 'Catatan Anda: "${app.counterOfferNotes}"'
                                    : 'Catatan Pemilik: "${app.counterOfferNotes}"',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Respons / Tombol Aksi
                  if (app.counterOfferStatus == 'pending') ...[
                    const Divider(color: Color(0xFFF59E0B), height: 1),
                    const SizedBox(height: 12),
                    if (app.counterOfferBy == 'creator') ...[
                      Text(
                        'Menunggu tanggapan / persetujuan dari pemilik proyek:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleCreatorCounterDialog(app),
                            icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFD97706)),
                            label: const Text('Ubah Tawaran Anda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFD97706))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD97706)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          if (_opp.postedBy != null)
                            TextButton.icon(
                              onPressed: () => _openChatWithUser(_opp.postedBy!, _opp.poster?.name ?? 'Pemilik Proyek'),
                              icon: const Icon(Icons.chat_outlined, size: 16),
                              label: const Text('Diskusi via Chat', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Silakan tanggapi tawaran nego dana ini:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleRespondCounterOffer(app, 'accept'),
                            icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                            label: const Text('Terima Nego Dana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleCreatorCounterDialog(app),
                            icon: const Icon(Icons.handshake_rounded, size: 16, color: Color(0xFFD97706)),
                            label: const Text('Tawar Balik / Nego Ulang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFD97706))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleRespondCounterOffer(app, 'decline'),
                            icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                            label: const Text('Tolak Tawaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          if (_opp.postedBy != null)
                            TextButton.icon(
                              onPressed: () => _openChatWithUser(_opp.postedBy!, _opp.poster?.name ?? 'Pemilik Proyek'),
                              icon: const Icon(Icons.chat_outlined, size: 16),
                              label: const Text('Diskusi via Chat', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ],
                  ] else if (app.counterOfferStatus == 'accepted') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kesepakatan nego telah disetujui! Menunggu pemilik proyek meresmikan persetujuan.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (app.counterOfferStatus == 'declined') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tawaran nego ini belum disepakati.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleCreatorCounterDialog(app),
                            icon: const Icon(Icons.handshake_rounded, size: 14, color: Color(0xFFD97706)),
                            label: const Text('Tawar Ulang', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Approved & Digital Contract Validation Section
          if (isApproved) ...[
            const SizedBox(height: 14),
            Builder(builder: (ctx) {
              final isMyCreatorSigned = (app.creatorSignature != null && app.creatorSignature!.isNotEmpty) ||
                  (app.creatorSignedAt != null && app.creatorSignedAt!.isNotEmpty) ||
                  app.isCreatorSigned ||
                  _opp.approvedCreators.any((c) => c.id == widget.user?.id && c.isSigned);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isMyCreatorSigned
                      ? const Color(0xFF059669).withValues(alpha: isDark ? 0.12 : 0.08)
                      : const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isMyCreatorSigned ? const Color(0xFF059669) : const Color(0xFF3B82F6),
                    width: 1.3,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isMyCreatorSigned ? Icons.verified_user_rounded : Icons.draw_rounded,
                          color: isMyCreatorSigned ? const Color(0xFF059669) : const Color(0xFF2563EB),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isMyCreatorSigned
                                ? 'Kontrak Digital Telah Anda Tandatangani (Sah)'
                                : 'Pengesahan Kontrak Digital Diperlukan',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isMyCreatorSigned
                                  ? (isDark ? Colors.greenAccent : const Color(0xFF065F46))
                                  : (isDark ? Colors.lightBlueAccent : const Color(0xFF1E40AF)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isMyCreatorSigned
                          ? 'Perjanjian kerja telah Anda sepakati dan tandatangani secara sah. Acara akan dimulai setelah pihak penyelenggara menahan saldo ke Escrow Rekber Kreavana.'
                          : 'Sebagai syarat sebelum acara dapat dimulai secara resmi, Anda dan pihak penyelenggara wajib menyetujui ketentuan khusus dan menandatangani Dokumen Kontrak Digital 3 Pihak.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMyCreatorSigned ? const Color(0xFF059669) : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _showTripartiteContractModal,
                      icon: Icon(
                        isMyCreatorSigned ? Icons.description_outlined : Icons.edit_document,
                        size: 16,
                      ),
                      label: Text(
                        isMyCreatorSigned ? 'Lihat Dokumen Kontrak Sah' : 'Tinjau & Tandatangani Kontrak Digital',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 18),
            _buildWorkerWorkspaceSection(app, isDark, currencyFmt),
          ],

          // Rejection info
          if (isRejected && app.rejectionReason != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Text(
                'Alasan penolakan: ${app.rejectionReason}',
                style: TextStyle(fontSize: 12, color: Colors.red.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Ruang Kerja & Progres Pelamar (Creator Workspace) ──────────────────────
  Widget _buildWorkerWorkspaceSection(
    OpportunityApplicationModel app,
    bool isDark,
    NumberFormat currencyFmt,
  ) {
    // Cari catatan revisi jika ada
    String? revisionNote = app.revisionNotes;
    if (revisionNote == null || revisionNote.isEmpty) {
      for (final doc in app.submittedDeliverables.reversed) {
        if (doc['type'] == 'revision_request' && doc['notes'] != null && (doc['notes'] as String).isNotEmpty) {
          revisionNote = doc['notes'] as String;
          break;
        }
      }
    }

    final isRevision = app.isRevision || app.workerStatus == 'revision';
    final isCompleted = app.workerProgress >= 100 || app.workerStatus == 'completed';
    final isReview = app.workerStatus == 'review';
    final isInProgress = app.workerStatus == 'in_progress' || (app.workerProgress > 0 && !isCompleted && !isRevision && !isReview);

    Color statusColor = AppTheme.primaryPurple;
    String statusLabel = 'Sedang Berjalan';
    IconData statusIcon = Icons.trending_up_rounded;

    if (isCompleted) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Selesai 100%';
      statusIcon = Icons.check_circle_rounded;
    } else if (isRevision) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Perlu Revisi';
      statusIcon = Icons.rate_review_rounded;
    } else if (isReview) {
      statusColor = const Color(0xFF06B6D4);
      statusLabel = 'Siap Ditinjau Klien';
      statusIcon = Icons.search_rounded;
    } else if (!isInProgress && app.workerProgress == 0) {
      statusColor = Colors.grey;
      statusLabel = 'Terkonfirmasi';
      statusIcon = Icons.pending_actions_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1829) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRevision
              ? const Color(0xFFF59E0B).withValues(alpha: 0.8)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: isRevision ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Workspace Pelamar ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.engineering_rounded, size: 20, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ruang Kerja & Progres Pelamar',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Kelola progress kerja, kirimkan hasil kerja (deliverables), & pantau revisi',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Alert Revisi (Jika status revision) ──
          if (isRevision) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Text(
                        'Permintaan Revisi dari Klien / Pembuat Acara',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (revisionNote != null && revisionNote.isNotEmpty)
                        ? 'Catatan Klien: "$revisionNote"'
                        : 'Klien meminta penyesuaian pada pekerjaan Anda. Silakan hubungi via chat untuk konfirmasi detail atau unggah hasil revisi Anda di bawah.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _actionLoading ? null : () => _handleSubmitDeliverable(app),
                        icon: const Icon(Icons.upload_file_rounded, size: 15, color: Colors.white),
                        label: const Text('Unggah Hasil Revisi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (_opp.postedBy != null)
                        OutlinedButton.icon(
                          onPressed: () => _openChatWithUser(_opp.postedBy!, _opp.poster?.name ?? 'Pembuat Acara'),
                          icon: const Icon(Icons.chat_outlined, size: 15, color: Color(0xFFD97706)),
                          label: const Text('Diskusi Revisi via Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 1. Progress Pengerjaan Proyek ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13111E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.trending_up_rounded, size: 17, color: AppTheme.primaryPurple),
                        const SizedBox(width: 6),
                        Text(
                          'Progress Pengerjaan: ${app.workerProgress}%',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _actionLoading ? null : () => _handleUpdateWorkerProgress(app),
                      icon: const Icon(Icons.edit_note_rounded, size: 15),
                      label: const Text('Perbarui Progress', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: app.workerProgress / 100.0,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? const Color(0xFF10B981) : (isRevision ? const Color(0xFFF59E0B) : AppTheme.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isCompleted
                      ? 'Pekerjaan Anda telah selesai 100% dan siap untuk proses evaluasi/pelunasan.'
                      : (isRevision
                          ? 'Pekerjaan membutuhkan revisi sesuai permintaan klien. Silakan perbarui hasil kerja.'
                          : 'Perbarui persentase progress kerja Anda secara berkala agar pembuat acara dapat memantau perkembangan proyek.'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 2. Bukti & Hasil Kerja / Deliverables ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13111E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.folder_shared_rounded, size: 17, color: Color(0xFF06B6D4)),
                        SizedBox(width: 6),
                        Text(
                          'Hasil Kerja / Deliverables:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _actionLoading ? null : () => _handleSubmitDeliverable(app),
                      icon: const Icon(Icons.upload_file_rounded, size: 15),
                      label: const Text('Unggah Hasil Kerja', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Deliverables Items
                Builder(builder: (ctx) {
                  final allDeliverables = [...app.submittedDeliverables, ...app.submittedDocuments]
                      .where((d) => d['type'] != 'revision_request')
                      .toList();

                  if (allDeliverables.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 30, color: isDark ? AppTheme.textMuted : Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text(
                            'Belum ada hasil kerja yang diunggah.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Klik tombol "Unggah Hasil Kerja" di atas untuk melampirkan link Google Drive, Figma, video, atau dokumen pekerjaan Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: allDeliverables.map((doc) {
                      final type = (doc['type'] ?? 'link').toString().toLowerCase();
                      final title = doc['title'] ?? 'Hasil Kerja';
                      final url = doc['url'] ?? '';
                      final notes = doc['notes'] ?? '';
                      final createdAt = doc['created_at']?.toString() ?? '';

                      IconData iconData = Icons.link_rounded;
                      Color iconColor = const Color(0xFF06B6D4);
                      String typeLabel = 'Link URL';

                      if (type == 'image' || url.endsWith('.jpg') || url.endsWith('.png') || url.endsWith('.jpeg')) {
                        iconData = Icons.image_rounded;
                        iconColor = const Color(0xFF8B5CF6);
                        typeLabel = 'Foto / Gambar';
                      } else if (type == 'video' || url.endsWith('.mp4') || url.contains('youtube') || url.contains('drive.google')) {
                        iconData = Icons.videocam_rounded;
                        iconColor = const Color(0xFFEF4444);
                        typeLabel = 'Video';
                      } else if (type == 'document' || type == 'doc' || url.endsWith('.pdf') || url.endsWith('.docx')) {
                        iconData = Icons.description_rounded;
                        iconColor = const Color(0xFFF59E0B);
                        typeLabel = 'Dokumen';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(iconData, size: 16, color: iconColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: iconColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          typeLabel,
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: iconColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (url.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    InkWell(
                                      onTap: () async {
                                        final uri = Uri.tryParse(url);
                                        if (uri != null && await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        } else if (mounted) {
                                          AppSnackbar.info(context, 'Tautan: $url');
                                        }
                                      },
                                      child: Text(
                                        url,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2563EB),
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                  if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Catatan: $notes',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                  if (createdAt.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 3. Proteksi Escrow & Skema Pembayaran ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13111E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, size: 17, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          app.isTermPayment ? 'Skema: Pembayaran Per-Termin' : 'Skema: Sekaligus di Akhir',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: app.isFullyPaid
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (app.paidAmount > 0
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF3B82F6).withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        app.isFullyPaid
                            ? 'LUNAS'
                            : (app.paidAmount > 0 ? 'DIBAYAR SEBAGIAN' : 'TERPROTEKSI ESCROW'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: app.isFullyPaid
                              ? const Color(0xFF059669)
                              : (app.paidAmount > 0 ? const Color(0xFFD97706) : const Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Kesepakatan: ${currencyFmt.format(app.agreedFee)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Sudah Dicairkan: ${currencyFmt.format(app.paidAmount)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Dana Aman di Escrow:',
                            style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                          ),
                          Text(
                            currencyFmt.format(app.remainingUnpaidFee),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: app.remainingUnpaidFee > 0 ? const Color(0xFF2563EB) : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Termin Milestones List
                if (app.isTermPayment && app.paymentTerms.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text(
                    'Jadwal Termin Pembayaran:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(app.paymentTerms.length, (idx) {
                    final term = app.paymentTerms[idx];
                    final termName = term['name']?.toString() ?? 'Termin ${idx + 1}';
                    final termPct = term['percentage'] != null ? '${term['percentage']}%' : '';
                    final termAmt = double.tryParse(term['amount']?.toString() ?? '0') ??
                        (app.agreedFee * ((double.tryParse(term['percentage']?.toString() ?? '0') ?? 0) / 100.0));
                    final isPaid = term['is_paid'] == true || term['status'] == 'paid';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$termName ${termPct.isNotEmpty ? "($termPct)" : ""}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                ),
                                Text(
                                  currencyFmt.format(termAmt),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPaid ? 'SUDAH CAIR' : 'MENUNGGU SELESAI',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? const Color(0xFF059669) : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── 4. Aksi Bantuan & Koordinasi ──
          Row(
            children: [
              if (_opp.postedBy != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openChatWithUser(_opp.postedBy!, _opp.poster?.name ?? 'Pembuat Acara'),
                    icon: const Icon(Icons.chat_outlined, size: 15),
                    label: const Text('Chat Penyelenggara', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showTripartiteContractModal,
                  icon: const Icon(Icons.description_outlined, size: 15),
                  label: const Text('Kontrak Digital', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyApplicationLoadingCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Memuat status lamaran & tawaran negosiasi...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case 'approved':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF059669);
        text = 'Disetujui';
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red.shade700;
        text = 'Ditolak';
        icon = Icons.cancel_rounded;
        break;
      case 'under_consideration':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        text = 'Dipertimbangkan (Nego)';
        icon = Icons.handshake_rounded;
        break;
      case 'pending':
      default:
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = const Color(0xFF2563EB);
        text = 'Menunggu Review';
        icon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRespondCounterOffer(OpportunityApplicationModel app, String action) async {
    final isAccept = action == 'accept';
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final priceStr = app.counterOfferPrice != null ? currencyFmt.format(app.counterOfferPrice) : '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isAccept ? Icons.check_circle_rounded : Icons.cancel_outlined,
              color: isAccept ? const Color(0xFF10B981) : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isAccept ? 'Setujui Tawaran Nego?' : 'Tolak Tawaran Nego?'),
          ],
        ),
        content: Text(
          isAccept
              ? 'Anda akan menyetujui tawaran dana senilai $priceStr untuk proyek "${_opp.title}". Pemilik proyek akan segera diberitahu untuk meresmikan persetujuan.'
              : 'Apakah Anda yakin ingin menolak tawaran dana $priceStr dari pemilik proyek?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAccept ? const Color(0xFF10B981) : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isAccept ? 'Ya, Setujui' : 'Tolak Tawaran'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.respondCounterOffer(
        applicationId: app.id,
        action: action,
      );

      if (!mounted) return;
      setState(() => _actionLoading = false);

      if (res['status'] == true) {
        AppSnackbar.success(
          context,
          isAccept
              ? 'Tawaran nego dana berhasil disetujui! Menunggu konfirmasi pemilik proyek.'
              : 'Tawaran nego dana telah ditolak.',
        );
        _fetchApplications();
      } else {
        AppSnackbar.error(
          context,
          res['message'] ?? 'Gagal memproses tanggapan.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _actionLoading = false);
        AppSnackbar.error(context, 'Terjadi kesalahan: $e');
      }
    }
  }

  // ── Applications Manager Section (In-Place!) ───────────────────────────────
  Widget _buildApplicationsSection(
    List<OpportunityApplicationModel> apps,
    bool isDark,
  ) {
    final total = _applications.length;
    final pendingCount = _applications.where((a) => a.isPending).length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: AppTheme.primaryPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelola & Persetujuan Pelamar',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      pendingCount > 0
                          ? '$pendingCount proposal menunggu persetujuan Anda'
                          : 'Total $total pelamar telah mengajukan proposal',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$total Pelamar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Semua', total),
                const SizedBox(width: 8),
                _filterChip('Menunggu', _applications.where((a) => a.isPending).length, filterKey: 'pending'),
                const SizedBox(width: 8),
                _filterChip('Dipertimbangkan', _applications.where((a) => a.isConsideration).length, filterKey: 'under_consideration'),
                const SizedBox(width: 8),
                _filterChip('Disetujui', _applications.where((a) => a.isApproved).length, filterKey: 'approved'),
                const SizedBox(width: 8),
                _filterChip('Ditolak', _applications.where((a) => a.isRejected).length, filterKey: 'rejected'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Applications List
          if (_loadingApps)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (apps.isEmpty)
            _buildEmptyApplicationsState(isDark)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: apps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _buildApplicationCard(apps[index], isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int count, {String? filterKey}) {
    final key = filterKey ?? label;
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppTheme.primaryPurple : null,
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildEmptyApplicationsState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF9FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              size: 28,
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Pelamar Masuk',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'Kebutuhan proyek Anda sedang dipublikasikan di feed Kreavana. Begitu ada kreator yang mengajukan proposal, Anda dapat mereview dan memilihnya langsung di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(OpportunityApplicationModel app, bool isDark) {
    Color statusBg;
    Color statusColor;
    String statusText;

    if (app.isApproved) {
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      statusColor = const Color(0xFF059669);
      statusText = 'DISETUJUI';
    } else if (app.isRejected) {
      statusBg = Colors.red.withValues(alpha: 0.12);
      statusColor = Colors.red.shade700;
      statusText = 'DITOLAK';
    } else if (app.isConsideration) {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      statusColor = const Color(0xFFD97706);
      if (app.counterOfferStatus == 'accepted') {
        statusText = 'DIPERTIMBANGKAN (KREATOR SETUJU)';
      } else if (app.counterOfferStatus == 'declined') {
        statusText = 'DIPERTIMBANGKAN (KREATOR MENOLAK)';
      } else {
        statusText = 'DIPERTIMBANGKAN (MENUNGGU RESPON)';
      }
    } else {
      statusBg = const Color(0xFF6B7280).withValues(alpha: 0.12);
      statusColor = const Color(0xFF4B5563);
      statusText = 'MENUNGGU REVIEW';
    }

    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B192A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: app.isApproved
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : (app.isConsideration
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                  : (isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0))),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (app.creator?.id.isNotEmpty == true) {
                      UserProfileModal.show(
                        context,
                        userId: app.creator!.id,
                        initialName: app.creator!.name,
                        initialUsername: app.creator!.username,
                        initialAvatarUrl: app.creator!.avatarUrl,
                        initialRole: 'creator',
                        currentUser: widget.user,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                          backgroundImage: app.creator?.avatarUrl != null
                              ? CachedNetworkImageProvider(app.creator!.avatarUrl!)
                              : null,
                          child: app.creator?.avatarUrl == null
                              ? Text(
                                  (app.creator?.name.isNotEmpty == true)
                                      ? app.creator!.name[0].toUpperCase()
                                      : 'K',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      app.creator?.name ?? 'Kreator',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.open_in_new_rounded, size: 12, color: AppTheme.primaryPurple),
                                ],
                              ),
                              Row(
                                children: [
                                  if (app.creator?.username.isNotEmpty == true)
                                    Text(
                                      '@${app.creator!.username} • ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                      ),
                                    ),
                                  if (app.creator?.isUpgraded == true) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        (app.creator?.subscriptionTier ?? 'PRO').toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (app.creator?.isVerified == true) ...[
                                    const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF06B6D4)),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      app.subRoleSlug.replaceAll('_', ' '),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Proposal Pitch Message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13111E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proposal Pelamar:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app.pitchMessage.isNotEmpty ? app.pitchMessage : 'Tidak ada pesan pengantar.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                if (app.questionsNotes != null && app.questionsNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Catatan / Pertanyaan: ${app.questionsNotes}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Counter Offer Box (if available)
          if (app.counterOfferPrice != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.handshake_outlined, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        app.counterOfferBy == 'creator'
                            ? 'Tawaran Nego Pelamar: ${currencyFmt.format(app.counterOfferPrice)}'
                            : 'Tawaran Nego Klien: ${currencyFmt.format(app.counterOfferPrice)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const Spacer(),
                      _buildCounterOfferStatusBadge(app.counterOfferStatus, app.counterOfferBy),
                    ],
                  ),
                  if (app.counterOfferNotes != null && app.counterOfferNotes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      app.counterOfferBy == 'creator'
                          ? 'Pesan Pelamar: "${app.counterOfferNotes}"'
                          : 'Pesan Klien: "${app.counterOfferNotes}"',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_isOwner && app.isConsideration && app.counterOfferStatus == 'accepted') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pelamar telah menyetujui tawaran negosiasi dana. Anda tinggal menyetujui (Setuju / Deal) atau menolak lamaran ini.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Bid Price & Action Buttons Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (app.bidPrice != null && app.bidPrice! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.payments_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'Tawaran Awal: ${currencyFmt.format(app.bidPrice)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Portofolio button
                  if (app.creator?.id.isNotEmpty == true) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        UserProfileModal.show(
                          context,
                          userId: app.creator!.id,
                          initialName: app.creator!.name,
                          initialUsername: app.creator!.username,
                          initialAvatarUrl: app.creator!.avatarUrl,
                          initialRole: 'creator',
                          currentUser: widget.user,
                        );
                      },
                      icon: const Icon(Icons.person_search_rounded, size: 14),
                      label: const Text('Portofolio'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        foregroundColor: AppTheme.primaryPurple,
                        side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Chat button
                  if (app.creator?.id.isNotEmpty == true) ...[
                    OutlinedButton.icon(
                      onPressed: () => _openChatWithUser(app.creator!.id, app.creator?.name),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                      label: const Text('Chat'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Action buttons if pending
                  if (app.isPending && _isOwner) ...[
                    OutlinedButton(
                      onPressed: _actionLoading ? null : () => _handleReview(app, 'reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Tolak'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _actionLoading ? null : () => _handleConsiderDialog(app),
                      icon: const Icon(Icons.handshake_rounded, size: 14),
                      label: const Text('Pertimbangkan / Nego'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _actionLoading ? null : () => _handleReview(app, 'approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Setujui',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  // Action buttons if under_consideration
                  if (app.isConsideration) ...[
                    if (_isOwner) ...[
                      OutlinedButton(
                        onPressed: _actionLoading ? null : () => _handleReview(app, 'reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Tolak'),
                      ),
                      if (app.counterOfferStatus != 'accepted') ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _actionLoading ? null : () => _handleConsiderDialog(app),
                          icon: const Icon(Icons.edit_note_rounded, size: 14),
                          label: const Text('Ubah Nego'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _actionLoading ? null : () => _handleReview(app, 'approve'),
                        icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        label: Text(
                          (app.counterOfferStatus == 'accepted' || app.counterOfferBy == 'creator')
                              ? 'Setuju (Deal)'
                              : 'Setujui',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ] else if (_effectiveUser?.id == app.creatorId || _effectiveUser?.id == app.creator?.id || !_isOwner) ...[
                      if (app.counterOfferStatus == 'pending') ...[
                        if (app.counterOfferBy == 'creator') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.amber.shade800),
                                const SizedBox(width: 6),
                                Text(
                                  'Menunggu Klien',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleCreatorCounterDialog(app),
                            icon: const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFFD97706)),
                            label: const Text('Ubah Tawaran', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD97706)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleRespondCounterOffer(app, 'decline'),
                            icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                            label: const Text('Tolak Nego', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleCreatorCounterDialog(app),
                            icon: const Icon(Icons.handshake_rounded, size: 14, color: Color(0xFFD97706)),
                            label: const Text('Tawar Balik', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD97706)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _actionLoading ? null : () => _handleRespondCounterOffer(app, 'accept'),
                            icon: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                            label: const Text('Terima Nego', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ] else if (app.counterOfferStatus == 'accepted') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade400),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Nego Disetujui',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                              ),
                            ],
                          ),
                        ),
                      ] else if (app.counterOfferStatus == 'declined') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade400),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cancel_outlined, size: 14, color: Colors.red.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Nego Ditolak',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _actionLoading ? null : () => _handleCreatorCounterDialog(app),
                          icon: const Icon(Icons.handshake_rounded, size: 14, color: Color(0xFFD97706)),
                          label: const Text('Tawar Ulang', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ],
          ),

          // ── Approved Worker Workspace (Progress, Deliverables, Payment Terms, Auto-Release) ──
          if (app.isApproved) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13111E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Pekerja Terpilih
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Manajemen Kerja & Pembayaran Pelamar',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PELAMAR TERPILIH',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1. Progress Kerja Individual (Worker Progress)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.trending_up_rounded, size: 16, color: AppTheme.primaryPurple),
                                const SizedBox(width: 6),
                                Text(
                                  'Progress Kerja: ${app.workerProgress}%',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: app.workerProgress >= 100
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (app.workerProgress > 0
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                app.workerProgress >= 100
                                    ? 'Selesai 100%'
                                    : (app.workerProgress > 0 ? 'Sedang Dikerjakan' : 'Belum Berjalan'),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: app.workerProgress >= 100
                                      ? const Color(0xFF059669)
                                      : (app.workerProgress > 0 ? const Color(0xFF4F46E5) : Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: app.workerProgress / 100.0,
                            minHeight: 7,
                            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              app.workerProgress >= 100 ? const Color(0xFF10B981) : AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                        if (app.isRevision || app.workerStatus == 'revision') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.assignment_late_rounded, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Pekerja dalam tahap revisi.${app.revisionNotes != null && app.revisionNotes!.isNotEmpty ? " Catatan: \"${app.revisionNotes}\"" : ""}',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFFD97706), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: _actionLoading ? null : () => _handleUpdateWorkerProgress(app),
                              icon: const Icon(Icons.edit_note_rounded, size: 14),
                              label: const Text('Perbarui Progress', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _actionLoading ? null : () => _handleRequestRevision(app),
                              icon: const Icon(Icons.rate_review_rounded, size: 14),
                              label: const Text('Minta Revisi', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFD97706),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                            if (app.workerProgress < 100)
                              TextButton.icon(
                                onPressed: _actionLoading ? null : () => _handleApproveWorkerWork(app),
                                icon: const Icon(Icons.check_circle_rounded, size: 14),
                                label: const Text('Setujui Selesai', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF059669),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Deliverables / Bukti Hasil Kerja (Link, Gambar, Video, Dokumen)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.folder_shared_rounded, size: 16, color: Color(0xFF06B6D4)),
                            const SizedBox(width: 6),
                            const Text(
                              'Hasil Kerja / Deliverables:',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _actionLoading ? null : () => _handleSubmitDeliverable(app),
                              icon: const Icon(Icons.upload_file_rounded, size: 14),
                              label: const Text('Unggah Hasil Kerja', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF06B6D4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                        if (app.submittedDeliverables.isEmpty && app.submittedDocuments.isEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Belum ada hasil kerja (link/gambar/video/dokumen) yang diunggah oleh pekerja.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          ...[...app.submittedDeliverables, ...app.submittedDocuments].map((doc) {
                            final type = (doc['type'] ?? 'link').toString().toLowerCase();
                            final title = doc['title'] ?? 'Hasil Kerja';
                            final url = doc['url'] ?? '';
                            final notes = doc['notes'] ?? '';
                            final createdAt = doc['created_at']?.toString() ?? '';

                            IconData iconData = Icons.link_rounded;
                            Color iconColor = const Color(0xFF06B6D4);
                            String typeLabel = 'Link';

                            if (type == 'image' || url.endsWith('.jpg') || url.endsWith('.png') || url.endsWith('.jpeg')) {
                              iconData = Icons.image_rounded;
                              iconColor = const Color(0xFF8B5CF6);
                              typeLabel = 'Gambar';
                            } else if (type == 'video' || url.endsWith('.mp4') || url.contains('youtube') || url.contains('drive.google')) {
                              iconData = Icons.videocam_rounded;
                              iconColor = const Color(0xFFEF4444);
                              typeLabel = 'Video';
                            } else if (type == 'document' || type == 'doc' || url.endsWith('.pdf') || url.endsWith('.docx')) {
                              iconData = Icons.description_rounded;
                              iconColor = const Color(0xFFF59E0B);
                              typeLabel = 'Dokumen';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF13111E) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(iconData, size: 16, color: iconColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: iconColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                typeLabel,
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: iconColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (url.isNotEmpty)
                                          InkWell(
                                            onTap: () async {
                                              final uri = Uri.tryParse(url);
                                              if (uri != null && await canLaunchUrl(uri)) {
                                                await launchUrl(uri);
                                              } else if (mounted) {
                                                AppSnackbar.info(context, 'Tautan: $url');
                                              }
                                            },
                                            child: Text(
                                              url,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF2563EB),
                                                decoration: TextDecoration.underline,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (notes.isNotEmpty)
                                          Text(
                                            'Catatan: $notes',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                                            ),
                                          ),
                                        if (createdAt.isNotEmpty)
                                          Text(
                                            createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Skema Pembayaran & Tombol Bayar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.payments_rounded, size: 16, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Text(
                                  app.isTermPayment ? 'Skema: Pembayaran Per-Termin' : 'Skema: Sekaligus di Akhir',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: app.isFullyPaid
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (app.paidAmount > 0
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                app.isFullyPaid
                                    ? 'LUNAS'
                                    : (app.paidAmount > 0 ? 'DIBAYAR SEBAGIAN' : 'BELUM DIBAYAR'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: app.isFullyPaid
                                      ? const Color(0xFF059669)
                                      : (app.paidAmount > 0 ? const Color(0xFFD97706) : Colors.red.shade700),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Honor: ${currencyFmt.format(app.agreedFee)}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Sudah Terbayar: ${currencyFmt.format(app.paidAmount)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF059669)),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Sisa Tagihan:',
                                    style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                                  ),
                                  Text(
                                    currencyFmt.format(app.remainingUnpaidFee),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: app.remainingUnpaidFee > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Jika Skema Per-Termin: Tampilkan list termin & tombol bayar per termin
                        if (app.isTermPayment && app.paymentTerms.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          const Text(
                            'Jadwal Termin Pembayaran:',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          ...List.generate(app.paymentTerms.length, (idx) {
                            final term = app.paymentTerms[idx];
                            final termName = term['name']?.toString() ?? 'Termin ${idx + 1}';
                            final termPct = term['percentage'] != null ? '${term['percentage']}%' : '';
                            final termAmt = double.tryParse(term['amount']?.toString() ?? '0') ??
                                (app.agreedFee * ((double.tryParse(term['percentage']?.toString() ?? '0') ?? 0) / 100.0));
                            final isPaid = term['is_paid'] == true || term['status'] == 'paid';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF13111E) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$termName ${termPct.isNotEmpty ? "($termPct)" : ""}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                        ),
                                        Text(
                                          currencyFmt.format(termAmt),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF059669)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isPaid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Lunas',
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (_isOwner && (_opp.status == 'in_progress' || _opp.status == 'completed'))
                                    ElevatedButton.icon(
                                      onPressed: _actionLoading
                                          ? null
                                          : () => _handlePayWorkerTerm(
                                                app,
                                                milestoneIndex: idx,
                                                amount: termAmt,
                                                note: 'Pembayaran $termName',
                                              ),
                                      icon: const Icon(Icons.payment_rounded, size: 12, color: Colors.white),
                                      label: const Text('Bayar Termin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    )
                                  else
                                    Text(
                                      'Belum Dibayar',
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],

                        // Jika Skema Sekaligus di Akhir: Tombol Bayar Pelunasan
                        if (!app.isTermPayment && !app.isFullyPaid && _isOwner && (_opp.status == 'in_progress' || _opp.status == 'completed')) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _actionLoading
                                  ? null
                                  : () => _handlePayWorkerTerm(
                                        app,
                                        amount: app.remainingUnpaidFee,
                                        note: 'Pelunasan Sekaligus Honor Pekerja',
                                      ),
                              icon: const Icon(Icons.payments_rounded, size: 15, color: Colors.white),
                              label: Text(
                                'Bayar Pelunasan (${currencyFmt.format(app.remainingUnpaidFee)})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 4. Batas Waktu 1 Bulan & Auto-Release Alert
                  if (!app.isFullyPaid && (_opp.isGracePeriodActive || app.gracePeriodDeadline != null)) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 18, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Masa Tenggang Pembayaran 1 Bulan Aktif (Sisa: ${_opp.gracePeriodDaysLeft} Hari)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Acara telah selesai namun honor pekerja belum dilunasi. Pembuat acara diberikan waktu 1 bulan lagi. '
                            'Jika batas waktu terlewati dan belum dibayar, sistem akan otomatis mencairkan sisa saldo escrow ke pekerja sesuai kesepakatan nego.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.grey.shade800,
                              height: 1.35,
                            ),
                          ),
                          if (_opp.gracePeriodDaysLeft <= 0 || _isMarketingOrAdmin) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _actionLoading ? null : _handleAutoReleaseEscrow,
                                icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
                                label: const Text('Cairkan Otomatis (Auto-Release)', style: TextStyle(fontSize: 11, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Description Section ─────────────────────────────────────────────────────
  Widget _buildDescriptionSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deskripsi Kebutuhan & Ruang Lingkup',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _opp.description != null && _opp.description!.trim().isNotEmpty
                ? _opp.description!
                : 'Tidak ada rincian deskripsi tambahan yang dicantumkan.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Requirements Chips ──────────────────────────────────────────────────────
  bool _isSubRoleMatch(String slugA, String slugB) {
    final a = slugA.toLowerCase().replaceAll('-', '_').trim();
    final b = slugB.toLowerCase().replaceAll('-', '_').trim();
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;

    final isPhotoA = a.contains('foto') || a.contains('photo');
    final isPhotoB = b.contains('foto') || b.contains('photo');
    if (isPhotoA && isPhotoB) return true;

    final isVideoA = a.contains('video');
    final isVideoB = b.contains('video');
    if (isVideoA && isVideoB) return true;

    final isDesignA = a.contains('desain') || a.contains('design');
    final isDesignB = b.contains('desain') || b.contains('design');
    if (isDesignA && isDesignB) return true;

    final isEditA = a.contains('edit');
    final isEditB = b.contains('edit');
    if (isEditA && isEditB) return true;

    final isMca = a == 'mc' || a.contains('host');
    final isMcb = b == 'mc' || b.contains('host');
    if (isMca && isMcb) return true;

    return false;
  }

  IconData _getSubRoleIcon(String slug) {
    final s = slug.toLowerCase().replaceAll('-', '_');
    if (s.contains('foto') || s.contains('photo')) return Icons.camera_alt_outlined;
    if (s.contains('video') || s.contains('movie')) return Icons.videocam_outlined;
    if (s.contains('edit')) return Icons.content_cut_outlined;
    if (s.contains('desain') || s.contains('design')) return Icons.palette_outlined;
    if (s.contains('animat')) return Icons.animation_outlined;
    if (s.contains('drone')) return Icons.flight_takeoff_outlined;
    if (s.contains('mc') || s.contains('host')) return Icons.mic_none_outlined;
    if (s.contains('sing') || s.contains('musis') || s.contains('kendang') || s.contains('musik')) {
      return Icons.music_note_outlined;
    }
    if (s.contains('organizer') || s.contains('event')) return Icons.event_available_outlined;
    if (s.contains('model') || s.contains('talent')) return Icons.face_retouching_natural_outlined;
    return Icons.badge_outlined;
  }

  int _getApprovedCountForRequirement(OpportunityRequirementModel r) {
    final approvedInApps = _applications.where((a) =>
      a.isApproved && _isSubRoleMatch(a.subRoleSlug, r.subRoleSlug)
    ).length;

    final approvedInOpp = _opp.approvedCreators.where((c) {
      final cap = c.capability ?? c.subRole ?? '';
      return _isSubRoleMatch(cap, r.subRoleSlug);
    }).length;

    return approvedInApps > approvedInOpp ? approvedInApps : approvedInOpp;
  }

  int _getApplicantCountForRequirement(OpportunityRequirementModel r) {
    return _applications.where((a) =>
      _isSubRoleMatch(a.subRoleSlug, r.subRoleSlug)
    ).length;
  }

  Widget _buildRequirementsSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Peran & Spesialisasi yang Dibutuhkan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_opp.requirements.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_opp.requirements.length} Posisi',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_opp.requirements.isNotEmpty)
            Column(
              children: _opp.requirements.map((r) {
                final approvedCount = _getApprovedCountForRequirement(r);
                final applicantCount = _getApplicantCountForRequirement(r);
                final isFulfilled = r.quantity > 0 && approvedCount >= r.quantity;

                final roleIcon = isFulfilled
                    ? Icons.check_circle_rounded
                    : _getSubRoleIcon(r.subRoleSlug);
                final iconColor = isFulfilled ? Colors.green.shade600 : AppTheme.primaryPurple;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (isFulfilled ? const Color(0xFF14241C) : const Color(0xFF1B192A))
                        : (isFulfilled ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFulfilled
                          ? (isDark ? Colors.green.shade900 : const Color(0xFFBBF7D0))
                          : (isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isFulfilled
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : AppTheme.primaryPurple.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(roleIcon, size: 18, color: iconColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isFulfilled && !isDark ? Colors.green.shade900 : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isFulfilled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 13, color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Terpenuhi ($approvedCount/${r.quantity})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_isOwner && applicantCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_alt_outlined, size: 13, color: AppTheme.primaryPurple),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$applicantCount Pelamar',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryPurple,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_search_outlined,
                                    size: 13,
                                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Mencari ${r.quantity - approvedCount} orang',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (r.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: r.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFulfilled
                                    ? Colors.green.withValues(alpha: 0.08)
                                    : AppTheme.primaryPurple.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isFulfilled ? Colors.green.shade700 : AppTheme.primaryPurple,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            )
          else
            Chip(
              avatar: Icon(
                _getSubRoleIcon(_opp.subRoleSlug),
                size: 16,
                color: AppTheme.primaryPurple,
              ),
              label: Text(_opp.subRoleLabel),
              backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.08),
            ),
        ],
      ),
    );
  }

  // ── Sidebar: Project Info Card ──────────────────────────────────────────────
  Widget _buildProjectInfoCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Proyek',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _infoItem(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'Jadwal & Batas Waktu',
            value: _opp.eventDate != null
                ? '${_opp.eventDate} ${_opp.eventStartTime != null ? "(${_opp.eventStartTime} - ${_opp.eventEndTime ?? ''})" : ""}'
                : (_opp.deadline ?? 'Fleksibel'),
            isDark: isDark,
          ),
          const Divider(height: 20),
          _infoItem(
            icon: Icons.place_rounded,
            iconColor: const Color(0xFF06B6D4),
            label: 'Lokasi Event / Eksekusi',
            value: _opp.address ?? _opp.location ?? 'Indonesia (Online / Fleksibel)',
            isDark: isDark,
          ),
          const Divider(height: 20),
          _infoItem(
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF10B981),
            label: 'Perkiraan Budget',
            value: _opp.budgetRange ?? 'Sesuai Kesepakatan',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sidebar: Owner Card ─────────────────────────────────────────────────────
  Widget _buildOwnerCard(bool isDark) {
    final poster = _opp.poster;
    final name = poster?.name.isNotEmpty == true ? poster!.name : (widget.user?.name ?? 'Pembuat Proyek');
    final username = poster?.username.isNotEmpty == true ? poster!.username : (widget.user?.username ?? 'client');
    final userId = poster?.id ?? _opp.postedBy ?? widget.user?.id ?? '';
    final role = poster?.role ?? (widget.user?.id == userId ? widget.user?.role ?? 'user' : 'user');
    final isVerified = poster?.isVerified == true ||
        (widget.user?.id == userId && widget.user?.isVerified == true);
    final avatarUrl = poster?.avatarUrl ?? (widget.user?.id == userId ? widget.user?.avatarUrl : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (userId.isNotEmpty) {
            UserProfileModal.show(
              context,
              userId: userId,
              initialName: name,
              initialUsername: username,
              initialAvatarUrl: avatarUrl,
              initialRole: role,
              currentUser: widget.user,
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161426) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    role == 'creator' ? 'Pemilik Proyek (Kreator)' : 'Pemilik Proyek (Klien)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Profil',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: AppTheme.primaryPurple,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: (role == 'creator'
                                ? const Color(0xFF10B981)
                                : const Color(0xFF2563EB))
                            .withValues(alpha: 0.15),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'K',
                                style: TextStyle(
                                  color: role == 'creator'
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                      if (isVerified)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: VerificationBadge(
                            role: role,
                            isVerified: isVerified,
                            size: VerificationBadgeSize.small,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            VerificationBadge(
                              role: role,
                              isVerified: isVerified,
                              size: VerificationBadgeSize.small,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '@$username',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: (role == 'creator'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF2563EB))
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role == 'creator' ? 'Kreator' : 'Klien',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: role == 'creator'
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // ── Sidebar: Approved Creators ──────────────────────────────────────────────
  Widget _buildApprovedCreatorsCard(bool isDark) {
    final hasUnsignedMyCreator = _opp.approvedCreators.any((c) => c.id == widget.user?.id && !c.isSigned);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text(
                'Kreator Terpilih & Diterima',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._opp.approvedCreators.map((c) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: c.avatarUrl != null ? CachedNetworkImageProvider(c.avatarUrl!) : null,
                    child: c.avatarUrl == null
                        ? Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : 'K',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    c.subRole ?? 'Kreator',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade700),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.isSigned
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.isSigned ? '✓ TTD Sah' : 'Menunggu TTD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: c.isSigned ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (hasUnsignedMyCreator) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: _showTripartiteContractModal,
                icon: const Icon(Icons.draw_rounded, size: 16),
                label: const Text(
                  'Tandatangani Kontrak Digital Anda',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── AI Recommendations Section ─────────────────────────────────────────────
  Widget _buildAiRecommendationsSection(bool isDark) {
    final subRoles = <String>{'Semua'};
    for (final req in _opp.requirements) {
      if (req.subRoleSlug.isNotEmpty) subRoles.add(req.subRoleSlug);
    }
    for (final app in _applications) {
      if (app.subRoleSlug.isNotEmpty) subRoles.add(app.subRoleSlug);
    }

    final candidateApps = _applications.where((a) {
      if (a.isRejected) return false;
      if (_aiFilterSubRole == 'Semua') return true;
      return a.subRoleSlug.toLowerCase() == _aiFilterSubRole.toLowerCase();
    }).toList();

    candidateApps.sort((a, b) => _computeAiScore(b).compareTo(_computeAiScore(a)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Rekomendasi AI Pelamar',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AI MATCHMAKER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8B5CF6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Peringkat kecocokan berdasarkan ulasan/rating, reputasi portfolio, & status langganan kreator.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SubRole Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subRoles.map((role) {
                final isSelected = _aiFilterSubRole == role;
                final label = role == 'Semua' ? 'Semua Kategori' : role.replaceAll('_', ' ').toUpperCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _aiFilterSubRole = role;
                      });
                    },
                    selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    backgroundColor: isDark ? const Color(0xFF1E1B33) : const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF8B5CF6) : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          if (!_isSubscriber) ...[
            // Upsell card for non-subscribers
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    const Color(0xFFEC4899).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_person_rounded, size: 36, color: Color(0xFF8B5CF6)),
                  const SizedBox(height: 10),
                  const Text(
                    'Buka Rekomendasi Pelamar by AI',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upgrade akun Anda ke Plus, Pro, atau Super untuk membuka sistem kecocokan AI otomatis yang menyaring dan merekomendasikan pelamar terbaik berdasarkan rating, portofolio, dan rekam jejak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => UpgradePlanModal.show(context, user: widget.user),
                    icon: const Icon(Icons.star_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Upgrade ke Plus / Pro / Super',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (candidateApps.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF9FAFD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Belum ada pelamar untuk kategori "$_aiFilterSubRole" saat ini.',
                  style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                ),
              ),
            ),
          ] else ...[
            // Ranked Applicants List
            Column(
              children: candidateApps.take(3).map((app) {
                final score = _computeAiScore(app);
                final creator = app.creator;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B192A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: score >= 85
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                          : (isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: creator?.avatarUrl != null
                                ? CachedNetworkImageProvider(creator!.avatarUrl!)
                                : null,
                            child: creator?.avatarUrl == null
                                ? Text(
                                    creator?.name.isNotEmpty == true ? creator!.name[0].toUpperCase() : 'K',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        creator?.name ?? 'Kreator',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (creator?.isUpgraded == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          (creator?.subscriptionTier ?? 'PRO').toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),
                                    if (creator?.isVerified == true) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF06B6D4)),
                                    ],
                                  ],
                                ),
                                Text(
                                  app.subRoleSlug.replaceAll('_', ' '),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '$score% Cocok',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // AI Highlights
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _aiHighlightChip(
                            icon: Icons.star_rounded,
                            label: 'Rating ${creator?.rating ?? 4.8} / 5.0',
                            color: Colors.amber,
                          ),
                          if (creator?.isUpgraded == true)
                            _aiHighlightChip(
                              icon: Icons.workspace_premium_rounded,
                              label: 'Member Prioritas Kreavana',
                              color: const Color(0xFF8B5CF6),
                            ),
                          if (creator?.isVerified == true)
                            _aiHighlightChip(
                              icon: Icons.shield_rounded,
                              label: 'Terverifikasi KTP & Portofolio',
                              color: const Color(0xFF10B981),
                            ),
                          if (app.bidPrice != null && app.bidPrice! > 0)
                            _aiHighlightChip(
                              icon: Icons.payments_outlined,
                              label: 'Tawaran: Rp ${app.bidPrice!.toStringAsFixed(0)}',
                              color: const Color(0xFF059669),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (creator?.id.isNotEmpty == true) ...[
                            TextButton.icon(
                              onPressed: () {
                                UserProfileModal.show(
                                  context,
                                  userId: creator!.id,
                                  initialName: creator.name,
                                  initialUsername: creator.username,
                                  initialAvatarUrl: creator.avatarUrl,
                                  initialRole: 'creator',
                                  currentUser: widget.user,
                                );
                              },
                              icon: const Icon(Icons.person_search_rounded, size: 14),
                              label: const Text('Portofolio'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryPurple,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (app.isPending)
                            ElevatedButton(
                              onPressed: _actionLoading ? null : () => _handleReview(app, 'approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'Setujui',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aiHighlightChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Event Progress Milestone Tracker ───────────────────────────────────────
  Widget _buildEventProgressCard(bool isDark) {
    final progress = _opp.eventProgress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161426) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFF059669),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress & Pelaksanaan Acara',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _opp.isOngoing
                          ? 'Acara sedang berlangsung • Pendaftaran kreator baru telah ditutup.'
                          : 'Proyek dalam status: ${_opp.status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$progress% Selesai',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Milestone Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progress / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: isDark ? const Color(0xFF252238) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),
          const SizedBox(height: 12),

          // Milestones Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _milestoneStep('Persiapan (30%)', progress >= 30, isDark),
              _milestoneStep('Pelaksanaan (70%)', progress >= 70, isDark),
              _milestoneStep('Selesai (100%)', progress >= 100, isDark),
            ],
          ),

          if (_isOwner) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Perbarui Tahapan Progress:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 6,
                  children: [
                    _progressUpdateBtn(30, '30% Briefing'),
                    _progressUpdateBtn(70, '70% Event'),
                    _progressUpdateBtn(100, '100% Selesai'),
                  ],
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),

          // Participating Creators (Deduplicated 1 Orang = 1 Kontrak Individu)
          Builder(
            builder: (context) {
              final participatingEntries = _getIndividualContractEntries();
              final currencyFmt = NumberFormat.currency(
                locale: 'id_ID',
                symbol: 'Rp ',
                decimalDigits: 0,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded, size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kreator yang Berpartisipasi (${participatingEntries.length} Orang • ${participatingEntries.length} Kontrak Individu)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (participatingEntries.isEmpty)
                    Text(
                      'Belum ada nama kreator yang disetujui.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: participatingEntries.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final feeStr = item.agreedPrice > 0
                            ? ' • ${currencyFmt.format(item.agreedPrice)}'
                            : '';
                        return ActionChip(
                          onPressed: () => _showTripartiteContractModal(
                            initialIndex: idx,
                            initialApplicationId: item.applicationId,
                            initialCreatorId: item.creatorId,
                          ),
                          avatar: CircleAvatar(
                            backgroundColor: const Color(0xFF059669).withValues(alpha: 0.2),
                            child: Text(
                              item.creatorName.isNotEmpty
                                  ? item.creatorName[0].toUpperCase()
                                  : 'K',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                          label: Text(
                            '${item.creatorName} (${item.subRoleLabel}$feeStr)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                          side: const BorderSide(color: Color(0xFF10B981), width: 0.6),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _milestoneStep(String label, bool reached, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          reached ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: reached ? const Color(0xFF059669) : (isDark ? Colors.white30 : Colors.grey.shade400),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: reached ? FontWeight.bold : FontWeight.normal,
            color: reached
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? AppTheme.textMuted : Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _progressUpdateBtn(int target, String label) {
    return OutlinedButton(
      onPressed: _actionLoading ? null : () => _handleUpdateProgress(target),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: const BorderSide(color: Color(0xFF059669)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
      ),
    );
  }

  // ── High-Value MoU & Escrow Protocol Card ──────────────────────────────────
  Widget _buildHighValueMoUCard(bool isDark) {
    final isLarge = _opp.isLargeTransaction;
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    if (!isLarge) {
      // Standard Escrow & Dynamic Signature Card (< 100 Jt) — 1 Orang 1 Kontrak Individu (3 Pihak)
      final contractEntries = _getIndividualContractEntries();
      final totalContracts = contractEntries.length;
      final totalRequiredPositions = _opp.requirements.isNotEmpty
          ? _opp.requirements.fold<int>(0, (sum, r) => sum + (r.quantity > 0 ? r.quantity : 1))
          : (totalContracts > 0 ? totalContracts : 1);
      final finalContractsCount =
          contractEntries.where((e) => e.isContractFinal).length;
      final clientSignedCount =
          contractEntries.where((e) => e.isClientSigned).length;
      final creatorSignedCount =
          contractEntries.where((e) => e.isCreatorSigned).length;
      final totalIndividualContractValue = contractEntries.fold<double>(
        0.0,
        (sum, e) => sum + e.agreedPrice,
      );
      final displayEscrowTotal = (_opp.escrowAmount ?? 0) > 0
          ? _opp.escrowAmount!
          : (totalIndividualContractValue > 0
              ? totalIndividualContractValue
              : _parseBudgetFallback());

      final isClientSigned = totalContracts > 0
          ? (clientSignedCount == totalContracts)
          : (_opp.clientSignedAt != null && _opp.clientSignedAt!.isNotEmpty);
      final areAllCreatorsSigned =
          totalContracts > 0 && creatorSignedCount == totalContracts;
      final isFullySigned = totalContracts > 0
          ? (finalContractsCount == totalContracts)
          : (isClientSigned && areAllCreatorsSigned);
      final isEscrowHeld = _opp.escrowStatus == 'held' ||
          _opp.escrowStatus == 'held_in_escrow' ||
          _opp.status == 'in_progress';

      String badgeText;
      Color badgeBg;
      Color badgeTextColor;
      if (isFullySigned && totalContracts > 0) {
        badgeText = 'KONTRAK FIX ($finalContractsCount/$totalContracts FINAL)';
        badgeBg = const Color(0xFF059669).withValues(alpha: 0.15);
        badgeTextColor = const Color(0xFF059669);
      } else if (clientSignedCount > 0 || isClientSigned) {
        badgeText = 'MENUNGGU TTD PEKERJA ($creatorSignedCount/$totalContracts)';
        badgeBg = const Color(0xFFD97706).withValues(alpha: 0.15);
        badgeTextColor = const Color(0xFFD97706);
      } else {
        badgeText = totalContracts > 0
            ? 'MENUNGGU TTD ($finalContractsCount/$totalContracts FIX)'
            : 'MENUNGGU TTD KONTRAK';
        badgeBg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
        badgeTextColor = const Color(0xFF2563EB);
      }

      final safeContractPage = AppPaginationBar.safePage(
        _contractListPage,
        totalContracts,
        pageSize: _contractListPageSize,
      );
      final pagedEntries = AppPaginationBar.slicePage(
        contractEntries,
        safeContractPage,
        pageSize: _contractListPageSize,
      );

      final String bottomButtonLabel;
      if (totalContracts == 1) {
        final first = contractEntries.first;
        final feeLabel = first.agreedPrice > 0
            ? currencyFmt.format(first.agreedPrice)
            : (displayEscrowTotal > 0 ? currencyFmt.format(displayEscrowTotal) : 'Sesuai Kesepakatan');
        bottomButtonLabel =
            'Lihat Dokumen Kontrak: ${first.creatorName} (${first.subRoleLabel}) — $feeLabel';
      } else if (totalContracts > 1) {
        final previewNames = contractEntries
            .take(2)
            .map((e) => '${e.creatorName} (${currencyFmt.format(e.agreedPrice)})')
            .join(', ');
        final suffix = totalContracts > 2 ? ', +${totalContracts - 2} lainnya' : '';
        bottomButtonLabel =
            'Kelola & Lihat $totalContracts Dokumen Kontrak Individu: $previewNames$suffix • Total ${currencyFmt.format(displayEscrowTotal)}';
      } else {
        bottomButtonLabel =
            'Pratinjau Draf Kontrak Digital Resmi A4 (Target Kebutuhan: $totalRequiredPositions Orang — 1 Orang 1 Kontrak)';
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161426) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF06B6D4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Escrow & Kontrak Elektronik Dynamic (< Rp 100 Jt)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: badgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sistem 1 Orang = 1 Kontrak Digital Resmi A4 (Kop CV Transforma Alam Kreasi — Aplikasi Kreavana). Jika proyek membutuhkan $totalRequiredPositions pekerja, maka diterbitkan $totalRequiredPositions dokumen kontrak terpisah dengan nominal & klausul khusus sesuai posisi masing-masing.',
                        style: TextStyle(
                          fontSize: 12.2,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // PANDUAN KONSEP PERSETUJUAN KEDUA BELAH PIHAK (PEMBUAT ACARA & PELAMAR)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1B2E)
                    : const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 15,
                        color: Color(0xFF0284C7),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alur Persetujuan Kontrak Digital 2 Arah (Pembuat Acara ↔ Pelamar Individu):',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. Pilih & ACC Pelamar (1 Orang 1 Kontrak sesuai bidang & nominal)  →  '
                    '2. Susun Klausul Khusus per Posisi (Bisa diedit Klien/Pelamar; jika klausul diubah, tanda tangan di-reset agar disepakati ulang)  →  '
                    '3. Tanda Tangan Pihak Pertama (Pembuat Acara) & Pihak Kedua (Pelamar)  →  '
                    '4. Kontrak Fix & Final (Terkunci permanen, siap diunduh A4, & acara dapat dimulai).',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isEscrowHeld
                          ? Icons.lock_clock_rounded
                          : (isFullySigned
                              ? Icons.check_circle_rounded
                              : Icons.pending_actions_rounded),
                      size: 16,
                      color: isFullySigned || isEscrowHeld
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEscrowHeld
                          ? 'Total Escrow Ditahan: ${currencyFmt.format(displayEscrowTotal)} ($totalContracts Kontrak Individu)'
                          : (isFullySigned
                              ? 'Seluruh $totalContracts Kontrak Fix & Final (${currencyFmt.format(displayEscrowTotal)})'
                              : 'Kebutuhan: $totalRequiredPositions Posisi  •  Kontrak Aktif: $totalContracts Dokumen (${currencyFmt.format(displayEscrowTotal)})'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isFullySigned || isEscrowHeld
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                Text(
                  totalContracts > 0
                      ? 'TTD Klien: $clientSignedCount/$totalContracts  |  TTD Pekerja: $creatorSignedCount/$totalContracts  |  Kontrak Fix: $finalContractsCount/$totalContracts'
                      : 'Klien: ${isClientSigned ? "✓" : "⏳"}  |  Pekerja: ${areAllCreatorsSigned ? "✓" : "⏳"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                  ),
                ),
              ],
            ),

            // DAFTAR KONTRAK INDIVIDU (1 ORANG = 1 KONTRAK, TERPAGINASI, DENGAN NAMA, POSISI, NOMINAL, & KLAUSUL KHUSUS)
            if (contractEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...pagedEntries.asMap().entries.map((mapEntry) {
                final globalIdx =
                    (safeContractPage - 1) * _contractListPageSize + mapEntry.key;
                final item = mapEntry.value;
                final isFinal = item.isContractFinal;
                final itemFee = item.agreedPrice > 0
                    ? item.agreedPrice
                    : (totalContracts > 0
                        ? (displayEscrowTotal / totalContracts)
                        : displayEscrowTotal);
                final statusLabel = isFinal
                    ? 'KONTRAK FIX (FINAL)'
                    : (item.isClientSigned && !item.isCreatorSigned
                        ? 'MENUNGGU TTD PEKERJA'
                        : (!item.isClientSigned && item.isCreatorSigned
                            ? 'MENUNGGU TTD KLIEN'
                            : 'BELUM DITANDATANGANI'));
                final statusColor = isFinal
                    ? const Color(0xFF059669)
                    : (item.isClientSigned || item.isCreatorSigned
                        ? const Color(0xFFD97706)
                        : const Color(0xFF2563EB));
                final clausePreview = item.dynamicTerms.length > 1
                    ? item.dynamicTerms[1]
                    : (item.dynamicTerms.isNotEmpty ? item.dynamicTerms.first : '');

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1B2E)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${globalIdx + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Kontrak ${item.creatorName} (${item.subRoleLabel})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.8,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          currencyFmt.format(itemFee),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'No: ${item.contractNumber} • ${item.paymentSchemeLabel}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? AppTheme.textMuted
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  side: BorderSide(
                                    color: statusColor.withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _showTripartiteContractModal(
                                  initialIndex: globalIdx,
                                  initialApplicationId: item.applicationId,
                                  initialCreatorId: item.creatorId,
                                ),
                                icon: Icon(
                                  isFinal
                                      ? Icons.visibility_outlined
                                      : Icons.draw_rounded,
                                  size: 14,
                                  color: statusColor,
                                ),
                                label: Text(
                                  isFinal
                                      ? 'Kontrak Fix: ${item.creatorName} (${currencyFmt.format(itemFee)})'
                                      : 'Buka & TTD: ${item.creatorName} (${currencyFmt.format(itemFee)})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip:
                                    'Unduh PDF Kontrak Resmi A4 — ${item.creatorName} (${currencyFmt.format(itemFee)})',
                                onPressed: () => _downloadOfficialContractA4(item),
                                icon: const Icon(
                                  Icons.download_rounded,
                                  size: 18,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (clausePreview.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF13111E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'Klausul Dinamis (${item.subRoleLabel} • ${item.dynamicTerms.length} Butir): $clausePreview',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white70 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (totalContracts > _contractListPageSize)
                AppPaginationBar(
                  currentPage: safeContractPage,
                  totalItems: totalContracts,
                  pageSize: _contractListPageSize,
                  itemLabel: 'kontrak individu',
                  onPageChanged: (newPage) {
                    setState(() => _contractListPage = newPage);
                  },
                ),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF06B6D4).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showTripartiteContractModal(),
                icon: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF06B6D4)),
                label: Text(
                  bottomButtonLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // High Value MoU Card (>= 100 Jt)
    final hasMeeting = _opp.meetingDate != null && _opp.meetingDate!.isNotEmpty;
    final isMoUConfirmed = _opp.escrowStatus == 'completed' ||
        _opp.wetSignatureVerifiedAt != null ||
        _opp.meetingStatus == 'verified_paid' ||
        _opp.isMeetingVerified ||
        _opp.adminStartedAt != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1A2A) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Protokol Skala Besar (>= Rp 100.000.000)',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Wajib Tanda Tangan Basah & Perjanjian Kerjasama Legal (MoU Fisik 3 Pihak)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isMoUConfirmed
                      ? const Color(0xFF059669)
                      : (_opp.isMeetingInProcess
                          ? const Color(0xFF2563EB)
                          : (_opp.isMeetingCounterByAdmin
                              ? const Color(0xFF6366F1)
                              : (_opp.isMeetingPending ? const Color(0xFFD97706) : Colors.red.shade700))),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isMoUConfirmed
                      ? 'TTD BASAH SAH'
                      : (_opp.isMeetingInProcess
                          ? 'STATUS: DIPROSES'
                          : (_opp.isMeetingCounterByAdmin
                              ? 'NEGO JADWAL ADMIN'
                              : (_opp.isMeetingPending ? 'STATUS: PENDING' : 'PERLU JADWAL'))),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171322) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Untuk transaksi bernilai Rp 100 Juta ke atas, diwajibkan pertemuan fisik tanda tangan basah dokumen MoU 3 pihak (Admin Kreavana, Pembuat Acara, dan Seluruh Penerima Job). Setelah jadwal diajukan (status: Pending), admin akan meninjau (status: Diproses), dan acara hanya dapat dimulai secara resmi oleh Admin Kreavana setelah MoU fisik diverifikasi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Meeting Details or Schedule Button
          if (hasMeeting) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13111E) : const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jadwal Temu Tanda Tangan Basah Dokumen Fisik:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isMoUConfirmed
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : (_opp.isMeetingInProcess
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                  : (_opp.isMeetingCounterByAdmin
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                      : const Color(0xFFD97706).withValues(alpha: 0.15))),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isMoUConfirmed
                              ? 'MoU Fisik Terverifikasi'
                              : (_opp.isMeetingInProcess
                                  ? 'Diproses (Disetujui Admin)'
                                  : (_opp.isMeetingCounterByAdmin
                                      ? 'Nego Jadwal Admin'
                                      : 'Menunggu Persetujuan Admin (Pending)')),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isMoUConfirmed
                                ? const Color(0xFF059669)
                                : (_opp.isMeetingInProcess
                                    ? const Color(0xFF2563EB)
                                    : (_opp.isMeetingCounterByAdmin ? const Color(0xFF4F46E5) : const Color(0xFFD97706))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'Tanggal: ${_opp.meetingDate}  •  Waktu: ${_opp.meetingTime ?? "14:00 WIB"}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, size: 15, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Lokasi: ${_opp.meetingLocation ?? "Kantor Kreavana (Pick by Map)"}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (_opp.meetingNotes != null && _opp.meetingNotes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Catatan: ${_opp.meetingNotes}',
                      style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
                    ),
                  ],

                  // Status Meeting Explanations and Admin Actions
                  if (_opp.isMeetingCounterByAdmin) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.handshake_rounded, size: 16, color: Color(0xFF6366F1)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Admin Mengajukan Nego Jadwal & Lokasi Temu',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('NEGO ADMIN', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Admin Kreavana telah meninjau pengajuan jadwal Anda dan mengusulkan alternatif waktu/lokasi pertemuan:',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade800),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF13111E) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tanggal Usulan: ${_opp.meetingCounterDate ?? "-"}  •  Waktu: ${_opp.meetingCounterTime ?? "-"}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.place_rounded, size: 14, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Lokasi Usulan: ${_opp.meetingCounterLocation ?? "-"}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_opp.meetingCounterNotes != null && _opp.meetingCounterNotes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Alasan / Catatan Admin: ${_opp.meetingCounterNotes}',
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_isOwner) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _actionLoading ? null : () => _handleRespondMeetingCounter('counter'),
                                  icon: const Icon(Icons.edit_calendar_rounded, size: 13, color: Color(0xFFD97706)),
                                  label: const Text('Tawar Balik', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFD97706)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _actionLoading ? null : () => _handleRespondMeetingCounter('accept'),
                                  icon: const Icon(Icons.check_circle_rounded, size: 13, color: Colors.white),
                                  label: const Text('Terima Jadwal Admin', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (_isMarketingOrAdmin) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Menunggu respon persetujuan / tawar balik dari pembuat acara.',
                                  style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                                ),
                                TextButton.icon(
                                  onPressed: _actionLoading ? null : _handleAdminCounterMeeting,
                                  icon: const Icon(Icons.edit_calendar_rounded, size: 12),
                                  label: const Text('Ubah Usulan', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (_opp.isMeetingPending) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFD97706)),
                              SizedBox(width: 6),
                              Text(
                                'Status: Pending (Menunggu Persetujuan Admin)',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jadwal pertemuan fisik telah diajukan oleh pembuat acara. Admin Kreavana dapat menyetujui langsung atau mengajukan nego waktu & lokasi jika jadwal padat atau lokasi kejauhan.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade800),
                          ),
                          if (_isMarketingOrAdmin) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _actionLoading ? null : _handleAdminCounterMeeting,
                                  icon: const Icon(Icons.handshake_rounded, size: 13, color: Color(0xFF6366F1)),
                                  label: const Text('Nego Waktu / Lokasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF6366F1)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _actionLoading ? null : () => _handleAdminReviewMeeting(approveDirectly: true),
                                  icon: const Icon(Icons.check_circle_rounded, size: 13, color: Colors.white),
                                  label: const Text('Setujui Jadwal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (_opp.isMeetingInProcess) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.assignment_turned_in_rounded, size: 14, color: Color(0xFF2563EB)),
                              SizedBox(width: 6),
                              Text(
                                'Status: Diproses (Jadwal Disetujui Admin)',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Admin Kreavana telah menyetujui jadwal pertemuan. Ketiga pihak (Admin, Pembuat Acara, dan Penerima Job) akan bertemu untuk tanda tangan basah berkas fisik MoU. Setelah selesai, acara resmi akan dimulai oleh Admin Kreavana.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade800),
                          ),
                          if (_isMarketingOrAdmin) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _actionLoading ? null : _handleAdminStartEventAfterWetSignature,
                              icon: const Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                              label: const Text('Verifikasi TTD Basah & Mulai Acara', style: TextStyle(fontSize: 11, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Jadwal pertemuan fisik tanda tangan basah 3 pihak belum diatur.',
                    style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
                  ),
                ),
                if (_isOwner)
                  ElevatedButton.icon(
                    onPressed: _actionLoading ? null : _handleScheduleMeeting,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 15, color: Colors.white),
                    label: const Text('Atur Jadwal Temu Fisik (Map)', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
          ],

          // Marketing Confirmation Section
          if (_isMarketingOrAdmin) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFFD97706)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Otorisasi Tim Marketing / Legal Kreavana',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          isMoUConfirmed
                              ? 'MoU telah sah dan uang telah diterima oleh Kreavana.'
                              : 'Klik tombol untuk mengonfirmasi penerimaan berkas MoU dan dana.',
                          style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.textMuted : Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (!isMoUConfirmed)
                    ElevatedButton(
                      onPressed: _actionLoading ? null : _handleMarketingConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text(
                        'Konfirmasi Uang & MoU',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
