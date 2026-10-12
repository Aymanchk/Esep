import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import 'onboarding_screen.dart';
import 'stats_screen.dart';
import 'groups_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isEditing = false;
  bool _uploadingAvatar = false;

  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameCtrl.text = auth.userName ?? '';
    _emailCtrl.text = auth.userEmail ?? '';
    _phoneCtrl.text = auth.userPhone ?? '';

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final auth = context.read<AuthProvider>();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    final ok = await auth.uploadAvatar(File(picked.path));
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Фото обновлено')));
    }
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Профиль обновлён')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Ошибка')));
    }
  }

  void _logout() {
    context.read<AuthProvider>().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              left: -30,
              child: _Blob(color: const Color(0xFF22D3EE), size: 200),
            ),
            Positioned(
              bottom: 100,
              right: -50,
              child: _Blob(color: const Color(0xFF67E8F9), size: 150),
            ),
            Positioned(
              top: 60,
              right: 30,
              child: _Blob(color: const Color(0xFFA78BFA), size: 100),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Профиль',
                      style: AppTheme.headingStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 28),

                    // ── Avatar with gradient ring ───────────────────
                    GestureDetector(
                      onTap: auth.isGuest ? null : _pickAvatar,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating gradient ring
                          if (!auth.isGuest)
                            AnimatedBuilder(
                              animation: _ringController,
                              builder: (_, __) => Transform.rotate(
                                angle: _ringController.value * 2 * math.pi,
                                child: CustomPaint(
                                  size: const Size(124, 124),
                                  painter: _GradientRingPainter(),
                                ),
                              ),
                            ),
                          CircleAvatar(
                            radius: auth.isGuest ? 52 : 48,
                            backgroundColor: AppTheme.primary,
                            backgroundImage: auth.userAvatarUrl != null
                                ? CachedNetworkImageProvider(
                                    auth.userAvatarUrl!)
                                : null,
                            child: _uploadingAvatar
                                ? const CircularProgressIndicator(
                                    color: Color(0xFF1A1A1A), strokeWidth: 2)
                                : auth.userAvatarUrl == null
                                    ? Text(
                                        (auth.userName ?? 'G')[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      )
                                    : null,
                          ),
                          if (!auth.isGuest)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.background, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                    size: 14, color: Color(0xFF1A1A1A)),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    Text(
                      auth.userName ?? 'Гость',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (!auth.isGuest)
                      Text(
                        auth.userEmail ?? '',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),

                    const SizedBox(height: 20),

                    // ── Quick stats ──────────────────────────────────
                    if (!auth.isGuest) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatPill(label: 'Счетов', value: '—'),
                          const SizedBox(width: 8),
                          _StatPill(label: 'Потрачено', value: '—'),
                          const SizedBox(width: 8),
                          _StatPill(label: 'Друзей', value: '—'),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Guest banner ─────────────────────────────────
                    if (auth.isGuest) ...[
                      LiquidGlass(
                        borderRadius: BorderRadius.circular(20),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.person_rounded,
                                size: 36, color: AppTheme.primary),
                            const SizedBox(height: 10),
                            const Text(
                              'Вы вошли как гость',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Зарегистрируйтесь, чтобы сохранять историю и общаться с друзьями',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: FilledButton(
                                onPressed: _logout,
                                child: const Text('Зарегистрироваться'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ] else ...[
                      // ── Menu items ─────────────────────────────────
                      _MenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.bar_chart_rounded,
                            label: 'Статистика',
                            color: AppTheme.primary,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const StatsScreen()),
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.group_rounded,
                            label: 'Группы друзей',
                            color: AppTheme.primary,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const GroupsScreen()),
                            ),
                          ),
                          _MenuItemWithBadge(
                            icon: Icons.notifications_rounded,
                            label: 'Уведомления',
                            color: AppTheme.success,
                            onTap: () {
                              context
                                  .read<NotificationProvider>()
                                  .loadNotifications();
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationsScreen()));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Edit profile card ──────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _FieldRow(
                              icon: Icons.person_rounded,
                              label: 'Имя',
                              ctrl: _nameCtrl,
                              editing: _isEditing,
                            ),
                            Divider(
                                height: 24,
                                color: Colors.white.withValues(alpha: 0.06)),
                            _FieldRow(
                              icon: Icons.email_rounded,
                              label: 'Email',
                              ctrl: _emailCtrl,
                              editing: _isEditing,
                              kb: TextInputType.emailAddress,
                            ),
                            Divider(
                                height: 24,
                                color: Colors.white.withValues(alpha: 0.06)),
                            _FieldRow(
                              icon: Icons.phone_rounded,
                              label: 'Телефон',
                              ctrl: _phoneCtrl,
                              editing: _isEditing,
                              kb: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Edit / Save row
                      if (_isEditing)
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: () {
                                    _nameCtrl.text = auth.userName ?? '';
                                    _emailCtrl.text = auth.userEmail ?? '';
                                    _phoneCtrl.text = auth.userPhone ?? '';
                                    setState(() => _isEditing = false);
                                  },
                                  child: const Text('Отмена'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed:
                                      auth.isLoading ? null : _saveProfile,
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text('Сохранить'),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: LiquidGlass(
                            borderRadius: BorderRadius.circular(14),
                            interactive: true,
                            onTap: () => setState(() => _isEditing = true),
                            padding: EdgeInsets.zero,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.edit_rounded,
                                    size: 16, color: AppTheme.textSecondary),
                                SizedBox(width: 8),
                                Text('Редактировать профиль',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // Logout
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded,
                              color: AppTheme.danger, size: 18),
                          label: const Text('Выйти',
                              style: TextStyle(color: AppTheme.danger)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.danger),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(50),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06));
          }
          return items[i ~/ 2];
        }),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MenuItemWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItemWithBadge(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (_, np, __) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
              if (np.unreadCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${np.unreadCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController ctrl;
  final bool editing;
  final TextInputType? kb;
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.ctrl,
    required this.editing,
    this.kb,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: editing
              ? TextField(
                  controller: ctrl,
                  keyboardType: kb,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: label,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(ctrl.text.isEmpty ? '—' : ctrl.text,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 15)),
                  ],
                ),
        ),
      ],
    );
  }
}

// Animated gradient ring painter
class _GradientRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        colors: const [
          AppTheme.primary,
          AppTheme.primaryLight,
          Color(0xFFA78BFA),
          AppTheme.primary,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 1.5, paint);
  }

  @override
  bool shouldRepaint(_) => true;
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
