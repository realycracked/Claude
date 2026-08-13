import 'package:collection/collection.dart';

enum SourceKind { xtream, m3u }

/// Une source IPTV : soit un panel Xtream Codes, soit une playlist M3U/M3U8.
class IptvSource {
  IptvSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.url,
    this.username = '',
    this.password = '',
    this.epgUrl = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final SourceKind kind;

  /// Xtream : http://host:port (sans slash final). M3U : lien direct .m3u/.m3u8.
  final String url;
  final String username;
  final String password;
  final String epgUrl;
  final bool isActive;
  final int sortOrder;

  bool get isXtream => kind == SourceKind.xtream;

  /// URL de base de l'API Xtream player_api.php
  String get xtreamApiBase => '$url/player_api.php?username=$username&password=$password';

  String xtreamAction(String action) => '$xtreamApiBase&action=$action';

  /// URL de flux live Xtream (format .ts par défaut, .m3u8 possible).
  String xtreamLiveUrl(String streamId, {String ext = 'ts'}) =>
      '$url/live/$username/$password/$streamId.$ext';

  String xtreamMovieUrl(String streamId, String ext) =>
      '$url/movie/$username/$password/$streamId.$ext';

  String xtreamSeriesUrl(String streamId, String ext) =>
      '$url/series/$username/$password/$streamId.$ext';

  /// EPG Xtream intégré (XMLTV).
  String get xtreamEpgUrl => '$url/xmltv.php?username=$username&password=$password';

  IptvSource copyWith({
    String? name,
    SourceKind? kind,
    String? url,
    String? username,
    String? password,
    String? epgUrl,
    bool? isActive,
    int? sortOrder,
  }) {
    return IptvSource(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      epgUrl: epgUrl ?? this.epgUrl,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'url': url,
        'username': username,
        'password': password,
        'epg_url': epgUrl,
        'is_active': isActive,
        'sort_order': sortOrder,
      };

  factory IptvSource.fromJson(Map<String, dynamic> j) => IptvSource(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Source',
        kind: SourceKind.values.firstWhereOrNull((k) => k.name == j['kind']) ??
            SourceKind.m3u,
        url: (j['url']?.toString() ?? '').replaceAll(RegExp(r'/+$'), ''),
        username: j['username']?.toString() ?? '',
        password: j['password']?.toString() ?? '',
        epgUrl: j['epg_url']?.toString() ?? '',
        isActive: j['is_active'] as bool? ?? true,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );
}
