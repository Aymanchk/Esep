import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bill_item.dart';
import '../providers/bill_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import '../utils/ocr_helper.dart';
import 'summary_screen.dart';

const _splitModeLabels = {
  SplitMode.byItems: 'По позициям',
  SplitMode.equal: 'Поровну',
  SplitMode.percentage: 'Проценты',
  SplitMode.shares: 'Доли',
};

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    bool isKg = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Добавить позицию'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'Название'),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Единица:', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('шт.'),
                    selected: !isKg,
                    onSelected: (_) => setState(() => isKg = false),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('кг'),
                    selected: isKg,
                    onSelected: (_) => setState(() => isKg = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  hintText: isKg ? 'Цена за 1 кг' : 'Цена за 1 шт.',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
              ),
              if (isKg) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Вес (кг), напр. 0.5',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final pricePerUnit = double.tryParse(
                  priceCtrl.text.replaceAll(',', '.'),
                );
                if (name.isEmpty || pricePerUnit == null || pricePerUnit <= 0) {
                  return;
                }
                if (isKg) {
                  final weight = double.tryParse(
                    weightCtrl.text.replaceAll(',', '.'),
                  );
                  if (weight == null || weight <= 0) return;
                  final totalPrice =
                      (pricePerUnit * weight * 100).round() / 100;
                  context.read<BillProvider>().addItem(
                    name,
                    totalPrice,
                    isWeightBased: true,
                    weightKg: weight,
                  );
                } else {
                  context.read<BillProvider>().addItem(name, pricePerUnit);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, BillProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Валюта',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...Currency.values.map((c) {
                final isActive = provider.currency == c;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        c.symbol,
                        style: TextStyle(
                          color: isActive
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    c.code,
                    style: TextStyle(
                      color: isActive ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isActive
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    provider.setCurrency(c);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Сканировать чек',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _ScanOption(
                icon: Icons.camera_alt_rounded,
                color: AppTheme.primary,
                title: 'Камера',
                subtitle: 'Сфотографировать чек',
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              _ScanOption(
                icon: Icons.photo_library_rounded,
                color: const Color(0xFFA78BFA),
                title: 'Галерея',
                subtitle: 'Выбрать фото чека',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !context.mounted) return;
    try {
      final items = await OcrHelper.scanReceipt(source: source);
      if (items.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Не удалось распознать. Попробуйте при хорошем освещении.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      if (context.mounted) {
        context.read<BillProvider>().addItemsFromOcr(items);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Добавлено ${items.length} позиций')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -70,
              child: _Blob(color: const Color(0xFF22D3EE), size: 130),
            ),
            SafeArea(
              child: Consumer<BillProvider>(
                builder: (context, provider, _) {
                  // Sum of item-cost not yet covered by anyone. Items with
                  // shares > quantity contribute 0 (over-allocated). Items
                  // with shares < quantity contribute the leftover units'
                  // worth. Items with no shares contribute their full cost.
                  final unassignedTotal = provider.items.fold<double>(0, (
                    s,
                    i,
                  ) {
                    final remaining = provider.getRemainingUnits(i.id);
                    return remaining > 0 ? s + i.price * remaining : s;
                  });

                  return Column(
                    children: [
                      // ── AppBar ───────────────────────────────────────
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
                                'Разделить счёт',
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
                                horizontal: 8,
                                vertical: 4,
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
                                    size: 13,
                                    color: provider.category.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    provider.category.name,
                                    style: TextStyle(
                                      color: provider.category.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Split mode tabs ─────────────────────────────
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: SplitMode.values.map((mode) {
                            final isActive = provider.splitMode == mode;
                            return GestureDetector(
                              onTap: () => provider.setSplitMode(mode),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppTheme.primary
                                      : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: isActive
                                        ? AppTheme.primary
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  _splitModeLabels[mode]!,
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(0xFF1A1A1A)
                                        : AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Floating total pill ──────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: () => _showCurrencyPicker(context, provider),
                          child: LiquidGlass(
                            borderRadius: BorderRadius.circular(50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${provider.total.toStringAsFixed(0)} ${provider.currency.symbol}',
                                      style: AppTheme.moneyStyle(fontSize: 22),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        provider.currency.code,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (provider.serviceChargeEnabled)
                                  Text(
                                    'включая ${provider.serviceChargePercent.toStringAsFixed(0)}% обслуживания',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Service charge ─────────────────────
                              _buildServiceCharge(provider),
                              const SizedBox(height: 16),

                              // ── Action buttons ─────────────────────
                              Row(
                                children: [
                                  Expanded(
                                    child: _ActionButton(
                                      icon: Icons.add_rounded,
                                      label: 'Добавить',
                                      color: AppTheme.primary,
                                      onTap: _showAddItemDialog,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ActionButton(
                                      icon: Icons.camera_alt_rounded,
                                      label: 'Скан чека',
                                      color: const Color(0xFFA78BFA),
                                      onTap: _scanReceipt,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ── Items list ─────────────────────────
                              Row(
                                children: [
                                  Text(
                                    'Позиции (${provider.items.length})',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (provider.unassignedItems.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${provider.unassignedItems.length} не распределено',
                                        style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              if (provider.items.isEmpty)
                                _EmptyItemsState()
                              else
                                ...provider.items.map((item) {
                                  final assigned = provider.getPeopleForItem(
                                    item.id,
                                  );
                                  return _ItemTile(
                                    item: item,
                                    assignedPeople: assigned,
                                    provider: provider,
                                  );
                                }),

                              const SizedBox(height: 20),

                              // ── Mode-specific UI ──────────────────────
                              if (provider.splitMode == SplitMode.byItems) ...[
                                // ── Drop targets ───────────────────────
                                if (provider.people.isNotEmpty) ...[
                                  const Text(
                                    'Перетащите позиции на участников',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _PeopleDropRow(provider: provider),
                                ],

                                if (unassignedTotal > 0) ...[
                                  const SizedBox(height: 12),
                                  Center(
                                    child: LiquidGlass(
                                      borderRadius: BorderRadius.circular(50),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'Осталось: ${unassignedTotal.toStringAsFixed(0)} ${provider.currency.symbol}',
                                        style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ] else if (provider.splitMode ==
                                  SplitMode.equal) ...[
                                // ── Equal split ───────────────────────
                                if (provider.people.isNotEmpty &&
                                    provider.items.isNotEmpty)
                                  _EqualSplitPreview(provider: provider),
                              ] else if (provider.splitMode ==
                                  SplitMode.percentage) ...[
                                // ── Percentage split ──────────────────
                                if (provider.people.isNotEmpty)
                                  _PercentageSplitEditor(provider: provider),
                              ] else if (provider.splitMode ==
                                  SplitMode.shares) ...[
                                // ── Shares split ──────────────────────
                                if (provider.people.isNotEmpty)
                                  _SharesSplitEditor(provider: provider),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),

                      // ── Bottom button ────────────────────────────────
                      _BottomBar(
                        enabled:
                            provider.items.isNotEmpty &&
                            (provider.splitMode != SplitMode.byItems ||
                                provider.unassignedItems.isEmpty),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SummaryScreen(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final BillItem item;
  final Set<String> assignedPeople;
  final BillProvider provider;

  const _ItemTile({
    required this.item,
    required this.assignedPeople,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    // Items can always be dragged — extra drops on new people share the
    // item proportionally (handled in BillProvider).
    return Draggable<BillItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              '${item.name}  ×1  ${item.price.toStringAsFixed(0)} ${provider.currency.symbol}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _card(context)),
      child: _card(context),
    );
  }

  Widget _card(BuildContext context) {
    final remaining = provider.getRemainingUnits(item.id);
    final totalAssigned = provider.getTotalAssignedUnits(item.id);
    final isShared = totalAssigned > item.quantity;
    final isFullyAssigned = totalAssigned == item.quantity;
    final isPartiallyAssigned =
        totalAssigned > 0 && totalAssigned < item.quantity;

    Color bgColor = AppTheme.surface;
    Color borderColor = Colors.white.withValues(alpha: 0.06);
    if (isShared) {
      bgColor = AppTheme.primary.withValues(alpha: 0.08);
      borderColor = AppTheme.primary.withValues(alpha: 0.30);
    } else if (isFullyAssigned) {
      bgColor = const Color(0xFF22C55E).withValues(alpha: 0.08);
      borderColor = const Color(0xFF22C55E).withValues(alpha: 0.30);
    } else if (isPartiallyAssigned) {
      bgColor = AppTheme.accent.withValues(alpha: 0.08);
      borderColor = AppTheme.accent.withValues(alpha: 0.25);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Person avatars — tap to unassign 1 share
          if (assignedPeople.isNotEmpty) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: assignedPeople.take(4).map((pid) {
                final person = provider.people.firstWhere((p) => p.id == pid);
                final unitCount = provider.getPersonUnitCount(item.id, pid);
                return GestureDetector(
                  onTap: () => provider.unassignOneUnit(item.id, pid),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: person.avatarColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.background,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            person.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (unitCount > 1)
                        Positioned(
                          bottom: -2,
                          right: 2,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.background,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$unitCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 4),
          ],

          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: isFullyAssigned
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  item.isWeightBased
                      ? '${(item.price / item.weightKg).toStringAsFixed(0)} сом/кг × ${item.weightKg} кг = ${item.totalPrice.toStringAsFixed(0)} ${provider.currency.symbol}'
                      : '${item.price.toStringAsFixed(0)} × ${item.quantity} = ${item.totalPrice.toStringAsFixed(0)} ${provider.currency.symbol}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // State badge
          if (isShared)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'на $totalAssigned',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (isFullyAssigned)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.check_circle_rounded,
                color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                size: 16,
              ),
            )
          else if (isPartiallyAssigned)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$remaining ост.',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // Quantity / weight controls
          if (item.isWeightBased)
            GestureDetector(
              onTap: () => _showEditWeightDialog(context, item, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${item.weightKg} кг',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: item.quantity > 1
                      ? () =>
                            provider.setItemQuantity(item.id, item.quantity - 1)
                      : null,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 14,
                      color: item.quantity > 1
                          ? AppTheme.textSecondary
                          : AppTheme.textSecondary.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      provider.setItemQuantity(item.id, item.quantity + 1),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),

          // Delete
          GestureDetector(
            onTap: () => provider.removeItem(item.id),
            child: Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditWeightDialog(
    BuildContext context,
    BillItem item,
    BillProvider provider,
  ) {
    final pricePerKg = item.weightKg > 0 ? item.price / item.weightKg : 0.0;
    final weightCtrl = TextEditingController(text: item.weightKg.toString());
    final priceCtrl = TextEditingController(
      text: pricePerKg.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить вес'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(hintText: 'Цена за 1 кг'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              decoration: const InputDecoration(hintText: 'Вес (кг)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
              final p = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
              if (w != null && w > 0 && p != null && p > 0) {
                provider.setItemWeight(item.id, w, p);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _PeopleDropRow extends StatelessWidget {
  final BillProvider provider;
  const _PeopleDropRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, 0.82, 0.94, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  provider.people
                      .map((person) {
                        final personTotal = provider.getPersonTotal(person.id);
                        return DragTarget<BillItem>(
                          onWillAcceptWithDetails: (_) => true,
                          onAcceptWithDetails: (details) {
                            provider.assignOneUnit(details.data.id, person.id);
                          },
                          builder: (context, candidates, _) {
                            final hovering = candidates.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: hovering ? 64 : 56,
                                    height: hovering ? 64 : 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: hovering
                                          ? person.avatarColor
                                          : person.avatarColor.withValues(
                                              alpha: 0.75,
                                            ),
                                      border: Border.all(
                                        color: hovering
                                            ? const Color(0xFF67E8F9)
                                            : person.avatarColor,
                                        width: hovering ? 3 : 2,
                                      ),
                                      boxShadow: hovering
                                          ? [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF22D3EE,
                                                ).withValues(alpha: 0.6),
                                                blurRadius: 20,
                                                spreadRadius: 3,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        person.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    person.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (personTotal > 0)
                                    Text(
                                      '${personTotal.toStringAsFixed(0)} ${provider.currency.symbol}',
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      })
                      .cast<Widget>()
                      .toList()
                    ..add(_AddPersonButton(provider: provider)),
            ),
          ),
        ),
        if (provider.people.length > 2)
          Positioned(
            right: 0,
            top: 16,
            child: IgnorePointer(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddPersonButton extends StatelessWidget {
  final BillProvider provider;
  const _AddPersonButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddPersonDialog(context),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Добавить',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  void _showAddPersonDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить участника'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'Имя'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                provider.addPerson(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(14),
      interactive: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _BottomBar({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: enabled
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: onTap,
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
                        Text(
                          'Разделить счёт',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Color(0xFF1A1A1A),
                        ),
                      ],
                    ),
                  ),
                )
              : FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: AppTheme.primary.withValues(
                      alpha: 0.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Разделить счёт',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ScanOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 40, color: AppTheme.primary),
          SizedBox(height: 12),
          Text(
            'Пока тут пусто\nДобавьте позиции или сканируйте чек',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EqualSplitPreview extends StatelessWidget {
  final BillProvider provider;
  const _EqualSplitPreview({required this.provider});

  @override
  Widget build(BuildContext context) {
    final perPerson = provider.people.isEmpty
        ? 0.0
        : provider.total / provider.people.length;
    final sym = provider.currency.symbol;

    return LiquidGlass(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.balance_rounded, size: 18, color: AppTheme.accent),
              SizedBox(width: 8),
              Text(
                'Поровну',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...provider.people.map((person) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: person.avatarColor,
                    child: Text(
                      person.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      person.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${perPerson.toStringAsFixed(0)} $sym',
                    style: AppTheme.moneyStyle(
                      fontSize: 15,
                    ).copyWith(color: person.avatarColor),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PercentageSplitEditor extends StatelessWidget {
  final BillProvider provider;
  const _PercentageSplitEditor({required this.provider});

  @override
  Widget build(BuildContext context) {
    final sym = provider.currency.symbol;
    final totalPct = provider.percentages.values.fold<double>(
      0,
      (s, v) => s + v,
    );

    return LiquidGlass(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart_rounded,
                size: 18,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Проценты',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (totalPct - 100).abs() < 0.5
                      ? AppTheme.success.withValues(alpha: 0.15)
                      : AppTheme.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${totalPct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: (totalPct - 100).abs() < 0.5
                        ? AppTheme.success
                        : AppTheme.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...provider.people.map((person) {
            final pct = provider.percentages[person.id] ?? 0;
            final amount = provider.getPersonTotal(person.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: person.avatarColor,
                    child: Text(
                      person.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${amount.toStringAsFixed(0)} $sym',
                          style: TextStyle(
                            color: person.avatarColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    height: 36,
                    child: TextField(
                      onChanged: (v) {
                        final val = double.tryParse(v) ?? 0;
                        provider.setPersonPercentage(person.id, val);
                      },
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '${pct.toStringAsFixed(0)}',
                        suffixText: '%',
                        suffixStyle: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SharesSplitEditor extends StatelessWidget {
  final BillProvider provider;
  const _SharesSplitEditor({required this.provider});

  @override
  Widget build(BuildContext context) {
    final sym = provider.currency.symbol;

    return LiquidGlass(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.grid_view_rounded,
                size: 18,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Доли',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Всего: ${provider.totalShares}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...provider.people.map((person) {
            final s = provider.shares[person.id] ?? 1;
            final amount = provider.getPersonTotal(person.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: person.avatarColor,
                    child: Text(
                      person.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${amount.toStringAsFixed(0)} $sym',
                          style: TextStyle(
                            color: person.avatarColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: s > 1
                            ? () => provider.setPersonShares(person.id, s - 1)
                            : null,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 16,
                            color: s > 1
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Center(
                          child: Text(
                            '$s',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => provider.setPersonShares(person.id, s + 1),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
