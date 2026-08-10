import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../features/auth/services/auth_service.dart';
import '../services/storage_service.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  UserModel? _user;
  bool _isLoading = true;
  List<dynamic> _files = [];
  int _usedStorageBytes = 0;
  int _storageLimitBytes = 0;

  String _selectedType = 'Semua';
  String _selectedCategory = 'Semua';
  String _selectedSort = 'Terbaru';

  final List<String> _types = ['Semua', 'Foto', 'Video', 'Audio', 'Dokumen'];
  final List<String> _categories = ['Semua', 'Upload Saya', 'Purchased Asset', 'Chat Attachment', 'Portfolio', 'Marketplace'];
  final List<String> _sorts = ['Terbaru', 'Terlama', 'A-Z', 'Z-A', 'Ukuran terbesar', 'Ukuran terkecil'];

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    try {
      final res = await StorageService.getHistory(
        type: _selectedType,
        category: _selectedCategory,
        sort: _selectedSort,
      );
      final user = await AuthService.getCurrentUser();
      setState(() {
        _user = user;
        if (res.containsKey('files') && res['files']['data'] != null) {
          _files = res['files']['data'];
        } else {
           _files = [];
        }
        _usedStorageBytes = res['used_storage_bytes'] ?? user?.usedStorageBytes ?? 0;
        _storageLimitBytes = res['storage_limit_bytes'] ?? user?.storageLimitBytes ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteFile(String id) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Apakah Anda yakin ingin menghapus file ini? Fitur yang menggunakan file ini akan menampilkan "Media telah dihapus".'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan menghapus (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await StorageService.deleteFile(id, reason: reasonController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File berhasil dihapus')));
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus file: $e')));
      }
    }
  }

  Future<void> _retryClone(String id) async {
    try {
      await StorageService.retryPurchasedClone(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File berhasil disimpan ke storage.')));
        _loadStorageData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal retry: $e')));
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _files.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return const Scaffold(body: Center(child: Text('Gagal memuat data')));
    }

    final percentage = _storageLimitBytes > 0 ? (_usedStorageBytes / _storageLimitBytes) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Storage'),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penggunaan Storage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.grey.shade200,
              color: percentage > 0.9 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_formatBytes(_usedStorageBytes)} terpakai', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${_formatBytes(_storageLimitBytes)} total'),
              ],
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: _selectedType,
                    items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedType = v!);
                      _loadStorageData();
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    items: _categories.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedCategory = v!);
                      _loadStorageData();
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedSort,
                    items: _sorts.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedSort = v!);
                      _loadStorageData();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                  ? const Center(child: Text('Belum ada file yang diunggah.'))
                  : ListView.builder(
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final isPending = file['status'] == 'pending_storage';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isPending ? Colors.grey.shade100 : null,
                          child: ListTile(
                            leading: Icon(isPending ? Icons.warning : Icons.insert_drive_file, color: isPending ? Colors.orange : null),
                            title: Text(file['original_name'] ?? 'Unknown File', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${file['category'] ?? '-'} • ${_formatBytes(file['size'] ?? 0)}'),
                                if (isPending)
                                  const Text('Status: Storage penuh', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                            trailing: isPending 
                              ? TextButton(
                                  onPressed: () => _retryClone(file['id']),
                                  child: const Text('Simpan ke Storage Saya'),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteFile(file['id']),
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
}
