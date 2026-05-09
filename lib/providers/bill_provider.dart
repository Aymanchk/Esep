import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill_item.dart';
import '../models/person.dart';
import '../models/expense_category.dart';

enum SplitMode { byItems, equal, percentage, shares }

enum Currency { kgs, usd, eur, rub, kzt }

extension CurrencyExt on Currency {
  String get symbol {
    switch (this) {
      case Currency.kgs:
        return 'сом';
      case Currency.usd:
        return '\$';
      case Currency.eur:
        return '€';
      case Currency.rub:
        return '₽';
      case Currency.kzt:
        return '₸';
    }
  }

  String get code {
    switch (this) {
      case Currency.kgs:
        return 'KGS';
      case Currency.usd:
        return 'USD';
      case Currency.eur:
        return 'EUR';
      case Currency.rub:
        return 'RUB';
      case Currency.kzt:
        return 'KZT';
    }
  }
}

class BillProvider extends ChangeNotifier {
  static const _draftKey = 'fs_bill_draft_v1';
  static const _draftVersion = 1;

  final List<BillItem> _items = [];
  final List<Person> _people = [];
  double _serviceChargePercent = 0.0;
  bool _serviceChargeEnabled = false;

  // itemId -> personId -> unit count
  final Map<String, Map<String, int>> _assignments = {};

  int _nextItemId = 0;
  int _nextPersonId = 0;
  ExpenseCategory _category = ExpenseCategory.all.last;
  SplitMode _splitMode = SplitMode.byItems;
  Currency _currency = Currency.kgs;
  String _billTitle = '';

  final Map<String, double> _percentages = {};
  final Map<String, int> _shares = {};
  Timer? _draftSaveDebounce;
  bool _suspendAutosave = false;
  bool _restoredFromDraft = false;

  List<BillItem> get items => List.unmodifiable(_items);
  List<Person> get people => List.unmodifiable(_people);
  double get serviceChargePercent => _serviceChargePercent;
  bool get serviceChargeEnabled => _serviceChargeEnabled;

  // Backward-compat getter: itemId -> set of personIds with ≥1 unit
  Map<String, Set<String>> get assignments => _assignments.map(
    (itemId, personMap) => MapEntry(
      itemId,
      personMap.entries.where((e) => e.value > 0).map((e) => e.key).toSet(),
    ),
  );

  /// Raw assignment matrix: itemId -> personId -> unit count.
  /// Use this when persisting a bill so multi-unit assignments survive the
  /// round-trip through the backend.
  Map<String, Map<String, int>> get unitAssignments => _assignments.map(
    (itemId, personMap) => MapEntry(itemId, Map<String, int>.from(personMap)),
  );

  ExpenseCategory get category => _category;
  SplitMode get splitMode => _splitMode;
  Currency get currency => _currency;
  String get billTitle => _billTitle;
  Map<String, double> get percentages => Map.unmodifiable(_percentages);
  Map<String, int> get shares => Map.unmodifiable(_shares);
  bool get restoredFromDraft => _restoredFromDraft;
  bool get hasDraftContent =>
      _people.isNotEmpty ||
      _items.isNotEmpty ||
      _billTitle.trim().isNotEmpty ||
      _assignments.isNotEmpty ||
      _percentages.isNotEmpty ||
      _shares.isNotEmpty ||
      _serviceChargeEnabled ||
      _serviceChargePercent > 0 ||
      _category.id != ExpenseCategory.all.last.id ||
      _currency != Currency.kgs ||
      _splitMode != SplitMode.byItems;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_suspendAutosave) {
      _scheduleDraftSave();
    }
  }

  @override
  void dispose() {
    _draftSaveDebounce?.cancel();
    super.dispose();
  }

  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get serviceChargeAmount =>
      _serviceChargeEnabled ? subtotal * _serviceChargePercent / 100 : 0;

  double get total => subtotal + serviceChargeAmount;

  int get totalShares => _shares.values.fold(0, (sum, s) => sum + s);

  // --- Unit-based assignment helpers ---

  int getPersonUnitCount(String itemId, String personId) =>
      _assignments[itemId]?[personId] ?? 0;

  int getTotalAssignedUnits(String itemId) =>
      _assignments[itemId]?.values.fold(0, (s, c) => (s ?? 0) + c) ?? 0;

  int getRemainingUnits(String itemId) {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx < 0) return 0;
    return _items[idx].quantity - getTotalAssignedUnits(itemId);
  }

  /// Assigns one share of an item to a person. Sharing is allowed: if the
  /// total assigned shares exceed the item's quantity, the item's total
  /// price is divided proportionally across all shares (see
  /// [getPersonSubtotal]).
  void assignOneUnit(String itemId, String personId) {
    if (_items.indexWhere((i) => i.id == itemId) < 0) return;
    _assignments.putIfAbsent(itemId, () => {});
    _assignments[itemId]![personId] =
        (_assignments[itemId]![personId] ?? 0) + 1;
    notifyListeners();
  }

  void unassignOneUnit(String itemId, String personId) {
    final current = _assignments[itemId]?[personId] ?? 0;
    if (current <= 0) return;
    if (current == 1) {
      _assignments[itemId]!.remove(personId);
    } else {
      _assignments[itemId]![personId] = current - 1;
    }
    if (_assignments[itemId]?.isEmpty ?? false) {
      _assignments.remove(itemId);
    }
    notifyListeners();
  }

  void setItemQuantity(String itemId, int quantity) {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx < 0 || quantity < 1) return;
    _items[idx].quantity = quantity;
    notifyListeners();
  }

  void setItemWeight(String itemId, double weightKg, double pricePerKg) {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx < 0 || weightKg <= 0) return;
    _items[idx].weightKg = weightKg;
    _items[idx].price = (pricePerKg * weightKg * 100).round() / 100;
    notifyListeners();
  }

  // --- Category ---

  void setCategory(ExpenseCategory cat) {
    _category = cat;
    if (cat.defaultServicePercent > 0) {
      _serviceChargeEnabled = true;
      _serviceChargePercent = cat.defaultServicePercent;
    } else {
      _serviceChargeEnabled = false;
      _serviceChargePercent = 0.0;
    }
    notifyListeners();
  }

  // --- Split Mode ---

  void setSplitMode(SplitMode mode) {
    _splitMode = mode;
    notifyListeners();
  }

  // --- Currency ---

  void setCurrency(Currency c) {
    _currency = c;
    notifyListeners();
  }

  // --- Title ---

  void setBillTitle(String title) {
    _billTitle = title;
    notifyListeners();
  }

  // --- Items ---

  void addItem(
    String name,
    double price, {
    int quantity = 1,
    bool isWeightBased = false,
    double weightKg = 0,
  }) {
    _items.add(
      BillItem(
        id: 'item_${_nextItemId++}',
        name: name,
        price: price,
        quantity: quantity,
        isWeightBased: isWeightBased,
        weightKg: weightKg,
      ),
    );
    notifyListeners();
  }

  void removeItem(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    _assignments.remove(itemId);
    notifyListeners();
  }

  void addItemsFromOcr(List<Map<String, dynamic>> ocrItems) {
    for (final item in ocrItems) {
      _items.add(
        BillItem(
          id: 'item_${_nextItemId++}',
          name: item['name'] as String,
          price: (item['price'] as num).toDouble(),
        ),
      );
    }
    notifyListeners();
  }

  // --- People ---

  void addPerson(String name, {int? userId, String? avatarUrl}) {
    final colorIndex = _nextPersonId % Person.avatarColors.length;
    _people.add(
      Person(
        id: 'person_${_nextPersonId++}',
        name: name,
        avatarColor: Person.avatarColors[colorIndex],
        userId: userId,
        avatarUrl: avatarUrl,
      ),
    );
    notifyListeners();
  }

  void removePerson(String personId) {
    _people.removeWhere((p) => p.id == personId);
    for (final personMap in _assignments.values) {
      personMap.remove(personId);
    }
    _percentages.remove(personId);
    _shares.remove(personId);
    notifyListeners();
  }

  // --- Assignment queries ---

  bool isItemAssignedToPerson(String itemId, String personId) =>
      getPersonUnitCount(itemId, personId) > 0;

  Set<String> getPeopleForItem(String itemId) =>
      _assignments[itemId]?.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .toSet() ??
      {};

  List<BillItem> getPersonItems(String personId) => _items
      .where((item) => getPersonUnitCount(item.id, personId) > 0)
      .toList();

  /// Items with no people assigned yet. Used to flag the bill as incomplete
  /// in `byItems` mode.
  List<BillItem> get unassignedItems =>
      _items.where((item) => getTotalAssignedUnits(item.id) == 0).toList();

  // --- Percentages ---

  void setPersonPercentage(String personId, double pct) {
    _percentages[personId] = pct;
    notifyListeners();
  }

  // --- Shares ---

  void setPersonShares(String personId, int count) {
    _shares[personId] = count;
    notifyListeners();
  }

  // --- Service Charge ---

  void setServiceChargePercent(double percent) {
    _serviceChargePercent = percent;
    notifyListeners();
  }

  void toggleServiceCharge(bool enabled) {
    _serviceChargeEnabled = enabled;
    notifyListeners();
  }

  // --- Calculations ---

  double getPersonSubtotal(String personId) {
    switch (_splitMode) {
      case SplitMode.equal:
        if (_people.isEmpty) return 0;
        return subtotal / _people.length;

      case SplitMode.percentage:
        final pct = _percentages[personId] ?? 0;
        return subtotal * pct / 100;

      case SplitMode.shares:
        final personShares = _shares[personId] ?? 1;
        final total = totalShares;
        if (total == 0) return 0;
        return subtotal * personShares / total;

      case SplitMode.byItems:
        double sum = 0;
        for (final item in _items) {
          sum += _personItemCost(item, personId);
        }
        return sum;
    }
  }

  /// A person's share of a single item. Two regimes:
  /// - **Per-unit** (totalShares ≤ quantity): person pays `price * theirShares`,
  ///   leaving any unallocated units uncharged.
  /// - **Proportional** (totalShares > quantity): the item is shared, so its
  ///   full cost (`price * quantity`) splits across every share.
  double _personItemCost(BillItem item, String personId) {
    final personShares = getPersonUnitCount(item.id, personId);
    if (personShares == 0) return 0;
    final totalShares = getTotalAssignedUnits(item.id);
    if (totalShares == 0) return 0;
    if (totalShares <= item.quantity) {
      return item.price * personShares;
    }
    return item.totalPrice * personShares / totalShares;
  }

  double getPersonTotal(String personId) {
    final sub = getPersonSubtotal(personId);
    if (_serviceChargeEnabled) {
      return sub + sub * _serviceChargePercent / 100;
    }
    return sub;
  }

  double getItemSplitPrice(String itemId, String personId) {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx < 0) return 0;
    return _personItemCost(_items[idx], personId);
  }

  void markRestoredDraftContinued() {
    _restoredFromDraft = false;
  }

  Future<bool> hasSavedDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_draftKey);
  }

  Future<void> restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _draftVersion) {
        await clearDraft();
        return;
      }

      _suspendAutosave = true;
      _items
        ..clear()
        ..addAll(
          (decoded['items'] as List? ?? []).map((rawItem) {
            final item = Map<String, dynamic>.from(rawItem as Map);
            return BillItem(
              id: item['id'] as String,
              name: item['name'] as String? ?? '',
              price: (item['price'] as num? ?? 0).toDouble(),
              quantity: item['quantity'] as int? ?? 1,
              isWeightBased: item['is_weight_based'] as bool? ?? false,
              weightKg: (item['weight_kg'] as num? ?? 0).toDouble(),
            );
          }),
        );
      _people
        ..clear()
        ..addAll(
          (decoded['people'] as List? ?? []).map((rawPerson) {
            final person = Map<String, dynamic>.from(rawPerson as Map);
            final colorIndex =
                _people.length % Person.avatarColors.length;
            return Person(
              id: person['id'] as String,
              name: person['name'] as String? ?? '',
              avatarColor: Person.avatarColors[colorIndex],
              userId: person['user_id'] as int?,
              avatarUrl: person['avatar_url'] as String?,
            );
          }),
        );

      _assignments
        ..clear()
        ..addAll(
          (decoded['assignments'] as Map? ?? {}).map(
            (itemId, personMap) => MapEntry(
              itemId.toString(),
              Map<String, int>.from(personMap as Map),
            ),
          ),
        );
      _percentages
        ..clear()
        ..addAll(
          (decoded['percentages'] as Map? ?? {}).map(
            (personId, pct) => MapEntry(
              personId.toString(),
              (pct as num).toDouble(),
            ),
          ),
        );
      _shares
        ..clear()
        ..addAll(
          (decoded['shares'] as Map? ?? {}).map(
            (personId, count) => MapEntry(personId.toString(), count as int),
          ),
        );

      _nextItemId = decoded['next_item_id'] as int? ?? _items.length;
      _nextPersonId = decoded['next_person_id'] as int? ?? _people.length;
      _serviceChargePercent =
          (decoded['service_charge_percent'] as num? ?? 0).toDouble();
      _serviceChargeEnabled =
          decoded['service_charge_enabled'] as bool? ?? false;
      _category = ExpenseCategory.findById(
        decoded['category_id'] as String? ?? ExpenseCategory.all.last.id,
      );
      _splitMode = SplitMode.values.firstWhere(
        (mode) => mode.name == decoded['split_mode'],
        orElse: () => SplitMode.byItems,
      );
      _currency = Currency.values.firstWhere(
        (currency) => currency.name == decoded['currency'],
        orElse: () => Currency.kgs,
      );
      _billTitle = decoded['bill_title'] as String? ?? '';
      _restoredFromDraft = true;
      _suspendAutosave = false;
      notifyListeners();
    } catch (_) {
      _suspendAutosave = false;
      await clearDraft();
    }
  }

  Future<void> clearDraft() async {
    _draftSaveDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> discardDraft() async {
    _suspendAutosave = true;
    _clearAllState();
    _restoredFromDraft = false;
    _suspendAutosave = false;
    await clearDraft();
    notifyListeners();
  }

  void _scheduleDraftSave() {
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(
      const Duration(seconds: 3),
      () => _saveDraftNow(),
    );
  }

  Future<void> _saveDraftNow() async {
    final prefs = await SharedPreferences.getInstance();
    if (!hasDraftContent) {
      await prefs.remove(_draftKey);
      return;
    }

    await prefs.setString(_draftKey, jsonEncode(_toDraftJson()));
  }

  Map<String, dynamic> _toDraftJson() => {
        'version': _draftVersion,
        'updated_at': DateTime.now().toIso8601String(),
        'bill_title': _billTitle,
        'category_id': _category.id,
        'split_mode': _splitMode.name,
        'currency': _currency.name,
        'service_charge_percent': _serviceChargePercent,
        'service_charge_enabled': _serviceChargeEnabled,
        'next_item_id': _nextItemId,
        'next_person_id': _nextPersonId,
        'items': _items
            .map(
              (item) => {
                'id': item.id,
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'is_weight_based': item.isWeightBased,
                'weight_kg': item.weightKg,
              },
            )
            .toList(),
        'people': _people
            .map(
              (person) => {
                'id': person.id,
                'name': person.name,
                'user_id': person.userId,
                'avatar_url': person.avatarUrl,
              },
            )
            .toList(),
        'assignments': _assignments,
        'percentages': _percentages,
        'shares': _shares,
      };

  // --- Reset ---

  void _clearAllState() {
    _items.clear();
    _people.clear();
    _assignments.clear();
    _percentages.clear();
    _shares.clear();
    _nextItemId = 0;
    _nextPersonId = 0;
    _billTitle = '';
    _serviceChargePercent = 0.0;
    _serviceChargeEnabled = false;
    _category = ExpenseCategory.all.last;
    _splitMode = SplitMode.byItems;
    _currency = Currency.kgs;
  }

  void reset({bool keepPeople = false}) {
    _restoredFromDraft = false;
    _items.clear();
    _assignments.clear();
    _nextItemId = 0;
    _splitMode = SplitMode.byItems;
    _percentages.clear();
    _shares.clear();
    if (!keepPeople) {
      _people.clear();
      _nextPersonId = 0;
      _billTitle = '';
      _serviceChargePercent = 0.0;
      _serviceChargeEnabled = false;
      _category = ExpenseCategory.all.last;
      _currency = Currency.kgs;
    } else {
      if (_category.defaultServicePercent > 0) {
        _serviceChargeEnabled = true;
        _serviceChargePercent = _category.defaultServicePercent;
      } else {
        _serviceChargeEnabled = false;
        _serviceChargePercent = 0.0;
      }
    }
    notifyListeners();
  }
}
