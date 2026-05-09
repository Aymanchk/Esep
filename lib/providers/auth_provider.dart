import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

enum AuthRestoreResult { authenticated, noToken, invalidToken, failed }

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const _accessTokenKey = 'fs_access_token';
  static const _refreshTokenKey = 'fs_refresh_token';
  static const _lastEmailKey = 'fs_last_email';
  static const _onboardingSeenKey = 'fs_onboarding_seen';

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

  AuthProvider() {
    _api.configureAuthCallbacks(
      onTokenRefreshed: _saveAuthTokens,
      onAuthExpired: _handleAuthExpired,
    );
  }

  void _setUserFromMap(Map<String, dynamic> user) {
    _userId = user['id'] as int?;
    _userName = user['name'] as String?;
    _userEmail = user['email'] as String?;
    _userPhone = user['phone'] as String?;
    _userAvatarUrl = user['avatar'] as String?;
  }

  Future<void> _saveAuthTokens(String accessToken, String? refreshToken) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> _clearStoredAuth() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  void _clearUserState() {
    _isLoggedIn = false;
    _isGuest = false;
    _userName = null;
    _userEmail = null;
    _userPhone = null;
    _userAvatarUrl = null;
    _userId = null;
    _api.setTokens(accessToken: null, refreshToken: null);
  }

  Future<void> _handleAuthExpired() async {
    await _clearStoredAuth();
    _clearUserState();
    notifyListeners();
  }

  Future<AuthRestoreResult> restoreSession() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (accessToken == null || accessToken.isEmpty) {
      _clearUserState();
      _isLoading = false;
      notifyListeners();
      return AuthRestoreResult.noToken;
    }

    _api.setTokens(accessToken: accessToken, refreshToken: refreshToken);
    try {
      final profile = await _api.getProfile();
      _setUserFromMap(profile['user'] as Map<String, dynamic>);
      _isLoggedIn = true;
      _isGuest = false;
      _isLoading = false;
      notifyListeners();
      return AuthRestoreResult.authenticated;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _clearStoredAuth();
        _clearUserState();
        _isLoading = false;
        notifyListeners();
        return AuthRestoreResult.invalidToken;
      }
      _clearUserState();
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return AuthRestoreResult.failed;
    } catch (_) {
      _clearUserState();
      _error = 'No connection to server';
      _isLoading = false;
      notifyListeners();
      return AuthRestoreResult.failed;
    }
  }

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  Future<String?> getLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastEmailKey);
  }

  Future<void> _saveLastEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEmailKey, email);
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

      final accessToken = result['token'] as String;
      final refreshToken = result['refresh'] as String?;
      _api.setTokens(accessToken: accessToken, refreshToken: refreshToken);
      await _saveAuthTokens(accessToken, refreshToken);
      await _saveLastEmail(email);
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

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.login(email: email, password: password);

      final accessToken = result['token'] as String;
      final refreshToken = result['refresh'] as String?;
      _api.setTokens(accessToken: accessToken, refreshToken: refreshToken);
      await _saveAuthTokens(accessToken, refreshToken);
      await _saveLastEmail(email);
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

  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.updateProfile(
        name: name,
        email: email,
        phone: phone,
      );
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

  Future<void> logout() async {
    await _clearStoredAuth();
    _clearUserState();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
