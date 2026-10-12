import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userAvatarUrl;
  int? _userId;
  String? _error;
  bool _isGuest = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  String? get userAvatarUrl => _userAvatarUrl;
  int? get userId => _userId;
  String? get error => _error;
  bool get isGuest => _isGuest;
  ApiService get api => _api;

  void _setUserFromMap(Map<String, dynamic> user) {
    _userId = user['id'] as int?;
    _userName = user['name'] as String?;
    _userEmail = user['email'] as String?;
    _userPhone = user['phone'] as String?;
    _userAvatarUrl = user['avatar'] as String?;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );

      _api.setToken(result['token'] as String);
      _setUserFromMap(result['user'] as Map<String, dynamic>);
      _isLoggedIn = true;
      _isGuest = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Нет подключения к серверу';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.login(email: email, password: password);

      _api.setToken(result['token'] as String);
      _setUserFromMap(result['user'] as Map<String, dynamic>);
      _isLoggedIn = true;
      _isGuest = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Нет подключения к серверу';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.sendOtp(phone);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Нет подключения к серверу';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.verifyOtp(phone, code);
      _api.setToken(result['token'] as String);
      _setUserFromMap(result['user'] as Map<String, dynamic>);
      _isLoggedIn = true;
      _isGuest = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Нет подключения к серверу';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> tryTelegramAutoLogin(String initData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.loginWithTelegram(initData);
      _api.setToken(result['token'] as String);
      _setUserFromMap(result['user'] as Map<String, dynamic>);
      _isLoggedIn = true;
      _isGuest = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Не удалось войти через Telegram';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({String? name, String? email, String? phone}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.updateProfile(name: name, email: email, phone: phone);
      _setUserFromMap(result['user'] as Map<String, dynamic>);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Нет подключения к серверу';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(File imageFile) async {
    try {
      final result = await _api.uploadAvatar(imageFile);
      _setUserFromMap(result['user'] as Map<String, dynamic>);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  void continueAsGuest() {
    _isGuest = true;
    _isLoggedIn = true;
    _userName = 'Гость';
    _error = null;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _isGuest = false;
    _userName = null;
    _userEmail = null;
    _userPhone = null;
    _userAvatarUrl = null;
    _userId = null;
    _api.setToken(null);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
