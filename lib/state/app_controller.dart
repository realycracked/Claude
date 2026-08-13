import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/app_settings.dart';
import '../models/media_item.dart';
import '../models/profile.dart';
import '../models/source.dart';
import '../models/watch_progress.dart';
import '../services/content_repository.dart';
import '../services/local_store.dart';
import '../services/parental_service.dart';
import '../services/supabase_service.dart';

enum LoadStatus { idle, loading, ready, error }

/// Contrôleur central de l'app. Relie stockage local, cloud (Supabase),
/// catalogue IPTV, profils, favoris, progression et déverrouillage adulte.
class AppController extends ChangeNotifier {
  AppController({
    required this.local,
    required this.repo,
    required this.parental,
  });

  final LocalStore local;
  final ContentRepository repo;
  final ParentalService parental;
  final SupabaseService cloud = SupabaseService.instance;

  AppConfig get config => AppConfig.instance;

  // ---- État global -------------------------------------------------------
  LoadStatus status = LoadStatus.idle;
  String? errorMessage;

  List<Profile> profiles = [];
  Profile? activeProfile;

  List<IptvSource> sources = [];
  List<Favorite> favorites = [];
  List<WatchProgress> progress = [];

  AppSettings settings = const AppSettings();

  /// Déverrouillage temporaire des contenus adultes pour le profil actif.
  DateTime? _adultUnlockUntil;
  bool get adultUnlocked {
    final until = _adultUnlockUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  bool get cloudEnabled => cloud.enabled;
  bool get isSignedIn => cloud.isSignedIn;

  // ---- Démarrage ---------------------------------------------------------
  Future<void> bootstrap() async {
    settings = local.getSettings();
    repo.applyLanguage(settings.contentLanguage);
    profiles = local.getProfiles();
    sources = local.getSources();

    // Sources par défaut de la config (au premier lancement).
    if (sources.isEmpty && config.defaultSources.isNotEmpty) {
      sources = config.defaultSources.map(IptvSource.fromJson).toList();
      await local.saveSources(sources);
    }

    // Restaure le profil actif.
    final activeId = local.getActiveProfileId();
    if (activeId != null) {
      activeProfile = profiles.where((p) => p.id == activeId).firstOrNull;
    }

    // Synchro cloud en arrière-plan (non bloquant).
    if (cloudEnabled && isSignedIn) {
      unawaited(_syncFromCloud());
    }
    notifyListeners();
  }

  Future<void> _syncFromCloud() async {
    try {
      final cloudProfiles = await cloud.fetchProfiles();
      if (cloudProfiles.isNotEmpty) {
        profiles = cloudProfiles;
        await local.saveProfiles(profiles);
      }
      final cloudSources = await cloud.fetchSources();
      if (cloudSources.isNotEmpty) {
        sources = cloudSources;
        await local.saveSources(sources);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ---- Profils -----------------------------------------------------------
  Future<void> selectProfile(Profile p) async {
    activeProfile = p;
    await local.setActiveProfileId(p.id);
    _adultUnlockUntil = local.getAdultUnlockUntil(p.id);
    favorites = local.getFavorites(p.id);
    progress = local.getProgress(p.id);

    if (cloudEnabled && isSignedIn) {
      unawaited(() async {
        favorites = await cloud.fetchFavorites(p.id);
        progress = await cloud.fetchProgress(p.id);
        await local.saveFavorites(p.id, favorites);
        await local.saveProgress(p.id, progress);
        notifyListeners();
      }());
    }
    notifyListeners();
  }

  Future<Profile> createProfile(String name,
      {String avatar = 'avatar_1'}) async {
    final p = Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      avatar: avatar,
    );
    profiles = [...profiles, p];
    await local.saveProfiles(profiles);
    if (cloudEnabled && isSignedIn) unawaited(cloud.upsertProfile(p));
    notifyListeners();
    return p;
  }

  Future<void> updateProfile(Profile p) async {
    profiles = [for (final x in profiles) if (x.id == p.id) p else x];
    await local.saveProfiles(profiles);
    if (activeProfile?.id == p.id) activeProfile = p;
    if (cloudEnabled && isSignedIn) unawaited(cloud.upsertProfile(p));
    notifyListeners();
  }

  Future<void> deleteProfile(Profile p) async {
    profiles = profiles.where((x) => x.id != p.id).toList();
    await local.saveProfiles(profiles);
    if (activeProfile?.id == p.id) {
      activeProfile = null;
      await local.setActiveProfileId(null);
    }
    if (cloudEnabled && isSignedIn) unawaited(cloud.deleteProfile(p.id));
    notifyListeners();
  }

  // ---- Réglages ----------------------------------------------------------
  Future<void> updateSettings(AppSettings s) async {
    final languageChanged = s.contentLanguage != settings.contentLanguage;
    settings = s;
    await local.saveSettings(s);
    if (languageChanged) {
      repo.applyLanguage(s.contentLanguage);
    }
    notifyListeners();
  }

  Future<void> clearContinueWatching() async {
    final id = activeProfile?.id;
    if (id == null) return;
    progress = [];
    await local.saveProgress(id, progress);
    notifyListeners();
  }

  // ---- Authentification cloud -------------------------------------------
  /// true = session ouverte tout de suite ; false = confirmation email requise.
  Future<bool> signUp(String email, String password) async {
    final immediate = await cloud.signUp(email, password);
    if (immediate) await _afterAuth();
    return immediate;
  }

  Future<void> signIn(String email, String password) async {
    await cloud.signIn(email, password);
    await _afterAuth();
  }

  Future<void> signOut() async {
    await cloud.signOut();
    notifyListeners();
  }

  Future<void> _afterAuth() async {
    await _syncFromCloud();
    notifyListeners();
  }

  // ---- Sources -----------------------------------------------------------
  Future<void> addSource(IptvSource s) async {
    sources = [...sources, s.copyWith(sortOrder: sources.length)];
    await local.saveSources(sources);
    if (cloudEnabled && isSignedIn) unawaited(cloud.upsertSource(s));
    await reloadCatalog(force: true);
  }

  Future<void> removeSource(IptvSource s) async {
    sources = sources.where((x) => x.id != s.id).toList();
    await local.saveSources(sources);
    if (cloudEnabled && isSignedIn) unawaited(cloud.deleteSource(s.id));
    await reloadCatalog(force: true);
  }

  Future<void> updateSource(IptvSource s) async {
    sources = [for (final x in sources) if (x.id == s.id) s else x];
    await local.saveSources(sources);
    if (cloudEnabled && isSignedIn) unawaited(cloud.upsertSource(s));
    await reloadCatalog(force: true);
  }

  // ---- Catalogue ---------------------------------------------------------
  /// Étape de chargement en cours, affichée à l'écran.
  String loadStep = '';

  /// Problèmes rencontrés au dernier chargement.
  List<String> get loadErrors => repo.loadErrors;

  int get totalItems =>
      repo.movies.length + repo.series.length + repo.live.length;

  Future<void> reloadCatalog({bool force = false}) async {
    if (sources.isEmpty) {
      status = LoadStatus.ready;
      notifyListeners();
      return;
    }
    status = LoadStatus.loading;
    errorMessage = null;
    loadStep = 'Préparation…';
    notifyListeners();

    repo.onProgress = (step) {
      loadStep = step;
      notifyListeners();
    };

    try {
      await repo.loadAll(sources, force: force);
      status = totalItems == 0 ? LoadStatus.error : LoadStatus.ready;
      if (totalItems == 0) {
        errorMessage = repo.loadErrors.isNotEmpty
            ? repo.loadErrors.first
            : 'Aucun contenu trouvé.';
      }
    } catch (e) {
      status = LoadStatus.error;
      errorMessage = e.toString();
    } finally {
      repo.onProgress = null;
      loadStep = '';
    }
    notifyListeners();
  }

  List<ContentRow> get homeRows => repo.homeRows(includeAdult: adultUnlocked);

  List<MediaItem> search(String query) =>
      repo.search(query, includeAdult: adultUnlocked);

  List<MediaItem> get liveChannels =>
      parental.filter(repo.live, unlocked: adultUnlocked);

  // ---- Déverrouillage adulte (commande secrète /activeX) -----------------
  /// Analyse une saisie de recherche. Retourne true si c'était une commande
  /// secrète (et l'UI ne doit alors PAS traiter ça comme une recherche).
  Future<bool> handleSecretCommand(String query) async {
    if (parental.isUnlockCommand(query)) {
      _adultUnlockUntil =
          DateTime.now().add(Duration(minutes: parental.unlockMinutes));
      final id = activeProfile?.id;
      if (id != null) await local.setAdultUnlockUntil(id, _adultUnlockUntil);
      notifyListeners();
      return true;
    }
    if (parental.isLockCommand(query)) {
      _adultUnlockUntil = null;
      final id = activeProfile?.id;
      if (id != null) await local.setAdultUnlockUntil(id, null);
      notifyListeners();
      return true;
    }
    return false;
  }

  void relockAdult() {
    _adultUnlockUntil = null;
    final id = activeProfile?.id;
    if (id != null) local.setAdultUnlockUntil(id, null);
    notifyListeners();
  }

  // ---- Favoris -----------------------------------------------------------
  bool isFavorite(String itemId) => favorites.any((f) => f.itemId == itemId);

  Future<void> toggleFavorite(MediaItem item) async {
    final id = activeProfile?.id;
    if (id == null) return;
    if (isFavorite(item.id)) {
      favorites = favorites.where((f) => f.itemId != item.id).toList();
      if (cloudEnabled && isSignedIn) unawaited(cloud.deleteFavorite(id, item.id));
    } else {
      final fav = Favorite(
        itemId: item.id,
        itemType: item.type.name,
        title: item.title,
        poster: item.poster,
      );
      favorites = [fav, ...favorites];
      if (cloudEnabled && isSignedIn) unawaited(cloud.upsertFavorite(id, fav));
    }
    await local.saveFavorites(id, favorites);
    notifyListeners();
  }

  List<Favorite> get favoriteItems => favorites;

  // ---- Progression -------------------------------------------------------
  List<WatchProgress> get continueWatching =>
      progress.where((p) => p.inProgress).toList();

  WatchProgress? progressFor(String itemId) =>
      progress.where((p) => p.itemId == itemId).firstOrNull;

  Future<void> saveProgress(WatchProgress wp) async {
    final id = activeProfile?.id;
    if (id == null) return;
    progress = [wp, ...progress.where((p) => p.itemId != wp.itemId)];
    await local.saveProgress(id, progress);
    if (cloudEnabled && isSignedIn) unawaited(cloud.upsertProgress(id, wp));
    notifyListeners();
  }

  @override
  void dispose() {
    repo.dispose();
    super.dispose();
  }
}

/// Petit helper pour lancer un future sans l'attendre proprement.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}
