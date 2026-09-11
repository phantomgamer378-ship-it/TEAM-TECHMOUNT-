import 'dart:async';
import 'dart:convert';


import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// REST + WebSocket client for the Voice Clone Shield backend.
/// Endpoints are the frozen v3 contract (docs/architecture.md §5).
class ApiClient {
  ApiClient(this.baseUrl);

  /// Mutable on purpose: the Home ⚙ settings dialog updates it at runtime
  /// (LAN IP for phones, 10.0.2.2 for the Android emulator, localhost for web).
  String baseUrl;

  /// Sensible default per platform: web/desktop talk to localhost; the
  /// Android emulator reaches the host machine via 10.0.2.2 (§12).
  static Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('baseUrl');
    if (saved != null && saved.isNotEmpty) return saved;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', url);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final r = await http
        .get(_uri(path, query))
        .timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final r = await http
        .post(_uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return jsonDecode(r.body);
  }

  /// POST /api/analyze/audio — multipart upload; the backend deletes the
  /// audio right after analysis (privacy_mode).
  Future<dynamic> uploadAudio({
    required Uint8List bytes,
    required String filename,
    String lang = 'hi',
    String? sessionId,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/api/analyze/audio'))
      ..fields['lang'] = lang
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      req.fields['session_id'] = sessionId.trim();
    }
    final streamed =
        await req.send().timeout(const Duration(minutes: 5));
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body);
  }

  /// WS /ws/session/{id} — protocol: start → audio(base64) → end;
  /// server streams status / risk_update (one per chunk) / final.
  WebSocketChannel connectStream(String sessionId) {
    final httpUri = Uri.parse('$baseUrl/ws/session/$sessionId');
    final wsUri = httpUri.replace(
        scheme: httpUri.scheme == 'https' ? 'wss' : 'ws');
    return WebSocketChannel.connect(wsUri);
  }
}
