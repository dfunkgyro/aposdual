import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ui_theme.dart';

class AppState with ChangeNotifier {
  static const String _splitRatioKey = 'ui_main_split_ratio_v1';
  static const String _themePresetKey = 'ui_theme_preset_v1';
  static const String _mainFocusOffsetKey = 'ui_main_focus_offset_v1';
  static const String _mimicFocusOffsetKey = 'ui_mimic_focus_offset_v1';
  static const String _mainFocusAdjustKey = 'ui_main_focus_adjust_v2';
  static const String _mimicFocusAdjustKey = 'ui_mimic_focus_adjust_v2';
  static const String _linkZoomKey = 'ui_link_zoom_v1';
  static const String _themeModeKey = 'ui_theme_mode_v1';
  static const String _sidebarCollapsedKey = 'ui_sidebar_collapsed_v1';
  static const String _leftSidebarCollapsedKey = 'ui_left_sidebar_collapsed_v1';
  static const String _timelineVisibleKey = 'ui_timeline_visible_v1';
  static const String _mimicCollapsedKey = 'ui_mimic_collapsed_v1';
  static const String _maxZoomKey = 'ui_max_zoom_v1';
  static const String _mainZoomKey = 'ui_main_zoom_v1';
  static const String _mimicZoomKey = 'ui_mimic_zoom_v1';
  static const String _mainBgKey = 'ui_main_bg_v1';
  static const String _mimicBgKey = 'ui_mimic_bg_v1';
  static const String _focusLockedKey = 'ui_focus_locked_v1';
  static const String _keyboardPanKey = 'ui_keyboard_pan_v1';
  static const String _showCursorKey = 'ui_show_cursor_v1';
  static const String _mimicSyncedKey = 'ui_mimic_synced_v1';
  static const String _tooltipsEnabledKey = 'ui_tooltips_enabled_v1';
  static const String _tooltipHoverKey = 'ui_tooltip_hover_v1';
  static const String _tooltipSelectedKey = 'ui_tooltip_selected_v1';
  static const String _tooltipLabelKey = 'ui_tooltip_label_v1';
  static const String _tooltipOpacityKey = 'ui_tooltip_opacity_v1';
  static const String _tooltipScaleKey = 'ui_tooltip_scale_v1';
  static const String _tooltipRadiusKey = 'ui_tooltip_radius_v1';
  static const String _tooltipBgKey = 'ui_tooltip_bg_v1';
  static const String _tooltipTextKey = 'ui_tooltip_text_v1';
  static const String _tooltipAutoTextKey = 'ui_tooltip_auto_text_v1';
  static const String _textScaleKey = 'ui_text_scale_v1';
  static const String _highContrastKey = 'ui_high_contrast_v1';
  static const String _reduceMotionKey = 'ui_reduce_motion_v1';
  ThemeMode _themeMode = ThemeMode.light;
  bool _isMimicCollapsed = false;
  bool _isTimelineVisible = false; // Fixed: was unused/implicit
  bool _isSidebarCollapsed = false;
  bool _isLeftSidebarCollapsed = false;
  double _mainSplitRatio = 0.5;
  ThemePreset _themePreset = ThemePreset.glassIce;
  static const Offset _baseMainFocusOffset = Offset(-0.5, -0.15);
  static const Offset _baseMimicFocusOffset = Offset(-0.5, -0.15);
  Offset _mainFocusAdjust = Offset.zero;
  Offset _mimicFocusAdjust = Offset.zero;
  bool _linkZoom = false;
  bool _tooltipsEnabled = true;
  bool _tooltipHover = true;
  bool _tooltipSelected = true;
  bool _tooltipShowLabel = true;
  double _tooltipOpacity = 0.5;
  double _tooltipScale = 1.0;
  double _tooltipHitRadius = 14.0;
  Color _tooltipBackgroundColor = const Color(0xFFF4E8D0);
  Color _tooltipTextColor = Colors.black;
  bool _tooltipAutoText = true;
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;
  final List<String> _errorLog = [];
  Offset? _focusTarget;
  bool _focusLocked = true;
  double _mainZoom = 1.0;
  double _mimicZoom = 1.0;
  double _maxZoom = 5.0;
  Color _mainBackgroundColor = Colors.white;
  Color _mimicBackgroundColor = Colors.white;
  String? _mainSvgContent;
  String? _mimicSvgContent;
  Offset _mainViewOffset = Offset.zero;
  Offset _mimicViewOffset = Offset.zero;
  bool _isMimicSynced = true;
  Offset? _pendingMainFocus;
  Offset? _pendingMimicFocus;
  Size? _mainSvgSize;
  Size? _mimicSvgSize;
  bool _keyboardPanEnabled = false;
  Offset? _cursorPosition;
  bool _showCursorPosition = false;
  
  List<String> _platformFiles = [];
  List<String> _telemetryFiles = [];

  ThemeMode get themeMode => _themeMode;
  bool get isMimicCollapsed => _isMimicCollapsed;
  bool get isTimelineVisible => _isTimelineVisible;
  bool get isSidebarCollapsed => _isSidebarCollapsed;
  bool get isLeftSidebarCollapsed => _isLeftSidebarCollapsed;
  double get mainSplitRatio => _mainSplitRatio;
  ThemePreset get themePreset => _themePreset;
  Offset get mainFocusOffset => _baseMainFocusOffset + _mainFocusAdjust;
  Offset get mimicFocusOffset => _baseMimicFocusOffset + _mimicFocusAdjust;
  Offset get mainFocusAdjust => _mainFocusAdjust;
  Offset get mimicFocusAdjust => _mimicFocusAdjust;
  Offset get mainFocusBaseOffset => _baseMainFocusOffset;
  Offset get mimicFocusBaseOffset => _baseMimicFocusOffset;
  bool get linkZoom => _linkZoom;
  bool get tooltipsEnabled => _tooltipsEnabled;
  bool get tooltipHoverEnabled => _tooltipHover;
  bool get tooltipSelectedEnabled => _tooltipSelected;
  bool get tooltipShowLabel => _tooltipShowLabel;
  double get tooltipOpacity => _tooltipOpacity;
  double get tooltipScale => _tooltipScale;
  double get tooltipHitRadius => _tooltipHitRadius;
  Color get tooltipBackgroundColor => _tooltipBackgroundColor;
  Color get tooltipTextColor => _tooltipTextColor;
  bool get tooltipAutoText => _tooltipAutoText;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  List<String> get errorLog => List.unmodifiable(_errorLog);
  Offset? get focusTarget => _focusTarget;
  bool get focusLocked => _focusLocked;
  double get mainZoom => _mainZoom;
  double get mimicZoom => _mimicZoom;
  double get maxZoom => _maxZoom;
  Color get mainBackgroundColor => _mainBackgroundColor;
  Color get mimicBackgroundColor => _mimicBackgroundColor;
  String? get mainSvgContent => _mainSvgContent;
  String? get mimicSvgContent => _mimicSvgContent;
  Offset get mainViewOffset => _mainViewOffset;
  Offset get mimicViewOffset => _mimicViewOffset;
  bool get isMimicSynced => _isMimicSynced;
  Size? get mainSvgSize => _mainSvgSize;
  Size? get mimicSvgSize => _mimicSvgSize;
  bool get keyboardPanEnabled => _keyboardPanEnabled;
  Offset? get cursorPosition => _cursorPosition;
  bool get showCursorPosition => _showCursorPosition;
  List<String> get platformFiles => _platformFiles;
  List<String> get telemetryFiles => _telemetryFiles;
  
  Future<void> loadAssetLists() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest.listAssets();

    _platformFiles = keys
        .where((key) => key.startsWith('assets/platform/') && key.endsWith('.svg') && !key.contains('/._'))
        .toList();
        
    _telemetryFiles = keys
        .where((key) => key.startsWith('assets/telemetry/') && key.endsWith('.json') && !key.contains('/._'))
        .toList();
        
    notifyListeners();
  }

  AppState() {
    _loadAssetLists();
  }

  // Helper to init from context
  BuildContext? _appContext;
  void init(BuildContext context) {
    _appContext = context;
    _scanAssets(context);
    _loadUiPrefs();
  }

  Future<void> _loadUiPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final ratio = prefs.getDouble(_splitRatioKey);
    if (ratio != null) {
      _mainSplitRatio = ratio.clamp(0.1, 0.9);
    }
    final themeMode = prefs.getString(_themeModeKey);
    if (themeMode == ThemeMode.dark.name) {
      _themeMode = ThemeMode.dark;
    } else if (themeMode == ThemeMode.light.name) {
      _themeMode = ThemeMode.light;
    }
    final themeId = prefs.getString(_themePresetKey);
    if (themeId != null) {
      _themePreset = _themePresetFromId(themeId);
    }
    final mainAdjust = prefs.getString(_mainFocusAdjustKey);
    if (mainAdjust != null) {
      _mainFocusAdjust = _parseAdjust(mainAdjust);
    } else {
      final legacyMain = prefs.getString(_mainFocusOffsetKey);
      if (legacyMain != null) {
        _mainFocusAdjust = _parseOffset(legacyMain) - _baseMainFocusOffset;
      }
    }
    final mimicAdjust = prefs.getString(_mimicFocusAdjustKey);
    if (mimicAdjust != null) {
      _mimicFocusAdjust = _parseAdjust(mimicAdjust);
    } else {
      final legacyMimic = prefs.getString(_mimicFocusOffsetKey);
      if (legacyMimic != null) {
        _mimicFocusAdjust = _parseOffset(legacyMimic) - _baseMimicFocusOffset;
      }
    }
    _linkZoom = prefs.getBool(_linkZoomKey) ?? _linkZoom;
    _isSidebarCollapsed = prefs.getBool(_sidebarCollapsedKey) ?? _isSidebarCollapsed;
    _isLeftSidebarCollapsed = prefs.getBool(_leftSidebarCollapsedKey) ?? _isLeftSidebarCollapsed;
    _isTimelineVisible = prefs.getBool(_timelineVisibleKey) ?? _isTimelineVisible;
    _isMimicCollapsed = prefs.getBool(_mimicCollapsedKey) ?? _isMimicCollapsed;
    _maxZoom = (prefs.getDouble(_maxZoomKey) ?? _maxZoom).clamp(1.0, 10.0);
    _mainZoom = (prefs.getDouble(_mainZoomKey) ?? _mainZoom).clamp(0.1, _maxZoom);
    _mimicZoom = (prefs.getDouble(_mimicZoomKey) ?? _mimicZoom).clamp(0.1, _maxZoom);
    _mainBackgroundColor = Color(prefs.getInt(_mainBgKey) ?? _mainBackgroundColor.value);
    _mimicBackgroundColor = Color(prefs.getInt(_mimicBgKey) ?? _mimicBackgroundColor.value);
    _focusLocked = prefs.getBool(_focusLockedKey) ?? _focusLocked;
    _keyboardPanEnabled = prefs.getBool(_keyboardPanKey) ?? _keyboardPanEnabled;
    _showCursorPosition = prefs.getBool(_showCursorKey) ?? _showCursorPosition;
    _isMimicSynced = prefs.getBool(_mimicSyncedKey) ?? _isMimicSynced;
    _tooltipsEnabled = prefs.getBool(_tooltipsEnabledKey) ?? _tooltipsEnabled;
    _tooltipHover = prefs.getBool(_tooltipHoverKey) ?? _tooltipHover;
    _tooltipSelected = prefs.getBool(_tooltipSelectedKey) ?? _tooltipSelected;
    _tooltipShowLabel = prefs.getBool(_tooltipLabelKey) ?? _tooltipShowLabel;
    _tooltipOpacity = (prefs.getDouble(_tooltipOpacityKey) ?? _tooltipOpacity).clamp(0.1, 1.0);
    _tooltipScale = (prefs.getDouble(_tooltipScaleKey) ?? _tooltipScale).clamp(0.6, 2.0);
    _tooltipHitRadius = (prefs.getDouble(_tooltipRadiusKey) ?? _tooltipHitRadius).clamp(6.0, 60.0);
    _tooltipBackgroundColor = Color(prefs.getInt(_tooltipBgKey) ?? _tooltipBackgroundColor.value);
    _tooltipTextColor = Color(prefs.getInt(_tooltipTextKey) ?? _tooltipTextColor.value);
    _tooltipAutoText = prefs.getBool(_tooltipAutoTextKey) ?? _tooltipAutoText;
    _textScale = (prefs.getDouble(_textScaleKey) ?? _textScale).clamp(0.8, 1.4);
    _highContrast = prefs.getBool(_highContrastKey) ?? _highContrast;
    _reduceMotion = prefs.getBool(_reduceMotionKey) ?? _reduceMotion;
    notifyListeners();
  }

  Future<void> _persistSplitRatio() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_splitRatioKey, _mainSplitRatio);
  }

  Future<void> _persistThemePreset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePresetKey, _themePreset.name);
  }

  Future<void> _persistFocusOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mainFocusAdjustKey, _serializeOffset(_mainFocusAdjust));
    await prefs.setString(_mimicFocusAdjustKey, _serializeOffset(_mimicFocusAdjust));
  }

  Future<void> _persistLinkZoom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_linkZoomKey, _linkZoom);
  }

  Future<void> _persistThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeMode.name);
  }

  Future<void> _persistBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _persistDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _persistInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _loadAssetLists() async {
    // Initial load logic if needed
  }

  Future<void> _scanAssets(BuildContext context) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context));
      final keys = manifest.listAssets();

      _platformFiles = keys
          .where((key) => key.startsWith('assets/platform/') && key.toLowerCase().endsWith('.svg'))
          .toList();
          
      _telemetryFiles = keys
          .where((key) => key.startsWith('assets/telemetry/') && key.toLowerCase().endsWith('.json'))
          .toList();
          
      notifyListeners();
    } catch (e) {
      debugPrint("Error scanning assets: $e");
    }
  }

  void setPlatformFiles(List<String> files) {
    _platformFiles = files;
    notifyListeners();
  }
  
  void setTelemetryFiles(List<String> files) {
    _telemetryFiles = files;
    notifyListeners();
  }

  void toggleMimicCollapse() {
    _isMimicCollapsed = !_isMimicCollapsed;
    notifyListeners();
    _persistBool(_mimicCollapsedKey, _isMimicCollapsed);
  }

  void setMainZoom(double zoom) {
    final clamped = zoom.clamp(0.1, _maxZoom);
    if (_linkZoom) {
      _mainZoom = clamped;
      _mimicZoom = clamped;
    } else {
      _mainZoom = clamped;
    }
    notifyListeners();
    _persistDouble(_mainZoomKey, _mainZoom);
    if (_linkZoom) {
      _persistDouble(_mimicZoomKey, _mimicZoom);
    }
  }

  void setMimicZoom(double zoom) {
    final clamped = zoom.clamp(0.1, _maxZoom);
    if (_linkZoom) {
      _mainZoom = clamped;
      _mimicZoom = clamped;
    } else {
      _mimicZoom = clamped;
    }
    notifyListeners();
    _persistDouble(_mimicZoomKey, _mimicZoom);
    if (_linkZoom) {
      _persistDouble(_mainZoomKey, _mainZoom);
    }
  }

  void setMainViewOffset(Offset offset) {
    _mainViewOffset = offset;
    if (_isMimicSynced) {
      _mimicViewOffset = offset;
    }
    notifyListeners();
  }

  void setMimicViewOffset(Offset offset) {
    _mimicViewOffset = offset;
    if (_isMimicSynced) {
      _mainViewOffset = offset;
    }
    notifyListeners();
  }

  void panMain(Offset delta) {
    setMainViewOffset(_mainViewOffset + delta);
  }

  void panMimic(Offset delta) {
    setMimicViewOffset(_mimicViewOffset + delta);
  }

  void setMimicSynced(bool synced) {
    _isMimicSynced = synced;
    if (_isMimicSynced) {
      _mimicViewOffset = _mainViewOffset;
    }
    notifyListeners();
    _persistBool(_mimicSyncedKey, _isMimicSynced);
  }

  void setMainBackgroundColor(Color color) {
    _mainBackgroundColor = color;
    notifyListeners();
    _persistInt(_mainBgKey, color.value);
  }

  void setMimicBackgroundColor(Color color) {
    _mimicBackgroundColor = color;
    notifyListeners();
    _persistInt(_mimicBgKey, color.value);
  }

  void setMainSvgContent(String content) {
    _mainSvgContent = content;
    _mainSvgSize = _parseSvgSize(content);
    notifyListeners();
  }

  void setMimicSvgContent(String content) {
    _mimicSvgContent = content;
    _mimicSvgSize = _parseSvgSize(content);
    notifyListeners();
  }

  void requestFocus(Offset normalized, {bool includeMimic = true}) {
    _pendingMainFocus = normalized;
    if (includeMimic) {
      _pendingMimicFocus = normalized;
    }
    notifyListeners();
  }

  Offset? consumeFocus({required bool isMimic}) {
    if (isMimic) {
      final focus = _pendingMimicFocus;
      _pendingMimicFocus = null;
      return focus;
    }
    final focus = _pendingMainFocus;
    _pendingMainFocus = null;
    return focus;
  }

  void setMaxZoom(double zoom) {
    _maxZoom = zoom.clamp(1.0, 10.0);
    _mainZoom = _mainZoom.clamp(0.1, _maxZoom);
    _mimicZoom = _mimicZoom.clamp(0.1, _maxZoom);
    notifyListeners();
    _persistDouble(_maxZoomKey, _maxZoom);
    _persistDouble(_mainZoomKey, _mainZoom);
    _persistDouble(_mimicZoomKey, _mimicZoom);
  }

  void setMainSplitRatio(double ratio) {
    _mainSplitRatio = ratio.clamp(0.1, 0.9);
    notifyListeners();
    _persistSplitRatio();
  }

  void resetMainSplitRatio() {
    _mainSplitRatio = 0.5;
    notifyListeners();
    _persistSplitRatio();
  }

  void setThemePreset(ThemePreset preset) {
    _themePreset = preset;
    notifyListeners();
    _persistThemePreset();
  }

  void resetUiTheme() {
    _themePreset = ThemePreset.glassIce;
    notifyListeners();
    _persistThemePreset();
  }

  void setFocusTarget(Offset? target, {bool lock = true}) {
    _focusTarget = target;
    if (lock) {
      _focusLocked = true;
    }
    notifyListeners();
    if (lock) {
      _persistBool(_focusLockedKey, _focusLocked);
    }
  }

  void setFocusLocked(bool locked) {
    _focusLocked = locked;
    notifyListeners();
    _persistBool(_focusLockedKey, _focusLocked);
  }

  void setKeyboardPanEnabled(bool enabled) {
    _keyboardPanEnabled = enabled;
    notifyListeners();
    _persistBool(_keyboardPanKey, _keyboardPanEnabled);
  }

  void updateCursorPosition(Offset? svgCoords) {
    if (!_showCursorPosition) return;
    _cursorPosition = svgCoords;
    notifyListeners();
  }

  void setShowCursorPosition(bool show) {
    _showCursorPosition = show;
    if (!show) {
      _cursorPosition = null;
    }
    notifyListeners();
    _persistBool(_showCursorKey, _showCursorPosition);
  }

  void resetMainView() {
    _mainZoom = 1.0;
    _mainViewOffset = Offset.zero;
    if (_linkZoom) {
      _mimicZoom = 1.0;
      _mimicViewOffset = Offset.zero;
    }
    notifyListeners();
    _persistDouble(_mainZoomKey, _mainZoom);
    _persistDouble(_mimicZoomKey, _mimicZoom);
  }

  void resetMimicView() {
    _mimicZoom = 1.0;
    _mimicViewOffset = Offset.zero;
    if (_linkZoom) {
      _mainZoom = 1.0;
      _mainViewOffset = Offset.zero;
    }
    notifyListeners();
    _persistDouble(_mainZoomKey, _mainZoom);
    _persistDouble(_mimicZoomKey, _mimicZoom);
  }

  void resetAll() {
    _mainSvgContent = null;
    _mimicSvgContent = null;
    _mainSvgSize = null;
    _mimicSvgSize = null;
    _mainZoom = 1.0;
    _mimicZoom = 1.0;
    _mainViewOffset = Offset.zero;
    _mimicViewOffset = Offset.zero;
    _isMimicSynced = true;
    _cursorPosition = null;
    _showCursorPosition = false;
    _focusTarget = null;
    _focusLocked = true;
    _mainFocusAdjust = Offset.zero;
    _mimicFocusAdjust = Offset.zero;
    _linkZoom = false;
    notifyListeners();
    persistAllSettings();
  }

  Size? _parseSvgSize(String svg) {
    final svgTagMatch = RegExp(r'<svg[^>]*>', caseSensitive: false).firstMatch(svg);
    if (svgTagMatch == null) return _parseViewBox(svg);
    final svgTag = svgTagMatch.group(0) ?? '';

    final viewBox = _parseViewBox(svgTag) ?? _parseViewBox(svg);
    if (viewBox != null) return viewBox;

    final width = _parseAttribute(svgTag, 'width');
    final height = _parseAttribute(svgTag, 'height');
    if (width != null && height != null && width > 0 && height > 0) {
      return Size(width, height);
    }
    return null;
  }

  Size? _parseViewBox(String svgSource) {
    final raw = _parseAttributeRaw(svgSource, 'viewBox');
    if (raw == null) return null;
    final parts = raw.trim().split(RegExp(r'[,\s]+'));
    if (parts.length < 4) return null;
    final width = double.tryParse(parts[2]) ?? 0;
    final height = double.tryParse(parts[3]) ?? 0;
    if (width <= 0 || height <= 0) return null;
    return Size(width, height);
  }

  double? _parseAttribute(String svgSource, String name) {
    final raw = _parseAttributeRaw(svgSource, name);
    return _parseSvgNumber(raw);
  }

  String? _parseAttributeRaw(String svgSource, String name) {
    final doubleQuoted = RegExp('$name\\s*=\\s*\"([^\"]+)\"', caseSensitive: false).firstMatch(svgSource);
    if (doubleQuoted != null) return doubleQuoted.group(1);
    final singleQuoted = RegExp("$name\\s*=\\s*'([^']+)'", caseSensitive: false).firstMatch(svgSource);
    return singleQuoted?.group(1);
  }

  double? _parseSvgNumber(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.endsWith('%')) return null;
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9\\.]+'), '');
    return double.tryParse(cleaned);
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _persistThemeMode();
  }

  void toggleTimeline() {
    _isTimelineVisible = !_isTimelineVisible;
    notifyListeners();
    _persistBool(_timelineVisibleKey, _isTimelineVisible);
  }

  void toggleSidebarCollapsed() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
    _persistBool(_sidebarCollapsedKey, _isSidebarCollapsed);
  }

  void setSidebarCollapsed(bool collapsed) {
    _isSidebarCollapsed = collapsed;
    notifyListeners();
    _persistBool(_sidebarCollapsedKey, _isSidebarCollapsed);
  }

  void toggleLeftSidebarCollapsed() {
    _isLeftSidebarCollapsed = !_isLeftSidebarCollapsed;
    notifyListeners();
    _persistBool(_leftSidebarCollapsedKey, _isLeftSidebarCollapsed);
  }

  void setLeftSidebarCollapsed(bool collapsed) {
    _isLeftSidebarCollapsed = collapsed;
    notifyListeners();
    _persistBool(_leftSidebarCollapsedKey, _isLeftSidebarCollapsed);
  }

  void setMainFocusOffset(Offset offset) {
    _mainFocusAdjust = _clampFocusAdjust(offset);
    notifyListeners();
    _persistFocusOffsets();
  }

  void setMimicFocusOffset(Offset offset) {
    _mimicFocusAdjust = _clampFocusAdjust(offset);
    notifyListeners();
    _persistFocusOffsets();
  }

  void resetFocusOffsets() {
    _mainFocusAdjust = Offset.zero;
    _mimicFocusAdjust = Offset.zero;
    notifyListeners();
    _persistFocusOffsets();
  }

  void setLinkZoom(bool enabled) {
    _linkZoom = enabled;
    if (_linkZoom) {
      _mimicZoom = _mainZoom;
      _mimicViewOffset = _mainViewOffset;
    }
    notifyListeners();
    _persistLinkZoom();
    _persistDouble(_mimicZoomKey, _mimicZoom);
    _persistDouble(_mainZoomKey, _mainZoom);
  }

  void setTooltipsEnabled(bool enabled) {
    _tooltipsEnabled = enabled;
    notifyListeners();
    _persistBool(_tooltipsEnabledKey, _tooltipsEnabled);
  }

  void setTooltipHoverEnabled(bool enabled) {
    _tooltipHover = enabled;
    notifyListeners();
    _persistBool(_tooltipHoverKey, _tooltipHover);
  }

  void setTooltipSelectedEnabled(bool enabled) {
    _tooltipSelected = enabled;
    notifyListeners();
    _persistBool(_tooltipSelectedKey, _tooltipSelected);
  }

  void setTooltipShowLabel(bool enabled) {
    _tooltipShowLabel = enabled;
    notifyListeners();
    _persistBool(_tooltipLabelKey, _tooltipShowLabel);
  }

  void setTooltipOpacity(double value) {
    _tooltipOpacity = value.clamp(0.1, 1.0);
    notifyListeners();
    _persistDouble(_tooltipOpacityKey, _tooltipOpacity);
  }

  void setTooltipScale(double value) {
    _tooltipScale = value.clamp(0.6, 2.0);
    notifyListeners();
    _persistDouble(_tooltipScaleKey, _tooltipScale);
  }

  void setTooltipHitRadius(double value) {
    _tooltipHitRadius = value.clamp(6.0, 60.0);
    notifyListeners();
    _persistDouble(_tooltipRadiusKey, _tooltipHitRadius);
  }

  void setTooltipBackgroundColor(Color color) {
    _tooltipBackgroundColor = color;
    notifyListeners();
    _persistInt(_tooltipBgKey, _tooltipBackgroundColor.value);
  }

  void setTooltipTextColor(Color color) {
    _tooltipTextColor = color;
    notifyListeners();
    _persistInt(_tooltipTextKey, _tooltipTextColor.value);
  }

  void setTooltipAutoText(bool enabled) {
    _tooltipAutoText = enabled;
    notifyListeners();
    _persistBool(_tooltipAutoTextKey, _tooltipAutoText);
  }

  void setTextScale(double value) {
    _textScale = value.clamp(0.8, 1.4);
    notifyListeners();
    _persistDouble(_textScaleKey, _textScale);
  }

  void setHighContrast(bool enabled) {
    _highContrast = enabled;
    notifyListeners();
    _persistBool(_highContrastKey, _highContrast);
  }

  void setReduceMotion(bool enabled) {
    _reduceMotion = enabled;
    notifyListeners();
    _persistBool(_reduceMotionKey, _reduceMotion);
  }

  void reportError(String message) {
    final timestamp = DateTime.now().toIso8601String();
    _errorLog.insert(0, '[$timestamp] $message');
    if (_errorLog.length > 50) {
      _errorLog.removeRange(50, _errorLog.length);
    }
    notifyListeners();
  }

  void clearErrors() {
    _errorLog.clear();
    notifyListeners();
  }

  Map<String, dynamic> toSettingsJson() {
    return {
      'version': 1,
      'themeMode': _themeMode.name,
      'themePreset': _themePreset.name,
      'mainSplitRatio': _mainSplitRatio,
      'mainZoom': _mainZoom,
      'mimicZoom': _mimicZoom,
      'maxZoom': _maxZoom,
      'mainBackgroundColor': _mainBackgroundColor.value,
      'mimicBackgroundColor': _mimicBackgroundColor.value,
      'isMimicCollapsed': _isMimicCollapsed,
      'isTimelineVisible': _isTimelineVisible,
      'isSidebarCollapsed': _isSidebarCollapsed,
      'isLeftSidebarCollapsed': _isLeftSidebarCollapsed,
      'focusLocked': _focusLocked,
      'keyboardPanEnabled': _keyboardPanEnabled,
      'showCursorPosition': _showCursorPosition,
      'isMimicSynced': _isMimicSynced,
      'mainFocusAdjust': _serializeOffset(_mainFocusAdjust),
      'mimicFocusAdjust': _serializeOffset(_mimicFocusAdjust),
      'mainFocusOffset': _serializeOffset(mainFocusOffset),
      'mimicFocusOffset': _serializeOffset(mimicFocusOffset),
      'linkZoom': _linkZoom,
      'tooltipsEnabled': _tooltipsEnabled,
      'tooltipHover': _tooltipHover,
      'tooltipSelected': _tooltipSelected,
      'tooltipShowLabel': _tooltipShowLabel,
      'tooltipOpacity': _tooltipOpacity,
      'tooltipScale': _tooltipScale,
      'tooltipHitRadius': _tooltipHitRadius,
      'tooltipBackgroundColor': _tooltipBackgroundColor.value,
      'tooltipTextColor': _tooltipTextColor.value,
      'tooltipAutoText': _tooltipAutoText,
      'textScale': _textScale,
      'highContrast': _highContrast,
      'reduceMotion': _reduceMotion,
    };
  }

  void applySettingsJson(Map<String, dynamic> data) {
    _themeMode = data['themeMode'] == ThemeMode.dark.name ? ThemeMode.dark : ThemeMode.light;
    _themePreset = _themePresetFromId(data['themePreset']?.toString() ?? _themePreset.name);
    _mainSplitRatio = _parseDouble(data['mainSplitRatio'], _mainSplitRatio).clamp(0.1, 0.9);
    _maxZoom = _parseDouble(data['maxZoom'], _maxZoom).clamp(1.0, 10.0);
    _mainZoom = _parseDouble(data['mainZoom'], _mainZoom).clamp(0.1, _maxZoom);
    _mimicZoom = _parseDouble(data['mimicZoom'], _mimicZoom).clamp(0.1, _maxZoom);
    _mainBackgroundColor = Color(_parseInt(data['mainBackgroundColor'], _mainBackgroundColor.value));
    _mimicBackgroundColor = Color(_parseInt(data['mimicBackgroundColor'], _mimicBackgroundColor.value));
    _isMimicCollapsed = _parseBool(data['isMimicCollapsed'], _isMimicCollapsed);
    _isTimelineVisible = _parseBool(data['isTimelineVisible'], _isTimelineVisible);
    _isSidebarCollapsed = _parseBool(data['isSidebarCollapsed'], _isSidebarCollapsed);
    _isLeftSidebarCollapsed = _parseBool(data['isLeftSidebarCollapsed'], _isLeftSidebarCollapsed);
    _focusLocked = _parseBool(data['focusLocked'], _focusLocked);
    _keyboardPanEnabled = _parseBool(data['keyboardPanEnabled'], _keyboardPanEnabled);
    _showCursorPosition = _parseBool(data['showCursorPosition'], _showCursorPosition);
    _isMimicSynced = _parseBool(data['isMimicSynced'], _isMimicSynced);
    if (data['mainFocusAdjust'] != null) {
      _mainFocusAdjust = _parseAdjust(data['mainFocusAdjust']?.toString() ?? '0,0');
    } else {
      final legacyMain = data['mainFocusOffset']?.toString();
      if (legacyMain != null) {
        _mainFocusAdjust = _parseOffset(legacyMain) - _baseMainFocusOffset;
      }
    }
    if (data['mimicFocusAdjust'] != null) {
      _mimicFocusAdjust = _parseAdjust(data['mimicFocusAdjust']?.toString() ?? '0,0');
    } else {
      final legacyMimic = data['mimicFocusOffset']?.toString();
      if (legacyMimic != null) {
        _mimicFocusAdjust = _parseOffset(legacyMimic) - _baseMimicFocusOffset;
      }
    }
    _linkZoom = _parseBool(data['linkZoom'], _linkZoom);
    _tooltipsEnabled = _parseBool(data['tooltipsEnabled'], _tooltipsEnabled);
    _tooltipHover = _parseBool(data['tooltipHover'], _tooltipHover);
    _tooltipSelected = _parseBool(data['tooltipSelected'], _tooltipSelected);
    _tooltipShowLabel = _parseBool(data['tooltipShowLabel'], _tooltipShowLabel);
    _tooltipOpacity = _parseDouble(data['tooltipOpacity'], _tooltipOpacity).clamp(0.1, 1.0);
    _tooltipScale = _parseDouble(data['tooltipScale'], _tooltipScale).clamp(0.6, 2.0);
    _tooltipHitRadius = _parseDouble(data['tooltipHitRadius'], _tooltipHitRadius).clamp(6.0, 60.0);
    _tooltipBackgroundColor = Color(_parseInt(data['tooltipBackgroundColor'], _tooltipBackgroundColor.value));
    _tooltipTextColor = Color(_parseInt(data['tooltipTextColor'], _tooltipTextColor.value));
    _tooltipAutoText = _parseBool(data['tooltipAutoText'], _tooltipAutoText);
    _textScale = _parseDouble(data['textScale'], _textScale).clamp(0.8, 1.4);
    _highContrast = _parseBool(data['highContrast'], _highContrast);
    _reduceMotion = _parseBool(data['reduceMotion'], _reduceMotion);
    notifyListeners();
    persistAllSettings();
  }

  Future<void> persistAllSettings() async {
    await _persistThemeMode();
    await _persistSplitRatio();
    await _persistThemePreset();
    await _persistFocusOffsets();
    await _persistLinkZoom();
    await _persistBool(_sidebarCollapsedKey, _isSidebarCollapsed);
    await _persistBool(_leftSidebarCollapsedKey, _isLeftSidebarCollapsed);
    await _persistBool(_timelineVisibleKey, _isTimelineVisible);
    await _persistBool(_mimicCollapsedKey, _isMimicCollapsed);
    await _persistDouble(_maxZoomKey, _maxZoom);
    await _persistDouble(_mainZoomKey, _mainZoom);
    await _persistDouble(_mimicZoomKey, _mimicZoom);
    await _persistInt(_mainBgKey, _mainBackgroundColor.value);
    await _persistInt(_mimicBgKey, _mimicBackgroundColor.value);
    await _persistBool(_focusLockedKey, _focusLocked);
    await _persistBool(_keyboardPanKey, _keyboardPanEnabled);
    await _persistBool(_showCursorKey, _showCursorPosition);
    await _persistBool(_mimicSyncedKey, _isMimicSynced);
    await _persistBool(_tooltipsEnabledKey, _tooltipsEnabled);
    await _persistBool(_tooltipHoverKey, _tooltipHover);
    await _persistBool(_tooltipSelectedKey, _tooltipSelected);
    await _persistBool(_tooltipLabelKey, _tooltipShowLabel);
    await _persistDouble(_tooltipOpacityKey, _tooltipOpacity);
    await _persistDouble(_tooltipScaleKey, _tooltipScale);
    await _persistDouble(_tooltipRadiusKey, _tooltipHitRadius);
    await _persistInt(_tooltipBgKey, _tooltipBackgroundColor.value);
    await _persistInt(_tooltipTextKey, _tooltipTextColor.value);
    await _persistBool(_tooltipAutoTextKey, _tooltipAutoText);
    await _persistDouble(_textScaleKey, _textScale);
    await _persistBool(_highContrastKey, _highContrast);
    await _persistBool(_reduceMotionKey, _reduceMotion);
  }

  ThemePreset _themePresetFromId(String id) {
    for (final preset in ThemePreset.values) {
      if (preset.name == id) return preset;
    }
    return ThemePreset.glassIce;
  }

  Offset _parseOffset(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) return Offset.zero;
    final dx = double.tryParse(parts[0]) ?? 0.0;
    final dy = double.tryParse(parts[1]) ?? 0.0;
    return Offset(dx, dy);
  }

  String _serializeOffset(Offset offset) {
    return '${offset.dx},${offset.dy}';
  }

  Offset _parseAdjust(String raw) {
    final parsed = _parseOffset(raw);
    return _clampFocusAdjust(parsed);
  }

  Offset _clampFocusAdjust(Offset offset) {
    final dx = offset.dx.clamp(-0.45, 0.45);
    final dy = offset.dy.clamp(-0.45, 0.45);
    return Offset(dx, dy);
  }

  double _parseDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _parseBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return fallback;
  }
}
