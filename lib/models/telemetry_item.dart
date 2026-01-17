class TelemetryItem {
  final String id;
  final String title;
  final double x;
  final double y;
  final String category;
  final String pin;
  final String level;
  final String action;
  final String? about;
  final String? description;

  const TelemetryItem({
    required this.id,
    required this.title,
    required this.x,
    required this.y,
    required this.category,
    this.pin = '',
    this.level = '',
    this.action = '',
    this.about,
    this.description,
  });

  TelemetryItem copyWith({
    String? id,
    String? title,
    double? x,
    double? y,
    String? category,
    String? pin,
    String? level,
    String? action,
    String? about,
    String? description,
  }) {
    return TelemetryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      x: x ?? this.x,
      y: y ?? this.y,
      category: category ?? this.category,
      pin: pin ?? this.pin,
      level: level ?? this.level,
      action: action ?? this.action,
      about: about ?? this.about,
      description: description ?? this.description,
    );
  }

  factory TelemetryItem.fromJson(Map<String, dynamic> json) {
    return TelemetryItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      x: _toDouble(json['x']),
      y: _toDouble(json['y']),
      category: json['category']?.toString() ?? 'Uncategorized',
      pin: json['pin']?.toString() ?? '',
      level: json['level']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      about: json['about']?.toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'x': x,
      'y': y,
      'category': category,
      'pin': pin,
      'level': level,
      'action': action,
      'about': about,
      'description': description,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
