import 'dart:convert';
import 'dart:io';

import 'package:mathra_admin/firebase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Firebase Auth (email + password) through its REST API.
/// Only the admin account can write plans / confirm orders (Firestore rules).
class AdminAuth {
  String? _idToken;
  String? _refreshToken;
  int _expiresAtMs = 0;
  String email = '';

  bool get signedIn => _refreshToken != null;

  Future<Map<String, dynamic>> _post(
    String url,
    String body,
    String contentType,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
      req.add(utf8.encode(body));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      final json = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        var msg = 'Error ${res.statusCode}';
        if (json is Map && json['error'] is Map) {
          msg = '${(json['error'] as Map)['message']}';
        }
        throw AuthException(_friendly(msg));
      }
      return Map<String, dynamic>.from(json as Map);
    } on SocketException {
      throw AuthException('No internet connection');
    } finally {
      client.close(force: true);
    }
  }

  String _friendly(String code) {
    if (code.contains('INVALID_LOGIN_CREDENTIALS') ||
        code.contains('INVALID_PASSWORD') ||
        code.contains('EMAIL_NOT_FOUND')) {
      return 'Wrong email or password';
    }
    if (code.contains('TOO_MANY_ATTEMPTS')) return 'Too many tries. Wait a few minutes.';
    if (code.contains('OPERATION_NOT_ALLOWED')) {
      return 'Enable Email/Password sign-in in Firebase Authentication.';
    }
    return code;
  }

  void _apply(String idToken, String refresh, String expiresIn) {
    _idToken = idToken;
    _refreshToken = refresh;
    _expiresAtMs = DateTime.now().millisecondsSinceEpoch +
        (int.tryParse(expiresIn) ?? 3600) * 1000;
  }

  Future<void> signIn(String mail, String password) async {
    final r = await _post(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FirebaseConfig.apiKey}',
      jsonEncode({
        'email': mail.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
      'application/json',
    );
    email = mail.trim();
    _apply('${r['idToken']}', '${r['refreshToken']}', '${r['expiresIn']}');
    final p = await SharedPreferences.getInstance();
    await p.setString('admin_refresh', _refreshToken!);
    await p.setString('admin_email', email);
  }

  /// Auto sign-in on app start. False = must log in.
  Future<bool> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final rt = p.getString('admin_refresh');
      email = p.getString('admin_email') ?? '';
      if (rt == null || rt.isEmpty) return false;
      _refreshToken = rt;
      await _refresh();
      return true;
    } catch (_) {
      _refreshToken = null;
      return false;
    }
  }

  Future<void> _refresh() async {
    final rt = _refreshToken;
    if (rt == null) throw AuthException('Not signed in');
    final r = await _post(
      'https://securetoken.googleapis.com/v1/token?key=${FirebaseConfig.apiKey}',
      'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(rt)}',
      'application/x-www-form-urlencoded',
    );
    _apply('${r['id_token']}', '${r['refresh_token']}', '${r['expires_in']}');
    final p = await SharedPreferences.getInstance();
    await p.setString('admin_refresh', _refreshToken!);
  }

  /// A valid token (refreshed when it is about to expire).
  Future<String> token() async {
    if (_idToken == null ||
        DateTime.now().millisecondsSinceEpoch > _expiresAtMs - 120000) {
      await _refresh();
    }
    return _idToken!;
  }

  Future<void> signOut() async {
    _idToken = null;
    _refreshToken = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('admin_refresh');
  }
}
