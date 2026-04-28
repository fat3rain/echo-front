import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  Future<void> connect(Uri url) async {
    final socket = await WebSocket.connect(
      url.toString(),
    ).timeout(const Duration(seconds: 10));
    socket.pingInterval = const Duration(seconds: 20);
    _channel = IOWebSocketChannel(socket);
  }

  Stream get stream {
    final channel = _channel;
    if (channel == null) {
      throw StateError('WebSocket is not connected.');
    }
    return channel.stream;
  }

  void send(Map<String, dynamic> data) {
    final channel = _channel;
    if (channel == null) {
      throw StateError('WebSocket is not connected.');
    }
    channel.sink.add(jsonEncode(data));
  }

  void dispose() {
    
    _channel?.sink.close();
    _channel = null;
  }
}
