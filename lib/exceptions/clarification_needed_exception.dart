class ClarificationNeedException implements Exception {
  final String message;

  ClarificationNeedException(this.message);

  @override
  String toString() => message;
} 