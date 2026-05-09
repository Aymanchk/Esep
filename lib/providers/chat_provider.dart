import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';

enum ChatConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class ChatProvider extends ChangeNotifier {
  final ApiService _api;

  List<Map<String, dynamic>> _rooms = [];
  Map<int, List<Map<String, dynamic>>> _messagesByRoom = {};
  bool _isLoading = false;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  int? _activeRoomId;
  int _reconnectAttempt = 0;
  int _connectionGeneration = 0;
  bool _intentionalDisconnect = false;
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;

  ChatProvider(this._api);

  List<Map<String, dynamic>> get rooms => _rooms;
  bool get isLoading => _isLoading;
  ChatConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == ChatConnectionState.connected;

  List<Map<String, dynamic>> getMessages(int roomId) {
    return _messagesByRoom[roomId] ?? [];
  }

  Future<void> loadRooms() async {
    _isLoading = true;
    notifyListeners();
    try {
      _rooms = await _api.getChatRooms();
    } catch (e) {
      // silently fail
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getOrCreateRoom(int otherUserId) async {
    final result = await _api.createChatRoom([otherUserId]);
    await loadRooms();
    return result;
  }

  Future<void> loadMessages(int roomId) async {
    try {
      final messages = await _api.getMessages(roomId);
      _messagesByRoom[roomId] = messages;
      notifyListeners();
    } catch (e) {
      // silently fail
    }
  }

  Future<void> sendMessage(int roomId, String text) async {
    // The REST endpoint just inserts a row; it does NOT push through the
    // WebSocket consumer. So we append the server's response to our local
    // list ourselves, and only fall back to a full reload if the request
    // fails. The duplicate guard handles the case where a WS broadcast
    // races us.
    try {
      final newMsg = await _api.sendMessage(roomId, text);
      _messagesByRoom.putIfAbsent(roomId, () => []);
      final id = newMsg['id'];
      final exists =
          id != null && _messagesByRoom[roomId]!.any((m) => m['id'] == id);
      if (!exists) {
        _messagesByRoom[roomId]!.add(newMsg);
        notifyListeners();
      }
    } catch (_) {
      await loadMessages(roomId);
    }
  }

  void connectToRoom(int roomId) {
    if (_activeRoomId == roomId &&
        (_connectionState == ChatConnectionState.connecting ||
            _connectionState == ChatConnectionState.connected ||
            _connectionState == ChatConnectionState.reconnecting)) {
      return;
    }

    _closeSocket();
    _reconnectTimer?.cancel();
    _intentionalDisconnect = false;
    _activeRoomId = roomId;
    _reconnectAttempt = 0;
    _openSocket(roomId, reconnecting: false);
  }

  void _openSocket(int roomId, {required bool reconnecting}) {
    final token = _api.token;
    if (token == null || token.isEmpty || _intentionalDisconnect) {
      _setConnectionState(ChatConnectionState.disconnected);
      return;
    }

    _closeSocket();
    final generation = ++_connectionGeneration;
    _setConnectionState(
      reconnecting
          ? ChatConnectionState.reconnecting
          : ChatConnectionState.connecting,
    );

    // Reuse the same host the REST client resolved.
    final wsBase = 'ws://${ApiService.host}:${ApiService.port}';

    _wsChannel = WebSocketChannel.connect(
      Uri.parse('$wsBase/ws/chat/$roomId/?token=$token'),
    );

    _wsSubscription = _wsChannel!.stream.listen(
      (data) {
        if (generation != _connectionGeneration) return;
        _reconnectAttempt = 0;
        _setConnectionState(ChatConnectionState.connected);
        final message = jsonDecode(data as String) as Map<String, dynamic>;
        _messagesByRoom.putIfAbsent(roomId, () => []);
        // Avoid duplicates
        final exists = _messagesByRoom[roomId]!.any(
          (m) => m['id'] == message['id'],
        );
        if (!exists) {
          _messagesByRoom[roomId]!.add(message);
          notifyListeners();
        }
      },
      onError: (_) => _handleSocketClosed(roomId, generation),
      onDone: () => _handleSocketClosed(roomId, generation),
      cancelOnError: true,
    );
    _setConnectionState(ChatConnectionState.connected);
  }

  void disconnectFromRoom() {
    _intentionalDisconnect = true;
    _activeRoomId = null;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _closeSocket();
    _setConnectionState(ChatConnectionState.disconnected);
  }

  void _handleSocketClosed(int roomId, int generation) {
    if (generation != _connectionGeneration ||
        _intentionalDisconnect ||
        _activeRoomId != roomId ||
        _api.token == null) {
      return;
    }
    _scheduleReconnect(roomId);
  }

  void _scheduleReconnect(int roomId) {
    if (_reconnectTimer?.isActive ?? false) return;
    _closeSocket();
    _setConnectionState(ChatConnectionState.reconnecting);

    final seconds = _backoffSeconds(_reconnectAttempt);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (_intentionalDisconnect || _activeRoomId != roomId) return;
      _openSocket(roomId, reconnecting: true);
    });
  }

  int _backoffSeconds(int attempt) {
    final seconds = 1 << attempt;
    return seconds > 30 ? 30 : seconds;
  }

  void _closeSocket() {
    _connectionGeneration++;
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _wsSubscription = null;
  }

  void _setConnectionState(ChatConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    notifyListeners();
  }

  Future<void> markAsRead(int roomId) async {
    try {
      await _api.markAsRead(roomId);
    } catch (e) {
      // silently fail
    }
  }

  @override
  void dispose() {
    disconnectFromRoom();
    super.dispose();
  }
}
