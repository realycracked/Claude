import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Résultat d'enrichissement TMDB pour un média.
class TmdbInfo {
  TmdbInfo({
    this.tmdbId,
    this.poster = '',
    this.backdrop = '',
    this.overview = '',
    this.rating = 0,
    this.year = '',
    this.genres = const [],
  });

  final int? tmdbId;
  final String poster;
  final String backdrop;
  final String overview;
  final double rating;
  final String year;
  final List<String> genres;
}

/// Client TMDB. La clé vient du fichier de config (config/app_config.json).
class TmdbService {
  TmdbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://api.themoviedb.org/3';
  final _cache = <String, TmdbInfo>{};

  /// Langue choisie dans les réglages (prioritaire sur la config).
  String? languageOverride;

  AppConfig get _cfg => AppConfig.instance;
  bool get enabled => _cfg.tmdbEnabled;
  String get _language => languageOverride ?? _cfg.tmdbLanguage;

  String imageUrl(String path, {bool backdrop = false}) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final size = backdrop ? _cfg.tmdbBackdropSize : _cfg.tmdbPosterSize;
    return '${_cfg.tmdbImageBase}$size$path';
  }

  Uri _uri(String path, [Map<String, String>? params]) {
    return Uri.parse('$_base$path').replace(queryParameters: {
      'api_key': _cfg.tmdbApiKey,
      'language': _language,
      ...?params,
    });
  }

  /// Enrichit par ID TMDB direct (fourni par le panel Xtream).
  Future<TmdbInfo?> byId(int tmdbId, {required bool isSeries}) async {
    if (!enabled) return null;
    final key = 'id:$tmdbId:$isSeries';
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final path = isSeries ? '/tv/$tmdbId' : '/movie/$tmdbId';
      final res = await _client.get(_uri(path)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final info = _fromDetail(json.decode(res.body) as Map<String, dynamic>, isSeries);
      _cache[key] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Recherche par titre (nettoie les suffixes type "FR", "1080p", année).
  Future<TmdbInfo?> search(String rawTitle, {required bool isSeries, String? year}) async {
    if (!enabled) return null;
    final title = _cleanTitle(rawTitle);
    if (title.isEmpty) return null;

    final key = 'q:$title:$isSeries:$year';
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final path = isSeries ? '/search/tv' : '/search/movie';
      final params = {
        'query': title,
        'include_adult': 'false',
        if (year != null && year.isNotEmpty)
          (isSeries ? 'first_air_date_year' : 'year'): year,
      };
      final res =
          await _client.get(_uri(path, params)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final results = (json.decode(res.body)['results'] as List?) ?? const [];
      if (results.isEmpty) {
        _cache[key] = TmdbInfo();
        return null;
      }
      final info =
          _fromDetail((results.first as Map).cast<String, dynamic>(), isSeries);
      _cache[key] = info;
      return info;
    } catch (_) {
      return null;
    }
  }

  TmdbInfo _fromDetail(Map<String, dynamic> j, bool isSeries) {
    final date = '${j['release_date'] ?? j['first_air_date'] ?? ''}';
    final genresList = (j['genres'] as List?)
            ?.map((g) => '${(g as Map)['name']}')
            .where((g) => g.isNotEmpty)
            .toList() ??
        const <String>[];
    return TmdbInfo(
      tmdbId: (j['id'] as num?)?.toInt(),
      poster: imageUrl('${j['poster_path'] ?? ''}'),
      backdrop: imageUrl('${j['backdrop_path'] ?? ''}', backdrop: true),
      overview: '${j['overview'] ?? ''}',
      rating: (j['vote_average'] as num?)?.toDouble() ?? 0,
      year: date.length >= 4 ? date.substring(0, 4) : '',
      genres: genresList,
    );
  }

  /// Enlève les tags de qualité/langue courants d'un titre IPTV.
  String _cleanTitle(String input) {
    var t = input;
    t = t.replaceAll(RegExp(r'\((19|20)\d{2}\)'), ' ');
    t = t.replaceAll(
        RegExp(r'\b(4K|UHD|FHD|HD|SD|1080p|720p|480p|VF|VOSTFR|VOST|MULTI|FR|EN|TRUEFRENCH)\b',
            caseSensitive: false),
        ' ');
    t = t.replaceAll(RegExp(r'[\[\]\|]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  void dispose() => _client.close();
}
