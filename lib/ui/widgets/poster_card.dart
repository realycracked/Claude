import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/media_item.dart';
import 'focusable.dart';

/// Vignette d'affiche (portrait) façon Netflix, avec fallback élégant.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    this.onTap,
    this.width = 130,
    this.progress,
    this.autofocus = false,
  });

  final MediaItem item;
  final VoidCallback? onTap;
  final double width;
  final double? progress; // 0..1 pour la barre "reprendre"
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final height = width * 3 / 2;
    return SizedBox(
      width: width,
      child: Focusable(
        autofocus: autofocus,
        onTap: onTap,
        borderRadius: 8,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            _poster(context, height),
            if (progress != null && progress! > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _poster(BuildContext context, double height) {
    if (item.poster.isEmpty) return _placeholder(context, height);
    return CachedNetworkImage(
      imageUrl: item.poster,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => _skeleton(height),
      errorWidget: (_, __, ___) => _placeholder(context, height),
    );
  }

  Widget _skeleton(double height) => Container(
        width: width,
        height: height,
        color: Colors.white10,
      );

  Widget _placeholder(BuildContext context, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade900, Colors.grey.shade800],
        ),
      ),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.isLive ? Icons.live_tv : (item.isSeries ? Icons.tv : Icons.movie),
            color: Colors.white24,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
