import 'package:flutter/material.dart';

import '../../models/media_item.dart';
import 'poster_card.dart';

/// Carrousel horizontal titré (une "ligne" de l'accueil).
class ContentRowView extends StatelessWidget {
  const ContentRowView({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.onSeeAll,
    this.progressFor,
    this.itemWidth = 130,
  });

  final String title;
  final List<MediaItem> items;
  final void Function(MediaItem) onItemTap;
  final VoidCallback? onSeeAll;
  final double? Function(MediaItem)? progressFor;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('Tout voir'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: itemWidth * 3 / 2 + 12,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            clipBehavior: Clip.none,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: PosterCard(
                  item: item,
                  width: itemWidth,
                  progress: progressFor?.call(item),
                  onTap: () => onItemTap(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
