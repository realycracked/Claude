import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/source.dart';
import '../../services/xtream_service.dart';
import '../../state/app_controller.dart';
import 'profiles_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final cfg = AppConfig.instance;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const _SectionTitle('Réglages'),

          // ---- Profil actif ----
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
          const Divider(),

          // ---- Sources IPTV ----
          const _SectionHeader('Sources IPTV'),
          for (final s in c.sources)
            ListTile(
              leading: Icon(s.isXtream ? Icons.dns : Icons.link),
              title: Text(s.name),
              subtitle: Text(s.isXtream ? 'Xtream Codes' : 'Playlist M3U'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => c.removeSource(s),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Ajouter une source'),
            onTap: () => _addSource(context),
          ),
          const Divider(),

          // ---- Cloud (Supabase) ----
          const _SectionHeader('Cloud & synchronisation'),
          ListTile(
            leading: Icon(
              c.cloudEnabled ? Icons.cloud_done : Icons.cloud_off,
              color: c.cloudEnabled ? Colors.greenAccent : Colors.white38,
            ),
            title: Text(c.cloudEnabled
                ? (c.isSignedIn ? 'Connecté au cloud' : 'Cloud configuré')
                : 'Cloud non configuré'),
            subtitle: Text(c.cloudEnabled
                ? (c.isSignedIn
                    ? 'Profils et sources synchronisés'
                    : 'Connecte-toi pour synchroniser')
                : 'Remplis la section "supabase" dans le fichier de config'),
            trailing: c.cloudEnabled
                ? TextButton(
                    onPressed: () =>
                        c.isSignedIn ? c.cloud.signOut() : _authDialog(context),
                    child: Text(c.isSignedIn ? 'Déconnexion' : 'Connexion'),
                  )
                : null,
          ),
          const Divider(),

          // ---- Infos config ----
          const _SectionHeader('Configuration (fichier app_config.json)'),
          _StatusTile(
            label: 'Clé TMDB',
            ok: cfg.tmdbEnabled,
            okText: 'Active — affiches et résumés enrichis',
            koText: 'Ajoute ta clé TMDB dans le fichier de config',
          ),
          _StatusTile(
            label: 'Supabase',
            ok: cfg.supabaseEnabled,
            okText: 'Configuré',
            koText: 'Non configuré (optionnel)',
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
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${cfg.appName} v1.0.0',
              style: const TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _addSource(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddSourceSheet(),
    );
  }

  void _authDialog(BuildContext context) {
    final email = TextEditingController();
    final pass = TextEditingController();
    final c = context.read<AppController>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connexion cloud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              decoration: const InputDecoration(hintText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Mot de passe'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await c.cloud.signUp(email.text.trim(), pass.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {}
            },
            child: const Text('Créer un compte'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await c.cloud.signIn(email.text.trim(), pass.text.trim());
                await c.bootstrap();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Connexion échouée')),
                  );
                }
              }
            },
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}

class _AddSourceSheet extends StatefulWidget {
  const _AddSourceSheet();

  @override
  State<_AddSourceSheet> createState() => _AddSourceSheetState();
}

class _AddSourceSheetState extends State<_AddSourceSheet> {
  SourceKind _kind = SourceKind.xtream;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _epg = TextEditingController();
  bool _testing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter une source',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SegmentedButton<SourceKind>(
              segments: const [
                ButtonSegment(
                    value: SourceKind.xtream,
                    label: Text('Xtream'),
                    icon: Icon(Icons.dns)),
                ButtonSegment(
                    value: SourceKind.m3u,
                    label: Text('M3U'),
                    icon: Icon(Icons.link)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom de la source'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _url,
              decoration: InputDecoration(
                labelText: _kind == SourceKind.xtream
                    ? 'URL du serveur (http://host:port)'
                    : 'Lien de la playlist (.m3u / .m3u8)',
              ),
            ),
            if (_kind == SourceKind.xtream) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'Nom d\'utilisateur'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pass,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _epg,
              decoration: const InputDecoration(
                labelText: 'Lien EPG / XMLTV (optionnel)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _testing ? null : _save,
                child: _testing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tester et ajouter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _testing = true;
      _error = null;
    });
    final url = _url.text.trim().replaceAll(RegExp(r'/+$'), '');
    final source = IptvSource(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? 'Ma source' : _name.text.trim(),
      kind: _kind,
      url: url,
      username: _user.text.trim(),
      password: _pass.text.trim(),
      epgUrl: _epg.text.trim(),
    );

    // Test de connexion pour Xtream (les identifiants doivent être valides).
    if (_kind == SourceKind.xtream) {
      final x = XtreamService();
      try {
        await x.authenticate(source);
      } catch (e) {
        setState(() {
          _testing = false;
          _error = 'Connexion impossible. Vérifie l\'URL et les identifiants.';
        });
        x.dispose();
        return;
      }
      x.dispose();
    }

    if (!mounted) return;
    await context.read<AppController>().addSource(source);
    if (mounted) Navigator.pop(context);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(text,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(text.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            )),
      );
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
