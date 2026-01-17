import 'dart:convert';
import 'package:flutter/material.dart';

enum DrawingTool { none, line, circle, rectangle, triangle, star, freehand }

class DrawingObject {
  final DrawingTool type;
  List<Offset> points; // Mutable for updates? Or keep immutable and replace? Let's make it typical final for now but we might need to regenerate it if we apply transforms permanently.
  // Actually, for "Relocate", we can just add an offset.
  final Color color;
  final double strokeWidth;
  final bool isFilled;
  final Path? path; 
  final double opacity;
  
  // Transforms
  double rotation; // Radians
  double scale;
  Offset offset;

  DrawingObject({
    required this.type,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.isFilled,
    this.path,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.offset = Offset.zero,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
      'isFilled': isFilled,
      'opacity': opacity,
      'rotation': rotation,
      'scale': scale,
      'offset': {'x': offset.dx, 'y': offset.dy},
    };
  }

  factory DrawingObject.fromJson(Map<String, dynamic> json) {
    final typeString = json['type']?.toString() ?? 'line';
    final tool = DrawingTool.values.firstWhere(
      (t) => t.toString().split('.').last == typeString,
      orElse: () => DrawingTool.line,
    );
    final pointsRaw = json['points'] as List<dynamic>? ?? [];
    final points = pointsRaw.map((p) {
      final map = p as Map<String, dynamic>;
      return Offset(
        (map['x'] as num?)?.toDouble() ?? 0.0,
        (map['y'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
    final offsetMap = json['offset'] as Map<String, dynamic>? ?? {};
    return DrawingObject(
      type: tool,
      points: points,
      color: Color((json['color'] as num?)?.toInt() ?? Colors.black.value),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      isFilled: json['isFilled'] == true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      offset: Offset(
        (offsetMap['x'] as num?)?.toDouble() ?? 0.0,
        (offsetMap['y'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }
}

class DrawingProvider with ChangeNotifier {
  final List<DrawingObject> _drawings = [];
  final List<DrawingObject> _undoStack = [];
  
  DrawingTool _currentTool = DrawingTool.none;
  Color _currentColor = Colors.black;
  double _currentStrokeWidth = 2.0;
  bool _isFilled = false;
  
  List<Offset> _currentPoints = [];
  
  // Selection
  DrawingObject? _selectedDrawing;
  final List<DrawingObject> _selectedDrawings = [];

  List<DrawingObject> get drawings => _drawings;
  DrawingTool get currentTool => _currentTool;
  Color get currentColor => _currentColor;
  double get currentStrokeWidth => _currentStrokeWidth;
  bool get isFilled => _isFilled;
  DrawingObject? get selectedDrawing => _selectedDrawing;
  List<DrawingObject> get selectedDrawings => List.unmodifiable(_selectedDrawings);
  
  // Undo/Redo Capability
  bool get canUndo => _drawings.isNotEmpty;
  bool get canRedo => _undoStack.isNotEmpty;

  void setTool(DrawingTool tool) {
    _currentTool = tool;
    _selectedDrawing = null; // Clear selection when switching tools
    notifyListeners();
  }

  void setColor(Color color) {
    _currentColor = color;
    if (_selectedDrawings.isNotEmpty) {
       for (final drawing in _selectedDrawings) {
         _replaceDrawing(drawing, drawing.copyWith(color: color));
       }
    }
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _currentStrokeWidth = width;
     if (_selectedDrawings.isNotEmpty) {
       for (final drawing in _selectedDrawings) {
         _replaceDrawing(drawing, drawing.copyWith(strokeWidth: width));
       }
    }
    notifyListeners();
  }

  void toggleFill(bool fill) {
    _isFilled = fill;
     if (_selectedDrawings.isNotEmpty) {
       for (final drawing in _selectedDrawings) {
         _replaceDrawing(drawing, drawing.copyWith(isFilled: fill));
       }
    }
    notifyListeners();
  }

  void setOpacity(double opacity) {
    if (_selectedDrawings.isNotEmpty) {
      for (final drawing in _selectedDrawings) {
        _replaceDrawing(drawing, drawing.copyWith(opacity: opacity));
      }
    }
    notifyListeners();
  }
  
  // Transform Methods
  void rotateSelected(double angleRadians) {
    if (_selectedDrawings.isEmpty) return;
    for (final drawing in _selectedDrawings) {
      drawing.rotation += angleRadians;
    }
    notifyListeners();
  }
  
  void resizeSelected(double scaleFactor) {
    if (_selectedDrawings.isEmpty) return;
    for (final drawing in _selectedDrawings) {
      drawing.scale *= scaleFactor;
    }
    notifyListeners();
  }
  
  void moveSelected(Offset delta) {
    if (_selectedDrawings.isEmpty) return;
    for (final drawing in _selectedDrawings) {
      drawing.offset += delta;
    }
    notifyListeners();
  }
  
  void selectDrawing(DrawingObject? drawing) {
    _selectedDrawing = drawing;
    _selectedDrawings
      ..clear()
      ..addAll(drawing == null ? [] : [drawing]);
    if (drawing != null) {
       _currentColor = drawing.color;
       _currentStrokeWidth = drawing.strokeWidth;
       _isFilled = drawing.isFilled;
    }
    notifyListeners();
  }

  void selectAt(Offset point) {
    DrawingObject? hit;
    for (int i = _drawings.length - 1; i >= 0; i--) {
      if (_hitTest(_drawings[i], point)) {
        hit = _drawings[i];
        break;
      }
    }
    selectDrawing(hit);
  }

  void selectAll() {
    _selectedDrawings
      ..clear()
      ..addAll(_drawings);
    _selectedDrawing = _selectedDrawings.isNotEmpty ? _selectedDrawings.last : null;
    notifyListeners();
  }

  void deselectAll() {
    _selectedDrawings.clear();
    _selectedDrawing = null;
    notifyListeners();
  }

  void removeSelected() {
    if (_selectedDrawings.isEmpty) return;
    _drawings.removeWhere(_selectedDrawings.contains);
    _selectedDrawings.clear();
    _selectedDrawing = null;
    notifyListeners();
  }
  
  void startDrawing(Offset point) {
    if (_currentTool == DrawingTool.none) {
       // Hit test for selection logic could go here or in UI
       return;
    }
    _currentPoints = [point];
  }

  void updateDrawing(Offset point) {
    if (_currentTool == DrawingTool.none) return;
    
    if (_currentTool == DrawingTool.freehand) {
      _currentPoints.add(point);
    } else {
      if (_currentPoints.length > 1) {
        _currentPoints.last = point;
      } else {
        _currentPoints.add(point);
      }
    }
    notifyListeners(); 
  }

  void endDrawing() {
    if (_currentTool == DrawingTool.none || _currentPoints.isEmpty) return;

    final obj = DrawingObject(
      type: _currentTool,
      points: List.from(_currentPoints),
      color: _currentColor,
      strokeWidth: _currentStrokeWidth,
      isFilled: _isFilled,
      path: _currentTool == DrawingTool.freehand ? _createSmoothedPath(_currentPoints) : null,
    );

    _drawings.add(obj);
    _undoStack.clear(); 
    _currentPoints = [];
    notifyListeners();
  }
  
  Path _createSmoothedPath(List<Offset> points) {
    if (points.isEmpty) return Path();
    if (points.length < 3) return Path()..addPolygon(points, false);
    
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        path.lineTo(p1.dx, p1.dy);
    }
    return path;
  }

  void undo() {
    if (_drawings.isNotEmpty) {
      final obj = _drawings.removeLast();
      _undoStack.add(obj);
      notifyListeners();
    }
  }

  void redo() {
    if (_undoStack.isNotEmpty) {
      final obj = _undoStack.removeLast();
      _drawings.add(obj);
      notifyListeners();
    }
  }

  void clearDrawings() {
    _drawings.clear();
    _selectedDrawing = null;
    _selectedDrawings.clear();
    notifyListeners();
  }
  
  void _replaceDrawing(DrawingObject oldObj, DrawingObject newObj) {
     final index = _drawings.indexOf(oldObj);
     if (index != -1) {
       _drawings[index] = newObj;
       _selectedDrawing = newObj;
       final selectedIndex = _selectedDrawings.indexOf(oldObj);
       if (selectedIndex != -1) {
         _selectedDrawings[selectedIndex] = newObj;
       }
     }
  }

  void loadFromJsonString(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! List) {
      throw const FormatException('Drawing JSON must be a list.');
    }
    _drawings
      ..clear()
      ..addAll(
        data.whereType<Map<String, dynamic>>().map(DrawingObject.fromJson),
      );
    _selectedDrawings.clear();
    _selectedDrawing = null;
    notifyListeners();
  }

  String toJsonString() {
    return jsonEncode(_drawings.map((d) => d.toJson()).toList());
  }

  Rect? _boundsForPoints(List<Offset> points) {
    if (points.isEmpty) return null;
    double minX = points.first.dx;
    double minY = points.first.dy;
    double maxX = points.first.dx;
    double maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  bool _hitTest(DrawingObject drawing, Offset point) {
    final bounds = _boundsForPoints(drawing.points);
    if (bounds == null) return false;

    final left = drawing.offset.dx + bounds.left * drawing.scale;
    final top = drawing.offset.dy + bounds.top * drawing.scale;
    final right = drawing.offset.dx + bounds.right * drawing.scale;
    final bottom = drawing.offset.dy + bounds.bottom * drawing.scale;
    final inflated = Rect.fromLTRB(left, top, right, bottom).inflate(6 + drawing.strokeWidth);
    return inflated.contains(point);
  }

  DrawingObject? get activeDrawing {
    if (_currentPoints.isEmpty || _currentTool == DrawingTool.none) return null;
    return DrawingObject(
      type: _currentTool,
      points: _currentPoints,
      color: _currentColor,
      strokeWidth: _currentStrokeWidth,
      isFilled: _isFilled,
      opacity: 1.0,
    );
  }
}

extension DrawingObjectCopy on DrawingObject {
  DrawingObject copyWith({
    DrawingTool? type,
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    bool? isFilled,
    Path? path,
    double? opacity,
    double? rotation,
    double? scale,
    Offset? offset,
  }) {
    return DrawingObject(
      type: type ?? this.type,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isFilled: isFilled ?? this.isFilled,
      path: path ?? this.path,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
    );
  }
}
