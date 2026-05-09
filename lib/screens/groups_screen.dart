import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isGuest) {
        context.read<GroupProvider>().loadGroups();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _Blob(color: const Color(0xFF67E8F9), size: 160),
            ),
            Positioned(
              bottom: 80,
              left: -40,
              child: _Blob(color: const Color(0xFF22D3EE), size: 120),
            ),
            Positioned(
              top: 100,
              left: -20,
              child: _Blob(color: const Color(0xFFA78BFA), size: 90),
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
                          child: Text(
                            'Группы',
                            style: AppTheme.headingStyle(fontSize: 28),
                          ),
                        ),
                        if (!auth.isGuest)
                          LiquidGlass(
                            borderRadius: BorderRadius.circular(12),
                            interactive: true,
                            onTap: () => _showCreateGroupSheet(context),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(
                              Icons.add_rounded,
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
                        : groupProvider.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          )
                        : groupProvider.groups.isEmpty
                        ? _EmptyPlaceholder(
                            onCreateTap: () => _showCreateGroupSheet(context),
                          )
                        : RefreshIndicator(
                            onRefresh: () => groupProvider.loadGroups(),
                            color: AppTheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: groupProvider.groups.length,
                              itemBuilder: (context, index) {
                                final group = groupProvider.groups[index];
                                return _GroupCard(
                                  group: group,
                                  onEdit: () =>
                                      _showEditGroupSheet(context, group),
                                  onDelete: () async {
                                    final id = group['id'] as int;
                                    await groupProvider.deleteGroup(id);
                                  },
                                );
                              },
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

  void _showCreateGroupSheet(BuildContext context) {
    final nameController = TextEditingController();
    final searchController = TextEditingController();
    final selectedMembers = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> searchResults = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _GlassSheet(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Новая группа',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Название группы',
                    hintText: 'Напр: Одногруппники',
                    prefixIcon: Icon(Icons.group_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Поиск друзей',
                    hintText: 'Имя или email',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (query) async {
                    if (query.length < 2) {
                      setModalState(() => searchResults = []);
                      return;
                    }
                    try {
                      final auth = context.read<AuthProvider>();
                      final results = await auth.api.searchUsers(query);
                      setModalState(() => searchResults = results);
                    } catch (_) {}
                  },
                ),
                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (_, i) {
                        final user = searchResults[i];
                        final alreadyAdded = selectedMembers.any(
                          (m) => m['id'] == user['id'],
                        );
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primary.withValues(
                              alpha: 0.2,
                            ),
                            child: Text(
                              (user['name']?.toString() ?? '?')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            user['name']?.toString() ?? '',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            user['email']?.toString() ?? '',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          trailing: alreadyAdded
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.success,
                                  size: 18,
                                )
                              : null,
                          onTap: alreadyAdded
                              ? null
                              : () {
                                  setModalState(
                                    () => selectedMembers.add(user),
                                  );
                                },
                        );
                      },
                    ),
                  ),
                ],
                if (selectedMembers.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedMembers.map((m) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m['name']?.toString() ?? '',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setModalState(
                                () => selectedMembers.remove(m),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final memberIds = selectedMembers
                        .map((m) => m['id'] as int)
                        .toList();
                    final provider = context.read<GroupProvider>();
                    await provider.createGroup(
                      name: nameController.text.trim(),
                      memberIds: memberIds,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Создать группу',
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditGroupSheet(BuildContext context, Map<String, dynamic> group) {
    final nameController = TextEditingController(
      text: group['name']?.toString() ?? '',
    );
    final members = List<Map<String, dynamic>>.from(group['members'] ?? []);
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _GlassSheet(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Редактировать группу',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    prefixIcon: Icon(Icons.group_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Добавить участника',
                    hintText: 'Имя или email',
                    prefixIcon: Icon(Icons.person_add_rounded),
                  ),
                  onChanged: (query) async {
                    if (query.length < 2) {
                      setModalState(() => searchResults = []);
                      return;
                    }
                    try {
                      final auth = context.read<AuthProvider>();
                      final results = await auth.api.searchUsers(query);
                      setModalState(() => searchResults = results);
                    } catch (_) {}
                  },
                ),
                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (_, i) {
                        final user = searchResults[i];
                        final alreadyAdded = members.any(
                          (m) => m['id'] == user['id'],
                        );
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primary.withValues(
                              alpha: 0.2,
                            ),
                            child: Text(
                              (user['name']?.toString() ?? '?')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            user['name']?.toString() ?? '',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          trailing: alreadyAdded
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppTheme.success,
                                  size: 18,
                                )
                              : null,
                          onTap: alreadyAdded
                              ? null
                              : () {
                                  setModalState(() => members.add(user));
                                },
                        );
                      },
                    ),
                  ),
                ],
                if (members.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Участники:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: members.map((m) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m['name']?.toString() ?? '',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () =>
                                  setModalState(() => members.remove(m)),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final memberIds = members
                        .map((m) => m['id'] as int)
                        .toList();
                    final provider = context.read<GroupProvider>();
                    await provider.updateGroup(
                      groupId: group['id'] as int,
                      name: nameController.text.trim(),
                      memberIds: memberIds,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Сохранить',
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupCard({
    required this.group,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = group['name']?.toString() ?? '';
    final members = List<Map<String, dynamic>>.from(group['members'] ?? []);
    final memberCount = group['member_count'] as int? ?? members.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.group_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$memberCount участников',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  color: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text(
                            'Удалить группу?',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                          content: const Text(
                            'Это действие нельзя отменить.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                'Отмена',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onDelete();
                              },
                              child: const Text(
                                'Удалить',
                                style: TextStyle(color: AppTheme.danger),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Редактировать',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            size: 16,
                            color: AppTheme.danger,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Удалить',
                            style: TextStyle(color: AppTheme.danger),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (members.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  ...members.take(6).map((m) {
                    final mName = m['name']?.toString() ?? '?';
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.2,
                        ),
                        child: Text(
                          mName[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (members.length > 6)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '+${members.length - 6}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyPlaceholder({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\u{1F465}', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          const Text(
            'Нет групп',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Создайте группу, чтобы быстро\nдобавлять друзей в счёт',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onCreateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Color(0xFF1A1A1A), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Создать группу',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          Text('\u{1F465}', style: TextStyle(fontSize: 52)),
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
            'Чтобы управлять группами друзей',
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
