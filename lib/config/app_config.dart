import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

/// Configuration globale de l'app, chargée depuis `config/app_config.json`.
///
/// C'est le fichier que l'utilisateur remplit avec ses clés (TMDB, Supabase),
/// le nom de l'app, la couleur d'accent, et le code secret de déverrouillage.
class AppConfig {
  AppConfig._(this.raw);

  final Map<String, dynamic> raw;

  static AppConfig? _instance;
  static AppConfig get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('AppConfig non chargé. Appelle AppConfig.load() au démarrage.');
    }
    return i;
  }

  /// Charge la config depuis les assets. Doit être appelé avant runApp().
  static Future<AppConfig> load() async {
    Map<String, dynamic> data;
    try {
      final jsonStr = await rootBundle.loadString('config/app_config.json');
      data = json.decode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    _instance = AppConfig._(data);
    return _instance!;
  }

  Map<String, dynamic> _section(String key) =>
      (raw[key] as Map?)?.cast<String, dynamic>() ?? const {};

  // ---- Brand -------------------------------------------------------------
  String get appName => _section('brand')['name']?.toString() ?? 'Nova';
  String get tagline =>
      _section('brand')['tagline']?.toString() ?? 'Tout votre univers, un seul endroit.';

  // ---- Theme -------------------------------------------------------------
  Color get accentColor => _hex(_section('theme')['accentColor'], const Color(0xFFE50914));
  Color get backgroundColor => _hex(_section('theme')['backgroundColor'], const Color(0xFF0B0B0F));
  Color get surfaceColor => _hex(_section('theme')['surfaceColor'], const Color(0xFF16161D));

  // ---- TMDB --------------------------------------------------------------
  String get tmdbApiKey => _section('tmdb')['apiKey']?.toString() ?? '';
  String get tmdbLanguage => _section('tmdb')['language']?.toString() ?? 'fr-FR';
  String get tmdbRegion => _section('tmdb')['region']?.toString() ?? 'FR';
  String get tmdbImageBase =>
      _section('tmdb')['imageBaseUrl']?.toString() ?? 'https://image.tmdb.org/t/p/';
  String get tmdbPosterSize => _section('tmdb')['posterSize']?.toString() ?? 'w500';
  String get tmdbBackdropSize => _section('tmdb')['backdropSize']?.toString() ?? 'w1280';
  bool get tmdbEnabled =>
      (_section('tmdb')['enabled'] as bool? ?? true) && tmdbApiKey.isNotEmpty;

  // ---- Supabase ----------------------------------------------------------
  String get supabaseUrl => _section('supabase')['url']?.toString() ?? '';
  String get supabaseAnonKey => _section('supabase')['anonKey']?.toString() ?? '';
  bool get supabaseEnabled =>
      (_section('supabase')['enabled'] as bool? ?? false) &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;

  // ---- Secret / blocage X ------------------------------------------------
  String get unlockCommand => _section('secret')['unlockCommand']?.toString() ?? '/activeX';
  String get lockCommand => _section('secret')['lockCommand']?.toString() ?? '/lockX';
  int get unlockMinutes => (_section('secret')['unlockMinutes'] as num?)?.toInt() ?? 30;
  List<String> get adultKeywords {
    final list = _section('secret')['adultKeywords'];
    if (list is List) {
      return list.map((e) => e.toString().toLowerCase()).toList();
    }
    return const ['xxx', 'adult', 'adulte', 'porn', '18+', 'sex', 'nsfw'];
  }

  // ---- Features ----------------------------------------------------------
  bool feature(String name, {bool fallback = true}) =>
      _section('features')[name] as bool? ?? fallback;

  // ---- Player ------------------------------------------------------------
  String get playerUserAgent =>
      _section('player')['userAgent']?.toString() ?? 'NovaPlayer/1.0';
  int get seekSeconds => (_section('player')['seekSeconds'] as num?)?.toInt() ?? 10;
  int get bufferSeconds => (_section('player')['bufferSeconds'] as num?)?.toInt() ?? 15;

  // ---- Cache TTL ---------------------------------------------------------
  int get tmdbTtlHours => (_section('cache')['tmdbTtlHours'] as num?)?.toInt() ?? 168;
  int get playlistTtlHours => (_section('cache')['playlistTtlHours'] as num?)?.toInt() ?? 12;
  int get epgTtlHours => (_section('cache')['epgTtlHours'] as num?)?.toInt() ?? 6;

  // ---- Sources par défaut ------------------------------------------------
  List<Map<String, dynamic>> get defaultSources {
    final list = raw['defaultSources'];
    if (list is List) {
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  static Color _hex(dynamic value, Color fallback) {
    if (value is! String) return fallback;
    var s = value.replaceAll('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v == null ? fallback : Color(v);
  }
}
