import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml_events.dart';

import '../models/epg.dart';

/// Charge et parse un guide EPG au format XMLTV (streaming parser, économe en RAM).
class EpgService {
  EpgService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<EpgGuide> loadFromUrl(String url) async {
    if (url.isEmpty) return EpgGuide({});
    final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw EpgException('EPG indisponible (HTTP ${res.statusCode}).');
    }
    return parse(utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  EpgGuide parse(String xmlContent) {
    final byChannel = <String, List<EpgProgramme>>{};

    String? channel;
    String? start;
    String? stop;
    String currentTag = '';
    final title = StringBuffer();
    final desc = StringBuffer();
    final category = StringBuffer();
    bool inProgramme = false;

    for (final event in parseEvents(xmlContent)) {
      if (event is XmlStartElementEvent) {
        if (event.name == 'programme') {
          inProgramme = true;
          title.clear();
          desc.clear();
          category.clear();
          channel = _attr(event, 'channel');
          start = _attr(event, 'start');
          stop = _attr(event, 'stop');
        } else if (inProgramme) {
          currentTag = event.name;
        }
      } else if (event is XmlTextEvent && inProgramme) {
        switch (currentTag) {
          case 'title':
            title.write(event.value);
            break;
          case 'desc':
            desc.write(event.value);
            break;
          case 'category':
            if (category.isEmpty) category.write(event.value);
            break;
        }
      } else if (event is XmlEndElementEvent) {
        if (event.name == 'programme') {
          final ch = channel;
          final s = _parseXmltvDate(start);
          final e = _parseXmltvDate(stop);
          if (ch != null && ch.isNotEmpty && s != null && e != null) {
            byChannel.putIfAbsent(ch, () => []).add(EpgProgramme(
                  channelId: ch,
                  title: title.toString().trim(),
                  start: s,
                  stop: e,
                  description: desc.toString().trim(),
                  category: category.toString().trim(),
                ));
          }
          inProgramme = false;
          currentTag = '';
        } else {
          currentTag = '';
        }
      }
    }

    for (final list in byChannel.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return EpgGuide(byChannel);
  }

  String? _attr(XmlStartElementEvent e, String name) {
    for (final a in e.attributes) {
      if (a.name == name) return a.value;
    }
    return null;
  }

  /// Format XMLTV : "20240115203000 +0100".
  DateTime? _parseXmltvDate(String? s) {
    if (s == null || s.length < 14) return null;
    try {
      final y = int.parse(s.substring(0, 4));
      final mo = int.parse(s.substring(4, 6));
      final d = int.parse(s.substring(6, 8));
      final h = int.parse(s.substring(8, 10));
      final mi = int.parse(s.substring(10, 12));
      final se = int.parse(s.substring(12, 14));
      var dt = DateTime.utc(y, mo, d, h, mi, se);

      final tzMatch = RegExp(r'([+-])(\d{2})(\d{2})').firstMatch(s);
      if (tzMatch != null) {
        final sign = tzMatch.group(1) == '-' ? 1 : -1; // vers UTC
        final offH = int.parse(tzMatch.group(2)!);
        final offM = int.parse(tzMatch.group(3)!);
        dt = dt.add(Duration(hours: sign * offH, minutes: sign * offM));
      }
      return dt.toLocal();
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

class EpgException implements Exception {
  EpgException(this.message);
  final String message;
  @override
  String toString() => 'EpgException: $message';
}
