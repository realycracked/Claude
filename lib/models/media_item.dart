import 'package:collection/collection.dart';

enum MediaType { live, movie, series }

/// Une "version" jouable d'un film ou d'un épisode (qualité / source différente).
/// Ex : "4K — Source 1", "1080p — Source 2", "FR VOSTFR".
class StreamVersion {
  StreamVersion({
    required this.id,
    required this.label,
    required this.url,
    this.quality = '',
    this.sourceName = '',
    this.containerExt = '',
    this.headers = const {},
  });

  final String id;
  final String label;
  final String url;
  final String quality; // 4K / 1080p / 720p / SD
  final String sourceName;
  final String containerExt; // mp4, mkv, ts...
  final Map<String, String> headers;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'url': url,
        'quality': quality,
        'sourceName': sourceName,
        'containerExt': containerExt,
        'headers': headers,
      };

  factory StreamVersion.fromJson(Map<String, dynamic> j) => StreamVersion(
        id: j['id']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        url: j['url']?.toString() ?? '',
        quality: j['quality']?.toString() ?? '',
        sourceName: j['sourceName']?.toString() ?? '',
        containerExt: j['containerExt']?.toString() ?? '',
        headers: (j['headers'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
      );
}

/// Un épisode d'une série.
class Episode {
  Episode({
    required this.id,
    required this.title,
    required this.season,
    required this.episode,
    this.overview = '',
    this.still = '',
    this.durationSecs = 0,
    this.airDate = '',
    this.versions = const [],
  });

  final String id;
  final String title;
  final int season;
  final int episode;
  final String overview;
  final String still; // image de l'épisode
  final int durationSecs;
  final String airDate;
  final List<StreamVersion> versions;

  String get label => 'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'season': season,
        'episode': episode,
        'overview': overview,
        'still': still,
        'durationSecs': durationSecs,
        'airDate': airDate,
        'versions': versions.map((v) => v.toJson()).toList(),
      };

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        season: (j['season'] as num?)?.toInt() ?? 1,
        episode: (j['episode'] as num?)?.toInt() ?? 1,
        overview: j['overview']?.toString() ?? '',
        still: j['still']?.toString() ?? '',
        durationSecs: (j['durationSecs'] as num?)?.toInt() ?? 0,
        airDate: j['airDate']?.toString() ?? '',
        versions: ((j['versions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StreamVersion.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

/// Élément média unifié : chaîne live, film, ou série.
class MediaItem {
  MediaItem({
    required this.id,
    required this.type,
    required this.title,
    this.sortTitle = '',
    this.poster = '',
    this.backdrop = '',
    this.overview = '',
    this.categoryId = '',
    this.categoryName = '',
    this.sourceId = '',
    this.year = '',
    this.rating = 0,
    this.genres = const [],
    this.isAdult = false,
    this.tmdbId,
    this.epgChannelId = '',
    this.streamId = '',
    this.versions = const [],
    this.seasons = const {},
    this.durationSecs = 0,
    this.raw = const {},
  });

  final String id; // identifiant stable (ex: "src:type:streamId")
  final MediaType type;
  final String title;
  final String sortTitle;
  String poster;
  String backdrop;
  String overview;
  final String categoryId;
  final String categoryName;
  final String sourceId;
  String year;
  double rating; // sur 10
  List<String> genres;
  final bool isAdult;
  int? tmdbId;
  final String epgChannelId; // pour associer l'EPG (live)
  final String streamId;

  /// Films / live : versions jouables directes.
  final List<StreamVersion> versions;

  /// Séries : épisodes groupés par saison.
  final Map<int, List<Episode>> seasons;

  int durationSecs;
  final Map<String, dynamic> raw;

  bool get isLive => type == MediaType.live;
  bool get isMovie => type == MediaType.movie;
  bool get isSeries => type == MediaType.series;

  List<int> get seasonNumbers => seasons.keys.toList()..sort();

  MediaItem copyWith({
    String? poster,
    String? backdrop,
    String? overview,
    String? year,
    double? rating,
    List<String>? genres,
    int? tmdbId,
    List<StreamVersion>? versions,
    Map<int, List<Episode>>? seasons,
    int? durationSecs,
  }) {
    return MediaItem(
      id: id,
      type: type,
      title: title,
      sortTitle: sortTitle,
      poster: poster ?? this.poster,
      backdrop: backdrop ?? this.backdrop,
      overview: overview ?? this.overview,
      categoryId: categoryId,
      categoryName: categoryName,
      sourceId: sourceId,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      genres: genres ?? this.genres,
      isAdult: isAdult,
      tmdbId: tmdbId ?? this.tmdbId,
      epgChannelId: epgChannelId,
      streamId: streamId,
      versions: versions ?? this.versions,
      seasons: seasons ?? this.seasons,
      durationSecs: durationSecs ?? this.durationSecs,
      raw: raw,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'sortTitle': sortTitle,
        'poster': poster,
        'backdrop': backdrop,
        'overview': overview,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'sourceId': sourceId,
        'year': year,
        'rating': rating,
        'genres': genres,
        'isAdult': isAdult,
        'tmdbId': tmdbId,
        'epgChannelId': epgChannelId,
        'streamId': streamId,
        'versions': versions.map((v) => v.toJson()).toList(),
        'seasons': seasons.map(
          (k, v) => MapEntry('$k', v.map((e) => e.toJson()).toList()),
        ),
        'durationSecs': durationSecs,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) {
    final seasonsJson = (j['seasons'] as Map?)?.cast<String, dynamic>() ?? const {};
    final seasons = <int, List<Episode>>{};
    seasonsJson.forEach((k, v) {
      final n = int.tryParse(k) ?? 0;
      seasons[n] = ((v as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Episode.fromJson(e.cast<String, dynamic>()))
          .toList();
    });
    return MediaItem(
      id: j['id']?.toString() ?? '',
      type: MediaType.values.firstWhereOrNull((t) => t.name == j['type']) ?? MediaType.movie,
      title: j['title']?.toString() ?? '',
      sortTitle: j['sortTitle']?.toString() ?? '',
      poster: j['poster']?.toString() ?? '',
      backdrop: j['backdrop']?.toString() ?? '',
      overview: j['overview']?.toString() ?? '',
      categoryId: j['categoryId']?.toString() ?? '',
      categoryName: j['categoryName']?.toString() ?? '',
      sourceId: j['sourceId']?.toString() ?? '',
      year: j['year']?.toString() ?? '',
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      genres: ((j['genres'] as List?) ?? const []).map((e) => e.toString()).toList(),
      isAdult: j['isAdult'] as bool? ?? false,
      tmdbId: (j['tmdbId'] as num?)?.toInt(),
      epgChannelId: j['epgChannelId']?.toString() ?? '',
      streamId: j['streamId']?.toString() ?? '',
      versions: ((j['versions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => StreamVersion.fromJson(e.cast<String, dynamic>()))
          .toList(),
      seasons: seasons,
      durationSecs: (j['durationSecs'] as num?)?.toInt() ?? 0,
    );
  }
}
