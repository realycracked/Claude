import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Élément téléchargé/enregistré et disponible hors-ligne.
class DownloadItem {
  DownloadItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.itemType,
    this.poster = '',
    this.bytes = 0,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String filePath;
  final String itemType; // movie | episode | recording
  final String poster;
  int bytes;
  bool completed;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'itemType': itemType,
        'poster': poster,
        'bytes': bytes,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadItem.fromJson(Map<String, dynamic> j) => DownloadItem(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        filePath: j['filePath']?.toString() ?? '',
        itemType: j['itemType']?.toString() ?? 'movie',
        poster: j['poster']?.toString() ?? '',
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        completed: j['completed'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Progression de téléchargement (0..1) diffusée pendant l'opération.
class DownloadProgress {
  DownloadProgress(this.id, this.received, this.total);
  final String id;
  final int received;
  final int total;
  double get fraction => total > 0 ? received / total : 0;
}

/// Télécharge des films/épisodes ou enregistre un direct dans un fichier local.
class DownloadService {
  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _active = <String, StreamSubscription>{};
  final _progressCtrl = StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progressStream => _progressCtrl.stream;

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _indexFile(Directory dir) => File('${dir.path}/index.json');

  Future<List<DownloadItem>> list() async {
    final dir = await _dir();
    final f = _indexFile(dir);
    if (!await f.exists()) return [];
    try {
      final list = json.decode(await f.readAsString()) as List;
      return list
          .whereType<Map>()
          .map((e) => DownloadItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveIndex(List<DownloadItem> items) async {
    final dir = await _dir();
    await _indexFile(dir)
        .writeAsString(json.encode(items.map((e) => e.toJson()).toList()));
  }

  /// Télécharge un flux progressif (film/épisode mp4/mkv).
  Future<DownloadItem> download({
    required String id,
    required String title,
    required String url,
    required String itemType,
    String poster = '',
    String ext = 'mp4',
    Map<String, String> headers = const {},
  }) async {
    final dir = await _dir();
    final safe = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final file = File('${dir.path}/$safe.$ext');

    final item = DownloadItem(
      id: id,
      title: title,
      filePath: file.path,
      itemType: itemType,
      poster: poster,
    );

    final items = await list()..removeWhere((e) => e.id == id);
    items.add(item);
    await _saveIndex(items);

    final req = http.Request('GET', Uri.parse(url));
    req.headers.addAll(headers);
    final res = await _client.send(req);
    final total = res.contentLength ?? 0;
    final sink = file.openWrite();
    int received = 0;

    final completer = Completer<DownloadItem>();
    _active[id] = res.stream.listen(
      (chunk) {
        sink.add(chunk);
        received += chunk.length;
        _progressCtrl.add(DownloadProgress(id, received, total));
      },
      onDone: () async {
        await sink.close();
        item.bytes = received;
        item.completed = true;
        final all = await list()..removeWhere((e) => e.id == id);
        all.add(item);
        await _saveIndex(all);
        _active.remove(id);
        if (!completer.isCompleted) completer.complete(item);
      },
      onError: (e) async {
        await sink.close();
        _active.remove(id);
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  /// Annule un téléchargement / arrête un enregistrement en cours.
  Future<void> cancel(String id) async {
    await _active[id]?.cancel();
    _active.remove(id);
  }

  bool isDownloading(String id) => _active.containsKey(id);

  Future<void> delete(String id) async {
    await cancel(id);
    final items = await list();
    final target = items.where((e) => e.id == id).toList();
    for (final t in target) {
      final f = File(t.filePath);
      if (await f.exists()) await f.delete();
    }
    items.removeWhere((e) => e.id == id);
    await _saveIndex(items);
  }

  void dispose() {
    for (final s in _active.values) {
      s.cancel();
    }
    _progressCtrl.close();
    _client.close();
  }
}
