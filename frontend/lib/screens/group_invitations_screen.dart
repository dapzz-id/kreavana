import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../app/theme.dart';

class GroupInvitationsScreen extends StatefulWidget {
  const GroupInvitationsScreen({super.key});

  @override
  State<GroupInvitationsScreen> createState() => _GroupInvitationsScreenState();
}

class _GroupInvitationsScreenState extends State<GroupInvitationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    try {
      final invs = await ChatService.fetchInvitations();
      setState(() {
        _invitations = invs.map((i) => Map<String, dynamic>.from(i)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(String chatId, bool accept) async {
    try {
      await ChatService.respondInvitation(chatId, accept);
      _loadInvitations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'Undangan diterima' : 'Undangan ditolak')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal merespon undangan')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Undangan Grup'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invitations.isEmpty
              ? const Center(child: Text('Tidak ada undangan pending.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invitations.length,
                  itemBuilder: (context, index) {
                    final inv = _invitations[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.purple.shade100,
                              child: const Icon(Icons.group, color: Colors.purple),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inv['group_name'] ?? 'Grup Tidak Dikenal',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Mengundang Anda untuk bergabung'),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                                  onPressed: () => _respond(inv['chat_id'].toString(), true),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red, size: 32),
                                  onPressed: () => _respond(inv['chat_id'].toString(), false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
