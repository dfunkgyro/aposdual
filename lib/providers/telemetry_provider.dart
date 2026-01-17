import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diagnostic_issue.dart';
import '../models/telemetry_item.dart';

class TelemetryProvider with ChangeNotifier {
  static const String _markerStyleKey = 'telemetry_marker_style_v1';
  static const String _showMarkersKey = 'telemetry_show_markers_v1';
  static const String _pinFilterKey = 'telemetry_pin_filter_v1';
  static const String _categoryFilterKey = 'telemetry_category_filter_v1';
  static const String _levelFilterKey = 'telemetry_level_filter_v1';
  static const String _actionFilterKey = 'telemetry_action_filter_v1';
  static const String _requireAboutKey = 'telemetry_require_about_v1';
  static const String _queryKey = 'telemetry_query_v1';
  static const String _sortModeKey = 'telemetry_sort_mode_v1';
  static const String _onlyAlarmsKey = 'telemetry_only_alarms_v1';
  static const String _onlyMissingKey = 'telemetry_only_missing_v1';
  static const String _presetsKey = 'telemetry_presets_v1';
  static const String _fuzzySearchKey = 'telemetry_fuzzy_search_v1';
  final List<TelemetryItem> _items = [];
  TelemetryItem? _selectedItem;
  final Set<String> _selectedIds = {};
  String? _lastSelectedId;
  String _markerStyle = 'static';
  bool _showMarkers = false;
  String _pinFilter = 'all';
  String? _categoryFilter;
  String? _levelFilter;
  String? _actionFilter;
  bool _requireAbout = false;
  String _query = '';
  String _sortMode = 'title';
  bool _onlyAlarms = false;
  bool _onlyMissing = false;
  bool _fuzzySearchEnabled = true;
  Set<String> _alarmIds = {};
  List<TelemetryItem> _filteredCache = [];
  bool _filteredDirty = true;
  final List<TelemetryPreset> _presets = [];
  final List<String> _recentSelectionIds = [];

  List<TelemetryItem> get items => List.unmodifiable(_items);
  List<TelemetryItem> get filteredItems {
    if (_filteredDirty) {
      _filteredCache = _applyFilters();
      _filteredDirty = false;
    }
    return List.unmodifiable(_filteredCache);
  }
  TelemetryItem? get selectedItem => _selectedItem;
  List<TelemetryItem> get selectedItems {
    if (_selectedIds.isEmpty) return [];
    final map = {for (final item in _items) item.id: item};
    return _selectedIds.map((id) => map[id]).whereType<TelemetryItem>().toList();
  }
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectionCount => _selectedIds.length;
  bool get hasItems => _items.isNotEmpty;
  String get markerStyle => _markerStyle;
  bool get showMarkers => _showMarkers;
  String get pinFilter => _pinFilter;
  String? get categoryFilter => _categoryFilter;
  String? get levelFilter => _levelFilter;
  String? get actionFilter => _actionFilter;
  bool get requireAbout => _requireAbout;
  String get query => _query;
  String get sortMode => _sortMode;
  bool get onlyAlarms => _onlyAlarms;
  bool get onlyMissingDetails => _onlyMissing;
  bool get fuzzySearchEnabled => _fuzzySearchEnabled;
  List<TelemetryPreset> get presets => List.unmodifiable(_presets);
  List<TelemetryItem> get recentSelections {
    final map = {for (final item in _items) item.id: item};
    return _recentSelectionIds.map((id) => map[id]).whereType<TelemetryItem>().toList();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _markerStyle = prefs.getString(_markerStyleKey) ?? _markerStyle;
    _showMarkers = prefs.getBool(_showMarkersKey) ?? _showMarkers;
    _pinFilter = prefs.getString(_pinFilterKey) ?? _pinFilter;
    _categoryFilter = prefs.getString(_categoryFilterKey);
    _levelFilter = prefs.getString(_levelFilterKey);
    _actionFilter = prefs.getString(_actionFilterKey);
    _requireAbout = prefs.getBool(_requireAboutKey) ?? _requireAbout;
    _query = prefs.getString(_queryKey) ?? _query;
    _sortMode = prefs.getString(_sortModeKey) ?? _sortMode;
    _onlyAlarms = prefs.getBool(_onlyAlarmsKey) ?? _onlyAlarms;
    _onlyMissing = prefs.getBool(_onlyMissingKey) ?? _onlyMissing;
    _fuzzySearchEnabled = prefs.getBool(_fuzzySearchKey) ?? _fuzzySearchEnabled;
    final presetRaw = prefs.getStringList(_presetsKey);
    if (presetRaw != null) {
      _presets
        ..clear()
        ..addAll(presetRaw.map(TelemetryPreset.fromJsonString).whereType<TelemetryPreset>());
    }
    _markDirty();
    notifyListeners();
  }

  Future<void> _persistString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _persistBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> persistAllSettings() async {
    await _persistString(_markerStyleKey, _markerStyle);
    await _persistBool(_showMarkersKey, _showMarkers);
    await _persistString(_pinFilterKey, _pinFilter);
    final prefs = await SharedPreferences.getInstance();
    if (_categoryFilter != null) {
      await prefs.setString(_categoryFilterKey, _categoryFilter!);
    } else {
      await prefs.remove(_categoryFilterKey);
    }
    if (_levelFilter != null) {
      await prefs.setString(_levelFilterKey, _levelFilter!);
    } else {
      await prefs.remove(_levelFilterKey);
    }
    if (_actionFilter != null) {
      await prefs.setString(_actionFilterKey, _actionFilter!);
    } else {
      await prefs.remove(_actionFilterKey);
    }
    await _persistBool(_requireAboutKey, _requireAbout);
    await _persistString(_queryKey, _query);
    await _persistString(_sortModeKey, _sortMode);
    await _persistBool(_onlyAlarmsKey, _onlyAlarms);
    await _persistBool(_onlyMissingKey, _onlyMissing);
    await _persistBool(_fuzzySearchKey, _fuzzySearchEnabled);
    await prefs.setStringList(_presetsKey, _presets.map((e) => e.toJsonString()).toList());
  }

  void loadFromJsonString(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! List) {
      throw const FormatException('Telemetry JSON must be a list.');
    }
    _items
      ..clear()
      ..addAll(
        data
            .whereType<Map<String, dynamic>>()
            .map(TelemetryItem.fromJson)
            .where((item) => item.id.isNotEmpty || item.title.isNotEmpty),
      );
    _selectedItem = null;
    _selectedIds.clear();
    _lastSelectedId = null;
    _markDirty();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _selectedItem = null;
    _markDirty();
    notifyListeners();
  }

  String toJsonString() {
    return jsonEncode(_items.map((e) => e.toJson()).toList());
  }

  void selectItem(TelemetryItem? item, {bool clearSelection = true}) {
    _selectedItem = item;
    if (item != null) {
      _recentSelectionIds.remove(item.id);
      _recentSelectionIds.insert(0, item.id);
      if (_recentSelectionIds.length > 20) {
        _recentSelectionIds.removeRange(20, _recentSelectionIds.length);
      }
      if (clearSelection) {
        _selectedIds
          ..clear()
          ..add(item.id);
      }
      _lastSelectedId = item.id;
    } else if (clearSelection) {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  void toggleSelection(TelemetryItem item) {
    if (_selectedIds.contains(item.id)) {
      _selectedIds.remove(item.id);
      if (_selectedItem?.id == item.id) {
        _selectedItem = _selectedIds.isEmpty ? null : _items.firstWhere((e) => _selectedIds.contains(e.id), orElse: () => item);
      }
    } else {
      _selectedIds.add(item.id);
      _selectedItem = item;
      _lastSelectedId = item.id;
    }
    notifyListeners();
  }

  void addToSelection(TelemetryItem item) {
    _selectedIds.add(item.id);
    _selectedItem = item;
    _lastSelectedId = item.id;
    notifyListeners();
  }

  void selectRange(TelemetryItem item) {
    if (_lastSelectedId == null || _lastSelectedId == item.id) {
      addToSelection(item);
      return;
    }
    final list = filteredItems;
    final startIndex = list.indexWhere((e) => e.id == _lastSelectedId);
    final endIndex = list.indexWhere((e) => e.id == item.id);
    if (startIndex == -1 || endIndex == -1) {
      addToSelection(item);
      return;
    }
    final lower = startIndex < endIndex ? startIndex : endIndex;
    final upper = startIndex < endIndex ? endIndex : startIndex;
    for (var i = lower; i <= upper; i++) {
      _selectedIds.add(list[i].id);
    }
    _selectedItem = item;
    _lastSelectedId = item.id;
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    _selectedItem = null;
    _lastSelectedId = null;
    notifyListeners();
  }

  void updateItem(String id, TelemetryItem updated) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _items[index] = updated;
    _markDirty();
    notifyListeners();
  }

  void updateItems(Iterable<String> ids, TelemetryItem Function(TelemetryItem) updater) {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (ids.contains(item.id)) {
        _items[i] = updater(item);
        changed = true;
      }
    }
    if (changed) {
      _markDirty();
      notifyListeners();
    }
  }

  TelemetryItem? selectNext({bool useFiltered = true}) {
    final list = useFiltered ? filteredItems : _items;
    if (list.isEmpty) return null;
    if (_selectedItem == null) {
      _selectedItem = list.first;
      _selectedIds
        ..clear()
        ..add(_selectedItem!.id);
      notifyListeners();
      return _selectedItem;
    }
    final index = list.indexWhere((item) => item.id == _selectedItem!.id);
    final nextIndex = index == -1 ? 0 : (index + 1) % list.length;
    _selectedItem = list[nextIndex];
    _selectedIds
      ..clear()
      ..add(_selectedItem!.id);
    notifyListeners();
    return _selectedItem;
  }

  TelemetryItem? selectPrevious({bool useFiltered = true}) {
    final list = useFiltered ? filteredItems : _items;
    if (list.isEmpty) return null;
    if (_selectedItem == null) {
      _selectedItem = list.first;
      _selectedIds
        ..clear()
        ..add(_selectedItem!.id);
      notifyListeners();
      return _selectedItem;
    }
    final index = list.indexWhere((item) => item.id == _selectedItem!.id);
    final prevIndex = index == -1 ? 0 : (index - 1 + list.length) % list.length;
    _selectedItem = list[prevIndex];
    _selectedIds
      ..clear()
      ..add(_selectedItem!.id);
    notifyListeners();
    return _selectedItem;
  }

  void setMarkerStyle(String style) {
    _markerStyle = style;
    notifyListeners();
    _persistString(_markerStyleKey, _markerStyle);
  }

  void setShowMarkers(bool show) {
    _showMarkers = show;
    notifyListeners();
    _persistBool(_showMarkersKey, _showMarkers);
  }

  void setPinFilter(String value) {
    _pinFilter = value;
    _markDirty();
    notifyListeners();
    _persistString(_pinFilterKey, _pinFilter);
  }

  void setCategoryFilter(String? value) {
    _categoryFilter = value;
    _markDirty();
    notifyListeners();
    final v = _categoryFilter;
    if (v == null) {
      SharedPreferences.getInstance().then((prefs) => prefs.remove(_categoryFilterKey));
    } else {
      _persistString(_categoryFilterKey, v);
    }
  }

  void setLevelFilter(String? value) {
    _levelFilter = value;
    _markDirty();
    notifyListeners();
    final v = _levelFilter;
    if (v == null) {
      SharedPreferences.getInstance().then((prefs) => prefs.remove(_levelFilterKey));
    } else {
      _persistString(_levelFilterKey, v);
    }
  }

  void setActionFilter(String? value) {
    _actionFilter = value;
    _markDirty();
    notifyListeners();
    final v = _actionFilter;
    if (v == null) {
      SharedPreferences.getInstance().then((prefs) => prefs.remove(_actionFilterKey));
    } else {
      _persistString(_actionFilterKey, v);
    }
  }

  void setRequireAbout(bool value) {
    _requireAbout = value;
    _markDirty();
    notifyListeners();
    _persistBool(_requireAboutKey, _requireAbout);
  }

  void setQuery(String value) {
    _query = value;
    _markDirty();
    notifyListeners();
    _persistString(_queryKey, _query);
  }

  void setSortMode(String value) {
    _sortMode = value;
    _markDirty();
    notifyListeners();
    _persistString(_sortModeKey, _sortMode);
  }

  void setOnlyAlarms(bool value) {
    _onlyAlarms = value;
    _markDirty();
    notifyListeners();
    _persistBool(_onlyAlarmsKey, _onlyAlarms);
  }

  void setOnlyMissingDetails(bool value) {
    _onlyMissing = value;
    _markDirty();
    notifyListeners();
    _persistBool(_onlyMissingKey, _onlyMissing);
  }

  void setFuzzySearchEnabled(bool value) {
    _fuzzySearchEnabled = value;
    notifyListeners();
    _persistBool(_fuzzySearchKey, _fuzzySearchEnabled);
  }

  void setAlarmIds(Set<String> ids) {
    if (setEquals(_alarmIds, ids)) return;
    _alarmIds = ids;
    _markDirty();
    notifyListeners();
  }

  void savePreset(String name) {
    final existing = _presets.indexWhere((p) => p.name == name);
    final preset = TelemetryPreset(
      name: name,
      markerStyle: _markerStyle,
      showMarkers: _showMarkers,
      pinFilter: _pinFilter,
      categoryFilter: _categoryFilter,
      levelFilter: _levelFilter,
      actionFilter: _actionFilter,
      requireAbout: _requireAbout,
      query: _query,
      sortMode: _sortMode,
      onlyAlarms: _onlyAlarms,
      onlyMissing: _onlyMissing,
    );
    if (existing >= 0) {
      _presets[existing] = preset;
    } else {
      _presets.add(preset);
    }
    notifyListeners();
    persistAllSettings();
  }

  void applyPreset(TelemetryPreset preset) {
    _markerStyle = preset.markerStyle;
    _showMarkers = preset.showMarkers;
    _pinFilter = preset.pinFilter;
    _categoryFilter = preset.categoryFilter;
    _levelFilter = preset.levelFilter;
    _actionFilter = preset.actionFilter;
    _requireAbout = preset.requireAbout;
    _query = preset.query;
    _sortMode = preset.sortMode;
    _onlyAlarms = preset.onlyAlarms;
    _onlyMissing = preset.onlyMissing;
    _markDirty();
    notifyListeners();
    persistAllSettings();
  }

  void deletePreset(String name) {
    _presets.removeWhere((p) => p.name == name);
    notifyListeners();
    persistAllSettings();
  }

  Map<String, dynamic> toSettingsJson() {
    return {
      'markerStyle': _markerStyle,
      'showMarkers': _showMarkers,
      'pinFilter': _pinFilter,
      'categoryFilter': _categoryFilter,
      'levelFilter': _levelFilter,
      'actionFilter': _actionFilter,
      'requireAbout': _requireAbout,
      'query': _query,
      'sortMode': _sortMode,
      'onlyAlarms': _onlyAlarms,
      'onlyMissing': _onlyMissing,
      'fuzzySearchEnabled': _fuzzySearchEnabled,
      'presets': _presets.map((e) => e.toJson()).toList(),
    };
  }

  void applySettingsJson(Map<String, dynamic> data) {
    _markerStyle = data['markerStyle']?.toString() ?? _markerStyle;
    _showMarkers = data['showMarkers'] == true;
    _pinFilter = data['pinFilter']?.toString() ?? _pinFilter;
    _categoryFilter = data['categoryFilter']?.toString();
    _levelFilter = data['levelFilter']?.toString();
    _actionFilter = data['actionFilter']?.toString();
    _requireAbout = data['requireAbout'] == true;
    _query = data['query']?.toString() ?? '';
    _sortMode = data['sortMode']?.toString() ?? _sortMode;
    _onlyAlarms = data['onlyAlarms'] == true;
    _onlyMissing = data['onlyMissing'] == true;
    _fuzzySearchEnabled = data['fuzzySearchEnabled'] == true;
    _presets
      ..clear()
      ..addAll(
        (data['presets'] as List?)
                ?.whereType<Map>()
                .map((e) => TelemetryPreset.fromJson(Map<String, dynamic>.from(e)))
                .whereType<TelemetryPreset>()
                .toList() ??
            [],
      );
    _markDirty();
    notifyListeners();
    persistAllSettings();
  }

  List<TelemetryItem> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return [];
    if (_fuzzySearchEnabled) {
      return _searchFuzzy(needle);
    }
    return filteredItems.where((item) => _matchesQuery(item, needle)).toList();
  }

  Map<String, List<TelemetryItem>> groupedByCategory({bool useFilters = true}) {
    final Map<String, List<TelemetryItem>> groups = {};
    final source = useFilters ? filteredItems : _items;
    for (final item in source) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }
    return groups;
  }

  List<String> categories() {
    final set = _items.map((e) => e.category).where((e) => e.isNotEmpty).toSet();
    final list = set.toList()..sort();
    return list;
  }

  List<String> levels() {
    final set = _items.map((e) => e.level).where((e) => e.isNotEmpty).toSet();
    final list = set.toList()..sort();
    return list;
  }

  List<String> actions() {
    final set = _items.map((e) => e.action).where((e) => e.isNotEmpty).toSet();
    final list = set.toList()..sort();
    return list;
  }

  List<TelemetryItem> _applyFilters() {
    final list = _items.where((item) {
      if (_pinFilter == 'hidden' && item.pin != 'hidden') return false;
      if (_pinFilter == 'visible' && item.pin == 'hidden') return false;
      if (_categoryFilter != null && _categoryFilter!.isNotEmpty && item.category != _categoryFilter) return false;
      if (_levelFilter != null && _levelFilter!.isNotEmpty && item.level != _levelFilter) return false;
      if (_actionFilter != null && _actionFilter!.isNotEmpty && item.action != _actionFilter) return false;
      if (_requireAbout && (item.about == null || item.about!.isEmpty) && (item.description == null || item.description!.isEmpty)) return false;
      if (_onlyMissing && (item.about != null && item.about!.isNotEmpty) && (item.description != null && item.description!.isNotEmpty)) return false;
      if (_onlyAlarms && !_alarmIds.contains(item.id)) return false;
      if (_query.isNotEmpty && !_matchesQuery(item, _query.toLowerCase())) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sortMode) {
        case 'id':
          return a.id.compareTo(b.id);
        case 'category':
          return a.category.compareTo(b.category);
        case 'level':
          return a.level.compareTo(b.level);
        default:
          return a.title.compareTo(b.title);
      }
    });
    return list;
  }

  bool _matchesQuery(TelemetryItem item, String needle) {
    return item.title.toLowerCase().contains(needle) ||
        item.id.toLowerCase().contains(needle) ||
        item.category.toLowerCase().contains(needle) ||
        item.level.toLowerCase().contains(needle) ||
        item.action.toLowerCase().contains(needle) ||
        (item.about?.toLowerCase().contains(needle) ?? false) ||
        (item.description?.toLowerCase().contains(needle) ?? false);
  }

  void _markDirty() {
    _filteredDirty = true;
  }

  List<TelemetryItem> _searchFuzzy(String needle) {
    final results = <_ScoredItem>[];
    for (final item in filteredItems) {
      final score = _fuzzyScore(item, needle);
      if (score > 0) {
        results.add(_ScoredItem(item, score));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.map((e) => e.item).toList();
  }

  int _fuzzyScore(TelemetryItem item, String needle) {
    final haystack = '${item.title} ${item.id} ${item.category} ${item.level} ${item.action} ${item.about ?? ''} ${item.description ?? ''}'
        .toLowerCase();
    if (haystack.contains(needle)) {
      return 100 + needle.length;
    }
    return _subsequenceScore(haystack, needle);
  }

  int _subsequenceScore(String haystack, String needle) {
    var score = 0;
    var hIndex = 0;
    for (var i = 0; i < needle.length; i++) {
      final ch = needle[i];
      var found = false;
      while (hIndex < haystack.length) {
        if (haystack[hIndex] == ch) {
          score += 2;
          hIndex++;
          found = true;
          break;
        }
        hIndex++;
      }
      if (!found) return 0;
    }
    return score;
  }

  List<DiagnosticIssue> validateItems() {
    final issues = <DiagnosticIssue>[];
    final seenIds = <String>{};
    for (final item in _items) {
      if (item.id.isEmpty) {
        issues.add(const DiagnosticIssue(
          severity: DiagnosticSeverity.error,
          source: 'telemetry',
          message: 'Telemetry item missing id.',
        ));
      } else if (!seenIds.add(item.id)) {
        issues.add(DiagnosticIssue(
          severity: DiagnosticSeverity.error,
          source: 'telemetry',
          message: 'Duplicate telemetry id: ${item.id}',
          itemId: item.id,
        ));
      }
      if (item.title.isEmpty) {
        issues.add(DiagnosticIssue(
          severity: DiagnosticSeverity.warning,
          source: 'telemetry',
          message: 'Telemetry item missing title.',
          itemId: item.id.isEmpty ? null : item.id,
        ));
      }
      if (item.x.isNaN || item.y.isNaN) {
        issues.add(DiagnosticIssue(
          severity: DiagnosticSeverity.error,
          source: 'telemetry',
          message: 'Invalid coordinates for ${item.id}.',
          itemId: item.id.isEmpty ? null : item.id,
        ));
      } else if (item.x < 0 || item.x > 1 || item.y < 0 || item.y > 1) {
        issues.add(DiagnosticIssue(
          severity: DiagnosticSeverity.warning,
          source: 'telemetry',
          message: 'Coordinates out of range for ${item.id} (expected 0-1).',
          itemId: item.id.isEmpty ? null : item.id,
        ));
      }
      if ((item.about == null || item.about!.isEmpty) && (item.description == null || item.description!.isEmpty)) {
        issues.add(DiagnosticIssue(
          severity: DiagnosticSeverity.info,
          source: 'telemetry',
          message: 'Missing about/description for ${item.id}.',
          itemId: item.id.isEmpty ? null : item.id,
        ));
      }
    }
    return issues;
  }
}

class TelemetryPreset {
  final String name;
  final String markerStyle;
  final bool showMarkers;
  final String pinFilter;
  final String? categoryFilter;
  final String? levelFilter;
  final String? actionFilter;
  final bool requireAbout;
  final String query;
  final String sortMode;
  final bool onlyAlarms;
  final bool onlyMissing;

  const TelemetryPreset({
    required this.name,
    required this.markerStyle,
    required this.showMarkers,
    required this.pinFilter,
    required this.categoryFilter,
    required this.levelFilter,
    required this.actionFilter,
    required this.requireAbout,
    required this.query,
    required this.sortMode,
    required this.onlyAlarms,
    required this.onlyMissing,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'markerStyle': markerStyle,
      'showMarkers': showMarkers,
      'pinFilter': pinFilter,
      'categoryFilter': categoryFilter,
      'levelFilter': levelFilter,
      'actionFilter': actionFilter,
      'requireAbout': requireAbout,
      'query': query,
      'sortMode': sortMode,
      'onlyAlarms': onlyAlarms,
      'onlyMissing': onlyMissing,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static TelemetryPreset? fromJsonString(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return null;
      return fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  static TelemetryPreset? fromJson(Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? '';
    if (name.isEmpty) return null;
    return TelemetryPreset(
      name: name,
      markerStyle: data['markerStyle']?.toString() ?? 'static',
      showMarkers: data['showMarkers'] == true,
      pinFilter: data['pinFilter']?.toString() ?? 'all',
      categoryFilter: data['categoryFilter']?.toString(),
      levelFilter: data['levelFilter']?.toString(),
      actionFilter: data['actionFilter']?.toString(),
      requireAbout: data['requireAbout'] == true,
      query: data['query']?.toString() ?? '',
      sortMode: data['sortMode']?.toString() ?? 'title',
      onlyAlarms: data['onlyAlarms'] == true,
      onlyMissing: data['onlyMissing'] == true,
    );
  }
}

class _ScoredItem {
  final TelemetryItem item;
  final int score;

  const _ScoredItem(this.item, this.score);
}
