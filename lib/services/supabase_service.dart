import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/profile.dart';
import '../models/source.dart';
import '../models/watch_progress.dart';

/// Couche de synchronisation cloud via Supabase.
///
/// Entièrement optionnelle : si la config Supabase n'est pas remplie, l'app
/// fonctionne en local uniquement et [enabled] vaut false.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;
  bool get enabled => _initialized && AppConfig.instance.supabaseEnabled;

  SupabaseClient get _client => Supabase.instance.client;
  User? get currentUser => enabled ? _client.auth.currentUser : null;
  bool get isSignedIn => currentUser != null;

  /// Initialise le SDK (à appeler au démarrage si la config est présente).
  static Future<void> init() async {
    final cfg = AppConfig.instance;
    if (!cfg.supabaseEnabled) return;
    try {
      await Supabase.initialize(url: cfg.supabaseUrl, anonKey: cfg.supabaseAnonKey);
      instance._initialized = true;
    } catch (_) {
      instance._initialized = false;
    }
  }

  Stream<AuthState> get authChanges =>
      enabled ? _client.auth.onAuthStateChange : const Stream.empty();

  // ---- Auth --------------------------------------------------------------
  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (enabled) await _client.auth.signOut();
  }

  // ---- Profils -----------------------------------------------------------
  Future<List<Profile>> fetchProfiles() async {
    if (!isSignedIn) return [];
    final rows = await _client.from('profiles').select().order('created_at');
    return (rows as List).map((r) => Profile.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> upsertProfile(Profile p) async {
    if (!isSignedIn) return;
    await _client.from('profiles').upsert({
      ...p.toJson(),
      'user_id': currentUser!.id,
    });
  }

  Future<void> deleteProfile(String id) async {
    if (!isSignedIn) return;
    await _client.from('profiles').delete().eq('id', id);
  }

  // ---- Sources -----------------------------------------------------------
  Future<List<IptvSource>> fetchSources() async {
    if (!isSignedIn) return [];
    final rows = await _client.from('sources').select().order('sort_order');
    return (rows as List).map((r) => IptvSource.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> upsertSource(IptvSource s) async {
    if (!isSignedIn) return;
    await _client.from('sources').upsert({
      ...s.toJson(),
      'user_id': currentUser!.id,
    });
  }

  Future<void> deleteSource(String id) async {
    if (!isSignedIn) return;
    await _client.from('sources').delete().eq('id', id);
  }

  // ---- Favoris -----------------------------------------------------------
  Future<List<Favorite>> fetchFavorites(String profileId) async {
    if (!isSignedIn) return [];
    final rows =
        await _client.from('favorites').select().eq('profile_id', profileId);
    return (rows as List).map((r) => Favorite.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> upsertFavorite(String profileId, Favorite f) async {
    if (!isSignedIn) return;
    await _client.from('favorites').upsert({
      ...f.toJson(),
      'user_id': currentUser!.id,
      'profile_id': profileId,
    }, onConflict: 'profile_id,item_id');
  }

  Future<void> deleteFavorite(String profileId, String itemId) async {
    if (!isSignedIn) return;
    await _client
        .from('favorites')
        .delete()
        .eq('profile_id', profileId)
        .eq('item_id', itemId);
  }

  // ---- Progression -------------------------------------------------------
  Future<List<WatchProgress>> fetchProgress(String profileId) async {
    if (!isSignedIn) return [];
    final rows = await _client
        .from('watch_progress')
        .select()
        .eq('profile_id', profileId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((r) => WatchProgress.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertProgress(String profileId, WatchProgress p) async {
    if (!isSignedIn) return;
    await _client.from('watch_progress').upsert({
      ...p.toJson(),
      'user_id': currentUser!.id,
      'profile_id': profileId,
    }, onConflict: 'profile_id,item_id');
  }
}
