import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/media_item.dart';
import '../../models/watch_progress.dart';
import '../../services/content_repository.dart';
import '../../state/app_controller.dart';
import '../widgets/content_row.dart';
import '../widgets/hero_billboard.dart';
import '../widgets/poster_card.dart';
import '../widgets/shimmer.dart';
import 'add_source_screen.dart';
import 'detail_screen.dart';
import 'player_screen.dart';

enum HomeFilter { all, movies, series }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  HomeFilter _filter = HomeFilter.all;
  double _topOpacity = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final o = (_scroll.offset / 240).clamp(0.0, 1.0);
      if ((o - _topOpacity).abs() > 0.02) setState(() => _topOpacity = o);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final cfg = AppConfig.instance;

    if (c.sources.isEmpty) {
      return _EmptyState(
        onAddSource: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSourceScreen()),
        ),
      );
    }

    if (c.status == LoadStatus.loading && !c.repo.isLoaded) {
      return const HomeSkeleton();
    }

    final rows = _applyFilter(c.homeRows);
    final hero = rows.isNotEmpty && rows.first.items.isNotEmpty
        ? rows.first.items.first
        : null;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => c.reloadCatalog(force: true),
          color: cfg.accentColor,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
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
              if (c.settings.showTop10 &&
                  rows.isNotEmpty &&
                  rows.first.items.length >= 3)
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
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
        _TopBar(opacity: _topOpacity, filter: _filter, onFilter: (f) {
          setState(() => _filter = f);
        }),
      ],
    );
  }

  List<ContentRow> _applyFilter(List<ContentRow> rows) {
    if (_filter == HomeFilter.all) return rows;
    return rows.where((r) {
      if (r.items.isEmpty) return false;
      final t = r.items.first.type;
      return _filter == HomeFilter.movies
          ? t == MediaType.movie
          : t == MediaType.series;
    }).toList();
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
    final all = [...c.repo.movies, ...c.repo.series, ...c.repo.live];
    for (final m in all) {
      if (m.id == wp.itemId || m.id == wp.seriesId) {
        _openDetail(context, m);
        return;
      }
    }
  }
}

/// Barre supérieure transparente qui se teinte au scroll, avec pills façon Netflix.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.opacity,
    required this.filter,
    required this.onFilter,
  });
  final double opacity;
  final HomeFilter filter;
  final ValueChanged<HomeFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.instance;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85 * opacity),
        gradient: opacity < 0.5
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              const SizedBox(width: 14),
              _pill(context, 'Tout', HomeFilter.all),
              _pill(context, 'Films', HomeFilter.movies),
              _pill(context, 'Séries', HomeFilter.series),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, HomeFilter f) {
    final selected = filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onFilter(f),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.white54 : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
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
