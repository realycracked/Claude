import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/profile.dart';
import '../../state/app_controller.dart';
import '../widgets/focusable.dart';
import 'home_shell.dart';

/// Sélection de profil (façon "Qui regarde ?" de Netflix).
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  bool _manage = false;

  static const _avatarColors = [
    Color(0xFFE50914),
    Color(0xFF2979FF),
    Color(0xFF00C853),
    Color(0xFFFFB300),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
  ];

  Color _colorFor(String id) =>
      _avatarColors[id.hashCode.abs() % _avatarColors.length];

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppController>();
    final cfg = AppConfig.instance;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cfg.appName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: cfg.accentColor,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _manage ? 'Gérer les profils' : 'Qui regarde ?',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 36),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in c.profiles)
                      _ProfileTile(
                        profile: p,
                        color: _colorFor(p.id),
                        manage: _manage,
                        onTap: () =>
                            _manage ? _edit(context, p) : _onSelect(context, p),
                      ),
                    if (!_manage && c.profiles.length < 6)
                      _AddTile(onTap: () => _edit(context, null)),
                  ],
                ),
                const SizedBox(height: 36),
                if (c.profiles.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _manage = !_manage),
                    icon: Icon(_manage ? Icons.check : Icons.edit),
                    label: Text(_manage ? 'Terminé' : 'Gérer les profils'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSelect(BuildContext context, Profile p) async {
    final c = context.read<AppController>();
    await c.selectProfile(p);
    c.reloadCatalog();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  void _edit(BuildContext context, Profile? p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileEditor(profile: p),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.color,
    required this.manage,
    required this.onTap,
  });

  final Profile profile;
  final Color color;
  final bool manage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Focusable(
            onTap: onTap,
            borderRadius: 14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      profile.name.isNotEmpty
                          ? profile.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (manage)
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 30),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            profile.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          if (profile.isKids)
            const Text('Enfant',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Focusable(
            onTap: onTap,
            borderRadius: 14,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.add, size: 42, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Ajouter', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({this.profile});
  final Profile? profile;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile?.name ?? '');
  late bool _isKids = widget.profile?.isKids ?? false;

  @override
  Widget build(BuildContext context) {
    final editing = widget.profile != null;
    final c = context.read<AppController>();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editing ? 'Modifier le profil' : 'Nouveau profil',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nom du profil'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isKids,
            onChanged: (v) => setState(() => _isKids = v),
            title: const Text('Profil enfant'),
            subtitle: const Text('Contenu limité et adapté'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (editing && c.profiles.length > 1)
                TextButton.icon(
                  onPressed: () async {
                    await c.deleteProfile(widget.profile!);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () => _save(c),
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppController c) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (widget.profile == null) {
      await c.createProfile(name, isKids: _isKids);
    } else {
      await c.updateProfile(widget.profile!.copyWith(name: name, isKids: _isKids));
    }
    if (mounted) Navigator.pop(context);
  }
}
