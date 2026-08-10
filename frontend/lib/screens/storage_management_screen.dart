import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../features/auth/services/auth_service.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    final user = await AuthService.getCurrentUser();
    // In a real implementation, we would also fetch the list of files from StorageController.
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return const Scaffold(body: Center(child: Text('Gagal memuat data')));
    }

    final used = _user!.usedStorageBytes;
    final total = _user!.storageLimitBytes;
    final percentage = total > 0 ? (used / total) : 0.0;

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
              value: percentage,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.grey.shade200,
              color: percentage > 0.9 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_formatBytes(used)} terpakai', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${_formatBytes(total)} total'),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'File yang Diunggah',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: 0, // MOCK for now
                itemBuilder: (context, index) {
                  return const ListTile(
                    title: Text('File Dummy'),
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
