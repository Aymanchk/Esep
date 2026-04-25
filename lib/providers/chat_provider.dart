import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;

  List<Map<String, dynamic>> _rooms = [];
  Map<int, List<Map<String, dynamic>>> _messagesByRoom = {};
  bool _isLoading = false;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  ChatProvider(this._api);

  List<Map<String, dynamic>> get rooms => _rooms;
  bool get isLoading => _isLoading;

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
    disconnectFromRoom();

    // Reuse the same host the REST client resolved (LAN IP on real device,
    // 10.0.2.2 on Android emulator, localhost on iOS sim / desktop).
    final wsBase = 'ws://${ApiService.host}:${ApiService.port}';
    final token = _api.token;

    _wsChannel = WebSocketChannel.connect(
      Uri.parse('$wsBase/ws/chat/$roomId/?token=$token'),
    );

    _wsSubscription = _wsChannel!.stream.listen(
      (data) {
        final message = jsonDecode(data as String) as Map<String, dynamic>;
        _messagesByRoom.putIfAbsent(roomId, () => []);
        // Avoid duplicates
        final exists = _messagesByRoom[roomId]!.any((m) => m['id'] == message['id']);
        if (!exists) {
          _messagesByRoom[roomId]!.add(message);
          notifyListeners();
        }
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  void disconnectFromRoom() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _wsSubscription = null;
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
