import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/debt_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/share_helper.dart';
import '../widgets/liquid_glass.dart';

const _defaultCurrencySymbol = 'сом';

/// Django `DecimalField` serializes to a JSON string ("100.00"), not a number.
double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isGuest) {
        context.read<DebtProvider>().loadDebts();
        context.read<DebtProvider>().loadSummary();
        context.read<DebtProvider>().loadSettlementPlan();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dp = context.watch<DebtProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              left: -70,
              child: _Blob(color: const Color(0xFF4ECDC4), size: 130),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Долги', style: AppTheme.headingStyle()),
                        ),
                        if (!auth.isGuest)
                          GestureDetector(
                            onTap: _showCreateDebtDialog,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Color(0xFF1A1A1A),
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (auth.isGuest)
                    Expanded(child: _GuestPlaceholder())
                  else ...[
                    // ── Balance summary scroll ─────────────────────────
                    if (dp.balances.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 88,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: dp.balances.length,
                          itemBuilder: (_, i) {
                            final b = dp.balances[i];
                            final amount = _asDouble(b['balance']);
                            final name = b['name']?.toString() ?? '';
                            final isPos = amount > 0;
                            return Container(
                              width: 170,
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
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isPos
                                          ? '+ ${amount.abs().toStringAsFixed(0)} $_defaultCurrencySymbol'
                                          : '− ${amount.abs().toStringAsFixed(0)} $_defaultCurrencySymbol',
                                      style: AppTheme.moneyStyle(fontSize: 14)
                                          .copyWith(
                                            color: isPos
                                                ? AppTheme.success
                                                : AppTheme.danger,
                                          ),
                                    ),
                                    Text(
                                      isPos ? 'должен вам' : 'вы должны',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    if (dp.isSettlementLoading || dp.settlements.isNotEmpty)
                      _SettlementPlanSection(
                        settlements: dp.settlements,
                        isLoading: dp.isSettlementLoading,
                      ),

                    const SizedBox(height: 18),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Список долгов',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Tab switcher ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LiquidGlass(
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.all(4),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: const Color(0xFF1A1A1A),
                          unselectedLabelColor: AppTheme.textSecondary,
                          dividerHeight: 0,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          tabs: const [
                            Tab(text: 'Активные'),
                            Tab(text: 'Оплаченные'),
                          ],
                          onTap: (i) {
                            context.read<DebtProvider>().loadDebts(
                              show: i == 0 ? 'active' : 'paid',
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: dp.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                              ),
                            )
                          : dp.debts.isEmpty
                          ? _EmptyDebts()
                          : RefreshIndicator(
                              onRefresh: () async {
                                await dp.loadDebts(
                                  show: _tabController.index == 0
                                      ? 'active'
                                      : 'paid',
                                );
                                await dp.loadSummary();
                                await dp.loadSettlementPlan();
                              },
                              color: AppTheme.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: dp.debts.length,
                                itemBuilder: (_, i) => _DebtCard(
                                  debt: dp.debts[i],
                                  currentUserId: auth.userId,
                                  onMarkPaid: () async {
                                    await dp.markPaid(dp.debts[i]['id'] as int);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Долг отмечен оплаченным',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onShowPaymentDetails: () =>
                                      _showPaymentDetailsModal(dp.debts[i]),
                                ),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDebtDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final auth = context.read<AuthProvider>();
    List<Map<String, dynamic>> searchResults = [];
    Map<String, dynamic>? selectedUser;
    bool searching = false;
    // true = current user owes selected user; false = selected user owes current user.
    bool iOwe = true;
    final searchCtrl = TextEditingController();
    Timer? debounce;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Создать долг'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Direction toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => iOwe = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: iOwe
                                  ? AppTheme.danger.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Center(
                              child: Text(
                                'Я должен',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => iOwe = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !iOwe
                                  ? AppTheme.success.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Center(
                              child: Text(
                                'Мне должны',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Поиск пользователя',
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    suffixIcon: searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (q) {
                    debounce?.cancel();
                    if (q.trim().length < 2) {
                      setDialogState(() => searchResults = []);
                      return;
                    }
                    debounce = Timer(
                      const Duration(milliseconds: 300),
                      () async {
                        setDialogState(() => searching = true);
                        try {
                          final res = await auth.api.searchUsers(q.trim());
                          setDialogState(() {
                            searchResults = res;
                            searching = false;
                          });
                        } catch (_) {
                          setDialogState(() => searching = false);
                        }
                      },
                    );
                  },
                ),
                if (selectedUser != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      label: Text(selectedUser!['name'] as String),
                      onDeleted: () =>
                          setDialogState(() => selectedUser = null),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                if (searchResults.isNotEmpty && selectedUser == null)
                  // ListView inside SingleChildScrollView inside AlertDialog
                  // triggers parentDataDirty assertions on iOS — render the
                  // results as a plain Column instead.
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: searchResults.take(8).map((user) {
                      final name = user['name'] as String? ?? '';
                      final avatarUrl = user['avatar'] as String?;
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedUser = user;
                            searchResults = [];
                            searchCtrl.text = name;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.primary,
                                backgroundImage: avatarUrl != null
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Сумма ($_defaultCurrencySymbol)',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Описание (необязательно)',
                    prefixIcon: Icon(Icons.note_rounded),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(
                  amountCtrl.text.replaceAll(',', '.'),
                );
                if (selectedUser == null || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Выберите пользователя и укажите сумму'),
                    ),
                  );
                  return;
                }
                if (auth.userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка: пользователь не авторизован'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final dp = context.read<DebtProvider>();
                final me = auth.userId!;
                final them = selectedUser!['id'] as int;
                final success = await dp.createDebt(
                  fromUserId: iOwe ? me : them,
                  toUserId: iOwe ? them : me,
                  amount: amount,
                  description: descCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Долг создан' : 'Не удалось создать долг',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetailsModal(Map<String, dynamic> debt) {
    final amount = _asDouble(debt['amount']);
    final from = Map<String, dynamic>.from(debt['from_user'] as Map? ?? {});
    final to = Map<String, dynamic>.from(debt['to_user'] as Map? ?? {});
    final details = _paymentDetailsText(debt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Payment details',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${amount.toStringAsFixed(0)} $_defaultCurrencySymbol',
              style: AppTheme.moneyStyle(
                fontSize: 30,
              ).copyWith(color: AppTheme.success),
            ),
            Text(
              '${from['name']} → ${to['name']}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Text(
                details,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use these details to coordinate payment outside Fair Splitter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: details));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment details copied')),
                  );
                },
                child: const Text('Copy details'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => ShareHelper.shareViaTelegram(details),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Telegram'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => ShareHelper.shareViaWhatsApp(details),
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _paymentDetailsText(Map<String, dynamic> debt) {
    final amount = _asDouble(debt['amount']);
    final from = Map<String, dynamic>.from(debt['from_user'] as Map? ?? {});
    final to = Map<String, dynamic>.from(debt['to_user'] as Map? ?? {});
    final description = debt['description']?.toString() ?? '';

    final lines = [
      'Fair Splitter payment details',
      'From: ${from['name'] ?? ''}',
      'To: ${to['name'] ?? ''}',
      'Amount: ${amount.toStringAsFixed(0)} $_defaultCurrencySymbol',
      if (description.isNotEmpty) 'Note: $description',
      'Please confirm payment method with the recipient.',
    ];
    return lines.join('\n');
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SettlementPlanSection extends StatelessWidget {
  final List<Map<String, dynamic>> settlements;
  final bool isLoading;

  const _SettlementPlanSection({
    required this.settlements,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: LiquidGlass(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(14),
        fillColor: AppTheme.primary.withValues(alpha: 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.auto_graph_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Optimized settlement plan',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isLoading)
              const SizedBox(
                height: 32,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              ...settlements.take(4).map((settlement) {
                final from = Map<String, dynamic>.from(
                  settlement['from_user'] as Map? ?? {},
                );
                final to = Map<String, dynamic>.from(
                  settlement['to_user'] as Map? ?? {},
                );
                final amount = _asDouble(settlement['amount']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${from['name'] ?? ''} → ${to['name'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${amount.toStringAsFixed(0)} $_defaultCurrencySymbol',
                        style: AppTheme.moneyStyle(
                          fontSize: 13,
                        ).copyWith(color: AppTheme.primary),
                      ),
                    ],
                  ),
                );
              }),
            if (!isLoading && settlements.length > 4)
              Text(
                '+${settlements.length - 4} more',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Map<String, dynamic> debt;
  final int? currentUserId;
  final VoidCallback onMarkPaid;
  final VoidCallback onShowPaymentDetails;

  const _DebtCard({
    required this.debt,
    required this.currentUserId,
    required this.onMarkPaid,
    required this.onShowPaymentDetails,
  });

  @override
  Widget build(BuildContext context) {
    final amount = _asDouble(debt['amount']);
    final isPaid = debt['is_paid'] as bool? ?? false;
    final from = Map<String, dynamic>.from(debt['from_user'] as Map? ?? {});
    final to = Map<String, dynamic>.from(debt['to_user'] as Map? ?? {});
    final description = debt['description']?.toString() ?? '';
    final isIOwe = from['id'] == currentUserId;

    return Dismissible(
      key: Key(debt['id'].toString()),
      direction: isPaid ? DismissDirection.none : DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.success,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Оплачено',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onMarkPaid();
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPaid
                ? AppTheme.success.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: (isIOwe ? AppTheme.danger : AppTheme.success).withValues(
                alpha: 0.06,
              ),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isIOwe ? AppTheme.danger : AppTheme.success)
                          .withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      isIOwe
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      color: isIOwe ? AppTheme.danger : AppTheme.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIOwe
                              ? 'Вы должны ${to['name']}'
                              : '${from['name']} должен вам',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${amount.toStringAsFixed(0)} $_defaultCurrencySymbol',
                    style: AppTheme.moneyStyle(fontSize: 17).copyWith(
                      color: isIOwe ? AppTheme.danger : AppTheme.success,
                    ),
                  ),
                ],
              ),
              if (isPaid) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '✓ Оплачено',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: LiquidGlass(
                          borderRadius: BorderRadius.circular(10),
                          interactive: true,
                          onTap: onShowPaymentDetails,
                          padding: EdgeInsets.zero,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.content_copy_rounded,
                                size: 15,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Details',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: FilledButton.icon(
                          onPressed: onMarkPaid,
                          icon: const Icon(Icons.check_rounded, size: 15),
                          label: const Text(
                            'Оплачено',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.zero,
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
      ),
    );
  }
}

class _EmptyDebts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.account_balance_wallet_rounded,
            size: 52,
            color: AppTheme.primary,
          ),
          SizedBox(height: 14),
          Text(
            'Долгов нет',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Все долги урегулированы',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _GuestPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_rounded, size: 48, color: AppTheme.primary),
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
              'Для отслеживания долгов\nнужна регистрация',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
        color: color.withValues(alpha: 0.15),
      ),
    );
  }
}
