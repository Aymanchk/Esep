import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bill_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import '../utils/share_helper.dart';
import 'home_shell.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _totalCountController;
  late Animation<double> _totalCountAnim;
  bool _saved = false;
  bool _saving = false;
  int? _savedBillId;
  final Set<String> _createdDebtKeys = {};

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    final provider = context.read<BillProvider>();
    _totalCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _totalCountAnim = Tween<double>(begin: 0, end: provider.total).animate(
      CurvedAnimation(parent: _totalCountController, curve: Curves.easeOut),
    );
    _totalCountController.forward();
  }

  Future<void> _saveBill() async {
    if (_saved || _saving) return;
    setState(() => _saving = true);
    final provider = context.read<BillProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.isGuest || !auth.isLoggedIn) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Войдите в аккаунт, чтобы сохранять счета'),
          ),
        );
      }
      return;
    }
    try {
      if (_savedBillId == null) {
        final result = await auth.api.saveBill(
          total: provider.total,
          serviceChargePercent: provider.serviceChargePercent,
          items: provider.items
              .map(
                (i) => {
                  'id': i.id,
                  'name': i.name,
                  'price': i.price,
                  'quantity': i.quantity,
                },
              )
              .toList(),
          people: provider.people
              .map((p) => {'name': p.name, 'id': p.id})
              .toList(),
          assignments: provider.unitAssignments,
          title: provider.billTitle,
          category: provider.category.id,
          currency: provider.currency.code,
          splitMode: provider.splitMode.name,
        );
        _savedBillId = _extractBillId(result);
        await provider.clearDraft();
      }
      await _createDebtsForSavedBill(provider, auth);
      if (mounted) {
        setState(() {
          _saved = true;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Счёт сохранён в историю')),
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint(e.toString());
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Не удалось сохранить')));
      }
    }
  }

  int? _extractBillId(Map<String, dynamic> result) {
    final bill = result['bill'];
    final rawId = bill is Map<String, dynamic> ? bill['id'] : result['id'];
    if (rawId is int) return rawId;
    if (rawId is num) return rawId.toInt();
    return int.tryParse(rawId?.toString() ?? '');
  }

  Future<void> _createDebtsForSavedBill(
    BillProvider provider,
    AuthProvider auth,
  ) async {
    final currentUserId = auth.userId;
    if (currentUserId == null) {
      throw Exception('Current user is missing');
    }

    final failedNames = <String>[];
    for (final person in provider.people) {
      final participantUserId = person.userId;
      final amount = provider.getPersonTotal(person.id);
      if (participantUserId == null ||
          participantUserId == currentUserId ||
          amount <= 0) {
        continue;
      }

      final billId = _savedBillId;
      final debtKey =
          '${billId ?? 'bill'}:$participantUserId:${amount.toStringAsFixed(2)}';
      if (_createdDebtKeys.contains(debtKey)) continue;

      try {
        await auth.api.createDebt(
          fromUserId: participantUserId,
          toUserId: currentUserId,
          amount: amount,
          billId: billId,
          description: provider.billTitle.trim().isEmpty
              ? 'Bill split'
              : provider.billTitle.trim(),
        );
        _createdDebtKeys.add(debtKey);
      } catch (_) {
        failedNames.add(person.name);
      }
    }

    if (failedNames.isNotEmpty) {
      throw Exception(
        'Bill saved, but debts failed for ${failedNames.join(', ')}',
      );
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _totalCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    final report = ShareHelper.generateReport(provider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Ambient blobs
            Positioned(
              top: -60,
              left: -40,
              child: _Blob(color: const Color(0xFF22D3EE), size: 220),
            ),
            Positioned(
              bottom: 80,
              right: -50,
              child: _Blob(color: const Color(0xFFA78BFA), size: 160),
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
                        const Expanded(
                          child: Text(
                            'Итоги',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: provider.category.color.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                provider.category.icon,
                                size: 14,
                                color: provider.category.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                provider.category.name,
                                style: TextStyle(
                                  color: provider.category.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // ── Success + confetti badge ────────────────
                          FadeTransition(
                            opacity: _confettiController,
                            child: SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(0, -0.4),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _confettiController,
                                      curve: Curves.easeOutBack,
                                    ),
                                  ),
                              child: LiquidGlass(
                                borderRadius: BorderRadius.circular(50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.celebration_rounded,
                                      size: 18,
                                      color: AppTheme.success,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Счёт разделён!',
                                      style: TextStyle(
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppTheme.success,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Animated total pill ─────────────────────
                          AnimatedBuilder(
                            animation: _totalCountAnim,
                            builder: (_, __) => LiquidGlass(
                              borderRadius: BorderRadius.circular(24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${_totalCountAnim.value.toStringAsFixed(0)} ${provider.currency.symbol}',
                                    style: AppTheme.moneyStyle(fontSize: 36),
                                  ),
                                  if (provider.serviceChargeEnabled) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'включая ${provider.serviceChargePercent.toStringAsFixed(0)}% обслуживания '
                                      '(${provider.serviceChargeAmount.toStringAsFixed(0)} ${provider.currency.symbol})',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Stats row ──────────────────────────────
                          LiquidGlass(
                            borderRadius: BorderRadius.circular(20),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatChip(
                                  value: '${provider.items.length}',
                                  label: 'Позиций',
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                _StatChip(
                                  value: '${provider.people.length}',
                                  label: 'Человек',
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                _StatChip(
                                  value: '${_sharedCount(provider)}',
                                  label: 'Общих',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Per-person breakdown ────────────────────
                          ...provider.people.map((person) {
                            final items = provider.getPersonItems(person.id);
                            final total = provider.getPersonTotal(person.id);
                            return _PersonCard(
                              person: person,
                              items: items,
                              total: total,
                              provider: provider,
                            );
                          }),

                          // ── Go Home button ──────────────────────────
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: LiquidGlass(
                              borderRadius: BorderRadius.circular(16),
                              interactive: true,
                              onTap: () =>
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const HomeShell(),
                                    ),
                                    (route) => false,
                                  ),
                              padding: EdgeInsets.zero,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.home_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'На главную',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── Save button ─────────────────────────────
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: _saved
                                ? LiquidGlass(
                                    borderRadius: BorderRadius.circular(16),
                                    padding: EdgeInsets.zero,
                                    child: const Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: AppTheme.success,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Сохранено в историю',
                                            style: TextStyle(
                                              color: AppTheme.success,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: FilledButton.icon(
                                      onPressed: _saving ? null : _saveBill,
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF1A1A1A),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.save_rounded,
                                              size: 18,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                      label: Text(
                                        _saving
                                            ? 'Сохраняем...'
                                            : 'Сохранить в историю',
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // ── Bottom share bar ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: LiquidGlass(
                              borderRadius: BorderRadius.circular(12),
                              interactive: true,
                              onTap: () => ShareHelper.shareViaTelegram(report),
                              padding: EdgeInsets.zero,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.send_rounded,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Telegram',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: LiquidGlass(
                                    borderRadius: BorderRadius.circular(12),
                                    interactive: true,
                                    onTap: () =>
                                        ShareHelper.shareViaWhatsApp(report),
                                    padding: EdgeInsets.zero,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.chat_rounded,
                                          size: 16,
                                          color: AppTheme.textSecondary,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'WhatsApp',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
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
                                  height: 44,
                                  child: LiquidGlass(
                                    borderRadius: BorderRadius.circular(12),
                                    interactive: true,
                                    onTap: () =>
                                        ShareHelper.shareViaSystem(report),
                                    padding: EdgeInsets.zero,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.share_rounded,
                                          size: 16,
                                          color: AppTheme.textSecondary,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Ещё',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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

  int _sharedCount(BillProvider p) =>
      p.items.where((i) => p.getPeopleForItem(i.id).length > 1).length;
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  final dynamic person;
  final List<dynamic> items;
  final double total;
  final BillProvider provider;

  const _PersonCard({
    required this.person,
    required this.items,
    required this.total,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.06),
            blurRadius: 20,
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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: person.avatarColor,
                  child: Text(
                    person.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${items.length} позиц.',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(0)} ${provider.currency.symbol}',
                  style: AppTheme.moneyStyle(
                    fontSize: 20,
                  ).copyWith(color: person.avatarColor),
                ),
              ],
            ),
            // Mini progress bar
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: provider.total > 0 ? (total / provider.total) : 0,
                backgroundColor: AppTheme.surfaceLight,
                valueColor: AlwaysStoppedAnimation<Color>(person.avatarColor),
                minHeight: 4,
              ),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...items.map((item) {
                final splitPrice = provider.getItemSplitPrice(
                  item.id,
                  person.id,
                );
                final unitCount = provider.getPersonUnitCount(
                  item.id,
                  person.id,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name + (unitCount > 1 ? ' ×$unitCount' : ''),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${splitPrice.toStringAsFixed(0)} ${provider.currency.symbol}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
      ],
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
