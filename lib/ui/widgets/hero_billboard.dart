import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/media_item.dart';

/// Grande bannière en haut de l'accueil (façon Netflix) avec dégradé,
/// titre, résumé et boutons Lecture / Plus d'infos.
class HeroBillboard extends StatelessWidget {
  const HeroBillboard({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onInfo,
  });

  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final bg = item.backdrop.isNotEmpty ? item.backdrop : item.poster;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      height: 460,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bg.isNotEmpty)
            CachedNetworkImage(
              imageUrl: bg,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (_, __, ___) => Container(color: Colors.grey.shade900),
            )
          else
            Container(color: Colors.grey.shade900),
          // Dégradé du bas pour lisibilité
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  Colors.transparent,
                  bgColor.withOpacity(0.4),
                  bgColor,
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                if (item.genres.isNotEmpty)
                  Text(
                    item.genres.take(3).join('  •  '),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow, size: 26),
                        label: const Text('Lecture'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onInfo,
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Infos'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
