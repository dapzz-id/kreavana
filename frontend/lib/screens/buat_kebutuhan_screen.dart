import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../app/app_animations.dart';
import '../utils/app_errors.dart';
import '../services/opportunity_service.dart';
import '../widgets/animated_input_field.dart';
import '../widgets/gradient_button.dart';
import 'proyek_saya_screen.dart';
import '../models/user_model.dart';
import '../widgets/desktop_sidebar_layout.dart';
import '../widgets/app_breadcrumbs.dart';
import '../services/verification_service.dart';
import 'client_verification_page.dart';

class RoleRequirementFormItem {
  String slug;
  int quantity;
  List<String> tags;
  final TextEditingController customTagController = TextEditingController();

  RoleRequirementFormItem({
    required this.slug,
    this.quantity = 1,
    List<String>? tags,
  }) : tags = tags ?? [];

  void dispose() {
    customTagController.dispose();
  }
}

class BuatKebutuhanScreen extends StatefulWidget {
  final UserModel? user;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialKategori;
  final String? initialBudget;

  const BuatKebutuhanScreen({
    super.key,
    this.user,
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
  final _alamatController = TextEditingController();
  final _bannerUrlController = TextEditingController();
  final _meetingLocationController = TextEditingController();
  final _meetingNotesController = TextEditingController();

  String? _bannerUrl;
  DateTime _eventStartDate = DateTime.now().add(const Duration(days: 3));
  DateTime _eventEndDate = DateTime.now().add(const Duration(days: 5));
  DateTime _meetingDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _meetingTime = const TimeOfDay(hour: 14, minute: 0);
  String _selectedMeetingPlaceType = 'office'; // 'office' | 'client_location'

  bool get _isLargeBudget => _selectedBudget.contains('20.000.000');

  bool _submitting = false;
  bool _isClientVerified = true;

  Future<void> _checkClientVerification() async {
    final isClient =
        widget.user?.role == 'user' || widget.user?.isClient == true;
    if (!isClient) {
      if (mounted) setState(() => _isClientVerified = true);
      return;
    }
    if (widget.user?.isVerified == true) {
      if (mounted) setState(() => _isClientVerified = true);
      return;
    }
    try {
      final status = await VerificationService.getStatus();
      if (mounted) {
        setState(() {
          _isClientVerified = status?.isVerified == true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isClientVerified = widget.user?.isVerified ?? false);
      }
    }
  }

  // Multi-role requirement items
  List<RoleRequirementFormItem>? _requirements;

  List<RoleRequirementFormItem> get safeRequirements {
    if (_requirements == null || _requirements!.isEmpty) {
      _initDefaultRequirement();
    }
    return _requirements!;
  }

  void _initDefaultRequirement() {
    _requirements = [];
    final initialRole = widget.initialKategori ?? 'fotografi';
    final initialTags = _rolePresetTags[initialRole]?.take(2).toList() ?? ['Portrait'];
    _requirements!.add(
      RoleRequirementFormItem(
        slug: initialRole,
        quantity: 1,
        tags: List<String>.from(initialTags),
      ),
    );
  }

  // Lokasi state
  bool _isRemote = false;
  String _selectedCity = 'Jakarta';

  String _selectedBudget = '< Rp 500.000';
  String _selectedDeadline = '1 Minggu';

  static const List<Map<String, dynamic>> _kategoriItems = [
    {
      'value': 'fotografi',
      'label': 'Fotografi & Dokumentasi',
      'icon': Icons.photo_camera_rounded,
    },
    {
      'value': 'videografi',
      'label': 'Videografi & Sinematografi',
      'icon': Icons.videocam_rounded,
    },
    {
      'value': 'desain-grafis',
      'label': 'Desain Grafis & Branding',
      'icon': Icons.palette_rounded,
    },
    {
      'value': 'editor',
      'label': 'Editor Video & Pascaproduksi',
      'icon': Icons.auto_fix_high_rounded,
    },
    {
      'value': 'animator',
      'label': 'Animator 2D/3D & VFX',
      'icon': Icons.animation_rounded,
    },
    {
      'value': 'konten-kreator',
      'label': 'Content Creator & Influencer',
      'icon': Icons.movie_creation_rounded,
    },
    {
      'value': 'drone',
      'label': 'Pilot Drone Udara (Aerial & FPV)',
      'icon': Icons.airplanemode_active_rounded,
    },
    {
      'value': 'mc',
      'label': 'Master of Ceremony (MC / Host)',
      'icon': Icons.mic_external_on_rounded,
    },
    {
      'value': 'singer',
      'label': 'Penyanyi & Musisi',
      'icon': Icons.music_note_rounded,
    },
    {
      'value': 'event_organizer',
      'label': 'Event Organizer (EO)',
      'icon': Icons.festival_rounded,
    },
    {
      'value': 'wedding_organizer',
      'label': 'Wedding Organizer (WO)',
      'icon': Icons.favorite_rounded,
    },
    {
      'value': 'makeup_artist',
      'label': 'Makeup Artist (MUA)',
      'icon': Icons.face_retouching_natural_rounded,
    },
    {
      'value': 'model',
      'label': 'Model & Talent Iklan',
      'icon': Icons.stars_rounded,
    },
    {
      'value': 'copywriter',
      'label': 'Copywriter & Penulis Naskah',
      'icon': Icons.draw_rounded,
    },
    {
      'value': 'community',
      'label': 'Komunitas Kreatif',
      'icon': Icons.groups_rounded,
    },
    {
      'value': 'institution',
      'label': 'Lembaga / Yayasan',
      'icon': Icons.assured_workload_rounded,
    },
    {
      'value': 'government',
      'label': 'Instansi Pemerintah',
      'icon': Icons.account_balance_rounded,
    },
    {
      'value': 'lainnya',
      'label': 'Kebutuhan Kreator Lainnya',
      'icon': Icons.more_horiz_rounded,
    },
  ];

  static const Map<String, List<String>> _rolePresetTags = {
    'fotografi': [
      'Portrait',
      'Landscape',
      'Wedding',
      'Katalog Produk',
      'Fashion',
      'Event & Dokumentasi',
      'Studio',
      'Street Photography',
    ],
    'videografi': [
      'Cinematic Reel',
      'Aftermovie Event',
      'Teaser',
      'Reels / TikTok',
      'Company Profile',
      'Music Video',
      'Wedding Clip',
    ],
    'desain-grafis': [
      'Logo & Branding',
      'Social Media Feed',
      'Packaging',
      'Poster & Banner',
      'UI/UX Design',
      'Ilustrasi',
    ],
    'editor': [
      'Color Grading',
      'Reels / Shorts Edit',
      'Motion Graphics',
      'Podcast Audio',
      'Sound Design',
      'VFX Compositing',
    ],
    'animator': [
      '2D Explainer',
      '3D Animation',
      'Character Design',
      'Logo Animation',
      'VFX Simulation',
    ],
    'konten-kreator': [
      'UGC Video',
      'Review Produk',
      'Endorsement',
      'Daily Vlog',
      'Live Streaming Host',
    ],
    'drone': [
      'FPV Drone Racing',
      'Aerial Landscape',
      'Real Estate Footage',
      'Outdoor Festival',
      'Aerial Inspection',
    ],
    'mc': [
      'Wedding MC',
      'Formal Protocol',
      'Konser & Festival',
      'Bilingual (ID/EN)',
      'Seminar / Talkshow',
      'Birthday Party',
    ],
    'singer': [
      'Akustik',
      'Full Band',
      'Solo Vocal',
      'Jingle Iklan',
      'Wedding Singer',
      'Pop & Jazz',
    ],
    'event_organizer': [
      'Corporate Gathering',
      'Konser Musik',
      'Exhibition & Pameran',
      'Seminar / Workshop',
      'Outbound & Team Building',
    ],
    'wedding_organizer': [
      'Pernikahan Tradisional',
      'Modern Intimate',
      'Outdoor Wedding',
      'Acara Lamaran',
      'Full Day Coordinator',
    ],
    'makeup_artist': [
      'Wedding Makeup',
      'Wisuda & Kelulusan',
      'Photoshoot Fashion',
      'SFX & Karakter',
      'Natural Glow',
    ],
    'model': [
      'Fashion Model',
      'Iklan Komersial',
      'Katalog Lookbook',
      'Talent Video',
      'Fitness Model',
    ],
    'copywriter': [
      'Naskah Iklan (Script)',
      'Artikel SEO',
      'Caption Sosmed',
      'Company Profile',
      'Tagline & Slogan',
    ],
    'community': [
      'Volunteer Event',
      'Workshop Kreatif',
      'Kolaborasi Komunitas',
      'Charity',
    ],
    'institution': [
      'CSR Project',
      'Seminar Akademik',
      'Pelatihan Keahlian',
    ],
    'government': [
      'Publikasi Program',
      'Dokumentasi Resmi',
      'Kampanye Publik',
    ],
    'lainnya': [
      'Freelance',
      'Kolaborasi',
      'Project Based',
    ],
  };

  static const List<Map<String, dynamic>> _cityPresets = [
    {'name': 'Jakarta', 'lat': -6.2088, 'lng': 106.8456},
    {'name': 'Bandung', 'lat': -6.9175, 'lng': 107.6191},
    {'name': 'Surabaya', 'lat': -7.2575, 'lng': 112.7521},
    {'name': 'Yogyakarta', 'lat': -7.7956, 'lng': 110.3695},
    {'name': 'Bali / Denpasar', 'lat': -8.6705, 'lng': 115.2126},
    {'name': 'Semarang', 'lat': -6.9667, 'lng': 110.4167},
    {'name': 'Medan', 'lat': 3.5952, 'lng': 98.6722},
    {'name': 'Makassar', 'lat': -5.1477, 'lng': 119.4327},
    {'name': 'Solo (Surakarta)', 'lat': -7.5755, 'lng': 110.8243},
    {'name': 'Malang', 'lat': -7.9666, 'lng': 112.6326},
    {'name': 'Bogor', 'lat': -6.5971, 'lng': 106.8060},
    {'name': 'Tangerang', 'lat': -6.1783, 'lng': 106.6319},
    {'name': 'Bekasi', 'lat': -6.2383, 'lng': 106.9756},
    {'name': 'Depok', 'lat': -6.4025, 'lng': 106.7942},
    {'name': 'Lainnya / Luar Kota', 'lat': -6.2000, 'lng': 106.8166},
  ];

  static const _budgetItems = [
    '< Rp 500.000',
    'Rp 500.000 - 1.000.000',
    'Rp 1.000.000 - 5.000.000',
    'Rp 5.000.000 - 20.000.000',
    '>= Rp 20.000.000 (Skala Besar - MoU Legal Kreavana)',
  ];

  static const List<Map<String, dynamic>> _deadlineItems = [
    {'value': '1 Minggu', 'days': 7},
    {'value': '2 Minggu', 'days': 14},
    {'value': '1 Bulan', 'days': 30},
    {'value': '3 Bulan', 'days': 90},
    {'value': 'Fleksibel', 'days': 90},
  ];

  String get deadlineDate {
    final days =
        _deadlineItems.firstWhere(
              (d) => d['value'] == _selectedDeadline,
            )['days']
            as int;
    return DateTime.now()
        .add(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _judulController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _deskripsiController.text = widget.initialDescription!;
    }
    if (widget.initialBudget != null) {
      _selectedBudget = widget.initialBudget!;
    }
    _initDefaultRequirement();
    _checkClientVerification();
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    _alamatController.dispose();
    _bannerUrlController.dispose();
    _meetingLocationController.dispose();
    _meetingNotesController.dispose();
    if (_requirements != null) {
      for (final item in _requirements!) {
        item.dispose();
      }
    }
    super.dispose();
  }

  void _addRequirement() {
    final reqs = safeRequirements;
    final existingSlugs = reqs.map((r) => r.slug).toSet();
    String nextSlug = 'videografi';
    for (final cat in _kategoriItems) {
      final val = cat['value'] as String;
      if (!existingSlugs.contains(val)) {
        nextSlug = val;
        break;
      }
    }

    final presetTags = _rolePresetTags[nextSlug]?.take(2).toList() ?? [];
    setState(() {
      reqs.add(
        RoleRequirementFormItem(
          slug: nextSlug,
          quantity: 1,
          tags: List<String>.from(presetTags),
        ),
      );
    });
  }

  void _removeRequirement(int index) {
    final reqs = safeRequirements;
    if (reqs.length <= 1) {
      AppSnackbar.warning(context, 'Minimal harus ada 1 peran kreator.');
      return;
    }
    setState(() {
      final removed = reqs.removeAt(index);
      removed.dispose();
    });
  }

  void _addCustomTag(RoleRequirementFormItem item) {
    final text = item.customTagController.text.trim();
    if (text.isEmpty) return;

    if (!item.tags.any((t) => t.toLowerCase() == text.toLowerCase())) {
      setState(() {
        item.tags.add(text);
      });
    }
    item.customTagController.clear();
  }

  Future<void> _submit() async {
    final isClient =
        widget.user?.role == 'user' || widget.user?.isClient == true;
    if (isClient && !_isClientVerified) {
      final shouldVerify = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Verifikasi KTP Diperlukan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Untuk mempublikasikan kebutuhan proyek baru, akun Klien Anda wajib diverifikasi KTP terlebih dahulu demi keamanan.\n\nVerifikasi ini tidak mengubah akun Anda menjadi Kreator.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Verifikasi Sekarang'),
            ),
          ],
        ),
      );
      if (shouldVerify == true && mounted) {
        final res = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ClientVerificationPage(user: widget.user),
          ),
        );
        if (res == true) {
          _checkClientVerification();
        }
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    final reqs = safeRequirements;
    if (reqs.isEmpty) {
      AppSnackbar.error(context, 'Pilih minimal satu peran kreator yang dibutuhkan.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final primaryRoleSlug = reqs.first.slug;
      final requirementsPayload = reqs.map((r) {
        return {
          'sub_role_slug': r.slug,
          'quantity': r.quantity,
          'notes': r.tags.isNotEmpty ? r.tags.join(', ') : null,
        };
      }).toList();

      final cityData = _cityPresets.firstWhere(
        (c) => c['name'] == _selectedCity,
        orElse: () => _cityPresets.first,
      );

      final locationName = _isRemote ? 'Remote / Online' : _selectedCity;
      final addressDetail = _isRemote
          ? 'Online / Remote (Dapat dikerjakan dari mana saja)'
          : (_alamatController.text.trim().isNotEmpty
              ? _alamatController.text.trim()
              : _selectedCity);

      final result = await OpportunityService.createOpportunity(
        title: _judulController.text.trim(),
        subRoleSlug: primaryRoleSlug,
        type: 'project',
        description: _deskripsiController.text.trim().isNotEmpty
            ? _deskripsiController.text.trim()
            : null,
        posterUrl: _bannerUrl,
        bannerUrl: _bannerUrl,
        location: locationName,
        address: addressDetail,
        latitude: _isRemote ? null : (cityData['lat'] as double),
        longitude: _isRemote ? null : (cityData['lng'] as double),
        budgetRange: _selectedBudget,
        deadline: deadlineDate,
        eventDate: _eventStartDate.toIso8601String().substring(0, 10),
        eventStartDate: _eventStartDate.toIso8601String().substring(0, 10),
        eventEndDate: _eventEndDate.toIso8601String().substring(0, 10),
        meetingDate: _isLargeBudget ? _meetingDate.toIso8601String().substring(0, 10) : null,
        meetingTime: _isLargeBudget ? '${_meetingTime.hour.toString().padLeft(2, '0')}:${_meetingTime.minute.toString().padLeft(2, '0')} WIB' : null,
        meetingLocation: _isLargeBudget
            ? (_selectedMeetingPlaceType == 'office'
                ? 'Kantor Representatif Kreavana (Menara Kreatif Lt. 8, Jakarta)'
                : (_meetingLocationController.text.trim().isNotEmpty
                    ? _meetingLocationController.text.trim()
                    : addressDetail))
            : null,
        meetingNotes: _isLargeBudget && _meetingNotesController.text.trim().isNotEmpty
            ? _meetingNotesController.text.trim()
            : null,
        requirements: requirementsPayload,
      );

      if (!mounted) return;

      if (result['status'] == true) {
        AppSnackbar.success(context, 'Kebutuhan proyek berhasil dipublikasikan!');
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ProyekSayaScreen(user: widget.user)),
          );
        }
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
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final content = Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF8F9FD),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: isDesktop ? 70 : 64,
        elevation: 0,
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Row(
              children: [
                if (Navigator.canPop(context))
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardBg : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                if (Navigator.canPop(context)) const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Buat Kebutuhan Proyek',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Dapatkan tawaran & proposal dari berbagai kreator terbaik',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            isDesktop ? 24 : 16,
            isDesktop ? 32 : 16,
            56,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      label: 'Buat Kebutuhan Proyek',
                      icon: Icons.add_circle_outline_rounded,
                    ),
                  ],
                ),
                if (!_isClientVerified &&
                    (widget.user?.role == 'user' ||
                        widget.user?.isClient == true))
                  Container(
                    margin: const EdgeInsets.only(top: 14, bottom: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50
                          .withValues(alpha: isDark ? 0.15 : 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Colors.amber.shade800,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verifikasi KTP Diperlukan Sebelum Publikasi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.amber.shade300
                                      : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sebagai Klien, verifikasi KTP wajib untuk menjamin rasa aman dan mendapatkan lencana centang biru 🔵. Verifikasi ini tidak mengubah peran Anda menjadi kreator.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final res = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientVerificationPage(user: widget.user),
                              ),
                            );
                            if (res == true) {
                              _checkClientVerification();
                            }
                          },
                          icon: const Icon(Icons.verified_user, size: 16),
                          label: const Text('Verifikasi KTP'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(isDesktop ? 32 : 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade200,
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: EntranceList(
                      stepDelay: const Duration(milliseconds: 50),
                      children: [
                        // ── Info banner ──
                        _InfoBanner(isDark: isDark),
                        const SizedBox(height: 24),

                        // ── Banner Acara (Opsional) ──
                        _buildBannerUploadSection(isDark),
                        const SizedBox(height: 24),

                        // ── Judul ──
                        AnimatedInputField(
                          controller: _judulController,
                          label: 'Judul Kebutuhan Proyek',
                          hint: 'Contoh: Foto Marathon 10Km & Video Highlight Dokumentasi',
                          icon: Icons.title_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                            if (v.trim().length < 5) return 'Minimal 5 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Durasi Acara (Tanggal Mulai - Selesai) ──
                        _buildDurationSection(isDark, isDesktop),
                        const SizedBox(height: 28),

                        // ── Multi-Role Section ──
                        _buildRolesSection(isDark),
                        const SizedBox(height: 28),

                        // ── Wilayah & Lokasi ──
                        _buildLocationSection(isDark, isDesktop),
                        const SizedBox(height: 28),

                        // ── Deskripsi ──
                        _AnimatedTextArea(
                          controller: _deskripsiController,
                          label: 'Deskripsi Kebutuhan & Ruang Lingkup',
                          hint: 'Jelaskan ekspektasi hasil, konsep visual, rundown acara, atau detail spesifik lainnya...',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Budget & Deadline (2-col on desktop) ──
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _AnimatedDropdown(
                                  label: 'Budget Estimasi',
                                  icon: Icons.payments_rounded,
                                  value: _selectedBudget,
                                  items: _budgetItems
                                      .map((e) => <String, dynamic>{'value': e, 'label': e})
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedBudget = v!),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _AnimatedDropdown(
                                  label: 'Target Deadline',
                                  icon: Icons.event_rounded,
                                  value: _selectedDeadline,
                                  items: _deadlineItems
                                      .map(
                                        (e) => <String, dynamic>{
                                          'value': e['value'] as String,
                                          'label': e['value'] as String,
                                        },
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedDeadline = v!),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _AnimatedDropdown(
                            label: 'Budget Estimasi',
                            icon: Icons.payments_rounded,
                            value: _selectedBudget,
                            items: _budgetItems
                                .map((e) => <String, dynamic>{'value': e, 'label': e})
                                .toList(),
                            onChanged: (v) => setState(() => _selectedBudget = v!),
                          ),
                          const SizedBox(height: 20),
                          _AnimatedDropdown(
                            label: 'Target Deadline',
                            icon: Icons.event_rounded,
                            value: _selectedDeadline,
                            items: _deadlineItems
                                .map(
                                  (e) => <String, dynamic>{
                                    'value': e['value'] as String,
                                    'label': e['value'] as String,
                                  },
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _selectedDeadline = v!),
                          ),
                        ],

                        // ── Escrow vs MoU Legal (> 20 Juta) ──
                        if (_isLargeBudget)
                          _buildMoUMeetingSection(isDark, isDesktop)
                        else
                          _buildEscrowProtectionCard(isDark),

                        const SizedBox(height: 36),

                        // ── Submit & Actions ──
                        Row(
                          children: [
                            if (Navigator.canPop(context))
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: _submitting ? null : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    side: BorderSide(
                                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    'Batal',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            if (Navigator.canPop(context)) const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: GradientButton(
                                text: 'Publikasikan Kebutuhan Proyek',
                                icon: Icons.rocket_launch_rounded,
                                isLoading: _submitting,
                                onPressed: _submit,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  // ── Multi-Role Requirements Builder ─────────────────────────────────────────
  Widget _buildRolesSection(bool isDark) {
    final reqs = safeRequirements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.group_work_rounded,
                      size: 20,
                      color: AppTheme.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Peran Kreator yang Dibutuhkan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bisa lebih dari satu peran (misal: Fotografer + MC + Event Organizer)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _addRequirement,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Peran'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.12),
                foregroundColor: AppTheme.primaryPurple,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.primaryPurple, width: 1.2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // List of requirement cards
        ...reqs.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildRequirementCard(item, index, isDark);
        }),
      ],
    );
  }

  Widget _buildRequirementCard(RoleRequirementFormItem item, int index, bool isDark) {
    final presetTags = _rolePresetTags[item.slug] ?? ['Umum', 'Profesional'];
    final reqCount = safeRequirements.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191629) : const Color(0xFFF9FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Role dropdown + Quantity + Remove
          Row(
            children: [
              Expanded(
                child: _AnimatedDropdown(
                  label: 'Peran Kreator #${index + 1}',
                  icon: Icons.badge_outlined,
                  value: item.slug,
                  items: _kategoriItems,
                  onChanged: (newSlug) {
                    if (newSlug != null && newSlug != item.slug) {
                      setState(() {
                        item.slug = newSlug;
                        // Populate default preset tags for this role
                        final newPresets = _rolePresetTags[newSlug]?.take(2).toList() ?? [];
                        item.tags = List<String>.from(newPresets);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Quantity Counter
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jumlah Orang',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.inputDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: item.quantity > 1
                              ? () => setState(() => item.quantity--)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: item.quantity < 50
                              ? () => setState(() => item.quantity++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (reqCount > 1) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton(
                    tooltip: 'Hapus peran ini',
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _removeRequirement(index),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Tags section
          Text(
            'Tag Spesialisasi & Keahlian (Bisa dicari oleh kreator):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),

          // Active Selected Tags
          if (item.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.tags.map((tag) {
                return Chip(
                  label: Text('#$tag', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.12),
                  side: const BorderSide(color: AppTheme.primaryPurple, width: 0.8),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.primaryPurple),
                  onDeleted: () {
                    setState(() {
                      item.tags.remove(tag);
                    });
                  },
                );
              }).toList(),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Belum ada tag dipilih. Pilih rekomendasi di bawah atau ketik tag manual.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
              ),
            ),

          const SizedBox(height: 10),

          // Recommended preset tags
          Text(
            'Rekomendasi untuk peran ini:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: presetTags.map((pTag) {
              final isSelected = item.tags.any((t) => t.toLowerCase() == pTag.toLowerCase());
              return ActionChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                backgroundColor: isSelected
                    ? AppTheme.primaryPurple.withValues(alpha: 0.18)
                    : (isDark ? const Color(0xFF262338) : Colors.white),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryPurple
                      : (isDark ? AppTheme.inputBorder : Colors.grey.shade300),
                ),
                label: Text(
                  isSelected ? '✓ $pTag' : '+ $pTag',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryPurple : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    if (isSelected) {
                      item.tags.removeWhere((t) => t.toLowerCase() == pTag.toLowerCase());
                    } else {
                      item.tags.add(pTag);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Custom Tag Input Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: item.customTagController,
                    onSubmitted: (_) => _addCustomTag(item),
                    decoration: InputDecoration(
                      hintText: 'Tambah tag manual (misal: portrait, candid, prewedding)...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textMuted : Colors.grey.shade500,
                      ),
                      filled: true,
                      fillColor: isDark ? AppTheme.inputDark : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () => _addCustomTag(item),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah Tag', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2C2842) : Colors.grey.shade200,
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Location & Wilayah Section ──────────────────────────────────────────────
  Widget _buildLocationSection(bool isDark, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191629) : const Color(0xFFF9FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF06B6D4)),
              const SizedBox(width: 8),
              Text(
                'Wilayah & Lokasi Pelaksanaan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kreator dapat mencari peluang berdasarkan kota atau jarak terdekat dari lokasi mereka.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 14),

          // Physical vs Remote Switcher
          Row(
            children: [
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Lokasi Fisik (On-site)'),
                  ],
                ),
                selected: !_isRemote,
                onSelected: (val) {
                  if (val) setState(() => _isRemote = false);
                },
                selectedColor: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontWeight: !_isRemote ? FontWeight.bold : FontWeight.normal,
                  color: !_isRemote ? const Color(0xFF0891B2) : null,
                ),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Online / Remote'),
                  ],
                ),
                selected: _isRemote,
                onSelected: (val) {
                  if (val) setState(() => _isRemote = true);
                },
                selectedColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontWeight: _isRemote ? FontWeight.bold : FontWeight.normal,
                  color: _isRemote ? const Color(0xFF059669) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!_isRemote) ...[
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _AnimatedDropdown(
                      label: 'Kota / Wilayah',
                      icon: Icons.location_city_rounded,
                      value: _selectedCity,
                      items: _cityPresets
                          .map((c) => {
                                'value': c['name'] as String,
                                'label': c['name'] as String,
                              })
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCity = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: AnimatedInputField(
                      controller: _alamatController,
                      label: 'Detail Lokasi / Tempat Acara',
                      hint: 'Misal: Hotel Mulia Senayan, Studio Foto Cipete, dsb.',
                      icon: Icons.map_rounded,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              )
            else ...[
              _AnimatedDropdown(
                label: 'Kota / Wilayah',
                icon: Icons.location_city_rounded,
                value: _selectedCity,
                items: _cityPresets
                    .map((c) => {
                          'value': c['name'] as String,
                          'label': c['name'] as String,
                        })
                    .toList(),
                onChanged: (v) => setState(() => _selectedCity = v!),
              ),
              const SizedBox(height: 14),
              AnimatedInputField(
                controller: _alamatController,
                label: 'Detail Lokasi / Tempat Acara',
                hint: 'Misal: Hotel Mulia Senayan, Studio Foto Cipete, dsb.',
                icon: Icons.map_rounded,
                textInputAction: TextInputAction.next,
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF059669), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Peluang ini terbuka untuk kreator dari seluruh Indonesia (remote / online delivery).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
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

  // ─── Banner Upload Section ──────────────────────────────────────────────────
  Widget _buildBannerUploadSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.image_outlined,
              size: 20,
              color: AppTheme.primaryPurple,
            ),
            const SizedBox(width: 8),
            Text(
              'Banner Acara / Proyek',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Opsional',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Upload foto banner atau pilih gambar tema untuk dipajang di bagian atas detail acara.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        if (_bannerUrl != null && _bannerUrl!.isNotEmpty) ...[
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
              ),
              image: DecorationImage(
                image: NetworkImage(_bannerUrl!),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  right: 12,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Hapus Banner', style: TextStyle(fontSize: 12)),
                    onPressed: () => setState(() {
                      _bannerUrl = null;
                      _bannerUrlController.clear();
                    }),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B33) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 38,
                  color: isDark ? Colors.white54 : Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Belum ada banner acara',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.palette_outlined, size: 16),
                      label: const Text('Pilih Tema Acara', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showBannerThemePicker(context, isDark),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Input URL Banner', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showBannerUrlDialog(context, isDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showBannerThemePicker(BuildContext context, bool isDark) {
    final themes = [
      {
        'title': 'Marathon & Olahraga',
        'url': 'https://images.unsplash.com/photo-1452626038306-9aae5e071dd3?auto=format&fit=crop&w=1200&q=80',
      },
      {
        'title': 'Festival Musik & Konser',
        'url': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
      },
      {
        'title': 'Wedding & Romance',
        'url': 'https://images.unsplash.com/photo-1519741497674-611481863552?auto=format&fit=crop&w=1200&q=80',
      },
      {
        'title': 'Tech Conference & Summit',
        'url': 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1200&q=80',
      },
      {
        'title': 'Creative Studio & Exhibition',
        'url': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161426) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Banner Tema Acara',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: themes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final t = themes[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() => _bannerUrl = t['url']);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: NetworkImage(t['url']!),
                          fit: BoxFit.cover,
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t['title']!,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBannerUrlDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161426) : Colors.white,
        title: const Text('Input URL Banner Acara'),
        content: TextField(
          controller: _bannerUrlController,
          decoration: const InputDecoration(
            hintText: 'https://example.com/banner.jpg',
            labelText: 'URL Gambar Banner',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = _bannerUrlController.text.trim();
              if (url.isNotEmpty) {
                setState(() => _bannerUrl = url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ─── Duration Section (Tanggal Mulai - Selesai) ──────────────────────────────
  Widget _buildDurationSection(bool isDark, bool isDesktop) {
    final diffDays = _eventEndDate.difference(_eventStartDate).inDays + 1;
    final startStr = '${_eventStartDate.day} ${_monthName(_eventStartDate.month)} ${_eventStartDate.year}';
    final endStr = '${_eventEndDate.day} ${_monthName(_eventEndDate.month)} ${_eventEndDate.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.event_available_rounded,
              size: 20,
              color: AppTheme.primaryPurple,
            ),
            const SizedBox(width: 8),
            Text(
              'Durasi Acara / Kegiatan Proyek',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$diffDays Hari',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Kreator dapat melihat durasi lengkap agar bisa mengajukan bayaran/gaji sesuai beban kerja.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.textMuted : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _eventStartDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _eventStartDate = picked;
                      if (_eventEndDate.isBefore(_eventStartDate)) {
                        _eventEndDate = _eventStartDate.add(const Duration(days: 2));
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.inputDark : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_outline_rounded, size: 20, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tanggal Mulai',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                            ),
                            Text(
                              startStr,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _eventEndDate,
                    firstDate: _eventStartDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _eventEndDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.inputDark : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.inputBorder : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 20, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tanggal Selesai',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                            ),
                            Text(
                              endStr,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── High-Value MoU Legal Meeting Section (>= 20 Jt) ─────────────────────────
  Widget _buildMoUMeetingSection(bool isDark, bool isDesktop) {
    final meetingDateStr = '${_meetingDate.day} ${_monthName(_meetingDate.month)} ${_meetingDate.year}';
    final meetingTimeStr = '${_meetingTime.hour.toString().padLeft(2, '0')}:${_meetingTime.minute.toString().padLeft(2, '0')} WIB';

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231D12) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚖️ Prosedur Hukum MoU Resmi (Anggaran >= Rp 20.000.000)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Wajib Hitam di Atas Putih Bersama Tim Marketing Kreavana',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Demi kepatuhan regulasi perbankan & hukum perdata Indonesia, dana proyek bernilai besar (>= 20 Jt) tidak diperkenankan ditransfer langsung ke sistem tanpa kontrak formal. Silakan tentukan jadwal & lokasi pertemuan dengan tim Marketing Kreavana:',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 16),

          // Tanggal & Jam Pertemuan
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _meetingDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setState(() => _meetingDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardBg : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal Pertemuan', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(meetingDateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _meetingTime,
                    );
                    if (picked != null) setState(() => _meetingTime = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardBg : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Waktu / Jam', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(meetingTimeStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pilihan Lokasi Pertemuan
          Text(
            'Lokasi Pertemuan:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Kantor Kreavana'),
                selected: _selectedMeetingPlaceType == 'office',
                onSelected: (_) => setState(() => _selectedMeetingPlaceType = 'office'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Pick Lokasi Klien / Map'),
                selected: _selectedMeetingPlaceType == 'client_location',
                onSelected: (_) => setState(() => _selectedMeetingPlaceType = 'client_location'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedMeetingPlaceType == 'office')
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardBg : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                children: [
                  Icon(Icons.business_rounded, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menara Kreatif Kreavana Lt. 8, Jl. Sudirman Kav. 24, Jakarta',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else
            TextField(
              controller: _meetingLocationController,
              decoration: const InputDecoration(
                hintText: 'Masukkan nama hotel, cafe, kantor atau koordinat lokasi pertemuan...',
                labelText: 'Detail Alamat Pertemuan MoU',
                prefixIcon: Icon(Icons.place_rounded, color: Colors.amber),
                border: OutlineInputBorder(),
                filled: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
        ],
      ),
    );
  }

  // ─── Escrow Protection Card (< 20 Jt) ───────────────────────────────────────
  Widget _buildEscrowProtectionCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🛡️ Sistem Escrow Rekber Kreavana Aktif',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Anggaran < Rp 20 Juta ditampung aman di Rekening Bersama (Escrow) Kreavana. Dana hanya akan dicairkan kepada kreator yang diterima setelah hasil kerja diverifikasi.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return (month >= 1 && month <= 12) ? months[month] : '';
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
              'Tentukan peran, tag spesialisasi, dan wilayah pelaksanaan agar kreator yang sesuai dapat langsung menemukan & melamar proyek Anda.',
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

class _AnimatedDropdown extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final fill = isDark ? AppTheme.inputDark : AppTheme.inputLight;
    final borderColor = isDark ? AppTheme.inputBorder : AppTheme.inputBorderLight;
    final dropdownCardBg = isDark ? const Color(0xFF1E1B2E) : Colors.white;

    final hasMatch = items.any((e) => e['value'] == value);
    final currentValue = hasMatch
        ? value
        : (items.isNotEmpty ? items.first['value'] as String : value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(currentValue),
          initialValue: currentValue,
          isExpanded: true,
          dropdownColor: dropdownCardBg,
          menuMaxHeight: 380,
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: fill,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(color: primary, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(color: theme.colorScheme.error, width: 1.8),
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
          items: items.map((item) {
            final itemValue = item['value'] as String;
            final itemLabel = (item['label'] ?? itemValue) as String;
            final itemIcon = item['icon'] as IconData?;
            final isSelected = itemValue == currentValue;

            return DropdownMenuItem<String>(
              value: itemValue,
              child: Row(
                children: [
                  if (itemIcon != null) ...[
                    Icon(
                      itemIcon,
                      size: 18,
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : (isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      itemLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppTheme.primaryPurple,
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
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
                color: isDark
                    ? AppTheme.inputBorder
                    : AppTheme.inputBorderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(
                color: isDark
                    ? AppTheme.inputBorder
                    : AppTheme.inputBorderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: const BorderSide(
                color: AppTheme.primaryPurple,
                width: 1.8,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: const BorderSide(color: AppTheme.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.8),
            ),
            errorStyle: const TextStyle(
              color: AppTheme.error,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
