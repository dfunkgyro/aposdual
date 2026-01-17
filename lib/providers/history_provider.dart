import 'dart:convert';
import 'package:flutter/foundation.dart';

class HistoryEntry {
  final DateTime timestamp;
  final String action;
  final String category;

  const HistoryEntry({
    required this.timestamp,
    required this.action,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        'category': category,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      action: json['action']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
    );
  }
}

class HistoryProvider with ChangeNotifier {
  final List<HistoryEntry> _entries = [];

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  void addEntry(String action, {String category = 'General'}) {
    _entries.insert(0, HistoryEntry(timestamp: DateTime.now(), action: action, category: category));
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void loadFromJsonString(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! List) {
      throw const FormatException('History JSON must be a list.');
    }
    _entries
      ..clear()
      ..addAll(
        data.whereType<Map<String, dynamic>>().map(HistoryEntry.fromJson),
      );
    notifyListeners();
  }

  String toJsonString() {
    return jsonEncode(_entries.map((e) => e.toJson()).toList());
  }
}
