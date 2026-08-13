import 'dart:async';

import '../config/app_config.dart';
import '../models/epg.dart';
import '../models/media_item.dart';
import '../models/source.dart';
import 'epg_service.dart';
import 'local_store.dart';
import 'm3u_service.dart';
import 'parental_service.dart';
import 'tmdb_service.dart';
import 'xtream_service.dart';

/// Une ligne de contenu façon Netflix ("Films populaires", "Nouveautés"…).
class ContentRow {
  ContentRow(this.title, this.items, {this.categoryId = ''});
  final String title;
  final List<MediaItem> items;
  final String categoryId;
}

/// Regroupe et prépare tout le contenu des sources IPTV.
class ContentRepository {
  ContentRepository({
    required this.local,
    required this.parental,
    XtreamService? xtream,
    M3uService? m3u,
    TmdbService? tmdb,
    EpgService? epg,
  })  : _xtream = xtream ?? XtreamService(),
        _m3u = m3u ?? M3uService(),
        tmdb = tmdb ?? TmdbService(),
        _epg = epg ?? EpgService();

  final LocalStore local;
  final ParentalService parental;
  final XtreamService _xtream;
  final M3uService _m3u;
  final TmdbService tmdb;
  final EpgService _epg;

  final List<MediaItem> _live = [];
  final List<MediaItem> _movies = [];
  final List<MediaItem> _series = [];
  EpgGuide _guide = EpgGuide({});

  List<MediaItem> get live => List.unmodifiable(_live);
  List<MediaItem> get movies => List.unmodifiable(_movies);
  List<MediaItem> get series => List.unmodifiable(_series);
  EpgGuide get guide => _guide;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  AppConfig get _cfg => AppConfig.instance;

  /// Charge (ou recharge) tout le catalogue à partir des sources actives.
  Future<void> loadAll(List<IptvSource> sources, {bool force = false}) async {
    if (_loaded && !force) return;
    _live.clear();
    _movies.clear();
    _series.clear();

    final active = sources.where((s) => s.isActive).toList();
    for (final src in active) {
      try {
        if (src.isXtream) {
          await _loadXtream(src);
        } else {
          await _loadM3u(src);
        }
      } catch (_) {
        // Une source en erreur ne casse pas les autres.
      }
    }

    _dedupe(_movies);
    _dedupe(_series);
    await _loadEpg(active);
    _loaded = true;
  }

  Future<void> _loadXtream(IptvSource src) async {
    // Catégories -> nom lisible
    final liveCats = {for (final c in await _xtream.liveCategories(src)) c.id: c.name};
    final vodCats = {for (final c in await _xtream.vodCategories(src)) c.id: c.name};
    final serCats = {for (final c in await _xtream.seriesCategories(src)) c.id: c.name};

    _live.addAll((await _xtream.liveStreams(src)).map((m) => _withCat(m, liveCats)));
    _movies.addAll((await _xtream.vodStreams(src)).map((m) => _withCat(m, vodCats)));
    _series.addAll((await _xtream.series(src)).map((m) => _withCat(m, serCats)));
  }

  MediaItem _withCat(MediaItem m, Map<String, String> cats) {
    final name = cats[m.categoryId] ?? m.categoryName;
    return MediaItem(
      id: m.id,
      type: m.type,
      title: m.title,
      poster: m.poster,
      backdrop: m.backdrop,
      overview: m.overview,
      categoryId: m.categoryId,
      categoryName: name,
      sourceId: m.sourceId,
      year: m.year,
      rating: m.rating,
      genres: m.genres,
      isAdult: m.isAdult,
      tmdbId: m.tmdbId,
      epgChannelId: m.epgChannelId,
      streamId: m.streamId,
      versions: m.versions,
      seasons: m.seasons,
      durationSecs: m.durationSecs,
      raw: m.raw,
    );
  }

  Future<void> _loadM3u(IptvSource src) async {
    final items = await _m3u.loadFromSource(src);
    for (final it in items) {
      switch (it.type) {
        case MediaType.live:
          _live.add(it);
          break;
        case MediaType.movie:
          _movies.add(it);
          break;
        case MediaType.series:
          _series.add(it);
          break;
      }
    }
  }

  Future<void> _loadEpg(List<IptvSource> sources) async {
    if (!_cfg.feature('epg')) return;
    // Priorité : epgUrl explicite, sinon EPG intégré Xtream.
    for (final src in sources) {
      final url = src.epgUrl.isNotEmpty
          ? src.epgUrl
          : (src.isXtream ? src.xtreamEpgUrl : '');
      if (url.isEmpty) continue;
      try {
        final g = await _epg.loadFromUrl(url);
        if (!g.isEmpty) {
          _guide = _merge(_guide, g);
        }
      } catch (_) {}
    }
  }

  EpgGuide _merge(EpgGuide a, EpgGuide b) {
    final map = Map<String, List<EpgProgramme>>.from(a.byChannel);
    b.byChannel.forEach((k, v) => map.putIfAbsent(k, () => v));
    return EpgGuide(map);
  }

  void _dedupe(List<MediaItem> list) {
    final seen = <String>{};
    list.retainWhere((m) {
      final key = '${m.type.name}:${m.title.toLowerCase()}';
      return seen.add(key);
    });
  }

  // ---- Fusion de versions (multi-sources d'un même film) -----------------
  /// Toutes les versions jouables d'un film (mêmes titres sur plusieurs sources).
  List<StreamVersion> allVersionsFor(MediaItem movie) {
    final versions = <StreamVersion>[...movie.versions];
    final key = movie.title.toLowerCase().trim();
    for (final m in _movies) {
      if (m.id == movie.id) continue;
      if (m.title.toLowerCase().trim() == key) {
        versions.addAll(m.versions);
      }
    }
    return versions;
  }

  // ---- Séries : charge les saisons/épisodes à la demande -----------------
  Future<MediaItem> loadSeriesDetail(MediaItem base, List<IptvSource> sources) async {
    if (base.seasons.isNotEmpty) return base;
    final src = sources.firstWhere(
      (s) => s.id == base.sourceId,
      orElse: () => sources.isNotEmpty ? sources.first : throw StateError('no source'),
    );
    if (src.isXtream) {
      return _xtream.seriesInfo(src, base);
    }
    return base;
  }

  // ---- TMDB : enrichit un média (affiche, résumé, note) ------------------
  Future<MediaItem> enrich(MediaItem item) async {
    if (!tmdb.enabled || item.isLive) return item;
    final isSeries = item.isSeries;
    TmdbInfo? info;
    if (item.tmdbId != null) {
      info = await tmdb.byId(item.tmdbId!, isSeries: isSeries);
    }
    info ??= await tmdb.search(item.title, isSeries: isSeries, year: item.year);
    if (info == null) return item;
    return item.copyWith(
      poster: info.poster.isNotEmpty ? info.poster : item.poster,
      backdrop: info.backdrop.isNotEmpty ? info.backdrop : item.backdrop,
      overview: info.overview.isNotEmpty ? info.overview : item.overview,
      rating: info.rating > 0 ? info.rating : item.rating,
      year: info.year.isNotEmpty ? info.year : item.year,
      genres: info.genres.isNotEmpty ? info.genres : item.genres,
      tmdbId: info.tmdbId ?? item.tmdbId,
    );
  }

  // ---- Lignes d'accueil (façon Netflix) ----------------------------------
  List<ContentRow> homeRows({required bool includeAdult}) {
    final rows = <ContentRow>[];

    final movies = parental.filter(_movies, unlocked: includeAdult);
    final series = parental.filter(_series, unlocked: includeAdult);

    // Catégories de films (les plus fournies d'abord)
    final movieByCat = _groupByCategory(movies);
    final seriesByCat = _groupByCategory(series);

    if (movies.isNotEmpty) {
      rows.add(ContentRow('Films récents', movies.take(20).toList()));
    }
    if (series.isNotEmpty) {
      rows.add(ContentRow('Séries à découvrir', series.take(20).toList()));
    }

    for (final entry in movieByCat.entries.take(12)) {
      rows.add(ContentRow(entry.key, entry.value, categoryId: entry.key));
    }
    for (final entry in seriesByCat.entries.take(8)) {
      rows.add(ContentRow('Séries · ${entry.key}', entry.value, categoryId: entry.key));
    }
    return rows;
  }

  Map<String, List<MediaItem>> _groupByCategory(List<MediaItem> items) {
    final map = <String, List<MediaItem>>{};
    for (final m in items) {
      final cat = m.categoryName.isNotEmpty ? m.categoryName : 'Autres';
      map.putIfAbsent(cat, () => []).add(m);
    }
    // Trie par nombre d'éléments décroissant.
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return {for (final e in sorted) e.key: e.value};
  }

  // ---- Recherche globale -------------------------------------------------
  List<MediaItem> search(String query, {required bool includeAdult}) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];
    final pool = parental.filter(
      [..._movies, ..._series, ..._live],
      unlocked: includeAdult,
    );
    return pool.where((m) => m.title.toLowerCase().contains(q)).take(60).toList();
  }

  List<MediaItem> liveByCategory() => _live;

  void dispose() {
    _xtream.dispose();
    _m3u.dispose();
    tmdb.dispose();
    _epg.dispose();
  }
}
