import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/telemetry_item.dart';
import '../models/diagnostic_issue.dart';

class AlarmItem {
  final String id;
  final String title;

  const AlarmItem({required this.id, required this.title});

  factory AlarmItem.fromJson(Map<String, dynamic> json) {
    return AlarmItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class AlarmProvider with ChangeNotifier {
  static const String _showMarkersKey = 'alarm_show_markers_v1';
  final List<AlarmItem> _alarms = [];
  final List<TelemetryItem> _matches = [];
  bool _showMarkers = false;

  List<AlarmItem> get alarms => List.unmodifiable(_alarms);
  List<TelemetryItem> get matches => List.unmodifiable(_matches);
  bool get showMarkers => _showMarkers;

  String toJsonString() {
    return jsonEncode(_alarms.map((e) => {'id': e.id, 'title': e.title}).toList());
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showMarkers = prefs.getBool(_showMarkersKey) ?? _showMarkers;
    notifyListeners();
  }

  Future<void> _persistBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> persistAllSettings() async {
    await _persistBool(_showMarkersKey, _showMarkers);
  }

  void loadFromJsonString(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! List) {
      throw const FormatException('Alarm JSON must be a list.');
    }
    _alarms
      ..clear()
      ..addAll(data.whereType<Map<String, dynamic>>().map(AlarmItem.fromJson));
    notifyListeners();
  }

  void checkMatches(List<TelemetryItem> telemetryItems) {
    _matches
      ..clear()
      ..addAll(
        telemetryItems.where((item) {
          return _alarms.any((alarm) => alarm.id == item.id || alarm.title == item.title);
        }),
      );
    notifyListeners();
  }

  void toggleMarkers() {
    _showMarkers = !_showMarkers;
    notifyListeners();
    _persistBool(_showMarkersKey, _showMarkers);
  }

  Map<String, dynamic> toSettingsJson() {
    return {
      'showMarkers': _showMarkers,
    };
  }

  void applySettingsJson(Map<String, dynamic> data) {
    _showMarkers = data['showMarkers'] == true;
    notifyListeners();
    persistAllSettings();
  }

  void clear() {
    _alarms.clear();
    _matches.clear();
    notifyListeners();
  }

  List<DiagnosticIssue> validateAlarms(List<TelemetryItem> telemetryItems) {
    final issues = <DiagnosticIssue>[];
    final seenIds = <String>{};
    final telemetryIds = telemetryItems.map((e) => e.id).toSet();
    for (final alarm in _alarms) {
      if (alarm.id.isEmpty) {
        issues.add(const DiagnosticIssue(
          severity: DiagnosticSeverity.error,
          source: 'alarms',
          message: 'Alarm item missing id.',
        ));
      } else if (!seenIds.add(alarm.id)) {
        issues.add(DiagnosticIssue(
          severity: DiagnosticSeverity.warning,
          source: 'alarms',
          message: 'Duplicate alarm id: ${alarm.id}',
          itemId: alarm.id,
        ));
      }
      if (alarm.title.isEmpty) {
        issues.add(DiagnosticIssue(
          severity: DiagnosticSeverity.warning,
          source: 'alarms',
          message: 'Alarm missing title for id ${alarm.id}.',
          itemId: alarm.id.isEmpty ? null : alarm.id,
        ));
      }
      if (alarm.id.isNotEmpty && !telemetryIds.contains(alarm.id)) {
        issues.add(DiagnosticIssue(
          severity: DiagnosticSeverity.info,
          source: 'alarms',
          message: 'Alarm id ${alarm.id} not found in telemetry.',
          itemId: alarm.id,
        ));
      }
    }
    return issues;
  }
}
