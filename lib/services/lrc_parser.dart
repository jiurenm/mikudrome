import '../models/timed_lyric_line.dart';

final RegExp _timeTagPattern = RegExp(r'\[(\d+):(\d{2})(?:\.(\d{1,3}))?\]');
final RegExp _metadataTagPattern = RegExp(r'^\[[A-Za-z]+:.*\]$');

List<TimedLyricLine> parseLrcLyrics(String raw) {
  if (raw.trim().isEmpty) return const [];

  final groupedTexts = <int, List<String>>{};
  final lines = raw.split(RegExp(r'\r?\n'));

  for (final rawLine in lines) {
    final trimmedLine = rawLine.trim();
    if (trimmedLine.isEmpty || _metadataTagPattern.hasMatch(trimmedLine)) {
      continue;
    }

    final matches = _timeTagPattern.allMatches(trimmedLine).toList();
    if (matches.isEmpty) {
      continue;
    }

    final text = trimmedLine.replaceAll(_timeTagPattern, '').trim();
    if (text.isEmpty) {
      continue;
    }

    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '');
      final seconds = int.tryParse(match.group(2) ?? '');
      final fraction = match.group(3) ?? '';
      if (minutes == null || seconds == null) {
        continue;
      }

      final milliseconds = switch (fraction.length) {
        0 => 0,
        1 => int.parse(fraction) * 100,
        2 => int.parse(fraction) * 10,
        _ => int.parse(fraction.substring(0, 3)),
      };

      final start = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
      groupedTexts.putIfAbsent(start.inMilliseconds, () => <String>[]).add(text);
    }
  }

  final result = groupedTexts.entries.map((entry) {
    return TimedLyricLine(
      start: Duration(milliseconds: entry.key),
      texts: List<String>.unmodifiable(entry.value),
    );
  }).toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  return result;
}

bool hasTimedLyrics(String raw) => parseLrcLyrics(raw).isNotEmpty;

int findActiveLyricIndex(
  List<TimedLyricLine> lines,
  Duration position,
) {
  if (lines.isEmpty || position < lines.first.start) {
    return -1;
  }

  var low = 0;
  var high = lines.length - 1;
  var answer = -1;

  while (low <= high) {
    final mid = low + ((high - low) >> 1);
    if (lines[mid].start <= position) {
      answer = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return answer;
}
