import 'dart:convert';
import 'package:flutter/foundation.dart';

class NoteEntry {
  final String title;
  final String description;
  final String category;
  final String about;

  const NoteEntry({
    required this.title,
    required this.description,
    required this.category,
    required this.about,
  });

  factory NoteEntry.empty() => const NoteEntry(title: '', description: '', category: '', about: '');

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'about': about,
      };

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    return NoteEntry(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      about: json['about']?.toString() ?? '',
    );
  }
}

class NotesProvider with ChangeNotifier {
  final Map<String, NoteEntry> _notes = {};

  NoteEntry noteFor(String id) => _notes[id] ?? NoteEntry.empty();

  void setNote(String id, NoteEntry entry) {
    _notes[id] = entry;
    notifyListeners();
  }

  void loadFromJsonString(String jsonString) {
    final data = jsonDecode(jsonString);
    if (data is! Map) {
      throw const FormatException('Notes JSON must be an object map.');
    }
    _notes.clear();
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _notes[key.toString()] = NoteEntry.fromJson(value);
      }
    });
    notifyListeners();
  }

  void clear() {
    _notes.clear();
    notifyListeners();
  }

  String toJsonString() {
    final map = _notes.map((key, value) => MapEntry(key, value.toJson()));
    return jsonEncode(map);
  }
}
