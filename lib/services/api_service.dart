import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const _timeout = Duration(seconds: 10);

  /// Override the backend host at launch:
  ///   flutter run --dart-define=FS_HOST=192.168.1.42
  /// Defaults: 10.0.2.2 on Android emulator, localhost otherwise.
  static const _hostOverride = String.fromEnvironment('FS_HOST');
  static const _portOverride =
      String.fromEnvironment('FS_PORT', defaultValue: '8000');

  static String get host {
    if (_hostOverride.isNotEmpty) return _hostOverride;
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static String get port => _portOverride;

  static String get _baseUrl => 'http://$host:$port/api';

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Map<String, String> get _authHeaders => {
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // --- Auth ---

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register/'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login/'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/otp/send/'),
      headers: _headers,
      body: jsonEncode({'phone': phone}),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/otp/verify/'),
      headers: _headers,
      body: jsonEncode({
        'phone': phone,
        'code': code,
      }),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> loginWithTelegram(String initData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/telegram/'),
      headers: _headers,
      body: jsonEncode({'initData': initData}),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/auth/me/'),
      headers: _headers,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;

    final response = await http.patch(
      Uri.parse('$_baseUrl/auth/me/'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> uploadAvatar(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/auth/me/avatar/'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      await http.MultipartFile.fromPath('avatar', imageFile.path),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  // --- Users ---

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/search/?q=${Uri.encodeQueryComponent(query)}'),
      headers: _headers,
    ).timeout(_timeout);
    final body = _handleResponse(response);
    final results = body.containsKey('results') ? body['results'] : [];
    return List<Map<String, dynamic>>.from(results);
  }

  // --- Bills ---

  Future<Map<String, dynamic>> saveBill({
    required double total,
    required double serviceChargePercent,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> people,
    required Map<String, dynamic> assignments,
    String? title,
    String? category,
    String? currency,
    String? splitMode,
    List<Map<String, dynamic>>? debts,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/bills/'),
      headers: _headers,
      body: jsonEncode({
        'total': total,
        'service_charge_percent': serviceChargePercent,
        'items': items,
        'people': people,
        'assignments': assignments,
        if (title != null && title.isNotEmpty) 'title': title,
        if (category != null) 'category': category,
        if (currency != null) 'currency': currency,
        if (splitMode != null) 'split_mode': splitMode,
        if (debts != null) 'debts': debts,
      }),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getUserBills() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/bills/'),
      headers: _headers,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<bool> deleteBill(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/bills/$id/'),
      headers: _headers,
    ).timeout(_timeout);
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // --- OCR Scan ---

  Future<List<Map<String, dynamic>>> scanReceipt(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/ocr/scan/'),
    );
    request.headers.addAll(_authHeaders);
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = _handleResponse(response);
    final items = body['items'] ?? [];
    return List<Map<String, dynamic>>.from(items);
  }

  // --- Debts ---

  Future<Map<String, dynamic>> getDebts({String show = 'active'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/debts/?show=$show'),
      headers: _headers,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  /// Creates a debt. Caller specifies both [fromUserId] (debtor) and
  /// [toUserId] (creditor); current authenticated user must be one of them.
  Future<Map<String, dynamic>> createDebt({
    required int fromUserId,
    required int toUserId,
    required double amount,
    int? billId,
    String description = '',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/debts/'),
      headers: _headers,
      body: jsonEncode({
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'amount': amount,
        if (billId != null) 'bill': billId,
        'description': description,
      }),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> markDebtPaid(int debtId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/debts/$debtId/pay/'),
      headers: _headers,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getDebtSummary() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/debts/summary/'),
      headers: _headers,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  // --- Friend Groups ---

  Future<Map<String, dynamic>> getGroups() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/groups/'),
      headers: _headers,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/groups/'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'member_ids': memberIds,
      }),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateGroup({
    required int groupId,
    String? name,
    List<int>? memberIds,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (memberIds != null) body['member_ids'] = memberIds;
    final response = await http.patch(
      Uri.parse('$_baseUrl/groups/$groupId/'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<bool> deleteGroup(int groupId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/groups/$groupId/'),
      headers: _headers,
    ).timeout(_timeout);
    return response.statusCode == 200;
  }

  // --- Notifications ---

  Future<Map<String, dynamic>> getNotifications() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/notifications/'),
      headers: _headers,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<void> markAllNotificationsRead() async {
    await http.post(
      Uri.parse('$_baseUrl/notifications/read/'),
      headers: _headers,
    ).timeout(_timeout);
  }

  Future<void> markNotificationRead(int notificationId) async {
    await http.post(
      Uri.parse('$_baseUrl/notifications/$notificationId/read/'),
      headers: _headers,
    ).timeout(_timeout);
  }

  // --- Statistics ---

  Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/stats/'),
      headers: _headers,
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  // --- Helpers ---

  /// Tolerant response handler: server may return a JSON object or a JSON
  /// array; we normalize to a map. Lists are wrapped as {"results": [...]}.
  Map<String, dynamic> _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Ошибка сервера (${response.statusCode})',
      );
    }

    Map<String, dynamic> body;
    if (decoded is Map<String, dynamic>) {
      body = decoded;
    } else if (decoded is List) {
      body = {'results': decoded};
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Неожиданный формат ответа',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['error'] as String? ?? 'Ошибка сервера',
    );
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
