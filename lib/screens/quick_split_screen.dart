import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/bill_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import '../utils/share_helper.dart';

class QuickSplitScreen extends StatefulWidget {
  const QuickSplitScreen({super.key});

  @override
  State<QuickSplitScreen> createState() => _QuickSplitScreenState();
}

class _QuickSplitScreenState extends State<QuickSplitScreen>
    with TickerProviderStateMixin {
  final _totalController = TextEditingController();
  bool _showResult = false;
  bool _saved = false;
  bool _saving = false;
  late AnimationController _resultController;

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _totalController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  void _calculate() {
    final total = double.tryParse(_totalController.text.replaceAll(',', '.'));
    if (total == null || total <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите сумму')));
      return;
    }
    final provider = context.read<BillProvider>();
    provider.addItem('Общий счёт', total);
    provider.setSplitMode(SplitMode.equal);

    setState(() => _showResult = true);
    _resultController.forward(from: 0);
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
      await auth.api.saveBill(
        total: provider.total,
        serviceChargePercent: provider.serviceChargePercent,
        items: provider.items
            .map((i) => {'name': i.name, 'price': i.price})
            .toList(),
        people: provider.people
            .map((p) => {'name': p.name, 'id': p.id})
            .toList(),
        assignments: {},
        title: provider.billTitle,
        category: provider.category.id,
        currency: provider.currency.code,
        splitMode: provider.splitMode.name,
      );
      await provider.clearDraft();
      if (mounted) {
        setState(() {
          _saved = true;
          _saving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Счёт сохранён')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Не удалось сохранить')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BillProvider>();
    final currSymbol = provider.currency.symbol;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -30,
              child: _Blob(color: const Color(0xFFA78BFA), size: 180),
            ),
            Positioned(
              bottom: 100,
              left: -40,
              child: _Blob(color: const Color(0xFF22D3EE), size: 140),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────
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
                            'Быстрый сплит',
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),

                          // ── People chips ──────────────────────────
                          LiquidGlass(
                            borderRadius: BorderRadius.circular(20),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Участники (${provider.people.length})',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: provider.people.map((p) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.avatarColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                          color: p.avatarColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: p.avatarColor,
                                            child: Text(
                                              p.name[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            p.name,
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          if (!_showResult) ...[
                            // ── Total input ─────────────────────────
                            LiquidGlass(
                              borderRadius: BorderRadius.circular(24),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.flash_on_rounded,
                                    size: 40,
                                    color: AppTheme.accent,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Введите общую сумму',
                                    style: AppTheme.headingStyle(fontSize: 18),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Разделим поровну на ${provider.people.length} человек',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextField(
                                    controller: _totalController,
                                    autofocus: true,
                                    textAlign: TextAlign.center,
                                    style: AppTheme.moneyStyle(fontSize: 36),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[\d.,]'),
                                      ),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle:
                                          AppTheme.moneyStyle(
                                            fontSize: 36,
                                          ).copyWith(
                                            color: AppTheme.textSecondary
                                                .withValues(alpha: 0.3),
                                          ),
                                      suffixText: currSymbol,
                                      suffixStyle: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 18,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Service charge toggle ───────────────
                            _buildServiceCharge(provider),
                          ] else ...[
                            // ── Result ──────────────────────────────
                            FadeTransition(
                              opacity: _resultController,
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: _resultController,
                                        curve: Curves.easeOutBack,
                                      ),
                                    ),
                                child: Column(
                                  children: [
                                    // Success badge
                                    LiquidGlass(
                                      borderRadius: BorderRadius.circular(50),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: AppTheme.success,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Готово!',
                                            style: TextStyle(
                                              color: AppTheme.success,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Total
                                    LiquidGlass(
                                      borderRadius: BorderRadius.circular(24),
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${provider.total.toStringAsFixed(0)} $currSymbol',
                                            style: AppTheme.moneyStyle(
                                              fontSize: 32,
                                            ),
                                          ),
                                          if (provider.serviceChargeEnabled)
                                            Text(
                                              'включая ${provider.serviceChargePercent.toStringAsFixed(0)}% обслуживания',
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Per-person cards
                                    ...provider.people.map((person) {
                                      final perPerson = provider.getPersonTotal(
                                        person.id,
                                      );
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.06,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor:
                                                  person.avatarColor,
                                              child: Text(
                                                person.name[0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                person.name,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${perPerson.toStringAsFixed(0)} $currSymbol',
                                              style:
                                                  AppTheme.moneyStyle(
                                                    fontSize: 18,
                                                  ).copyWith(
                                                    color: person.avatarColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),

                                    const SizedBox(height: 16),

                                    // Save button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: _saved
                                          ? LiquidGlass(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              padding: EdgeInsets.zero,
                                              child: const Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      size: 18,
                                                      color: AppTheme.success,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Сохранено',
                                                      style: TextStyle(
                                                        color: AppTheme.success,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : OutlinedButton.icon(
                                              onPressed: _saving
                                                  ? null
                                                  : _saveBill,
                                              icon: _saving
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: AppTheme
                                                                .primary,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.save_rounded,
                                                      size: 18,
                                                    ),
                                              label: Text(
                                                _saving
                                                    ? 'Сохраняем...'
                                                    : 'Сохранить',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                  color: AppTheme.primary,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),

                  // ── Bottom button ─────────────────────────────
                  if (!_showResult)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: FilledButton(
                              onPressed: _calculate,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.flash_on_rounded,
                                    size: 20,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Разделить',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: LiquidGlass(
                                  borderRadius: BorderRadius.circular(14),
                                  interactive: true,
                                  onTap: () => ShareHelper.shareViaTelegram(
                                    ShareHelper.generateReport(provider),
                                  ),
                                  padding: EdgeInsets.zero,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
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
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: LiquidGlass(
                                  borderRadius: BorderRadius.circular(14),
                                  interactive: true,
                                  onTap: () => ShareHelper.shareViaSystem(
                                    ShareHelper.generateReport(provider),
                                  ),
                                  padding: EdgeInsets.zero,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.share_rounded,
                                        size: 16,
                                        color: AppTheme.textSecondary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Поделиться',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildServiceCharge(BillProvider provider) {
    const percentages = [0.0, 10.0, 15.0];
    return LiquidGlass(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_rounded,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          const Text(
            'Обслуживание',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ...percentages.map((pct) {
            final isZero = pct == 0;
            final isActive = isZero
                ? !provider.serviceChargeEnabled
                : (provider.serviceChargeEnabled &&
                      provider.serviceChargePercent == pct);
            return GestureDetector(
              onTap: () {
                if (isZero) {
                  provider.toggleServiceCharge(false);
                  provider.setServiceChargePercent(0);
                } else {
                  provider.toggleServiceCharge(true);
                  provider.setServiceChargePercent(pct);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primary : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.primary
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF1A1A1A)
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
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
