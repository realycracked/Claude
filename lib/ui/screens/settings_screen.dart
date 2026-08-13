import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_settings.dart';
import '../../state/app_controller.dart';
import 'add_source_screen.dart';
import 'auth_screen.dart';
import 'profiles_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final s = c.settings;
    final cfg = AppConfig.instance;

    void update(AppSettings ns) => c.updateSettings(ns);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          const _Title('Réglages'),

          // ---- Compte / profil ----
          const _Header('Compte'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: cfg.accentColor,
              child: Text(
                (c.activeProfile?.name ?? '?').characters.first.toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(c.activeProfile?.name ?? 'Aucun profil'),
            subtitle: const Text('Changer de profil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfilesScreen()),
            ),
          ),
          if (c.cloudEnabled)
            ListTile(
              leading: Icon(
                c.isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                color: c.isSignedIn ? Colors.greenAccent : Colors.white38,
              ),
              title: Text(c.isSignedIn ? 'Connecté au cloud' : 'Non connecté'),
              subtitle: Text(c.cloud.currentUser?.email ??
                  'Connecte-toi pour synchroniser tes appareils'),
              trailing: TextButton(
                onPressed: () async {
                  if (c.isSignedIn) {
                    await c.signOut();
                  } else {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()));
                  }
                },
                child: Text(c.isSignedIn ? 'Déconnexion' : 'Connexion'),
              ),
            ),

          // ---- Sources ----
          const _Header('Sources IPTV'),
          for (final src in c.sources)
            ListTile(
              leading: Icon(src.isXtream ? Icons.dns : Icons.link),
              title: Text(src.name),
              subtitle: Text(src.isXtream ? 'Xtream Codes' : 'Playlist M3U'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => c.removeSource(src),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Ajouter une source'),
            subtitle: c.cloudEnabled && !c.isSignedIn
                ? const Text('Connecte-toi d\'abord')
                : null,
            onTap: () => _addSource(context, c),
          ),

          // ---- Apparence ----
          const _Header('Apparence'),
          _DropdownTile<String>(
            icon: Icons.language,
            label: 'Langue du contenu',
            value: s.contentLanguage,
            options: AppSettings.languageOptions,
            onChanged: (v) => update(s.copyWith(contentLanguage: v)),
          ),
          _AccentTile(
            current: s.accent,
            onPick: (a) => update(s.copyWith(accent: a)),
          ),
          _SwitchTile(
            icon: Icons.leaderboard,
            label: 'Afficher le Top 10',
            value: s.showTop10,
            onChanged: (v) => update(s.copyWith(showTop10: v)),
          ),
          _SwitchTile(
            icon: Icons.animation,
            label: 'Aperçus animés à l\'accueil',
            subtitle: 'Peut consommer plus de données',
            value: s.autoplayPreviews,
            onChanged: (v) => update(s.copyWith(autoplayPreviews: v)),
          ),

          // ---- Lecture ----
          const _Header('Lecture'),
          _DropdownTile<String>(
            icon: Icons.high_quality,
            label: 'Qualité préférée',
            value: s.preferredQuality,
            options: const {
              'auto': 'Automatique',
              '4K': '4K / Ultra HD',
              '1080p': 'Full HD (1080p)',
              '720p': 'HD (720p)',
            },
            onChanged: (v) => update(s.copyWith(preferredQuality: v)),
          ),
          _SwitchTile(
            icon: Icons.skip_next,
            label: 'Lecture auto de l\'épisode suivant',
            value: s.autoplayNext,
            onChanged: (v) => update(s.copyWith(autoplayNext: v)),
          ),
          _SwitchTile(
            icon: Icons.history_toggle_off,
            label: 'Reprendre où je m\'étais arrêté',
            value: s.rememberPosition,
            onChanged: (v) => update(s.copyWith(rememberPosition: v)),
          ),
          _DropdownTile<double>(
            icon: Icons.speed,
            label: 'Vitesse de lecture par défaut',
            value: s.playbackSpeed,
            options: <double, String>{
              0.5: '0.5×',
              0.75: '0.75×',
              1.0: 'Normale (1×)',
              1.25: '1.25×',
              1.5: '1.5×',
              2.0: '2×',
            },
            onChanged: (v) => update(s.copyWith(playbackSpeed: v)),
          ),
          _DropdownTile<int>(
            icon: Icons.fast_forward,
            label: 'Avance / recul rapide',
            value: s.seekSeconds,
            options: const {10: '10 secondes', 15: '15 secondes', 30: '30 secondes'},
            onChanged: (v) => update(s.copyWith(seekSeconds: v)),
          ),
          _SwitchTile(
            icon: Icons.memory,
            label: 'Accélération matérielle',
            subtitle: 'Désactive si la vidéo saccade',
            value: s.hardwareAcceleration,
            onChanged: (v) => update(s.copyWith(hardwareAcceleration: v)),
          ),

          // ---- Sous-titres ----
          const _Header('Sous-titres'),
          _SwitchTile(
            icon: Icons.subtitles,
            label: 'Sous-titres activés par défaut',
            value: s.subtitlesEnabled,
            onChanged: (v) => update(s.copyWith(subtitlesEnabled: v)),
          ),
          _DropdownTile<String>(
            icon: Icons.translate,
            label: 'Langue des sous-titres',
            value: s.subtitleLanguage,
            options: const {
              'Français': 'Français',
              'Anglais': 'Anglais',
              'Espagnol': 'Espagnol',
              'Arabe': 'Arabe',
            },
            onChanged: (v) => update(s.copyWith(subtitleLanguage: v)),
          ),

          // ---- Données & téléchargements ----
          const _Header('Données & téléchargements'),
          _SwitchTile(
            icon: Icons.wifi,
            label: 'Télécharger en Wi-Fi uniquement',
            value: s.wifiOnlyDownloads,
            onChanged: (v) => update(s.copyWith(wifiOnlyDownloads: v)),
          ),
          _SwitchTile(
            icon: Icons.data_saver_on,
            label: 'Économiseur de données',
            subtitle: 'Qualité réduite en connexion mobile',
            value: s.dataSaver,
            onChanged: (v) => update(s.copyWith(dataSaver: v)),
          ),

          // ---- Maintenance ----
          const _Header('Maintenance'),
          ListTile(
            leading: const Icon(Icons.playlist_remove),
            title: const Text('Effacer « Continuer à regarder »'),
            onTap: () async {
              await c.clearContinueWatching();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historique effacé')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cached),
            title: const Text('Vider le cache'),
            subtitle: const Text('Recharge le catalogue à neuf'),
            onTap: () async {
              await c.local.clearCache();
              await c.reloadCatalog(force: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache vidé')),
                );
              }
            },
          ),

          // ---- État config ----
          const _Header('Configuration'),
          _StatusTile(
            label: 'Clé TMDB',
            ok: cfg.tmdbEnabled,
            okText: 'Active — affiches et résumés enrichis',
            koText: 'Ajoute ta clé TMDB dans le fichier de config',
          ),
          _StatusTile(
            label: 'Supabase (cloud)',
            ok: cfg.supabaseEnabled,
            okText: 'Configuré',
            koText: 'Non configuré',
          ),

          const SizedBox(height: 20),
          Center(
            child: Text('${cfg.appName} v2.0.0',
                style: const TextStyle(color: Colors.white24, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _addSource(BuildContext context, AppController c) {
    if (c.cloudEnabled && !c.isSignedIn) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AddSourceScreen()));
  }
}

// --------------------------------------------------------------- Widgets util

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            )),
      );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: DropdownButton<T>(
        value: options.containsKey(value) ? value : options.keys.first,
        dropdownColor: const Color(0xFF16161D),
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(10),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _AccentTile extends StatelessWidget {
  const _AccentTile({required this.current, required this.onPick});
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Couleur d\'accent'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in AppSettings.accentOptions.entries)
            GestureDetector(
              onTap: () => onPick(e.key),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(e.value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current == e.key ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.ok,
    required this.okText,
    required this.koText,
  });
  final String label;
  final bool ok;
  final String okText;
  final String koText;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(ok ? Icons.check_circle : Icons.error_outline,
          color: ok ? Colors.greenAccent : Colors.orangeAccent),
      title: Text(label),
      subtitle: Text(ok ? okText : koText),
    );
  }
}
