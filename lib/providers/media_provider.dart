import 'dart:convert';
import 'package:flutter/foundation.dart';

class MediaEntry {
  final String data; // base64
  final String title;
  final String description;
  final String category;
  final String about;

  const MediaEntry({
    required this.data,
    required this.title,
    required this.description,
    required this.category,
    required this.about,
  });

  factory MediaEntry.empty() => const MediaEntry(
        data: '',
        title: '',
        description: '',
        category: '',
        about: '',
      );

  Map<String, dynamic> toJson() => {
        'data': data,
        'title': title,
        'description': description,
        'category': category,
        'about': about,
      };

  factory MediaEntry.fromJson(Map<String, dynamic> json) {
    return MediaEntry(
      data: json['data']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      about: json['about']?.toString() ?? '',
    );
  }
}

class MediaProvider with ChangeNotifier {
  final Map<String, MediaEntry> _images = {};
  final Map<String, MediaEntry> _videos = {};

  MediaEntry imageFor(String id) => _images[id] ?? MediaEntry.empty();
  MediaEntry videoFor(String id) => _videos[id] ?? MediaEntry.empty();

  void setImage(String id, MediaEntry entry) {
    _images[id] = entry;
    notifyListeners();
  }

  void setVideo(String id, MediaEntry entry) {
    _videos[id] = entry;
    notifyListeners();
  }

  void loadImagesFromJsonString(String jsonString) {
    _images
      ..clear()
      ..addAll(_decodeMap(jsonString));
    notifyListeners();
  }

  void loadVideosFromJsonString(String jsonString) {
    _videos
      ..clear()
      ..addAll(_decodeMap(jsonString));
    notifyListeners();
  }

  void clearAll() {
    _images.clear();
    _videos.clear();
    notifyListeners();
  }

  String imagesToJsonString() {
    final map = _images.map((key, value) => MapEntry(key, value.toJson()));
    return jsonEncode(map);
  }

  String videosToJsonString() {
    final map = _videos.map((key, value) => MapEntry(key, value.toJson()));
    return jsonEncode(map);
  }

  Map<String, MediaEntry> _decodeMap(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! Map) {
      throw const FormatException('Media JSON must be an object map.');
    }
    final map = <String, MediaEntry>{};
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        map[key.toString()] = MediaEntry.fromJson(value);
      }
    });
    return map;
  }
}
