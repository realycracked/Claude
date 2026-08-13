import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../services/download_service.dart';
import '../../state/app_controller.dart';
import '../widgets/poster_card.dart';
import 'detail_screen.dart';
import 'player_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ma liste',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Favoris'),
                Tab(text: 'En cours'),
                Tab(text: 'Téléchargements'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _FavoritesTab(),
                  _ContinueTab(),
                  _DownloadsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final favs = c.favoriteItems;
    if (favs.isEmpty) {
      return const _Empty(
          icon: Icons.bookmark_border, text: 'Aucun favori pour le moment');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
      ),
      itemCount: favs.length,
      itemBuilder: (context, i) {
        final f = favs[i];
        final item = _findItem(c, f.itemId) ??
            MediaItem(
              id: f.itemId,
              type: MediaType.values.firstWhere(
                (t) => t.name == f.itemType,
                orElse: () => MediaType.movie,
              ),
              title: f.title,
              poster: f.poster,
            );
        return PosterCard(
          item: item,
          width: 130,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
          ),
        );
      },
    );
  }

  MediaItem? _findItem(AppController c, String id) {
    for (final m in [...c.repo.movies, ...c.repo.series, ...c.repo.live]) {
      if (m.id == id) return m;
    }
    return null;
  }
}

class _ContinueTab extends StatelessWidget {
  const _ContinueTab();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final items = c.continueWatching;
    if (items.isEmpty) {
      return const _Empty(icon: Icons.history, text: 'Rien à reprendre');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final wp = items[i];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 54,
              height: 54,
              child: wp.poster.isNotEmpty
                  ? Image.network(wp.poster, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.white10))
                  : Container(color: Colors.white10, child: const Icon(Icons.movie)),
            ),
          ),
          title: Text(wp.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: LinearProgressIndicator(
            value: wp.progress,
            minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor:
                AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
          ),
          trailing: const Icon(Icons.play_arrow),
          onTap: () {
            final id = wp.seriesId ?? wp.itemId;
            for (final m in [...c.repo.movies, ...c.repo.series]) {
              if (m.id == id) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => DetailScreen(item: m)));
                return;
              }
            }
          },
        );
      },
    );
  }
}

class _DownloadsTab extends StatefulWidget {
  const _DownloadsTab();

  @override
  State<_DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<_DownloadsTab> {
  late Future<List<DownloadItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<DownloadService>().list();
  }

  void _refresh() =>
      setState(() => _future = context.read<DownloadService>().list());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DownloadItem>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const _Empty(
              icon: Icons.download_done, text: 'Aucun téléchargement');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final d = items[i];
            return ListTile(
              leading: Icon(
                d.completed ? Icons.play_circle_fill : Icons.downloading,
                color: d.completed ? Colors.white : Colors.white54,
                size: 34,
              ),
              title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                d.completed
                    ? '${(d.bytes / (1024 * 1024)).toStringAsFixed(0)} Mo · Disponible hors-ligne'
                    : 'Téléchargement en cours…',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await context.read<DownloadService>().delete(d.id);
                  _refresh();
                },
              ),
              onTap: d.completed ? () => _playLocal(context, d) : null,
            );
          },
        );
      },
    );
  }

  void _playLocal(BuildContext context, DownloadItem d) {
    final item = MediaItem(
      id: d.id,
      type: MediaType.movie,
      title: d.title,
      poster: d.poster,
    );
    final version = StreamVersion(
      id: d.id,
      label: 'Hors-ligne',
      url: d.filePath,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(title: d.title, version: version, item: item),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 60, color: Colors.white24),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
