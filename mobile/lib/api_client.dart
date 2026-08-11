import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Thrown for any non-2xx response; [message] is the API's `error` field.
class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status): $message';
}

/// Talks to the Patela Flask API and holds the session tokens.
///
/// Tokens are persisted with shared_preferences so a signed-in user stays
/// signed in across app restarts. On a 401 the client transparently refreshes
/// the access token once and replays the request.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  static const _accessKey = 'patela.access_token';
  static const _refreshKey = 'patela.refresh_token';

  final http.Client _http;
  final String baseUrl;

  String? _accessToken;
  String? _refreshToken;

  bool get hasSession => _accessToken != null;

  /// Restores any persisted session. Call once at startup.
  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_accessKey);
      _refreshToken = prefs.getString(_refreshKey);
    } catch (_) {
      // No platform storage (e.g. widget tests) — run without a saved session.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken == null) {
        await prefs.remove(_accessKey);
        await prefs.remove(_refreshKey);
      } else {
        await prefs.setString(_accessKey, _accessToken!);
        if (_refreshToken != null) {
          await prefs.setString(_refreshKey, _refreshToken!);
        }
      }
    } catch (_) {
      // Storage unavailable — session stays in memory only.
    }
  }

  Future<void> _setTokens(Map<String, dynamic> body) async {
    _accessToken = body['access_token'] as String?;
    _refreshToken = (body['refresh_token'] as String?) ?? _refreshToken;
    await _persist();
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    await _persist();
  }

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String mode,
    String? fullName,
    String? businessName,
    String? category,
  }) async {
    final body = await _send('POST', '/api/auth/register', body: {
      'email': email,
      'password': password,
      'mode': mode,
      'full_name': ?fullName,
      'business_name': ?businessName,
      'category': ?category,
    }, authed: false);
    await _setTokens(body);
    return body['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final body = await _send('POST', '/api/auth/login',
        body: {'email': email, 'password': password}, authed: false);
    await _setTokens(body);
    return body['user'] as Map<String, dynamic>;
  }

  /// Exchanges a Google ID token for a Patela session. The backend verifies the
  /// token with Google before trusting it.
  Future<Map<String, dynamic>> googleSignIn({
    required String idToken,
    required String mode,
  }) async {
    final body = await _send('POST', '/api/auth/google',
        body: {'id_token': idToken, 'mode': mode}, authed: false);
    await _setTokens(body);
    return body['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async =>
      await _send('GET', '/api/auth/me') as Map<String, dynamic>;

  Future<void> logout() async {
    try {
      await _send('POST', '/api/auth/logout');
    } catch (_) {
      // Even if the call fails, drop the local session.
    }
    await clearSession();
  }

  // -------------------------------------------------------------------------
  // Domain
  // -------------------------------------------------------------------------
  Future<List<dynamic>> listFriends() async =>
      await _send('GET', '/api/friends') as List<dynamic>;

  Future<Map<String, dynamic>> addFriend(String name, String color) async =>
      await _send('POST', '/api/friends',
          body: {'name': name, 'color': color}) as Map<String, dynamic>;

  Future<void> deleteFriend(String id) async =>
      await _send('DELETE', '/api/friends/$id');

  Future<Map<String, dynamic>> createBill({
    required String merchant,
    required double total,
    required List<Map<String, dynamic>> participants,
  }) async =>
      await _send('POST', '/api/bills', body: {
        'merchant': merchant,
        'total': total,
        'participants': participants,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> payParticipant({
    required String billId,
    required String participantId,
    required String method,
  }) async =>
      await _send('POST', '/api/bills/$billId/participants/$participantId/pay',
          body: {'method': method}) as Map<String, dynamic>;

  Future<Map<String, dynamic>> settleBill(String billId) async =>
      await _send('POST', '/api/bills/$billId/settle') as Map<String, dynamic>;

  Future<List<dynamic>> listTransactions({int limit = 100}) async =>
      await _send('GET', '/api/transactions?limit=$limit') as List<dynamic>;

  Future<Map<String, dynamic>> recordSale({
    required double amount,
    required String method,
    String? reference,
    String? subtitle,
  }) async =>
      await _send('POST', '/api/transactions/sale', body: {
        'amount': amount,
        'method': method,
        'reference': ?reference,
        'subtitle': ?subtitle,
      }) as Map<String, dynamic>;

  Future<Map<String, dynamic>> todaySales() async =>
      await _send('GET', '/api/sales/today') as Map<String, dynamic>;

  // -------------------------------------------------------------------------
  // Transport
  // -------------------------------------------------------------------------
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authed = true,
    bool allowRefresh = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authed && _accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
    final payload = body == null ? null : jsonEncode(body);

    http.Response res;
    try {
      res = await switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'POST' => _http.post(uri, headers: headers, body: payload),
        'PATCH' => _http.patch(uri, headers: headers, body: payload),
        'DELETE' => _http.delete(uri, headers: headers),
        _ => throw ApiException('Unsupported method $method'),
      }
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException("The server didn't respond. Please try again.");
    } catch (e) {
      debugPrint('Patela API error: $e');
      throw ApiException("Can't reach the server. Check your connection.");
    }

    // One transparent refresh attempt on an expired access token.
    if (res.statusCode == 401 && authed && allowRefresh && _refreshToken != null) {
      if (await _refreshAccessToken()) {
        return _send(method, path, body: body, authed: authed, allowRefresh: false);
      }
    }

    if (res.statusCode == 204 || res.body.isEmpty) {
      if (res.statusCode >= 400) {
        throw ApiException('Request failed', status: res.statusCode);
      }
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw ApiException('Unexpected server response', status: res.statusCode);
    }

    if (res.statusCode >= 400) {
      final msg = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed';
      throw ApiException(msg, status: res.statusCode);
    }
    return decoded;
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final res = await _http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Authorization': 'Bearer $_refreshToken'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _accessToken = body['access_token'] as String?;
      await _persist();
      return _accessToken != null;
    } catch (_) {
      return false;
    }
  }
}
