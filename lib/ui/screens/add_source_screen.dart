import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/source.dart';
import '../../services/xtream_service.dart';
import '../../state/app_controller.dart';

/// Ajout d'une source IPTV en page plein écran (Xtream ou M3U).
class AddSourceScreen extends StatefulWidget {
  const AddSourceScreen({super.key});

  @override
  State<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends State<AddSourceScreen> {
  SourceKind _kind = SourceKind.xtream;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _epg = TextEditingController();
  bool _testing = false;
  String? _error;
  String _step = '';
  final List<String> _doneSteps = [];

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _epg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter une source')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom de la source'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: _kind == SourceKind.xtream
                    ? 'URL du serveur (http://host:port)'
                    : 'Lien de la playlist (.m3u / .m3u8)',
              ),
            ),
            if (_kind == SourceKind.xtream) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _user,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Nom d\'utilisateur'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _epg,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Lien EPG / XMLTV (optionnel)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _testing ? null : _save,
                child: _testing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Tester et ajouter'),
              ),
            ),
            // Progression détaillée du chargement (au lieu d'un simple rond).
            if (_testing) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.downloading, size: 18, color: Colors.white54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _step.isEmpty ? 'Connexion…' : _step,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (_doneSteps.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final d in _doneSteps.reversed.take(6))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            children: [
                              const Icon(Icons.check,
                                  size: 13, color: Color(0xFF46D369)),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(d,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11.5, color: Colors.white54)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final url = _url.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      setState(() => _error = 'Entre l\'URL ou le lien de la source.');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
      _step = 'Connexion au serveur…';
      _doneSteps.clear();
    });

    final source = IptvSource(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? 'Ma source' : _name.text.trim(),
      kind: _kind,
      url: url,
      username: _user.text.trim(),
      password: _pass.text.trim(),
      epgUrl: _epg.text.trim(),
    );

    if (_kind == SourceKind.xtream) {
      final x = XtreamService();
      try {
        await x.authenticate(source);
        setState(() => _doneSteps.add('Identifiants validés'));
      } catch (_) {
        x.dispose();
        setState(() {
          _testing = false;
          _step = '';
          _error = 'Connexion impossible. Vérifie l\'URL et les identifiants.';
        });
        return;
      }
      x.dispose();
    }

    if (!mounted) return;
    final c = context.read<AppController>();

    // Suit les étapes réelles du chargement du catalogue.
    c.addListener(_onControllerTick);
    await c.addSource(source);
    c.removeListener(_onControllerTick);

    if (!mounted) return;
    final total = c.totalItems;
    if (total == 0) {
      setState(() {
        _testing = false;
        _step = '';
        _error = c.loadErrors.isNotEmpty
            ? c.loadErrors.first
            : 'Source ajoutée, mais aucun contenu trouvé.';
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('« ${source.name} » ajoutée — $total éléments')),
    );
    Navigator.pop(context);
  }

  void _onControllerTick() {
    if (!mounted) return;
    final c = context.read<AppController>();
    final s = c.loadStep;
    if (s.isEmpty || s == _step) return;
    setState(() {
      if (_step.isNotEmpty) _doneSteps.add(_step);
      _step = s;
    });
  }
}
