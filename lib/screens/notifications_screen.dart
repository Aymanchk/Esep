import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAndMarkRead();
    });
  }

  Future<void> _loadAndMarkRead() async {
    final provider = context.read<NotificationProvider>();
    await provider.loadNotifications();
    if (!mounted) return;
    await provider.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _Blob(color: const Color(0xFF22D3EE), size: 160),
            ),
            Positioned(
              bottom: 100,
              left: -30,
              child: _Blob(color: const Color(0xFF67E8F9), size: 110),
            ),
            Positioned(
              top: 80,
              left: -20,
              child: _Blob(color: const Color(0xFFA78BFA), size: 80),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ── Header ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: LiquidGlass(
                            borderRadius: BorderRadius.circular(12),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Уведомления',
                            style: AppTheme.headingStyle(fontSize: 20),
                          ),
                        ),
                        if (provider.unreadCount > 0)
                          LiquidGlass(
                            borderRadius: BorderRadius.circular(50),
                            interactive: true,
                            onTap: () => provider.markAllRead(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: const Text(
                              'Прочитать все',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: provider.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          )
                        : provider.notifications.isEmpty
                        ? _EmptyState()
                        : RefreshIndicator(
                            onRefresh: () => provider.loadNotifications(),
                            color: AppTheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: provider.notifications.length,
                              itemBuilder: (_, i) {
                                final n = provider.notifications[i];
                                return _NotifCard(
                                  notification: n,
                                  onTap: () {
                                    final id = n['id'] as int?;
                                    if (id != null) provider.markRead(id);
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
}

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  const _NotifCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = notification['type']?.toString() ?? '';
    final title = notification['title']?.toString() ?? '';
    final body = notification['body']?.toString() ?? '';
    final isRead = notification['is_read'] as bool? ?? false;
    final createdAt = notification['created_at']?.toString();

    IconData icon;
    Color iconColor;
    switch (type) {
      case 'bill_added':
        icon = Icons.receipt_long_rounded;
        iconColor = AppTheme.primary;
      case 'debt_paid':
        icon = Icons.check_circle_rounded;
        iconColor = AppTheme.success;
      case 'debt_created':
        icon = Icons.account_balance_wallet_rounded;
        iconColor = AppTheme.danger;
      case 'new_message':
        icon = Icons.chat_bubble_rounded;
        iconColor = const Color(0xFF67E8F9);
      default:
        icon = Icons.notifications_rounded;
        iconColor = AppTheme.textSecondary;
    }

    String timeAgo = '';
    if (createdAt != null) {
      try {
        final diff = DateTime.now().difference(DateTime.parse(createdAt));
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes} мин';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours} ч';
        } else {
          timeAgo = '${diff.inDays} дн';
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isRead ? AppTheme.surface : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isRead ? Colors.transparent : AppTheme.primary,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('\u{1F514}', style: TextStyle(fontSize: 52)),
          SizedBox(height: 14),
          Text(
            'Нет уведомлений',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Здесь будут появляться\nновые события',
            textAlign: TextAlign.center,
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
