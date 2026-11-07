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
import '../services/user_store.dart';
import '../services/wallet_service.dart';
import 'wallet_screen.dart';
import 'proyek_saya_screen.dart';

class DetailKebutuhanScreen extends StatefulWidget {
  final OpportunityModel opportunity;
  final UserModel? user;

  const DetailKebutuhanScreen({
    super.key,
    required this.opportunity,
    this.user,
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
          _applications = apps;
          _loadingApps = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
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

    // KASUS 3: Konfirmasi & Tanda Tangan Elektronik Dynamic 3 Pihak (< 100 Jt)
    String dynamicSignaturePayload = '';
    List<String> dynamicTermsToSubmit = [];

    if (_opp.isDynamicSignatureBudget) {
      final signerName = widget.user?.name ?? widget.user?.username ?? 'Klien Penyelenggara';
      final signerController = TextEditingController(text: signerName);
      
      final defaultTermsText = '• Kamera & perlengkapan teknis disiapkan oleh pihak EO/WO sesuai kesepakatan tertulis.\n'
          '• Penyelenggara menyediakan konsumsi di lokasi dan akses resmi ke venue acara.\n'
          '• Pekerja hadir tepat waktu dan menyerahkan hasil kerja / file dokumentasi sesuai tenggat waktu.\n'
          '• Honorarium kerja diamankan 100% pada sistem Escrow Rekber Kreavana dan baru dicairkan setelah hasil pekerjaan disetujui.';
      
      final termsController = TextEditingController(
        text: _opp.dynamicTerms.isNotEmpty ? _opp.dynamicTerms.map((t) => '• $t').join('\n') : defaultTermsText,
      );

      bool agreeContract = false;

      if (!mounted) return;
      final signConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.draw_rounded, color: Color(0xFF3B82F6)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Kontrak Digital Dynamic (3 Pihak)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ringkasan Escrow & Anggaran
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user_rounded, color: Color(0xFF3B82F6), size: 16),
                                SizedBox(width: 6),
                                Text('Perjanjian Kerja Digital Mengikat 3 Pihak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• 1. Pembuat Event (Klien): Menyetujui ketentuan & membayar Escrow\n'
                              '• 2. Pekerja / Kreator: ${approvedApps.map((a) => a.creator?.name ?? "Kreator").join(", ")}\n'
                              '• 3. Admin Kreavana: Auto-input sistem (Cap & Tanda Tangan Resmi)\n'
                              '• Total Escrow Ditahan: ${currencyFmt.format(totalEscrow)} dari saldo ${currencyFmt.format(userBalance)}',
                              style: const TextStyle(fontSize: 11.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Klausul & Ketentuan Dinamis yang Dapat Diedit
                      const Text('Ketentuan Khusus & Klausul Dinamis *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Dapat disesuaikan (misal: penyediaan kamera oleh EO/WO, konsumsi, akomodasi, dsb):',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: termsController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tuliskan butir-butir ketentuan khusus...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                        style: const TextStyle(fontSize: 11.5, height: 1.35),
                      ),
                      const SizedBox(height: 14),

                      // Nama Lengkap Penandatangan
                      const Text('Nama Lengkap Penandatangan (Klien) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: signerController,
                        decoration: InputDecoration(
                          hintText: 'Nama lengkap Anda',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.fingerprint_rounded, size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Dynamic Hash: SIG-${DateTime.now().millisecondsSinceEpoch}-${widget.user?.id?.substring(0, 6) ?? "0000"}',
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blueGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            agreeContract = !agreeContract;
                          });
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: agreeContract,
                              activeColor: const Color(0xFF059669),
                              onChanged: (v) {
                                setDialogState(() {
                                  agreeContract = v ?? false;
                                });
                              },
                            ),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Saya secara sadar menandatangani surat perjanjian kerja dinamis ini dan menyetujui saldo sebesar nilai kontrak ditahan ke dalam Escrow Kreavana.',
                                  style: TextStyle(fontSize: 11.5, height: 1.3),
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
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: agreeContract ? const Color(0xFF059669) : Colors.grey,
                    ),
                    onPressed: agreeContract && signerController.text.trim().isNotEmpty
                        ? () {
                            dynamicSignaturePayload = 'DIGITAL_SIGNATURE:${signerController.text.trim()}:${DateTime.now().toIso8601String()}:SECURE_ESCROW';
                            dynamicTermsToSubmit = termsController.text
                                .split('\n')
                                .map((s) => s.replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim())
                                .where((s) => s.isNotEmpty)
                                .toList();
                            Navigator.pop(ctx, true);
                          }
                        : null,
                    child: const Text(
                      'Tandatangani & Mulai Acara',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (signConfirmed != true) return;
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
        signature: dynamicSignaturePayload.isNotEmpty ? dynamicSignaturePayload : null,
        signatureType: _opp.isWetSignatureBudget ? 'wet_signature' : 'dynamic_electronic',
        dynamicTerms: dynamicTermsToSubmit.isNotEmpty ? dynamicTermsToSubmit : null,
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

  Future<void> _showTripartiteContractModal() async {
    setState(() => _actionLoading = true);
    List<JobContract> contracts = [];
    try {
      contracts = await OpportunityService.getOpportunityContracts(_opp.id ?? '');
    } catch (_) {}
    setState(() => _actionLoading = false);

    if (!mounted) return;

    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultDynamicTerms = _opp.dynamicTerms.isNotEmpty
        ? _opp.dynamicTerms
        : [
            'Penyelenggara (Pihak Pertama) wajib menyediakan akses lokasi, jadwal rundown yang jelas, dan koordinasi teknis di venue.',
            'Penyediaan fasilitas dan alat kerja utama (seperti kamera, lensa, instrumen, dll) disepakati tertulis antara pembuat event dan pekerja.',
            'Pekerja (Pihak Kedua) berkewajiban hadir tepat waktu dan menyerahkan hasil kerja sesuai standar profesional yang disepakati.',
            'Honorarium kerja diamankan 100% pada sistem Escrow Rekber Kreavana (Pihak Ketiga) dan hanya dicairkan setelah hasil pekerjaan disetujui.',
          ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF13111E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.96,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // KOP SURAT
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                            : [const Color(0xFFEFF6FF), const Color(0xFFF8FAFC)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'PT KREAVANA DIGITAL INDONESIA',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SURAT PERJANJIAN KERJA SAMA ELEKTRONIK DINAMIS (3 PIHAK)',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No. Kontrak: ${contracts.isNotEmpty ? (contracts.first.contractNumber ?? 'KVN-CTR-${_opp.id?.substring(0, 8)}') : 'KVN-CTR-DRAFT-${_opp.id?.substring(0, 8)}'}',
                          style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: isDark ? Colors.cyanAccent : const Color(0xFF0369A1)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PARA PIHAK BERIKATAN (3 PIHAK)
                  const Text('PARA PIHAK YANG BERSEPAKAT:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildPartyCard(
                    title: 'PIHAK PERTAMA (Pembuat Event / Penyelenggara)',
                    name: _opp.poster?.name.isNotEmpty == true ? _opp.poster!.name : (widget.user?.name ?? 'Klien Penyelenggara'),
                    role: 'Penyelenggara Acara',
                    statusText: _opp.clientSignedAt != null ? 'Telah Ditandatangani Secara Sah' : 'Menunggu Pengesahan',
                    isSigned: _opp.clientSignedAt != null,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildPartyCard(
                    title: 'PIHAK KEDUA (Pekerja Kreatif / Pelamar)',
                    name: _opp.approvedCreators.isNotEmpty
                        ? _opp.approvedCreators.map((c) => '${c.name} (${c.subRole ?? _opp.subRoleSlug})').join(', ')
                        : 'Pekerja / Kreator Terpilih',
                    role: 'Pekerja Pelaksana Proyek',
                    statusText: _opp.isOngoing || _opp.clientSignedAt != null ? 'Telah Disetujui & Terikat Kontrak' : 'Menyetujui Penawaran',
                    isSigned: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildPartyCard(
                    title: 'PIHAK KETIGA (Platform & Penjamin Escrow)',
                    name: _opp.adminName ?? 'Tim Legal & Penjamin Escrow Kreavana',
                    role: 'Otoritas Penjamin Escrow & Sistem',
                    statusText: 'Otomatis Diinput Sistem (Cap & TTD Resmi)',
                    isSigned: true,
                    isAdmin: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // DANA ESCROW & PEKERJAAN
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: Color(0xFF059669), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nilai Kontrak Terproteksi Escrow:', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                              Text(
                                currencyFmt.format(_opp.escrowAmount ?? 0),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF059669)),
                              ),
                              Text(
                                _opp.escrowStatus == 'held' || _opp.status == 'in_progress'
                                    ? 'Status: DANA TELAH DITAHAN AMAN DI REKBER'
                                    : 'Status: Menunggu Penahanan saat Mulai Acara',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // KLAUSUL DINAMIS
                  const Text('KETENTUAN KHUSUS & KLAUSUL DINAMIS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: defaultDynamicTerms.map((term) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                              Expanded(
                                child: Text(term, style: const TextStyle(fontSize: 12, height: 1.35)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3 KOLOM TANDA TANGAN DIGITAL BERDAMPINGAN
                  const Text('PENGESAHAN TANDA TANGAN DIGITAL (3 PIHAK):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TTD Klien
                      Expanded(
                        child: _buildSignatureBox(
                          title: 'Pihak Pertama\n(Penyelenggara)',
                          signer: _opp.poster?.name ?? (widget.user?.name ?? 'Klien'),
                          signature: _opp.clientSignature ?? 'SIG-CLIENT-VERIFIED',
                          date: _opp.clientSignedAt?.substring(0, 10) ?? '-',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // TTD Kreator
                      Expanded(
                        child: _buildSignatureBox(
                          title: 'Pihak Kedua\n(Pekerja / Kreator)',
                          signer: _opp.approvedCreators.isNotEmpty ? _opp.approvedCreators.first.name : 'Pekerja Kreator',
                          signature: 'SIG-CREATOR-VERIFIED',
                          date: _opp.clientSignedAt?.substring(0, 10) ?? '-',
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // TTD Admin Kreavana
                      Expanded(
                        child: _buildSignatureBox(
                          title: 'Pihak Ketiga\n(Admin Kreavana)',
                          signer: _opp.adminName ?? 'Admin Legal Kreavana',
                          signature: 'ADMIN-AUTO-INPUT',
                          date: _opp.adminSignedAt?.substring(0, 10) ?? DateTime.now().toIso8601String().substring(0, 10),
                          isAdmin: true,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup Dokumen Kontrak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
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
    bool isAdmin = false,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAdmin ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isAdmin
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                  : const Color(0xFF059669).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Icon(
                  isAdmin ? Icons.verified_rounded : Icons.draw_rounded,
                  size: 20,
                  color: isAdmin ? const Color(0xFF2563EB) : const Color(0xFF059669),
                ),
                const SizedBox(height: 2),
                Text(
                  isAdmin ? 'STEMPEL RESMI\nKREAVANA' : 'DIGITAL SIGN',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: isAdmin ? const Color(0xFF2563EB) : const Color(0xFF059669),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(signer, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          Text('Tgl: $date', style: TextStyle(fontSize: 8.5, color: Colors.grey.shade600), textAlign: TextAlign.center),
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
    final notesCtrl = TextEditingController();

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
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
            content: Column(
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
                  onChanged: (val) => setDialogState(() => current = val.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [0, 25, 50, 75, 100].map((step) {
                    return InkWell(
                      onTap: () => setDialogState(() => current = step),
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
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Progress (Opsional)',
                    hintText: 'Misal: Pengambilan gambar selesai, tahap editing...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                onPressed: () => Navigator.pop(ctx, current),
                child: const Text('Simpan Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    setState(() => _actionLoading = true);
    try {
      final res = await OpportunityService.updateWorkerProgress(
        applicationId: app.id,
        progress: result,
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      );

      if (mounted) {
        if (res['status'] == true) {
          AppSnackbar.success(context, 'Progress berhasil diperbarui menjadi $result%!');
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

  Future<void> _handleAdminReviewMeeting() async {
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
                'Jika disetujui, status akan berubah menjadi DIPROSES.',
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
            child: const Text('Tolak Jadwal', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, 'approve'),
            child: const Text('Setujui (Status: Diproses)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (decision == null) return;

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
                        Navigator.pop(ctx, dataUri);
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

          // Approved celebration
          if (isApproved) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selamat! Lamaran Anda telah disetujui oleh pemilik proyek. Silakan koordinasikan tahap pengerjaan proyek.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _actionLoading ? null : () => _handleUpdateWorkerProgress(app),
                            icon: const Icon(Icons.edit_note_rounded, size: 14),
                            label: const Text('Perbarui Progress', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryPurple,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
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
                ],
              ),
            );
          }),
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
    final approvedList = _applications.where((a) => a.isApproved).toList();

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

          // Participating Creators
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 18, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Text(
                'Kreator yang Berpartisipasi (${approvedList.length + _opp.approvedCreators.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (approvedList.isEmpty && _opp.approvedCreators.isEmpty)
            Text(
              'Belum ada nama kreator yang disetujui.',
              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...approvedList.map((app) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundImage: app.creator?.avatarUrl != null
                          ? CachedNetworkImageProvider(app.creator!.avatarUrl!)
                          : null,
                      child: app.creator?.avatarUrl == null
                          ? Text(
                              app.creator?.name.isNotEmpty == true ? app.creator!.name[0].toUpperCase() : 'K',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    label: Text('${app.creator?.name ?? "Kreator"} (${app.subRoleSlug.replaceAll('_', ' ')})'),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    side: const BorderSide(color: Color(0xFF10B981), width: 0.5),
                  );
                }),
                ..._opp.approvedCreators.map((c) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundImage: c.avatarUrl != null ? CachedNetworkImageProvider(c.avatarUrl!) : null,
                      child: c.avatarUrl == null
                          ? Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : 'K',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    label: Text('${c.name} (${c.subRole ?? "Kreator"})'),
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                    side: const BorderSide(color: Color(0xFF10B981), width: 0.5),
                  );
                }),
              ],
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
      // Standard Escrow & Dynamic Signature Card (< 100 Jt)
      final isSigned = _opp.clientSignature != null || _opp.clientSignedAt != null;
      final isEscrowHeld = _opp.escrowStatus == 'held' || _opp.escrowStatus == 'held_in_escrow' || _opp.status == 'in_progress';

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
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Escrow & Kontrak Elektronik Dynamic (< Rp 100 Jt)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSigned
                                  ? const Color(0xFF059669).withValues(alpha: 0.15)
                                  : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isSigned ? 'TTD DIGITAL SAH' : 'TTD DYNAMIC WAJIB',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isSigned ? const Color(0xFF059669) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Budget proyek < Rp 100.000.000 dilindungi sistem Escrow Rekber Kreavana dan Kontrak Elektronik Dynamic. Saat event dimulai, saldo diamankan ke Escrow dan baru diteruskan ke kreator setelah hasil kerja Anda setujui.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isEscrowHeld || isSigned) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEscrowHeld ? Icons.lock_clock_rounded : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: const Color(0xFF059669),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEscrowHeld
                            ? 'Escrow Ditahan: ${currencyFmt.format(_opp.escrowAmount ?? 0)}'
                            : 'Kontrak Terverifikasi',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                  if (_opp.clientSignedAt != null)
                    Text(
                      'Ditandatangani: ${_opp.clientSignedAt!.substring(0, 10)}',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textMuted : Colors.grey.shade600),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF06B6D4).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showTripartiteContractModal,
                icon: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF06B6D4)),
                label: const Text(
                  'Lihat Dokumen Kontrak Digital (3 Pihak)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
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
                          : (_opp.isMeetingPending ? const Color(0xFFD97706) : Colors.red.shade700)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isMoUConfirmed
                      ? 'TTD BASAH SAH'
                      : (_opp.isMeetingInProcess
                          ? 'STATUS: DIPROSES'
                          : (_opp.isMeetingPending ? 'STATUS: PENDING' : 'PERLU JADWAL')),
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
                                  : const Color(0xFFD97706).withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isMoUConfirmed
                              ? 'MoU Fisik Terverifikasi'
                              : (_opp.isMeetingInProcess
                                  ? 'Diproses (Disetujui Admin)'
                                  : 'Menunggu Persetujuan Admin (Pending)'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isMoUConfirmed
                                ? const Color(0xFF059669)
                                : (_opp.isMeetingInProcess ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
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
                  if (_opp.isMeetingPending) ...[
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
                            'Jadwal pertemuan fisik telah diajukan oleh pembuat acara. Admin Kreavana akan meninjau dan mengonfirmasi tanggal tersebut.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade800),
                          ),
                          if (_isMarketingOrAdmin) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _actionLoading ? null : _handleAdminReviewMeeting,
                              icon: const Icon(Icons.rate_review_rounded, size: 14, color: Colors.white),
                              label: const Text('Tinjau & Setujui Jadwal Temu', style: TextStyle(fontSize: 11, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
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
