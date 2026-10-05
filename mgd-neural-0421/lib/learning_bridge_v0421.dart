/// Runtime hook shared by teaching, imports and external documents.
/// Disabled in standalone tools/tests unless their owner explicitly enables it.
class LearningBridge421 {
  static Future<void> Function(String text, String source)? observe;

  static Future<void> external(String text, String source) async {
    if (text.trim().isEmpty) return;
    await observe?.call(text, source);
  }
}
