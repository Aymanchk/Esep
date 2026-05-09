import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class DebtProvider extends ChangeNotifier {
  final ApiService _api;
  List<Map<String, dynamic>> _debts = [];
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _settlements = [];
  bool _isLoading = false;
  bool _isSettlementLoading = false;

  DebtProvider(this._api);

  List<Map<String, dynamic>> get debts => _debts;
  List<Map<String, dynamic>> get balances => _balances;
  List<Map<String, dynamic>> get settlements => _settlements;
  bool get isLoading => _isLoading;
  bool get isSettlementLoading => _isSettlementLoading;

  Future<void> loadDebts({String show = 'active'}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _api.getDebts(show: show);
      _debts = List<Map<String, dynamic>>.from(result['debts'] ?? []);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSummary() async {
    try {
      final result = await _api.getDebtSummary();
      _balances = List<Map<String, dynamic>>.from(result['balances'] ?? []);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadSettlementPlan() async {
    _isSettlementLoading = true;
    notifyListeners();
    try {
      final result = await _api.getDebtSettlementPlan();
      _settlements = List<Map<String, dynamic>>.from(
        result['settlements'] ?? [],
      );
    } catch (_) {
      _settlements = [];
    }
    _isSettlementLoading = false;
    notifyListeners();
  }

  Future<bool> createDebt({
    required int fromUserId,
    required int toUserId,
    required double amount,
    int? billId,
    String description = '',
  }) async {
    try {
      await _api.createDebt(
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        billId: billId,
        description: description,
      );
      await loadDebts();
      await loadSummary();
      await loadSettlementPlan();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markPaid(int debtId) async {
    try {
      await _api.markDebtPaid(debtId);
      await loadDebts();
      await loadSummary();
      await loadSettlementPlan();
      return true;
    } catch (_) {
      return false;
    }
  }
}
