import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/user_model.dart';
import '../../../services/admin_service.dart';
import '../../../screens/direct_message_screen.dart';

class AdminResolutionScreen extends StatefulWidget {
  final UserModel user;

  const AdminResolutionScreen({super.key, required this.user});

  @override
  State<AdminResolutionScreen> createState() => _AdminResolutionScreenState();
}

class _AdminResolutionScreenState extends State<AdminResolutionScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _disputes = [];

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);
    try {
      final data = await AdminService.getAssignedDisputes();
      if (mounted) {
        setState(() {
          _disputes = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        title: const Text(
          'Resolusi & Dispute',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDisputes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _disputes.isEmpty
          ? const Center(
              child: Text(
                'Tidak ada dispute yang ditugaskan kepada Anda saat ini.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _disputes.length,
              itemBuilder: (context, index) {
                final dispute = _disputes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  color: isDark ? AppTheme.cardBg : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                      ),
                    ),
                    title: Text(
                      'Dispute #${dispute['id'].toString().substring(0, 8).toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Tipe: ${dispute['case_type'] == 'marketplace_refund' ? 'Marketplace Refund' : 'Opportunity Cancellation'}',
                        ),
                        Text(
                          'Requester: ${dispute['requester']?['name'] ?? 'Unknown'}',
                        ),
                        Text(
                          'Status: ${dispute['status']?.toString().toUpperCase()}',
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        if (dispute['chat_id'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DirectMessageScreen(
                                currentUser: widget.user,
                                chatId: dispute['chat_id'],
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Chat belum dibuat untuk dispute ini.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Buka Chat Resolusi'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
