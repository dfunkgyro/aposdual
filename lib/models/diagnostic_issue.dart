enum DiagnosticSeverity { info, warning, error }

class DiagnosticIssue {
  final DiagnosticSeverity severity;
  final String source;
  final String message;
  final String? itemId;

  const DiagnosticIssue({
    required this.severity,
    required this.source,
    required this.message,
    this.itemId,
  });
}
