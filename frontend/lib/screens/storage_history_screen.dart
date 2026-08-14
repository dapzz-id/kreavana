import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StorageHistoryScreen extends StatefulWidget {
  const StorageHistoryScreen({super.key});

  @override
  State<StorageHistoryScreen> createState() => _StorageHistoryScreenState();
}

class _StorageHistoryScreenState extends State<StorageHistoryScreen> {
  bool _isLoading = true;
  int _usedStorage = 0;
  int _storageLimit = 1; // avoid division by zero
  int _remainingStorage = 0;
  List<dynamic> _files = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/storage/history');
      if (mounted) {
        setState(() {
          _usedStorage = response['used_storage_bytes'] ?? 0;
          _storageLimit = response['storage_limit_bytes'] ?? 1;
          _remainingStorage = response['remaining_storage_bytes'] ?? 0;
          _files = response['files']?['data'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat history storage: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus File?'),
        content: const Text('File ini akan dihapus secara permanen.'),
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
      await ApiService.delete('/storage/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File berhasil dihapus.')),
        );
        _fetchHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus file: $e')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStorageHeader(),
                const Divider(),
                Expanded(child: _buildFilesList()),
              ],
            ),
    );
  }

  Widget _buildStorageHeader() {
    final progress = (_usedStorage / _storageLimit).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Storage Usage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            color: progress > 0.9 ? Colors.red : Colors.blue,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Terpakai: ${_formatBytes(_usedStorage)}'),
              Text('Sisa: ${_formatBytes(_remainingStorage)}'),
            ],
          ),
          Text('Limit: ${_formatBytes(_storageLimit)}', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    if (_files.isEmpty) {
      return const Center(child: Text('Belum ada file.'));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        return ListTile(
          title: Text(file['original_name'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${_formatBytes(file['size'] ?? 0)} • ${file['category']} • ${file['visibility']}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteFile(file['id']),
          ),
        );
      },
    );
  }
}
