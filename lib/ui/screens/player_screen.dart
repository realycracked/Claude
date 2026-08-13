import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/media_item.dart';
import '../../models/watch_progress.dart';
import '../../state/app_controller.dart';

/// Lecteur plein écran (média direct, film ou épisode).
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.title,
    required this.version,
    required this.item,
    this.episode,
  });

  final String title;
  final StreamVersion version;
  final MediaItem item;
  final Episode? episode;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  Timer? _saveTimer;
  bool _resumed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _player = Player();
    _controller = VideoController(_player);
    _open();
    _startProgressTracking();
  }

  Future<void> _open() async {
    final ua = AppConfig.instance.playerUserAgent;
    final headers = <String, String>{
      'User-Agent': ua,
      ...widget.version.headers,
    };
    await _player.open(
      Media(widget.version.url, httpHeaders: headers),
    );
  }

  String get _progressId =>
      widget.episode != null ? '${widget.item.id}:${widget.episode!.id}' : widget.item.id;

  void _startProgressTracking() {
    // Reprise à la position sauvegardée.
    _player.stream.duration.listen((d) async {
      if (_resumed || d.inSeconds <= 0 || widget.item.isLive) return;
      _resumed = true;
      final c = context.read<AppController>();
      final wp = c.progressFor(_progressId);
      if (wp != null && wp.inProgress) {
        await _player.seek(Duration(seconds: wp.positionSecs));
      }
    });

    // Sauvegarde périodique de la progression.
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  void _saveProgress() {
    if (widget.item.isLive) return;
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (dur <= 0 || pos <= 0) return;
    final c = context.read<AppController>();
    c.saveProgress(WatchProgress(
      itemId: _progressId,
      itemType: widget.episode != null ? 'episode' : 'movie',
      title: widget.title,
      seriesId: widget.episode != null ? widget.item.id : null,
      season: widget.episode?.season,
      episode: widget.episode?.episode,
      poster: widget.item.poster,
      positionSecs: pos,
      durationSecs: dur,
      finished: pos / dur > 0.95,
    ));
  }

  @override
  void dispose() {
    _saveProgress();
    _saveTimer?.cancel();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Video(
        controller: _controller,
        controls: AdaptiveVideoControls,
        subtitleViewConfiguration: const SubtitleViewConfiguration(
          style: TextStyle(
            fontSize: 34,
            color: Colors.white,
            backgroundColor: Colors.black54,
          ),
        ),
      ),
    );
  }
}
