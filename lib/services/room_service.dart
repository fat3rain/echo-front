import 'dart:convert';
import 'dart:io';

import '../models/room_summary.dart';

class RoomService {
  Future<List<RoomSummary>> listRooms({
    required Uri baseUri,
    required String token,
  }) async {
    final response = await _request(
      method: 'GET',
      uri: baseUri.resolve('/api/rooms'),
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => RoomSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RoomSummary> createRoom({
    required Uri baseUri,
    required String token,
    required String name,
  }) async {
    final response = await _request(
      method: 'POST',
      uri: baseUri.resolve('/api/rooms'),
      token: token,
      body: {'name': name},
    );

    if (response.statusCode != 201) {
      throw Exception(_extractError(response));
    }

    return RoomSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<RoomSummary> findRoom({
    required Uri baseUri,
    required String token,
    required String roomId,
  }) async {
    final response = await _request(
      method: 'GET',
      uri: baseUri.resolve('/api/rooms/$roomId'),
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }

    return RoomSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<RoomSummary> joinRoom({
    required Uri baseUri,
    required String token,
    required String roomId,
  }) async {
    final response = await _request(
      method: 'POST',
      uri: baseUri.resolve('/api/rooms/$roomId/join'),
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }

    return RoomSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteRoom({
    required Uri baseUri,
    required String token,
    required String roomId,
  }) async {
    final response = await _request(
      method: 'DELETE',
      uri: baseUri.resolve('/api/rooms/$roomId'),
      token: token,
    );

    if (response.statusCode != 204) {
      throw Exception(_extractError(response));
    }
  }

  Future<_HttpResponse> _request({
    required String method,
    required Uri uri,
    required String token,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      return _HttpResponse(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }

  String _extractError(_HttpResponse response) {
    final body = response.body.trim();
    if (body.isNotEmpty) {
      return body;
    }
    return 'HTTP ${response.statusCode}';
  }
}

class _HttpResponse {
  const _HttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}
