import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/epg.dart';
import '../../models/media_item.dart';
import '../../state/app_controller.dart';
import '../widgets/focusable.dart';
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  String _category = 'Toutes';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final channels = c.liveChannels;

    if (channels.isEmpty) {
      return const SafeArea(
        child: Center(
          child: Text('Aucune chaîne en direct',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final categories = <String>{'Toutes'};
    for (final ch in channels) {
      categories.add(ch.categoryName.isNotEmpty ? ch.categoryName : 'Autres');
    }

    final filtered = _category == 'Toutes'
        ? channels
        : channels
            .where((ch) =>
                (ch.categoryName.isNotEmpty ? ch.categoryName : 'Autres') ==
                _category)
            .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('TV en direct',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final cat in categories)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: _category == cat,
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final ch = filtered[i];
                final now = c.repo.guide.nowOn(ch.epgChannelId);
                final next = c.repo.guide.nextOn(ch.epgChannelId);
                return _ChannelTile(
                  channel: ch,
                  now: now,
                  next: next,
                  onTap: () => _play(context, ch),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _play(BuildContext context, MediaItem ch) {
    if (ch.versions.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: ch.title,
          version: ch.versions.first,
          item: ch,
        ),
      ),
    );
  }
}

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.now,
    required this.next,
    required this.onTap,
  });

  final MediaItem channel;
  final EpgProgramme? now;
  final EpgProgramme? next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Focusable(
        onTap: onTap,
        borderRadius: 10,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 56,
                  height: 56,
                  color: Colors.black26,
                  child: channel.poster.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: channel.poster,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.live_tv, color: Colors.white38),
                        )
                      : const Icon(Icons.live_tv, color: Colors.white38),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (now != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('DIRECT',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Colors.white)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_hm(now!.start)} - ${_hm(now!.stop)}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        now!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: now!.progressAt(DateTime.now()),
                        minHeight: 3,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary),
                      ),
                      if (next != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Ensuite : ${next!.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Text('Programme non disponible',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill, size: 30, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
