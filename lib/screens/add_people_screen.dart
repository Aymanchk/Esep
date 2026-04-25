import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/bill_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../models/expense_category.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import 'split_screen.dart';
import 'quick_split_screen.dart';

class AddPeopleScreen extends StatefulWidget {
  const AddPeopleScreen({super.key});

  @override
  State<AddPeopleScreen> createState() => _AddPeopleScreenState();
}

class _AddPeopleScreenState extends State<AddPeopleScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _focusNode = FocusNode();
  final _billNameController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  late AnimationController _addController;

  @override
  void initState() {
    super.initState();
    _addController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    _billNameController.dispose();
    _debounce?.cancel();
    _addController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final auth = context.read<AuthProvider>();
      if (auth.isGuest) return;
      setState(() => _isSearching = true);
      try {
        final results = await auth.api.searchUsers(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _addPerson() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    context.read<BillProvider>().addPerson(name);
    _nameController.clear();
    setState(() => _searchResults = []);
    _addController.forward(from: 0);
  }

  void _addFromSearch(Map<String, dynamic> user) {
    final provider = context.read<BillProvider>();
    if (provider.people.any((p) => p.userId == user['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Участник уже добавлен')),
      );
      return;
    }
    provider.addPerson(
      user['name'] as String,
      userId: user['id'] as int,
      avatarUrl: user['avatar'] as String?,
    );
    _nameController.clear();
    setState(() => _searchResults = []);
  }

  void _showGroupPickerDialog() {
    final groupProvider = context.read<GroupProvider>();
    groupProvider.loadGroups();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer<GroupProvider>(
          builder: (ctx, gp, _) {
            if (gp.isLoading) {
              return const SizedBox(
                height: 200,
                child:
                    Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              );
            }
            if (gp.groups.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_rounded, size: 40, color: AppTheme.primary),
                    const SizedBox(height: 12),
                    const Text('Нет групп',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'Создайте группу в разделе Профиль',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Выберите группу',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...gp.groups.map((group) {
                    final members =
                        List<Map<String, dynamic>>.from(group['members'] ?? []);
                    final name = group['name']?.toString() ?? '';
                    return _GroupListTile(
                      name: name,
                      memberCount: members.length,
                      onTap: () {
                        final billProvider = context.read<BillProvider>();
                        for (final member in members) {
                          if (!billProvider.people
                              .any((p) => p.userId == member['id'])) {
                            billProvider.addPerson(
                              member['name'] as String? ?? '',
                              userId: member['id'] as int?,
                              avatarUrl: member['avatar'] as String?,
                            );
                          }
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Добавлено из "$name"')),
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            // Ambient blobs — warm tones
            Positioned(
              top: -50,
              right: -30,
              child: _Blob(color: const Color(0xFF22D3EE), size: 180),
            ),
            Positioned(
              bottom: 100,
              left: -40,
              child: _Blob(color: const Color(0xFF67E8F9), size: 140),
            ),
            Positioned(
              bottom: 200,
              right: -20,
              child: _Blob(color: const Color(0xFFA78BFA), size: 100),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── Header ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: LiquidGlass(
                            borderRadius: BorderRadius.circular(12),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 18, color: AppTheme.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Новый счёт',
                            style: AppTheme.headingStyle(fontSize: 22),
                          ),
                        ),
                        if (!auth.isGuest)
                          LiquidGlass(
                              borderRadius: BorderRadius.circular(12),
                              interactive: true,
                              onTap: _showGroupPickerDialog,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.group_rounded,
                                      size: 16, color: AppTheme.primary),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Из группы',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Category picker ──────────────────────────────
                  SizedBox(
                    height: 44,
                    child: Consumer<BillProvider>(
                      builder: (_, bp, __) => ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: ExpenseCategory.all.length,
                        itemBuilder: (_, i) {
                          final cat = ExpenseCategory.all[i];
                          final isActive = bp.category.id == cat.id;
                          return GestureDetector(
                            onTap: () => bp.setCategory(cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? cat.color.withValues(alpha: 0.2)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: isActive
                                      ? cat.color
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: isActive ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(cat.icon,
                                      size: 16,
                                      color: isActive
                                          ? cat.color
                                          : AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      color: isActive
                                          ? cat.color
                                          : AppTheme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.normal,
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

                  const SizedBox(height: 12),

                  // ── Bill title field ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _billNameController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Название счёта (необязательно)',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onChanged: (v) =>
                          context.read<BillProvider>().setBillTitle(v.trim()),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      auth.isGuest
                          ? 'Добавьте минимум 2 участников'
                          : 'Введите имя или найдите пользователя',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Search input ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: auth.isGuest
                                  ? 'Имя участника'
                                  : 'Имя или email',
                              prefixIcon:
                                  const Icon(Icons.person_search_rounded),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            textCapitalization: TextCapitalization.words,
                            onChanged: _onSearchChanged,
                            onSubmitted: (_) => _addPerson(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _addPerson,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: Color(0xFF1A1A1A), size: 26),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Search results dropdown ───────────────────────
                  if (_searchResults.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: LiquidGlass(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.length,
                            itemBuilder: (_, i) {
                              final user = _searchResults[i];
                              final avatarUrl = user['avatar'] as String?;
                              final name = user['name'] as String;
                              return ListTile(
                                leading: _Avatar(
                                    name: name, avatarUrl: avatarUrl, radius: 18),
                                title: Text(name,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.person_add_outlined,
                                    color: AppTheme.primary, size: 20),
                                onTap: () => _addFromSearch(user),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Added participants list ───────────────────────
                  Expanded(
                    child: provider.people.isEmpty
                        ? _EmptyParticipants()
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: provider.people.length,
                            itemBuilder: (_, i) {
                              final person = provider.people[i];
                              return TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration:
                                    const Duration(milliseconds: 300),
                                curve: Curves.easeOutBack,
                                builder: (_, v, child) => Transform.scale(
                                  scale: v,
                                  child: Opacity(opacity: v, child: child),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.06),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.06),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    leading: _Avatar(
                                      name: person.name,
                                      avatarUrl: person.avatarUrl,
                                      radius: 20,
                                      bgColor: person.avatarColor,
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          person.name,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (person.userId != null) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.verified_rounded,
                                              color: AppTheme.primary,
                                              size: 15),
                                        ],
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(Icons.close_rounded,
                                          color: AppTheme.textSecondary
                                              .withValues(alpha: 0.6),
                                          size: 20),
                                      onPressed: () =>
                                          provider.removePerson(person.id),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // ── Bottom buttons ─────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          // Main: По позициям
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: _canProceed(provider)
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: FilledButton(
                                      onPressed: () {
                                        provider.reset(keepPeople: true);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const SplitScreen(),
                                          ),
                                        );
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.list_alt_rounded,
                                              size: 18,
                                              color: Color(0xFF1A1A1A)),
                                          SizedBox(width: 8),
                                          Text('По позициям',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1A1A1A),
                                              )),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded,
                                              size: 20,
                                              color: Color(0xFF1A1A1A)),
                                        ],
                                      ),
                                    ),
                                  )
                                : FilledButton(
                                    onPressed: null,
                                    style: FilledButton.styleFrom(
                                      disabledBackgroundColor:
                                          AppTheme.primary.withValues(alpha: 0.2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.list_alt_rounded,
                                            size: 18,
                                            color: AppTheme.textSecondary),
                                        SizedBox(width: 8),
                                        Text('По позициям',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textSecondary,
                                            )),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          // Quick split button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: LiquidGlass(
                              borderRadius: BorderRadius.circular(14),
                              interactive: true,
                              onTap: _canProceed(provider)
                                  ? () {
                                      provider.reset(keepPeople: true);
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const QuickSplitScreen(),
                                        ),
                                      );
                                    }
                                  : null,
                              padding: EdgeInsets.zero,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.flash_on_rounded,
                                      size: 18,
                                      color: _canProceed(provider)
                                          ? AppTheme.accent
                                          : AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Быстрый сплит',
                                    style: TextStyle(
                                      color: _canProceed(provider)
                                          ? AppTheme.accent
                                          : AppTheme.textSecondary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  bool _canProceed(BillProvider provider) => provider.people.length >= 2;
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;
  final Color? bgColor;

  const _Avatar({
    required this.name,
    this.avatarUrl,
    required this.radius,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor ?? AppTheme.primary,
      backgroundImage:
          avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
}

class _GroupListTile extends StatelessWidget {
  final String name;
  final int memberCount;
  final VoidCallback onTap;

  const _GroupListTile(
      {required this.name,
      required this.memberCount,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            const Icon(Icons.group_rounded, color: AppTheme.primary, size: 20),
      ),
      title: Text(name,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
      subtitle: Text('$memberCount участников',
          style:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      onTap: onTap,
    );
  }
}

class _EmptyParticipants extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_rounded, size: 48, color: AppTheme.primary),
          const SizedBox(height: 12),
          const Text(
            'Добавьте участников',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
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
        color: color.withValues(alpha: 0.20),
      ),
    );
  }
}
