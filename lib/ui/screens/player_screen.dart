import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_settings.dart';
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
  late AppSettings _settings;
  Timer? _saveTimer;
  bool _resumed = false;
  String? _error;
  bool _opening = true;
  StreamSubscription? _errorSub;

  // État mutable (change lors de l'enchaînement d'épisodes).
  late String _title = widget.title;
  late StreamVersion _version = widget.version;
  Episode? _episode;

  @override
  void initState() {
    super.initState();
    _episode = widget.episode;
    _settings = context.read<AppController>().settings;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _player = Player();
    _controller = VideoController(_player);
    _open();
    _startProgressTracking();
    _listenCompletion();
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _opening = true;
    });
    final headers = <String, String>{
      'User-Agent': AppConfig.instance.playerUserAgent,
      ..._version.headers,
    };
    try {
      await _player.open(Media(_version.url, httpHeaders: headers));
      if (_settings.playbackSpeed != 1.0) {
        await _player.setRate(_settings.playbackSpeed);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Lecture impossible : $e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String get _progressId =>
      _episode != null ? '${widget.item.id}:${_episode!.id}' : widget.item.id;

  void _startProgressTracking() {
    _player.stream.duration.listen((d) async {
      if (_resumed || d.inSeconds <= 0 || widget.item.isLive) return;
      _resumed = true;
      if (!_settings.rememberPosition) return;
      final c = context.read<AppController>();
      final wp = c.progressFor(_progressId);
      if (wp != null && wp.inProgress) {
        await _player.seek(Duration(seconds: wp.positionSecs));
      }
    });
    _saveTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  void _listenCompletion() {
    _player.stream.completed.listen((done) {
      if (done && _settings.autoplayNext) _playNextEpisode();
    });
    // Erreurs du moteur vidéo (flux mort, format non supporté…).
    _errorSub = _player.stream.error.listen((e) {
      if (mounted && e.toString().trim().isNotEmpty) {
        setState(() => _error = e.toString());
      }
    });
  }

  void _playNextEpisode() {
    final ep = _episode;
    if (ep == null) return;
    final next = _findNextEpisode(ep);
    if (next == null || next.versions.isEmpty) return;
    setState(() {
      _episode = next;
      _version = next.versions.first;
      _title = '${widget.item.title} · ${next.label}';
      _resumed = true; // pas de reprise sur un nouvel épisode
    });
    _open();
  }

  Episode? _findNextEpisode(Episode current) {
    final seasons = widget.item.seasons;
    final sameSeason = seasons[current.season] ?? const [];
    final idx = sameSeason.indexWhere((e) => e.id == current.id);
    if (idx >= 0 && idx + 1 < sameSeason.length) return sameSeason[idx + 1];
    // Sinon, premier épisode de la saison suivante.
    final nums = widget.item.seasonNumbers;
    final si = nums.indexOf(current.season);
    if (si >= 0 && si + 1 < nums.length) {
      final nextSeason = seasons[nums[si + 1]] ?? const [];
      if (nextSeason.isNotEmpty) return nextSeason.first;
    }
    return null;
  }

  void _saveProgress() {
    if (widget.item.isLive || !_settings.rememberPosition) return;
    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (dur <= 0 || pos <= 0) return;
    context.read<AppController>().saveProgress(WatchProgress(
          itemId: _progressId,
          itemType: _episode != null ? 'episode' : 'movie',
          title: _title,
          seriesId: _episode != null ? widget.item.id : null,
          season: _episode?.season,
          episode: _episode?.episode,
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
    _errorSub?.cancel();
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
      body: Stack(
        children: [
          Video(
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
          if (_error != null) _errorOverlay(),
          if (_opening && _error == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _errorOverlay() {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 52, color: Colors.white38),
          const SizedBox(height: 14),
          const Text('Lecture impossible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
