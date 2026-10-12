import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/debt_provider.dart';
import '../models/expense_category.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import 'add_people_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recentBills = [];
  bool _loadingBills = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.isGuest) {
      setState(() => _loadingBills = false);
      return;
    }
    try {
      context.read<DebtProvider>().loadSummary();
      final result = await auth.api.getUserBills();
      final raw = result['bills'] ?? result['results'] ?? [];
      if (mounted) {
        setState(() {
          _recentBills =
              List<Map<String, dynamic>>.from(raw is List ? raw : [])
                  .take(5)
                  .toList();
          _loadingBills = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBills = false);
    }
  }

  void _openNewBill() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddPeopleScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final now = DateTime.now();
    final greeting = _greeting(now.hour);
    final userName = auth.userName?.split(' ').first ?? 'там';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Cool ambient blobs
            Positioned(
              top: -60,
              right: -40,
              child: _Blob(color: const Color(0xFF22D3EE), size: 200),
            ),
            Positioned(
              top: 200,
              left: -50,
              child: _Blob(color: const Color(0xFFA78BFA), size: 160),
            ),

            SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$greeting, $userName',
                                        style: AppTheme.headingStyle(fontSize: 26),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('d MMMM, EEEE', 'ru').format(now),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // Quick Actions — three action cards
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickActionCard(
                                    icon: Icons.receipt_long_rounded,
                                    label: 'Новый счёт',
                                    gradient: AppTheme.primaryGradient,
                                    onTap: _openNewBill,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _QuickActionCard(
                                    icon: Icons.camera_alt_rounded,
                                    label: 'Сканировать чек',
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFA78BFA), Color(0xFFC4B5FD)],
                                    ),
                                    onTap: _openNewBill,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _QuickActionCard(
                              icon: Icons.flash_on_rounded,
                              label: 'Быстрый сплит — разделить поровну',
                              gradient: const LinearGradient(
                                colors: [Color(0xFF34D399), Color(0xFF22D3EE)],
                              ),
                              onTap: _openNewBill,
                              isWide: true,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // Balance summary
                    if (!auth.isGuest && debtProvider.balances.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('Баланс', style: AppTheme.headingStyle(fontSize: 18)),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: debtProvider.balances.length.clamp(0, 4),
                            itemBuilder: (_, i) {
                              final b = debtProvider.balances[i];
                              final amount = (b['balance'] as num?)?.toDouble() ?? 0;
                              final name = b['name']?.toString() ?? '';
                              final isPos = amount > 0;
                              return Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 12),
                                child: LiquidGlass(
                                  borderRadius: BorderRadius.circular(16),
                                  padding: const EdgeInsets.all(14),
                                  fillColor: isPos
                                      ? AppTheme.success.withValues(alpha: 0.08)
                                      : AppTheme.danger.withValues(alpha: 0.08),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(
                                        isPos
                                            ? '+${amount.abs().toStringAsFixed(0)} сом'
                                            : '-${amount.abs().toStringAsFixed(0)} сом',
                                        style: AppTheme.moneyStyle(fontSize: 15).copyWith(
                                          color: isPos ? AppTheme.success : AppTheme.danger,
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
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],

                    // Recent Bills header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text('Последние разделения', style: AppTheme.headingStyle(fontSize: 18)),
                            const Spacer(),
                            if (_recentBills.isNotEmpty)
                              Text('Все',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  )),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    if (auth.isGuest)
                      SliverToBoxAdapter(child: _GuestBillsPlaceholder(onCreateBill: _openNewBill))
                    else if (_loadingBills)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                        ),
                      )
                    else if (_recentBills.isEmpty)
                      SliverToBoxAdapter(child: _EmptyBillsState(onCreateBill: _openNewBill))
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _BillCard(bill: _recentBills[i]),
                            childCount: _recentBills.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 160)),
                  ],
                ),
              ),
            ),

            // Golden FAB with glow
            Positioned(
              right: 20,
              bottom: 90,
              child: _GradientFAB(onTap: _openNewBill),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }
}

// Sub-widgets

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool isWide;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return LiquidGlass(
        borderRadius: BorderRadius.circular(20),
        interactive: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, size: 22, color: const Color(0xFF1A1A1A)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                size: 18, color: AppTheme.textSecondary),
          ],
        ),
      );
    }

    return LiquidGlass(
      borderRadius: BorderRadius.circular(20),
      interactive: true,
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 22, color: const Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  const _BillCard({required this.bill});

  String _currSym() {
    final code = bill['currency']?.toString();
    if (code == null) return 'сом';
    for (final c in Currency.values) {
      if (c.code == code) return c.symbol;
    }
    return 'сом';
  }

  ExpenseCategory? _billCategory() {
    final catId = bill['category']?.toString();
    if (catId == null) return null;
    try {
      return ExpenseCategory.findById(catId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Django DecimalField serializes to a JSON string; parse defensively.
    final rawTotal = bill['total'];
    final total = rawTotal is num
        ? rawTotal.toDouble()
        : double.tryParse(rawTotal?.toString() ?? '') ?? 0;
    final people = List.from(bill['people'] ?? []);
    final createdAt = bill['created_at']?.toString();
    final title = bill['title']?.toString();
    final cat = _billCategory();

    String dateStr = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(date);
        if (diff.inDays == 0) {
          dateStr = 'Сегодня';
        } else if (diff.inDays == 1) {
          dateStr = 'Вчера';
        } else if (diff.inDays < 7) {
          dateStr = '${diff.inDays} дн. назад';
        } else {
          dateStr = DateFormat('d MMM').format(date);
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: cat?.color ?? AppTheme.primary, width: 3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (cat?.color ?? AppTheme.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  cat?.icon ?? Icons.receipt_long_rounded,
                  size: 20,
                  color: cat?.color ?? AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title?.isNotEmpty == true ? title! : 'Счёт #${bill['id']}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(dateStr,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      if (people.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text('·', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 8),
                        Text('${people.length} чел.',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${total.toStringAsFixed(0)} ${_currSym()}',
              style: AppTheme.moneyStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _GradientFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Color(0xFF1A1A1A), size: 30),
      ),
    );
  }
}

class _EmptyBillsState extends StatelessWidget {
  final VoidCallback onCreateBill;
  const _EmptyBillsState({required this.onCreateBill});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: LiquidGlass(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_rounded, size: 44, color: AppTheme.primary),
            const SizedBox(height: 10),
            Text('Пока тут пусто', style: AppTheme.headingStyle(fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'Делим расходы?\nРазделите первый счёт',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: onCreateBill,
                  icon: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF1A1A1A)),
                  label: const Text('Создать счёт',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      )),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestBillsPlaceholder extends StatelessWidget {
  final VoidCallback onCreateBill;
  const _GuestBillsPlaceholder({required this.onCreateBill});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: LiquidGlass(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, size: 32, color: AppTheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Войдите, чтобы сохранять историю',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 4),
                  Text('Счета гостей не сохраняются',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: FilledButton(
                onPressed: onCreateBill,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('Создать'),
              ),
            ),
          ],
        ),
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
