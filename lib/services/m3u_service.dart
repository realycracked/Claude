import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/source.dart';

/// Parse une playlist M3U/M3U8 (téléchargée ou fournie en texte).
///
/// Gère les attributs `#EXTINF` : tvg-id, tvg-name, tvg-logo, group-title,
/// et détecte films/séries/live à partir de l'URL et des groupes.
class M3uService {
  M3uService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<MediaItem>> loadFromSource(IptvSource src) async {
    final res = await _client.get(Uri.parse(src.url)).timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) {
      throw M3uException('Téléchargement M3U échoué (HTTP ${res.statusCode}).');
    }
    return parse(res.body, src);
  }

  List<MediaItem> parse(String content, IptvSource src) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final items = <MediaItem>[];
    String? extinf;
    final headers = <String, String>{};

    for (var raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        extinf = line;
        headers.clear();
      } else if (line.startsWith('#EXTVLCOPT')) {
        // ex: #EXTVLCOPT:http-user-agent=Mozilla
        final idx = line.indexOf(':');
        if (idx > 0) {
          final kv = line.substring(idx + 1).split('=');
          if (kv.length == 2) {
            final key = kv[0].toLowerCase();
            if (key.contains('user-agent')) headers['User-Agent'] = kv[1];
            if (key.contains('referrer') || key.contains('referer')) {
              headers['Referer'] = kv[1];
            }
          }
        }
      } else if (line.startsWith('#')) {
        continue;
      } else if (extinf != null) {
        final item = _buildItem(extinf, line, src, Map.of(headers));
        if (item != null) items.add(item);
        extinf = null;
      }
    }
    return items;
  }

  MediaItem? _buildItem(String extinf, String url, IptvSource src, Map<String, String> headers) {
    final attrs = _parseAttributes(extinf);
    final name = _displayName(extinf, attrs);
    if (url.isEmpty) return null;

    final group = attrs['group-title'] ?? '';
    final logo = attrs['tvg-logo'] ?? '';
    final tvgId = attrs['tvg-id'] ?? '';
    final type = _guessType(url, group);

    final ext = _extOf(url);
    final id = 'm:${src.id}:${type.name}:${url.hashCode}';

    return MediaItem(
      id: id,
      type: type,
      title: name,
      poster: logo,
      categoryId: group,
      categoryName: group,
      sourceId: src.id,
      epgChannelId: tvgId,
      streamId: '${url.hashCode}',
      versions: [
        StreamVersion(
          id: 'm:${url.hashCode}',
          label: type == MediaType.live ? 'Live' : 'HD',
          url: url,
          sourceName: src.name,
          containerExt: ext,
          headers: headers,
        ),
      ],
    );
  }

  Map<String, String> _parseAttributes(String extinf) {
    final map = <String, String>{};
    final re = RegExp(r'([a-zA-Z0-9\-]+)="([^"]*)"');
    for (final m in re.allMatches(extinf)) {
      map[m.group(1)!.toLowerCase()] = m.group(2)!;
    }
    return map;
  }

  String _displayName(String extinf, Map<String, String> attrs) {
    // Le nom lisible est après la dernière virgule du #EXTINF.
    final commaIdx = extinf.lastIndexOf(',');
    var name = commaIdx >= 0 ? extinf.substring(commaIdx + 1).trim() : '';
    if (name.isEmpty) name = attrs['tvg-name'] ?? 'Sans titre';
    return name;
  }

  MediaType _guessType(String url, String group) {
    final u = url.toLowerCase();
    final g = group.toLowerCase();
    if (u.contains('/series/') || g.contains('serie') || g.contains('series')) {
      return MediaType.series;
    }
    if (u.contains('/movie/') ||
        g.contains('film') ||
        g.contains('movie') ||
        g.contains('vod') ||
        _hasVideoExt(u)) {
      return MediaType.movie;
    }
    return MediaType.live;
  }

  bool _hasVideoExt(String url) {
    const exts = ['.mp4', '.mkv', '.avi', '.mov', '.m4v'];
    return exts.any((e) => url.contains(e));
  }

  String _extOf(String url) {
    final clean = url.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0) return '';
    final ext = clean.substring(dot + 1).toLowerCase();
    return ext.length <= 4 ? ext : '';
  }

  void dispose() => _client.close();
}

class M3uException implements Exception {
  M3uException(this.message);
  final String message;
  @override
  String toString() => 'M3uException: $message';
}
