import 'package:flutter/foundation.dart';
import '../models/bill_item.dart';
import '../models/person.dart';
import '../models/expense_category.dart';

enum SplitMode { byItems, equal, percentage, shares }

enum Currency { kgs, usd, eur, rub, kzt }

extension CurrencyExt on Currency {
  String get symbol {
    switch (this) {
      case Currency.kgs: return 'сом';
      case Currency.usd: return '\$';
      case Currency.eur: return '€';
      case Currency.rub: return '₽';
      case Currency.kzt: return '₸';
    }
  }

  String get code {
    switch (this) {
      case Currency.kgs: return 'KGS';
      case Currency.usd: return 'USD';
      case Currency.eur: return 'EUR';
      case Currency.rub: return 'RUB';
      case Currency.kzt: return 'KZT';
    }
  }
}

class BillProvider extends ChangeNotifier {
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

  List<BillItem> get items => List.unmodifiable(_items);
  List<Person> get people => List.unmodifiable(_people);
  double get serviceChargePercent => _serviceChargePercent;
  bool get serviceChargeEnabled => _serviceChargeEnabled;

  // Backward-compat getter: itemId -> set of personIds with ≥1 unit
  Map<String, Set<String>> get assignments =>
      _assignments.map((itemId, personMap) => MapEntry(
            itemId,
            personMap.entries
                .where((e) => e.value > 0)
                .map((e) => e.key)
                .toSet(),
          ));

  /// Raw assignment matrix: itemId -> personId -> unit count.
  /// Use this when persisting a bill so multi-unit assignments survive the
  /// round-trip through the backend.
  Map<String, Map<String, int>> get unitAssignments =>
      _assignments.map((itemId, personMap) => MapEntry(
            itemId,
            Map<String, int>.from(personMap),
          ));

  ExpenseCategory get category => _category;
  SplitMode get splitMode => _splitMode;
  Currency get currency => _currency;
  String get billTitle => _billTitle;
  Map<String, double> get percentages => Map.unmodifiable(_percentages);
  Map<String, int> get shares => Map.unmodifiable(_shares);

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

  void addItem(String name, double price, {int quantity = 1}) {
    _items.add(BillItem(
      id: 'item_${_nextItemId++}',
      name: name,
      price: price,
      quantity: quantity,
    ));
    notifyListeners();
  }

  void removeItem(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    _assignments.remove(itemId);
    notifyListeners();
  }

  void addItemsFromOcr(List<Map<String, dynamic>> ocrItems) {
    for (final item in ocrItems) {
      _items.add(BillItem(
        id: 'item_${_nextItemId++}',
        name: item['name'] as String,
        price: (item['price'] as num).toDouble(),
      ));
    }
    notifyListeners();
  }

  // --- People ---

  void addPerson(String name, {int? userId, String? avatarUrl}) {
    final colorIndex = _nextPersonId % Person.avatarColors.length;
    _people.add(Person(
      id: 'person_${_nextPersonId++}',
      name: name,
      avatarColor: Person.avatarColors[colorIndex],
      userId: userId,
      avatarUrl: avatarUrl,
    ));
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
      _assignments[itemId]
          ?.entries
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

  // --- Reset ---

  void reset({bool keepPeople = false}) {
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
