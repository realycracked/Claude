import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/media_item.dart';
import '../../models/watch_progress.dart';
import '../../state/app_controller.dart';
import '../widgets/content_row.dart';
import '../widgets/hero_billboard.dart';
import '../widgets/poster_card.dart';
import 'detail_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final cfg = AppConfig.instance;

    if (c.sources.isEmpty) {
      return _EmptyState(
        onAddSource: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      );
    }

    if (c.status == LoadStatus.loading && !c.repo.isLoaded) {
      return const _LoadingState();
    }

    final rows = c.homeRows;
    final hero = rows.isNotEmpty && rows.first.items.isNotEmpty
        ? rows.first.items.first
        : null;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => c.reloadCatalog(force: true),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      cfg.appName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: cfg.accentColor,
                      ),
                    ),
                    const Spacer(),
                    if (c.activeProfile != null)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cfg.accentColor,
                        child: Text(
                          c.activeProfile!.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (hero != null)
              SliverToBoxAdapter(
                child: HeroBillboard(
                  item: hero,
                  onPlay: () => _play(context, hero),
                  onInfo: () => _openDetail(context, hero),
                ),
              ),
            if (c.continueWatching.isNotEmpty)
              SliverToBoxAdapter(
                child: _ContinueRow(
                  items: c.continueWatching,
                  onTap: (wp) => _resume(context, wp),
                ),
              ),
            if (c.settings.showTop10 && rows.isNotEmpty && rows.first.items.length >= 3)
              SliverToBoxAdapter(
                child: _Top10Row(
                  items: rows.first.items.take(10).toList(),
                  onTap: (item) => _openDetail(context, item),
                ),
              ),
            for (final row in rows)
              SliverToBoxAdapter(
                child: ContentRowView(
                  title: row.title,
                  items: row.items,
                  progressFor: (item) {
                    final p = c.progressFor(item.id);
                    return p?.inProgress == true ? p!.progress : null;
                  },
                  onItemTap: (item) => _openDetail(context, item),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, MediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
  }

  void _play(BuildContext context, MediaItem item) {
    if (item.versions.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: item.title,
            version: item.versions.first,
            item: item,
          ),
        ),
      );
    } else {
      _openDetail(context, item);
    }
  }

  void _resume(BuildContext context, WatchProgress wp) {
    final c = context.read<AppController>();
    // Retrouve le média pour récupérer une version jouable.
    final all = [...c.repo.movies, ...c.repo.series, ...c.repo.live];
    final item = all.where((m) => m.id == wp.itemId || m.id == wp.seriesId).cast<MediaItem?>().firstWhere(
          (m) => m != null,
          orElse: () => null,
        );
    if (item != null) {
      _openDetail(context, item);
    }
  }
}

class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.items, required this.onTap});
  final List<WatchProgress> items;
  final void Function(WatchProgress) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Text('Continuer à regarder',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 130 * 3 / 2 + 12,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final wp = items[i];
              final fake = MediaItem(
                id: wp.itemId,
                type: MediaType.movie,
                title: wp.title,
                poster: wp.poster,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: PosterCard(
                  item: fake,
                  progress: wp.progress,
                  onTap: () => onTap(wp),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Top10Row extends StatelessWidget {
  const _Top10Row({required this.items, required this.onTap});
  final List<MediaItem> items;
  final void Function(MediaItem) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text('Top 10 aujourd\'hui',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () => onTap(items[i]),
                child: SizedBox(
                  width: 172,
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      Positioned(
                        left: 4,
                        bottom: -12,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 110,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 3
                              ..color = Colors.white60,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PosterCard(item: items[i], width: 96),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddSource});
  final VoidCallback onAddSource;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_add, size: 72, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('Aucune source configurée',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Ajoute une source Xtream Codes ou une playlist M3U pour commencer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAddSource,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une source'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppConfig.instance.accentColor),
          const SizedBox(height: 16),
          const Text('Chargement du catalogue…',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
