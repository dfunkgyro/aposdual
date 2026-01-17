import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/alarm_provider.dart';
import '../providers/app_state.dart';
import '../providers/apd_provider.dart';
import '../providers/chatbot_provider.dart';
import '../providers/drawing_provider.dart';
import '../providers/history_provider.dart';
import '../providers/media_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/telemetry_provider.dart';
import '../providers/text_provider.dart';
import '../providers/link_provider.dart';
import '../providers/supabase_provider.dart';
import '../providers/openai_provider.dart';
import '../providers/item_links_provider.dart';
import '../providers/view_preset_provider.dart';
import 'controls/search_control.dart';
import 'controls/sector_control.dart';
import 'controls/subsystems_control.dart';
import 'glass_panel.dart';
import '../models/ui_theme.dart';
import '../models/diagnostic_issue.dart';
import '../models/telemetry_item.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  static const String _sectionOrderKey = 'sidebar_section_order_v1';
  static const List<String> _defaultSectionOrder = [
    'chatbot',
    'search',
    'subsystems',
    'navigation',
    'layout_theme',
    'assets',
    'selected_item',
    'batch_actions',
    'marker_settings',
    'tooltips',
    'telemetry_insights',
    'filter_presets',
    'view_presets',
    'recent_items',
    'diagnostics',
    'snapshot_history',
    'accessibility',
    'supabase',
    'openai',
    'system_status',
    'background_colors',
    'alarms',
    'data_fetch',
    'notes',
    'media',
    'history',
    'project',
    'sector',
  ];

  late List<String> _sectionOrder;
  String? _selectedMainSvg;
  String? _selectedMimicSvg;
  String? _selectedTelemetry;
  String? _selectedAlarmJson;
  String? _currentMainPath;
  String? _currentMimicPath;
  String? _currentTelemetryPath;
  bool _isLoadingMain = false;
  bool _isLoadingMimic = false;
  bool _isLoadingTelemetry = false;
  bool _isLoadingAlarms = false;
  bool _autoLinking = false;

  String? _activeItemId;
  final _noteTitleController = TextEditingController();
  final _noteDescriptionController = TextEditingController();
  final _noteCategoryController = TextEditingController();
  final _noteAboutController = TextEditingController();
  final _imageTitleController = TextEditingController();
  final _imageDescriptionController = TextEditingController();
  final _imageCategoryController = TextEditingController();
  final _imageAboutController = TextEditingController();
  final _videoTitleController = TextEditingController();
  final _videoDescriptionController = TextEditingController();
  final _videoCategoryController = TextEditingController();
  final _videoAboutController = TextEditingController();
  final _chatInputController = TextEditingController();
  final _dataFetchUrlController = TextEditingController(text: 'http://localhost:3036');
  final _dataFetchKeyController = TextEditingController();
  final _presetNameController = TextEditingController();
  final _viewPresetNameController = TextEditingController();
  final _batchCategoryController = TextEditingController();
  final _batchNoteTitleController = TextEditingController();
  final _batchNoteDescriptionController = TextEditingController();
  final _batchLinkLabelController = TextEditingController();
  final _batchLinkUrlController = TextEditingController();
  final _linkLabelController = TextEditingController();
  final _linkUrlController = TextEditingController();
  final _snapshotLabelController = TextEditingController();
  final _supabaseEmailController = TextEditingController();
  final _supabasePasswordController = TextEditingController();
  String _fetchStatus = '';
  bool _dataFetchActive = false;
  String? _selectedPresetName;
  String? _compareSnapshotA;
  String? _compareSnapshotB;
  List<SnapshotMeta> _snapshotList = [];
  String _snapshotStatus = '';
  String _snapshotDiff = '';
  List<LinkSetMeta> _linkSetList = [];
  String _linkSetStatus = '';

  @override
  void initState() {
    super.initState();
    _sectionOrder = List<String>.from(_defaultSectionOrder);
    _loadSectionOrder();
  }

  @override
  void dispose() {
    _noteTitleController.dispose();
    _noteDescriptionController.dispose();
    _noteCategoryController.dispose();
    _noteAboutController.dispose();
    _imageTitleController.dispose();
    _imageDescriptionController.dispose();
    _imageCategoryController.dispose();
    _imageAboutController.dispose();
    _videoTitleController.dispose();
    _videoDescriptionController.dispose();
    _videoCategoryController.dispose();
    _videoAboutController.dispose();
    _chatInputController.dispose();
    _dataFetchUrlController.dispose();
    _dataFetchKeyController.dispose();
    _presetNameController.dispose();
    _viewPresetNameController.dispose();
    _batchCategoryController.dispose();
    _batchNoteTitleController.dispose();
    _batchNoteDescriptionController.dispose();
    _batchLinkLabelController.dispose();
    _batchLinkUrlController.dispose();
    _linkLabelController.dispose();
    _linkUrlController.dispose();
    _snapshotLabelController.dispose();
    _supabaseEmailController.dispose();
    _supabasePasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSvg(String assetPath, {required bool isMain}) async {
    await _loadSvgByPath(assetPath, isMain: isMain);
  }

  Future<void> _loadSvgByPath(String path, {required bool isMain, bool allowLink = true}) async {
    if (isMain) {
      setState(() => _isLoadingMain = true);
    } else {
      setState(() => _isLoadingMimic = true);
    }

    try {
      final svg = _isAssetPath(path) ? await rootBundle.loadString(path) : await File(path).readAsString();
      final sanitized = _sanitizeSvgContent(svg);
      _auditSvgCoordinates(sanitized, path);
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (isMain) {
        appState.setMainSvgContent(sanitized);
        if (appState.isMimicSynced) {
          appState.setMimicSvgContent(sanitized);
        }
      } else {
        appState.setMimicSvgContent(sanitized);
        appState.setMimicSynced(false);
      }
      setState(() {
        if (isMain) {
          _currentMainPath = path;
          _selectedMainSvg = _isAssetPath(path) ? path : null;
          if (appState.isMimicSynced) {
            _currentMimicPath = path;
            _selectedMimicSvg = _isAssetPath(path) ? path : null;
          }
        } else {
          _currentMimicPath = path;
          _selectedMimicSvg = _isAssetPath(path) ? path : null;
        }
      });
      if (isMain) {
        appState.setMainViewOffset(Offset.zero);
        if (appState.isMimicSynced) {
          appState.setMimicViewOffset(Offset.zero);
        }
      } else {
        appState.setMimicViewOffset(Offset.zero);
      }
      if (allowLink) {
        await _applyLinkedFiles(path, source: isMain ? 'main' : 'mimic');
      }
    } catch (e) {
      if (!mounted) return;
      context.read<AppState>().reportError("SVG load failed: $path");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load SVG: $path")),
      );
    } finally {
      if (!mounted) return;
      if (isMain) {
        setState(() => _isLoadingMain = false);
      } else {
        setState(() => _isLoadingMimic = false);
      }
    }
  }

  Future<void> _loadTelemetryAsset(String assetPath) async {
    await _loadTelemetryByPath(assetPath);
  }

  Future<void> _loadTelemetryByPath(String path, {bool allowLink = true}) async {
    setState(() => _isLoadingTelemetry = true);
    try {
      final content = _isAssetPath(path) ? await rootBundle.loadString(path) : await File(path).readAsString();
      if (!mounted) return;
      context.read<TelemetryProvider>().loadFromJsonString(content);
      setState(() {
        _currentTelemetryPath = path;
        _selectedTelemetry = _isAssetPath(path) ? path : null;
      });
      if (allowLink) {
        await _applyLinkedFiles(path, source: 'telemetry');
      }
    } catch (e) {
      if (!mounted) return;
      context.read<AppState>().reportError("Telemetry load failed: $path");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load telemetry: $path")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingTelemetry = false);
    }
  }

  Future<void> _loadAlarmAsset(String assetPath) async {
    setState(() => _isLoadingAlarms = true);
    try {
      final content = await rootBundle.loadString(assetPath);
      if (!mounted) return;
      context.read<AlarmProvider>().loadFromJsonString(content);
      final telemetry = context.read<TelemetryProvider>();
      context.read<AlarmProvider>().checkMatches(telemetry.items);
    } catch (e) {
      if (!mounted) return;
      context.read<AppState>().reportError("Alarm load failed: $assetPath");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load alarms: $assetPath")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingAlarms = false);
    }
  }

  Future<void> _pickSvgFile({required bool isMain}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['svg'],
    );
    if (result == null || result.files.single.path == null) return;
    await _loadSvgByPath(result.files.single.path!, isMain: isMain);
  }

  Future<void> _pickTelemetryFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    try {
      await _loadTelemetryByPath(result.files.single.path!);
    } catch (e) {
      if (mounted) {
        context.read<AppState>().reportError("Telemetry JSON invalid.");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Telemetry JSON format is invalid.")),
      );
    }
  }

  Future<void> _pickAlarmFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final content = await File(path).readAsString();
    if (!mounted) return;
    try {
      context.read<AlarmProvider>().loadFromJsonString(content);
      final telemetry = context.read<TelemetryProvider>();
      context.read<AlarmProvider>().checkMatches(telemetry.items);
    } catch (e) {
      if (mounted) {
        context.read<AppState>().reportError("Alarm JSON invalid: $path");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alarm JSON format is invalid.")),
      );
    }
  }

  Future<void> _saveJsonToFile(String suggestedName, String content) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save JSON',
      fileName: suggestedName,
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    if (path == null) return;
    await File(path).writeAsString(content);
  }

  void _syncNoteControllers(NoteEntry entry) {
    if (_noteTitleController.text != entry.title) _noteTitleController.text = entry.title;
    if (_noteDescriptionController.text != entry.description) _noteDescriptionController.text = entry.description;
    if (_noteCategoryController.text != entry.category) _noteCategoryController.text = entry.category;
    if (_noteAboutController.text != entry.about) _noteAboutController.text = entry.about;
  }

  void _syncMediaControllers(MediaEntry entry, TextEditingController title, TextEditingController desc, TextEditingController cat, TextEditingController about) {
    if (title.text != entry.title) title.text = entry.title;
    if (desc.text != entry.description) desc.text = entry.description;
    if (cat.text != entry.category) cat.text = entry.category;
    if (about.text != entry.about) about.text = entry.about;
  }

  Future<void> _pickImage(MediaProvider media, String itemId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final data = base64Encode(result.files.single.bytes!);
    media.setImage(
      itemId,
      MediaEntry(
        data: data,
        title: _imageTitleController.text,
        description: _imageDescriptionController.text,
        category: _imageCategoryController.text,
        about: _imageAboutController.text,
      ),
    );
  }

  Future<void> _pickVideo(MediaProvider media, String itemId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'avi', 'mov', 'wmv', 'mkv', 'webm'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final data = base64Encode(result.files.single.bytes!);
    media.setVideo(
      itemId,
      MediaEntry(
        data: data,
        title: _videoTitleController.text,
        description: _videoDescriptionController.text,
        category: _videoCategoryController.text,
        about: _videoAboutController.text,
      ),
    );
  }

  Future<void> _saveProject() async {
    final telemetry = context.read<TelemetryProvider>();
    final drawings = context.read<DrawingProvider>();
    final texts = context.read<TextProvider>();
    final notes = context.read<NotesProvider>();
    final media = context.read<MediaProvider>();
    final history = context.read<HistoryProvider>();
    final itemLinks = context.read<ItemLinksProvider>();
    final payload = {
      'telemetry': jsonDecode(telemetry.toJsonString()),
      'drawings': jsonDecode(drawings.toJsonString()),
      'texts': jsonDecode(texts.toJsonString()),
      'notes': jsonDecode(notes.toJsonString()),
      'item_links': jsonDecode(itemLinks.toJsonString()),
      'images': jsonDecode(media.imagesToJsonString()),
      'videos': jsonDecode(media.videosToJsonString()),
      'history': jsonDecode(history.toJsonString()),
    };
    await _saveJsonToFile('project.json', jsonEncode(payload));
  }

  Future<void> _exportPack() async {
    final appState = context.read<AppState>();
    final telemetry = context.read<TelemetryProvider>();
    final alarms = context.read<AlarmProvider>();
    final links = context.read<LinkProvider>();
    final itemLinks = context.read<ItemLinksProvider>();
    final drawings = context.read<DrawingProvider>();
    final texts = context.read<TextProvider>();
    final notes = context.read<NotesProvider>();
    final media = context.read<MediaProvider>();
    final history = context.read<HistoryProvider>();
    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'settings': appState.toSettingsJson(),
      'telemetry': jsonDecode(telemetry.toJsonString()),
      'telemetry_settings': telemetry.toSettingsJson(),
      'alarms': jsonDecode(alarms.toJsonString()),
      'alarm_settings': alarms.toSettingsJson(),
      'links': jsonDecode(links.exportJson()),
      'item_links': jsonDecode(itemLinks.toJsonString()),
      'drawings': jsonDecode(drawings.toJsonString()),
      'texts': jsonDecode(texts.toJsonString()),
      'notes': jsonDecode(notes.toJsonString()),
      'media_images': jsonDecode(media.imagesToJsonString()),
      'media_videos': jsonDecode(media.videosToJsonString()),
      'history': jsonDecode(history.toJsonString()),
      'assets': {
        'main_svg_content': appState.mainSvgContent,
        'mimic_svg_content': appState.mimicSvgContent,
        'main_asset_path': _currentMainPath,
        'mimic_asset_path': _currentMimicPath,
        'telemetry_asset_path': _currentTelemetryPath,
      },
    };
    await _saveJsonToFile('export_pack.json', jsonEncode(payload));
  }

  Future<void> _loadProject() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    final content = await File(result.files.single.path!).readAsString();
    final data = jsonDecode(content);
    if (data is! Map) return;
    if (data['telemetry'] != null) {
      context.read<TelemetryProvider>().loadFromJsonString(jsonEncode(data['telemetry']));
    }
    if (data['drawings'] != null) {
      context.read<DrawingProvider>().loadFromJsonString(jsonEncode(data['drawings']));
    }
    if (data['texts'] != null) {
      context.read<TextProvider>().loadFromJsonString(jsonEncode(data['texts']));
    }
    if (data['notes'] != null) {
      context.read<NotesProvider>().loadFromJsonString(jsonEncode(data['notes']));
    }
    if (data['item_links'] != null) {
      context.read<ItemLinksProvider>().loadFromJsonString(jsonEncode(data['item_links']));
    }
    if (data['images'] != null) {
      context.read<MediaProvider>().loadImagesFromJsonString(jsonEncode(data['images']));
    }
    if (data['videos'] != null) {
      context.read<MediaProvider>().loadVideosFromJsonString(jsonEncode(data['videos']));
    }
    if (data['history'] != null) {
      context.read<HistoryProvider>().loadFromJsonString(jsonEncode(data['history']));
    }
  }

  Future<void> _fetchAllData() async {
    final baseUrl = _dataFetchUrlController.text.trim();
    if (baseUrl.isEmpty) return;
    final key = _dataFetchKeyController.text.trim();
    setState(() => _fetchStatus = 'Fetching data...');
    try {
      final mainSvg = await _fetchText('$baseUrl/api/data/main_container.svg', key: key);
      if (mainSvg != null) {
        context.read<AppState>().setMainSvgContent(mainSvg);
      }
      final mimicSvg = await _fetchText('$baseUrl/api/data/mimic_container.svg', key: key);
      if (mimicSvg != null) {
        context.read<AppState>().setMimicSvgContent(mimicSvg);
      }
      final telemetryJson = await _fetchText('$baseUrl/api/data/select_item_list.json', key: key);
      if (telemetryJson != null) {
        context.read<TelemetryProvider>().loadFromJsonString(telemetryJson);
      }
      final chatbotJson = await _fetchText('$baseUrl/api/data/chatbot_data.json', key: key);
      if (chatbotJson != null) {
        context.read<ChatbotProvider>().loadIntentsFromJsonString(chatbotJson);
      }
      final drawingsJson = await _fetchText('$baseUrl/api/data/drawing_control_panel.json', key: key);
      if (drawingsJson != null) {
        context.read<DrawingProvider>().loadFromJsonString(drawingsJson);
      }
      final textJson = await _fetchText('$baseUrl/api/data/texting_control_panel.json', key: key);
      if (textJson != null) {
        context.read<TextProvider>().loadFromJsonString(textJson);
      }
      final alarmsJson = await _fetchText('$baseUrl/api/data/alarms_control_panel.json', key: key);
      if (alarmsJson != null) {
        context.read<AlarmProvider>().loadFromJsonString(alarmsJson);
        context.read<AlarmProvider>().checkMatches(context.read<TelemetryProvider>().items);
      }
      final notesJson = await _fetchText('$baseUrl/api/data/additional_notes.json', key: key);
      if (notesJson != null) {
        context.read<NotesProvider>().loadFromJsonString(notesJson);
      }
      final imageJson = await _fetchText('$baseUrl/api/data/add_image.json', key: key);
      if (imageJson != null) {
        context.read<MediaProvider>().loadImagesFromJsonString(imageJson);
      }
      final videoJson = await _fetchText('$baseUrl/api/data/video_playback.json', key: key);
      if (videoJson != null) {
        context.read<MediaProvider>().loadVideosFromJsonString(videoJson);
      }
      final historyJson = await _fetchText('$baseUrl/api/data/history.json', key: key);
      if (historyJson != null) {
        context.read<HistoryProvider>().loadFromJsonString(historyJson);
      }
      setState(() => _fetchStatus = 'Data fetch complete.');
    } catch (e) {
      setState(() => _fetchStatus = 'Fetch failed: $e');
      if (mounted) {
        context.read<AppState>().reportError("Data fetch failed: $e");
      }
    }
  }

  Future<String?> _fetchText(String url, {required String key}) async {
    final client = HttpClient();
    final uri = Uri.parse(key.isEmpty ? url : '$url?authKey=$key');
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) {
      return null;
    }
    return await response.transform(utf8.decoder).join();
  }

  Future<void> _refreshSnapshots(SupabaseProvider supabase) async {
    if (!supabase.isReady) return;
    setState(() => _snapshotStatus = 'Loading snapshots...');
    final list = await supabase.listSnapshots();
    if (!mounted) return;
    setState(() {
      _snapshotList = list;
      _snapshotStatus = 'Loaded ${list.length} snapshots.';
    });
  }

  Future<void> _refreshLinkSets(SupabaseProvider supabase) async {
    if (!supabase.isReady || !supabase.isAuthenticated || supabase.isAnonymous) return;
    setState(() => _linkSetStatus = 'Loading link sets...');
    final list = await supabase.listLinkSets();
    if (!mounted) return;
    setState(() {
      _linkSetList = list;
      _linkSetStatus = 'Loaded ${list.length} link sets.';
    });
  }

  Future<void> _restoreSnapshotById(String id) async {
    final supabase = context.read<SupabaseProvider>();
    final data = await supabase.fetchSnapshotById(id);
    if (!mounted || data == null) return;
    final appState = context.read<AppState>();
    final telemetry = context.read<TelemetryProvider>();
    final alarms = context.read<AlarmProvider>();
    final links = context.read<LinkProvider>();
    final itemLinks = context.read<ItemLinksProvider>();
    final drawings = context.read<DrawingProvider>();
    final texts = context.read<TextProvider>();
    final notes = context.read<NotesProvider>();
    final media = context.read<MediaProvider>();
    final history = context.read<HistoryProvider>();
    final settings = data['settings'];
    if (settings is Map<String, dynamic>) {
      appState.applySettingsJson(settings);
    }
    if (data['telemetry'] != null) {
      telemetry.loadFromJsonString(jsonEncode(data['telemetry']));
    }
    if (data['alarms'] != null) {
      alarms.loadFromJsonString(jsonEncode(data['alarms']));
    }
    if (data['links'] != null) {
      links.importJson(jsonEncode(data['links']));
    }
    if (data['item_links'] != null) {
      itemLinks.loadFromJsonString(jsonEncode(data['item_links']));
    }
    if (data['drawings'] != null) {
      drawings.loadFromJsonString(jsonEncode(data['drawings']));
    }
    if (data['texts'] != null) {
      texts.loadFromJsonString(jsonEncode(data['texts']));
    }
    if (data['notes'] != null) {
      notes.loadFromJsonString(jsonEncode(data['notes']));
    }
    if (data['media_images'] != null) {
      media.loadImagesFromJsonString(jsonEncode(data['media_images']));
    }
    if (data['media_videos'] != null) {
      media.loadVideosFromJsonString(jsonEncode(data['media_videos']));
    }
    if (data['history'] != null) {
      history.loadFromJsonString(jsonEncode(data['history']));
    }
    if (data['telemetry_settings'] is Map<String, dynamic>) {
      telemetry.applySettingsJson(Map<String, dynamic>.from(data['telemetry_settings']));
    }
    if (data['alarm_settings'] is Map<String, dynamic>) {
      alarms.applySettingsJson(Map<String, dynamic>.from(data['alarm_settings']));
    }
  }

  String _diffSnapshot(Map<String, dynamic> a, Map<String, dynamic> b) {
    int _count(dynamic value) {
      if (value is List) return value.length;
      if (value is Map) return value.length;
      return 0;
    }

    final lines = <String>[];
    final telemetryA = _count(a['telemetry']);
    final telemetryB = _count(b['telemetry']);
    lines.add('Telemetry: $telemetryA -> $telemetryB');
    final alarmsA = _count(a['alarms']);
    final alarmsB = _count(b['alarms']);
    lines.add('Alarms: $alarmsA -> $alarmsB');
    final notesA = _count(a['notes']);
    final notesB = _count(b['notes']);
    lines.add('Notes: $notesA -> $notesB');
    final imagesA = _count(a['media_images']);
    final imagesB = _count(b['media_images']);
    lines.add('Images: $imagesA -> $imagesB');
    final videosA = _count(a['media_videos']);
    final videosB = _count(b['media_videos']);
    lines.add('Videos: $videosA -> $videosB');
    final drawingsA = _count(a['drawings']);
    final drawingsB = _count(b['drawings']);
    lines.add('Drawings: $drawingsA -> $drawingsB');
    return lines.join('\n');
  }

  String _labelForAsset(String assetPath) {
    final parts = assetPath.split('/');
    return parts.isNotEmpty ? parts.last : assetPath;
  }

  String _labelForPath(String path) {
    if (path.contains(Platform.pathSeparator)) {
      final parts = path.split(Platform.pathSeparator);
      return parts.isNotEmpty ? parts.last : path;
    }
    return _labelForAsset(path);
  }

  bool _isAssetPath(String path) {
    return path.startsWith('assets/');
  }

  String _sanitizeSvgContent(String svg) {
    var sanitized = svg;
    sanitized = sanitized.replaceAll(
      RegExp(r'<clipPath\b[\s\S]*?</clipPath>', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'<mask\b[\s\S]*?</mask>', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\sclip-path\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r"\sclip-path\s*=\s*'[^']*'", caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\smask\s*=\s*"[^"]*"', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r"\smask\s*=\s*'[^']*'", caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'clip-path\s*:\s*url\([^)]+\)\s*;?', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'mask\s*:\s*url\([^)]+\)\s*;?', caseSensitive: false),
      '',
    );

    final match = RegExp(r'<svg\b[^>]*>', caseSensitive: false).firstMatch(sanitized);
    if (match == null) return sanitized;
    var svgTag = match.group(0) ?? '';

    if (!RegExp(r'\soverflow\s*=', caseSensitive: false).hasMatch(svgTag)) {
      svgTag = svgTag.replaceFirst('>', ' overflow="visible">');
    }
    if (!RegExp(r'\spreserveAspectRatio\s*=', caseSensitive: false).hasMatch(svgTag)) {
      svgTag = svgTag.replaceFirst('>', ' preserveAspectRatio="xMidYMid meet">');
    }
    if (!RegExp(r'\sviewBox\s*=', caseSensitive: false).hasMatch(svgTag)) {
      final width = _parseSvgAttribute(svgTag, 'width');
      final height = _parseSvgAttribute(svgTag, 'height');
      if (width != null && height != null && width > 0 && height > 0) {
        svgTag = svgTag.replaceFirst('>', ' viewBox="0 0 $width $height">');
      }
    }

    return sanitized.replaceRange(match.start, match.end, svgTag);
  }

  double? _parseSvgAttribute(String svgTag, String name) {
    final doubleQuoted = RegExp('$name\\s*=\\s*"([^"]+)"', caseSensitive: false).firstMatch(svgTag);
    final raw = doubleQuoted?.group(1) ??
        RegExp("$name\\s*=\\s*'([^']+)'", caseSensitive: false).firstMatch(svgTag)?.group(1);
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.endsWith('%')) return null;
    final cleaned = trimmed.replaceAll(RegExp(r'[^0-9\.]+'), '');
    return double.tryParse(cleaned);
  }

  void _auditSvgCoordinates(String svg, String label) {
    if (!kDebugMode) return;
    final viewBox = RegExp(r'viewBox\s*=\s*"([^"]+)"', caseSensitive: false).firstMatch(svg)?.group(1) ??
        RegExp(r"viewBox\s*=\s*'([^']+)'", caseSensitive: false).firstMatch(svg)?.group(1);
    double? vbWidth;
    double? vbHeight;
    if (viewBox != null) {
      final parts = viewBox.trim().split(RegExp(r'[,\s]+'));
      if (parts.length >= 4) {
        vbWidth = double.tryParse(parts[2]);
        vbHeight = double.tryParse(parts[3]);
      }
    }
    var maxNumber = 0.0;
    final dMatches = RegExp(r'd\s*=\s*"([^"]+)"', caseSensitive: false).allMatches(svg);
    final numRegex = RegExp(r'[-+]?(?:\d*\.?\d+|\d+)(?:[eE][-+]?\d+)?');
    for (final match in dMatches) {
      final d = match.group(1) ?? '';
      for (final num in numRegex.allMatches(d)) {
        final value = double.tryParse(num.group(0) ?? '') ?? 0.0;
        final absValue = value.abs();
        if (absValue > maxNumber) maxNumber = absValue;
      }
    }
    if (vbWidth != null && vbHeight != null && maxNumber > 0) {
      if (maxNumber > vbWidth * 1.1 || maxNumber > vbHeight * 1.1) {
        debugPrint('[SVG AUDIT] $label: max coordinate ~$maxNumber exceeds viewBox $vbWidth x $vbHeight');
      } else {
        debugPrint('[SVG AUDIT] $label: viewBox $vbWidth x $vbHeight looks consistent');
      }
    } else {
      debugPrint('[SVG AUDIT] $label: viewBox or path data missing for audit');
    }
  }

  void _clearAll() {
    final appState = context.read<AppState>();
    context.read<TelemetryProvider>().clear();
    context.read<AlarmProvider>().clear();
    context.read<DrawingProvider>().clearDrawings();
    context.read<TextProvider>().clearTexts();
    context.read<NotesProvider>().clear();
    context.read<MediaProvider>().clearAll();
    context.read<HistoryProvider>().clear();
    appState.resetAll();
    setState(() {
      _selectedMainSvg = null;
      _selectedMimicSvg = null;
      _selectedTelemetry = null;
      _selectedAlarmJson = null;
      _currentMainPath = null;
      _currentMimicPath = null;
      _currentTelemetryPath = null;
      _isLoadingMain = false;
      _isLoadingMimic = false;
      _isLoadingTelemetry = false;
      _isLoadingAlarms = false;
    });
  }

  Future<void> _applyLinkedFiles(String path, {required String source}) async {
    if (_autoLinking) return;
    final linkProvider = context.read<LinkProvider>();
    final link = linkProvider.findByPath(path);
    if (link == null) return;
    _autoLinking = true;
    try {
      if (source != 'main' && link.mainSvg.isNotEmpty) {
        await _loadSvgByPath(link.mainSvg, isMain: true, allowLink: false);
      }
      if (source != 'mimic' && link.mimicSvg.isNotEmpty) {
        await _loadSvgByPath(link.mimicSvg, isMain: false, allowLink: false);
      }
      if (source != 'telemetry' && link.telemetryJson.isNotEmpty) {
        await _loadTelemetryByPath(link.telemetryJson, allowLink: false);
      }
    } finally {
      _autoLinking = false;
    }
  }

  Future<void> _linkCurrent(LinkProvider linkProvider) async {
    final main = _currentMainPath;
    final mimic = _currentMimicPath;
    final telemetry = _currentTelemetryPath;
    if (main == null || mimic == null || telemetry == null) return;
    linkProvider.upsert(
      LinkAssociation(mainSvg: main, mimicSvg: mimic, telemetryJson: telemetry),
    );
    final supabase = context.read<SupabaseProvider>();
    if (supabase.isAuthenticated && !supabase.isAnonymous) {
      final appState = context.read<AppState>();
      final telemetryProvider = context.read<TelemetryProvider>();
      final mainSvg = appState.mainSvgContent;
      final mimicSvg = appState.mimicSvgContent;
      if (mainSvg != null && mimicSvg != null) {
        final label = 'Links ${_labelForPath(main)} / ${_labelForPath(mimic)}';
        await supabase.uploadPortableLinks(
          label: label,
          mainSvg: mainSvg,
          mimicSvg: mimicSvg,
          telemetryJson: telemetryProvider.toJsonString(),
        );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Linked file set saved.")),
    );
  }

  Future<void> _importLinks(LinkProvider linkProvider) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    final content = await File(result.files.single.path!).readAsString();
    try {
      final count = linkProvider.importJson(content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Imported $count link file set(s).")),
      );
    } catch (_) {
      if (!mounted) return;
      context.read<AppState>().reportError("Link file import failed.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Link file list is invalid.")),
      );
    }
  }

  Future<void> _editLink(LinkProvider linkProvider, int index, LinkAssociation link) async {
    final mainController = TextEditingController(text: link.mainSvg);
    final mimicController = TextEditingController(text: link.mimicSvg);
    final telemetryController = TextEditingController(text: link.telemetryJson);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Linked Files"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: mainController,
                  decoration: const InputDecoration(labelText: 'Main SVG path'),
                ),
                TextField(
                  controller: mimicController,
                  decoration: const InputDecoration(labelText: 'Mimic SVG path'),
                ),
                TextField(
                  controller: telemetryController,
                  decoration: const InputDecoration(labelText: 'Telemetry JSON path'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final main = mainController.text.trim();
                final mimic = mimicController.text.trim();
                final telemetry = telemetryController.text.trim();
                if (main.isEmpty || mimic.isEmpty || telemetry.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All fields are required.")),
                  );
                  return;
                }
                linkProvider.updateAt(
                  index,
                  LinkAssociation(mainSvg: main, mimicSvg: mimic, telemetryJson: telemetry),
                );
                Navigator.of(context).pop(true);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Linked file set updated.")),
      );
    }
  }

  Future<void> _deleteLink(LinkProvider linkProvider, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Linked Files"),
          content: const Text("Remove this link association?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    linkProvider.deleteAt(index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Linked file set deleted.")),
    );
  }

  Future<void> _loadSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_sectionOrderKey);
    if (!mounted || stored == null) return;
    setState(() => _sectionOrder = _mergeSectionOrder(stored));
  }

  Future<void> _persistSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sectionOrderKey, _sectionOrder);
  }

  List<String> _mergeSectionOrder(List<String> stored) {
    final seen = <String>{};
    final merged = <String>[];
    for (final id in stored) {
      if (_defaultSectionOrder.contains(id) && seen.add(id)) {
        merged.add(id);
      }
    }
    for (final id in _defaultSectionOrder) {
      if (seen.add(id)) {
        merged.add(id);
      }
    }
    return merged;
  }

  void _resetSectionOrder() {
    setState(() => _sectionOrder = List<String>.from(_defaultSectionOrder));
    _persistSectionOrder();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final moved = _sectionOrder.removeAt(oldIndex);
      _sectionOrder.insert(newIndex, moved);
    });
    _persistSectionOrder();
  }

  Widget _wrapSection(String id, int index, Widget child) {
    return Padding(
      key: ValueKey(id),
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            right: 0,
            child: ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.drag_handle, size: 18, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final uiTheme = UiThemes.presets[appState.themePreset] ?? UiThemes.glassIce;
    final sections = <String, Widget>{
      'assets': _buildAssetsSection(),
      'selected_item': _buildSelectedItemSection(),
      'batch_actions': _buildBatchActionsSection(),
      'marker_settings': _buildMarkerSettingsSection(),
      'navigation': _buildNavigationSection(),
      'layout_theme': _buildLayoutThemeSection(),
      'tooltips': _buildTooltipSection(),
      'telemetry_insights': _buildTelemetryInsightsSection(),
      'filter_presets': _buildFilterPresetsSection(),
      'view_presets': _buildViewPresetsSection(),
      'recent_items': _buildRecentItemsSection(),
      'diagnostics': _buildDiagnosticsSection(),
      'snapshot_history': _buildSnapshotHistorySection(),
      'accessibility': _buildAccessibilitySection(),
      'supabase': _buildSupabaseSection(),
      'openai': _buildOpenAiSection(),
      'system_status': _buildSystemStatusSection(),
      'background_colors': _buildBackgroundSection(),
      'alarms': _buildAlarmsSection(),
      'data_fetch': _buildDataFetchSection(),
      'notes': _buildNotesSection(),
      'media': _buildMediaSection(),
      'history': _buildHistorySection(),
      'project': _buildProjectSection(),
      'chatbot': _buildChatbotSection(),
      'search': const SearchControl(),
      'sector': const SectorControl(),
      'subsystems': const SubSystemsControl(),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: uiTheme.backgroundGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                const Text(
                  "Sidebar",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Reset layout',
                  onPressed: _resetSectionOrder,
                  icon: Icon(Icons.refresh, size: 20, color: uiTheme.accent),
                ),
                IconButton(
                  tooltip: 'Collapse sidebar',
                  onPressed: appState.toggleSidebarCollapsed,
                  icon: Icon(Icons.chevron_right, size: 22, color: uiTheme.accent),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ReorderableListView(
                padding: const EdgeInsets.all(8),
                buildDefaultDragHandles: false,
                onReorder: _onReorder,
                children: [
                  for (var i = 0; i < _sectionOrder.length; i++)
                    _wrapSection(
                      _sectionOrder[i],
                      i,
                      sections[_sectionOrder[i]] ?? const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassPanel({required Widget child}) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: child,
    );
  }

  Future<void> _exportSettings() async {
    final appState = context.read<AppState>();
    final telemetry = context.read<TelemetryProvider>();
    final alarms = context.read<AlarmProvider>();
    final payload = {
      'version': 1,
      'appState': appState.toSettingsJson(),
      'telemetry': telemetry.toSettingsJson(),
      'alarms': alarms.toSettingsJson(),
    };
    await _saveJsonToFile('settings.json', jsonEncode(payload));
  }

  Future<void> _importSettings() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    try {
      final content = await File(result.files.single.path!).readAsString();
      final data = jsonDecode(content);
      if (data is! Map) return;
      final appState = context.read<AppState>();
      final telemetry = context.read<TelemetryProvider>();
      final alarms = context.read<AlarmProvider>();
      if (data['appState'] is Map<String, dynamic>) {
        appState.applySettingsJson(Map<String, dynamic>.from(data['appState'] as Map));
      }
      if (data['telemetry'] is Map<String, dynamic>) {
        telemetry.applySettingsJson(Map<String, dynamic>.from(data['telemetry'] as Map));
      }
      if (data['alarms'] is Map<String, dynamic>) {
        alarms.applySettingsJson(Map<String, dynamic>.from(data['alarms'] as Map));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings imported.")),
        );
      }
    } catch (e) {
      if (mounted) {
        context.read<AppState>().reportError("Settings import failed: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings import failed.")),
        );
      }
    }
  }

  Widget _buildLayoutThemeSection() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Layout & Theme", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<ThemePreset>(
                  value: appState.themePreset,
                  items: ThemePreset.values
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(UiThemes.presets[preset]?.label ?? preset.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    appState.setThemePreset(value);
                  },
                  decoration: const InputDecoration(labelText: "Theme Style"),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  title: const Text("Dark Mode"),
                  value: appState.themeMode == ThemeMode.dark,
                  onChanged: (_) => appState.toggleTheme(),
                  dense: true,
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: appState.resetUiTheme,
                      child: const Text("Reset Theme"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _exportSettings,
                      child: const Text("Export Settings"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _importSettings,
                      child: const Text("Import Settings"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () {
                    appState.persistAllSettings();
                    context.read<TelemetryProvider>().persistAllSettings();
                    context.read<AlarmProvider>().persistAllSettings();
                  },
                  child: const Text("Save As Default"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTooltipSection() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tooltips & Thumbnails", style: TextStyle(fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text("Enable Tooltips"),
                  value: appState.tooltipsEnabled,
                  onChanged: appState.setTooltipsEnabled,
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text("Hover Thumbnail"),
                  value: appState.tooltipHoverEnabled,
                  onChanged: appState.setTooltipHoverEnabled,
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text("Selected Item Thumbnail"),
                  value: appState.tooltipSelectedEnabled,
                  onChanged: appState.setTooltipSelectedEnabled,
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text("Show Label if No Image"),
                  value: appState.tooltipShowLabel,
                  onChanged: appState.setTooltipShowLabel,
                  dense: true,
                ),
                const SizedBox(height: 4),
                Text("Opacity: ${(appState.tooltipOpacity * 100).toStringAsFixed(0)}%"),
                Slider(
                  value: appState.tooltipOpacity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: appState.setTooltipOpacity,
                ),
                Text("Size: ${(appState.tooltipScale * 100).toStringAsFixed(0)}%"),
                Slider(
                  value: appState.tooltipScale,
                  min: 0.6,
                  max: 2.0,
                  onChanged: appState.setTooltipScale,
                ),
                Text("Hover Radius: ${appState.tooltipHitRadius.toStringAsFixed(0)} px"),
                Slider(
                  value: appState.tooltipHitRadius,
                  min: 6.0,
                  max: 60.0,
                  onChanged: appState.setTooltipHitRadius,
                ),
                const SizedBox(height: 6),
                const Text("Thumbnail Colors", style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    _colorDot(() => appState.setTooltipBackgroundColor(const Color(0xFFF4E8D0)), const Color(0xFFF4E8D0)),
                    _colorDot(() => appState.setTooltipBackgroundColor(Colors.black), Colors.black),
                    _colorDot(() => appState.setTooltipBackgroundColor(Colors.blueGrey), Colors.blueGrey),
                    _colorDot(() => appState.setTooltipBackgroundColor(Colors.indigo), Colors.indigo),
                    _colorDot(() => appState.setTooltipBackgroundColor(Colors.teal), Colors.teal),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Auto Contrast Text"),
                  value: appState.tooltipAutoText,
                  onChanged: appState.setTooltipAutoText,
                  dense: true,
                ),
                if (!appState.tooltipAutoText)
                  Row(
                    children: [
                      const Text("Text: "),
                      _colorDot(() => appState.setTooltipTextColor(Colors.black), Colors.black),
                      _colorDot(() => appState.setTooltipTextColor(Colors.white), Colors.white),
                      _colorDot(() => appState.setTooltipTextColor(Colors.yellow), Colors.yellow),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryInsightsSection() {
    return Consumer3<TelemetryProvider, AlarmProvider, OpenAiProvider>(
      builder: (context, telemetry, alarms, openai, _) {
        telemetry.setAlarmIds(alarms.matches.map((e) => e.id).toSet());
        final total = telemetry.items.length;
        final filtered = telemetry.filteredItems.length;
        final alarmCount = alarms.matches.length;
        final missing = telemetry.items.where((item) {
          final hasAbout = item.about != null && item.about!.isNotEmpty;
          final hasDesc = item.description != null && item.description!.isNotEmpty;
          return !hasAbout && !hasDesc;
        }).length;
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Telemetry Insights", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Total: $total"),
                Text("Filtered: $filtered"),
                Text("Alarms: $alarmCount"),
                Text("Missing Details: $missing"),
                SwitchListTile(
                  title: const Text("Only Alarms"),
                  value: telemetry.onlyAlarms,
                  onChanged: telemetry.setOnlyAlarms,
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text("Only Missing Details"),
                  value: telemetry.onlyMissingDetails,
                  onChanged: telemetry.setOnlyMissingDetails,
                  dense: true,
                ),
                const SizedBox(height: 6),
                if (openai.isReady)
                  OutlinedButton(
                    onPressed: () => _showAiSummary(context, telemetry, alarms, openai),
                    child: const Text("AI Summary"),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterPresetsSection() {
    return Consumer<TelemetryProvider>(
      builder: (context, telemetry, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Filter Presets", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _viewPresetNameController,
                  decoration: const InputDecoration(labelText: "Preset name"),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final name = _viewPresetNameController.text.trim();
                        if (name.isEmpty) return;
                        telemetry.savePreset(name);
                        setState(() => _selectedPresetName = name);
                      },
                      child: const Text("Save"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        final name = _selectedPresetName;
                        if (name == null) return;
                        telemetry.deletePreset(name);
                        setState(() => _selectedPresetName = null);
                      },
                      child: const Text("Delete"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPresetName != null &&
                          telemetry.presets.any((p) => p.name == _selectedPresetName)
                      ? _selectedPresetName
                      : null,
                  items: telemetry.presets
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset.name,
                          child: Text(preset.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedPresetName = value);
                    final preset = telemetry.presets.firstWhere((p) => p.name == value);
                    telemetry.applyPreset(preset);
                  },
                  decoration: const InputDecoration(labelText: "Apply preset"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentItemsSection() {
    return Consumer2<TelemetryProvider, AppState>(
      builder: (context, telemetry, appState, _) {
        final recent = telemetry.recentSelections;
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Recent Selections", style: TextStyle(fontWeight: FontWeight.bold)),
                if (recent.isEmpty) const Text("No recent items."),
                if (recent.isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      itemCount: recent.length,
                      itemBuilder: (context, index) {
                        final item = recent[index];
                        return ListTile(
                          dense: true,
                          title: Text(item.title.isNotEmpty ? item.title : item.id),
                          onTap: () {
                            telemetry.selectItem(item);
                            appState.setFocusTarget(Offset(item.x, item.y), lock: true);
                            appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccessibilitySection() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Accessibility", style: TextStyle(fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text("High Contrast"),
                  value: appState.highContrast,
                  onChanged: appState.setHighContrast,
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text("Reduce Motion"),
                  value: appState.reduceMotion,
                  onChanged: appState.setReduceMotion,
                  dense: true,
                ),
                Text("Text Size: ${(appState.textScale * 100).toStringAsFixed(0)}%"),
                Slider(
                  value: appState.textScale,
                  min: 0.8,
                  max: 1.4,
                  onChanged: appState.setTextScale,
                ),
                OutlinedButton(
                  onPressed: () => _showShortcutHelp(context),
                  child: const Text("Keyboard Shortcuts"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAiSummary(
    BuildContext context,
    TelemetryProvider telemetry,
    AlarmProvider alarms,
    OpenAiProvider openai,
  ) async {
    final counts = {
      'total': telemetry.items.length,
      'filtered': telemetry.filteredItems.length,
      'alarms': alarms.matches.length,
    };
    final categories = telemetry.categories();
    final contextMap = {
      'counts': counts,
      'categories': categories.take(8).toList(),
      'filters': {
        'query': telemetry.query,
        'category': telemetry.categoryFilter,
        'level': telemetry.levelFilter,
        'action': telemetry.actionFilter,
      },
    };
    final result = await openai.ask(
      system:
          'You summarize telemetry datasets for operators. Provide a concise insight list and 1-2 recommended next actions.',
      user: 'Summarize telemetry status and highlight risks.',
      context: contextMap,
    );
    if (!mounted) return;
    if (result == null) {
      context.read<AppState>().reportError("OpenAI summary failed.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI summary failed.")),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("AI Telemetry Summary"),
          content: SingleChildScrollView(child: Text(result.reply)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close")),
          ],
        );
      },
    );
  }

  Future<void> _showShortcutHelp(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Keyboard Shortcuts"),
          content: const Text(
            "Arrow Keys: Pan (when keyboard pan enabled)\n"
            "PageUp/PageDown: Cycle selection\n"
            "Mouse Wheel: Zoom\n",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Close")),
          ],
        );
      },
    );
  }

  Widget _buildSystemStatusSection() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final errors = appState.errorLog;
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("System Status", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Errors: ${errors.length}"),
                if (errors.isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      itemCount: errors.length,
                      itemBuilder: (context, index) {
                        return Text(errors[index]);
                      },
                    ),
                  ),
                if (errors.isEmpty) const Text("No recent errors."),
                if (errors.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: appState.clearErrors,
                      child: const Text("Clear Errors"),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupabaseSection() {
    return Consumer<SupabaseProvider>(
      builder: (context, supabase, _) {
        Color statusColor;
        String statusLabel;
        switch (supabase.status) {
          case SupabaseStatus.ready:
            statusColor = Colors.green;
            statusLabel = "Connected";
            break;
          case SupabaseStatus.connecting:
            statusColor = Colors.orange;
            statusLabel = "Connecting";
            break;
          case SupabaseStatus.error:
            statusColor = Colors.red;
            statusLabel = "Error";
            break;
          default:
            statusColor = Colors.grey;
            statusLabel = "Disconnected";
        }
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Supabase Sync", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(statusLabel),
                    const Spacer(),
                    Text(supabase.isAuthenticated ? (supabase.userEmail ?? 'User') : supabase.namespace),
                  ],
                ),
                if (!supabase.isAuthenticated) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _supabaseEmailController,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),
                  TextField(
                    controller: _supabasePasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password"),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: !supabase.isReady
                            ? null
                            : () async {
                                final email = _supabaseEmailController.text.trim();
                                final password = _supabasePasswordController.text.trim();
                                if (email.isEmpty || password.isEmpty) return;
                                final ok = await supabase.signIn(email, password);
                                if (!ok && mounted) {
                                  context.read<AppState>().reportError("Supabase sign-in failed.");
                                } else {
                                  await supabase.applyLatestPortableLinks(
                                    appState: context.read<AppState>(),
                                    telemetry: context.read<TelemetryProvider>(),
                                  );
                                }
                              },
                        child: const Text("Sign In"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: !supabase.isReady
                            ? null
                            : () async {
                                final email = _supabaseEmailController.text.trim();
                                final password = _supabasePasswordController.text.trim();
                                if (email.isEmpty || password.isEmpty) return;
                                final ok = await supabase.signUp(email, password);
                                if (!ok && mounted) {
                                  context.read<AppState>().reportError("Supabase sign-up failed.");
                                }
                              },
                        child: const Text("Sign Up"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: !supabase.isReady
                            ? null
                            : () async {
                                final ok = await supabase.signInAnonymously();
                                if (!ok && mounted) {
                                  context.read<AppState>().reportError("Guest login failed.");
                                }
                              },
                        child: const Text("Guest Login"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Guest mode uses local file paths only.",
                    style: TextStyle(fontSize: 12),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await supabase.signOut();
                        },
                        child: const Text("Sign Out"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: supabase.isAnonymous
                            ? null
                            : () async {
                                final ok = await supabase.applyLatestPortableLinks(
                                  appState: context.read<AppState>(),
                                  telemetry: context.read<TelemetryProvider>(),
                                );
                                if (!ok && mounted) {
                                  context.read<AppState>().reportError("Portable link sync failed.");
                                }
                              },
                        child: const Text("Sync Links"),
                      ),
                    ],
                  ),
                  if (supabase.isAnonymous)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        "Guest login keeps local file paths and does not sync portable links.",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                if (supabase.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      supabase.lastError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: supabase.status == SupabaseStatus.connecting
                          ? null
                          : () => supabase.initialize(),
                      child: const Text("Connect"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: supabase.isReady
                          ? () async {
                              final ok = await supabase.fetchSnapshot(
                                appState: context.read<AppState>(),
                                telemetry: context.read<TelemetryProvider>(),
                                alarms: context.read<AlarmProvider>(),
                                links: context.read<LinkProvider>(),
                                itemLinks: context.read<ItemLinksProvider>(),
                                drawings: context.read<DrawingProvider>(),
                                texts: context.read<TextProvider>(),
                                notes: context.read<NotesProvider>(),
                                media: context.read<MediaProvider>(),
                                history: context.read<HistoryProvider>(),
                              );
                              if (!ok && mounted) {
                                context.read<AppState>().reportError("Supabase fetch failed.");
                              }
                            }
                          : null,
                      child: const Text("Fetch"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: supabase.isReady
                          ? () async {
                              final ok = await supabase.saveSnapshot(
                                appState: context.read<AppState>(),
                                telemetry: context.read<TelemetryProvider>(),
                                alarms: context.read<AlarmProvider>(),
                                links: context.read<LinkProvider>(),
                                itemLinks: context.read<ItemLinksProvider>(),
                                drawings: context.read<DrawingProvider>(),
                                texts: context.read<TextProvider>(),
                                notes: context.read<NotesProvider>(),
                                media: context.read<MediaProvider>(),
                                history: context.read<HistoryProvider>(),
                              );
                              if (!ok && mounted) {
                                context.read<AppState>().reportError("Supabase save failed.");
                              }
                            }
                          : null,
                      child: const Text("Save"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: (!supabase.isAuthenticated || supabase.isAnonymous)
                          ? null
                          : () async {
                              final appState = context.read<AppState>();
                              final telemetry = context.read<TelemetryProvider>();
                              final mainSvg = appState.mainSvgContent;
                              final mimicSvg = appState.mimicSvgContent;
                              if (mainSvg == null || mimicSvg == null) {
                                appState.reportError("Portable link upload requires main/mimic SVG.");
                                return;
                              }
                              final ok = await supabase.uploadPortableLinks(
                                label: "Portable link set",
                                mainSvg: mainSvg,
                                mimicSvg: mimicSvg,
                                telemetryJson: telemetry.toJsonString(),
                              );
                              if (!ok && mounted) {
                                appState.reportError("Portable link upload failed.");
                              }
                            },
                      child: const Text("Upload Links"),
                    ),
                  ],
                ),
                if (supabase.isAuthenticated && !supabase.isAnonymous) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => _refreshLinkSets(supabase),
                        child: const Text("Link History"),
                      ),
                      const SizedBox(width: 8),
                      Text(_linkSetStatus),
                    ],
                  ),
                  if (_linkSetList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text("No link history yet."),
                    ),
                  if (_linkSetList.isNotEmpty)
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        itemCount: _linkSetList.length,
                        itemBuilder: (context, index) {
                          final item = _linkSetList[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.label),
                            subtitle: Text(item.createdAt.toLocal().toString()),
                            onTap: () async {
                              final ok = await supabase.applyPortableLinksById(
                                id: item.id,
                                appState: context.read<AppState>(),
                                telemetry: context.read<TelemetryProvider>(),
                              );
                              if (!ok && mounted) {
                                context.read<AppState>().reportError("Link set apply failed.");
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
                const SizedBox(height: 6),
                Text(
                  "Offline-safe: the app runs without Supabase and syncs when connected.",
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpenAiSection() {
    return Consumer<OpenAiProvider>(
      builder: (context, openai, _) {
        Color statusColor;
        String statusLabel;
        switch (openai.status) {
          case OpenAiStatus.ready:
            statusColor = Colors.green;
            statusLabel = "Connected";
            break;
          case OpenAiStatus.connecting:
            statusColor = Colors.orange;
            statusLabel = "Connecting";
            break;
          case OpenAiStatus.error:
            statusColor = Colors.red;
            statusLabel = "Error";
            break;
          case OpenAiStatus.configured:
            statusColor = Colors.blueGrey;
            statusLabel = "Configured";
            break;
          default:
            statusColor = Colors.grey;
            statusLabel = "Disconnected";
        }
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("OpenAI", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(statusLabel),
                    const Spacer(),
                    Text(openai.model),
                  ],
                ),
                if (openai.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      openai.lastError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: openai.status == OpenAiStatus.connecting
                          ? null
                          : () => openai.initialize(),
                      child: const Text("Load Key"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: openai.isConfigured && openai.status != OpenAiStatus.connecting
                          ? () => openai.connect()
                          : null,
                      child: const Text("Connect"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "OpenAI enhances chat, search, and insights. App works without it.",
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssetsSection() {
    return Consumer3<AppState, TelemetryProvider, LinkProvider>(
      builder: (context, appState, telemetry, linkProvider, _) {
        final canLink = _currentMainPath != null && _currentMimicPath != null && _currentTelemetryPath != null;
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Assets", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _assetDropdown(
                  label: "Main SVG",
                  items: appState.platformFiles,
                  value: _selectedMainSvg,
                  isLoading: _isLoadingMain,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedMainSvg = value);
                    _loadSvg(value, isMain: true);
                  },
                ),
                const SizedBox(height: 8),
                _assetDropdown(
                  label: "Mimic SVG",
                  items: appState.platformFiles,
                  value: _selectedMimicSvg,
                  isLoading: _isLoadingMimic,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedMimicSvg = value);
                    _loadSvg(value, isMain: false);
                  },
                ),
                const SizedBox(height: 8),
                _assetDropdown(
                  label: "Telemetry JSON",
                  items: appState.telemetryFiles,
                  value: _selectedTelemetry,
                  isLoading: _isLoadingTelemetry,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedTelemetry = value);
                    _loadTelemetryAsset(value);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  "Main SVG size: ${_formatSize(appState.mainSvgSize)}",
                ),
                Text(
                  "Mimic SVG size: ${_formatSize(appState.mimicSvgSize)}",
                ),
                const SizedBox(height: 8),
                const Text("Cursor", style: TextStyle(fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text("Show Cursor Position"),
                  value: appState.showCursorPosition,
                  onChanged: appState.setShowCursorPosition,
                  dense: true,
                ),
                if (appState.cursorPosition != null)
                  Text(
                    "Cursor: X ${appState.cursorPosition!.dx.toStringAsFixed(1)}  Y ${appState.cursorPosition!.dy.toStringAsFixed(1)}",
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton(
                      onPressed: () => _pickSvgFile(isMain: true),
                      child: const Text("Load Main SVG"),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickSvgFile(isMain: false),
                      child: const Text("Load Mimic SVG"),
                    ),
                    OutlinedButton(
                      onPressed: appState.mainSvgContent == null
                          ? null
                          : () {
                              appState.setMimicSynced(true);
                              appState.setMimicSvgContent(appState.mainSvgContent!);
                              setState(() {
                                _currentMimicPath = _currentMainPath;
                                _selectedMimicSvg = _currentMainPath != null && _isAssetPath(_currentMainPath!)
                                    ? _currentMainPath
                                    : null;
                              });
                                      appState.setMimicViewOffset(Offset.zero);
                                    },
                              child: const Text("Sync Mimic to Main"),
                            ),
                    OutlinedButton(
                      onPressed: _pickTelemetryFile,
                      child: const Text("Load Telemetry JSON"),
                    ),
                    OutlinedButton(
                      onPressed: _clearAll,
                      child: const Text("Clear All"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Telemetry items: ${telemetry.items.length}"),
                const Divider(height: 20),
                const Text("Linked Files", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton(
                      onPressed: canLink ? () => _linkCurrent(linkProvider) : null,
                      child: const Text("Link Current Files"),
                    ),
                    OutlinedButton(
                      onPressed: linkProvider.links.isEmpty
                          ? null
                          : () => _saveJsonToFile('linked_files.json', linkProvider.exportJson()),
                      child: const Text("Export Links"),
                    ),
                    OutlinedButton(
                      onPressed: () => _importLinks(linkProvider),
                      child: const Text("Import Links"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text("Main: ${_currentMainPath == null ? 'None' : _labelForPath(_currentMainPath!)}"),
                Text("Mimic: ${_currentMimicPath == null ? 'None' : _labelForPath(_currentMimicPath!)}"),
                Text("Telemetry: ${_currentTelemetryPath == null ? 'None' : _labelForPath(_currentTelemetryPath!)}"),
                const SizedBox(height: 6),
                if (linkProvider.links.isEmpty)
                  const Text("No linked file sets yet."),
                if (linkProvider.links.isNotEmpty)
                  Column(
                    children: linkProvider.links.asMap().entries.map((entry) {
                      final index = entry.key;
                      final link = entry.value;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                "Main: ${_labelForPath(link.mainSvg)}\n"
                                "Mimic: ${_labelForPath(link.mimicSvg)}\n"
                                "Telemetry: ${_labelForPath(link.telemetryJson)}",
                              ),
                            ),
                            IconButton(
                              onPressed: () => _editLink(linkProvider, index, link),
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Edit link',
                            ),
                            IconButton(
                              onPressed: () => _deleteLink(linkProvider, index),
                              icon: const Icon(Icons.delete, size: 18),
                              tooltip: 'Delete link',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedItemSection() {
    return Consumer4<TelemetryProvider, NotesProvider, MediaProvider, ItemLinksProvider>(
      builder: (context, telemetry, notes, media, itemLinks, _) {
        final selected = telemetry.selectedItem;
        if (selected == null) return const SizedBox.shrink();
        if (_activeItemId != selected.id) {
          _activeItemId = selected.id;
          _syncNoteControllers(notes.noteFor(selected.id));
          _syncMediaControllers(media.imageFor(selected.id), _imageTitleController, _imageDescriptionController, _imageCategoryController, _imageAboutController);
          _syncMediaControllers(media.videoFor(selected.id), _videoTitleController, _videoDescriptionController, _videoCategoryController, _videoAboutController);
        }
        final note = notes.noteFor(selected.id);
        final links = itemLinks.linksFor(selected.id);
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Selected Item", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(selected.title),
                Text("ID: ${selected.id}"),
                Text("Category: ${selected.category}"),
                Text("X: ${selected.x}  Y: ${selected.y}"),
                if (selected.about != null && selected.about!.isNotEmpty)
                  Text("About: ${selected.about}"),
                if (selected.description != null && selected.description!.isNotEmpty)
                  Text("Description: ${selected.description}"),
                const Divider(height: 16),
                const Text("Quick Note", style: TextStyle(fontWeight: FontWeight.w600)),
                TextField(
                  controller: _noteTitleController,
                  decoration: const InputDecoration(labelText: "Title"),
                ),
                TextField(
                  controller: _noteDescriptionController,
                  decoration: const InputDecoration(labelText: "Description"),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        notes.setNote(
                          selected.id,
                          NoteEntry(
                            title: _noteTitleController.text,
                            description: _noteDescriptionController.text,
                            category: _noteCategoryController.text,
                            about: _noteAboutController.text,
                          ),
                        );
                      },
                      child: const Text("Save Note"),
                    ),
                    const SizedBox(width: 8),
                    Text(note.title.isEmpty && note.description.isEmpty ? "No note yet" : "Note updated"),
                  ],
                ),
                const Divider(height: 16),
                const Text("Links", style: TextStyle(fontWeight: FontWeight.w600)),
                TextField(
                  controller: _linkLabelController,
                  decoration: const InputDecoration(labelText: "Label"),
                ),
                TextField(
                  controller: _linkUrlController,
                  decoration: const InputDecoration(labelText: "URL"),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final label = _linkLabelController.text.trim();
                        final url = _linkUrlController.text.trim();
                        if (url.isEmpty) return;
                        itemLinks.addLink(selected.id, ItemLinkEntry(label: label, url: url));
                        _linkLabelController.clear();
                        _linkUrlController.clear();
                      },
                      child: const Text("Add Link"),
                    ),
                    const SizedBox(width: 8),
                    Text("Total: ${links.length}"),
                  ],
                ),
                if (links.isNotEmpty)
                  Column(
                    children: links.asMap().entries.map((entry) {
                      return Row(
                        children: [
                          Expanded(child: Text(entry.value.label.isEmpty ? entry.value.url : entry.value.label)),
                          IconButton(
                            onPressed: () => itemLinks.removeLinkAt(selected.id, entry.key),
                            icon: const Icon(Icons.delete, size: 18),
                            tooltip: 'Remove link',
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                Text("Selected: ${telemetry.selectionCount}"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchActionsSection() {
    return Consumer3<TelemetryProvider, NotesProvider, ItemLinksProvider>(
      builder: (context, telemetry, notes, itemLinks, _) {
        if (telemetry.selectionCount == 0) return const SizedBox.shrink();
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Batch Actions", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Selected: ${telemetry.selectionCount}"),
                TextField(
                  controller: _batchCategoryController,
                  decoration: const InputDecoration(labelText: "Set Category"),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final category = _batchCategoryController.text.trim();
                        if (category.isEmpty) return;
                        telemetry.updateItems(
                          telemetry.selectedIds,
                          (item) => item.copyWith(category: category),
                        );
                      },
                      child: const Text("Apply Category"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: telemetry.clearSelection,
                      child: const Text("Clear Selection"),
                    ),
                  ],
                ),
                const Divider(height: 16),
                const Text("Batch Notes", style: TextStyle(fontWeight: FontWeight.w600)),
                TextField(
                  controller: _batchNoteTitleController,
                  decoration: const InputDecoration(labelText: "Title"),
                ),
                TextField(
                  controller: _batchNoteDescriptionController,
                  decoration: const InputDecoration(labelText: "Description"),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () {
                    final title = _batchNoteTitleController.text;
                    final desc = _batchNoteDescriptionController.text;
                    if (title.trim().isEmpty && desc.trim().isEmpty) return;
                    for (final id in telemetry.selectedIds) {
                      notes.setNote(
                        id,
                        NoteEntry(
                          title: title,
                          description: desc,
                          category: '',
                          about: '',
                        ),
                      );
                    }
                  },
                  child: const Text("Apply Notes"),
                ),
                const Divider(height: 16),
                const Text("Batch Links", style: TextStyle(fontWeight: FontWeight.w600)),
                TextField(
                  controller: _batchLinkLabelController,
                  decoration: const InputDecoration(labelText: "Label"),
                ),
                TextField(
                  controller: _batchLinkUrlController,
                  decoration: const InputDecoration(labelText: "URL"),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: () {
                    final label = _batchLinkLabelController.text.trim();
                    final url = _batchLinkUrlController.text.trim();
                    if (url.isEmpty) return;
                    for (final id in telemetry.selectedIds) {
                      itemLinks.addLink(id, ItemLinkEntry(label: label, url: url));
                    }
                  },
                  child: const Text("Apply Links"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewPresetsSection() {
    return Consumer4<ViewPresetProvider, AppState, TelemetryProvider, AlarmProvider>(
      builder: (context, presets, appState, telemetry, alarms, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("View Presets", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _presetNameController,
                  decoration: const InputDecoration(labelText: "Preset name"),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final name = _presetNameController.text.trim();
                        if (name.isEmpty) return;
                        presets.savePreset(
                          ViewPreset(
                            name: name,
                            createdAt: DateTime.now(),
                            appState: appState.toSettingsJson(),
                            telemetry: telemetry.toSettingsJson(),
                            alarms: alarms.toSettingsJson(),
                          ),
                        );
                        _viewPresetNameController.clear();
                      },
                      child: const Text("Save"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: presets.presets.isEmpty
                          ? null
                          : () {
                              final latest = presets.presets.first;
                              appState.applySettingsJson(latest.appState);
                              telemetry.applySettingsJson(latest.telemetry);
                              alarms.applySettingsJson(latest.alarms);
                            },
                      child: const Text("Apply Latest"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (presets.presets.isEmpty) const Text("No presets yet."),
                if (presets.presets.isNotEmpty)
                  Column(
                    children: presets.presets.map((preset) {
                      return Row(
                        children: [
                          Expanded(child: Text(preset.name)),
                          IconButton(
                            onPressed: () {
                              appState.applySettingsJson(preset.appState);
                              telemetry.applySettingsJson(preset.telemetry);
                              alarms.applySettingsJson(preset.alarms);
                            },
                            icon: const Icon(Icons.play_arrow, size: 18),
                            tooltip: 'Apply preset',
                          ),
                          IconButton(
                            onPressed: () => presets.deletePreset(preset.name),
                            icon: const Icon(Icons.delete, size: 18),
                            tooltip: 'Delete preset',
                          ),
                        ],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticsSection() {
    return Consumer2<TelemetryProvider, AlarmProvider>(
      builder: (context, telemetry, alarms, _) {
        final telemetryIssues = telemetry.validateItems();
        final alarmIssues = alarms.validateAlarms(telemetry.items);
        final issues = [...telemetryIssues, ...alarmIssues];
        final errors = issues.where((e) => e.severity == DiagnosticSeverity.error).length;
        final warnings = issues.where((e) => e.severity == DiagnosticSeverity.warning).length;
        final infos = issues.where((e) => e.severity == DiagnosticSeverity.info).length;
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Diagnostics", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Errors: $errors  Warnings: $warnings  Info: $infos"),
                const SizedBox(height: 6),
                if (issues.isEmpty) const Text("No issues detected."),
                if (issues.isNotEmpty)
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      itemCount: issues.length,
                      itemBuilder: (context, index) {
                        final issue = issues[index];
                        final color = issue.severity == DiagnosticSeverity.error
                            ? Colors.red
                            : (issue.severity == DiagnosticSeverity.warning ? Colors.orange : Colors.blueGrey);
                        return ListTile(
                          dense: true,
                          title: Text(
                            issue.message,
                            style: TextStyle(color: color, fontSize: 12),
                          ),
                          onTap: issue.itemId == null
                              ? null
                              : () {
                                  final item = telemetry.items.firstWhere(
                                    (e) => e.id == issue.itemId,
                                    orElse: () => telemetry.items.isEmpty ? const TelemetryItem(id: '', title: '', x: 0, y: 0, category: '') : telemetry.items.first,
                                  );
                                  if (item.id.isNotEmpty) {
                                    telemetry.selectItem(item);
                                    context.read<AppState>().setFocusTarget(Offset(item.x, item.y), lock: true);
                                    context.read<AppState>().requestFocus(Offset(item.x, item.y), includeMimic: true);
                                  }
                                },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSnapshotHistorySection() {
    return Consumer<SupabaseProvider>(
      builder: (context, supabase, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Snapshot History", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: _snapshotLabelController,
                  decoration: const InputDecoration(labelText: "Snapshot label"),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: !supabase.isReady
                          ? null
                          : () async {
                              final label = _snapshotLabelController.text.trim();
                              final ok = await supabase.saveSnapshotVersion(
                                label: label.isEmpty ? 'Snapshot' : label,
                                appState: context.read<AppState>(),
                                telemetry: context.read<TelemetryProvider>(),
                                alarms: context.read<AlarmProvider>(),
                                links: context.read<LinkProvider>(),
                                itemLinks: context.read<ItemLinksProvider>(),
                                drawings: context.read<DrawingProvider>(),
                                texts: context.read<TextProvider>(),
                                notes: context.read<NotesProvider>(),
                                media: context.read<MediaProvider>(),
                                history: context.read<HistoryProvider>(),
                              );
                              if (!mounted) return;
                              setState(() => _snapshotStatus = ok ? 'Snapshot saved.' : 'Snapshot failed.');
                              _refreshSnapshots(supabase);
                            },
                      child: const Text("Save Version"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: !supabase.isReady ? null : () => _refreshSnapshots(supabase),
                      child: const Text("Refresh"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_snapshotStatus),
                const SizedBox(height: 8),
                if (_snapshotList.isEmpty) const Text("No snapshots found."),
                if (_snapshotList.isNotEmpty)
                  Column(
                    children: _snapshotList.map((snap) {
                      return Row(
                        children: [
                          Expanded(child: Text("${snap.label} (${snap.createdAt.toLocal()})")),
                          IconButton(
                            onPressed: () => _restoreSnapshotById(snap.id),
                            icon: const Icon(Icons.restore, size: 18),
                            tooltip: 'Restore',
                          ),
                          Checkbox(
                            value: _compareSnapshotA == snap.id,
                            onChanged: (_) {
                              setState(() => _compareSnapshotA = snap.id);
                            },
                          ),
                          Checkbox(
                            value: _compareSnapshotB == snap.id,
                            onChanged: (_) {
                              setState(() => _compareSnapshotB = snap.id);
                            },
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: (_compareSnapshotA == null || _compareSnapshotB == null || _compareSnapshotA == _compareSnapshotB)
                      ? null
                      : () async {
                          final a = await supabase.fetchSnapshotById(_compareSnapshotA!);
                          final b = await supabase.fetchSnapshotById(_compareSnapshotB!);
                          if (a == null || b == null) return;
                          setState(() {
                            _snapshotDiff = _diffSnapshot(a, b);
                          });
                        },
                  child: const Text("Compare Selected"),
                ),
                if (_snapshotDiff.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_snapshotDiff),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarkerSettingsSection() {
    return Consumer<TelemetryProvider>(
      builder: (context, telemetry, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Marker Settings", style: TextStyle(fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text("Show Markers"),
                  value: telemetry.showMarkers,
                  onChanged: telemetry.setShowMarkers,
                  dense: true,
                ),
                DropdownButtonFormField<String>(
                  value: telemetry.markerStyle,
                  decoration: const InputDecoration(labelText: "Marker Style"),
                  items: const [
                    DropdownMenuItem(value: 'static', child: Text("Static")),
                    DropdownMenuItem(value: 'invisible', child: Text("Invisible")),
                    DropdownMenuItem(value: 'pulsing', child: Text("Pulsing")),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    telemetry.setMarkerStyle(value);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationSection() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Navigation", style: TextStyle(fontWeight: FontWeight.bold)),
                const Text("Main Zoom", style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        appState.setMainZoom(appState.mainZoom * 1.1);
                        final focus = appState.focusLocked ? appState.focusTarget : null;
                        if (focus != null) {
                          appState.requestFocus(focus, includeMimic: true);
                        }
                      },
                      child: const Text("Zoom In"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        appState.setMainZoom(appState.mainZoom / 1.1);
                        final focus = appState.focusLocked ? appState.focusTarget : null;
                        if (focus != null) {
                          appState.requestFocus(focus, includeMimic: true);
                        }
                      },
                      child: const Text("Zoom Out"),
                    ),
                    OutlinedButton(
                      onPressed: appState.resetMainView,
                      child: const Text("Reset Main"),
                    ),
                    OutlinedButton(
                      onPressed: appState.resetMainSplitRatio,
                      child: const Text("Reset Split"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  title: const Text("Link Main + Mimic Zoom"),
                  value: appState.linkZoom,
                  onChanged: appState.setLinkZoom,
                  dense: true,
                ),
                const SizedBox(height: 6),
                const Text("Mimic Zoom", style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        appState.setMimicZoom(appState.mimicZoom * 1.1);
                        final focus = appState.focusLocked ? appState.focusTarget : null;
                        if (focus != null) {
                          appState.requestFocus(focus, includeMimic: true);
                        }
                      },
                      child: const Text("Zoom In"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        appState.setMimicZoom(appState.mimicZoom / 1.1);
                        final focus = appState.focusLocked ? appState.focusTarget : null;
                        if (focus != null) {
                          appState.requestFocus(focus, includeMimic: true);
                        }
                      },
                      child: const Text("Zoom Out"),
                    ),
                    OutlinedButton(
                      onPressed: appState.resetMimicView,
                      child: const Text("Reset Mimic"),
                    ),
                    OutlinedButton(
                      onPressed: appState.toggleTimeline,
                      child: Text(appState.isTimelineVisible ? "Hide Timeline" : "Show Timeline"),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Lock Focus to Selection"),
                  value: appState.focusLocked,
                  onChanged: appState.setFocusLocked,
                  dense: true,
                ),
                const SizedBox(height: 4),
                const Text("Auto Pan Offset", style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  "Main base: ${(appState.mainFocusBaseOffset.dx * 100).toStringAsFixed(0)}% x "
                  "${(appState.mainFocusBaseOffset.dy * 100).toStringAsFixed(0)}%",
                ),
                Text("Main X adjust: ${(appState.mainFocusAdjust.dx * 100).toStringAsFixed(0)}%"),
                Slider(
                  value: appState.mainFocusAdjust.dx,
                  min: -0.45,
                  max: 0.45,
                  onChanged: (value) {
                    appState.setMainFocusOffset(Offset(value, appState.mainFocusAdjust.dy));
                  },
                ),
                Text("Main Y adjust: ${(appState.mainFocusAdjust.dy * 100).toStringAsFixed(0)}%"),
                Slider(
                  value: appState.mainFocusAdjust.dy,
                  min: -0.45,
                  max: 0.45,
                  onChanged: (value) {
                    appState.setMainFocusOffset(Offset(appState.mainFocusAdjust.dx, value));
                  },
                ),
                Text(
                  "Mimic base: ${(appState.mimicFocusBaseOffset.dx * 100).toStringAsFixed(0)}% x "
                  "${(appState.mimicFocusBaseOffset.dy * 100).toStringAsFixed(0)}%",
                ),
                Text("Mimic X adjust: ${(appState.mimicFocusAdjust.dx * 100).toStringAsFixed(0)}%"),
                Slider(
                  value: appState.mimicFocusAdjust.dx,
                  min: -0.45,
                  max: 0.45,
                  onChanged: (value) {
                    appState.setMimicFocusOffset(Offset(value, appState.mimicFocusAdjust.dy));
                  },
                ),
                Text("Mimic Y adjust: ${(appState.mimicFocusAdjust.dy * 100).toStringAsFixed(0)}%"),
                Slider(
                  value: appState.mimicFocusAdjust.dy,
                  min: -0.45,
                  max: 0.45,
                  onChanged: (value) {
                    appState.setMimicFocusOffset(Offset(appState.mimicFocusAdjust.dx, value));
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: appState.resetFocusOffsets,
                    child: const Text("Reset Pan Offset"),
                  ),
                ),
                const SizedBox(height: 4),
                Consumer<TelemetryProvider>(
                  builder: (context, telemetry, _) {
                    return Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: telemetry.items.isEmpty
                              ? null
                              : () {
                                  final item = telemetry.selectPrevious();
                                  if (item != null) {
                                    appState.setFocusTarget(Offset(item.x, item.y), lock: true);
                                    appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
                                  }
                                },
                          child: const Text("Prev Item"),
                        ),
                        OutlinedButton(
                          onPressed: telemetry.items.isEmpty
                              ? null
                              : () {
                                  final item = telemetry.selectNext();
                                  if (item != null) {
                                    appState.setFocusTarget(Offset(item.x, item.y), lock: true);
                                    appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
                                  }
                                },
                          child: const Text("Next Item"),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(onPressed: () => appState.panMain(const Offset(50, 0)), icon: const Icon(Icons.arrow_left)),
                    Column(
                      children: [
                        IconButton(onPressed: () => appState.panMain(const Offset(0, 50)), icon: const Icon(Icons.arrow_drop_up)),
                        IconButton(onPressed: () => appState.panMain(const Offset(0, -50)), icon: const Icon(Icons.arrow_drop_down)),
                      ],
                    ),
                    IconButton(onPressed: () => appState.panMain(const Offset(-50, 0)), icon: const Icon(Icons.arrow_right)),
                  ],
                ),
                SwitchListTile(
                  title: const Text("Keyboard Panning"),
                  value: appState.keyboardPanEnabled,
                  onChanged: appState.setKeyboardPanEnabled,
                  dense: true,
                ),
                SwitchListTile(
                  title: const Text("Collapse Mimic"),
                  value: appState.isMimicCollapsed,
                  onChanged: (_) => appState.toggleMimicCollapse(),
                  dense: true,
                ),
                Text("Max Zoom: ${appState.maxZoom.toStringAsFixed(1)}"),
                Slider(
                  value: appState.maxZoom,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: appState.setMaxZoom,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundSection() {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Background Colors", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text("Main: "),
                    _colorDot(() => appState.setMainBackgroundColor(Colors.white), Colors.white),
                    _colorDot(() => appState.setMainBackgroundColor(Colors.grey.shade200), Colors.grey.shade200),
                    _colorDot(() => appState.setMainBackgroundColor(Colors.black), Colors.black),
                  ],
                ),
                Row(
                  children: [
                    const Text("Mimic: "),
                    _colorDot(() => appState.setMimicBackgroundColor(Colors.white), Colors.white),
                    _colorDot(() => appState.setMimicBackgroundColor(Colors.grey.shade200), Colors.grey.shade200),
                    _colorDot(() => appState.setMimicBackgroundColor(Colors.black), Colors.black),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlarmsSection() {
    return Consumer2<AlarmProvider, TelemetryProvider>(
      builder: (context, alarms, telemetry, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Alarms", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _pickAlarmFile, child: const Text("Load Alarm JSON")),
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: telemetry.items.isEmpty ? null : () => alarms.checkMatches(telemetry.items),
                  child: const Text("Check Alarms"),
                ),
                Text("Matches: ${alarms.matches.length}"),
                SwitchListTile(
                  title: const Text("Show Alarm Markers"),
                  value: alarms.showMarkers,
                  onChanged: (_) => alarms.toggleMarkers(),
                  dense: true,
                ),
                Container(
                  height: 100,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                  child: ListView.builder(
                    itemCount: alarms.matches.length,
                    itemBuilder: (context, index) {
                      final item = alarms.matches[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.title),
                                onTap: () {
                                  context.read<TelemetryProvider>().selectItem(item);
                                  context.read<AppState>().setFocusTarget(
                                        Offset(item.x, item.y),
                                        lock: true,
                                      );
                                  context.read<AppState>().requestFocus(
                                        Offset(item.x, item.y),
                                        includeMimic: true,
                                      );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataFetchSection() {
    return _glassPanel(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Data Fetch", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _dataFetchUrlController,
              decoration: const InputDecoration(labelText: "Base URL"),
            ),
            TextField(
              controller: _dataFetchKeyController,
              decoration: const InputDecoration(labelText: "Auth Key"),
            ),
            SwitchListTile(
              title: const Text("Activate Data Fetch"),
              value: _dataFetchActive,
              onChanged: (val) => setState(() => _dataFetchActive = val),
              dense: true,
            ),
            Text(_fetchStatus),
            ElevatedButton(
              onPressed: !_dataFetchActive ? null : _fetchAllData,
              child: const Text("Fetch Now"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Consumer2<NotesProvider, TelemetryProvider>(
      builder: (context, notes, telemetry, _) {
        final selected = telemetry.selectedItem;
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Additional Notes", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _noteTitleController, decoration: const InputDecoration(labelText: "Title")),
                TextField(controller: _noteDescriptionController, decoration: const InputDecoration(labelText: "Description")),
                TextField(controller: _noteCategoryController, decoration: const InputDecoration(labelText: "Category")),
                TextField(controller: _noteAboutController, decoration: const InputDecoration(labelText: "About")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: selected == null
                          ? null
                          : () => notes.setNote(
                                selected.id,
                                NoteEntry(
                                  title: _noteTitleController.text,
                                  description: _noteDescriptionController.text,
                                  category: _noteCategoryController.text,
                                  about: _noteAboutController.text,
                                ),
                              ),
                      child: const Text("Save Note"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result == null || result.files.single.path == null) return;
                        final content = await File(result.files.single.path!).readAsString();
                        notes.loadFromJsonString(content);
                      },
                      child: const Text("Load Notes"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _saveJsonToFile('notes.json', notes.toJsonString()),
                      child: const Text("Save Notes"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaSection() {
    return Consumer2<MediaProvider, TelemetryProvider>(
      builder: (context, media, telemetry, _) {
        final selected = telemetry.selectedItem;
        final imageEntry = selected == null ? MediaEntry.empty() : media.imageFor(selected.id);
        final videoEntry = selected == null ? MediaEntry.empty() : media.videoFor(selected.id);
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Images", style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: _imageTitleController, decoration: const InputDecoration(labelText: "Title")),
                TextField(controller: _imageDescriptionController, decoration: const InputDecoration(labelText: "Description")),
                TextField(controller: _imageCategoryController, decoration: const InputDecoration(labelText: "Category")),
                TextField(controller: _imageAboutController, decoration: const InputDecoration(labelText: "About")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: selected == null ? null : () => _pickImage(media, selected.id),
                      child: const Text("Load Image"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result == null || result.files.single.path == null) return;
                        final content = await File(result.files.single.path!).readAsString();
                        media.loadImagesFromJsonString(content);
                      },
                      child: const Text("Load Image JSON"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _saveJsonToFile('image_data.json', media.imagesToJsonString()),
                      child: const Text("Save Image JSON"),
                    ),
                  ],
                ),
                const Divider(height: 20),
                const Text("Videos", style: TextStyle(fontWeight: FontWeight.bold)),
                if (videoEntry.data.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("Video loaded (${(videoEntry.data.length / 1024).toStringAsFixed(1)} KB)"),
                  ),
                TextField(controller: _videoTitleController, decoration: const InputDecoration(labelText: "Title")),
                TextField(controller: _videoDescriptionController, decoration: const InputDecoration(labelText: "Description")),
                TextField(controller: _videoCategoryController, decoration: const InputDecoration(labelText: "Category")),
                TextField(controller: _videoAboutController, decoration: const InputDecoration(labelText: "About")),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: selected == null ? null : () => _pickVideo(media, selected.id),
                      child: const Text("Load Video"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result == null || result.files.single.path == null) return;
                        final content = await File(result.files.single.path!).readAsString();
                        media.loadVideosFromJsonString(content);
                      },
                      child: const Text("Load Video JSON"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _saveJsonToFile('video_data.json', media.videosToJsonString()),
                      child: const Text("Save Video JSON"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistorySection() {
    return Consumer<HistoryProvider>(
      builder: (context, history, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("History", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    itemCount: history.entries.length,
                    itemBuilder: (context, index) {
                      final entry = history.entries[index];
                      return Text("${entry.timestamp.toLocal()} - ${entry.action}");
                    },
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton(onPressed: history.clear, child: const Text("Clear")),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _saveJsonToFile('history.json', history.toJsonString()),
                      child: const Text("Save"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result == null || result.files.single.path == null) return;
                        final content = await File(result.files.single.path!).readAsString();
                        history.loadFromJsonString(content);
                      },
                      child: const Text("Load"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectSection() {
    return _glassPanel(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Project Management", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                ElevatedButton(onPressed: _saveProject, child: const Text("Save Project")),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _loadProject, child: const Text("Load Project")),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _exportPack, child: const Text("Export Pack")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatbotSection() {
    return Consumer3<ChatbotProvider, TelemetryProvider, AppState>(
      builder: (context, chatbot, telemetry, appState, _) {
        return _glassPanel(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Chatbot", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: chatbot.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatbot.messages[index];
                      return Text("${msg.isUser ? 'You' : 'Gyro'}: ${msg.text}");
                    },
                  ),
                ),
                TextField(
                  controller: _chatInputController,
                  decoration: const InputDecoration(labelText: "Enter command..."),
                  onSubmitted: (val) async {
                    await chatbot.processCommand(
                      val,
                      appState: appState,
                      telemetry: telemetry,
                      apd: context.read<APDProvider>(),
                      history: context.read<HistoryProvider>(),
                      openai: context.read<OpenAiProvider>(),
                      alarms: context.read<AlarmProvider>(),
                    );
                    _chatInputController.clear();
                  },
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await chatbot.processCommand(
                          _chatInputController.text,
                          appState: appState,
                          telemetry: telemetry,
                          apd: context.read<APDProvider>(),
                          history: context.read<HistoryProvider>(),
                          openai: context.read<OpenAiProvider>(),
                          alarms: context.read<AlarmProvider>(),
                        );
                        _chatInputController.clear();
                      },
                      child: const Text("Send"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: chatbot.clearChat, child: const Text("Clear")),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _assetDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required bool isLoading,
    required ValueChanged<String?> onChanged,
  }) {
    final enabled = items.isNotEmpty && !isLoading;
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      items: items
          .map(
            (asset) => DropdownMenuItem(
              value: asset,
              child: Text(_labelForAsset(asset)),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      hint: Text(items.isEmpty ? "No assets found" : "Select asset"),
    );
  }

  String _formatSize(Size? size) {
    if (size == null) return "unknown";
    return "${size.width.toStringAsFixed(0)} x ${size.height.toStringAsFixed(0)} px";
  }

  Widget _colorDot(VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
      ),
    );
  }
}
