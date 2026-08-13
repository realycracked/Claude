/// Progression de lecture (Reprendre à regarder).
class WatchProgress {
  WatchProgress({
    required this.itemId,
    required this.itemType,
    required this.title,
    this.seriesId,
    this.season,
    this.episode,
    this.poster = '',
    this.positionSecs = 0,
    this.durationSecs = 0,
    this.finished = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String itemId; // film ou épisode
  final String itemType; // 'movie' | 'episode' | 'live'
  final String title;
  final String? seriesId;
  final int? season;
  final int? episode;
  final String poster;
  final int positionSecs;
  final int durationSecs;
  final bool finished;
  final DateTime updatedAt;

  double get progress {
    if (durationSecs <= 0) return 0;
    return (positionSecs / durationSecs).clamp(0.0, 1.0);
  }

  /// Considéré "en cours" si entre 3% et 95%.
  bool get inProgress => !finished && progress > 0.03 && progress < 0.95;

  WatchProgress copyWith({
    int? positionSecs,
    int? durationSecs,
    bool? finished,
    DateTime? updatedAt,
  }) {
    return WatchProgress(
      itemId: itemId,
      itemType: itemType,
      title: title,
      seriesId: seriesId,
      season: season,
      episode: episode,
      poster: poster,
      positionSecs: positionSecs ?? this.positionSecs,
      durationSecs: durationSecs ?? this.durationSecs,
      finished: finished ?? this.finished,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_type': itemType,
        'title': title,
        'series_id': seriesId,
        'season': season,
        'episode': episode,
        'poster': poster,
        'position_secs': positionSecs,
        'duration_secs': durationSecs,
        'finished': finished,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory WatchProgress.fromJson(Map<String, dynamic> j) => WatchProgress(
        itemId: j['item_id']?.toString() ?? '',
        itemType: j['item_type']?.toString() ?? 'movie',
        title: j['title']?.toString() ?? '',
        seriesId: j['series_id']?.toString(),
        season: (j['season'] as num?)?.toInt(),
        episode: (j['episode'] as num?)?.toInt(),
        poster: j['poster']?.toString() ?? '',
        positionSecs: (j['position_secs'] as num?)?.toInt() ?? 0,
        durationSecs: (j['duration_secs'] as num?)?.toInt() ?? 0,
        finished: j['finished'] as bool? ?? false,
        updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Un favori (chaîne / film / série).
class Favorite {
  Favorite({
    required this.itemId,
    required this.itemType,
    required this.title,
    this.poster = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String itemId;
  final String itemType;
  final String title;
  final String poster;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_type': itemType,
        'title': title,
        'poster': poster,
        'created_at': createdAt.toIso8601String(),
      };

  factory Favorite.fromJson(Map<String, dynamic> j) => Favorite(
        itemId: j['item_id']?.toString() ?? '',
        itemType: j['item_type']?.toString() ?? 'movie',
        title: j['title']?.toString() ?? '',
        poster: j['poster']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}
