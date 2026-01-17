import 'package:flutter/services.dart';

class EnvConfig {
  final String url;
  final String anonKey;
  final String namespace;
  final String storageBucket;

  const EnvConfig({
    required this.url,
    required this.anonKey,
    required this.namespace,
    required this.storageBucket,
  });

  static Future<EnvConfig?> loadFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/.env');
      final map = parseEnv(raw);
      final url = map['SUPABASE_URL'] ?? '';
      final anonKey = map['SUPABASE_ANON_KEY'] ?? '';
      if (url.isEmpty || anonKey.isEmpty) return null;
      final namespace = map['SUPABASE_NAMESPACE'] ?? 'default';
      final storageBucket = map['SUPABASE_STORAGE_BUCKET'] ?? 'app_files';
      return EnvConfig(
        url: url,
        anonKey: anonKey,
        namespace: namespace,
        storageBucket: storageBucket,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> parseEnv(String raw) {
    final Map<String, String> values = {};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final index = trimmed.indexOf('=');
      if (index <= 0) continue;
      final key = trimmed.substring(0, index).trim();
      final value = trimmed.substring(index + 1).trim();
      if (key.isEmpty) continue;
      values[key] = value;
    }
    return values;
  }

  static Future<Map<String, String>> loadEnvMap() async {
    try {
      final raw = await rootBundle.loadString('assets/.env');
      return parseEnv(raw);
    } catch (_) {
      return {};
    }
  }
}
