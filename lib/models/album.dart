/// Placeholder album for UI; can be wired to backend later.
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.producerName,
    required this.year,
    required this.trackCount,
    this.coverSeed = 'album',
  });

  final String id;
  final String title;
  final String producerName;
  final int year;
  final int trackCount;
  final String coverSeed;

  String get coverUrl => 'https://api.dicebear.com/7.x/identicon/svg?seed=$coverSeed';
}
