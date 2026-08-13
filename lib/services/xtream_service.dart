import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/source.dart';

/// Client de l'API Xtream Codes (player_api.php).
///
/// Récupère les catégories/flux Live, les VOD (films) et les Séries.
class XtreamService {
  XtreamService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<dynamic> _get(IptvSource src, String action, {Map<String, String>? extra}) async {
    final params = {
      'username': src.username,
      'password': src.password,
      'action': action,
      ...?extra,
    };
    final uri = Uri.parse('${src.url}/player_api.php').replace(queryParameters: params);
    final res = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw XtreamException('HTTP ${res.statusCode} sur $action');
    }
    if (res.body.trim().isEmpty) return const [];
    return json.decode(res.body);
  }

  /// Vérifie les identifiants et retourne les infos du compte.
  Future<Map<String, dynamic>> authenticate(IptvSource src) async {
    final uri = Uri.parse(
        '${src.url}/player_api.php?username=${src.username}&password=${src.password}');
    final res = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw XtreamException('Connexion impossible (HTTP ${res.statusCode}).');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    final auth = (data['user_info'] as Map?)?['auth'];
    if (auth == 0 || auth == '0') {
      throw XtreamException('Identifiants Xtream invalides.');
    }
    return data;
  }

  // --------------------------------------------------------------------- LIVE
  Future<List<XtreamCategory>> liveCategories(IptvSource src) async =>
      _categories(await _get(src, 'get_live_categories'));

  Future<List<MediaItem>> liveStreams(IptvSource src, {String? categoryId}) async {
    final data = await _get(src, 'get_live_streams',
        extra: categoryId != null ? {'category_id': categoryId} : null);
    final list = (data as List).cast<Map<String, dynamic>>();
    return list.map((m) {
      final streamId = '${m['stream_id']}';
      return MediaItem(
        id: 'x:${src.id}:live:$streamId',
        type: MediaType.live,
        title: '${m['name'] ?? ''}'.trim(),
        poster: '${m['stream_icon'] ?? ''}',
        categoryId: '${m['category_id'] ?? ''}',
        sourceId: src.id,
        epgChannelId: '${m['epg_channel_id'] ?? ''}',
        streamId: streamId,
        versions: [
          StreamVersion(
            id: 'x:$streamId',
            label: 'Live',
            url: src.xtreamLiveUrl(streamId),
            sourceName: src.name,
            containerExt: 'ts',
          ),
        ],
        raw: m,
      );
    }).toList();
  }

  // -------------------------------------------------------------------- MOVIES
  Future<List<XtreamCategory>> vodCategories(IptvSource src) async =>
      _categories(await _get(src, 'get_vod_categories'));

  Future<List<MediaItem>> vodStreams(IptvSource src, {String? categoryId}) async {
    final data = await _get(src, 'get_vod_streams',
        extra: categoryId != null ? {'category_id': categoryId} : null);
    final list = (data as List).cast<Map<String, dynamic>>();
    return list.map((m) {
      final streamId = '${m['stream_id']}';
      final ext = '${m['container_extension'] ?? 'mp4'}';
      return MediaItem(
        id: 'x:${src.id}:movie:$streamId',
        type: MediaType.movie,
        title: '${m['name'] ?? ''}'.trim(),
        poster: '${m['stream_icon'] ?? m['cover'] ?? ''}',
        categoryId: '${m['category_id'] ?? ''}',
        sourceId: src.id,
        year: '${m['year'] ?? ''}',
        rating: double.tryParse('${m['rating'] ?? ''}') ?? 0,
        streamId: streamId,
        tmdbId: int.tryParse('${m['tmdb'] ?? m['tmdb_id'] ?? ''}'),
        versions: [
          StreamVersion(
            id: 'x:$streamId',
            label: (m['quality'] ?? 'HD').toString(),
            url: src.xtreamMovieUrl(streamId, ext),
            quality: '${m['quality'] ?? ''}',
            sourceName: src.name,
            containerExt: ext,
          ),
        ],
        raw: m,
      );
    }).toList();
  }

  /// Détails d'un film (infos TMDB brutes fournies par le panel).
  Future<Map<String, dynamic>> vodInfo(IptvSource src, String vodId) async {
    final data = await _get(src, 'get_vod_info', extra: {'vod_id': vodId});
    return (data as Map).cast<String, dynamic>();
  }

  // -------------------------------------------------------------------- SERIES
  Future<List<XtreamCategory>> seriesCategories(IptvSource src) async =>
      _categories(await _get(src, 'get_series_categories'));

  Future<List<MediaItem>> series(IptvSource src, {String? categoryId}) async {
    final data = await _get(src, 'get_series',
        extra: categoryId != null ? {'category_id': categoryId} : null);
    final list = (data as List).cast<Map<String, dynamic>>();
    return list.map((m) {
      final seriesId = '${m['series_id']}';
      return MediaItem(
        id: 'x:${src.id}:series:$seriesId',
        type: MediaType.series,
        title: '${m['name'] ?? ''}'.trim(),
        poster: '${m['cover'] ?? ''}',
        overview: '${m['plot'] ?? ''}',
        categoryId: '${m['category_id'] ?? ''}',
        sourceId: src.id,
        year: '${m['year'] ?? m['releaseDate'] ?? ''}',
        rating: double.tryParse('${m['rating'] ?? ''}') ?? 0,
        genres: '${m['genre'] ?? ''}'
            .split(RegExp(r'[,/|]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        streamId: seriesId,
        tmdbId: int.tryParse('${m['tmdb'] ?? ''}'),
        raw: m,
      );
    }).toList();
  }

  /// Détails complets d'une série : remplit les saisons/épisodes + versions.
  Future<MediaItem> seriesInfo(IptvSource src, MediaItem base) async {
    final data =
        await _get(src, 'get_series_info', extra: {'series_id': base.streamId});
    final map = (data as Map).cast<String, dynamic>();
    final info = (map['info'] as Map?)?.cast<String, dynamic>() ?? const {};
    final episodesRaw = (map['episodes'] as Map?)?.cast<String, dynamic>() ?? const {};

    final seasons = <int, List<Episode>>{};
    episodesRaw.forEach((seasonKey, eps) {
      final seasonNo = int.tryParse(seasonKey) ?? 0;
      final list = (eps as List?)?.cast<Map<String, dynamic>>() ?? const [];
      seasons[seasonNo] = list.map((e) {
        final epId = '${e['id']}';
        final ext = '${e['container_extension'] ?? 'mp4'}';
        final epInfo = (e['info'] as Map?)?.cast<String, dynamic>() ?? const {};
        return Episode(
          id: epId,
          title: '${e['title'] ?? 'Épisode ${e['episode_num']}'}'.trim(),
          season: seasonNo,
          episode: int.tryParse('${e['episode_num']}') ?? 0,
          overview: '${epInfo['plot'] ?? ''}',
          still: '${epInfo['movie_image'] ?? ''}',
          durationSecs: int.tryParse('${epInfo['duration_secs'] ?? ''}') ?? 0,
          airDate: '${epInfo['releasedate'] ?? epInfo['air_date'] ?? ''}',
          versions: [
            StreamVersion(
              id: 'x:$epId',
              label: 'HD',
              url: src.xtreamSeriesUrl(epId, ext),
              sourceName: src.name,
              containerExt: ext,
            ),
          ],
        );
      }).toList()
        ..sort((a, b) => a.episode.compareTo(b.episode));
    });

    return base.copyWith(
      overview: '${info['plot'] ?? base.overview}',
      backdrop: (info['backdrop_path'] is List && (info['backdrop_path'] as List).isNotEmpty)
          ? '${(info['backdrop_path'] as List).first}'
          : base.backdrop,
      poster: '${info['cover'] ?? base.poster}',
      rating: double.tryParse('${info['rating'] ?? ''}') ?? base.rating,
      seasons: seasons,
    );
  }

  List<XtreamCategory> _categories(dynamic data) {
    final list = (data as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return list
        .map((m) => XtreamCategory('${m['category_id']}', '${m['category_name']}'))
        .toList();
  }

  void dispose() => _client.close();
}

class XtreamCategory {
  XtreamCategory(this.id, this.name);
  final String id;
  final String name;
}

class XtreamException implements Exception {
  XtreamException(this.message);
  final String message;
  @override
  String toString() => 'XtreamException: $message';
}
