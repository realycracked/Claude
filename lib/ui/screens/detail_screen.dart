import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../services/download_service.dart';
import '../../state/app_controller.dart';
import 'player_screen.dart';

/// Fiche détail façon Netflix.
///
/// - Bouton **Lecture** : propose TOUTES les versions/qualités du film.
/// - Séries : liste des épisodes **par saison** avec résumé.
/// - Résumé, note, genres, favori, téléchargement.
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.item});
  final MediaItem item;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late MediaItem _item = widget.item;
  bool _loading = true;
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = context.read<AppController>();
    var item = _item;
    // Enrichissement TMDB (affiche, résumé, note).
    if (!item.isLive) {
      item = await c.repo.enrich(item);
    }
    // Séries : charge saisons/épisodes.
    if (item.isSeries) {
      item = await c.repo.loadSeriesDetail(item, c.sources);
      if (item.seasonNumbers.isNotEmpty) {
        _selectedSeason = item.seasonNumbers.first;
      }
    }
    if (mounted) {
      setState(() {
        _item = item;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final item = _item;
    final isFav = c.isFavorite(item.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: _backdrop(item),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  _metaRow(item),
                  const SizedBox(height: 16),
                  _actions(context, item, isFav),
                  const SizedBox(height: 16),
                  if (item.overview.isNotEmpty)
                    Text(
                      item.overview,
                      style: const TextStyle(
                          color: Colors.white70, height: 1.4, fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  if (item.genres.isNotEmpty)
                    Text(
                      'Genres : ${item.genres.join(', ')}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          if (item.isSeries) ..._seasonSection(context, item),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _backdrop(MediaItem item) {
    final url = item.backdrop.isNotEmpty ? item.backdrop : item.poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: Colors.grey.shade900),
          )
        else
          Container(color: Colors.grey.shade900),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaRow(MediaItem item) {
    final parts = <Widget>[];
    if (item.year.isNotEmpty) parts.add(_chipText(item.year));
    if (item.rating > 0) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 15, color: Colors.amber),
          const SizedBox(width: 3),
          Text(item.rating.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white70)),
        ],
      ));
    }
    parts.add(_chipText(item.isSeries
        ? 'Série'
        : item.isLive
            ? 'Direct'
            : 'Film'));
    return Wrap(spacing: 12, runSpacing: 6, children: parts);
  }

  Widget _chipText(String s) => Text(s,
      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600));

  Widget _actions(BuildContext context, MediaItem item, bool isFav) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _onPlay(context, item),
            icon: const Icon(Icons.play_arrow, size: 26),
            label: const Text('Lecture'),
          ),
        ),
        const SizedBox(width: 10),
        _circleButton(
          icon: isFav ? Icons.check : Icons.add,
          label: 'Ma liste',
          onTap: () => context.read<AppController>().toggleFavorite(item),
        ),
        const SizedBox(width: 6),
        if (!item.isLive)
          _circleButton(
            icon: Icons.download_outlined,
            label: 'Télécharger',
            onTap: () => _onDownload(context, item),
          ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }

  // ------------------------------------------------------------- Lecture film
  void _onPlay(BuildContext context, MediaItem item) {
    if (item.isSeries) {
      // Joue le premier épisode disponible.
      final season = item.seasons[_selectedSeason];
      if (season != null && season.isNotEmpty) {
        _playEpisode(context, item, season.first);
      }
      return;
    }
    final c = context.read<AppController>();
    final versions = c.repo.allVersionsFor(item);
    if (versions.length <= 1) {
      _launch(context, item, versions.isNotEmpty ? versions.first : item.versions.first);
    } else {
      _showVersionPicker(context, item, versions);
    }
  }

  /// Bottom sheet listant TOUTES les versions/qualités d'un film.
  void _showVersionPicker(
      BuildContext context, MediaItem item, List<StreamVersion> versions) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Choisir une version',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: versions.length,
                itemBuilder: (context, i) {
                  final v = versions[i];
                  final label = v.quality.isNotEmpty ? v.quality : v.label;
                  return ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(label.isEmpty ? 'Version ${i + 1}' : label),
                    subtitle: Text(
                      [
                        if (v.sourceName.isNotEmpty) v.sourceName,
                        if (v.containerExt.isNotEmpty) v.containerExt.toUpperCase(),
                      ].join(' • '),
                      style: const TextStyle(color: Colors.white38),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _launch(context, item, v);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launch(BuildContext context, MediaItem item, StreamVersion v) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(title: item.title, version: v, item: item),
      ),
    );
  }

  // ------------------------------------------------------------ Séries/saisons
  List<Widget> _seasonSection(BuildContext context, MediaItem item) {
    final seasons = item.seasonNumbers;
    if (seasons.isEmpty) return const [];
    final episodes = item.seasons[_selectedSeason] ?? const [];

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Text('Épisodes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              DropdownButton<int>(
                value: _selectedSeason,
                dropdownColor: const Color(0xFF16161D),
                underline: const SizedBox.shrink(),
                items: [
                  for (final s in seasons)
                    DropdownMenuItem(value: s, child: Text('Saison $s')),
                ],
                onChanged: (v) => setState(() => _selectedSeason = v ?? _selectedSeason),
              ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _EpisodeTile(
            episode: episodes[i],
            onPlay: () => _playEpisode(context, item, episodes[i]),
            onDownload: () => _downloadEpisode(context, item, episodes[i]),
          ),
          childCount: episodes.length,
        ),
      ),
    ];
  }

  void _playEpisode(BuildContext context, MediaItem series, Episode ep) {
    if (ep.versions.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: '${series.title} · ${ep.label}',
          version: ep.versions.first,
          item: series,
          episode: ep,
        ),
      ),
    );
  }

  // -------------------------------------------------------------- Téléchargement
  Future<void> _onDownload(BuildContext context, MediaItem item) async {
    final v = item.versions.isNotEmpty ? item.versions.first : null;
    if (v == null) return;
    final dl = context.read<DownloadService>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Téléchargement de « ${item.title} » démarré')),
    );
    try {
      await dl.download(
        id: item.id,
        title: item.title,
        url: v.url,
        itemType: 'movie',
        poster: item.poster,
        ext: v.containerExt.isNotEmpty ? v.containerExt : 'mp4',
        headers: v.headers,
      );
    } catch (_) {}
  }

  Future<void> _downloadEpisode(
      BuildContext context, MediaItem series, Episode ep) async {
    if (ep.versions.isEmpty) return;
    final v = ep.versions.first;
    final dl = context.read<DownloadService>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Téléchargement ${ep.label} démarré')),
    );
    try {
      await dl.download(
        id: '${series.id}:${ep.id}',
        title: '${series.title} ${ep.label}',
        url: v.url,
        itemType: 'episode',
        poster: series.poster,
        ext: v.containerExt.isNotEmpty ? v.containerExt : 'mp4',
        headers: v.headers,
      );
    } catch (_) {}
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.onPlay,
    required this.onDownload,
  });

  final Episode episode;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 120,
                height: 68,
                child: episode.still.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: episode.still,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.white10),
                      )
                    : Container(
                        color: Colors.white10,
                        child: const Icon(Icons.play_arrow, color: Colors.white54),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${episode.episode}. ${episode.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (episode.overview.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        episode.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
