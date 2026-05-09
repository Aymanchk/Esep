import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/glass_bottom_nav_bar.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'debts_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  int _historyKey = 0;

  List<Widget> get _screens => [
    const HomeScreen(),
    HistoryScreen(key: ValueKey(_historyKey)),
    const DebtsScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  void _onTabTap(int index) {
    if (index == 1 && _currentIndex != 1) {
      _historyKey++;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final chatRooms = context.watch<ChatProvider>().rooms;
    final chatBadge = chatRooms.fold<int>(
      0,
      (sum, r) => sum + ((r['unread_count'] as int?) ?? 0),
    );
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _currentIndex,
        chatBadge: chatBadge,
        onTap: _onTabTap,
      ),
    );
  }
}
