import '../config/app_config.dart';
import '../models/media_item.dart';

/// Gère le blocage des contenus adultes et le déverrouillage secret.
///
/// Principe demandé :
///  - Les chaînes/contenus "X" sont **totalement invisibles** par défaut :
///    filtrés de l'accueil, des catégories, de la recherche, des favoris.
///  - Rien n'indique qu'ils existent (aucun bouton, aucune mention).
///  - Ils n'apparaissent QUE si l'utilisateur tape la commande secrète
///    (par défaut `/activeX`) dans la barre de recherche. Le déverrouillage
///    est temporaire (durée réglable) et se relock automatiquement.
class ParentalService {
  ParentalService();

  AppConfig get _cfg => AppConfig.instance;

  /// Le texte tapé correspond-il à la commande d'activation ?
  bool isUnlockCommand(String query) =>
      query.trim().toLowerCase() == _cfg.unlockCommand.trim().toLowerCase();

  /// Le texte tapé correspond-il à la commande de re-verrouillage ?
  bool isLockCommand(String query) =>
      query.trim().toLowerCase() == _cfg.lockCommand.trim().toLowerCase();

  int get unlockMinutes => _cfg.unlockMinutes;

  /// Détecte si un média est un contenu adulte, à partir de son titre,
  /// de sa catégorie/groupe, et des mots-clés configurés.
  bool isAdult(MediaItem item) {
    if (item.isAdult) return true;
    final hay = '${item.title} ${item.categoryName} ${item.categoryId}'.toLowerCase();
    return _matchesAdult(hay);
  }

  bool isAdultText(String text) => _matchesAdult(text.toLowerCase());

  bool _matchesAdult(String hay) {
    for (final kw in _cfg.adultKeywords) {
      if (kw.isEmpty) continue;
      // Mots courts (ex: "sex", "xxx") : bordure de mot pour éviter les faux positifs.
      if (kw.length <= 4) {
        final re = RegExp(r'(^|[^a-z])' + RegExp.escape(kw) + r'([^a-z]|$)');
        if (re.hasMatch(hay)) return true;
      } else if (hay.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// Filtre une liste : retire les contenus adultes SAUF si déverrouillé.
  List<MediaItem> filter(List<MediaItem> items, {required bool unlocked}) {
    if (unlocked) return items;
    return items.where((i) => !isAdult(i)).toList();
  }
}
