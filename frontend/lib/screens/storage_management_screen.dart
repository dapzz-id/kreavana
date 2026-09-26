import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/theme.dart';
import '../models/user_model.dart';
import '../features/auth/services/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/app_errors.dart';
import '../widgets/app_breadcrumbs.dart';
import '../widgets/desktop_sidebar_layout.dart';
import 'main_navigation.dart';

class StorageManagementScreen extends StatefulWidget {
  final UserModel? user;

  const StorageManagementScreen({super.key, this.user});

  @override
  State<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  UserModel? _user;
  bool _isLoading = true;
  List<dynamic> _files = [];
  int _usedStorageBytes = 0;
  int _storageLimitBytes = 0;

  int _currentTab = 0; // 0: File Aktif, 1: Tempat Sampah
  int _trashCount = 0;
  int _trashBytes = 0;
  int _activeCount = 0;

  final Set<String> _selectedFileIds = {};

  String _selectedType = 'Semua';
  String _selectedCategory = 'Semua';
  String _selectedSort = 'Terbaru';

  final List<String> _types = ['Semua', 'Foto', 'Video', 'Audio', 'Dokumen'];
  final List<String> _categories = [
    'Semua',
    'Upload Saya',
    'Purchased Asset',
    'Chat Attachment',
    'Portfolio',
    'Marketplace',
  ];
  final List<String> _sorts = [
    'Terbaru',
    'Terlama',
    'A-Z',
    'Z-A',
    'Ukuran terbesar',
    'Ukuran terkecil',
  ];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    try {
      final res = await StorageService.getHistory(
        type: _selectedType,
        category: _selectedCategory,
        sort: _selectedSort,
        isTrash: _currentTab == 1,
      );
      final user = await AuthService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = user ?? _user;
        if (res.containsKey('files') && res['files']['data'] != null) {
          _files = res['files']['data'];
        } else {
          _files = [];
        }
        _usedStorageBytes =
            res['used_storage_bytes'] ?? user?.usedStorageBytes ?? _user?.usedStorageBytes ?? 0;
        _storageLimitBytes =
            res['storage_limit_bytes'] ?? user?.storageLimitBytes ?? _user?.storageLimitBytes ?? (512 * 1024 * 1024);
        _trashCount = res['trash_count'] ?? 0;
        _trashBytes = res['trash_bytes'] ?? 0;
        _activeCount = res['active_count'] ?? 0;
        _isLoading = false;
        // Clean up selected files that are no longer in list
        final currentIds = _files.map((f) => f['id']?.toString()).toSet();
        _selectedFileIds.removeWhere((id) => !currentIds.contains(id));
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal memuat data storage: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _switchTab(int index) {
    if (_currentTab == index) return;
    setState(() {
      _currentTab = index;
      _selectedFileIds.clear();
    });
    _loadStorageData();
  }

  bool get _isAllSelected =>
      _files.isNotEmpty && _selectedFileIds.length == _files.length;

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedFileIds.clear();
      } else {
        _selectedFileIds.clear();
        for (final f in _files) {
          final id = f['id']?.toString();
          if (id != null) _selectedFileIds.add(id);
        }
      }
    });
  }

  void _toggleFileSelection(String id) {
    setState(() {
      if (_selectedFileIds.contains(id)) {
        _selectedFileIds.remove(id);
      } else {
        _selectedFileIds.add(id);
      }
    });
  }

  Future<String> _resolveFileUrl(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    try {
      final token = await SecureStorageService().getToken();
      if (token != null && token.isNotEmpty && !rawUrl.contains('token=')) {
        final separator = rawUrl.contains('?') ? '&' : '?';
        return '$rawUrl${separator}token=$token';
      }
    } catch (_) {}
    return rawUrl;
  }

  Future<void> _viewFile(Map<String, dynamic> file) async {
    final fileName = file['original_name']?.toString() ?? 'File';
    final mimeType = file['mime_type']?.toString() ?? '';
    final fileUrl = await _resolveFileUrl(file['url']?.toString());

    if (fileUrl.isEmpty) {
      if (mounted) AppSnackbar.error(context, 'URL file tidak tersedia.');
      return;
    }

    final isImage = mimeType.startsWith('image/') ||
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.webp');

    if (isImage) {
      if (!mounted) return;
      _showImagePreviewDialog(fileName, fileUrl, file);
    } else {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        AppSnackbar.error(context, 'Tidak dapat membuka file di browser.');
      }
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    final rawDownloadUrl =
        file['download_url']?.toString() ?? file['url']?.toString();
    final downloadUrl = await _resolveFileUrl(rawDownloadUrl);

    if (downloadUrl.isEmpty) {
      if (mounted) AppSnackbar.error(context, 'URL unduhan tidak tersedia.');
      return;
    }

    final uri = Uri.parse(downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        AppSnackbar.success(
          context,
          'Mengunduh ${file['original_name'] ?? 'file'}...',
        );
      }
    } else {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal memulai unduhan file.');
      }
    }
  }

  void _showImagePreviewDialog(
    String fileName,
    String imageUrl,
    Map<String, dynamic> file,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.image_rounded,
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
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_formatBytes(file['size'] is int ? file['size'] : int.tryParse(file['size']?.toString() ?? '0') ?? 0)} • ${_getCategoryLabel(file['category']?.toString())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Image Container
              Flexible(
                child: Container(
                  color: isDark ? const Color(0xFF13111C) : const Color(0xFFF1F5F9),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: InteractiveViewer(
                    maxScale: 5.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppTheme.primaryPurple,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.broken_image_rounded,
                                size: 54,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Gagal memuat pratinjau gambar.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                label: const Text('Buka URL Langsung'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  launchUrl(
                                    Uri.parse(imageUrl),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Footer Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Format: ${(file['mime_type']?.toString() ?? 'image').toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Download Media'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _downloadFile(file);
                          },
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
    );
  }

  Future<void> _deleteSingleFile(String id, String fileName) async {
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pindahkan ke Sampah',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pindahkan file "$fileName" ke Tempat Sampah?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File yang berada di Tempat Sampah tetap menggunakan kuota Anda sampai dihapus secara permanen atau Anda mengosongkan tempat sampah.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Alasan penghapusan (opsional)',
                labelStyle: TextStyle(
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: const BorderSide(color: AppTheme.primaryPurple),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
            ),
            child: const Text('Pindahkan ke Sampah'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await StorageService.deleteFile(id, reason: reasonController.text);
      if (mounted) {
        AppSnackbar.success(context, 'File dipindahkan ke Tempat Sampah.');
        _selectedFileIds.remove(id);
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal memindahkan file: $e');
      }
    }
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFileIds.isEmpty) return;

    final count = _selectedFileIds.length;
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pindahkan Terpilih ke Sampah',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pindahkan $count file yang dipilih ke Tempat Sampah?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File tetap memakan kuota penyimpanan Anda selama berada di Tempat Sampah hingga dikosongkan atau dihapus permanen.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Alasan penghapusan (opsional)',
                labelStyle: TextStyle(
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: const BorderSide(color: AppTheme.primaryPurple),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
            ),
            child: Text('Pindahkan $count File'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await StorageService.deleteFiles(
        _selectedFileIds.toList(),
        reason: reasonController.text,
      );
      if (mounted) {
        final deletedCount = res['deleted_count'] ?? count;
        AppSnackbar.success(context, '$deletedCount file dipindahkan ke Tempat Sampah.');
        _selectedFileIds.clear();
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal memindahkan file: $e');
      }
    }
  }

  Future<void> _deleteAllFiles() async {
    if (_files.isEmpty) return;

    final allIds = _files
        .map((f) => f['id']?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toList();
    if (allIds.isEmpty) return;

    final count = allIds.length;
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pindahkan Semua ke Sampah?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan memindahkan SEMUA file ($count file) pada halaman ini ke Tempat Sampah.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File di tempat sampah tetap dihitung dalam kuota Anda sampai dihapus secara permanen.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Alasan penghapusan (opsional)',
                labelStyle: TextStyle(
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: const BorderSide(color: AppTheme.primaryPurple),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
            ),
            child: const Text('Pindahkan Semua ke Sampah'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await StorageService.deleteFiles(
        allIds,
        reason: reasonController.text,
      );
      if (mounted) {
        final deletedCount = res['deleted_count'] ?? count;
        AppSnackbar.success(context, 'Semua ($deletedCount) file dipindahkan ke Tempat Sampah.');
        _selectedFileIds.clear();
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal memindahkan file: $e');
      }
    }
  }

  Future<void> _restoreSingleFile(String id, String fileName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restore_from_trash_rounded,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pulihkan File',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Pulihkan file "$fileName" kembali ke daftar File Aktif?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Pulihkan File'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await StorageService.restoreFile(id);
      if (mounted) {
        AppSnackbar.success(context, 'File berhasil dipulihkan.');
        _selectedFileIds.remove(id);
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal memulihkan file: $e');
      }
    }
  }

  Future<void> _restoreSelectedFiles() async {
    if (_selectedFileIds.isEmpty) return;

    final count = _selectedFileIds.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restore_from_trash_rounded,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pulihkan File Terpilih',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Pulihkan $count file terpilih kembali ke daftar File Aktif?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text('Pulihkan $count File'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await StorageService.restoreFiles(_selectedFileIds.toList());
      if (mounted) {
        final restoredCount = res['restored_count'] ?? count;
        AppSnackbar.success(context, '$restoredCount file berhasil dipulihkan.');
        _selectedFileIds.clear();
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal memulihkan file: $e');
      }
    }
  }

  Future<void> _permanentDeleteSingleFile(String id, String fileName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Hapus Permanen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hapus file "$fileName" secara permanen?',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PERINGATAN: File fisik akan dihapus dari server dan kuota penyimpanan Anda akan dibebaskan. Tindakan ini TIDAK DAPAT DIBATALKAN!',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Ya, Hapus Permanen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await StorageService.permanentDeleteFile(id);
      if (mounted) {
        AppSnackbar.success(context, 'File berhasil dihapus permanen & kuota dibebaskan.');
        _selectedFileIds.remove(id);
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal menghapus file permanen: $e');
      }
    }
  }

  Future<void> _permanentDeleteSelectedFiles() async {
    if (_selectedFileIds.isEmpty) return;

    final count = _selectedFileIds.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Hapus Permanen Terpilih',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hapus $count file terpilih secara permanen?',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Semua file yang dipilih akan dihapus selamanya dari server dan kuota penyimpanan Anda akan dibebaskan. Tindakan ini tidak dapat diurungkan.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: Text('Hapus $count File Permanen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await StorageService.permanentDeleteFiles(_selectedFileIds.toList());
      if (mounted) {
        final deletedCount = res['deleted_count'] ?? count;
        AppSnackbar.success(context, '$deletedCount file berhasil dihapus permanen.');
        _selectedFileIds.clear();
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal menghapus file permanen: $e');
      }
    }
  }

  Future<void> _clearTrash() async {
    final count = _trashCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Kosongkan Tempat Sampah?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERINGATAN: Anda akan menghapus SEMUA file di Tempat Sampah ($count file).',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seluruh media yang berada di tempat sampah (${_formatBytes(_trashBytes)}) akan dihapus secara permanen dari server dan kuota penyimpanan Anda akan dibebaskan. Tindakan ini tidak dapat dibatalkan.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Ya, Kosongkan Tempat Sampah'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await StorageService.clearTrash();
      if (mounted) {
        final deletedCount = res['deleted_count'] ?? count;
        AppSnackbar.success(context, 'Tempat sampah berhasil dikosongkan ($deletedCount file dihapus permanen).');
        _selectedFileIds.clear();
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal mengosongkan tempat sampah: $e');
      }
    }
  }

  Future<void> _retryClone(String id) async {
    try {
      await StorageService.retryPurchasedClone(id);
      if (mounted) {
        AppSnackbar.success(context, 'File berhasil dialokasikan ke storage Anda.');
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Gagal mengalokasikan file: $e');
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  ({IconData icon, Color color, String label}) _getFileMeta(String? mimeType, String? name) {
    final mime = (mimeType ?? '').toLowerCase();
    final lowerName = (name ?? '').toLowerCase();

    if (mime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp')) {
      return (
        icon: Icons.image_rounded,
        color: const Color(0xFF0EA5E9),
        label: 'Foto',
      );
    }
    if (mime.startsWith('video/') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.mkv')) {
      return (
        icon: Icons.movie_creation_rounded,
        color: const Color(0xFFEC4899),
        label: 'Video',
      );
    }
    if (mime.startsWith('audio/') ||
        lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.wav') ||
        lowerName.endsWith('.m4a')) {
      return (
        icon: Icons.headphones_rounded,
        color: const Color(0xFFF59E0B),
        label: 'Audio',
      );
    }
    if (mime.contains('pdf') || lowerName.endsWith('.pdf')) {
      return (
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFFEF4444),
        label: 'PDF',
      );
    }
    if (mime.contains('word') ||
        mime.contains('document') ||
        lowerName.endsWith('.doc') ||
        lowerName.endsWith('.docx') ||
        lowerName.endsWith('.txt')) {
      return (
        icon: Icons.description_rounded,
        color: const Color(0xFF3B82F6),
        label: 'Dokumen',
      );
    }
    if (lowerName.endsWith('.zip') || lowerName.endsWith('.rar') || lowerName.endsWith('.7z')) {
      return (
        icon: Icons.folder_zip_rounded,
        color: const Color(0xFF8B5CF6),
        label: 'Arsip',
      );
    }
    return (
      icon: Icons.insert_drive_file_rounded,
      color: const Color(0xFF64748B),
      label: 'File',
    );
  }

  String _getCategoryLabel(String? cat) {
    if (cat == null || cat.isEmpty) return 'Lainnya';
    switch (cat.toLowerCase()) {
      case 'creator_upload':
        return 'Upload Saya';
      case 'purchased_asset':
        return 'Asset Dibeli';
      case 'chat_attachment':
        return 'Lampiran Chat';
      case 'portfolio':
        return 'Portofolio';
      case 'marketplace_original':
      case 'marketplace_watermarked':
        return 'Marketplace';
      case 'ktp':
        return 'Verifikasi KTP';
      case 'selfie':
        return 'Selfie KTP';
      case 'posters':
        return 'Poster Proyek';
      default:
        return cat.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final content = Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        toolbarHeight: 72,
        titleSpacing: isDesktop ? 32 : 16,
        elevation: 0,
        title: const Text(
          'Manajemen Storage',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStorageData,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 40 : 16,
          16,
          isDesktop ? 40 : 16,
          80,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumbs
                AppBreadcrumbs(
                  items: [
                    BreadcrumbItem(
                      label: 'Beranda',
                      icon: Icons.home_rounded,
                      onTap: () {
                        if (_user != null) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MainNavigation(
                                initialUser: _user!,
                                initialIndex: 0,
                              ),
                            ),
                            (r) => false,
                          );
                        }
                      },
                    ),
                    BreadcrumbItem(
                      label: 'Pengaturan',
                      icon: Icons.settings_rounded,
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else if (_user != null) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MainNavigation(
                                initialUser: _user!,
                                initialIndex: 8,
                              ),
                            ),
                            (r) => false,
                          );
                        }
                      },
                    ),
                    const BreadcrumbItem(
                      label: 'Manajemen Storage',
                      icon: Icons.storage_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hero / Storage Capacity Card
                _buildStorageOverviewCard(isDark, isDesktop),
                const SizedBox(height: 20),

                // Tabs Selector (File Aktif vs Tempat Sampah)
                _buildTabs(isDark, isDesktop),
                const SizedBox(height: 16),

                // Educational Banner if on Trash Tab
                if (_currentTab == 1) ...[
                  _buildTrashInfoBanner(isDark, isDesktop),
                  const SizedBox(height: 16),
                ],

                // Filters & Sorting Toolbar
                _buildToolbar(isDark, isDesktop),
                const SizedBox(height: 16),

                // Selection / Batch Action Bar
                if (_files.isNotEmpty) ...[
                  _buildBatchActionBar(isDark, isDesktop),
                  const SizedBox(height: 14),
                ],

                // Files Content Section
                _buildFileListSection(isDark),
              ],
            ),
          ),
        ),
      ),
    );

    if (isDesktop && _user != null) {
      return DesktopSidebarLayout(
        user: _user!,
        activeRoute: 'pengaturan',
        child: content,
      );
    }

    return content;
  }

  Widget _buildStorageOverviewCard(bool isDark, bool isDesktop) {
    final percentage = _storageLimitBytes > 0
        ? (_usedStorageBytes / _storageLimitBytes)
        : 0.0;
    final clampedPercent = percentage.clamp(0.0, 1.0);
    final remainingBytes = max(0, _storageLimitBytes - _usedStorageBytes);
    final percentText = (clampedPercent * 100).toStringAsFixed(1);

    Color progressColor;
    if (clampedPercent >= 0.9) {
      progressColor = const Color(0xFFEF4444);
    } else if (clampedPercent >= 0.75) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = AppTheme.primaryPurple;
    }

    final tier = (_user?.subscriptionTier ?? 'free').toLowerCase();
    String tierLabel;
    String tierQuotaDescription;
    if (tier == 'super') {
      tierLabel = 'SUPER PLAN';
      tierQuotaDescription = 'Kuota 20 GB • Layanan Prioritas & Boost 5x';
    } else if (tier == 'pro') {
      tierLabel = 'PRO PLAN';
      tierQuotaDescription = 'Kuota 10 GB • Fitur AI & Boost 2x';
    } else if (tier == 'plus') {
      tierLabel = 'PLUS PLAN';
      tierQuotaDescription = 'Kuota 3 GB • Rekomendasi AI & Boost 1.5x';
    } else {
      tierLabel = 'FREE (TIDAK BERLANGGANAN)';
      tierQuotaDescription = 'Kuota bawaan 512 MB • Upgrade untuk kuota 3 GB / 10 GB / 20 GB';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_done_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Kapasitas Penyimpanan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            tierLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tierQuotaDescription,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (_user != null) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: Text(
                    tier == 'super' ? 'Kelola Paket' : 'Upgrade Kuota',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MainNavigation(
                          initialUser: _user!,
                          initialIndex: 7,
                        ),
                      ),
                      (r) => false,
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Big usage stat & percentage
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _formatBytes(_usedStorageBytes),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    TextSpan(
                      text: ' / ${_formatBytes(_storageLimitBytes)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentText% Terpakai',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custom rounded progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 10,
              width: double.infinity,
              color: isDark ? const Color(0xFF1E1B30) : const Color(0xFFE2E8F0),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: clampedPercent,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: clampedPercent >= 0.9
                          ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                          : clampedPercent >= 0.75
                              ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                              : [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4 Indicator Pills
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _buildIndicatorPill(
                color: progressColor,
                label: 'Terpakai',
                value: _formatBytes(_usedStorageBytes),
                isDark: isDark,
              ),
              _buildIndicatorPill(
                color: const Color(0xFF10B981),
                label: 'Tersisa',
                value: _formatBytes(remainingBytes),
                isDark: isDark,
              ),
              _buildIndicatorPill(
                color: const Color(0xFF6366F1),
                label: 'Total Kuota',
                value: _formatBytes(_storageLimitBytes),
                isDark: isDark,
              ),
              _buildIndicatorPill(
                color: const Color(0xFF94A3B8),
                label: 'File Aktif',
                value: '$_activeCount file',
                isDark: isDark,
              ),
              if (_trashBytes > 0 || _trashCount > 0)
                _buildIndicatorPill(
                  color: const Color(0xFFF59E0B),
                  label: 'Di Tempat Sampah',
                  value: '${_formatBytes(_trashBytes)} ($_trashCount file)',
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorPill({
    required Color color,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(bool isDark, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A162B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
        ),
      ),
      child: Row(
        mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
        children: [
          _buildTabItem(
            index: 0,
            title: 'File Aktif',
            count: _activeCount,
            icon: Icons.folder_rounded,
            isDark: isDark,
            isDesktop: isDesktop,
          ),
          const SizedBox(width: 4),
          _buildTabItem(
            index: 1,
            title: 'Tempat Sampah',
            count: _trashCount,
            icon: Icons.delete_outline_rounded,
            isDark: isDark,
            isDesktop: isDesktop,
            isTrash: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    required bool isDark,
    required bool isDesktop,
    bool isTrash = false,
  }) {
    final isSelected = _currentTab == index;
    final itemContent = InkWell(
      onTap: () => _switchTab(index),
      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.primaryPurple : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                    : (isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppTheme.primaryPurple.withValues(alpha: 0.12))
                    : (isTrash && count > 0
                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                        : (isDark
                            ? const Color(0xFF28233D)
                            : const Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? Colors.white : AppTheme.primaryPurple)
                      : (isTrash && count > 0
                          ? const Color(0xFFEF4444)
                          : (isDark ? AppTheme.textMuted : const Color(0xFF64748B))),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return itemContent;
    }
    return Expanded(child: itemContent);
  }

  Widget _buildTrashInfoBanner(bool isDark, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF451A03).withValues(alpha: 0.35)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.4 : 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File di Tempat Sampah tetap menggunakan kuota Anda',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Selagi belum dihapus permanen, file di tempat sampah (${_formatBytes(_trashBytes)}) tetap memotong kuota penyimpanan Anda. Kosongkan tempat sampah untuk membebaskan ruang penyimpanan.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          if (_trashCount > 0) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('Kosongkan Sampah'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
              ),
              onPressed: _clearTrash,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
        ),
        boxShadow: isDark ? null : AppTheme.cardShadowLight,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDropdownFilter(
                label: 'Tipe',
                icon: Icons.category_outlined,
                value: _selectedType,
                items: _types,
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedType = v);
                    _loadStorageData();
                  }
                },
              ),
              _buildDropdownFilter(
                label: 'Kategori',
                icon: Icons.folder_open_outlined,
                value: _selectedCategory,
                items: _categories,
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedCategory = v);
                    _loadStorageData();
                  }
                },
              ),
              _buildDropdownFilter(
                label: 'Urutan',
                icon: Icons.sort_rounded,
                value: _selectedSort,
                items: _sorts,
                isDark: isDark,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedSort = v);
                    _loadStorageData();
                  }
                },
              ),
            ],
          ),
          Text(
            '${_files.length} file ditemukan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B30) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              dropdownColor: isDark ? AppTheme.cardDark : Colors.white,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              items: items
                  .map(
                    (it) => DropdownMenuItem(
                      value: it,
                      child: Text(it),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActionBar(bool isDark, bool isDesktop) {
    final selectedCount = _selectedFileIds.length;
    final isTrashTab = _currentTab == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selectedCount > 0
            ? (isDark
                ? const Color(0xFF2E1065).withValues(alpha: 0.5)
                : const Color(0xFFF5F3FF))
            : (isDark ? const Color(0xFF1E1B30) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: selectedCount > 0
              ? AppTheme.primaryPurple.withValues(alpha: 0.4)
              : (isDark ? AppTheme.inputBorder : AppTheme.dividerLight),
        ),
      ),
      child: Row(
        children: [
          // Select All Checkbox
          InkWell(
            onTap: _toggleSelectAll,
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _isAllSelected,
                  activeColor: AppTheme.primaryPurple,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (_) => _toggleSelectAll(),
                ),
                Text(
                  _isAllSelected ? 'Batalkan Semua' : 'Pilih Semua (${_files.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          if (selectedCount > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$selectedCount Terpilih',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryPurple,
                ),
              ),
            ),
          ],

          const Spacer(),

          // Batch Action Buttons
          if (isTrashTab) ...[
            if (selectedCount > 0) ...[
              TextButton(
                onPressed: () => setState(() => _selectedFileIds.clear()),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                label: Text('Pulihkan ($selectedCount)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                ),
                onPressed: _restoreSelectedFiles,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: Text('Hapus Permanen ($selectedCount)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                ),
                onPressed: _permanentDeleteSelectedFiles,
              ),
            ] else ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text('Kosongkan Tempat Sampah'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                ),
                onPressed: _clearTrash,
              ),
            ],
          ] else ...[
            if (selectedCount > 0) ...[
              TextButton(
                onPressed: () => setState(() => _selectedFileIds.clear()),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text('Pindahkan ke Sampah ($selectedCount)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                ),
                onPressed: _deleteSelectedFiles,
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  size: 16,
                  color: Color(0xFFEF4444),
                ),
                label: const Text(
                  'Pindahkan Semua ke Sampah',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                ),
                onPressed: _deleteAllFiles,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFileListSection(bool isDark) {
    final isTrashTab = _currentTab == 1;

    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isTrashTab ? 'Memuat tempat sampah...' : 'Memuat daftar file...',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isTrashTab ? const Color(0xFF10B981) : AppTheme.primaryPurple)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isTrashTab ? Icons.auto_delete_outlined : Icons.folder_open_rounded,
                size: 40,
                color: isTrashTab ? const Color(0xFF10B981) : AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isTrashTab ? 'Tempat Sampah Bersih' : 'Belum Ada File di Kategori Ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isTrashTab
                  ? 'Tidak ada file di tempat sampah. File yang Anda hapus akan masuk ke sini dan tetap memakan kuota hingga dihapus secara permanen.'
                  : 'Setiap media yang Anda unggah (foto portofolio, chat, poster, verifikasi) otomatis dicatat di sini.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_selectedType != 'Semua' || _selectedCategory != 'Semua')
              OutlinedButton.icon(
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Reset Filter'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  side: BorderSide(
                    color: isDark ? AppTheme.inputBorder : AppTheme.dividerLight,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _selectedType = 'Semua';
                    _selectedCategory = 'Semua';
                  });
                  _loadStorageData();
                },
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final file = _files[index];
        final isPending = file['status'] == 'pending_storage';
        final fileName = file['original_name']?.toString() ?? 'File Tanpa Nama';
        final fileMeta = _getFileMeta(file['mime_type']?.toString(), fileName);
        final categoryLabel = _getCategoryLabel(file['category']?.toString());
        final sizeText = _formatBytes(
          file['size'] is int
              ? file['size']
              : int.tryParse(file['size']?.toString() ?? '0') ?? 0,
        );
        final dateText = _formatDate(file['created_at']?.toString());
        final deletedAtText = file['deleted_at'] != null ? _formatDate(file['deleted_at']?.toString()) : null;
        final fileId = file['id']?.toString() ?? '';
        final isSelected = _selectedFileIds.contains(fileId);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF2E1065).withValues(alpha: 0.35)
                    : const Color(0xFFFAF5FF))
                : (isPending
                    ? (isDark ? const Color(0xFF2D2318) : const Color(0xFFFFFBEB))
                    : (isDark ? AppTheme.cardDark : Colors.white)),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryPurple
                  : (isPending
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                      : (isDark ? AppTheme.inputBorder : AppTheme.dividerLight)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isDark ? null : AppTheme.cardShadowLight,
          ),
          child: Row(
            children: [
              // Checkbox selection
              Checkbox(
                value: isSelected,
                activeColor: AppTheme.primaryPurple,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => _toggleFileSelection(fileId),
              ),
              const SizedBox(width: 6),

              // File type icon container
              InkWell(
                onTap: () => _viewFile(file),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: fileMeta.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    border: Border.all(
                      color: fileMeta.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    fileMeta.icon,
                    color: fileMeta.color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // File Details
              Expanded(
                child: InkWell(
                  onTap: () => _toggleFileSelection(fileId),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E1B30)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.inputBorder
                                    : AppTheme.dividerLight,
                              ),
                            ),
                            child: Text(
                              categoryLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.textMuted
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Text(
                            '•',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textMuted
                                  : AppTheme.textMutedLight,
                            ),
                          ),
                          Text(
                            sizeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '•',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textMuted
                                  : AppTheme.textMutedLight,
                            ),
                          ),
                          Text(
                            dateText,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.textMuted
                                  : AppTheme.textMutedLight,
                            ),
                          ),
                          if (isTrashTab && deletedAtText != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Dihapus: $deletedAtText',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (isPending) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 12,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Storage Penuh (Tertunda)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Action Buttons: View, Download, Restore, Delete
              if (isPending)
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Simpan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                  ),
                  onPressed: () => _retryClone(fileId),
                )
              else if (isTrashTab)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View Media Button
                    IconButton(
                      tooltip: 'Lihat Media / Pratinjau',
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: AppTheme.primaryPurple,
                        size: 20,
                      ),
                      hoverColor:
                          AppTheme.primaryPurple.withValues(alpha: 0.1),
                      onPressed: () => _viewFile(file),
                    ),
                    // Download Button
                    IconButton(
                      tooltip: 'Download File',
                      icon: Icon(
                        Icons.download_rounded,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                        size: 20,
                      ),
                      hoverColor:
                          AppTheme.primaryPurple.withValues(alpha: 0.1),
                      onPressed: () => _downloadFile(file),
                    ),
                    // Restore Button
                    IconButton(
                      tooltip: 'Pulihkan File',
                      icon: const Icon(
                        Icons.restore_from_trash_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                      hoverColor:
                          const Color(0xFF10B981).withValues(alpha: 0.1),
                      onPressed: () => _restoreSingleFile(fileId, fileName),
                    ),
                    // Permanent Delete Button
                    IconButton(
                      tooltip: 'Hapus Permanen',
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      hoverColor:
                          const Color(0xFFDC2626).withValues(alpha: 0.1),
                      onPressed: () => _permanentDeleteSingleFile(fileId, fileName),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View Media Button
                    IconButton(
                      tooltip: 'Lihat Media / Pratinjau',
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: AppTheme.primaryPurple,
                        size: 20,
                      ),
                      hoverColor:
                          AppTheme.primaryPurple.withValues(alpha: 0.1),
                      onPressed: () => _viewFile(file),
                    ),
                    // Download Button
                    IconButton(
                      tooltip: 'Download File',
                      icon: Icon(
                        Icons.download_rounded,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                        size: 20,
                      ),
                      hoverColor:
                          AppTheme.primaryPurple.withValues(alpha: 0.1),
                      onPressed: () => _downloadFile(file),
                    ),
                    // Move to Trash Button
                    IconButton(
                      tooltip: 'Pindahkan ke Sampah',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      hoverColor:
                          const Color(0xFFEF4444).withValues(alpha: 0.1),
                      onPressed: () => _deleteSingleFile(fileId, fileName),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

