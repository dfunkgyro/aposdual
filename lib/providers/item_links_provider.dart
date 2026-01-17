import 'dart:convert';
import 'package:flutter/foundation.dart';

class ItemLinkEntry {
  final String label;
  final String url;

  const ItemLinkEntry({required this.label, required this.url});

  Map<String, dynamic> toJson() => {
        'label': label,
        'url': url,
      };

  factory ItemLinkEntry.fromJson(Map<String, dynamic> json) {
    return ItemLinkEntry(
      label: json['label']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class ItemLinksProvider with ChangeNotifier {
  final Map<String, List<ItemLinkEntry>> _links = {};

  List<ItemLinkEntry> linksFor(String id) => List.unmodifiable(_links[id] ?? const []);

  void setLinks(String id, List<ItemLinkEntry> links) {
    _links[id] = List<ItemLinkEntry>.from(links);
    notifyListeners();
  }

  void addLink(String id, ItemLinkEntry entry) {
    final list = _links.putIfAbsent(id, () => []);
    list.add(entry);
    notifyListeners();
  }

  void removeLinkAt(String id, int index) {
    final list = _links[id];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _links.clear();
    notifyListeners();
  }

  String toJsonString() {
    final payload = _links.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()));
    return jsonEncode(payload);
  }

  void loadFromJsonString(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! Map) {
      throw const FormatException('Item links JSON must be an object map.');
    }
    _links.clear();
    data.forEach((key, value) {
      if (value is List) {
        _links[key.toString()] = value
            .whereType<Map>()
            .map((e) => ItemLinkEntry.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.url.isNotEmpty)
            .toList();
      }
    });
    notifyListeners();
  }
}
