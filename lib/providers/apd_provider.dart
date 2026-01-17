import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math_64.dart' as v;

enum APDStep {
  inactive,
  sectionAItemId,
  confirmSectionAItemId,
  askSectionASegment,
  sectionASegment,
  sectionBItemId,
  confirmSectionBItemId,
  askSectionBSegment,
  sectionBSegment,
  chooseSectionCMethod,
  sectionCPinpoint,
  sectionCPinpointOperation,
  sectionCPegpoint,
  confirmSectionCPegpoint,
  sectionCDistanceMeters,
  sectionCDistanceMetersOperation,
  sectionCCalculate,
  sectionCFlag,
  sectionCGoTo,
}

class APDItem {
  final String id;
  final String title;
  final double x;
  final double y;
  
  APDItem({required this.id, required this.title, required this.x, required this.y});
}

class APDProvider with ChangeNotifier {
  bool _isActive = false;
  APDStep _currentStep = APDStep.inactive;
  
  // Data collected during the flow
  String? _sectionAId;
  double? _sectionASegment;
  String? _sectionBId;
  double? _sectionBSegment;
  
  double? _sectionCSegment;
  double? _sectionCPinpoint;
  double? _sectionCDistance;
  
  // Resolved Items (In a real app, these would be looked up from a central ItemService/Provider)
  APDItem? _sectionAItem;
  APDItem? _sectionBItem;
  APDItem? _sectionCItem;
  
  // For the sake of this standalone provider, we'll store resolved items here. 
  // In the full app, we need a way to 'resolve' ID to Item. 
  // We will assume the UI passes the item details when setting ID.

  bool get isActive => _isActive;
  APDStep get currentStep => _currentStep;
  APDItem? get sectionAItem => _sectionAItem;
  APDItem? get sectionBItem => _sectionBItem;
  APDItem? get sectionCItem => _sectionCItem;

  void activateAPD() {
    _isActive = true;
    _currentStep = APDStep.sectionAItemId;
    notifyListeners();
  }

  void deactivateAPD() {
    _isActive = false;
    _currentStep = APDStep.inactive;
    _resetData();
    notifyListeners();
  }
  
  void nextStep(APDStep next) {
    _currentStep = next;
    notifyListeners();
  }
  
  void setSectionA(APDItem item) {
    _sectionAId = item.id;
    _sectionAItem = item;
    notifyListeners();
  }
  
  void setSectionASegment(double seg) {
    _sectionASegment = seg;
    notifyListeners();
  }
  
  void setSectionB(APDItem item) {
    _sectionBId = item.id;
    _sectionBItem = item;
    notifyListeners();
  }
  
  void setSectionBSegment(double seg) {
    _sectionBSegment = seg;
    notifyListeners();
  }
  
  // Calculation Methods based on vectorg35.html
  
  // Method 1: Pinpoint/Pegpoint (Interpolation based on Chainage)
  // Logic: Calculate ratio of C's chainage between A and B, then interpolate position.
  void calculateSectionCFromChainage(double cSegment) {
    _sectionCSegment = cSegment;
    if (_sectionAItem != null && _sectionBItem != null && _sectionASegment != null && _sectionBSegment != null) {
       final segmentDiff = _sectionBSegment! - _sectionASegment!;
       if (segmentDiff == 0) return; // Avoid divide by zero
       
       final ratio = (cSegment - _sectionASegment!) / segmentDiff;
       
       // Linear interpolation
       final dx = _sectionBItem!.x - _sectionAItem!.x;
       final dy = _sectionBItem!.y - _sectionAItem!.y;
       
       final cx = _sectionAItem!.x + (dx * ratio);
       final cy = _sectionAItem!.y + (dy * ratio);
       
       _sectionCItem = APDItem(id: "SectionC", title: "Section C", x: cx, y: cy);
       notifyListeners();
    }
  }
  
  // Method 2: Distance (Vector Addition from A towards B)
  // Logic: Unit vector A->B * distance + A
  void calculateSectionCFromDistance(double distance) {
    _sectionCDistance = distance;
    if (_sectionAItem != null && _sectionBItem != null) {
      final dx = _sectionBItem!.x - _sectionAItem!.x;
      final dy = _sectionBItem!.y - _sectionAItem!.y;
      final length = sqrt(dx * dx + dy * dy);
      
      if (length == 0) return;
      
      final unitX = dx / length;
      final unitY = dy / length;
      
      final cx = _sectionAItem!.x + (unitX * distance);
      final cy = _sectionAItem!.y + (unitY * distance);
      
      _sectionCItem = APDItem(id: "SectionC", title: "Section C", x: cx, y: cy);
      notifyListeners();
    }
  }

  void _resetData() {
    _sectionAId = null;
    _sectionASegment = null;
    _sectionBId = null;
    _sectionBSegment = null;
    _sectionCSegment = null;
    _sectionCDistance = null;
    _sectionAItem = null;
    _sectionBItem = null;
    _sectionCItem = null;
  }
}

