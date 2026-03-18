class TimedLyricLine {
  const TimedLyricLine({
    required this.start,
    required this.texts,
  });

  final Duration start;
  final List<String> texts;
}
