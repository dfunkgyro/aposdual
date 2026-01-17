import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

enum TextOrientation { horizontal, vertical }

class TextObject {
  String id;
  String text;
  Offset position;
  Color color;
  double fontSize;
  String fontFamily;
  double rotation;
  TextOrientation orientation;

  // Special effects
  String? effectType; // "flash", "disappear", "colorChange"
  int? effectInterval;
  List<Color>? effectColors;

  TextObject({
    required this.id,
    required this.text,
    required this.position,
    this.color = Colors.black,
    this.fontSize = 16.0,
    this.fontFamily = 'Arial',
    this.rotation = 0.0,
    this.orientation = TextOrientation.horizontal,
    this.effectType,
    this.effectInterval,
    this.effectColors,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'x': position.dx,
      'y': position.dy,
      'color': color.value,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'rotation': rotation,
      'orientation': orientation.toString().split('.').last,
      'effectType': effectType,
      'effectInterval': effectInterval,
      'effectColors': effectColors?.map((c) => c.value).toList(),
    };
  }

  factory TextObject.fromJson(Map<String, dynamic> json) {
    final orientationRaw = json['orientation']?.toString() ?? 'horizontal';
    final orientation = TextOrientation.values.firstWhere(
      (o) => o.toString().split('.').last == orientationRaw,
      orElse: () => TextOrientation.horizontal,
    );
    final effectColorsRaw = json['effectColors'] as List<dynamic>?;
    final effectColors = effectColorsRaw?.map((c) => Color((c as num).toInt())).toList();
    return TextObject(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: json['text']?.toString() ?? '',
      position: Offset(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      ),
      color: Color((json['color'] as num?)?.toInt() ?? Colors.black.value),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      fontFamily: json['fontFamily']?.toString() ?? 'Arial',
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      orientation: orientation,
      effectType: json['effectType']?.toString(),
      effectInterval: (json['effectInterval'] as num?)?.toInt(),
      effectColors: effectColors,
    );
  }
}

class TextProvider with ChangeNotifier {
  final List<TextObject> _texts = [];
  TextObject? _selectedText;
  bool _placingText = false;
  Timer? _effectsTimer;
  final Map<String, bool> _visibility = {};
  final Map<String, int> _colorIndex = {};
  final Map<String, DateTime> _lastTick = {};

  // Tool settings
  String _currentText = "";
  Color _currentColor = Colors.black;
  double _currentFontSize = 16.0;
  String _currentFontFamily = 'Arial';
  double _currentRotation = 0.0;
  TextOrientation _currentOrientation = TextOrientation.horizontal;
  String _currentEffectType = 'none';
  int _currentEffectInterval = 1000;
  List<Color> _currentEffectColors = [];

  List<TextObject> get texts => _texts;
  TextObject? get selectedText => _selectedText;
  bool get placingText => _placingText;
  bool isVisible(String id) => _visibility[id] ?? true;

  // Getters for tool settings
  String get currentTextInput => _currentText;
  Color get currentColor => _currentColor;
  double get currentFontSize => _currentFontSize;
  String get currentFontFamily => _currentFontFamily;
  double get currentRotation => _currentRotation;
  TextOrientation get currentOrientation => _currentOrientation;
  String get currentEffectType => _currentEffectType;
  int get currentEffectInterval => _currentEffectInterval;
  List<Color> get currentEffectColors => _currentEffectColors;

  Color currentEffectColor(TextObject text) {
    if (text.effectType != 'colorChange' || text.effectColors == null || text.effectColors!.isEmpty) {
      return text.color;
    }
    final index = _colorIndex[text.id] ?? 0;
    return text.effectColors![index % text.effectColors!.length];
  }

  void updateToolSettings({
    String? text,
    Color? color,
    double? fontSize,
    String? fontFamily,
    double? rotation,
    TextOrientation? orientation,
    String? effectType,
    int? effectInterval,
    List<Color>? effectColors,
  }) {
    if (text != null) _currentText = text;
    if (color != null) _currentColor = color;
    if (fontSize != null) _currentFontSize = fontSize;
    if (fontFamily != null) _currentFontFamily = fontFamily;
    if (rotation != null) _currentRotation = rotation;
    if (orientation != null) _currentOrientation = orientation;
    if (effectType != null) _currentEffectType = effectType;
    if (effectInterval != null) _currentEffectInterval = effectInterval;
    if (effectColors != null) _currentEffectColors = effectColors;
    notifyListeners();
  }

  void addText(Offset position) {
    if (_currentText.isEmpty) return;

    final newText = TextObject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _currentText,
      position: position,
      color: _currentColor,
      fontSize: _currentFontSize,
      fontFamily: _currentFontFamily,
      rotation: _currentRotation,
      orientation: _currentOrientation,
      effectType: _currentEffectType,
      effectInterval: _currentEffectInterval,
      effectColors: _currentEffectColors,
    );

    _texts.add(newText);
    _visibility[newText.id] = true;
    _colorIndex[newText.id] = 0;
    _lastTick[newText.id] = DateTime.now();
    _ensureEffectsTimer();
    notifyListeners();
  }

  void selectText(String id) {
    try {
      _selectedText = _texts.firstWhere((t) => t.id == id);
      _currentText = _selectedText!.text;
      _currentColor = _selectedText!.color;
      _currentFontSize = _selectedText!.fontSize;
      _currentFontFamily = _selectedText!.fontFamily;
      _currentRotation = _selectedText!.rotation;
      _currentOrientation = _selectedText!.orientation;
      _currentEffectType = _selectedText!.effectType ?? 'none';
      _currentEffectInterval = _selectedText!.effectInterval ?? 1000;
      _currentEffectColors = _selectedText!.effectColors ?? [];
      notifyListeners();
    } catch (_) {
      _selectedText = null;
      notifyListeners();
    }
  }

  void updateSelectedText() {
    if (_selectedText == null) return;
    _selectedText!.text = _currentText;
    _selectedText!.color = _currentColor;
    _selectedText!.fontSize = _currentFontSize;
    _selectedText!.fontFamily = _currentFontFamily;
    _selectedText!.rotation = _currentRotation;
    _selectedText!.orientation = _currentOrientation;
    _selectedText!.effectType = _currentEffectType;
    _selectedText!.effectInterval = _currentEffectInterval;
    _selectedText!.effectColors = _currentEffectColors;
    notifyListeners();
  }

  void removeSelectedText() {
    if (_selectedText != null) {
      _visibility.remove(_selectedText!.id);
      _colorIndex.remove(_selectedText!.id);
      _lastTick.remove(_selectedText!.id);
      _texts.remove(_selectedText);
      _selectedText = null;
      notifyListeners();
    }
  }

  void clearTexts() {
    _texts.clear();
    _selectedText = null;
    _visibility.clear();
    _colorIndex.clear();
    _lastTick.clear();
    notifyListeners();
  }

  void setPlacingText(bool placing) {
    _placingText = placing;
    notifyListeners();
  }

  void moveSelectedText(Offset delta) {
    if (_selectedText == null) return;
    _selectedText!.position += delta;
    notifyListeners();
  }

  void loadFromJsonString(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! List) {
      throw const FormatException('Text JSON must be a list.');
    }
    _texts
      ..clear()
      ..addAll(data.whereType<Map<String, dynamic>>().map(TextObject.fromJson));
    _selectedText = null;
    _visibility.clear();
    _colorIndex.clear();
    _lastTick.clear();
    for (final text in _texts) {
      _visibility[text.id] = true;
      _colorIndex[text.id] = 0;
      _lastTick[text.id] = DateTime.now();
    }
    _ensureEffectsTimer();
    notifyListeners();
  }

  String toJsonString() {
    return jsonEncode(_texts.map((t) => t.toJson()).toList());
  }

  void _ensureEffectsTimer() {
    if (_effectsTimer != null) return;
    _effectsTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final now = DateTime.now();
      bool changed = false;
      for (final text in _texts) {
        final interval = text.effectInterval ?? 1000;
        if (text.effectType == null || text.effectType == 'none' || interval <= 0) continue;
        final last = _lastTick[text.id] ?? now;
        if (now.difference(last).inMilliseconds < interval) continue;
        _lastTick[text.id] = now;
        if (text.effectType == 'flash' || text.effectType == 'disappear') {
          _visibility[text.id] = !(_visibility[text.id] ?? true);
          changed = true;
        } else if (text.effectType == 'colorChange') {
          final index = (_colorIndex[text.id] ?? 0) + 1;
          _colorIndex[text.id] = index;
          changed = true;
        }
      }
      if (changed) notifyListeners();
    });
  }

  void disposeEffects() {
    _effectsTimer?.cancel();
    _effectsTimer = null;
  }
}
