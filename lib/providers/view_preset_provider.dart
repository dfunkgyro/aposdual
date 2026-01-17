import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewPreset {
  final String name;
  final DateTime createdAt;
  final Map<String, dynamic> appState;
  final Map<String, dynamic> telemetry;
  final Map<String, dynamic> alarms;

  ViewPreset({
    required this.name,
    required this.createdAt,
    required this.appState,
    required this.telemetry,
    required this.alarms,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'appState': appState,
        'telemetry': telemetry,
        'alarms': alarms,
      };

  factory ViewPreset.fromJson(Map<String, dynamic> json) {
    return ViewPreset(
      name: json['name']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      appState: Map<String, dynamic>.from(json['appState'] ?? const {}),
      telemetry: Map<String, dynamic>.from(json['telemetry'] ?? const {}),
      alarms: Map<String, dynamic>.from(json['alarms'] ?? const {}),
    );
  }
}

class ViewPresetProvider with ChangeNotifier {
  static const String _prefsKey = 'view_presets_v1';
  final List<ViewPreset> _presets = [];
  bool _loaded = false;

  List<ViewPreset> get presets => List.unmodifiable(_presets);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _presets
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map>()
                  .map((e) => ViewPreset.fromJson(Map<String, dynamic>.from(e)))
                  .where((e) => e.name.isNotEmpty),
            );
        }
      } catch (_) {
        // Ignore corrupted data.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_presets.map((e) => e.toJson()).toList()));
  }

  void savePreset(ViewPreset preset) {
    final index = _presets.indexWhere((p) => p.name == preset.name);
    if (index >= 0) {
      _presets[index] = preset;
    } else {
      _presets.insert(0, preset);
    }
    notifyListeners();
    _persist();
  }

  void deletePreset(String name) {
    _presets.removeWhere((p) => p.name == name);
    notifyListeners();
    _persist();
  }
}
