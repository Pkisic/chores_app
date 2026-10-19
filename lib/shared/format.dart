/// The single duration display format used across the app.
///
/// Durations are stored and passed around in seconds everywhere; this is the
/// only place that turns them into text: `40s`, `5m 07s`, `1h 05m 30s`.
class DurationFormat {
  DurationFormat._();

  static String format(int totalSeconds) {
    final s = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final seconds = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) return '${hours}h ${two(minutes)}m ${two(seconds)}s';
    if (minutes > 0) return '${minutes}m ${two(seconds)}s';
    return '${seconds}s';
  }
}
