/// Placeholder producer for UI; can be wired to backend later.
class Producer {
  const Producer({
    required this.id,
    required this.name,
    this.trackCount = 0,
    this.albumCount = 0,
    this.avatarSeed,
  });

  final String id;
  final String name;
  final int trackCount;
  final int albumCount;
  final String? avatarSeed;

  String get avatarUrl =>
      'https://api.dicebear.com/7.x/identicon/svg?seed=${avatarSeed ?? id}';
}
