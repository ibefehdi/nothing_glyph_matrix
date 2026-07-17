/// Formats rest countdown seconds for Glyph Matrix text frames.
String formatRestCountdown(int seconds, {bool compact = false}) {
  final safe = seconds < 0 ? 0 : seconds;
  final m = safe ~/ 60;
  final s = safe % 60;
  if (compact && m <= 0) return '$s';
  return '$m:${s.toString().padLeft(2, '0')}';
}
