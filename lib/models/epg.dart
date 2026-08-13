/// Un programme du guide TV (EPG / XMLTV).
class EpgProgramme {
  EpgProgramme({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description = '',
    this.category = '',
  });

  final String channelId;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String description;
  final String category;

  Duration get duration => stop.difference(start);

  bool isLiveAt(DateTime t) => !t.isBefore(start) && t.isBefore(stop);

  /// Progression (0..1) à un instant donné.
  double progressAt(DateTime t) {
    final total = duration.inSeconds;
    if (total <= 0) return 0;
    final done = t.difference(start).inSeconds.clamp(0, total);
    return done / total;
  }

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'title': title,
        'start': start.toIso8601String(),
        'stop': stop.toIso8601String(),
        'description': description,
        'category': category,
      };

  factory EpgProgramme.fromJson(Map<String, dynamic> j) => EpgProgramme(
        channelId: j['channelId']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        start: DateTime.tryParse(j['start']?.toString() ?? '') ?? DateTime.now(),
        stop: DateTime.tryParse(j['stop']?.toString() ?? '') ?? DateTime.now(),
        description: j['description']?.toString() ?? '',
        category: j['category']?.toString() ?? '',
      );
}

/// Guide EPG complet : programmes indexés par identifiant de chaîne.
class EpgGuide {
  EpgGuide(this.byChannel);

  final Map<String, List<EpgProgramme>> byChannel;

  EpgProgramme? nowOn(String channelId, [DateTime? at]) {
    final t = at ?? DateTime.now();
    final list = byChannel[channelId];
    if (list == null) return null;
    for (final p in list) {
      if (p.isLiveAt(t)) return p;
    }
    return null;
  }

  EpgProgramme? nextOn(String channelId, [DateTime? at]) {
    final t = at ?? DateTime.now();
    final list = byChannel[channelId];
    if (list == null) return null;
    for (final p in list) {
      if (p.start.isAfter(t)) return p;
    }
    return null;
  }

  List<EpgProgramme> forChannel(String channelId) =>
      byChannel[channelId] ?? const [];

  bool get isEmpty => byChannel.isEmpty;
}
