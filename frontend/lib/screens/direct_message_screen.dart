import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/chat_service.dart';

class DirectMessageScreen extends StatefulWidget {
  const DirectMessageScreen({super.key});

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  // State untuk melacak obrolan yang dipilih di tampilan Master-Detail (Desktop/Web)
  Map<String, dynamic>? selectedChat;
  final GlobalKey<ChatListSectionState> chatListKey = GlobalKey<ChatListSectionState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Jika lebar layar besar (Web/Tablet/Desktop), gunakan Master-Detail layout
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                SizedBox(
                  width: 380,
                  child: ChatListSection(
                    key: chatListKey,
                    onChatSelected: (chat) {
                      setState(() {
                        selectedChat = chat;
                      });
                    },
                    selectedChat: selectedChat,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: selectedChat == null
                      ? _buildEmptyState(context)
                      : ChatDetailSection(
                          chat: selectedChat!,
                          onMessageSent: () {
                            chatListKey.currentState?.loadChats();
                          },
                          onChatLeft: () {
                            setState(() {
                              selectedChat = null;
                            });
                            chatListKey.currentState?.loadChats();
                          },
                        ),
                ),
              ],
            );
          } else {
            // Jika lebar layar kecil (Mobile), hanya tampilkan daftar chat
            return ChatListSection(
              key: chatListKey,
              onChatSelected: (chat) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: ChatDetailSection(
                        chat: chat, 
                        isMobile: true,
                        onMessageSent: () {
                          chatListKey.currentState?.loadChats();
                        },
                        onChatLeft: () {
                          chatListKey.currentState?.loadChats();
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 100, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Kreavana Chat',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih obrolan untuk mulai mengirim pesan',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class ChatListSection extends StatefulWidget {
  final Function(Map<String, dynamic>) onChatSelected;
  final Map<String, dynamic>? selectedChat;

  const ChatListSection({super.key, required this.onChatSelected, this.selectedChat});

  @override
  State<ChatListSection> createState() => ChatListSectionState();
}

class ChatListSectionState extends State<ChatListSection> {
  String viewType = 'personal';
  String searchQuery = '';
  bool isLoading = true;
  bool isSearching = false;

  List<Map<String, dynamic>> _personalChats = [];
  List<Map<String, dynamic>> _groupChats = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    loadChats();
  }

  Future<void> loadChats() async {
    try {
      final chats = await ChatService.fetchChats();
      final invs = await ChatService.fetchInvitations();
      setState(() {
        _personalChats = chats.where((c) => c['isGroup'] == false).map((c) => Map<String, dynamic>.from(c)).toList();
        _groupChats = chats.where((c) => c['isGroup'] == true).map((c) => Map<String, dynamic>.from(c)).toList();
        _invitations = invs.map((i) => Map<String, dynamic>.from(i)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading chats: $e');
    }
  }

  void _showInvitationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undangan Grup'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _invitations.length,
            itemBuilder: (context, index) {
              final inv = _invitations[index];
              return ListTile(
                title: Text(inv['group_name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        ChatService.respondInvitation(inv['chat_id'].toString(), true).then((_) {
                          Navigator.pop(context);
                          loadChats();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        ChatService.respondInvitation(inv['chat_id'].toString(), false).then((_) {
                          Navigator.pop(context);
                          loadChats();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buat Grup Baru'),
        content: TextField(
          controller: groupNameController,
          decoration: const InputDecoration(
            labelText: 'Nama Grup',
            hintText: 'Masukkan nama grup',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
                if (groupNameController.text.isNotEmpty) {
                  ChatService.createGroup(groupNameController.text).then((newGroup) {
                    setState(() {
                      _groupChats.insert(0, Map<String, dynamic>.from(newGroup));
                    });
                    widget.onChatSelected(Map<String, dynamic>.from(newGroup));
                  }).catchError((e) {
                    print('Error creating group: $e');
                  });
                  Navigator.pop(context);
                }
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var baseChats = viewType == 'personal' ? _personalChats : _groupChats;
    var chats = List<Map<String, dynamic>>.from(baseChats);
    List<Map<String, dynamic>> additionalResults = [];

    if (searchQuery.isNotEmpty) {
      chats = chats.where((chat) => chat['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
      
      if (viewType == 'personal') {
          // Tambahkan hasil pencarian dari database yang belum ada di daftar chat
          for (var user in _searchResults) {
              bool exists = _personalChats.any((c) => c['name'] == user['name']);
              if (!exists) {
                  additionalResults.add({
                      'isNewUser': true,
                      'userId': user['id'],
                      'name': user['name'],
                      'email': user['email']
                  });
              }
          }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Obrolan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_invitations.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showInvitationsDialog,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('${_invitations.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Pencarian Material 3
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              hintText: 'Cari akun atau pesan...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.search),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              onChanged: (value) async {
                setState(() {
                  searchQuery = value;
                  isSearching = true;
                });
                if (value.isNotEmpty) {
                    try {
                        final results = await ChatService.searchUsers(value);
                        setState(() {
                            _searchResults = results.map((r) => Map<String, dynamic>.from(r)).toList();
                            isSearching = false;
                        });
                    } catch (e) {
                        setState(() => isSearching = false);
                    }
                } else {
                    setState(() {
                        _searchResults = [];
                        isSearching = false;
                    });
                }
              },
            ),
          ),
          // Pemilihan Tipe Obrolan menggunakan SegmentedButton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'personal',
                      label: Text('Personal'),
                      icon: Icon(Icons.person_outline)),
                  ButtonSegment(
                      value: 'group',
                      label: Text('Grup'),
                      icon: Icon(Icons.groups_outlined)),
                ],
                selected: {viewType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    viewType = newSelection.first;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Daftar Obrolan
          Expanded(
            child: isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              itemCount: chats.length + additionalResults.length,
              itemBuilder: (context, index) {
                if (index >= chats.length) {
                  final user = additionalResults[index - chats.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(Icons.person_add, color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      title: Text('Mulai obrolan dengan "${user['name']}"'),
                      subtitle: Text(user['email']),
                      onTap: () async {
                          try {
                              final newChat = await ChatService.startPersonalChat(user['userId']);
                              setState(() {
                                  _personalChats.insert(0, Map<String, dynamic>.from(newChat));
                                  searchQuery = '';
                                  _searchResults = [];
                              });
                              widget.onChatSelected(Map<String, dynamic>.from(newChat));
                          } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gagal memulai obrolan')),
                              );
                          }
                      },
                    ),
                  );
                }

                final chat = chats[index];
                final isSelected = widget.selectedChat?['id'] == chat['id'];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: chat['isGroup']
                              ? Theme.of(context).colorScheme.tertiaryContainer
                              : Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            chat['isGroup'] ? Icons.group : Icons.person,
                            color: chat['isGroup']
                                ? Theme.of(context).colorScheme.onTertiaryContainer
                                : Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        if (chat['unread'])
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Theme.of(context).colorScheme.surface, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      chat['name'],
                      style: TextStyle(
                        fontWeight: chat['unread'] ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      chat['lastMessage'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: chat['unread']
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: chat['unread'] ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    trailing: Text(
                      chat['time'],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: chat['unread']
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: chat['unread'] ? FontWeight.bold : FontWeight.normal,
                          ),
                    ),
                    onTap: () => widget.onChatSelected(chat),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: viewType == 'group' ? _showCreateGroupDialog : () {},
        child: Icon(viewType == 'group' ? Icons.group_add : Icons.chat),
      ),
    );
  }
}

class ChatDetailSection extends StatefulWidget {
  final Map<String, dynamic> chat;
  final bool isMobile;
  final VoidCallback? onMessageSent;
  final VoidCallback? onChatLeft;

  const ChatDetailSection({super.key, required this.chat, this.isMobile = false, this.onMessageSent, this.onChatLeft});

  @override
  State<ChatDetailSection> createState() => _ChatDetailSectionState();
}

class _ChatDetailSectionState extends State<ChatDetailSection> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void didUpdateWidget(ChatDetailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat['id'] != widget.chat['id']) {
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    setState(() => isLoading = true);
    try {
      final msgs = await ChatService.fetchMessages(widget.chat['id'].toString());
      setState(() {
        _messages = msgs.map((m) => Map<String, dynamic>.from(m)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error loading messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final text = _messageController.text;
      _messageController.clear();
      try {
        final newMsg = await ChatService.sendMessage(widget.chat['id'].toString(), text);
        setState(() {
          _messages.insert(0, Map<String, dynamic>.from(newMsg));
        });
        widget.onMessageSent?.call();
      } catch (e) {
        print('Error sending message: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: widget.isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: InkWell(
          onTap: () {
            if (widget.chat['isGroup']) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupInfoScreen(
                    chat: widget.chat,
                    onGroupLeft: () {
                      if (widget.isMobile) {
                        Navigator.pop(context);
                      }
                      widget.onChatLeft?.call();
                    },
                  ),
                ),
              );
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: widget.chat['isGroup']
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.primaryContainer,
                child: Icon(
                  widget.chat['isGroup'] ? Icons.group : Icons.person,
                  size: 20,
                  color: widget.chat['isGroup']
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat['name'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.chat['isGroup'] ? 'Ketuk untuk info grup' : 'Online',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallScreen(chat: widget.chat, isVideo: false),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallScreen(chat: widget.chat, isVideo: true),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
          if (widget.isMobile) const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              child: isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isMe = message['isMe'];

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: isMe
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                          bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(20),
                        ),
                        boxShadow: [
                          if (!isMe)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            message['text'],
                            style: TextStyle(
                              color: isMe
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message['time'],
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? theme.colorScheme.onPrimary.withOpacity(0.7)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: theme.colorScheme.primary,
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: null,
                  elevation: 0,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CallScreen extends StatefulWidget {
  final Map<String, dynamic> chat;
  final bool isVideo;

  const CallScreen({super.key, required this.chat, this.isVideo = false});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late bool isVideoActive;
  bool isMuted = false;
  bool isSpeaker = false;
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    isVideoActive = widget.isVideo;
    // Jika video call, otomatis loudspeaker menyala
    if (isVideoActive) {
      isSpeaker = true;
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first);

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _toggleMute() => setState(() => isMuted = !isMuted);
  void _toggleSpeaker() => setState(() => isSpeaker = !isSpeaker);
  void _toggleVideo() {
    setState(() {
      isVideoActive = !isVideoActive;
      if (isVideoActive) {
        isSpeaker = true;
        if (_cameraController == null) _initializeCamera();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Dinamis
          if (isVideoActive)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black87,
                image: DecorationImage(
                  // Gambar latar belakang simulasi kamera video call
                  image: NetworkImage('https://images.unsplash.com/photo-1573164713988-8665fc963095?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceVariant,
                  ],
                ),
              ),
            ),
            
          // PIP (Picture-in-Picture) Kamera Asli Kita saat Video Call
          if (isVideoActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black54,
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _cameraController != null && _cameraController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: 110 / 160,
                          child: CameraPreview(_cameraController!),
                        )
                      : const Center(
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                        ),
                ),
              ),
            ),

          // Konten Utama
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  widget.chat['name'],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: isVideoActive ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '00:24', // Simulasi durasi panggilan berjalan
                  style: TextStyle(
                    color: isVideoActive ? Colors.white70 : theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isVideoActive) ...[
                  const SizedBox(height: 80),
                  // Avatar Profile membesar saat Voice Call
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: theme.colorScheme.primary,
                        backgroundImage: widget.chat['isGroup'] 
                            ? null 
                            // Random avatar sesuai nama untuk simulasi profil
                            : NetworkImage('https://ui-avatars.com/api/?name=${widget.chat['name']}&background=random&size=200'),
                        child: widget.chat['isGroup'] 
                            ? Icon(Icons.group, size: 80, color: theme.colorScheme.onPrimary)
                            : null,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                
                // Papan Kontrol Bawah (Bottom Controls)
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isVideoActive ? Colors.black.withOpacity(0.6) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      if (!isVideoActive)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: isMuted ? Icons.mic_off : Icons.mic,
                        isActive: isMuted,
                        onPressed: _toggleMute,
                      ),
                      _buildControlButton(
                        icon: isVideoActive ? Icons.videocam : Icons.videocam_off,
                        isActive: isVideoActive, // Jika nyala (true), indikator tombol juga akan nyala (putih)
                        onPressed: _toggleVideo,
                      ),
                      _buildControlButton(
                        icon: isSpeaker ? Icons.volume_up : Icons.volume_down,
                        isActive: isSpeaker,
                        onPressed: _toggleSpeaker,
                      ),
                      FloatingActionButton(
                        heroTag: null,
                        backgroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    // Logika pewarnaan stateful
    final bgColor = isVideoActive 
        ? (isActive ? Colors.white : Colors.white24)
        : (isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant);
        
    final iconColor = isVideoActive
        ? (isActive ? Colors.black : Colors.white)
        : (isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant);

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}

class GroupInfoScreen extends StatefulWidget {
  final Map<String, dynamic> chat;
  final VoidCallback? onGroupLeft;

  const GroupInfoScreen({super.key, required this.chat, this.onGroupLeft});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool onlyAdminCanAdd = false;
  List<Map<String, dynamic>> members = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    onlyAdminCanAdd = widget.chat['onlyAdminCanAdd'] ?? false;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final msgs = await ChatService.fetchGroupMembers(widget.chat['id'].toString());
      setState(() {
        members = msgs.map((m) => Map<String, dynamic>.from(m)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _addMember() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        bool isSearching = false;
        List<dynamic> searchResults = [];
        List<dynamic> selectedUsers = [];

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            List<dynamic> displayList = List.from(selectedUsers);
            for (var result in searchResults) {
               if (!displayList.any((u) => u['id'] == result['id'])) {
                  displayList.add(result);
               }
            }

            return AlertDialog(
              title: const Text('Tambah Anggota'),
              content: SizedBox(
                width: 350,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Cari Nama Anggota...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: controller.text.isNotEmpty ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.clear();
                            setStateDialog(() {
                              searchResults = [];
                              isSearching = false;
                            });
                          },
                        ) : null,
                      ),
                      onChanged: (value) async {
                        setStateDialog(() {
                          isSearching = true;
                        });
                        if (value.isNotEmpty) {
                          try {
                            final results = await ChatService.searchUsers(value);
                            setStateDialog(() {
                              searchResults = results;
                              isSearching = false;
                            });
                          } catch (e) {
                            setStateDialog(() => isSearching = false);
                          }
                        } else {
                          setStateDialog(() {
                            searchResults = [];
                            isSearching = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    if (isSearching)
                      const CircularProgressIndicator()
                    else if (controller.text.isNotEmpty && searchResults.isEmpty && selectedUsers.isEmpty)
                      const Text('Pengguna tidak ditemukan', style: TextStyle(color: Colors.red))
                    else if (displayList.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final user = displayList[index];
                            final isAlreadyMember = members.any((m) => m['id'] == user['id']);
                            final isSelected = selectedUsers.any((u) => u['id'] == user['id']);

                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(user['name']),
                              subtitle: Text(isAlreadyMember ? 'Sudah berada di dalam grup' : user['email']),
                              enabled: !isAlreadyMember,
                              trailing: isAlreadyMember 
                                  ? const Icon(Icons.groups, color: Colors.grey)
                                  : Checkbox(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setStateDialog(() {
                                          if (val == true) {
                                            selectedUsers.add(user);
                                          } else {
                                            selectedUsers.removeWhere((u) => u['id'] == user['id']);
                                          }
                                        });
                                      },
                                    ),
                              onTap: isAlreadyMember ? null : () {
                                setStateDialog(() {
                                  if (isSelected) {
                                    selectedUsers.removeWhere((u) => u['id'] == user['id']);
                                  } else {
                                    selectedUsers.add(user);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                FilledButton(
                  onPressed: selectedUsers.isEmpty
                      ? null
                      : () async {
                          for (var user in selectedUsers) {
                            try {
                              await ChatService.addGroupMember(widget.chat['id'].toString(), user['id']);
                            } catch (e) {
                              print('Failed to add ${user['id']}: $e');
                            }
                          }
                          _loadMembers();
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Info Grup'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.tertiaryContainer,
              child: Icon(Icons.group, size: 60, color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              widget.chat['name'],
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Center(
            child: Text('Grup · ${members.length} Anggota', style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 20),
          Divider(thickness: 8, color: theme.colorScheme.surfaceVariant.withOpacity(0.4)),
          
          // Pengaturan
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Pengaturan Grup'),
            subtitle: const Text('Hanya Admin yang dapat menambahkan anggota baru'),
            trailing: Switch(
              value: onlyAdminCanAdd,
              activeColor: theme.colorScheme.primary,
              onChanged: (val) {
                ChatService.updateGroupSettings(widget.chat['id'].toString(), val).then((_) {
                  setState(() {
                    onlyAdminCanAdd = val;
                  });
                });
              },
            ),
          ),
          Divider(thickness: 8, color: theme.colorScheme.surfaceVariant.withOpacity(0.4)),
          
          // Daftar Anggota
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${members.length} Anggota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)),
                const Icon(Icons.search, color: Colors.grey),
              ],
            ),
          ),
          
          // Tombol Tambah Anggota
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.person_add, color: theme.colorScheme.onPrimary),
            ),
            title: const Text('Tambah Anggota', style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
              if (onlyAdminCanAdd) {
                // Check if I am admin
                final myMember = members.firstWhere((m) => m['name'] == 'Anda', orElse: () => {'isAdmin': false});
                final isMeAdmin = myMember['isAdmin'];
                if (!isMeAdmin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hanya Admin yang dapat menambahkan anggota!')),
                  );
                  return;
                }
              }
              _addMember();
            },
          ),
          
          if (isLoading) const Center(child: CircularProgressIndicator())
          else ...members.map((m) => ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceVariant,
              backgroundImage: NetworkImage('https://ui-avatars.com/api/?name=${m['name']}&background=random'),
            ),
            title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: m['name'] == 'Anda' ? const Text('Ponsel ini') : null,
            trailing: m['isAdmin'] 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Admin', style: TextStyle(color: theme.colorScheme.onTertiaryContainer, fontSize: 12, fontWeight: FontWeight.bold)),
                  ) 
                : null,
            onTap: m['name'] == 'Anda' ? null : () {
              final myMember = members.firstWhere((memb) => memb['name'] == 'Anda', orElse: () => {'isAdmin': false});
              if (myMember['isAdmin']) {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings),
                          title: const Text('Jadikan Admin'),
                          onTap: () {
                            Navigator.pop(context);
                            ChatService.makeAdmin(widget.chat['id'].toString(), m['id'].toString()).then((_) => _loadMembers());
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_remove, color: Colors.red),
                          title: const Text('Keluarkan dari Grup', style: TextStyle(color: Colors.red)),
                          onTap: () {
                            Navigator.pop(context);
                            ChatService.kickMember(widget.chat['id'].toString(), m['id'].toString()).then((_) => _loadMembers());
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          )),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                ChatService.leaveGroup(widget.chat['id'].toString()).then((_) {
                  Navigator.pop(context);
                  widget.onGroupLeft?.call();
                });
              },
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              label: const Text('Keluar dari Grup', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

