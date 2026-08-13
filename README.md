# Nova — Lecteur IPTV façon Netflix 📺

Application **Flutter** (téléphone + télé/Android TV) pour lire des sources IPTV
avec une interface soignée inspirée de Netflix.

## ✨ Fonctionnalités

- **Interface façon Netflix** : bannière d'accueil, carrousels, fiches détail, thème sombre + accent rouge.
- **Téléphone & TV** : un seul code, navigation tactile *et* à la télécommande (focus visuel sur Android TV).
- **Sources** : **Xtream Codes API** *et* **playlists M3U / M3U8**.
- **Plusieurs profils** (façon Netflix).
- **Sync cloud Supabase** (optionnel) : profils, sources, favoris et progression synchronisés entre appareils.
- **Reprendre à regarder**, **favoris**, **recherche globale**.
- **Enrichissement TMDB** : affiches, résumés, notes, genres.
- **Guide TV (EPG / XMLTV)** : programme en cours + à suivre.
- **Fiche détail avancée** : le bouton **Lecture** propose **toutes les versions/qualités** d'un film ; pour les séries, **épisodes par saison** avec résumé.
- **Téléchargement / hors-ligne**.
- **Blocage des chaînes X** invisible (voir plus bas).

## 🗂️ Le fichier de configuration

Tout se règle dans **`config/app_config.json`**. C'est là que tu mets tes clés :

| Champ | Rôle |
|-------|------|
| `brand.name` | Nom de l'app (par défaut `Nova`) |
| `theme.accentColor` | Couleur d'accent (par défaut rouge Netflix `#E50914`) |
| `tmdb.apiKey` | **Ta clé TMDB** (v3) pour les affiches/résumés |
| `supabase.url` / `supabase.anonKey` | Projet Supabase (sync cloud) |
| `supabase.enabled` | `true` pour activer le cloud |
| `secret.unlockCommand` | Le **code secret** (par défaut `/activeX`) |
| `secret.unlockMinutes` | Durée du déverrouillage (min) |

> 🔒 **Astuce sécurité** : pour ne pas pousser tes vraies clés sur GitHub, copie
> le fichier en `config/app_config.local.json` (ignoré par git) et mets tes clés
> dedans — sinon édite directement `config/app_config.json`.

## 🙈 Blocage des chaînes X (invisible)

Par défaut, **tout contenu adulte est totalement masqué** : rien dans l'accueil,
les catégories, la recherche ou les favoris ne laisse deviner qu'il existe. Aucun
bouton, aucun réglage visible.

Pour l'activer, il faut **taper la commande secrète dans la barre de recherche** :

```
/activeX
```

Le contenu adulte devient alors visible pendant `unlockMinutes` (30 min par
défaut), puis se re-masque automatiquement. Pour re-masquer immédiatement, tape :

```
/lockX
```

La commande est configurable dans `secret.unlockCommand`.

## 🚀 Installation & lancement

### 1. Pré-requis
- [Flutter](https://docs.flutter.dev/get-started/install) 3.19+ installé (`flutter doctor`).

### 2. Générer les dossiers natifs
Ce dépôt contient le code de l'app (`lib/`), la config et un `AndroidManifest.xml`
prêt pour l'IPTV + Android TV. Génère le reste des plateformes :

```bash
flutter create . --org com.tonnom --platforms=android,ios
```

> ⚠️ Si `flutter create` écrase `android/app/src/main/AndroidManifest.xml`,
> réapplique les ajouts qui s'y trouvent (permission `INTERNET`,
> `android:usesCleartextTraffic="true"`, et l'`intent-filter`
> `LEANBACK_LAUNCHER` pour la TV).

### 3. Installer les dépendances
```bash
flutter pub get
```

### 4. Remplir la config
Édite `config/app_config.json` (au minimum ta clé TMDB).

### 5. Lancer
```bash
# Téléphone / émulateur
flutter run

# Android TV (appareil branché ou émulateur TV)
flutter run -d <device_id>
```

Build release :
```bash
flutter build apk --release        # Android téléphone
flutter build apk --release        # (installable aussi sur Android TV)
flutter build appbundle --release  # Play Store
flutter build ios --release        # iOS (Xcode requis)
```

## ☁️ Configuration Supabase (cloud, optionnel)

1. Crée un projet gratuit sur [supabase.com](https://supabase.com).
2. Dans **SQL Editor**, exécute le script [`supabase/schema.sql`](supabase/schema.sql).
   Il crée les tables (profils, sources, favoris, progression) avec la sécurité
   (RLS) : chaque utilisateur ne voit que ses données.
3. Dans **Project Settings → API**, copie l'`URL` et la clé `anon public`.
4. Colle-les dans `config/app_config.json` (`supabase.url`, `supabase.anonKey`)
   et mets `supabase.enabled` à `true`.
5. Dans l'app : **Réglages → Cloud → Connexion** pour créer un compte / te connecter.

Sans Supabase, l'app fonctionne parfaitement en **local** (rapide), avec profils
et données stockés sur l'appareil.

## 🧱 Architecture

```
lib/
├── config/         app_config.dart        → charge config/app_config.json
├── theme/          app_theme.dart         → thème sombre façon Netflix
├── models/         profil, source, media, epg, progression…
├── services/
│   ├── xtream_service.dart      client API Xtream Codes
│   ├── m3u_service.dart         parseur M3U/M3U8
│   ├── tmdb_service.dart        enrichissement TMDB
│   ├── epg_service.dart         parseur XMLTV (EPG)
│   ├── supabase_service.dart    sync cloud
│   ├── local_store.dart         stockage local (local-first)
│   ├── parental_service.dart    blocage adulte + code /activeX
│   ├── download_service.dart    téléchargement hors-ligne
│   └── content_repository.dart  orchestre tout (catalogue, lignes, recherche)
├── state/          app_controller.dart    → état global (Provider)
└── ui/
    ├── screens/    splash, profils, accueil, recherche, détail,
    │               lecteur, TV en direct, ma liste, réglages
    └── widgets/    poster, carrousel, bannière, focus TV
```

## 🛠️ Stack technique

- **Flutter** (Material 3, thème sombre)
- **provider** — gestion d'état
- **media_kit** — lecture vidéo (HLS/TS/MP4/MKV…), Android/iOS/TV
- **supabase_flutter** — cloud
- **shared_preferences** — cache local
- **cached_network_image** — affiches
- **xml** — parsing EPG XMLTV
- **TMDB** — métadonnées (clé fournie par l'utilisateur)

## ⚖️ Note

Nova est un **lecteur** : il ne fournit aucun contenu. L'utilisateur doit
ajouter ses propres sources IPTV, dont il détient les droits.
