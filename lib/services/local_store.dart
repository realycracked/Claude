import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';
import '../models/source.dart';
import '../models/watch_progress.dart';

/// Stockage local (local-first). Tout est mis en cache ici pour un accès
/// instantané ; la synchro cloud (Supabase) se fait en arrière-plan.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> create() async =>
      LocalStore(await SharedPreferences.getInstance());

  // Clés
  static const _kProfiles = 'profiles';
  static const _kActiveProfile = 'active_profile';
  static const _kSources = 'sources';
  static const _kFavorites = 'favorites'; // par profil : favorites:<profileId>
  static const _kProgress = 'progress'; // par profil : progress:<profileId>
  static const _kAdultUnlockUntil = 'adult_unlock_until'; // par profil

  // ---- Profils -----------------------------------------------------------
  List<Profile> getProfiles() => _list(_kProfiles).map(Profile.fromJson).toList();

  Future<void> saveProfiles(List<Profile> profiles) async =>
      _setList(_kProfiles, profiles.map((p) => p.toJson()).toList());

  String? getActiveProfileId() => _prefs.getString(_kActiveProfile);

  Future<void> setActiveProfileId(String? id) async {
    if (id == null) {
      await _prefs.remove(_kActiveProfile);
    } else {
      await _prefs.setString(_kActiveProfile, id);
    }
  }

  // ---- Sources -----------------------------------------------------------
  List<IptvSource> getSources() =>
      (_list(_kSources).map(IptvSource.fromJson).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  Future<void> saveSources(List<IptvSource> sources) async =>
      _setList(_kSources, sources.map((s) => s.toJson()).toList());

  // ---- Favoris (par profil) ---------------------------------------------
  List<Favorite> getFavorites(String profileId) =>
      _list('$_kFavorites:$profileId').map(Favorite.fromJson).toList();

  Future<void> saveFavorites(String profileId, List<Favorite> favs) async =>
      _setList('$_kFavorites:$profileId', favs.map((f) => f.toJson()).toList());

  // ---- Progression (par profil) -----------------------------------------
  List<WatchProgress> getProgress(String profileId) =>
      _list('$_kProgress:$profileId').map(WatchProgress.fromJson).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> saveProgress(String profileId, List<WatchProgress> items) async =>
      _setList('$_kProgress:$profileId', items.map((p) => p.toJson()).toList());

  // ---- Déverrouillage adulte (temporaire, par profil) --------------------
  DateTime? getAdultUnlockUntil(String profileId) {
    final ms = _prefs.getInt('$_kAdultUnlockUntil:$profileId');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setAdultUnlockUntil(String profileId, DateTime? until) async {
    final key = '$_kAdultUnlockUntil:$profileId';
    if (until == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setInt(key, until.millisecondsSinceEpoch);
    }
  }

  // ---- Cache générique (playlists, epg, tmdb…) ---------------------------
  Future<void> cachePut(String key, Object value) async =>
      _prefs.setString('cache:$key', json.encode({
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': value,
      }));

  /// Retourne les données si présentes et non expirées (ttl en heures).
  dynamic cacheGet(String key, {required int ttlHours}) {
    final raw = _prefs.getString('cache:$key');
    if (raw == null) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final ts = DateTime.fromMillisecondsSinceEpoch(map['ts'] as int);
      if (DateTime.now().difference(ts).inHours >= ttlHours) return null;
      return map['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCache() async {
    for (final k in _prefs.getKeys().where((k) => k.startsWith('cache:'))) {
      await _prefs.remove(k);
    }
  }

  // ---- Helpers -----------------------------------------------------------
  List<Map<String, dynamic>> _list(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _setList(String key, List<Map<String, dynamic>> list) async =>
      _prefs.setString(key, json.encode(list));
}
