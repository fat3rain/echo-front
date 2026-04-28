import 'dart:convert';
import 'dart:io';

import '../models/user_profile.dart';

class AuthService {
  Future<void> register({
    required Uri baseUri,
    required String username,
    required String password,
  }) async {
    final response = await _post(baseUri.resolve('/api/register'), {
      'username': username,
      'password': password,
    });

    if (response.statusCode != 201) {
      throw Exception(_extractError(response));
    }
  }

  Future<String> login({
    required Uri baseUri,
    required String username,
    required String password,
  }) async {
    final response = await _post(baseUri.resolve('/api/login'), {
      'username': username,
      'password': password,
    });

    if (response.statusCode != 200) {
      throw Exception(_extractError(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Server did not return a token');
    }

    return token;
  }

  Future<UserProfile> me({required Uri baseUri, required String token}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(baseUri.resolve('/api/me'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final wrapped = _HttpResponse(response.statusCode, responseBody);

      if (wrapped.statusCode != 200) {
        throw Exception(_extractError(wrapped));
      }

      return UserProfile.fromJson(
        jsonDecode(wrapped.body) as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<_HttpResponse> _post(Uri uri, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

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
