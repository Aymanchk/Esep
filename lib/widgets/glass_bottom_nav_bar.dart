import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int chatBadge;

  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.chatBadge = 0,
  });

  @override
  State<GlassBottomNavBar> createState() => _GlassBottomNavBarState();
}

class _GlassBottomNavBarState extends State<GlassBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbController;

  static const _tabs = [
    _TabDef(Icons.home_rounded, Icons.home_rounded, 'Главная'),
    _TabDef(Icons.history_rounded, Icons.history_rounded, 'История'),
    _TabDef(
      Icons.account_balance_wallet_rounded,
      Icons.account_balance_wallet_rounded,
      'Долги',
    ),
    _TabDef(Icons.chat_bubble_rounded, Icons.chat_bubble_rounded, 'Чат'),
    _TabDef(Icons.person_rounded, Icons.person_rounded, 'Профиль'),
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 72 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.glassNavFill,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final isActive = i == widget.currentIndex;
                final showBadge = i == 3 && widget.chatBadge > 0;
                return Expanded(
                  child: _NavItem(
                    tab: _tabs[i],
                    isActive: isActive,
                    badge: showBadge ? widget.chatBadge : 0,
                    orbController: _orbController,
                    onTap: () => widget.onTap(i),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabDef(this.icon, this.activeIcon, this.label);
}

class _NavItem extends StatelessWidget {
  final _TabDef tab;
  final bool isActive;
  final int badge;
  final AnimationController orbController;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.badge,
    required this.orbController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  tab.activeIcon,
                  key: ValueKey(isActive),
                  size: 24,
                  color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -6,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              tab.label,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Glowing orb indicator — golden
          AnimatedBuilder(
            animation: orbController,
            builder: (context, _) {
              final pulse = orbController.value;
              return AnimatedOpacity(
                opacity: isActive ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  width: 4 + pulse * 2,
                  height: 4 + pulse * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(
                          alpha: 0.4 + pulse * 0.3,
                        ),
                        blurRadius: 6 + pulse * 4,
                        spreadRadius: 1 + pulse,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
