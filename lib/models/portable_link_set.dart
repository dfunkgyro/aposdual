class PortableLinkSet {
  final String label;
  final DateTime createdAt;
  final String mainSvgContent;
  final String mimicSvgContent;
  final String telemetryJson;
  final String mainPath;
  final String mimicPath;
  final String telemetryPath;

  const PortableLinkSet({
    required this.label,
    required this.createdAt,
    required this.mainSvgContent,
    required this.mimicSvgContent,
    required this.telemetryJson,
    required this.mainPath,
    required this.mimicPath,
    required this.telemetryPath,
  });
}
