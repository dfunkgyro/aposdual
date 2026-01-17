import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LinkAssociation {
  final String mainSvg;
  final String mimicSvg;
  final String telemetryJson;
  final int updatedAtMs;

  LinkAssociation({
    required this.mainSvg,
    required this.mimicSvg,
    required this.telemetryJson,
    int? updatedAtMs,
  }) : updatedAtMs = updatedAtMs ?? DateTime.now().millisecondsSinceEpoch;

  bool matchesPath(String path) {
    return mainSvg == path || mimicSvg == path || telemetryJson == path;
  }

  Map<String, dynamic> toJson() {
    return {
      'mainSvg': mainSvg,
      'mimicSvg': mimicSvg,
      'telemetryJson': telemetryJson,
      'updatedAtMs': updatedAtMs,
    };
  }

  factory LinkAssociation.fromJson(Map<String, dynamic> json) {
    return LinkAssociation(
      mainSvg: (json['mainSvg'] ?? '').toString(),
      mimicSvg: (json['mimicSvg'] ?? '').toString(),
      telemetryJson: (json['telemetryJson'] ?? '').toString(),
      updatedAtMs: json['updatedAtMs'] is int ? json['updatedAtMs'] as int : null,
    );
  }
}

class LinkProvider with ChangeNotifier {
  static const _prefsKey = 'link_associations_v1';
  final List<LinkAssociation> _links = [];
  bool _loaded = false;

  List<LinkAssociation> get links => List.unmodifiable(_links);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _links
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map>()
                  .map((e) => LinkAssociation.fromJson(Map<String, dynamic>.from(e)))
                  .where((e) => e.mainSvg.isNotEmpty && e.mimicSvg.isNotEmpty && e.telemetryJson.isNotEmpty),
            );
        }
      } catch (_) {
        // Ignore corrupted stored data.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_links.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, payload);
  }

  LinkAssociation? findByPath(String path) {
    final matches = _links.where((e) => e.matchesPath(path)).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return matches.first;
  }

  void upsert(LinkAssociation link) {
    _removeConflicts(link);
    _links.insert(0, link);
    notifyListeners();
    _persist();
  }

  void updateAt(int index, LinkAssociation updated) {
    if (index < 0 || index >= _links.length) return;
    _links.removeAt(index);
    _removeConflicts(updated);
    _links.insert(0, updated);
    notifyListeners();
    _persist();
  }

  void deleteAt(int index) {
    if (index < 0 || index >= _links.length) return;
    _links.removeAt(index);
    notifyListeners();
    _persist();
  }

  int importJson(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException('Links JSON must be a list.');
    }
    var imported = 0;
    for (final entry in decoded.whereType<Map>()) {
      final link = LinkAssociation.fromJson(Map<String, dynamic>.from(entry));
      if (link.mainSvg.isEmpty || link.mimicSvg.isEmpty || link.telemetryJson.isEmpty) continue;
      upsert(link);
      imported++;
    }
    return imported;
  }

  String exportJson() {
    return jsonEncode(_links.map((e) => e.toJson()).toList());
  }

  void _removeConflicts(LinkAssociation link) {
    _links.removeWhere((existing) {
      return existing.mainSvg == link.mainSvg ||
          existing.mimicSvg == link.mimicSvg ||
          existing.telemetryJson == link.telemetryJson;
    });
  }
}
