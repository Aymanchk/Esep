import 'package:flutter/material.dart';
import '../widgets/glass_bottom_nav_bar.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'debts_screen.dart';
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
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}
