import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isGuest) context.read<ChatProvider>().loadRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _Blob(color: const Color(0xFF22D3EE), size: 160),
            ),
            Positioned(
              bottom: 100,
              left: -40,
              child: _Blob(color: const Color(0xFF67E8F9), size: 120),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ── Header ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Чаты', style: AppTheme.headingStyle()),
                        ),
                        if (!auth.isGuest)
                          LiquidGlass(
                            borderRadius: BorderRadius.circular(12),
                            interactive: true,
                            onTap: () => _showNewChatSheet(context),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: AppTheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Expanded(
                    child: auth.isGuest
                        ? _GuestPlaceholder()
                        : chat.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          )
                        : chat.rooms.isEmpty
                        ? _EmptyPlaceholder()
                        : RefreshIndicator(
                            color: AppTheme.primary,
                            onRefresh: () => chat.loadRooms(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: chat.rooms.length,
                              itemBuilder: (_, i) => _RoomTile(
                                room: chat.rooms[i],
                                currentUserId: auth.userId,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewChatSheet(BuildContext context) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Новый чат',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Поиск по имени или email',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (q) async {
                  if (q.trim().length < 2) {
                    set(() => results = []);
                    return;
                  }
                  set(() => searching = true);
                  try {
                    final r = await context
                        .read<AuthProvider>()
                        .api
                        .searchUsers(q);
                    set(() {
                      results = r;
                      searching = false;
                    });
                  } catch (_) {
                    set(() => searching = false);
                  }
                },
              ),
              const SizedBox(height: 8),
              if (searching)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final u = results[i];
                    final name = u['name'] as String;
                    final avatarUrl = u['avatar'] as String?;
                    return ListTile(
                      leading: _Avatar(
                        name: name,
                        avatarUrl: avatarUrl,
                        radius: 20,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      subtitle: Text(
                        u['email'] as String? ?? '',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final chatProv = context.read<ChatProvider>();
                        final room = await chatProv.getOrCreateRoom(
                          u['id'] as int,
                        );
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                roomId: room['id'] as int,
                                otherUserName: name,
                                otherAvatarUrl: avatarUrl,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Map<String, dynamic> room;
  final int? currentUserId;
  const _RoomTile({required this.room, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final parts = List<Map<String, dynamic>>.from(room['participants'] ?? []);
    final other = parts.firstWhere(
      (p) => p['id'] != currentUserId,
      orElse: () => parts.isNotEmpty ? parts.first : {'name': '?'},
    );
    final name = other['name'] as String? ?? '?';
    final avatarUrl = other['avatar'] as String?;
    final lastMsg = room['last_message'] as Map<String, dynamic>?;
    final unread = room['unread_count'] as int? ?? 0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            roomId: room['id'] as int,
            otherUserName: name,
            otherAvatarUrl: avatarUrl,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _Avatar(name: name, avatarUrl: avatarUrl, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastMsg != null
                          ? (lastMsg['text'] as String? ?? '')
                          : 'Нет сообщений',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread > 0
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;
  const _Avatar({required this.name, this.avatarUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary,
      backgroundImage: avatarUrl != null
          ? CachedNetworkImageProvider(avatarUrl!)
          : null,
      child: avatarUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.75,
              ),
            )
          : null,
    );
  }
}

class _GuestPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_rounded, size: 52, color: AppTheme.primary),
          SizedBox(height: 14),
          Text(
            'Войдите в аккаунт',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Чтобы общаться с друзьями',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_rounded, size: 52, color: AppTheme.primary),
          SizedBox(height: 14),
          Text(
            'Пока нет чатов',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Нажмите кнопку чтобы начать',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
    );
  }
}
