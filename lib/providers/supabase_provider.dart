import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/env_loader.dart';
import 'app_state.dart';
import 'alarm_provider.dart';
import 'drawing_provider.dart';
import 'history_provider.dart';
import 'link_provider.dart';
import 'media_provider.dart';
import 'item_links_provider.dart';
import 'notes_provider.dart';
import 'telemetry_provider.dart';
import 'text_provider.dart';
import '../models/portable_link_set.dart';

enum SupabaseStatus { disconnected, connecting, ready, error }

class SnapshotMeta {
  final String id;
  final String label;
  final DateTime createdAt;

  const SnapshotMeta({
    required this.id,
    required this.label,
    required this.createdAt,
  });
}

class LinkSetMeta {
  final String id;
  final String label;
  final DateTime createdAt;

  const LinkSetMeta({
    required this.id,
    required this.label,
    required this.createdAt,
  });
}

class SupabaseProvider with ChangeNotifier {
  SupabaseStatus _status = SupabaseStatus.disconnected;
  String? _lastError;
  String _namespace = 'default';
  String _storageBucket = 'app_files';
  User? _user;

  SupabaseStatus get status => _status;
  String? get lastError => _lastError;
  bool get isReady => _status == SupabaseStatus.ready;
  String get namespace => _namespace;
  bool get isAuthenticated => _user != null;
  String? get userEmail => _user?.email;
  String? get userId => _user?.id;
  bool get isAnonymous => _user?.isAnonymous ?? false;

  Future<void> initialize() async {
    if (_status == SupabaseStatus.connecting || _status == SupabaseStatus.ready) return;
    _status = SupabaseStatus.connecting;
    _lastError = null;
    notifyListeners();
    try {
      final config = await EnvConfig.loadFromAssets();
      if (config == null) {
        _status = SupabaseStatus.disconnected;
        notifyListeners();
        return;
      }
      await Supabase.initialize(url: config.url, anonKey: config.anonKey);
      _namespace = config.namespace;
      _storageBucket = config.storageBucket;
      _user = Supabase.instance.client.auth.currentUser;
      _status = SupabaseStatus.ready;
      notifyListeners();
    } catch (e) {
      _status = SupabaseStatus.error;
      _lastError = e.toString();
      notifyListeners();
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _syncUser() {
    final client = _client;
    if (client == null) return;
    _user = client.auth.currentUser;
  }

  Future<void> refreshSession() async {
    final client = _client;
    if (client == null) return;
    _user = client.auth.currentUser;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    final client = _client;
    if (client == null || !isReady) return false;
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      _syncUser();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInAnonymously() async {
    final client = _client;
    if (client == null || !isReady) return false;
    try {
      await client.auth.signInAnonymously();
      _syncUser();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    final client = _client;
    if (client == null || !isReady) return false;
    try {
      await client.auth.signUp(email: email, password: password);
      _syncUser();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null || !isReady) return;
    await client.auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<bool> ping() async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('app_snapshots').select('namespace').limit(1);
      return true;
    } catch (e) {
      _status = SupabaseStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveSnapshot({
    required AppState appState,
    required TelemetryProvider telemetry,
    required AlarmProvider alarms,
    required LinkProvider links,
    required ItemLinksProvider itemLinks,
    required DrawingProvider drawings,
    required TextProvider texts,
    required NotesProvider notes,
    required MediaProvider media,
    required HistoryProvider history,
  }) async {
    final client = _client;
    if (client == null || !isReady) return false;
    try {
      final userId = _user?.id;
      final payload = {
        'user_id': userId,
        'namespace': _namespace,
        'settings': appState.toSettingsJson(),
        'telemetry': jsonDecode(telemetry.toJsonString()),
        'alarms': jsonDecode(alarms.toJsonString()),
        'links': jsonDecode(links.exportJson()),
        'item_links': jsonDecode(itemLinks.toJsonString()),
        'drawings': jsonDecode(drawings.toJsonString()),
        'texts': jsonDecode(texts.toJsonString()),
        'notes': jsonDecode(notes.toJsonString()),
        'media_images': jsonDecode(media.imagesToJsonString()),
        'media_videos': jsonDecode(media.videosToJsonString()),
        'history': jsonDecode(history.toJsonString()),
        'telemetry_settings': telemetry.toSettingsJson(),
        'alarm_settings': alarms.toSettingsJson(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client.from('app_snapshots').upsert(payload);
      return true;
    } catch (e) {
      _status = SupabaseStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> fetchSnapshot({
    required AppState appState,
    required TelemetryProvider telemetry,
    required AlarmProvider alarms,
    required LinkProvider links,
    required ItemLinksProvider itemLinks,
    required DrawingProvider drawings,
    required TextProvider texts,
    required NotesProvider notes,
    required MediaProvider media,
    required HistoryProvider history,
  }) async {
    final client = _client;
    if (client == null || !isReady) return false;
    try {
      var query = client.from('app_snapshots').select();
      if (_user?.id != null) {
        query = query.eq('user_id', _user!.id);
      } else {
        query = query.eq('namespace', _namespace);
      }
      final result = await query.order('updated_at', ascending: false).limit(1).maybeSingle();
      if (result == null) return false;
      final settings = result['settings'];
      if (settings is Map<String, dynamic>) {
        appState.applySettingsJson(settings);
      }
      _applyListJson(telemetry.loadFromJsonString, result['telemetry']);
      _applyListJson(alarms.loadFromJsonString, result['alarms']);
      if (result['links'] != null) {
        links.importJson(jsonEncode(result['links']));
      }
      if (result['item_links'] != null) {
        itemLinks.loadFromJsonString(jsonEncode(result['item_links']));
      }
      _applyListJson(drawings.loadFromJsonString, result['drawings']);
      _applyListJson(texts.loadFromJsonString, result['texts']);
      _applyListJson(notes.loadFromJsonString, result['notes']);
      _applyListJson(media.loadImagesFromJsonString, result['media_images']);
      _applyListJson(media.loadVideosFromJsonString, result['media_videos']);
      _applyListJson(history.loadFromJsonString, result['history']);
      if (result['telemetry_settings'] is Map<String, dynamic>) {
        telemetry.applySettingsJson(Map<String, dynamic>.from(result['telemetry_settings']));
      }
      if (result['alarm_settings'] is Map<String, dynamic>) {
        alarms.applySettingsJson(Map<String, dynamic>.from(result['alarm_settings']));
      }
      return true;
    } catch (e) {
      _status = SupabaseStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _applyListJson(void Function(String) loader, dynamic value) {
    if (value == null) return;
    loader(jsonEncode(value));
  }

  Future<bool> saveSnapshotVersion({
    required String label,
    required AppState appState,
    required TelemetryProvider telemetry,
    required AlarmProvider alarms,
    required LinkProvider links,
    required ItemLinksProvider itemLinks,
    required DrawingProvider drawings,
    required TextProvider texts,
    required NotesProvider notes,
    required MediaProvider media,
    required HistoryProvider history,
  }) async {
    final client = _client;
    if (client == null || !isReady) return false;
    try {
      final userId = _user?.id;
      final payload = {
        'user_id': userId,
        'namespace': _namespace,
        'label': label,
        'settings': appState.toSettingsJson(),
        'telemetry': jsonDecode(telemetry.toJsonString()),
        'alarms': jsonDecode(alarms.toJsonString()),
        'links': jsonDecode(links.exportJson()),
        'item_links': jsonDecode(itemLinks.toJsonString()),
        'drawings': jsonDecode(drawings.toJsonString()),
        'texts': jsonDecode(texts.toJsonString()),
        'notes': jsonDecode(notes.toJsonString()),
        'media_images': jsonDecode(media.imagesToJsonString()),
        'media_videos': jsonDecode(media.videosToJsonString()),
        'history': jsonDecode(history.toJsonString()),
        'telemetry_settings': telemetry.toSettingsJson(),
        'alarm_settings': alarms.toSettingsJson(),
        'created_at': DateTime.now().toIso8601String(),
      };
      await client.from('app_snapshot_history').insert(payload);
      return true;
    } catch (e) {
      _status = SupabaseStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<SnapshotMeta>> listSnapshots() async {
    final client = _client;
    if (client == null || !isReady) return [];
    try {
      var query = client.from('app_snapshot_history').select('id,label,created_at');
      if (_user?.id != null) {
        query = query.eq('user_id', _user!.id);
      } else {
        query = query.eq('namespace', _namespace);
      }
      final result = await query.order('created_at', ascending: false);
      if (result is! List) return [];
      return result
          .whereType<Map>()
          .map((row) {
            final id = row['id']?.toString() ?? '';
            final label = row['label']?.toString() ?? 'Snapshot';
            final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
            if (id.isEmpty) return null;
            return SnapshotMeta(id: id, label: label, createdAt: createdAt);
          })
          .whereType<SnapshotMeta>()
          .toList();
    } catch (e) {
      _status = SupabaseStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchSnapshotById(String id) async {
    final client = _client;
    if (client == null || !isReady) return null;
    try {
      final result = await client
          .from('app_snapshot_history')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (result is Map<String, dynamic>) {
        return result;
      }
      return null;
    } catch (e) {
      _status = SupabaseStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> uploadPortableLinks({
    required String label,
    required String mainSvg,
    required String mimicSvg,
    required String telemetryJson,
  }) async {
    final client = _client;
    final userId = _user?.id;
    if (client == null || !isReady || userId == null || isAnonymous) return false;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mainPath = '$userId/links/$timestamp-main.svg';
      final mimicPath = '$userId/links/$timestamp-mimic.svg';
      final telemetryPath = '$userId/links/$timestamp-telemetry.json';
      await client.storage.from(_storageBucket).uploadBinary(
            mainPath,
            Uint8List.fromList(utf8.encode(mainSvg)),
          );
      await client.storage.from(_storageBucket).uploadBinary(
            mimicPath,
            Uint8List.fromList(utf8.encode(mimicSvg)),
          );
      await client.storage.from(_storageBucket).uploadBinary(
            telemetryPath,
            Uint8List.fromList(utf8.encode(telemetryJson)),
          );
      await client.from('app_link_sets').insert({
        'user_id': userId,
        'namespace': _namespace,
        'label': label,
        'main_path': mainPath,
        'mimic_path': mimicPath,
        'telemetry_path': telemetryPath,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<PortableLinkSet?> fetchLatestPortableLinks() async {
    final client = _client;
    final userId = _user?.id;
    if (client == null || !isReady || userId == null || isAnonymous) return null;
    try {
      final row = await client
          .from('app_link_sets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final mainPath = row['main_path']?.toString() ?? '';
      final mimicPath = row['mimic_path']?.toString() ?? '';
      final telemetryPath = row['telemetry_path']?.toString() ?? '';
      if (mainPath.isEmpty || mimicPath.isEmpty || telemetryPath.isEmpty) return null;
      final mainBytes = await client.storage.from(_storageBucket).download(mainPath);
      final mimicBytes = await client.storage.from(_storageBucket).download(mimicPath);
      final telemetryBytes = await client.storage.from(_storageBucket).download(telemetryPath);
      return PortableLinkSet(
        label: row['label']?.toString() ?? 'Portable links',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
        mainSvgContent: utf8.decode(mainBytes),
        mimicSvgContent: utf8.decode(mimicBytes),
        telemetryJson: utf8.decode(telemetryBytes),
        mainPath: mainPath,
        mimicPath: mimicPath,
        telemetryPath: telemetryPath,
      );
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> applyLatestPortableLinks({
    required AppState appState,
    required TelemetryProvider telemetry,
  }) async {
    if (!isAuthenticated || isAnonymous) return false;
    final linkSet = await fetchLatestPortableLinks();
    if (linkSet == null) return false;
    appState.setMainSvgContent(linkSet.mainSvgContent);
    appState.setMimicSvgContent(linkSet.mimicSvgContent);
    telemetry.loadFromJsonString(linkSet.telemetryJson);
    appState.setMainViewOffset(Offset.zero);
    appState.setMimicViewOffset(Offset.zero);
    return true;
  }

  Future<List<LinkSetMeta>> listLinkSets() async {
    final client = _client;
    final userId = _user?.id;
    if (client == null || !isReady || userId == null || isAnonymous) return [];
    try {
      final result = await client
          .from('app_link_sets')
          .select('id,label,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (result is! List) return [];
      return result
          .whereType<Map>()
          .map((row) {
            final id = row['id']?.toString() ?? '';
            final label = row['label']?.toString() ?? 'Link set';
            final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
            if (id.isEmpty) return null;
            return LinkSetMeta(id: id, label: label, createdAt: createdAt);
          })
          .whereType<LinkSetMeta>()
          .toList();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<PortableLinkSet?> fetchPortableLinksById(String id) async {
    final client = _client;
    final userId = _user?.id;
    if (client == null || !isReady || userId == null || isAnonymous) return null;
    try {
      final row = await client
          .from('app_link_sets')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      final mainPath = row['main_path']?.toString() ?? '';
      final mimicPath = row['mimic_path']?.toString() ?? '';
      final telemetryPath = row['telemetry_path']?.toString() ?? '';
      if (mainPath.isEmpty || mimicPath.isEmpty || telemetryPath.isEmpty) return null;
      final mainBytes = await client.storage.from(_storageBucket).download(mainPath);
      final mimicBytes = await client.storage.from(_storageBucket).download(mimicPath);
      final telemetryBytes = await client.storage.from(_storageBucket).download(telemetryPath);
      return PortableLinkSet(
        label: row['label']?.toString() ?? 'Link set',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
        mainSvgContent: utf8.decode(mainBytes),
        mimicSvgContent: utf8.decode(mimicBytes),
        telemetryJson: utf8.decode(telemetryBytes),
        mainPath: mainPath,
        mimicPath: mimicPath,
        telemetryPath: telemetryPath,
      );
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> applyPortableLinksById({
    required String id,
    required AppState appState,
    required TelemetryProvider telemetry,
  }) async {
    if (!isAuthenticated || isAnonymous) return false;
    final linkSet = await fetchPortableLinksById(id);
    if (linkSet == null) return false;
    appState.setMainSvgContent(linkSet.mainSvgContent);
    appState.setMimicSvgContent(linkSet.mimicSvgContent);
    telemetry.loadFromJsonString(linkSet.telemetryJson);
    appState.setMainViewOffset(Offset.zero);
    appState.setMimicViewOffset(Offset.zero);
    return true;
  }
}
