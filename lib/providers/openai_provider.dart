import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/env_loader.dart';

enum OpenAiStatus { disconnected, configured, connecting, ready, error }

class OpenAiProvider with ChangeNotifier {
  OpenAiStatus _status = OpenAiStatus.disconnected;
  String? _lastError;
  String _model = 'gpt-4.1-mini';
  String? _apiKey;

  OpenAiStatus get status => _status;
  String? get lastError => _lastError;
  bool get isReady => _status == OpenAiStatus.ready;
  bool get isConfigured => _status == OpenAiStatus.configured || _status == OpenAiStatus.ready;
  String get model => _model;

  Future<void> initialize() async {
    final env = await EnvConfig.loadEnvMap();
    _apiKey = env['OPENAI_API_KEY'];
    _model = env['OPENAI_MODEL']?.trim().isNotEmpty == true ? env['OPENAI_MODEL']!.trim() : _model;
    if (_apiKey == null || _apiKey!.isEmpty) {
      _status = OpenAiStatus.disconnected;
    } else {
      _status = OpenAiStatus.configured;
    }
    _lastError = null;
    notifyListeners();
  }

  Future<void> connect() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _status = OpenAiStatus.disconnected;
      _lastError = 'Missing OPENAI_API_KEY';
      notifyListeners();
      return;
    }
    _status = OpenAiStatus.connecting;
    _lastError = null;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );
      if (response.statusCode == 200) {
        _status = OpenAiStatus.ready;
      } else {
        _status = OpenAiStatus.error;
        _lastError = 'OpenAI error: ${response.statusCode}';
      }
    } catch (e) {
      _status = OpenAiStatus.error;
      _lastError = e.toString();
    }
    notifyListeners();
  }

  Future<OpenAiResult?> ask({
    required String system,
    required String user,
    Map<String, dynamic>? context,
  }) async {
    if (!isReady || _apiKey == null || _apiKey!.isEmpty) return null;
    try {
      final payload = {
        'model': _model,
        'input': [
          {
            'role': 'system',
            'content': [
              {'type': 'text', 'text': system}
            ],
          },
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': user},
              if (context != null) {'type': 'text', 'text': 'CONTEXT: ${jsonEncode(context)}'},
            ],
          },
        ],
      };
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/responses'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) {
        _lastError = 'OpenAI error: ${response.statusCode}';
        notifyListeners();
        return null;
      }
      final data = jsonDecode(response.body);
      final outputText = _extractText(data);
      if (outputText.isEmpty) return null;
      return OpenAiResult.fromJsonString(outputText) ?? OpenAiResult(reply: outputText);
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  String _extractText(dynamic data) {
    if (data is! Map) return '';
    final output = data['output'];
    if (output is List) {
      for (final item in output) {
        if (item is Map && item['content'] is List) {
          final content = item['content'] as List;
          final buffer = StringBuffer();
          for (final part in content) {
            if (part is Map && part['type'] == 'text') {
              buffer.write(part['text'] ?? '');
            }
          }
          final text = buffer.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    }
    return '';
  }
}

class OpenAiResult {
  final String reply;
  final String? action;
  final String? target;
  final String? query;

  const OpenAiResult({
    required this.reply,
    this.action,
    this.target,
    this.query,
  });

  static OpenAiResult? fromJsonString(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      return OpenAiResult(
        reply: data['reply']?.toString() ?? raw,
        action: data['action']?.toString(),
        target: data['target']?.toString(),
        query: data['query']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
